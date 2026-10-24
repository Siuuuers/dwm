#requires -Version 7.0
# Isolated qualification controller; never merge into the product branch.
# All product runtime remains the exact supplied commit plus explicitly recorded
# timing-only contextual instrumentation for the native lane. No production file
# is restored wholesale from an old diagnostic revision. A patch conflict fails closed.
# Engine and PowerShell execution belong on Windows cloud runners only.
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$CandidateRef,
    [Parameter(Mandatory)][ValidateSet('focused', 'native', 'inventory', 'save-load', 'attribution')][string]$Lane,
    [Parameter(Mandatory)][string[]]$RuntimePaths,
    [string[]]$FocusedTests = @(),
    [switch]$CandidateFirst
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows cloud runner required.' }
$controller = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$baseRef = 'a5a7da03b9573ab2d751129de0063027dd2d2d50'
$overlayRef = '3ed9cf1fd51cc1910d1d2a96fb4eb87784bb822c'
$output = Join-Path $controller ".godot/ci/newacc-$Lane"
if (Test-Path $output) { throw 'Fresh qualification output required.' }
New-Item -ItemType Directory -Path $output | Out-Null
function Invoke-ControllerGit([string[]]$Arguments) {
    $value = & git -C $controller -c core.autocrlf=false @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git failed: $Arguments" }
    return $value
}
foreach ($ref in @($baseRef, $CandidateRef, $overlayRef)) { Invoke-ControllerGit -Arguments @('fetch', '--no-tags', 'origin', $ref) | Out-Null }
$runtimeAllow = $RuntimePaths
if ($runtimeAllow.Count -eq 0 -or @($runtimeAllow | Where-Object { $_ -notmatch '^(autoload|scripts)/[A-Za-z0-9_./-]+\.gd$' -or $_ -match '\.\.' }).Count) { throw 'Explicit reviewed GDScript runtime paths required.' }
$runtimeChanges = @(Invoke-ControllerGit -Arguments @('diff', '--name-only', $baseRef, $CandidateRef, '--', 'autoload', 'scripts', 'addons', 'scenes', 'assets', 'data', 'dialogic', 'localization', 'project.godot'))
if ($runtimeChanges.Count -eq 0 -or @($runtimeChanges | Where-Object { $_ -notin $runtimeAllow }).Count) { throw "Unexpected runtime change set: $runtimeChanges" }
$instrumentedPaths = @('autoload/ApplicationBootstrap.gd', 'autoload/SaveManager.gd', 'scripts/ui/MenuScene.gd')
$overlays = @('tests/support/StartupAttributionTiming.gd', 'tests/integration/startup_new_acc_attribution.gd',
    'tools/testing/Invoke-StartupNewAccAttribution.ps1')
$record = [ordered]@{
    controller_ref = (Invoke-ControllerGit -Arguments @('rev-parse', 'HEAD')).Trim(); baseline_ref = $baseRef; candidate_ref = $CandidateRef
    overlay_ref = $overlayRef; lane = $Lane; runtime_changed_files = $runtimeChanges
    legacy_helper_runtime_base = '88e44efbf6d65cc3b70118e73923eb408db98b7e'
    provenance_note = 'Actual runtime refs are recorded here. Production instrumentation is a pinned contextual patch, never a whole-file overlay. Three diagnostic helper files retain exact pinned bytes. Legacy helper runtime_base describes only original instrumentation provenance.'
    engine_sha256 = (Get-FileHash $env:GODOT_CONSOLE_PATH -Algorithm SHA256).Hash.ToLowerInvariant()
    order = @(); runs = @(); status = 'started'
}
if ($record.engine_sha256 -ne '63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a') { throw 'Unexpected Godot executable.' }
$instrumentationPatch = Join-Path $output 'startup-instrumentation.patch'
if ($Lane -eq 'native') {
    Invoke-ControllerGit -Arguments (@('diff', '--binary', "--output=$instrumentationPatch", $record.legacy_helper_runtime_base, $overlayRef, '--') + $instrumentedPaths) | Out-Null
    $record.instrumentation_patch_sha256 = (Get-FileHash $instrumentationPatch -Algorithm SHA256).Hash.ToLowerInvariant()
}
if ($Lane -eq 'focused' -and ($FocusedTests.Count -eq 0 -or @($FocusedTests | Where-Object { $_ -notmatch '^tests/(unit|integration)/test_[a-z0-9_]+\.gd$' }).Count)) { throw 'Explicit focused suite names required.' }
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
    $labels = if ($Lane -eq 'native') { if ($CandidateFirst) { @('candidate', 'baseline') } else { @('baseline', 'candidate') } } else { @('candidate') }
    foreach ($label in $labels) {
        $ref = if ($label -eq 'baseline') { $baseRef } else { $CandidateRef }
        $runtime = Join-Path $env:RUNNER_TEMP "newacc-$Lane-$label"
        if (Test-Path $runtime) { throw 'Runtime checkout already exists.' }
        Invoke-ControllerGit -Arguments @('worktree', 'add', '--detach', $runtime, $ref) | Out-Null
        $run = [ordered]@{ label = $label; runtime_ref = $ref; overlay_hashes = @{}; source_runtime_hashes = @{}; runtime_hashes = @{}; status = 'started' }
        $record.order += $label; $record.runs += $run; Save-Record
        try {
            foreach ($path in $runtimeAllow) {
                $blob = (& git -C $runtime hash-object --no-filters -- $path).Trim()
                if ($blob -ne (Invoke-ControllerGit -Arguments @('rev-parse', "${ref}:$path")).Trim()) { throw "Runtime checkout byte mismatch: $path" }
                $run.source_runtime_hashes[$path] = (Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            if ($Lane -eq 'native') {
                & git -C $runtime apply --check -- $instrumentationPatch
                if ($LASTEXITCODE -ne 0) { throw 'Pinned instrumentation conflicts with runtime; adapt explicitly before qualification.' }
                & git -C $runtime apply -- $instrumentationPatch
                if ($LASTEXITCODE -ne 0) { throw 'Instrumentation patch failed.' }
                foreach ($path in $instrumentedPaths) {
                    $run.overlay_hashes[$path] = @{ sha256 = (Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant(); method = 'contextual_patch' }
                }
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
            foreach ($path in $runtimeAllow) {
                $run.runtime_hashes[$path] = (Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            if ($Lane -eq 'save-load') {
                & (Join-Path $runtime 'tools/testing/Invoke-FreshSaveLoadComparison.ps1') -BaseRef $baseRef -CandidateFirst:$CandidateFirst
                if ($LASTEXITCODE -ne 0) { throw 'Save/Load comparison failed.' }
                $comparison = Get-Content (Join-Path $runtime '.godot/ci/fresh-save-load-comparison/comparison.json') -Raw | ConvertFrom-Json -AsHashtable
                if (-not $comparison.complete -or $comparison.base_ref -ne $baseRef -or $comparison.candidate_ref -ne $CandidateRef) { throw 'Save/Load comparison provenance/completion mismatch.' }
                $run.comparison = $comparison
                $run.status = 'passed'
                continue
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
                foreach ($path in ($overlays + $instrumentedPaths)) {
                    if ((Get-FileHash (Join-Path $runtime $path) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $run.overlay_hashes[$path].sha256) { throw "Overlay changed during import: $path" }
                }
                & (Join-Path $runtime 'tools/testing/Invoke-StartupNewAccAttribution.ps1')
                $receipt = Get-Content "$ci/startup-newacc/processes.json" -Raw | ConvertFrom-Json -AsHashtable
                if ($receipt.source_ref -ne $ref -or $receipt.processes.Count -ne 2) { throw 'Wrong native source/process census.' }
                foreach ($child in $receipt.processes) {
                    if (-not $child.clean_exit -or $child.exit_code -ne 0 -or $child.timed_out) { throw 'Native process failed.' }
                    $childReport = Get-Content (Join-Path $ci ("startup-newacc/" + $child.case + '/results.json')) -Raw | ConvertFrom-Json -AsHashtable
                    if (-not $childReport.complete -or $childReport.failures.Count -ne 0) { throw 'Native child report failed.' }
                    $child.max_new_acc_frame_gap_ms = $childReport.max_new_acc_frame_gap_us / 1000.0
                }
                $run.processes = $receipt.processes
            } elseif ($Lane -eq 'attribution') {
                & (Join-Path $runtime 'tools/testing/Invoke-FreshSaveLoad.ps1')
                if ($LASTEXITCODE -ne 0) { throw 'Save/Load attribution workload failed.' }
                $result = Get-Content (Join-Path $ci 'fresh-save-load/result.json') -Raw | ConvertFrom-Json -AsHashtable
                if ($result.source_ref -ne $CandidateRef) { throw 'Attribution source mismatch.' }
                $profiles = @()
                foreach ($logName in @('fresh-save-write.log', 'fresh-save-load.log')) {
                    $log = Join-Path $runtime ('.godot/phase2r_logs/' + $logName)
                    foreach ($line in Get-Content -LiteralPath $log) {
                        if ($line.StartsWith('DWM_SCENE_VALIDATION_PROFILE ')) {
                            $profile = $line.Substring('DWM_SCENE_VALIDATION_PROFILE '.Length) | ConvertFrom-Json -AsHashtable
                            $profile.diagnostic_log = $logName
                            $profiles += $profile
                        }
                    }
                }
                $observations = @($profiles | ForEach-Object { $_.snapshot_validations })
                if ($observations.Count -eq 0 -or @($observations | Where-Object { $_.callers.Count -eq 0 -or -not $_.snapshot_hash_ok -or -not $_.bundle_hash_ok }).Count) {
                    throw 'Attribution requires nonempty caller stacks and admitted input hashes.'
                }
                $profiles | ConvertTo-Json -Depth 50 | Set-Content (Join-Path $ci 'snapshot-callers.json') -Encoding utf8
                $run.result = $result; $run.snapshot_observations = $observations.Count
                $run.limits = 'Instrumentation-only attribution. Exact canonical input hashes do not establish object identity or justify reuse across callbacks. Metadata overhead is recorded separately and included in enclosing elapsed times. No performance comparison claim.'
            } elseif ($Lane -eq 'inventory') {
                & (Join-Path $runtime 'tools/testing/Invoke-PublicSurfaceValidation.ps1') -EmitPayloads
                if ($LASTEXITCODE -ne 0) { throw 'Read-only inventory verification failed.' }
            } else {
                & (Join-Path $runtime 'tools/testing/Invoke-PublicSurfaceValidation.ps1') -Regenerate -EmitPayloads
                $tests = $FocusedTests
                $expectedTests = 0
                foreach ($name in $tests) {
                    $file = Join-Path $runtime "$name"
                    $expectedTests += @(Select-String -LiteralPath $file -Pattern '^func test_[^(]+\(').Count
                }
                $testArg = '-gtest=' + (($tests | ForEach-Object { "res://$_" }) -join ',')
                & (Join-Path $runtime 'tools/testing/Invoke-IsolatedGodot.ps1') -SuiteId newacc-focused -LogName newacc-focused.log -EvidenceLogPath .godot/ci/newacc-focused.jsonl -TimeoutSeconds 1800 -GodotArgs @('-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=', $testArg, '-gexit', '-glog=1', '-gjunit_xml_file=res://.godot/ci/newacc-focused.xml')
                if ($LASTEXITCODE -ne 0) { throw 'Focused suite failed.' }
                if (Select-String (Join-Path $runtime '.godot/phase2r_logs/newacc-focused.log') -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) { throw 'Focused suite logged script or Unicode errors.' }
                [xml]$xml = Get-Content "$ci/newacc-focused.xml" -Raw
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
            $before = @((@($record.runs | Where-Object label -eq 'baseline')[0]).processes | Where-Object case -eq $case)[0]
            $after = @((@($record.runs | Where-Object label -eq 'candidate')[0]).processes | Where-Object case -eq $case)[0]
            foreach ($metric in @('launch_to_bootstrap_start_ms', 'launch_to_title_drawn_ms', 'new_acc_to_caption_complete_ms', 'confirm_to_caption_complete_ms', 'max_new_acc_frame_gap_ms')) {
                if (-not $before.ContainsKey($metric)) { continue }
                $record.comparison += @{ case = $case; metric = $metric; baseline = $before[$metric]; candidate = $after[$metric]; delta_ms = $after[$metric] - $before[$metric]; percent = 100.0 * ($after[$metric] - $before[$metric]) / $before[$metric] }
            }
        }
        $record.limits = 'One ordered pair on same runner; actual order recorded above. Fresh profile is not cold OS cache. No acceptance speed threshold; NewAcc variations require review. Inclusive phase/profile times overlap. Both variants use the same contextual instrumentation patch and identical helper bytes; no compiler attribution probes. All captures require visual review.'
    }
    $record.status = 'passed_requires_evidence_review'
} finally { Save-Record }
