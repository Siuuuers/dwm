[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$TestRoot,
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
        [Parameter(Mandatory = $true)][string]$Candidate,
        [switch]$RequireStrictDescendant)
    $rootFull = Get-CanonicalPath $Root
    $candidateFull = Get-CanonicalPath $Candidate
    $inside = $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or
        (Test-StrictDescendant -Root $rootFull -Candidate $candidateFull)
    if (-not $inside -or ($RequireStrictDescendant -and
        $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase))) {
        throw "PATH_CONTAINMENT: '$candidateFull' is outside '$rootFull'."
    }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\', '/')
    $cursor = $rootFull
    $parts = if ($relative.Length -eq 0) { @() } else { @($relative -split '[\\/]') }
    foreach ($part in @('') + $parts) {
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

function Get-UniqueMarker {
    param([Parameter(Mandatory = $true)][string]$Prefix,
        [Parameter(Mandatory = $true)][double]$TimeoutSeconds)
    $poll = [Diagnostics.Stopwatch]::StartNew()
    while ($poll.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if (Test-Path -LiteralPath $script:logFull -PathType Leaf) {
            $markers = @(Get-Content -LiteralPath $script:logFull | Where-Object {
                $_.StartsWith($Prefix, [StringComparison]::Ordinal)
            })
            if ($markers.Count -gt 1) { throw "$($Prefix.Trim())_MARKER_AMBIGUOUS: $($markers.Count)" }
            if ($markers.Count -eq 1) {
                return ConvertFrom-Json -InputObject $markers[0].Substring($Prefix.Length) -ErrorAction Stop
            }
        }
        Start-Sleep -Milliseconds 100
    }
    throw "$($Prefix.Trim())_TIMEOUT: $script:logFull"
}

function Get-ControlViewSnapshot {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Window)
    $elements = $Window.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        [Windows.Automation.Automation]::ControlViewCondition)
    return @($elements | ForEach-Object {
        [ordered]@{
            name = [string]$_.Current.Name
            automation_id = [string]$_.Current.AutomationId
            control_type = [string]$_.Current.ControlType.ProgrammaticName
            enabled = [bool]$_.Current.IsEnabled
            offscreen = [bool]$_.Current.IsOffscreen
            process_id = [int]$_.Current.ProcessId
        }
    })
}

function Get-AuthenticatedWindow {
    param([Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$ExpectedTitle)
    $poll = [Diagnostics.Stopwatch]::StartNew()
    while ($poll.Elapsed.TotalSeconds -lt 5) {
        $Process.Refresh()
        if ($Process.MainWindowHandle -ne [IntPtr]::Zero -and
            $Process.MainWindowTitle -ceq $ExpectedTitle) {
            $candidate = [Windows.Automation.AutomationElement]::FromHandle($Process.MainWindowHandle)
            if ($null -ne $candidate -and $candidate.Current.ProcessId -eq $Process.Id) {
                return $candidate
            }
        }
        Start-Sleep -Milliseconds 100
    }
    $Process.Refresh()
    throw "UIA_WINDOW_NOT_FOUND: expected='$ExpectedTitle' actual='$($Process.MainWindowTitle)' handle=$($Process.MainWindowHandle) pid=$($Process.Id)"
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$phaseTestsRoot = Get-CanonicalPath (Join-Path $repositoryRoot '.godot\phase2r_tests')
$logFull = Get-CanonicalPath $LogPath
$testRootFull = Assert-ContainedNonReparseChain -Root $phaseTestsRoot -Candidate $TestRoot `
    -RequireStrictDescendant
if (-not (Test-Path -LiteralPath $testRootFull -PathType Container) -or
    -not (Test-StrictDescendant -Root $phaseTestsRoot -Candidate $testRootFull)) {
    throw "TEST_ROOT_INVALID: $testRootFull"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = $logFull + '.uia.json' }
$outputFull = Get-CanonicalPath $OutputPath
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFull) -PathType Container)) {
    throw "OUTPUT_PARENT_MISSING: $outputFull"
}

$sourceReady = Get-UniqueMarker -Prefix 'SOURCE_READY ' -TimeoutSeconds 15
$targetPid = [int]$sourceReady.pid
$expectedTitle = "DWM Witnessed Reading Recovery Accessibility $targetPid"
$sourceLabel = 'Reading recovery source probe'
if ($targetPid -le 0 -or [string]$sourceReady.window_title -cne $expectedTitle -or
    [string]$sourceReady.source_label -cne $sourceLabel -or
    [bool]$sourceReady.source_accessibility_withdrawn) {
    throw 'SOURCE_READY_CONTRACT_INVALID'
}
$ackFull = Assert-ContainedNonReparseChain -Root $testRootFull `
    -Candidate ([string]$sourceReady.acknowledge_file) -RequireStrictDescendant
if (-not (Test-StrictDescendant -Root $testRootFull -Candidate $ackFull) -or
    -not (Test-Path -LiteralPath (Split-Path -Parent $ackFull) -PathType Container) -or
    (Test-Path -LiteralPath $ackFull)) {
    throw "SOURCE_ACK_INVALID: $ackFull"
}

$process = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $targetPid"
if ($null -eq $process -or [string]::IsNullOrWhiteSpace([string]$process.CommandLine)) {
    throw "SOURCE_PROCESS_NOT_LIVE: $targetPid"
}
$commandLine = [string]$process.CommandLine
$scriptArgument = 'res://tests/manual/witnessed_reading_recovery_capture.gd'
foreach ($required in @($repositoryRoot, $logFull, $scriptArgument, '--native-invoke',
        '--display-driver windows', '--accessibility always')) {
    if ($commandLine.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "SOURCE_PROCESS_COMMAND_MISMATCH: missing '$required' pid=$targetPid"
    }
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$nativeProcess = [Diagnostics.Process]::GetProcessById($targetPid)
$window = Get-AuthenticatedWindow -Process $nativeProcess -ExpectedTitle $expectedTitle
$sourceTree = Get-ControlViewSnapshot -Window $window
$sourceMatches = @($sourceTree | Where-Object {
    $_.name.TrimEnd() -ceq $sourceLabel -and $_.control_type -ceq 'ControlType.Text'
})
if ($sourceMatches.Count -ne 1 -or $sourceMatches[0].offscreen) {
    throw "SOURCE_PROBE_NOT_UNIQUELY_VISIBLE: count=$($sourceMatches.Count) pid=$targetPid"
}

$utf8NoBom = New-Object Text.UTF8Encoding($false)
$ack = ConvertTo-Json -Compress -InputObject ([ordered]@{
    pid = $targetPid
    observed_label = $sourceLabel
    observed_at_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
})
[IO.File]::WriteAllText($ackFull, $ack + "`n", $utf8NoBom)

$ready = Get-UniqueMarker -Prefix 'READY ' -TimeoutSeconds 15
if ([int]$ready.pid -ne $targetPid -or [string]$ready.window_title -cne $expectedTitle -or
    [string]$ready.control -cne 'Retry' -or [string]$ready.expected_caption -cne 'Retry' -or
    [string]$ready.withdrawn_source_label -cne $sourceLabel -or
    -not [bool]$ready.programmatic_pressed_rejected -or
    [int]$ready.activations -ne 0 -or [int]$ready.physical_contacts -ne 0) {
    throw 'READY_CONTRACT_INVALID'
}
$sourceImageFull = Assert-ContainedNonReparseChain -Root $testRootFull `
    -Candidate ([string]$ready.source_image) -RequireStrictDescendant
if (-not (Test-StrictDescendant -Root $testRootFull -Candidate $sourceImageFull) -or
    -not (Test-Path -LiteralPath $sourceImageFull -PathType Leaf)) {
    throw "SOURCE_IMAGE_INVALID: $sourceImageFull"
}

$liveProcess = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $targetPid"
if ($null -eq $liveProcess -or [string]$liveProcess.CommandLine -cne $commandLine) {
    throw "READY_PROCESS_CHANGED: $targetPid"
}
$window = Get-AuthenticatedWindow -Process $nativeProcess -ExpectedTitle $expectedTitle
$recoveryTree = Get-ControlViewSnapshot -Window $window
$withdrawnMatches = @($recoveryTree | Where-Object { $_.name.TrimEnd() -ceq $sourceLabel })
if ($withdrawnMatches.Count -ne 0) {
    throw "WITHDRAWN_SOURCE_STILL_IN_CONTROL_VIEW: $($withdrawnMatches.Count)"
}
$retryMatches = @($recoveryTree | Where-Object {
    $_.name.TrimEnd() -ceq 'Retry' -and $_.control_type -ceq 'ControlType.Button'
})
if ($retryMatches.Count -ne 1 -or -not $retryMatches[0].enabled) {
    throw "UIA_RETRY_NOT_UNIQUE_ENABLED: count=$($retryMatches.Count) pid=$targetPid"
}
$recoveryElements = $window.FindAll(
    [Windows.Automation.TreeScope]::Descendants,
    [Windows.Automation.Automation]::ControlViewCondition)
$retryElements = @($recoveryElements | Where-Object {
    $_.Current.Name.TrimEnd() -ceq 'Retry' -and
    $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button
})
$retry = $retryElements[0]
if ($null -eq $retry -or -not $retry.Current.IsEnabled) {
    throw "UIA_RETRY_ELEMENT_LOST: $targetPid"
}
$invokeObject = $null
if (-not $retry.TryGetCurrentPattern(
        [Windows.Automation.InvokePattern]::Pattern, [ref]$invokeObject)) {
    throw "UIA_INVOKE_PATTERN_MISSING: Retry pid=$targetPid"
}
$retrySnapshot = [ordered]@{
    name = [string]$retry.Current.Name
    reported_process_id = [int]$retry.Current.ProcessId
    automation_id = [string]$retry.Current.AutomationId
    control_type = [string]$retry.Current.ControlType.ProgrammaticName
    enabled_before_invoke = [bool]$retry.Current.IsEnabled
    help_text = [string]$retry.Current.HelpText
}
$windowSnapshot = [ordered]@{
    name = [string]$window.Current.Name
    process_id = [int]$window.Current.ProcessId
    automation_id = [string]$window.Current.AutomationId
    native_window_handle = [int64]$nativeProcess.MainWindowHandle
    native_title = [string]$nativeProcess.MainWindowTitle
}
$retry.SetFocus()
([Windows.Automation.InvokePattern]$invokeObject).Invoke()

$record = [ordered]@{
    schema_version = 1
    invoked_at_utc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    source_log_path = $logFull
    target = [ordered]@{
        pid = $targetPid
        repository_root = $repositoryRoot
        test_root = $testRootFull
        script = $scriptArgument
        control = 'Retry'
    }
    process = [ordered]@{
        process_id = [int]$process.ProcessId
        name = [string]$process.Name
        command_line = $commandLine
    }
    window = $windowSnapshot
    source_phase = [ordered]@{
        unique_visible_probe = $true
        acknowledge_file = $ackFull
        source_image = $sourceImageFull
        control_view = $sourceTree
    }
    recovery_phase = [ordered]@{
        source_probe_absent = $true
        retry_unique_enabled = $true
        control_view = $recoveryTree
    }
    element = $retrySnapshot
    native_method = 'Windows.UIAutomation.InvokePattern.Invoke'
    invocation_count = 1
}
$json = ConvertTo-Json -InputObject $record -Depth 8 -Compress
$temporary = $outputFull + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
try {
    [IO.File]::WriteAllText($temporary, $json + "`n", $utf8NoBom)
    if (Test-Path -LiteralPath $outputFull -PathType Leaf) {
        [IO.File]::Replace($temporary, $outputFull, $null)
    } else {
        [IO.File]::Move($temporary, $outputFull)
    }
} finally {
    if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) }
}
[Console]::Out.WriteLine($json)
