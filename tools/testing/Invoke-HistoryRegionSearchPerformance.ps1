param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/history-region-search'
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
    throw "History region search requires this checkout's fresh verified Day7 payload and all 66 checkpoints."
}
$sourceHashes = [ordered]@{}
foreach ($entry in @(
    @('port', 'scripts/application/run/SaveManagerCheckpointPort.gd'),
    @('journal', 'scripts/infrastructure/save/CheckpointJournal.gd'),
    @('storage', 'scripts/infrastructure/storage/JsonFileStorage.gd'),
    @('file_ops', 'tests/support/FakeFileOps.gd'),
    @('reference', 'tests/support/HistoryRegionSearchReference.gd'),
    @('harness', 'tests/manual/benchmark_history_region_search.gd'),
    @('driver', 'tools/testing/Invoke-HistoryRegionSearchPerformance.ps1'))) {
    $sourceHashes[$entry[0]] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $entry[1]) -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextHash {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-ReferenceMethod {
    param([string]$Text)
    $match = [regex]::Match($Text, '(?ms)^func _remember_written_history\(.*?(?=^(?:func |static func |## )|\z)')
    if (-not $match.Success) { throw 'Missing frozen history-learning method.' }
    return $match.Value.TrimEnd([char[]]"`r`n") + "`n"
}

# Read and bind the actual historical git blob, not merely the reference's claimed hashes.
$referenceCommit = '5c3368dbba14475a3749bd71df971bfed353699f'
$referencePortHash = '72d400998c3bc6d9a3b4a7645bfd24a749e34a78eaa140ba73d1b23d6fc20310'
$referenceMethodHash = '470919ccd5ff929337c6a0c00185e9082772c97de7f5ce72a3b9e0209dff4617'
$historicalLines = @(& git show "${referenceCommit}:scripts/application/run/SaveManagerCheckpointPort.gd")
if ($LASTEXITCODE -ne 0) { throw 'Frozen reference source is unavailable in this checkout history.' }
$historicalSource = [string]::Join("`n", $historicalLines) + "`n"
$referenceSource = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'tests/support/HistoryRegionSearchReference.gd')).Replace("`r`n", "`n")
$historicalMethod = Get-ReferenceMethod $historicalSource
$frozenMethod = Get-ReferenceMethod $referenceSource
$candidateSource = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'scripts/application/run/SaveManagerCheckpointPort.gd')).Replace("`r`n", "`n")
$candidateMethod = Get-ReferenceMethod $candidateSource
if ((Get-TextHash $historicalSource) -cne $referencePortHash -or
    (Get-TextHash $historicalMethod) -cne $referenceMethodHash -or
    (Get-TextHash $frozenMethod) -cne $referenceMethodHash -or $frozenMethod -cne $historicalMethod) {
    throw 'Frozen history-learning control is not the exact identified original method.'
}
if ((Get-TextHash $candidateSource.Replace($candidateMethod, $historicalMethod)) -cne $referencePortHash) {
    throw 'Replacing only the candidate learning method does not reproduce the exact original port source.'
}

function Get-Median {
    param([object[]]$Values)
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { throw 'Median requires samples.' }
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) { return [double]$sorted[$middle] }
    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function ConvertTo-EvidenceText {
    param([object]$Value)
    return ConvertTo-Json -InputObject $Value -Depth 20 -Compress
}

$metrics = @('learning_seam', 'port_commit_fake_io')
$pairs = @()
$modeInvariants = @{}
foreach ($mode in @('cold', 'mixed')) {
    for ($pair = 1; $pair -le 4; $pair++) {
        $order = if ($pair % 2 -eq 1) { @('baseline', 'candidate') } else { @('candidate', 'baseline') }
        $row = [ordered]@{ mode = $mode; pair = $pair; order = $order }
        foreach ($variant in $order) {
            $name = "$mode-$pair-$variant"
            $logName = "cloud-history-region-search-$name.log"
            & $runner -SuiteId "cloud-history-region-search-$name" -LogName $logName `
                -EvidenceLogPath ".godot/ci/history-region-search/$name.jsonl" -TimeoutSeconds 300 `
                -GodotArgs @('-s', 'res://tests/manual/benchmark_history_region_search.gd', '--',
                    "--document=$document", "--variant=$variant", "--mode=$mode") | Out-Null
            $result = $LASTEXITCODE
            $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
            if ($result -ne 0) {
                if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
                throw "History region search $name failed with exit $result."
            }
            if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character|HISTORY_REGION_SEARCH_FAIL:' -Quiet) {
                throw "History region search $name reported a script, invariant or Unicode error."
            }
            $prefix = 'HISTORY_REGION_SEARCH_BENCHMARK: '
            $markers = @(Get-Content -LiteralPath $log | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) } |
                ForEach-Object { $_.Substring($prefix.Length) | ConvertFrom-Json })
            if ($markers.Count -ne 1) { throw 'Expected one history region search measurement.' }
            $measurement = $markers[0]
            $present = if ($mode -ceq 'mixed') { 51 } else { 0 }
            if ($measurement.variant -cne $variant -or $measurement.mode -cne $mode -or
                $measurement.input_sha256 -cne $inputHash -or $measurement.output_sha256 -cne $inputHash -or
                $measurement.bytes -ne (Get-Item -LiteralPath $document).Length -or
                $measurement.journal_bundles -ne 66 -or $measurement.validated_journal_bundles -ne 66 -or
                $measurement.retained.line -ne 32 -or $measurement.retained.manual_save -ne 32 -or $measurement.retained.semantic -ne 2 -or
                $measurement.schema_version -ne 7 -or $measurement.snapshot_schema_version -ne 7 -or
                $measurement.warmup_count -ne 2 -or $measurement.sample_count -ne 5 -or
                $measurement.initial_proofs_present -ne $present -or $measurement.initial_proofs_missing -ne (66 - $present) -or
                @($measurement.proof_seed).Count -ne $present -or @($measurement.final_proof_manifest).Count -ne 66 -or
                $measurement.source_unchanged -ne $true -or $measurement.exact_proof_strings_and_documents -ne $true -or
                $measurement.exact_physical_bytes -ne $true -or
                $measurement.reference_commit -cne $referenceCommit -or
                $measurement.reference_port_source_sha256 -cne $referencePortHash -or
                $measurement.reference_method_sha256 -cne $referenceMethodHash -or
                $measurement.candidate_port_source_sha256 -cne $sourceHashes.port) {
                throw 'History region search changed its source, payload, proof state, schema or retention contract.'
            }
            foreach ($metric in $metrics) {
                $samples = @($measurement.PSObject.Properties["${metric}_samples_us"].Value)
                if ($samples.Count -ne 5 -or @($samples | Where-Object { $_ -lt 0 }).Count -ne 0 -or
                    (Get-Median $samples) -ne $measurement.PSObject.Properties["${metric}_median_us"].Value) {
                    throw "Invalid $metric samples or median."
                }
                if ($measurement.evidence.PSObject.Properties[$metric].Value.journal_sha256 -cne $measurement.final_journal_sha256) {
                    throw "Unexpected $metric final journal."
                }
            }
            if (@($measurement.evidence.learning_seam.operation_trace).Count -ne 0 -or
                @($measurement.evidence.port_commit_fake_io.operation_trace).Count -eq 0) {
                throw 'Measured scopes did not preserve their physical-operation boundary.'
            }
            if ((Get-FileHash -LiteralPath $document -Algorithm SHA256).Hash.ToLowerInvariant() -cne $inputHash) {
                throw 'History region search mutated its source file.'
            }
            # Compare complete ordered physical traces and file hashes, exact proof manifests and
            # journal hashes across every sample process in each mode, not only within one pair.
            $invariants = [ordered]@{}
            foreach ($field in @('input_sha256', 'output_sha256', 'bytes', 'proof_seed', 'proof_seed_sha256',
                'final_proof_manifest', 'final_proof_manifest_sha256', 'prior_journal_sha256', 'final_journal_sha256',
                'initial_proofs_present', 'initial_proofs_missing', 'evidence', 'reference_commit',
                'reference_port_source_sha256', 'reference_method_sha256', 'candidate_port_source_sha256')) {
                $invariants[$field] = $measurement.PSObject.Properties[$field].Value
            }
            $invariantText = ConvertTo-EvidenceText $invariants
            if ($modeInvariants.ContainsKey($mode)) {
                if ($modeInvariants[$mode] -cne $invariantText) { throw "Unmatched proof, journal, source, file or ordered trace in $name." }
            } else { $modeInvariants[$mode] = $invariantText }
            $row[$variant] = $measurement
        }
        $delta = [ordered]@{}
        foreach ($metric in $metrics) {
            $delta[$metric] = $row.candidate.PSObject.Properties["${metric}_median_us"].Value -
                $row.baseline.PSObject.Properties["${metric}_median_us"].Value
        }
        $row['candidate_minus_baseline_us'] = $delta
        $pairs += $row
        Write-Host ('HISTORY_REGION_SEARCH_PAIR: ' + ($row | ConvertTo-Json -Depth 20 -Compress))
    }
}
$summaries = @()
foreach ($mode in @('cold', 'mixed')) {
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
    sampling = 'Four alternating pairs per cold/mixed mode; sixteen fresh isolated processes. Each independent metric keeps five fresh-state samples after two warmups. No pooled/nested timing sum or timing threshold; OS caches are not flushed.'
    scope = 'Frozen original method versus current ordered cursor. Exact Day7 bytes and 66 history bundles; mixed has the same first 51 proofs and 15 misses. Direct learning plus complete port commit use real journal and storage protocol with FakeFileOps, not physical disk, public port preparation, gameplay or input-to-paint timing.'
}
$report | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
Write-Host ('HISTORY_REGION_SEARCH_COMPARISON: ' + ([ordered]@{
    checkout_ref = $checkoutRef; source_sha256 = $sourceHashes; input_sha256 = $inputHash
    sampling = $report.sampling; scope = $report.scope; summaries = $summaries
} | ConvertTo-Json -Depth 8 -Compress))
Write-Host 'HISTORY_REGION_SEARCH_VERIFIED: sixteen matched processes preserved exact proof strings/documents, journal, physical bytes/traces and 66 retained checkpoints.'
