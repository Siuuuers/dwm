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
    $json = ConvertTo-Json -InputObject $Value -Depth 10 -Compress
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, $json + "`n", $script:utf8NoBom)
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($temporary, $Path, $null)
        } else {
            [IO.File]::Move($temporary, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) }
    }
    return $json
}

function Get-AvailablePatterns {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Element)
    return @($Element.GetSupportedPatterns() | ForEach-Object { [string]$_.ProgrammaticName })
}

function Get-TreeSnapshot {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Window,
        [Parameter(Mandatory = $true)][Windows.Automation.Condition]$Condition)
    $elements = $Window.FindAll(
        [Windows.Automation.TreeScope]::Descendants, $Condition)
    return @($elements | ForEach-Object {
        [ordered]@{
            name = [string]$_.Current.Name
            process_id = [int]$_.Current.ProcessId
            automation_id = [string]$_.Current.AutomationId
            control_type = [string]$_.Current.ControlType.ProgrammaticName
            enabled = [bool]$_.Current.IsEnabled
            offscreen = [bool]$_.Current.IsOffscreen
            keyboard_focusable = [bool]$_.Current.IsKeyboardFocusable
            has_keyboard_focus = [bool]$_.Current.HasKeyboardFocus
            patterns = @(Get-AvailablePatterns -Element $_)
        }
    })
}

function Get-SelectionState {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Element)
    $pattern = $null
    $available = $Element.TryGetCurrentPattern(
        [Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)
    $container = if ($available) {
        ([Windows.Automation.SelectionItemPattern]$pattern).Current.SelectionContainer
    } else { $null }
    return [ordered]@{
        available = [bool]$available
        container_type = if ($null -ne $container) { $container.Current.ControlType.ProgrammaticName } else { '' }
        container_name = if ($null -ne $container) { $container.Current.Name.TrimEnd() } else { '' }
        selected = if ($available) {
            [bool]([Windows.Automation.SelectionItemPattern]$pattern).Current.IsSelected
        } else { $null }
    }
}

function Get-InteractiveRows {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Window,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTitles)
    $elements = $Window.FindAll(
        [Windows.Automation.TreeScope]::Descendants,
        [Windows.Automation.Automation]::ControlViewCondition)
    return @($elements | Where-Object {
        $name = $_.Current.Name.TrimEnd()
        $type = $_.Current.ControlType
        $ExpectedTitles -ccontains $name -and
            ($type -eq [Windows.Automation.ControlType]::Button -or
                $type -eq [Windows.Automation.ControlType]::ListItem)
    })
}

function Get-RowSnapshot {
    param([Parameter(Mandatory = $true)][Windows.Automation.AutomationElement]$Element)
    $selection = Get-SelectionState -Element $Element
    $invoke = $null
    $hasInvoke = $Element.TryGetCurrentPattern(
        [Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)
    return [ordered]@{
        name = [string]$Element.Current.Name.TrimEnd()
        process_id = [int]$Element.Current.ProcessId
        automation_id = [string]$Element.Current.AutomationId
        control_type = [string]$Element.Current.ControlType.ProgrammaticName
        enabled = [bool]$Element.Current.IsEnabled
        keyboard_focusable = [bool]$Element.Current.IsKeyboardFocusable
        has_keyboard_focus = [bool]$Element.Current.HasKeyboardFocus
        patterns = @(Get-AvailablePatterns -Element $Element)
        invoke_pattern = [bool]$hasInvoke
        selection_item_pattern = [bool]$selection.available
        selection_container_type = $selection.container_type
        selection_container_name = $selection.container_name
        selected = $selection.selected
    }
}

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    [void]$script:failures.Add($Message)
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
$completionFull = $null
$targetPid = 0
$expectedTitle = ''
$expectedTitles = @()
$processRecord = $null
$windowRecord = $null
$initialRows = @()
$finalRows = @()
$rawTree = @()
$controlTree = @()
$invoked = $false
$selectionMethod = 'none'

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
        Start-Sleep -Milliseconds 100
    }
    if ($null -eq $ready) { throw "READY_TIMEOUT: $logFull" }

    $completionFull = Assert-ContainedNonReparseChain -Root $phaseTestsRoot `
        -Candidate ([string]$ready.completion_path)
    $testRoot = Split-Path -Parent $completionFull
    $runRoot = Split-Path -Parent $testRoot
    $runParent = Get-CanonicalPath (Split-Path -Parent $runRoot)
    $runId = Split-Path -Leaf $runRoot
    $parsedRunId = [guid]::Empty
    if ((Split-Path -Leaf $completionFull) -cne 'gallery-selection-complete.json' -or
        (Split-Path -Leaf $testRoot) -cne 'dwm_test_root' -or
        -not $runParent.Equals($phaseTestsRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not [guid]::TryParse($runId, [ref]$parsedRunId) -or
        -not (Test-Path -LiteralPath $testRoot -PathType Container)) {
        $completionFull = $null
        throw 'READY_COMPLETION_PATH_INVALID'
    }

    $targetPid = [int]$ready.pid
    $expectedTitle = "DWM Gallery Selection $targetPid"
    $expectedTitles = @($ready.expected_titles | ForEach-Object { [string]$_ })
    if ($targetPid -le 0 -or [string]$ready.window_title -cne $expectedTitle -or
        $expectedTitles.Count -ne 2 -or
        [string]::IsNullOrWhiteSpace($expectedTitles[0]) -or
        [string]::IsNullOrWhiteSpace($expectedTitles[1]) -or
        $expectedTitles[0] -ceq $expectedTitles[1]) {
        throw 'READY_CONTRACT_INVALID'
    }

    $process = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $targetPid"
    if ($null -eq $process -or [string]::IsNullOrWhiteSpace([string]$process.CommandLine)) {
        throw "READY_PROCESS_NOT_LIVE: $targetPid"
    }
    $commandLine = [string]$process.CommandLine
    $scriptArgument = 'res://tests/manual/verify_gallery_selection_accessibility.gd'
    foreach ($required in @($repositoryRoot, $scriptArgument, '--display-driver windows',
            '--accessibility always')) {
        if ($commandLine.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "READY_PROCESS_COMMAND_MISMATCH: missing '$required' pid=$targetPid"
        }
    }
    $processRecord = [ordered]@{
        process_id = [int]$process.ProcessId
        name = [string]$process.Name
        command_line = $commandLine
    }

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $nativeProcess = [Diagnostics.Process]::GetProcessById($targetPid)
    $window = $null
    $authenticatedWindow = $null
    $rows = @()
    $uiaPoll = [Diagnostics.Stopwatch]::StartNew()
    while ($uiaPoll.Elapsed.TotalSeconds -lt 5) {
        $nativeProcess.Refresh()
        if ($nativeProcess.MainWindowHandle -ne [IntPtr]::Zero -and
            $nativeProcess.MainWindowTitle -ceq $expectedTitle) {
            $candidate = [Windows.Automation.AutomationElement]::FromHandle(
                $nativeProcess.MainWindowHandle)
            if ($null -ne $candidate -and $candidate.Current.ProcessId -eq $targetPid) {
                $authenticatedWindow = $candidate
                $candidateRows = @(Get-InteractiveRows -Window $candidate `
                    -ExpectedTitles $expectedTitles)
                $rows = $candidateRows
                if ($candidateRows.Count -eq 2) {
                    $window = $candidate
                    $rows = $candidateRows
                    break
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($null -eq $window) {
        $nativeProcess.Refresh()
        if ($null -eq $authenticatedWindow) {
            throw "UIA_WINDOW_NOT_FOUND: expected='$expectedTitle' actual='$($nativeProcess.MainWindowTitle)' pid=$targetPid"
        }
        $window = $authenticatedWindow
        $windowRecord = [ordered]@{
            name = [string]$window.Current.Name
            process_id = [int]$window.Current.ProcessId
            automation_id = [string]$window.Current.AutomationId
            native_window_handle = [int64]$nativeProcess.MainWindowHandle
            native_title = [string]$nativeProcess.MainWindowTitle
        }
        $rawTree = @(Get-TreeSnapshot -Window $window `
            -Condition ([Windows.Automation.Condition]::TrueCondition))
        $controlTree = @(Get-TreeSnapshot -Window $window `
            -Condition ([Windows.Automation.Automation]::ControlViewCondition))
        throw "UIA_ROWS_NOT_FOUND: count=$($rows.Count) expected='$($expectedTitles -join '|')' pid=$targetPid"
    }
    $windowRecord = [ordered]@{
        name = [string]$window.Current.Name
        process_id = [int]$window.Current.ProcessId
        automation_id = [string]$window.Current.AutomationId
        native_window_handle = [int64]$nativeProcess.MainWindowHandle
        native_title = [string]$nativeProcess.MainWindowTitle
    }

    $observedTitles = @($rows | ForEach-Object { [string]$_.Current.Name.TrimEnd() })
    if ($observedTitles.Count -ne 2 -or $observedTitles[0] -cne $expectedTitles[0] -or
        $observedTitles[1] -cne $expectedTitles[1]) {
        Add-Failure "UIA_ROW_ORDER: observed='$($observedTitles -join '|')'"
    }
    foreach ($title in $expectedTitles) {
        if (@($rows | Where-Object { $_.Current.Name.TrimEnd() -ceq $title }).Count -ne 1) {
            Add-Failure "UIA_ROW_NOT_UNIQUE: $title"
        }
    }

    $initialRows = @($rows | ForEach-Object { Get-RowSnapshot -Element $_ })
    foreach ($row in $initialRows) {
        if ($row.control_type -cne 'ControlType.ListItem' -or
            $row.selection_container_type -cne 'ControlType.List' -or
            $row.selection_container_name -cne '') {
            Add-Failure 'UIA_RECORD_LIST_SEMANTICS_INVALID'
        }
    }
    if (-not $initialRows[0].selection_item_pattern -or
        -not $initialRows[1].selection_item_pattern) {
        Add-Failure 'UIA_SELECTION_ITEM_PATTERN_MISSING'
    } elseif (-not [bool]$initialRows[0].selected -or [bool]$initialRows[1].selected) {
        Add-Failure "UIA_INITIAL_SELECTION_INVALID: $($initialRows[0].selected),$($initialRows[1].selected)"
    }
    if (-not $initialRows[1].keyboard_focusable) {
        Add-Failure "UIA_FOCUS_NOT_AVAILABLE: $($expectedTitles[1])"
    }

    # Select must change the record before SetFocus can mask a broken action.
    $selectionObject = $null
    if ($rows[1].TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern, [ref]$selectionObject)) {
        try {
            ([Windows.Automation.SelectionItemPattern]$selectionObject).Select()
            $selectionMethod = 'Windows.UIAutomation.SelectionItemPattern.Select'
            $invoked = $true
        } catch {
            Add-Failure "UIA_SELECT_FAILED: $($_.Exception.Message)"
        }
    } else {
        $invokeObject = $null
        if ($rows[1].TryGetCurrentPattern(
                [Windows.Automation.InvokePattern]::Pattern, [ref]$invokeObject)) {
            ([Windows.Automation.InvokePattern]$invokeObject).Invoke()
            $selectionMethod = 'Windows.UIAutomation.InvokePattern.Invoke (baseline)'
            $invoked = $true
        }
    }

    $selectionChanged = $false
    $statePoll = [Diagnostics.Stopwatch]::StartNew()
    while ($statePoll.Elapsed.TotalSeconds -lt 5) {
        $candidateRows = @(Get-InteractiveRows -Window $window -ExpectedTitles $expectedTitles)
        if ($candidateRows.Count -eq 2) {
            $candidateTitles = @($candidateRows | ForEach-Object {
                [string]$_.Current.Name.TrimEnd()
            })
            if ($candidateTitles[0] -ceq $expectedTitles[0] -and
                $candidateTitles[1] -ceq $expectedTitles[1]) {
                $firstState = Get-SelectionState -Element $candidateRows[0]
                $secondState = Get-SelectionState -Element $candidateRows[1]
                if ($firstState.available -and $secondState.available -and
                    -not [bool]$firstState.selected -and [bool]$secondState.selected) {
                    $rows = $candidateRows
                    $selectionChanged = $true
                    break
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not $selectionChanged) { Add-Failure 'UIA_SELECTION_DID_NOT_INVERT' }

    try {
        $rows[1].SetFocus()
        $focusPoll = [Diagnostics.Stopwatch]::StartNew()
        while (-not $rows[1].Current.HasKeyboardFocus -and $focusPoll.Elapsed.TotalSeconds -lt 2) {
            Start-Sleep -Milliseconds 50
        }
    } catch {
        Add-Failure "UIA_SET_FOCUS_FAILED: $($_.Exception.Message)"
    }

    $rows = @(Get-InteractiveRows -Window $window -ExpectedTitles $expectedTitles)
    if ($rows.Count -ne 2) {
        Add-Failure "UIA_FINAL_ROW_COUNT: $($rows.Count)"
    } else {
        $finalRows = @($rows | ForEach-Object { Get-RowSnapshot -Element $_ })
        $finalTitles = @($finalRows | ForEach-Object { [string]$_.name })
        if ($finalTitles[0] -cne $expectedTitles[0] -or
            $finalTitles[1] -cne $expectedTitles[1]) {
            Add-Failure "UIA_FINAL_ROW_ORDER: observed='$($finalTitles -join '|')'"
        }
        if (-not $finalRows[1].selection_item_pattern) {
            Add-Failure "UIA_FINAL_SELECTION_PATTERN_MISSING: $($expectedTitles[1])"
        }
        if (-not $finalRows[1].keyboard_focusable -or
            -not $finalRows[1].has_keyboard_focus) {
            Add-Failure "UIA_FINAL_FOCUS_LOST: $($expectedTitles[1])"
        }
    }
} catch {
    Add-Failure $_.Exception.Message
} finally {
    $ok = $failures.Count -eq 0
    $code = if ($ok) { 'ok' } else { 'gallery_selection_accessibility_failed' }
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
            script = 'res://tests/manual/verify_gallery_selection_accessibility.gd'
            expected_window_title = $expectedTitle
            expected_titles = @($expectedTitles)
            completion_path = $completionFull
        }
        process = $processRecord
        window = $windowRecord
        initial_rows = @($initialRows)
        final_rows = @($finalRows)
        raw_descendants = @($rawTree)
        control_descendants = @($controlTree)
        native_actions = [ordered]@{
            method = $selectionMethod
            focus_after_selection = $true
            invoked = $invoked
        }
    }
    try {
        $json = Write-AtomicJson -Path $outputFull -Value $record
        [Console]::Out.WriteLine($json)
    } catch {
        [Console]::Error.WriteLine("EVIDENCE_WRITE_FAILED: $($_.Exception.Message)")
        $ok = $false
        $code = 'gallery_selection_evidence_write_failed'
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
