[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSource,
    [switch]$NativeProviderProvenance
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Run against the exact qualification checkout; all generated evidence stays under .godot.
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$helper = Join-Path $RepositoryRoot 'tools/testing/Invoke-IsolatedGodot.ps1'
$output = Join-Path $RepositoryRoot '.godot/ci/continue-publication'
$utf8 = New-Object Text.UTF8Encoding($false)
if ($env:OS -cne 'Windows_NT') { throw 'CONTINUE_WINDOWS_REQUIRED' }
if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or
    -not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf) -or
    [IO.Path]::GetFileName($env:GODOT_CONSOLE_PATH) -cne 'Godot_v4.6.3-stable_win64_console.exe') {
    throw 'CONTINUE_OFFICIAL_STANDARD_463_CONSOLE_REQUIRED'
}
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw 'CONTINUE_ISOLATION_HELPER_MISSING' }
$source = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $source -cne $ExpectedSource) { throw 'CONTINUE_SOURCE_MISMATCH' }
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) {
    throw 'CONTINUE_OUTPUT_NOT_FRESH'
}
New-Item -ItemType Directory -Force -Path $output | Out-Null
$runtimePath = 'tests/integration/test_witnessed_caption_runtime.gd'
$publicationPath = 'tests/manual/test_continue_reveal_publication.gd'
$plans = @(
    @{ id = 'initial-observation'; path = $publicationPath; name = 'test_continue_initial_registration_observation' }
)

# GUT -gunit_test_name is a substring filter, not a list or regular expression.
# Check the inherited fixture as well, then prove the actual selection in JUnit.
$runtimeText = Get-Content -LiteralPath (Join-Path $RepositoryRoot $runtimePath) -Raw
$publicationText = Get-Content -LiteralPath (Join-Path $RepositoryRoot $publicationPath) -Raw
foreach ($plan in $plans) {
    $text = $runtimeText
    if ($plan.path -ceq $publicationPath) { $text += "`n" + $publicationText }
    $names = @([regex]::Matches($text, '(?m)^func (test_[A-Za-z0-9_]+)\(') |
        ForEach-Object { $_.Groups[1].Value } | Where-Object { $_.Contains($plan.name) })
    if ($names.Count -ne 1 -or $names[0] -cne $plan.name) { throw "CONTINUE_FILTER_NOT_UNIQUE: $($plan.name)" }
    $plan['expected_cases'] = 1
}
$manifest = [ordered]@{ source = $source; expected_cases = 1; registration_cases = 1; diagnostic_only = $true;
    rendered = $true; accessibility = 'always'; tests = $plans;
    native_provider_provenance = [bool]$NativeProviderProvenance;
    client_route = $(if ($NativeProviderProvenance) { 'managed-discovery-then-native-COM-provenance' } else { 'managed-baseline' });
    console_sha256 = (Get-FileHash -LiteralPath $env:GODOT_CONSOLE_PATH -Algorithm SHA256).Hash.ToLowerInvariant() }
[IO.File]::WriteAllText((Join-Path $output 'selection.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
function Write-ConsumerOutcome([string]$LogPath, [int]$RunnerExit) {
    # Compare same-machine UTC samples, bracketed by the fixture's original
    # monotonic registration clock. Never reset or extend that deadline.
    $outcome = [ordered]@{ runner_exit = $RunnerExit; registration = 'unobserved';
        attachment = 'unobserved'; timing = 'unavailable'; reader = $null; lifecycle = $null;
        window = $null; clock_drift_msec = $null; reader_clock_drift_max_msec = $null;
        discovery_start_from_window_msec = $null;
        discovery_end_from_window_msec = $null; analysis_error = $null; qualified = $false }
    try {
        $readerPath = Join-Path $output 'consumer-reader.json'
        $lifecyclePath = Join-Path $output 'consumer-lifecycle.json'
        if (Test-Path -LiteralPath $readerPath) {
            $outcome.reader = Get-Content -LiteralPath $readerPath -Raw | ConvertFrom-Json
            $outcome.attachment = if ($outcome.reader.discovered) { 'discovered' } else { 'failed' }
        }
        if (Test-Path -LiteralPath $lifecyclePath) {
            $outcome.lifecycle = Get-Content -LiteralPath $lifecyclePath -Raw | ConvertFrom-Json
        }
        $lines = @(Get-Content -LiteralPath $LogPath | Where-Object { $_.StartsWith('CONTINUE_REGISTRATION_OBSERVATION ') })
        if ($lines.Count -ne 1) { throw 'CONSUMER_OBSERVATION_COUNT' }
        $observation = $lines[0].Substring('CONTINUE_REGISTRATION_OBSERVATION '.Length) | ConvertFrom-Json
        $outcome.registration = $observation.final.outcome
        $window = $observation.registration_window
        $clock = $window.start_clock
        $endClock = $observation.end_clock
        $offset = [double]$clock.unix_msec - (([double]$clock.ticks_before + [double]$clock.ticks_after) / 2.0)
        $endOffset = [double]$endClock.unix_msec - (([double]$endClock.ticks_before + [double]$endClock.ticks_after) / 2.0)
        $outcome.clock_drift_msec = $endOffset - $offset
        $earliestDeadline = [double]$clock.unix_msec + [double]$window.deadline_ticks_msec - [double]$clock.ticks_after
        $latestDeadline = [double]$clock.unix_msec + [double]$window.deadline_ticks_msec - [double]$clock.ticks_before
        $outcome.window = [ordered]@{ original = $window; end_clock = $endClock;
            deadline_earliest_unix_msec = $earliestDeadline; deadline_latest_unix_msec = $latestDeadline;
            boundary_margin_msec = 12; clock_drift_limit_msec = 10 }
        # Reader may discover before the fixture window starts. Its existing
        # UTC/Stopwatch event pairs cover that earlier interval through cleanup.
        $readerClockValid = $false
        if ($null -ne $outcome.reader) {
            $events = @($outcome.reader.events)
            if ($events.Count -ge 2 -and $events[0].stage -ceq 'reader_start' -and
                $events[-1].stage -ceq 'reader_complete') {
                $maximumDrift = 0.0
                foreach ($event in $events) {
                    $drift = ([double]$event.unix_msec - [double]$events[0].unix_msec) -
                        ([double]$event.elapsed_msec - [double]$events[0].elapsed_msec)
                    $maximumDrift = [Math]::Max($maximumDrift, [Math]::Abs($drift))
                }
                $outcome.reader_clock_drift_max_msec = $maximumDrift
                $readerClockValid = $maximumDrift -le 10
            }
        }
        if (-not $readerClockValid -or [Math]::Abs($outcome.clock_drift_msec) -gt 10 -or
            ([double]$clock.ticks_after - [double]$clock.ticks_before) -gt 10 -or
            ([double]$endClock.ticks_after - [double]$endClock.ticks_before) -gt 10) {
            $outcome.timing = 'clock_incomparable'
        } elseif ($null -ne $outcome.reader -and $null -ne $outcome.reader.discovery_completed_unix_msec) {
            $done = [double]$outcome.reader.discovery_completed_unix_msec
            $outcome.discovery_start_from_window_msec = [double]$outcome.reader.discovery_started_unix_msec - [double]$clock.unix_msec
            $outcome.discovery_end_from_window_msec = $done - [double]$clock.unix_msec
            if ($done -lt ($earliestDeadline - 12)) { $outcome.timing = 'timely' }
            elseif ($done -gt ($latestDeadline + 12)) { $outcome.timing = 'late' }
            else { $outcome.timing = 'boundary_ambiguous' }
        }
        $outcome.qualified = $RunnerExit -eq 0 -and $outcome.registration -ceq 'initial_registration_observed' -and
            $outcome.attachment -ceq 'discovered' -and $outcome.timing -ceq 'timely' -and
            $null -ne $outcome.lifecycle -and $outcome.lifecycle.child_exit -eq 0 -and
            $outcome.lifecycle.reader_exit -eq 0 -and -not $outcome.lifecycle.reader_forced -and
            $null -eq $outcome.lifecycle.error -and @($outcome.lifecycle.cleanup_errors).Count -eq 0 -and
            $outcome.reader.ok
    } catch {
        $outcome.analysis_error = $_.Exception.Message
    }
    [IO.File]::WriteAllText((Join-Path $output 'consumer-outcome.json'), (ConvertTo-Json $outcome -Depth 20), $utf8)
    return $outcome
}

$completed = New-Object Collections.Generic.List[object]
foreach ($plan in $plans) {
    $logName = "continue-publication-$($plan.id).log"
    $logPath = Join-Path $RepositoryRoot ".godot/phase2r_logs/$logName"
    $reportPath = Join-Path $output "$($plan.id).xml"
    if (Test-Path -LiteralPath $logPath) { throw "CONTINUE_LOG_NOT_FRESH: $logName" }
    $arguments = @('--verbose', '--accessibility', 'always', '-s', 'res://addons/gut/gut_cmdln.gd',
        '-gconfig=', "-gtest=res://$($plan.path)", "-gunit_test_name=$($plan.name)",
        '-gexit', '-glog=2', '-gdisable_colors',
        "-gjunit_xml_file=res://.godot/ci/continue-publication/$($plan.id).xml")
    & $helper -SuiteId "continue-publication-$($plan.id)" -LogName $logName `
        -EvidenceLogPath '.godot/ci/continue-publication/isolation.jsonl' `
        -TimeoutSeconds 120 -Rendered -ContinueAccessibilityConsumer -NativeProviderProvenance:$NativeProviderProvenance -GodotArgs $arguments
    $result = $LASTEXITCODE
    $consumerOutcome = Write-ConsumerOutcome -LogPath $logPath -RunnerExit $result
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath }
        throw "CONTINUE_CHILD_FAILED: $($plan.id) exit $result"
    }
    if (-not $consumerOutcome.qualified) { throw 'CONTINUE_CONSUMER_PREREQUISITE_NOT_QUALIFIED' }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -notmatch '(?m)^Godot Engine v4\.6\.3\.stable\.official\.' -or
        $log -match 'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character') {
        throw "CONTINUE_ENGINE_OR_RUNTIME_DIAGNOSTIC: $($plan.id)"
    }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw "CONTINUE_REPORT_MISSING: $($plan.id)" }
    [xml]$xml = Get-Content -LiteralPath $reportPath -Raw
    $cases = $xml.SelectNodes('//testcase')
    $suites = $xml.SelectNodes('//testsuite')
    if ($cases.Count -ne 1 -or $suites.Count -ne 1 -or
        $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) {
        throw "CONTINUE_SELECTION_OR_RESULT_INVALID: $($plan.id)"
    }
    $case = $cases[0]
    if ($case.GetAttribute('name') -cne $plan.name -or $case.GetAttribute('classname') -cne $plan.path -or
        $suites[0].GetAttribute('name') -cne $plan.path -or
        $case.GetAttribute('status') -cne 'pass' -or [int]$case.GetAttribute('assertions') -le 0) {
        throw "CONTINUE_EXACT_CASE_NOT_PASSED: $($plan.id)"
    }
    $completed.Add([ordered]@{ id = $plan.id; script = $plan.path; test = $plan.name;
        passed = 1; skipped = 0; assertions = [int]$case.GetAttribute('assertions'); log = $logPath })
    [IO.File]::WriteAllText((Join-Path $output 'completed.json'),
        (ConvertTo-Json -InputObject @($completed.ToArray()) -Depth 6), $utf8)
}
if ($completed.Count -ne 1) { throw 'CONTINUE_COMPLETED_COUNT_INVALID' }
Write-Output 'CONTINUE_INITIAL_OBSERVATION_COMPLETED: 1 exact case; not completion/native qualification'
