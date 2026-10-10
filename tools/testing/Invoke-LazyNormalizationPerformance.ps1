param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/lazy-normalization'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$checkoutRef = (& git rev-parse HEAD)
if ($LASTEXITCODE -ne 0) { throw 'Could not identify the benchmark checkout.' }
$historyRoot = Join-Path $repositoryRoot '.godot/ci/seven-day-history'
$history = Get-Content -LiteralPath (Join-Path $historyRoot 'results.json') -Raw | ConvertFrom-Json
$document = Join-Path $historyRoot 'day7-autosave.json'
$inputHash = (Get-FileHash -LiteralPath $document -Algorithm SHA256).Hash.ToLowerInvariant()
if ($history.checkout_ref -cne $checkoutRef -or $history.payload_sha256 -cne $inputHash -or
    $history.cold_read.retained_checkpoint_count -ne 66 -or $history.write.retained.line -ne 32 -or
    $history.write.retained.manual_save -ne 32 -or $history.write.retained.semantic -ne 2) {
    throw "Lazy normalization requires this checkout's fresh verified Day7 payload and all 66 checkpoints."
}
$sourceHashes = [ordered]@{}
foreach ($entry in @(
    @('schema', 'scripts/infrastructure/save/SaveDocumentSchema.gd'),
    @('port', 'scripts/application/run/SaveManagerCheckpointPort.gd'),
    @('reference', 'tests/support/EagerNormalizationReference.gd'),
    @('harness', 'tests/manual/benchmark_lazy_normalization.gd'))) {
    $sourceHashes[$entry[0]] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $entry[1]) -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Median {
    param([object[]]$Values)
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { throw 'Median requires samples.' }
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) { return [double]$sorted[$middle] }
    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

$metrics = @('schema_helper', 'port_helper', 'port_seam')
$pairs = @()
foreach ($mode in @('full', 'splice')) {
    for ($pair = 1; $pair -le 4; $pair++) {
        $order = if ($pair % 2 -eq 1) { @('baseline', 'candidate') } else { @('candidate', 'baseline') }
        $row = [ordered]@{ mode = $mode; pair = $pair; order = $order }
        foreach ($variant in $order) {
            $name = "$mode-$pair-$variant"
            $logName = "cloud-lazy-normalization-$name.log"
            & $runner -SuiteId "cloud-lazy-normalization-$name" -LogName $logName `
                -EvidenceLogPath ".godot/ci/lazy-normalization/$name.jsonl" -TimeoutSeconds 180 `
                -GodotArgs @('-s', 'res://tests/manual/benchmark_lazy_normalization.gd', '--',
                    "--document=$document", "--variant=$variant", "--mode=$mode") | Out-Null
            $result = $LASTEXITCODE
            $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
            if ($result -ne 0) {
                if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
                throw "Lazy normalization $name failed with exit $result."
            }
            if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) {
                throw "Lazy normalization $name reported a script or Unicode error."
            }
            $prefix = 'LAZY_NORMALIZATION_BENCHMARK: '
            $markers = @(Get-Content -LiteralPath $log | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) } |
                ForEach-Object { $_.Substring($prefix.Length) | ConvertFrom-Json })
            if ($markers.Count -ne 1) { throw 'Expected one lazy normalization measurement.' }
            $measurement = $markers[0]
            if ($measurement.variant -cne $variant -or $measurement.mode -cne $mode -or
                $measurement.input_sha256 -cne $inputHash -or $measurement.output_sha256 -cne $inputHash -or
                $measurement.bytes -ne (Get-Item -LiteralPath $document).Length -or
                $measurement.journal_bundles -ne 66 -or $measurement.validated_journal_bundles -ne 66 -or
                $measurement.schema_version -ne 7 -or $measurement.snapshot_schema_version -ne 7 -or
                $measurement.warmup_count -ne 2 -or $measurement.sample_count -ne 5 -or
                $measurement.identity_preserved_unchanged -ne $true -or $measurement.identity_replaced_changed -ne $true -or
                $measurement.source_unchanged -ne $true -or
                $measurement.reference_commit -cne 'dae70bf9aa05b6b3debb60f95738e5ffc4e97548' -or
                $measurement.candidate_schema_source_sha256 -cne $sourceHashes.schema -or
                $measurement.candidate_port_source_sha256 -cne $sourceHashes.port) {
                throw 'Lazy normalization changed its source, payload, schema, identity, or retention contract.'
            }
            foreach ($metric in $metrics) {
                $samples = @($measurement.PSObject.Properties["${metric}_samples_us"].Value)
                if ($samples.Count -ne 5 -or @($samples | Where-Object { $_ -lt 0 }).Count -ne 0 -or
                    (Get-Median $samples) -ne $measurement.PSObject.Properties["${metric}_median_us"].Value) {
                    throw "Invalid $metric samples or median."
                }
            }
            if ((Get-FileHash -LiteralPath $document -Algorithm SHA256).Hash.ToLowerInvariant() -cne $inputHash) {
                throw 'Normalization benchmark mutated its source file.'
            }
            $row[$variant] = $measurement
        }
        foreach ($field in @('helper_input_sha256', 'helper_input_bytes', 'reference_commit',
            'reference_schema_source_sha256', 'reference_port_source_sha256',
            'reference_schema_helper_sha256', 'reference_port_helper_sha256')) {
            if ($row.baseline.PSObject.Properties[$field].Value -cne $row.candidate.PSObject.Properties[$field].Value) {
                throw "Pair $mode/$pair differs in $field."
            }
        }
        $delta = [ordered]@{}
        foreach ($metric in $metrics) {
            $delta[$metric] = $row.candidate.PSObject.Properties["${metric}_median_us"].Value -
                $row.baseline.PSObject.Properties["${metric}_median_us"].Value
        }
        $row['candidate_minus_baseline_us'] = $delta
        $pairs += $row
        Write-Host ('LAZY_NORMALIZATION_PAIR: ' + ($row | ConvertTo-Json -Depth 12 -Compress))
    }
}
$summaries = @()
foreach ($mode in @('full', 'splice')) {
    $selected = @($pairs | Where-Object { $_.mode -ceq $mode })
    foreach ($metric in $metrics) {
        $summaries += [ordered]@{ mode = $mode; metric = $metric; pairs = $selected.Count
            baseline_median_us = Get-Median @($selected | ForEach-Object { $_.baseline.PSObject.Properties["${metric}_median_us"].Value })
            candidate_median_us = Get-Median @($selected | ForEach-Object { $_.candidate.PSObject.Properties["${metric}_median_us"].Value })
            median_paired_candidate_minus_baseline_us = Get-Median @($selected | ForEach-Object { $_.candidate_minus_baseline_us[$metric] }) }
    }
}
$report = [ordered]@{
    checkout_ref = $checkoutRef; run_id = [string]$env:GITHUB_RUN_ID; source_sha256 = $sourceHashes
    input_sha256 = $inputHash; retained_checkpoint_count = 66; pairs = $pairs; summaries = $summaries
    sampling = 'Four alternating pairs per full/splice mode; sixteen fresh isolated processes. Each metric keeps five samples after two warmups. No timing threshold; OS caches are not flushed.'
    scope = 'Frozen eager helpers versus current lazy helpers on identical strict Day7 JSON. Both port seams use the same current strict outgoing schema and proofs. This is not a matched schema-build, physical-save, gameplay, or input-to-paint comparison.'
}
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
Write-Host ('LAZY_NORMALIZATION_COMPARISON: ' + ([ordered]@{
    checkout_ref = $checkoutRef; source_sha256 = $sourceHashes; input_sha256 = $inputHash
    sampling = $report.sampling; scope = $report.scope; summaries = $summaries
} | ConvertTo-Json -Depth 8 -Compress))
Write-Host 'LAZY_NORMALIZATION_VERIFIED: sixteen matched processes preserved strict bytes, identity and 66 retained checkpoints.'
