[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSource
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
    @{ id = 'organic'; path = $publicationPath; name = 'test_continue_registered_action_refreshes_after_organic_finish' },
    @{ id = 'manual'; path = $publicationPath; name = 'test_continue_registered_action_refreshes_after_manual_finish' },
    @{ id = 'pointer'; path = $runtimePath; name = 'test_actual_background_and_caption_accept_share_one_release_gesture' },
    @{ id = 'keyboard'; path = $runtimePath; name = 'test_actual_enter_and_same_frame_unrelated_packets_issue_one_accept' },
    @{ id = 'touch'; path = $runtimePath; name = 'test_actual_current_short_tap_accepts_but_drag_only_scrolls' },
    @{ id = 'review'; path = $runtimePath; name = 'test_review_background_click_returns_live_before_a_fresh_click_reveals' },
    @{ id = 'speech-start'; path = $runtimePath; name = 'test_speech_starts_with_visible_primary_during_reveal_without_speaker_or_markup' },
    @{ id = 'speech-cancel'; path = $runtimePath; name = 'test_accept_or_custody_cancels_current_speech_and_uncover_cannot_replay' }
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
$manifest = [ordered]@{ source = $source; expected_cases = 8; registration_cases = 2;
    rendered = $true; accessibility = 'always'; tests = $plans;
    console_sha256 = (Get-FileHash -LiteralPath $env:GODOT_CONSOLE_PATH -Algorithm SHA256).Hash.ToLowerInvariant() }
[IO.File]::WriteAllText((Join-Path $output 'selection.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
$completed = New-Object Collections.Generic.List[object]
foreach ($plan in $plans) {
    $logName = "continue-publication-$($plan.id).log"
    $logPath = Join-Path $RepositoryRoot ".godot/phase2r_logs/$logName"
    $reportPath = Join-Path $output "$($plan.id).xml"
    if (Test-Path -LiteralPath $logPath) { throw "CONTINUE_LOG_NOT_FRESH: $logName" }
    $arguments = @('--accessibility', 'always', '-s', 'res://addons/gut/gut_cmdln.gd',
        '-gconfig=', "-gtest=res://$($plan.path)", "-gunit_test_name=$($plan.name)",
        '-gexit', '-glog=2', '-gdisable_colors',
        "-gjunit_xml_file=res://.godot/ci/continue-publication/$($plan.id).xml")
    & $helper -SuiteId "continue-publication-$($plan.id)" -LogName $logName `
        -EvidenceLogPath '.godot/ci/continue-publication/isolation.jsonl' `
        -TimeoutSeconds 120 -Rendered -GodotArgs $arguments
    $result = $LASTEXITCODE
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath }
        throw "CONTINUE_CHILD_FAILED: $($plan.id) exit $result"
    }
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
if ($completed.Count -ne 8) { throw 'CONTINUE_COMPLETED_COUNT_INVALID' }
Write-Output 'CONTINUE_PUBLICATION_CHECKS_PASSED: 8 exact cases; 2 registration, 6 input/review/speech; skipped=0'
