param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repositoryRoot '.godot/ci/seven-day-history'
$runner = Join-Path $PSScriptRoot 'Invoke-IsolatedGodot.ps1'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$previousCheckpointProfile = $env:DWM_CHECKPOINT_PROFILE
$previousConsequenceProfile = $env:DWM_CONSEQUENCE_PROFILE
$env:DWM_CHECKPOINT_PROFILE = '1'
$env:DWM_CONSEQUENCE_PROFILE = '1'

function Invoke-HistoryProbe {
    param([string]$Phase, [string]$Source = '')
    $evidence = ".godot/ci/seven-day-history/$Phase.jsonl"
    $logName = "cloud-seven-day-history-$Phase.log"
    $arguments = @('-s', 'res://tests/manual/benchmark_seven_day_history.gd', '--',
        '--phase2r-bootstrap-mode=final', "--history-phase=$Phase")
    if ($Source) { $arguments += "--user-data=$Source" }
    & $runner -SuiteId "cloud-seven-day-history-$Phase" -LogName $logName `
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
    $read = Invoke-HistoryProbe -Phase 'read' -Source $write.Record.user_dir
    $restored = @(Read-HistoryMarkers $read.Lines 'SEVEN_DAY_HISTORY_READ_PASS: ')
    if ($restored.Count -ne 1 -or $restored[0].day -ne 7 -or $restored[0].autosave_sha256 -cne $hash) {
        throw 'Cold Login must restore the exact completed Day 7 history.'
    }
    $report = [ordered]@{
        checkout_ref = (& git rev-parse HEAD)
        timing_policy = 'Observations on one shared Windows runner; no speed threshold or physical input-to-paint guarantee.'
        fixture = '7 synthetic line and 7 synthetic manual checkpoint records/day, plus one real Slot 1 save and App loss/day. Public Schedule Done advances to Day 7. This is not an authored-dialogue playthrough.'
        days = $days
        write = $written[0]
        cold_read = $restored[0]
        payload_sha256 = $hash
        checkpoint_profiles = @(Read-HistoryMarkers $write.Lines 'DWM_CHECKPOINT_PROFILE ')
        consequence_profiles = @(Read-HistoryMarkers $write.Lines 'DWM_CONSEQUENCE_PROFILE ')
    }
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
    Write-Host 'SEVEN_DAY_HISTORY_PERFORMANCE_VERIFIED: seven real days, saturated checkpoint budgets, exact cold Login.'
} finally {
    $env:DWM_CHECKPOINT_PROFILE = $previousCheckpointProfile
    $env:DWM_CONSEQUENCE_PROFILE = $previousConsequenceProfile
}
