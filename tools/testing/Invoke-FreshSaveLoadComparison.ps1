param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$BaseRef,
    [switch]$CandidateFirst
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$BaseRef = $BaseRef.ToLowerInvariant()
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/fresh-save-load-comparison'
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('dwm-fresh-pair-' + [Guid]::NewGuid().ToString('N'))
$runtimeRoots = @('autoload', 'scripts', 'scenes', 'dialogic', 'localization', 'project.godot')
$measurementPaths = @('tools/testing/Invoke-FreshSaveLoad.ps1', 'tools/testing/Invoke-IsolatedGodot.ps1',
    'tests/integration/fresh_save_load_child.gd', 'tests/integration/authored_week_child.gd')
$archivePath = 'evidence/phase_2r/current_ci_20261023/final_retention/run39988834004/original-12517208437.zip'
$outputCreated = $false
$worktrees = @{}
$savedEnvironment = @{}
$order = if ($CandidateFirst) { @('candidate', 'baseline') } else { @('baseline', 'candidate') }
$comparison = [ordered]@{ complete = $false; base_ref = $BaseRef; candidate_ref = ''; order = $order
    scope = 'Same runner, exact separate Git worktrees, identical measurement helpers and retained input. Each variant writes a new Save9 and loads it in another process. One ordered pair is not a latency distribution. Generated slot identities may differ.'
    runtime_files = @(); measurement_sha256 = @{}; variants = @(); error = $null }
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Save-Comparison {
    $comparison | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $output 'comparison.json') -Encoding utf8
}
Push-Location $repositoryRoot
try {
    if (Test-Path -LiteralPath $output) { throw 'Comparison output already exists; refusing stale evidence.' }
    New-Item -ItemType Directory -Path $output | Out-Null
    $outputCreated = $true
    $comparison.candidate_ref = (git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Candidate commit is unavailable.' }
    git cat-file -e "$BaseRef^{commit}"
    if ($LASTEXITCODE -ne 0) {
        git fetch --no-tags --depth=1 origin $BaseRef
        if ($LASTEXITCODE -ne 0) { throw 'Baseline commit could not be fetched.' }
    }
    $runtimePaths = @(git diff --name-only $BaseRef $comparison.candidate_ref -- @runtimeRoots)
    if ($LASTEXITCODE -ne 0 -or $runtimePaths.Count -eq 0) { throw 'No changed runtime files to compare.' }
    $nonModifications = @(git diff --name-only --diff-filter=ACDRTUXB $BaseRef $comparison.candidate_ref -- @runtimeRoots)
    if ($LASTEXITCODE -ne 0 -or $nonModifications.Count -ne 0) { throw 'Comparison supports modified runtime files only, not additions/deletions/renames.' }
    $comparison.runtime_files = $runtimePaths
    $engine = [Environment]::GetEnvironmentVariable('GODOT_CONSOLE_PATH')
    if ([string]::IsNullOrWhiteSpace($engine) -or -not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Checksum-installed GODOT_CONSOLE_PATH is required.' }
    $comparison.wrapper_sha256 = Get-Sha256 $PSCommandPath
    $comparison.engine_sha256 = Get-Sha256 $engine
    $comparison.engine_version = (& $engine --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $comparison.engine_version -notmatch '^4\.6\.3\.stable') { throw 'Godot 4.6.3 standard is required.' }
    $comparison.engine_provenance = 'Workflow verifies the official release archive; this helper records and rechecks the installed executable.'
    foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'DWM_TEST_ROOT', 'DWM_SCENE_VALIDATION_PROFILE', 'DWM_SAVE_LOAD_PROFILE', 'DWM_TERMINAL_COMPLETE')) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    foreach ($variant in @('baseline', 'candidate')) {
        $ref = if ($variant -eq 'baseline') { $BaseRef } else { $comparison.candidate_ref }
        $worktree = Join-Path $temporaryRoot $variant
        git -c core.autocrlf=false worktree add --detach $worktree $ref
        if ($LASTEXITCODE -ne 0) { throw "Cannot create $variant worktree." }
        $worktrees[$variant] = $worktree
        if ((git -C $worktree rev-parse HEAD).Trim() -cne $ref) { throw "$variant checkout does not match its source pin." }
        $hashes = @{}
        foreach ($path in $measurementPaths + @($archivePath)) { $hashes[$path] = Get-Sha256 (Join-Path $worktree $path) }
        if ($variant -eq 'baseline') { $comparison.measurement_sha256 = $hashes }
        else {
            foreach ($path in $hashes.Keys) {
                if ($hashes[$path] -cne $comparison.measurement_sha256[$path]) { throw "Measurement/input source differs: $path" }
            }
        }
    }
    Save-Comparison
    foreach ($variant in $order) {
        $worktree = $worktrees[$variant]
        $variantOutput = Join-Path $output $variant
        New-Item -ItemType Directory -Path $variantOutput | Out-Null
        $record = [ordered]@{ variant = $variant; source_ref = (git -C $worktree rev-parse HEAD).Trim()
            runtime_sha256 = @{}; complete = $false; result = $null; error = $null }
        $comparison.variants += $record
        try {
            if ((Get-Sha256 $engine) -cne $comparison.engine_sha256) { throw 'Installed engine changed between variants.' }
            foreach ($path in $runtimePaths) { $record.runtime_sha256[$path] = Get-Sha256 (Join-Path $worktree $path) }
            # Import before any script-based isolation probe needs the global class cache.
            $importRoot = Join-Path $worktree '.godot/ci/import-user'
            foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'DWM_TEST_ROOT')) {
                $path = Join-Path $importRoot $name
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                [Environment]::SetEnvironmentVariable($name, $path)
            }
            $importLog = Join-Path $variantOutput 'fresh-pair-import.log'
            $start = [Diagnostics.ProcessStartInfo]::new()
            $start.FileName = $engine
            $start.UseShellExecute = $false
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            foreach ($argument in @('--headless', '--path', $worktree, '--import', '--log-file', $importLog)) { $start.ArgumentList.Add($argument) }
            $process = [Diagnostics.Process]::Start($start)
            try {
                $stdout = $process.StandardOutput.ReadToEndAsync()
                $stderr = $process.StandardError.ReadToEndAsync()
                $finished = $process.WaitForExit(480000)
                if (-not $finished) { $process.Kill($true); $process.WaitForExit(10000) | Out-Null }
                if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 10000)) { throw "$variant import output did not close." }
                $stdout.Result + $stderr.Result | Set-Content -LiteralPath (Join-Path $variantOutput 'import-console.log') -Encoding utf8
                if (-not $finished -or $process.ExitCode -ne 0) { throw "$variant import failed or timed out." }
                if (-not (Test-Path -LiteralPath $importLog) -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet)) { throw "$variant import has missing/error evidence." }
            } finally { $process.Dispose() }
            git -C $worktree restore --source=$($record.source_ref) --worktree -- project.godot
            if ($LASTEXITCODE -ne 0) { throw "$variant project settings restoration failed." }
            git -C $worktree diff --exit-code $record.source_ref -- @runtimeRoots @measurementPaths
            if ($LASTEXITCODE -ne 0) { throw "$variant import changed measured source." }
            foreach ($path in $runtimePaths) {
                if ((Get-Sha256 (Join-Path $worktree $path)) -cne $record.runtime_sha256[$path]) { throw "$variant runtime changed during import: $path" }
            }
            & (Join-Path $worktree 'tools/testing/Invoke-FreshSaveLoad.ps1')
            if ($LASTEXITCODE -ne 0) { throw "$variant fresh Save/Load failed." }
            $resultPath = Join-Path $worktree '.godot/ci/fresh-save-load/result.json'
            $record.result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json -AsHashtable
            if ($record.result.source_ref -cne $record.source_ref -or -not $record.result.write.complete -or
                -not $record.result.load.complete -or $record.result.assertions.write -ne 112 -or
                $record.result.assertions.load -le 0 -or $record.result.load.recovery_journal_count -ne 0) { throw "$variant native result is incomplete or has wrong provenance." }
            foreach ($path in $runtimePaths) {
                if ((Get-Sha256 (Join-Path $worktree $path)) -cne $record.runtime_sha256[$path]) { throw "$variant runtime changed during measurement: $path" }
            }
            foreach ($path in $measurementPaths + @($archivePath)) {
                if ((Get-Sha256 (Join-Path $worktree $path)) -cne $comparison.measurement_sha256[$path]) { throw "$variant measurement/input source changed: $path" }
            }
            if ((Get-Sha256 $engine) -cne $comparison.engine_sha256) { throw 'Installed engine changed during measurement.' }
            $record.complete = $true
        } catch {
            $record.error = $_.Exception.Message
            throw
        } finally {
            # Copy whatever exists even if import, native execution or result verification fails.
            $nativeOutput = Join-Path $worktree '.godot/ci/fresh-save-load'
            if (Test-Path -LiteralPath $nativeOutput) { Get-ChildItem -LiteralPath $nativeOutput -Force | Copy-Item -Destination $variantOutput -Recurse -Force }
            foreach ($relative in @('.godot/phase2r_logs/fresh-save-seed.log', '.godot/phase2r_logs/fresh-save-write.log', '.godot/phase2r_logs/fresh-save-load.log')) {
                $path = Join-Path $worktree $relative
                if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $variantOutput -Force }
            }
            Save-Comparison
        }
    }
    $first = $comparison.variants[0].result
    $second = $comparison.variants[1].result
    if ($first.write.source_slot_sha256 -cne $second.write.source_slot_sha256 -or
        $first.archive_sha256 -cne $second.archive_sha256 -or
        $first.assertions.load -ne $second.assertions.load -or
        $first.fresh_helper_sha256 -cne $second.fresh_helper_sha256 -or $first.runner_sha256 -cne $second.runner_sha256) {
        throw 'Variants did not execute the same retained source and measurement contract.'
    }
    $comparison.complete = $true
    Save-Comparison
    Write-Host ('FRESH_SAVE_LOAD_COMPARISON_VERIFIED ' + (Join-Path $output 'comparison.json'))
} catch {
    $comparison.error = $_.Exception.Message
    if ($outputCreated) { Save-Comparison }
    throw
} finally {
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    foreach ($worktree in $worktrees.Values) {
        git -C $repositoryRoot worktree remove --force $worktree
        if ($LASTEXITCODE -ne 0) { Write-Warning "Could not remove owned temporary worktree: $worktree" }
    }
    if ((Test-Path -LiteralPath $temporaryRoot) -and @(Get-ChildItem -LiteralPath $temporaryRoot -Force).Count -eq 0) { Remove-Item -LiteralPath $temporaryRoot }
    Pop-Location
}
