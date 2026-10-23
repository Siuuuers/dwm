[CmdletBinding()]
param(
    [string]$SubjectCommit = '',
    [string]$OutputDirectory = 'evidence/phase_2r/closeout',
    [switch]$StaticScans
)

# =================================================================================================
# The Plan-04 Task-3 Phase-2R closeout runner (dwm-p2r.10).
#
# tests/tooling/Test-RunPhase2RGate.ps1 is this runner's specification: it pins every production
# function name, the preflight refusal order, the canonical-JSON oracle and the Step-4/Step-5
# source-text mandates. The fixture dot-sources this file, so the entry point is guarded with
# $MyInvocation.InvocationName and every function below is the real production function.
#
# PREREQUISITE stays runner-internal by design: validate_phase2r_closeout_gate.gd deliberately
# exposes only the four post-creation inventory modes plus the two auxiliary modes, because
# PREREQUISITE runs while the output root does not yet exist, which only this runner can arrange.
# The runner therefore enforces the prerequisite Beads state natively over the fresh read-only
# snapshot, and the authoritative GDScript re-validation of everything it wrote happens in the one
# PRE_SEAL invocation this runner makes through the isolated wrapper. A native mistake cannot seal:
# the PRE_SEAL call fails closed on it.
#
# The canonical JSON emitted here must reproduce scripts/validation/CanonicalJsonWriter.gd byte for
# byte: compact separators, object keys sorted by UTF-8 BYTE order (PowerShell's default
# case-insensitive sort would order "a" before "Z" and silently invalidate every record hash), the
# seven named escapes, lowercase \u escapes below 0x20, every other codepoint literal, ints bare,
# one trailing LF per document. Floats are REFUSED: no gate member is a float, and emitting one
# would make the bytes engine-dependent.
#
# The Step-5 static scans are frozen here in two mechanical kinds. forbidden_pattern scans run a
# regex over the tracked tree with GDScript comments stripped line-by-line; required_guard scans
# assert the law's owning guard file exists and is executed by the bound command. Every pattern was
# calibrated against subject c4245a1da42684258edee07ca6fd0150188a4ca1 on 2026-08-26: each reports
# zero violations there. The patterns are line-based tripwires against reintroducing the named
# construct shapes; each law's primary enforcement remains its owning suite and gate.
#
# The happy path (Invoke-Phase2RCloseoutGate driving the whole frozen inventory) is Task-4 work and
# is never executed by the Task-3 fixture.
# =================================================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Phase2RUtf8Strict = New-Object Text.UTF8Encoding($false, $true)
$script:Phase2RUtf8NoBom = New-Object Text.UTF8Encoding($false)
$script:Phase2RRepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\', '/')

$script:Phase2RCloseoutRoot = 'evidence/phase_2r/closeout'
$script:Phase2RCloseoutLogs = 'evidence/phase_2r/closeout/logs'
$script:Phase2RMetadataRelative = 'prompt_docs/metadata/phase_2r_beads.v1.json'
$script:Phase2RRequirementIndexRelative = 'prompt_docs/INDEX.md'
$script:Phase2REvidenceJournalRelative = 'evidence/phase_2r/closeout/logs/isolated-godot.jsonl'
$script:Phase2RSnapshotExportRelative = '.godot/phase2r_logs/phase2r-closeout-beads.json'

## The four authority documents whose raw committed bytes the gate digests. The CLI re-derives
## every one of them with FileAccess.get_file_as_bytes, so these are raw-byte hashes, never the
## CRLF-normalized plan-suite hashes.
$script:Phase2RDigestDocuments = [ordered]@{
    authority = 'docs/design/2026-08-11-phase-2r-foundation-repair-current-authority.md'
    plan = 'docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-04-verification-closeout.md'
    requirement_index = 'prompt_docs/INDEX.md'
    design_authority_registry = 'prompt_docs/metadata/design_authority_registry.v1.json'
}

## Mirror of Phase2RCloseoutInventory.DEFERRED_REQUIREMENTS (Plan-04's four deferred obligations).
## The prefix rule below additionally removes every id beginning 'req.ending.', exactly as
## _expected_requirement_ids does; the derived set itself is never hardcoded anywhere in this file.
$script:Phase2RDeferredRequirementIds = @(
    'req.run.day7_terminal_intent', 'req.schedule.done_board_fate', 'req.schedule.warning_queue',
    'req.test.schedule_gate',
    'req.ending.epilogue', 'req.ending.ids', 'req.ending.playback', 'req.ending.primary',
    'req.run.day7_terminal'
)
$script:Phase2REndingPrefix = 'req.ending.'

## The two non-contract child classes, in Plan-04 Global-Constraints DECLARATION order. The ids
## arrays are deliberately not sorted; Phase2RCloseoutInventory compares them by exact equality.
$script:Phase2RHistoricalHelperIds = @('dwm-p2r.11', 'dwm-p2r.7.1')
$script:Phase2RExecutionRemediationIds = @(
    'dwm-p2r.17', 'dwm-p2r.18', 'dwm-p2r.19', 'dwm-p2r.20', 'dwm-p2r.21', 'dwm-p2r.22',
    'dwm-p2r.23', 'dwm-p2r.24', 'dwm-p2r.25', 'dwm-p2r.26', 'dwm-p2r.27', 'dwm-p2r.28',
    'dwm-p2r.29', 'dwm-p2r.30', 'dwm-p2r.31', 'dwm-p2r.32', 'dwm-p2r.33', 'dwm-p2r.34',
    'dwm-p2r.35', 'dwm-p2r.36', 'dwm-p2r.37', 'dwm-p2r.38'
)

## The eight sealed evidence documents whose source_bindings the gate walks and counts.
$script:Phase2RSourceBindingDocuments = @(
    'evidence/phase_2r/baseline.json',
    'evidence/phase_2r/contracts/desktop_contract.json',
    'evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json',
    'evidence/phase_2r/contracts/minesweeper_contract.json',
    'evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json',
    'evidence/phase_2r/handoff/desktop_contract.json',
    'evidence/phase_2r/handoff/minesweeper_contract.json',
    'evidence/phase_2r/schedule/gate.json'
)

# =================================================================================================
# Path and process primitives, reused from tools/evidence/capture_phase_2r_baseline.ps1.
# =================================================================================================

function Get-Phase2RCanonicalPath {
    param([string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-Phase2RStrictDescendant {
    param([string]$Root, [string]$Candidate)
    $rootFull = Get-Phase2RCanonicalPath $Root
    $candidateFull = Get-Phase2RCanonicalPath $Candidate
    return $candidateFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-Phase2RContainedNonReparseChain {
    param([string]$Root, [string]$Candidate, [switch]$RequireStrictDescendant)
    $rootFull = Get-Phase2RCanonicalPath $Root
    $candidateFull = Get-Phase2RCanonicalPath $Candidate
    $inside = $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or (Test-Phase2RStrictDescendant $rootFull $candidateFull)
    if (-not $inside -or ($RequireStrictDescendant -and $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase))) {
        throw ('GATE_PATH_CONTAINMENT: ' + $candidateFull)
    }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\', '/')
    $cursor = $rootFull
    $parts = if ($relative.Length -eq 0) { @() } else { @($relative -split '[\\/]') }
    foreach ($part in @('') + $parts) {
        if ($part.Length) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('GATE_PATH_REPARSE_POINT: ' + $cursor) }
        }
    }
    return $candidateFull
}

function New-Phase2RVerifiedDirectory {
    param([string]$Path)
    [void](Assert-Phase2RContainedNonReparseChain -Root $script:Phase2RRepositoryRoot -Candidate $Path)
    [void][IO.Directory]::CreateDirectory((Get-Phase2RCanonicalPath $Path))
    [void](Assert-Phase2RContainedNonReparseChain -Root $script:Phase2RRepositoryRoot -Candidate $Path)
}

function ConvertTo-Phase2RNativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes += 1; continue }
        if ($character -eq '"') { [void]$builder.Append(('\' * (($slashes * 2) + 1)) + '"'); $slashes = 0; continue }
        if ($slashes) { [void]$builder.Append('\' * $slashes); $slashes = 0 }
        [void]$builder.Append($character)
    }
    if ($slashes) { [void]$builder.Append('\' * ($slashes * 2)) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-Phase2RNativeBytes {
    param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = $script:Phase2RRepositoryRoot)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $FilePath
    $info.Arguments = [string]::Join(' ', @($Arguments | ForEach-Object { ConvertTo-Phase2RNativeArgument ([string]$_) }))
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    if (-not $process.Start()) { throw ('GATE_PROCESS_START_FAILED: ' + $FilePath) }
    $stdout = New-Object IO.MemoryStream
    $stderr = New-Object IO.MemoryStream
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
    $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
    $process.WaitForExit()
    [void]$stdoutTask.GetAwaiter().GetResult()
    [void]$stderrTask.GetAwaiter().GetResult()
    return [pscustomobject]@{
        argv = @($FilePath) + @($Arguments)
        exit_code = [int]$process.ExitCode
        stdout = $stdout.ToArray()
        stderr = $stderr.ToArray()
    }
}

function ConvertFrom-Phase2RStrictUtf8 {
    param([byte[]]$Bytes, [string]$Label)
    try { return $script:Phase2RUtf8Strict.GetString($Bytes) } catch { throw ('GATE_UTF8_INVALID: ' + $Label) }
}

## Godot log files are not reliably valid UTF-8. Command logs are hashed as raw bytes; only this
## lenient decoding is used to PARSE them, replacing invalid sequences and stripping NUL bytes.
function ConvertFrom-Phase2RLenientLogText {
    param([byte[]]$Bytes)
    return ([Text.Encoding]::UTF8.GetString($Bytes)) -replace "`0", ''
}

function Get-Phase2RPluginVersion {
    param([string]$RelativePath, [string]$Label)
    $bytes = [IO.File]::ReadAllBytes((Join-Path $script:Phase2RRepositoryRoot ($RelativePath -replace '/', '\')))
    $text = ConvertFrom-Phase2RStrictUtf8 -Bytes $bytes -Label $RelativePath
    $matched = @([regex]::Matches($text, '(?m)^version="([^"]+)"\s*$'))
    if ($matched.Count -ne 1) { throw ('GATE_PLUGIN_VERSION_INVALID: ' + $Label) }
    return $matched[0].Groups[1].Value
}

# =================================================================================================
# The canonical JSON writer. Byte-compatible with scripts/validation/CanonicalJsonWriter.gd, and
# proven so by the fixture against three committed documents that writer produced.
# =================================================================================================

function Get-Phase2RSha256Hex {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes) { throw 'GATE_SHA256_INPUT_NULL: Get-Phase2RSha256Hex requires bytes' }
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

## Keys sort by the byte order of their UTF-8 encoding. Each key is projected to a string holding
## one char per byte, and [StringComparer]::Ordinal over those projections is exactly byte order.
function Get-Phase2RUtf8SortedKeys {
    param([string[]]$Keys)
    $keyArray = [string[]]@($Keys)
    if ($keyArray.Length -le 1) { return $keyArray }
    $projections = New-Object string[] $keyArray.Length
    for ($index = 0; $index -lt $keyArray.Length; $index += 1) {
        $projections[$index] = -join ([char[]]$script:Phase2RUtf8NoBom.GetBytes($keyArray[$index]))
    }
    [Array]::Sort($projections, $keyArray, [StringComparer]::Ordinal)
    return $keyArray
}

function Write-Phase2RCanonicalString {
    param([string]$Value, [Text.StringBuilder]$Builder)
    [void]$Builder.Append('"')
    $index = 0
    while ($index -lt $Value.Length) {
        $character = $Value[$index]
        if ([char]::IsHighSurrogate($character)) {
            if ($index + 1 -ge $Value.Length -or -not [char]::IsLowSurrogate($Value[$index + 1])) {
                throw 'GATE_CANONICAL_UNSUPPORTED: lone surrogate code unit in string'
            }
            [void]$Builder.Append($character)
            [void]$Builder.Append($Value[$index + 1])
            $index += 2
            continue
        }
        if ([char]::IsLowSurrogate($character)) {
            throw 'GATE_CANONICAL_UNSUPPORTED: lone surrogate code unit in string'
        }
        $code = [int]$character
        switch ($code) {
            0x22 { [void]$Builder.Append('\"') }
            0x5C { [void]$Builder.Append('\\') }
            0x08 { [void]$Builder.Append('\b') }
            0x0C { [void]$Builder.Append('\f') }
            0x0A { [void]$Builder.Append('\n') }
            0x0D { [void]$Builder.Append('\r') }
            0x09 { [void]$Builder.Append('\t') }
            default {
                if ($code -lt 0x20) {
                    [void]$Builder.Append('\u' + $code.ToString('x4'))
                } else {
                    [void]$Builder.Append($character)
                }
            }
        }
        $index += 1
    }
    [void]$Builder.Append('"')
}

function Write-Phase2RCanonicalValue {
    param($Value, [Text.StringBuilder]$Builder)
    if ($null -eq $Value) { [void]$Builder.Append('null'); return }
    if ($Value -is [bool]) { [void]$Builder.Append($(if ($Value) { 'true' } else { 'false' })); return }
    if ($Value -is [string] -or $Value -is [char]) { Write-Phase2RCanonicalString -Value ([string]$Value) -Builder $Builder; return }
    if ($Value -is [sbyte] -or $Value -is [byte] -or $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64]) {
        [void]$Builder.Append(([IConvertible]$Value).ToString([Globalization.CultureInfo]::InvariantCulture))
        return
    }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        throw ('GATE_CANONICAL_UNSUPPORTED: floating-point value <' + $Value + '> has no engine-independent canonical form')
    }
    if ($Value -is [Collections.IDictionary]) {
        $keys = New-Object Collections.Generic.List[string]
        foreach ($key in $Value.Keys) {
            if ($key -isnot [string]) { throw 'GATE_CANONICAL_UNSUPPORTED: object keys must be strings' }
            $keys.Add([string]$key)
        }
        $sorted = Get-Phase2RUtf8SortedKeys -Keys $keys.ToArray()
        [void]$Builder.Append('{')
        $first = $true
        foreach ($key in $sorted) {
            if (-not $first) { [void]$Builder.Append(',') }
            $first = $false
            Write-Phase2RCanonicalString -Value $key -Builder $Builder
            [void]$Builder.Append(':')
            Write-Phase2RCanonicalValue -Value $Value[$key] -Builder $Builder
        }
        [void]$Builder.Append('}')
        return
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $keys = New-Object Collections.Generic.List[string]
        $lookup = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $keys.Add([string]$property.Name)
            $lookup[[string]$property.Name] = $property.Value
        }
        $sorted = Get-Phase2RUtf8SortedKeys -Keys $keys.ToArray()
        [void]$Builder.Append('{')
        $first = $true
        foreach ($key in $sorted) {
            if (-not $first) { [void]$Builder.Append(',') }
            $first = $false
            Write-Phase2RCanonicalString -Value $key -Builder $Builder
            [void]$Builder.Append(':')
            Write-Phase2RCanonicalValue -Value $lookup[$key] -Builder $Builder
        }
        [void]$Builder.Append('}')
        return
    }
    if ($Value -is [Collections.IEnumerable]) {
        [void]$Builder.Append('[')
        $first = $true
        foreach ($item in $Value) {
            if (-not $first) { [void]$Builder.Append(',') }
            $first = $false
            Write-Phase2RCanonicalValue -Value $item -Builder $Builder
        }
        [void]$Builder.Append(']')
        return
    }
    throw ('GATE_CANONICAL_UNSUPPORTED: Variant type ' + $Value.GetType().FullName + ' has no canonical form')
}

## Returns the canonical text WITHOUT the trailing LF; document writers append exactly one.
function ConvertTo-Phase2RCanonicalJson {
    param($Value)
    $builder = New-Object Text.StringBuilder
    Write-Phase2RCanonicalValue -Value $Value -Builder $builder
    return $builder.ToString()
}

## A command record's sha256 covers the canonical bytes of the record with sha256 REMOVED. Hashing
## a record that still carries a placeholder sha256 member is the obvious wrong implementation.
function Add-Phase2RRecordSha256 {
    param($Record)
    if ($Record -isnot [Collections.Specialized.OrderedDictionary]) {
        throw 'GATE_RECORD_INVALID: Add-Phase2RRecordSha256 requires an ordered dictionary record'
    }
    $bare = [ordered]@{}
    foreach ($key in $Record.Keys) {
        if ([string]$key -cne 'sha256') { $bare[$key] = $Record[$key] }
    }
    $digest = Get-Phase2RSha256Hex -Bytes ($script:Phase2RUtf8NoBom.GetBytes((ConvertTo-Phase2RCanonicalJson -Value $bare)))
    $sealed = [ordered]@{}
    foreach ($key in $bare.Keys) { $sealed[$key] = $bare[$key] }
    $sealed['sha256'] = $digest
    return $sealed
}

# =================================================================================================
# Path traversal. "." and ".." are built only from characters a legal component needs, so no
# character-class pattern can exclude them; components are the only level this settles at.
# =================================================================================================

function Test-Phase2RPathTraversal {
    param([AllowEmptyString()][string]$Path = '')
    foreach ($component in ($Path -split '[\\/]')) {
        if ($component -ceq '.' -or $component -ceq '..') { return $true }
    }
    return $false
}

# =================================================================================================
# GUT log parsing. Counts come from the final Totals block; an absent "Failing Tests" line reads
# as zero because GUT omits it on a clean run. Orphans are GUT-owned and never become a project
# count. Executed suites are the exact standalone res:// path lines, deduplicated and sorted -
# a path merely mentioned inside a sentence is not an execution record.
# =================================================================================================

function Get-Phase2RGutCounts {
    param([AllowEmptyString()][string]$LogText = '')
    $counts = [ordered]@{ scripts = 0; tests = 0; passing = 0; failing = 0; pending = 0; asserts = 0; load_failures = 0 }
    $labels = @(
        @('scripts', 'Scripts'), @('tests', 'Tests'), @('passing', 'Passing Tests'),
        @('failing', 'Failing Tests'), @('pending', 'Risky/Pending')
    )
    foreach ($pair in $labels) {
        $found = [regex]::Matches($LogText, '(?m)^' + [regex]::Escape($pair[1]) + '[ ]+([0-9]+)[ ]*\r?$')
        if ($found.Count -gt 0) { $counts[$pair[0]] = [int]$found[$found.Count - 1].Groups[1].Value }
    }
    ## GUT emits 'Asserts N/M' when asserts failed. Equal halves read as the count; unequal
    ## halves must refuse rather than let a plausible zero stand in for failed asserts.
    $assertsMatches = [regex]::Matches($LogText, '(?m)^Asserts[ ]+([0-9]+)(?:/([0-9]+))?[ ]*\r?$')
    if ($assertsMatches.Count -gt 0) {
        $lastAsserts = $assertsMatches[$assertsMatches.Count - 1]
        if ($lastAsserts.Groups[2].Success -and $lastAsserts.Groups[2].Value -cne $lastAsserts.Groups[1].Value) {
            throw ('GATE_COUNTS_INCONSISTENT: asserts line reports failed asserts <' + $lastAsserts.Value.Trim() + '>')
        }
        $counts['asserts'] = [int]$lastAsserts.Groups[1].Value
    }
    $counts['load_failures'] = ([regex]::Matches($LogText, 'ERROR: Failed to load script')).Count
    return $counts
}

function Get-Phase2RExecutedSuites {
    param([AllowEmptyString()][string]$LogText = '')
    $seen = New-Object Collections.Generic.HashSet[string]
    foreach ($line in ($LogText -split "`n")) {
        $trimmed = $line.TrimEnd("`r")
        if ($trimmed -cmatch '^res://tests/[A-Za-z0-9_./-]+\.gd$') { [void]$seen.Add($trimmed) }
    }
    $result = New-Object string[] $seen.Count
    $seen.CopyTo($result)
    [Array]::Sort($result, [StringComparer]::Ordinal)
    return $result
}

# =================================================================================================
# Record-level laws EvidenceValidator will enforce on the sealed gate. The runner refuses before
# writing rather than emit a gate its own validator rejects. The suites/executed_suites comparison
# is the law commit 727051ca broke: a suite that never ran must never be reported.
# =================================================================================================

function Assert-Phase2RRecordConsistent {
    param($Record)
    if ($null -eq $Record) { throw 'GATE_RECORD_INVALID: no record' }
    $commandId = [string]$Record['command_id']
    $logPath = [string]$Record['log_path']
    if (Test-Phase2RPathTraversal -Path $logPath) {
        throw ('GATE_PATH_TRAVERSAL: ' + $commandId + ' log_path <' + $logPath + '>')
    }
    $suites = @($Record['suites'])
    $executed = @($Record['executed_suites'])
    if ([string]::Join('|', $suites) -cne [string]::Join('|', $executed)) {
        throw ('GATE_SUITE_NOT_EXECUTED: ' + $commandId + ' requested <' + [string]::Join(',', $suites) + '> executed <' + [string]::Join(',', $executed) + '>')
    }
    if (([int]$Record['passing'] + [int]$Record['failing'] + [int]$Record['pending']) -ne [int]$Record['tests']) {
        throw ('GATE_COUNTS_INCONSISTENT: ' + $commandId)
    }
}

## counts.pending > 0 is admissible only when a diagnostic classifies a pending test; anything else
## is exactly what EvidenceValidator rejects as CLOSEOUT_PENDING_UNDECLARED.
function Assert-Phase2RPendingDeclared {
    param($Counts, $Diagnostics)
    $pending = 0
    if ($null -ne $Counts -and $Counts -is [Collections.IDictionary] -and $Counts.Contains('pending')) {
        $pending = [int]$Counts['pending']
    }
    if ($pending -le 0) { return }
    foreach ($diagnostic in @($Diagnostics)) {
        if ($null -eq $diagnostic) { continue }
        if ([string]$diagnostic['classification'] -ceq 'pending_test') { return }
    }
    throw ('GATE_PENDING_UNDECLARED: ' + $pending + ' pending test(s) with no pending_test diagnostic')
}

## GUT prints every pending test's [Pending] line twice - inline and again in the run summary -
## and two pending tests may share one reason string. The gate schema declares diagnostics with
## uniqueItems, so extraction deduplicates by detail; without this the sealed gate is
## schema-invalid on the repository's own known-green state (one pending symlink test).
function Get-Phase2RPendingDiagnostics {
    param([string]$CommandId, [AllowEmptyString()][string]$LogText = '', [string]$LogSha256)
    $seen = New-Object Collections.Generic.HashSet[string]
    $records = New-Object Collections.Generic.List[object]
    foreach ($pendingMatch in [regex]::Matches($LogText, '(?m)^\s*\[Pending\]:\s*(.+?)\r?$')) {
        $detail = $pendingMatch.Groups[1].Value.Trim()
        if (-not $seen.Add($detail)) { continue }
        $records.Add([ordered]@{
            command_id = $CommandId
            classification = 'pending_test'
            detail = $detail
            log_sha256 = $LogSha256
        })
    }
    return $records.ToArray()
}

# =================================================================================================
# The expected requirement set. DERIVED from the metadata exactly as
# Phase2RCloseoutInventory._expected_requirement_ids derives it - the union of every contract's
# child_contracts[].expected_metadata.requirement_ids, minus the deferred obligations, minus every
# id beginning with the req.ending. prefix, sorted. Never hardcoded: a hardcoded copy would drift
# silently and produce a gate PRE_SEAL rejects.
# =================================================================================================

function Get-Phase2RExpectedRequirementIds {
    param([AllowEmptyString()][string]$MetadataPath = '')
    if ([string]::IsNullOrEmpty($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        throw ('GATE_METADATA_MISSING: <' + $MetadataPath + '>')
    }
    $metadataText = ConvertFrom-Phase2RStrictUtf8 -Bytes ([IO.File]::ReadAllBytes($MetadataPath)) -Label $MetadataPath
    $metadata = ConvertFrom-Json -InputObject $metadataText
    $deferred = @{}
    foreach ($deferredId in $script:Phase2RDeferredRequirementIds) { $deferred[$deferredId] = $true }
    $union = @{}
    foreach ($contract in @($metadata.child_contracts)) {
        foreach ($requirementId in @($contract.expected_metadata.requirement_ids)) {
            $id = [string]$requirementId
            if ($deferred.ContainsKey($id) -or $id.StartsWith($script:Phase2REndingPrefix)) { continue }
            $union[$id] = $true
        }
    }
    $ids = New-Object string[] $union.Keys.Count
    $union.Keys.CopyTo($ids, 0)
    [Array]::Sort($ids, [StringComparer]::Ordinal)
    return $ids
}

## Selects a subset of the derived pool by prefix and by exact id. Every exact id is validated
## against the pool, so a literal that drifts out of the metadata refuses instead of silently
## claiming a requirement outside the derived set.
function Select-Phase2RRequirementSubset {
    param([string[]]$Pool, [string[]]$Prefixes = @(), [string[]]$Exact = @())
    foreach ($exactId in $Exact) {
        if ($Pool -cnotcontains $exactId) { throw ('GATE_REQUIREMENT_UNKNOWN: ' + $exactId) }
    }
    $selected = New-Object Collections.Generic.List[string]
    foreach ($id in $Pool) {
        $take = $false
        foreach ($prefix in $Prefixes) {
            if ($id.StartsWith($prefix)) { $take = $true; break }
        }
        if (-not $take -and $Exact -ccontains $id) { $take = $true }
        if ($take) { $selected.Add($id) }
    }
    return ([string[]]$selected.ToArray())
}

# =================================================================================================
# Step 4: the frozen command inventory.
#
# Every command declares the requirement ids it evidences. The specific gates claim their own
# subsets; the complete-GUT command claims the remainder, so the union equals the derived set
# exactly BY CONSTRUCTION in both directions - and Select-Phase2RRequirementSubset still refuses
# any literal outside the derived set. Suite lists are the frozen gate compositions: the Schedule
# foundation gate from the sealed schedule/gate.json commands[], the desktop amendment gate and
# dialogic gate from their authoring plans' committed argv, the handoff gate from Plan-04 Task 2.
#
# tools/beads/Sync-Phase2RMetadata.ps1 is MANDATORY here: without it, dwm-p2r.9's ten stale
# evidence links pinning 1abf65999f60e7fb would reach Task 4 unchallenged.
# =================================================================================================

$script:Phase2RScheduleFoundationSuites = @(
    'res://tests/unit/test_schedule_action_registry.gd',
    'res://tests/unit/tooling/test_schedule_action_manifest.gd',
    'res://tests/unit/test_schedule_strict_validation.gd',
    'res://tests/unit/test_schedule_source_receipts.gd',
    'res://tests/unit/test_schedule_state_schema.gd',
    'res://tests/unit/test_schedule_foundation_publication_ledger.gd',
    'res://tests/unit/test_game_state_schedule_commit_port.gd',
    'res://tests/unit/test_day_resolution_start_port.gd',
    'res://tests/unit/test_day7_schedule_provenance.gd',
    'res://tests/unit/test_hospital_rules.gd',
    'res://tests/unit/test_run_snapshot_schema.gd',
    'res://tests/unit/test_save_migrations.gd',
    'res://tests/integration/test_schedule_publication_restart.gd',
    'res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd',
    'res://tests/integration/test_committed_schedule_day_resolution.gd',
    'res://tests/integration/test_committed_schedule_effect_order.gd',
    'res://tests/scenario/test_hospital_invitation_closures.gd',
    'res://tests/scenario/test_hospital_twofriends_order.gd',
    'res://tests/scenario/test_day7_schedule_provenance.gd',
    'res://tests/unit/tooling/test_public_surface_inventory.gd'
)

$script:Phase2RDesktopAmendmentSuites = @(
    'res://tests/unit/test_desktop_contracts.gd',
    'res://tests/unit/test_desktop_identity_nonce_issuer.gd',
    'res://tests/unit/test_desktop_issuer_root_store.gd',
    'res://tests/unit/test_causal_day_advance_identity_port.gd',
    'res://tests/unit/test_desktop_continuation_operation_journal.gd',
    'res://tests/unit/test_desktop_publication_ledger.gd',
    'res://tests/unit/tooling/test_desktop_identity_issuer_boundary.gd',
    'res://tests/unit/test_minesweeper_capabilities.gd',
    'res://tests/unit/test_deterministic_rng32.gd',
    'res://tests/unit/test_minesweeper_board_schema.gd',
    'res://tests/unit/test_minesweeper_no_guess_verifier.gd',
    'res://tests/unit/test_minesweeper_generator_kernel.gd',
    'res://tests/unit/test_minesweeper_board_generator.gd',
    'res://tests/unit/test_desktop_board_state.gd',
    'res://tests/unit/test_minesweeper_round_coordinator.gd',
    'res://tests/unit/test_desktop_consequence_state.gd',
    'res://tests/unit/test_desktop_causal_sequence_port.gd',
    'res://tests/unit/test_application_mutation_gate.gd',
    'res://tests/unit/test_run_snapshot_schema.gd',
    'res://tests/unit/test_save_document_schema.gd',
    'res://tests/unit/test_save_migrations.gd',
    'res://tests/unit/test_desktop_identity_allocation_restore_participant.gd',
    'res://tests/unit/test_desktop_continuation_remapper.gd',
    'res://tests/unit/test_desktop_first_reveal_snapshot_composer.gd',
    'res://tests/unit/test_logout_coordinator.gd',
    'res://tests/unit/test_desktop_action_receipt.gd',
    'res://tests/unit/test_minesweeper_shop_purchase_participant.gd',
    'res://tests/unit/test_desktop_board_fate_port.gd',
    'res://tests/unit/test_desktop_consequence_coordinator.gd',
    'res://tests/unit/test_desktop_accessibility_contract.gd',
    'res://tests/unit/tooling/test_minesweeper_generator_artifacts.gd',
    'res://tests/unit/tooling/test_desktop_amendment_evidence.gd',
    'res://tests/integration/test_minesweeper_first_reveal_transaction.gd',
    'res://tests/integration/test_desktop_board_persistence.gd',
    'res://tests/integration/test_minesweeper_shop_transaction.gd',
    'res://tests/integration/test_desktop_completion_transaction.gd',
    'res://tests/integration/test_shop_condition_contract_departure.gd',
    'res://tests/integration/test_desktop_action_matrix.gd',
    'res://tests/integration/test_desktop_bootstrap_wiring.gd',
    'res://tests/integration/test_desktop_crash_recovery.gd',
    'res://tests/integration/test_desktop_simulator_authority.gd'
)

$script:Phase2RDialogicGateSuites = @(
    'res://tests/unit/test_timeline_manifest.gd',
    'res://tests/unit/test_dialogic_runtime_adapter.gd',
    'res://tests/unit/test_narrative_checkpoint_schema.gd',
    'res://tests/unit/test_save_manager_narrative_checkpoint_port.gd',
    'res://tests/unit/test_dialogic_ending_playback_port.gd',
    'res://tests/unit/test_effect_resolver.gd',
    'res://tests/unit/test_effect_transactions.gd',
    'res://tests/unit/test_run_snapshot_schema.gd',
    'res://tests/unit/test_save_document_schema.gd',
    'res://tests/unit/test_save_migrations.gd',
    'res://tests/unit/test_skip_policy.gd',
    'res://tests/unit/test_input_accessibility.gd',
    'res://tests/unit/tooling/test_no_unconditional_pass.gd',
    'res://tests/unit/tooling/test_dialogic_gate_summary.gd',
    'res://tests/integration/test_dialogic_restore.gd',
    'res://tests/integration/test_narrative_checkpoint_wiring.gd',
    'res://tests/integration/test_ending_dialogic_wiring.gd',
    'res://tests/integration/test_restore_production_adapters.gd',
    'res://tests/integration/test_dialogic_effect_boundary.gd',
    'res://tests/integration/test_dialogic_skip.gd',
    'res://tests/integration/test_dialogic_bridge_contract.gd',
    'res://tests/integration/test_restore_transaction.gd'
)

$script:Phase2RHandoffGateSuites = @(
    'res://tests/integration/test_phase2r_schedule_desktop_handoff.gd',
    'res://tests/integration/test_desktop_bootstrap_wiring.gd',
    'res://tests/integration/test_committed_schedule_day_resolution.gd'
)

function Get-Phase2RCommandInventory {
    $metadataPath = Join-Path $script:Phase2RRepositoryRoot ($script:Phase2RMetadataRelative -replace '/', '\')
    $pool = @(Get-Phase2RExpectedRequirementIds -MetadataPath $metadataPath)
    $snapshotFlag = '--beads-snapshot=res://evidence/phase_2r/closeout/preclose_beads_snapshot.json'
    $metadataText = ConvertFrom-Phase2RStrictUtf8 -Bytes ([IO.File]::ReadAllBytes($metadataPath)) -Label $script:Phase2RMetadataRelative
    $contractIds = @((ConvertFrom-Json -InputObject $metadataText).child_contracts | ForEach-Object { [string]$_.issue_id })
    $gutEntry = 'res://addons/gut/gut_cmdln.gd'
    $entries = New-Object Collections.Generic.List[object]

    $entries.Add([ordered]@{
        command_id = 'closeout-import'; suite_id = 'closeout_import'; log_name = 'closeout-import.log'
        kind = 'godot'; tool = ''; arguments = @('--editor', '--quit-after', '1')
        requirement_ids = @()
    })
    $fullGut = [ordered]@{
        command_id = 'closeout-full-gut'; suite_id = 'closeout_full_gut'; log_name = 'closeout-full-gut.log'
        kind = 'gut'; tool = ''; arguments = @('-s', $gutEntry, '-gdir=res://tests', '-ginclude_subdirs', '-gexit')
        requirement_ids = @()
    }
    $entries.Add($fullGut)
    $entries.Add([ordered]@{
        command_id = 'closeout-tooling-gut'; suite_id = 'closeout_tooling_gut'; log_name = 'closeout-tooling-gut.log'
        kind = 'gut'; tool = ''; arguments = @('-s', $gutEntry, '-gdir=res://tests/unit/tooling', '-gexit')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Exact @('req.test.phase2r_gate'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-schedule-foundation-gate'; suite_id = 'closeout_schedule_foundation_gate'; log_name = 'closeout-schedule-foundation-gate.log'
        kind = 'gut'; tool = ''; arguments = @('-s', $gutEntry, ('-gtest=' + [string]::Join(',', $script:Phase2RScheduleFoundationSuites)), '-gexit')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Prefixes @('req.schedule.') -Exact @(
            'req.flow.hospital_order', 'req.save.schedule_state', 'req.save.schedule_migration',
            'req.test.schedule_foundation_gate'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-desktop-amendment-gate'; suite_id = 'closeout_desktop_amendment_gate'; log_name = 'closeout-desktop-amendment-gate.log'
        kind = 'gut'; tool = ''; arguments = @('-s', $gutEntry, ('-gtest=' + [string]::Join(',', $script:Phase2RDesktopAmendmentSuites)), '-gexit')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Prefixes @('req.desktop.', 'req.minesweeper.', 'req.shop.') -Exact @(
            'req.save.desktop_board_continuity', 'req.test.desktop_amendment_gate'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-dialogic-gate'; suite_id = 'closeout_dialogic_gate'; log_name = 'closeout-dialogic-gate.log'
        kind = 'gut'; tool = ''; arguments = @('-s', $gutEntry, ('-gtest=' + [string]::Join(',', $script:Phase2RDialogicGateSuites)), '-gexit')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Prefixes @('req.dialogic.') -Exact @(
            'req.locale.narrative_deferred', 'req.test.dialogic_fixture'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-handoff-gate'; suite_id = 'closeout_handoff_gate'; log_name = 'closeout-handoff-gate.log'
        kind = 'gut'; tool = ''; arguments = @('-s', $gutEntry, ('-gtest=' + [string]::Join(',', $script:Phase2RHandoffGateSuites)), '-gexit')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Exact @(
            'req.runtime.schedule_ownership', 'req.schedule.done_commit', 'req.schedule.day7_provenance',
            'req.run.day_resolution_plan', 'req.save.schedule_state', 'req.save.desktop_board_continuity',
            'req.desktop.cross_app_actions', 'req.minesweeper.causal_departure', 'req.minesweeper.phase_boundary',
            'req.test.schedule_foundation_gate', 'req.test.desktop_amendment_gate'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-docs-gate'; suite_id = 'closeout_docs_gate'; log_name = 'closeout-docs-gate.log'
        kind = 'godot'; tool = ''; arguments = @('-s', 'res://tools/docs/validate_docs.gd', '--', $snapshotFlag)
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Prefixes @('req.docs.'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-agent-workflow'; suite_id = 'closeout_agent_workflow'; log_name = 'closeout-agent-workflow.log'
        kind = 'godot'; tool = ''; arguments = @('-s', 'res://tools/docs/validate_agent_workflow.gd', '--', $snapshotFlag)
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Prefixes @('req.beads.'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-dialogic-manifests'; suite_id = 'closeout_dialogic_manifests'; log_name = 'closeout-dialogic-manifests.log'
        kind = 'godot'; tool = ''; arguments = @('-s', 'res://tools/dialogic/validate_manifests.gd')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Exact @('req.dialogic.manifest'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-config-validate'; suite_id = 'closeout_config_validate'; log_name = 'closeout-config-validate.log'
        kind = 'godot'; tool = ''; arguments = @('-s', 'res://tools/config/validate_project_config.gd')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Exact @('req.config.version'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-schedule-actions'; suite_id = 'closeout_schedule_actions'; log_name = 'closeout-schedule-actions.log'
        kind = 'godot'; tool = ''; arguments = @('-s', 'res://tools/schedule/validate_schedule_actions.gd')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Exact @('req.schedule.action_registry', 'req.schedule.validation'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-desktop-contract'; suite_id = 'closeout_desktop_contract'; log_name = 'closeout-desktop-contract.log'
        kind = 'godot'; tool = ''; arguments = @('-s', 'res://tools/evidence/validate_desktop_contract.gd')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-minesweeper-contract'; suite_id = 'closeout_minesweeper_contract'; log_name = 'closeout-minesweeper-contract.log'
        kind = 'godot'; tool = ''; arguments = @('-s', 'res://tools/evidence/validate_minesweeper_contract.gd')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-isolation-fixture'; suite_id = 'closeout_isolation_fixture'; log_name = 'closeout-isolation-fixture.log'
        kind = 'native'; tool = 'powershell'; arguments = @('tests/tooling/Test-InvokeIsolatedGodot.ps1')
        requirement_ids = @(Select-Phase2RRequirementSubset -Pool $pool -Exact @('req.test.isolation'))
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-preservation-boundary'; suite_id = 'closeout_preservation_boundary'; log_name = 'closeout-preservation-boundary.log'
        kind = 'native'; tool = 'powershell'; arguments = @('tools/evidence/Assert-Phase2rPreservationBoundary.ps1')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-metadata-sync'; suite_id = 'closeout_metadata_sync'; log_name = 'closeout-metadata-sync.log'
        kind = 'native'; tool = 'powershell'; arguments = @('tools/beads/Sync-Phase2RMetadata.ps1')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-beads-dep-cycles'; suite_id = 'closeout_beads_dep_cycles'; log_name = 'closeout-beads-dep-cycles.log'
        kind = 'native'; tool = 'bd'; arguments = @('dep', 'cycles', '--json', '--readonly')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-beads-lint'; suite_id = 'closeout_beads_lint'; log_name = 'closeout-beads-lint.log'
        kind = 'native'; tool = 'bd'; arguments = @('lint', 'dwm-p2r') + $contractIds + @('--status', 'all', '--json', '--readonly')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-beads-orphans'; suite_id = 'closeout_beads_orphans'; log_name = 'closeout-beads-orphans.log'
        kind = 'native'; tool = 'bd'; arguments = @('orphans', '--json', '--readonly')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-git-diff-check'; suite_id = 'closeout_git_diff_check'; log_name = 'closeout-git-diff-check.log'
        kind = 'native'; tool = 'git'; arguments = @('diff', '--check')
        requirement_ids = @()
    })
    $entries.Add([ordered]@{
        command_id = 'closeout-static-scans'; suite_id = 'closeout_static_scans'; log_name = 'closeout-static-scans.log'
        kind = 'native'; tool = 'powershell'; arguments = @('tools/evidence/run_phase2r_gate.ps1', '-StaticScans')
        requirement_ids = @()
    })

    ## The remainder rule: every derived requirement not claimed by a specific gate above is
    ## evidenced by the complete GUT run, which executes every suite in the repository.
    $claimed = @{}
    foreach ($entry in $entries) {
        foreach ($id in @($entry['requirement_ids'])) { $claimed[[string]$id] = $true }
    }
    $remainder = New-Object Collections.Generic.List[string]
    foreach ($id in $pool) {
        if (-not $claimed.ContainsKey($id)) { $remainder.Add($id) }
    }
    $fullGut['requirement_ids'] = [string[]]$remainder.ToArray()
    return $entries.ToArray()
}

# =================================================================================================
# Step 5: the frozen static scans.
#
# forbidden_pattern scans sweep the tracked tree (git ls-files) with GDScript comments stripped
# from each line before matching, so a law named in prose cannot trip its own scan.
# required_guard scans pin an existing law-owning suite: the guard files must exist and the bound
# command must actually execute them. Both kinds are mechanical; neither trusts a green suite.
# =================================================================================================

function Get-Phase2RStaticScans {
    return @(
        [ordered]@{
            scan_id = 'unconditional_passes'; command_id = 'closeout-tooling-gut'; kind = 'required_guard'
            description = 'No test may pass unconditionally; tools/testing/UnconditionalPassAudit.gd owns the audit and its tooling suite executes it.'
            pattern = ''; pathspecs = @()
            guards = @('tools/testing/UnconditionalPassAudit.gd', 'tests/unit/tooling/test_no_unconditional_pass.gd')
        },
        [ordered]@{
            scan_id = 'test_production_user_dir'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'Non-tooling tests must not resolve the production user data directory; the isolated wrapper owns user:// isolation.'
            pattern = 'OS\.get_user_data_dir'
            pathspecs = @('tests/', ':(exclude)tests/unit/tooling'); guards = @()
        },
        [ordered]@{
            scan_id = 'unclassified_diagnostics'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'Every pending() must carry a reason string; a bare pending() is an unclassifiable diagnostic.'
            pattern = '(^|[^A-Za-z0-9_.])pending\(\s*\)'
            pathspecs = @('tests/'); guards = @()
        },
        [ordered]@{
            scan_id = 'duplicate_identity_owners'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'No second construction of the identity issuer, issuer root store, causal sequence port, or admission checkpoint port outside autoload/ApplicationBootstrap.gd.'
            pattern = '(DesktopIdentityNonceIssuer|DesktopIssuerRootStore|DesktopCausalSequencePort|SaveManagerMinesweeperPort|SaveManagerCheckpointPort)\.new\('
            pathspecs = @('scripts/', 'autoload/', ':(exclude)autoload/ApplicationBootstrap.gd'); guards = @()
        },
        [ordered]@{
            scan_id = 'canonical_identity_minting'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'Domain code must not mint identity from wall time, global RNG, or instance ids; DeterministicRng32 is the sole random source and is exempt as the replacement itself.'
            pattern = '(^|[^A-Za-z0-9_])(randi_range|randf_range|randfn|randomize|randi|randf)\(|Time\.get_|get_instance_id\(|RandomNumberGenerator\.new\('
            pathspecs = @('scripts/domain/', ':(exclude)scripts/domain/minesweeper/DeterministicRng32.gd'); guards = @()
        },
        [ordered]@{
            scan_id = 'caller_supplied_route_effect_cost'; command_id = 'closeout-schedule-foundation-gate'; kind = 'required_guard'
            description = 'Routes, effects and costs come only from the frozen v1 manifest; the strict-validation and source-receipt suites own the law.'
            pattern = ''; pathspecs = @()
            guards = @('tests/unit/test_schedule_strict_validation.gd', 'tests/unit/test_schedule_source_receipts.gd')
        },
        [ordered]@{
            scan_id = 'direct_domain_bag_mutation'; command_id = 'closeout-desktop-amendment-gate'; kind = 'required_guard'
            description = 'Domain state mutates only through the application mutation gate; its suite owns the law.'
            pattern = ''; pathspecs = @()
            guards = @('tests/unit/test_application_mutation_gate.gd')
        },
        [ordered]@{
            scan_id = 'schedule_migration_receipts'; command_id = 'closeout-schedule-foundation-gate'; kind = 'required_guard'
            description = 'Schedule migrations are receipt-carrying or empty; the save-migrations suite owns the law.'
            pattern = ''; pathspecs = @()
            guards = @('tests/unit/test_save_migrations.gd')
        },
        [ordered]@{
            scan_id = 'synthetic_empty_day_resolution'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'No production or autoload site may construct an empty synthetic day-resolution plan.'
            pattern = 'DayResolutionPlan\.new\(\s*\)'
            pathspecs = @('scripts/', 'autoload/'); guards = @()
        },
        [ordered]@{
            scan_id = 'minesweeper_lifetime_save_lock'; command_id = 'closeout-desktop-amendment-gate'; kind = 'required_guard'
            description = 'The Minesweeper save lock is round-scoped, never lifetime; the round coordinator suite owns acquire/release pairing.'
            pattern = ''; pathspecs = @()
            guards = @('tests/unit/test_minesweeper_round_coordinator.gd')
        },
        [ordered]@{
            scan_id = 'whole_pre_board_rollback'; command_id = 'closeout-desktop-amendment-gate'; kind = 'required_guard'
            description = 'Crash recovery is forward-only; the crash-recovery suite rejects whole-pre-board rollback.'
            pattern = ''; pathspecs = @()
            guards = @('tests/integration/test_desktop_crash_recovery.gd')
        },
        [ordered]@{
            scan_id = 'player_facing_simulation_authority'; command_id = 'closeout-desktop-amendment-gate'; kind = 'required_guard'
            description = 'No player-facing simulator replaces the production authority; the simulator-authority suite owns the law.'
            pattern = ''; pathspecs = @()
            guards = @('tests/integration/test_desktop_simulator_authority.gd')
        },
        [ordered]@{
            scan_id = 'oyo3_schedule_view_owner'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'No OYO3 ScheduleView, warning, or Done facade owner may exist inside the Phase-2R subject.'
            pattern = 'class_name (ScheduleView|ScheduleWarning|ScheduleDoneFacade)'
            pathspecs = @('scripts/', 'autoload/', 'scenes/'); guards = @()
        },
        [ordered]@{
            scan_id = 'relationship_witness_application'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'No relationship-witness application surface may exist inside the Phase-2R subject.'
            pattern = 'RelationshipWitness'
            pathspecs = @('scripts/', 'autoload/'); guards = @()
        },
        [ordered]@{
            scan_id = 'final_ending_claim'; command_id = 'closeout-static-scans'; kind = 'forbidden_pattern'
            description = 'No final ending plan or selection claim may exist; the 13-ID final plan belongs to dwm-oyo.6.'
            pattern = 'FinalEndingPlan|select_final_ending|final_ending_plan'
            pathspecs = @('scripts/', 'autoload/'); guards = @()
        }
    )
}

## Strips a GDScript line comment so a pattern named in prose cannot trip its own scan. A '#'
## inside a string literal is rare in this tree and stripping it can only make scans laxer for
## that one line, never produce a false violation.
function Get-Phase2RScanVisibleLine {
    param([AllowEmptyString()][string]$Line = '')
    $hashIndex = $Line.IndexOf('#')
    if ($hashIndex -lt 0) { return $Line }
    return $Line.Substring(0, $hashIndex)
}

function Invoke-Phase2RStaticScanSweep {
    $scans = @(Get-Phase2RStaticScans)
    $inventory = @(Get-Phase2RCommandInventory)
    $inventoryById = @{}
    foreach ($entry in $inventory) { $inventoryById[[string]$entry['command_id']] = $entry }
    $results = New-Object Collections.Generic.List[object]
    foreach ($scan in $scans) {
        $scanId = [string]$scan['scan_id']
        $violations = New-Object Collections.Generic.List[string]
        if ([string]$scan['kind'] -ceq 'forbidden_pattern') {
            $expression = New-Object Text.RegularExpressions.Regex ([string]$scan['pattern'])
            $listing = Invoke-Phase2RNativeBytes -FilePath 'git' -Arguments (@('ls-files', '--') + @($scan['pathspecs']))
            if ($listing.exit_code -ne 0) { throw ('GATE_STATIC_SCAN_VIOLATIONS: ' + $scanId + ' git ls-files failed') }
            $files = @(((ConvertFrom-Phase2RStrictUtf8 -Bytes $listing.stdout -Label ('ls-files ' + $scanId)) -split "`n") | Where-Object { $_.Trim().Length -gt 0 })
            foreach ($relative in $files) {
                $full = Join-Path $script:Phase2RRepositoryRoot ($relative.Trim() -replace '/', '\')
                if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
                $text = ConvertFrom-Phase2RLenientLogText -Bytes ([IO.File]::ReadAllBytes($full))
                $lineNumber = 0
                foreach ($line in ($text -split "`n")) {
                    $lineNumber += 1
                    $visible = Get-Phase2RScanVisibleLine -Line ($line.TrimEnd("`r"))
                    if ($expression.IsMatch($visible)) {
                        $violations.Add($relative.Trim() + ':' + $lineNumber + ': ' + $visible.Trim())
                    }
                }
            }
        } else {
            $boundCommand = $null
            if ($inventoryById.ContainsKey([string]$scan['command_id'])) { $boundCommand = $inventoryById[[string]$scan['command_id']] }
            if ($null -eq $boundCommand) {
                $violations.Add('bound command absent from the inventory: ' + [string]$scan['command_id'])
            }
            foreach ($guard in @($scan['guards'])) {
                $guardRelative = [string]$guard
                $guardFull = Join-Path $script:Phase2RRepositoryRoot ($guardRelative -replace '/', '\')
                if (-not (Test-Path -LiteralPath $guardFull -PathType Leaf)) {
                    $violations.Add('guard file missing: ' + $guardRelative)
                    continue
                }
                if ($guardRelative.EndsWith('.gd') -and $guardRelative.StartsWith('tests/') -and $null -ne $boundCommand) {
                    $resourcePath = 'res://' + $guardRelative
                    $covered = $false
                    foreach ($argument in @($boundCommand['arguments'])) {
                        $argumentText = [string]$argument
                        if ($argumentText.StartsWith('-gtest=') -and (@(($argumentText.Substring(7)) -split ',') -ccontains $resourcePath)) { $covered = $true }
                        if ($argumentText.StartsWith('-gdir=')) {
                            $directory = $argumentText.Substring(6).TrimEnd('/')
                            if ($resourcePath.StartsWith($directory + '/')) {
                                $relativeToDirectory = $resourcePath.Substring($directory.Length + 1)
                                $recursive = @($boundCommand['arguments']) -ccontains '-ginclude_subdirs'
                                if ($recursive -or -not $relativeToDirectory.Contains('/')) { $covered = $true }
                            }
                        }
                    }
                    if (-not $covered) { $violations.Add('guard suite not executed by ' + [string]$scan['command_id'] + ': ' + $guardRelative) }
                }
            }
        }
        $results.Add([ordered]@{ scan_id = $scanId; violations = [string[]]$violations.ToArray() })
    }
    return $results.ToArray()
}

# =================================================================================================
# Worktree cleanliness: a pure predicate over the exact bytes of `git status --porcelain`.
# =================================================================================================

function Assert-Phase2RWorktreeClean {
    param([AllowEmptyString()][string]$StatusText = '')
    if ($null -ne $StatusText -and $StatusText.Trim().Length -ne 0) {
        $firstLine = @($StatusText -split "`n")[0].TrimEnd("`r")
        throw ('GATE_WORKTREE_NOT_CLEAN: ' + $firstLine)
    }
}

# =================================================================================================
# Isolated Godot execution, reusing the proven EncodedCommand child shape from
# capture_phase_2r_baseline.ps1. Every Godot process goes through the isolated wrapper.
# =================================================================================================

function ConvertFrom-Phase2RHelperRecord {
    param([string]$Json)
    $expected = @('suite_id', 'argv', 'exit_code', 'log_path', 'test_root', 'user_dir', 'started_at_utc', 'ended_at_utc')
    $keys = @([regex]::Matches($Json, '"((?:\\.|[^"\\])*)"\s*:') | ForEach-Object { ConvertFrom-Json ('"' + $_.Groups[1].Value + '"') })
    if ($keys.Count -ne $expected.Count -or [string]::Join("`n", $keys) -cne [string]::Join("`n", $expected)) {
        throw 'GATE_HELPER_RECORD_KEYS_OR_DUPLICATES'
    }
    $parsed = ConvertFrom-Phase2RStrictJson -Json $Json -Label 'isolated helper record'
    if ($null -eq $parsed.argv -or $parsed.argv -isnot [array]) { throw 'GATE_HELPER_RECORD_ARGV_INVALID' }
    return $parsed
}

function Invoke-Phase2RIsolatedCapture {
    param([string]$SuiteId, [string]$LogName, [string[]]$GodotArgs, [string]$EvidenceLogPath = '')
    $helper = Join-Path $script:Phase2RRepositoryRoot 'tools\testing\Invoke-IsolatedGodot.ps1'
    $hostPath = (Get-Process -Id $PID).Path
    $literal = { param([string]$value) return "'" + $value.Replace("'", "''") + "'" }
    $argumentLiterals = @($GodotArgs | ForEach-Object { & $literal ([string]$_) })
    $clause = ''
    if (-not [string]::IsNullOrWhiteSpace($EvidenceLogPath)) { $clause = ' -EvidenceLogPath ' + (& $literal $EvidenceLogPath) }
    $command = "& $(& $literal $helper) -SuiteId $(& $literal $SuiteId) -LogName $(& $literal $LogName) -GodotArgs @($($argumentLiterals -join ','))$clause; exit `$LASTEXITCODE"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $result = Invoke-Phase2RNativeBytes -FilePath $hostPath -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded)
    $record = ConvertFrom-Phase2RHelperRecord -Json ((ConvertFrom-Phase2RStrictUtf8 -Bytes $result.stdout -Label ('helper ' + $SuiteId)).Trim())
    if ([int]$record.exit_code -ne [int]$result.exit_code) { throw ('GATE_COMMAND_FAILED: HELPER_EXIT_DISAGREEMENT ' + $SuiteId) }
    if ([int]$result.exit_code -in @(124, 125, 126)) {
        throw ('GATE_COMMAND_FAILED: isolation, evidence, or suite-execution guard tripped for ' + $SuiteId + ' exit=' + $result.exit_code)
    }
    return $record
}

# =================================================================================================
# Atomic canonical document writes. Refuses to overwrite anything, writes to a contained temporary
# path, promotes with a rename, and returns the exact bytes written.
# =================================================================================================

function Write-Phase2RNewCanonicalDocument {
    param([string]$RelativePath, $Value)
    $full = Get-Phase2RCanonicalPath (Join-Path $script:Phase2RRepositoryRoot ($RelativePath -replace '/', '\'))
    if (Test-Path -LiteralPath $full) { throw ('GATE_OUTPUT_EXISTS: ' + $RelativePath) }
    New-Phase2RVerifiedDirectory -Path (Split-Path -Parent $full)
    $temporary = $full + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [void](Assert-Phase2RContainedNonReparseChain -Root $script:Phase2RRepositoryRoot -Candidate $temporary -RequireStrictDescendant)
    $bytes = $script:Phase2RUtf8NoBom.GetBytes((ConvertTo-Phase2RCanonicalJson -Value $Value) + "`n")
    [IO.File]::WriteAllBytes($temporary, $bytes)
    if (Test-Path -LiteralPath $full) { throw ('GATE_OUTPUT_PROMOTION_RACE: ' + $RelativePath) }
    [IO.File]::Move($temporary, $full)
    return , $bytes
}

function Write-Phase2RNewRawBytes {
    param([string]$RelativePath, [byte[]]$Bytes)
    $full = Get-Phase2RCanonicalPath (Join-Path $script:Phase2RRepositoryRoot ($RelativePath -replace '/', '\'))
    if (Test-Path -LiteralPath $full) { throw ('GATE_OUTPUT_EXISTS: ' + $RelativePath) }
    New-Phase2RVerifiedDirectory -Path (Split-Path -Parent $full)
    $temporary = $full + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [void](Assert-Phase2RContainedNonReparseChain -Root $script:Phase2RRepositoryRoot -Candidate $temporary -RequireStrictDescendant)
    [IO.File]::WriteAllBytes($temporary, $Bytes)
    if (Test-Path -LiteralPath $full) { throw ('GATE_OUTPUT_PROMOTION_RACE: ' + $RelativePath) }
    [IO.File]::Move($temporary, $full)
}

# =================================================================================================
# Inventory-level laws, refused before any command runs.
# =================================================================================================

function Assert-Phase2RInventoryValid {
    param([object[]]$Inventory, [string[]]$ExpectedRequirementIds)
    if (@($Inventory).Count -eq 0) { throw 'GATE_INVENTORY_EMPTY' }
    $commandIds = @{}
    $logNames = @{}
    $claimed = @{}
    $namesMetadataSync = $false
    foreach ($entry in $Inventory) {
        $commandId = [string]$entry['command_id']
        $suiteId = [string]$entry['suite_id']
        $logName = [string]$entry['log_name']
        if ($commandId -cnotmatch '^[a-z0-9][a-z0-9-]*$') { throw ('GATE_COMMAND_ID_SHAPE: ' + $commandId) }
        if ($suiteId -cnotmatch '^[a-z0-9][a-z0-9_]*$') { throw ('GATE_SUITE_ID_SHAPE: ' + $suiteId) }
        if ($logName -cnotmatch '^[A-Za-z0-9._-]+$') { throw ('GATE_LOG_NAME_SHAPE: ' + $logName) }
        if ($commandIds.ContainsKey($commandId)) { throw ('GATE_COMMAND_ID_DUPLICATE: ' + $commandId) }
        $commandIds[$commandId] = $true
        if ($logNames.ContainsKey($logName)) { throw ('GATE_LOG_NAME_DUPLICATE: ' + $logName) }
        $logNames[$logName] = $true
        foreach ($id in @($entry['requirement_ids'])) {
            $requirementId = [string]$id
            if ($ExpectedRequirementIds -cnotcontains $requirementId) { throw ('GATE_REQUIREMENT_UNKNOWN: ' + $requirementId) }
            $claimed[$requirementId] = $true
        }
        foreach ($argument in @($entry['arguments'])) {
            if (([string]$argument).Contains('Sync-Phase2RMetadata.ps1')) { $namesMetadataSync = $true }
        }
    }
    foreach ($id in $ExpectedRequirementIds) {
        if (-not $claimed.ContainsKey($id)) { throw ('GATE_REQUIREMENT_UNCOVERED: ' + $id) }
    }
    if (-not $namesMetadataSync) { throw 'GATE_INVENTORY_OMITS_METADATA_SYNC' }
    $scanIds = @{}
    foreach ($scan in @(Get-Phase2RStaticScans)) {
        $scanId = [string]$scan['scan_id']
        if ($scanId -cnotmatch '^[a-z0-9][a-z0-9_]*$') { throw ('GATE_STATIC_SCAN_ID_SHAPE: ' + $scanId) }
        if ($scanIds.ContainsKey($scanId)) { throw ('GATE_STATIC_SCAN_ID_DUPLICATE: ' + $scanId) }
        $scanIds[$scanId] = $true
        if (-not $commandIds.ContainsKey([string]$scan['command_id'])) {
            throw ('GATE_STATIC_SCAN_COMMAND_UNBOUND: ' + $scanId)
        }
    }
    if (-not $scanIds.ContainsKey('unconditional_passes')) { throw 'GATE_STATIC_SCAN_UNCONDITIONAL_PASS_MISSING' }
}

# =================================================================================================
# Source-binding scans: walk each sealed document for source_bindings arrays and count the
# distinct bound paths observed.
# =================================================================================================

function Get-Phase2RBoundPathsRecursive {
    param($Value, [Collections.Generic.HashSet[string]]$Collected)
    if ($Value -is [Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ([string]$property.Name -ceq 'source_bindings' -and $property.Value -is [Collections.IEnumerable]) {
                foreach ($binding in @($property.Value)) {
                    if ($binding -is [Management.Automation.PSCustomObject]) {
                        $pathProperty = $binding.PSObject.Properties['path']
                        if ($null -ne $pathProperty) { [void]$Collected.Add([string]$pathProperty.Value) }
                    }
                }
            }
            Get-Phase2RBoundPathsRecursive -Value $property.Value -Collected $Collected
        }
        return
    }
    if ($Value -is [string]) { return }
    if ($Value -is [Collections.IEnumerable]) {
        foreach ($item in $Value) { Get-Phase2RBoundPathsRecursive -Value $item -Collected $Collected }
    }
}

function Get-Phase2RSourceBindingScans {
    $records = New-Object Collections.Generic.List[object]
    foreach ($relative in $script:Phase2RSourceBindingDocuments) {
        $full = Join-Path $script:Phase2RRepositoryRoot ($relative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw ('GATE_SOURCE_BINDING_DOCUMENT_MISSING: ' + $relative) }
        $bytes = [IO.File]::ReadAllBytes($full)
        $document = ConvertFrom-Json -InputObject (ConvertFrom-Phase2RStrictUtf8 -Bytes $bytes -Label $relative)
        $collected = New-Object Collections.Generic.HashSet[string]
        Get-Phase2RBoundPathsRecursive -Value $document -Collected $collected
        $records.Add([ordered]@{
            document_path = $relative
            document_sha256 = Get-Phase2RSha256Hex -Bytes $bytes
            bound_path_count = [int]$collected.Count
        })
    }
    return $records.ToArray()
}

# =================================================================================================
# The gate itself. Preflight refusals come in the fixture-pinned order; nothing below a refusal
# reaches a command, a Godot process, or a write. The happy path is Task-4 work.
# =================================================================================================

function Get-Phase2RGutDirSuites {
    param([string]$ResourceDirectory, [bool]$Recurse)
    $relative = $ResourceDirectory -replace '^res://', ''
    $full = Join-Path $script:Phase2RRepositoryRoot ($relative -replace '/', '\')
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw ('GATE_SUITE_DIRECTORY_MISSING: ' + $ResourceDirectory) }
    $files = if ($Recurse) {
        @(Get-ChildItem -LiteralPath $full -Recurse -File -Filter 'test_*.gd')
    } else {
        @(Get-ChildItem -LiteralPath $full -File -Filter 'test_*.gd')
    }
    $paths = @($files | ForEach-Object {
        $relativePath = $_.FullName.Substring($script:Phase2RRepositoryRoot.Length).TrimStart('\', '/')
        'res://' + ($relativePath -replace '\\', '/')
    })
    $sorted = [string[]]$paths
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return $sorted
}

function Get-Phase2RRequestedSuites {
    param($Entry)
    if ([string]$Entry['kind'] -cne 'gut') { return ([string[]]@()) }
    foreach ($argument in @($Entry['arguments'])) {
        $argumentText = [string]$argument
        if ($argumentText.StartsWith('-gtest=')) {
            $suites = [string[]]@(($argumentText.Substring(7)) -split ',')
            [Array]::Sort($suites, [StringComparer]::Ordinal)
            return $suites
        }
        if ($argumentText.StartsWith('-gdir=')) {
            $recursive = @($Entry['arguments']) -ccontains '-ginclude_subdirs'
            return (Get-Phase2RGutDirSuites -ResourceDirectory ($argumentText.Substring(6)) -Recurse $recursive)
        }
    }
    return ([string[]]@())
}

function Invoke-Phase2RCloseoutGate {
    param([AllowEmptyString()][string]$SubjectCommit = '', [AllowEmptyString()][string]$OutputDirectory = '')

    ## Preflight 1: the output root is exact. Refusing a wrong root before anything else means the
    ## runner can never create, inspect, or delete a path it was not built for.
    if ($OutputDirectory -cne $script:Phase2RCloseoutRoot) {
        throw ('GATE_OUTPUT_ROOT_NOT_EXACT: <' + $OutputDirectory + '> is not ' + $script:Phase2RCloseoutRoot)
    }
    ## Preflight 2: the subject is a full lowercase 40-hex commit.
    if ($SubjectCommit -cnotmatch '^[0-9a-f]{40}$') {
        throw ('GATE_SUBJECT_COMMIT_INVALID: <' + $SubjectCommit + '>')
    }
    ## Preflight 3: the resolved repository root is a Godot repository and the worktree toplevel.
    ## The git dir of a linked worktree lives OUTSIDE the worktree root, so the worktree-correct
    ## invariant is `git rev-parse --show-toplevel` equality, never git-dir containment.
    if (-not (Test-Path -LiteralPath (Join-Path $script:Phase2RRepositoryRoot 'project.godot') -PathType Leaf)) {
        throw ('GATE_REPOSITORY_INVALID: no project.godot at ' + $script:Phase2RRepositoryRoot)
    }
    $toplevelResult = Invoke-Phase2RNativeBytes -FilePath 'git' -Arguments @('rev-parse', '--show-toplevel')
    if ($toplevelResult.exit_code -ne 0) { throw 'GATE_REPOSITORY_INVALID: git rev-parse --show-toplevel failed' }
    $toplevel = Get-Phase2RCanonicalPath ((ConvertFrom-Phase2RStrictUtf8 -Bytes $toplevelResult.stdout -Label 'git toplevel').Trim() -replace '/', '\')
    if (-not $toplevel.Equals($script:Phase2RRepositoryRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw ('GATE_REPOSITORY_INVALID: worktree toplevel ' + $toplevel + ' is not ' + $script:Phase2RRepositoryRoot)
    }
    ## Preflight 4: never overwrite an existing output root, checked before HEAD or cleanliness so
    ## the refusal is deterministic whatever state the worktree is in.
    $outputRoot = Get-Phase2RCanonicalPath (Join-Path $script:Phase2RRepositoryRoot ($OutputDirectory -replace '/', '\'))
    if (Test-Path -LiteralPath $outputRoot) {
        throw ('GATE_OUTPUT_ROOT_EXISTS: ' + $OutputDirectory + ' already exists; remove it under separate authority and rerun from a clean subject')
    }
    ## Preflight 5: HEAD is exactly the subject.
    $headResult = Invoke-Phase2RNativeBytes -FilePath 'git' -Arguments @('rev-parse', 'HEAD')
    if ($headResult.exit_code -ne 0) { throw 'GATE_REPOSITORY_INVALID: git rev-parse HEAD failed' }
    $head = (ConvertFrom-Phase2RStrictUtf8 -Bytes $headResult.stdout -Label 'git HEAD').Trim()
    if ($head -cne $SubjectCommit) {
        throw ('GATE_HEAD_NOT_SUBJECT: HEAD is ' + $head + ', subject is ' + $SubjectCommit)
    }
    ## Preflight 6: the worktree is clean.
    $statusResult = Invoke-Phase2RNativeBytes -FilePath 'git' -Arguments @('status', '--porcelain')
    if ($statusResult.exit_code -ne 0) { throw 'GATE_REPOSITORY_INVALID: git status --porcelain failed' }
    $statusText = ConvertFrom-Phase2RStrictUtf8 -Bytes $statusResult.stdout -Label 'git status'
    Assert-Phase2RWorktreeClean -StatusText $statusText
    $statusHash = Get-Phase2RSha256Hex -Bytes $statusResult.stdout

    $treeResult = Invoke-Phase2RNativeBytes -FilePath 'git' -Arguments @('rev-parse', 'HEAD^{tree}')
    if ($treeResult.exit_code -ne 0) { throw 'GATE_REPOSITORY_INVALID: git rev-parse HEAD^{tree} failed' }
    $treeHash = (ConvertFrom-Phase2RStrictUtf8 -Bytes $treeResult.stdout -Label 'git tree').Trim()

    ## The frozen inventory and its laws, refused before any command runs.
    $metadataPath = Join-Path $script:Phase2RRepositoryRoot ($script:Phase2RMetadataRelative -replace '/', '\')
    $expectedRequirements = @(Get-Phase2RExpectedRequirementIds -MetadataPath $metadataPath)
    $inventory = @(Get-Phase2RCommandInventory)
    Assert-Phase2RInventoryValid -Inventory $inventory -ExpectedRequirementIds $expectedRequirements

    ## Fresh read-only Beads snapshot, exported before the output root exists.
    $hostPath = (Get-Process -Id $PID).Path
    $exportScript = Join-Path $script:Phase2RRepositoryRoot 'tools\beads\Export-BeadsSnapshot.ps1'
    $exportRelative = $script:Phase2RSnapshotExportRelative
    $exportFull = Join-Path $script:Phase2RRepositoryRoot ($exportRelative -replace '/', '\')
    if (Test-Path -LiteralPath $exportFull) { Remove-Item -LiteralPath $exportFull -Force -Confirm:$false }
    $exportResult = Invoke-Phase2RNativeBytes -FilePath $hostPath -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $exportScript, '-OutputPath', $exportRelative)
    if ($exportResult.exit_code -ne 0) { throw ('GATE_PREREQUISITE_STATE: Beads snapshot export failed exit=' + $exportResult.exit_code) }
    $snapshotBytes = [IO.File]::ReadAllBytes($exportFull)
    $snapshot = ConvertFrom-Json -InputObject (ConvertFrom-Phase2RStrictUtf8 -Bytes $snapshotBytes -Label 'beads snapshot')

    ## Native PREREQUISITE checks over the snapshot. The GDScript PREREQUISITE seam is deliberately
    ## unreachable from the CLI, and the one PRE_SEAL invocation below re-validates all of this
    ## authoritatively, so a native mistake here cannot seal anything.
    $issuesById = @{}
    foreach ($issue in @($snapshot)) { $issuesById[[string]$issue.id] = $issue }
    $metadataText = ConvertFrom-Phase2RStrictUtf8 -Bytes ([IO.File]::ReadAllBytes($metadataPath)) -Label $script:Phase2RMetadataRelative
    $contracts = @((ConvertFrom-Json -InputObject $metadataText).child_contracts)
    foreach ($contract in $contracts) {
        $contractId = [string]$contract.issue_id
        if (-not $issuesById.ContainsKey($contractId)) { throw ('GATE_PREREQUISITE_STATE: contract record absent from snapshot: ' + $contractId) }
        $status = [string]$issuesById[$contractId].status
        if ($contractId -ceq 'dwm-p2r.10') {
            if ($status -cne 'open') { throw ('GATE_PREREQUISITE_STATE: dwm-p2r.10 must be open, found ' + $status) }
        } elseif ($status -cne 'closed') {
            throw ('GATE_PREREQUISITE_STATE: contract ' + $contractId + ' must be closed, found ' + $status)
        }
    }
    foreach ($member in ($script:Phase2RHistoricalHelperIds + $script:Phase2RExecutionRemediationIds)) {
        if (-not $issuesById.ContainsKey($member)) { throw ('GATE_PREREQUISITE_STATE: non-contract child absent from snapshot: ' + $member) }
        if ([string]$issuesById[$member].status -cne 'closed') { throw ('GATE_PREREQUISITE_STATE: non-contract child ' + $member + ' is not closed') }
    }
    $closeoutIssue = $issuesById['dwm-p2r.10']
    $notesProperty = $closeoutIssue.PSObject.Properties['notes']
    if ($null -ne $notesProperty -and ([string]$notesProperty.Value).Contains('PHASE2R_CLOSEOUT_EVIDENCE_V1')) {
        throw 'GATE_PREREQUISITE_STATE: dwm-p2r.10 already carries a closeout evidence attachment'
    }

    ## Create the output root and copy the snapshot bytes verbatim.
    New-Phase2RVerifiedDirectory -Path $outputRoot
    New-Phase2RVerifiedDirectory -Path (Join-Path $outputRoot 'logs')
    Write-Phase2RNewRawBytes -RelativePath ($script:Phase2RCloseoutRoot + '/preclose_beads_snapshot.json') -Bytes $snapshotBytes
    $precloseSnapshotSha256 = Get-Phase2RSha256Hex -Bytes $snapshotBytes

    ## contract_inventory.json: the natively derived child/evidence inventory the gate hashes.
    $inventoryContracts = New-Object Collections.Generic.List[object]
    foreach ($contract in $contracts) {
        $contractId = [string]$contract.issue_id
        $inventoryContracts.Add([ordered]@{
            issue_id = $contractId
            expected_spec_id = [string]$contract.expected_spec_id
            status = [string]$issuesById[$contractId].status
            requirement_ids = @($contract.expected_metadata.requirement_ids | ForEach-Object { [string]$_ })
        })
    }
    $nonContractChildren = [ordered]@{
        historical_helpers = [ordered]@{
            count = @($script:Phase2RHistoricalHelperIds).Count
            ids = @($script:Phase2RHistoricalHelperIds)
        }
        execution_remediation_children = [ordered]@{
            count = @($script:Phase2RExecutionRemediationIds).Count
            ids = @($script:Phase2RExecutionRemediationIds)
        }
    }
    $contractInventoryBytes = Write-Phase2RNewCanonicalDocument -RelativePath ($script:Phase2RCloseoutRoot + '/contract_inventory.json') -Value ([ordered]@{
        schema_version = 1
        kind = 'phase2r_closeout_contract_inventory'
        epic_id = 'dwm-p2r'
        closeout_issue_id = 'dwm-p2r.10'
        child_contracts = $inventoryContracts.ToArray()
        non_contract_children = $nonContractChildren
        expected_requirement_ids = $expectedRequirements
    })

    ## Run every command in the frozen inventory.
    $records = New-Object Collections.Generic.List[object]
    $diagnostics = New-Object Collections.Generic.List[object]
    $recordsById = @{}
    $logHashesByName = @{}
    foreach ($entry in $inventory) {
        $commandId = [string]$entry['command_id']
        $logName = [string]$entry['log_name']
        $logRelative = $script:Phase2RCloseoutLogs + '/' + $logName
        $argv = @()
        $exitCode = 0
        $logBytes = $null
        if ([string]$entry['kind'] -cin @('gut', 'godot')) {
            $helperRecord = Invoke-Phase2RIsolatedCapture -SuiteId ([string]$entry['suite_id']) -LogName $logName -GodotArgs ([string[]]@($entry['arguments'])) -EvidenceLogPath $script:Phase2REvidenceJournalRelative
            $argv = @($helperRecord.argv | ForEach-Object { [string]$_ })
            $exitCode = [int]$helperRecord.exit_code
            $logBytes = [IO.File]::ReadAllBytes([string]$helperRecord.log_path)
        } else {
            $filePath = ''
            $arguments = @()
            switch ([string]$entry['tool']) {
                'powershell' {
                    $filePath = $hostPath
                    $scriptRelative = [string]@($entry['arguments'])[0]
                    $scriptFull = Join-Path $script:Phase2RRepositoryRoot ($scriptRelative -replace '/', '\')
                    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptFull) + @(@($entry['arguments']) | Select-Object -Skip 1 | ForEach-Object { [string]$_ })
                }
                'bd' { $filePath = 'bd'; $arguments = @(@($entry['arguments']) | ForEach-Object { [string]$_ }) }
                'git' { $filePath = 'git'; $arguments = @(@($entry['arguments']) | ForEach-Object { [string]$_ }) }
                default { throw ('GATE_COMMAND_FAILED: unknown native tool for ' + $commandId) }
            }
            $nativeResult = Invoke-Phase2RNativeBytes -FilePath $filePath -Arguments ([string[]]$arguments)
            $argv = @($nativeResult.argv | ForEach-Object { [string]$_ })
            $exitCode = [int]$nativeResult.exit_code
            $logBytes = $nativeResult.stdout + $nativeResult.stderr
            if ($nativeResult.stderr.Length -gt 0) {
                $stderrText = (ConvertFrom-Phase2RLenientLogText -Bytes $nativeResult.stderr).Trim()
                if ($stderrText.Length -gt 0) {
                    $diagnostics.Add([ordered]@{
                        command_id = $commandId
                        classification = 'external_tool_notice'
                        detail = @($stderrText -split "`n")[0].TrimEnd("`r")
                        log_sha256 = Get-Phase2RSha256Hex -Bytes $logBytes
                    })
                }
            }
        }
        if ($exitCode -ne 0) { throw ('GATE_COMMAND_FAILED: ' + $commandId + ' exit=' + $exitCode) }
        Write-Phase2RNewRawBytes -RelativePath $logRelative -Bytes $logBytes
        $logSha256 = Get-Phase2RSha256Hex -Bytes $logBytes
        $logText = ConvertFrom-Phase2RLenientLogText -Bytes $logBytes
        $counts = Get-Phase2RGutCounts -LogText $logText
        $suites = @()
        $executedSuites = @()
        if ([string]$entry['kind'] -ceq 'gut') {
            $suites = @(Get-Phase2RRequestedSuites -Entry $entry)
            $executedSuites = @(Get-Phase2RExecutedSuites -LogText $logText)
            $orphanMatches = [regex]::Matches($logText, '(?m)^Orphans[ ]+([0-9]+)[ ]*\r?$')
            if ($orphanMatches.Count -gt 0) {
                $diagnostics.Add([ordered]@{
                    command_id = $commandId
                    classification = 'gut_orphan_count'
                    detail = 'orphans=' + $orphanMatches[$orphanMatches.Count - 1].Groups[1].Value
                    log_sha256 = $logSha256
                })
            }
            foreach ($pendingDiagnostic in @(Get-Phase2RPendingDiagnostics -CommandId $commandId -LogText $logText -LogSha256 $logSha256)) {
                $diagnostics.Add($pendingDiagnostic)
            }
        } else {
            ## Non-GUT records carry zero counts by law, but a Godot tool log that reports a
            ## script load failure must refuse rather than have the marker zeroed away.
            if ([string]$entry['kind'] -ceq 'godot' -and [int]$counts['load_failures'] -ne 0) {
                throw ('GATE_COMMAND_FAILED: ' + $commandId + ' tool log carries a script load failure')
            }
            $counts = [ordered]@{ scripts = 0; tests = 0; passing = 0; failing = 0; pending = 0; asserts = 0; load_failures = 0 }
        }
        if ([int]$counts['failing'] -ne 0 -or [int]$counts['load_failures'] -ne 0) {
            throw ('GATE_COMMAND_FAILED: ' + $commandId + ' failing=' + $counts['failing'] + ' load_failures=' + $counts['load_failures'])
        }
        $record = [ordered]@{
            command_id = $commandId
            suite_id = [string]$entry['suite_id']
            argv = $argv
            exit_code = $exitCode
            log_name = $logName
            log_path = $logRelative
            log_sha256 = $logSha256
            scripts = [int]$counts['scripts']
            suites = $suites
            executed_suites = $executedSuites
            tests = [int]$counts['tests']
            passing = [int]$counts['passing']
            failing = [int]$counts['failing']
            pending = [int]$counts['pending']
            asserts = [int]$counts['asserts']
            load_failures = [int]$counts['load_failures']
        }
        Assert-Phase2RRecordConsistent -Record $record
        $sealed = Add-Phase2RRecordSha256 -Record $record
        $records.Add($sealed)
        $recordsById[$commandId] = $sealed
        $logHashesByName[$logRelative] = $logSha256
        ## Plan-04 Global Constraint: before Beads mutation only the closeout root may become
        ## dirty. Checked after every command so a command that dirties the tree - an editor
        ## import regenerating uncommitted .uid files, a tool writing outside the root - fails
        ## fast with attribution instead of surfacing hours later at the evidence-commit law.
        $postStatus = Invoke-Phase2RNativeBytes -FilePath 'git' -Arguments @('status', '--porcelain')
        if ($postStatus.exit_code -ne 0) { throw 'GATE_REPOSITORY_INVALID: git status --porcelain failed' }
        foreach ($statusLine in ((ConvertFrom-Phase2RStrictUtf8 -Bytes $postStatus.stdout -Label 'git status') -split "`n")) {
            $trimmedLine = $statusLine.TrimEnd("`r")
            if ($trimmedLine.Trim().Length -eq 0) { continue }
            $dirtyPath = $trimmedLine.Substring(3).Trim('"')
            if (-not $dirtyPath.StartsWith($script:Phase2RCloseoutRoot + '/')) {
                throw ('GATE_WORKTREE_NOT_CLEAN: ' + $commandId + ' dirtied <' + $trimmedLine + '>')
            }
        }
    }

    ## Summed counts, with the pending allowance declared or refused.
    $totals = [ordered]@{ scripts = 0; tests = 0; passing = 0; failing = 0; pending = 0; asserts = 0; load_failures = 0 }
    foreach ($sealedRecord in $records) {
        foreach ($key in @('scripts', 'tests', 'passing', 'failing', 'pending', 'asserts', 'load_failures')) {
            $totals[$key] = [int]$totals[$key] + [int]$sealedRecord[$key]
        }
    }
    Assert-Phase2RPendingDeclared -Counts $totals -Diagnostics $diagnostics.ToArray()

    ## Requirement mapping: invert the inventory's declarations over the sealed records.
    $requirementEvidence = [ordered]@{}
    foreach ($requirementId in $expectedRequirements) {
        $bindings = New-Object Collections.Generic.List[object]
        foreach ($entry in $inventory) {
            if (@($entry['requirement_ids']) -ccontains $requirementId) {
                $sealedRecord = $recordsById[[string]$entry['command_id']]
                $bindings.Add([ordered]@{
                    command_id = [string]$sealedRecord['command_id']
                    command_record_sha256 = [string]$sealedRecord['sha256']
                    log_path = [string]$sealedRecord['log_path']
                    log_sha256 = [string]$sealedRecord['log_sha256']
                })
            }
        }
        if ($bindings.Count -eq 0) { throw ('GATE_REQUIREMENT_UNCOVERED: ' + $requirementId) }
        ## Both consumers order these records by ordinal comparison of command_id|log_path;
        ## Sort-Object's linguistic comparison can disagree on hyphenated ids, and the
        ## parallel-array [Array]::Sort(keys, items, comparer) overload leaves the items
        ## array unsorted under Windows PowerShell 5.1, so order the records through an
        ## ordinal SortedDictionary instead.
        $sortedBindings = New-Object 'Collections.Generic.SortedDictionary[string,object]' ([StringComparer]::Ordinal)
        foreach ($binding in $bindings) {
            $bindingKey = [string]$binding['command_id'] + '|' + [string]$binding['log_path']
            if ($sortedBindings.ContainsKey($bindingKey)) { throw ('GATE_REQUIREMENT_RECORD_DUPLICATE: ' + $requirementId + ' ' + $bindingKey) }
            $sortedBindings.Add($bindingKey, $binding)
        }
        $requirementEvidence[$requirementId] = @($sortedBindings.Values)
    }

    ## Beads results from the three read-only commands' own logs.
    $beadsResults = [ordered]@{}
    foreach ($pair in @(@('dep_cycles', 'closeout-beads-dep-cycles'), @('lint', 'closeout-beads-lint'), @('orphans', 'closeout-beads-orphans'))) {
        $sealedRecord = $recordsById[$pair[1]]
        $logFull = Join-Path $script:Phase2RRepositoryRoot (([string]$sealedRecord['log_path']) -replace '/', '\')
        $findingCount = 0
        $bodyText = (ConvertFrom-Phase2RLenientLogText -Bytes ([IO.File]::ReadAllBytes($logFull))).Trim()
        ## bd prints operational notices prefixed 'beads:' beside its JSON payload, reports
        ## lint findings as a numeric issues field, and prints a bare null for no orphans.
        $payloadText = ([string]::Join("`n", @($bodyText -split "`r?`n" | Where-Object { $_ -notmatch '^beads: ' }))).Trim()
        if ($payloadText.Length -gt 0) {
            $payload = ConvertFrom-Json -InputObject $payloadText
            if ($payload -is [Collections.IEnumerable] -and $payload -isnot [string]) {
                $findingCount = @($payload).Count
            } elseif ($null -ne $payload) {
                $issuesProperty = $payload.PSObject.Properties['issues']
                if ($null -eq $issuesProperty) { $findingCount = 1 }
                elseif ($issuesProperty.Value -is [Collections.IEnumerable] -and $issuesProperty.Value -isnot [string]) { $findingCount = @($issuesProperty.Value).Count }
                else { $findingCount = [int]$issuesProperty.Value }
            }
        }
        if ($findingCount -ne 0) { throw ('GATE_BEADS_FINDINGS: ' + $pair[0] + ' reported ' + $findingCount + ' finding(s)') }
        $beadsResults[$pair[0]] = [ordered]@{
            command_id = [string]$sealedRecord['command_id']
            exit_code = [int]$sealedRecord['exit_code']
            finding_count = 0
        }
    }

    ## Static scan results, parsed from the closeout-static-scans command's own log.
    $scanRecord = $recordsById['closeout-static-scans']
    $scanLogText = ConvertFrom-Phase2RLenientLogText -Bytes ([IO.File]::ReadAllBytes((Join-Path $script:Phase2RRepositoryRoot (([string]$scanRecord['log_path']) -replace '/', '\'))))
    $staticScanResults = New-Object Collections.Generic.List[object]
    foreach ($scan in @(Get-Phase2RStaticScans)) {
        $scanId = [string]$scan['scan_id']
        $lineMatch = [regex]::Match($scanLogText, '(?m)^STATIC_SCAN ' + [regex]::Escape($scanId) + ' violations=([0-9]+)[ ]*\r?$')
        if (-not $lineMatch.Success) { throw ('GATE_STATIC_SCAN_VIOLATIONS: no sweep line for ' + $scanId) }
        $violationCount = [int]$lineMatch.Groups[1].Value
        if ($violationCount -ne 0) { throw ('GATE_STATIC_SCAN_VIOLATIONS: ' + $scanId + ' reported ' + $violationCount) }
        $staticScanResults.Add([ordered]@{
            scan_id = $scanId
            command_id = [string]$scan['command_id']
            violation_count = 0
        })
    }

    ## Versions, digests, and the source-binding scans.
    $importRecord = $recordsById['closeout-import']
    $importLogText = ConvertFrom-Phase2RLenientLogText -Bytes ([IO.File]::ReadAllBytes((Join-Path $script:Phase2RRepositoryRoot (([string]$importRecord['log_path']) -replace '/', '\'))))
    $godotMatch = [regex]::Match($importLogText, '(?m)^Godot Engine v([^\s]+)')
    if (-not $godotMatch.Success) { throw 'GATE_COMMAND_FAILED: Godot version not present in the import log' }
    $bdVersionResult = Invoke-Phase2RNativeBytes -FilePath 'bd' -Arguments @('--version')
    if ($bdVersionResult.exit_code -ne 0) { throw 'GATE_COMMAND_FAILED: bd --version failed' }
    $configText = ConvertFrom-Phase2RStrictUtf8 -Bytes ([IO.File]::ReadAllBytes((Join-Path $script:Phase2RRepositoryRoot 'project.godot'))) -Label 'project.godot'
    $configMatch = [regex]::Match($configText, '(?m)^config_version=([0-9]+)\s*$')
    if (-not $configMatch.Success) { throw 'GATE_REPOSITORY_INVALID: project.godot carries no config_version' }
    $versions = [ordered]@{
        godot = $godotMatch.Groups[1].Value
        gut = Get-Phase2RPluginVersion -RelativePath 'addons/gut/plugin.cfg' -Label 'GUT'
        dialogic = Get-Phase2RPluginVersion -RelativePath 'addons/dialogic/plugin.cfg' -Label 'Dialogic'
        beads = (ConvertFrom-Phase2RLenientLogText -Bytes $bdVersionResult.stdout).Trim()
        config = $configMatch.Groups[1].Value
    }
    $digests = [ordered]@{}
    foreach ($digestKey in $script:Phase2RDigestDocuments.Keys) {
        $documentRelative = [string]$script:Phase2RDigestDocuments[$digestKey]
        $documentFull = Join-Path $script:Phase2RRepositoryRoot ($documentRelative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $documentFull -PathType Leaf)) { throw ('GATE_REPOSITORY_INVALID: authority document missing: ' + $documentRelative) }
        $digests[$digestKey] = [ordered]@{
            path = $documentRelative
            sha256 = Get-Phase2RSha256Hex -Bytes ([IO.File]::ReadAllBytes($documentFull))
        }
    }
    $sourceBindingScans = @(Get-Phase2RSourceBindingScans)

    ## primary_logs: every command log, strictly ascending. The validation log and the
    ## validation-command record are produced after the gate and are bound by the receipt instead.
    $primaryLogs = New-Object Collections.Generic.List[object]
    $primaryPaths = [string[]]@($logHashesByName.Keys)
    [Array]::Sort($primaryPaths, [StringComparer]::Ordinal)
    foreach ($path in $primaryPaths) {
        $primaryLogs.Add([ordered]@{ path = $path; sha256 = [string]$logHashesByName[$path] })
    }

    ## generated_paths: the projected regular-file inventory below the output root, including the
    ## three paths produced after the gate is written.
    $generated = New-Object Collections.Generic.HashSet[string]
    foreach ($file in @(Get-ChildItem -LiteralPath $outputRoot -Recurse -File)) {
        $relativePath = $file.FullName.Substring($script:Phase2RRepositoryRoot.Length).TrimStart('\', '/') -replace '\\', '/'
        [void]$generated.Add($relativePath)
    }
    foreach ($projected in @('gate.json', 'validation_receipt.json', 'logs/phase2r-closeout-validate.log', 'logs/validation-command.jsonl')) {
        [void]$generated.Add($script:Phase2RCloseoutRoot + '/' + $projected)
    }
    $generatedPaths = New-Object string[] $generated.Count
    $generated.CopyTo($generatedPaths)
    [Array]::Sort($generatedPaths, [StringComparer]::Ordinal)
    foreach ($path in $generatedPaths) {
        if (Test-Phase2RPathTraversal -Path $path) { throw ('GATE_PATH_TRAVERSAL: generated path <' + $path + '>') }
    }

    ## Assemble and write the closed twenty-key gate document.
    $gate = [ordered]@{
        schema_version = 1
        evidence_id = 'phase_2r.closeout_gate'
        kind = 'phase2r_closeout_gate'
        captured_at_utc = [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
        subject_commit = $SubjectCommit
        worktree = [ordered]@{
            commit = $SubjectCommit
            tree = $treeHash
            status_porcelain_sha256 = $statusHash
            clean = $true
        }
        versions = $versions
        digests = $digests
        counts = $totals
        contract_inventory_sha256 = Get-Phase2RSha256Hex -Bytes $contractInventoryBytes
        preclose_beads_snapshot_sha256 = $precloseSnapshotSha256
        non_contract_children = $nonContractChildren
        generated_paths = $generatedPaths
        requirement_evidence = $requirementEvidence
        command_records = $records.ToArray()
        diagnostics = $diagnostics.ToArray()
        beads_results = $beadsResults
        source_binding_scans = $sourceBindingScans
        static_scans = $staticScanResults.ToArray()
        primary_logs = $primaryLogs.ToArray()
    }
    $gateBytes = Write-Phase2RNewCanonicalDocument -RelativePath ($script:Phase2RCloseoutRoot + '/gate.json') -Value $gate
    $gateSha256 = Get-Phase2RSha256Hex -Bytes $gateBytes

    ## The one PRE_SEAL invocation, through the isolated wrapper, with the exact recorded vector.
    $presealVector = @(
        '--mode=preseal',
        ('--metadata=res://' + $script:Phase2RMetadataRelative),
        ('--beads=res://' + $script:Phase2RCloseoutRoot + '/preclose_beads_snapshot.json'),
        ('--requirements=res://' + $script:Phase2RRequirementIndexRelative),
        ('--evidence-root=res://' + $script:Phase2RCloseoutRoot),
        ('--gate=res://' + $script:Phase2RCloseoutRoot + '/gate.json')
    )
    $validationRecord = Invoke-Phase2RIsolatedCapture -SuiteId 'phase2r_closeout_preseal' -LogName 'phase2r-closeout-validate.log' -GodotArgs ([string[]](@('-s', 'res://tools/evidence/validate_phase2r_closeout_gate.gd', '--') + $presealVector)) -EvidenceLogPath $script:Phase2REvidenceJournalRelative
    if ([int]$validationRecord.exit_code -ne 0) {
        throw ('GATE_PRESEAL_VALIDATION_FAILED: exit=' + $validationRecord.exit_code)
    }
    $validationLogBytes = [IO.File]::ReadAllBytes([string]$validationRecord.log_path)
    Write-Phase2RNewRawBytes -RelativePath ($script:Phase2RCloseoutRoot + '/logs/phase2r-closeout-validate.log') -Bytes $validationLogBytes
    $validationLogSha256 = Get-Phase2RSha256Hex -Bytes $validationLogBytes

    ## logs/validation-command.jsonl: exactly one compact canonical line plus one LF.
    $commandRecordBytes = Write-Phase2RNewCanonicalDocument -RelativePath ($script:Phase2RCloseoutRoot + '/logs/validation-command.jsonl') -Value ([ordered]@{
        schema_version = 1
        command_id = 'phase2r-closeout-validate'
        argv = $presealVector
        subject_commit = $SubjectCommit
        gate_path = ($script:Phase2RCloseoutRoot + '/gate.json')
        gate_sha256 = $gateSha256
        log_path = ($script:Phase2RCloseoutRoot + '/logs/phase2r-closeout-validate.log')
        log_sha256 = $validationLogSha256
        exit_code = 0
    })

    ## validation_receipt.json, written last. Its command hash covers the whole LF-terminated file.
    [void](Write-Phase2RNewCanonicalDocument -RelativePath ($script:Phase2RCloseoutRoot + '/validation_receipt.json') -Value ([ordered]@{
        schema_version = 1
        subject_commit = $SubjectCommit
        gate_sha256 = $gateSha256
        validation_command_record_sha256 = (Get-Phase2RSha256Hex -Bytes $commandRecordBytes)
        validation_log_sha256 = $validationLogSha256
        validator_exit_code = 0
        sealed_at_utc = [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
    }))

    Write-Output ('PHASE2R_CLOSEOUT_GATE: PASS subject=' + $SubjectCommit + ' gate_sha256=' + $gateSha256)
}

# =================================================================================================
# Entry point. Dot-sourcing defines the functions above without running anything; direct execution
# runs the static-scan sweep or the gate.
# =================================================================================================

$script:Phase2RStrictJsonReader = Join-Path $script:Phase2RRepositoryRoot 'tools\testing\Read-StrictJson.ps1'
[void](Assert-Phase2RContainedNonReparseChain -Root $script:Phase2RRepositoryRoot -Candidate $script:Phase2RStrictJsonReader -RequireStrictDescendant)
. $script:Phase2RStrictJsonReader

if ($MyInvocation.InvocationName -ne '.') {
    if ($StaticScans) {
        $violationTotal = 0
        foreach ($scanResult in @(Invoke-Phase2RStaticScanSweep)) {
            Write-Output ('STATIC_SCAN ' + [string]$scanResult['scan_id'] + ' violations=' + @($scanResult['violations']).Count)
            foreach ($violation in @($scanResult['violations'])) { Write-Output ('  ' + $violation) }
            $violationTotal += @($scanResult['violations']).Count
        }
        if ($violationTotal -ne 0) { exit 1 }
        exit 0
    }
    Invoke-Phase2RCloseoutGate -SubjectCommit $SubjectCommit -OutputDirectory $OutputDirectory
}
