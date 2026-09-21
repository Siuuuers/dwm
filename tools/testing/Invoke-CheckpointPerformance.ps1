param(
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$BaselineRef = '681251dc832262c08826ce74d6a4480291eac4a8'
)

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
# Preserve the exact committed bytes; PowerShell's native text pipeline changes line endings.
python -c 'import pathlib,subprocess,sys; pathlib.Path(sys.argv[2]).write_bytes(subprocess.check_output(["git","show",sys.argv[1]]))' "${BaselineRef}:$schemaRelative" $baseline
if ($LASTEXITCODE -ne 0) { throw 'Could not read the pinned baseline schema.' }
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
    baseline_ref = $BaselineRef
    checkout_ref = (& git rev-parse HEAD)
    ablation = 'Only SaveDocumentSchema.gd is replaced; all other code is the candidate.'
    timing_policy = 'Observations on one shared Windows runner; no speed threshold or frame-time guarantee.'
    journey_comparison = 'Fresh journeys may generate different boards; fixed_payloads reuse identical saved bytes.'
    journeys = @()
    fixed_payloads = @()
    schema_sha256 = @{}
}
$fixed = @{}
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
                $measurement.journal_bundles -ne 2) {
                throw 'Fixed payload must retain exact canonical bytes and both journal bundles.'
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
    $report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
    Write-Host 'CHECKPOINT_PERFORMANCE_VERIFIED: four localized journeys and four matched-payload probes.'
} finally {
    [IO.File]::WriteAllBytes($schema, $candidateBytes)
    $env:DWM_CHECKPOINT_PROFILE = $previousCheckpointProfile
    $env:DWM_CONSEQUENCE_PROFILE = $previousConsequenceProfile
}
