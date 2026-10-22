[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSource
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$helper = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
. (Join-Path $PSScriptRoot 'Get-ContinueFileSha256.ps1')
$utf8 = New-Object Text.UTF8Encoding($false)
$testPath = 'tests/integration/test_scene_ending_direct_return.gd'
$testName = 'test_direct_ending_accept_returns_without_save'
$output = Join-Path $RepositoryRoot '.godot/ci/ending-layout'
$reportPath = Join-Path $output 'boundary.xml'
$logName = 'ending-layout-boundary.log'
$logPath = Join-Path $RepositoryRoot ".godot/phase2r_logs/$logName"
$observationPath = Join-Path $RepositoryRoot '.godot/ci/ending-layout-boundary.json'
$capturePath = Join-Path $RepositoryRoot '.godot/ci/ending-layout-boundary.png'
if ($env:OS -cne 'Windows_NT') { throw 'ENDING_WINDOWS_REQUIRED' }
if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or
    -not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf) -or
    [IO.Path]::GetFileName($env:GODOT_CONSOLE_PATH) -cne 'Godot_v4.6.3-stable_win64_console.exe') {
    throw 'ENDING_OFFICIAL_STANDARD_463_CONSOLE_REQUIRED'
}
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw 'ENDING_ISOLATION_HELPER_MISSING' }
$source = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $source -cne $ExpectedSource) { throw 'ENDING_SOURCE_MISMATCH' }
# Preparation may generate project resources, but the selected test must be the pinned source.
$testBlob = (& git -C $RepositoryRoot rev-parse "HEAD:$testPath").Trim()
if ($LASTEXITCODE -ne 0) { throw 'ENDING_TEST_SOURCE_MISSING' }
$workingBlob = (& git -C $RepositoryRoot hash-object -- $testPath).Trim()
if ($LASTEXITCODE -ne 0 -or $workingBlob -cne $testBlob) { throw 'ENDING_TEST_SOURCE_CHANGED' }
foreach ($path in @($output, $logPath, $observationPath, $capturePath)) {
    if (Test-Path -LiteralPath $path) { throw "ENDING_OUTPUT_NOT_FRESH: $path" }
}
# This also creates .godot/ci before the fixture writes its JSON and viewport PNG.
New-Item -ItemType Directory -Force -Path $output | Out-Null
$testText = Get-Content -LiteralPath (Join-Path $RepositoryRoot $testPath) -Raw
$names = @([regex]::Matches($testText, '(?m)^func (test_[A-Za-z0-9_]+)\(') |
    ForEach-Object { $_.Groups[1].Value } | Where-Object { $_.Contains($testName) })
if ($names.Count -ne 1 -or $names[0] -cne $testName) { throw 'ENDING_FILTER_NOT_UNIQUE' }
$selection = [ordered]@{
    source = $source; script = $testPath; test = $testName; test_blob = $testBlob;
    test_sha256 = Get-ContinueFileSha256 -LiteralPath (Join-Path $RepositoryRoot $testPath);
    runner_sha256 = Get-ContinueFileSha256 -LiteralPath $PSCommandPath;
    isolation_sha256 = Get-ContinueFileSha256 -LiteralPath $helper;
    console_sha256 = Get-ContinueFileSha256 -LiteralPath $env:GODOT_CONSOLE_PATH;
    expected_cases = 1; rendered = $true; accessibility = 'always'; child_timeout_seconds = 120;
    external_uia_consumer = $false; scope = 'ending presentation ownership and existing direct-return contract';
    capture_source = 'Godot viewport, not desktop'
}
[IO.File]::WriteAllText((Join-Path $output 'selection.json'), ($selection | ConvertTo-Json -Depth 5), $utf8)
$arguments = @('--verbose', '--accessibility', 'always', '-s', 'res://addons/gut/gut_cmdln.gd',
    '-gconfig=', "-gtest=res://$testPath", "-gunit_test_name=$testName", '-gexit', '-glog=2',
    '-gdisable_colors', '-gjunit_xml_file=res://.godot/ci/ending-layout/boundary.xml')
& $helper -RepositoryRoot $RepositoryRoot -SuiteId 'ending-layout-boundary' -LogName $logName `
    -EvidenceLogPath '.godot/ci/ending-layout/isolation.jsonl' -TimeoutSeconds 120 -Rendered -GodotArgs $arguments
$childExit = $LASTEXITCODE
$result = [ordered]@{ source = $source; child_exit = $childExit; ok = $false; error = $null;
    script = $testPath; test = $testName; log = $logPath; report = $reportPath;
    observation = $observationPath; viewport_capture = $capturePath; assertions = 0 }
# Preserve the actual child failure code. A baseline failure is evidence, never a green result.
if ($childExit -ne 0) {
    $result.error = "ENDING_CHILD_FAILED: exit $childExit"
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 5), $utf8)
    if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath }
    [Console]::Error.WriteLine($result.error)
    exit $childExit
}
try {
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -notmatch '(?m)^Godot Engine v4\.6\.3\.stable\.official\.' -or
        $log -match 'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character') {
        throw 'ENDING_ENGINE_OR_RUNTIME_DIAGNOSTIC'
    }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'ENDING_REPORT_MISSING' }
    [xml]$xml = Get-Content -LiteralPath $reportPath -Raw
    $cases = $xml.SelectNodes('//testcase')
    $suites = $xml.SelectNodes('//testsuite')
    if ($cases.Count -ne 1 -or $suites.Count -ne 1 -or
        $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) {
        throw 'ENDING_SELECTION_OR_RESULT_INVALID'
    }
    $case = $cases[0]
    if ($case.GetAttribute('name') -cne $testName -or $case.GetAttribute('classname') -cne $testPath -or
        $suites[0].GetAttribute('name') -cne $testPath -or $case.GetAttribute('status') -cne 'pass' -or
        [int]$case.GetAttribute('assertions') -le 0) { throw 'ENDING_EXACT_CASE_NOT_PASSED' }
    if (-not (Test-Path -LiteralPath $observationPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $capturePath -PathType Leaf)) { throw 'ENDING_BOUNDARY_EVIDENCE_MISSING' }
    $observation = Get-Content -LiteralPath $observationPath -Raw | ConvertFrom-Json
    if ($observation.ending_ready -ne $true -or
        $observation.capture.source -cne 'Godot viewport, not desktop' -or
        $observation.capture.file -cne 'ending-layout-boundary.png' -or
        $observation.capture.width -le 0 -or $observation.capture.height -le 0 -or
        $observation.capture.sha256 -cne (Get-ContinueFileSha256 -LiteralPath $capturePath)) {
        throw 'ENDING_CAPTURE_EVIDENCE_INVALID'
    }
    $result.assertions = [int]$case.GetAttribute('assertions')
    $result.ok = $true
} catch {
    $result.error = $_.Exception.Message
} finally {
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 5), $utf8)
}
if (-not $result.ok) { [Console]::Error.WriteLine($result.error); exit 1 }
Write-Output 'ENDING_LAYOUT_BOUNDARY_PASSED: 1 exact rendered case; skipped=0; viewport evidence only'
exit 0
