#requires -Version 7.0
<#
.SYNOPSIS
External, English-only Windows release UI probe. Run ONLY on a disposable cloud runner.
.DESCRIPTION
Consumes the existing export validation ZIP; does not export, patch, inject scripts,
or enable fixture registration. Run each mode in a fresh pwsh process. A owns dispatch.
Capability uses its own empty UserRoot. Create uses a different empty UserRoot; Load
reuses Create's UserRoot and requires its result.json. TerminalLoad then reuses that root
with successful Create and Load receipts, loading the genuine COMPLETED autosave in a
new process. It expects automatic Title return, not replay of an older ending slot.
Every mode needs a fresh OutputPath.
Example (replace all pins with the actual candidate and retained archive receipt):
  ./tools/testing/Invoke-ExportedGameplay.ps1 -Mode Capability -ArchivePath $zip `
    -ExpectedArchiveSha256 $sha256 -ExpectedCommit $commit -UserRoot $probe -OutputPath $out
Then Create with a different UserRoot/OutputPath, then Load with that creator UserRoot,
a third OutputPath and -CreatorReceipt <create-output>/result.json. Pass the successful
capability result.json as -CapabilityReceipt to Create. Renderer defaults to the project's
renderer; an explicit gl_compatibility run is separately scoped and recorded.
Accessibility Always and Audio Dummy are explicit cloud harness settings, not default
accessibility or audio-output qualification. Receipts bind these settings across modes.
Success means bounded machine checks passed. Screenshots require independent visual review;
UIA names alone do not prove full-line pixels. Capability is not Save/Load acceptance.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Capability', 'Create', 'Load', 'TerminalLoad')][string]$Mode,
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedArchiveSha256,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{40}$')][string]$ExpectedCommit,
    [Parameter(Mandatory)][string]$UserRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$CapabilityReceipt,
    [string]$CreatorReceipt,
    [string]$CompletionReceipt,
    [ValidateSet('ProjectDefault', 'gl_compatibility')][string]$Renderer = 'ProjectDefault',
    [ValidateSet('ProjectDefault', 'Always')][string]$Accessibility = 'ProjectDefault',
    [ValidateSet('ProjectDefault', 'Dummy')][string]$Audio = 'ProjectDefault',
    [ValidateRange(10, 60)][int]$StepTimeoutSeconds = 30,
    [ValidateRange(120, 900)][int]$JourneyTimeoutSeconds = 480
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
if (-not $IsWindows) { throw 'WINDOWS_CLOUD_RUNNER_REQUIRED' }
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DwmExportWindow {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    private static System.Threading.Timer watchdog;
    public static volatile bool Expired;
    public static void Arm(System.Diagnostics.Process child, int milliseconds) {
        watchdog = new System.Threading.Timer(_ => {
            Expired = true;
            try { if (!child.HasExited) child.Kill(true); } catch { }
        }, null, milliseconds, System.Threading.Timeout.Infinite);
    }
    public static void Disarm() { if (watchdog != null) watchdog.Dispose(); }
}
'@
[void][DwmExportWindow]::SetThreadDpiAwarenessContext([IntPtr](-4))
$output = [IO.Path]::GetFullPath($OutputPath)
$user = [IO.Path]::GetFullPath($UserRoot)
$archive = [IO.Path]::GetFullPath($ArchivePath)
$utf8 = [Text.UTF8Encoding]::new($false)
$child = $null
$stdoutRead = $null
$stderrRead = $null
$window = $null
$dataRoot = $null
$providerSession = $null
$providerWindow = $null
$providerElements = $null
$providerClosed = $false
$providerRecord = [ordered]@{ status = 'not_started'; mode = $Mode;
    client_route = 'managed-discovery-then-native-COM-provenance'; identity_verified = $false;
    operations = @(); events = @(); cleanup_errors = @(); error = $null; closed = $false }
$clock = [Diagnostics.Stopwatch]::StartNew()
$events = [Collections.Generic.List[object]]::new()
$result = [ordered]@{
    schema_version = 1; mode = $Mode; ok = $false; visual_review_required = $true
    source_commit = $ExpectedCommit.ToLowerInvariant(); archive_sha256 = $ExpectedArchiveSha256.ToLowerInvariant()
    accessibility_request = $Accessibility; audio_request = $Audio
    renderer_request = $Renderer; user_root = $user; output_path = $output
    scope = 'Ordinary release UI; normal packaged seven-day TEST story; no Challenge registration'
    forced_cleanup = $false; clean_player_exit = $false
    driver_sha256 = Get-ContinueFileSha256 -LiteralPath $PSCommandPath
    step_timeout_seconds = $StepTimeoutSeconds; journey_timeout_seconds = $JourneyTimeoutSeconds
}

function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 100), $utf8)
}
function Read-Json([string]$Path) {
    return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable)
}
function Hash([string]$Path) { return Get-ContinueFileSha256 -LiteralPath $Path }
function Require([bool]$Condition, [string]$Reason) { if (-not $Condition) { throw $Reason } }
function Below([string]$Path, [string]$Parent) {
    return $Path.StartsWith($Parent.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Record([string]$Kind, $Data) {
    $events.Add([ordered]@{ utc = [DateTime]::UtcNow.ToString('o'); kind = $Kind; data = $Data })
    Write-Json (Join-Path $output 'events.json') $events.ToArray()
}
function Check-Live {
    Require ($clock.Elapsed.TotalSeconds -lt $JourneyTimeoutSeconds) 'JOURNEY_TIMEOUT'
    Require ($null -ne $child -and -not $child.HasExited) 'EXPORTED_PROCESS_EXITED_EARLY'
    $child.Refresh()
    Require ([IO.Path]::GetFullPath($child.MainModule.FileName) -ieq $executable) 'PROCESS_EXECUTABLE_CHANGED'
    Require ($child.StartTime.ToUniversalTime().ToString('o') -ceq $result.process.started_utc) 'PROCESS_IDENTITY_CHANGED'
}
function Window {
    Check-Live
    $handle = $child.MainWindowHandle
    if ($handle -eq [IntPtr]::Zero) { return $null }
    $owner = [uint32]0
    [void][DwmExportWindow]::GetWindowThreadProcessId($handle, [ref]$owner)
    Require ($owner -eq $child.Id) 'WINDOW_PID_MISMATCH'
    if ($providerRecord.status -cne 'not_started') {
        Require ($providerRecord.hwnd -eq $handle.ToInt64() -and
            $providerRecord.engine_start_ticks -ceq $child.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)) 'EXPORT_PROVIDER_BOUND_WINDOW_CHANGED'
    }
    $element = [Windows.Automation.AutomationElement]::FromHandle($handle)
    Require ($element.Current.ProcessId -eq $child.Id) 'UIA_WINDOW_PID_MISMATCH'
    return $element
}
function Nodes($Root) {
    if ($null -eq $Root) { return @() }
    return @($Root.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition))
}
function Visible($Element) {
    $c = $Element.Current
    $bounds = $c.BoundingRectangle
    # Scene replacement can invalidate an enumerated provider before its bounds read.
    # It is not an actionable target; bounded discovery must obtain fresh controls.
    if ($bounds -isnot [Windows.Rect]) {
        Record 'uia-unavailable-bounds' @{ name = $c.Name; type = $(if ($null -eq $bounds) { 'null' } else { $bounds.GetType().FullName }) }
        return $false
    }
    return (-not $c.IsOffscreen -and -not $bounds.IsEmpty -and
        [double]::IsFinite($bounds.X) -and [double]::IsFinite($bounds.Y) -and
        [double]::IsFinite($bounds.Width) -and [double]::IsFinite($bounds.Height) -and
        $bounds.Width -gt 1 -and $bounds.Height -gt 1)
}
function Actions($Root, [string]$Name) {
    return @(Nodes $Root | Where-Object {
        $pattern = $null
        (Visible $_) -and $_.Current.IsEnabled -and $_.Current.Name.TrimEnd() -ceq $Name -and
            $_.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)
    })
}
function Write-ProviderJson([string]$Name, $Value) { Write-Json (Join-Path $output $Name) $Value }
function Save-CaptionProviderEvent([string]$Stage, [Diagnostics.Stopwatch]$Deadline) {
    $script:providerRecord.events += [ordered]@{ stage = $Stage;
        unix_msec = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();
        lookup_elapsed_msec = $Deadline.Elapsed.TotalMilliseconds }
    if ($null -ne $script:providerSession) {
        $script:providerRecord.operations = @($script:providerSession.Operations)
    }
    Write-ProviderJson 'native-provider.json' $script:providerRecord
}

function Assert-CaptionProviderBinding([Diagnostics.Process]$Native, [IntPtr]$Handle,
    [object]$ProcessIdentity, [long]$StartTicks, [Diagnostics.Stopwatch]$Deadline) {
    Require ($Deadline.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) 'EXPORT_PROVIDER_LOOKUP_DEADLINE'
    Check-Live
    [uint32]$windowPid = 0
    Require ($Native.StartTime.ToUniversalTime().Ticks -eq $StartTicks -and
        $Native.MainWindowHandle -eq $Handle -and
        [DwmExportWindow]::GetWindowThreadProcessId($Handle, [ref]$windowPid) -ne 0 -and
        $windowPid -eq [uint32]$ProcessIdentity.pid -and $Native.Id -eq $ProcessIdentity.pid) 'EXPORT_PROVIDER_BINDING_CHANGED'
    Require ($Deadline.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) 'EXPORT_PROVIDER_LOOKUP_DEADLINE'
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
    Write-ProviderJson 'native-provider.json' $script:providerRecord
}

function Wait-One([string]$Name, [scriptblock]$Find) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) {
        $script:window = Window
        if ($watch.Elapsed.TotalSeconds -ge $StepTimeoutSeconds) {
            Record 'wait-deadline-expired' @{ name = $Name; phase = 'window' }
            break
        }
        if ($null -ne $window) {
            if ($providerRecord.status -ceq 'not_started') {
                $managedElements = @(Nodes $window)
                $identity = [ordered]@{ pid = $child.Id; executable = $executable;
                    started_utc = $result.process.started_utc }
                Start-CaptionProvider $child $child.MainWindowHandle $identity $window $managedElements $watch
            }
            if ($watch.Elapsed.TotalSeconds -ge $StepTimeoutSeconds) {
                Record 'wait-deadline-expired' @{ name = $Name; phase = 'provider' }
                break
            }
            Require ($providerRecord.status -ceq 'observed') 'EXPORT_PROVIDER_NOT_READY'
            $items = @(& $Find)
            if ($watch.Elapsed.TotalSeconds -ge $StepTimeoutSeconds) {
                Record 'wait-deadline-expired' @{ name = $Name; phase = 'find'; late_matches = $items.Count }
                break
            }
            Require ($items.Count -le 1) "UIA_AMBIGUOUS: $Name ($($items.Count))"
            if ($items.Count -eq 1 -and $watch.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) { return $items[0] }
        }
        Start-Sleep -Milliseconds 100
    }
    throw "UIA_UNAVAILABLE_OR_TIMEOUT: $Name"
}
function Button([string]$Name) { return Wait-One $Name { Actions $window $Name } }
function Describe($Element) {
    $c = $Element.Current
    return [ordered]@{ name = $c.Name; type = $c.ControlType.ProgrammaticName;
        automation_id = $c.AutomationId; runtime_id = @($Element.GetRuntimeId()); pid = $c.ProcessId;
        enabled = $c.IsEnabled; offscreen = $c.IsOffscreen;
        rectangle = @($c.BoundingRectangle.X, $c.BoundingRectangle.Y, $c.BoundingRectangle.Width, $c.BoundingRectangle.Height);
        patterns = @($Element.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName }) }
}
function Capture([string]$Stage) {
    $script:window = Window
    Require ($null -ne $window) 'CAPTURE_WINDOW_MISSING'
    [void][DwmExportWindow]::SetForegroundWindow($child.MainWindowHandle)
    Start-Sleep -Milliseconds 200
    Require ([DwmExportWindow]::GetForegroundWindow() -eq $child.MainWindowHandle) 'CAPTURE_WINDOW_NOT_FOREGROUND'
    $records = @(Nodes $window | ForEach-Object { Describe $_ })
    Write-Json (Join-Path $output "$Stage.uia.json") $records
    $r = $window.Current.BoundingRectangle
    Require (-not $r.IsEmpty -and $r.Width -gt 0 -and $r.Height -gt 0 -and $r.Width -le 4096 -and $r.Height -le 4096) 'CAPTURE_BOUNDS_INVALID'
    $bitmap = [Drawing.Bitmap]::new([int][Math]::Ceiling($r.Width), [int][Math]::Ceiling($r.Height))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $path = Join-Path $output "$Stage.png"
    try {
        $graphics.CopyFromScreen([int]$r.X, [int]$r.Y, 0, 0, $bitmap.Size)
        $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    Record 'capture' @{ stage = $Stage; file = "$Stage.png"; sha256 = (Hash $path) }
}
function Invoke-UI($Element, [string]$Purpose) {
    Check-Live
    Require ((Visible $Element) -and $Element.Current.IsEnabled) "UIA_ACTION_DISABLED: $Purpose"
    # Runtime IDs and window ancestry bind the current target even if providers omit a child PID.
    $current = $Element
    $belongs = $false
    for ($i = 0; $i -lt 64 -and $null -ne $current; $i++) {
        if ([Windows.Automation.Automation]::Compare($current, $window)) { $belongs = $true; break }
        $current = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($current)
    }
    Require $belongs 'UIA_ACTION_OUTSIDE_BOUND_WINDOW'
    Require ($window.Current.BoundingRectangle.Contains($Element.Current.BoundingRectangle)) 'UIA_ACTION_OUTSIDE_WINDOW'
    [void][DwmExportWindow]::SetForegroundWindow($child.MainWindowHandle)
    $Element.SetFocus()
    Require ([DwmExportWindow]::GetForegroundWindow() -eq $child.MainWindowHandle) 'UIA_ACTION_NOT_FOREGROUND'
    $pattern = $null
    Require ($Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) 'UIA_INVOKE_UNSUPPORTED'
    Record 'invoke' @{ purpose = $Purpose; target = (Describe $Element) }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    Start-Sleep -Milliseconds 200
}
function Caption-Nodes($Root, [string]$Text) {
    return @(Nodes $Root | Where-Object {
        (Visible $_) -and $_.Current.Name.TrimEnd() -ceq $Text -and
            $_.Current.ControlType -eq [Windows.Automation.ControlType]::Text
    })
}
function Assert-CaptionElement($Element, $BoundWindow) {
    Require ((Visible $Element) -and $Element.Current.IsEnabled) 'CAPTION_ELEMENT_UNAVAILABLE'
    Require ($Element.Current.ProcessId -in @(0, $child.Id)) 'CAPTION_ELEMENT_FOREIGN_PROCESS'
    $current = $Element
    $belongs = $false
    for ($i = 0; $i -lt 64 -and $null -ne $current; $i++) {
        if ([Windows.Automation.Automation]::Compare($current, $BoundWindow)) { $belongs = $true; break }
        $current = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($current)
    }
    Require $belongs 'CAPTION_ELEMENT_OUTSIDE_BOUND_WINDOW'
    Require ($BoundWindow.Current.BoundingRectangle.Contains($Element.Current.BoundingRectangle)) 'CAPTION_ELEMENT_OUTSIDE_WINDOW'
}
function Assert-Prose($Element, $BoundWindow, [string]$Text) {
    Assert-CaptionElement $Element $BoundWindow
    $pattern = $null
    Require ($Element.Current.ControlType -eq [Windows.Automation.ControlType]::Text -and
        $Element.Current.Name.TrimEnd() -ceq $Text -and
        -not $Element.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) 'CAPTION_TEXT_ROLE_OR_ACTION_CHANGED'
}
function Caption([string]$Text) {
    return Wait-One $Text {
        $matches = @(Caption-Nodes $window $Text)
        foreach ($prose in $matches) { Assert-Prose $prose $window $Text }
        $matches
    }
}
function Invoke-Continue([string]$Text, [string]$Purpose) {
    # Resolve both objects under one existing step deadline. A pause-menu Continue
    # cannot qualify: the story background must contain the expected prose rectangle.
    $binding = Wait-One "Continue for: $Text" {
        $proseMatches = @(Caption-Nodes $window $Text)
        Require ($proseMatches.Count -le 1) "UIA_AMBIGUOUS: $Text"
        if ($proseMatches.Count -eq 1) {
            $prose = $proseMatches[0]
            Assert-Prose $prose $window $Text
            foreach ($action in @(Actions $window 'Continue')) {
                if (-not $action.Current.BoundingRectangle.Contains($prose.Current.BoundingRectangle)) { continue }
                Assert-CaptionElement $action $window
                Require ($action.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
                    -not [Windows.Automation.Automation]::Compare($prose, $action)) 'CONTINUE_ROLE_INVALID'
                [pscustomobject]@{ prose = $prose; action = $action; window = $window;
                    hwnd = $child.MainWindowHandle; prose_id = @($prose.GetRuntimeId());
                    action_id = @($action.GetRuntimeId()); prose_rect = $prose.Current.BoundingRectangle;
                    action_rect = $action.Current.BoundingRectangle }
            }
        }
    }
    Check-Live
    Require ($child.MainWindowHandle -eq $binding.hwnd) 'CONTINUE_WINDOW_HANDLE_CHANGED'
    $currentWindow = Window
    Require ([Windows.Automation.Automation]::Compare($currentWindow, $binding.window)) 'CONTINUE_WINDOW_CHANGED'
    [void][DwmExportWindow]::SetForegroundWindow($binding.hwnd)
    Require ([DwmExportWindow]::GetForegroundWindow() -eq $binding.hwnd) 'CONTINUE_NOT_FOREGROUND'
    Assert-Prose $binding.prose $binding.window $Text
    Assert-CaptionElement $binding.action $binding.window
    Require ((@($binding.prose.GetRuntimeId()) -join ',') -ceq ($binding.prose_id -join ',') -and
        (@($binding.action.GetRuntimeId()) -join ',') -ceq ($binding.action_id -join ',') -and
        $binding.prose.Current.BoundingRectangle -eq $binding.prose_rect -and
        $binding.action.Current.BoundingRectangle -eq $binding.action_rect -and
        $binding.action.Current.Name.TrimEnd() -ceq 'Continue' -and
        $binding.action.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
        $binding.action.Current.BoundingRectangle.Contains($binding.prose.Current.BoundingRectangle)) 'CONTINUE_BINDING_CHANGED'
    $pattern = $null
    Require ($binding.action.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) 'CONTINUE_INVOKE_UNSUPPORTED'
    Record 'invoke-continue' @{ purpose = $Purpose; prose = (Describe $binding.prose);
        target = (Describe $binding.action); hwnd = $binding.hwnd.ToInt64(); attempted_calls = 1 }
    # Do not move focus to Continue: that could retire the captured action.
    # No callback substitution or invocation retry.
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    Record 'invoke-continue-returned' @{ purpose = $Purpose }
    Start-Sleep -Milliseconds 200
}
function Observe-Line([string]$Text, [string]$Stage) {
    $null = Caption $Text
    Capture "$Stage-first-observed"
    # Text naming is not visibility proof. Keep a settled screenshot for independent review.
    Start-Sleep -Milliseconds 1600
    $null = Caption $Text
    Capture $Stage
}
function Advance([string]$From, [string]$To, [string]$Stage) {
    Invoke-Continue $From "advance: $From"
    Observe-Line $To $Stage
}
function Backup-Scope {
    # Prefer a common Backup ancestor. The observed native provider flattens this
    # surface, so a window-bound fallback requires the exact unique 3x3 drawer grid.
    # Action selection still uses the dock geometry, never a first global name match.
    $slots = @(Nodes $window | Where-Object {
        (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
            $_.Current.Name -cmatch '^Slot 1, '
    })
    Require ($slots.Count -eq 1) 'BACKUP_SLOT1_UNAVAILABLE_OR_AMBIGUOUS'
    $ancestor = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($slots[0])
    for ($i = 0; $i -lt 32 -and $null -ne $ancestor; $i++) {
        $descendants = @(Nodes $ancestor)
        $matched = @($descendants | Where-Object {
            (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
                $_.Current.Name -cmatch '^(Autosave|Quick|Slot [1-7]), '
        })
        if ($matched.Count -eq 9) {
            $identities = @($matched | ForEach-Object { ($_.Current.Name -split ', ', 2)[0] } | Sort-Object -Unique)
            Require ($identities.Count -eq 9) 'BACKUP_DRAWERS_NOT_UNIQUE'
            $lefts = @($matched | ForEach-Object { $_.Current.BoundingRectangle.Left } | Sort-Object -Unique)
            $tops = @($matched | ForEach-Object { $_.Current.BoundingRectangle.Top } | Sort-Object -Unique)
            Require ($lefts.Count -eq 3 -and $tops.Count -eq 3) 'BACKUP_DRAWER_GRID_UNEXPECTED'
            $cells = @($matched | ForEach-Object { "$($_.Current.BoundingRectangle.Left):$($_.Current.BoundingRectangle.Top)" } | Sort-Object -Unique)
            Require ($cells.Count -eq 9) 'BACKUP_DRAWER_GRID_OVERLAP'
            Record 'backup-provider-scope' @{ flattened = [Windows.Automation.Automation]::Compare($ancestor, $window); drawer_names = $identities; columns = $lefts; rows = $tops }
            return $ancestor
        }
        if ([Windows.Automation.Automation]::Compare($ancestor, $window)) { break }
        $ancestor = [Windows.Automation.TreeWalker]::RawViewWalker.GetParent($ancestor)
    }
    throw 'BACKUP_PROVIDER_SURFACE_NOT_EXPOSED'
}
function Select-Slot([int]$Number) {
    $scope = Backup-Scope
    $slots = @(Nodes $scope | Where-Object {
        (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
            $_.Current.Name.StartsWith("Slot $Number, ", [StringComparison]::Ordinal)
    })
    Require ($slots.Count -eq 1) 'BACKUP_SLOT_UNAVAILABLE_OR_AMBIGUOUS'
    Invoke-UI $slots[0] "select slot $Number"
}
function Backup-Action([string]$Name) {
    $scope = Backup-Scope
    $drawers = @(Nodes $scope | Where-Object {
        (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
            $_.Current.Name -cmatch '^(Autosave|Quick|Slot [1-7]), '
    })
    # Existing Backup layout has the action dock right of the grid, in its lower half.
    # Mode controls are above the grid. Geometry is observed, never a fixed click coordinate.
    $right = ($drawers | ForEach-Object { $_.Current.BoundingRectangle.Right } | Measure-Object -Maximum).Maximum
    $bottom = ($drawers | ForEach-Object { $_.Current.BoundingRectangle.Bottom } | Measure-Object -Maximum).Maximum
    $top = ($drawers | ForEach-Object { $_.Current.BoundingRectangle.Top } | Measure-Object -Minimum).Minimum
    $actions = @(Actions $scope $Name | Where-Object {
        $_.Current.BoundingRectangle.Left -ge $right -and $_.Current.BoundingRectangle.Top -ge ($top + $bottom) / 2 -and
            $_.Current.BoundingRectangle.Bottom -le $bottom
    })
    Require ($actions.Count -eq 1) "BACKUP_ACTION_UNAVAILABLE_OR_AMBIGUOUS: $Name"
    Record 'backup-action-scope' @{ action = $Name; surface = (Describe $scope); target = (Describe $actions[0]) }
    return $actions[0]
}
function Reading-Save {
    # SceneHost also has a left Save control. Select the unique bottom reading rail action.
    return Wait-One 'reading Save rail' {
        $r = $window.Current.BoundingRectangle
        Actions $window 'Save' | Where-Object {
                $_.Current.BoundingRectangle.Top -gt $r.Top + $r.Height * 0.7
        }
    }
}
function Wait-File([string]$Path) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) {
        Check-Live
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            try { $value = Read-Json $Path; if ($value.Contains('current_snapshot')) { return $value } } catch { }
        }
        Start-Sleep -Milliseconds 100
    }
    throw "SAVE_FILE_TIMEOUT: $Path"
}
function Save-Slot([int]$Number) {
    Invoke-UI (Reading-Save) "open Save for slot $Number"
    $null = Wait-One 'Backup drawers' {
        Nodes $window | Where-Object { (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $_.Current.Name.TrimEnd() -ceq "Slot $Number, Empty" }
    }
    Select-Slot $Number
    Capture "save-$Number-selected"
    Invoke-UI (Backup-Action 'Save') "commit empty slot $Number"
    $path = Join-Path $dataRoot "saves/slot_$Number.json"
    $document = Wait-File $path
    $null = Wait-One 'Saved status' { Nodes $window | Where-Object { (Visible $_) -and $_.Current.Name.TrimEnd() -ceq 'Saved' } }
    Capture "save-$Number-complete"
    Invoke-UI (Button 'Back') 'close direct Backup host'
    return $document
}

function Capture-FailureStacks {
    if ($null -eq $child -or $child.HasExited -or [string]::IsNullOrWhiteSpace($env:DWM_CDB_PATH)) { return }
    Check-Live
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $env:DWM_CDB_PATH
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $symbols = 'srv*' + (Join-Path $env:RUNNER_TEMP 'dwm-symbols') + '*https://msdl.microsoft.com/download/symbols'
    foreach ($arg in @('-pv','-p',[string]$child.Id,'-y',$symbols,'-c','!runaway; ~* kv 24; lm; q')) { $start.ArgumentList.Add($arg) }
    $debugger = [Diagnostics.Process]::new()
    $debugger.StartInfo = $start
    try {
        Require ($debugger.Start()) 'STACK_DIAGNOSTIC_START_FAILED'
        $stdout = $debugger.StandardOutput.ReadToEndAsync()
        $stderr = $debugger.StandardError.ReadToEndAsync()
        $complete = $debugger.WaitForExit(55000)
        if (-not $complete) { $debugger.Kill($true); [void]$debugger.WaitForExit(3000) }
        $result.stack_probe_completed = $complete
        if ([Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),3000)) {
            [IO.File]::WriteAllText((Join-Path $output 'failure-stacks.stdout.log'),$stdout.GetAwaiter().GetResult(),$utf8)
            [IO.File]::WriteAllText((Join-Path $output 'failure-stacks.stderr.log'),$stderr.GetAwaiter().GetResult(),$utf8)
        }
    } finally { $debugger.Dispose() }
}

function Capture-FailureWindow {
    if ($null -eq $child -or $child.HasExited) { return }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Command pwsh).Source
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($arg in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'Probe-ExportedWindow.ps1'),
        '-TargetProcessId',[string]$child.Id,'-ExpectedExecutable',$executable,
        '-ExpectedStartedUtc',$result.process.started_utc,'-OutputFile',(Join-Path $output 'failure-native-window.json'))) {
        $start.ArgumentList.Add($arg)
    }
    $probe = [Diagnostics.Process]::new()
    $probe.StartInfo = $start
    try {
        Require ($probe.Start()) 'DIAGNOSTIC_START_FAILED'
        $stdout = $probe.StandardOutput.ReadToEndAsync()
        $stderr = $probe.StandardError.ReadToEndAsync()
        $complete = $probe.WaitForExit(15000)
        if (-not $complete) { $probe.Kill($true); [void]$probe.WaitForExit(3000) }
        $result.native_probe_completed = $complete
        if ([Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),3000)) {
            [IO.File]::WriteAllText((Join-Path $output 'failure-native-probe.stdout.log'),$stdout.GetAwaiter().GetResult(),$utf8)
            [IO.File]::WriteAllText((Join-Path $output 'failure-native-probe.stderr.log'),$stderr.GetAwaiter().GetResult(),$utf8)
        }
    } finally { $probe.Dispose() }
}

function Capture-FailureSaves {
    # Read-only live observations, not an atomic checkpoint or acceptance evidence.
    # Capture before UIA: a provider call may block until the process watchdog fires.
    if ([string]::IsNullOrWhiteSpace($dataRoot)) { return }
    $observations = @()
    foreach ($relative in @('profile.json', 'saves/slot_1.json', 'saves/slot_2.json', 'saves/autosave.json', 'saves/desktop-continuation-operations.json')) {
        $entry = [ordered]@{ source = $relative; utc = [DateTime]::UtcNow.ToString('o'); status = 'missing' }
        $stream = $null
        try {
            $source = Join-Path $dataRoot $relative
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                $stream = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                Require ($stream.Length -le 16MB) 'FAILURE_SAVE_CAPTURE_SIZE_LIMIT'
                $bytes = [byte[]]::new([int]$stream.Length)
                $offset = 0
                while ($offset -lt $bytes.Length) {
                    $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
                    Require ($count -gt 0) 'FAILURE_SAVE_CHANGED_DURING_READ'
                    $offset += $count
                }
                Require ($stream.ReadByte() -eq -1) 'FAILURE_SAVE_GREW_DURING_READ'
                $name = 'failure-' + ($relative -replace '/', '-')
                $destination = Join-Path $output $name
                [IO.File]::WriteAllBytes($destination, $bytes)
                $entry.status = 'copied'
                $entry.file = $name
                $entry.bytes = $bytes.Length
                $entry.sha256 = Hash $destination
            }
        } catch { $entry.status = 'error'; $entry.error = $_.Exception.Message }
        finally { if ($null -ne $stream) { $stream.Dispose() } }
        $observations += $entry
    }
    Write-Json (Join-Path $output 'failure-save-observations.json') $observations
}

function Snapshot($Document) {
    Require ($Document.Contains('current_snapshot') -and $Document.current_snapshot.Contains('snapshot')) 'SAVE_ENVELOPE_UNEXPECTED'
    return $Document.current_snapshot.snapshot
}
function Canonical($Value) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [Collections.IDictionary]) {
        $parts = @($Value.Keys | Sort-Object -CaseSensitive | ForEach-Object {
            (ConvertTo-Json -InputObject ([string]$_) -Compress) + ':' + (Canonical $Value[$_])
        })
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [array]) { return '[' + ((@($Value | ForEach-Object { Canonical $_ })) -join ',') + ']' }
    return ConvertTo-Json -InputObject $Value -Compress -Depth 100
}
function End-Process([bool]$AtTitle) {
    if ($AtTitle) {
        Invoke-UI (Button 'Shut down') 'request normal shutdown'
        $sheet = Wait-One 'Shut down confirmation' {
            Nodes $window | Where-Object { (Visible $_) -and $_.Current.Name.TrimEnd() -ceq 'Shut down?' -and @(Actions $_ 'Shut down').Count -eq 1 }
        }
        Invoke-UI (@(Actions $sheet 'Shut down')[0]) 'confirm normal shutdown'
    } else {
        Capture 'before-window-close'
        $pattern = $null
        Require ($window.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern, [ref]$pattern)) 'NORMAL_WINDOW_CLOSE_UNAVAILABLE'
        Record 'window-close' @{ method = 'UIAutomation.WindowPattern.Close'; pid = $child.Id }
        ([Windows.Automation.WindowPattern]$pattern).Close()
    }
    Require ($child.WaitForExit($StepTimeoutSeconds * 1000)) 'PLAYER_EXIT_TIMEOUT'
    $result.exit_code = $child.ExitCode
    Require ($child.ExitCode -eq 0) 'PLAYER_EXIT_NONZERO'
    $result.clean_player_exit = $true
}
function Receipt([string]$Path, [string]$ExpectedMode) {
    Require (-not [string]::IsNullOrWhiteSpace($Path)) "$ExpectedMode`_RECEIPT_REQUIRED"
    $r = Read-Json ([IO.Path]::GetFullPath($Path))
    Require ($r.ok -and $r.clean_player_exit -and -not $r.forced_cleanup -and $r.mode -ceq $ExpectedMode) 'PREREQUISITE_NOT_SUCCESSFUL'
    Require ($r.archive_sha256 -ceq $result.archive_sha256 -and $r.source_commit -ceq $result.source_commit -and
        $r.renderer_request -ceq $Renderer) 'PREREQUISITE_PACKAGE_OR_RENDERER_MISMATCH'
    Require ($r.accessibility_request -ceq $Accessibility -and $r.audio_request -ceq $Audio) 'PREREQUISITE_ACCESSIBILITY_OR_AUDIO_MISMATCH'
    Require ($r.driver_sha256 -ceq $result.driver_sha256 -and $r.step_timeout_seconds -eq $StepTimeoutSeconds -and
        $r.journey_timeout_seconds -eq $JourneyTimeoutSeconds) 'PREREQUISITE_DRIVER_OR_DEADLINE_MISMATCH'
    return $r
}

# No cleanup of caller directories, including on failure. Only the process we launch may be killed.
Require (-not (Test-Path -LiteralPath $output)) 'OUTPUT_MUST_NOT_EXIST'
Require ($output -ine $user -and -not (Below $output $user) -and -not (Below $user $output)) 'USER_OUTPUT_ROOTS_MUST_BE_DISJOINT'
Require (-not (Below $archive $output) -and -not (Below $archive $user)) 'ARCHIVE_MUST_BE_OUTSIDE_WORK_ROOTS'
New-Item -ItemType Directory -Path $output | Out-Null
try {
    Require ((Hash $archive) -ceq $result.archive_sha256) 'ARCHIVE_CHECKSUM_MISMATCH'
    if ($Mode -eq 'Create') { $result.capability = Receipt $CapabilityReceipt 'Capability' }
    if ($Mode -in @('Load', 'TerminalLoad')) {
        $creator = Receipt $CreatorReceipt 'Create'
        Require ($creator.user_root -ieq $user) 'CREATOR_USER_ROOT_MISMATCH'
        if ($Mode -eq 'TerminalLoad') {
            $completion = Receipt $CompletionReceipt 'Load'
            Require ($completion.user_root -ieq $user) 'COMPLETION_USER_ROOT_MISMATCH'
            Require ($completion.creator_receipt_sha256 -ceq (Hash $CreatorReceipt)) 'COMPLETION_CREATOR_MISMATCH'
            $result.completion_receipt_sha256 = Hash $CompletionReceipt
        }
        $result.creator_receipt_sha256 = Hash $CreatorReceipt
    } else {
        Require (-not (Test-Path -LiteralPath $user)) 'CAPABILITY_CREATE_USER_ROOT_MUST_NOT_EXIST'
        New-Item -ItemType Directory -Path $user | Out-Null
    }
    $package = Join-Path $output 'package'
    New-Item -ItemType Directory -Path $package | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $total = [long]0
        foreach ($entry in $zip.Entries) {
            $destination = [IO.Path]::GetFullPath((Join-Path $package $entry.FullName))
            Require ((Below $destination $package) -and $seen.Add($destination) -and $entry.FullName -notmatch ':') 'UNSAFE_OR_DUPLICATE_ARCHIVE_ENTRY'
            $total += $entry.Length
            Require ($total -le 2GB) 'ARCHIVE_EXPANDED_SIZE_LIMIT'
            if ($entry.FullName.EndsWith('/')) { New-Item -ItemType Directory -Force -Path $destination | Out-Null; continue }
            New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($destination)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $false)
        }
    } finally { $zip.Dispose() }
    $validation = Read-Json (Join-Path $package 'validation.json')
    Require ($validation.ok -and $validation.commit -ceq $result.source_commit -and $validation.engine -ceq '4.6.3.stable') 'EXPORT_RECEIPT_PIN_MISMATCH'
    $listed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $validation.files) {
        $path = [IO.Path]::GetFullPath((Join-Path $package $file.path))
        Require ((Below $path $package) -and $listed.Add($path)) 'EXPORT_MANIFEST_PATH_INVALID'
        Require ((Get-Item -LiteralPath $path).Length -eq $file.bytes -and (Hash $path) -ceq $file.sha256) 'EXPORTED_FILE_HASH_MISMATCH'
    }
    foreach ($file in Get-ChildItem -LiteralPath $package -Recurse -File) {
        Require ($listed.Contains($file.FullName) -or $file.FullName -ieq (Join-Path $package 'validation.json')) 'UNLISTED_PACKAGE_FILE'
    }
    $executable = Join-Path $package 'DWM.exe'
    Require ($listed.Contains($executable) -and $listed.Contains((Join-Path $package 'DWM.pck'))) 'EXPORTED_EXECUTABLE_OR_PACK_UNLISTED'
    $result.executable_sha256 = Hash $executable
    $result.pck_sha256 = Hash (Join-Path $package 'DWM.pck')
    $dataRoot = Join-Path $user 'appdata/Godot/app_userdata/DWM'
    $profilePath = Join-Path $dataRoot 'profile.json'
    $slotPath = Join-Path $dataRoot 'saves/slot_1.json'
    $autosavePath = Join-Path $dataRoot 'saves/autosave.json'
    if ($Mode -eq 'TerminalLoad') {
        Require ((Hash $autosavePath) -ceq $completion.completed_autosave_sha256) 'COMPLETED_AUTOSAVE_CHANGED_BEFORE_LOAD'
        Require ((Hash $profilePath) -ceq $completion.completed_profile_sha256) 'COMPLETED_PROFILE_CHANGED_BEFORE_LOAD'
        Require ((Hash $slotPath) -ceq $creator.source_slot_sha256) 'CREATOR_SLOT_CHANGED_BEFORE_TERMINAL_LOAD'
        Require ((Hash (Join-Path $dataRoot 'saves/slot_2.json')) -ceq $completion.witness_slot_sha256) 'WITNESS_SLOT_CHANGED_BEFORE_TERMINAL_LOAD'
        $terminalDocument = Read-Json $autosavePath
        $terminalSnapshot = Snapshot $terminalDocument
        $continuationPath = Join-Path $dataRoot 'saves/desktop-continuation-operations.json'
        Require ((Hash $continuationPath) -ceq $completion.completed_continuation_sha256) 'COMPLETED_CONTINUATION_CHANGED_BEFORE_LOAD'
        $terminalJournalBefore = Read-Json $continuationPath
        Copy-Item -LiteralPath $continuationPath -Destination (Join-Path $output 'terminal-continuation-before.json')
        Require ($terminalSnapshot.lifecycle.state -ceq 'COMPLETED' -and
            $terminalSnapshot.lifecycle.ending_plan.playback_stage -ceq 'GALLERY_RECORDED') 'TERMINAL_SOURCE_NOT_COMPLETED'
        $terminalProfile = Read-Json $profilePath
        $terminalGalleryKey = 'ending:' + $terminalSnapshot.lifecycle.run_id + ':gallery:ending.alone'
        Require ($terminalProfile.gallery_transaction_receipts.Contains($terminalGalleryKey) -and
            (Canonical $terminalProfile.gallery_transaction_receipts[$terminalGalleryKey]) -ceq
            (Canonical @{ ending_id = 'ending.alone'; unlocked = $true })) 'TERMINAL_SOURCE_GALLERY_RECEIPT_INVALID'
        Copy-Item -LiteralPath $autosavePath -Destination (Join-Path $output 'terminal-autosave-before.json')
        Copy-Item -LiteralPath $profilePath -Destination (Join-Path $output 'terminal-profile-before.json')
        $result.terminal_locator = 'autosave'
        $result.terminal_source_sha256 = Hash $autosavePath
        $result.terminal_run_id = $terminalSnapshot.lifecycle.run_id
    }
    if ($Mode -eq 'Load') {
        Require ((Hash $slotPath) -ceq $creator.source_slot_sha256) 'CREATOR_SLOT_CHANGED_BEFORE_LOAD'
        Require (-not (Test-Path -LiteralPath (Join-Path $dataRoot 'saves/slot_2.json'))) 'RESTORE_WITNESS_SLOT_NOT_EMPTY'
        $sourceSnapshot = Snapshot (Read-Json $slotPath)
        Require ((Hash $profilePath) -ceq $creator.source_profile_sha256) 'CREATOR_PROFILE_CHANGED_BEFORE_LOAD'
        $sourceProfile = Read-Json $profilePath
        Copy-Item -LiteralPath $profilePath -Destination (Join-Path $output 'profile-before-load.json')
    }
    $log = Join-Path $output 'game.log'
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $executable
    $start.WorkingDirectory = $package
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('--windowed', '--resolution', '1280x720', '--log-file', $log)) { $start.ArgumentList.Add($argument) }
    if ($Renderer -ne 'ProjectDefault') { $start.ArgumentList.Add('--rendering-method'); $start.ArgumentList.Add($Renderer) }
    if ($Accessibility -eq 'Always') { $start.ArgumentList.Add('--accessibility'); $start.ArgumentList.Add('always') }
    if ($Audio -eq 'Dummy') { $start.ArgumentList.Add('--audio-driver'); $start.ArgumentList.Add('Dummy') }
    foreach ($name in @($start.Environment.Keys | Where-Object { $_ -like 'DWM_*' })) { [void]$start.Environment.Remove($name) }
    foreach ($name in @('APPDATA', 'LOCALAPPDATA')) {
        $directory = Join-Path $user $name.ToLowerInvariant()
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $start.Environment[$name] = $directory
    }
    $child = [Diagnostics.Process]::new(); $child.StartInfo = $start
    Require ($child.Start()) 'EXPORT_LAUNCH_FAILED'
    $stdoutRead = $child.StandardOutput.ReadToEndAsync()
    $stderrRead = $child.StandardError.ReadToEndAsync()
    # Also bounds a blocking native UIA provider call, not just polling loops.
    [DwmExportWindow]::Arm($child, [int][Math]::Max(1, ($JourneyTimeoutSeconds - $clock.Elapsed.TotalSeconds) * 1000))
    $result.process = @{ pid = $child.Id; started_utc = $child.StartTime.ToUniversalTime().ToString('o'); executable = $executable; arguments = @($start.ArgumentList) }
    $nativeProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $($child.Id)"
    Require ($null -ne $nativeProcess -and [string]$nativeProcess.ExecutablePath -ieq $executable) 'NATIVE_PROCESS_PATH_MISMATCH'
    $result.process.observed_command_line = [string]$nativeProcess.CommandLine
    $null = Button 'New Acc'
    Capture 'title'
    if ($Mode -eq 'TerminalLoad') {
        foreach ($prior in @($creator, $completion)) {
            Require ($prior.process.pid -ne $child.Id -or $prior.process.started_utc -cne $result.process.started_utc) 'TERMINAL_LOAD_NOT_DISTINCT_PROCESS'
        }
        Invoke-UI (Button 'Log in') 'open completed autosave Load from Title'
        $null = Wait-One 'completed autosave drawer' {
            Nodes $window | Where-Object { (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $_.Current.Name.StartsWith('Autosave, ', [StringComparison]::Ordinal) }
        }
        $scope = Backup-Scope
        $autosaves = @(Nodes $scope | Where-Object {
            (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
                $_.Current.Name.StartsWith('Autosave, ', [StringComparison]::Ordinal)
        })
        Require ($autosaves.Count -eq 1) 'TERMINAL_AUTOSAVE_DRAWER_AMBIGUOUS'
        Invoke-UI $autosaves[0] 'select completed autosave'
        Capture 'terminal-autosave-selected'
        Invoke-UI (Backup-Action 'Load') 'load completed autosave'
        # A genuine COMPLETED restore drains return_completed to Title without replay.
        # Require the visible Backup drawers to disappear, not just the pre-existing Title.
        $null = Wait-One 'Title after completed autosave Load' {
            $drawers = @(Nodes $window | Where-Object {
                (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and
                    $_.Current.Name -cmatch '^(Autosave|Quick|Slot [1-7]), '
            })
            if ($drawers.Count -eq 0) { Actions $window 'New Acc' }
        }
        Capture 'terminal-load-return-title'
        $terminalJournalAfter = Read-Json $continuationPath
        $priorOperations = $terminalJournalBefore.operations
        $newOperations = @($terminalJournalAfter.operations.Keys | Where-Object { -not $priorOperations.Contains($_) })
        Require ($newOperations.Count -eq 1 -and $terminalJournalAfter.operations.Count -eq $priorOperations.Count + 1) 'TERMINAL_RESTORE_OPERATION_COUNT'
        foreach ($id in $priorOperations.Keys) {
            Require ($terminalJournalAfter.operations.Contains($id) -and
                (Canonical $terminalJournalAfter.operations[$id]) -ceq (Canonical $priorOperations[$id])) 'TERMINAL_RESTORE_CHANGED_PRIOR_OPERATION'
        }
        $operation = $terminalJournalAfter.operations[$newOperations[0]]
        Require ($operation.kind -ceq 'scene_restore' -and $operation.stage -ceq 'completed' -and
            $operation.activation_state -ceq 'acknowledged' -and $operation.source_locator.slot_id -ceq 'autosave' -and
            $operation.source_locator.checkpoint_id -ceq $terminalSnapshot.checkpoint_id -and
            (Canonical $operation.selected_document) -ceq (Canonical $terminalDocument)) 'TERMINAL_RESTORE_NOT_EXACT_ACKNOWLEDGED_AUTOSAVE'
        Copy-Item -LiteralPath $continuationPath -Destination (Join-Path $output 'terminal-continuation-after.json')
        $result.terminal_restore_transaction_id = $newOperations[0]
        Require ((Hash $autosavePath) -ceq $result.terminal_source_sha256) 'TERMINAL_LOAD_REWROTE_AUTOSAVE'
        Require ((Canonical (Read-Json $profilePath)) -ceq (Canonical $terminalProfile)) 'TERMINAL_LOAD_CHANGED_PROFILE_OR_GALLERY'
        $result.terminal_return_observed = $true
        End-Process $true
    } elseif ($Mode -eq 'Load') {
        Require ($creator.process.pid -ne $child.Id -or $creator.process.started_utc -cne $result.process.started_utc) 'LOAD_NOT_DISTINCT_PROCESS'
        Invoke-UI (Button 'Log in') 'open selected-slot Load from Title'
        $null = Wait-One 'saved slot drawer' { Nodes $window | Where-Object { (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $_.Current.Name -cmatch '^Slot 1, ' } }
        Select-Slot 1
        Capture 'load-slot-selected'
        Invoke-UI (Backup-Action 'Load') 'load source slot 1'
        # Title login may not require a confirmation. Never invoke a duplicate global Load.
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while ($watch.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) {
            $script:window = Window
            if (@(Actions $window 'TEST Day4 closing.').Count -eq 1) { break }
            $sheets = @(Nodes $window | Where-Object { (Visible $_) -and $_.Current.Name.TrimEnd() -ceq 'Load Slot 1?' -and @(Actions $_ 'Load').Count -eq 1 })
            Require ($sheets.Count -le 1) 'LOAD_CONFIRMATION_AMBIGUOUS'
            if ($sheets.Count -eq 1) { Invoke-UI (@(Actions $sheets[0] 'Load')[0]) 'confirm source slot Load'; break }
            Start-Sleep -Milliseconds 100
        }
        Observe-Line 'TEST Day4 closing.' 'restored-day4'
        $restored = Snapshot (Save-Slot 2)
        foreach ($key in @('narrative_checkpoint', 'gameplay', 'scene', 'command_receipts', 'applied_effect_transaction_ids', 'applied_variable_transaction_ids')) {
            Require ($sourceSnapshot.Contains($key) -and $restored.Contains($key)) "RESTORE_WITNESS_FIELD_MISSING: $key"
            Require ((Canonical $sourceSnapshot[$key]) -ceq (Canonical $restored[$key])) "RESTORED_STATE_CHANGED: $key"
        }
        Require ($restored.lifecycle.run_id -ceq $sourceSnapshot.lifecycle.run_id -and $restored.lifecycle.branch_id -cne $sourceSnapshot.lifecycle.branch_id) 'RESTORED_RUN_BRANCH_SEMANTICS'
        $restoredProfile = Read-Json $profilePath
        Require ((Canonical $restoredProfile) -ceq (Canonical $sourceProfile)) 'LOAD_OR_WITNESS_SAVE_CHANGED_PROFILE'
        Copy-Item -LiteralPath $profilePath -Destination (Join-Path $output 'profile-after-load.json')
        Copy-Item -LiteralPath (Join-Path $dataRoot 'saves/slot_2.json') -Destination (Join-Path $output 'restored-slot-2.json')
        Observe-Line 'TEST Day4 closing.' 'restored-after-witness-save'
        $previous = 'TEST Day4 closing.'
        for ($day = 5; $day -le 7; $day++) {
            foreach ($half in @('opening', 'closing')) {
                $next = "TEST Day$day $half."
                Advance $previous $next "day-$day-$half"
                $previous = $next
            }
        }
        Advance $previous 'TEST Seven-day ending.' 'ending'
        Invoke-Continue 'TEST Seven-day ending.' 'finish ending'
        $null = Button 'New Acc'
        Capture 'ending-return-title'
        $completed = Snapshot (Read-Json (Join-Path $dataRoot 'saves/autosave.json'))
        Require ($completed.lifecycle.state -ceq 'COMPLETED' -and $completed.lifecycle.ending_plan.playback_stage -ceq 'GALLERY_RECORDED') 'ENDING_NOT_DURABLY_COMPLETED'
        $completedProfile = Read-Json $profilePath
        $galleryKey = 'ending:' + $sourceSnapshot.lifecycle.run_id + ':gallery:ending.alone'
        Require ($completedProfile.gallery_transaction_receipts.Contains($galleryKey)) 'ENDING_GALLERY_RECEIPT_MISSING'
        Require ((Canonical $completedProfile.gallery_transaction_receipts[$galleryKey]) -ceq (Canonical @{ ending_id = 'ending.alone'; unlocked = $true })) 'ENDING_GALLERY_RECEIPT_WRONG'
        Require ($completedProfile.gallery_transaction_receipts.Count -eq $sourceProfile.gallery_transaction_receipts.Count + 1 -and
            'ending.alone' -cin $completedProfile.gallery_unlocks) 'ENDING_GALLERY_AWARD_COUNT'
        foreach ($key in $sourceProfile.gallery_transaction_receipts.Keys) {
            Require ($completedProfile.gallery_transaction_receipts.Contains($key) -and
                (Canonical $completedProfile.gallery_transaction_receipts[$key]) -ceq (Canonical $sourceProfile.gallery_transaction_receipts[$key])) 'PRIOR_GALLERY_RECEIPT_CHANGED'
        }
        Copy-Item -LiteralPath (Join-Path $dataRoot 'saves/autosave.json') -Destination (Join-Path $output 'completed-autosave.json')
        $result.restored_checkpoint_matches = $true
        End-Process $true
    } else {
        Invoke-UI (Button 'New Acc') 'ordinary New Game'
        Observe-Line 'TEST Day1 opening.' 'new-game'
        Invoke-UI (Button 'Check Computer') 'open Computer'
        $null = Button 'Close Computer'
        Capture 'computer-open'
        Invoke-UI (Button 'Close Computer') 'close Computer'
        Observe-Line 'TEST Day1 opening.' 'computer-closed-same-caption'
        if ($Mode -eq 'Capability') {
            Invoke-UI (Reading-Save) 'discover Backup without saving'
            $null = Wait-One 'empty slot drawer' { Nodes $window | Where-Object { (Visible $_) -and $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $_.Current.Name.TrimEnd() -ceq 'Slot 1, Empty' } }
            Select-Slot 1
            $null = Backup-Action 'Save'
            Capture 'capability-backup-action'
            Require (-not (Test-Path -LiteralPath $slotPath)) 'CAPABILITY_UNEXPECTED_MANUAL_SAVE'
            End-Process $false
        } else {
            $previous = 'TEST Day1 opening.'
            for ($day = 1; $day -le 4; $day++) {
                foreach ($half in @('opening', 'closing')) {
                    if ($day -eq 1 -and $half -ceq 'opening') { continue }
                    $next = "TEST Day$day $half."
                    Advance $previous $next "day-$day-$half"
                    $previous = $next
                }
            }
            $sourceSnapshot = Snapshot (Save-Slot 1)
            Require ($sourceSnapshot.narrative_checkpoint.reading_session.frontier.line_id -ceq 'line.Day4.two') 'WRONG_SAVED_FRONTIER'
            $result.source_slot_sha256 = Hash $slotPath
            Copy-Item -LiteralPath $slotPath -Destination (Join-Path $output 'source-slot-1.json')
            Observe-Line 'TEST Day4 closing.' 'saved-day4'
            End-Process $false
        }
    }
    if ($Mode -eq 'Load') { Require ((Hash $slotPath) -ceq $creator.source_slot_sha256) 'SOURCE_SLOT_MUTATED' }
    if ($Mode -eq 'Create') { Require ((Hash $slotPath) -ceq $result.source_slot_sha256) 'SOURCE_SLOT_MUTATED_ON_EXIT' }
    if ($Mode -eq 'Load') {
        Require ((Hash $autosavePath) -ceq (Hash (Join-Path $output 'completed-autosave.json'))) 'COMPLETED_AUTOSAVE_CHANGED_ON_EXIT'
        Require ((Canonical (Read-Json $profilePath)) -ceq (Canonical $completedProfile)) 'COMPLETED_PROFILE_CHANGED_ON_EXIT'
        $result.completed_autosave_sha256 = Hash $autosavePath
        $result.completed_profile_sha256 = Hash $profilePath
        $result.witness_slot_sha256 = Hash (Join-Path $dataRoot 'saves/slot_2.json')
        $result.completed_continuation_sha256 = Hash (Join-Path $dataRoot 'saves/desktop-continuation-operations.json')
        Copy-Item -LiteralPath (Join-Path $dataRoot 'saves/desktop-continuation-operations.json') -Destination (Join-Path $output 'completed-continuation.json')
    }
    if ($Mode -eq 'TerminalLoad') {
        Require ((Hash $continuationPath) -ceq (Hash (Join-Path $output 'terminal-continuation-after.json'))) 'TERMINAL_EXIT_CHANGED_CONTINUATION'
        Require ((Hash $autosavePath) -ceq $result.terminal_source_sha256) 'TERMINAL_EXIT_REWROTE_AUTOSAVE'
        Require ((Canonical (Read-Json $profilePath)) -ceq (Canonical $terminalProfile)) 'TERMINAL_EXIT_CHANGED_PROFILE_OR_GALLERY'
        Require ((Hash $slotPath) -ceq $creator.source_slot_sha256 -and
            (Hash (Join-Path $dataRoot 'saves/slot_2.json')) -ceq $completion.witness_slot_sha256) 'TERMINAL_LOAD_MUTATED_MANUAL_SLOTS'
        Copy-Item -LiteralPath $autosavePath -Destination (Join-Path $output 'terminal-autosave-after.json')
        $result.terminal_autosave_unchanged = $true
        $result.terminal_profile_and_gallery_unchanged = $true
    }
    Require (Test-Path -LiteralPath $log -PathType Leaf) 'GAME_LOG_MISSING'
    $logText = (Get-Content -LiteralPath $log -Raw -Encoding utf8) + "`n" + $stdoutRead.GetAwaiter().GetResult() + "`n" + $stderrRead.GetAwaiter().GetResult()
    Require ($logText -notmatch '(?m)SCRIPT ERROR:|^\s*ERROR:|STARTUP_FAILED|Unicode parsing error|Unexpected NUL character') 'GAME_ERROR_LOG'
    $result.renderer_log = @($logText -split '\r?\n' | Where-Object { $_ -match 'Vulkan|OpenGL|D3D12|Direct3D|Rendering' })
    if (Test-Path -LiteralPath $profilePath) { Copy-Item -LiteralPath $profilePath -Destination (Join-Path $output 'profile-after.json') }
    if ($Mode -eq 'Create') { $result.source_profile_sha256 = Hash $profilePath }
    Require (-not [DwmExportWindow]::Expired) 'EXPORTED_PROCESS_WATCHDOG_TIMEOUT'
    Close-CaptionProvider
    Require ($providerRecord.identity_verified -and $providerRecord.closed -and
        $providerRecord.cleanup_errors.Count -eq 0) 'EXPORT_PROVIDER_CLEANUP_OR_IDENTITY_FAILED'
    $result.ok = $true
} catch {
    $result.failure = $_.Exception.Message
    try { Capture-FailureSaves } catch { $result.save_capture_failure = $_.Exception.Message }
    try { Capture-FailureWindow } catch { $result.native_probe_failure = $_.Exception.Message }
    try { Capture-FailureStacks } catch { $result.stack_probe_failure = $_.Exception.Message }
    try { if ($null -ne $child -and -not $child.HasExited) { Capture 'failure' } } catch { $result.capture_failure = $_.Exception.Message }
    throw
} finally {
    try {
    [DwmExportWindow]::Disarm()
    if ([DwmExportWindow]::Expired) { $result.forced_cleanup = $true; $result.ok = $false; $result.watchdog_expired = $true }
    if ($null -ne $child) {
        $result.child_exited_before_cleanup = $child.HasExited
        if (-not $child.HasExited) {
            $result.forced_cleanup = $true
            $result.ok = $false
            $child.Kill($true)
            [void]$child.WaitForExit(10000)
        }
        if ($child.HasExited) { $result.exit_code = $child.ExitCode }
        if ($null -ne $stdoutRead) { [IO.File]::WriteAllText((Join-Path $output 'game.stdout.log'), $stdoutRead.GetAwaiter().GetResult(), $utf8) }
        if ($null -ne $stderrRead) { [IO.File]::WriteAllText((Join-Path $output 'game.stderr.log'), $stderrRead.GetAwaiter().GetResult(), $utf8) }
        $child.Dispose()
    }
    } catch {
        $result.ok = $false
        $result.process_cleanup_failure = $_.Exception.Message
    } finally {
        try { Close-CaptionProvider }
        catch { $providerRecord.cleanup_errors += $_.Exception.Message }
        if ($providerRecord.cleanup_errors.Count -gt 0) { $result.ok = $false }
        $result.provider_cleanup_errors = @($providerRecord.cleanup_errors)
    }
    $result.elapsed_seconds = $clock.Elapsed.TotalSeconds
    Write-Json (Join-Path $output 'result.json') $result
    $evidence = @(Get-ChildItem -LiteralPath $output -File | Sort-Object Name | ForEach-Object {
        @{ file = $_.Name; bytes = $_.Length; sha256 = (Hash $_.FullName) }
    })
    Write-Json (Join-Path $output 'manifest.json') $evidence
    if (-not $result.ok -and -not $result.Contains('failure')) { throw 'EXPORTED_CLEANUP_FAILED' }
}

