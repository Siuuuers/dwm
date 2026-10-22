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
$helper = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
$output = Join-Path $RepositoryRoot '.godot/ci/continue-publication'
$utf8 = New-Object Text.UTF8Encoding($false)
if ($env:OS -cne 'Windows_NT') { throw 'CONTINUE_WINDOWS_REQUIRED' }
if (-not $NativeProviderProvenance) { throw 'CONTINUE_NATIVE_CONSUMER_REQUIRED' }
. (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
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
    @{ id = 'organic'; path = $publicationPath; name = 'test_continue_registered_action_refreshes_after_organic_finish' },
    @{ id = 'manual'; path = $publicationPath; name = 'test_continue_registered_action_refreshes_after_manual_finish' },
    @{ id = 'pointer'; path = $runtimePath; name = 'test_actual_background_and_caption_accept_share_one_release_gesture' },
    @{ id = 'keyboard'; path = $runtimePath; name = 'test_actual_enter_and_same_frame_unrelated_packets_issue_one_accept' },
    @{ id = 'touch'; path = $runtimePath; name = 'test_actual_current_short_tap_accepts_but_drag_only_scrolls' },
    @{ id = 'review'; path = $runtimePath; name = 'test_review_background_click_returns_live_before_a_fresh_click_reveals' },
    @{ id = 'speech-start'; path = $runtimePath; name = 'test_speech_starts_with_visible_primary_during_reveal_without_speaker_or_markup' },
    @{ id = 'speech-cancel'; path = $runtimePath; name = 'test_accept_or_custody_cancels_current_speech_and_uncover_cannot_replay' },
    @{ id = 'projection'; path = $runtimePath; name = 'test_continue_projection_uses_existing_surface_and_follows_source_admission' }
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
    $plan['native_consumer'] = $plan.path -ceq $publicationPath
}
$manifest = [ordered]@{ source = $source; expected_cases = 9; registration_cases = 2;
    rendered = $true; accessibility = 'always'; tests = $plans;
    client_route = 'managed-discovery-then-native-COM-provenance for two publication cases only';
    console_sha256 = (Get-FileHash -LiteralPath $env:GODOT_CONSOLE_PATH -Algorithm SHA256).Hash.ToLowerInvariant() }
[IO.File]::WriteAllText((Join-Path $output 'selection.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
# Each registered-completion fixture owns its unchanged 5000ms publication waits.
# Unlike the diagnostic lane, it emits no successful registration clock snapshot.
# Keep reader clock comparability separate; do not fabricate cross-clock native timing.
function Assert-ConsumerReceipt([string]$Directory) {
    $reader = Get-Content -LiteralPath (Join-Path $Directory 'consumer-reader.json') -Raw | ConvertFrom-Json
    $lifecycle = Get-Content -LiteralPath (Join-Path $Directory 'consumer-lifecycle.json') -Raw | ConvertFrom-Json
    $binding = Get-Content -LiteralPath (Join-Path $Directory 'consumer-binding.json') -Raw | ConvertFrom-Json
    if ($reader.ok -ne $true -or $reader.exit_code -ne 0 -or $reader.discovered -ne $true -or
        $null -ne $reader.error -or $reader.native_provider.status -cne 'observed' -or
        $reader.native_provider.identity_verified -ne $true -or
        @($reader.native_provider.cleanup_errors).Count -ne 0 -or
        $lifecycle.child_exit -ne 0 -or $lifecycle.reader_exit -ne 0 -or
        $lifecycle.reader_started -ne $true -or $lifecycle.reader_forced -ne $false -or
        $null -ne $lifecycle.error -or @($lifecycle.cleanup_errors).Count -ne 0) {
        throw 'CONTINUE_CONSUMER_NOT_CLEAN'
    }
    if ($reader.client_route -cne 'managed-discovery-then-native-COM-provenance' -or
        $reader.native_provider.reader_sha256 -cne (Get-ContinueFileSha256 -LiteralPath (Join-Path $PSScriptRoot 'Read-ContinueNativeProvider.ps1')) -or
        $reader.native_provider.interop_sha256 -cne (Get-ContinueFileSha256 -LiteralPath (Join-Path $PSScriptRoot 'ContinueNativeProvider.cs')) -or
        $reader.identity.launcher_pid -ne $binding.launcher_pid -or
        $reader.identity.parent_pid -ne $binding.launcher_pid -or
        $reader.binding.launcher_start_ticks -cne $binding.launcher_start_ticks -or
        $reader.identity.executable -cne $binding.engine_path -or
        $reader.binding.arguments -cne $binding.arguments -or
        $reader.binding.console_path -cne $binding.console_path) {
        throw 'CONTINUE_CONSUMER_RECEIPT_IDENTITY'
    }
    $events = @($reader.events)
    if ($events.Count -lt 2 -or $events[0].stage -cne 'reader_start' -or
        $events[-1].stage -cne 'reader_complete') { throw 'CONTINUE_CONSUMER_CLOCK_INCOMPLETE' }
    $maximumDrift = 0.0
    foreach ($event in $events) {
        $drift = ([double]$event.unix_msec - [double]$events[0].unix_msec) -
            ([double]$event.elapsed_msec - [double]$events[0].elapsed_msec)
        $maximumDrift = [Math]::Max($maximumDrift, [Math]::Abs($drift))
    }
    $summary = [ordered]@{ reader_clock_drift_max_msec = $maximumDrift;
        reader_clock_drift_limit_msec = 10; clock_comparable = $maximumDrift -le 10;
        publication_deadline_owner = 'fixture unchanged 5000ms waits';
        native_query_timing = 'not_classified'; reader_pid = $reader.reader_pid;
        engine_pid = $reader.identity.pid; hwnd = $reader.hwnd }
    [IO.File]::WriteAllText((Join-Path $Directory 'consumer-summary.json'),
        (ConvertTo-Json $summary -Depth 6), $utf8)
    if ($maximumDrift -gt 10) { throw 'CONTINUE_CONSUMER_CLOCK_INCOMPARABLE' }
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
    $useConsumer = [bool]$plan.native_consumer
    $consumerDirectory = Join-Path $output "consumer-$($plan.id)"
    $consumerFiles = @('consumer-binding.json', 'consumer-reader.json', 'consumer-lifecycle.json', 'consumer-stop')
    if ($plan.native_consumer) {
        if (Test-Path -LiteralPath $consumerDirectory) { throw 'CONTINUE_CASE_OUTPUT_NOT_FRESH' }
        New-Item -ItemType Directory -Path $consumerDirectory | Out-Null
    }
    try {
        & $helper -RepositoryRoot $RepositoryRoot -SuiteId "continue-publication-$($plan.id)" -LogName $logName `
            -EvidenceLogPath '.godot/ci/continue-publication/isolation.jsonl' `
            -TimeoutSeconds 120 -Rendered -ContinueAccessibilityConsumer:$useConsumer `
            -NativeProviderProvenance:$useConsumer -GodotArgs $arguments
        $result = $LASTEXITCODE
    } finally {
        if ($plan.native_consumer) {
            # Preserve even failed attempts, then leave the helper's fixed paths fresh.
            foreach ($name in $consumerFiles) {
                $path = Join-Path $output $name
                if (Test-Path -LiteralPath $path) {
                    Move-Item -LiteralPath $path -Destination (Join-Path $consumerDirectory $name) -ErrorAction Stop
                }
            }
        }
    }
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath }
        throw "CONTINUE_CHILD_FAILED: $($plan.id) exit $result"
    }
    if ($plan.native_consumer) { Assert-ConsumerReceipt $consumerDirectory }
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
if ($completed.Count -ne 9) { throw 'CONTINUE_COMPLETED_COUNT_INVALID' }
Write-Output 'CONTINUE_PUBLICATION_CHECKS_PASSED: 9 exact cases; 2 registration, 7 input/review/speech/projection; skipped=0'
