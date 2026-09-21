param(
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$BaselineRef = '4c4f9c987c96b65293554b1ce0f083f9263aa791'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/outgoing-normalization'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
$portRelative = 'scripts/application/run/SaveManagerCheckpointPort.gd'
$port = Join-Path $repositoryRoot $portRelative
New-Item -ItemType Directory -Force -Path $output | Out-Null
$candidateBytes = [IO.File]::ReadAllBytes($port)
$baseline = Join-Path $output 'baseline-SaveManagerCheckpointPort.gd'
python -c 'import pathlib,subprocess,sys; pathlib.Path(sys.argv[2]).write_bytes(subprocess.check_output(["git","show",sys.argv[1]]))' "${BaselineRef}:$portRelative" $baseline
if ($LASTEXITCODE -ne 0) { throw 'Could not read pinned baseline checkpoint port.' }
$baselineBytes = [IO.File]::ReadAllBytes($baseline)
$documents = [ordered]@{
    'zh-CN' = 'evidence/beads_cloud_review/performance/fixed-zh-CN-autosave.json'
    'zh-HK' = 'evidence/beads_cloud_review/performance/fixed-zh-HK-autosave.json'
    'day7' = '.godot/ci/seven-day-history/day7-autosave.json'
}
$report = [ordered]@{
    baseline_ref = $BaselineRef
    checkout_ref = (& git rev-parse HEAD)
    ablation = 'Only SaveManagerCheckpointPort.gd is replaced; five timed samples after two warmups reuse each identical document. No timing threshold.'
    source_sha256 = @{}
    measurements = @()
}
try {
    foreach ($variant in @('baseline', 'candidate')) {
        if ($variant -eq 'baseline') {
            [IO.File]::WriteAllBytes($port, $baselineBytes)
        } else {
            [IO.File]::WriteAllBytes($port, $candidateBytes)
        }
        $report.source_sha256[$variant] = (Get-FileHash -LiteralPath $port -Algorithm SHA256).Hash.ToLowerInvariant()
        foreach ($label in $documents.Keys) {
            $document = Join-Path $repositoryRoot $documents[$label]
            if (-not (Test-Path -LiteralPath $document -PathType Leaf)) { throw "Missing fixed $label payload; run seven-day history first." }
            $evidence = ".godot/ci/outgoing-normalization/$variant-$label.jsonl"
            $logName = "cloud-outgoing-normalization-$variant-$label.log"
            & $runner -SuiteId "cloud-outgoing-normalization-$variant-$label" -LogName $logName `
                -EvidenceLogPath $evidence -GodotArgs @('-s', 'res://tests/manual/benchmark_outgoing_normalization.gd', '--', "--document=$document") | Out-Null
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
            if ($measurement.variant -cne $variant -or $measurement.input_sha256 -cne $hash -or
                $measurement.output_sha256 -cne $hash -or $measurement.journal_bundles -ne $expectedBundles -or
                @($measurement.samples_us).Count -ne 5) {
                throw 'Matched normalization measurement did not preserve exact bytes, variant, samples or retention.'
            }
            $report.measurements += [ordered]@{ variant = $variant; label = $label; measurement = $measurement }
        }
    }
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
    foreach ($measurement in $report.measurements) {
        Write-Host ('OUTGOING_NORMALIZATION_MEASUREMENT: ' + ($measurement | ConvertTo-Json -Depth 8 -Compress))
    }
    $proof = [ordered]@{ checkout_ref = $report.checkout_ref; baseline_ref = $BaselineRef
        source_sha256 = $report.source_sha256; ablation = $report.ablation }
    Write-Host ('OUTGOING_NORMALIZATION_PROOF: ' + ($proof | ConvertTo-Json -Depth 5 -Compress))
    Write-Host 'OUTGOING_NORMALIZATION_PERFORMANCE_VERIFIED: six exact-payload probes with unchanged validation and retention.'
} finally {
    [IO.File]::WriteAllBytes($port, $candidateBytes)
}
