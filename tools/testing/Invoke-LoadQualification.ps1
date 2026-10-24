#requires -Version 7.0
# Controller-only source; do not merge into the product branch.
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$CandidateRef,
    [Parameter(Mandatory)][ValidateSet('focused', 'terminal', 'inventory', 'diagnostic')][string]$Lane,
    [switch]$RegenerateInventories
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows cloud runner required.' }
$controller = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$baseRef = '08e9471a589fde0ebc9e460ab650047f465aef93'
$output = Join-Path $controller ".godot/ci/load-$Lane"
if (Test-Path $output) { throw 'Fresh qualification output required.' }
New-Item -ItemType Directory -Path $output | Out-Null
function Invoke-Git([string[]]$Arguments) {
    $value = & git -C $controller -c core.autocrlf=false @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git failed: $Arguments" }
    return $value
}
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
foreach ($ref in @($baseRef, $CandidateRef)) { Invoke-Git -Arguments @('fetch', '--no-tags', 'origin', $ref) | Out-Null }
$runtimePaths = @('autoload/SaveManager.gd', 'scripts/narrative/FrozenRunContext.gd', 'scripts/domain/narrative/SceneEventContract.gd', 'scripts/narrative/SceneValidationTiming.gd')
$runtimeChanges = @(Invoke-Git -Arguments @('diff', '--name-only', $baseRef, $CandidateRef, '--', 'autoload', 'scripts', 'addons', 'scenes', 'assets', 'data', 'dialogic', 'localization', 'project.godot'))
$allowed = if ($Lane -eq 'diagnostic') { @('scripts/narrative/FrozenRunContext.gd', 'scripts/domain/narrative/SceneEventContract.gd', 'scripts/narrative/SceneValidationTiming.gd') } else { @('autoload/SaveManager.gd') }
if (@($runtimeChanges | Where-Object { $_ -notin $allowed }).Count) { throw "Unexpected runtime changes: $runtimeChanges" }
$tests = @('tests/integration/test_backup_current_build.gd', 'tests/integration/test_save_manager_public_boundaries.gd')
$record = [ordered]@{ controller_ref = (Invoke-Git -Arguments @('rev-parse', 'HEAD')).Trim()
    baseline_ref = $baseRef; candidate_ref = $CandidateRef; lane = $Lane; runtime_changed_files = $runtimeChanges
    engine_sha256 = Get-Sha256 $env:GODOT_CONSOLE_PATH; source_hashes = @{}; suites = @(); status = 'started'
    inventory_mode = if ($Lane -ne 'inventory') { 'not_executed_in_this_lane' } elseif ($RegenerateInventories) { 'diagnostic_generation_not_committed_verification' } else { 'read_only_committed_verification' } }
if ($record.engine_sha256 -ne '63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a') { throw 'Unexpected Godot executable.' }
function Save-Record { $record | ConvertTo-Json -Depth 50 | Set-Content (Join-Path $output 'qualification.json') -Encoding utf8 }
$runtime = Join-Path $env:RUNNER_TEMP "load-$Lane-candidate"
function Preserve {
    foreach ($relative in @('.godot/ci', '.godot/phase2r_logs')) {
        $from = Join-Path $runtime $relative
        if (-not (Test-Path $from)) { continue }
        foreach ($file in Get-ChildItem $from -File -Recurse) {
            $name = [IO.Path]::GetRelativePath($runtime, $file.FullName).Replace('\','/')
            if ($name -match '/(?:shared-user|import-user)/') { continue }
            if ($file.Extension -notin @('.json', '.jsonl', '.log', '.xml', '.png')) { continue }
            $target = Join-Path $output "candidate/$name"
            New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $target
        }
    }
    foreach ($name in @('game_state_surface.json', 'save_manager_surface.json')) {
        $from = Join-Path $runtime "evidence/phase_2r/runtime/$name"
        if (Test-Path $from) { Copy-Item $from (Join-Path $output $name) }
    }
}
try {
    if (Test-Path $runtime) { throw 'Runtime checkout already exists.' }
    Invoke-Git -Arguments @('worktree', 'add', '--detach', $runtime, $CandidateRef) | Out-Null
    $sources = $runtimePaths + $tests + @('tests/integration/authored_terminal_admission_checks.gd',
        'tools/testing/Invoke-CloudTests.ps1', 'tools/testing/Invoke-IsolatedGodot.ps1',
        'tools/testing/Invoke-PublicSurfaceValidation.ps1', 'tools/testing/Invoke-FreshSaveLoadComparison.ps1',
        'tools/testing/Invoke-FreshSaveLoad.ps1', 'tests/integration/fresh_save_load_child.gd',
        'tests/integration/authored_week_child.gd')
    foreach ($path in $sources) {
        $blob = (& git -C $runtime hash-object --no-filters -- $path).Trim()
        if ($LASTEXITCODE -ne 0 -or $blob -ne (Invoke-Git -Arguments @('rev-parse', "${CandidateRef}:$path")).Trim()) { throw "Source checkout byte mismatch: $path" }
        $record.source_hashes[$path] = Get-Sha256 (Join-Path $runtime $path)
    }
    Save-Record
    $ci = Join-Path $runtime '.godot/ci'
    $env:APPDATA = Join-Path $ci 'import-user/appdata'; $env:LOCALAPPDATA = Join-Path $ci 'import-user/localappdata'; $env:DWM_TEST_ROOT = Join-Path $ci 'import-user/test-root'
    New-Item -ItemType Directory -Force $ci, $env:APPDATA, $env:LOCALAPPDATA, $env:DWM_TEST_ROOT | Out-Null
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $env:GODOT_CONSOLE_PATH; $start.WorkingDirectory = $runtime
    $start.UseShellExecute = $false; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($argument in @('--headless', '--path', $runtime, '--import', '--log-file', "$ci/import.log")) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        $finished = $process.WaitForExit(600000)
        if (-not $finished) { $process.Kill($true); $process.WaitForExit(10000) | Out-Null }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 10000)) { throw 'Import output drain timeout.' }
        $stdout.Result | Set-Content "$ci/import-stdout.log" -Encoding utf8
        $stderr.Result | Set-Content "$ci/import-stderr.log" -Encoding utf8
        $record.import = @{ timed_out = -not $finished; exit_code = $process.ExitCode }
        if (-not $finished -or $process.ExitCode -ne 0) { throw 'Import failed or timed out.' }
    } finally { $process.Dispose() }
    if (Select-String "$ci/import.log" -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) { throw 'Import errors.' }
    & git -C $runtime -c core.autocrlf=false restore --worktree -- project.godot
    if ($LASTEXITCODE -ne 0) { throw 'Project settings restoration failed.' }
    if ($Lane -eq 'diagnostic') {
        $env:DWM_TERMINAL_LEDGER_DIAGNOSTIC = '1'
        & (Join-Path $runtime 'tools/testing/Invoke-FreshSaveLoad.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'Fresh Save/Load diagnostic failed.' }
    } elseif ($Lane -eq 'inventory') {
        & (Join-Path $runtime 'tools/testing/Invoke-PublicSurfaceValidation.ps1') -EmitPayloads -Regenerate:$RegenerateInventories
        if ($LASTEXITCODE -ne 0) { throw 'Inventory generation/verification failed.' }
    } elseif ($Lane -eq 'terminal') {
        & (Join-Path $runtime 'tools/testing/Invoke-CloudTests.ps1') -Suite terminal_admission
        if ($LASTEXITCODE -ne 0) { throw 'Genuine terminal admission failed.' }
    } else {
        $failures = @()
        foreach ($name in $tests) {
            $suiteId = 'load-' + [IO.Path]::GetFileNameWithoutExtension($name)
            $expected = @(Select-String -LiteralPath (Join-Path $runtime $name) -Pattern '^func test_[^(]+\(').Count
            $suite = [ordered]@{ file = $name; expected_tests = $expected; actual_tests = 0; assertions = 0; status = 'started'; error = '' }
            $record.suites += $suite
            try {
                & (Join-Path $runtime 'tools/testing/Invoke-IsolatedGodot.ps1') -SuiteId $suiteId -LogName "$suiteId.log" -EvidenceLogPath ".godot/ci/$suiteId.jsonl" -TimeoutSeconds 1800 -GodotArgs @('-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=', "-gtest=res://$name", '-gexit', '-glog=1', "-gjunit_xml_file=res://.godot/ci/$suiteId.xml")
                $suite.exit_code = $LASTEXITCODE
                [xml]$xml = Get-Content (Join-Path $ci "$suiteId.xml") -Raw
                $cases = @($xml.SelectNodes('//testcase'))
                $suite.actual_tests = $cases.Count
                $suite.assertions = ($cases | ForEach-Object { [int]$_.assertions } | Measure-Object -Sum).Sum
                $log = Join-Path $runtime ".godot/phase2r_logs/$suiteId.log"
                $errors = Select-String $log -Pattern 'SCRIPT ERROR:|ERROR:|Unicode parsing error|Unexpected NUL character|before_all/after_all assert failed|\[Failed\]' -Quiet
                if ($suite.exit_code -ne 0 -or $errors -or $expected -eq 0 -or $cases.Count -ne $expected -or
                    @($cases | Where-Object { $_.status -ne 'pass' -or [int]$_.assertions -le 0 }).Count -or $xml.SelectNodes('//failure|//error|//skipped').Count) { throw "Suite failed/census mismatch: $name" }
                $suite.status = 'passed'
            } catch { $suite.status = 'failed'; $suite.error = $_.Exception.Message; $failures += "$name`: $($suite.error)" }
            Save-Record
        }
        if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
    }
    foreach ($path in $record.source_hashes.Keys) {
        if ((Get-Sha256 (Join-Path $runtime $path)) -ne $record.source_hashes[$path]) { throw "Source changed during qualification: $path" }
    }
    $record.status = if ($Lane -eq 'inventory' -and $RegenerateInventories) { 'diagnostic_inventory_generated' } else { 'passed_requires_evidence_review' }
} catch { $record.status = 'failed'; $record.error = $_.Exception.Message; throw }
finally { Preserve; Save-Record }
