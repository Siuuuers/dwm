param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/outgoing-normalization'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$checkoutRef = (& git rev-parse HEAD)
if ($LASTEXITCODE -ne 0) { throw 'Could not identify the benchmark checkout.' }
$payloadRoot = Join-Path $repositoryRoot '.godot/ci/performance'
$manifest = Get-Content -LiteralPath (Join-Path $payloadRoot 'payload-manifest.json') -Raw | ConvertFrom-Json
# A failed-job retry may reuse the successful producer's earlier attempt in this same run.
# The exact checkout and payload hashes must still match; never read committed historical saves.
if ($manifest.checkout_ref -cne $checkoutRef -or
    $manifest.producer_run_id -cne [string]$env:GITHUB_RUN_ID -or
    $manifest.producer_run_attempt -lt 1 -or $manifest.producer_run_attempt -gt [int]$env:GITHUB_RUN_ATTEMPT -or
    @($manifest.payloads).Count -ne 2) {
    throw 'Localized payload manifest must come from this checkout and workflow run.'
}
$documents = [ordered]@{}
$expectedHashes = @{}
foreach ($locale in @('zh-CN', 'zh-HK')) {
    $entries = @($manifest.payloads | Where-Object { $_.locale -ceq $locale })
    if ($entries.Count -ne 1 -or $entries[0].file -cne "fixed-$locale-autosave.json" -or
        $entries[0].journal_bundles -ne 2 -or $entries[0].sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw "Invalid generated $locale payload manifest."
    }
    $documents[$locale] = Join-Path $payloadRoot $entries[0].file
    $expectedHashes[$locale] = $entries[0].sha256
}
$documents['day7'] = Join-Path $repositoryRoot '.godot/ci/seven-day-history/day7-autosave.json'
$expectedHashes['day7'] = (Get-FileHash -LiteralPath $documents.day7 -Algorithm SHA256).Hash.ToLowerInvariant()
foreach ($label in $documents.Keys) {
    if ((Get-FileHash -LiteralPath $documents[$label] -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHashes[$label]) {
        throw "Generated $label payload hash differs from its source proof."
    }
}
$report = [ordered]@{
    checkout_ref = $checkoutRef
    ablation = 'Current port and strict schema for both variants; only complete-document versus proven-journal normalization differs. Five timed samples after two warmups reuse each identical document. No timing threshold.'
    source_sha256 = [ordered]@{
        checkpoint_port = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot 'scripts/application/run/SaveManagerCheckpointPort.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
        document_schema = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot 'scripts/infrastructure/save/SaveDocumentSchema.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
        run_schema = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot 'scripts/domain/run/RunSnapshotSchema.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    localized_payload_manifest = $manifest
    measurements = @()
}
foreach ($variant in @('baseline', 'candidate')) {
    foreach ($label in $documents.Keys) {
        $document = $documents[$label]
        $evidence = ".godot/ci/outgoing-normalization/$variant-$label.jsonl"
        $logName = "cloud-outgoing-normalization-$variant-$label.log"
        & $runner -SuiteId "cloud-outgoing-normalization-$variant-$label" -LogName $logName `
            -EvidenceLogPath $evidence -GodotArgs @('-s', 'res://tests/manual/benchmark_outgoing_normalization.gd', '--', "--document=$document", "--variant=$variant") | Out-Null
        $result = $LASTEXITCODE
        $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
        if ($result -ne 0) {
            if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
            throw "Outgoing $variant/$label failed with exit $result."
        }
        if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) {
            throw "Outgoing $variant/$label reported a script or Unicode error."
        }
        $prefix = 'OUTGOING_NORMALIZATION_BENCHMARK: '
        $markers = @(Get-Content -LiteralPath $log | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) } |
            ForEach-Object { $_.Substring($prefix.Length) | ConvertFrom-Json })
        if ($markers.Count -ne 1) { throw 'Expected one outgoing normalization measurement.' }
        $measurement = $markers[0]
        $hash = (Get-FileHash -LiteralPath $document -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedBundles = if ($label -eq 'day7') { 66 } else { 2 }
        if ($hash -cne $expectedHashes[$label] -or $measurement.variant -cne $variant -or
            $measurement.input_sha256 -cne $hash -or $measurement.output_sha256 -cne $hash -or
            $measurement.journal_bundles -ne $expectedBundles -or $measurement.validated_journal_bundles -ne $expectedBundles -or
            @($measurement.samples_us).Count -ne 5 -or @($measurement.samples_us | Where-Object { $_ -lt 0 }).Count -ne 0) {
            throw 'Matched normalization measurement did not preserve exact bytes, variant, samples or strict retention.'
        }
        $report.measurements += [ordered]@{ variant = $variant; label = $label; measurement = $measurement }
    }
}
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
foreach ($measurement in $report.measurements) {
    Write-Host ('OUTGOING_NORMALIZATION_MEASUREMENT: ' + ($measurement | ConvertTo-Json -Depth 8 -Compress))
}
$proof = [ordered]@{ checkout_ref = $report.checkout_ref; source_sha256 = $report.source_sha256
    localized_payload_manifest = $manifest; ablation = $report.ablation }
Write-Host ('OUTGOING_NORMALIZATION_PROOF: ' + ($proof | ConvertTo-Json -Depth 8 -Compress))
Write-Host 'OUTGOING_NORMALIZATION_PERFORMANCE_VERIFIED: six exact-payload probes with unchanged validation and retention.'
