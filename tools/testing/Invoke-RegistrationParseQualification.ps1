#requires -Version 7.0
# Diagnostic controller only; never merge this workflow/helper as product runtime.
# Dispatch or isolated controller push requires a separately reviewed exact candidate SHA.
# The archived workflow fallback remains REPLACE_WITH_REVIEWED_40_HEX_SHA and fails closed.
# Focused lane: untouched candidate, four inventory generate/check executions, full listed GUT suites.
# Native lane: baseline then candidate on one runner, each fresh and retained process;
# six exact3ed9cf1 overlay files, no compiler instrumentation, independently imported assets.
# qualification.json is the authority for runtime refs; nested legacy helper runtime_base stays88e44.
# Review generated inventory payloads and copy approved line-reference changes into product separately.
# Draft caveat: final candidate suite census and cold92-entry semantic test coverage require review.
# Native compilation counters count requests (including cache hits), not actual timeline process calls.
# Never overlay the old3fbc adapter probe onto candidate compiler code. An exact7-parse claim
# requires a separately reviewed narrow probe adapted to the candidate, outside this benchmark.

param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$CandidateRef,
    [Parameter(Mandatory)][ValidateSet('focused', 'native')][string]$Lane
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows cloud runner required.' }
$controller = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$baseRef = 'bb518236c741497d657b8b5bac19838b3ce1a4f0'
$overlayRef = '3ed9cf1fd51cc1910d1d2a96fb4eb87784bb822c'
$output = Join-Path $controller ".godot/ci/parse-$Lane"
if (Test-Path $output) { throw 'Fresh qualification output required.' }
New-Item -ItemType Directory -Path $output | Out-Null
function Invoke-ControllerGit([string[]]$Arguments) {
    $value = & git -C $controller -c core.autocrlf=false @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git failed: $Arguments" }
    return $value
}
foreach ($ref in @($baseRef, $CandidateRef, $overlayRef)) { Invoke-ControllerGit -Arguments @('fetch', '--no-tags', 'origin', $ref) | Out-Null }
$runtimeAllow = @('scripts/narrative/DialogicRuntimeAdapter.gd', 'scripts/narrative/DialogicEntryManifest.gd')
$runtimeChanges = @(Invoke-ControllerGit -Arguments @('diff', '--name-only', $baseRef, $CandidateRef, '--', 'autoload', 'scripts', 'addons', 'scenes', 'assets', 'data', 'project.godot'))
if ($runtimeChanges.Count -eq 0 -or @($runtimeChanges | Where-Object { $_ -notin $runtimeAllow }).Count) { throw "Unexpected runtime change set: $runtimeChanges" }
$overlays = @('autoload/ApplicationBootstrap.gd', 'autoload/SaveManager.gd', 'scripts/ui/MenuScene.gd',
    'tests/support/StartupAttributionTiming.gd', 'tests/integration/startup_new_acc_attribution.gd',
    'tools/testing/Invoke-StartupNewAccAttribution.ps1')
$record = [ordered]@{
    controller_ref = (Invoke-ControllerGit -Arguments @('rev-parse', 'HEAD')).Trim(); baseline_ref = $baseRef; candidate_ref = $CandidateRef
    overlay_ref = $overlayRef; lane = $Lane; runtime_changed_files = $runtimeChanges
    legacy_helper_runtime_base = '88e44efbf6d65cc3b70118e73923eb408db98b7e'
    provenance_note = 'Legacy helper runtime_base describes original instrumentation base. This wrapper records actual baseline/candidate commits; six overlay bytes are exact3ed9cf1. Baseline game code equals88e44. Compiler/manifest are never overlaid.'
    engine_sha256 = (Get-FileHash $env:GODOT_CONSOLE_PATH -Algorithm SHA256).Hash.ToLowerInvariant()
    order = @(); runs = @(); status = 'started'
}
if ($record.engine_sha256 -ne '63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a') { throw 'Unexpected Godot executable.' }
$equivalence = @(Invoke-ControllerGit -Arguments @('diff', '--name-only', $record.legacy_helper_runtime_base, $baseRef, '--', 'autoload', 'scripts', 'addons', 'scenes', 'assets', 'data', 'project.godot'))
if ($equivalence.Count) { throw 'Baseline game code differs from legacy runtime base.' }
function Save-Record { $record | ConvertTo-Json -Depth 50 | Set-Content (Join-Path $output 'qualification.json') -Encoding utf8 }
function Preserve([string]$runtime, [string]$label) {
    $dest = Join-Path $output $label
    foreach ($relative in @('.godot/ci', '.godot/phase2r_logs')) {
        $from = Join-Path $runtime $relative
        if (-not (Test-Path $from)) { continue }
        foreach ($file in Get-ChildItem $from -File -Recurse) {
            $name = [IO.Path]::GetRelativePath($runtime, $file.FullName).Replace('\','/')
            if ($name -match '/(?:shared-user|import-user)/') { continue }
            if ($file.Extension -notin @('.json', '.jsonl', '.log', '.xml', '.png')) { continue }
            $target = Join-Path $dest $name
            New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $target
        }
    }
    foreach ($name in @('game_state_surface.json', 'save_manager_surface.json')) {
        $from = Join-Path $runtime "evidence/phase_2r/runtime/$name"
        if (Test-Path $from) { New-Item -ItemType Directory -Force $dest | Out-Null; Copy-Item $from (Join-Path $dest $name) }
    }
}
try {
    $labels = if ($Lane -eq 'native') { @('baseline', 'candidate') } else { @('candidate') }
    foreach ($label in $labels) {
        $ref = if ($label -eq 'baseline') { $baseRef } else { $CandidateRef }
        $runtime = Join-Path $env:RUNNER_TEMP "parse-$Lane-$label"
        if (Test-Path $runtime) { throw 'Runtime checkout already exists.' }
        Invoke-ControllerGit -Arguments @('worktree', 'add', '--detach', $runtime, $ref) | Out-Null
        $run = [ordered]@{ label = $label; runtime_ref = $ref; overlay_hashes = @{}; runtime_hashes = @{}; status = 'started' }
        $record.order += $label; $record.runs += $run; Save-Record
        try {
            foreach ($path in $runtimeAllow) {
                $blob = (& git -C $runtime hash-object --no-filters -- $path).Trim()
                if ($blob -ne (Invoke-ControllerGit -Arguments @('rev-parse', "${ref}:$path")).Trim()) { throw "Runtime checkout byte mismatch: $path" }
                $run.runtime_hashes[$path] = (Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            if ($Lane -eq 'native') {
                foreach ($path in $overlays) {
                    # Restore directly from the pinned Git object: no newline/encoding translation by PowerShell.
                    & git -C $runtime -c core.autocrlf=false restore --source=$overlayRef --worktree -- $path
                    if ($LASTEXITCODE -ne 0) { throw "Overlay restore failed: $path" }
                    $blob = (& git -C $runtime hash-object --no-filters -- $path).Trim()
                    $expected = (Invoke-ControllerGit -Arguments @('rev-parse', "${overlayRef}:$path")).Trim()
                    if ($blob -ne $expected) { throw "Overlay byte mismatch: $path" }
                    $run.overlay_hashes[$path] = @{ git_blob = $blob; sha256 = (Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant() }
                }
            }
            $ci = Join-Path $runtime '.godot/ci'
            $env:APPDATA = Join-Path $ci 'import-user/appdata'; $env:LOCALAPPDATA = Join-Path $ci 'import-user/localappdata'; $env:DWM_TEST_ROOT = Join-Path $ci 'import-user/test-root'
            New-Item -ItemType Directory -Force $ci, $env:APPDATA, $env:LOCALAPPDATA, $env:DWM_TEST_ROOT | Out-Null
            $importStart = [Diagnostics.ProcessStartInfo]::new()
            $importStart.FileName = $env:GODOT_CONSOLE_PATH
            $importStart.WorkingDirectory = $runtime
            $importStart.UseShellExecute = $false
            $importStart.RedirectStandardOutput = $true
            $importStart.RedirectStandardError = $true
            foreach ($argument in @('--headless', '--path', $runtime, '--import', '--log-file', "$ci/import.log")) {
                $importStart.ArgumentList.Add($argument)
            }
            $importProcess = [Diagnostics.Process]::Start($importStart)
            try {
                $importOut = $importProcess.StandardOutput.ReadToEndAsync()
                $importErr = $importProcess.StandardError.ReadToEndAsync()
                $importFinished = $importProcess.WaitForExit(600000)
                if (-not $importFinished) {
                    $importProcess.Kill($true)
                    if (-not $importProcess.WaitForExit(10000)) { throw 'Import termination timeout.' }
                }
                if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($importOut, $importErr), 10000)) {
                    throw 'Import output drain timeout.'
                }
                $importOut.Result | Set-Content "$ci/import-stdout.log" -Encoding utf8
                $importErr.Result | Set-Content "$ci/import-stderr.log" -Encoding utf8
                $run.import = @{ timed_out = -not $importFinished; exit_code = $importProcess.ExitCode }
                if (-not $importFinished -or $importProcess.ExitCode -ne 0) { throw 'Import failed or exceeded 600 seconds.' }
            } finally { $importProcess.Dispose() }
            if (Select-String "$ci/import.log" -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) { throw 'Import errors.' }
            & git -C $runtime -c core.autocrlf=false restore --worktree -- project.godot
            if ($LASTEXITCODE -ne 0) { throw 'Project settings restoration failed.' }
            foreach ($path in $runtimeAllow) {
                if ((Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $run.runtime_hashes[$path]) { throw "Runtime changed during preparation: $path" }
            }
            if ($Lane -eq 'native') {
                foreach ($path in $overlays) {
                    if ((Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $run.overlay_hashes[$path].sha256) { throw "Overlay changed during import: $path" }
                }
                & (Join-Path $runtime 'tools/testing/Invoke-StartupNewAccAttribution.ps1')
                $receipt = Get-Content "$ci/startup-newacc/processes.json" -Raw | ConvertFrom-Json -AsHashtable
                if ($receipt.source_ref -ne $ref -or $receipt.processes.Count -ne 2) { throw 'Wrong native source/process census.' }
                foreach ($child in $receipt.processes) {
                    if (-not $child.clean_exit -or $child.exit_code -ne 0 -or $child.timed_out) { throw 'Native process failed.' }
                }
                $run.processes = $receipt.processes
            } else {
                & (Join-Path $runtime 'tools/testing/Invoke-PublicSurfaceValidation.ps1') -Regenerate -EmitPayloads
                $tests = @('test_scene_compiler_cache', 'test_dialogic_entry_manifest', 'test_scene_reading_registration',
                    'test_scene_registration_v2', 'test_scene_sequence_authoring', 'test_scene_event_contract',
                    'test_authored_week', 'test_scene_author_option_slots', 'test_dialogic_timeline_catalog', 'test_timeline_manifest')
                $expectedTests = 0
                foreach ($name in $tests) {
                    $file = Join-Path $runtime "tests/unit/$name.gd"
                    $expectedTests += @(Select-String -LiteralPath $file -Pattern '^func test_[^(]+\(').Count
                }
                $testArg = '-gtest=' + (($tests | ForEach-Object { "res://tests/unit/$_.gd" }) -join ',')
                & (Join-Path $runtime 'tools/testing/Invoke-IsolatedGodot.ps1') -SuiteId parse-focused -LogName parse-focused.log -EvidenceLogPath .godot/ci/parse-focused.jsonl -TimeoutSeconds 1800 -GodotArgs @('-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=', $testArg, '-gexit', '-glog=1', '-gjunit_xml_file=res://.godot/ci/parse-focused.xml')
                if ($LASTEXITCODE -ne 0) { throw 'Focused suite failed.' }
                if (Select-String (Join-Path $runtime '.godot/phase2r_logs/parse-focused.log') -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) { throw 'Focused suite logged script or Unicode errors.' }
                [xml]$xml = Get-Content "$ci/parse-focused.xml" -Raw
                $cases = @($xml.SelectNodes('//testcase'))
                if ($cases.Count -ne $expectedTests -or @($cases | Where-Object { $_.status -ne 'pass' }).Count -or $xml.SelectNodes('//failure|//error|//skipped').Count) { throw "Focused census/pass mismatch: $($cases.Count) expected$expectedTests" }
                $run.tests = $tests; $run.expected_tests = $expectedTests; $run.actual_tests = $cases.Count
                $run.assertions = ($cases | ForEach-Object { [int]$_.assertions } | Measure-Object -Sum).Sum
            }
            $run.status = 'passed'
        } finally { Preserve $runtime $label; Save-Record }
    }
    if ($Lane -eq 'native') {
        $record.comparison = @()
        foreach ($case in @('fresh', 'retained')) {
            $before = @($record.runs[0].processes | Where-Object case -eq $case)[0]
            $after = @($record.runs[1].processes | Where-Object case -eq $case)[0]
            foreach ($metric in @('launch_to_bootstrap_start_ms', 'launch_to_title_drawn_ms', 'new_acc_to_caption_complete_ms', 'confirm_to_caption_complete_ms')) {
                if (-not $before.ContainsKey($metric)) { continue }
                $record.comparison += @{ case = $case; metric = $metric; baseline = $before[$metric]; candidate = $after[$metric]; delta_ms = $after[$metric] - $before[$metric]; percent = 100.0 * ($after[$metric] - $before[$metric]) / $before[$metric] }
            }
        }
        $record.limits = 'One ordered baseline then candidate pair on same runner. Fresh profile is not cold OS cache. No acceptance speed threshold; NewAcc variations require review. Inclusive phase/profile times overlap. Sources contain identical temporary instrumentation; no compiler attribution probes. All captures require visual review.'
    }
    $record.status = 'passed_requires_evidence_review'
} finally { Save-Record }
