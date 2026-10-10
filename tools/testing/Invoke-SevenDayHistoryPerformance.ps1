param([switch]$ComparePreparation)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/seven-day-history'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$saveManager = Join-Path $repositoryRoot 'autoload/SaveManager.gd'
$candidateBytes = [IO.File]::ReadAllBytes($saveManager)
$baseline = Join-Path $output 'baseline-SaveManager.gd'
python (Join-Path $PSScriptRoot 'derive_save_admission_baseline.py') $saveManager $baseline
if ($LASTEXITCODE -ne 0) { throw 'Could not derive the current-source SaveManager baseline.' }
$baselineBytes = [IO.File]::ReadAllBytes($baseline)
$manualMode = if ($ComparePreparation) { 'prepare' } else { 'write' }
$manualMetric = if ($ComparePreparation) { 'prepare_us' } else { 'commit_us' }
$manualMarker = if ($ComparePreparation) { 'MANUAL_SAVE_PREPARE' } else { 'MANUAL_SAVE_WRITE' }
$manualBaseline = Join-Path $output "baseline-$manualMode-SaveManager.gd"
$manualDeriver = if ($ComparePreparation) { 'derive_save_prepare_baseline.py' } else { 'derive_save_write_baseline.py' }
python (Join-Path $PSScriptRoot $manualDeriver) $saveManager $manualBaseline
if ($LASTEXITCODE -ne 0) { throw "Could not derive the manual $manualMode baseline." }
$manualBaselineBytes = [IO.File]::ReadAllBytes($manualBaseline)
$manualSourceHashes = [ordered]@{
    candidate = (Get-FileHash -LiteralPath $saveManager -Algorithm SHA256).Hash.ToLowerInvariant()
    baseline = (Get-FileHash -LiteralPath $manualBaseline -Algorithm SHA256).Hash.ToLowerInvariant()
    storage = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot 'scripts/infrastructure/storage/JsonFileStorage.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
    harness = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot 'tests/manual/benchmark_manual_save_write.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
    witness_port = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot 'tests/support/ManualSaveWitnessPort.gd') -Algorithm SHA256).Hash.ToLowerInvariant()
}
$sourceCodeHashes = [ordered]@{
    candidate = (Get-FileHash -LiteralPath $saveManager -Algorithm SHA256).Hash.ToLowerInvariant()
    baseline = (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant()
    shared = [ordered]@{}
}
foreach ($relative in @('scripts/infrastructure/save/SaveMigrations.gd',
    'scripts/infrastructure/save/SaveDocumentSchema.gd', 'scripts/domain/run/RunSnapshotSchema.gd',
    'scripts/infrastructure/save/CheckpointJournal.gd')) {
    $sourceCodeHashes.shared[$relative] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
}
$previousCheckpointProfile = $env:DWM_CHECKPOINT_PROFILE
$previousConsequenceProfile = $env:DWM_CONSEQUENCE_PROFILE
$previousSaveLoadProfile = $env:DWM_SAVE_LOAD_PROFILE
$previousParseCacheDisabled = $env:DWM_SAVE_PARSE_CACHE_DISABLED
$env:DWM_CHECKPOINT_PROFILE = '1'
$env:DWM_CONSEQUENCE_PROFILE = '1'
$env:DWM_SAVE_LOAD_PROFILE = '1'
$env:DWM_SAVE_PARSE_CACHE_DISABLED = ''

function Invoke-HistoryProbe {
    param([string]$Phase, [string]$Source = '', [string]$Name = '')
    if (-not $Name) { $Name = $Phase }
    $evidence = ".godot/ci/seven-day-history/$Name.jsonl"
    $logName = "cloud-seven-day-history-$Name.log"
    if ($Phase -eq 'write-commit') {
        $arguments = @('-s', 'res://tests/manual/benchmark_manual_save_write.gd', '--',
            '--phase2r-bootstrap-mode=test_manual', "--write-source=$(Join-Path $Source 'saves')")
    } else {
        $arguments = @('-s', 'res://tests/manual/benchmark_seven_day_history.gd', '--',
            '--phase2r-bootstrap-mode=final', "--history-phase=$Phase")
        if ($Source) { $arguments += "--user-data=$Source" }
    }
    $timeout = if ($Phase -eq 'write') { 660 } else { 180 }
    & $runner -SuiteId "cloud-seven-day-history-$Name" -LogName $logName `
        -EvidenceLogPath $evidence -GodotArgs $arguments -TimeoutSeconds $timeout -KeepRoot | Out-Null
    $result = $LASTEXITCODE
    $log = Join-Path $repositoryRoot ".godot/phase2r_logs/$logName"
    if ($result -ne 0) {
        if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Write-Host }
        throw "History $Phase failed with exit $result."
    }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character' -Quiet) {
        throw "History $Phase reported a script or Unicode error."
    }
    return [pscustomobject]@{
        Lines = @(Get-Content -LiteralPath $log)
        Record = (Get-Content -LiteralPath (Join-Path $repositoryRoot $evidence) | Select-Object -Last 1 | ConvertFrom-Json)
    }
}

function Read-HistoryMarkers {
    param([string[]]$Lines, [string]$Prefix)
    return @($Lines | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) } |
        ForEach-Object { $_.Substring($Prefix.Length) | ConvertFrom-Json })
}

function Get-HistorySourceHashes {
    param([string]$Source)
    $hashes = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Source -Recurse -File -Filter '*.json' | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($Source, $file.FullName).Replace('\', '/')
        $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    return $hashes
}

function Get-HistoryMedian {
    param([long[]]$Values)
    $ordered = @($Values | Sort-Object)
    if ($ordered.Count -eq 0) { throw 'A timing median requires samples.' }
    $middle = [int][Math]::Floor($ordered.Count / 2)
    if ($ordered.Count % 2 -eq 0) { return ($ordered[$middle - 1] + $ordered[$middle]) / 2.0 }
    return $ordered[$middle]
}

function Assert-CheckpointDiagnostics {
    param([object[]]$Records)
    $prepareFields = @('document_proof_entries', 'document_proof_hits', 'document_proof_misses',
        'document_proof_lookup_us', 'document_schema_build_us', 'document_schema_discriminators_us',
        'document_schema_proof_selection_us', 'document_schema_normalize_current_us',
        'document_schema_normalize_journal_us', 'document_schema_validate_current_us',
        'document_schema_validate_journal_us', 'document_schema_compose_us', 'document_schema_metadata_us')
    $commitFields = @('outgoing_normalize_us', 'outgoing_validate_us', 'outgoing_history_capture_us',
        'outgoing_schema_envelope_normalize_us', 'outgoing_schema_shape_us',
        'outgoing_schema_validate_current_us', 'outgoing_schema_compose_current_us',
        'journal_current_compare_us', 'journal_current_remember_us', 'journal_history_learning_us',
        'journal_current_learn_attempts', 'journal_current_learn_successes', 'document_proof_remember_us',
        'history_proof_entries', 'history_proof_hits', 'history_proof_misses', 'history_proof_skipped',
        'history_proof_emit_failures', 'history_proof_region_misses', 'history_proof_learn_attempts',
        'history_proof_learn_successes', 'history_proof_lookup_us', 'history_proof_emit_us',
        'history_proof_region_us', 'history_proof_remember_us')
    $counts = [ordered]@{ diagnostics_version = 2; prepare_records = 0; commit_records = 0 }
    foreach ($record in $Records) {
        if ($record.scope -cnotin @('save_checkpoint_prepare', 'save_checkpoint')) { continue }
        if (-not $record.ok -or -not $record.autosave) { continue }
        if ($null -eq $record.PSObject.Properties['diagnostics_version'] -or $record.diagnostics_version -ne 2) {
            throw 'Checkpoint profiles must contain version 2 phase diagnostics.'
        }
        if ($record.scope -ceq 'save_checkpoint_prepare') {
            $fields = $prepareFields
            $booleans = @('document_schema_journal_proven')
            $counts.prepare_records += 1
        } elseif ($record.scope -ceq 'save_checkpoint') {
            $journalField = if ($record.journal_spliced) { 'outgoing_schema_compose_proven_journal_us' } else { 'outgoing_schema_validate_journal_us' }
            $fields = $commitFields + @($journalField)
            $booleans = @('journal_current_proof_available', 'journal_current_proof_matches')
            $counts.commit_records += 1
        } else { throw "Unexpected checkpoint diagnostic scope: $($record.scope)" }
        foreach ($field in $fields) {
            if ($null -eq $record.PSObject.Properties[$field] -or $null -eq $record.$field -or [long]$record.$field -lt 0) {
                throw "Missing or invalid checkpoint diagnostic: $($record.scope).$field"
            }
        }
        foreach ($field in $booleans) {
            if ($null -eq $record.PSObject.Properties[$field] -or $record.$field -isnot [bool]) {
                throw "Missing checkpoint proof outcome: $($record.scope).$field"
            }
        }
    }
    if ($counts.prepare_records -eq 0 -or $counts.prepare_records -ne $counts.commit_records) {
        throw 'Checkpoint diagnostics need matched successful autosave prepare and commit records.'
    }
    return $counts
}

function Get-HistoryProfileSummary {
    param([object[]]$Records, [string]$Family)
    # Keep scopes/phases separate: consequence parent and child elapsed values overlap.
    $groups = @{}
    foreach ($record in $Records) {
        $phase = if ($null -ne $record.PSObject.Properties['phase']) { [string]$record.phase } else { '' }
        $kind = if ($null -ne $record.PSObject.Properties['checkpoint_kind']) { [string]$record.checkpoint_kind } else { '' }
        $key = "$($record.scope)|$phase|$kind"
        if ($Family.StartsWith('save_load', [StringComparison]::Ordinal)) {
            $key = "$($record.context)|$($record.scope)|$($record.action)|$($record.locator)"
        }
        if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
        $groups[$key] += $record
    }
    foreach ($key in @($groups.Keys | Sort-Object)) {
        $items = @($groups[$key])
        $summary = [ordered]@{ family = $Family; group = $key; count = $items.Count; phases = [ordered]@{} }
        $metrics = @($items | ForEach-Object { $_.PSObject.Properties.Name } |
            Where-Object { $_.EndsWith('_us', [StringComparison]::Ordinal) } | Sort-Object -Unique)
        foreach ($metric in $metrics) {
            $values = @($items | Where-Object { $null -ne $_.PSObject.Properties[$metric] } | ForEach-Object { [long]$_.$metric } | Sort-Object)
            if ($values.Count -gt 0) {
                $summary.phases[$metric] = [ordered]@{
                    sum = ($values | Measure-Object -Sum).Sum
                    median = Get-HistoryMedian $values
                    max = $values[-1]
                }
            }
        }
        $spliceRecords = @($items | Where-Object { $null -ne $_.PSObject.Properties['journal_spliced'] })
        if ($spliceRecords.Count -gt 0) {
            $summary['spliced'] = @($spliceRecords | Where-Object { $_.journal_spliced }).Count
            $summary['full_document'] = @($spliceRecords | Where-Object { -not $_.journal_spliced }).Count
        }
        $parseRecords = @($items | Where-Object { $null -ne $_.PSObject.Properties['cache_hit'] })
        if ($parseRecords.Count -gt 0) {
            $summary['cache_hits'] = @($parseRecords | Where-Object { $_.cache_hit }).Count
            $summary['parse_calls'] = @($parseRecords | Where-Object { -not $_.cache_hit }).Count
        }
        $proofCounts = [ordered]@{}
        $countFields = @($items | ForEach-Object { $_.PSObject.Properties.Name } |
            Where-Object { $_ -match '^(document_proof|journal_current|history_proof)_(entries|hits|misses|skipped|emit_failures|region_misses|learn_attempts|learn_successes)$' } |
            Sort-Object -Unique)
        foreach ($field in $countFields) {
            $proofCounts[$field] = ($items | Where-Object { $null -ne $_.PSObject.Properties[$field] } |
                ForEach-Object { [long]$_.$field } | Measure-Object -Sum).Sum
        }
        if ($proofCounts.Count -gt 0) { $summary['proof_counts'] = $proofCounts }
        Write-Output $summary
    }
}

try {
    $write = Invoke-HistoryProbe -Phase 'write'
    $days = @(Read-HistoryMarkers $write.Lines 'SEVEN_DAY_HISTORY_DAY: ')
    $written = @(Read-HistoryMarkers $write.Lines 'SEVEN_DAY_HISTORY_WRITE_PASS: ')
    if ($days.Count -ne 7 -or $written.Count -ne 1 -or $written[0].synthetic_checkpoints -ne 98) {
        throw 'History write must report all seven days and the explicit synthetic fixture.'
    }
    for ($index = 0; $index -lt 7; $index++) {
        if ($days[$index].day -ne ($index + 1) -or $days[$index].terminal_settlement_us -lt 0) {
            throw 'History day order or timing is invalid.'
        }
    }
    if ($written[0].retained.line -ne 32 -or $written[0].retained.manual_save -ne 32 -or $written[0].retained.semantic -ne 2) {
        throw 'History stress must saturate the unchanged 32 line / 32 manual / 2 semantic budgets.'
    }
    $checkpointProfiles = @(Read-HistoryMarkers $write.Lines 'DWM_CHECKPOINT_PROFILE ')
    $checkpointDiagnostics = Assert-CheckpointDiagnostics $checkpointProfiles
    Write-Host ('CHECKPOINT_PHASE_DIAGNOSTICS_VERIFIED: ' + ($checkpointDiagnostics | ConvertTo-Json -Compress))
    $fixed = Join-Path $output 'day7-autosave.json'
    Copy-Item -LiteralPath (Join-Path $write.Record.user_dir 'saves/autosave.json') -Destination $fixed
    $hash = (Get-FileHash -LiteralPath $fixed -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -cne $written[0].autosave_sha256) { throw 'Copied Day 7 payload hash differs.' }
    # Each process clones the same untouched write root before Bootstrap starts. The control
    # changes only parser reuse; real reads, revision/schema checks and the Login journey remain.
    $reads = [ordered]@{}
    $restores = [ordered]@{}
    $sourceHashes = Get-HistorySourceHashes $write.Record.user_dir
    $sourceManifest = $sourceHashes | ConvertTo-Json -Compress
    foreach ($variant in @('disabled', 'enabled')) {
        $env:DWM_SAVE_PARSE_CACHE_DISABLED = if ($variant -eq 'disabled') { '1' } else { '' }
        $probe = Invoke-HistoryProbe -Phase 'read' -Source $write.Record.user_dir -Name "read-cache-$variant"
        $records = @(Read-HistoryMarkers $probe.Lines 'SEVEN_DAY_HISTORY_READ_PASS: ')
        if ($records.Count -ne 1 -or $records[0].day -ne 7 -or $records[0].autosave_sha256 -cne $hash -or
            $records[0].parse_cache_enabled -ne ($variant -eq 'enabled') -or
            $records[0].save_manager_sha256 -cne $sourceCodeHashes.candidate -or $records[0].retained_checkpoint_count -ne 66) {
            throw 'Each cold Login control must restore the exact completed Day 7 history.'
        }
        $reads[$variant] = $probe
        $restores[$variant] = $records[0]
        $afterSource = Get-HistorySourceHashes $write.Record.user_dir
        if (($afterSource | ConvertTo-Json -Compress) -cne $sourceManifest) {
            throw 'A read control changed the retained source root.'
        }
    }
    foreach ($field in @('restored_gameplay_sha256', 'restored_board_sha256', 'restored_recovery_journal_sha256')) {
        if ($restores.disabled.$field -cnotmatch '^[0-9a-f]{64}$' -or
            $restores.disabled.$field -cne $restores.enabled.$field) {
            throw "Cold Login controls differ in $field."
        }
    }
    $read = $reads.enabled
    $restored = @($restores.enabled)
    $parseCacheComparison = [ordered]@{
        control = 'Same checkout and retained user-data source, cloned into a new isolated process per variant. Only DWM_SAVE_PARSE_CACHE_DISABLED differs.'
        sampling = 'One cold Login per variant, fixed disabled-then-enabled order on one shared Windows runner; observational, not a repeated-sample or frame-time guarantee.'
        source_json_sha256 = $sourceHashes
        disabled = $restores.disabled; enabled = $restores.enabled
    }
    # Eight matched pairs, each with fresh processes and cloned identical saved bytes. Keep
    # parser reuse enabled in BOTH variants; only the four redundant admission traversals differ.
    $env:DWM_SAVE_PARSE_CACHE_DISABLED = ''
    $admissionComparison = [ordered]@{
        control = 'Current SaveManager versus the same source with only the four redundant schema validations restored. Same current schemas, parse cache enabled, identical retained source bytes, one new isolated process per sample.'
        sampling = 'Eight matched pairs / sixteen processes; odd pairs baseline then candidate, even pairs candidate then baseline. Shared Windows runner; process-cold Login, not flushed OS filesystem caches or physical input-to-paint.'
        source_code_sha256 = $sourceCodeHashes
        source_json_sha256 = $sourceHashes
        pairs = @()
    }
    for ($pair = 1; $pair -le 8; $pair++) {
        $order = if ($pair % 2 -eq 1) { @('baseline', 'candidate') } else { @('candidate', 'baseline') }
        $measurements = [ordered]@{}
        $profiles = [ordered]@{}
        foreach ($variant in $order) {
            $variantBytes = if ($variant -eq 'baseline') { $baselineBytes } else { $candidateBytes }
            [IO.File]::WriteAllBytes($saveManager, $variantBytes)
            if ((Get-FileHash -LiteralPath $saveManager -Algorithm SHA256).Hash.ToLowerInvariant() -cne $sourceCodeHashes[$variant]) {
                throw 'Installed SaveManager differs from its measured source hash.'
            }
            $probe = Invoke-HistoryProbe -Phase 'read' -Source $write.Record.user_dir -Name "read-admission-pair-$pair-$variant"
            $records = @(Read-HistoryMarkers $probe.Lines 'SEVEN_DAY_HISTORY_READ_PASS: ')
            if ($records.Count -ne 1 -or $records[0].day -ne 7 -or $records[0].autosave_sha256 -cne $hash -or
                -not $records[0].parse_cache_enabled -or $records[0].save_manager_sha256 -cne $sourceCodeHashes[$variant] -or
                $records[0].retained_checkpoint_count -ne 66 -or $records[0].login_us -lt 0) {
                throw 'Admission sample must prove its source variant and exact Day 7 recovery.'
            }
            foreach ($field in @('restored_gameplay_sha256', 'restored_board_sha256', 'restored_recovery_journal_sha256')) {
                if ($records[0].$field -cne $restores.enabled.$field) {
                    throw "Admission comparison changed $field."
                }
            }
            if (((Get-HistorySourceHashes $write.Record.user_dir) | ConvertTo-Json -Compress) -cne $sourceManifest) {
                throw 'Admission comparison changed retained source bytes.'
            }
            $measurements[$variant] = $records[0]
            $profiles[$variant] = @(Read-HistoryMarkers $probe.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -ne '' })
        }
        $comparison = [ordered]@{
            pair = $pair; order = $order; baseline = $measurements.baseline; candidate = $measurements.candidate
            candidate_minus_baseline_us = [long]$measurements.candidate.login_us - [long]$measurements.baseline.login_us
            profiles = $profiles
        }
        $admissionComparison.pairs += $comparison
        # Preserve completed pairs if a later probe fails or reaches its bounded timeout.
        $admissionComparison | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $output 'admission-pairs.json') -Encoding utf8
        Write-Host ('SAVE_ADMISSION_PAIR: ' + ([ordered]@{
            pair = $pair; order = $order; baseline = $measurements.baseline; candidate = $measurements.candidate
            candidate_minus_baseline_us = $comparison.candidate_minus_baseline_us
        } | ConvertTo-Json -Depth 8 -Compress))
    }
    [IO.File]::WriteAllBytes($saveManager, $candidateBytes)
    $admissionComparison['summary'] = [ordered]@{
        pair_count = $admissionComparison.pairs.Count
        baseline_median_login_us = Get-HistoryMedian @($admissionComparison.pairs | ForEach-Object { $_.baseline.login_us })
        candidate_median_login_us = Get-HistoryMedian @($admissionComparison.pairs | ForEach-Object { $_.candidate.login_us })
        median_paired_candidate_minus_baseline_us = Get-HistoryMedian @($admissionComparison.pairs | ForEach-Object { $_.candidate_minus_baseline_us })
    }
    $admissionComparison | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $output 'admission-pairs.json') -Encoding utf8
    Write-Host ('SAVE_ADMISSION_COMPARISON: ' + ([ordered]@{
        control = $admissionComparison.control; sampling = $admissionComparison.sampling
        source_code_sha256 = $sourceCodeHashes; source_json_sha256 = $sourceHashes
        summary = $admissionComparison.summary
    } | ConvertTo-Json -Depth 8 -Compress))
    # Select one manual-save ablation; preparation mode replaces the historical write
    # comparison rather than adding another sixteen processes to the bounded job.
    $manualControl = if ($ComparePreparation) {
        'Public prepare_backup_action and commit_backup_action with real storage, the same seeded Day7 journal, immutable capture fixture and a test-subclass fixed clock. Only the discarded eager journal copy in configured capture differs; parse cache and write validation memo are enabled in both.'
    } else {
        'Public prepare_backup_action and commit_backup_action with real storage, the same seeded Day7 journal, immutable capture fixture and a test-subclass fixed clock. The historical control bypasses both the write validation memo and compact success witness; parse cache enabled in both.'
    }
    $manualSampling = if ($ComparePreparation) {
        'Eight alternating pairs / sixteen fresh isolated processes; identical prepared candidate, physical source files, target revision and pre-commit parser cache. Preparation timing covers only the public prepare_backup_action call, including immutable fixture copying, and excludes source cloning, journal seeding, proof generation, commit, live UI callbacks, issuer-flush callbacks and rendering. OS filesystem caches are not flushed.'
    } else {
        'Eight alternating pairs / sixteen fresh isolated processes; identical prepared candidate, physical source files, target revision and pre-commit parser cache. Commit timing excludes preparation, live UI callbacks, issuer-flush callbacks and rendering. OS filesystem caches are not flushed.'
    }
    $manualContext = if ($ComparePreparation) { 'manual-write-prepare' } else { 'manual-write-commit' }
    $manualPairsPath = Join-Path $output "manual-$manualMode-pairs.json"
    $manualComparison = [ordered]@{
        control = $manualControl
        sampling = $manualSampling
        metric = $manualMetric
        source_code_sha256 = $manualSourceHashes
        shared_schema_sha256 = $sourceCodeHashes.shared
        pairs = @()
    }
    $referenceManual = $null
    $invariantFields = @('candidate_sha256', 'source_revision', 'source_files_sha256',
        'output_files_sha256', 'prior_journal_sha256', 'journal_sha256', 'output_sha256',
        'output_bytes', 'retained_checkpoint_count', 'parse_cache_before')
    for ($pair = 1; $pair -le 8; $pair++) {
        $order = if ($pair % 2 -eq 1) { @('baseline', 'candidate') } else { @('candidate', 'baseline') }
        $measurements = [ordered]@{}
        $profiles = [ordered]@{}
        foreach ($variant in $order) {
            $variantBytes = if ($variant -eq 'baseline') { $manualBaselineBytes } else { $candidateBytes }
            [IO.File]::WriteAllBytes($saveManager, $variantBytes)
            if ((Get-FileHash -LiteralPath $saveManager -Algorithm SHA256).Hash.ToLowerInvariant() -cne $manualSourceHashes[$variant]) {
                throw "Installed manual $manualMode comparison source differs from its recorded hash."
            }
            $probe = Invoke-HistoryProbe -Phase 'write-commit' -Source $write.Record.user_dir -Name "$manualMode-pair-$pair-$variant"
            $records = @(Read-HistoryMarkers $probe.Lines 'MANUAL_SAVE_WRITE_PASS: ')
            if ($records.Count -ne 1 -or $records[0].commit_us -lt 0 -or $records[0].prepare_us -lt 0 -or
                $records[0].write_variant -cne 'production' -or $records[0].timing_mode -cne 'legacy-phase-context' -or
                $records[0].retained_checkpoint_count -ne 66 -or -not $records[0].parse_cache_enabled -or
                $records[0].save_manager_sha256 -cne $manualSourceHashes[$variant] -or
                $records[0].storage_sha256 -cne $manualSourceHashes.storage -or
                $records[0].harness_sha256 -cne $manualSourceHashes.harness -or
                $records[0].witness_port_sha256 -cne $manualSourceHashes.witness_port) {
                throw "Manual $manualMode sample must prove its exact source and retained output."
            }
            if ($null -eq $referenceManual) { $referenceManual = $records[0] }
            foreach ($field in $invariantFields) {
                if (($records[0].$field | ConvertTo-Json -Depth 12 -Compress) -cne
                    ($referenceManual.$field | ConvertTo-Json -Depth 12 -Compress)) {
                    throw "Manual $manualMode comparison changed $field."
                }
            }
            if (((Get-HistorySourceHashes $write.Record.user_dir) | ConvertTo-Json -Compress) -cne $sourceManifest) {
                throw "Manual $manualMode comparison changed retained source bytes."
            }
            $measurements[$variant] = $records[0]
            $profiles[$variant] = @(Read-HistoryMarkers $probe.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -eq $manualContext })
        }
        if ($ComparePreparation -and ($measurements.baseline.strict_validation_calls -ne 1 -or
            $measurements.candidate.strict_validation_calls -ne 1)) {
            throw 'Preparation ablation must retain one successful write validation in both variants.'
        }
        if (-not $ComparePreparation -and ($measurements.baseline.strict_validation_calls -le 1 -or
            $measurements.candidate.strict_validation_calls -ne 1)) {
            throw 'Ablation did not exercise repeated baseline validation and one successful candidate validation.'
        }
        $comparison = [ordered]@{
            pair = $pair; order = $order; baseline = $measurements.baseline; candidate = $measurements.candidate
            candidate_minus_baseline_us = [long]$measurements.candidate.$manualMetric - [long]$measurements.baseline.$manualMetric
            profiles = $profiles
        }
        $manualComparison.pairs += $comparison
        $manualComparison | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $manualPairsPath -Encoding utf8
        Write-Host ($manualMarker + '_PAIR: ' + ([ordered]@{
            pair = $pair; order = $order; baseline = $measurements.baseline; candidate = $measurements.candidate
            candidate_minus_baseline_us = $comparison.candidate_minus_baseline_us
        } | ConvertTo-Json -Depth 12 -Compress))
    }
    [IO.File]::WriteAllBytes($saveManager, $candidateBytes)
    $manualComparison['summary'] = [ordered]@{
        pair_count = $manualComparison.pairs.Count
        median_paired_candidate_minus_baseline_us = Get-HistoryMedian @($manualComparison.pairs | ForEach-Object { $_.candidate_minus_baseline_us })
    }
    $manualComparison.summary["baseline_median_$manualMetric"] = Get-HistoryMedian @($manualComparison.pairs | ForEach-Object { $_.baseline.$manualMetric })
    $manualComparison.summary["candidate_median_$manualMetric"] = Get-HistoryMedian @($manualComparison.pairs | ForEach-Object { $_.candidate.$manualMetric })
    $manualComparison | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $manualPairsPath -Encoding utf8
    Write-Host ($manualMarker + '_COMPARISON: ' + ([ordered]@{
        control = $manualComparison.control; sampling = $manualComparison.sampling; metric = $manualMetric
        source_code_sha256 = $manualSourceHashes; summary = $manualComparison.summary
    } | ConvertTo-Json -Depth 8 -Compress))
    $report = [ordered]@{
        checkout_ref = (& git rev-parse HEAD)
        timing_policy = 'Observations on one shared Windows runner; no speed threshold or physical input-to-paint guarantee.'
        timing_boundaries = [ordered]@{
            manual_slot_save_us = 'Production prepare_backup_action(save, slot:1) plus commit_backup_action, including synchronous signal handlers.'
            login_us = 'Automated Title Login, Backup picker opening and Autosave selection, load consent, restore and awaited process frames.'
            phase_scopes = 'Each scope is inclusive. Parent and child scopes overlap and must not be summed; repeated phases inside one scope accumulate.'
            phase_collection = 'Save/load profiles include only labeled manual-save and Title Login measurement windows; startup and opening each daily Backup app before its save timer are excluded.'
            checkpoint_subphases = 'Version 2 document/schema/proof timers are nested inclusive measurements. History proof timers accumulate across entries; document proof lookup stops at its first miss. Profile instrumentation adds overhead and is not a speedup comparison.'
        }
        fixture = '7 synthetic line and 7 synthetic manual checkpoint records/day, plus one real Slot 1 save and App loss/day. Public Schedule Done advances to Day 7. This is not an authored-dialogue playthrough.'
        days = $days
        write = $written[0]
        cold_read = $restored[0]
        parse_cache_comparison = $parseCacheComparison
        save_admission_comparison = $admissionComparison
        payload_sha256 = $hash
        checkpoint_profiles = $checkpointProfiles
        checkpoint_diagnostics = $checkpointDiagnostics
        consequence_profiles = @(Read-HistoryMarkers $write.Lines 'DWM_CONSEQUENCE_PROFILE ')
        save_load_write_profiles = @(Read-HistoryMarkers $write.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -ne '' })
        save_load_read_profiles = @(Read-HistoryMarkers $read.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -ne '' })
        save_load_read_control_profiles = @(Read-HistoryMarkers $reads.disabled.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -ne '' })
    }
    $report["manual_${manualMode}_comparison"] = $manualComparison
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
    # Also expose bounded machine-readable evidence through the job log. Artifact download may
    # be unavailable to a reviewer; never print save contents or the thousands of raw events.
    foreach ($day in $days) {
        $compactDay = [ordered]@{
            day = $day.day; retained = $day.retained; files = $day.files
            first_reveal_sync_us = $day.first_reveal_sync_us
            terminal_reveal_sync_us = $day.terminal_reveal_sync_us
            terminal_settlement_us = $day.terminal_settlement_us
            manual_slot_save_us = $day.manual_slot_save_us
            manual_slot_prepare_us = $day.manual_slot_prepare_us
            manual_slot_commit_us = $day.manual_slot_commit_us
            autosave_sha256 = $day.autosave_sha256
        }
        Write-Host ('SEVEN_DAY_HISTORY_MEASUREMENT: ' + ($compactDay | ConvertTo-Json -Depth 8 -Compress))
    }
    # Preserve first-Reveal/checkpoint ordering after timing, with one-based write-log lines.
    $tracePrefixes = [ordered]@{
        checkpoint = 'DWM_CHECKPOINT_PROFILE '
        consequence = 'DWM_CONSEQUENCE_PROFILE '
        day = 'SEVEN_DAY_HISTORY_DAY: '
    }
    for ($lineIndex = 0; $lineIndex -lt $write.Lines.Count; $lineIndex++) {
        foreach ($family in $tracePrefixes.Keys) {
            $prefix = $tracePrefixes[$family]
            if (-not $write.Lines[$lineIndex].StartsWith($prefix, [StringComparison]::Ordinal)) { continue }
            $value = $write.Lines[$lineIndex].Substring($prefix.Length) | ConvertFrom-Json
            if ($family -eq 'consequence' -and $value.scope -cne 'first_reveal_durable') { continue }
            if ($family -eq 'day') { $value = [ordered]@{ day = $value.day } }
            Write-Host ('SEVEN_DAY_HISTORY_TRACE: ' + ([ordered]@{
                log_line = $lineIndex + 1; family = $family; value = $value
            } | ConvertTo-Json -Depth 8 -Compress))
        }
    }
    $proofSummary = [ordered]@{
        checkout_ref = $report.checkout_ref; payload_bytes = (Get-Item -LiteralPath $fixed).Length
        payload_sha256 = $hash; write = $written[0]; cold_read = $restored[0]
        fixture = $report.fixture; timing_policy = $report.timing_policy
        timing_boundaries = $report.timing_boundaries
        parse_cache_comparison = $parseCacheComparison
    }
    Write-Host ('SEVEN_DAY_HISTORY_PROOF: ' + ($proofSummary | ConvertTo-Json -Depth 8 -Compress))
    foreach ($summary in @(Get-HistoryProfileSummary $report.checkpoint_profiles 'checkpoint') +
        @(Get-HistoryProfileSummary $report.consequence_profiles 'consequence') +
        @(Get-HistoryProfileSummary $report.save_load_write_profiles 'save_load_write') +
        @(Get-HistoryProfileSummary $report.save_load_read_profiles 'save_load_read') +
        @(Get-HistoryProfileSummary $report.save_load_read_control_profiles 'save_load_read_cache_disabled')) {
        Write-Host ('SEVEN_DAY_HISTORY_PROFILE_SUMMARY: ' + ($summary | ConvertTo-Json -Depth 8 -Compress))
    }
    Write-Host 'SEVEN_DAY_HISTORY_PERFORMANCE_VERIFIED: seven real days, saturated checkpoint budgets, exact cold Login.'
} finally {
    [IO.File]::WriteAllBytes($saveManager, $candidateBytes)
    $env:DWM_CHECKPOINT_PROFILE = $previousCheckpointProfile
    $env:DWM_CONSEQUENCE_PROFILE = $previousConsequenceProfile
    $env:DWM_SAVE_LOAD_PROFILE = $previousSaveLoadProfile
    $env:DWM_SAVE_PARSE_CACHE_DISABLED = $previousParseCacheDisabled
}
