[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\', '/')
$identity = [guid]::NewGuid().ToString('N')
$output = Join-Path $repositoryRoot '.godot/ci/caption-native'
$isolated = Join-Path $repositoryRoot ".godot/phase2r_tests/caption-native-$identity"
$log = Join-Path $output 'godot.log'
$scriptArgument = 'res://tests/manual/verify_caption_native_accept.gd'
$utf8 = New-Object Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force -Path $output, $isolated | Out-Null
if (Test-Path -LiteralPath $log) { throw 'NATIVE_CAPTION_OUTPUT_NOT_FRESH' }
if (-not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf)) { throw 'GODOT_MISSING' }

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$observations = New-Object Collections.Generic.List[object]
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
    @{ stage = 'review-return'; event_index = 3; revealing = $true; finished = 3; review_offset = 1; target_index = 2 },
    @{ stage = 'fresh-reveal'; event_index = 3; revealing = $true; finished = 3; review_offset = 0; target_index = 3 },
    @{ stage = 'fresh-advance'; event_index = 3; revealing = $false; finished = 4; review_offset = 0; target_index = 3 }
)

function Read-Stage([string]$Stage) {
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while ($deadline.Elapsed.TotalSeconds -lt 40) {
        if (Test-Path -LiteralPath $log) {
            $lines = @(Get-Content -LiteralPath $log)
            if ($lines | Select-String -Pattern 'SCRIPT ERROR:|CAPTION_RESULT .*"ok":false') {
                throw "CAPTION_RUNTIME_FAILED: $Stage"
            }
            $records = @($lines | Where-Object { $_.StartsWith('CAPTION_READY ') } |
                ForEach-Object { $_.Substring(14) | ConvertFrom-Json } | Where-Object { $_.stage -ceq $Stage })
            if ($records.Count -gt 1) { throw "AMBIGUOUS_STAGE: $Stage" }
            if ($records.Count -eq 1) { return $records[0] }
        }
        if ($child.HasExited) { throw "CAPTION_CHILD_EXITED: $Stage" }
        Start-Sleep -Milliseconds 100
    }
    throw "CAPTION_STAGE_TIMEOUT: $Stage"
}

function Invoke-Caption([object]$Ready, [object]$Expected) {
    $targetPid = [int]$Ready.pid
    $title = "DWM Native Caption Accept $targetPid"
    $isReview = $Expected.review_offset -eq 1
    if ($Ready.window_title -cne $title -or $targetPid -le 0 -or $Ready.physical_contacts -ne 0 -or
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
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $targetPid"
    if ($null -eq $process -or [string]$process.CommandLine -notlike "*$repositoryRoot*" -or
        [string]$process.CommandLine -notlike "*$scriptArgument*") { throw 'CAPTION_PROCESS_MISMATCH' }
    $native = [Diagnostics.Process]::GetProcessById($targetPid)
    $window = $null
    $target = $null
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while ($deadline.Elapsed.TotalSeconds -lt 10) {
        $native.Refresh()
        if ($native.MainWindowHandle -ne [IntPtr]::Zero -and $native.MainWindowTitle -ceq $title) {
            $window = [Windows.Automation.AutomationElement]::FromHandle($native.MainWindowHandle)
            if ($window.Current.ProcessId -ne $targetPid) { throw 'CAPTION_WINDOW_PROCESS_MISMATCH' }
            $elements = $window.FindAll([Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition)
            $snapshot = @($elements | ForEach-Object {
                [ordered]@{ name = $_.Current.Name; type = $_.Current.ControlType.ProgrammaticName;
                    enabled = $_.Current.IsEnabled; offscreen = $_.Current.IsOffscreen;
                    automation_id = $_.Current.AutomationId;
                    patterns = @($_.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName }) }
            })
            [IO.File]::WriteAllText((Join-Path $output ($Ready.stage + '-tree.json')),
                (ConvertTo-Json -InputObject $snapshot -Depth 8), $utf8)
            # Match the visible action's text, which differs from live text in review.
            $matches = @($elements | Where-Object {
                $_.Current.Name.TrimEnd() -ceq $Ready.target_text -and -not $_.Current.IsOffscreen
            })
            $actionable = @($matches | Where-Object {
                $candidatePattern = $null
                $_.Current.IsEnabled -and $_.TryGetCurrentPattern(
                    [Windows.Automation.InvokePattern]::Pattern, [ref]$candidatePattern)
            })
            if ($actionable.Count -gt 1) { throw 'CAPTION_UIA_AMBIGUOUS' }
            if ($actionable.Count -eq 1) { $target = $actionable[0]; break }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($null -eq $target) { throw "CAPTION_UIA_NOT_FOUND: $($Ready.stage)" }
    $pattern = $null
    if (-not $target.Current.IsEnabled -or
        -not $target.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw 'CAPTION_INVOKE_PATTERN_MISSING'
    }
    $runtimeId = @($target.GetRuntimeId())
    if ($isReview -and $observations.Count -gt 0 -and
        ($runtimeId -join ',') -ceq ($observations[$observations.Count - 1].runtime_id -join ',')) {
        throw 'CAPTION_REVIEW_REUSED_LIVE_TARGET'
    }
    $observation = [ordered]@{ stage = $Ready.stage; pid = $targetPid; window = $window.Current.Name;
        name = $target.Current.Name; type = $target.Current.ControlType.ProgrammaticName;
        runtime_id = $runtimeId; command_line = $process.CommandLine;
        method = 'Windows.UIAutomation.InvokePattern.Invoke'; invocations = 1; ready = $Ready }
    # No SetFocus or callback substitution. Never retry an invocation on timeout.
    ([Windows.Automation.InvokePattern]$pattern).Invoke()
    $observations.Add($observation)
    [IO.File]::WriteAllText((Join-Path $output 'invocations.json'),
        (ConvertTo-Json -InputObject @($observations.ToArray()) -Depth 20), $utf8)
}

$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $env:GODOT_CONSOLE_PATH
$start.Arguments = '--path "' + $repositoryRoot + '" --rendering-method gl_compatibility --audio-driver Dummy --accessibility always --log-file "' + $log + '" --script ' + $scriptArgument
$start.UseShellExecute = $false
$start.EnvironmentVariables['APPDATA'] = Join-Path $isolated 'appdata'
$start.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $isolated 'localappdata'
$start.EnvironmentVariables['DWM_TEST_ROOT'] = $isolated
$start.EnvironmentVariables['DWM_CAPTION_EVIDENCE_ROOT'] = $output
New-Item -ItemType Directory -Force -Path $start.EnvironmentVariables['APPDATA'], $start.EnvironmentVariables['LOCALAPPDATA'] | Out-Null
$child = New-Object Diagnostics.Process
$child.StartInfo = $start
$started = $false
try {
    $started = $child.Start()
    if (-not $started) { throw 'CAPTION_START_FAILED' }
    foreach ($step in $steps) { Invoke-Caption (Read-Stage $step.stage) $step }
    if (-not $child.WaitForExit(15000)) { throw 'CAPTION_EXIT_TIMEOUT' }
    if ($child.ExitCode -ne 0) { throw "CAPTION_EXIT_CODE: $($child.ExitCode)" }
    $result = Get-Content -Raw -LiteralPath (Join-Path $output 'runtime.json') | ConvertFrom-Json
    if (-not $result.ok -or $observations.Count -ne 9 -or $result.event_index -ne 4 -or
        $result.text -cne $captions[4] -or -not $result.revealing -or $result.finished -ne 4 -or
        $result.ended -ne 0 -or $result.physical_contacts -ne 0 -or $result.review_offset -ne 0) {
        throw 'CAPTION_NATIVE_RESULT_INVALID'
    }
    $review = $result.review_return
    $before = $review.before
    $returned = $review.returned
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
    $receipt = [ordered]@{ ok = $true; checkout = $source; run_id = $env:GITHUB_RUN_ID;
        run_attempt = $env:GITHUB_RUN_ATTEMPT; native_invocations = 9; runtime = $result;
        review_return_verified = $true;
        scope = 'Mounted fixture, native Windows UIA Invoke. Review entry is fixture setup, not native navigation. No screen-reader speech or production route claim.' }
    [IO.File]::WriteAllText((Join-Path $output 'receipt.json'), (ConvertTo-Json $receipt -Depth 25), $utf8)
    Write-Output 'CAPTION_NATIVE_ACCEPT_VERIFIED'
} finally {
    if ($started -and -not $child.HasExited) { & taskkill.exe /PID $child.Id /T /F | Out-Null }
    $child.Dispose()
}
