[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSource
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
. (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
$helper = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
$output = Join-Path $RepositoryRoot '.godot/ci/ending-load'
$utf8 = New-Object Text.UTF8Encoding($false)
$plans = @(
    @{ id = 'create'; path = 'tests/integration/test_scene_seven_day_connected_create.gd'; name = 'test_normal_title_new_game_reaches_day4_and_saves_exact_caption' },
    @{ id = 'load'; path = 'tests/integration/test_scene_seven_day_witness_load.gd'; name = 'test_fresh_load_witness_save_back_reaches_ending_and_preserves_completion' }
)
if ($env:OS -cne 'Windows_NT') { throw 'ENDING_LOAD_WINDOWS_REQUIRED' }
if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or
    -not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf) -or
    [IO.Path]::GetFileName($env:GODOT_CONSOLE_PATH) -cne 'Godot_v4.6.3-stable_win64_console.exe') {
    throw 'ENDING_LOAD_OFFICIAL_STANDARD_463_CONSOLE_REQUIRED'
}
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw 'ENDING_LOAD_HELPER_MISSING' }
$source = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $source -cne $ExpectedSource) { throw 'ENDING_LOAD_SOURCE_MISMATCH' }
if (Test-Path -LiteralPath $output) { throw 'ENDING_LOAD_OUTPUT_NOT_FRESH' }
$evidenceFiles = @('scene-seven-day-create-proof.json', 'scene-seven-day-load-proof.json',
    'scene-seven-day-witness-proof.json', 'scene-seven-day-witness-ending.json', 'computer-seven-day-witness-ending.png',
    'scene-seven-day-completed-autosave.json', 'scene-seven-day-completed-profile.json', 'scene-seven-day-completed-files.json')
foreach ($name in $evidenceFiles) {
    if (Test-Path -LiteralPath (Join-Path $RepositoryRoot ".godot/ci/$name")) { throw "ENDING_LOAD_EVIDENCE_NOT_FRESH: $name" }
}
foreach ($plan in $plans) {
    $plan.log = "ending-load-$($plan.id).log"
    $plan.report = Join-Path $output "$($plan.id).xml"
    if (Test-Path -LiteralPath (Join-Path $RepositoryRoot ".godot/phase2r_logs/$($plan.log)")) { throw 'ENDING_LOAD_LOG_NOT_FRESH' }
    $testBlob = (& git -C $RepositoryRoot rev-parse "HEAD:$($plan.path)").Trim()
    if ($LASTEXITCODE -ne 0) { throw 'ENDING_LOAD_TEST_SOURCE_MISSING' }
    $workingBlob = (& git -C $RepositoryRoot hash-object -- $plan.path).Trim()
    if ($LASTEXITCODE -ne 0 -or $workingBlob -cne $testBlob) { throw 'ENDING_LOAD_TEST_SOURCE_CHANGED' }
    $plan.test_blob = $testBlob
    $plan.test_sha256 = Get-ContinueFileSha256 -LiteralPath (Join-Path $RepositoryRoot $plan.path)
    $plan.arguments = @('--verbose', '--accessibility', 'always', '-s', 'res://addons/gut/gut_cmdln.gd',
        '-gconfig=', "-gtest=res://$($plan.path)", "-gunit_test_name=$($plan.name)", '-gexit', '-glog=2',
        '-gdisable_colors', "-gjunit_xml_file=res://.godot/ci/ending-load/$($plan.id).xml")
}
# Shared fixture is the only changed implementation; bind its working bytes too.
$fixture = 'tests/integration/scene_seven_day_connected_child.gd'
$fixtureBlob = (& git -C $RepositoryRoot rev-parse "HEAD:$fixture").Trim()
if ($LASTEXITCODE -ne 0) { throw 'ENDING_LOAD_FIXTURE_SOURCE_MISSING' }
$workingFixture = (& git -C $RepositoryRoot hash-object -- $fixture).Trim()
if ($LASTEXITCODE -ne 0 -or $workingFixture -cne $fixtureBlob) { throw 'ENDING_LOAD_FIXTURE_SOURCE_CHANGED' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$selection = [ordered]@{ source = $source; expected_cases = 2; tests = $plans; rendered = $true;
    accessibility = 'always'; external_uia_consumer = $false; child_timeout_seconds = 120;
    fixture_blob = $fixtureBlob; fixture_sha256 = Get-ContinueFileSha256 -LiteralPath (Join-Path $RepositoryRoot $fixture);
    runner_sha256 = Get-ContinueFileSha256 -LiteralPath $PSCommandPath;
    isolation_sha256 = Get-ContinueFileSha256 -LiteralPath $helper;
    console_sha256 = Get-ContinueFileSha256 -LiteralPath $env:GODOT_CONSOLE_PATH }
[IO.File]::WriteAllText((Join-Path $output 'selection.json'), ($selection | ConvertTo-Json -Depth 6), $utf8)
# Existing helper owns one isolated root, two fresh sequential processes, and cleanup.
& $helper -RepositoryRoot $RepositoryRoot -SuiteId 'ending-load-boundary' -LogName $plans[0].log `
    -GodotArgs $plans[0].arguments -NextLogName $plans[1].log -NextGodotArgs $plans[1].arguments `
    -EvidenceLogPath '.godot/ci/ending-load/isolation.jsonl' -TimeoutSeconds 120 -Rendered
$childExit = $LASTEXITCODE
$result = [ordered]@{ source = $source; child_exit = $childExit; ok = $false; error = $null; completed = @() }
$exitCode = 1
try {
    if ($childExit -ne 0) { $exitCode = $childExit; throw "ENDING_LOAD_CHILD_FAILED: exit $childExit" }
    foreach ($plan in $plans) {
        $log = Get-Content -LiteralPath (Join-Path $RepositoryRoot ".godot/phase2r_logs/$($plan.log)") -Raw
        if ($log -notmatch '(?m)^Godot Engine v4\.6\.3\.stable\.official\.' -or
            $log -match 'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character') { throw 'ENDING_LOAD_ENGINE_OR_RUNTIME_DIAGNOSTIC' }
        [xml]$xml = Get-Content -LiteralPath $plan.report -Raw
        $cases = $xml.SelectNodes('//testcase'); $suites = $xml.SelectNodes('//testsuite')
        if ($cases.Count -ne 1 -or $suites.Count -ne 1 -or
            $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) { throw 'ENDING_LOAD_SELECTION_OR_RESULT_INVALID' }
        $case = $cases[0]
        if ($case.GetAttribute('name') -cne $plan.name -or $case.GetAttribute('classname') -cne $plan.path -or
            $suites[0].GetAttribute('name') -cne $plan.path -or $case.GetAttribute('status') -cne 'pass' -or
            [int]$case.GetAttribute('assertions') -le 0) { throw 'ENDING_LOAD_EXACT_CASE_NOT_PASSED' }
        $result.completed += [ordered]@{ id = $plan.id; assertions = [int]$case.GetAttribute('assertions'); report = $plan.report }
    }
    foreach ($name in $evidenceFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot ".godot/ci/$name") -PathType Leaf)) { throw "ENDING_LOAD_EVIDENCE_MISSING: $name" }
    }
    $boundary = Get-Content -LiteralPath (Join-Path $RepositoryRoot '.godot/ci/scene-seven-day-witness-ending.json') -Raw | ConvertFrom-Json
    if ($boundary.ending_ready -ne $true -or $boundary.capture.source -cne 'Godot viewport, not desktop' -or
        $boundary.capture.sha256 -cne (Get-ContinueFileSha256 -LiteralPath (Join-Path $RepositoryRoot '.godot/ci/computer-seven-day-witness-ending.png'))) {
        throw 'ENDING_LOAD_CAPTURE_INVALID'
    }
    if ($result.completed.Count -ne 2) { throw 'ENDING_LOAD_CASE_COUNT_INVALID' }
    $result.ok = $true; $exitCode = 0
} catch {
    $result.error = $_.Exception.Message
} finally {
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 6), $utf8)
}
if (-not $result.ok) { [Console]::Error.WriteLine($result.error); exit $exitCode }
Write-Output 'ENDING_LOAD_BOUNDARY_PASSED: 2 exact rendered cases; no external UIA qualification'
exit 0
