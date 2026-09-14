[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd(
        [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-StrictDescendant {
    param([Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate)
    return $Candidate.StartsWith(
        $Root + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)
}

function Assert-ContainedNonReparseChain {
    param([Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate)
    $rootFull = Get-CanonicalPath $Root
    $candidateFull = Get-CanonicalPath $Candidate
    if (-not (Test-StrictDescendant -Root $rootFull -Candidate $candidateFull)) {
        throw "PATH_CONTAINMENT: '$candidateFull' is outside '$rootFull'."
    }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\', '/')
    $cursor = $rootFull
    foreach ($part in @('') + @($relative -split '[\\/]')) {
        if ($part.Length -ne 0) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "PATH_REPARSE_POINT: '$cursor'."
            }
        }
    }
    return $candidateFull
}

function Write-AtomicJson {
    param([Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value)
    $json = ConvertTo-Json -InputObject $Value -Depth 12 -Compress
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, $json + "`n", $script:utf8NoBom)
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($temporary, $Path, [NullString]::Value)
        } else {
            [IO.File]::Move($temporary, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) }
    }
    return $json
}

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    [void]$script:failures.Add($Message)
}

function Wait-LogMarker {
    param([Parameter(Mandatory = $true)][string]$Marker,
        [int]$TimeoutSeconds = 10)
    $poll = [Diagnostics.Stopwatch]::StartNew()
    while ($poll.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if (Test-Path -LiteralPath $script:logFull -PathType Leaf) {
            $matches = @(Get-Content -LiteralPath $script:logFull -Encoding UTF8 | Where-Object {
                $_ -ceq $Marker
            })
            if ($matches.Count -gt 1) { throw "MARKER_AMBIGUOUS: $Marker count=$($matches.Count)" }
            if ($matches.Count -eq 1) { return }
        }
        Start-Sleep -Milliseconds 50
    }
    throw "MARKER_TIMEOUT: $Marker"
}

function Get-ControlElements {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Window)
    return @($Window.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        [Windows.Automation.Automation]::ControlViewCondition))
}

function Get-PublicSnapshot {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Window,
        [Parameter(Mandatory = $true)][IntPtr]$WindowHandle)
    $elements = @(Get-ControlElements -Window $Window)
    $empty = @($elements | Where-Object {
        $_.Current.Name.TrimEnd() -ceq $script:expectedEmpty
    })
    $buttons = @($elements | Where-Object {
        $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button
    })
    $items = @($elements | Where-Object {
        $_.Current.ControlType -eq [Windows.Automation.ControlType]::ListItem
    })
    $liveValue = -1
    if ($empty.Count -eq 1) {
        $liveValue = [GalleryEmptyUiaCollector]::ReadLiveSetting(
            $WindowHandle, $script:expectedEmpty)
    }
    return [ordered]@{
        empty_count = $empty.Count
        empty_control_type = if ($empty.Count -eq 1) {
            [string]$empty[0].Current.ControlType.ProgrammaticName
        } else { '' }
        empty_live_setting = $liveValue
        list_item_count = $items.Count
        buttons = @($buttons | ForEach-Object {
            [ordered]@{
                name = [string]$_.Current.Name.TrimEnd()
                focused = [bool]$_.Current.HasKeyboardFocus
            }
        })
    }
}

function Assert-EmptyProjection {
    param([Parameter(Mandatory = $true)]$Snapshot,
        [Parameter(Mandatory = $true)][int]$ExpectedLiveSetting,
        [Parameter(Mandatory = $true)][string]$Phase)
    if ($Snapshot.empty_count -ne 1 -or $Snapshot.empty_control_type -cne 'ControlType.Text') {
        Add-Failure "UIA_EMPTY_TEXT_INVALID: phase=$Phase count=$($Snapshot.empty_count) type='$($Snapshot.empty_control_type)'"
    }
    if ($Snapshot.empty_live_setting -ne $ExpectedLiveSetting) {
        Add-Failure "UIA_EMPTY_LIVE_SETTING: phase=$Phase expected=$ExpectedLiveSetting actual=$($Snapshot.empty_live_setting)"
    }
    if ($Snapshot.list_item_count -ne 0) {
        Add-Failure "UIA_EMPTY_LIST_ITEMS_PRESENT: phase=$Phase count=$($Snapshot.list_item_count)"
    }
    if ($Snapshot.buttons.Count -ne 1 -or $Snapshot.buttons[0].name -cne $script:expectedReturn) {
        Add-Failure "UIA_EMPTY_BUTTONS_INVALID: phase=$Phase observed='$(@($Snapshot.buttons.name) -join '|')'"
    } elseif (-not [bool]$Snapshot.buttons[0].focused) {
        Add-Failure "UIA_EMPTY_RETURN_NOT_FOCUSED: phase=$Phase"
    }
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$phaseTestsRoot = Get-CanonicalPath (Join-Path $repositoryRoot '.godot\phase2r_tests')
$logFull = Get-CanonicalPath $LogPath
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = $logFull + '.uia.json' }
$outputFull = Get-CanonicalPath $OutputPath
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFull) -PathType Container)) {
    throw "OUTPUT_PARENT_MISSING: $outputFull"
}

$utf8NoBom = New-Object Text.UTF8Encoding($false)
$failures = [Collections.Generic.List[string]]::new()
$ready = $null
$commandFull = $null
$completionFull = $null
$targetPid = 0
$expectedTitle = ''
$expectedEmpty = ''
$expectedReturn = ''
$windowRecord = $null
$processRecord = $null
$openSnapshot = $null
$refreshSnapshot = $null
$reopenSnapshot = $null
$baselineSnapshot = $null
$baselineEvents = @()
$openEvents = @()
$refreshEvents = @()
$reopenEvents = @()
$collector = $null
$window = $null
$liveEvent = $null
$liveProperty = $null
$subscribed = $false
$ok = $false
$code = 'gallery_empty_accessibility_failed'

try {
    $poll = [Diagnostics.Stopwatch]::StartNew()
    while ($poll.Elapsed.TotalSeconds -lt 15) {
        if (Test-Path -LiteralPath $logFull -PathType Leaf) {
            $markers = @(Get-Content -LiteralPath $logFull -Encoding UTF8 | Where-Object {
                $_.StartsWith('READY ', [StringComparison]::Ordinal)
            })
            if ($markers.Count -gt 1) { throw "READY_MARKER_AMBIGUOUS: $($markers.Count)" }
            if ($markers.Count -eq 1) {
                $ready = ConvertFrom-Json -InputObject $markers[0].Substring(6) -ErrorAction Stop
                break
            }
        }
        Start-Sleep -Milliseconds 50
    }
    if ($null -eq $ready) { throw "READY_TIMEOUT: $logFull" }

    $commandFull = Assert-ContainedNonReparseChain -Root $phaseTestsRoot `
        -Candidate ([string]$ready.command_path)
    $completionFull = Assert-ContainedNonReparseChain -Root $phaseTestsRoot `
        -Candidate ([string]$ready.completion_path)
    $testRoot = Split-Path -Parent $completionFull
    $runRoot = Split-Path -Parent $testRoot
    $runParent = Get-CanonicalPath (Split-Path -Parent $runRoot)
    $runId = Split-Path -Leaf $runRoot
    $parsedRunId = [guid]::Empty
    if ((Split-Path -Leaf $commandFull) -cne 'gallery-empty-command.json' -or
        (Split-Path -Leaf $completionFull) -cne 'gallery-empty-complete.json' -or
        (Split-Path -Parent $commandFull) -cne $testRoot -or
        (Split-Path -Leaf $testRoot) -cne 'dwm_test_root' -or
        -not $runParent.Equals($phaseTestsRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not [guid]::TryParse($runId, [ref]$parsedRunId) -or
        -not (Test-Path -LiteralPath $testRoot -PathType Container) -or
        (Test-Path -LiteralPath $completionFull)) {
        $completionFull = $null
        throw 'READY_PATH_CONTRACT_INVALID'
    }

    $targetPid = [int]$ready.pid
    $expectedTitle = "DWM Gallery Empty $targetPid"
    $expectedEmpty = [string]$ready.expected_empty
    $expectedReturn = [string]$ready.expected_return
    if ($targetPid -le 0 -or [string]$ready.window_title -cne $expectedTitle -or
        [string]::IsNullOrWhiteSpace($expectedEmpty) -or
        [string]::IsNullOrWhiteSpace($expectedReturn) -or
        $expectedEmpty -ceq $expectedReturn) {
        throw 'READY_CONTRACT_INVALID'
    }

    $process = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $targetPid"
    if ($null -eq $process -or [string]::IsNullOrWhiteSpace([string]$process.CommandLine)) {
        throw "READY_PROCESS_NOT_LIVE: $targetPid"
    }
    $commandLine = [string]$process.CommandLine
    $arguments = @([regex]::Matches($commandLine, '"(?<quoted>[^" ](?:[^"]|"")*)"|(?<plain>\S+)') |
        ForEach-Object { if ($_.Groups['quoted'].Success) { $_.Groups['quoted'].Value } else { $_.Groups['plain'].Value } })
    function Assert-ExactOptionValue([string]$Option, [string]$Value) {
        $indices = @(0..($arguments.Count - 1) | Where-Object { $arguments[$_] -ieq $Option })
        if ($indices.Count -ne 1 -or $indices[0] + 1 -ge $arguments.Count -or
            $arguments[$indices[0] + 1] -ine $Value) {
            throw "READY_PROCESS_COMMAND_MISMATCH: expected '$Option $Value' pid=$targetPid"
        }
    }
    Assert-ExactOptionValue '--path' $repositoryRoot
    Assert-ExactOptionValue '--display-driver' 'windows'
    Assert-ExactOptionValue '--accessibility' 'always'
    if (-not ($arguments -ccontains 'res://tests/manual/verify_gallery_empty_accessibility.gd')) {
        throw "READY_PROCESS_COMMAND_MISMATCH: fixture script pid=$targetPid"
    }
    $processRecord = [ordered]@{
        process_id = [int]$process.ProcessId
        name = [string]$process.Name
        command_line = $commandLine
    }

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $identifierType = [Windows.Automation.AutomationElementIdentifiers]
    $eventField = $identifierType.GetField('LiveRegionChangedEvent')
    $propertyField = $identifierType.GetField('LiveSettingProperty')
    if ($null -ne $eventField) { $liveEvent = $eventField.GetValue($null) }
    if ($null -ne $propertyField) { $liveProperty = $propertyField.GetValue($null) }
    if ($null -eq $liveEvent) {
        $liveEvent = [Windows.Automation.AutomationEvent]::LookupById(20024)
    }
    if ($null -eq $liveProperty) {
        $liveProperty = [Windows.Automation.AutomationProperty]::LookupById(30135)
    }
    if ($null -eq $liveEvent -or $null -eq $liveProperty) {
        throw 'UIA_LIVE_IDENTIFIERS_UNAVAILABLE'
    }

    if ($null -eq ('GalleryEmptyUiaCollector' -as [type])) {
        $interopPath = Get-ChildItem -LiteralPath 'C:\Program Files (x86)\Windows Kits\10\bin' `
            -Filter 'Interop.UIAutomationClient.dll' -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]x64[\\/]UIAVerify[\\/]' } |
            Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
        if ([string]::IsNullOrWhiteSpace($interopPath)) {
            throw 'UIA_COM_INTEROP_ASSEMBLY_UNAVAILABLE'
        }
        [void][Reflection.Assembly]::LoadFrom($interopPath)
        $uiaReferences = @(
            [Windows.Automation.AutomationElement].Assembly.Location
            [Windows.Automation.Automation].Assembly.Location
            [Windows.Automation.AutomationEvent].Assembly.Location
            $interopPath
        ) | Select-Object -Unique
        $collectorSource = @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;
using System.Windows.Automation;
using RawUia = UIAutomationClient;

public sealed class GalleryEmptyUiaEventRecord {
    public string Name { get; set; }
    public string ControlType { get; set; }
    public int ProcessId { get; set; }
    public int LiveSetting { get; set; }
    public string ObservedAtUtc { get; set; }
}

public sealed class GalleryEmptyUiaCollector : IDisposable {
    private readonly object gate = new object();
    private readonly List<GalleryEmptyUiaEventRecord> records = new List<GalleryEmptyUiaEventRecord>();
    private AutomationElement root;
    private AutomationEvent eventId;
    private AutomationProperty liveProperty;
    private AutomationEventHandler handler;
    private Thread worker;
    private IntPtr subscribedWindowHandle;
    private readonly ManualResetEvent ready = new ManualResetEvent(false);
    private readonly ManualResetEvent stop = new ManualResetEvent(false);
    private Exception workerError;

    public static int ReadLiveSetting(IntPtr windowHandle, string expectedName) {
        RawUia.IUIAutomation automation = (RawUia.IUIAutomation)new RawUia.CUIAutomation8Class();
        RawUia.IUIAutomationElement root = automation.ElementFromHandle(windowHandle);
        RawUia.IUIAutomationCondition nameCondition = automation.CreatePropertyCondition(30005, expectedName);
        RawUia.IUIAutomationElement element = root.FindFirst(
            RawUia.TreeScope.TreeScope_Descendants, nameCondition);
        if (element == null) return -1;
        object value = element.GetCurrentPropertyValue(30135);
        return value == null ? -1 : Convert.ToInt32(value, CultureInfo.InvariantCulture);
    }

    public void Subscribe(IntPtr windowHandle, AutomationEvent liveEvent, AutomationProperty liveSetting) {
        if (worker != null) throw new InvalidOperationException("Already subscribed.");
        if (windowHandle == IntPtr.Zero) throw new ArgumentException("Window handle is zero.", "windowHandle");
        if (liveEvent == null) throw new ArgumentNullException("liveEvent");
        if (liveSetting == null) throw new ArgumentNullException("liveSetting");
        eventId = liveEvent;
        liveProperty = liveSetting;
        worker = new Thread(delegate() { Listen(windowHandle); });
        worker.IsBackground = true;
        worker.SetApartmentState(ApartmentState.MTA);
        worker.Start();
        if (!ready.WaitOne(5000)) {
            stop.Set();
            throw new TimeoutException("UIA event subscription timed out.");
        }
        if (workerError != null) {
            stop.Set();
            worker.Join(5000);
            throw new InvalidOperationException("UIA event subscription failed.", workerError);
        }
    }

    private void Listen(IntPtr windowHandle) {
        try {
            subscribedWindowHandle = windowHandle;
            root = AutomationElement.FromHandle(windowHandle);
            if (root == null) throw new InvalidOperationException("UIA window element is unavailable.");
            handler = OnEvent;
            Automation.AddAutomationEventHandler(eventId, root, TreeScope.Descendants, handler);
        } catch (Exception error) {
            workerError = error;
        } finally {
            ready.Set();
        }
        if (workerError != null) return;
        stop.WaitOne();
        try {
            Automation.RemoveAutomationEventHandler(eventId, root, handler);
        } catch (Exception error) {
            workerError = error;
        }
    }

    private void OnEvent(object sender, AutomationEventArgs args) {
        AutomationElement element = sender as AutomationElement;
        if (element == null || args == null || args.EventId != eventId) return;
        try {
            string name = element.Current.Name == null ? "" : element.Current.Name.TrimEnd();
            int live;
            try {
                live = ReadLiveSetting(subscribedWindowHandle, name);
            } catch {
                live = -1;
            }
            GalleryEmptyUiaEventRecord record = new GalleryEmptyUiaEventRecord {
                Name = name,
                ControlType = element.Current.ControlType.ProgrammaticName,
                ProcessId = element.Current.ProcessId,
                LiveSetting = live,
                ObservedAtUtc = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)
            };
            lock (gate) records.Add(record);
        } catch (ElementNotAvailableException) {
        } catch (InvalidOperationException) {
        }
    }

    public GalleryEmptyUiaEventRecord[] Snapshot() {
        lock (gate) return records.ToArray();
    }

    public void Dispose() {
        if (worker == null) return;
        stop.Set();
        if (!worker.Join(5000)) throw new TimeoutException("UIA event unsubscribe timed out.");
        if (workerError != null) throw new InvalidOperationException("UIA event listener failed.", workerError);
        worker = null;
        handler = null;
        root = null;
        eventId = null;
        liveProperty = null;
    }
}
'@
        Add-Type -TypeDefinition $collectorSource -ReferencedAssemblies $uiaReferences -ErrorAction Stop
    }

    $nativeProcess = [Diagnostics.Process]::GetProcessById($targetPid)
    $windowPoll = [Diagnostics.Stopwatch]::StartNew()
    while ($windowPoll.Elapsed.TotalSeconds -lt 5) {
        $nativeProcess.Refresh()
        if ($nativeProcess.MainWindowHandle -ne [IntPtr]::Zero -and
            $nativeProcess.MainWindowTitle -ceq $expectedTitle) {
            $candidate = [Windows.Automation.AutomationElement]::FromHandle(
                $nativeProcess.MainWindowHandle)
            if ($null -ne $candidate -and $candidate.Current.ProcessId -eq $targetPid) {
                $window = $candidate
                break
            }
        }
        Start-Sleep -Milliseconds 50
    }
    if ($null -eq $window) {
        throw "UIA_WINDOW_NOT_FOUND: expected='$expectedTitle' pid=$targetPid"
    }
    $windowRecord = [ordered]@{
        name = [string]$window.Current.Name
        process_id = [int]$window.Current.ProcessId
        automation_id = [string]$window.Current.AutomationId
        native_window_handle = [int64]$nativeProcess.MainWindowHandle
        native_title = [string]$nativeProcess.MainWindowTitle
    }

    $collector = [GalleryEmptyUiaCollector]::new()
    $collector.Subscribe($nativeProcess.MainWindowHandle, $liveEvent, $liveProperty)
    $subscribed = $true

    Start-Sleep -Milliseconds 300
    $baselineEvents = @($collector.Snapshot())
    $baselineSnapshot = Get-PublicSnapshot -Window $window -WindowHandle $nativeProcess.MainWindowHandle
    if ($baselineEvents.Count -ne 0) {
        Add-Failure "UIA_EMPTY_BASELINE_EVENTS: expected=0 actual=$($baselineEvents.Count)"
    }
    if ($baselineSnapshot.empty_count -ne 0) {
        Add-Failure "UIA_EMPTY_BASELINE_PUBLIC_TEXT: expected=0 actual=$($baselineSnapshot.empty_count)"
    }

    [void](Write-AtomicJson -Path $commandFull -Value ([ordered]@{ phase = 'open' }))
    Wait-LogMarker -Marker 'PHASE open'
    Start-Sleep -Milliseconds 300
    $openEvents = @($collector.Snapshot() | Where-Object {
        $_.ProcessId -eq $targetPid -and $_.Name -ceq $expectedEmpty -and
        $_.ControlType -ceq 'ControlType.Text' -and $_.LiveSetting -eq 1
    })
    $openSnapshot = Get-PublicSnapshot -Window $window -WindowHandle $nativeProcess.MainWindowHandle
    Assert-EmptyProjection -Snapshot $openSnapshot -ExpectedLiveSetting 1 -Phase 'open'
    if ($openEvents.Count -ne 1) {
        Add-Failure "UIA_EMPTY_OPEN_EVENT_COUNT: expected=1 actual=$($openEvents.Count)"
    }

    [void](Write-AtomicJson -Path $commandFull -Value ([ordered]@{ phase = 'refresh' }))
    Wait-LogMarker -Marker 'PHASE refresh'
    Start-Sleep -Milliseconds 300
    $refreshEvents = @($collector.Snapshot() | Where-Object {
        $_.ProcessId -eq $targetPid -and $_.Name -ceq $expectedEmpty -and
        $_.ControlType -ceq 'ControlType.Text' -and $_.LiveSetting -eq 1
    })
    $refreshSnapshot = Get-PublicSnapshot -Window $window -WindowHandle $nativeProcess.MainWindowHandle
    Assert-EmptyProjection -Snapshot $refreshSnapshot -ExpectedLiveSetting 0 -Phase 'refresh'
    if ($refreshEvents.Count -ne 1) {
        Add-Failure "UIA_EMPTY_REFRESH_EVENT_COUNT: expected=1 actual=$($refreshEvents.Count)"
    }

    [void](Write-AtomicJson -Path $commandFull -Value ([ordered]@{ phase = 'reopen' }))
    Wait-LogMarker -Marker 'PHASE reopen'
    Start-Sleep -Milliseconds 300
    $reopenEvents = @($collector.Snapshot() | Where-Object {
        $_.ProcessId -eq $targetPid -and $_.Name -ceq $expectedEmpty -and
        $_.ControlType -ceq 'ControlType.Text' -and $_.LiveSetting -eq 1
    })
    $reopenSnapshot = Get-PublicSnapshot -Window $window -WindowHandle $nativeProcess.MainWindowHandle
    Assert-EmptyProjection -Snapshot $reopenSnapshot -ExpectedLiveSetting 1 -Phase 'reopen'
    if ($reopenEvents.Count -ne 2) {
        Add-Failure "UIA_EMPTY_REOPEN_EVENT_COUNT: expected=2 actual=$($reopenEvents.Count)"
    }
} catch {
    Add-Failure $_.Exception.Message
} finally {
    if ($subscribed -and $null -ne $collector) {
        try {
            $collector.Dispose()
        } catch {
            Add-Failure "UIA_EVENT_UNSUBSCRIBE_FAILED: $($_.Exception.Message)"
        }
    }
    $ok = $failures.Count -eq 0
    $code = if ($ok) { 'ok' } else { 'gallery_empty_accessibility_failed' }
    $record = [ordered]@{
        schema_version = 1
        observed_at_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        ok = $ok
        code = $code
        failures = @($failures)
        source_log_path = $logFull
        target = [ordered]@{
            pid = $targetPid
            repository_root = $repositoryRoot
            script = 'res://tests/manual/verify_gallery_empty_accessibility.gd'
            expected_window_title = $expectedTitle
            expected_empty = $expectedEmpty
            expected_return = $expectedReturn
            command_path = $commandFull
            completion_path = $completionFull
        }
        process = $processRecord
        window = $windowRecord
        identifiers = [ordered]@{
            live_region_changed_event_id = 20024
            live_setting_property_id = 30135
            polite = 1
            off = 0
        }
        phases = [ordered]@{
            baseline = [ordered]@{ projection = $baselineSnapshot; raw_events = @($baselineEvents) }
            open = [ordered]@{ projection = $openSnapshot; matching_events = @($openEvents) }
            refresh = [ordered]@{ projection = $refreshSnapshot; matching_events = @($refreshEvents) }
            reopen = [ordered]@{ projection = $reopenSnapshot; matching_events = @($reopenEvents) }
        }
        raw_events = if ($null -ne $collector) { @($collector.Snapshot()) } else { @() }
    }
    try {
        $json = Write-AtomicJson -Path $outputFull -Value $record
        [Console]::Out.WriteLine($json)
    } catch {
        [Console]::Error.WriteLine("EVIDENCE_WRITE_FAILED: $($_.Exception.Message)")
        $ok = $false
        $code = 'gallery_empty_evidence_write_failed'
    }
    if ($null -ne $completionFull) {
        try {
            [void](Write-AtomicJson -Path $completionFull -Value ([ordered]@{
                ok = $ok
                code = $code
            }))
        } catch {
            [Console]::Error.WriteLine("COMPLETION_WRITE_FAILED: $($_.Exception.Message)")
            $ok = $false
        }
    }
}

if ($ok) { exit 0 }
exit 1
