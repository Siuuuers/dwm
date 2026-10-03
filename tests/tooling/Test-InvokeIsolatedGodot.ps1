[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$helper = Join-Path $repositoryRoot 'tools\testing\Invoke-IsolatedGodot.ps1'
$probe = Join-Path $repositoryRoot 'tools\evidence\print_user_dir.gd'
$powershell = (Get-Process -Id $PID).Path

if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    throw 'ISOLATION_HELPER_MISSING: tools/testing/Invoke-IsolatedGodot.ps1'
}
if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) {
    throw 'ISOLATION_PROBE_MISSING: tools/evidence/print_user_dir.gd'
}

function ConvertTo-SingleQuotedLiteral {
    param([AllowEmptyString()][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-HelperProcess {
    param([string]$SuiteId, [string]$LogName, [string[]]$GodotArgs, [AllowEmptyString()][string]$EvidenceLogPath = '', [int]$TimeoutSeconds = 0)
    $argumentLiterals = @($GodotArgs | ForEach-Object { ConvertTo-SingleQuotedLiteral ([string]$_) })
    $evidenceClause = if ($EvidenceLogPath.Length -eq 0) { '' } else { " -EvidenceLogPath $(ConvertTo-SingleQuotedLiteral $EvidenceLogPath)" }
    $command = "& $(ConvertTo-SingleQuotedLiteral $helper) -SuiteId $(ConvertTo-SingleQuotedLiteral $SuiteId) -LogName $(ConvertTo-SingleQuotedLiteral $LogName) -GodotArgs @($($argumentLiterals -join ','))$evidenceClause -TimeoutSeconds $TimeoutSeconds; exit `$LASTEXITCODE"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $powershell
    $start.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'ISOLATION_FIXTURE_CHILD_START' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $captured = $stdout.TrimEnd()
    if ($process.ExitCode -ne 0 -and $stderr.Trim().Length -ne 0) {
        $captured = @($captured, $stderr.TrimEnd() | Where-Object { $_.Length -ne 0 }) -join "`n"
    }
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $captured }
}

$forbidden = Invoke-HelperProcess -SuiteId 'fixture-forbidden-path' -LogName 'fixture-forbidden-path.log' -GodotArgs @('--path','C:\outside')
if ($forbidden.ExitCode -ne 124) {
    throw "ISOLATION_FORBIDDEN_ARG: expected 124, got $($forbidden.ExitCode): $($forbidden.Stdout)"
}

$escape = Invoke-HelperProcess -SuiteId 'fixture-log-escape' -LogName '..\escape.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd')
if ($escape.ExitCode -ne 124) {
    throw "ISOLATION_LOG_ESCAPE: expected 124, got $($escape.ExitCode): $($escape.Stdout)"
}

$valid = Invoke-HelperProcess -SuiteId 'fixture-valid' -LogName 'fixture-valid.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd')
if ($valid.ExitCode -ne 0) {
    throw "ISOLATION_VALID_RUN: expected 0, got $($valid.ExitCode): $($valid.Stdout)"
}
$lines = @($valid.Stdout -split "`r?`n" | Where-Object { $_.Trim().Length -ne 0 })
if ($lines.Count -ne 1) { throw "ISOLATION_JSON_COUNT: expected one stdout line, got $($lines.Count)." }
$record = ConvertFrom-Json -InputObject $lines[0] -ErrorAction Stop
$expectedKeys = @('suite_id','argv','exit_code','log_path','test_root','user_dir','started_at_utc','ended_at_utc')
$actualKeys = @($record.PSObject.Properties.Name)
if ([string]::Join("`n", $actualKeys) -cne [string]::Join("`n", $expectedKeys)) {
    throw 'ISOLATION_JSON_KEYS: record keys or order drifted.'
}
$root = [IO.Path]::GetFullPath([string]$record.test_root).TrimEnd('\','/')
$user = [IO.Path]::GetFullPath([string]$record.user_dir)
if (-not $user.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ISOLATION_USER_DIR: user_dir is not a strict descendant of test_root.'
}
if (Test-Path -LiteralPath $root) { throw 'ISOLATION_CLEANUP: GUID root survived without -KeepRoot.' }

# A real GUT teardown can log an engine error after its per-test error tracker
# has stopped and still exit 0. The runner must reject that diagnostic, retain
# its exact evidence, and clean the isolated user data despite a passing test.
$invalidTweenOutput = Join-Path $repositoryRoot '.godot\ci\public-surfaces'
[void][IO.Directory]::CreateDirectory($invalidTweenOutput)
$invalidTweenProbeName = 'test_isolation_invalid_tween_' + [guid]::NewGuid().ToString('N') + '.gd'
$invalidTweenProbe = Join-Path $invalidTweenOutput $invalidTweenProbeName
$invalidTweenResource = 'res://.godot/ci/public-surfaces/' + $invalidTweenProbeName
$invalidTweenEvidence = '.godot/ci/public-surfaces/isolation-invalid-tween.jsonl'
$invalidTweenEvidenceFull = Join-Path $repositoryRoot $invalidTweenEvidence
$invalidTweenLog = Join-Path $repositoryRoot '.godot\phase2r_logs\cloud-public-surface-invalid-tween.log'
try {
    $invalidTweenScript = @'
extends GutTest

func test_passes_before_invalid_tween_teardown() -> void:
    assert_true(true)

func after_each() -> void:
    var tween := create_tween()
    tween.tween_interval(1.0)
    tween.kill()
    print("ISOLATION_INVALID_TWEEN_TEARDOWN_STARTED")
    tween.play()
    print("ISOLATION_INVALID_TWEEN_TEARDOWN_COMPLETED")
'@
    [IO.File]::WriteAllText($invalidTweenProbe, $invalidTweenScript, (New-Object Text.UTF8Encoding($false)))
    foreach ($priorOutput in @($invalidTweenEvidenceFull, $invalidTweenLog)) {
        if (Test-Path -LiteralPath $priorOutput) { Remove-Item -LiteralPath $priorOutput -Force }
    }
    $invalidTween = Invoke-HelperProcess -SuiteId 'fixture-invalid-tween' -LogName 'cloud-public-surface-invalid-tween.log' `
        -GodotArgs @('-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=', "-gtest=$invalidTweenResource", '-gexit', '-glog=2') `
        -EvidenceLogPath $invalidTweenEvidence -TimeoutSeconds 60
    # 126 is synthesized only from a zero child exit by the diagnostic gate.
    if ($invalidTween.ExitCode -ne 126 -or -not $invalidTween.Stdout.Contains('TWEEN_INVALID: ERROR: Tween invalid.')) {
        throw "ISOLATION_INVALID_TWEEN_EXIT: expected diagnostic rejection 126, got $($invalidTween.ExitCode): $($invalidTween.Stdout)"
    }
    if (-not (Test-Path -LiteralPath $invalidTweenLog -PathType Leaf)) { throw 'ISOLATION_INVALID_TWEEN_LOG_MISSING' }
    $invalidTweenLogText = Get-Content -LiteralPath $invalidTweenLog -Raw
    $invalidTweenLines = @($invalidTweenLogText -split "`r?`n")
    $invalidTweenErrors = @($invalidTweenLines | Where-Object { $_ -match 'SCRIPT ERROR:|(?:^|\s)ERROR:|Parse Error:' })
    if (@($invalidTweenLines | Where-Object { $_.Trim() -ceq $invalidTweenResource }).Count -ne 1 -or
        -not $invalidTweenLogText.Contains('1/1 passed.') -or
        -not $invalidTweenLogText.Contains('ISOLATION_INVALID_TWEEN_TEARDOWN_STARTED') -or
        -not $invalidTweenLogText.Contains('ISOLATION_INVALID_TWEEN_TEARDOWN_COMPLETED') -or
        $invalidTweenErrors.Count -ne 1 -or
        $invalidTweenErrors[0].Trim() -cne 'ERROR: Tween invalid. Either finished or created outside scene tree.') {
        throw 'ISOLATION_INVALID_TWEEN_RAW_PROOF: expected one executed passing test and one retained native teardown error.'
    }
    $invalidTweenRecords = @(Get-Content -LiteralPath $invalidTweenEvidenceFull)
    if ($invalidTweenRecords.Count -ne 1) { throw 'ISOLATION_INVALID_TWEEN_EVIDENCE_COUNT' }
    $invalidTweenRecord = $invalidTweenRecords[0] | ConvertFrom-Json
    if ($invalidTweenRecord.exit_code -ne 126 -or $invalidTweenRecord.suite_id -cne 'fixture-invalid-tween' -or
        [string]$invalidTweenRecord.log_path -cne [IO.Path]::GetFullPath($invalidTweenLog) -or
        @($invalidTweenRecord.argv | Where-Object { $_ -ceq "-gtest=$invalidTweenResource" }).Count -ne 1) {
        throw 'ISOLATION_INVALID_TWEEN_EVIDENCE_RESULT'
    }
    if (Test-Path -LiteralPath ([string]$invalidTweenRecord.test_root)) {
        throw 'ISOLATION_INVALID_TWEEN_CLEANUP: GUID root survived diagnostic rejection.'
    }
} finally {
    if (Test-Path -LiteralPath $invalidTweenProbe) { Remove-Item -LiteralPath $invalidTweenProbe -Force }
}

# A real non-exiting Godot process must fail before the Actions step timeout,
# retain its last output and command record, and still remove isolated user data.
$timeoutOutput = Join-Path $repositoryRoot '.godot\ci'
[void][IO.Directory]::CreateDirectory($timeoutOutput)
$timeoutProbe = Join-Path $timeoutOutput ('isolation-timeout-' + [guid]::NewGuid().ToString('N') + '.gd')
$timeoutEvidence = '.godot/ci/isolation-timeout.jsonl'
$timeoutEvidenceFull = Join-Path $repositoryRoot $timeoutEvidence
$timeoutLog = Join-Path $repositoryRoot '.godot\phase2r_logs\cloud-isolation-timeout.log'
try {
    $timeoutScript = @'
extends SceneTree

func _init() -> void:
    print("ISOLATION_TIMEOUT_PROBE_STARTED")
'@
    [IO.File]::WriteAllText($timeoutProbe, $timeoutScript, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $timeoutEvidenceFull) { Remove-Item -LiteralPath $timeoutEvidenceFull -Force }
    foreach ($priorLog in @($timeoutLog, ($timeoutLog + '.timeout.log'))) {
        if (Test-Path -LiteralPath $priorLog) { Remove-Item -LiteralPath $priorLog -Force }
    }
    $timeout = Invoke-HelperProcess -SuiteId 'fixture-timeout' -LogName 'cloud-isolation-timeout.log' `
        -GodotArgs @('-s', $timeoutProbe) -EvidenceLogPath $timeoutEvidence -TimeoutSeconds 20
    if ($timeout.ExitCode -ne 124 -or -not $timeout.Stdout.Contains('GODOT_CHILD_TIMEOUT:')) {
        throw "ISOLATION_TIMEOUT_EXIT: expected timed-out exit 124, got $($timeout.ExitCode): $($timeout.Stdout)"
    }
    foreach ($retainedLog in @($timeoutLog, ($timeoutLog + '.timeout.log'))) {
        if (-not (Test-Path -LiteralPath $retainedLog) -or
            -not (Get-Content -LiteralPath $retainedLog -Raw).Contains('ISOLATION_TIMEOUT_PROBE_STARTED')) {
            throw "ISOLATION_TIMEOUT_OUTPUT_MISSING: $retainedLog"
        }
    }
    $timeoutRecords = @(Get-Content -LiteralPath $timeoutEvidenceFull)
    if ($timeoutRecords.Count -ne 1) { throw 'ISOLATION_TIMEOUT_EVIDENCE_COUNT' }
    $timeoutRecord = $timeoutRecords[0] | ConvertFrom-Json
    if ($timeoutRecord.exit_code -ne 124 -or $timeoutRecord.suite_id -cne 'fixture-timeout') {
        throw 'ISOLATION_TIMEOUT_EVIDENCE_RESULT'
    }
    if (Test-Path -LiteralPath ([string]$timeoutRecord.test_root)) {
        throw 'ISOLATION_TIMEOUT_CLEANUP: GUID root survived the timeout.'
    }
    $timeoutDuration = ([DateTime]$timeoutRecord.ended_at_utc - [DateTime]$timeoutRecord.started_at_utc).TotalSeconds
    if ($timeoutDuration -lt 19 -or $timeoutDuration -gt 50) {
        throw "ISOLATION_TIMEOUT_DURATION: expected bounded termination, got $timeoutDuration seconds."
    }
} finally {
    if (Test-Path -LiteralPath $timeoutProbe) { Remove-Item -LiteralPath $timeoutProbe -Force }
}

# -EvidenceLogPath containment for the closeout log root (dwm-p2r.10 Plan 04 Task 3 Step 2).
#
# MUTATION CAMPAIGN, 2026-08-25. Sites were enumerated mechanically from the -EvidenceLogPath
# guard block of Invoke-IsolatedGodot.ps1 plus its exclusive-append writer, then each was disabled
# alone: 7 mutations, 5 killed with exact attribution, 2 documented survivors.
#   killed  drop the closeout root from the creation allowlist -> ISOLATION_EVIDENCE_CLOSEOUT_ROOT (124)
#   killed  never refuse an unapproved missing parent          -> ISOLATION_EVIDENCE_STRAY_PARENT
#   killed  truncate instead of exclusive-append               -> ISOLATION_EVIDENCE_APPEND_COUNT
#   killed  never create the approved parent                   -> ISOLATION_EVIDENCE_CLOSEOUT_ROOT (125)
#   killed  drop BOTH containment asserts                      -> ISOLATION_EVIDENCE_ESCAPE
#   SURVIVES  dropping ONLY the $evidenceFull containment assert
#   SURVIVES  dropping ONLY the post-creation $parent containment assert
# The two survivors are not a coverage gap. Those two asserts are deliberate defence in depth over
# the SAME escape law, so either one alone still rejects a path outside the repository; only
# removing both lets an escape through, and that case is killed exactly. Do not "fix" the
# survivors by deleting one assert to make the campaign look cleaner - that would convert
# redundant containment into single-point containment.
#
# The closeout runner appends one command record per invocation below
# evidence/phase_2r/closeout/logs/. That root must be creatable on demand exactly like the
# pre-existing evidence/phase_2r/logs root, while every other containment guard stays intact.
# This fixture must leave no trace: PREREQUISITE mode requires evidence/phase_2r/closeout to be
# absent, so a surviving fixture directory would redden the very gate it exists to support.
$closeoutRoot = Join-Path $repositoryRoot 'evidence\phase_2r\closeout'
$closeoutPreexisted = Test-Path -LiteralPath $closeoutRoot
$evidenceRelative = 'evidence/phase_2r/closeout/logs/fixture-evidence.jsonl'
$evidenceFull = Join-Path $repositoryRoot 'evidence\phase_2r\closeout\logs\fixture-evidence.jsonl'
$strayParent = Join-Path $repositoryRoot 'evidence\phase_2r\fixture_stray'
try {
    $first = Invoke-HelperProcess -SuiteId 'fixture-evidence-first' -LogName 'fixture-evidence-first.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd') -EvidenceLogPath $evidenceRelative
    if ($first.ExitCode -ne 0) {
        throw "ISOLATION_EVIDENCE_CLOSEOUT_ROOT: expected 0, got $($first.ExitCode): $($first.Stdout)"
    }
    if (-not (Test-Path -LiteralPath $evidenceFull -PathType Leaf)) {
        throw 'ISOLATION_EVIDENCE_RECORD_MISSING: the closeout evidence log was not written.'
    }

    $second = Invoke-HelperProcess -SuiteId 'fixture-evidence-second' -LogName 'fixture-evidence-second.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd') -EvidenceLogPath $evidenceRelative
    if ($second.ExitCode -ne 0) {
        throw "ISOLATION_EVIDENCE_APPEND: expected 0, got $($second.ExitCode): $($second.Stdout)"
    }
    $evidenceBytes = [IO.File]::ReadAllBytes($evidenceFull)
    $evidenceText = (New-Object Text.UTF8Encoding($false)).GetString($evidenceBytes)
    if (-not $evidenceText.EndsWith("`n")) { throw 'ISOLATION_EVIDENCE_NOT_LF_TERMINATED.' }
    if ($evidenceText.Contains("`r")) { throw 'ISOLATION_EVIDENCE_CARRIAGE_RETURN.' }
    $evidenceLines = @($evidenceText.TrimEnd("`n") -split "`n")
    if ($evidenceLines.Count -ne 2) {
        throw "ISOLATION_EVIDENCE_APPEND_COUNT: expected two records, got $($evidenceLines.Count)."
    }
    $suiteIds = @($evidenceLines | ForEach-Object { [string](ConvertFrom-Json -InputObject $_ -ErrorAction Stop).suite_id })
    if ([string]::Join(',', $suiteIds) -cne 'fixture-evidence-first,fixture-evidence-second') {
        throw "ISOLATION_EVIDENCE_APPEND_ORDER: got $([string]::Join(',', $suiteIds))."
    }

    # Widening the allowlist to the closeout log root must not widen it to any other missing parent.
    # The refusal is only observable while the stray parent is ABSENT, so a directory left behind by
    # an earlier failed or mutated run would silently disable this assertion forever. Remove it
    # first: this test must never be able to pass because it stopped testing anything.
    if (Test-Path -LiteralPath $strayParent) { Remove-Item -LiteralPath $strayParent -Recurse -Force }
    $stray = Invoke-HelperProcess -SuiteId 'fixture-evidence-stray' -LogName 'fixture-evidence-stray.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd') -EvidenceLogPath 'evidence/phase_2r/fixture_stray/stray.jsonl'
    if ($stray.ExitCode -ne 124) {
        throw "ISOLATION_EVIDENCE_STRAY_PARENT: expected 124, got $($stray.ExitCode): $($stray.Stdout)"
    }
    if (Test-Path -LiteralPath $strayParent) {
        throw 'ISOLATION_EVIDENCE_STRAY_CREATED: a refused evidence parent was created anyway.'
    }

    $escaped = Invoke-HelperProcess -SuiteId 'fixture-evidence-escape' -LogName 'fixture-evidence-escape.log' -GodotArgs @('-s','res://tools/evidence/print_user_dir.gd') -EvidenceLogPath '../outside-evidence.jsonl'
    if ($escaped.ExitCode -ne 124) {
        throw "ISOLATION_EVIDENCE_ESCAPE: expected 124, got $($escaped.ExitCode): $($escaped.Stdout)"
    }
} finally {
    if (Test-Path -LiteralPath $evidenceFull) { Remove-Item -LiteralPath $evidenceFull -Force }
    if (-not $closeoutPreexisted -and (Test-Path -LiteralPath $closeoutRoot)) {
        Remove-Item -LiteralPath $closeoutRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $strayParent) { Remove-Item -LiteralPath $strayParent -Recurse -Force }
}
if (-not $closeoutPreexisted -and (Test-Path -LiteralPath $closeoutRoot)) {
    throw 'ISOLATION_EVIDENCE_FIXTURE_RESIDUE: the closeout evidence root survived the fixture.'
}
if (Test-Path -LiteralPath $strayParent) {
    throw 'ISOLATION_EVIDENCE_STRAY_RESIDUE: the refused evidence parent survived the fixture.'
}

Write-Output 'ISOLATION_HELPER: PASS'
