param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/manual-save-witness'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
$retainedRoot = Join-Path $output 'producer-user'
New-Item -ItemType Directory -Force -Path $output, (Join-Path $output 'logs') | Out-Null
if (Test-Path -LiteralPath $retainedRoot) { throw 'A fresh diagnostic requires a new output directory.' }

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Save-Json([object]$Value, [string]$Name) {
    $Value | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $output $Name) -Encoding utf8
}
function Get-Manifest([string]$Root) {
    $items = @((Get-Item -Force -LiteralPath $Root)) + @(Get-ChildItem -Force -Recurse -LiteralPath $Root)
    if (@($items | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }).Count) {
        throw 'Retained input must contain no reparse points.'
    }
    return @($items | Where-Object { -not $_.PSIsContainer } | Sort-Object FullName | ForEach-Object {
        [ordered]@{ file = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
            bytes = $_.Length; sha256 = Get-Sha256 $_.FullName }
    })
}
function Assert-Same([object]$Actual, [object]$Expected, [string]$Label) {
    if ((ConvertTo-Json -InputObject $Actual -Depth 30 -Compress) -cne
        (ConvertTo-Json -InputObject $Expected -Depth 30 -Compress)) { throw "Invariant differs: $Label" }
}
function Get-Markers([string[]]$Lines, [string]$Prefix) {
    return @($Lines | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) } |
        ForEach-Object { $_.Substring($Prefix.Length) | ConvertFrom-Json })
}
function Get-Median([long[]]$Values) {
    $sorted = @($Values | Sort-Object)
    if (-not $sorted.Count) { throw 'Median requires samples.' }
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2) { return $sorted[$middle] }
    return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
}
$sourcePaths = @('autoload/SaveManager.gd', 'scripts/infrastructure/storage/JsonFileStorage.gd',
    'scripts/infrastructure/storage/FileOps.gd', 'scripts/infrastructure/save/CheckpointJournal.gd',
    'scripts/infrastructure/save/SaveDocumentSchema.gd', 'scripts/domain/run/RunSnapshotSchema.gd',
    'scripts/validation/StrictJson.gd', 'scripts/validation/CanonicalJsonWriter.gd',
    'tests/manual/benchmark_manual_save_write.gd', 'tests/support/ManualSaveWitnessPort.gd',
    'tests/manual/benchmark_seven_day_history.gd',
    'tests/manual/benchmark_minesweeper_click_latency.gd', 'tools/testing/Invoke-IsolatedGodot.ps1',
    'tools/testing/Invoke-ManualSaveWitnessPerformance.ps1')
$sourceHashes = [ordered]@{}
foreach ($path in $sourcePaths) { $sourceHashes[$path] = Get-Sha256 (Join-Path $repositoryRoot $path) }
function Assert-Sources {
    foreach ($path in $sourcePaths) {
        if ((Get-Sha256 (Join-Path $repositoryRoot $path)) -cne $sourceHashes[$path]) {
            throw "Diagnostic changed measured source: $path"
        }
    }
}
$checkout = (& git -C $repositoryRoot rev-parse HEAD)
if ($LASTEXITCODE -ne 0) { throw 'Cannot bind checkout.' }
$tree = (& git -C $repositoryRoot rev-parse 'HEAD^{tree}')
if ($LASTEXITCODE -ne 0) { throw 'Cannot bind checkout tree.' }
# Freeze the full-result control to its accepted Git source. The candidate calls
# the production helper, and only this documented helper block may differ.
$baselineGuard = @'
import hashlib,json,pathlib,re,subprocess,sys
root=pathlib.Path(sys.argv[1])
reference='9a4c63f05d13bc2960aae4fa6c58db9911916f86'
expected_body_hash='316ff83a7f767daefb05e9afd63c5d1557e05526a2282306b0728c36b2a68946'
def git_text(path):
    raw=subprocess.check_output(['git','-C',str(root),'show',reference+':'+path])
    return raw.decode('utf-8').replace('\r\n','\n'),hashlib.sha256(raw).hexdigest()
source=(root/'autoload/SaveManager.gd').read_text(encoding='utf-8')
harness=(root/'tests/manual/benchmark_manual_save_write.gd').read_text(encoding='utf-8')
port=(root/'tests/support/ManualSaveWitnessPort.gd').read_text(encoding='utf-8')
historical,historical_hash=git_text('autoload/SaveManager.gd')
old_port,old_port_hash=git_text('tests/support/ManualSaveWitnessPort.gd')
assert 'class FixedClockSave extends "res://tests/support/ManualSaveWitnessPort.gd":' in harness, 'benchmark uses shared comparison owner'
assert 'func _write_document_text_validator' not in harness, 'benchmark cannot override the compared helper'
assert 'var write_variant := "production"' in harness and 'var write_variant := "production"' in port, 'default preparation uses production'
assert 'const BASELINE_SOURCE_REF := "'+reference+'"' in port, 'control source reference'
assert 'const BASELINE_HELPER_SHA256 := "'+expected_body_hash+'"' in port, 'control body reference'
name='func _write_document_text_validator(text: String, validated_texts: Dictionary) -> Dictionary:\n'
def method_body(text):
    assert text.count(name)==1, 'unique validation helper'
    return text.split(name)[1].split('\nfunc ',1)[0].strip('\n')
body=method_body(historical)
assert hashlib.sha256(body.encode()).hexdigest()==expected_body_hash, 'immutable full-result body'
start='\tif write_variant == "baseline":\n'
forward='\treturn super._write_document_text_validator(text, validated_texts)'
assert port.count(start)==1 and port.count(forward)==1, 'one baseline and actual production forwarder'
branch=port.split(start)[1].split(forward,1)[0]
lines=[line[1:] for line in branch.splitlines() if line.strip() and not line.lstrip().startswith('#')]
control='\n'.join(lines).replace('baseline_result','result')
assert control==body, 'control differs from frozen Git helper'
assert port.split(forward,1)[1].strip()=='', 'candidate contains no duplicate helper implementation'
# The adopted body must be the exact diagnostic witness that Run78/79 exercised.
old_candidate=old_port.split('\t# Diagnostic-only ablation.',1)[1].split('\n',2)[2].strip('\n')
assert method_body(source)==old_candidate, 'production differs from proven compact witness'
block_start='## One synchronous Backup write may validate the same outgoing text before and after promotion.\n'
block_end='func _document_text_validator(text: String) -> Dictionary:\n'
def helper_block(text):
    assert text.count(block_start)==1 and text.count(block_end)==1, 'unique helper block anchors'
    return text.split(block_start)[1].split(block_end)[0]
old_block=helper_block(historical)
new_block=helper_block(source)
assert source.replace(block_start+new_block,block_start+old_block,1)==historical, 'SaveManager has another runtime change'
print(json.dumps({'baseline_source_ref':reference,'baseline_source_sha256':historical_hash,
    'baseline_body_sha256':expected_body_hash,'diagnostic_port_sha256':old_port_hash,
    'production_body_sha256':hashlib.sha256(method_body(source).encode()).hexdigest(),
    'exact_frozen_body_match':True,'exact_proven_witness_match':True,
    'whole_source_single_helper_difference':True,'candidate_calls_production':True}))
'@
$baselineProof = python -c $baselineGuard $repositoryRoot
if ($LASTEXITCODE -ne 0) { throw 'Frozen baseline or production witness provenance failed.' }
$report = [ordered]@{
    checkout_ref = $checkout; checkout_tree = $tree; run_id = [string]$env:GITHUB_RUN_ID
    run_attempt = [string]$env:GITHUB_RUN_ATTEMPT; source_sha256 = $sourceHashes; status = 'incomplete'
    ablation = 'Actual production compact validation witness versus the exact full-result helper frozen to source 9a4c63f. Whole SaveManager reconstruction proves this helper is the sole runtime change; strict admission and storage protocol are identical.'
    sampling = 'Four alternating pairs in each parser-cache mode; sixteen fresh isolated processes, each cloning the same full saves directory. Modes are separate experiments; do not pool them.'
    limits = 'Shared Windows runner; process-fresh, not OS-cache-cold. Immutable capture and fixed clock; real public preparation/commit and disk I/O, no live UI, issuer-flush callback, rendering or physical input-to-paint. No speed threshold or complete gameplay responsiveness claim.'
    timing_boundaries = 'prepare_us and commit_us time the individual public calls. envelope_us continuously surrounds both, including only token/reference and shallow cache bookkeeping between them. These nested timers must not be summed. All expensive oracles are outside the envelope.'
    baseline_body_proof = ($baselineProof | ConvertFrom-Json); processes = @(); modes = [ordered]@{}
}
function Invoke-Probe([string]$Name, [string[]]$Arguments, [int]$Timeout = 180) {
    Assert-Sources
    $evidence = ".godot/ci/manual-save-witness/$Name-process.jsonl"
    $logName = "cloud-manual-save-witness-$Name.log"
    & $runner -SuiteId "manual-save-witness-$Name" -LogName $logName -EvidenceLogPath $evidence `
        -GodotArgs $Arguments -TimeoutSeconds $Timeout -KeepRoot | Out-Null
    $exitCode = $LASTEXITCODE
    $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
    $lines = @()
    $record = $null
    if (Test-Path -LiteralPath $log) {
        Copy-Item -LiteralPath $log -Destination (Join-Path $output "logs/$logName")
        $lines = @(Get-Content -LiteralPath $log)
    }
    $processPath = Join-Path $repositoryRoot $evidence
    if (Test-Path -LiteralPath $processPath) {
        $records = @(Get-Content -LiteralPath $processPath | ForEach-Object { $_ | ConvertFrom-Json })
        if ($records.Count -ne 1) { throw 'Each diagnostic process needs exactly one isolation receipt.' }
        $record = $records[0]
        if (@($report.processes | Where-Object { $null -ne $_.process -and $_.process.test_root -ceq $record.test_root }).Count) {
            throw 'Each probe must use a new isolated process root.'
        }
    }
    $receipt = [ordered]@{ name = $Name; exit_code = $exitCode; process = $record
        log = "logs/$logName"; log_sha256 = if (Test-Path -LiteralPath $log) { Get-Sha256 $log } else { $null }
        marker_lines = @($lines | Where-Object { $_ -match '^(MANUAL_SAVE_WRITE_PASS: |SEVEN_DAY_HISTORY_(DAY|WRITE_PASS|READ_PASS): )' }) }
    $report.processes += $receipt
    Save-Json $report 'results.json'
    if ($exitCode -ne 0 -or $null -eq $record -or $record.exit_code -ne 0) {
        $lines | Write-Host
        throw "Diagnostic process $Name failed ($exitCode)."
    }
    if ($lines -match 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character') {
        throw "Diagnostic process $Name reported a script or Unicode error."
    }
    Assert-Sources
    return [pscustomobject]@{ Lines = $lines; Record = $record; Receipt = $receipt }
}
$environment = [ordered]@{}
foreach ($name in @('DWM_CHECKPOINT_PROFILE', 'DWM_CONSEQUENCE_PROFILE', 'DWM_SAVE_LOAD_PROFILE', 'DWM_SAVE_PARSE_CACHE_DISABLED')) {
    $environment[$name] = [Environment]::GetEnvironmentVariable($name)
    [Environment]::SetEnvironmentVariable($name, '')
}
try {
    $producer = Invoke-Probe 'producer' @('-s', 'res://tests/manual/benchmark_seven_day_history.gd', '--',
        '--phase2r-bootstrap-mode=final', '--history-phase=write') 660
    $days = @(Get-Markers $producer.Lines 'SEVEN_DAY_HISTORY_DAY: ')
    $written = @(Get-Markers $producer.Lines 'SEVEN_DAY_HISTORY_WRITE_PASS: ')
    if ($days.Count -ne 7 -or $written.Count -ne 1 -or $written[0].days -ne 7 -or
        $written[0].synthetic_checkpoints -ne 98 -or $written[0].retained.line -ne 32 -or
        $written[0].retained.manual_save -ne 32 -or $written[0].retained.semantic -ne 2) {
        throw 'Producer must prove seven days, 98 synthetic checkpoints and exact 32/32/2 retention.'
    }
    for ($index = 0; $index -lt 7; $index++) {
        if ($days[$index].day -ne $index + 1) { throw 'Producer day sequence differs.' }
    }
    $source = [string]$producer.Record.user_dir
    $sourceManifest = @(Get-Manifest $source)
    Copy-Item -LiteralPath $source -Destination $retainedRoot -Recurse -Force
    Assert-Same @(Get-Manifest $retainedRoot) $sourceManifest 'retained full producer directory'
    $savesManifest = @(Get-Manifest (Join-Path $source 'saves'))
    foreach ($required in @('autosave.json', 'slot_1.json')) {
        if (@($savesManifest | Where-Object { $_.file -ceq $required }).Count -ne 1) { throw "Missing $required" }
    }
    $autosaveHash = Get-Sha256 (Join-Path $source 'saves/autosave.json')
    if ($autosaveHash -cne $written[0].autosave_sha256) { throw 'Producer autosave hash differs.' }
    $fixture = [ordered]@{ checkout_ref = $checkout; checkout_tree = $tree
        run_id = $report.run_id; run_attempt = $report.run_attempt; source_sha256 = $sourceHashes
        producer_process = $producer.Receipt; directory = 'producer-user'; files = $sourceManifest
        saves_files = $savesManifest; write = $written[0]; days = $days }
    Save-Json $fixture 'producer-manifest.json'
    $report['producer_manifest_sha256'] = Get-Sha256 (Join-Path $output 'producer-manifest.json')
    Write-Host ('MANUAL_SAVE_WITNESS_FIXTURE: ' + ([ordered]@{ checkout_ref = $checkout; checkout_tree = $tree
        run_id = $report.run_id; run_attempt = $report.run_attempt; directory = 'producer-user'; files = $sourceManifest
        manifest_sha256 = $report.producer_manifest_sha256; write = $written[0] } | ConvertTo-Json -Depth 8 -Compress))
    $read = Invoke-Probe 'cold-login' @('-s', 'res://tests/manual/benchmark_seven_day_history.gd', '--',
        '--phase2r-bootstrap-mode=final', '--history-phase=read', "--user-data=$source")
    $restored = @(Get-Markers $read.Lines 'SEVEN_DAY_HISTORY_READ_PASS: ')
    if ($restored.Count -ne 1 -or $restored[0].day -ne 7 -or $restored[0].retained_checkpoint_count -ne 66 -or
        $restored[0].autosave_sha256 -cne $autosaveHash -or -not $restored[0].parse_cache_enabled -or
        $restored[0].save_manager_sha256 -cne $sourceHashes['autoload/SaveManager.gd']) {
        throw 'Fresh Login must restore the exact producer and all 66 checkpoints.'
    }
    $report['cold_login'] = $restored[0]
    Assert-Same @(Get-Manifest $source) $sourceManifest 'source after cold Login'
    $globalReference = $null
    $sourceSaveHashes = [ordered]@{}
    foreach ($file in $savesManifest) { $sourceSaveHashes[$file.file] = $file.sha256 }
    $commonFields = @('candidate_sha256', 'source_revision', 'source_files_sha256', 'output_files_sha256',
        'prior_journal_sha256', 'journal_sha256', 'output_sha256', 'output_bytes', 'retained_checkpoint_count',
        'capture_input_sha256', 'prepared_record_sha256')
    $metrics = @('prepare_us', 'commit_us', 'envelope_us')
    foreach ($mode in @('enabled', 'disabled')) {
        $env:DWM_SAVE_PARSE_CACHE_DISABLED = if ($mode -ceq 'disabled') { '1' } else { '' }
        $report.modes[$mode] = [ordered]@{ pairs = @(); summary = [ordered]@{} }
        $modeReference = $null
        for ($pair = 1; $pair -le 4; $pair++) {
            $order = if ($pair % 2) { @('baseline', 'production') } else { @('production', 'baseline') }
            $samples = [ordered]@{}
            foreach ($variant in $order) {
                $probe = Invoke-Probe "$mode-pair-$pair-$variant" @('-s', 'res://tests/manual/benchmark_manual_save_write.gd', '--',
                    '--phase2r-bootstrap-mode=test_manual', "--write-source=$(Join-Path $source 'saves')", "--write-variant=$variant")
                $records = @(Get-Markers $probe.Lines 'MANUAL_SAVE_WRITE_PASS: ')
                if ($records.Count -ne 1) { throw 'Manual probe needs exactly one complete result.' }
                $sample = $records[0]
                if ($sample.write_variant -cne $variant -or $sample.timing_mode -cne 'continuous' -or
                    $sample.parse_cache_enabled -ne ($mode -ceq 'enabled') -or
                    $sample.strict_validation_calls -ne 1 -or $sample.retained_checkpoint_count -ne 66 -or
                    $sample.save_manager_sha256 -cne $sourceHashes['autoload/SaveManager.gd'] -or
                    $sample.storage_sha256 -cne $sourceHashes['scripts/infrastructure/storage/JsonFileStorage.gd'] -or
                    $sample.witness_port_sha256 -cne $sourceHashes['tests/support/ManualSaveWitnessPort.gd'] -or
                    $sample.harness_sha256 -cne $sourceHashes['tests/manual/benchmark_manual_save_write.gd']) {
                    throw 'Manual sample source, variant, cache mode or strict admission differs.'
                }
                foreach ($metric in $metrics) { if ($null -eq $sample.$metric -or $sample.$metric -lt 0) { throw "Invalid $metric" } }
                if ($sample.envelope_us -lt ($sample.prepare_us + $sample.commit_us)) { throw 'Envelope cannot exclude its sequential child calls.' }
                if ($null -eq $globalReference) { $globalReference = $sample }
                if ($null -eq $modeReference) { $modeReference = $sample }
                foreach ($field in $commonFields) { Assert-Same $sample.$field $globalReference.$field $field }
                foreach ($field in @('prepare_validation_calls', 'parse_cache_before_prepare', 'parse_cache_before', 'parse_cache_after')) {
                    Assert-Same $sample.$field $modeReference.$field "$mode/$field"
                }
                Assert-Same $sample.source_files_sha256 $sourceSaveHashes 'full saves admission'
                Assert-Same @(Get-Manifest $source) $sourceManifest 'unchanged producer source'
                Assert-Same @(Get-Manifest $retainedRoot) $sourceManifest 'unchanged retained fixture'
                $samples[$variant] = $sample
            }
            $deltas = [ordered]@{}
            foreach ($metric in $metrics) { $deltas[$metric] = [long]$samples.production.$metric - [long]$samples.baseline.$metric }
            $report.modes[$mode].pairs += [ordered]@{ pair = $pair; order = $order
                baseline = $samples.baseline; production = $samples.production; production_minus_baseline_us = $deltas }
            Save-Json $report 'results.json'
        }
        foreach ($metric in $metrics) {
            $pairs = $report.modes[$mode].pairs
            $report.modes[$mode].summary[$metric] = [ordered]@{
                baseline_median_us = Get-Median @($pairs | ForEach-Object { $_.baseline.$metric })
                production_median_us = Get-Median @($pairs | ForEach-Object { $_.production.$metric })
                median_paired_production_minus_baseline_us = Get-Median @($pairs | ForEach-Object { $_.production_minus_baseline_us[$metric] }) }
        }
        Write-Host ('MANUAL_SAVE_WITNESS_COMPARISON: ' + ([ordered]@{ mode = $mode; pair_count = 4
            summary = $report.modes[$mode].summary; checkout_ref = $checkout; limits = $report.limits } | ConvertTo-Json -Depth 8 -Compress))
    }
    if ($report.processes.Count -ne 18) { throw 'Expected one producer, one fresh Login and sixteen manual probes.' }
    $report.status = 'passed'
    Write-Host 'MANUAL_SAVE_WITNESS_VERIFIED: exact retained fixture, fresh 66-checkpoint Login, eight matched pairs; actual production versus frozen full-result control.'
} finally {
    foreach ($name in $environment.Keys) { [Environment]::SetEnvironmentVariable($name, $environment[$name]) }
    Save-Json $report 'results.json'
    Assert-Sources
}
