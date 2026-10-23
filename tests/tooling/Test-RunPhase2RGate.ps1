[CmdletBinding()]
param()

# =================================================================================================
# Fixture for tools/evidence/run_phase2r_gate.ps1, the Plan-04 Task-3 closeout runner.
#
# SCOPE, and why it stops where it does. A happy-path run of the runner executes the entire frozen
# command inventory - a Godot import, the complete GUT suite, every gate - and is Task-4-scale work
# measured in hours. This fixture therefore proves the REFUSAL PATHS and the PURE HELPERS, which is
# where every law that can silently produce a wrong sealed gate actually lives.
#
# The runner is dot-sourceable: it guards its own entry point with $MyInvocation.InvocationName so
# that dot-sourcing defines its functions without running anything. That is not a test-only hook -
# every function exercised below is the real production function the runner itself calls.
#
# Failures are COLLECTED rather than thrown one at a time, so a mutation campaign gets exact
# per-mutation attribution instead of whichever check happened to come first.
# =================================================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runner = Join-Path $repositoryRoot 'tools\evidence\run_phase2r_gate.ps1'
$metadataPath = Join-Path $repositoryRoot 'prompt_docs\metadata\phase_2r_beads.v1.json'
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)

if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw 'RUN_PHASE2R_GATE_MISSING: tools/evidence/run_phase2r_gate.ps1'
}

$failures = New-Object Collections.Generic.List[string]
function Add-Failure {
    param([string]$Code, [string]$Detail = '')
    if ($Detail.Length -eq 0) { $failures.Add($Code) } else { $failures.Add($Code + ': ' + $Detail) }
}
function Assert-Equal {
    param([string]$Code, [AllowEmptyString()][string]$Expected, [AllowEmptyString()][string]$Actual)
    if ($Expected -cne $Actual) { Add-Failure $Code ("expected <{0}> got <{1}>" -f $Expected, $Actual) }
}
function Assert-True {
    param([string]$Code, [bool]$Condition, [string]$Detail = '')
    if (-not $Condition) { Add-Failure $Code $Detail }
}

## Every refusal below must surface its exact code. A refusal that throws the wrong code, or does
## not throw at all, is a distinct failure so a mutation cannot hide behind a neighbouring guard.
function Assert-Throws {
    param([string]$Code, [string]$ExpectedToken, [scriptblock]$Action)
    try {
        & $Action
    } catch {
        $message = [string]$_.Exception.Message
        if (-not $message.Contains($ExpectedToken)) {
            Add-Failure $Code ("expected token <{0}> in <{1}>" -f $ExpectedToken, $message)
        }
        return
    }
    Add-Failure $Code ("no refusal was raised; expected " + $ExpectedToken)
}

. $runner

# =================================================================================================
# Source-text laws. These are the two Step-4/Step-5 mandates that cannot be observed any other way
# without executing the whole inventory.
# =================================================================================================

$runnerText = $utf8Strict.GetString([IO.File]::ReadAllBytes($runner))

## Without this command dwm-p2r.9's ten stale evidence links pinning 1abf65999f60e7fb reach Task 4
## completely unchallenged. The plan names it explicitly and the brief marks it MANDATORY.
Assert-True 'GATE_INVENTORY_OMITS_METADATA_SYNC' `
    ($runnerText.Contains('tools/beads/Sync-Phase2RMetadata.ps1') -or $runnerText.Contains('tools\beads\Sync-Phase2RMetadata.ps1'))

## The expected requirement set must be DERIVED from the metadata exactly as
## Phase2RCloseoutInventory._expected_requirement_ids derives it. A hardcoded copy would drift
## silently and produce a gate PRE_SEAL rejects, so the presence of any literal requirement id in
## the runner source is itself the defect.
Assert-True 'GATE_REQUIREMENTS_NOT_DERIVED' ($runnerText.Contains('child_contracts') -and $runnerText.Contains('req.ending.'))
Assert-True 'GATE_REQUIREMENTS_HARDCODED' (-not $runnerText.Contains('req.audio.semantic_context'))

# =================================================================================================
# The canonical JSON writer.
#
# A command record's sha256 covers the canonical bytes of that record with sha256 removed, and the
# canonical form is produced by GDScript's scripts/validation/CanonicalJsonWriter.gd. If the
# PowerShell writer drifts from it by one byte every record hash in the sealed gate is wrong.
#
# Twelve committed evidence documents are byte-exact output of that GDScript writer, so they are a
# free oracle needing no Godot process. Three are used here, chosen for nesting depth, size and
# integer content.
# =================================================================================================

$canonicalOracle = @(
    'evidence/phase_2r/schedule/gate.json',
    'evidence/phase_2r/contracts/desktop_contract.json',
    'evidence/phase_2r/runtime/game_state_surface.json'
)
foreach ($relative in $canonicalOracle) {
    $full = Join-Path $repositoryRoot ($relative -replace '/', '\')
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Add-Failure 'GATE_CANONICAL_ORACLE_MISSING' $relative
        continue
    }
    $committed = $utf8Strict.GetString([IO.File]::ReadAllBytes($full))
    if (-not $committed.EndsWith("`n")) {
        Add-Failure 'GATE_CANONICAL_ORACLE_MISSING' ($relative + ' is not LF-terminated')
        continue
    }
    $parsed = ConvertFrom-Json -InputObject $committed.TrimEnd("`n")
    $emitted = ConvertTo-Phase2RCanonicalJson -Value $parsed
    if ($emitted -cne $committed.TrimEnd("`n")) {
        Add-Failure 'GATE_CANONICAL_ORACLE_MISMATCH' $relative
    }
}

## PowerShell's Sort-Object is case-INSENSITIVE by default, which would order "a" before "Z". The
## canonical writer sorts by UTF-8 BYTE order, where 0x5A puts "Z" first. Getting this wrong breaks
## every hash while leaving the document superficially plausible, so it is pinned on its own.
Assert-Equal 'GATE_CANONICAL_KEY_ORDER_NOT_BYTEWISE' `
    '{"Z":2,"a":1}' (ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{ 'a' = 1; 'Z' = 2 }))
Assert-Equal 'GATE_CANONICAL_KEY_ORDER_NOT_BYTEWISE' `
    '{"A":1,"b":2}' (ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{ 'b' = 2; 'A' = 1 }))
## A shorter key that is a prefix of a longer one sorts first.
Assert-Equal 'GATE_CANONICAL_KEY_ORDER_NOT_BYTEWISE' `
    '{"a":1,"ab":2}' (ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{ 'ab' = 2; 'a' = 1 }))
## Above the ASCII range, UTF-16 ordinal and UTF-8 byte order disagree: a supplementary-plane
## key (surrogate pair, 4-byte UTF-8 starting 0xF0) must sort AFTER U+FFFD (3-byte, 0xEF),
## though its UTF-16 units sort first. Only this pair can catch an identity projection.
$replacementKey = [string][char]0xFFFD
$supplementaryKey = [string]([char]0xD83D) + [string]([char]0xDE00)
Assert-Equal 'GATE_CANONICAL_KEY_ORDER_NOT_BYTEWISE' `
    ('{"' + $replacementKey + '":1,"' + $supplementaryKey + '":2}') `
    (ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{ $supplementaryKey = 2; $replacementKey = 1 }))

## Exactly the seven named escapes, \u%04x in LOWERCASE hex below 0x20, and nothing else escaped.
$escaped = [ordered]@{ 'k' = ("q:`" b:\ t:`t n:`n r:`r " + [char]8 + ' ' + [char]12 + ' ' + [char]1) }
Assert-Equal 'GATE_CANONICAL_STRING_ESCAPING' `
    '{"k":"q:\" b:\\ t:\t n:\n r:\r \b \f \u0001"}' (ConvertTo-Phase2RCanonicalJson -Value $escaped)
## 0x01 is hex digits only, so it cannot distinguish lowercase from uppercase \u hex; 0x1f can.
Assert-Equal 'GATE_CANONICAL_STRING_ESCAPING' `
    '{"k":"\u001f"}' (ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{ 'k' = [string][char]0x1F }))

## Compact separators, primitives, nesting and empty containers.
Assert-Equal 'GATE_CANONICAL_SHAPE' '{}' (ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{}))
Assert-Equal 'GATE_CANONICAL_SHAPE' '[]' (ConvertTo-Phase2RCanonicalJson -Value @())
Assert-Equal 'GATE_CANONICAL_SHAPE' '[1,2,3]' (ConvertTo-Phase2RCanonicalJson -Value @(1, 2, 3))
Assert-Equal 'GATE_CANONICAL_SHAPE' `
    '{"a":[{"b":true}],"c":null,"d":false}' `
    (ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{ 'c' = $null; 'a' = @([ordered]@{ 'b' = $true }); 'd' = $false }))

## A float would make the bytes engine-dependent, and no gate member is a float. Fail closed.
Assert-Throws 'GATE_CANONICAL_UNSUPPORTED_NOT_REFUSED' 'GATE_CANONICAL_UNSUPPORTED' {
    ConvertTo-Phase2RCanonicalJson -Value ([ordered]@{ 'a' = [double]1.5 })
}

# =================================================================================================
# The command record hash law: sha256 over the canonical bytes of the record with sha256 REMOVED.
# Hashing it with an empty placeholder still present is the obvious wrong implementation and is
# what this pins.
# =================================================================================================

$sampleRecord = [ordered]@{
    command_id = 'sample-command'
    suite_id = 'sample_suite'
    argv = @('-s', 'res://addons/gut/gut_cmdln.gd')
    exit_code = 0
    log_name = 'sample.log'
    log_path = 'evidence/phase_2r/closeout/logs/sample.log'
    log_sha256 = ('a' * 64)
    scripts = 1
    suites = @('res://tests/unit/tooling/test_sample.gd')
    executed_suites = @('res://tests/unit/tooling/test_sample.gd')
    tests = 3
    passing = 3
    failing = 0
    pending = 0
    asserts = 9
    load_failures = 0
}
$bare = [ordered]@{}
foreach ($key in $sampleRecord.Keys) { $bare[$key] = $sampleRecord[$key] }
$sealed = Add-Phase2RRecordSha256 -Record $sampleRecord
$expectedHash = Get-Phase2RSha256Hex -Bytes ((New-Object Text.UTF8Encoding($false)).GetBytes((ConvertTo-Phase2RCanonicalJson -Value $bare)))
Assert-Equal 'GATE_RECORD_SHA256_NOT_OVER_BARE_RECORD' $expectedHash ([string]$sealed.sha256)
Assert-True 'GATE_RECORD_SHA256_KEY_MISSING' ($sealed.Contains('sha256'))
## A record arriving with a stale sha256 must re-seal to the same digest as a fresh record:
## the hash covers the canonical bytes with sha256 REMOVED, so the stale member is inert.
$staleRecord = [ordered]@{}
foreach ($key in $bare.Keys) { $staleRecord[$key] = $bare[$key] }
$staleRecord['sha256'] = ('f' * 64)
$resealed = Add-Phase2RRecordSha256 -Record $staleRecord
Assert-Equal 'GATE_RECORD_SHA256_NOT_OVER_BARE_RECORD' $expectedHash ([string]$resealed.sha256)

# =================================================================================================
# Path traversal. A schema character class cannot forbid a "." or ".." component, because both are
# built only from characters a legal component needs. Components are the only level this settles at.
# =================================================================================================

foreach ($bad in @('evidence/phase_2r/closeout/logs/..', 'evidence/phase_2r/closeout/logs/../x.log', 'evidence/phase_2r/closeout/./logs/x.log', '../x.log')) {
    Assert-True 'GATE_PATH_TRAVERSAL_NOT_DETECTED' (Test-Phase2RPathTraversal -Path $bad) $bad
}
foreach ($good in @('evidence/phase_2r/closeout/logs/x.log', 'evidence/phase_2r/closeout/gate.json', 'evidence/phase_2r/closeout/logs/a.b.log')) {
    Assert-True 'GATE_PATH_TRAVERSAL_FALSE_POSITIVE' (-not (Test-Phase2RPathTraversal -Path $good)) $good
}

# =================================================================================================
# GUT log parsing. The counts and the executed-suite list are the two things a wrong parse turns
# into a plausible but false sealed gate.
# =================================================================================================

$sampleLog = @(
    'res://tests/unit/tooling/test_alpha.gd',
    '* test_one',
    'res://tests/unit/tooling/test_beta.gd',
    '* test_two',
    'res://tests/unit/tooling/test_alpha.gd',
    '',
    'Totals',
    '------',
    'Scripts               2',
    'Tests                 7',
    'Passing Tests         6',
    'Risky/Pending         1',
    'Asserts             123',
    'Orphans              24',
    'Time              10.00s'
) -join "`n"

$counts = Get-Phase2RGutCounts -LogText $sampleLog
Assert-Equal 'GATE_GUT_COUNTS_SCRIPTS' '2' ([string]$counts.scripts)
Assert-Equal 'GATE_GUT_COUNTS_TESTS' '7' ([string]$counts.tests)
Assert-Equal 'GATE_GUT_COUNTS_PASSING' '6' ([string]$counts.passing)
Assert-Equal 'GATE_GUT_COUNTS_PENDING' '1' ([string]$counts.pending)
Assert-Equal 'GATE_GUT_COUNTS_ASSERTS' '123' ([string]$counts.asserts)
## GUT prints no "Failing Tests" line on a clean run, so a parser that requires one would throw on
## every green gate. Zero is the correct reading of an absent line.
Assert-Equal 'GATE_GUT_COUNTS_FAILING' '0' ([string]$counts.failing)
## GUT emits 'Asserts N/M' when asserts failed: equal halves read as the count, unequal halves
## must refuse rather than let a plausible zero stand in for failed asserts.
Assert-Equal 'GATE_GUT_COUNTS_ASSERTS' '442' ([string](Get-Phase2RGutCounts -LogText 'Asserts             442/442').asserts)
Assert-Throws 'GATE_GUT_COUNTS_ASSERTS_SLASH_NOT_REFUSED' 'GATE_COUNTS_INCONSISTENT' {
    Get-Phase2RGutCounts -LogText 'Asserts             440/442'
}
## Orphans are GUT-owned and constant regardless of what runs; they are never a project count.
Assert-True 'GATE_GUT_COUNTS_ORPHANS_LEAKED' (-not $counts.Contains('orphans'))
## A script that fails to load is the silent-miss 727051ca exploited; the parser must count it.
Assert-Equal 'GATE_GUT_COUNTS_LOAD_FAILURES' '0' ([string]$counts.load_failures)
$loadFailureLog = "ERROR: Failed to load script res://tests/unit/broken.gd`n" + $sampleLog
Assert-Equal 'GATE_GUT_COUNTS_LOAD_FAILURES' '1' ([string](Get-Phase2RGutCounts -LogText $loadFailureLog).load_failures)

## The trust run emitted 26 standalone suite lines for 24 distinct scripts, so deduping is a law and
## not a tidiness preference.
$executed = @(Get-Phase2RExecutedSuites -LogText $sampleLog)
Assert-Equal 'GATE_EXECUTED_SUITES_NOT_DEDUPED' '2' ([string]$executed.Count)
Assert-Equal 'GATE_EXECUTED_SUITES_NOT_SORTED' `
    'res://tests/unit/tooling/test_alpha.gd|res://tests/unit/tooling/test_beta.gd' ($executed -join '|')

## Only an exact standalone path line counts as evidence a suite ran. A path merely mentioned inside
## a sentence is not an execution record - that conflation is how 727051ca reported suites that
## never ran.
$noisyLog = "Loading res://tests/unit/tooling/test_gamma.gd now`nres://tests/unit/tooling/test_alpha.gd"
$noisy = @(Get-Phase2RExecutedSuites -LogText $noisyLog)
Assert-Equal 'GATE_EXECUTED_SUITES_ACCEPTS_EMBEDDED_PATH' '1' ([string]$noisy.Count)
## This line ends in .gd, so only the START anchor rejects it; the one above needed the end.
$leadingNoiseLog = "Loading res://tests/unit/tooling/test_delta.gd`nres://tests/unit/tooling/test_alpha.gd"
$leadingNoise = @(Get-Phase2RExecutedSuites -LogText $leadingNoiseLog)
Assert-Equal 'GATE_EXECUTED_SUITES_ACCEPTS_EMBEDDED_PATH' '1' ([string]$leadingNoise.Count)

# =================================================================================================
# Record-level laws that EvidenceValidator will enforce on the sealed gate. The runner must refuse
# before writing rather than emit a gate its own validator rejects.
# =================================================================================================

## The law commit 727051ca broke: a suite that never ran must never be reported.
Assert-Throws 'GATE_SUITE_NOT_EXECUTED_NOT_REFUSED' 'GATE_SUITE_NOT_EXECUTED' {
    Assert-Phase2RRecordConsistent -Record ([ordered]@{
        command_id = 'c'; tests = 1; passing = 1; failing = 0; pending = 0
        suites = @('res://tests/a.gd', 'res://tests/b.gd'); executed_suites = @('res://tests/a.gd')
        log_path = 'evidence/phase_2r/closeout/logs/c.log'
    })
}
Assert-Throws 'GATE_COUNTS_INCONSISTENT_NOT_REFUSED' 'GATE_COUNTS_INCONSISTENT' {
    Assert-Phase2RRecordConsistent -Record ([ordered]@{
        command_id = 'c'; tests = 5; passing = 1; failing = 0; pending = 0
        suites = @(); executed_suites = @()
        log_path = 'evidence/phase_2r/closeout/logs/c.log'
    })
}
Assert-Throws 'GATE_PATH_TRAVERSAL_NOT_REFUSED' 'GATE_PATH_TRAVERSAL' {
    Assert-Phase2RRecordConsistent -Record ([ordered]@{
        command_id = 'c'; tests = 0; passing = 0; failing = 0; pending = 0
        suites = @(); executed_suites = @()
        log_path = 'evidence/phase_2r/closeout/logs/../c.log'
    })
}

## A pending test is admissible only when a diagnostic classifies it. counts.pending > 0 with no
## "pending_test" diagnostic is exactly what EvidenceValidator rejects as CLOSEOUT_PENDING_UNDECLARED.
Assert-Throws 'GATE_PENDING_UNDECLARED_NOT_REFUSED' 'GATE_PENDING_UNDECLARED' {
    Assert-Phase2RPendingDeclared -Counts ([ordered]@{ pending = 1 }) -Diagnostics @()
}
Assert-Throws 'GATE_PENDING_UNDECLARED_NOT_REFUSED' 'GATE_PENDING_UNDECLARED' {
    Assert-Phase2RPendingDeclared -Counts ([ordered]@{ pending = 1 }) -Diagnostics @([ordered]@{ classification = 'gut_orphan_count' })
}

## GUT prints each [Pending] line twice - inline and in the run summary - and two pending tests
## may share one reason. diagnostics carries uniqueItems, so extraction deduplicates by detail;
## without it the sealed gate is schema-invalid on the repository's own known-green state.
$pendingLog = "* test_one`n    [Pending]:  reason alpha`n* test_two`n    [Pending]:  reason beta`nRun Summary`n    [Pending]:  reason alpha`n    [Pending]:  reason beta"
$pendingDiagnostics = @(Get-Phase2RPendingDiagnostics -CommandId 'c' -LogText $pendingLog -LogSha256 ('a' * 64))
Assert-Equal 'GATE_PENDING_DIAGNOSTICS_NOT_DEDUPED' '2' ([string]$pendingDiagnostics.Count)
Assert-Equal 'GATE_PENDING_DIAGNOSTICS_NOT_DEDUPED' 'reason alpha|reason beta' (@($pendingDiagnostics | ForEach-Object { [string]$_['detail'] }) -join '|')
Assert-Equal 'GATE_PENDING_DIAGNOSTICS_SHAPE' 'pending_test' ([string]$pendingDiagnostics[0]['classification'])

# =================================================================================================
# Step 4: the frozen command inventory, and Step 5: the frozen static scans.
# =================================================================================================

$expectedRequirements = @(Get-Phase2RExpectedRequirementIds -MetadataPath $metadataPath)
## Derived, never asserted from memory: the union of child_contracts[].expected_metadata
## .requirement_ids minus the deferred OYO obligations minus every req.ending.* id.
Assert-Equal 'GATE_EXPECTED_REQUIREMENT_COUNT' '72' ([string]$expectedRequirements.Count)

$inventory = @(Get-Phase2RCommandInventory)
Assert-True 'GATE_INVENTORY_EMPTY' ($inventory.Count -gt 0)

$commandIds = @($inventory | ForEach-Object { [string]$_.command_id })
Assert-Equal 'GATE_COMMAND_ID_DUPLICATE' ([string]$commandIds.Count) ([string](@($commandIds | Sort-Object -Unique).Count))
$logNames = @($inventory | ForEach-Object { [string]$_.log_name })
Assert-Equal 'GATE_LOG_NAME_DUPLICATE' ([string]$logNames.Count) ([string](@($logNames | Sort-Object -Unique).Count))

foreach ($record in $inventory) {
    if ([string]$record.command_id -notmatch '^[a-z0-9][a-z0-9-]*$') {
        Add-Failure 'GATE_COMMAND_ID_SHAPE' ([string]$record.command_id)
    }
    if ([string]$record.suite_id -notmatch '^[a-z0-9][a-z0-9_]*$') {
        Add-Failure 'GATE_SUITE_ID_SHAPE' ([string]$record.suite_id)
    }
    if ([string]$record.log_name -notmatch '^[A-Za-z0-9._-]+$') {
        Add-Failure 'GATE_LOG_NAME_SHAPE' ([string]$record.log_name)
    }
}

## Every fully satisfied Phase-2R requirement must be evidenced by at least one command, and no
## command may claim a requirement outside the derived set. Both directions are the law.
$covered = @($inventory | ForEach-Object { $_.requirement_ids } | Sort-Object -Unique)
$missing = @($expectedRequirements | Where-Object { $covered -notcontains $_ })
$extra = @($covered | Where-Object { $expectedRequirements -notcontains $_ })
Assert-True 'GATE_REQUIREMENT_UNCOVERED' ($missing.Count -eq 0) ($missing -join ',')
Assert-True 'GATE_REQUIREMENT_UNKNOWN' ($extra.Count -eq 0) ($extra -join ',')

$scans = @(Get-Phase2RStaticScans)
Assert-True 'GATE_STATIC_SCANS_EMPTY' ($scans.Count -gt 0)
$scanIds = @($scans | ForEach-Object { [string]$_.scan_id })
Assert-Equal 'GATE_STATIC_SCAN_ID_DUPLICATE' ([string]$scanIds.Count) ([string](@($scanIds | Sort-Object -Unique).Count))
foreach ($scan in $scans) {
    if ([string]$scan.scan_id -notmatch '^[a-z0-9][a-z0-9_]*$') {
        Add-Failure 'GATE_STATIC_SCAN_ID_SHAPE' ([string]$scan.scan_id)
    }
    if ($commandIds -notcontains [string]$scan.command_id) {
        Add-Failure 'GATE_STATIC_SCAN_COMMAND_UNBOUND' ([string]$scan.scan_id)
    }
}
## tools/testing/UnconditionalPassAudit.gd already owns this scan; the plan names it in Step 5.
Assert-True 'GATE_STATIC_SCAN_UNCONDITIONAL_PASS_MISSING' ($scanIds -contains 'unconditional_passes')

# =================================================================================================
# Preflight refusals. Nothing below reaches a command, a Godot process or a write.
# =================================================================================================

Assert-Throws 'GATE_OUTPUT_ROOT_NOT_EXACT_NOT_REFUSED' 'GATE_OUTPUT_ROOT_NOT_EXACT' {
    Invoke-Phase2RCloseoutGate -SubjectCommit ('0' * 40) -OutputDirectory 'evidence/phase_2r/elsewhere'
}
Assert-Throws 'GATE_OUTPUT_ROOT_NOT_EXACT_NOT_REFUSED' 'GATE_OUTPUT_ROOT_NOT_EXACT' {
    Invoke-Phase2RCloseoutGate -SubjectCommit ('0' * 40) -OutputDirectory 'evidence/phase_2r/closeout/logs'
}
foreach ($badSubject in @('', 'abc', ('A' * 40), ('0' * 39), ('0' * 41), ('g' * 40))) {
    $subjectUnderTest = $badSubject
    Assert-Throws 'GATE_SUBJECT_COMMIT_INVALID_NOT_REFUSED' 'GATE_SUBJECT_COMMIT_INVALID' {
        Invoke-Phase2RCloseoutGate -SubjectCommit $subjectUnderTest -OutputDirectory 'evidence/phase_2r/closeout'
    }
}

## The two root-dependent probes must never destroy committed evidence. A pre-existing EMPTY
## root can only be this fixture's own crashed remnant (the fixture only ever creates it empty)
## and is reclaimed; a pre-existing NONEMPTY root is the sealed Task-4 evidence, which this
## fixture must not touch - there the never-overwrite refusal is proven against the real root
## and the HEAD probe is skipped, because GATE_OUTPUT_ROOT_EXISTS precedes it by design.
$outputRoot = Join-Path $repositoryRoot 'evidence\phase_2r\closeout'
$outputRootPreexisted = Test-Path -LiteralPath $outputRoot
if ($outputRootPreexisted -and @(Get-ChildItem -Force -LiteralPath $outputRoot).Count -eq 0) {
    Remove-Item -LiteralPath $outputRoot -Recurse -Force -Confirm:$false
    $outputRootPreexisted = $false
}
if ($outputRootPreexisted) {
    Assert-Throws 'GATE_OUTPUT_ROOT_EXISTS_NOT_REFUSED' 'GATE_OUTPUT_ROOT_EXISTS' {
        Invoke-Phase2RCloseoutGate -SubjectCommit ('0' * 40) -OutputDirectory 'evidence/phase_2r/closeout'
    }
} else {
    ## A subject that is well formed but is not HEAD must be refused before any work begins;
    ## this probe needs the root absent or the EXISTS refusal fires first.
    Assert-Throws 'GATE_HEAD_NOT_SUBJECT_NOT_REFUSED' 'GATE_HEAD_NOT_SUBJECT' {
        Invoke-Phase2RCloseoutGate -SubjectCommit ('0' * 40) -OutputDirectory 'evidence/phase_2r/closeout'
    }
    ## An EMPTY directory is invisible to git, so creating and removing it leaves the worktree
    ## byte-identical; it is deleted in finally ONLY because this fixture created it.
    try {
        [void][IO.Directory]::CreateDirectory($outputRoot)
        Assert-Throws 'GATE_OUTPUT_ROOT_EXISTS_NOT_REFUSED' 'GATE_OUTPUT_ROOT_EXISTS' {
            Invoke-Phase2RCloseoutGate -SubjectCommit ('0' * 40) -OutputDirectory 'evidence/phase_2r/closeout'
        }
    } finally {
        if (Test-Path -LiteralPath $outputRoot) { Remove-Item -LiteralPath $outputRoot -Recurse -Force -Confirm:$false }
    }
    Assert-True 'GATE_OUTPUT_ROOT_LEAKED' (-not (Test-Path -LiteralPath $outputRoot))
}

## Cleanliness is a pure predicate over the exact bytes of `git status --porcelain`, so it is proven
## here without touching the real worktree at all.
Assert-Throws 'GATE_WORKTREE_NOT_CLEAN_NOT_REFUSED' 'GATE_WORKTREE_NOT_CLEAN' {
    Assert-Phase2RWorktreeClean -StatusText " M tools/evidence/run_phase2r_gate.ps1`n"
}
Assert-Throws 'GATE_WORKTREE_NOT_CLEAN_NOT_REFUSED' 'GATE_WORKTREE_NOT_CLEAN' {
    Assert-Phase2RWorktreeClean -StatusText "?? stray.txt`n"
}
try {
    Assert-Phase2RWorktreeClean -StatusText ''
} catch {
    Add-Failure 'GATE_WORKTREE_CLEAN_FALSE_POSITIVE' ([string]$_.Exception.Message)
}

# =================================================================================================
# Verdict.
# =================================================================================================

if ($failures.Count -ne 0) {
    foreach ($failure in $failures) { Write-Output ('RUN_PHASE2R_GATE_FAILURE ' + $failure) }
    throw ('RUN_PHASE2R_GATE: FAIL count=' + $failures.Count)
}
Write-Output 'RUN_PHASE2R_GATE: PASS'
