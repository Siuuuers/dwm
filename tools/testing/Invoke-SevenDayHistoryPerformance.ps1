param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/seven-day-history'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
New-Item -ItemType Directory -Force -Path $output | Out-Null
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
    $arguments = @('-s', 'res://tests/manual/benchmark_seven_day_history.gd', '--',
        '--phase2r-bootstrap-mode=final', "--history-phase=$Phase")
    if ($Source) { $arguments += "--user-data=$Source" }
    & $runner -SuiteId "cloud-seven-day-history-$Name" -LogName $logName `
        -EvidenceLogPath $evidence -GodotArgs $arguments -KeepRoot | Out-Null
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
                    median = $values[[int][Math]::Floor($values.Count / 2)]
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
            $records[0].parse_cache_enabled -ne ($variant -eq 'enabled')) {
            throw 'Each cold Login control must restore the exact completed Day 7 history.'
        }
        $reads[$variant] = $probe
        $restores[$variant] = $records[0]
        $afterSource = Get-HistorySourceHashes $write.Record.user_dir
        if (($afterSource | ConvertTo-Json -Compress) -cne $sourceManifest) {
            throw 'A read control changed the retained source root.'
        }
    }
    foreach ($field in @('restored_gameplay_sha256', 'restored_board_sha256')) {
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
    $report = [ordered]@{
        checkout_ref = (& git rev-parse HEAD)
        timing_policy = 'Observations on one shared Windows runner; no speed threshold or physical input-to-paint guarantee.'
        timing_boundaries = [ordered]@{
            manual_slot_save_us = 'Production prepare_backup_action(save, slot:1) plus commit_backup_action, including synchronous signal handlers.'
            login_us = 'Automated Title Login, Backup picker opening and Autosave selection, load consent, restore and awaited process frames.'
            phase_scopes = 'Each scope is inclusive. Parent and child scopes overlap and must not be summed; repeated phases inside one scope accumulate.'
            phase_collection = 'Save/load profiles include only labeled manual-save and Title Login measurement windows; startup and opening each daily Backup app before its save timer are excluded.'
        }
        fixture = '7 synthetic line and 7 synthetic manual checkpoint records/day, plus one real Slot 1 save and App loss/day. Public Schedule Done advances to Day 7. This is not an authored-dialogue playthrough.'
        days = $days
        write = $written[0]
        cold_read = $restored[0]
        parse_cache_comparison = $parseCacheComparison
        payload_sha256 = $hash
        checkpoint_profiles = @(Read-HistoryMarkers $write.Lines 'DWM_CHECKPOINT_PROFILE ')
        consequence_profiles = @(Read-HistoryMarkers $write.Lines 'DWM_CONSEQUENCE_PROFILE ')
        save_load_write_profiles = @(Read-HistoryMarkers $write.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -ne '' })
        save_load_read_profiles = @(Read-HistoryMarkers $read.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -ne '' })
        save_load_read_control_profiles = @(Read-HistoryMarkers $reads.disabled.Lines 'DWM_SAVE_LOAD_PROFILE ' | Where-Object { $_.context -ne '' })
    }
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
    $env:DWM_CHECKPOINT_PROFILE = $previousCheckpointProfile
    $env:DWM_CONSEQUENCE_PROFILE = $previousConsequenceProfile
    $env:DWM_SAVE_LOAD_PROFILE = $previousSaveLoadProfile
    $env:DWM_SAVE_PARSE_CACHE_DISABLED = $previousParseCacheDisabled
}
