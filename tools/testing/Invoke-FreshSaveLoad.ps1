Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ci = Join-Path $repositoryRoot '.godot/ci'
$output = Join-Path $ci 'fresh-save-load'
$archive = Join-Path $repositoryRoot 'evidence/phase_2r/current_ci_20261023/final_retention/run39988834004/original-12517208437.zip'
$archiveHash = 'c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670'
$savedEnvironment = @{}

Push-Location $repositoryRoot
try {
    if (Test-Path -LiteralPath $output) { throw 'Fresh Save/Load output already exists; refusing stale evidence.' }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $archiveHash) {
        throw 'Retained native workload archive checksum mismatch.'
    }
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    # Keep historical input reports outside the current execution artifact.
    $retained = Join-Path $ci 'fresh-save-retained-input'
    Expand-Archive -LiteralPath $archive -DestinationPath $retained
    $helperHashes = Get-Content -LiteralPath (Join-Path $retained 'helper-hashes.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach ($helper in @('seed.gd', 'pair.gd', 'pair-next.gd', 'replay.gd')) {
        $source = Join-Path $retained $helper
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $helperHashes[$helper]) {
            throw "Retained helper checksum mismatch: $helper"
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $ci $helper)
    }
    $inputHashes = Get-Content -LiteralPath (Join-Path $retained 'terminal-root-hashes.json') -Raw | ConvertFrom-Json -AsHashtable
    if ($inputHashes.Count -ne 40) { throw 'Retained native workload must contain exactly 40 files.' }
    foreach ($relative in $inputHashes.Keys) {
        $file = Join-Path (Join-Path $retained 'terminal-root') $relative
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $inputHashes[$relative]) {
            throw "Retained input checksum mismatch: $relative"
        }
    }
    Copy-Item -LiteralPath (Join-Path $retained 'terminal-root-hashes.json') -Destination $ci
    Copy-Item -LiteralPath (Join-Path $retained 'terminal-root') -Destination $ci -Recurse
    foreach ($name in @('DWM_SCENE_VALIDATION_PROFILE', 'DWM_SAVE_LOAD_PROFILE', 'DWM_TERMINAL_COMPLETE')) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    $env:DWM_SCENE_VALIDATION_PROFILE = '1'
    $env:DWM_SAVE_LOAD_PROFILE = '1'
    $env:DWM_TERMINAL_COMPLETE = '0'
    $started = [DateTime]::UtcNow
    & (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
        -SuiteId 'fresh-save-load' -Rendered -TimeoutSeconds 900 `
        -LogName 'fresh-save-seed.log' -EvidenceLogPath '.godot/ci/fresh-save-load/processes.jsonl' `
        -GodotArgs @('--verbose', '-s', 'res://.godot/ci/seed.gd') `
        -NextLogName 'fresh-save-write.log' `
        -NextGodotArgs @('--verbose', '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
            '-gtest=res://.godot/ci/pair-next.gd', '-gexit', '-glog=1',
            '-gjunit_xml_file=res://.godot/ci/fresh-save-load/write.xml') `
        -ThirdLogName 'fresh-save-load.log' `
        -ThirdGodotArgs @('--verbose', '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
            '-gtest=res://tests/integration/fresh_save_load_child.gd', '-gexit', '-glog=1',
            '-gjunit_xml_file=res://.godot/ci/fresh-save-load/load.xml')
    $childExit = $LASTEXITCODE
    foreach ($name in @('terminal-pair.json', 'authored-week-terminal-pair.json',
        'computer-authored-restored-slot-2.png', 'computer-authored-terminal-pair.png',
        'computer-authored-restored-slot-3.png')) {
        $path = Join-Path $ci $name
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $output }
    }
    foreach ($name in @('fresh-save-seed.log', 'fresh-save-write.log', 'fresh-save-load.log')) {
        $path = Join-Path $repositoryRoot ".godot/phase2r_logs/$name"
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $output }
    }
    if ($childExit -ne 0) { throw "Fresh Save/Load native workload exited $childExit." }
    $assertions = @{}
    foreach ($phase in @('write', 'load')) {
        [xml]$xml = Get-Content -LiteralPath (Join-Path $output "$phase.xml") -Raw
        $cases = @($xml.SelectNodes('//testcase'))
        $expected = if ($phase -eq 'write') { 'test_genuine_ending_load_save' } else { 'test_fresh_current_save_load' }
        if ($cases.Count -ne 1 -or $cases[0].GetAttribute('name') -cne $expected -or
            $cases[0].GetAttribute('status') -cne 'pass' -or
            $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) {
            throw "Fresh Save/Load $phase did not execute its complete native case."
        }
        $assertions[$phase] = [int]$cases[0].GetAttribute('assertions')
        if ($assertions[$phase] -le 0 -or ($phase -eq 'write' -and $assertions[$phase] -ne 112)) {
            throw "Unexpected $phase assertion count."
        }
    }
    $written = Get-Content -LiteralPath (Join-Path $output 'terminal-pair.json') -Raw | ConvertFrom-Json -AsHashtable
    $loaded = Get-Content -LiteralPath (Join-Path $output 'fresh-load.json') -Raw | ConvertFrom-Json -AsHashtable
    $proof = Get-Content -LiteralPath (Join-Path $output 'authored-week-terminal-pair.json') -Raw | ConvertFrom-Json -AsHashtable
    if (-not $written.complete -or $written.pending_phase -ne '' -or $written.phases.Count -ne 3 -or
        @($written.phases | Where-Object { -not $_.ok }).Count -ne 0 -or
        -not $loaded.complete -or $loaded.pending_phase -ne '' -or $loaded.phases.Count -ne 2 -or
        @($loaded.phases | Where-Object { -not $_.ok }).Count -ne 0 -or
        $loaded.process_id -eq $written.process_id -or $loaded.creator_process_id -ne $written.process_id -or
        $loaded.source_slot_sha256 -cne $proof.slot_sha256 -or $loaded.recovery_journal_count -ne 0) {
        throw 'Fresh Save/Load result does not prove a new history-free Save loaded in a distinct process.'
    }
    $runtimeHashes = @{}
    foreach ($path in @('autoload/SaveManager.gd', 'autoload/GameState.gd',
        'scripts/infrastructure/save/CheckpointJournal.gd',
        'scripts/infrastructure/save/DesktopContinuationOperationJournal.gd',
        'scripts/infrastructure/save/SaveDocumentSchema.gd',
        'scripts/infrastructure/save/SaveMigrations.gd', 'scripts/narrative/FrozenRunContext.gd')) {
        $runtimeHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    if ((Get-FileHash -LiteralPath (Join-Path $output 'slot_3.json') -Algorithm SHA256).Hash.ToLowerInvariant() -cne $proof.slot_sha256) {
        throw 'Retained newly written Save bytes do not match the loaded source.'
    }
    $result = [ordered]@{
        source_ref = (git rev-parse HEAD).Trim(); archive_sha256 = $archiveHash
        scope = 'One current-build native Save followed by a fresh-process native Load of its history-free slot. Source state is the retained ending workload; no baseline pair or latency distribution is claimed.'
        helper_sha256 = $helperHashes
        runtime_sha256 = $runtimeHashes
        fresh_helper_sha256 = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot 'tests/integration/fresh_save_load_child.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
        runner_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        assertions = $assertions
        wall_seconds = ([DateTime]::UtcNow - $started).TotalSeconds
        write = $written; load = $loaded
    }
    $result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
    Write-Host ('FRESH_SAVE_LOAD_VERIFIED ' + ($result | ConvertTo-Json -Depth 30 -Compress))
} finally {
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    Pop-Location
}
