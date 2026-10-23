param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$BaseRef
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$ci = Join-Path $repositoryRoot '.godot/ci'
$output = Join-Path $ci 'startup-load-comparison'
$archive = Join-Path $repositoryRoot 'evidence/phase_2r/current_ci_20261023/final_retention/run39988834004/original-12517208437.zip'
$archiveHash = 'c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670'
$runtimePaths = @()
$helpers = @('seed.gd', 'pair.gd', 'pair-next.gd', 'replay.gd')
$generated = @('terminal-pair.json', 'authored-week-terminal-pair.json',
    'computer-authored-restored-slot-2.png', 'computer-authored-terminal-pair.png')
$savedBytes = @{}
$savedEnvironment = @{}
$comparison = [ordered]@{
    base_ref = $BaseRef; candidate_ref = ''; archive_sha256 = $archiveHash
    scope = 'Same candidate checkout and retained 40-file input; only the named runtime files are replaced by base bytes for the baseline. Fresh processes and isolated roots per variant. Timings are one matched pair, not a latency distribution.'
    runtime_files = @(); helper_hashes = @{}; variants = @()
}

Push-Location $repositoryRoot
try {
    git cat-file -e "$BaseRef^{commit}"
    if ($LASTEXITCODE -ne 0) { throw 'Baseline commit is unavailable.' }
    # Compare every changed runtime file, not a hard-coded subset from an earlier optimization.
    $runtimePaths = @(git diff --name-only $BaseRef HEAD -- autoload scripts scenes dialogic localization project.godot)
    if ($LASTEXITCODE -ne 0 -or $runtimePaths.Count -eq 0) { throw 'No runtime comparison paths found.' }
    foreach ($path in $runtimePaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $path))) { throw "Deleted runtime path requires a separate baseline checkout: $path" }
        git cat-file -e "${BaseRef}:$path"
        if ($LASTEXITCODE -ne 0) { throw "Added runtime path requires a separate baseline checkout: $path" }
    }
    $comparison.runtime_files = $runtimePaths
    git diff --exit-code -- @runtimePaths
    if ($LASTEXITCODE -ne 0) { throw 'Comparison requires clean runtime files.' }
    $comparison.candidate_ref = (git rev-parse HEAD).Trim()
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $archiveHash) {
        throw 'Retained native workload archive checksum mismatch.'
    }
    if (Test-Path -LiteralPath $output) { throw 'Comparison output already exists; refusing stale evidence.' }
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    $retained = Join-Path $ci 'startup-load-retained-input'
    Expand-Archive -LiteralPath $archive -DestinationPath $retained
    $helperHashes = Get-Content -LiteralPath (Join-Path $retained 'helper-hashes.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach ($helper in $helpers) {
        $source = Join-Path $retained $helper
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $helperHashes[$helper]) {
            throw "Retained helper checksum mismatch: $helper"
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $ci $helper)
    }
    $comparison.helper_hashes = $helperHashes
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
    foreach ($path in $runtimePaths) { $savedBytes[$path] = [IO.File]::ReadAllBytes((Join-Path $repositoryRoot $path)) }
    foreach ($name in @('DWM_SCENE_VALIDATION_PROFILE', 'DWM_SAVE_LOAD_PROFILE', 'DWM_TERMINAL_COMPLETE')) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    $env:DWM_SCENE_VALIDATION_PROFILE = '1'
    $env:DWM_SAVE_LOAD_PROFILE = '1'
    $env:DWM_TERMINAL_COMPLETE = '0'

    foreach ($variant in @('candidate', 'baseline')) {
        if ($variant -eq 'baseline') {
            git restore --source=$BaseRef --worktree -- @runtimePaths
            if ($LASTEXITCODE -ne 0) { throw 'Could not install baseline runtime files.' }
        } else {
            foreach ($path in $runtimePaths) { [IO.File]::WriteAllBytes((Join-Path $repositoryRoot $path), $savedBytes[$path]) }
        }
        $variantOutput = Join-Path $output $variant
        New-Item -ItemType Directory -Path $variantOutput | Out-Null
        $runtimeHashes = @{}
        foreach ($path in $runtimePaths) {
            $runtimeHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        foreach ($name in $generated) {
            $path = Join-Path $ci $name
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
        }
        $reportRelative = ".godot/ci/startup-load-comparison/$variant/result.xml"
        $evidenceRelative = ".godot/ci/startup-load-comparison/$variant/processes.jsonl"
        $started = [DateTime]::UtcNow
        & (Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1') `
            -SuiteId "startup-load-$variant" -Rendered -TimeoutSeconds 900 `
            -LogName "startup-load-$variant-seed.log" -EvidenceLogPath $evidenceRelative `
            -GodotArgs @('--verbose', '-s', 'res://.godot/ci/seed.gd') `
            -NextLogName "startup-load-$variant.log" `
            -NextGodotArgs @('--verbose', '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
                '-gtest=res://.godot/ci/pair-next.gd', '-gexit', '-glog=1', "-gjunit_xml_file=res://$reportRelative")
        $childExit = $LASTEXITCODE
        foreach ($name in $generated) {
            $path = Join-Path $ci $name
            if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $variantOutput }
        }
        foreach ($name in @("startup-load-$variant-seed.log", "startup-load-$variant.log")) {
            $path = Join-Path $repositoryRoot ".godot/phase2r_logs/$name"
            if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination $variantOutput }
        }
        if ($childExit -ne 0) { throw "$variant native workload exited $childExit." }
        [xml]$xml = Get-Content -LiteralPath (Join-Path $repositoryRoot $reportRelative) -Raw
        $cases = @($xml.SelectNodes('//testcase'))
        if ($cases.Count -ne 1 -or $cases[0].GetAttribute('name') -cne 'test_genuine_ending_load_save' -or
            $cases[0].GetAttribute('classname') -cne '.godot/ci/pair-next.gd' -or
            $cases[0].GetAttribute('status') -cne 'pass' -or [int]$cases[0].GetAttribute('assertions') -ne 112 -or
            $xml.SelectNodes('//failure | //error | //skipped').Count -ne 0) {
            throw "$variant did not execute the complete retained 112-assertion native workload."
        }
        $result = Get-Content -LiteralPath (Join-Path $variantOutput 'terminal-pair.json') -Raw | ConvertFrom-Json -AsHashtable
        if (-not $result.complete -or $result.pending_phase -ne '' -or $result.phases.Count -ne 3 -or
            @($result.phases | Where-Object { -not $_.ok }).Count -ne 0) { throw "$variant workload is incomplete." }
        $loads = @(Select-String -LiteralPath (Join-Path $variantOutput "startup-load-$variant.log") `
            -Pattern '^Loading resource: res://dialogic/timelines/authored_week/Day[1-7]\.dtl$')
        $comparison.variants += [ordered]@{ variant = $variant; runtime_sha256 = $runtimeHashes
            wall_seconds = ([DateTime]::UtcNow - $started).TotalSeconds; assertions = 112
            authored_day_resource_load_messages = $loads.Count; result = $result }
        $comparison | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $output 'comparison.json') -Encoding utf8
        Write-Host ("STARTUP_LOAD_RESULT " + ($comparison.variants[-1] | ConvertTo-Json -Depth 20 -Compress))
    }
    if ($comparison.variants[0].result.source_slot_sha256 -cne $comparison.variants[1].result.source_slot_sha256 -or
        $comparison.variants[0].result.process_id -eq $comparison.variants[1].result.process_id) {
        throw 'Matched variants did not use the same source slot in separate processes.'
    }
} finally {
    foreach ($path in $savedBytes.Keys) { [IO.File]::WriteAllBytes((Join-Path $repositoryRoot $path), $savedBytes[$path]) }
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    Pop-Location
}
