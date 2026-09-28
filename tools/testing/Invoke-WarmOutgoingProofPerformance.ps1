param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/warm-outgoing-proof'
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
    throw "Warm outgoing proofs requires this checkout's fresh verified Day7 payload and all 66 checkpoints."
}
$sourceHashes = [ordered]@{}
foreach ($entry in @(
    @('port', 'scripts/application/run/SaveManagerCheckpointPort.gd'),
    @('schema', 'scripts/infrastructure/save/SaveDocumentSchema.gd'),
    @('warm_provenance', 'tools/testing/Assert-WarmOutgoingProofBaseline.ps1'),
    @('journal', 'scripts/infrastructure/save/CheckpointJournal.gd'),
    @('storage', 'scripts/infrastructure/storage/JsonFileStorage.gd'),
    @('file_ops', 'tests/support/FakeFileOps.gd'),
    @('reference', 'tests/support/WarmOutgoingProofReference.gd'),
    @('journal_reference', 'tests/support/WarmOutgoingJournalReference.gd'),
    @('harness', 'tests/manual/benchmark_warm_outgoing_proofs.gd'),
    @('driver', 'tools/testing/Invoke-WarmOutgoingProofPerformance.ps1'))) {
    $sourceHashes[$entry[0]] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $entry[1]) -Algorithm SHA256).Hash.ToLowerInvariant()
}

# The guard reads actual accepted Git blobs and proves the frozen method bodies plus the
# exact, narrowly reviewed port/schema/journal difference boundaries before any measurements run.
$provenance = & (Join-Path $PSScriptRoot 'Assert-WarmOutgoingProofBaseline.ps1') -RepositoryRoot $repositoryRoot
$referenceCommit = $provenance.reference_commit
$referencePortHash = $provenance.reference_port_source_sha256
$referenceSchemaHash = $provenance.reference_schema_source_sha256
$referenceJournalHash = $provenance.reference_journal_source_sha256

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

$metrics = @('schema_composition', 'port_commit_fake_io')
$pairs = @()
$modeInvariants = @{}
foreach ($mode in @('cold', 'mixed', 'warm')) {
    for ($pair = 1; $pair -le 4; $pair++) {
        $order = if ($pair % 2 -eq 1) { @('baseline', 'candidate') } else { @('candidate', 'baseline') }
        $row = [ordered]@{ mode = $mode; pair = $pair; order = $order }
        foreach ($variant in $order) {
            $name = "$mode-$pair-$variant"
            $logName = "cloud-warm-outgoing-proof-$name.log"
            & $runner -SuiteId "cloud-warm-outgoing-proof-$name" -LogName $logName `
                -EvidenceLogPath ".godot/ci/warm-outgoing-proof/$name.jsonl" -TimeoutSeconds 300 `
                -GodotArgs @('-s', 'res://tests/manual/benchmark_warm_outgoing_proofs.gd', '--',
                    "--document=$document", "--variant=$variant", "--mode=$mode") | Out-Null
            $result = $LASTEXITCODE
            $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
            if ($result -ne 0) {
                if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
                throw "Warm outgoing proofs $name failed with exit $result."
            }
            if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character|WARM_OUTGOING_PROOF_FAIL:' -Quiet) {
                throw "Warm outgoing proofs $name reported a script, invariant or Unicode error."
            }
            $prefix = 'WARM_OUTGOING_PROOF_BENCHMARK: '
            $markers = @(Get-Content -LiteralPath $log | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) } |
                ForEach-Object { $_.Substring($prefix.Length) | ConvertFrom-Json })
            if ($markers.Count -ne 1) { throw 'Expected one warm outgoing proof measurement.' }
            $measurement = $markers[0]
            $present = if ($mode -ceq 'warm') { 66 } elseif ($mode -ceq 'mixed') { 51 } else { 0 }
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
                $measurement.reference_schema_source_sha256 -cne $referenceSchemaHash -or
                $measurement.reference_commit_method_sha256 -cne $provenance.reference_method_sha256.commit -or
                $measurement.reference_splice_method_sha256 -cne $provenance.reference_method_sha256._splice_autosave_text -or
                $measurement.reference_validate_method_sha256 -cne $provenance.reference_method_sha256._validate_document -or
                $measurement.reference_journal_commit -cne $referenceCommit -or
                $measurement.reference_journal_source_sha256 -cne $referenceJournalHash -or
                $measurement.reference_remember_method_sha256 -cne $provenance.reference_method_sha256.remember_written_retained_bundle -or
                $measurement.candidate_port_source_sha256 -cne $sourceHashes.port -or
                $measurement.candidate_schema_source_sha256 -cne $sourceHashes.schema -or
                $measurement.candidate_journal_source_sha256 -cne $sourceHashes.journal -or
                $measurement.journal_reference_source_sha256 -cne $sourceHashes.journal_reference -or
                $measurement.exact_composed_values_types_and_bytes -ne $true) {
                throw 'Warm outgoing proofs changed its source, payload, proof state, schema or retention contract.'
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
            if (@($measurement.evidence.schema_composition.operation_trace).Count -ne 0 -or
                @($measurement.evidence.port_commit_fake_io.operation_trace).Count -eq 0 -or
                $measurement.evidence.schema_composition.final_proof_count -ne $present -or
                $measurement.evidence.port_commit_fake_io.final_proof_count -ne 66 -or
                @($measurement.evidence.schema_composition.proof_state).Count -ne 66 -or
                @($measurement.evidence.port_commit_fake_io.proof_state).Count -ne 66 -or
                [string]::IsNullOrEmpty($measurement.evidence.schema_composition.composed_type_sha256)) {
                throw 'Measured scopes did not preserve their physical-operation boundary.'
            }
            if ((Get-FileHash -LiteralPath $document -Algorithm SHA256).Hash.ToLowerInvariant() -cne $inputHash) {
                throw 'Warm outgoing proofs mutated its source file.'
            }
            # Compare complete ordered physical traces and file hashes, exact proof manifests and
            # journal hashes across every sample process in each mode, not only within one pair.
            $invariants = [ordered]@{}
            foreach ($field in @('input_sha256', 'output_sha256', 'bytes', 'proof_seed', 'proof_seed_sha256',
                'final_proof_manifest', 'final_proof_manifest_sha256', 'prior_journal_sha256', 'final_journal_sha256',
                'initial_proofs_present', 'initial_proofs_missing', 'evidence', 'reference_commit',
                'reference_port_source_sha256', 'reference_schema_source_sha256',
                'reference_commit_method_sha256', 'reference_splice_method_sha256', 'reference_validate_method_sha256',
                'reference_journal_commit', 'reference_journal_source_sha256', 'reference_remember_method_sha256',
                'candidate_port_source_sha256', 'candidate_schema_source_sha256', 'candidate_journal_source_sha256',
                'journal_reference_source_sha256', 'control_boundary', 'scope', 'timing_boundary')) {
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
        Write-Host ('WARM_OUTGOING_PROOF_PAIR: ' + ($row | ConvertTo-Json -Depth 20 -Compress))
    }
}
$summaries = @()
foreach ($mode in @('cold', 'mixed', 'warm')) {
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
    sampling = 'Four alternating pairs per cold/mixed/warm mode; twenty-four fresh isolated processes. Each independent metric keeps five fresh-state samples after two warmups. No pooled/nested timing sum or timing threshold; OS caches are not flushed.'
    scope = 'Accepted226 commit/splice and journal proof learning versus current warm document-proof path; remaining port/journal methods and public raw-proof validator are shared and source-guarded. Each variant seeds its own journal implementation outside timing. Direct schema composition always has 66 trusted raw bundles with 0/51/66 normalized proofs. Complete commit uses the same real journal proof count, causing full fallback for cold/mixed and splice for warm. Exact Day7 bytes, types, proofs, journal and physical files/ordered traces with FakeFileOps; no physical disk, public preparation, gameplay or input-to-paint claim.'
}
$report | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
Write-Host ('WARM_OUTGOING_PROOF_COMPARISON: ' + ([ordered]@{
    checkout_ref = $checkoutRef; source_sha256 = $sourceHashes; input_sha256 = $inputHash
    sampling = $report.sampling; scope = $report.scope; summaries = $summaries
} | ConvertTo-Json -Depth 8 -Compress))
Write-Host 'WARM_OUTGOING_PROOF_VERIFIED: twenty-four matched processes preserved exact composed values/types/bytes, proof strings/documents, journal, physical bytes/traces and 66 retained checkpoints.'
