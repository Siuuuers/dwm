[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\', '/')
$identity = [guid]::NewGuid().ToString('N')
$output = Join-Path $repositoryRoot '.godot/ci/caption-native'
$isolated = Join-Path $repositoryRoot ".godot/phase2r_tests/caption-native-$identity"
$log = Join-Path $output 'godot.log'
$scriptArgument = 'res://tests/manual/verify_caption_native_accept.gd'
$utf8 = New-Object Text.UTF8Encoding($false)
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) {
    throw 'NATIVE_CAPTION_OUTPUT_NOT_FRESH'
}
New-Item -ItemType Directory -Force -Path $output, $isolated | Out-Null
if (-not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf)) { throw 'GODOT_MISSING' }

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
# Driver-only native transport. INPUT uses its largest union member, MOUSEINPUT.
# This driver is launched in a fresh Windows PowerShell process by the existing CI step.
Add-Type -AssemblyName WindowsBase
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DwmCaptionNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct Point { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool ClientToScreen(IntPtr window, ref Point point);
    public static int[] ClientBounds(IntPtr window) {
        Rect rect;
        Point origin = new Point();
        if (!GetClientRect(window, out rect) || !ClientToScreen(window, ref origin))
            throw new Win32Exception(Marshal.GetLastWin32Error());
        return new int[] { origin.X, origin.Y, rect.Right - rect.Left, rect.Bottom - rect.Top };
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct MouseInput {
        public int dx, dy;
        public uint mouseData, dwFlags, time;
        public UIntPtr dwExtraInfo;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct Input { public uint type; public MouseInput mouse; }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetPhysicalCursorPos(int x, int y);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetPhysicalCursorPos(out Point point);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPhysicalPoint(Point point);
    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr window, uint flags);
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr CommandLineToArgvW(string command, out int count);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr memory);
    public static Point Cursor() {
        Point result;
        if (!GetPhysicalCursorPos(out result)) throw new Win32Exception(Marshal.GetLastWin32Error());
        return result;
    }
    public static int[] PressedKeys() {
        var result = new List<int>();
        for (int key = 1; key < 255; key++) if (GetAsyncKeyState(key) < 0) result.Add(key);
        return result.ToArray();
    }
    public static string[] Arguments(string command) {
        int count;
        IntPtr memory = CommandLineToArgvW(command, out count);
        if (memory == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            var result = new string[count];
            for (int i = 0; i < count; i++)
                result[i] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(memory, i * IntPtr.Size));
            return result;
        } finally { LocalFree(memory); }
    }
    public static uint WheelDown(out int error) {
        var input = new Input[1];
        input[0].type = 0; // INPUT_MOUSE; positioning is a separately recorded operation.
        input[0].mouse.dwFlags = 0x0800; // MOUSEEVENTF_WHEEL
        input[0].mouse.mouseData = unchecked((uint)-120);
        uint inserted = SendInput(1, input, Marshal.SizeOf(typeof(Input)));
        error = inserted == 1 ? 0 : Marshal.GetLastWin32Error();
        return inserted;
    }
    public static int InputSize() { return Marshal.SizeOf(typeof(Input)); }
}
'@
$consolePath = [IO.Path]::GetFullPath($env:GODOT_CONSOLE_PATH)
if ($consolePath -notmatch '_console\.exe$') { throw 'CAPTION_PINNED_CONSOLE_NAME_REQUIRED' }
$enginePath = $consolePath -replace '_console\.exe$', '.exe'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) { throw 'CAPTION_ENGINE_MISSING' }
$boundProcess = $null
$providerSession = $null
$providerWindow = $null
$providerElements = $null
$providerClosed = $false
$providerRecord = [ordered]@{ status = 'not_started'; diagnostic_only = $true;
    run_token = $identity; run_id = $env:GITHUB_RUN_ID; run_attempt = $env:GITHUB_RUN_ATTEMPT;
    client_route = 'managed-discovery-then-native-COM-provenance'; identity_verified = $false;
    operations = @(); events = @(); cleanup_errors = @(); error = $null; closed = $false }

$wheelObservation = $null
$partialPrefix = 'The live fourth'
$observations = New-Object Collections.Generic.List[object]
$proseGeometryObservations = New-Object Collections.Generic.List[object]
$captions = @('Native caption activation fixture.', 'The successor keeps its own reveal.',
    'Third witnessed caption.', 'The live fourth caption stays partial.', 'Guard caption.')
# Independent expectations for each pre-invocation runtime state.
$steps = @(
    @{ stage = 'reveal'; event_index = 0; revealing = $true; finished = 0; review_offset = 0; target_index = 0 },
    @{ stage = 'advance'; event_index = 0; revealing = $false; finished = 1; review_offset = 0; target_index = 0 },
    @{ stage = 'second-reveal'; event_index = 1; revealing = $true; finished = 1; review_offset = 0; target_index = 1 },
    @{ stage = 'second-advance'; event_index = 1; revealing = $false; finished = 2; review_offset = 0; target_index = 1 },
    @{ stage = 'third-reveal'; event_index = 2; revealing = $true; finished = 2; review_offset = 0; target_index = 2 },
    @{ stage = 'third-advance'; event_index = 2; revealing = $false; finished = 3; review_offset = 0; target_index = 2 },
    @{ stage = 'review-enter'; event_index = 3; revealing = $true; finished = 3; review_offset = 0; target_index = 3 },
    @{ stage = 'review-return'; event_index = 3; revealing = $true; finished = 3; review_offset = 1; target_index = 2 },
    @{ stage = 'fresh-reveal'; event_index = 3; revealing = $true; finished = 3; review_offset = 0; target_index = 3 },
    @{ stage = 'fresh-advance'; event_index = 3; revealing = $false; finished = 4; review_offset = 0; target_index = 3 }
)

function Read-Stage([string]$Stage) {
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while ($deadline.Elapsed.TotalSeconds -lt 40) {
        if (Test-Path -LiteralPath $log) {
            $lines = @(Get-Content -LiteralPath $log -Encoding UTF8)
            if ($lines | Select-String -Pattern 'SCRIPT ERROR:|CAPTION_RESULT .*"ok":false') {
                throw "CAPTION_RUNTIME_FAILED: $Stage"
            }
            $allStages = @($lines | Where-Object { $_.StartsWith('CAPTION_READY ') } |
                ForEach-Object { $_.Substring(14) | ConvertFrom-Json })
            $records = @($allStages | Where-Object { $_.stage -ceq $Stage })
            if ($records.Count -gt 1) { throw "AMBIGUOUS_STAGE: $Stage" }
            if ($records.Count -eq 1) {
                if ($allStages[-1].stage -cne $Stage) { throw "CAPTION_STALE_STAGE: $Stage" }
                return $records[0]
            }
        }
        if ($child.HasExited) { throw "CAPTION_CHILD_EXITED: $Stage" }
        Start-Sleep -Milliseconds 100
    }
    throw "CAPTION_STAGE_TIMEOUT: $Stage"
}

function Save-CaptionProviderEvent([string]$Stage, [Diagnostics.Stopwatch]$Deadline) {
    $script:providerRecord.events += [ordered]@{ stage = $Stage;
        unix_msec = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();
        lookup_elapsed_msec = $Deadline.Elapsed.TotalMilliseconds }
    if ($null -ne $script:providerSession) {
        $script:providerRecord.operations = @($script:providerSession.Operations)
    }
    Write-CaptionJson 'native-provider.json' $script:providerRecord
}

function Assert-CaptionProviderBinding([Diagnostics.Process]$Native, [IntPtr]$Handle,
    [object]$ProcessIdentity, [long]$StartTicks, [Diagnostics.Stopwatch]$Deadline) {
    if ($Deadline.Elapsed.TotalSeconds -ge 10) { throw 'CAPTION_PROVIDER_LOOKUP_DEADLINE' }
    $child.Refresh()
    $Native.Refresh()
    [uint32]$windowPid = 0
    if ($child.HasExited -or $Native.HasExited -or
        $Native.StartTime.ToUniversalTime().Ticks -ne $StartTicks -or
        $Native.MainWindowHandle -ne $Handle -or
        [DwmCaptionNative]::GetWindowThreadProcessId($Handle, [ref]$windowPid) -eq 0 -or
        $windowPid -ne [uint32]$ProcessIdentity.pid) { throw 'CAPTION_PROVIDER_BINDING_CHANGED' }
    $current = Get-CimInstance Win32_Process -Filter "ProcessId = $($ProcessIdentity.pid)"
    if ($null -eq $current -or [int]$current.ParentProcessId -ne $ProcessIdentity.parent_pid -or
        [string]$current.ExecutablePath -ine $ProcessIdentity.executable -or
        [string]$current.CommandLine -cne $ProcessIdentity.command_line -or
        $current.CreationDate.ToUniversalTime().ToString('o') -cne $ProcessIdentity.created_utc) {
        throw 'CAPTION_PROVIDER_PROCESS_CHANGED'
    }
    if ($Deadline.Elapsed.TotalSeconds -ge 10) { throw 'CAPTION_PROVIDER_LOOKUP_DEADLINE' }
}

function Start-CaptionProvider([Diagnostics.Process]$Native, [IntPtr]$Handle,
    [object]$ProcessIdentity, [object]$Window, [object]$Elements, [Diagnostics.Stopwatch]$Deadline) {
    if ($script:providerRecord.status -cne 'not_started') { throw 'CAPTION_PROVIDER_REPEATED_START' }
    # Hold the original managed objects alongside the native client through cleanup.
    $script:providerWindow = $Window
    $script:providerElements = $Elements
    $startTicks = $Native.StartTime.ToUniversalTime().Ticks
    $script:providerRecord['process_identity'] = $ProcessIdentity
    $script:providerRecord['engine_start_ticks'] = $startTicks.ToString([Globalization.CultureInfo]::InvariantCulture)
    $script:providerRecord['hwnd'] = $Handle.ToInt64()
    $script:providerRecord['managed_descendants'] = $Elements.Count
    try {
        Assert-CaptionProviderBinding $Native $Handle $ProcessIdentity $startTicks $Deadline
        $script:providerRecord.status = 'loading_interop'
        Save-CaptionProviderEvent 'native_interop_start' $Deadline
        $interopPath = Join-Path $PSScriptRoot 'ContinueNativeProvider.cs'
        $script:providerRecord['interop_sha256'] = Get-ContinueFileSha256 -LiteralPath $interopPath
        $script:providerRecord['reader_sha256'] = Get-ContinueFileSha256 -LiteralPath $PSCommandPath
        $script:providerRecord['powershell'] = $PSVersionTable.PSVersion.ToString()
        $script:providerRecord['clr'] = [Environment]::Version.ToString()
        $script:providerRecord['process_bits'] = [IntPtr]::Size * 8
        $uiaCorePath = Join-Path $env:SystemRoot 'System32/UIAutomationCore.dll'
        $script:providerRecord['uia_core'] = [ordered]@{ path = $uiaCorePath;
            file_version = [Diagnostics.FileVersionInfo]::GetVersionInfo($uiaCorePath).FileVersion;
            sha256 = (Get-ContinueFileSha256 -LiteralPath $uiaCorePath) }
        Add-Type -Path $interopPath
        $script:providerSession = New-Object DwmNativeProvider.Session
        $script:providerRecord['assembly'] = $script:providerSession.GetType().Assembly.FullName
        $script:providerRecord['apartment'] = $script:providerSession.Apartment
        Save-CaptionProviderEvent 'native_interop_ready' $Deadline
        Assert-CaptionProviderBinding $Native $Handle $ProcessIdentity $startTicks $Deadline
        $script:providerRecord.status = 'activating_client'
        Save-CaptionProviderEvent 'native_activate_start' $Deadline
        $operation = $script:providerSession.Activate()
        Save-CaptionProviderEvent 'native_activate_return' $Deadline
        if ($operation.State -cne 'ok') { throw 'CAPTION_PROVIDER_ACTIVATION_FAILED' }
        Assert-CaptionProviderBinding $Native $Handle $ProcessIdentity $startTicks $Deadline
        $script:providerRecord.status = 'attaching'
        Save-CaptionProviderEvent 'native_attach_start' $Deadline
        $operation = $script:providerSession.Attach($Handle)
        Save-CaptionProviderEvent 'native_attach_return' $Deadline
        if ($operation.State -cne 'ok') { throw 'CAPTION_PROVIDER_ATTACHMENT_FAILED' }
        Assert-CaptionProviderBinding $Native $Handle $ProcessIdentity $startTicks $Deadline
        foreach ($propertyId in @(30002, 30020)) {
            $script:providerRecord.status = 'verifying_identity'
            Save-CaptionProviderEvent "native_property_${propertyId}_start" $Deadline
            $operation = $script:providerSession.Read($propertyId)
            Save-CaptionProviderEvent "native_property_${propertyId}_return" $Deadline
            Assert-CaptionProviderBinding $Native $Handle $ProcessIdentity $startTicks $Deadline
            if ($operation.State -cne 'value' -or $operation.Value -isnot [int]) {
                throw "CAPTION_PROVIDER_IDENTITY_UNAVAILABLE: $propertyId"
            }
            if ($propertyId -eq 30002 -and $operation.Value -ne [int]$ProcessIdentity.pid) {
                throw 'CAPTION_PROVIDER_PID_MISMATCH'
            }
            if ($propertyId -eq 30020) {
                $normalized = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$operation.Value), 0)
                $handle64 = $Handle.ToInt64()
                $upper = $handle64 -shr 32
                if (($upper -ne 0 -and $upper -ne -1) -or
                    [long]$normalized -ne ($handle64 -band 4294967295L)) { throw 'CAPTION_PROVIDER_HWND_MISMATCH' }
                $script:providerRecord['native_hwnd_uint32'] = [long]$normalized
            }
        }
        $script:providerRecord.identity_verified = $true
        $script:providerRecord.status = 'reading_provenance'
        Save-CaptionProviderEvent 'native_property_30107_start' $Deadline
        $operation = $script:providerSession.Read(30107)
        Save-CaptionProviderEvent 'native_property_30107_return' $Deadline
        Assert-CaptionProviderBinding $Native $Handle $ProcessIdentity $startTicks $Deadline
        if ($operation.State -notin @('value', 'empty', 'null', 'null_variant', 'unsupported')) {
            throw 'CAPTION_PROVIDER_PROVENANCE_FAILED'
        }
        # The raw description is diagnostic only, never a caption/Continue pass grammar.
        $script:providerRecord.status = 'observed'
        Save-CaptionProviderEvent 'native_provenance_complete' $Deadline
    } catch {
        $script:providerRecord.status = 'failed'
        $script:providerRecord.error = $_.Exception.Message
        Save-CaptionProviderEvent 'native_failure' $Deadline
        throw
    }
}

function Close-CaptionProvider {
    if ($script:providerClosed) { return }
    $script:providerClosed = $true
    if ($null -ne $script:providerSession) {
        try { $script:providerSession.Dispose() }
        catch { $script:providerRecord.cleanup_errors += $_.Exception.Message }
        $script:providerRecord.operations = @($script:providerSession.Operations)
        $script:providerRecord.cleanup_errors += @($script:providerSession.CleanupErrors)
    }
    [GC]::KeepAlive($script:providerElements)
    [GC]::KeepAlive($script:providerWindow)
    $script:providerRecord.closed = $true
    Write-CaptionJson 'native-provider.json' $script:providerRecord
}

function Resolve-Caption([object]$Ready, [object]$Expected) {
    $targetPid = [int]$Ready.pid
    $title = "DWM Native Caption Accept $targetPid"
    $isReview = $Expected.review_offset -eq 1
    if ($Ready.window_title -cne $title -or $targetPid -le 0 -or $Ready.physical_contacts -ne 0 -or
        $Ready.run_token -cne $identity -or $Ready.anything_pressed -or $Ready.tree_paused -or $Ready.runtime_paused -or
        -not $Ready.input_delay_stopped -or -not $Ready.source_admitted -or -not $Ready.window_focused -or
        -not $Ready.continue_available -or -not $Ready.continue_source_visible -or
        $Ready.continue_label -cne 'Continue' -or @($Ready.continue_rect).Count -ne 4 -or
        @($Ready.target_rect).Count -ne 4 -or
        $Ready.stage -cne $Expected.stage -or $Ready.ended -ne 0 -or
        $Ready.text -cne $captions[$Expected.event_index] -or $Ready.event_index -ne $Expected.event_index -or
        $Ready.target_text -cne $captions[$Expected.target_index] -or $Ready.review_offset -ne $Expected.review_offset -or
        $Ready.revealing -ne $Expected.revealing -or $Ready.finished -ne $Expected.finished -or
        $Ready.live_visible -eq $isReview -or $Ready.review_visible -ne $isReview -or
        ($isReview -and -not $Ready.review_focused) -or
        (-not $isReview -and -not $Ready.live_focused) -or
        ($Ready.revealing -and ($Ready.visible_characters -lt 0 -or $Ready.visible_characters -ge $Ready.total_characters))) {
        throw "CAPTION_READY_CONTRACT_INVALID: $($Expected.stage)"
    }
    Assert-Capture $Ready.capture $Ready.stage
    Assert-SameLiveState $Ready.capture.state $Ready
    if ($Ready.stage -in @('review-enter', 'review-return', 'fresh-reveal')) {
        $partial = $Ready.partial_setup
        if ($Ready.visible_characters -ne $partialPrefix.Length -or
            $partial.method -cne 'fixture_visible_characters_assignment' -or
            $partial.expected_prefix -cne $partialPrefix -or $partial.visible_characters -ne $partialPrefix.Length -or
            $partial.changed_caption_pixels -le 20 -or -not $partial.outside_caption_unchanged -or
            -not $partial.caption_fully_visible -or $partial.naturally_elapsed) { throw 'CAPTION_PARTIAL_SETUP_INVALID' }
    }
    # The pinned console wrapper starts the real engine as a child; it is not the window PID.
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $targetPid"
    if ($child.HasExited -or $null -eq $process -or $process.ParentProcessId -ne $child.Id -or
        [string]$process.ExecutablePath -ine $enginePath) { throw 'CAPTION_PROCESS_MISMATCH' }
    $arguments = [DwmCaptionNative]::Arguments([string]$process.CommandLine)
    $expectedArguments = [DwmCaptionNative]::Arguments('"' + $enginePath + '" ' + $start.Arguments)
    if ($arguments.Count -ne $expectedArguments.Count) { throw 'CAPTION_PROCESS_ARGUMENTS' }
    for ($i = 0; $i -lt $arguments.Count; $i++) {
        if ($arguments[$i] -cne $expectedArguments[$i]) { throw "CAPTION_PROCESS_ARGUMENT: $i" }
    }
    $processIdentity = [ordered]@{ pid = $targetPid; parent_pid = [int]$process.ParentProcessId;
        executable = [string]$process.ExecutablePath; command_line = [string]$process.CommandLine;
        created_utc = $process.CreationDate.ToUniversalTime().ToString('o'); launcher_pid = $child.Id }
    if ($null -eq $script:boundProcess) { $script:boundProcess = $processIdentity }
    elseif ((ConvertTo-Json $processIdentity -Compress) -cne (ConvertTo-Json $boundProcess -Compress)) {
        throw 'CAPTION_CHILD_IDENTITY_CHANGED'
    }
    $native = [Diagnostics.Process]::GetProcessById($targetPid)
    $window = $null
    $target = $null
    $continueTarget = $null
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    try {
    while ($deadline.Elapsed.TotalSeconds -lt 10) {
        $native.Refresh()
        if ($native.MainWindowHandle -ne [IntPtr]::Zero -and $native.MainWindowTitle -ceq $title) {
            $window = [Windows.Automation.AutomationElement]::FromHandle($native.MainWindowHandle)
            if ($window.Current.ProcessId -ne $targetPid) { throw 'CAPTION_WINDOW_PROCESS_MISMATCH' }
            $elements = $window.FindAll([Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            if ($script:providerRecord.status -ceq 'not_started') {
                Start-CaptionProvider $native $native.MainWindowHandle $processIdentity $window $elements $deadline
            } elseif ($script:providerRecord.status -cne 'observed' -or
                $script:providerRecord.hwnd -ne $native.MainWindowHandle.ToInt64() -or
                $script:providerRecord.engine_start_ticks -cne
                    $native.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)) {
                throw 'CAPTION_PROVIDER_BOUND_WINDOW_CHANGED'
            }
            $snapshot = @($elements | ForEach-Object {
                [ordered]@{ name = $_.Current.Name; type = $_.Current.ControlType.ProgrammaticName;
                    enabled = $_.Current.IsEnabled; offscreen = $_.Current.IsOffscreen;
                    focused = $_.Current.HasKeyboardFocus; pid = $_.Current.ProcessId;
                    automation_id = $_.Current.AutomationId; runtime_id = @($_.GetRuntimeId());
                    physical_rectangle = @($_.Current.BoundingRectangle.X, $_.Current.BoundingRectangle.Y,
                        $_.Current.BoundingRectangle.Width, $_.Current.BoundingRectangle.Height);
                    patterns = @($_.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName }) }
            })
            [IO.File]::WriteAllText((Join-Path $output ($Ready.stage + '-tree.json')),
                (ConvertTo-Json -InputObject $snapshot -Depth 8), $utf8)
            # Read prose from its actual focused Text node. Invocation belongs only
            # to the separately projected, geometry-bound background Continue.
            $matches = @($elements | Where-Object {
                $_.Current.Name.TrimEnd() -ceq $Ready.target_text -and -not $_.Current.IsOffscreen -and
                    $_.Current.HasKeyboardFocus
            })
            if ($matches.Count -gt 1) { throw 'CAPTION_UIA_AMBIGUOUS' }
            if ($matches.Count -eq 1) {
                $prose = $matches[0]
                $prosePattern = $null
                if ($prose.Current.ProcessId -ne $targetPid -or -not $prose.Current.IsEnabled -or
                    $prose.Current.ControlType -ne [Windows.Automation.ControlType]::Text -or
                    $prose.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$prosePattern)) {
                    throw 'CAPTION_PROSE_ROLE_OR_ACTION_INVALID'
                }
                Assert-InWindow $prose $window $targetPid
                $proseOwner = Resolve-ProseOwner $prose $window $targetPid $Ready.target_rect $native.MainWindowHandle $Ready.stage 'resolve'
                $continueMatches = @($elements | Where-Object {
                    $_.Current.Name.TrimEnd() -ceq $Ready.continue_label -and -not $_.Current.IsOffscreen
                })
                $storyActions = @()
                foreach ($candidate in $continueMatches) {
                    # Pause's Continue is a different, small rectangle and cannot qualify.
                    if (-not $candidate.Current.BoundingRectangle.Contains($prose.Current.BoundingRectangle)) { continue }
                    if ($candidate.Current.ProcessId -ne $targetPid) { throw 'CONTINUE_FOREIGN_PROCESS' }
                    Assert-InWindow $candidate $window $targetPid
                    $candidatePattern = $null
                    if ($candidate.Current.ControlType -ne [Windows.Automation.ControlType]::Button -or
                        -not $candidate.Current.IsEnabled -or
                        -not $candidate.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$candidatePattern)) {
                        throw 'CONTINUE_ACTION_INVALID'
                    }
                    Assert-FixtureRectangle $candidate $Ready.continue_rect $native.MainWindowHandle
                    if ([Windows.Automation.Automation]::Compare($prose, $candidate)) { throw 'CONTINUE_IS_PROSE' }
                    $storyActions += $candidate
                }
                if ($storyActions.Count -gt 1) { throw 'CONTINUE_UIA_AMBIGUOUS' }
                if ($storyActions.Count -eq 1) {
                    $target = $prose
                    $continueTarget = $storyActions[0]
                    break
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($null -eq $target -or $null -eq $continueTarget -or $deadline.Elapsed.TotalSeconds -ge 10) {
        throw "CAPTION_TEXT_OR_CONTINUE_NOT_FOUND_IN_DEADLINE: $($Ready.stage)"
    }
    $pattern = $null
    if (-not $continueTarget.Current.IsEnabled -or
        -not $continueTarget.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw 'CONTINUE_INVOKE_PATTERN_MISSING'
    }
    $runtimeId = @($target.GetRuntimeId())
    if ($isReview -and $observations.Count -gt 0 -and
        ($runtimeId -join ',') -ceq ($observations[$observations.Count - 1].runtime_id -join ',')) {
        throw 'CAPTION_REVIEW_REUSED_LIVE_TARGET'
    }
    $rectangle = $target.Current.BoundingRectangle
    if ($rectangle.IsEmpty -or $rectangle.Width -le 2 -or $rectangle.Height -le 2 -or
        -not $window.Current.BoundingRectangle.Contains($rectangle)) { throw 'CAPTION_NATIVE_RECTANGLE' }
    foreach ($value in @($rectangle.X, $rectangle.Y, $rectangle.Width, $rectangle.Height)) {
        if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { throw 'CAPTION_NATIVE_NONFINITE_RECTANGLE' }
    }
    $binding = [pscustomobject]@{ target = $target; pattern = $pattern; window = $window;
        continue_target = $continueTarget; continue_runtime_id = @($continueTarget.GetRuntimeId());
        continue_rectangle = $continueTarget.Current.BoundingRectangle;
        window_handle = $native.MainWindowHandle.ToInt64(); pid = $targetPid;
        runtime_id = $runtimeId; rectangle = $rectangle; ready = $Ready; process_identity = $processIdentity;
        prose_owner = $proseOwner.owner; prose_owner_runtime_id = $proseOwner.runtime_id;
        prose_ancestry_ids = $proseOwner.ancestry_ids;
        physical_rectangle = @($rectangle.X, $rectangle.Y, $rectangle.Width, $rectangle.Height) }
    return $binding
    } finally { $native.Dispose() }
}

function Assert-InWindow($Element, $Window, [int]$ElementProcessId) {
    if ($Element.Current.ProcessId -ne $ElementProcessId) { throw 'CAPTION_ELEMENT_FOREIGN_PROCESS' }
    $node = $Element
    for ($depth = 0; $null -ne $node -and $depth -lt 64; $depth++) {
        if ([Windows.Automation.Automation]::Compare($node, $Window)) { return }
        $node = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($node)
    }
    throw 'CAPTION_ELEMENT_OUTSIDE_BOUND_WINDOW'
}

function Assert-FixtureRectangle($Element, $Logical, [IntPtr]$Handle) {
    $client = [DwmCaptionNative]::ClientBounds($Handle)
    if ($client[2] -le 0 -or $client[3] -le 0) { throw 'CAPTION_CLIENT_RECTANGLE_INVALID' }
    if (@($Logical).Count -ne 4) { throw 'CAPTION_FIXTURE_LOGICAL_RECTANGLE_INVALID' }
    foreach ($value in @($Logical)) {
        if ([double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value)) {
            throw 'CAPTION_FIXTURE_LOGICAL_RECTANGLE_NONFINITE'
        }
    }
    if ([double]$Logical[2] -le 0 -or [double]$Logical[3] -le 0) { throw 'CAPTION_FIXTURE_LOGICAL_RECTANGLE_EMPTY' }
    $actual = $Element.Current.BoundingRectangle
    $expected = @(($client[0] + [double]$Logical[0] * $client[2] / 1280.0),
        ($client[1] + [double]$Logical[1] * $client[3] / 720.0),
        ([double]$Logical[2] * $client[2] / 1280.0), ([double]$Logical[3] * $client[3] / 720.0))
    $values = @($actual.X, $actual.Y, $actual.Width, $actual.Height)
    for ($i = 0; $i -lt 4; $i++) {
        if ([double]::IsNaN($values[$i]) -or [double]::IsInfinity($values[$i]) -or
            [Math]::Abs($values[$i] - $expected[$i]) -gt 1.0) { throw 'CAPTION_FIXTURE_GEOMETRY_MISMATCH' }
    }
    if ($actual.IsEmpty -or $actual.Width -le 2 -or $actual.Height -le 2) { throw 'CAPTION_FIXTURE_EMPTY_GEOMETRY' }
}

function Write-CaptionJson([string]$Name, [object]$Value) {
    [IO.File]::WriteAllText((Join-Path $output $Name), (ConvertTo-Json -InputObject $Value -Depth 40), $utf8)
}

function Resolve-ProseOwner($Prose, $Window, [int]$ElementProcessId, $Logical,
        [IntPtr]$Handle, [string]$Stage, [string]$Phase) {
    # RichTextLabel publishes focused glyph text below its full-control Text node.
    # A flat geometry match is insufficient: retain the actual raw-parent chain.
    $chain = New-Object Collections.Generic.List[object]
    $owners = New-Object Collections.Generic.List[object]
    $receipt = [ordered]@{ stage = $Stage; phase = $Phase; pid = $ElementProcessId;
        hwnd = $Handle.ToInt64(); reached_window = $false; owner_count = 0;
        chain = @(); owner_runtime_id = @(); ok = $false }
    $proseGeometryObservations.Add($receipt)
    try {
        $rectangle = $Prose.Current.BoundingRectangle
        foreach ($value in @($rectangle.X, $rectangle.Y, $rectangle.Width, $rectangle.Height)) {
            if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { throw 'CAPTION_PROSE_NONFINITE_GEOMETRY' }
        }
        if ($rectangle.IsEmpty -or $rectangle.Width -le 2 -or $rectangle.Height -le 2) { throw 'CAPTION_PROSE_EMPTY_GEOMETRY' }
        $node = $Prose
        for ($depth = 0; $null -ne $node -and $depth -lt 64; $depth++) {
            if ($node.Current.ProcessId -ne $ElementProcessId) { throw 'CAPTION_PROSE_ANCESTOR_FOREIGN_PROCESS' }
            $bounds = $node.Current.BoundingRectangle
            $chain.Add([ordered]@{ depth = $depth; runtime_id = @($node.GetRuntimeId());
                name = $node.Current.Name; type = $node.Current.ControlType.ProgrammaticName;
                pid = $node.Current.ProcessId; rectangle = @($bounds.X, $bounds.Y, $bounds.Width, $bounds.Height) })
            if ([Windows.Automation.Automation]::Compare($node, $Window)) {
                $receipt.reached_window = $true
                break
            }
            if ($depth -gt 0 -and $node.Current.ControlType -eq [Windows.Automation.ControlType]::Text) {
                $matches = $true
                try { Assert-FixtureRectangle $node $Logical $Handle }
                catch {
                    if ($_.Exception.Message -cne 'CAPTION_FIXTURE_GEOMETRY_MISMATCH') { throw }
                    $matches = $false
                }
                if ($matches) { $owners.Add($node) }
            }
            $node = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($node)
        }
        $receipt.owner_count = $owners.Count
        if (-not $receipt.reached_window) { throw 'CAPTION_PROSE_ANCESTRY_OUTSIDE_BOUND_WINDOW' }
        if ($owners.Count -ne 1) { throw "CAPTION_PROSE_OWNER_NOT_UNIQUE: $($owners.Count)" }
        $owner = $owners[0]
        if (-not $owner.Current.IsEnabled -or $owner.Current.IsOffscreen -or
            -not $owner.Current.BoundingRectangle.Contains($rectangle)) { throw 'CAPTION_PROSE_OUTSIDE_FIXTURE_OWNER' }
        $receipt.owner_runtime_id = @($owner.GetRuntimeId())
        $receipt.ok = $true
        return [pscustomobject]@{ owner = $owner; runtime_id = $receipt.owner_runtime_id;
            ancestry_ids = @($chain | ForEach-Object { $_.runtime_id -join ',' }) }
    } finally {
        $receipt.chain = @($chain.ToArray())
        $receipt.owner_count = $owners.Count
        Write-CaptionJson 'prose-geometry.json' @($proseGeometryObservations.ToArray())
    }
}

function Assert-SameLiveState([object]$Before, [object]$After) {
    foreach ($key in @('run_token', 'text', 'visible_characters', 'total_characters', 'revealing',
        'reveal_generation', 'event_index', 'finished', 'ended', 'retained_captions', 'simple_history', 'full_history')) {
        if ((ConvertTo-Json -InputObject $Before.$key -Depth 25 -Compress) -cne
            (ConvertTo-Json -InputObject $After.$key -Depth 25 -Compress)) {
            throw "CAPTION_LIVE_STATE_CHANGED: $key"
        }
    }
}

function Assert-Capture([object]$Capture, [string]$Stage) {
    if ($Capture.file -cne ($Stage + '.png') -or $Capture.width -ne 1280 -or $Capture.height -ne 720 -or
        $Capture.sha256 -cnotmatch '^[a-f0-9]{64}$') { throw "CAPTION_CAPTURE_IDENTITY: $Stage" }
    $path = Join-Path $output $Capture.file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-ContinueFileSha256 -LiteralPath $path) -cne $Capture.sha256) {
        throw "CAPTION_CAPTURE_HASH: $Stage"
    }
}

function Assert-NativeBoundary([object]$Binding) {
    $handle = [IntPtr]$Binding.window_handle
    $windowPid = [uint32]0
    [void][DwmCaptionNative]::GetWindowThreadProcessId($handle, [ref]$windowPid)
    $keys = @([DwmCaptionNative]::PressedKeys())
    if ($child.HasExited -or $windowPid -ne $Binding.pid -or
        [DwmCaptionNative]::GetForegroundWindow() -ne $handle -or $keys.Count -ne 0 -or
        -not $Binding.target.Current.IsEnabled -or $Binding.target.Current.IsOffscreen -or
        $Binding.target.Current.ProcessId -ne $Binding.pid -or
        ($Binding.target.GetRuntimeId() -join ',') -cne ($Binding.runtime_id -join ',') -or
        $Binding.target.Current.Name.TrimEnd() -cne $Binding.ready.target_text -or
        -not $Binding.target.Current.HasKeyboardFocus -or
        $Binding.target.Current.ControlType -ne [Windows.Automation.ControlType]::Text) {
        throw "CAPTION_NATIVE_CUSTODY: $($Binding.ready.stage); held_keys=$($keys -join ',')"
    }
    Assert-InWindow $Binding.target $Binding.window $Binding.pid
    Assert-InWindow $Binding.continue_target $Binding.window $Binding.pid
    $prosePattern = $null
    $continuePattern = $null
    if ($Binding.target.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$prosePattern) -or
        -not $Binding.continue_target.Current.IsEnabled -or $Binding.continue_target.Current.IsOffscreen -or
        $Binding.continue_target.Current.ControlType -ne [Windows.Automation.ControlType]::Button -or
        $Binding.continue_target.Current.Name.TrimEnd() -cne $Binding.ready.continue_label -or
        ($Binding.continue_target.GetRuntimeId() -join ',') -cne ($Binding.continue_runtime_id -join ',') -or
        -not $Binding.continue_target.Current.BoundingRectangle.Equals($Binding.continue_rectangle) -or
        -not $Binding.continue_target.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$continuePattern)) {
        throw 'CAPTION_TEXT_CONTINUE_BINDING_CHANGED'
    }
    $proseOwner = Resolve-ProseOwner $Binding.target $Binding.window $Binding.pid $Binding.ready.target_rect $handle $Binding.ready.stage 'boundary'
    if (-not [Windows.Automation.Automation]::Compare($proseOwner.owner, $Binding.prose_owner) -or
        ($proseOwner.runtime_id -join ',') -cne ($Binding.prose_owner_runtime_id -join ',') -or
        ($proseOwner.ancestry_ids -join ';') -cne ($Binding.prose_ancestry_ids -join ';')) {
        throw 'CAPTION_PROSE_OWNER_OR_ANCESTRY_CHANGED'
    }
    Assert-FixtureRectangle $Binding.continue_target $Binding.ready.continue_rect $handle
}

function Assert-PhysicalTarget([object]$Binding, [object]$Point) {
    Assert-NativeBoundary $Binding
    $rectangle = $Binding.target.Current.BoundingRectangle
    $pointValue = [Windows.Point]::new([double]$Point.X, [double]$Point.Y)
    if (-not $rectangle.Equals($Binding.rectangle) -or -not $rectangle.Contains($pointValue) -or
        [DwmCaptionNative]::GetAncestor([DwmCaptionNative]::WindowFromPhysicalPoint($Point), 2) -ne
            [IntPtr]$Binding.window_handle) { throw 'CAPTION_PHYSICAL_TARGET_CHANGED' }
    $hit = [Windows.Automation.AutomationElement]::FromPoint($pointValue)
    $node = $hit
    $matched = $false
    for ($depth = 0; $null -ne $node -and $depth -lt 32; $depth++) {
        if ($node.Current.ProcessId -ne $Binding.pid) { break }
        if (($node.GetRuntimeId() -join ',') -ceq ($Binding.runtime_id -join ',')) { $matched = $true; break }
        $node = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($node)
    }
    if (-not $matched) { throw 'CAPTION_PHYSICAL_HIT_NOT_LIVE_TARGET' }
    return [ordered]@{ name = $hit.Current.Name; runtime_id = @($hit.GetRuntimeId());
        type = $hit.Current.ControlType.ProgrammaticName; pid = $hit.Current.ProcessId }
}

function Invoke-Caption([object]$Ready, [object]$Expected) {
    $binding = Resolve-Caption $Ready $Expected
    Assert-NativeBoundary $binding
    [void](Read-Stage $Ready.stage) # Refuse a stage that advanced during discovery.
    $observation = [ordered]@{ stage = $Ready.stage; pid = $binding.pid;
        window_handle = $binding.window_handle; window = $binding.window.Current.Name;
        name = $binding.target.Current.Name; type = $binding.target.Current.ControlType.ProgrammaticName;
        runtime_id = $binding.runtime_id; process = $binding.process_identity;
        prose_has_keyboard_focus = $binding.target.Current.HasKeyboardFocus; prose_has_invoke = $false;
        continue_name = $binding.continue_target.Current.Name;
        continue_type = $binding.continue_target.Current.ControlType.ProgrammaticName;
        continue_runtime_id = $binding.continue_runtime_id;
        continue_physical_rectangle = @($binding.continue_rectangle.X, $binding.continue_rectangle.Y,
            $binding.continue_rectangle.Width, $binding.continue_rectangle.Height);
        physical_rectangle = $binding.physical_rectangle; foreground = $binding.window_handle;
        method = 'Windows.UIAutomation.InvokePattern.Invoke'; attempted_calls = 1; returned = $false;
        invocations = 0; ready = $Ready }
    $observations.Add($observation)
    Write-CaptionJson 'invocations.json' @($observations.ToArray())
    # No SetFocus, callback substitution or automatic invocation retry.
    try {
        ([Windows.Automation.InvokePattern]$binding.pattern).Invoke()
        $observation.returned = $true
        $observation.invocations = 1
    } finally { Write-CaptionJson 'invocations.json' @($observations.ToArray()) }
}

function Invoke-ReviewWheel([object]$Ready, [object]$Expected) {
    $binding = Resolve-Caption $Ready $Expected
    Assert-NativeBoundary $binding
    $rectangle = $binding.rectangle
    $destination = New-Object DwmCaptionNative+Point
    $destination.X = [int][Math]::Floor($rectangle.X + $rectangle.Width / 2)
    $destination.Y = [int][Math]::Floor($rectangle.Y + $rectangle.Height / 2)
    $cursorBefore = [DwmCaptionNative]::Cursor()
    $script:wheelObservation = [ordered]@{ stage = $Ready.stage; run_token = $identity; pid = $binding.pid;
        process = $binding.process_identity; window_handle = $binding.window_handle;
        live_runtime_id = $binding.runtime_id; physical_rectangle = $binding.physical_rectangle;
        before = $Ready; after = $null; observed_transition = $false;
        cursor = [ordered]@{ method = 'SetPhysicalCursorPos'; attempted_calls = 1;
            before = $cursorBefore; requested = $destination; succeeded = $false; after = $null };
        wheel = [ordered]@{ method = 'SendInput/MOUSEEVENTF_WHEEL'; delta = -120;
            attempted_calls = 0; requested_packets = 1; inserted_packets = $null; last_error = $null;
            input_size = [DwmCaptionNative]::InputSize() } }
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    $wheelObservation.cursor.succeeded = [DwmCaptionNative]::SetPhysicalCursorPos($destination.X, $destination.Y)
    $wheelObservation.cursor['last_error'] = if ($wheelObservation.cursor.succeeded) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
    $wheelObservation.cursor.after = [DwmCaptionNative]::Cursor()
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    if (-not $wheelObservation.cursor.succeeded -or $wheelObservation.cursor.after.X -ne $destination.X -or
        $wheelObservation.cursor.after.Y -ne $destination.Y) { throw 'CAPTION_CURSOR_POSITION_FAILED' }
    Start-Sleep -Milliseconds 150 # Settle positioning; this is not a caption action or retry.
    $actualPoint = [DwmCaptionNative]::Cursor()
    if ($actualPoint.X -ne $destination.X -or $actualPoint.Y -ne $destination.Y) { throw 'CAPTION_CURSOR_MOVED' }
    $wheelObservation['hit'] = Assert-PhysicalTarget $binding $actualPoint
    [void](Read-Stage $Ready.stage)
    $wheelObservation.wheel.attempted_calls = 1
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    $errorCode = 0
    $wheelObservation.wheel.inserted_packets = [DwmCaptionNative]::WheelDown([ref]$errorCode)
    $wheelObservation.wheel.last_error = $errorCode
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    if ($wheelObservation.wheel.inserted_packets -ne 1) { throw "CAPTION_WHEEL_INSERTION_FAILED: $errorCode" }
    # Insertion is not acceptance. The fixture must observe the actual review transition.
    $after = Read-Stage 'review-return'
    $wheelObservation.after = $after
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
    Assert-SameLiveState $Ready $after
    if ($Ready.review_offset -ne 0 -or $after.review_offset -ne 1 -or $after.pid -ne $Ready.pid -or
        $after.run_token -cne $identity -or $after.target_text -cne $captions[2] -or
        -not $after.review_focused -or -not $after.review_visible -or $after.live_visible -or
        $after.physical_contacts -ne 0 -or $after.anything_pressed -or -not $after.source_admitted) {
        throw 'CAPTION_WHEEL_REVIEW_TRANSITION_FAILED'
    }
    $wheelObservation.observed_transition = $true
    Write-CaptionJson 'wheel-entry.json' $wheelObservation
}

$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $consolePath
$start.Arguments = '--path "' + $repositoryRoot + '" --rendering-method gl_compatibility --audio-driver Dummy --accessibility always --log-file "' + $log + '" --script ' + $scriptArgument
$start.UseShellExecute = $false
$start.EnvironmentVariables['APPDATA'] = Join-Path $isolated 'appdata'
$start.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $isolated 'localappdata'
$start.EnvironmentVariables['DWM_TEST_ROOT'] = $isolated
$start.EnvironmentVariables['DWM_CAPTION_EVIDENCE_ROOT'] = $output
$start.EnvironmentVariables['DWM_CAPTION_RUN_TOKEN'] = $identity
New-Item -ItemType Directory -Force -Path $start.EnvironmentVariables['APPDATA'], $start.EnvironmentVariables['LOCALAPPDATA'] | Out-Null
$child = New-Object Diagnostics.Process
$child.StartInfo = $start
$started = $false
$previousDpi = [IntPtr]::Zero
$activeStage = 'launch'
try {
    $previousDpi = [DwmCaptionNative]::SetThreadDpiAwarenessContext([IntPtr](-4))
    if ($previousDpi -eq [IntPtr]::Zero -or [DwmCaptionNative]::InputSize() -ne 40 -or [IntPtr]::Size -ne 8) {
        throw 'CAPTION_NATIVE_DRIVER_ABI_OR_DPI'
    }
    $started = $child.Start()
    if (-not $started) { throw 'CAPTION_START_FAILED' }
    foreach ($step in $steps) {
        $activeStage = $step.stage
        $ready = Read-Stage $step.stage
        if ($step.stage -ceq 'review-enter') { Invoke-ReviewWheel $ready $step }
        else { Invoke-Caption $ready $step }
    }
    $activeStage = 'verify-result'
    if (-not $child.WaitForExit(15000)) { throw 'CAPTION_EXIT_TIMEOUT' }
    if ($child.ExitCode -ne 0) { throw "CAPTION_EXIT_CODE: $($child.ExitCode)" }
    $result = Get-Content -Raw -LiteralPath (Join-Path $output 'runtime.json') -Encoding UTF8 | ConvertFrom-Json
    if (-not $result.ok -or $observations.Count -ne 9 -or $result.event_index -ne 4 -or
        $result.text -cne $captions[4] -or -not $result.revealing -or $result.finished -ne 4 -or
        $result.ended -ne 0 -or $result.physical_contacts -ne 0 -or $result.review_offset -ne 0) {
        throw 'CAPTION_NATIVE_RESULT_INVALID'
    }
    if ($result.run_token -cne $identity -or $null -eq $wheelObservation -or
        -not $wheelObservation.observed_transition -or $wheelObservation.wheel.attempted_calls -ne 1 -or
        $wheelObservation.wheel.inserted_packets -ne 1 -or $result.anything_pressed -or
        @($observations | Where-Object { -not $_.returned -or $_.invocations -ne 1 }).Count -ne 0) {
        throw 'CAPTION_NATIVE_ACTION_RECORDS'
    }
    $entry = $result.review_entry
    Assert-SameLiveState $entry.before $entry.after
    Assert-SameLiveState $wheelObservation.before $entry.before
    Assert-SameLiveState $wheelObservation.after $entry.after
    if (-not $entry.invariants_unchanged -or ($entry.observed_offsets -join ',') -cne '0,1' -or
        $entry.before.review_offset -ne 0 -or $entry.after.review_offset -ne 1) { throw 'CAPTION_ENTRY_RESULT' }
    $review = $result.review_return
    $before = $review.before
    $returned = $review.returned
    Assert-SameLiveState $before $returned
    Assert-SameLiveState $entry.before $before
    if ($before.visible_characters -ne $partialPrefix.Length -or
        $returned.scroll_offset -ne $before.scroll_offset -or -not $review.partial_pixels_equal) {
        throw 'CAPTION_NONZERO_RETURN_RESULT'
    }
    foreach ($capture in $result.captures.PSObject.Properties) { Assert-Capture $capture.Value $capture.Name }
    if (-not $review.invariants_unchanged -or -not $review.native_history_unchanged -or
        $before.event_index -ne 3 -or $before.finished -ne 3 -or -not $before.revealing -or
        $review.reviewing.review_offset -ne 1 -or $review.reviewing.target_text -cne $captions[2] -or
        $returned.review_offset -ne 0 -or -not $returned.live_visible -or $returned.review_visible -or
        -not $returned.live_focused -or -not $returned.revealing -or $returned.physical_contacts -ne 0 -or
        $returned.event_index -ne $before.event_index -or $returned.finished -ne $before.finished -or
        $returned.ended -ne $before.ended -or $returned.text -cne $before.text -or
        $returned.visible_characters -ne $before.visible_characters -or
        $returned.reveal_generation -ne $before.reveal_generation -or
        (ConvertTo-Json -InputObject $returned.simple_history -Depth 20 -Compress) -cne
            (ConvertTo-Json -InputObject $before.simple_history -Depth 20 -Compress) -or
        (ConvertTo-Json -InputObject $returned.full_history -Depth 20 -Compress) -cne
            (ConvertTo-Json -InputObject $before.full_history -Depth 20 -Compress)) {
        throw 'CAPTION_NATIVE_REVIEW_RETURN_INVALID'
    }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load' -Quiet) {
        throw 'CAPTION_NATIVE_SCRIPT_ERROR'
    }
    $source = (& git -C $repositoryRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'CAPTION_SOURCE_UNKNOWN' }
    if ($script:providerRecord.status -cne 'observed' -or -not $script:providerRecord.identity_verified) {
        throw 'CAPTION_PROVIDER_NOT_OBSERVED'
    }
    # Keep both routes alive until the game exits; cleanup must pass before success.
    Close-CaptionProvider
    if (@($script:providerRecord.cleanup_errors).Count -ne 0) { throw 'CAPTION_PROVIDER_CLEANUP_FAILED' }
    $receipt = [ordered]@{ ok = $true; checkout = $source; run_id = $env:GITHUB_RUN_ID;
        run_attempt = $env:GITHUB_RUN_ATTEMPT; native_invocations = 9; runtime = $result;
        review_return_verified = $true; native_wheel_entry_verified = $true; run_token = $identity;
        wheel_entry = $wheelObservation; process_identity = $boundProcess; native_provider = $script:providerRecord;
        console_sha256 = (Get-ContinueFileSha256 -LiteralPath $consolePath);
        engine_sha256 = (Get-ContinueFileSha256 -LiteralPath $enginePath);
        scope = 'Mounted fixture; focused prose Text without InvokePattern, separate fixture-geometry-bound Continue, native wheel entry plus UIA return. Nonzero count is seeded with elapsed reveal disabled. No speech, ScrollPattern, production consequences or timed-lifecycle claim. PNGs are Godot viewport captures.' }
    [IO.File]::WriteAllText((Join-Path $output 'receipt.json'), (ConvertTo-Json $receipt -Depth 25), $utf8)
    Write-Output 'CAPTION_NATIVE_ACCEPT_VERIFIED'
} catch {
    Write-CaptionJson 'driver-failure.json' ([ordered]@{ ok = $false; stage = $activeStage; run_token = $identity;
        error = $_.Exception.Message; position = $_.InvocationInfo.PositionMessage;
        process_identity = $boundProcess; wheel_entry = $wheelObservation;
        invocations = @($observations.ToArray()); run_id = $env:GITHUB_RUN_ID; run_attempt = $env:GITHUB_RUN_ATTEMPT })
    throw
} finally {
    try {
        try {
            if ($started -and -not $child.HasExited) { & taskkill.exe /PID $child.Id /T /F | Out-Null }
        } finally { $child.Dispose() }
    } finally {
        try { Close-CaptionProvider } finally {
            try {
                if ($previousDpi -ne [IntPtr]::Zero) { [void][DwmCaptionNative]::SetThreadDpiAwarenessContext($previousDpi) }
            } finally {
                $files = @(Get-ChildItem -LiteralPath $output -File | Where-Object { $_.Name -cne 'files.sha256.json' } |
                    Sort-Object Name | ForEach-Object { [ordered]@{ file = $_.Name; bytes = $_.Length;
                        sha256 = (Get-ContinueFileSha256 -LiteralPath $_.FullName) } })
                Write-CaptionJson 'files.sha256.json' $files
            }
        }
        if (@($script:providerRecord.cleanup_errors).Count -ne 0) { throw 'CAPTION_PROVIDER_CLEANUP_FAILED' }
    }
}


