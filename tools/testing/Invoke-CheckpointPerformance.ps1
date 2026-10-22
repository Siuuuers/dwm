param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/performance'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
$schemaRelative = 'scripts/infrastructure/save/SaveDocumentSchema.gd'
$schema = Join-Path $repositoryRoot $schemaRelative
New-Item -ItemType Directory -Force -Path $output | Out-Null
$candidateBytes = [IO.File]::ReadAllBytes($schema)
$baseline = Join-Path $output 'baseline-SaveDocumentSchema.gd'
# Reverse only the redundant journal-normalization optimization. Both variants retain every
# current schema/version/frozen-context check; never transplant a historical validator.
python -c 'import pathlib,sys; source=pathlib.Path(sys.argv[1]).read_bytes(); needle=b"if key == \"current_snapshot\" or (use_proven_journal and key == \"recovery_journal\"):"; assert source.count(needle)==1, "expected one normalization condition"; pathlib.Path(sys.argv[2]).write_bytes(source.replace(needle,b"if key == \"current_snapshot\":"))' $schema $baseline
if ($LASTEXITCODE -ne 0) { throw 'Could not derive the single-condition baseline schema.' }
$baselineBytes = [IO.File]::ReadAllBytes($baseline)
$previousCheckpointProfile = $env:DWM_CHECKPOINT_PROFILE
$previousConsequenceProfile = $env:DWM_CONSEQUENCE_PROFILE
$env:DWM_CHECKPOINT_PROFILE = '1'
$env:DWM_CONSEQUENCE_PROFILE = '1'

function Invoke-PerformanceProbe {
    param([string]$Name, [string[]]$Arguments, [switch]$KeepRoot)
    $evidence = ".godot/ci/performance/$Name.jsonl"
    $logName = "cloud-performance-$Name.log"
    & $runner -SuiteId "cloud-performance-$Name" -LogName $logName `
        -EvidenceLogPath $evidence -GodotArgs $Arguments -KeepRoot:$KeepRoot | Out-Null
    $result = $LASTEXITCODE
    $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
        throw "$Name failed with exit $result."
    }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) {
        throw "$Name reported a script or Unicode error."
    }
    return [pscustomobject]@{
        Lines = @(Get-Content -LiteralPath $log)
        Record = (Get-Content -LiteralPath (Join-Path $repositoryRoot $evidence) | Select-Object -Last 1 | ConvertFrom-Json)
    }
}

function Read-Markers {
    param([string[]]$Lines, [string]$Prefix)
    return @($Lines | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) } |
        ForEach-Object { $_.Substring($Prefix.Length) | ConvertFrom-Json })
}

$report = [ordered]@{
    checkout_ref = (& git rev-parse HEAD)
    ablation = 'Current SaveDocumentSchema with only its outgoing proven-journal normalization shortcut reversed; all current validation remains in both variants.'
    timing_policy = 'Observations on one shared Windows runner; no speed threshold or frame-time guarantee.'
    journey_comparison = 'Fresh journeys may generate different boards; fixed_payloads reuse identical saved bytes.'
    journeys = @()
    fixed_payloads = @()
    schema_sha256 = @{}
}
$fixed = @{}
$payloadManifest = [ordered]@{
    checkout_ref = $report.checkout_ref
    producer_run_id = [string]$env:GITHUB_RUN_ID
    producer_run_attempt = [int]$env:GITHUB_RUN_ATTEMPT
    payloads = @()
}
try {
    foreach ($variant in @('baseline', 'candidate')) {
        if ($variant -eq 'baseline') {
            [IO.File]::WriteAllBytes($schema, $baselineBytes)
        } else {
            [IO.File]::WriteAllBytes($schema, $candidateBytes)
        }
        $report.schema_sha256[$variant] = (Get-FileHash -LiteralPath $schema -Algorithm SHA256).Hash.ToLowerInvariant()
        foreach ($locale in @('zh-CN', 'zh-HK')) {
            # Exercise both terminal outcomes across the two localized fresh journeys.
            $ending = if ($locale -eq 'zh-CN') { 'win' } else { 'loss' }
            $probe = Invoke-PerformanceProbe -Name "$variant-$locale" -KeepRoot -Arguments @(
                '-s', 'res://tests/manual/benchmark_minesweeper_click_latency.gd', '--',
                '--phase2r-bootstrap-mode=final', "--reply-locale=$locale", "--dating-ending=$ending"
            )
            if (@($probe.Lines | Where-Object { $_.StartsWith('CLICK_LATENCY_PASS:', [StringComparison]::Ordinal) }).Count -ne 1) {
                throw "$variant/$locale did not complete the real App and Dating journey."
            }
            $reply = @(Read-Markers $probe.Lines 'CLICK_LATENCY_REPLY: ')
            $mode = @(Read-Markers $probe.Lines 'CLICK_LATENCY_MODE: ')
            $checkpoints = @(Read-Markers $probe.Lines 'DWM_CHECKPOINT_PROFILE ')
            $consequences = @(Read-Markers $probe.Lines 'DWM_CONSEQUENCE_PROFILE ')
            if ($reply.Count -ne 1 -or $reply[0].locale -cne $locale -or -not $reply[0].contains_non_ascii -or
                $mode.Count -ne 1 -or $mode[0].mode -cne 'fresh-account' -or
                $checkpoints.Count -eq 0 -or $consequences.Count -eq 0) {
                throw "$variant/$locale did not record the localized receipt, fresh mode, and both profiling layers."
            }
            $report.journeys += [ordered]@{
                variant = $variant; locale = $locale; dating_ending = $ending
                summary = @(Read-Markers $probe.Lines 'CLICK_LATENCY_SUMMARY: ')
                settlement = @(Read-Markers $probe.Lines 'CLICK_LATENCY_SETTLED: ')
                checkpoint_profiles = $checkpoints; consequence_profiles = $consequences
            }
            if ($variant -eq 'baseline') {
                $fixed[$locale] = Join-Path $output "fixed-$locale-autosave.json"
                Copy-Item -LiteralPath (Join-Path $probe.Record.user_dir 'saves/autosave.json') -Destination $fixed[$locale]
            }
            $micro = Invoke-PerformanceProbe -Name "$variant-$locale-fixed" -Arguments @(
                '-s', 'res://tests/manual/benchmark_checkpoint_json.gd', '--', "--document=$($fixed[$locale])"
            )
            $measurements = @(Read-Markers $micro.Lines 'CHECKPOINT_JSON_BENCHMARK: ')
            if ($measurements.Count -ne 1) { throw 'Fixed-payload benchmark did not report one result.' }
            $measurement = $measurements[0]
            $hash = (Get-FileHash -LiteralPath $fixed[$locale] -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($measurement.input_sha256 -cne $hash -or $measurement.output_sha256 -cne $hash -or
                $measurement.journal_bundles -ne 2 -or $measurement.validated_journal_bundles -ne 2) {
                throw 'Fixed payload must retain exact canonical bytes and both journal bundles.'
            }
            if ($variant -eq 'baseline') {
                $payloadManifest.payloads += [ordered]@{
                    locale = $locale; file = "fixed-$locale-autosave.json"; sha256 = $hash
                    schema_version = $measurement.schema_version
                    snapshot_schema_version = $measurement.snapshot_schema_version
                    journal_bundles = $measurement.validated_journal_bundles
                    producer_variant = $variant; producer_schema_sha256 = $report.schema_sha256[$variant]
                    dating_ending = $ending
                }
            }
            foreach ($phase in @('parse_us', 'schema_us', 'stringify_us', 'value_validation_us', 'outgoing_validation_us')) {
                $samples = @($measurement.samples.$phase)
                if ($samples.Count -ne 5 -or @($samples | Where-Object { $_ -lt 0 }).Count -ne 0) {
                    throw "Invalid five-sample measurement for $phase."
                }
            }
            $report.fixed_payloads += [ordered]@{ variant = $variant; locale = $locale; measurement = $measurement }
        }
    }
    $payloadManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'payload-manifest.json') -Encoding utf8
    $report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
    Write-Host ('CHECKPOINT_PERFORMANCE_PAYLOADS: ' + ($payloadManifest | ConvertTo-Json -Depth 8 -Compress))
    Write-Host 'CHECKPOINT_PERFORMANCE_VERIFIED: four localized journeys and four matched-payload probes.'
} finally {
    [IO.File]::WriteAllBytes($schema, $candidateBytes)
    $env:DWM_CHECKPOINT_PROFILE = $previousCheckpointProfile
    $env:DWM_CONSEQUENCE_PROFILE = $previousConsequenceProfile
}
