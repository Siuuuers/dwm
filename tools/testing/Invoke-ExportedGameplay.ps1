#requires -Version 7.0
<#
.SYNOPSIS
External, English-only Windows release UI probe. Run ONLY on a disposable cloud runner.
.DESCRIPTION
Consumes the existing export validation ZIP; does not export, patch, inject scripts,
or enable fixture registration. Run each mode in a fresh pwsh process. A owns dispatch.
Capability uses its own empty UserRoot. Create uses a different empty UserRoot; Load
reuses Create's UserRoot and requires its result.json. Every mode needs a fresh OutputPath.
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
    [Parameter(Mandatory)][ValidateSet('Capability', 'Create', 'Load')][string]$Mode,
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedArchiveSha256,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{40}$')][string]$ExpectedCommit,
    [Parameter(Mandatory)][string]$UserRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$CapabilityReceipt,
    [string]$CreatorReceipt,
    [switch]$ProfileSaveLoad,
    [switch]$ContinueAfterQuiet,
    [switch]$TraceDay5,
    [switch]$NativeReadyCaptions,
    [switch]$TraceEndingActions,
    [ValidateSet('ProjectDefault', 'gl_compatibility')][string]$Renderer = 'ProjectDefault',
    [ValidateSet('ProjectDefault', 'Always')][string]$Accessibility = 'ProjectDefault',
    [ValidateSet('ProjectDefault', 'Dummy')][string]$Audio = 'ProjectDefault',
    [ValidateRange(10, 60)][int]$StepTimeoutSeconds = 30,
    [ValidateRange(120, 900)][int]$JourneyTimeoutSeconds = 480
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'WINDOWS_CLOUD_RUNNER_REQUIRED' }
if ($ProfileSaveLoad -and $Mode -ne 'Load') { throw 'PROFILE_REQUIRES_DIAGNOSTIC_LOAD' }
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
    [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr h, System.Text.StringBuilder text, int count);
    public static string ClassName(IntPtr h) { var text = new System.Text.StringBuilder(256); GetClassName(h,text,256); return text.ToString(); }
    [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr wp, IntPtr lp, uint flags, uint timeout, out IntPtr result);
    public static bool Responds(IntPtr h, uint timeout) { IntPtr result; return SendMessageTimeout(h,0,IntPtr.Zero,IntPtr.Zero,2,timeout,out result)!=IntPtr.Zero; }
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
$clock = [Diagnostics.Stopwatch]::StartNew()
$events = [Collections.Generic.List[object]]::new()
$day5Watch = $null
$endingActionObservation = $null
$day5TraceConsumed = $false
$lastNativeResponds = $false
$result = [ordered]@{
    schema_version = 1; mode = $Mode; ok = $false; visual_review_required = $true
    source_commit = $ExpectedCommit.ToLowerInvariant(); archive_sha256 = $ExpectedArchiveSha256.ToLowerInvariant()
    accessibility_request = $Accessibility; audio_request = $Audio
    save_load_profile = [bool]$ProfileSaveLoad
    checkpoint_profile = [bool]$ProfileSaveLoad
    renderer_request = $Renderer; user_root = $user; output_path = $output
    scope = 'Ordinary release UI; normal packaged seven-day TEST story; no Challenge registration'
    forced_cleanup = $false; clean_player_exit = $false
}

function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 100), $utf8)
}
function Read-Json([string]$Path) {
    return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable)
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
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
    if ($result.Contains('native_baseline_handle')) {
        Require ($handle.ToInt64() -eq $result.native_baseline_handle) 'UIA_BASELINE_WINDOW_CHANGED'
    }
    $owner = [uint32]0
    [void][DwmExportWindow]::GetWindowThreadProcessId($handle, [ref]$owner)
    Require ($owner -eq $child.Id) 'WINDOW_PID_MISMATCH'
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
# Copies only already-evaluated gate values; never invokes a provider.
function Copy-EndingActionName([string]$Name) {
    $text = [Text.StringBuilder]::new(); $bytes = 0; $index = 0
    while ($index -lt $Name.Length) {
        $count = if ([char]::IsHighSurrogate($Name[$index]) -and $index + 1 -lt $Name.Length -and [char]::IsLowSurrogate($Name[$index + 1])) { 2 } else { 1 }
        $piece = $Name.Substring($index, $count)
        $size = [Text.Encoding]::UTF8.GetByteCount($piece)
        if ($bytes + $size -gt 1024) { break }
        [void]$text.Append($piece); $bytes += $size; $index += $count
    }
    return @{ text=$text.ToString(); utf8_bytes=$bytes; truncated=($index -lt $Name.Length) }
}
function Observe-EndingAction($Visible, $Enabled, $Name, $Invoke, $Accepted) {
    $batch = $script:endingActionObservation
    if ($null -eq $batch) { return }
    $ordinal = $batch.evaluated_count; $batch.evaluated_count++
    if ($batch.records.Count -ge 4096) { $batch.record_cap_reached=$true; return }
    if ($batch.byte_cap_reached -or $batch.observer_failed) { return }
    try {
    $copy = if ($null -ne $Name) { Copy-EndingActionName $Name } else { $null }
    $entry = [ordered]@{ ordinal=$ordinal; visible=$Visible; enabled=$Enabled;
        name=$(if ($null -ne $copy) { $copy.text } else { $null });
        name_truncated=($null -ne $copy -and $copy.truncated);
        invoke=$Invoke; accepted=$Accepted }
    # Each record is bounded before serialization. Reserve the fixed envelope and
    # 32 additional indentation bytes per line, beyond this record's own pretty JSON.
    # This exceeds its nesting indentation in events.json; commas/CRLF are included.
    $serialized = $entry | ConvertTo-Json -Depth 5
    $lines = ($serialized -split '\r?\n').Count
    $size = [Text.Encoding]::UTF8.GetByteCount($serialized) + ($lines * 34) + 2
    if ($batch.record_bytes + $size + 4096 -gt 1048576) { $batch.byte_cap_reached=$true; return }
    $batch.record_bytes += $size
    [void]$batch.records.Add($entry)
    } catch {
        # Diagnostic copying/serialization must never replace a provider outcome.
        $batch.observer_failed = $true
    }
}
function Actions($Root, [string]$Name) {
    $trace = $null -ne $script:day5Watch
    $queryStart = if ($trace) { $script:day5Watch.Elapsed.TotalSeconds } else { 0 }
    $nodes = @(Nodes $Root)
    if ($null -ne $script:endingActionObservation) { $script:endingActionObservation.descendants=$nodes.Count }
    $candidates = [Collections.Generic.List[object]]::new()
    $matches = @($nodes | Where-Object {
        $pattern = $null
        # Preserve the original gate and short-circuit order. Null means not evaluated.
        $visible = Visible $_
        $enabled = $null; $observedName = $null; $invokable = $null
        $accepted = $false
        if ($visible) {
            $enabled = $_.Current.IsEnabled
            if ($enabled) {
                $observedName = $_.Current.Name.TrimEnd()
                if ($observedName -ceq $Name) {
                    $invokable = $_.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)
                    $accepted = $invokable
                }
            }
        }
        if ($null -ne $script:endingActionObservation) { Observe-EndingAction $visible $enabled $observedName $invokable $accepted }
        if ($trace) {
            # Additional diagnostic reads follow the actual decision; they never admit a target.
            try {
                $diagnosticName = $_.Current.Name
                if ($diagnosticName -cmatch '^TEST Day[45] ') {
                    $current = $_.Current
                    $bounds = $current.BoundingRectangle
                    $diagnosticPattern = $null
                    $diagnosticInvoke = $_.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$diagnosticPattern)
                    $candidates.Add(@{ observed_seconds=$script:day5Watch.Elapsed.TotalSeconds;
                        gate=@{ visible=$visible; enabled=$enabled; name=$observedName; invoke=$invokable; accepted=$accepted };
                        candidate=@{ name=$diagnosticName; type=$current.ControlType.ProgrammaticName;
                            runtime_id=@($_.GetRuntimeId()); enabled=$current.IsEnabled; offscreen=$current.IsOffscreen;
                            rectangle=@($bounds.X, $bounds.Y, $bounds.Width, $bounds.Height); invoke=$diagnosticInvoke } })
                }
            } catch {
                $candidates.Add(@{ observed_seconds=$script:day5Watch.Elapsed.TotalSeconds; diagnostic_error=$_.Exception.Message;
                    gate=@{ visible=$visible; enabled=$enabled; name=$observedName; invoke=$invokable; accepted=$accepted } })
            }
        }
        $accepted
    })
    if ($trace) {
        Record 'day5-poll' @{ query_started_seconds=$queryStart; query_finished_seconds=$script:day5Watch.Elapsed.TotalSeconds;
            deadline_seconds=$StepTimeoutSeconds; descendants=$nodes.Count; matches=$matches.Count; candidates=$candidates.ToArray() }
    }
    return $matches
}
function Wait-One([string]$Name, [scriptblock]$Find) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $trace = $TraceDay5 -and -not $script:day5TraceConsumed -and $Mode -eq 'Load' -and $Name -ceq 'TEST Day5 opening.'
    $nativeGate = $NativeReadyCaptions -and $Mode -eq 'Load' -and
        ($Name -cmatch '^TEST Day[5-7] (opening|closing)\.$' -or $Name -ceq 'TEST Seven-day ending.')
    if ($trace) {
        $script:day5TraceConsumed = $true
        $script:day5Watch = $watch
        Record 'day5-wait-start' @{ name=$Name; deadline_seconds=$StepTimeoutSeconds }
    }
    $endingTrace = $nativeGate -and $Name -ceq 'TEST Seven-day ending.' -and $TraceEndingActions
    $queryOrdinal = 0
    $cpuStart = if ($nativeGate) { $child.TotalProcessorTime.TotalSeconds } else { 0 }
    if ($nativeGate) { Record 'native-caption-wait-start' @{ name=$Name; deadline_seconds=$StepTimeoutSeconds; cpu_total_seconds=$cpuStart } }
    try {
        while ($watch.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) {
            if ($trace -or $nativeGate) {
                $remaining = [int][Math]::Floor(($StepTimeoutSeconds - $watch.Elapsed.TotalSeconds) * 1000)
                if ($remaining -le 0) { break }
                Observe-Native ("caption-before-query: " + $Name) $watch.Elapsed.TotalSeconds ([uint32][Math]::Min(50, $remaining))
                if ($watch.Elapsed.TotalSeconds -ge $StepTimeoutSeconds) { break }
                if ($nativeGate -and -not $script:lastNativeResponds) {
                    $remaining = [int][Math]::Floor(($StepTimeoutSeconds - $watch.Elapsed.TotalSeconds) * 1000)
                    if ($remaining -gt 0) { Start-Sleep -Milliseconds ([Math]::Min(100, $remaining)) }
                    continue
                }
            }
            $windowStart = $watch.Elapsed.TotalSeconds
            $script:window = Window
            if ($nativeGate) { Record 'caption-window-acquisition' @{ name=$Name; started_seconds=$windowStart; finished_seconds=$watch.Elapsed.TotalSeconds; cpu_delta_seconds=($child.TotalProcessorTime.TotalSeconds-$cpuStart) } }
            # Blocking root acquisition must not extend the original acceptance deadline.
            if ($watch.Elapsed.TotalSeconds -ge $StepTimeoutSeconds) {
                Record 'wait-deadline-expired' @{ name=$Name; phase='window'; elapsed_seconds=$watch.Elapsed.TotalSeconds }
                break
            }
            if ($null -ne $window) {
                $findStart = $watch.Elapsed.TotalSeconds
                $batch = $null
                if ($endingTrace) {
                    $script:endingActionObservation = @{ descendants=$null; evaluated_count=0;
                        records=[Collections.Generic.List[object]]::new(); record_bytes=0;
                        record_cap_reached=$false; byte_cap_reached=$false; observer_failed=$false }
                }
                try {
                    $items = @(& $Find)
                    if ($endingTrace) { $batch = $script:endingActionObservation }
                } finally { $script:endingActionObservation = $null }
                if ($nativeGate) {
                    $enumeration = @{ name=$Name; started_seconds=$findStart; finished_seconds=$watch.Elapsed.TotalSeconds; matches=$items.Count }
                    if ($null -ne $batch) {
                        $enumeration.ending_actions = [ordered]@{ schema=1; source='ending-actions-v1'; query_ordinal=$queryOrdinal;
                            descendants=$batch.descendants; evaluated_count=$batch.evaluated_count;
                            observed_count=$batch.records.Count; omitted_count=($batch.evaluated_count-$batch.records.Count);
                            complete=($null -ne $batch.descendants -and $batch.descendants -eq $batch.evaluated_count -and $batch.records.Count -eq $batch.evaluated_count);
                            record_cap_reached=$batch.record_cap_reached; byte_cap_reached=$batch.byte_cap_reached; observer_failed=$batch.observer_failed;
                            record_bytes=$batch.record_bytes; byte_accounting='pretty-json-records-plus-34-bytes-per-line-and-2-per-record;4096-envelope-reserve';
                            limits=@{records=4096; name_utf8_bytes=1024; batch_bytes=1048576}; records=$batch.records.ToArray() }
                    }
                    Record 'caption-action-enumeration' $enumeration
                }
                $queryOrdinal++
                if ($watch.Elapsed.TotalSeconds -ge $StepTimeoutSeconds) {
                    Record 'wait-deadline-expired' @{ name=$Name; phase='find'; elapsed_seconds=$watch.Elapsed.TotalSeconds; late_matches=$items.Count }
                    break
                }
                Require ($items.Count -le 1) "UIA_AMBIGUOUS: $Name ($($items.Count))"
                if ($items.Count -eq 1 -and $watch.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) { return $items[0] }
            }
            $remaining = [int][Math]::Floor(($StepTimeoutSeconds - $watch.Elapsed.TotalSeconds) * 1000)
            if ($remaining -gt 0) { Start-Sleep -Milliseconds ([Math]::Min(100, $remaining)) }
        }
        throw "UIA_UNAVAILABLE_OR_TIMEOUT: $Name"
    } finally {
        if ($nativeGate) {
            $finish = @{ name=$Name; elapsed_seconds=$watch.Elapsed.TotalSeconds }
            try { $finish.cpu_delta_seconds = $child.TotalProcessorTime.TotalSeconds-$cpuStart }
            catch { $finish.cpu_unavailable = $_.Exception.Message }
            Record 'native-caption-wait-end' $finish
        }
        if ($trace) {
            Record 'day5-wait-end' @{ elapsed_seconds=$watch.Elapsed.TotalSeconds }
            $script:day5Watch = $null
        }
    }
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
function Observe-Native([string]$Stage, [double]$Elapsed = 0, [uint32]$Timeout = 250) {
    Check-Live
    $handle = $child.MainWindowHandle
    Require ($handle -ne [IntPtr]::Zero) 'BASELINE_NATIVE_WINDOW_MISSING'
    $owner = [uint32]0
    [void][DwmExportWindow]::GetWindowThreadProcessId($handle, [ref]$owner)
    Require ($owner -eq $child.Id) 'BASELINE_NATIVE_WINDOW_PID_MISMATCH'
    if ($result.Contains('native_baseline_handle')) {
        Require ($handle.ToInt64() -eq $result.native_baseline_handle) 'BASELINE_NATIVE_WINDOW_CHANGED'
    } else { $result.native_baseline_handle = $handle.ToInt64() }
    $responds = [DwmExportWindow]::Responds($handle, $Timeout)
    $script:lastNativeResponds = $responds
    $foreground = [DwmExportWindow]::GetForegroundWindow()
    $foregroundOwner = [uint32]0
    if ($foreground -ne [IntPtr]::Zero) {
        [void][DwmExportWindow]::GetWindowThreadProcessId($foreground, [ref]$foregroundOwner)
    }
    Record 'native-boundary' @{ stage=$Stage; elapsed_seconds=$Elapsed;
        handle=$handle.ToInt64(); pid=$owner; class=[DwmExportWindow]::ClassName($handle);
        hung=[DwmExportWindow]::IsHungAppWindow($handle); responds=$responds; cpu_total_seconds=$child.TotalProcessorTime.TotalSeconds;
        foreground_handle=$foreground.ToInt64(); foreground_pid=$foregroundOwner;
        foreground_class=[DwmExportWindow]::ClassName($foreground);
        foreground_is_game=($foreground -eq $handle) }
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
    $timedWitness = $Mode -eq 'Load' -and $Purpose -ceq 'commit empty slot 2'
    if ($timedWitness) {
        $result.diagnostic_only = $true
        Observe-Native 'before-save-invoke'
        Record 'save-invoke-start' @{}
        $invokeClock = [Diagnostics.Stopwatch]::StartNew()
    }
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    if ($timedWitness) {
        Record 'save-invoke-return' @{ elapsed_seconds=$invokeClock.Elapsed.TotalSeconds }
        Observe-Native 'after-save-invoke' $invokeClock.Elapsed.TotalSeconds
    }
    Start-Sleep -Milliseconds 200
}
function Caption([string]$Text) { return Button $Text }
function Observe-Line([string]$Text, [string]$Stage) {
    $null = Caption $Text
    Capture "$Stage-first-observed"
    # Text naming is not visibility proof. Keep a settled screenshot for independent review.
    Start-Sleep -Milliseconds 1600
    $null = Caption $Text
    Capture $Stage
}
function Advance([string]$From, [string]$To, [string]$Stage) {
    Invoke-UI (Caption $From) "advance: $From"
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
    if ($Mode -eq 'Load' -and $Number -eq 2) {
        Record 'save-file-wait-start' @{}
        $fileClock = [Diagnostics.Stopwatch]::StartNew()
    }
    $document = Wait-File $path
    if ($Mode -eq 'Load' -and $Number -eq 2) {
        Record 'save-file-wait-return' @{ elapsed_seconds=$fileClock.Elapsed.TotalSeconds }
        Observe-Native 'after-save-file' $fileClock.Elapsed.TotalSeconds
    }
    if ($Mode -eq 'Load' -and $Number -eq 2) {
        # Diagnostic only: preserve the original observation budget, without repeated UIA.
        $result.diagnostic_only = $true
        $quiet = [Diagnostics.Stopwatch]::StartNew()
        Record 'quiet-native-start' @{ deadline_seconds=$StepTimeoutSeconds; traversal_policy='one fresh UIA observation after native-only sampling' }
        Capture-FailureSaves 'quiet-before'
        while ($quiet.Elapsed.TotalSeconds -lt $StepTimeoutSeconds) {
            $remaining = [int][Math]::Floor(($StepTimeoutSeconds - $quiet.Elapsed.TotalSeconds) * 1000)
            if ($remaining -le 0) { break }
            Observe-Native 'quiet-sample' $quiet.Elapsed.TotalSeconds ([uint32][Math]::Min(250, $remaining))
            $remaining = [int][Math]::Floor(($StepTimeoutSeconds - $quiet.Elapsed.TotalSeconds) * 1000)
            if ($remaining -gt 0) { Start-Sleep -Milliseconds ([Math]::Min(750, $remaining)) }
        }
        Capture-FailureSaves 'quiet-after'
        Record 'quiet-fresh-uia-start' @{ elapsed_seconds=$quiet.Elapsed.TotalSeconds }
        $script:window = Window
        Require ($null -ne $window) 'QUIET_FRESH_WINDOW_MISSING'
        $observed = @(Nodes $window)
        $saved = @($observed | Where-Object { (Visible $_) -and $_.Current.Name.TrimEnd() -ceq 'Saved' })
        Write-Json (Join-Path $output 'quiet-fresh-uia.json') @($observed | ForEach-Object { Describe $_ })
        Record 'quiet-fresh-uia-result' @{ elapsed_seconds=$quiet.Elapsed.TotalSeconds; descendants=$observed.Count; saved_count=$saved.Count }
        Observe-Native 'after-fresh-uia' $quiet.Elapsed.TotalSeconds
        $result.quiet_observation_completed = $true
        $result.quiet_saved_count = $saved.Count
        # Continuation still requires every ordinary UI, state and clean-exit check below.
        if (-not $ContinueAfterQuiet) { throw 'DIAGNOSTIC_ONLY_QUIET_OBSERVATION_COMPLETE' }
        $result.diagnostic_only = $false
        $result.continued_after_quiet = $true
    }
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
    if ($result.Contains('native_baseline_handle')) {
        $start.ArgumentList.Add('-ExpectedWindowHandle')
        $start.ArgumentList.Add([string]$result.native_baseline_handle)
    }
    $probe = [Diagnostics.Process]::new()
    $probe.StartInfo = $start
    $probeStarted = $false
    $result.native_probe_started_utc = [DateTime]::UtcNow.ToString('o')
    $result.native_probe_timeout_seconds = 15
    try {
        $probeStarted = $probe.Start()
        Require $probeStarted 'DIAGNOSTIC_START_FAILED'
        $stdout = $probe.StandardOutput.ReadToEndAsync()
        $stderr = $probe.StandardError.ReadToEndAsync()
        $complete = $probe.WaitForExit(15000)
        if (-not $complete) { $probe.Kill($true); [void]$probe.WaitForExit(3000) }
        $result.native_probe_completed = $complete
        $result.native_probe_timed_out = -not $complete
        if ([Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),3000)) {
            [IO.File]::WriteAllText((Join-Path $output 'failure-native-probe.stdout.log'),$stdout.GetAwaiter().GetResult(),$utf8)
            [IO.File]::WriteAllText((Join-Path $output 'failure-native-probe.stderr.log'),$stderr.GetAwaiter().GetResult(),$utf8)
        }
    } finally {
        # Also contain the diagnostic child if collection itself throws.
        try {
            if ($probeStarted -and -not $probe.HasExited) {
                $probe.Kill($true); [void]$probe.WaitForExit(3000)
            }
        } finally {
            $result.native_probe_finished_utc = [DateTime]::UtcNow.ToString('o')
            $probe.Dispose()
        }
    }
}

function Capture-FailureSaves([string]$Prefix = 'failure') {
    # Read-only live observations, not an atomic checkpoint or acceptance evidence.
    # Capture before UIA: a provider call may block until the process watchdog fires.
    if ([string]::IsNullOrWhiteSpace($dataRoot)) { return }
    $observations = @()
    foreach ($relative in @('profile.json', 'saves/slot_1.json', 'saves/slot_2.json', 'saves/autosave.json')) {
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
                $name = $Prefix + '-' + ($relative -replace '/', '-')
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
    Write-Json (Join-Path $output "$Prefix-save-observations.json") $observations
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
    if ($Mode -eq 'Load') {
        $creator = Receipt $CreatorReceipt 'Create'
        Require ($creator.user_root -ieq $user) 'CREATOR_USER_ROOT_MISMATCH'
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
    if ($ProfileSaveLoad) {
        # Existing read-only timing hooks in the retained package; no fixture flags.
        $start.Environment['DWM_SAVE_LOAD_PROFILE'] = '1'
        $start.Environment['DWM_CHECKPOINT_PROFILE'] = '1'
        $start.Environment['DWM_SAVE_LOAD_CONTEXT'] = 'exported-load-phase-diagnostic'
    }
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
    if ($Mode -eq 'Load') {
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
        Invoke-UI (Caption 'TEST Seven-day ending.') 'finish ending'
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
    Require (Test-Path -LiteralPath $log -PathType Leaf) 'GAME_LOG_MISSING'
    $logText = (Get-Content -LiteralPath $log -Raw -Encoding utf8) + "`n" + $stdoutRead.GetAwaiter().GetResult() + "`n" + $stderrRead.GetAwaiter().GetResult()
    Require ($logText -notmatch '(?m)SCRIPT ERROR:|^\s*ERROR:|STARTUP_FAILED|Unicode parsing error|Unexpected NUL character') 'GAME_ERROR_LOG'
    $result.renderer_log = @($logText -split '\r?\n' | Where-Object { $_ -match 'Vulkan|OpenGL|D3D12|Direct3D|Rendering' })
    if (Test-Path -LiteralPath $profilePath) { Copy-Item -LiteralPath $profilePath -Destination (Join-Path $output 'profile-after.json') }
    if ($Mode -eq 'Create') { $result.source_profile_sha256 = Hash $profilePath }
    Require (-not [DwmExportWindow]::Expired) 'EXPORTED_PROCESS_WATCHDOG_TIMEOUT'
    $result.ok = $true
} catch {
    $result.failure = $_.Exception.Message
    # Preserve the failed gate before any post-failure provider call can block.
    try {
        Write-Json (Join-Path $output 'failure-boundary.json') ([ordered]@{
            utc=[DateTime]::UtcNow.ToString('o'); failure=$result.failure; diagnostic_only=$true
            process=$(if ($result.Contains('process')) { $result.process } else { $null })
            original_window_handle=$(if ($result.Contains('native_baseline_handle')) { $result.native_baseline_handle } else { $null })
            cleanup_state='not-yet-observed'
        })
    } catch { $result.failure_boundary_error = $_.Exception.Message }
    try { Capture-FailureSaves } catch { $result.save_capture_failure = $_.Exception.Message }
    # The quiet experiment permits exactly one UIA enumeration; generic diagnostics
    # would add a fresh-client enumeration and foreground/capture intervention.
    if (-not $result.Contains('diagnostic_only') -or -not $result.diagnostic_only) {
        try { Capture-FailureWindow } catch { $result.native_probe_failure = $_.Exception.Message }
        try { Capture-FailureStacks } catch { $result.stack_probe_failure = $_.Exception.Message }
        try { if ($null -ne $child -and -not $child.HasExited) { Capture 'failure' } } catch { $result.capture_failure = $_.Exception.Message }
    }
    throw
} finally {
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
    $result.elapsed_seconds = $clock.Elapsed.TotalSeconds
    # Qualify the receipt after existing failure/cleanup decisions; this flag must
    # not change their diagnostic-capture branching.
    if ($TraceEndingActions) {
        $result.diagnostic_only = $true
        $result.ending_actions_trace = $true
        $result.scope = 'Diagnostic-only ending action predicate observation; not official release acceptance'
    }
    Write-Json (Join-Path $output 'result.json') $result
    $evidence = @(Get-ChildItem -LiteralPath $output -File | Sort-Object Name | ForEach-Object {
        @{ file = $_.Name; bytes = $_.Length; sha256 = (Hash $_.FullName) }
    })
    Write-Json (Join-Path $output 'manifest.json') $evidence
}
