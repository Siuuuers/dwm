[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\', '/')
$logFull = [IO.Path]::GetFullPath($LogPath)
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = $logFull + '.uia.json' }
$outputFull = [IO.Path]::GetFullPath($OutputPath)
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFull) -PathType Container)) {
    throw "OUTPUT_PARENT_MISSING: $outputFull"
}

$ready = $null
$poll = [Diagnostics.Stopwatch]::StartNew()
while ($poll.Elapsed.TotalSeconds -lt 15) {
    if (Test-Path -LiteralPath $logFull -PathType Leaf) {
        $markers = @(Get-Content -LiteralPath $logFull | Where-Object { $_.StartsWith('READY ', [StringComparison]::Ordinal) })
        if ($markers.Count -gt 1) { throw "READY_MARKER_AMBIGUOUS: $($markers.Count)" }
        if ($markers.Count -eq 1) {
            $ready = ConvertFrom-Json -InputObject $markers[0].Substring(6) -ErrorAction Stop
            break
        }
    }
    Start-Sleep -Milliseconds 100
}
if ($null -eq $ready) { throw "READY_TIMEOUT: $logFull" }

$targetPid = [int]$ready.pid
$expectedTitle = "DWM Witnessed Transport Accessibility $targetPid"
if ($targetPid -le 0 -or [string]$ready.window_title -cne $expectedTitle -or
    [string]$ready.expected_caption -cne ('Skip: Skip ' + [char]0x00b7 + ' Off') -or -not [bool]$ready.programmatic_pressed_rejected -or
    [int]$ready.activations -ne 0 -or [int]$ready.physical_contacts -ne 0) {
    throw 'READY_CONTRACT_INVALID'
}

$process = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $targetPid"
if ($null -eq $process -or [string]::IsNullOrWhiteSpace([string]$process.CommandLine)) {
    throw "READY_PROCESS_NOT_LIVE: $targetPid"
}
$commandLine = [string]$process.CommandLine
$scriptArgument = 'res://tests/manual/witnessed_transport_capture.gd'
if ($commandLine.IndexOf($repositoryRoot, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
    $commandLine.IndexOf($scriptArgument, [StringComparison]::Ordinal) -lt 0) {
    throw "READY_PROCESS_COMMAND_MISMATCH: $targetPid"
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$nativeProcess = [Diagnostics.Process]::GetProcessById($targetPid)
$window = $null
$button = $null
$uiaPoll = [Diagnostics.Stopwatch]::StartNew()
while ($uiaPoll.Elapsed.TotalSeconds -lt 5 -and $null -eq $button) {
    $nativeProcess.Refresh()
    $handle = $nativeProcess.MainWindowHandle
    if ($handle -ne [IntPtr]::Zero -and $nativeProcess.MainWindowTitle -ceq $expectedTitle) {
        $window = [Windows.Automation.AutomationElement]::FromHandle($handle)
        if ($null -eq $window -or $window.Current.ProcessId -ne $targetPid) {
            $window = $null
            Start-Sleep -Milliseconds 100
            continue
        }
        $descendants = $window.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition)
        $buttons = @($descendants | Where-Object {
            $_.Current.Name.TrimEnd() -ceq [string]$ready.expected_caption -and
            $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button
        })
        if ($buttons.Count -gt 1) { throw "UIA_BUTTON_AMBIGUOUS: $($buttons.Count)" }
        if ($buttons.Count -eq 1) { $button = $buttons[0]; break }
    }
    Start-Sleep -Milliseconds 100
}
if ($null -eq $window) {
    $nativeProcess.Refresh()
    throw "UIA_WINDOW_NOT_FOUND: expected='$expectedTitle' actual='$($nativeProcess.MainWindowTitle)' handle=$($nativeProcess.MainWindowHandle) pid=$targetPid"
}
if ($null -eq $button) {
    $observed = @($descendants | ForEach-Object {
        [ordered]@{ name = $_.Current.Name; type = $_.Current.ControlType.ProgrammaticName; enabled = $_.Current.IsEnabled }
    })
    $discovery = ConvertTo-Json -InputObject ([ordered]@{ discovery_only = $true; pid = $targetPid; elements = $observed }) -Depth 5 -Compress
    [IO.File]::WriteAllText($outputFull, $discovery, (New-Object Text.UTF8Encoding($false)))
    [Console]::Out.WriteLine($discovery)
    throw "UIA_BUTTON_NOT_FOUND: Skip pid=$targetPid"
}

$invokeObject = $null
if (-not $button.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$invokeObject)) {
    throw "UIA_INVOKE_PATTERN_MISSING: Skip pid=$targetPid"
}
$button.SetFocus()
([Windows.Automation.InvokePattern]$invokeObject).Invoke()

$record = [ordered]@{
    schema_version = 1
    invoked_at_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    source_log_path = $logFull
    target = [ordered]@{ pid = $targetPid; repository_root = $repositoryRoot; script = $scriptArgument }
    process = [ordered]@{ process_id = [int]$process.ProcessId; name = [string]$process.Name; command_line = $commandLine }
    window = [ordered]@{ name = [string]$window.Current.Name; process_id = [int]$window.Current.ProcessId; automation_id = [string]$window.Current.AutomationId; native_window_handle = [int64]$nativeProcess.MainWindowHandle; native_title = [string]$nativeProcess.MainWindowTitle }
    element = [ordered]@{ name = [string]$button.Current.Name; reported_process_id = [int]$button.Current.ProcessId; automation_id = [string]$button.Current.AutomationId; control_type = [string]$button.Current.ControlType.ProgrammaticName; enabled = [bool]$button.Current.IsEnabled }
    native_method = 'Windows.UIAutomation.InvokePattern.Invoke'
}
$json = ConvertTo-Json -InputObject $record -Depth 6 -Compress
$temporary = $outputFull + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
try {
    [IO.File]::WriteAllText($temporary, $json + "`n", $utf8NoBom)
    if (Test-Path -LiteralPath $outputFull -PathType Leaf) { [IO.File]::Replace($temporary, $outputFull, $null) }
    else { [IO.File]::Move($temporary, $outputFull) }
} finally {
    if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) }
}
[Console]::Out.WriteLine($json)
