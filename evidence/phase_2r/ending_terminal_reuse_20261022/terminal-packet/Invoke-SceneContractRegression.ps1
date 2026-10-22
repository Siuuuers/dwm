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
$output = Join-Path $RepositoryRoot '.godot/ci/scene-contract-regression'
if ($env:OS -cne 'Windows_NT') { throw 'CONTRACT_WINDOWS_REQUIRED' }
if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH) -or
    -not (Test-Path -LiteralPath $env:GODOT_CONSOLE_PATH -PathType Leaf) -or
    [IO.Path]::GetFileName($env:GODOT_CONSOLE_PATH) -cne 'Godot_v4.6.3-stable_win64_console.exe') {
    throw 'CONTRACT_OFFICIAL_STANDARD_463_CONSOLE_REQUIRED'
}
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw 'CONTRACT_ISOLATION_HELPER_MISSING' }
$source = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $source -cne $ExpectedSource) { throw 'CONTRACT_SOURCE_MISMATCH' }
if (Test-Path -LiteralPath $output) { throw 'CONTRACT_OUTPUT_NOT_FRESH' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$scripts = @('tests/unit/test_scene_event_contract.gd', 'tests/unit/test_scene_receipt_validation.gd', 'tests/unit/test_scene_terminal_lifecycle.gd')
$sourceReceipts = @()
foreach ($path in ($scripts + @('scripts/domain/narrative/SceneEventContract.gd', 'scripts/narrative/SceneValidationTiming.gd'))) {
    $blob = (& git -C $RepositoryRoot rev-parse "HEAD:$path").Trim()
    if ($LASTEXITCODE -ne 0) { throw "CONTRACT_SOURCE_MISSING: $path" }
    $working = (& git -C $RepositoryRoot hash-object -- $path).Trim()
    if ($LASTEXITCODE -ne 0 -or $working -cne $blob) { throw "CONTRACT_SOURCE_CHANGED: $path" }
    $sourceReceipts += [ordered]@{ path = $path; blob = $blob; sha256 = Get-ContinueFileSha256 -LiteralPath (Join-Path $RepositoryRoot $path) }
}
$selection = [ordered]@{
    source = $source; sources = $sourceReceipts; scripts = $scripts;
    runner_sha256 = Get-ContinueFileSha256 -LiteralPath $PSCommandPath;
    isolation_sha256 = Get-ContinueFileSha256 -LiteralPath $helper;
    console_sha256 = Get-ContinueFileSha256 -LiteralPath $env:GODOT_CONSOLE_PATH;
    rendered = $false; child_timeout_seconds = 120; distinct_isolated_children = $true;
    census = 'exact source function names against JUnit; no fixed assertion count';
    scope = 'focused scene contract unit regression; not rendered or full-game acceptance'
}
[IO.File]::WriteAllText((Join-Path $output 'selection.json'), ($selection | ConvertTo-Json -Depth 8), $utf8)
$results = @()
$failureExit = 0
foreach ($testPath in $scripts) {
    $id = [IO.Path]::GetFileNameWithoutExtension($testPath)
    $suiteOutput = Join-Path $output $id
    $logName = "contract-$id.log"
    $logPath = Join-Path $RepositoryRoot ".godot/phase2r_logs/$logName"
    $reportPath = Join-Path $suiteOutput 'boundary.xml'
    $result = [ordered]@{ source = $source; script = $testPath; child_exit = $null; ok = $false; error = $null;
        expected_names = @(); actual_names = @(); cases = 0; assertions = 0; log = $logPath; report = $reportPath }
    try {
        if ((Test-Path -LiteralPath $suiteOutput) -or (Test-Path -LiteralPath $logPath) -or (Test-Path -LiteralPath ($logPath + '.timeout.log'))) { throw "CONTRACT_SUITE_OUTPUT_NOT_FRESH: $id" }
        New-Item -ItemType Directory -Path $suiteOutput | Out-Null
        $text = Get-Content -LiteralPath (Join-Path $RepositoryRoot $testPath) -Raw -Encoding utf8
        $names = @([regex]::Matches($text, '(?m)^func (test_[A-Za-z0-9_]+)\(') | ForEach-Object { $_.Groups[1].Value })
        if ($names.Count -eq 0 -or @($names | Sort-Object -Unique).Count -ne $names.Count) { throw 'CONTRACT_SOURCE_CENSUS_INVALID' }
        $result.expected_names = $names
        [IO.File]::WriteAllText((Join-Path $suiteOutput 'expected-names.json'), (ConvertTo-Json -InputObject $names), $utf8)
        $arguments = @('--verbose', '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=', "-gtest=res://$testPath", '-gexit', '-glog=2', '-gdisable_colors', "-gjunit_xml_file=res://.godot/ci/scene-contract-regression/$id/boundary.xml")
        & $helper -RepositoryRoot $RepositoryRoot -SuiteId "contract-$id" -LogName $logName `
            -EvidenceLogPath ".godot/ci/scene-contract-regression/$id/isolation.jsonl" -TimeoutSeconds 120 -GodotArgs $arguments
        $result.child_exit = $LASTEXITCODE
        if ($result.child_exit -ne 0) {
            if ($failureExit -eq 0) { $failureExit = [int]$result.child_exit }
            throw "CONTRACT_CHILD_FAILED: $($result.child_exit)"
        }
        $log = Get-Content -LiteralPath $logPath -Raw -Encoding utf8
        if ($log -notmatch '(?m)^Godot Engine v4\.6\.3\.stable\.official\.' -or
            $log -match 'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character') { throw 'CONTRACT_ENGINE_OR_RUNTIME_DIAGNOSTIC' }
        if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'CONTRACT_REPORT_MISSING' }
        [xml]$xml = Get-Content -LiteralPath $reportPath -Raw -Encoding utf8
        $cases = $xml.SelectNodes('//testcase')
        $suites = $xml.SelectNodes('//testsuite')
        if ($suites.Count -ne 1 -or $suites[0].GetAttribute('name') -cne $testPath -or
            $cases.Count -ne $names.Count -or $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) { throw 'CONTRACT_SELECTION_OR_RESULT_INVALID' }
        $actual = @($cases | ForEach-Object { $_.GetAttribute('name') })
        $result.actual_names = $actual
        if (@($actual | Sort-Object -Unique).Count -ne $actual.Count -or
            @(Compare-Object -CaseSensitive ($names | Sort-Object) ($actual | Sort-Object)).Count -ne 0) { throw 'CONTRACT_EXACT_CENSUS_MISMATCH' }
        foreach ($case in $cases) {
            if ($case.GetAttribute('classname') -cne $testPath -or $case.GetAttribute('status') -cne 'pass' -or
                $case.GetAttribute('assertions') -cnotmatch '^[0-9]+$' -or [long]$case.GetAttribute('assertions') -le 0) { throw 'CONTRACT_CASE_NOT_PASSED' }
            $result.assertions += [long]$case.GetAttribute('assertions')
        }
        foreach ($receipt in $sourceReceipts) {
            $working = (& git -C $RepositoryRoot hash-object -- $receipt.path).Trim()
            if ($LASTEXITCODE -ne 0 -or $working -cne $receipt.blob) { throw "CONTRACT_POST_SOURCE_CHANGED: $($receipt.path)" }
        }
        $result.cases = $cases.Count
        $result.ok = $true
    } catch {
        $result.error = $_.Exception.Message
        if ($failureExit -eq 0) { $failureExit = 1 }
        [Console]::Error.WriteLine($result.error)
    } finally {
        $results += $result
        [IO.File]::WriteAllText((Join-Path $output "$id-result.json"), ($result | ConvertTo-Json -Depth 8), $utf8)
        [IO.File]::WriteAllText((Join-Path $output 'results.json'), (ConvertTo-Json -InputObject $results -Depth 8), $utf8)
    }
}
exit $failureExit
