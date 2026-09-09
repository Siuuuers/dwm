# Phase 2R Documentation and Tooling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish an immutable evidence baseline, bounded requirement packets, generated context lookup, configuration guard, audited legacy retirement, durable Beads metadata, and verified replacement workflow before repository CodeGraph metadata is removed.

**Architecture:** A GUID-scoped process runner prepares isolated storage before any Godot child starts and proves the resolved `user://` before the requested task script runs. Strict primitive-only JSON artifacts preserve exact source bytes, patches, legacy-heading identity, requirements, Beads mappings, and command evidence; GDScript validators enforce their schemas and bijections. Generated indexes provide lookup, Beads owns work state, and legacy material is removed only after its exact archive and disposition are independently verifiable.

**Tech Stack:** Godot 4.6.3 stable Mono, GDScript, GUT 9.6.1, Dialogic 2.0-Alpha-19, primitive-only JSON/JSON Schema, Markdown with a strict YAML-frontmatter subset, PowerShell, Beads 1.1.0, `git`, and `rg`.

## Global Constraints

- This plan owns Beads issues `dwm-p2r.1` and `dwm-p2r.2`.
- Runtime behavior is out of scope except the single malformed `project.godot` key and tooling needed to validate evidence/configuration.
- Runtime code, `project.godot`, active prompt documents, tests, localization data, legacy files, and `.codegraph/` remain unchanged until the implementation-plan approval gate passes.
- Preserve the user-owned diffs in `Prompt.md`, `prompt_docs/CONTRACTS.md`, `prompt_docs/DIALOGIC.md`, `prompt_docs/PHASES.md`, and `prompt_docs/TESTING.md`. Capture exact bytes and reconstructable patches before replacing or deleting any of them.
- Preserve `CLAUDE.md` and the user-kept, currently unreferenced `dialogic fx.md` byte-for-byte. They are explicitly outside Phase 2R documentation authority, legacy migration, generated-index input, staging, and deletion.
- Do not stage or edit `.claude/**`, either modified skill directory, `scripts/data/ArtManifest.gd`, or `scripts/ui/ShopApp.gd`.
- Repository CodeGraph removal does not uninstall or modify `codegraph.cmd` or any global package.
- Actual legacy deletion requires `DWM_ARCHIVE_DELETION_AUTHORIZED=1`; the mutating CodeGraph removal branch requires `DWM_CODEGRAPH_REMOVAL_AUTHORIZED=1`. Neither variable is implied by implementation approval or commit authority, and CodeGraph verify-only mode does not require removal authority.
- `implementation_authorized: true` as of 2026-07-18. Task-scoped implementation artifacts, configuration repair, evidence, active-document migration, and ordinary Beads execution updates may proceed in written order. Legacy/archive deletion, repository `.codegraph/` removal, staging, and committing remain behind their separately named gates; global CodeGraph removal remains forbidden.
- Every Godot process uses `tools/testing/Invoke-IsolatedGodot.ps1` after that helper is created; raw Godot command lines are forbidden thereafter.
- Every generated JSON file is UTF-8 without BOM, strict-parsed with duplicate-member rejection, and primitive-only.
- Plan 01 owns, behavior-tests, and first commits `tools/git/Invoke-ExactPathCommit.ps1`; Plans 02–06 consume that one checked-in implementation. Every proposed commit invokes it with an exact current `HEAD^{commit}`, literal required `A|M|D` entries, present-only optional `.uid` additions, and any separately named destructive authority variable. The helper itself requires `DWM_COMMIT_AUTHORIZED=1`, distinguishes Git quiet exit `0`, `1`, and error, rejects partial/rename/copy/type/unmerged/mode drift, and verifies the sole direct-child commit again.
- Proposed commits remain forbidden until the user grants separate, path-specific commit authority. Every helper invocation below is a gate, not permission.

---

## Task 1: Create the isolated Godot runner and immutable pre-migration baseline

**Beads:** `dwm-p2r.1`

**Files:**

- Create: `tools/testing/Invoke-IsolatedGodot.ps1`
- Create: `tests/tooling/Test-InvokeIsolatedGodot.ps1`
- Create: `tools/testing/Read-StrictJson.ps1`
- Create: `tests/tooling/Test-ReadStrictJson.ps1`
- Create: `tools/git/Invoke-ExactPathCommit.ps1`
- Create: `tests/tooling/test_invoke_exact_path_commit.ps1`
- Create: `tests/unit/tooling/test_exact_path_commit.gd`
- Create: `tools/evidence/capture_phase_2r_baseline.ps1`
- Create: `tools/evidence/print_user_dir.gd`
- Create: `tools/evidence/EvidenceValidator.gd`
- Create: `tools/evidence/validate_evidence.gd`
- Create: `prompt_docs/schemas/evidence_report.v1.json`
- Create: `tests/unit/tooling/test_evidence_contract.gd`
- Generate once: `evidence/phase_2r/baseline.json`
- Generate once: `evidence/phase_2r/legacy/legacy_heading_inventory.v1.json`
- Generate: `evidence/phase_2r/logs/baseline-import.log`
- Generate: `evidence/phase_2r/logs/baseline-gut.log`
- Generate: `evidence/phase_2r/logs/baseline-scenes.log`
- Generate: `evidence/phase_2r/logs/isolated-godot.jsonl`

The baseline evidence sub-bundle that the old plan incorrectly called “eight paths” is exactly these nine paths: `capture_phase_2r_baseline.ps1`, `print_user_dir.gd`, `EvidenceValidator.gd`, `evidence_report.v1.json`, `test_evidence_contract.gd`, `baseline.json`, and the three baseline logs. The isolated runner, its PowerShell fixture, the validator CLI, heading inventory, and JSONL process evidence are additional explicit paths.

**Interfaces:**

- Consumes: approved design `2` and `3`; master-plan verified-command convention; repository root containing `project.godot`; read-only `git`, `bd`, and `rg` commands.
- Produces: `ConvertFrom-Phase2RStrictJson -Json String -Label String -> Object`; `Invoke-IsolatedGodot.ps1 -SuiteId String -LogName String -GodotArgs String[] -EvidenceLogPath String? -KeepRoot Switch`; `Invoke-ExactPathCommit.ps1 -RequiredStatus IDictionary -OptionalPresentStatus IDictionary -AllowedDirtyPaths String[] -WhitespaceExemptPaths String[] -RequiredAuthorityVariables String[] -ExpectedHead String -RequireRemainingDirtyExact Switch -Message String`; `EvidenceValidator.validate_file(path: String, schema_path: String) -> Dictionary`; `EvidenceValidator.parse_strict_text(text: String) -> Dictionary` for tooling-only duplicate-aware parsing; `validate_evidence.gd --evidence=<res-path> --schema=<res-path>`; immutable `baseline.json`; immutable `legacy_heading_inventory.v1.json`.

- [ ] **Step 1.1: Protect the current worktree and claim the issue only after plan approval**

Run:

~~~powershell
git status --short
git diff -- Prompt.md prompt_docs/CONTRACTS.md prompt_docs/DIALOGIC.md prompt_docs/PHASES.md prompt_docs/TESTING.md
git diff -- scripts/data/ArtManifest.gd scripts/ui/ShopApp.gd
bd show dwm-p2r.1 --json --readonly
bd update dwm-p2r.1 --claim
~~~

Expected: the known dirty paths remain present and unchanged; `dwm-p2r.1` becomes the sole claimed implementation issue. Do not normalize line endings or clean the worktree.

- [ ] **Step 1.2: Implement strict JSON and process isolation before starting Godot**

Create `tests/tooling/Test-ReadStrictJson.ps1` before its implementation. This complete RED fixture proves recursive duplicate rejection, strict grammar, exact-key case sensitivity, and successful materialization:

~~~powershell
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$reader = Join-Path $PSScriptRoot '..\..\tools\testing\Read-StrictJson.ps1'
if (-not (Test-Path -LiteralPath $reader -PathType Leaf)) {
    throw 'STRICT_JSON_READER_MISSING: tools/testing/Read-StrictJson.ps1'
}
. $reader

$valid = ConvertFrom-Phase2RStrictJson -Json '[{"id":"one","metadata":{"phase2r":true}}]' -Label 'valid'
if (@($valid).Count -ne 1 -or [string]$valid[0].id -cne 'one') { throw 'STRICT_JSON_VALID_MATERIALIZATION' }

foreach ($case in @(
    [ordered]@{ label = 'duplicate-top'; json = '{"id":"one","id":"two"}'; code = 'JSON_DUPLICATE_MEMBER' },
    [ordered]@{ label = 'duplicate-nested'; json = '{"outer":{"id":1,"id":2}}'; code = 'JSON_DUPLICATE_MEMBER' },
    [ordered]@{ label = 'trailing-comma'; json = '[1,]'; code = 'JSON_VALUE_INVALID' },
    [ordered]@{ label = 'comment'; json = '{"id":1/*x*/}'; code = 'JSON_COMMA_OR_OBJECT_END' },
    [ordered]@{ label = 'single-quote'; json = "{'id':1}"; code = 'JSON_OBJECT_KEY_EXPECTED' }
)) {
    $failed = $false
    try { [void](ConvertFrom-Phase2RStrictJson -Json $case.json -Label $case.label) }
    catch {
        $failed = $true
        if (-not $_.Exception.Message.Contains([string]$case.code)) { throw }
    }
    if (-not $failed) { throw "STRICT_JSON_ACCEPTED_INVALID: $($case.label)" }
}
Write-Output 'STRICT_JSON_READER: PASS'
~~~

Run before implementation:

~~~powershell
& .\tests\tooling\Test-ReadStrictJson.ps1
~~~

Expected RED: `STRICT_JSON_READER_MISSING`. Then create `tools/testing/Read-StrictJson.ps1` with this complete PowerShell 5.1-compatible body:

~~~powershell
Set-StrictMode -Version Latest

function ConvertFrom-Phase2RStrictJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json,
        [Parameter(Mandatory = $true)][string]$Label
    )

    function Skip-JsonWhitespace {
        param([string]$Text, [ref]$Position)
        while ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -in @(' ', "`t", "`r", "`n")) {
            $Position.Value += 1
        }
    }

    function Read-JsonString {
        param([string]$Text, [ref]$Position, [string]$Path)
        $start = $Position.Value
        if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne '"') {
            throw "JSON_STRING_EXPECTED: $Label at $Path byte=$($Position.Value)"
        }
        $Position.Value += 1
        while ($Position.Value -lt $Text.Length) {
            $character = $Text[$Position.Value]
            if ([int][char]$character -lt 0x20) { throw "JSON_CONTROL_CHARACTER: $Label at $Path byte=$($Position.Value)" }
            if ($character -ceq '"') {
                $Position.Value += 1
                $token = $Text.Substring($start, $Position.Value - $start)
                return ConvertFrom-Json -InputObject $token -ErrorAction Stop
            }
            if ($character -ceq '\') {
                $Position.Value += 1
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -notin @('"','\','/','b','f','n','r','t','u')) {
                    throw "JSON_ESCAPE_INVALID: $Label at $Path byte=$($Position.Value)"
                }
                if ($Text[$Position.Value] -ceq 'u') {
                    if ($Position.Value + 4 -ge $Text.Length -or $Text.Substring($Position.Value + 1, 4) -notmatch '^[0-9a-fA-F]{4}$') {
                        throw "JSON_UNICODE_ESCAPE_INVALID: $Label at $Path byte=$($Position.Value)"
                    }
                    $Position.Value += 4
                }
            }
            $Position.Value += 1
        }
        throw "JSON_UNTERMINATED_STRING: $Label at $Path byte=$($Position.Value)"
    }

    function Read-JsonValue {
        param([string]$Text, [ref]$Position, [string]$Path)
        Skip-JsonWhitespace $Text $Position
        if ($Position.Value -ge $Text.Length) { throw "JSON_UNEXPECTED_EOF: $Label at $Path" }
        $character = $Text[$Position.Value]
        if ($character -ceq '{') {
            $Position.Value += 1
            $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            Skip-JsonWhitespace $Text $Position
            if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq '}') { $Position.Value += 1; return }
            while ($true) {
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne '"') {
                    throw "JSON_OBJECT_KEY_EXPECTED: $Label at $Path byte=$($Position.Value)"
                }
                $key = [string](Read-JsonString $Text $Position $Path)
                if (-not $seen.Add($key)) { throw "JSON_DUPLICATE_MEMBER: $Label at $Path.$key" }
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne ':') {
                    throw "JSON_COLON_EXPECTED: $Label at $Path.$key byte=$($Position.Value)"
                }
                $Position.Value += 1
                Read-JsonValue $Text $Position ($Path + '.' + $key)
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq '}') { $Position.Value += 1; return }
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne ',') {
                    throw "JSON_COMMA_OR_OBJECT_END: $Label at $Path byte=$($Position.Value)"
                }
                $Position.Value += 1
            }
        }
        if ($character -ceq '[') {
            $Position.Value += 1
            Skip-JsonWhitespace $Text $Position
            if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq ']') { $Position.Value += 1; return }
            $index = 0
            while ($true) {
                Read-JsonValue $Text $Position ("$Path[$index]")
                $index += 1
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq ']') { $Position.Value += 1; return }
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne ',') {
                    throw "JSON_COMMA_OR_ARRAY_END: $Label at $Path byte=$($Position.Value)"
                }
                $Position.Value += 1
            }
        }
        if ($character -ceq '"') { [void](Read-JsonString $Text $Position $Path); return }
        $remaining = $Text.Substring($Position.Value)
        $match = [regex]::Match($remaining, '^(?:true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)')
        if (-not $match.Success) { throw "JSON_VALUE_INVALID: $Label at $Path byte=$($Position.Value)" }
        $Position.Value += $match.Length
    }

    $position = 0
    $positionRef = [ref]$position
    Read-JsonValue $Json $positionRef '$'
    Skip-JsonWhitespace $Json $positionRef
    if ($position -ne $Json.Length) { throw "JSON_TRAILING_DATA: $Label byte=$position" }
    return ConvertFrom-Json -InputObject $Json -ErrorAction Stop
}
~~~

Run `Test-ReadStrictJson.ps1` again. Expected GREEN: exactly `STRICT_JSON_READER: PASS`. Every later PowerShell script strict-parses JSON by dot-sourcing this file through a repository-contained canonical path and calling `ConvertFrom-Phase2RStrictJson`; no destructive gate may call `ConvertFrom-Json` directly on unproved JSON.

Create `tests/tooling/Test-InvokeIsolatedGodot.ps1` **before** the helper. This is the complete fixture; it invokes the helper in a child PowerShell process because the helper deliberately returns its contract exit code with `exit`:

~~~powershell
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
    param([string]$SuiteId, [string]$LogName, [string[]]$GodotArgs)
    $argumentLiterals = @($GodotArgs | ForEach-Object { ConvertTo-SingleQuotedLiteral ([string]$_) })
    $command = "& $(ConvertTo-SingleQuotedLiteral $helper) -SuiteId $(ConvertTo-SingleQuotedLiteral $SuiteId) -LogName $(ConvertTo-SingleQuotedLiteral $LogName) -GodotArgs @($($argumentLiterals -join ','))"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $stdout = @(& $powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded 2>&1)
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Stdout = [string]::Join("`n", $stdout) }
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
Write-Output 'ISOLATION_HELPER: PASS'
~~~

Run before implementation:

~~~powershell
& .\tests\tooling\Test-InvokeIsolatedGodot.ps1
~~~

Expected RED: `ISOLATION_HELPER_MISSING: tools/testing/Invoke-IsolatedGodot.ps1`. After the helper and probe below are written, the same command is the GREEN test and prints exactly `ISOLATION_HELPER: PASS`.

`tools/testing/Invoke-IsolatedGodot.ps1` has exactly this public parameter contract:

~~~powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$SuiteId,

    [Parameter(Mandatory = $true)]
    [string]$LogName,

    [Parameter(Mandatory = $true)]
    [string[]]$GodotArgs,

    [string]$EvidenceLogPath,

    [switch]$KeepRoot
)
~~~

The helper MUST implement this closed behavior:

1. Resolve the repository root from the helper location and fail unless `project.godot` exists there.
2. Resolve the console executable from `GODOT_CONSOLE_PATH` when nonempty, otherwise use `C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe`.
3. Reject an empty `SuiteId`, a `LogName` containing a directory separator, any caller-supplied `--path`, `--headless`, or `--log-file`, and an `EvidenceLogPath` outside the repository.
4. Capture the canonical production user-data candidate from the parent `APPDATA` before redirecting children. Implement one `Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $candidate` helper that canonicalizes both paths, requires the candidate to be the root or a strict descendant, and inspects **every existing component** from the repository root through the candidate with `Get-Item -Force`; any `ReparsePoint` attribute is fatal. Call it before and after creating `.godot`, `.godot/phase2r_logs`, `.godot/phase2r_tests`, the one GUID child, and that child's distinct `appdata`, `localappdata`, and `dwm_test_root` directories. If `EvidenceLogPath` is supplied, resolve its complete parent chain first; create it only when the chain is a non-reparse descendant of repository-owned `evidence/phase_2r/logs/` or `.godot/`, otherwise require the complete parent chain to exist and pass the same repository-containment/reparse check.
5. Launch child processes with redirected `APPDATA`, `LOCALAPPDATA`, and `DWM_TEST_ROOT`. Do not mutate the parent PowerShell process environment.
6. First run `res://tools/evidence/print_user_dir.gd` with a GUID-local proof log beneath the test root. Parse exactly one line prefixed `PHASE2R_USER_DIR=`.
7. Resolve all paths with `[IO.Path]::GetFullPath()` and compare with `[StringComparison]::OrdinalIgnoreCase`. Abort unless the reported `user_dir` is a strict descendant of the GUID root, differs from the captured production `Godot/app_userdata/dwm` path, and every existing component from the repository root through the GUID root and from the GUID root through the reported `user_dir` passes the same non-reparse-chain check.
8. Run the requested child with argv equal to `@('--headless','--path',$repositoryRoot,'--log-file',(Join-Path $repositoryRoot ('.godot/phase2r_logs/' + $LogName))) + $GodotArgs`.
9. Emit exactly one primitive-only JSON record with keys `suite_id`, `argv`, `exit_code`, `log_path`, `test_root`, `user_dir`, `started_at_utc`, and `ended_at_utc`. Print it to stdout; when `EvidenceLogPath` is supplied, append the same compact object as one UTF-8-without-BOM JSONL line.
10. Preserve the requested child exit code as the helper exit code. Use exit `124` only when isolation proof prevents the requested child from starting and `125` only when evidence write or cleanup verification fails.
11. In a `finally` block, canonicalize the repository root, `.godot`, `.godot/phase2r_tests`, and GUID target again; require the target's direct parent to equal `.godot/phase2r_tests`; and re-run the complete non-reparse-chain check through every existing descendant beneath the GUID target before cleanup. If any ancestor or nested entry is a reparse point, refuse recursive cleanup and exit `125`. Remove only that GUID child when `KeepRoot` is absent, verify it no longer exists, and re-check the surviving repository-to-`phase2r_tests` chain. `KeepRoot` retains only that fully verified GUID child.

The same complete-chain rule covers the private `.godot/phase2r_capture/` and `.godot/phase2r_archive_verify/` scratch roots used below: create only one GUID direct child, reject reparse points in every ancestor and nested entry, delete only that direct child, and prove cleanup. When `EvidenceLogPath` is present, append under an exclusive `FileStream` lock with UTF-8 without BOM, `Flush(true)`, and at most 50 retries separated by 100 ms. A lock timeout is exit `125`; parallel agents may not interleave or truncate JSONL records.

Use this paste-ready implementation body after the public `param(...)` block above. The body intentionally keeps all process mutation in `ProcessStartInfo.EnvironmentVariables`, and the one final `exit` occurs only after cleanup has been verified:

~~~powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-StrictDescendant {
    param([string]$Root, [string]$Candidate)
    $rootFull = Get-CanonicalPath $Root
    $candidateFull = Get-CanonicalPath $Candidate
    return $candidateFull.StartsWith(
        $rootFull + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-ContainedNonReparseChain {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate,
        [switch]$RequireStrictDescendant
    )
    $rootFull = Get-CanonicalPath $Root
    $candidateFull = Get-CanonicalPath $Candidate
    $inside = $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or
        (Test-StrictDescendant -Root $rootFull -Candidate $candidateFull)
    if (-not $inside -or ($RequireStrictDescendant -and $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase))) {
        throw "PATH_CONTAINMENT: '$candidateFull' is outside '$rootFull'."
    }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\','/')
    $cursor = $rootFull
    $parts = if ($relative.Length -eq 0) { @() } else { @($relative -split '[\\/]') }
    foreach ($part in @('') + $parts) {
        if ($part.Length -ne 0) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "PATH_REPARSE_POINT: '$cursor'."
            }
        }
    }
    return $candidateFull
}

function New-VerifiedDirectory {
    param([string]$RepositoryRoot, [string]$Path)
    [void](Assert-ContainedNonReparseChain -Root $RepositoryRoot -Candidate $Path)
    [void][IO.Directory]::CreateDirectory((Get-CanonicalPath $Path))
    [void](Assert-ContainedNonReparseChain -Root $RepositoryRoot -Candidate $Path)
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes += 1; continue }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($slashes * 2) + 1)) + '"')
            $slashes = 0
            continue
        }
        if ($slashes -ne 0) { [void]$builder.Append('\' * $slashes); $slashes = 0 }
        [void]$builder.Append($character)
    }
    if ($slashes -ne 0) { [void]$builder.Append('\' * ($slashes * 2)) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-GodotChild {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$AppData,
        [string]$LocalAppData,
        [string]$DwmTestRoot
    )
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = [string]::Join(' ', @($Arguments | ForEach-Object { ConvertTo-NativeArgument ([string]$_) }))
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['APPDATA'] = $AppData
    $start.EnvironmentVariables['LOCALAPPDATA'] = $LocalAppData
    $start.EnvironmentVariables['DWM_TEST_ROOT'] = $DwmTestRoot
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'GODOT_START_FAILED' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdout; Stderr = $stderr }
}

function Assert-TreeHasNoReparsePoints {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return }
    foreach ($item in @(Get-Item -Force -LiteralPath $Root) + @(Get-ChildItem -Force -Recurse -LiteralPath $Root)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "CLEANUP_REPARSE_POINT: '$($item.FullName)'."
        }
    }
}

function Add-JsonLineExclusive {
    param([string]$Path, [string]$JsonLine)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($JsonLine + "`n")
    for ($attempt = 1; $attempt -le 50; $attempt += 1) {
        $stream = $null
        try {
            $stream = New-Object IO.FileStream($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            [void]$stream.Seek(0, [IO.SeekOrigin]::End)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
            return
        } catch [IO.IOException] {
            if ($attempt -eq 50) { throw 'EVIDENCE_LOCK_TIMEOUT' }
            Start-Sleep -Milliseconds 100
        } finally {
            if ($null -ne $stream) { $stream.Dispose() }
        }
    }
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$projectPath = Join-Path $repositoryRoot 'project.godot'
$phaseTestsRoot = Join-Path $repositoryRoot '.godot\phase2r_tests'
$guidRoot = Join-Path $phaseTestsRoot ([guid]::NewGuid().ToString('D').ToLowerInvariant())
$recordJson = $null
$resultCode = 124
$phase = 'isolation'

try {
    if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) { throw 'PROJECT_ROOT_INVALID' }
    if ([string]::IsNullOrWhiteSpace($SuiteId)) { throw 'SUITE_ID_EMPTY' }
    if ([string]::IsNullOrWhiteSpace($LogName) -or [IO.Path]::GetFileName($LogName) -cne $LogName) { throw 'LOG_NAME_INVALID' }
    foreach ($argument in $GodotArgs) {
        if ([string]$argument -match '^(?i)--(?:path|headless|log-file)(?:=|$)') { throw "FORBIDDEN_GODOT_ARG: $argument" }
    }
    if ([string]::IsNullOrWhiteSpace($env:APPDATA)) { throw 'PARENT_APPDATA_MISSING' }
    $productionUserDir = Get-CanonicalPath (Join-Path $env:APPDATA 'Godot\app_userdata\dwm')
    $godotExecutable = if ([string]::IsNullOrWhiteSpace($env:GODOT_CONSOLE_PATH)) {
        'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
    } else { [string]$env:GODOT_CONSOLE_PATH }
    $godotExecutable = Get-CanonicalPath $godotExecutable
    if (-not (Test-Path -LiteralPath $godotExecutable -PathType Leaf)) { throw "GODOT_CONSOLE_MISSING: $godotExecutable" }

    [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $repositoryRoot)
    $dotGodot = Join-Path $repositoryRoot '.godot'
    $logsRoot = Join-Path $dotGodot 'phase2r_logs'
    foreach ($directory in @($dotGodot, $logsRoot, $phaseTestsRoot, $guidRoot)) {
        New-VerifiedDirectory -RepositoryRoot $repositoryRoot -Path $directory
    }
    $childAppData = Join-Path $guidRoot 'appdata'
    $childLocalAppData = Join-Path $guidRoot 'localappdata'
    $childDwmRoot = Join-Path $guidRoot 'dwm_test_root'
    foreach ($directory in @($childAppData, $childLocalAppData, $childDwmRoot)) {
        New-VerifiedDirectory -RepositoryRoot $repositoryRoot -Path $directory
    }

    $evidenceFull = $null
    if (-not [string]::IsNullOrWhiteSpace($EvidenceLogPath)) {
        $evidenceFull = Get-CanonicalPath $(if ([IO.Path]::IsPathRooted($EvidenceLogPath)) { $EvidenceLogPath } else { Join-Path $repositoryRoot $EvidenceLogPath })
        [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $evidenceFull -RequireStrictDescendant)
        $parent = Split-Path -Parent $evidenceFull
        $creationAllowed = (Test-StrictDescendant -Root (Join-Path $repositoryRoot 'evidence\phase_2r\logs') -Candidate $parent) -or
            $parent.Equals((Get-CanonicalPath (Join-Path $repositoryRoot 'evidence\phase_2r\logs')), [StringComparison]::OrdinalIgnoreCase) -or
            (Test-StrictDescendant -Root $dotGodot -Candidate $parent) -or
            $parent.Equals((Get-CanonicalPath $dotGodot), [StringComparison]::OrdinalIgnoreCase)
        if (-not (Test-Path -LiteralPath $parent)) {
            if (-not $creationAllowed) { throw 'EVIDENCE_PARENT_MISSING_OUTSIDE_ALLOWED_ROOT' }
            New-VerifiedDirectory -RepositoryRoot $repositoryRoot -Path $parent
        }
        [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $parent -RequireStrictDescendant)
    }

    $proofLog = Join-Path $guidRoot 'user-dir-proof.log'
    $proofArgs = @('--headless','--path',$repositoryRoot,'--log-file',$proofLog,'-s','res://tools/evidence/print_user_dir.gd')
    $proof = Invoke-GodotChild -Executable $godotExecutable -Arguments $proofArgs -AppData $childAppData -LocalAppData $childLocalAppData -DwmTestRoot $childDwmRoot
    if ($proof.ExitCode -ne 0) { throw "USER_DIR_PROOF_EXIT: $($proof.ExitCode) $($proof.Stderr)" }
    $markers = @($proof.Stdout -split "`r?`n" | Where-Object { $_.StartsWith('PHASE2R_USER_DIR=', [StringComparison]::Ordinal) })
    if ($markers.Count -ne 1) { throw "USER_DIR_MARKER_COUNT: $($markers.Count)" }
    $userDir = Get-CanonicalPath $markers[0].Substring('PHASE2R_USER_DIR='.Length)
    if (-not (Test-StrictDescendant -Root $guidRoot -Candidate $userDir)) { throw 'USER_DIR_OUTSIDE_GUID_ROOT' }
    if ($userDir.Equals($productionUserDir, [StringComparison]::OrdinalIgnoreCase)) { throw 'USER_DIR_EQUALS_PRODUCTION' }
    [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $guidRoot -RequireStrictDescendant)
    [void](Assert-ContainedNonReparseChain -Root $guidRoot -Candidate $userDir -RequireStrictDescendant)

    $logPath = Get-CanonicalPath (Join-Path $logsRoot $LogName)
    $argv = @('--headless','--path',$repositoryRoot,'--log-file',$logPath) + @($GodotArgs)
    $startedAt = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $requested = Invoke-GodotChild -Executable $godotExecutable -Arguments $argv -AppData $childAppData -LocalAppData $childLocalAppData -DwmTestRoot $childDwmRoot
    $endedAt = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $resultCode = [int]$requested.ExitCode
    $phase = 'evidence'
    $record = [ordered]@{
        suite_id = $SuiteId; argv = @($argv); exit_code = $resultCode; log_path = $logPath
        test_root = (Get-CanonicalPath $guidRoot); user_dir = $userDir
        started_at_utc = $startedAt; ended_at_utc = $endedAt
    }
    $recordJson = ConvertTo-Json -InputObject $record -Depth 4 -Compress
    if ($null -ne $evidenceFull) { Add-JsonLineExclusive -Path $evidenceFull -JsonLine $recordJson }
} catch {
    if ($phase -eq 'evidence') { $resultCode = 125 } else { $resultCode = 124 }
    [Console]::Error.WriteLine($_.Exception.Message)
} finally {
    try {
        foreach ($candidate in @($repositoryRoot, (Join-Path $repositoryRoot '.godot'), $phaseTestsRoot, $guidRoot)) {
            if (Test-Path -LiteralPath $candidate) { [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $candidate) }
        }
        if (Test-Path -LiteralPath $guidRoot) {
            $actualParent = Get-CanonicalPath (Split-Path -Parent $guidRoot)
            if (-not $actualParent.Equals((Get-CanonicalPath $phaseTestsRoot), [StringComparison]::OrdinalIgnoreCase)) { throw 'CLEANUP_PARENT_MISMATCH' }
            Assert-TreeHasNoReparsePoints -Root $guidRoot
            if (-not $KeepRoot) {
                Remove-Item -LiteralPath $guidRoot -Recurse -Force
                if (Test-Path -LiteralPath $guidRoot) { throw 'CLEANUP_TARGET_SURVIVED' }
            }
        }
        if (Test-Path -LiteralPath $phaseTestsRoot) {
            [void](Assert-ContainedNonReparseChain -Root $repositoryRoot -Candidate $phaseTestsRoot -RequireStrictDescendant)
        }
    } catch {
        $resultCode = 125
        [Console]::Error.WriteLine($_.Exception.Message)
    }
}
if ($null -ne $recordJson) { [Console]::Out.WriteLine($recordJson) }
exit $resultCode
~~~

`print_user_dir.gd` is a side-effect-free `SceneTree` script that deliberately calls no project manager or persistence API; it prints only the marker plus `ProjectSettings.globalize_path("user://")` and then exits zero. Godot may initialize project/autoload state for this exempt proof process, so its safety comes from `APPDATA`, `LOCALAPPDATA`, and `DWM_TEST_ROOT` already being redirected before launch.

Its complete body is:

~~~gdscript
extends SceneTree

func _init() -> void:
	print("PHASE2R_USER_DIR=" + ProjectSettings.globalize_path("user://"))
	quit(0)
~~~

- [ ] **Step 1.3: Create and behavior-test the one exact-path commit helper**

Create `tests/unit/tooling/test_exact_path_commit.gd` and `tests/tooling/test_invoke_exact_path_commit.ps1` before the helper. The GDScript fixture reads the future helper as text and fails with `missing_script` until it exists; after implementation it requires the exact parameter, authority, Git-quiet, raw-mode, partial-staging, ancestry, and postcommit tokens below. The PowerShell fixture creates a fresh scratch Git repository beneath the wrapper-proven `.godot/phase2r_tests` root and invokes the worktree copy in isolated child PowerShell processes. Its RED mode fails only because the helper path is absent:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'exact_path_commit_red' -LogName 'phase2r-red-exact-path-commit.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_exact_path_commit.gd','-gexit')
& .\tests\tooling\test_invoke_exact_path_commit.ps1 -Mode ExpectMissing
~~~

The complete fixtures MUST prove: exact required `A|M|D` plus present/absent optional UID success; mandatory `DWM_COMMIT_AUTHORIZED=1` and each named extra-authority variable; missing, explicitly empty, and wrong `ExpectedHead` rejection plus exact expected-parent/direct-child ancestry; empty-index exit `0` versus dirty-index exit `1` versus Git error handling; missing, extra, duplicate, malformed, and absent-required paths; empty commits; partial staging; rename and copy detection including a new path copied from an unchanged source under `--find-copies-harder`; `T|U|X|B` rejection; regular-blob mode `100644` for additions/modifications and old `100644` to new `000000` for deletions; chmod, symlink `120000`, gitlink `160000`, and every other type/mode drift rejection; failed commit exit; and exact committed status/mode revalidation. They use only scratch repositories and restore every caller environment variable.

Create `tools/git/Invoke-ExactPathCommit.ps1` with this complete PowerShell-5.1-compatible body. This is the sole commit implementation used by every Plan 01–06 boundary:

~~~powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][System.Collections.IDictionary]$RequiredStatus,
    [System.Collections.IDictionary]$OptionalPresentStatus = @{},
    [string[]]$AllowedDirtyPaths = @(),
    [string[]]$WhitespaceExemptPaths = @(),
    [string[]]$RequiredAuthorityVariables = @(),
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ExpectedHead,
    [switch]$RequireRemainingDirtyExact,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Message
)

$ErrorActionPreference = 'Stop'

function Assert-RepoPath([string]$Path) {
    $badSegments = @($Path.Split('/') | Where-Object { $_ -in @('', '.', '..') })
    if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path) -or
        $Path.Contains('\') -or $Path -match '[*?\[\]]' -or $badSegments.Count -ne 0) {
        throw ('Non-literal repository path: ' + $Path)
    }
}

function Invoke-GitQuiet([string[]]$Arguments, [string]$Label) {
    & git @Arguments
    $code = $LASTEXITCODE
    if ($code -notin @(0, 1)) { throw ($Label + ' failed with Git exit ' + $code) }
    return $code
}

function Test-Tracked([string]$Path) {
    & git ls-files --error-unmatch -- $Path *> $null
    $code = $LASTEXITCODE
    if ($code -eq 0) { return $true }
    if ($code -eq 1) { return $false }
    throw ('Unable to inspect tracked path: ' + $Path)
}

function ConvertTo-StatusMap([string[]]$Lines, [string]$Label) {
    $map = [ordered]@{}
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = @($line -split "`t", -1)
        if ($parts.Count -ne 2 -or $parts[0] -notin @('A','M','D')) {
            throw ($Label + ' has malformed/rename/copy/type/unmerged status: ' + $line)
        }
        Assert-RepoPath $parts[1]
        if ($map.Contains($parts[1])) { throw ($Label + ' repeats path: ' + $parts[1]) }
        $map[$parts[1]] = $parts[0]
    }
    return $map
}

function ConvertTo-RawModeMap([string[]]$Lines, [string]$Label) {
    $map = [ordered]@{}
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^:([0-7]{6}) ([0-7]{6}) ([0-9a-f]+) ([0-9a-f]+) ([A-Z][0-9]*)\t(.+)$') {
            throw ($Label + ' has malformed raw record: ' + $line)
        }
        $oldMode = $Matches[1]
        $newMode = $Matches[2]
        $status = $Matches[5]
        $path = $Matches[6]
        Assert-RepoPath $path
        if ($status -notin @('A','M','D') -or $map.Contains($path)) {
            throw ($Label + ' has rename/copy/type/unmerged/duplicate raw record: ' + $line)
        }
        $map[$path] = [ordered]@{status=$status;old_mode=$oldMode;new_mode=$newMode}
    }
    return $map
}

function Assert-ExactMap([System.Collections.IDictionary]$Actual, [System.Collections.IDictionary]$Expected, [string]$Label) {
    if ($Actual.Count -ne $Expected.Count) {
        throw ($Label + ' path cardinality differs: actual=' + $Actual.Count + ' expected=' + $Expected.Count)
    }
    foreach ($path in $Expected.Keys) {
        if (-not $Actual.Contains($path) -or [string]$Actual[$path] -cne [string]$Expected[$path]) {
            throw ($Label + ' expected ' + $Expected[$path] + "`t" + $path)
        }
    }
}

function Assert-ExactRawModes([System.Collections.IDictionary]$Actual, [System.Collections.IDictionary]$Expected, [string]$Label) {
    if ($Actual.Count -ne $Expected.Count) { throw ($Label + ' raw path cardinality differs.') }
    foreach ($path in $Expected.Keys) {
        if (-not $Actual.Contains($path)) { throw ($Label + ' raw record missing: ' + $path) }
        $status = [string]$Expected[$path]
        $record = $Actual[$path]
        $expectedOld = if ($status -eq 'A') { '000000' } else { '100644' }
        $expectedNew = if ($status -eq 'D') { '000000' } else { '100644' }
        if ([string]$record.status -cne $status -or [string]$record.old_mode -cne $expectedOld -or [string]$record.new_mode -cne $expectedNew) {
            throw ($Label + ' expected regular-blob modes ' + $expectedOld + ' -> ' + $expectedNew + ' for ' + $status + "`t" + $path)
        }
    }
}

if ([Environment]::GetEnvironmentVariable('DWM_COMMIT_AUTHORIZED') -cne '1') {
    throw 'Explicit commit authority is required.'
}
foreach ($name in $RequiredAuthorityVariables) {
    if ($name -notmatch '^DWM_[A-Z0-9_]+_AUTHORIZED$' -or
        [Environment]::GetEnvironmentVariable($name) -cne '1') {
        throw ('Missing exact extra authority: ' + $name)
    }
}

$indexCode = Invoke-GitQuiet @('diff','--cached','--quiet') 'Initial index inspection'
if ($indexCode -eq 1) { throw 'Staged index is not empty.' }

$parent = [string]::Join('', @(& git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $parent) { throw 'Cannot resolve current HEAD.' }
if ($parent -cne $ExpectedHead) { throw 'HEAD differs from the required parent boundary.' }

$expected = [ordered]@{}
foreach ($pathObject in $RequiredStatus.Keys) {
    $path = [string]$pathObject
    $status = [string]$RequiredStatus[$pathObject]
    Assert-RepoPath $path
    if ($status -notin @('A','M','D') -or $expected.Contains($path)) { throw ('Invalid required status: ' + $path) }
    $tracked = Test-Tracked $path
    if ($status -eq 'A' -and ($tracked -or -not (Test-Path -LiteralPath $path -PathType Leaf))) { throw ('Required A path is not a present untracked file: ' + $path) }
    if ($status -eq 'M' -and (-not $tracked -or -not (Test-Path -LiteralPath $path -PathType Leaf))) { throw ('Required M path is not a present tracked file: ' + $path) }
    if ($status -eq 'D' -and (-not $tracked -or (Test-Path -LiteralPath $path))) { throw ('Required D path is not an absent tracked file: ' + $path) }
    $expected[$path] = $status
}

foreach ($pathObject in $OptionalPresentStatus.Keys) {
    $path = [string]$pathObject
    $status = [string]$OptionalPresentStatus[$pathObject]
    Assert-RepoPath $path
    if (-not $path.EndsWith('.uid') -or $status -cne 'A' -or $expected.Contains($path)) { throw ('Invalid optional UID contract: ' + $path) }
    $tracked = Test-Tracked $path
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        if ($tracked) { throw ('Optional A UID is already tracked: ' + $path) }
        $expected[$path] = 'A'
    } elseif ($tracked) {
        throw ('Optional UID is tracked but absent: ' + $path)
    }
}

foreach ($path in $AllowedDirtyPaths) {
    Assert-RepoPath $path
    if ($expected.Contains($path)) { throw ('Allowed-dirty path overlaps commit set: ' + $path) }
}

foreach ($path in $RequiredStatus.Keys) {
    & git add -A -- ([string]$path)
    if ($LASTEXITCODE -ne 0) { throw ('Failed to stage required path: ' + $path) }
}
foreach ($path in $OptionalPresentStatus.Keys) {
    if ($expected.Contains([string]$path)) {
        & git add -- ([string]$path)
        if ($LASTEXITCODE -ne 0) { throw ('Failed to stage optional UID: ' + $path) }
    }
}

$nonemptyCode = Invoke-GitQuiet @('diff','--cached','--quiet') 'Staged index inspection'
if ($nonemptyCode -eq 0) { throw 'Refusing an empty commit.' }
$stagedLines = @(& git -c 'core.quotepath=false' diff --cached --name-status '--find-renames=50%' '--find-copies=50%' --find-copies-harder)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect staged statuses.' }
$stagedMap = ConvertTo-StatusMap $stagedLines 'Staged index'
Assert-ExactMap $stagedMap $expected 'Staged index'
$stagedRawLines = @(& git -c 'core.quotepath=false' diff --cached --raw --no-abbrev '--find-renames=50%' '--find-copies=50%' --find-copies-harder)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect staged raw modes.' }
$stagedRawMap = ConvertTo-RawModeMap $stagedRawLines 'Staged index'
Assert-ExactRawModes $stagedRawMap $expected 'Staged index'
$expectedPaths = @($expected.Keys)
$partiallyStaged = @(& git diff --name-only -- $expectedPaths)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect partial staging.' }
if (@($partiallyStaged | Where-Object { $_ }).Count -ne 0) { throw 'Required path has unstaged/partial content.' }
& git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Staged diff check failed.' }

if ($RequireRemainingDirtyExact) {
    $remaining = @(
        @(& git diff --name-only) + @(& git ls-files --others --exclude-standard) |
            Where-Object { $_ } | Sort-Object -Unique
    )
    $allowed = @($AllowedDirtyPaths | Sort-Object -Unique)
    if ([string]::Join("`n", $remaining) -cne [string]::Join("`n", $allowed)) {
        throw 'Remaining worktree paths differ from the exact allowed-dirty set.'
    }
}

& git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
$head = [string]::Join('', @(& git rev-parse --verify 'HEAD^{commit}')).Trim()
$parentLine = [string]::Join(' ', @(& git rev-list --parents -n 1 $head)).Trim() -split ' '
if ($LASTEXITCODE -ne 0 -or $parentLine.Count -ne 2 -or $parentLine[1] -cne $parent) {
    throw 'Committed boundary is not the sole direct child of the expected parent.'
}
$committedLines = @(& git -c 'core.quotepath=false' diff-tree --no-commit-id -r --name-status '--find-renames=50%' '--find-copies=50%' --find-copies-harder $head)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect committed statuses.' }
$committedMap = ConvertTo-StatusMap $committedLines 'Committed boundary'
Assert-ExactMap $committedMap $expected 'Committed boundary'
$committedRawLines = @(& git -c 'core.quotepath=false' diff-tree --no-commit-id -r --raw --no-abbrev '--find-renames=50%' '--find-copies=50%' --find-copies-harder $head)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect committed raw modes.' }
$committedRawMap = ConvertTo-RawModeMap $committedRawLines 'Committed boundary'
Assert-ExactRawModes $committedRawMap $expected 'Committed boundary'
Write-Output ('EXACT_PATH_COMMIT: PASS ' + $head)
~~~

Run the GREEN source/behavior fixtures before allowing the helper to commit itself:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'exact_path_commit_green' -LogName 'phase2r-exact-path-commit.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_exact_path_commit.gd','-gexit')
& .\tests\tooling\test_invoke_exact_path_commit.ps1 -Mode Verify
if ($LASTEXITCODE -ne 0) { throw 'Exact-path commit behavior fixture failed.' }
~~~

Expected GREEN: every success/rejection/mode/ancestry fixture above passes, no caller-repository path is staged or committed, and the caller environment is restored. Plan 01's first proposed boundary includes the helper and both fixtures, so every later plan consumes the exact committed implementation rather than recreating it.

- [ ] **Step 1.4: Write the failing evidence contract**

Create `tests/unit/tooling/test_evidence_contract.gd` with tests that require:

~~~gdscript
extends "res://addons/gut/test.gd"

const VALIDATOR_PATH := "res://tools/evidence/EvidenceValidator.gd"
const BASELINE_PATH := "res://evidence/phase_2r/baseline.json"
const SCHEMA_PATH := "res://prompt_docs/schemas/evidence_report.v1.json"
const INVENTORY_PATH := "res://evidence/phase_2r/legacy/legacy_heading_inventory.v1.json"

func test_baseline_exists_and_matches_schema() -> void:
	var validator_script: Script = load(VALIDATOR_PATH)
	assert_not_null(validator_script, "EvidenceValidator must exist")
	if validator_script == null:
		return
	var result: Dictionary = validator_script.validate_file(BASELINE_PATH, SCHEMA_PATH)
	assert_true(result.get("ok", false), JSON.stringify(result.get("errors", [])))

func test_every_command_proves_an_isolated_user_dir() -> void:
	var result: Dictionary = load(VALIDATOR_PATH).validate_file(BASELINE_PATH, SCHEMA_PATH)
	assert_true(result.get("ok", false))
	if not result.get("ok", false):
		return
	for command: Dictionary in result["evidence"]["commands"]:
		var root: String = str(command["test_root"]).replace("\\", "/").trim_suffix("/").to_lower()
		var user_dir: String = str(command["user_dir"]).replace("\\", "/").to_lower()
		assert_true(root.contains("/.godot/phase2r_tests/"))
		assert_true(user_dir.begins_with(root + "/"))

func test_heading_inventory_hash_is_bound_into_baseline() -> void:
	var result: Dictionary = load(VALIDATOR_PATH).validate_file(BASELINE_PATH, SCHEMA_PATH)
	assert_true(result.get("ok", false))
	assert_eq(result["evidence"]["legacy_heading_inventory"]["path"], INVENTORY_PATH)
~~~

Run through the new helper:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task1-evidence-red' -LogName 'phase2r-red-evidence.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_evidence_contract.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected RED: `EvidenceValidator must exist`. A parse error, helper exit `124`/`125`, crash, or production `user://` access is an invalid RED.

- [ ] **Step 1.5: Define the immutable schemas and exact source archive**

Implement:

~~~gdscript
class_name EvidenceValidator
extends RefCounted

static func validate_file(path: String, schema_path: String) -> Dictionary
~~~

Replace that declaration sketch with this line-complete implementation structure. `StrictReader` is private to this Task 1 file so Task 1 does not depend on a later runtime JSON utility. The implementation may be mechanically split into private methods, but no validation branch may be dropped:

~~~gdscript
class_name EvidenceValidator
extends RefCounted

const SOURCE_PATHS: Array[String] = [
	"Prompt.md", "prompt_docs/INDEX.md", "prompt_docs/CONTRACTS.md",
	"prompt_docs/CONTENT.md", "prompt_docs/DIALOGIC.md", "prompt_docs/FLOWS.md",
	"prompt_docs/PHASES.md", "prompt_docs/REPORT.md", "prompt_docs/TESTING.md",
	"prompt_docs/GLOSSARY.md", "ResultReport.md", "Beads.md",
]
const SHA256_PATTERN := "^[0-9a-f]{64}$"

class StrictReader:
	var source := ""
	var cursor := 0
	var errors: Array[String] = []

	func _init(text: String) -> void:
		source = text

	func parse() -> Dictionary:
		_skip_space()
		var value: Variant = _read_value("$")
		_skip_space()
		if errors.is_empty() and cursor != source.length():
			_fail("JSON_TRAILING_DATA", "$")
		return {"ok": errors.is_empty(), "value": value, "errors": errors}

	func _read_value(path: String) -> Variant:
		_skip_space()
		if cursor >= source.length():
			_fail("JSON_UNEXPECTED_EOF", path)
			return null
		match source[cursor]:
			"{": return _read_object(path)
			"[": return _read_array(path)
			"\"": return _read_string(path)
			"t": return _read_literal("true", true, path)
			"f": return _read_literal("false", false, path)
			"n": return _read_literal("null", null, path)
			_: return _read_number(path)

	func _read_object(path: String) -> Dictionary:
		cursor += 1
		var output := {}
		var seen := {}
		_skip_space()
		if _consume("}"): return output
		while errors.is_empty():
			_skip_space()
			if cursor >= source.length() or source[cursor] != "\"":
				_fail("JSON_OBJECT_KEY_EXPECTED", path)
				return output
			var key: Variant = _read_string(path)
			if seen.has(key):
				_fail("JSON_DUPLICATE_MEMBER", path + "." + str(key))
				return output
			seen[key] = true
			_skip_space()
			if not _consume(":"):
				_fail("JSON_COLON_EXPECTED", path + "." + str(key))
				return output
			output[key] = _read_value(path + "." + str(key))
			_skip_space()
			if _consume("}"): return output
			if not _consume(","):
				_fail("JSON_COMMA_EXPECTED", path)
				return output
		return output

	func _read_array(path: String) -> Array:
		cursor += 1
		var output: Array = []
		_skip_space()
		if _consume("]"): return output
		while errors.is_empty():
			output.append(_read_value("%s[%d]" % [path, output.size()]))
			_skip_space()
			if _consume("]"): return output
			if not _consume(","):
				_fail("JSON_COMMA_EXPECTED", path)
				return output
		return output

	func _read_string(path: String) -> Variant:
		var start := cursor
		cursor += 1
		while cursor < source.length():
			var character := source[cursor]
			if character == "\"":
				cursor += 1
				var token := source.substr(start, cursor - start)
				var parsed: Variant = JSON.parse_string(token)
				if typeof(parsed) != TYPE_STRING:
					_fail("JSON_STRING_INVALID", path)
				return parsed
			if character == "\\":
				cursor += 1
				if cursor >= source.length() or not source[cursor] in ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]:
					_fail("JSON_ESCAPE_INVALID", path)
					return null
				if source[cursor] == "u":
					if cursor + 4 >= source.length() or not source.substr(cursor + 1, 4).is_valid_hex_number(false):
						_fail("JSON_UNICODE_ESCAPE_INVALID", path)
						return null
					cursor += 4
			elif character.unicode_at(0) < 0x20:
				_fail("JSON_CONTROL_CHARACTER", path)
				return null
			cursor += 1
		_fail("JSON_UNTERMINATED_STRING", path)
		return null

	func _read_number(path: String) -> Variant:
		var start := cursor
		while cursor < source.length() and source[cursor] in ["-", "+", ".", "e", "E", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			cursor += 1
		if cursor == start:
			_fail("JSON_VALUE_INVALID", path)
			return null
		var token := source.substr(start, cursor - start)
		var number_pattern := RegEx.create_from_string("^-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$")
		if number_pattern.search(token) == null:
			_fail("JSON_NUMBER_INVALID", path)
			return null
		return JSON.parse_string(token)

	func _read_literal(token: String, value: Variant, path: String) -> Variant:
		if source.substr(cursor, token.length()) != token:
			_fail("JSON_LITERAL_INVALID", path)
			return null
		cursor += token.length()
		return value

	func _skip_space() -> void:
		while cursor < source.length() and source[cursor] in [" ", "\t", "\r", "\n"]:
			cursor += 1

	func _consume(token: String) -> bool:
		if cursor < source.length() and source[cursor] == token:
			cursor += 1
			return true
		return false

	func _fail(code: String, path: String) -> void:
		if errors.is_empty(): errors.append("%s at %s byte=%d" % [code, path, cursor])

static func validate_file(path: String, schema_path: String) -> Dictionary:
	var errors: Array[String] = []
	var evidence_result := _parse_utf8_file(path)
	var schema_result := _parse_utf8_file(schema_path)
	errors.append_array(evidence_result.errors)
	errors.append_array(schema_result.errors)
	if not errors.is_empty(): return {"ok": false, "errors": errors, "evidence": {}}
	if typeof(evidence_result.value) != TYPE_DICTIONARY or typeof(schema_result.value) != TYPE_DICTIONARY:
		errors.append("EVIDENCE_OR_SCHEMA_NOT_OBJECT")
		return {"ok": false, "errors": errors, "evidence": {}}
	_validate_schema(evidence_result.value, schema_result.value, "$", errors)
	if errors.is_empty(): _validate_cross_fields(evidence_result.value, errors)
	return {"ok": errors.is_empty(), "errors": errors, "evidence": evidence_result.value}

static func parse_strict_text(text: String) -> Dictionary:
	return StrictReader.new(text).parse()

static func _parse_utf8_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"value": null, "errors": ["FILE_MISSING: " + path]}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 3 and bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]):
		return {"value": null, "errors": ["UTF8_BOM_FORBIDDEN: " + path]}
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"value": null, "errors": ["UTF8_INVALID: " + path]}
	return StrictReader.new(text).parse()

static func _validate_schema(value: Variant, schema: Dictionary, path: String, errors: Array[String]) -> void:
	var allowed := ["$schema", "title", "description", "type", "const", "enum", "required", "additionalProperties", "properties", "items", "minItems", "maxItems", "uniqueItems", "minimum", "maximum", "minLength", "pattern"]
	for keyword: Variant in schema.keys():
		if not keyword in allowed: errors.append("SCHEMA_KEYWORD_UNSUPPORTED: %s at %s" % [keyword, path])
	if schema.has("type"):
		var declared_types: Array = schema.type if typeof(schema.type) == TYPE_ARRAY else [schema.type]
		var type_matches := false
		for declared: Variant in declared_types: type_matches = type_matches or _matches_type(value, str(declared))
		if not type_matches:
			errors.append("SCHEMA_TYPE: expected %s at %s" % [schema.type, path])
			return
	if schema.has("const") and value != schema.const: errors.append("SCHEMA_CONST: " + path)
	if schema.has("enum") and not value in schema.enum: errors.append("SCHEMA_ENUM: " + path)
	if typeof(value) == TYPE_DICTIONARY:
		for required: Variant in schema.get("required", []):
			if not value.has(required): errors.append("SCHEMA_REQUIRED: %s.%s" % [path, required])
		var properties: Dictionary = schema.get("properties", {})
		for key: Variant in value.keys():
			if properties.has(key): _validate_schema(value[key], properties[key], path + "." + str(key), errors)
			elif schema.get("additionalProperties", true) == false: errors.append("SCHEMA_UNKNOWN_MEMBER: %s.%s" % [path, key])
	elif typeof(value) == TYPE_ARRAY:
		if value.size() < int(schema.get("minItems", 0)): errors.append("SCHEMA_MIN_ITEMS: " + path)
		if schema.has("maxItems") and value.size() > int(schema.maxItems): errors.append("SCHEMA_MAX_ITEMS: " + path)
		if schema.get("uniqueItems", false):
			var seen := {}
			for item: Variant in value:
				var key := JSON.stringify(item, "", false)
				if seen.has(key): errors.append("SCHEMA_UNIQUE_ITEMS: " + path)
				seen[key] = true
		if schema.has("items"):
			for index in value.size(): _validate_schema(value[index], schema.items, "%s[%d]" % [path, index], errors)
	elif typeof(value) == TYPE_STRING:
		if value.length() < int(schema.get("minLength", 0)): errors.append("SCHEMA_MIN_LENGTH: " + path)
		if schema.has("pattern") and RegEx.create_from_string(str(schema.pattern)).search(value) == null: errors.append("SCHEMA_PATTERN: " + path)
	elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		if schema.has("minimum") and value < schema.minimum: errors.append("SCHEMA_MINIMUM: " + path)
		if schema.has("maximum") and value > schema.maximum: errors.append("SCHEMA_MAXIMUM: " + path)

static func _matches_type(value: Variant, expected: String) -> bool:
	match expected:
		"object": return typeof(value) == TYPE_DICTIONARY
		"array": return typeof(value) == TYPE_ARRAY
		"string": return typeof(value) == TYPE_STRING
		"integer": return typeof(value) == TYPE_INT
		"number": return typeof(value) in [TYPE_INT, TYPE_FLOAT]
		"boolean": return typeof(value) == TYPE_BOOL
		"null": return value == null
		_: return false

static func _validate_cross_fields(evidence: Dictionary, errors: Array[String]) -> void:
	var source_by_path := {}
	for record: Dictionary in evidence.source_archive:
		_validate_archive_record(record, "source_archive", errors)
		if source_by_path.has(record.path): errors.append("SOURCE_DUPLICATE: " + record.path)
		source_by_path[record.path] = record
	for path: String in SOURCE_PATHS:
		if not source_by_path.has(path): errors.append("SOURCE_MISSING: " + path)
	for unexpected: Variant in source_by_path.keys():
		if not unexpected in SOURCE_PATHS: errors.append("SOURCE_UNEXPECTED: " + str(unexpected))
	for record: Dictionary in evidence.preserved_outside_authority:
		_validate_base64_hash(record, "content_base64", "sha256", "byte_length", "preserved:" + str(record.path), errors)
	_validate_commands(evidence, errors)
	_validate_logs(evidence, errors)
	_validate_inventory(evidence, source_by_path, errors)
	if not _primitive_only(evidence): errors.append("EVIDENCE_NONPRIMITIVE")

static func _validate_archive_record(record: Dictionary, label: String, errors: Array[String]) -> void:
	_validate_base64_hash(record, "content_base64", "sha256", "byte_length", label + ":" + str(record.path), errors)
	var content_bytes := Marshalls.base64_to_raw(str(record.content_base64))
	if content_bytes.get_string_from_utf8() != str(record.content_utf8) or str(record.content_utf8).to_utf8_buffer() != content_bytes:
		errors.append("UTF8_BASE64_DISAGREEMENT: " + str(record.path))
	_validate_base64_hash(record, "working_tree_patch_base64", "working_tree_patch_sha256", "", "patch:" + str(record.path), errors)
	var patch_bytes := Marshalls.base64_to_raw(str(record.working_tree_patch_base64))
	if patch_bytes.get_string_from_utf8() != str(record.working_tree_patch_utf8) or str(record.working_tree_patch_utf8).to_utf8_buffer() != patch_bytes:
		errors.append("PATCH_UTF8_BASE64_DISAGREEMENT: " + str(record.path))

static func _validate_base64_hash(record: Dictionary, bytes_key: String, hash_key: String, length_key: String, label: String, errors: Array[String]) -> void:
	var encoded := str(record[bytes_key])
	var bytes := Marshalls.base64_to_raw(encoded)
	if Marshalls.raw_to_base64(bytes) != encoded: errors.append("BASE64_INVALID: " + label)
	if not length_key.is_empty() and bytes.size() != int(record[length_key]): errors.append("BYTE_LENGTH_MISMATCH: " + label)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	var digest := context.finish().hex_encode()
	if RegEx.create_from_string(SHA256_PATTERN).search(str(record[hash_key])) == null or digest != str(record[hash_key]):
		errors.append("SHA256_MISMATCH: " + label)

static func _validate_commands(evidence: Dictionary, errors: Array[String]) -> void:
	for command: Dictionary in evidence.commands:
		var root := str(command.test_root).replace("\\", "/").trim_suffix("/").to_lower()
		var user_dir := str(command.user_dir).replace("\\", "/").to_lower()
		if not user_dir.begins_with(root + "/"): errors.append("COMMAND_USER_DIR_OUTSIDE_ROOT: " + str(command.suite_id))
		if int(command.exit_code) != 0 and not command.suite_id in ["baseline-existing-gut", "baseline-existing-scenes"]:
			errors.append("COMMAND_EXIT_NONZERO: " + str(command.suite_id))
		if int(command.exit_code) != 0:
			var matched := false
			for diagnostic: Dictionary in evidence.diagnostics:
				matched = matched or (diagnostic.get("suite_id") == command.suite_id and int(diagnostic.get("exit_code", -1)) == int(command.exit_code) and diagnostic.has("log_sha256"))
			if not matched: errors.append("COMMAND_DIAGNOSTIC_MISSING: " + str(command.suite_id))

static func _validate_logs(evidence: Dictionary, errors: Array[String]) -> void:
	for record: Dictionary in evidence.archived_logs:
		if not FileAccess.file_exists("res://" + str(record.evidence_log_path)): errors.append("ARCHIVED_LOG_MISSING: " + str(record.evidence_log_path)); continue
		var bytes := FileAccess.get_file_as_bytes("res://" + str(record.evidence_log_path))
		if bytes.size() != int(record.byte_length): errors.append("ARCHIVED_LOG_LENGTH: " + str(record.evidence_log_path))
		var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
		if context.finish().hex_encode() != str(record.sha256): errors.append("ARCHIVED_LOG_SHA256: " + str(record.evidence_log_path))

static func _validate_inventory(evidence: Dictionary, sources: Dictionary, errors: Array[String]) -> void:
	var binding: Dictionary = evidence.legacy_heading_inventory
	var inventory_path := "res://" + str(binding.path)
	var parsed := _parse_utf8_file(inventory_path)
	if not parsed.errors.is_empty(): errors.append_array(parsed.errors); return
	var inventory_bytes := FileAccess.get_file_as_bytes(inventory_path)
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(inventory_bytes)
	if context.finish().hex_encode() != str(binding.sha256): errors.append("INVENTORY_SHA256_MISMATCH")
	var expected: Array[Dictionary] = []
	var zero_paths: Array[String] = []
	for path: String in SOURCE_PATHS:
		var extracted := _extract_atx_headings(Marshalls.base64_to_raw(str(sources[path].content_base64)), path, str(sources[path].sha256))
		expected.append_array(extracted.headings)
		if extracted.headings.is_empty(): zero_paths.append(path)
	if JSON.stringify(expected) != JSON.stringify(parsed.value.headings): errors.append("INVENTORY_HEADING_BIJECTION")
	var expected_zero: Array[Dictionary] = []
	for path: String in zero_paths: expected_zero.append({"path": path, "source_sha256": str(sources[path].sha256)})
	if JSON.stringify(parsed.value.zero_heading_documents) != JSON.stringify(expected_zero): errors.append("INVENTORY_ZERO_HEADING_BIJECTION")
	var expected_documents: Array[Dictionary] = []
	for path: String in SOURCE_PATHS:
		var heading_count := 0
		for heading: Dictionary in expected:
			if heading.source_path == path: heading_count += 1
		expected_documents.append({"path": path, "sha256": str(sources[path].sha256), "byte_length": int(sources[path].byte_length), "heading_count": heading_count})
	if JSON.stringify(parsed.value.source_documents) != JSON.stringify(expected_documents): errors.append("INVENTORY_SOURCE_DOCUMENT_DRIFT")
	if int(binding.heading_count) != expected.size() or int(binding.document_count) != SOURCE_PATHS.size(): errors.append("INVENTORY_COUNT_MISMATCH")

static func _extract_atx_headings(bytes: PackedByteArray, path: String, source_sha: String) -> Dictionary:
	var headings: Array[Dictionary] = []
	var offset := 0
	var line_number := 1
	var fence := ""
	while offset < bytes.size():
		var end := offset
		while end < bytes.size() and bytes[end] != 0x0a: end += 1
		var content_end := end - 1 if end > offset and bytes[end - 1] == 0x0d else end
		var line_bytes := bytes.slice(offset, content_end)
		var line := line_bytes.get_string_from_utf8()
		var fence_match := RegEx.create_from_string("^\\s*(`{3,}|~{3,})").search(line)
		if fence_match != null:
			var marker: String = fence_match.get_string(1)
			if fence.is_empty(): fence = marker[0]
			elif marker[0] == fence: fence = ""
		elif fence.is_empty():
			var match := RegEx.create_from_string("^(#{1,6})[ \\t]+.*$").search(line)
			if match != null:
				var ordinal := headings.size() + 1
				var exact := line_bytes.get_string_from_utf8()
				var identity := (path + "\u0000" + source_sha + "\u0000" + str(ordinal) + "\u0000" + exact).to_utf8_buffer()
				var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(identity)
				headings.append({"heading_id": hash.finish().hex_encode(), "source_path": path, "source_sha256": source_sha, "ordinal_in_document": ordinal, "markdown_level": match.get_string(1).length(), "line_number": line_number, "byte_offset": offset, "exact_heading_utf8": exact, "exact_heading_base64": Marshalls.raw_to_base64(line_bytes)})
		offset = end + 1 if end < bytes.size() else end
		line_number += 1
	return {"headings": headings}

static func _primitive_only(value: Variant) -> bool:
	if value == null or typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]: return true
	if typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			if not _primitive_only(item): return false
		return true
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value.keys():
			if typeof(key) != TYPE_STRING or not _primitive_only(value[key]): return false
		return true
	return false
~~~

The schema written beside this code MUST use only the supported keyword set shown in `_validate_schema`; a schema containing any other keyword is a validator error, not silently ignored. Add unit cases for duplicate members in both schema and evidence, unsupported schema keywords, invalid UTF-8/BOM, malformed base64, archive byte/hash drift, inventory heading drift, a nonzero unapproved command, and a `user_dir` sibling-prefix attack such as `root-evil/user`.

`validate_evidence.gd` is the noninteractive validation entry point used by the capture script. Its complete body is:

~~~gdscript
extends SceneTree

const VALIDATOR := preload("res://tools/evidence/EvidenceValidator.gd")

func _init() -> void:
	var evidence_values: Array[String] = []
	var schema_values: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence_values.append(argument.trim_prefix("--evidence="))
		elif argument.begins_with("--schema="): schema_values.append(argument.trim_prefix("--schema="))
		else: printerr("EVIDENCE_ARGUMENT_UNKNOWN: " + argument); quit(2); return
	if evidence_values.size() != 1 or schema_values.size() != 1:
		printerr("EVIDENCE_ARGUMENT_REQUIRED: exactly one --evidence and --schema")
		quit(2)
		return
	var result := VALIDATOR.validate_file(evidence_values[0], schema_values[0])
	if not result.ok:
		printerr("EVIDENCE_INVALID: " + JSON.stringify(result.errors))
		quit(1)
		return
	print("EVIDENCE_VALIDATION: PASS")
	quit(0)
~~~

The return shape is exactly `{"ok": bool, "errors": Array[String], "evidence": Dictionary}`. Validation rejects duplicate JSON members before materialization, unknown members, invalid lowercase SHA-256 strings, nonprimitive values, invalid base64, UTF-8/base64 disagreement, hash disagreement, missing source records, heading-inventory hash drift, invalid command records, and a `user_dir` outside its command `test_root`. Command exit `0` is required except that `baseline-existing-gut` and `baseline-existing-scenes` MAY be nonzero only when a matching diagnostic contains their `suite_id`, exit code, and log SHA-256.

`evidence_report.v1.json` requires this exact top-level structure:

~~~text
schema_version = 1
evidence_id
kind = baseline
immutable = true
captured_at_utc
worktree {commit, status_porcelain_utf8, status_porcelain_base64, status_sha256}
versions {godot, dialogic, gut, beads, rg}
external_tools {codegraph_command {resolved_path, sha256, version}}
counts {game_state_lines, english_timelines, timeline_todo_markers, timelines_with_todo}
source_archive[]
preserved_outside_authority[]
legacy_heading_inventory {path, sha256, heading_count, document_count}
commands[]
archived_logs[] {suite_id, source_log_path, evidence_log_path, sha256, byte_length}
diagnostics[]
~~~

Every `source_archive[]` record has exactly:

~~~text
path
git_blob_id_or_null
byte_length
sha256
utf8_valid = true
content_utf8
content_base64
working_tree_patch_utf8
working_tree_patch_base64
working_tree_patch_sha256
~~~

The validator MUST decode `content_base64`, prove it equals the UTF-8 encoding of `content_utf8` byte-for-byte, and prove `sha256` over those bytes. It MUST likewise validate the exact raw stdout bytes returned by `git diff --binary --no-ext-diff HEAD -- $sourcePath`; the capture script uses child-process byte streams rather than a PowerShell text pipeline. The current bytes plus the HEAD blob identifier and binary patch must be sufficient to reconstruct every captured pre-migration file.

Capture these exact authority-source paths before replacing any document:

~~~text
Prompt.md
prompt_docs/INDEX.md
prompt_docs/CONTRACTS.md
prompt_docs/CONTENT.md
prompt_docs/DIALOGIC.md
prompt_docs/FLOWS.md
prompt_docs/PHASES.md
prompt_docs/REPORT.md
prompt_docs/TESTING.md
prompt_docs/GLOSSARY.md
ResultReport.md
Beads.md
~~~

Capture `CLAUDE.md` and `dialogic fx.md` separately in `preserved_outside_authority[]` with `path`, `byte_length`, `sha256`, and `content_base64`. Their presence in evidence proves preservation only; their text MUST NOT create requirements, dispositions, generated-index entries, or implementation authority.

Generate `legacy_heading_inventory.v1.json` before replacing `Prompt.md` or `prompt_docs/INDEX.md` and before deleting anything. It contains:

~~~text
schema_version = 1
immutable = true
generated_at_utc
source_documents[] {path, sha256, byte_length, heading_count}
headings[] {
  heading_id,
  source_path,
  source_sha256,
  ordinal_in_document,
  markdown_level,
  line_number,
  byte_offset,
  exact_heading_utf8,
  exact_heading_base64
}
zero_heading_documents[] {path, source_sha256}
~~~

`heading_id` is lowercase SHA-256 of the UTF-8 bytes for `source_path + "\u0000" + source_sha256 + "\u0000" + ordinal_in_document + "\u0000" + exact_heading_utf8`. Inventory order is authority-source path order, then byte offset. The validator re-reads each archived source byte sequence, extracts ATX headings outside fenced code, and proves a byte-for-byte bijection with `headings[]`. Do not hardcode the discovery-era heading count; the immutable artifact owns the exact execution-time count.

- [ ] **Step 1.6: Capture once without touching production persistence**

`capture_phase_2r_baseline.ps1` has this parameter contract:

~~~powershell
param(
    [string]$OutputPath = 'evidence/phase_2r/baseline.json',
    [string]$InventoryPath = 'evidence/phase_2r/legacy/legacy_heading_inventory.v1.json'
)
~~~

The capture script copies `Get-CanonicalPath`, `Test-StrictDescendant`, `Assert-ContainedNonReparseChain`, `New-VerifiedDirectory`, `ConvertTo-NativeArgument`, and `Assert-TreeHasNoReparsePoints` **verbatim** from the paste-ready runner body in Step 1.2. This is exact source reuse inside a standalone script, not a dot-source dependency. After those copied functions, use this line-complete archive/capture body; every native process is byte-captured, every immutable promotion is same-directory, and no existing immutable output is overwritten:

~~~powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$sha256 = [Security.Cryptography.SHA256]::Create()
$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$strictJsonReader = Get-CanonicalPath (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1')
[void](Assert-ContainedNonReparseChain $repositoryRoot $strictJsonReader -RequireStrictDescendant)
. $strictJsonReader
$authorityPaths = @(
    'Prompt.md','prompt_docs/INDEX.md','prompt_docs/CONTRACTS.md','prompt_docs/CONTENT.md',
    'prompt_docs/DIALOGIC.md','prompt_docs/FLOWS.md','prompt_docs/PHASES.md','prompt_docs/REPORT.md',
    'prompt_docs/TESTING.md','prompt_docs/GLOSSARY.md','ResultReport.md','Beads.md'
)
$preservedPaths = @('CLAUDE.md','dialogic fx.md')

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    return ([BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
}

function ConvertFrom-StrictUtf8 {
    param([byte[]]$Bytes, [string]$Label)
    try { return $utf8Strict.GetString($Bytes) }
    catch { throw "UTF8_INVALID: $Label" }
}

function Invoke-NativeBytes {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = $repositoryRoot,
        [byte[]]$StandardInput = $null
    )
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $FilePath
    $info.Arguments = [string]::Join(' ', @($Arguments | ForEach-Object { ConvertTo-NativeArgument ([string]$_) }))
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.RedirectStandardInput = $null -ne $StandardInput
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "PROCESS_START_FAILED: $FilePath" }
    if ($null -ne $StandardInput) {
        $process.StandardInput.BaseStream.Write($StandardInput, 0, $StandardInput.Length)
        $process.StandardInput.BaseStream.Flush()
        $process.StandardInput.Close()
    }
    $stdout = New-Object IO.MemoryStream
    $stderr = New-Object IO.MemoryStream
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
    $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
    $process.WaitForExit()
    $stdoutTask.GetAwaiter().GetResult()
    $stderrTask.GetAwaiter().GetResult()
    return [pscustomobject]@{
        argv = @($FilePath) + @($Arguments)
        exit_code = [int]$process.ExitCode
        stdout = $stdout.ToArray()
        stderr = $stderr.ToArray()
    }
}

function Get-NativeText {
    param([string]$FilePath, [string[]]$Arguments, [string]$Label)
    $result = Invoke-NativeBytes -FilePath $FilePath -Arguments $Arguments
    if ($result.exit_code -ne 0) { throw "$Label exit=$($result.exit_code)" }
    return (ConvertFrom-StrictUtf8 -Bytes $result.stdout -Label $Label).Trim()
}

function Get-GitBlobOrNull {
    param([string]$Path)
    $result = Invoke-NativeBytes -FilePath 'git' -Arguments @('rev-parse','--verify',('HEAD:' + $Path))
    if ($result.exit_code -ne 0) { return $null }
    $value = (ConvertFrom-StrictUtf8 $result.stdout "git blob $Path").Trim()
    if ($value -notmatch '^[0-9a-f]{40}$|^[0-9a-f]{64}$') { throw "GIT_BLOB_INVALID: $Path" }
    return $value
}

function New-SourceRecord {
    param([string]$Path)
    $full = Get-CanonicalPath (Join-Path $repositoryRoot $Path)
    if (-not (Test-StrictDescendant $repositoryRoot $full) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "SOURCE_MISSING: $Path" }
    [byte[]]$bytes = [IO.File]::ReadAllBytes($full)
    $text = ConvertFrom-StrictUtf8 $bytes $Path
    $patchResult = Invoke-NativeBytes -FilePath 'git' -Arguments @('diff','--binary','--no-ext-diff','HEAD','--',$Path)
    if ($patchResult.exit_code -ne 0) { throw "GIT_DIFF_FAILED: $Path" }
    [byte[]]$patch = $patchResult.stdout
    $patchText = ConvertFrom-StrictUtf8 $patch "git diff $Path"
    $blob = Get-GitBlobOrNull $Path
    if ($null -eq $blob -and $patch.Length -ne 0) { throw "UNTRACKED_PATCH_NOT_EMPTY: $Path" }
    return [ordered]@{
        path = $Path; git_blob_id_or_null = $blob; byte_length = $bytes.Length
        sha256 = Get-Sha256Hex $bytes; utf8_valid = $true; content_utf8 = $text
        content_base64 = [Convert]::ToBase64String($bytes)
        working_tree_patch_utf8 = $patchText
        working_tree_patch_base64 = [Convert]::ToBase64String($patch)
        working_tree_patch_sha256 = Get-Sha256Hex $patch
    }
}

function New-PreservedRecord {
    param([string]$Path)
    [byte[]]$bytes = [IO.File]::ReadAllBytes((Join-Path $repositoryRoot $Path))
    [void](ConvertFrom-StrictUtf8 $bytes $Path)
    return [ordered]@{ path = $Path; byte_length = $bytes.Length; sha256 = Get-Sha256Hex $bytes; content_base64 = [Convert]::ToBase64String($bytes) }
}

function New-HeadingInventory {
    param([object[]]$SourceRecords)
    $documents = New-Object Collections.Generic.List[object]
    $headings = New-Object Collections.Generic.List[object]
    $zero = New-Object Collections.Generic.List[object]
    foreach ($source in $SourceRecords) {
        [byte[]]$bytes = [Convert]::FromBase64String([string]$source.content_base64)
        $offset = 0; $lineNumber = 1; $ordinal = 0; $fence = $null
        while ($offset -lt $bytes.Length) {
            $lineEnd = $offset
            while ($lineEnd -lt $bytes.Length -and $bytes[$lineEnd] -ne 10) { $lineEnd += 1 }
            $contentEnd = if ($lineEnd -gt $offset -and $bytes[$lineEnd - 1] -eq 13) { $lineEnd - 1 } else { $lineEnd }
            $lineBytes = New-Object byte[] ($contentEnd - $offset)
            if ($lineBytes.Length -ne 0) { [Array]::Copy($bytes, $offset, $lineBytes, 0, $lineBytes.Length) }
            $line = ConvertFrom-StrictUtf8 $lineBytes "$($source.path):$lineNumber"
            $fenceMatch = [regex]::Match($line, '^\s*(`{3,}|~{3,})')
            if ($fenceMatch.Success) {
                $marker = $fenceMatch.Groups[1].Value.Substring(0, 1)
                if ($null -eq $fence) { $fence = $marker } elseif ($fence -ceq $marker) { $fence = $null }
            } elseif ($null -eq $fence) {
                $headingMatch = [regex]::Match($line, '^(#{1,6})[ \t]+.*$')
                if ($headingMatch.Success) {
                    $ordinal += 1
                    $identity = [string]$source.path + [char]0 + [string]$source.sha256 + [char]0 + $ordinal + [char]0 + $line
                    $headingId = Get-Sha256Hex ($utf8NoBom.GetBytes($identity))
                    $headings.Add([ordered]@{
                        heading_id = $headingId; source_path = [string]$source.path; source_sha256 = [string]$source.sha256
                        ordinal_in_document = $ordinal; markdown_level = $headingMatch.Groups[1].Value.Length
                        line_number = $lineNumber; byte_offset = $offset; exact_heading_utf8 = $line
                        exact_heading_base64 = [Convert]::ToBase64String($lineBytes)
                    })
                }
            }
            $offset = if ($lineEnd -lt $bytes.Length) { $lineEnd + 1 } else { $lineEnd }
            $lineNumber += 1
        }
        $documents.Add([ordered]@{ path = [string]$source.path; sha256 = [string]$source.sha256; byte_length = [int64]$source.byte_length; heading_count = $ordinal })
        if ($ordinal -eq 0) { $zero.Add([ordered]@{ path = [string]$source.path; source_sha256 = [string]$source.sha256 }) }
    }
    return [ordered]@{
        schema_version = 1; immutable = $true; generated_at_utc = [DateTime]::UtcNow.ToString('o')
        source_documents = @($documents); headings = @($headings); zero_heading_documents = @($zero)
    }
}

function Write-NewAtomicJson {
    param([string]$Path, [object]$Value)
    $full = Get-CanonicalPath (Join-Path $repositoryRoot $Path)
    if (Test-Path -LiteralPath $full) { throw "IMMUTABLE_OUTPUT_EXISTS: $Path" }
    New-VerifiedDirectory -RepositoryRoot $repositoryRoot -Path (Split-Path -Parent $full)
    $temporary = $full + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [void](Assert-ContainedNonReparseChain $repositoryRoot $temporary -RequireStrictDescendant)
    $json = ConvertTo-Json -InputObject $Value -Depth 100 -Compress
    [IO.File]::WriteAllBytes($temporary, $utf8NoBom.GetBytes($json + "`n"))
    $stream = New-Object IO.FileStream($temporary, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $stream.Flush($true); $stream.Dispose()
    if (Test-Path -LiteralPath $full) { throw "IMMUTABLE_PROMOTION_RACE: $Path" }
    [IO.File]::Move($temporary, $full)
}

function ConvertFrom-HelperRecord {
    param([string]$Json)
    $expected = @('suite_id','argv','exit_code','log_path','test_root','user_dir','started_at_utc','ended_at_utc')
    $keys = @([regex]::Matches($Json, '"((?:\\.|[^"\\])*)"\s*:') | ForEach-Object { ConvertFrom-Json ('"' + $_.Groups[1].Value + '"') })
    if ($keys.Count -ne $expected.Count -or [string]::Join("`n", $keys) -cne [string]::Join("`n", $expected)) { throw 'HELPER_RECORD_KEYS_OR_DUPLICATES' }
    $parsed = ConvertFrom-Json -InputObject $Json -ErrorAction Stop
    if ($null -eq $parsed.argv -or $parsed.argv -isnot [array]) { throw 'HELPER_RECORD_ARGV_INVALID' }
    return $parsed
}

function Invoke-IsolatedCapture {
    param([string]$SuiteId, [string]$LogName, [string[]]$GodotArgs, [string]$RecordPath)
    $helper = Join-Path $repositoryRoot 'tools\testing\Invoke-IsolatedGodot.ps1'
    $hostPath = (Get-Process -Id $PID).Path
    $literal = { param([string]$Value) return "'" + $Value.Replace("'", "''") + "'" }
    $godotLiterals = @($GodotArgs | ForEach-Object { & $literal ([string]$_) })
    $evidenceClause = if ([string]::IsNullOrWhiteSpace($RecordPath)) { '' } else { " -EvidenceLogPath $(& $literal $RecordPath)" }
    $command = "& $(& $literal $helper) -SuiteId $(& $literal $SuiteId) -LogName $(& $literal $LogName) -GodotArgs @($($godotLiterals -join ','))$evidenceClause"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $result = Invoke-NativeBytes -FilePath $hostPath -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
    $stdout = (ConvertFrom-StrictUtf8 $result.stdout "helper $SuiteId").Trim()
    $record = ConvertFrom-HelperRecord $stdout
    if ([int]$record.exit_code -ne [int]$result.exit_code) { throw "HELPER_EXIT_DISAGREEMENT: $SuiteId" }
    if ($result.exit_code -in @(124,125)) { throw "HELPER_ISOLATION_OR_EVIDENCE_FAILURE: $SuiteId exit=$($result.exit_code)" }
    return $record
}

function Get-PluginVersion {
    param([string]$Path, [string]$Label)
    $text = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes((Join-Path $repositoryRoot $Path))) $Path
    $matches = @([regex]::Matches($text, '(?m)^version="([^"]+)"\s*$'))
    if ($matches.Count -ne 1) { throw "PLUGIN_VERSION_INVALID: $Label" }
    return $matches[0].Groups[1].Value
}

function Get-DiscoveryCounts {
    $timelines = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'dialogic\timelines\en') -Recurse -File -Filter '*.dtl')
    $todoCount = 0; $withTodo = 0
    foreach ($timeline in $timelines) {
        $text = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes($timeline.FullName)) $timeline.FullName
        $matches = @([regex]::Matches($text, 'TODO'))
        $todoCount += $matches.Count
        if ($matches.Count -ne 0) { $withTodo += 1 }
    }
    return [ordered]@{
        game_state_lines = @([IO.File]::ReadAllLines((Join-Path $repositoryRoot 'autoload\GameState.gd'))).Count
        english_timelines = $timelines.Count; timeline_todo_markers = $todoCount; timelines_with_todo = $withTodo
    }
}

function Copy-LogRecord {
    param([object]$CommandRecord, [string]$EvidencePath)
    $source = Get-CanonicalPath ([string]$CommandRecord.log_path)
    $target = Get-CanonicalPath (Join-Path $repositoryRoot $EvidencePath)
    New-VerifiedDirectory $repositoryRoot (Split-Path -Parent $target)
    [byte[]]$bytes = [IO.File]::ReadAllBytes($source)
    [IO.File]::WriteAllBytes($target, $bytes)
    return [ordered]@{ suite_id = [string]$CommandRecord.suite_id; source_log_path = $source; evidence_log_path = $EvidencePath; sha256 = Get-Sha256Hex $bytes; byte_length = $bytes.Length }
}

function Remove-VerifiedFile {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    [void](Assert-ContainedNonReparseChain $repositoryRoot $Path -RequireStrictDescendant)
    $item = Get-Item -Force -LiteralPath $Path
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $item.PSIsContainer) { throw "PAIR_RECOVERY_UNSAFE: $Label" }
    [IO.File]::Delete($item.FullName)
    if (Test-Path -LiteralPath $Path) { throw "PAIR_RECOVERY_DELETE_FAILED: $Label" }
}

function Read-PairTransaction {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    [void](Assert-ContainedNonReparseChain $repositoryRoot $Path -RequireStrictDescendant)
    $text = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes($Path)) $Path
    $record = ConvertFrom-Phase2RStrictJson -Json $text -Label 'baseline pair transaction'
    $keys = @($record.PSObject.Properties.Name)
    $expected = @('schema_version','output_path','inventory_path','inventory_sha256','candidate_path')
    if ([string]::Join("`n", $keys) -cne [string]::Join("`n", $expected) -or [int]$record.schema_version -ne 1) {
        throw 'PAIR_TRANSACTION_SHAPE_INVALID'
    }
    return $record
}

function Write-PairTransaction {
    param([string]$Path, [string]$OutputFull, [string]$InventoryFull, [string]$InventorySha256, [string]$CandidateFull)
    if (Test-Path -LiteralPath $Path) { throw 'PAIR_TRANSACTION_ALREADY_EXISTS' }
    New-VerifiedDirectory $repositoryRoot (Split-Path -Parent $Path)
    $record = [ordered]@{
        schema_version = 1; output_path = $OutputFull; inventory_path = $InventoryFull
        inventory_sha256 = $InventorySha256; candidate_path = $CandidateFull
    }
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [void](Assert-ContainedNonReparseChain $repositoryRoot $temporary -RequireStrictDescendant)
    [IO.File]::WriteAllBytes($temporary, $utf8NoBom.GetBytes((ConvertTo-Json $record -Depth 4 -Compress) + "`n"))
    [IO.File]::Move($temporary, $Path)
}

function Recover-PairTransaction {
    param([string]$MarkerPath, [string]$OutputFull, [string]$InventoryFull)
    $outputExistsNow = Test-Path -LiteralPath $OutputFull -PathType Leaf
    $inventoryExistsNow = Test-Path -LiteralPath $InventoryFull -PathType Leaf
    $record = Read-PairTransaction $MarkerPath
    if ($null -eq $record) {
        if ($outputExistsNow -xor $inventoryExistsNow) { throw 'IMMUTABLE_PAIR_PARTIAL_WITHOUT_TRANSACTION' }
        return
    }
    if ((Get-CanonicalPath ([string]$record.output_path)) -cne $OutputFull -or
        (Get-CanonicalPath ([string]$record.inventory_path)) -cne $InventoryFull) { throw 'PAIR_TRANSACTION_PATH_DRIFT' }
    $candidateFull = Get-CanonicalPath ([string]$record.candidate_path)
    [void](Assert-ContainedNonReparseChain $repositoryRoot $candidateFull -RequireStrictDescendant)
    if ($outputExistsNow -and -not $inventoryExistsNow) { throw 'PAIR_TRANSACTION_BASELINE_WITHOUT_INVENTORY' }
    if (-not $outputExistsNow -and $inventoryExistsNow) {
        [byte[]]$inventoryBytes = [IO.File]::ReadAllBytes($InventoryFull)
        if ((Get-Sha256Hex $inventoryBytes) -cne [string]$record.inventory_sha256) { throw 'PAIR_TRANSACTION_INVENTORY_HASH_DRIFT' }
        Remove-VerifiedFile $InventoryFull 'inventory'
    }
    if (-not $outputExistsNow) { Remove-VerifiedFile $candidateFull 'baseline candidate' }
    Remove-VerifiedFile $MarkerPath 'transaction marker'
}
~~~

The main branch immediately following those functions is exact and has only the two states below:

~~~powershell
$outputFull = Get-CanonicalPath (Join-Path $repositoryRoot $OutputPath)
$inventoryFull = Get-CanonicalPath (Join-Path $repositoryRoot $InventoryPath)
$pairMarker = Get-CanonicalPath (Join-Path $repositoryRoot '.godot\phase2r_capture\baseline-pair-transaction.json')
Recover-PairTransaction $pairMarker $outputFull $inventoryFull
$outputExists = Test-Path -LiteralPath $outputFull -PathType Leaf
$inventoryExists = Test-Path -LiteralPath $inventoryFull -PathType Leaf
if ($outputExists -xor $inventoryExists) { throw 'IMMUTABLE_PAIR_PARTIAL' }

if (-not $outputExists) {
    $sources = @($authorityPaths | ForEach-Object { New-SourceRecord $_ })
    $preserved = @($preservedPaths | ForEach-Object { New-PreservedRecord $_ })
    $inventory = New-HeadingInventory $sources
    $inventoryCandidateBytes = $utf8NoBom.GetBytes((ConvertTo-Json $inventory -Depth 100 -Compress) + "`n")
    $candidateRelative = $OutputPath + '.' + [guid]::NewGuid().ToString('N') + '.candidate'
    $candidateFull = Get-CanonicalPath (Join-Path $repositoryRoot $candidateRelative)
    Write-PairTransaction $pairMarker $outputFull $inventoryFull (Get-Sha256Hex $inventoryCandidateBytes) $candidateFull
    Write-NewAtomicJson -Path $InventoryPath -Value $inventory
    [byte[]]$inventoryBytes = [IO.File]::ReadAllBytes($inventoryFull)
    if ((Get-Sha256Hex $inventoryBytes) -cne (Get-Sha256Hex $inventoryCandidateBytes)) { throw 'PAIR_TRANSACTION_INVENTORY_SERIALIZATION_DRIFT' }

    $captureParent = Join-Path $repositoryRoot '.godot\phase2r_capture'
    New-VerifiedDirectory $repositoryRoot $captureParent
    $captureRoot = Join-Path $captureParent ([guid]::NewGuid().ToString('D').ToLowerInvariant())
    New-VerifiedDirectory $repositoryRoot $captureRoot
    $recordsPath = Join-Path $captureRoot 'records.jsonl'
    try {
        $commands = @(
            Invoke-IsolatedCapture 'baseline-import' 'baseline-import.log' @('--editor','--quit-after','1') $recordsPath
            Invoke-IsolatedCapture 'baseline-existing-gut' 'baseline-gut.log' @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests/unit','-ginclude_subdirs','-gexit') $recordsPath
            Invoke-IsolatedCapture 'baseline-existing-scenes' 'baseline-scenes.log' @('-s','res://tests/smoke_load_scenes.gd') $recordsPath
        )
        $recordLines = @([IO.File]::ReadAllLines($recordsPath, $utf8Strict) | Where-Object { $_.Length -ne 0 })
        if ($recordLines.Count -ne 3) { throw "CAPTURE_RECORD_COUNT: $($recordLines.Count)" }
        $parsedRecordLines = @($recordLines | ForEach-Object { ConvertFrom-HelperRecord $_ })
        if ([string]::Join("`n", @($commands.suite_id)) -cne [string]::Join("`n", @($parsedRecordLines.suite_id))) { throw 'CAPTURE_RECORD_ORDER_DRIFT' }
        $archivedLogs = @(
            Copy-LogRecord $commands[0] 'evidence/phase_2r/logs/baseline-import.log'
            Copy-LogRecord $commands[1] 'evidence/phase_2r/logs/baseline-gut.log'
            Copy-LogRecord $commands[2] 'evidence/phase_2r/logs/baseline-scenes.log'
        )
        $diagnostics = @()
        foreach ($index in 0..2) {
            if ([int]$commands[$index].exit_code -ne 0) {
                $diagnostics += [ordered]@{ suite_id = [string]$commands[$index].suite_id; exit_code = [int]$commands[$index].exit_code; log_sha256 = [string]$archivedLogs[$index].sha256 }
            }
        }
        if ([int]$commands[0].exit_code -ne 0) { throw 'BASELINE_IMPORT_FAILED' }

        $status = Invoke-NativeBytes 'git' @('status','--porcelain=v1')
        if ($status.exit_code -ne 0) { throw 'GIT_STATUS_FAILED' }
        $commit = Get-NativeText 'git' @('rev-parse','HEAD') 'git rev-parse HEAD'
        $bdVersion = Get-NativeText 'bd' @('--version') 'bd --version'
        $rgVersion = Get-NativeText 'rg' @('--version') 'rg --version'
        $codegraphCommand = (Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop).Source
        [byte[]]$codegraphBytes = [IO.File]::ReadAllBytes($codegraphCommand)
        $codegraphVersion = Get-NativeText $codegraphCommand @('--version') 'codegraph --version'
        $importLogText = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'evidence\phase_2r\logs\baseline-import.log'))) 'baseline-import.log'
        $godotMatch = [regex]::Match($importLogText, '(?m)^Godot Engine v([^\s]+)')
        if (-not $godotMatch.Success) { throw 'GODOT_VERSION_NOT_IN_IMPORT_LOG' }
        $baseline = [ordered]@{
            schema_version = 1; evidence_id = 'phase_2r.pre_migration'; kind = 'baseline'; immutable = $true
            captured_at_utc = [DateTime]::UtcNow.ToString('o')
            worktree = [ordered]@{ commit = $commit; status_porcelain_utf8 = ConvertFrom-StrictUtf8 $status.stdout 'git status'; status_porcelain_base64 = [Convert]::ToBase64String($status.stdout); status_sha256 = Get-Sha256Hex $status.stdout }
            versions = [ordered]@{ godot = $godotMatch.Groups[1].Value; dialogic = Get-PluginVersion 'addons/dialogic/plugin.cfg' 'Dialogic'; gut = Get-PluginVersion 'addons/gut/plugin.cfg' 'GUT'; beads = $bdVersion; rg = ($rgVersion -split "`r?`n")[0] }
            external_tools = [ordered]@{ codegraph_command = [ordered]@{ resolved_path = Get-CanonicalPath $codegraphCommand; sha256 = Get-Sha256Hex $codegraphBytes; version = $codegraphVersion } }
            counts = Get-DiscoveryCounts
            source_archive = $sources; preserved_outside_authority = $preserved
            legacy_heading_inventory = [ordered]@{ path = $InventoryPath.Replace('\','/'); sha256 = Get-Sha256Hex $inventoryBytes; heading_count = @($inventory.headings).Count; document_count = @($inventory.source_documents).Count }
            commands = @($commands); archived_logs = @($archivedLogs); diagnostics = @($diagnostics)
        }
        Write-NewAtomicJson $candidateRelative $baseline
        $validation = Invoke-IsolatedCapture 'baseline-candidate-validation' 'baseline-candidate-validation.log' @('-s','res://tools/evidence/validate_evidence.gd','--',('--evidence=res://' + $candidateRelative.Replace('\','/')), '--schema=res://prompt_docs/schemas/evidence_report.v1.json') $recordsPath
        if ([int]$validation.exit_code -ne 0) { throw 'BASELINE_CANDIDATE_INVALID' }
        if (Test-Path -LiteralPath $outputFull) { throw 'BASELINE_PROMOTION_RACE' }
        [IO.File]::Move($candidateFull, $outputFull)
        Remove-VerifiedFile $pairMarker 'committed transaction marker'
    } finally {
        if (Test-Path -LiteralPath $captureRoot) {
            [void](Assert-ContainedNonReparseChain $captureParent $captureRoot -RequireStrictDescendant)
            Assert-TreeHasNoReparsePoints $captureRoot
            Remove-Item -LiteralPath $captureRoot -Recurse -Force
            if (Test-Path -LiteralPath $captureRoot) { throw 'CAPTURE_CLEANUP_FAILED' }
        }
    }
}

$verification = Invoke-IsolatedCapture 'baseline-verify' 'baseline-verify.log' @('-s','res://tools/evidence/validate_evidence.gd','--',('--evidence=res://' + $OutputPath.Replace('\','/')),'--schema=res://prompt_docs/schemas/evidence_report.v1.json') ''
if ([int]$verification.exit_code -ne 0) { throw 'BASELINE_VERIFY_FAILED' }
Assert-ArchiveReconstructs -BaselinePath $outputFull -InventoryPath $inventoryFull
Write-Output ("PHASE2R_ARCHIVE: PASS sources={0}" -f $authorityPaths.Count)
~~~

`Assert-ArchiveReconstructs` is the final required body. It uses the same exact scratch-chain functions already copied at the top and never writes outside its one GUID child:

~~~powershell
function Assert-ArchiveReconstructs {
    param([string]$BaselinePath, [string]$InventoryPath)
    $baselineText = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes($BaselinePath)) $BaselinePath
    $baseline = ConvertFrom-Phase2RStrictJson -Json $baselineText -Label $BaselinePath
    $scratchParent = Join-Path $repositoryRoot '.godot\phase2r_archive_verify'
    New-VerifiedDirectory $repositoryRoot $scratchParent
    $scratch = Join-Path $scratchParent ([guid]::NewGuid().ToString('D').ToLowerInvariant())
    New-VerifiedDirectory $repositoryRoot $scratch
    try {
        foreach ($source in @($baseline.source_archive)) {
            $target = Get-CanonicalPath (Join-Path $scratch ([string]$source.path))
            [void](Assert-ContainedNonReparseChain $scratch $target -RequireStrictDescendant)
            New-VerifiedDirectory $scratch (Split-Path -Parent $target)
            [byte[]]$expected = [Convert]::FromBase64String([string]$source.content_base64)
            if ($expected.Length -ne [int64]$source.byte_length -or (Get-Sha256Hex $expected) -cne [string]$source.sha256) { throw "ARCHIVE_CONTENT_INVALID: $($source.path)" }
            if ($null -eq $source.git_blob_id_or_null) {
                [byte[]]$patch = [Convert]::FromBase64String([string]$source.working_tree_patch_base64)
                if ($patch.Length -ne 0) { throw "ARCHIVE_NULL_BLOB_PATCH: $($source.path)" }
                [IO.File]::WriteAllBytes($target, $expected)
            } else {
                $blob = Invoke-NativeBytes 'git' @('cat-file','blob',[string]$source.git_blob_id_or_null)
                if ($blob.exit_code -ne 0) { throw "ARCHIVE_BLOB_MISSING: $($source.path)" }
                [IO.File]::WriteAllBytes($target, $blob.stdout)
                [byte[]]$patch = [Convert]::FromBase64String([string]$source.working_tree_patch_base64)
                if ($patch.Length -ne 0) {
                    $apply = Invoke-NativeBytes 'git' @('apply','--binary','--no-index','--unsafe-paths','-') $scratch $patch
                    if ($apply.exit_code -ne 0) { throw "ARCHIVE_PATCH_FAILED: $($source.path)" }
                }
            }
            [byte[]]$actual = [IO.File]::ReadAllBytes($target)
            if ([Convert]::ToBase64String($actual) -cne [Convert]::ToBase64String($expected)) { throw "ARCHIVE_RECONSTRUCTION_MISMATCH: $($source.path)" }
        }
        $rebuiltInventory = New-HeadingInventory @($baseline.source_archive)
        $inventoryText = ConvertFrom-StrictUtf8 ([IO.File]::ReadAllBytes($InventoryPath)) $InventoryPath
        $recordedInventory = ConvertFrom-Phase2RStrictJson -Json $inventoryText -Label $InventoryPath
        $rebuiltInventory.generated_at_utc = [string]$recordedInventory.generated_at_utc
        if ((ConvertTo-Json $rebuiltInventory -Depth 100 -Compress) -cne (ConvertTo-Json $recordedInventory -Depth 100 -Compress)) { throw 'ARCHIVE_INVENTORY_RECONSTRUCTION_MISMATCH' }
    } finally {
        if (Test-Path -LiteralPath $scratch) {
            [void](Assert-ContainedNonReparseChain $scratchParent $scratch -RequireStrictDescendant)
            Assert-TreeHasNoReparsePoints $scratch
            Remove-Item -LiteralPath $scratch -Recurse -Force
            if (Test-Path -LiteralPath $scratch) { throw 'ARCHIVE_SCRATCH_CLEANUP_FAILED' }
        }
    }
}
~~~

Place `Assert-ArchiveReconstructs` before the main branch when assembling the file. The apparent later presentation above is only to keep the main state machine readable; PowerShell function definitions are all loaded before the first main statement.

The script MUST:

1. Refuse a partial existing pair. When both immutable outputs already exist, enter verify-only mode: never overwrite either artifact, strict-validate both, and perform the reconstruction proof below. A new capture requires a new schema/versioned filename and plan amendment.
2. Capture `git rev-parse HEAD`, exact `git status --porcelain=v1` bytes, the twelve authority sources, the two preserved-outside-authority files, and exact per-path binary diffs before any replacement.
3. Create and validate the heading inventory first, then bind its SHA-256 and counts into `baseline.json`.
4. Capture exact Godot, Dialogic, GUT, Beads, and `rg` versions. Resolve `codegraph.cmd` read-only and capture its absolute path, file SHA-256, and version so Task 5 can prove repository cleanup did not modify the global tool.
5. Record discovery counts without turning them into behavioral pass claims. The expected comparison observations are 1,596 GameState lines, 61 English timelines, 91 TODO markers, and 24 timelines containing TODO; differences become diagnostics, not silent normalization.
6. Create one private capture-record JSONL file beneath `.godot/phase2r_capture/`. Invoke `Invoke-IsolatedGodot.ps1` with these exact records, embed exactly these three parsed records in `baseline.json.commands`, copy each raw helper log from `.godot/phase2r_logs/` to its exact `evidence/phase_2r/logs/` path, and bind both paths plus byte length/SHA-256 in `archived_logs[]`. Remove the private JSONL only after schema and copied-log validation:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'baseline-import' -LogName 'baseline-import.log' -GodotArgs @('--editor','--quit-after','1') -EvidenceLogPath $captureRecordsPath
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'baseline-existing-gut' -LogName 'baseline-gut.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests/unit','-ginclude_subdirs','-gexit') -EvidenceLogPath $captureRecordsPath
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'baseline-existing-scenes' -LogName 'baseline-scenes.log' -GodotArgs @('-s','res://tests/smoke_load_scenes.gd') -EvidenceLogPath $captureRecordsPath
~~~

The general `evidence/phase_2r/logs/isolated-godot.jsonl` may contain RED/GREEN task executions and is never imported wholesale into immutable baseline commands.
7. Preserve historical behavioral failures as diagnostics. Isolation failure, evidence-schema failure, or inability to capture exact source bytes is fatal.
8. Write a temporary UTF-8-without-BOM candidate, strict-validate it, and use a same-directory atomic promotion only when `baseline.json` does not exist.
9. For both a new capture and verify-only mode, create one GUID scratch child beneath `.godot/phase2r_archive_verify/` using the complete non-reparse creation/cleanup chain from Step 1.2. For each `source_archive` record, decode `content_base64` and prove its byte length/SHA-256. When `git_blob_id_or_null` is nonnull, obtain those exact base bytes with `git cat-file blob <id>`, write only inside the scratch tree, apply the archived raw `working_tree_patch_base64` bytes there with `git apply --binary --no-index --unsafe-paths` (or copy the base unchanged when the patch is zero bytes), and require the reconstructed bytes to equal `content_base64`. For a null blob, require an empty patch and reconstruct directly from the archived content bytes. Validate the inventory against those reconstructed source bytes, remove only the verified GUID scratch child, and print exactly `PHASE2R_ARCHIVE: PASS sources=<count>` after cleanup. A schema, base-blob, patch-application, byte-equality, inventory, reparse, or cleanup failure is fatal.

Run:

~~~powershell
& .\tools\evidence\capture_phase_2r_baseline.ps1
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task1-evidence-green' -LogName 'phase2r-green-evidence.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_evidence_contract.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected GREEN: `3/3 passed`; `PHASE2R_ARCHIVE: PASS sources=12`; both immutable artifacts validate; all command user directories are strict descendants of their GUID roots. Existing behavioral defects may remain recorded in baseline diagnostics.

- [ ] **Step 1.7: Path-specific proposed archival commit boundary**

Do not run this block without explicit authority to commit exactly these evidence/tooling paths. The shared helper requires an empty index, exact regular-blob status/modes, no partial or copy/rename records, and a sole direct-child commit; it never unstages someone else's work.

~~~powershell
$required = [ordered]@{
  'tools/testing/Invoke-IsolatedGodot.ps1'='A'
  'tests/tooling/Test-InvokeIsolatedGodot.ps1'='A'
  'tools/testing/Read-StrictJson.ps1'='A'
  'tests/tooling/Test-ReadStrictJson.ps1'='A'
  'tools/git/Invoke-ExactPathCommit.ps1'='A'
  'tests/tooling/test_invoke_exact_path_commit.ps1'='A'
  'tests/unit/tooling/test_exact_path_commit.gd'='A'
  'tools/evidence/capture_phase_2r_baseline.ps1'='A'
  'tools/evidence/print_user_dir.gd'='A'
  'tools/evidence/EvidenceValidator.gd'='A'
  'tools/evidence/validate_evidence.gd'='A'
  'prompt_docs/schemas/evidence_report.v1.json'='A'
  'tests/unit/tooling/test_evidence_contract.gd'='A'
  'evidence/phase_2r/baseline.json'='A'
  'evidence/phase_2r/legacy/legacy_heading_inventory.v1.json'='A'
  'evidence/phase_2r/logs/baseline-import.log'='A'
  'evidence/phase_2r/logs/baseline-gut.log'='A'
  'evidence/phase_2r/logs/baseline-scenes.log'='A'
  'evidence/phase_2r/logs/isolated-godot.jsonl'='A'
}
$optionalUids = [ordered]@{
  'tests/unit/tooling/test_exact_path_commit.gd.uid'='A'
  'tools/evidence/print_user_dir.gd.uid'='A'
  'tools/evidence/EvidenceValidator.gd.uid'='A'
  'tools/evidence/validate_evidence.gd.uid'='A'
  'tests/unit/tooling/test_evidence_contract.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Task 1 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -WhitespaceExemptPaths @('evidence/phase_2r/logs/baseline-import.log','evidence/phase_2r/logs/baseline-gut.log','evidence/phase_2r/logs/baseline-scenes.log') -ExpectedHead $expectedHead -Message 'test(tooling): archive immutable Phase 2R baseline'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 1 archival commit boundary failed.' }
~~~

After an authorized commit, resolve exactly one lowercase commit object ID with `git rev-parse --verify HEAD^{commit}` and append exactly `phase2r_archive_commit=<object-id>` to `dwm-p2r.1` notes with `bd update dwm-p2r.1 --append-notes`; refuse to append if that key already exists. Without that authority, retain the artifacts unmodified and do not perform the deletion substeps in Task 4.

## Task 2: Build requirement packets, Beads metadata, and generated context lookup

**Beads:** `dwm-p2r.1`

**Files:**

- Create: `prompt_docs/schemas/document_packet.v1.json`
- Create: `prompt_docs/schemas/legacy_disposition.v1.json`
- Create: `prompt_docs/schemas/phase_2r_beads_metadata.v1.json`
- Create: `prompt_docs/metadata/phase_2r_beads.v1.json`
- Create: `prompt_docs/phases/phase_2r.md`
- Create: `prompt_docs/requirements/authority_context.md`
- Create: `prompt_docs/requirements/documentation_tooling.md`
- Create: `prompt_docs/requirements/runtime_ownership.md`
- Create: `prompt_docs/requirements/run_lifecycle.md`
- Create: `prompt_docs/requirements/dating_endings.md`
- Create: `prompt_docs/requirements/contacts_invitations.md`
- Create: `prompt_docs/requirements/persistence.md`
- Create: `prompt_docs/requirements/dialogic_skip.md`
- Create: `prompt_docs/requirements/desktop_minesweeper_handoff.md`
- Create: `prompt_docs/requirements/audio_preferences.md`
- Create: `prompt_docs/requirements/localization.md`
- Create: `prompt_docs/requirements/verification.md`
- Create: `prompt_docs/decisions/narrative_localization_adapter.md`
- Create: `tools/beads/Export-BeadsSnapshot.ps1`
- Create: `tools/beads/Sync-Phase2RMetadata.ps1`
- Create: `tests/tooling/Test-ExportBeadsSnapshot.ps1`
- Create: `tests/tooling/Test-SyncPhase2RMetadata.ps1`
- Create: `tools/docs/DocFrontmatter.gd`
- Create: `tools/docs/DocValidator.gd`
- Create: `tools/docs/DocIndexGenerator.gd`
- Create: `tools/docs/validate_docs.gd`
- Create: `tools/docs/generate_index.gd`
- Create: `tests/unit/tooling/test_doc_frontmatter.gd`
- Create: `tests/unit/tooling/test_doc_validator.gd`
- Create: `tests/fixtures/docs/valid_packet.md`
- Create: `tests/fixtures/docs/missing_section.md`
- Create: `tests/fixtures/docs/duplicate_section.md`
- Create: `tests/fixtures/docs/missing_dependency.md`
- Create: `tests/fixtures/docs/dependency_cycle_a.md`
- Create: `tests/fixtures/docs/dependency_cycle_b.md`
- Create: `tests/fixtures/docs/approved_placeholder.md`
- Create: `tests/fixtures/docs/beads_metadata_drift.md`
- Modify after Task 1 archive exists: `Prompt.md`
- Replace generated output after Task 1 archive exists: `prompt_docs/INDEX.md`

**Interfaces:**

- Consumes: Task 1 immutable source archive and heading inventory; `Invoke-IsolatedGodot.ps1`; read-only Beads array exported by the exact command `bd list --status all --json --readonly`.
- Produces: `DocFrontmatter.parse_text(text: String, source_path: String = "<memory>") -> Dictionary`; `DocFrontmatter.parse_file(path: String) -> Dictionary`; `DocValidator.validate_tree(docs_root: String = "res://prompt_docs", beads_snapshot: Array[Dictionary] = []) -> Dictionary`; `DocIndexGenerator.render(validation_result: Dictionary) -> String`; `DocIndexGenerator.write_index(path: String, content: String) -> Error`; exact metadata for every `dwm-p2r.1` through `dwm-p2r.10` child; validation and metadata binding for existing deferred decision `dwm-eob`.

- [ ] **Step 2.1: Write parser, graph, snapshot, and Beads-metadata tests first**

Tests MUST prove these stable error codes:

~~~text
DOC_FRONTMATTER_MISSING
DOC_FRONTMATTER_INVALID
DOC_SCHEMA_UNKNOWN_FIELD
DOC_REQUIREMENT_SECTION_MISSING
DOC_REQUIREMENT_SECTION_DUPLICATE
DOC_BODY_UNREGISTERED
DOC_DEPENDENCY_MISSING
DOC_DEPENDENCY_CYCLE
DOC_APPROVED_PLACEHOLDER
DOC_BEAD_UNKNOWN
DOC_BEAD_SNAPSHOT_REQUIRED
DOC_BEAD_SNAPSHOT_INVALID
DOC_BEAD_METADATA_DRIFT
DOC_INDEX_DRIFT
~~~

Use this strict fixture:

~~~yaml
---
id: req_packet.run_lifecycle
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.4"]
requirements:
  - {"id":"req.run.day_range","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
---

# Run Lifecycle

## Rule req.run.day_range

The active run day MUST be an integer from 1 through 7.
~~~

The subset accepts top-level `key: JSON-compatible scalar/array` plus `requirements:` followed by `- {JSON object}`. It rejects anchors, aliases, tags, multiline scalars, duplicate keys, implicit dates, tabs, and arbitrary nested YAML.

The same tests strict-parse the complete `phase_2r_beads.v1.json` object shown in Step 2.4, assert its exact four top-level keys and ten-child/one-decision cardinality, and reject an array-shaped manifest. Decision fixtures require `kind: decision_packet`, `specification_status: deferred`, and `decision_status: decision_required`; using `decision_required` as `specification_status`, omitting `decision_status`, or placing `decision_status` on another packet kind is RED.

`test_doc_frontmatter.gd` is runnable before either implementation and begins with this complete RED seam:

~~~gdscript
extends "res://addons/gut/test.gd"

const PARSER_PATH := "res://tools/docs/DocFrontmatter.gd"

func test_strict_frontmatter_contract() -> void:
	var parser: Script = load(PARSER_PATH)
	assert_not_null(parser, "DocFrontmatter.gd must exist")
	if parser == null: return
	var valid := "---\nid: req_packet.run_lifecycle\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: [\"dwm-p2r.4\"]\nrequirements:\n  - {\"id\":\"req.run.day_range\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Run Lifecycle\n\n## Rule req.run.day_range\n\nThe active run day MUST be an integer from 1 through 7.\n"
	var result: Dictionary = parser.parse_text(valid, "valid.md")
	assert_true(result.ok, JSON.stringify(result.errors))
	assert_eq(result.frontmatter.requirements[0].id, "req.run.day_range")
	for invalid: String in [
		valid.replace("id: req_packet.run_lifecycle", "id: a\nid: b"),
		valid.replace("schema_version: 1", "schema_version: 2026-07-17"),
		valid.replace("beads: [\"dwm-p2r.4\"]", "beads: &ids [\"dwm-p2r.4\"]"),
		valid.replace("kind: requirement_packet", "kind:\t requirement_packet"),
		valid.replace("{\"id\":\"req.run.day_range\"", "{\"id\":\"one\",\"id\":\"two\""),
	]:
		assert_false(parser.parse_text(invalid, "invalid.md").ok)
	assert_has(parser.parse_text("# no header", "missing.md").errors[0], "DOC_FRONTMATTER_MISSING")
~~~

Create the eight fixture files with the exact strict header shape above. Their complete distinguishing bodies are below; every omitted common field is copied byte-for-byte from `valid_packet.md`, and only the shown `requirements` item/body changes. This makes fixture construction mechanical rather than interpretive:

| Fixture | Requirement JSON object(s) | Markdown body after `# Fixture` |
|---|---|---|
| `valid_packet.md` | `{"id":"req.run.day_range","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}` | `## Rule req.run.day_range` then `The day MUST remain in range.` |
| `missing_section.md` | `{"id":"req.fixture.missing_section","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}` | `No rule section is present.` |
| `duplicate_section.md` | `{"id":"req.fixture.duplicate","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}` | two exact `## Rule req.fixture.duplicate` sections, each containing `The fixture MUST remain deterministic.` |
| `missing_dependency.md` | `{"id":"req.fixture.missing_dependency","depends_on":["req.fixture.absent"],"implementation_evidence":[],"verification_evidence":[]}` | `## Rule req.fixture.missing_dependency` then `The dependency MUST exist.` |
| `dependency_cycle_a.md` | `{"id":"req.fixture.cycle_a","depends_on":["req.fixture.cycle_b"],"implementation_evidence":[],"verification_evidence":[]}` | `## Rule req.fixture.cycle_a` then `A MUST follow B.` |
| `dependency_cycle_b.md` | `{"id":"req.fixture.cycle_b","depends_on":["req.fixture.cycle_a"],"implementation_evidence":[],"verification_evidence":[]}` | `## Rule req.fixture.cycle_b` then `B MUST follow A.` |
| `approved_placeholder.md` | `{"id":"req.fixture.placeholder","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}` | `## Rule req.fixture.placeholder` then `TODO: decide this later.` |
| `beads_metadata_drift.md` | `{"id":"req.fixture.beads_drift","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}` | `## Rule req.fixture.beads_drift` then `Metadata MUST agree.` |

For all fixture headers, derive a unique `id: req_packet.fixture.<basename>`, retain `kind`, `schema_version`, and `specification_status`, and use `beads: []` except `valid_packet.md` and `beads_metadata_drift.md`, which use `beads: ["dwm-p2r.4"]`. No other substitutions are allowed.

`test_doc_validator.gd` copies selected fixtures into the isolated `DWM_TEST_ROOT` and is therefore runnable without reading or writing production `user://`:

~~~gdscript
extends "res://addons/gut/test.gd"

const VALIDATOR_PATH := "res://tools/docs/DocValidator.gd"
const FIXTURES := "res://tests/fixtures/docs"
var _counter := 0

func _snapshot(requirement_ids: Array[String]) -> Array[Dictionary]:
	return [{"id": "dwm-p2r.4", "metadata": {"phase2r": {"requirement_ids": requirement_ids}}}]

func _validate_fixture(names: Array[String], snapshot: Array[Dictionary] = []) -> Dictionary:
	_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("docs-fixture-%d" % _counter)
	var requirements := root.path_join("requirements")
	assert_eq(DirAccess.make_dir_recursive_absolute(requirements), OK)
	for name: String in names:
		var bytes := FileAccess.get_file_as_bytes(FIXTURES.path_join(name))
		var output := FileAccess.open(requirements.path_join(name), FileAccess.WRITE)
		output.store_buffer(bytes); output.close()
	return load(VALIDATOR_PATH).new().validate_tree(root, snapshot)

func _has_code(result: Dictionary, code: String) -> bool:
	for error: String in result.errors:
		if error.begins_with(code): return true
	return false

func test_validator_error_matrix() -> void:
	var validator: Script = load(VALIDATOR_PATH)
	assert_not_null(validator, "DocValidator.gd must exist")
	if validator == null: return
	assert_true(_validate_fixture(["valid_packet.md"], _snapshot(["req.run.day_range"])).ok)
	assert_true(_has_code(_validate_fixture(["missing_section.md"]), "DOC_REQUIREMENT_SECTION_MISSING"))
	assert_true(_has_code(_validate_fixture(["duplicate_section.md"]), "DOC_REQUIREMENT_SECTION_DUPLICATE"))
	assert_true(_has_code(_validate_fixture(["missing_dependency.md"]), "DOC_DEPENDENCY_MISSING"))
	assert_true(_has_code(_validate_fixture(["dependency_cycle_a.md", "dependency_cycle_b.md"]), "DOC_DEPENDENCY_CYCLE"))
	assert_true(_has_code(_validate_fixture(["approved_placeholder.md"]), "DOC_APPROVED_PLACEHOLDER"))
	assert_true(_has_code(_validate_fixture(["beads_metadata_drift.md"], _snapshot(["req.wrong"])), "DOC_BEAD_METADATA_DRIFT"))
	assert_true(_has_code(_validate_fixture(["valid_packet.md"]), "DOC_BEAD_SNAPSHOT_REQUIRED"))
~~~

Create both PowerShell RED fixtures before either Beads script. `Test-ExportBeadsSnapshot.ps1` is complete and uses only a GUID-local fake command:

~~~powershell
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root 'tools\beads\Export-BeadsSnapshot.ps1'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'EXPORT_BEADS_SNAPSHOT_MISSING' }
$scratch = Join-Path $root ('.godot\phase2r_tests\' + [guid]::NewGuid().ToString('D'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
try {
    $fake = Join-Path $scratch 'bd.cmd'
    [IO.File]::WriteAllText($fake, '@echo [{"id":"one","id":"duplicate"}]', [Text.Encoding]::ASCII)
    $output = Join-Path $scratch 'snapshot.json'
    $failed = $false; $text = @()
    try { $text = @(& $script -OutputPath $output -BdCommand $fake 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('JSON_DUPLICATE_MEMBER')) {
        throw 'EXPORT_BEADS_DUPLICATE_NOT_REJECTED'
    }
    if (Test-Path -LiteralPath $output) { throw 'EXPORT_BEADS_INVALID_OUTPUT_CREATED' }
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Write-Output 'EXPORT_BEADS_FIXTURE: PASS'
~~~

`Test-SyncPhase2RMetadata.ps1` is complete; malformed duplicate input must fail before any `bd` invocation:

~~~powershell
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script = Join-Path $root 'tools\beads\Sync-Phase2RMetadata.ps1'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'SYNC_PHASE2R_METADATA_MISSING' }
$scratch = Join-Path $root ('.godot\phase2r_tests\' + [guid]::NewGuid().ToString('D'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
try {
    $manifest = Join-Path $scratch 'duplicate.json'
    [IO.File]::WriteAllText($manifest, '{"schema_version":1,"schema_version":1,"spec_id":"x","child_contracts":[],"deferred_decision_contract":{}}', (New-Object Text.UTF8Encoding($false)))
    $fake = Join-Path $scratch 'bd.cmd'
    [IO.File]::WriteAllText($fake, '@echo FAKE_BD_MUST_NOT_RUN 1>&2 & @exit /b 99', [Text.Encoding]::ASCII)
    $failed = $false; $text = @()
    try { $text = @(& $script -ManifestPath $manifest -SnapshotPath (Join-Path $scratch 'snapshot.json') -BdCommand $fake 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('JSON_DUPLICATE_MEMBER')) {
        throw 'SYNC_PHASE2R_DUPLICATE_NOT_REJECTED'
    }
    if ([string]::Join("`n", $text).Contains('FAKE_BD_MUST_NOT_RUN')) { throw 'SYNC_PHASE2R_CALLED_BD_BEFORE_VALIDATION' }
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Write-Output 'SYNC_PHASE2R_FIXTURE: PASS'
~~~

Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task2-frontmatter-red' -LogName 'phase2r-red-doc-frontmatter.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_doc_frontmatter.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task2-validator-red' -LogName 'phase2r-red-doc-validator.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_doc_validator.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tests\tooling\Test-ExportBeadsSnapshot.ps1
& .\tests\tooling\Test-SyncPhase2RMetadata.ps1
~~~

Expected RED: missing `DocFrontmatter.gd`, then missing `DocValidator.gd`, `EXPORT_BEADS_SNAPSHOT_MISSING`, and `SYNC_PHASE2R_METADATA_MISSING`. Any isolation failure or real `bd` mutation is invalid.

- [ ] **Step 2.2: Implement exact document and Beads-snapshot interfaces**

Implement:

~~~gdscript
# DocFrontmatter.gd
static func parse_text(text: String, source_path: String = "<memory>") -> Dictionary
static func parse_file(path: String) -> Dictionary

# DocValidator.gd
func validate_tree(
	docs_root: String = "res://prompt_docs",
	beads_snapshot: Array[Dictionary] = []
) -> Dictionary

# DocIndexGenerator.gd
func render(validation_result: Dictionary) -> String
func write_index(path: String, content: String) -> Error
~~~

Use the following complete parser body for `DocFrontmatter.gd`. It deliberately reuses only Task 1's tooling-only strict JSON entry point for JSON values; it does not depend on a runtime serializer:

~~~gdscript
class_name DocFrontmatter
extends RefCounted

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const KEY_PATTERN := "^[a-z][a-z0-9_]*$"
const BARE_SCALAR_PATTERN := "^[A-Za-z0-9_.-]+$"

static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(false, {}, "", ["DOC_FRONTMATTER_MISSING: " + path])
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _result(false, {}, "", ["DOC_FRONTMATTER_INVALID: invalid UTF-8 in " + path])
	return parse_text(text, path)

static func parse_text(text: String, source_path: String = "<memory>") -> Dictionary:
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	var lines := normalized.split("\n", true)
	if lines.is_empty() or lines[0] != "---":
		return _result(false, {}, normalized, ["DOC_FRONTMATTER_MISSING: " + source_path])
	var closing := -1
	for index in range(1, lines.size()):
		if lines[index] == "---": closing = index; break
	if closing < 0:
		return _result(false, {}, normalized, ["DOC_FRONTMATTER_INVALID: unterminated frontmatter in " + source_path])
	var frontmatter := {}
	var errors: Array[String] = []
	var line_index := 1
	while line_index < closing:
		var line: String = lines[line_index]
		if line.is_empty(): line_index += 1; continue
		if line.contains("\t") or line.begins_with(" "):
			errors.append("DOC_FRONTMATTER_INVALID: illegal indentation/tab at %s:%d" % [source_path, line_index + 1])
			line_index += 1; continue
		var colon := line.find(":")
		if colon <= 0:
			errors.append("DOC_FRONTMATTER_INVALID: expected key:value at %s:%d" % [source_path, line_index + 1])
			line_index += 1; continue
		var key := line.substr(0, colon)
		var raw := line.substr(colon + 1).strip_edges()
		if RegEx.create_from_string(KEY_PATTERN).search(key) == null:
			errors.append("DOC_FRONTMATTER_INVALID: invalid key %s" % key)
		elif frontmatter.has(key):
			errors.append("DOC_FRONTMATTER_INVALID: duplicate key %s" % key)
		if key == "requirements":
			if not raw.is_empty(): errors.append("DOC_FRONTMATTER_INVALID: requirements must use block JSON objects")
			var requirements: Array[Dictionary] = []
			line_index += 1
			while line_index < closing and lines[line_index].begins_with("  - "):
				var item_text := lines[line_index].substr(4)
				var parsed := STRICT_JSON.parse_strict_text(item_text)
				if not parsed.ok or typeof(parsed.value) != TYPE_DICTIONARY:
					errors.append("DOC_FRONTMATTER_INVALID: requirement JSON at %s:%d %s" % [source_path, line_index + 1, JSON.stringify(parsed.errors)])
				else: requirements.append(parsed.value)
				line_index += 1
			if requirements.is_empty(): errors.append("DOC_FRONTMATTER_INVALID: requirements list is empty")
			frontmatter[key] = requirements
			continue
		if raw.is_empty() or raw.begins_with("&") or raw.begins_with("*") or raw.begins_with("!") or raw in ["|", ">", "|-", ">-"]:
			errors.append("DOC_FRONTMATTER_INVALID: forbidden YAML feature for %s" % key)
		else:
			var parsed_value := _parse_scalar(raw)
			if not parsed_value.ok: errors.append("DOC_FRONTMATTER_INVALID: %s at %s:%d" % [parsed_value.error, source_path, line_index + 1])
			else: frontmatter[key] = parsed_value.value
		line_index += 1
	var body := "\n".join(lines.slice(closing + 1))
	return _result(errors.is_empty(), frontmatter, body, errors)

static func _parse_scalar(raw: String) -> Dictionary:
	if RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}(?:[T ].*)?$").search(raw) != null:
		return {"ok": false, "error": "implicit date forbidden", "value": null}
	if raw.begins_with("[") or raw.begins_with("{") or raw.begins_with("\"") or raw in ["true", "false", "null"] or RegEx.create_from_string("^-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?$").search(raw) != null:
		var parsed := STRICT_JSON.parse_strict_text(raw)
		return {"ok": parsed.ok, "error": JSON.stringify(parsed.errors), "value": parsed.value}
	if RegEx.create_from_string(BARE_SCALAR_PATTERN).search(raw) != null:
		return {"ok": true, "error": "", "value": raw}
	return {"ok": false, "error": "scalar is outside strict subset", "value": null}

static func _result(ok: bool, frontmatter: Dictionary, body: String, errors: Array[String]) -> Dictionary:
	return {"ok": ok, "frontmatter": frontmatter, "body": body, "errors": errors}
~~~

Use this line-complete validator body for `DocValidator.gd`; the private methods are part of the required body, not optional suggestions:

~~~gdscript
class_name DocValidator
extends RefCounted

const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
const INDEX_GENERATOR := preload("res://tools/docs/DocIndexGenerator.gd")
const PACKET_FIELDS := ["id", "kind", "schema_version", "specification_status", "decision_status", "beads", "requirements", "depends_on", "evidence", "scope", "affected_requirement_ids", "blocking_requirement_ids", "recommended_investigation"]
const REQUIREMENT_FIELDS := ["id", "depends_on", "implementation_evidence", "verification_evidence"]

func validate_tree(docs_root: String = "res://prompt_docs", beads_snapshot: Array[Dictionary] = []) -> Dictionary:
	var packet_paths: Array[String] = []
	for folder: String in ["phases", "requirements", "decisions"]:
		_collect_markdown(docs_root.path_join(folder), packet_paths)
	packet_paths.sort()
	var errors: Array[String] = []
	var packets: Array[Dictionary] = []
	var requirements: Array[Dictionary] = []
	var packet_ids := {}
	var requirement_ids := {}
	for path: String in packet_paths:
		var parsed := FRONTMATTER.parse_file(path)
		if not parsed.ok: errors.append_array(parsed.errors); continue
		var front: Dictionary = parsed.frontmatter
		for key: Variant in front.keys():
			if not key in PACKET_FIELDS: errors.append("DOC_SCHEMA_UNKNOWN_FIELD: %s in %s" % [key, path])
		var packet_id := str(front.get("id", ""))
		if packet_id.is_empty() or packet_ids.has(packet_id): errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty packet id %s" % packet_id)
		packet_ids[packet_id] = path
		var kind := str(front.get("kind", ""))
		if not kind in ["phase_packet", "requirement_packet", "decision_packet"]: errors.append("DOC_FRONTMATTER_INVALID: invalid kind in " + path)
		if int(front.get("schema_version", -1)) != 1: errors.append("DOC_FRONTMATTER_INVALID: schema_version in " + path)
		_validate_status_pair(front, path, errors)
		var packet := front.duplicate(true)
		packet["path"] = path.trim_prefix("res://")
		packet["body"] = parsed.body
		packets.append(packet)
		var registered_here := {}
		for requirement_value: Variant in front.get("requirements", []):
			if typeof(requirement_value) != TYPE_DICTIONARY: errors.append("DOC_FRONTMATTER_INVALID: non-object requirement in " + path); continue
			var requirement: Dictionary = requirement_value
			for key: Variant in requirement.keys():
				if not key in REQUIREMENT_FIELDS: errors.append("DOC_SCHEMA_UNKNOWN_FIELD: requirement.%s in %s" % [key, path])
			for required_key: String in REQUIREMENT_FIELDS:
				if not requirement.has(required_key): errors.append("DOC_FRONTMATTER_INVALID: requirement missing %s in %s" % [required_key, path])
			var requirement_id := str(requirement.get("id", ""))
			if requirement_id.is_empty() or requirement_ids.has(requirement_id): errors.append("DOC_FRONTMATTER_INVALID: duplicate/empty requirement id %s" % requirement_id)
			requirement_ids[requirement_id] = path
			registered_here[requirement_id] = true
			var enriched := requirement.duplicate(true)
			enriched["packet_id"] = packet_id
			enriched["path"] = packet.path
			enriched["specification_status"] = front.get("specification_status", "")
			requirements.append(enriched)
		_validate_rule_sections(parsed.body, registered_here, str(front.get("specification_status", "")), path, errors)
	_validate_dependencies(requirements, requirement_ids, errors)
	_validate_decisions(packets, requirement_ids, errors)
	_validate_beads(packets, requirements, beads_snapshot, errors)
	packets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	requirements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var blocked: Array[String] = _blocked_requirements(packets)
	var result := {"ok": errors.is_empty(), "packets": packets, "requirements": requirements, "errors": errors, "blocked_requirement_ids": blocked}
	if _is_authority_root(docs_root):
		var expected := INDEX_GENERATOR.new().render(result)
		var index_path := docs_root.path_join("INDEX.md")
		if not FileAccess.file_exists(index_path) or FileAccess.get_file_as_string(index_path) != expected:
			errors.append("DOC_INDEX_DRIFT: " + index_path)
		result.ok = errors.is_empty()
	return result

func _collect_markdown(path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty(): break
		if name.begins_with("."): continue
		var child := path.path_join(name)
		if directory.current_is_dir(): _collect_markdown(child, output)
		elif name.ends_with(".md"): output.append(child)
	directory.list_dir_end()

func _validate_status_pair(front: Dictionary, path: String, errors: Array[String]) -> void:
	var kind := str(front.get("kind", ""))
	if kind == "decision_packet":
		if front.get("specification_status") != "deferred" or front.get("decision_status") != "decision_required": errors.append("DOC_FRONTMATTER_INVALID: decision status pair in " + path)
	elif front.has("decision_status"): errors.append("DOC_SCHEMA_UNKNOWN_FIELD: decision_status in " + path)
	elif not front.get("specification_status") in ["approved", "deferred"]: errors.append("DOC_FRONTMATTER_INVALID: specification_status in " + path)

func _validate_rule_sections(body: String, registered: Dictionary, status: String, path: String, errors: Array[String]) -> void:
	var counts := {}
	var current_heading := ""
	var current_text := ""
	var flush_section := func() -> void:
		if current_heading.begins_with("## Rule "):
			var rule_id := current_heading.trim_prefix("## Rule ")
			counts[rule_id] = int(counts.get(rule_id, 0)) + 1
		elif RegEx.create_from_string("\\b(?:MUST(?: NOT)?|MAY)\\b").search(current_text) != null:
			errors.append("DOC_BODY_UNREGISTERED: %s in %s" % [current_heading, path])
	for line: String in body.split("\n", true):
		if line.begins_with("## "):
			flush_section.call(); current_heading = line; current_text = ""
		else: current_text += line + "\n"
	flush_section.call()
	for requirement_id: Variant in registered.keys():
		if int(counts.get(requirement_id, 0)) == 0: errors.append("DOC_REQUIREMENT_SECTION_MISSING: %s in %s" % [requirement_id, path])
		elif int(counts[requirement_id]) != 1: errors.append("DOC_REQUIREMENT_SECTION_DUPLICATE: %s in %s" % [requirement_id, path])
	for heading_id: Variant in counts.keys():
		if not registered.has(heading_id): errors.append("DOC_BODY_UNREGISTERED: %s in %s" % [heading_id, path])
	if status == "approved" and RegEx.create_from_string("(?i)\\b(?:TODO|TBD|unresolved choice)\\b|(?:^|\\n)\\s*(?:User|Assistant):").search(body) != null:
		errors.append("DOC_APPROVED_PLACEHOLDER: " + path)

func _validate_dependencies(requirements: Array[Dictionary], known: Dictionary, errors: Array[String]) -> void:
	var graph := {}
	for requirement: Dictionary in requirements:
		graph[requirement.id] = requirement.get("depends_on", [])
		for dependency: Variant in graph[requirement.id]:
			if not known.has(dependency): errors.append("DOC_DEPENDENCY_MISSING: %s -> %s" % [requirement.id, dependency])
	var colors := {}
	var visit: Callable
	visit = func(node: String, trail: Array[String]) -> void:
		if colors.get(node, 0) == 1: errors.append("DOC_DEPENDENCY_CYCLE: " + " -> ".join(trail + [node])); return
		if colors.get(node, 0) == 2: return
		colors[node] = 1
		for next: Variant in graph.get(node, []):
			if graph.has(next): visit.call(str(next), trail + [node])
		colors[node] = 2
	for node: Variant in graph.keys(): visit.call(str(node), [])

func _validate_decisions(packets: Array[Dictionary], known_requirements: Dictionary, errors: Array[String]) -> void:
	for packet: Dictionary in packets:
		if packet.kind != "decision_packet": continue
		for key: String in ["evidence", "scope", "affected_requirement_ids", "blocking_requirement_ids", "recommended_investigation"]:
			if not packet.has(key) or (typeof(packet[key]) in [TYPE_ARRAY, TYPE_STRING] and packet[key].is_empty()): errors.append("DOC_FRONTMATTER_INVALID: decision missing %s in %s" % [key, packet.path])
		for requirement_id: Variant in packet.get("affected_requirement_ids", []) + packet.get("blocking_requirement_ids", []):
			if not known_requirements.has(requirement_id): errors.append("DOC_DEPENDENCY_MISSING: decision %s -> %s" % [packet.id, requirement_id])

func _validate_beads(packets: Array[Dictionary], requirements: Array[Dictionary], snapshot: Array[Dictionary], errors: Array[String]) -> void:
	var registered := {}
	for packet: Dictionary in packets:
		for issue_id: Variant in packet.get("beads", []): registered[issue_id] = true
	if registered.is_empty(): return
	if snapshot.is_empty(): errors.append("DOC_BEAD_SNAPSHOT_REQUIRED"); return
	var issue_by_id := {}
	for issue: Dictionary in snapshot:
		if not issue.has("id") or issue_by_id.has(issue.id): errors.append("DOC_BEAD_SNAPSHOT_INVALID"); continue
		issue_by_id[issue.id] = issue
	for issue_id: Variant in registered.keys():
		if not issue_by_id.has(issue_id): errors.append("DOC_BEAD_UNKNOWN: " + str(issue_id)); continue
		var phase_metadata: Variant = issue_by_id[issue_id].get("metadata", {}).get("phase2r", null)
		if typeof(phase_metadata) != TYPE_DICTIONARY: errors.append("DOC_BEAD_METADATA_DRIFT: " + str(issue_id)); continue
		var expected_ids: Array[String] = []
		for packet: Dictionary in packets:
			if issue_id in packet.get("beads", []):
				for requirement: Variant in packet.get("requirements", []): expected_ids.append(str(requirement.id))
		expected_ids.sort()
		var actual_ids: Array = phase_metadata.get("requirement_ids", []).duplicate()
		actual_ids.sort()
		if actual_ids != expected_ids: errors.append("DOC_BEAD_METADATA_DRIFT: %s requirement_ids" % issue_id)

func _blocked_requirements(packets: Array[Dictionary]) -> Array[String]:
	var blocked: Array[String] = []
	for packet: Dictionary in packets:
		if packet.kind == "decision_packet" and packet.get("decision_status") == "decision_required":
			for id: Variant in packet.get("blocking_requirement_ids", []):
				if not id in blocked: blocked.append(str(id))
	blocked.sort()
	return blocked

func _is_authority_root(path: String) -> bool:
	return path.trim_suffix("/").replace("\\", "/").ends_with("/prompt_docs") or path.trim_suffix("/") == "res://prompt_docs"
~~~

`DocIndexGenerator.gd` is deterministic and contains no prose-producing branch. Its exact rendered bytes are defined by this body:

~~~gdscript
class_name DocIndexGenerator
extends RefCounted

func render(validation_result: Dictionary) -> String:
	var lines: Array[String] = [
		"<!-- GENERATED BY res://tools/docs/generate_index.gd; DO NOT EDIT -->",
		"# Requirement Index", "",
		"| requirement_id | packet_id | path | specification_status | beads |",
		"|---|---|---|---|---|",
	]
	var requirements: Array = validation_result.get("requirements", []).duplicate(true)
	requirements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var packets_by_id := {}
	for packet: Dictionary in validation_result.get("packets", []): packets_by_id[packet.id] = packet
	for requirement: Dictionary in requirements:
		var packet: Dictionary = packets_by_id[requirement.packet_id]
		var beads: Array = packet.get("beads", []).duplicate(); beads.sort()
		lines.append("| `%s` | `%s` | `%s` | `%s` | `%s` |" % [requirement.id, requirement.packet_id, requirement.path, requirement.specification_status, ",".join(beads)])
	lines.append("")
	lines.append("blocked_requirement_ids: " + JSON.stringify(validation_result.get("blocked_requirement_ids", [])))
	return "\n".join(lines) + "\n"

func write_index(path: String, content: String) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if directory_error not in [OK, ERR_ALREADY_EXISTS]: return directory_error
	var temporary := "%s.%s.tmp" % [path, str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + str(randi())]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_buffer(content.to_utf8_buffer())
	file.flush()
	file.close()
	var temporary_absolute := ProjectSettings.globalize_path(temporary)
	var target_absolute := ProjectSettings.globalize_path(path)
	# One same-directory replace is the commit point. Never delete or rename the old target first.
	# Godot's Windows backend uses replace-existing rename semantics; on a backend that refuses
	# replacement, this returns an error and the old target remains byte-for-byte intact.
	var promote_error := DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if promote_error != OK and FileAccess.file_exists(temporary):
		var cleanup_error := DirAccess.remove_absolute(temporary_absolute)
		if cleanup_error != OK: return cleanup_error
	return promote_error
~~~

`validate_docs.gd` and `generate_index.gd` share this complete argument/snapshot loader; copy it into both scripts, then use the distinct terminal blocks shown below:

~~~gdscript
extends SceneTree

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const VALIDATOR := preload("res://tools/docs/DocValidator.gd")
const GENERATOR := preload("res://tools/docs/DocIndexGenerator.gd")

func _load_snapshot_or_quit() -> Array[Dictionary]:
	var values: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--beads-snapshot="): values.append(argument.trim_prefix("--beads-snapshot="))
	if values.size() != 1 or not FileAccess.file_exists(values[0]):
		printerr("DOC_BEAD_SNAPSHOT_REQUIRED"); quit(2); return []
	var bytes := FileAccess.get_file_as_bytes(values[0])
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		printerr("DOC_BEAD_SNAPSHOT_INVALID: UTF-8"); quit(2); return []
	var parsed := STRICT_JSON.parse_strict_text(text)
	if not parsed.ok or typeof(parsed.value) != TYPE_ARRAY or parsed.value.is_empty():
		printerr("DOC_BEAD_SNAPSHOT_INVALID: " + JSON.stringify(parsed.errors)); quit(2); return []
	var typed: Array[Dictionary] = []
	for value: Variant in parsed.value:
		if typeof(value) != TYPE_DICTIONARY:
			printerr("DOC_BEAD_SNAPSHOT_INVALID: non-object record"); quit(2); return []
		typed.append(value)
	return typed
~~~

For `validate_docs.gd`, append:

~~~gdscript
func _init() -> void:
	var result := VALIDATOR.new().validate_tree("res://prompt_docs", _load_snapshot_or_quit())
	if not result.ok: printerr(JSON.stringify(result.errors)); quit(1); return
	print("DOC_VALIDATION: PASS packets=%d" % result.packets.size())
	quit(0)
~~~

For `generate_index.gd`, append:

~~~gdscript
func _init() -> void:
	var snapshot := _load_snapshot_or_quit()
	var validator := VALIDATOR.new()
	var result := validator.validate_tree("res://prompt_docs", snapshot)
	result.errors = result.errors.filter(func(error: String) -> bool: return not error.begins_with("DOC_INDEX_DRIFT:"))
	result.ok = result.errors.is_empty()
	if not result.ok: printerr(JSON.stringify(result.errors)); quit(1); return
	var generator := GENERATOR.new()
	var error := generator.write_index("res://prompt_docs/INDEX.md", generator.render(result))
	if error != OK: printerr("DOC_INDEX_WRITE: %d" % error); quit(1); return
	var verified := validator.validate_tree("res://prompt_docs", snapshot)
	if not verified.ok: printerr(JSON.stringify(verified.errors)); quit(1); return
	print("DOC_INDEX: PASS")
	quit(0)
~~~

The generator's unique temporary path must be absent after both success and a returned promotion failure. Tests MUST pre-create an index with sentinel bytes, force a write/open failure and a replace failure in an isolated `DWM_TEST_ROOT`, and prove the sentinel target bytes survive while no `*.tmp` child remains. A platform on which the single same-directory `rename_absolute` cannot replace an existing file fails this tooling test; never fall back to delete-then-rename.

Parser results contain exactly `ok`, `frontmatter`, `body`, and `errors`. Validator results contain exactly `ok`, `packets`, `requirements`, `errors`, and `blocked_requirement_ids`.

The validator MUST enforce:

1. One unique packet ID and requirement ID.
2. Exactly one `## Rule ` heading followed by the registered requirement ID per registered requirement.
3. No unregistered normative `MUST`, `MUST NOT`, or `MAY` section.
4. Approved packets contain no TODO, TBD, unresolved choice, or conversational history.
5. Every semantic dependency exists and the dependency graph is acyclic.
6. Decision packets use the closed pair `specification_status: deferred` and `decision_status: decision_required`; `decision_status` is forbidden on non-decision packets. Each decision packet contains known evidence, scope, affected requirements, blocking relationships, and recommended investigation.
7. `beads_snapshot` is a nonempty `Array[Dictionary]` whenever any packet registers a Beads ID; IDs and `phase2r` metadata must match the registered packet map.
8. `INDEX.md` byte-for-byte equals generated output and contains no hand-edited body.

`validate_docs.gd` and `generate_index.gd` MUST NOT execute Beads. They parse one required user argument, with the repository command using exactly `--beads-snapshot=res://.godot/beads/phase2r-all.json`, strict-parse that file as a top-level `Array[Dictionary]`, and pass the typed array into `validate_tree()`. Missing, empty, object-shaped, malformed, or duplicate-key snapshots fail closed. Unit tests inject fixed arrays and never access the live database.

`Export-BeadsSnapshot.ps1` runs exactly `bd list --status all --json --readonly` and requires exit zero. On PowerShell 5.1 it collects stdout as lines, joins them into one string, trims only surrounding whitespace, lexically requires leading `[` and trailing `]`, runs `ConvertFrom-Phase2RStrictJson` to completion, and materializes/enumerates records only after that recursive duplicate-aware grammar proof succeeds. It rejects an empty array or non-object record. It writes the already-validated top-level-array text—not a singleton-collapsing `ConvertTo-Json` pipeline—as UTF-8 without BOM via same-directory atomic promotion to the explicit repository-contained `-OutputPath`. No `bd list --json` shorthand and no live `OS.execute()` call are accepted.

Use this complete body:

~~~powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$BdCommand = 'bd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-CanonicalPath {
    param([string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
}
function Test-StrictDescendant {
    param([string]$Root, [string]$Candidate)
    $rootFull = Get-CanonicalPath $Root; $candidateFull = Get-CanonicalPath $Candidate
    return $candidateFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Assert-NonReparseChain {
    param([string]$Root, [string]$Candidate, [switch]$Strict)
    $rootFull = Get-CanonicalPath $Root; $candidateFull = Get-CanonicalPath $Candidate
    if (-not ($candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or (Test-StrictDescendant $rootFull $candidateFull)) -or
        ($Strict -and $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase))) { throw 'BEADS_SNAPSHOT_PATH_OUTSIDE_REPOSITORY' }
    $relative = $candidateFull.Substring($rootFull.Length).TrimStart('\','/'); $cursor = $rootFull
    foreach ($part in @('') + @(if ($relative) { $relative -split '[\/]' } else { @() })) {
        if ($part) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "BEADS_SNAPSHOT_REPARSE: $cursor" }
        }
    }
    return $candidateFull
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'project.godot') -PathType Leaf)) { throw 'BEADS_SNAPSHOT_REPOSITORY_INVALID' }
$reader = Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1') -Strict
. $reader
$outputFull = Assert-NonReparseChain $repositoryRoot $(if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repositoryRoot $OutputPath }) -Strict
$parent = Split-Path -Parent $outputFull
[void](Assert-NonReparseChain $repositoryRoot $parent -Strict)
[IO.Directory]::CreateDirectory($parent) | Out-Null
[void](Assert-NonReparseChain $repositoryRoot $parent -Strict)

$stdoutLines = @(& $BdCommand list --status all --json --readonly)
$bdExit = $LASTEXITCODE
if ($bdExit -ne 0) { throw "BD_LIST_ALL_FAILED: exit=$bdExit" }
$json = [string]::Join([Environment]::NewLine, $stdoutLines).Trim()
if ($json.Length -lt 2 -or $json[0] -cne '[' -or $json[$json.Length - 1] -cne ']') { throw 'BD_LIST_ALL_TOP_LEVEL_ARRAY_REQUIRED' }
$records = @(ConvertFrom-Phase2RStrictJson -Json $json -Label 'bd list --status all --json --readonly')
if ($records.Count -eq 0) { throw 'BD_LIST_ALL_EMPTY' }
foreach ($record in $records) {
    if ($null -eq $record -or $record -isnot [psobject] -or $null -eq $record.PSObject.Properties['id']) { throw 'BD_LIST_ALL_RECORD_INVALID' }
}

$temporary = $outputFull + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
[void](Assert-NonReparseChain $repositoryRoot $temporary -Strict)
try {
    [IO.File]::WriteAllBytes($temporary, $utf8NoBom.GetBytes($json + "`n"))
    if (Test-Path -LiteralPath $outputFull -PathType Leaf) { [IO.File]::Replace($temporary, $outputFull, $null) }
    else { [IO.File]::Move($temporary, $outputFull) }
} finally {
    if (Test-Path -LiteralPath $temporary -PathType Leaf) { [IO.File]::Delete($temporary) }
}
[void](Assert-NonReparseChain $repositoryRoot $outputFull -Strict)
$written = (New-Object Text.UTF8Encoding($false, $true)).GetString([IO.File]::ReadAllBytes($outputFull)).Trim()
[void](ConvertFrom-Phase2RStrictJson -Json $written -Label $outputFull)
Write-Output ("BEADS_SNAPSHOT: PASS records={0}" -f $records.Count)
~~~

- [ ] **Step 2.3: Register the approved packets without adding behavior**

Register these requirement families:

| Packet | Required IDs |
|---|---|
| `authority_context.md` | `req.docs.authority`, `req.docs.context_order`, `req.docs.status_separation` |
| `documentation_tooling.md` | `req.docs.packet_schema`, `req.docs.generated_index`, `req.docs.legacy_disposition`, `req.beads.execution`, `req.codegraph.removal` |
| `runtime_ownership.md` | `req.runtime.sole_owners`, `req.runtime.game_state_facade`, `req.runtime.commands_signals` |
| `run_lifecycle.md` | `req.run.day_range`, `req.run.lifecycle_states`, `req.run.day_resolution_plan`, `req.run.day7_terminal`, `req.run.no_day8` |
| `dating_endings.md` | `req.flow.hospital_order`, `req.ending.primary`, `req.ending.epilogue`, `req.ending.playback`, `req.ending.ids` |
| `contacts_invitations.md` | `req.contact.history_watermark`, `req.invitation.solo`, `req.invitation.group_activation`, `req.invitation.group_resolution`, `req.invitation.run_end` |
| `persistence.md` | `req.profile.partition`, `req.save.snapshot`, `req.save.journal`, `req.save.minesweeper_lock`, `req.save.restore_atomic`, `req.save.migration`, `req.save.test_isolation` |
| `dialogic_skip.md` | `req.dialogic.authority`, `req.dialogic.manifest`, `req.dialogic.effects`, `req.dialogic.visited`, `req.dialogic.skip`, `req.dialogic.content_status` |
| `desktop_minesweeper_handoff.md` | `req.desktop.registry`, `req.desktop.host`, `req.desktop.logout`, `req.minesweeper.round_contract`, `req.minesweeper.phase_boundary` |
| `audio_preferences.md` | `req.audio.sole_owner`, `req.audio.semantic_context`, `req.preferences.profile`, `req.preferences.reset` |
| `localization.md` | `req.locale.custom_json`, `req.locale.manifest`, `req.locale.extraction`, `req.locale.lookup`, `req.locale.switch_atomic`, `req.locale.binding`, `req.locale.presentation`, `req.locale.narrative_deferred` |
| `verification.md` | `req.test.layers`, `req.test.isolation`, `req.test.dialogic_fixture`, `req.test.phase2r_gate`, `req.config.version` |

Every rule body is a machine-precise semantic transcription of the approved design. Do not import old contradictions, narrative prose, implementation status, or issue status.

Create `narrative_localization_adapter.md` with `kind: decision_packet`, `specification_status: deferred`, `decision_status: decision_required`, and Beads ID `dwm-eob`. It blocks only translated narrative import; it does not block Phase 2R, English narrative playback, custom JSON UI catalogs, or `dwm-p2r.10`.

- [ ] **Step 2.4: Synchronize structured metadata for every child and validate the existing deferred decision**

`phase_2r_beads.v1.json` is exactly one strict-parseable top-level JSON object with no duplicate or unknown members. It contains exactly ten `child_contracts` and one `deferred_decision_contract`. Each child contract has `issue_id`, `plan_path`, `expected_spec_id`, `expected_labels`, and `expected_metadata`. The complete bootstrap object is exactly:

~~~json
{
  "schema_version": 1,
  "spec_id": "spec.phase_2r.foundation_repair",
  "child_contracts": [
  {"issue_id":"dwm-p2r.1","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-01-documentation-tooling.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["documentation","phase-2r"],"expected_metadata":{"scope":["baseline evidence","requirement packets","generated index","legacy disposition","Beads metadata"],"exclusions":["runtime behavior except configuration validation","global CodeGraph installation"],"evidence_links":[],"requirement_ids":["req.docs.authority","req.docs.context_order","req.docs.status_separation","req.docs.packet_schema","req.docs.generated_index","req.docs.legacy_disposition","req.beads.execution","req.config.version"],"verification_commands":["Invoke-IsolatedGodot.ps1:docs_tooling_gate","bd list --status all --json --readonly"]}},
  {"issue_id":"dwm-p2r.2","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-01-documentation-tooling.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["phase-2r","tooling"],"expected_metadata":{"scope":["repository .codegraph data","CodeGraph-first repository instructions"],"exclusions":["global CodeGraph executable/package"],"evidence_links":[],"requirement_ids":["req.codegraph.removal","req.beads.execution","req.docs.generated_index"],"verification_commands":["Invoke-IsolatedGodot.ps1:repository_tooling","rg active-consumer audit"]}},
  {"issue_id":"dwm-p2r.3","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-02-profile-localization-audio.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["audio","localization","phase-2r","runtime"],"expected_metadata":{"scope":["ProfileManager","custom JSON UI localization","UI bindings/presentation","AudioManager"],"exclusions":["translated narrative adapter","TranslationServer","run-save profile fields"],"evidence_links":[],"requirement_ids":["req.profile.partition","req.preferences.profile","req.preferences.reset","req.locale.custom_json","req.locale.manifest","req.locale.extraction","req.locale.lookup","req.locale.switch_atomic","req.locale.binding","req.locale.presentation","req.audio.sole_owner","req.audio.semantic_context"],"verification_commands":["Invoke-IsolatedGodot.ps1:profile_locale_audio_gate"]}},
  {"issue_id":"dwm-p2r.4","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["lifecycle","phase-2r","runtime"],"expected_metadata":{"scope":["GameState surface inventory","RunLifecycle","DayResolutionCoordinator"],"exclusions":["disk save schema","Dialogic manifests"],"evidence_links":[],"requirement_ids":["req.runtime.sole_owners","req.runtime.game_state_facade","req.runtime.commands_signals","req.run.day_range","req.run.lifecycle_states","req.run.day_resolution_plan","req.run.day7_terminal","req.run.no_day8"],"verification_commands":["Invoke-IsolatedGodot.ps1:lifecycle_gate","rg Day8 current-state audit"]}},
  {"issue_id":"dwm-p2r.5","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["persistence","phase-2r"],"expected_metadata":{"scope":["RunSnapshotSchema","CheckpointJournal","SaveManager","storage","migrations","restore adapters"],"exclusions":["player-facing Backup composition","arbitrary object saves"],"evidence_links":[],"requirement_ids":["req.save.snapshot","req.save.journal","req.save.minesweeper_lock","req.save.restore_atomic","req.save.migration","req.save.test_isolation","req.profile.partition"],"verification_commands":["Invoke-IsolatedGodot.ps1:lifecycle_save_gate","Invoke-IsolatedGodot.ps1:restore_transaction"]}},
  {"issue_id":"dwm-p2r.6","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-04-invitations-schedule-endings.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["invitations","phase-2r","runtime"],"expected_metadata":{"scope":["contact history","solo/group invitation state","facade transactions"],"exclusions":["message prose","dating presentation"],"evidence_links":[],"requirement_ids":["req.contact.history_watermark","req.invitation.solo","req.invitation.group_activation","req.invitation.group_resolution","req.invitation.run_end"],"verification_commands":["Invoke-IsolatedGodot.ps1:invitation_branches"]}},
  {"issue_id":"dwm-p2r.7","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-04-invitations-schedule-endings.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["endings","phase-2r","runtime","schedule"],"expected_metadata":{"scope":["schedule validation","Hospital/dating receipts","Day7 endings/playback"],"exclusions":["narrative prose","Dialogic event implementation"],"evidence_links":[],"requirement_ids":["req.run.day_resolution_plan","req.flow.hospital_order","req.ending.primary","req.ending.epilogue","req.ending.playback","req.ending.ids"],"verification_commands":["Invoke-IsolatedGodot.ps1:invitations_flow_gate","Invoke-IsolatedGodot.ps1:day7_endings"]}},
  {"issue_id":"dwm-p2r.8","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-05-dialogic-skip.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["dialogic","phase-2r","runtime"],"expected_metadata":{"scope":["Dialogic adapter/bridge","exact manifests","effect/variable transactions","visited history","skip fixture"],"exclusions":["Chinese narrative adapter","invented narrative prose"],"evidence_links":[],"requirement_ids":["req.dialogic.authority","req.dialogic.manifest","req.dialogic.effects","req.dialogic.visited","req.dialogic.skip","req.dialogic.content_status","req.test.dialogic_fixture","req.locale.narrative_deferred"],"verification_commands":["Invoke-IsolatedGodot.ps1:dialogic_gate","Invoke-IsolatedGodot.ps1:dialogic_fixture_smoke"]}},
  {"issue_id":"dwm-p2r.9","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-06-phase3-contracts-integration.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["phase-2r","phase-3-contract"],"expected_metadata":{"scope":["desktop registry/host contract","logout policy","round coordinator","deterministic fixtures"],"exclusions":["visible Phase3 desktop composition","player-facing simulator","real Phase6 board"],"evidence_links":[],"requirement_ids":["req.desktop.registry","req.desktop.host","req.desktop.logout","req.minesweeper.round_contract","req.minesweeper.phase_boundary"],"verification_commands":["Invoke-IsolatedGodot.ps1:desktop_contract","Invoke-IsolatedGodot.ps1:minesweeper_contract"]}},
  {"issue_id":"dwm-p2r.10","plan_path":"docs/superpowers/plans/2026-07-17-phase-2r-06-phase3-contracts-integration.md","expected_spec_id":"spec.phase_2r.foundation_repair","expected_labels":["phase-2r","verification"],"expected_metadata":{"scope":["on-tree scenes","Day1-7 scenarios","all validators","final evidence resolution","closure"],"exclusions":["waiving project-owned diagnostics","unverified archive deletion"],"evidence_links":[],"requirement_ids":["req.test.layers","req.test.isolation","req.test.dialogic_fixture","req.test.phase2r_gate","req.config.version"],"verification_commands":["tools/evidence/run_phase2r_gate.ps1","bd dep cycles","bd lint","bd orphans"]}}
  ],
  "deferred_decision_contract": {
    "issue_id": "dwm-eob",
    "title": "Choose narrative localization adapter after representative files exist",
    "description": "## Rationale\n\nOnly English Dialogic timelines physically exist, while the user will supply already-localized narrative files later. Choosing an adapter before one representative source/translation set exists would assume an unknown physical format and could damage stable IDs, branches, or Dialogic round trips. Affected requirement: req.locale.narrative_deferred. This decision blocks translated narrative import only; it does not block Phase 2R UI localization or English narrative validation.\n\n## Alternatives Considered\n\n- Godot TranslationServer resources: rejected because the approved architecture uses the user's own localized files and custom JSON for UI localization.\n- Preselect a duplicated-Dialogic-timeline adapter now: rejected until physical translated files prove their structure and stable-ID behavior.\n- Test at least two adapters against representative files, then record the evidence-backed choice: selected decision process.\n\n## Decision Trigger\n\nReopen active work when one representative English source and corresponding external localized files are present. Inspect their formats, stable IDs, branches, and round-trip requirements before proposing the adapter.",
    "acceptance_criteria": "Representative source and translated files are present; at least two viable adapters are tested against them; the chosen adapter preserves stable IDs, branches, and Dialogic structure without inventing prose; the decision packet records evidence and closes this issue.",
    "expected_spec_id": "spec.phase_2r.foundation_repair",
    "expected_status": "open",
    "expected_priority": 2,
    "expected_issue_type": "decision",
    "expected_labels": ["deferred", "narrative-localization", "phase-2r"],
    "expected_dependencies": [
      {"issue_id": "dwm-p2r", "dependency_type": "discovered-from"}
    ],
    "expected_blocking_dependency_count": 0,
    "expected_dependent_count": 0
  }
}
~~~

`evidence_links` starts empty and later accepts only objects with `requirement_id`, `path`, `sha256`, and `command_record_id`; later valid links are append-only and are not metadata drift. All other object members, array order, and values are exact.

`Sync-Phase2RMetadata.ps1` MUST:

1. Strict-parse the manifest and require the exact child set `dwm-p2r.1` through `dwm-p2r.10`.
2. Read each current issue with `bd show $issueId --json --readonly`.
3. Merge only `scope`, `exclusions`, `evidence_links`, `requirement_ids`, and `verification_commands`, preserving all unrelated metadata, status, assignee, priority, notes, dependencies, and history.
4. Set `--spec-id spec.phase_2r.foundation_repair`, add only missing expected labels, and write the merged metadata using `bd update`. An already matching record is a no-op.
5. Require existing issue `dwm-eob`; never create, rename, close, reparent, duplicate, or mutate any field or dependency.
6. Validate `dwm-eob` field-for-field against `deferred_decision_contract`: exact title, normalized description (line endings converted to `\n`, with all other bytes unchanged), acceptance criteria, type, status, spec ID, priority, labels, and dependent count. Its dependency set is exactly one edge `{issue_id:"dwm-p2r", dependency_type:"discovered-from"}`. Require the count of edges whose `dependency_type` is exactly `blocks` to be zero, and reject any second edge even when it is nonblocking. The exact `discovered-from` provenance edge does not make the decision a Phase 2R blocker.
7. Preserve `dwm-eob` byte-for-byte at the Beads field level and edge-for-edge at the dependency level; this task validates the already-created decision and MUST NOT mutate it.
8. Export a fresh all-status read-only snapshot and prove it matches ten child contracts plus the `dwm-eob` decision contract.

Use this complete body:

~~~powershell
[CmdletBinding()]
param(
    [string]$ManifestPath = 'prompt_docs/metadata/phase_2r_beads.v1.json',
    [string]$SnapshotPath = '.godot/beads/phase2r-all.json',
    [string]$BdCommand = 'bd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)

function Get-CanonicalPath { param([string]$Path) return [IO.Path]::GetFullPath($Path).TrimEnd('\','/') }
function Test-StrictDescendant {
    param([string]$Root, [string]$Candidate)
    $r = Get-CanonicalPath $Root; $c = Get-CanonicalPath $Candidate
    return $c.StartsWith($r + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Assert-RepositoryPath {
    param([string]$Root, [string]$Candidate)
    $r = Get-CanonicalPath $Root; $c = Get-CanonicalPath $Candidate
    if (-not (Test-StrictDescendant $r $c)) { throw "SYNC_PATH_OUTSIDE_REPOSITORY: $c" }
    $relative = $c.Substring($r.Length).TrimStart('\','/'); $cursor = $r
    foreach ($part in @($relative -split '[\/]')) {
        if ($part) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "SYNC_PATH_REPARSE: $cursor" }
        }
    }
    return $c
}
function Read-StrictFile {
    param([string]$Path, [string]$Label)
    [byte[]]$bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) { throw "UTF8_BOM_FORBIDDEN: $Label" }
    $text = $utf8Strict.GetString($bytes)
    return ConvertFrom-Phase2RStrictJson -Json $text -Label $Label
}
function Invoke-BdJsonArray {
    param([string[]]$Arguments, [string]$Label)
    $lines = @(& $BdCommand @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "$Label failed exit=$LASTEXITCODE" }
    $json = [string]::Join([Environment]::NewLine, $lines).Trim()
    if ($json.Length -lt 2 -or $json[0] -cne '[' -or $json[$json.Length - 1] -cne ']') { throw "$Label TOP_LEVEL_ARRAY_REQUIRED" }
    return @(ConvertFrom-Phase2RStrictJson -Json $json -Label $Label)
}
function Copy-PropertiesOrdered {
    param([object]$Value)
    $copy = [ordered]@{}
    if ($null -ne $Value) { foreach ($property in $Value.PSObject.Properties) { $copy[$property.Name] = $property.Value } }
    return $copy
}
function ConvertTo-SemanticValue {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [bool] -or
        $Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64] -or
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) { return $Value }
    if ($Value -is [Collections.IDictionary]) {
        [string[]]$names = @($Value.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($names, [StringComparer]::Ordinal)
        $output = [ordered]@{}
        foreach ($name in $names) { $output[$name] = ConvertTo-SemanticValue $Value[$name] }
        return $output
    }
    if ($Value -is [pscustomobject]) {
        [string[]]$names = @($Value.PSObject.Properties.Name)
        [Array]::Sort($names, [StringComparer]::Ordinal)
        $output = [ordered]@{}
        foreach ($name in $names) { $output[$name] = ConvertTo-SemanticValue $Value.$name }
        return $output
    }
    if ($Value -is [Collections.IEnumerable]) {
        $items = New-Object Collections.Generic.List[object]
        foreach ($item in $Value) { $items.Add((ConvertTo-SemanticValue $item)) }
        return ,$items.ToArray()
    }
    throw "SEMANTIC_VALUE_UNSUPPORTED: $($Value.GetType().FullName)"
}
function ConvertTo-SemanticJson {
    param([AllowNull()][object]$Value)
    return ConvertTo-Json -InputObject (ConvertTo-SemanticValue $Value) -Depth 100 -Compress
}
function Get-UnrelatedMetadata {
    param([AllowNull()][object]$Metadata)
    $copy = Copy-PropertiesOrdered $Metadata
    if ($copy.Contains('phase2r')) {
        $phase = Copy-PropertiesOrdered $copy['phase2r']
        foreach ($owned in @('scope','exclusions','evidence_links','requirement_ids','verification_commands')) { [void]$phase.Remove($owned) }
        if ($phase.Count -eq 0) { [void]$copy.Remove('phase2r') } else { $copy['phase2r'] = $phase }
    }
    return $copy
}
function Assert-ExactArraySet {
    param([object[]]$Actual, [object[]]$Expected, [string]$Label)
    $a = @($Actual | ForEach-Object { [string]$_ })
    $e = @($Expected | ForEach-Object { [string]$_ })
    if ([string]::Join("`n", $a) -cne [string]::Join("`n", $e)) { throw "$Label ARRAY_DRIFT" }
}
function Assert-EvidenceLinks {
    param([object[]]$Links, [string]$IssueId, [string[]]$AllowedRequirementIds)
    foreach ($link in @($Links)) {
        $keys = @($link.PSObject.Properties.Name | Sort-Object)
        $expected = @('command_record_id','path','requirement_id','sha256')
        if ([string]::Join("`n", $keys) -cne [string]::Join("`n", $expected)) { throw "EVIDENCE_LINK_SHAPE: $IssueId" }
        if ([string]$link.sha256 -notmatch '^[0-9a-f]{64}$' -or [string]$link.requirement_id -notin $AllowedRequirementIds -or
            [string]::IsNullOrWhiteSpace([string]$link.path) -or [string]::IsNullOrWhiteSpace([string]$link.command_record_id)) { throw "EVIDENCE_LINK_INVALID: $IssueId" }
    }
}
function Assert-PhaseMetadata {
    param([object]$Actual, [object]$Expected, [string]$IssueId)
    if ($null -eq $Actual) { throw "PHASE2R_METADATA_MISSING: $IssueId" }
    foreach ($field in @('scope','exclusions','requirement_ids','verification_commands')) {
        if ($null -eq $Actual.PSObject.Properties[$field]) { throw "PHASE2R_METADATA_FIELD_MISSING: $IssueId.$field" }
        Assert-ExactArraySet @($Actual.$field) @($Expected.$field) "$IssueId.$field"
    }
    if ($null -eq $Actual.PSObject.Properties['evidence_links']) { throw "PHASE2R_METADATA_FIELD_MISSING: $IssueId.evidence_links" }
    Assert-EvidenceLinks @($Actual.evidence_links) $IssueId @($Expected.requirement_ids)
}

$repositoryRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'project.godot') -PathType Leaf)) { throw 'SYNC_REPOSITORY_INVALID' }
$reader = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1')
. $reader
$manifestFull = Assert-RepositoryPath $repositoryRoot $(if ([IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath } else { Join-Path $repositoryRoot $ManifestPath })
$manifest = Read-StrictFile $manifestFull 'phase_2r_beads manifest'
$topKeys = @($manifest.PSObject.Properties.Name)
if ([string]::Join("`n", $topKeys) -cne [string]::Join("`n", @('schema_version','spec_id','child_contracts','deferred_decision_contract'))) { throw 'PHASE2R_MANIFEST_TOP_LEVEL_SHAPE' }
if ([int]$manifest.schema_version -ne 1 -or [string]$manifest.spec_id -cne 'spec.phase_2r.foundation_repair') { throw 'PHASE2R_MANIFEST_IDENTITY' }
$children = @($manifest.child_contracts)
$expectedIds = @(1..10 | ForEach-Object { "dwm-p2r.$_" })
if ($children.Count -ne 10) { throw 'PHASE2R_MANIFEST_CHILD_COUNT' }
Assert-ExactArraySet @($children.issue_id) $expectedIds 'child_contracts'

$unrelatedMetadataBefore = @{}
$evidenceLinksBefore = @{}
$labelsBefore = @{}
foreach ($contract in $children) {
    $issueId = [string]$contract.issue_id
    $records = @(Invoke-BdJsonArray -Arguments @('show',$issueId,'--json','--readonly') -Label "bd show $issueId")
    if ($records.Count -ne 1 -or [string]$records[0].id -cne $issueId) { throw "BD_SHOW_IDENTITY: $issueId" }
    $issue = $records[0]
    $unrelatedMetadataBefore[$issueId] = ConvertTo-SemanticJson (Get-UnrelatedMetadata $issue.metadata)
    $existingPhase = if ($null -ne $issue.metadata -and $null -ne $issue.metadata.PSObject.Properties['phase2r']) { $issue.metadata.phase2r } else { $null }
    $existingEvidence = if ($null -ne $existingPhase -and $null -ne $existingPhase.PSObject.Properties['evidence_links']) { @($existingPhase.evidence_links) } else { @() }
    $evidenceLinksBefore[$issueId] = ConvertTo-SemanticJson $existingEvidence
    $labelsBefore[$issueId] = @($issue.labels | ForEach-Object { [string]$_ })
    $metadata = Copy-PropertiesOrdered $issue.metadata
    $phase = Copy-PropertiesOrdered $metadata['phase2r']
    foreach ($field in @('scope','exclusions','requirement_ids','verification_commands')) { $phase[$field] = @($contract.expected_metadata.$field) }
    if (-not $phase.Contains('evidence_links')) { $phase['evidence_links'] = @($contract.expected_metadata.evidence_links) }
    Assert-EvidenceLinks @($phase['evidence_links']) $issueId @($contract.expected_metadata.requirement_ids)
    $metadata['phase2r'] = $phase
    $missingLabels = @($contract.expected_labels | Where-Object {
        $requiredLabel = [string]$_
        @($issue.labels | Where-Object { [string]$_ -ceq $requiredLabel }).Count -eq 0
    })
    $metadataJson = ConvertTo-Json $metadata -Depth 100 -Compress
    $currentMetadataJson = ConvertTo-Json $issue.metadata -Depth 100 -Compress
    $needsUpdate = ([string]$issue.spec_id -cne [string]$contract.expected_spec_id) -or ($missingLabels.Count -ne 0) -or ($metadataJson -cne $currentMetadataJson)
    if ($needsUpdate) {
        $arguments = @('update',$issueId,'--spec-id',[string]$contract.expected_spec_id,'--metadata',$metadataJson)
        foreach ($label in $missingLabels) { $arguments += @('--add-label',[string]$label) }
        & $BdCommand @arguments
        if ($LASTEXITCODE -ne 0) { throw "BD_UPDATE_FAILED: $issueId exit=$LASTEXITCODE" }
    }
}

$decision = $manifest.deferred_decision_contract
$decisionRecords = @(Invoke-BdJsonArray -Arguments @('show',[string]$decision.issue_id,'--json','--readonly') -Label 'bd show deferred decision')
if ($decisionRecords.Count -ne 1 -or [string]$decisionRecords[0].id -cne [string]$decision.issue_id) { throw 'DEFERRED_DECISION_IDENTITY' }
$actualDecision = $decisionRecords[0]
$actualDescription = ([string]$actualDecision.description).Replace("`r`n", "`n").Replace("`r", "`n")
$expectedDescription = ([string]$decision.description).Replace("`r`n", "`n").Replace("`r", "`n")
$comparisons = @(
    [pscustomobject]@{actual=[string]$actualDecision.title;expected=[string]$decision.title;field='title'},
    [pscustomobject]@{actual=$actualDescription;expected=$expectedDescription;field='description'},
    [pscustomobject]@{actual=[string]$actualDecision.acceptance_criteria;expected=[string]$decision.acceptance_criteria;field='acceptance_criteria'},
    [pscustomobject]@{actual=[string]$actualDecision.spec_id;expected=[string]$decision.expected_spec_id;field='spec_id'},
    [pscustomobject]@{actual=[string]$actualDecision.status;expected=[string]$decision.expected_status;field='status'},
    [pscustomobject]@{actual=[string]$actualDecision.issue_type;expected=[string]$decision.expected_issue_type;field='issue_type'}
)
foreach ($comparison in $comparisons) { if ($comparison.actual -cne $comparison.expected) { throw "DEFERRED_DECISION_DRIFT: $($comparison.field)" } }
if ([int]$actualDecision.priority -ne [int]$decision.expected_priority -or [int]$actualDecision.dependent_count -ne [int]$decision.expected_dependent_count) { throw 'DEFERRED_DECISION_COUNT_OR_PRIORITY_DRIFT' }
Assert-ExactArraySet @($actualDecision.labels) @($decision.expected_labels) 'deferred_decision.labels'
$dependencies = @($actualDecision.dependencies)
if ($dependencies.Count -ne @($decision.expected_dependencies).Count) { throw 'DEFERRED_DECISION_DEPENDENCY_COUNT' }
foreach ($expectedDependency in @($decision.expected_dependencies)) {
    $matches = @($dependencies | Where-Object { [string]$_.id -ceq [string]$expectedDependency.issue_id -and [string]$_.dependency_type -ceq [string]$expectedDependency.dependency_type })
    if ($matches.Count -ne 1) { throw 'DEFERRED_DECISION_DEPENDENCY_DRIFT' }
}
if (@($dependencies | Where-Object { [string]$_.dependency_type -ceq 'blocks' }).Count -ne [int]$decision.expected_blocking_dependency_count) { throw 'DEFERRED_DECISION_BLOCKING_DRIFT' }

$exporter = Assert-RepositoryPath $repositoryRoot (Join-Path $repositoryRoot 'tools\beads\Export-BeadsSnapshot.ps1')
& $exporter -OutputPath $SnapshotPath -BdCommand $BdCommand
if ($LASTEXITCODE -ne 0) { throw 'PHASE2R_SNAPSHOT_EXPORT_FAILED' }
$snapshotFull = Assert-RepositoryPath $repositoryRoot $(if ([IO.Path]::IsPathRooted($SnapshotPath)) { $SnapshotPath } else { Join-Path $repositoryRoot $SnapshotPath })
$snapshot = @(Read-StrictFile $snapshotFull 'fresh all-status snapshot')
foreach ($contract in $children) {
    $matches = @($snapshot | Where-Object { [string]$_.id -ceq [string]$contract.issue_id })
    if ($matches.Count -ne 1) { throw "SNAPSHOT_CHILD_IDENTITY: $($contract.issue_id)" }
    $issueId = [string]$contract.issue_id
    $actual = $matches[0]
    if ([string]$actual.spec_id -cne [string]$contract.expected_spec_id) { throw "SNAPSHOT_SPEC_ID_DRIFT: $issueId" }
    $afterLabels = @($actual.labels | ForEach-Object { [string]$_ })
    if (@($afterLabels | Sort-Object -Unique).Count -ne $afterLabels.Count) { throw "SNAPSHOT_DUPLICATE_LABEL: $issueId" }
    foreach ($requiredLabel in @($contract.expected_labels)) {
        if (@($afterLabels | Where-Object { $_ -ceq [string]$requiredLabel }).Count -ne 1) { throw "SNAPSHOT_REQUIRED_LABEL_DRIFT: $issueId $requiredLabel" }
    }
    foreach ($oldLabel in @($labelsBefore[$issueId])) {
        if (@($afterLabels | Where-Object { $_ -ceq [string]$oldLabel }).Count -ne 1) { throw "SNAPSHOT_UNRELATED_LABEL_REMOVED: $issueId $oldLabel" }
    }
    $unauthorizedLabels = @($afterLabels | Where-Object {
        $candidate = [string]$_
        @($labelsBefore[$issueId] | Where-Object { [string]$_ -ceq $candidate }).Count -eq 0 -and
        @($contract.expected_labels | Where-Object { [string]$_ -ceq $candidate }).Count -eq 0
    })
    if ($unauthorizedLabels.Count -ne 0) { throw "SNAPSHOT_UNAUTHORIZED_LABEL_ADDED: $issueId $($unauthorizedLabels -join ',')" }
    if ($null -eq $actual.metadata -or $null -eq $actual.metadata.PSObject.Properties['phase2r']) { throw "SNAPSHOT_PHASE2R_METADATA_MISSING: $issueId" }
    Assert-PhaseMetadata $actual.metadata.phase2r $contract.expected_metadata $issueId
    if ((ConvertTo-SemanticJson @($actual.metadata.phase2r.evidence_links)) -cne [string]$evidenceLinksBefore[$issueId]) { throw "SNAPSHOT_EVIDENCE_LINKS_MUTATED: $issueId" }
    if ((ConvertTo-SemanticJson (Get-UnrelatedMetadata $actual.metadata)) -cne [string]$unrelatedMetadataBefore[$issueId]) { throw "SNAPSHOT_UNRELATED_METADATA_MUTATED: $issueId" }
}
if (@($snapshot | Where-Object { [string]$_.id -ceq [string]$decision.issue_id }).Count -ne 1) { throw 'SNAPSHOT_DEFERRED_DECISION_MISSING' }
Write-Output 'PHASE2R_METADATA_SYNC: PASS children=10 decisions=1'
~~~

Run:

~~~powershell
& .\tools\beads\Sync-Phase2RMetadata.ps1
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
~~~

Expected: every child has the exact structured bootstrap metadata above; existing `dwm-eob` exactly matches its normalized contract, retains only the `discovered-from` edge to `dwm-p2r`, has zero blocking dependencies, and remains outside the epic’s blocking child graph.

- [ ] **Step 2.5: Replace the entry contract and generate the index**

Before editing `Prompt.md` or `prompt_docs/INDEX.md`, validate that Task 1’s immutable archive contains their current exact SHA-256 and bytes. Do not replace either file if it has changed since capture; create a new versioned baseline through a plan amendment instead.

`Prompt.md` becomes a minimal frontmatter entry contract with `schema_version: 1`, authority boundaries, `active_phase: phase_2r`, the exact context order `Prompt -> bd prime -> in-progress Phase 2R child or bd ready Phase 2R child -> substituted active issue -> phase packet -> referenced packets -> transitive dependencies -> generated INDEX lookup`, and no hardcoded child ID. Its PowerShell 5.1-compatible executable Beads selection is:

~~~powershell
. ([IO.Path]::GetFullPath('.\tools\testing\Read-StrictJson.ps1'))

function ConvertFrom-BdTopLevelArray {
    param(
        [Parameter(Mandatory = $true)][string]$Json,
        [Parameter(Mandatory = $true)][string]$CommandName
    )
    $trimmed = $Json.Trim()
    if ($trimmed.Length -lt 2 -or $trimmed[0] -ne '[' -or $trimmed[$trimmed.Length - 1] -ne ']') {
        throw "$CommandName did not return a top-level JSON array."
    }
    try {
        $parsed = ConvertFrom-Phase2RStrictJson -Json $Json -Label $CommandName
    } catch {
        throw "$CommandName returned malformed JSON: $($_.Exception.Message)"
    }
    foreach ($item in @($parsed)) {
        if ($null -eq $item -or
            $null -eq $item.PSObject.Properties['id'] -or
            $null -eq $item.PSObject.Properties['issue_type'] -or
            $null -eq $item.PSObject.Properties['status'] -or
            $null -eq $item.PSObject.Properties['priority']) {
            throw "$CommandName returned an invalid issue record."
        }
        Write-Output $item
    }
}

bd prime
if ($LASTEXITCODE -ne 0) { throw 'bd prime failed.' }
$phaseChildPattern = '^dwm-p2r\.(?:[1-9]|10)$'

$inProgressOutput = @(bd list --status in_progress --json --readonly)
if ($LASTEXITCODE -ne 0) { throw 'bd list --status in_progress failed.' }
$inProgressJson = [string]::Join([Environment]::NewLine, $inProgressOutput)
$inProgressChildren = @(
    ConvertFrom-BdTopLevelArray -Json $inProgressJson -CommandName 'bd list --status in_progress' |
        Where-Object {
            ([string]$_.id -match $phaseChildPattern) -and
            ([string]$_.issue_type -notin @('epic', 'decision')) -and
            ([string]$_.status -eq 'in_progress')
        }
)
if ($inProgressChildren.Count -gt 1) {
    throw ('Multiple Phase 2R children are in progress: ' + (($inProgressChildren.id | Sort-Object) -join ', '))
}

if ($inProgressChildren.Count -eq 1) {
    $activeIssue = $inProgressChildren[0]
} else {
    $readyOutput = @(bd ready --json --readonly)
    if ($LASTEXITCODE -ne 0) { throw 'bd ready failed.' }
    $readyJson = [string]::Join([Environment]::NewLine, $readyOutput)
    $readyChildren = @(
        ConvertFrom-BdTopLevelArray -Json $readyJson -CommandName 'bd ready' |
            Where-Object {
                ([string]$_.id -match $phaseChildPattern) -and
                ([string]$_.issue_type -notin @('epic', 'decision')) -and
                ([string]$_.status -eq 'open')
            }
    )
    $activeIssue = $readyChildren |
        Sort-Object `
            @{Expression = {[int]$_.priority}; Ascending = $true}, `
            @{Expression = {[int](([string]$_.id -split '\.')[-1])}; Ascending = $true} |
        Select-Object -First 1
}
if ($null -eq $activeIssue) { throw 'No in-progress or ready Phase 2R child; stop without inventing work.' }
$activeIssueId = [string]$activeIssue.id
bd show $activeIssueId --json --readonly
if ($LASTEXITCODE -ne 0) { throw "bd show failed for $activeIssueId." }
~~~

The selected `$activeIssueId` is substituted into the context lookup. An existing in-progress Phase 2R child is always resumed; otherwise the highest-priority numerically earliest ready Phase 2R child is selected. The epic, `dwm-eob`, every other decision, and non-Phase-2R issues are excluded.

Generate and validate using the same snapshot:

~~~powershell
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task2-generate-index' -LogName 'phase2r-generate-index.log' -GodotArgs @('-s','res://tools/docs/generate_index.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task2-validate-docs' -LogName 'phase2r-validate-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected GREEN: `DOC_INDEX: PASS` and `DOC_VALIDATION: PASS packets=14`: one phase packet, twelve requirement packets, and one decision packet.

- [ ] **Step 2.6: Run focused tooling tests**

~~~powershell
& .\tests\tooling\Test-ExportBeadsSnapshot.ps1
& .\tests\tooling\Test-SyncPhase2RMetadata.ps1
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task2-doc-tools-green' -LogName 'phase2r-green-doc-tools.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_doc_frontmatter.gd,res://tests/unit/tooling/test_doc_validator.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected GREEN: all fixture cases pass, including array-shaped Beads snapshot validation and metadata drift rejection.

- [ ] **Step 2.7: Path-specific proposed commit boundary**

Do not run without explicit authority for the exact Task 2 paths. This boundary is additionally blocked until both current immutable artifacts are exact blobs owned by the one authorized Task 1 archival commit.

~~~powershell
$reader = [IO.Path]::GetFullPath('.\tools\testing\Read-StrictJson.ps1')
. $reader
$issueJson = [string]::Join([Environment]::NewLine, @(bd show dwm-p2r.1 --json --readonly)).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to read Task 1 archive authority.' }
$issues = @(ConvertFrom-Phase2RStrictJson -Json $issueJson -Label 'bd show dwm-p2r.1')
if ($issues.Count -ne 1 -or [string]$issues[0].id -cne 'dwm-p2r.1') { throw 'Task 1 archive authority record drift.' }
$notes = ([string]$issues[0].notes).Replace(([char]13+[char]10),[char]10).Replace([char]13,[char]10)
$matches = @([regex]::Matches($notes, '(?m)^phase2r_archive_commit=([0-9a-f]{40}|[0-9a-f]{64})$'))
if ($matches.Count -ne 1) { throw 'Exactly one authorized Task 1 archive commit is required.' }
$archiveCommit = $matches[0].Groups[1].Value
$resolved = [string]::Join('', @(git rev-parse --verify ($archiveCommit + '^{commit}'))).Trim()
if ($LASTEXITCODE -ne 0 -or $resolved -cne $archiveCommit) { throw 'Authorized archive commit is not an exact commit object.' }
foreach ($artifactPath in @(
  'evidence/phase_2r/baseline.json',
  'evidence/phase_2r/legacy/legacy_heading_inventory.v1.json'
)) {
  $pathCommit = [string]::Join('', @(git log -1 --format=%H -- $artifactPath)).Trim()
  if ($LASTEXITCODE -ne 0 -or $pathCommit -cne $archiveCommit) { throw "Task 2 artifact is not owned by the authorized archive commit: $artifactPath" }
  $committedBlob = [string]::Join('', @(git rev-parse --verify ($archiveCommit + ':' + $artifactPath))).Trim()
  if ($LASTEXITCODE -ne 0 -or $committedBlob -notmatch '^[0-9a-f]{40}$|^[0-9a-f]{64}$') { throw "Authorized archive blob cannot be resolved: $artifactPath" }
  $blobType = [string]::Join('', @(git cat-file -t $committedBlob)).Trim()
  if ($LASTEXITCODE -ne 0 -or $blobType -cne 'blob') { throw "Authorized archive object is not a blob: $artifactPath" }
  $workingBlob = [string]::Join('', @(git hash-object -- $artifactPath)).Trim()
  if ($LASTEXITCODE -ne 0 -or $workingBlob -cne $committedBlob) { throw "Current archive bytes differ from the authorized blob: $artifactPath" }
}
$required = [ordered]@{
  'Prompt.md'='M'
  'prompt_docs/INDEX.md'='M'
  'prompt_docs/schemas/document_packet.v1.json'='A'
  'prompt_docs/schemas/legacy_disposition.v1.json'='A'
  'prompt_docs/schemas/phase_2r_beads_metadata.v1.json'='A'
  'prompt_docs/metadata/phase_2r_beads.v1.json'='A'
  'prompt_docs/phases/phase_2r.md'='A'
  'prompt_docs/requirements/authority_context.md'='A'
  'prompt_docs/requirements/documentation_tooling.md'='A'
  'prompt_docs/requirements/runtime_ownership.md'='A'
  'prompt_docs/requirements/run_lifecycle.md'='A'
  'prompt_docs/requirements/dating_endings.md'='A'
  'prompt_docs/requirements/contacts_invitations.md'='A'
  'prompt_docs/requirements/persistence.md'='A'
  'prompt_docs/requirements/dialogic_skip.md'='A'
  'prompt_docs/requirements/desktop_minesweeper_handoff.md'='A'
  'prompt_docs/requirements/audio_preferences.md'='A'
  'prompt_docs/requirements/localization.md'='A'
  'prompt_docs/requirements/verification.md'='A'
  'prompt_docs/decisions/narrative_localization_adapter.md'='A'
  'tools/beads/Export-BeadsSnapshot.ps1'='A'
  'tools/beads/Sync-Phase2RMetadata.ps1'='A'
  'tests/tooling/Test-ExportBeadsSnapshot.ps1'='A'
  'tests/tooling/Test-SyncPhase2RMetadata.ps1'='A'
  'tools/docs/DocFrontmatter.gd'='A'
  'tools/docs/DocValidator.gd'='A'
  'tools/docs/DocIndexGenerator.gd'='A'
  'tools/docs/validate_docs.gd'='A'
  'tools/docs/generate_index.gd'='A'
  'tests/unit/tooling/test_doc_frontmatter.gd'='A'
  'tests/unit/tooling/test_doc_validator.gd'='A'
  'tests/fixtures/docs/valid_packet.md'='A'
  'tests/fixtures/docs/missing_section.md'='A'
  'tests/fixtures/docs/duplicate_section.md'='A'
  'tests/fixtures/docs/missing_dependency.md'='A'
  'tests/fixtures/docs/dependency_cycle_a.md'='A'
  'tests/fixtures/docs/dependency_cycle_b.md'='A'
  'tests/fixtures/docs/approved_placeholder.md'='A'
  'tests/fixtures/docs/beads_metadata_drift.md'='A'
}
$optionalUids = [ordered]@{
  'tools/docs/DocFrontmatter.gd.uid'='A'
  'tools/docs/DocValidator.gd.uid'='A'
  'tools/docs/DocIndexGenerator.gd.uid'='A'
  'tools/docs/validate_docs.gd.uid'='A'
  'tools/docs/generate_index.gd.uid'='A'
  'tests/unit/tooling/test_doc_frontmatter.gd.uid'='A'
  'tests/unit/tooling/test_doc_validator.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Task 2 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'docs: add validated Phase 2R requirement packets'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 2 commit boundary failed.' }
~~~

## Task 3: Guard and repair `project.godot` configuration

**Beads:** `dwm-p2r.1`

**Files:**

- Create: `tools/config/ProjectConfigGuard.gd`
- Create: `tools/config/validate_project_config.gd`
- Create: `tests/unit/tooling/test_project_config_guard.gd`
- Modify: `project.godot`

**Interfaces:**

- Consumes: Task 1 isolated runner and approved `req.config.version`.
- Produces: `ProjectConfigGuard.inspect_text(text: String) -> Dictionary`; `ProjectConfigGuard.inspect_file(path: String = "res://project.godot") -> Dictionary`; one canonical unquoted `config_version=5` before the first section.

- [ ] **Step 3.1: Write and run the failing guard**

The test requires exactly one unquoted `config_version=5` assignment before the first section, no quoted or misencoded variant, and no other value.

Create `tests/unit/tooling/test_project_config_guard.gd` first with this complete body:

~~~gdscript
extends "res://addons/gut/test.gd"

const GUARD_PATH := "res://tools/config/ProjectConfigGuard.gd"

func test_inspect_text_matrix() -> void:
	var guard_script: Script = load(GUARD_PATH)
	assert_not_null(guard_script, "ProjectConfigGuard.gd must exist")
	if guard_script == null: return
	var guard := guard_script.new()
	assert_true(guard.inspect_text("config_version=5\n\n[application]\n").ok)
	for invalid: String in [
		"[application]\nconfig_version=5\n",
		"config_version=4\n[application]\n",
		"config_version=5\nconfig_version=5\n[application]\n",
		"\"config_version\"=5\n[application]\n",
		"\"ï»¿config_version\"=5\n[application]\n",
	]:
		assert_false(guard.inspect_text(invalid).ok, invalid)

func test_project_file_has_one_canonical_version() -> void:
	var guard_script: Script = load(GUARD_PATH)
	assert_not_null(guard_script, "ProjectConfigGuard.gd must exist")
	if guard_script == null: return
	var result: Dictionary = guard_script.new().inspect_file("res://project.godot")
	assert_true(result.ok, JSON.stringify(result.errors))
	assert_eq(result.canonical_count, 1)
~~~

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task3-config-red' -LogName 'phase2r-red-project-config.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_project_config_guard.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected RED after the guard exists: `PROJECT_CONFIG_INVALID: noncanonical config_version key "ï»¿config_version"`.

- [ ] **Step 3.2: Make the one-line repair and verify**

Before changing `project.godot`, create `tools/config/ProjectConfigGuard.gd` with this complete body:

~~~gdscript
class_name ProjectConfigGuard
extends RefCounted

func inspect_file(path: String = "res://project.godot") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["PROJECT_CONFIG_MISSING: " + path], "canonical_count": 0}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 3 and bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]):
		return {"ok": false, "errors": ["PROJECT_CONFIG_INVALID: UTF-8 BOM"], "canonical_count": 0}
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false, "errors": ["PROJECT_CONFIG_INVALID: invalid UTF-8"], "canonical_count": 0}
	return inspect_text(text)

func inspect_text(text: String) -> Dictionary:
	var errors: Array[String] = []
	var canonical_count := 0
	var first_section := -1
	var assignments: Array[Dictionary] = []
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	for index in lines.size():
		var line: String = lines[index]
		if first_section < 0 and line.begins_with("["): first_section = index
		var equals := line.find("=")
		if equals < 0: continue
		var key := line.substr(0, equals).strip_edges()
		if not key.contains("config_version"): continue
		var value := line.substr(equals + 1).strip_edges()
		assignments.append({"index": index, "key": key, "value": value})
		if key == "config_version" and value == "5" and (first_section < 0 or index < first_section):
			canonical_count += 1
		else:
			errors.append("PROJECT_CONFIG_INVALID: noncanonical config_version key %s" % key)
	if assignments.is_empty(): errors.append("PROJECT_CONFIG_INVALID: config_version missing")
	if canonical_count != 1: errors.append("PROJECT_CONFIG_INVALID: canonical config_version count=%d" % canonical_count)
	if assignments.size() != 1: errors.append("PROJECT_CONFIG_INVALID: total config_version count=%d" % assignments.size())
	return {"ok": errors.is_empty(), "errors": errors, "canonical_count": canonical_count}
~~~

Create `tools/config/validate_project_config.gd` with this complete body:

~~~gdscript
extends SceneTree

const GUARD := preload("res://tools/config/ProjectConfigGuard.gd")

func _init() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		printerr("PROJECT_CONFIG_ARGUMENT_UNKNOWN")
		quit(2)
		return
	var result: Dictionary = GUARD.new().inspect_file("res://project.godot")
	if not result.ok:
		printerr(JSON.stringify(result.errors))
		quit(1)
		return
	print("PROJECT_CONFIG: PASS config_version=5 count=%d" % result.canonical_count)
	quit(0)
~~~

Run the focused GUT test again before the one-line repair. Expected RED is now the physical noncanonical key, while `test_inspect_text_matrix` is GREEN. Then make exactly the repair below.

Remove only:

~~~text
"ï»¿config_version"=5
~~~

Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task3-config-green' -LogName 'phase2r-green-project-config.log' -GodotArgs @('-s','res://tools/config/validate_project_config.gd') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected GREEN: `PROJECT_CONFIG: PASS config_version=5 count=1`.
- [ ] **Step 3.3: Path-specific proposed commit boundary**

Do not run without explicit authority for exactly these paths:

~~~powershell
$required = [ordered]@{
  'tools/config/ProjectConfigGuard.gd'='A'
  'tools/config/validate_project_config.gd'='A'
  'tests/unit/tooling/test_project_config_guard.gd'='A'
  'project.godot'='M'
}
$optionalUids = [ordered]@{
  'tools/config/ProjectConfigGuard.gd.uid'='A'
  'tools/config/validate_project_config.gd.uid'='A'
  'tests/unit/tooling/test_project_config_guard.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Task 3 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'fix(config): enforce one canonical project config version'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 3 commit boundary failed.' }
~~~

## Task 4: Prove a legacy-inventory disposition bijection and retire only archived sources

**Beads:** `dwm-p2r.1`

**Files:**

- Create: `evidence/phase_2r/documentation/legacy_disposition.json`
- Create: `tests/unit/tooling/test_legacy_disposition.gd`
- Delete only after all gates pass: `prompt_docs/CONTRACTS.md`
- Delete only after all gates pass: `prompt_docs/CONTENT.md`
- Delete only after all gates pass: `prompt_docs/DIALOGIC.md`
- Delete only after all gates pass: `prompt_docs/FLOWS.md`
- Delete only after all gates pass: `prompt_docs/PHASES.md`
- Delete only after all gates pass: `prompt_docs/REPORT.md`
- Delete only after all gates pass: `prompt_docs/TESTING.md`
- Delete only after all gates pass: `prompt_docs/GLOSSARY.md`
- Delete only after a committed archive and explicit path authority: `ResultReport.md`
- Delete only after a committed archive and explicit path authority: `Beads.md`

`Prompt.md` and `prompt_docs/INDEX.md` were dispositioned and replaced in Task 2, not deleted. The approved dated umbrella specification remains outside normal context until the final `dwm-p2r.10` audit. `CLAUDE.md` and `dialogic fx.md` remain unchanged and are never disposition targets.

**Interfaces:**

- Consumes: immutable `legacy_heading_inventory.v1.json` and `baseline.json` from Task 1; validated requirement IDs and generated index from Task 2; archival commit hash recorded on `dwm-p2r.1`.
- Produces: `legacy_disposition.json` with an exact heading-set bijection; zero active references to retired sources; removal of ten archived legacy paths only after gates.

- [ ] **Step 4.1: Write the failing bijection test**

Each heading disposition has exactly:

~~~json
{
  "heading_id": "the inventory heading_id",
  "source_path": "prompt_docs/FLOWS.md",
  "disposition": "rejected_as_incorrect",
  "target_requirement_ids": ["req.run.day_resolution_plan", "req.run.day7_terminal"],
  "reason_code": "contradicts_approved_lifecycle",
  "reason": "The Day 8 sentinel and preemptive Day 7 route contradict the approved lifecycle."
}
~~~

Only `migrated`, `retired`, and `rejected_as_incorrect` are accepted. The test computes both ID sets and requires:

~~~text
inventory_heading_ids - disposition_heading_ids = empty
disposition_heading_ids - inventory_heading_ids = empty
count(disposition records for each heading_id) = 1
~~~

It also verifies `source_path` against the inventory record; every target requirement exists; reasons and reason codes are nonempty; every source hash matches baseline; and every captured dirty hunk maps to at least one `migrated` or `rejected_as_incorrect` record. Every zero-heading authority document, including `ResultReport.md` when applicable, receives exactly one file-level disposition keyed by source SHA-256.

Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task4-disposition-red' -LogName 'phase2r-red-legacy-disposition.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_legacy_disposition.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected RED: missing disposition IDs. Do not use a hardcoded heading count.

- [ ] **Step 4.2: Complete exact dispositions and preservation proofs**

Explicitly account for:

~~~text
Prompt.md and PHASES.md: Beads replaces Markdown work tracking; CodeGraph is not active context.
CONTRACTS.md: ending-threshold ownership and primary/epilogue clarification.
DIALOGIC.md and TESTING.md: the old Dialogic smoke is an unconditional stub, not evidence.
ResultReport.md and Beads.md: duplicate or obsolete “My first issue” planning placeholders have no authority.
~~~

Compute current SHA-256 for `CLAUDE.md` and `dialogic fx.md` and assert equality with `baseline.json.preserved_outside_authority`. The test fails if either file changed, appears in `legacy_disposition.json`, appears as a generated packet, or is staged by a Task 4 gate.

Run the focused test until GREEN:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task4-disposition-green' -LogName 'phase2r-green-legacy-disposition.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_legacy_disposition.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected GREEN: `LEGACY_DISPOSITION: PASS` with `records` equal to `headings.size() + zero_heading_documents.size()` from the immutable inventory.

- [ ] **Step 4.3: Require archival commit evidence before any deletion**

Deletion is forbidden unless all of these are true:

1. The user explicitly authorized and Task 1 created an archival commit.
2. `bd show dwm-p2r.1 --json --readonly` contains exactly one note line `phase2r_archive_commit=<object-id>` and that exact object ID is used for every following check.
3. The commit contains both `evidence/phase_2r/baseline.json` and `evidence/phase_2r/legacy/legacy_heading_inventory.v1.json`.
4. The committed baseline contains exact bytes and reconstructable patches for every deletion target.
5. Task 2 doc validation and Task 4 disposition validation are GREEN.
6. The user separately authorizes deletion of the exact listed paths. `ResultReport.md` and `Beads.md` MUST remain until that explicit archival-commit and deletion authority exists.

Strict-parse the Beads record, compare the exact recorded archive commit, bind the current immutable files to the recorded commit's blobs, and re-run validation plus scratch reconstruction immediately before deletion:

~~~powershell
$issueOutput = @(bd show dwm-p2r.1 --json --readonly)
if ($LASTEXITCODE -ne 0) { throw 'Unable to read dwm-p2r.1.' }
$issueJson = [string]::Join([Environment]::NewLine, $issueOutput).Trim()
if ($issueJson.Length -lt 2 -or $issueJson[0] -ne '[' -or $issueJson[$issueJson.Length - 1] -ne ']') {
    throw 'bd show dwm-p2r.1 did not return a top-level JSON array.'
}
$gitRootText = [string]::Join('', @(git rev-parse --show-toplevel)).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRootText)) { throw 'Unable to prove repository root.' }
$repositoryRoot = [IO.Path]::GetFullPath($gitRootText).TrimEnd('\','/')
$gitPrefix = [string]::Join('', @(git rev-parse --show-prefix))
if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrEmpty($gitPrefix)) { throw 'Pre-delete gate must run at the exact repository root.' }
function Test-StrictRepositoryDescendant {
    param([string]$Root, [string]$Candidate)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $candidateFull = [IO.Path]::GetFullPath($Candidate).TrimEnd('\','/')
    return $candidateFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Assert-RepositoryRegularFile {
    param([string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains('..')) { throw "PREDELETE_PATH_INVALID: $RelativePath" }
    $full = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (-not (Test-StrictRepositoryDescendant $repositoryRoot $full)) { throw "PREDELETE_PATH_OUTSIDE_REPOSITORY: $RelativePath" }
    $relative = $full.Substring($repositoryRoot.Length).TrimStart('\','/')
    $cursor = $repositoryRoot
    foreach ($part in @('') + @($relative -split '[\/]')) {
        if ($part) { $cursor = Join-Path $cursor $part }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -Force -LiteralPath $cursor
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "PREDELETE_REPARSE_POINT: $cursor" }
        }
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "PREDELETE_REGULAR_FILE_MISSING: $RelativePath" }
    $leaf = Get-Item -Force -LiteralPath $full
    if ($leaf.PSIsContainer -or ($leaf.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "PREDELETE_NOT_REGULAR_FILE: $RelativePath" }
    return $full
}
$strictReader = Assert-RepositoryRegularFile 'tools/testing/Read-StrictJson.ps1'
. $strictReader
$issues = @(ConvertFrom-Phase2RStrictJson -Json $issueJson -Label 'bd show dwm-p2r.1')
if ($issues.Count -ne 1 -or [string]$issues[0].id -ne 'dwm-p2r.1') { throw 'Unexpected dwm-p2r.1 record.' }
$notes = ([string]$issues[0].notes).Replace("`r`n", "`n").Replace("`r", "`n")
$archiveMatches = @([regex]::Matches($notes, '(?m)^phase2r_archive_commit=([0-9a-f]{40}|[0-9a-f]{64})$'))
if ($archiveMatches.Count -ne 1) { throw 'Expected exactly one phase2r_archive_commit note.' }
$archiveCommit = $archiveMatches[0].Groups[1].Value
$resolvedCommit = [string]::Join('', @(git rev-parse --verify ($archiveCommit + '^{commit}'))).Trim()
if ($LASTEXITCODE -ne 0 -or $resolvedCommit -cne $archiveCommit) { throw 'Recorded archive commit is not an exact commit object ID.' }
$pathCommit = [string]::Join('', @(git log -1 --format=%H -- evidence/phase_2r/baseline.json)).Trim()
if ($LASTEXITCODE -ne 0 -or $pathCommit -cne $archiveCommit) { throw 'Recorded commit is not the immutable baseline archival commit.' }
git cat-file -e ($archiveCommit + ':evidence/phase_2r/baseline.json')
if ($LASTEXITCODE -ne 0) { throw 'Baseline missing from archive commit.' }
git cat-file -e ($archiveCommit + ':evidence/phase_2r/legacy/legacy_heading_inventory.v1.json')
if ($LASTEXITCODE -ne 0) { throw 'Heading inventory missing from archive commit.' }
$archivePaths = @(
    'evidence/phase_2r/baseline.json',
    'evidence/phase_2r/legacy/legacy_heading_inventory.v1.json'
)
$committedArchiveBlobs = @{}
foreach ($path in $archivePaths) {
    $committedBlob = [string]::Join('', @(git rev-parse --verify ($archiveCommit + ':' + $path))).Trim()
    if ($LASTEXITCODE -ne 0 -or $committedBlob -notmatch '^[0-9a-f]{40}$|^[0-9a-f]{64}$') { throw "Unable to resolve committed blob for $path." }
    $committedType = [string]::Join('', @(git cat-file -t $committedBlob)).Trim()
    if ($LASTEXITCODE -ne 0 -or $committedType -cne 'blob') { throw "Committed archive object is not a blob: $path" }
    $workingFull = Assert-RepositoryRegularFile $path
    $workingBlob = [string]::Join('', @(git hash-object -- $workingFull)).Trim()
    if ($LASTEXITCODE -ne 0 -or $workingBlob -cne $committedBlob) {
        throw "Immutable archive drift for $path."
    }
    $committedArchiveBlobs[$path] = $committedBlob
}
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)
$baselineFull = Assert-RepositoryRegularFile 'evidence/phase_2r/baseline.json'
$baseline = ConvertFrom-Phase2RStrictJson -Json ($utf8Strict.GetString([IO.File]::ReadAllBytes($baselineFull))) -Label 'committed Phase 2R baseline'
$sourceByPath = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
foreach ($source in @($baseline.source_archive)) {
    if ($null -eq $source.PSObject.Properties['path']) { throw 'BASELINE_SOURCE_PATH_MISSING' }
    $sourcePath = [string]$source.path
    if ($sourceByPath.ContainsKey($sourcePath)) { throw "BASELINE_SOURCE_PATH_DUPLICATE: $sourcePath" }
    $sourceByPath.Add($sourcePath, $source)
}
$deletionTargets = @(
    'prompt_docs/CONTRACTS.md','prompt_docs/CONTENT.md','prompt_docs/DIALOGIC.md','prompt_docs/FLOWS.md',
    'prompt_docs/PHASES.md','prompt_docs/REPORT.md','prompt_docs/TESTING.md','prompt_docs/GLOSSARY.md',
    'ResultReport.md','Beads.md'
)
$sha256 = [Security.Cryptography.SHA256]::Create()
function Get-PredeleteSha256 {
    param([byte[]]$Bytes)
    return ([BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()
}
function Assert-DeletionTargetsMatchArchive {
    foreach ($targetPath in $deletionTargets) {
        $currentFull = Assert-RepositoryRegularFile $targetPath
        if (-not $sourceByPath.ContainsKey($targetPath)) { throw "BASELINE_SOURCE_RECORD_MISSING: $targetPath" }
        $record = $sourceByPath[$targetPath]
        foreach ($member in @('path','sha256','byte_length','content_base64','git_blob_id_or_null','working_tree_patch_base64')) {
            if ($null -eq $record.PSObject.Properties[$member]) { throw "BASELINE_SOURCE_MEMBER_MISSING: $targetPath.$member" }
        }
        try { [byte[]]$archivedBytes = [Convert]::FromBase64String([string]$record.content_base64) }
        catch { throw "BASELINE_SOURCE_BASE64_INVALID: $targetPath" }
        $archivedSha = Get-PredeleteSha256 $archivedBytes
        if ([Convert]::ToBase64String($archivedBytes) -cne [string]$record.content_base64 -or
            $archivedBytes.Length -ne [int64]$record.byte_length -or
            $archivedSha -cne [string]$record.sha256) { throw "BASELINE_SOURCE_HASH_OR_LENGTH_INVALID: $targetPath" }
        if ($null -ne $record.git_blob_id_or_null) {
            $sourceBlobType = [string]::Join('', @(git cat-file -t ([string]$record.git_blob_id_or_null))).Trim()
            if ($LASTEXITCODE -ne 0 -or $sourceBlobType -cne 'blob') { throw "BASELINE_SOURCE_GIT_BLOB_INVALID: $targetPath" }
        }
        [byte[]]$currentBytes = [IO.File]::ReadAllBytes($currentFull)
        if ((Get-PredeleteSha256 $currentBytes) -cne $archivedSha -or
            [Convert]::ToBase64String($currentBytes) -cne [string]$record.content_base64) {
            throw "POST_CAPTURE_SOURCE_DRIFT_REQUIRES_NEW_AUTHORIZED_ARCHIVE: $targetPath"
        }
    }
}
& .\tools\evidence\capture_phase_2r_baseline.ps1
if ($LASTEXITCODE -ne 0) { throw 'Archive schema/reconstruction verification failed.' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task4-archive-predelete' -LogName 'phase2r-archive-predelete.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_evidence_contract.gd,res://tests/unit/tooling/test_legacy_disposition.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
if ($LASTEXITCODE -ne 0) { throw 'Pre-deletion archive/disposition validation failed.' }
if ([Environment]::GetEnvironmentVariable('DWM_ARCHIVE_DELETION_AUTHORIZED') -cne '1') {
    throw 'Exact legacy archive deletion requires DWM_ARCHIVE_DELETION_AUTHORIZED=1.'
}
Assert-DeletionTargetsMatchArchive
~~~

Expected: exact Beads note, commit object, both committed archive blobs, schema validation, source reconstruction, heading bijection, disposition validation, and exact deletion authority all agree. The block's final operation is the byte/type/reparse proof for every deletion target.

- [ ] **Step 4.4: Update active references, delete exact files, and revalidate**

Use this exact reference classifier before and after deletion:

~~~powershell
$legacyPattern = 'CONTRACTS\.md|CONTENT\.md|DIALOGIC\.md|FLOWS\.md|PHASES\.md|REPORT\.md|TESTING\.md|GLOSSARY\.md|ResultReport\.md|Beads\.md'
$strictReader = [IO.Path]::GetFullPath('.\tools\testing\Read-StrictJson.ps1')
. $strictReader
$deletionTargets = @(
    'prompt_docs/CONTRACTS.md', 'prompt_docs/CONTENT.md', 'prompt_docs/DIALOGIC.md',
    'prompt_docs/FLOWS.md', 'prompt_docs/PHASES.md', 'prompt_docs/REPORT.md',
    'prompt_docs/TESTING.md', 'prompt_docs/GLOSSARY.md', 'ResultReport.md', 'Beads.md'
)
$archivalReferenceAllowlist = @(
    'tools/evidence/capture_phase_2r_baseline.ps1',
    'tests/unit/tooling/test_legacy_disposition.gd'
)
$searchRoots = @('Prompt.md', 'prompt_docs', 'autoload', 'scripts', 'scenes', 'tests', 'tools', 'project.godot', 'ResultReport.md', 'Beads.md') |
    Where-Object { Test-Path -LiteralPath $_ }
$rgOutput = @(rg --json -n -- $legacyPattern @searchRoots)
$rgExit = $LASTEXITCODE
if ($rgExit -notin @(0, 1)) { throw "Legacy-reference rg failed with exit $rgExit." }
$matchedPaths = @(
    foreach ($line in $rgOutput) {
        $record = ConvertFrom-Phase2RStrictJson -Json ([string]$line) -Label 'rg --json legacy classifier record'
        if ([string]$record.type -eq 'match') {
            ([string]$record.data.path.text).Replace('\', '/') -replace '^\./', ''
        }
    }
) | Sort-Object -Unique
$unexpected = @($matchedPaths | Where-Object { ($_ -notin $deletionTargets) -and ($_ -notin $archivalReferenceAllowlist) })
if ($unexpected.Count -ne 0) { throw ('Active legacy consumers remain: ' + ($unexpected -join ', ')) }
$unexpectedArchival = @($matchedPaths | Where-Object { $_ -match '^(tests|tools)/' -and $_ -notin $archivalReferenceAllowlist })
if ($unexpectedArchival.Count -ne 0) { throw ('Unapproved archival-tool references: ' + ($unexpectedArchival -join ', ')) }
~~~

Before deletion, matches are permitted only inside the ten deletion targets or the two exact archival allowlist files. Update every other authoritative consumer to a requirement packet or generated index. Do not edit or treat `CLAUDE.md` or `dialogic fx.md` as consumers. After the classifier is GREEN, rerun the entire self-contained Step 4.3 PowerShell block. Its authority guard and final `Assert-DeletionTargetsMatchArchive` call MUST be followed immediately by one `apply_patch` deletion batch containing only the ten literal `$deletionTargets`. No command, generator, checkout, merge, or edit may intervene. Otherwise rerun the classifier and then the entire Step 4.3 block again. `POST_CAPTURE_SOURCE_DRIFT_REQUIRES_NEW_AUTHORIZED_ARCHIVE` is a hard stop: preserve every target and obtain a new separately authorized immutable archive. If `DWM_ARCHIVE_DELETION_AUTHORIZED` is absent, stop with all files intact; do not close `dwm-p2r.1` or claim `dwm-p2r.2`.

After deletion, re-run the classifier and additionally require `@($matchedPaths | Where-Object { $_ -in $deletionTargets }).Count -eq 0`; remaining matches may exist only in `capture_phase_2r_baseline.ps1` (immutable archive inventory) and `test_legacy_disposition.gd` (archive/disposition reconstruction proof). This replaces the impossible zero-match assertion with zero **active consumers** plus a closed archival-tool allowlist. Then:

~~~powershell
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task4-docs-after-delete' -LogName 'phase2r-docs-after-delete.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task4-disposition-after-delete' -LogName 'phase2r-disposition-after-delete.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_legacy_disposition.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Expected GREEN: generated docs and archived-source disposition remain valid after deletion.
- [ ] **Step 4.5: Path-specific proposed retirement commit boundary**

Do not run without exact commit authority and the same exact archive-deletion authority used for the immediately preceding ten-file deletion:

~~~powershell
$required = [ordered]@{
  'evidence/phase_2r/documentation/legacy_disposition.json'='A'
  'tests/unit/tooling/test_legacy_disposition.gd'='A'
  'prompt_docs/CONTRACTS.md'='D'
  'prompt_docs/CONTENT.md'='D'
  'prompt_docs/DIALOGIC.md'='D'
  'prompt_docs/FLOWS.md'='D'
  'prompt_docs/PHASES.md'='D'
  'prompt_docs/REPORT.md'='D'
  'prompt_docs/TESTING.md'='D'
  'prompt_docs/GLOSSARY.md'='D'
  'ResultReport.md'='D'
  'Beads.md'='D'
}
$optionalUids = [ordered]@{
  'tests/unit/tooling/test_legacy_disposition.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Task 4 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -RequiredAuthorityVariables @('DWM_ARCHIVE_DELETION_AUTHORIZED') -ExpectedHead $expectedHead -Message 'docs: retire archived legacy prompt documents'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 4 retirement commit boundary failed.' }
~~~

## Task 5: Remove repository CodeGraph only after all three replacements are proven

**Beads:** `dwm-p2r.2`

**Files:**

- Create: `tools/tooling/Verify-CodeGraphPrerequisites.ps1`
- Create: `tools/tooling/Remove-RepositoryCodeGraph.ps1`
- Create: `tools/tooling/stop_repository_codegraph_daemon.cjs`
- Create: `tests/unit/tooling/test_repository_tooling.gd`
- Create: `tests/tooling/Test-CodeGraphRemovalScripts.ps1`
- Generate: `evidence/phase_2r/tooling/codegraph_prerequisites.json`
- Generate: `evidence/phase_2r/tooling/codegraph_removal.json`
- Delete after prerequisites pass: `.codegraph/`
- Modify only if an active reference exists: `Prompt.md`
- Modify only if an active reference exists: `prompt_docs/phases/phase_2r.md`
- Modify only if an active reference exists: `prompt_docs/requirements/documentation_tooling.md`

**Interfaces:**

- Consumes: closed `dwm-p2r.1` with evidence; read-only all-status Beads snapshot; generated requirement index; validated `rg` version/output workflow; Task 1 isolated runner.
- Produces: `Verify-CodeGraphPrerequisites.ps1 -EvidencePath String [-ActiveInstructionAuditRoot String]`, where the optional root is accepted only as a read-only audit beneath `.godot/phase2r_tests` and returns before evidence generation; `Remove-RepositoryCodeGraph.ps1 -PrerequisiteEvidencePath String -RemovalEvidencePath String`; root-scoped `stop_repository_codegraph_daemon.cjs <module-path> <module-sha256> <repository-root>`; primitive-only prerequisite/removal evidence; absent repository `.codegraph/`; no active CodeGraph-first consumer.

- [ ] **Step 5.1: Claim only after `dwm-p2r.1` is closed and write the failing test**

~~~powershell
bd show dwm-p2r.1 --json --readonly
bd show dwm-p2r.2 --json --readonly
bd update dwm-p2r.2 --claim
~~~

The first command must show `closed` with baseline, disposition, docs-validation, and archive evidence. The test is:

~~~gdscript
extends "res://addons/gut/test.gd"

const STOP_HELPER := "res://tools/tooling/stop_repository_codegraph_daemon.cjs"

func test_repository_codegraph_directory_is_absent() -> void:
	assert_false(
		DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path("res://.codegraph")
		)
	)

func _write(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return
	file.store_string(text)
	file.close()

func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func _node_path() -> String:
	var configured := OS.get_environment("NODE_EXE")
	return configured if not configured.is_empty() else "C:\\Program Files\\nodejs\\node.exe"

func test_stop_helper_rejects_hash_drift_and_handles_absent_lock() -> void:
	assert_true(FileAccess.file_exists(STOP_HELPER), "stop helper must exist")
	if not FileAccess.file_exists(STOP_HELPER): return
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("codegraph-helper")
	var module := root.path_join("package/daemon-registry.js")
	var repository := root.path_join("repository")
	_write(module, "module.exports.stopDaemonAt = async () => ({root:'x',pid:null,outcome:'no-daemon'});\n")
	_write(repository.path_join("project.godot"), "config_version=5\n")
	var output: Array = []
	var mismatch_exit := OS.execute(_node_path(), [ProjectSettings.globalize_path(STOP_HELPER), module, "0".repeat(64), repository], output, true)
	assert_ne(mismatch_exit, 0)
	assert_true("\n".join(output).contains("MODULE_SHA256_DRIFT"))
	output.clear()
	var absent_exit := OS.execute(_node_path(), [ProjectSettings.globalize_path(STOP_HELPER), module, _sha256(module), repository], output, true)
	assert_eq(absent_exit, 0, "\n".join(output))
	var lines := "\n".join(output).strip_edges().split("\n", false)
	assert_eq(lines.size(), 1)
	var parsed: Variant = JSON.parse_string(lines[0])
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	if typeof(parsed) == TYPE_DICTIONARY:
		assert_eq(parsed.pid, null)
		assert_eq(parsed.outcome, "absent")
~~~

Create `tests/tooling/Test-CodeGraphRemovalScripts.ps1` before either PowerShell implementation. Its RED assertions require the future verifier audit to ignore only its closed owned paths, reject both real instruction forms everywhere else, accept lexical near-matches, keep prerequisite generation read-only, reject duplicate prerequisite evidence before authority, and reject valid unauthorized removal before mutation:

~~~powershell
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$verify = Join-Path $root 'tools\tooling\Verify-CodeGraphPrerequisites.ps1'
$remove = Join-Path $root 'tools\tooling\Remove-RepositoryCodeGraph.ps1'
if (-not (Test-Path -LiteralPath $verify -PathType Leaf)) { throw 'VERIFY_CODEGRAPH_PREREQUISITES_MISSING' }
if (-not (Test-Path -LiteralPath $remove -PathType Leaf)) { throw 'REMOVE_REPOSITORY_CODEGRAPH_MISSING' }
$scratch = Join-Path $root ('.godot\phase2r_tests\' + [guid]::NewGuid().ToString('D'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$priorRemovalAuthority = [Environment]::GetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED', 'Process')

function Write-Utf8NoBomFile {
    param([string]$Path, [string]$Text)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}
function Invoke-ActiveInstructionAuditFixture {
    param([string]$AuditRoot)
    $failed = $false
    $text = @()
    try { $text = @(& $verify -ActiveInstructionAuditRoot $AuditRoot 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    return [ordered]@{ failed = $failed; text = [string]::Join("`n", $text) }
}
function Assert-ActiveInstructionAuditPass {
    param([string]$AuditRoot, [string]$Label)
    $result = Invoke-ActiveInstructionAuditFixture $AuditRoot
    if ($result.failed -or -not $result.text.Contains('ACTIVE_CODEGRAPH_INSTRUCTION_AUDIT: PASS')) {
        throw ("ACTIVE_INSTRUCTION_AUDIT_EXPECTED_PASS: {0}: {1}" -f $Label, $result.text)
    }
}
function Assert-ActiveInstructionAuditRejects {
    param([string]$AuditRoot, [string]$ExpectedPath, [string]$Label)
    $result = Invoke-ActiveInstructionAuditFixture $AuditRoot
    if (-not $result.failed -or -not $result.text.Contains('ACTIVE_CODEGRAPH_FIRST_INSTRUCTION_REMAINS') -or -not $result.text.Contains($ExpectedPath)) {
        throw ("ACTIVE_INSTRUCTION_AUDIT_EXPECTED_REJECTION: {0}: {1}" -f $Label, $result.text)
    }
}

try {
    [Environment]::SetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED', $null, 'Process')
    $before = [IO.Path]::GetFullPath((Join-Path $root '.codegraph'))

    $auditRoot = Join-Path $scratch 'active-instruction-audit'
    $verifierCopy = Join-Path $auditRoot 'tools\tooling\Verify-CodeGraphPrerequisites.ps1'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $verifierCopy)) | Out-Null
    Copy-Item -LiteralPath $verify -Destination $verifierCopy
    $ownedInstructionText = "<!-- CODEGRAPH_START -->`nreach for it BEFORE source lookup`n"
    foreach ($ownedRelativePath in @(
        'tools/tooling/Remove-RepositoryCodeGraph.ps1',
        'tools/tooling/stop_repository_codegraph_daemon.cjs',
        'tests/tooling/Test-CodeGraphRemovalScripts.ps1',
        'tests/unit/tooling/test_repository_tooling.gd',
        'evidence/phase_2r/tooling/codegraph_prerequisites.json',
        'evidence/phase_2r/tooling/codegraph_removal.json'
    )) {
        Write-Utf8NoBomFile (Join-Path $auditRoot $ownedRelativePath) $ownedInstructionText
    }
    Assert-ActiveInstructionAuditPass $auditRoot 'verifier source and exact owned paths must not self-match'

    $activeMarkerPath = Join-Path $auditRoot 'tools\unowned\active-marker.ps1'
    Write-Utf8NoBomFile $activeMarkerPath '<!-- CODEGRAPH_START -->'
    Assert-ActiveInstructionAuditRejects $auditRoot 'tools/unowned/active-marker.ps1' 'marker instruction outside exact allowlist'
    Remove-Item -LiteralPath $activeMarkerPath -Force

    $activePhrasePath = Join-Path $auditRoot 'tests\unowned\active-phrase.md'
    Write-Utf8NoBomFile $activePhrasePath 'Agents must reach for it BEFORE ordinary text search.'
    Assert-ActiveInstructionAuditRejects $auditRoot 'tests/unowned/active-phrase.md' 'priority instruction outside exact allowlist'
    Remove-Item -LiteralPath $activePhrasePath -Force

    $nearMatchPath = Join-Path $auditRoot 'scripts\near-matches.txt'
    Write-Utf8NoBomFile $nearMatchPath ([string]::Join("`n", @(
        '<!-- CODEGRAPH_STARTER -->',
        '<!-- XCODEGRAPH_START -->',
        'Agents may preach for it BEFORE ordinary text search.',
        'Agents may reach for it BEFOREHAND.'
    )))
    Assert-ActiveInstructionAuditPass $auditRoot 'lexical near-matches must not be active instructions'

    $validPrerequisite = Join-Path $scratch 'prerequisites.json'
    & $verify -EvidencePath $validPrerequisite
    if ($LASTEXITCODE -ne 0) { throw 'VERIFY_CODEGRAPH_FIXTURE_FAILED' }
    if (-not (Test-Path -LiteralPath $before -PathType Container)) { throw 'VERIFY_CODEGRAPH_MUTATED_TARGET' }
    $duplicate = Join-Path $scratch 'duplicate.json'
    [IO.File]::WriteAllText($duplicate, '{"schema_version":1,"schema_version":1}', (New-Object Text.UTF8Encoding($false)))
    $failed = $false; $text = @()
    try { $text = @(& $remove -PrerequisiteEvidencePath $duplicate -RemovalEvidencePath (Join-Path $scratch 'removal.json') 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('JSON_DUPLICATE_MEMBER')) { throw 'REMOVE_CODEGRAPH_DUPLICATE_NOT_REJECTED' }
    if (-not (Test-Path -LiteralPath $before -PathType Container)) { throw 'REMOVE_CODEGRAPH_MUTATED_BEFORE_VALIDATION' }
    $unauthorizedRemoval = Join-Path $scratch 'unauthorized-removal.json'
    $failed = $false; $text = @()
    try { $text = @(& $remove -PrerequisiteEvidencePath $validPrerequisite -RemovalEvidencePath $unauthorizedRemoval 2>&1) }
    catch { $failed = $true; $text += $_.Exception.Message }
    if (-not $failed -or -not ([string]::Join("`n", $text)).Contains('CODEGRAPH_REMOVAL_AUTHORITY_REQUIRED')) { throw 'REMOVE_CODEGRAPH_MISSING_AUTHORITY_NOT_REJECTED' }
    if (-not (Test-Path -LiteralPath $before -PathType Container) -or (Test-Path -LiteralPath $unauthorizedRemoval)) { throw 'REMOVE_CODEGRAPH_MUTATED_WITHOUT_AUTHORITY' }
} finally {
    [Environment]::SetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED', $priorRemovalAuthority, 'Process')
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Write-Output 'CODEGRAPH_SCRIPT_FIXTURE: PASS'
~~~

Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task5-codegraph-red' -LogName 'phase2r-red-codegraph.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_repository_tooling.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tests\tooling\Test-CodeGraphRemovalScripts.ps1
~~~

Expected RED: repository `.codegraph` exists, the Node helper is missing, and the PowerShell fixture reports `VERIFY_CODEGRAPH_PREREQUISITES_MISSING`. No prerequisite or removal implementation exists before this run.

- [ ] **Step 5.2: Prove the exact three removal prerequisites**

`Verify-CodeGraphPrerequisites.ps1` writes UTF-8-without-BOM JSON with command argv, exit codes, stdout/stderr SHA-256, and these booleans:

~~~text
beads_issue_lookup_operational
documentation_issue_closed_with_bound_evidence
requirement_index_lookup_operational
verified_rg_inspection_operational
rg_source_inventory_covers_project_gdscript_and_scenes = true
global_codegraph_identity_matches_baseline = true
repository_root_identity_proven = true
repository_codegraph_tree_reparse_free = true
daemon_identity_proven_or_absent = true
~~~

It proves:

1. **Beads lookup and documentation closure:** `bd show dwm-p2r.1 --json --readonly` returns exactly one closed record, `bd show dwm-p2r.2 --json --readonly` returns exactly one record, and the all-status snapshot created by exact command `bd list --status all --json --readonly` contains exactly one of each. The closed `.1` record contains exactly one `phase2r_archive_commit=<object-id>` note whose commit still owns the exact current baseline and inventory blobs. Its `metadata.phase2r.evidence_links` contains exactly one path binding for each of `evidence/phase_2r/baseline.json -> req.docs.authority`, `evidence/phase_2r/legacy/legacy_heading_inventory.v1.json -> req.docs.legacy_disposition`, `evidence/phase_2r/documentation/legacy_disposition.json -> req.docs.legacy_disposition`, and `prompt_docs/INDEX.md -> req.docs.generated_index`; every link has exactly the four approved members, a nonempty command-record ID, a lowercase SHA-256 matching the current regular reparse-free repository file, and no duplicate path. Additional evidence links remain allowed only when they pass the same exact shape/path/hash checks and use a requirement ID registered to `.1`.
2. **Requirement/index lookup:** `validate_docs.gd` exits zero with the same array snapshot; `prompt_docs/INDEX.md` resolves `req.codegraph.removal` to `prompt_docs/requirements/documentation_tooling.md`; generated bytes match.
3. **Verified `rg` inspection:** `rg --version` exits zero; `rg --files autoload scripts scenes` captures the actual project `.gd`/`.tscn` inventory; direct `rg -n` queries locate symbols/references; and an active-authority search finds no CodeGraph-first instruction outside the closed owned-path allowlist. The verifier constructs both prohibited needles from fragments, uses word/token boundaries so lexical near-matches do not count, scans every existing closed authority root, parses `rg --json`, and excludes only `tools/tooling/Verify-CodeGraphPrerequisites.ps1`, `tools/tooling/Remove-RepositoryCodeGraph.ps1`, `tools/tooling/stop_repository_codegraph_daemon.cjs`, `tests/tooling/Test-CodeGraphRemovalScripts.ps1`, `tests/unit/tooling/test_repository_tooling.gd`, and the two Task-5 evidence paths. A matching non-allowlisted file under `Prompt.md`, `prompt_docs`, `autoload`, `scripts`, `scenes`, `tests`, `tools`, or `project.godot` fails with its normalized repository path; no directory-wide exclusion is permitted. The approved specification’s captured discovery finding—not a false claim about `rg` reading the binary CodeGraph database—establishes that CodeGraph has no project GDScript/scene relationships.
4. **Global-tool identity:** read-only resolution, SHA-256, and version for `codegraph.cmd` exactly match `baseline.json.external_tools.codegraph_command` before deletion.
5. **Repository identity:** `git rev-parse --show-toplevel` resolves to the canonical current directory, `git rev-parse --show-prefix` is empty, `project.godot` exists at that root, `.codegraph` is its exact direct child, and `git ls-files --error-unmatch -- .codegraph/.gitignore` proves the target belongs to this repository. The complete root-to-target chain and every nested `.codegraph` entry are enumerated with `Get-Item -Force`; any reparse point fails closed.
6. **Daemon identity:** if `.codegraph/daemon.pid` names a live PID, the strict-parsed lock record, the one matching `$HOME/.codegraph/daemons/*.json` registry record, canonical registry `root`, PID, version/socket identity, and `Get-Process -Id <pid>.Path` must all agree. The executable path must equal the exact Node executable resolved by the baseline-matched `codegraph.cmd` launcher (the launcher uses its adjacent `node.exe` when present and otherwise the uniquely resolved `node.exe` on `PATH`). A missing, duplicate, cross-project, or unprovable live daemon fails closed. No process is stopped in the prerequisite step.

Use this complete body for `Verify-CodeGraphPrerequisites.ps1`:

~~~powershell
[CmdletBinding()]
param(
    [string]$EvidencePath = 'evidence/phase_2r/tooling/codegraph_prerequisites.json',
    [string]$ActiveInstructionAuditRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict = New-Object Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$sha = [Security.Cryptography.SHA256]::Create()

function Get-CanonicalPath { param([string]$Path) return [IO.Path]::GetFullPath($Path).TrimEnd('\','/') }
function Get-Sha256Hex { param([byte[]]$Bytes) return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
function Test-StrictDescendant {
    param([string]$Root,[string]$Candidate)
    $r=Get-CanonicalPath $Root; $c=Get-CanonicalPath $Candidate
    return $c.StartsWith($r+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
}
function Assert-NonReparseChain {
    param([string]$Root,[string]$Candidate,[switch]$Strict)
    $r=Get-CanonicalPath $Root; $c=Get-CanonicalPath $Candidate
    if (-not ($c.Equals($r,[StringComparison]::OrdinalIgnoreCase) -or (Test-StrictDescendant $r $c)) -or ($Strict -and $c.Equals($r,[StringComparison]::OrdinalIgnoreCase))) { throw "CODEGRAPH_PATH_OUTSIDE_ROOT: $c" }
    $relative=$c.Substring($r.Length).TrimStart('\','/'); $cursor=$r
    foreach($part in @('')+@(if($relative){$relative -split '[\/]'}else{@()})){
        if($part){$cursor=Join-Path $cursor $part}
        if(Test-Path -LiteralPath $cursor){$item=Get-Item -Force -LiteralPath $cursor;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw "CODEGRAPH_REPARSE: $cursor"}}
    }
    return $c
}
function Assert-TreeReparseFree {
    param([string]$Root)
    foreach($item in @(Get-Item -Force -LiteralPath $Root)+@(Get-ChildItem -Force -Recurse -LiteralPath $Root)){
        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw "CODEGRAPH_TREE_REPARSE: $($item.FullName)"}
    }
}
function Read-StrictJsonFile {
    param([string]$Path,[string]$Label)
    [byte[]]$bytes=[IO.File]::ReadAllBytes($Path)
    if($bytes.Length-ge 3 -and $bytes[0]-eq 0xef -and $bytes[1]-eq 0xbb -and $bytes[2]-eq 0xbf){throw "UTF8_BOM_FORBIDDEN: $Label"}
    return ConvertFrom-Phase2RStrictJson -Json ($utf8Strict.GetString($bytes)) -Label $Label
}
function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    if($Value-notmatch'[\s"]'){return $Value};$builder=New-Object Text.StringBuilder;[void]$builder.Append('"');$slashes=0
    foreach($character in $Value.ToCharArray()){if($character-eq'\'){$slashes+=1;continue};if($character-eq'"'){[void]$builder.Append(('\'*(($slashes*2)+1))+'"');$slashes=0;continue};if($slashes-ne0){[void]$builder.Append('\'*$slashes);$slashes=0};[void]$builder.Append($character)}
    if($slashes-ne0){[void]$builder.Append('\'*($slashes*2))};[void]$builder.Append('"');return $builder.ToString()
}
function Invoke-TextCommand {
    param([string]$Command,[string[]]$Arguments,[string]$Label)
    $resolved=(Get-Command $Command -CommandType Application -ErrorAction Stop).Source;$start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$resolved;$start.Arguments=[string]::Join(' ',@($Arguments|ForEach-Object{ConvertTo-NativeArgument([string]$_)}));$start.WorkingDirectory=$repositoryRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;if(-not$process.Start()){throw "PROCESS_START_FAILED: $Label"};$stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync();$process.WaitForExit();$stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult()
    return [ordered]@{label=$Label;argv=@($resolved)+@($Arguments);exit_code=[int]$process.ExitCode;stdout_utf8=$stdout;stdout_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stdout));stderr_utf8=$stderr;stderr_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stderr))}
}
function Invoke-ActiveCodeGraphInstructionAudit {
    param([string]$ScanRoot)
    $root = Get-CanonicalPath $ScanRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'ACTIVE_INSTRUCTION_AUDIT_ROOT_MISSING' }
    $ownedPaths = @(
        'tools/tooling/Verify-CodeGraphPrerequisites.ps1',
        'tools/tooling/Remove-RepositoryCodeGraph.ps1',
        'tools/tooling/stop_repository_codegraph_daemon.cjs',
        'tests/tooling/Test-CodeGraphRemovalScripts.ps1',
        'tests/unit/tooling/test_repository_tooling.gd',
        'evidence/phase_2r/tooling/codegraph_prerequisites.json',
        'evidence/phase_2r/tooling/codegraph_removal.json'
    )
    $authorityInputs = @()
    foreach ($relativePath in @('Prompt.md','prompt_docs','autoload','scripts','scenes','tests','tools','project.godot','evidence/phase_2r/tooling/codegraph_prerequisites.json','evidence/phase_2r/tooling/codegraph_removal.json')) {
        $candidate = Join-Path $root $relativePath
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        $candidate = Assert-NonReparseChain $root $candidate -Strict
        $item = Get-Item -Force -LiteralPath $candidate
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "ACTIVE_INSTRUCTION_REPARSE_INPUT: $relativePath" }
        if ($item.PSIsContainer) { Assert-TreeReparseFree $candidate }
        elseif (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "ACTIVE_INSTRUCTION_INPUT_NOT_REGULAR: $relativePath" }
        $authorityInputs += $candidate
    }
    if ($authorityInputs.Count -eq 0) { throw 'ACTIVE_INSTRUCTION_AUTHORITY_INPUTS_EMPTY' }

    $markerToken = [string]::Concat('CODE','GRAPH_','START')
    $priorityToken = [string]::Concat('BE','FORE')
    $markerPattern = [string]::Concat('(?:^|[^A-Z0-9_])',[regex]::Escape($markerToken),'(?:[^A-Z0-9_]|$)')
    $priorityPattern = [string]::Concat('\b','reach','[ \t]+','for','[ \t]+','it','[ \t]+',$priorityToken,'\b')
    $arguments = @('--json','-n','-i','-e',$markerPattern,'-e',$priorityPattern,'--') + @($authorityInputs)
    $search = Invoke-TextCommand 'rg' $arguments 'rg-active-authority'
    if ([int]$search.exit_code -notin @(0,1)) { throw 'RG_ACTIVE_SEARCH_FAILED' }

    $ownedMatches = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $unexpectedMatches = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($line in @(([string]$search.stdout_utf8 -split "`r?`n") | Where-Object { $_ })) {
        $record = ConvertFrom-Phase2RStrictJson -Json ([string]$line) -Label 'rg active-authority record'
        if ([string]$record.type -cne 'match') { continue }
        if ($null -eq $record.data -or $null -eq $record.data.path -or [string]::IsNullOrWhiteSpace([string]$record.data.path.text)) { throw 'RG_ACTIVE_MATCH_PATH_MISSING' }
        $reportedPath = [string]$record.data.path.text
        $fullPath = Get-CanonicalPath $(if ([IO.Path]::IsPathRooted($reportedPath)) { $reportedPath } else { Join-Path $repositoryRoot $reportedPath })
        if (-not (Test-StrictDescendant $root $fullPath)) { throw "RG_ACTIVE_MATCH_OUTSIDE_SCAN_ROOT: $reportedPath" }
        $relativePath = $fullPath.Substring($root.Length).TrimStart('\','/').Replace('\','/')
        if ($ownedPaths -ccontains $relativePath) { [void]$ownedMatches.Add($relativePath) }
        else { [void]$unexpectedMatches.Add($relativePath) }
    }
    if ($unexpectedMatches.Count -ne 0) {
        throw ('ACTIVE_CODEGRAPH_FIRST_INSTRUCTION_REMAINS: ' + ([string]::Join(', ', @($unexpectedMatches | Sort-Object))))
    }
    return [ordered]@{ command = $search; owned_match_paths = @($ownedMatches | Sort-Object) }
}
function Require-Zero { param([object]$Record) if([int]$Record.exit_code-ne 0){throw "$($Record.label) failed exit=$($Record.exit_code)"} }
function Read-ExactIssueRecord {
    param([string]$Json,[string]$IssueId,[string]$Label)
    $trimmed=$Json.Trim()
    if($trimmed.Length-lt2-or$trimmed[0]-cne'['-or$trimmed[$trimmed.Length-1]-cne']'){throw "$Label TOP_LEVEL_ARRAY_REQUIRED"}
    $records=@(ConvertFrom-Phase2RStrictJson -Json $trimmed -Label $Label)
    if($records.Count-ne1-or[string]$records[0].id-cne$IssueId){throw "$Label EXACT_ISSUE_IDENTITY_REQUIRED"}
    return $records[0]
}
function Assert-P2R1ClosureEvidence {
    param([object]$Issue)
    if([string]$Issue.id-cne'dwm-p2r.1'-or[string]$Issue.status-cne'closed'){throw 'P2R1_NOT_EXACTLY_CLOSED'}
    $notes=([string]$Issue.notes).Replace("`r`n","`n").Replace("`r","`n")
    $commitMatches=@([regex]::Matches($notes,'(?m)^phase2r_archive_commit=([0-9a-f]{40}|[0-9a-f]{64})$'))
    if($commitMatches.Count-ne1){throw 'P2R1_ARCHIVE_COMMIT_NOTE_REQUIRED_ONCE'}
    $archiveCommit=$commitMatches[0].Groups[1].Value
    $commitRecord=Invoke-TextCommand 'git' @('rev-parse','--verify',($archiveCommit+'^{commit}')) 'p2r1-archive-commit';Require-Zero $commitRecord
    if(([string]$commitRecord.stdout_utf8).Trim()-cne$archiveCommit){throw 'P2R1_ARCHIVE_COMMIT_IDENTITY_DRIFT'}
    foreach($artifactPath in @('evidence/phase_2r/baseline.json','evidence/phase_2r/legacy/legacy_heading_inventory.v1.json')){
        $artifactFull=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot $artifactPath) -Strict
        if(-not(Test-Path -LiteralPath $artifactFull -PathType Leaf)){throw "P2R1_ARCHIVE_ARTIFACT_MISSING: $artifactPath"}
        $item=Get-Item -Force -LiteralPath $artifactFull;if($item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "P2R1_ARCHIVE_ARTIFACT_NOT_REGULAR: $artifactPath"}
        $committed=Invoke-TextCommand 'git' @('rev-parse','--verify',($archiveCommit+':'+$artifactPath)) "p2r1-blob-$artifactPath";Require-Zero $committed
        $committedBlob=([string]$committed.stdout_utf8).Trim()
        $typeRecord=Invoke-TextCommand 'git' @('cat-file','-t',$committedBlob) "p2r1-blob-type-$artifactPath";Require-Zero $typeRecord
        if(([string]$typeRecord.stdout_utf8).Trim()-cne'blob'){throw "P2R1_ARCHIVE_OBJECT_NOT_BLOB: $artifactPath"}
        $working=Invoke-TextCommand 'git' @('hash-object','--',$artifactFull) "p2r1-working-blob-$artifactPath";Require-Zero $working
        if(([string]$working.stdout_utf8).Trim()-cne$committedBlob){throw "P2R1_ARCHIVE_WORKING_BLOB_DRIFT: $artifactPath"}
    }
    if($null-eq$Issue.metadata-or$null-eq$Issue.metadata.PSObject.Properties['phase2r']){throw 'P2R1_PHASE2R_METADATA_MISSING'}
    $phase=$Issue.metadata.phase2r
    if($null-eq$phase.PSObject.Properties['requirement_ids']-or$null-eq$phase.PSObject.Properties['evidence_links']){throw 'P2R1_EVIDENCE_METADATA_FIELDS_MISSING'}
    $allowedRequirementIds=@($phase.requirement_ids|ForEach-Object{[string]$_})
    $links=@($phase.evidence_links)
    $pathsSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($link in $links){
        $keys=@($link.PSObject.Properties.Name|Sort-Object)
        if([string]::Join("`n",$keys)-cne[string]::Join("`n",@('command_record_id','path','requirement_id','sha256'))){throw 'P2R1_EVIDENCE_LINK_SHAPE'}
        $path=[string]$link.path
        if([string]::IsNullOrWhiteSpace($path)-or[IO.Path]::IsPathRooted($path)-or$path.Contains('\')-or@($path-split'/'|Where-Object{$_-ceq'..'}).Count-ne0){throw "P2R1_EVIDENCE_PATH_INVALID: $path"}
        if(-not$pathsSeen.Add($path)){throw "P2R1_EVIDENCE_PATH_DUPLICATE: $path"}
        if($allowedRequirementIds -cnotcontains [string]$link.requirement_id){throw "P2R1_EVIDENCE_REQUIREMENT_UNREGISTERED: $path"}
        if([string]::IsNullOrWhiteSpace([string]$link.command_record_id)-or[string]$link.sha256-notmatch'^[0-9a-f]{64}$'){throw "P2R1_EVIDENCE_LINK_VALUE_INVALID: $path"}
        $full=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot $path) -Strict
        if(-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "P2R1_EVIDENCE_FILE_MISSING: $path"}
        $item=Get-Item -Force -LiteralPath $full;if($item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "P2R1_EVIDENCE_FILE_NOT_REGULAR: $path"}
        if((Get-Sha256Hex([IO.File]::ReadAllBytes($full)))-cne[string]$link.sha256){throw "P2R1_EVIDENCE_SHA256_DRIFT: $path"}
    }
    $required=[ordered]@{
        'evidence/phase_2r/baseline.json'='req.docs.authority'
        'evidence/phase_2r/legacy/legacy_heading_inventory.v1.json'='req.docs.legacy_disposition'
        'evidence/phase_2r/documentation/legacy_disposition.json'='req.docs.legacy_disposition'
        'prompt_docs/INDEX.md'='req.docs.generated_index'
    }
    $bound=@()
    foreach($entry in $required.GetEnumerator()){
        $matches=@($links|Where-Object{[string]$_.path-ceq[string]$entry.Key-and[string]$_.requirement_id-ceq[string]$entry.Value})
        if($matches.Count-ne1){throw "P2R1_REQUIRED_EVIDENCE_BINDING: $($entry.Key) -> $($entry.Value)"}
        $bound+=,[ordered]@{path=[string]$entry.Key;requirement_id=[string]$entry.Value;sha256=[string]$matches[0].sha256;command_record_id=[string]$matches[0].command_record_id}
    }
    return [ordered]@{status='closed';archive_commit=$archiveCommit;required_evidence=@($bound)}
}

$repositoryRoot=Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$reader=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1') -Strict
. $reader
if (-not [string]::IsNullOrWhiteSpace($ActiveInstructionAuditRoot)) {
    if ($PSBoundParameters.ContainsKey('EvidencePath')) { throw 'ACTIVE_INSTRUCTION_AUDIT_FORBIDS_EVIDENCE_PATH' }
    $phaseTestsRoot = Get-CanonicalPath (Join-Path $repositoryRoot '.godot\phase2r_tests')
    $auditRoot = Assert-NonReparseChain $phaseTestsRoot $ActiveInstructionAuditRoot -Strict
    $audit = Invoke-ActiveCodeGraphInstructionAudit $auditRoot
    Write-Output ('ACTIVE_CODEGRAPH_INSTRUCTION_AUDIT: PASS owned_matches=' + @($audit.owned_match_paths).Count)
    return
}
$target=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot '.codegraph') -Strict
if(-not (Test-Path -LiteralPath $target -PathType Container)){throw 'REPOSITORY_CODEGRAPH_MISSING'}
Assert-TreeReparseFree $target
$project=Join-Path $repositoryRoot 'project.godot';if(-not(Test-Path -LiteralPath $project -PathType Leaf)){throw 'PROJECT_GODOT_MISSING'}
$gitRootCommand=Invoke-TextCommand 'git' @('rev-parse','--show-toplevel') 'git-root';Require-Zero $gitRootCommand
$gitRoot=Get-CanonicalPath ([string]$gitRootCommand.stdout_utf8.Trim())
if(-not $gitRoot.Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'GIT_ROOT_MISMATCH'}
$prefixCommand=Invoke-TextCommand 'git' @('rev-parse','--show-prefix') 'git-prefix';Require-Zero $prefixCommand
if(-not [string]::IsNullOrWhiteSpace([string]$prefixCommand.stdout_utf8)){throw 'GIT_PREFIX_NOT_EMPTY'}
$sentinelCommand=Invoke-TextCommand 'git' @('ls-files','--error-unmatch','--','.codegraph/.gitignore') 'tracked-sentinel';Require-Zero $sentinelCommand

$baselinePath=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'evidence\phase_2r\baseline.json') -Strict
$baseline=Read-StrictJsonFile $baselinePath 'immutable baseline'
$codegraphCommand=(Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop).Source
[byte[]]$commandBytes=[IO.File]::ReadAllBytes($codegraphCommand)
$versionOutput=@(& $codegraphCommand --version 2>&1);if($LASTEXITCODE-ne 0){throw 'CODEGRAPH_VERSION_FAILED'}
$codegraphVersion=([string]::Join([Environment]::NewLine,$versionOutput)).Trim()
$baselineCommand=$baseline.external_tools.codegraph_command
if(-not (Get-CanonicalPath $codegraphCommand).Equals((Get-CanonicalPath ([string]$baselineCommand.resolved_path)),[StringComparison]::OrdinalIgnoreCase) -or
   (Get-Sha256Hex $commandBytes)-cne [string]$baselineCommand.sha256 -or $codegraphVersion-cne [string]$baselineCommand.version){throw 'GLOBAL_CODEGRAPH_IDENTITY_DRIFT'}
$commandParent=Split-Path -Parent $codegraphCommand
$packageRoot=Get-CanonicalPath (Join-Path $commandParent 'node_modules\@colbymchenry\codegraph')
if(-not(Test-Path -LiteralPath $packageRoot -PathType Container)){throw 'CODEGRAPH_PACKAGE_ROOT_MISSING'}
$package=Read-StrictJsonFile (Join-Path $packageRoot 'package.json') 'CodeGraph package.json'
if([string]$package.version-cne $codegraphVersion){throw 'CODEGRAPH_PACKAGE_VERSION_DRIFT'}
$modules=@(Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -File -Filter 'daemon-registry.js')
if($modules.Count-ne 1){throw "DAEMON_REGISTRY_MODULE_COUNT: $($modules.Count)"}
$modulePath=Get-CanonicalPath $modules[0].FullName;[byte[]]$moduleBytes=[IO.File]::ReadAllBytes($modulePath)
$nodeCandidate=Join-Path $commandParent 'node.exe'
$nodePath=if(Test-Path -LiteralPath $nodeCandidate -PathType Leaf){Get-CanonicalPath $nodeCandidate}else{Get-CanonicalPath ((Get-Command node.exe -CommandType Application -ErrorAction Stop).Source)}
[byte[]]$nodeBytes=[IO.File]::ReadAllBytes($nodePath)

$exporter=Assert-NonReparseChain $repositoryRoot (Join-Path $repositoryRoot 'tools\beads\Export-BeadsSnapshot.ps1') -Strict
$snapshotPath=Join-Path $repositoryRoot '.godot\beads\phase2r-all.json'
& $exporter -OutputPath $snapshotPath;if($LASTEXITCODE-ne 0){throw 'BEADS_SNAPSHOT_EXPORT_FAILED'}
$snapshot=@(Read-StrictJsonFile $snapshotPath 'all-status Beads snapshot')
if(@($snapshot|Where-Object{[string]$_.id-ceq 'dwm-p2r.1'}).Count-ne1){throw 'BEADS_P2R1_LOOKUP_FAILED'}
if(@($snapshot|Where-Object{[string]$_.id-ceq 'dwm-p2r.2'}).Count-ne 1){throw 'BEADS_P2R2_LOOKUP_FAILED'}
$bead1Command=Invoke-TextCommand 'bd' @('show','dwm-p2r.1','--json','--readonly') 'bd-show-p2r1';Require-Zero $bead1Command
$bead1=Read-ExactIssueRecord ([string]$bead1Command.stdout_utf8) 'dwm-p2r.1' 'bd show dwm-p2r.1'
$closureReceipt=Assert-P2R1ClosureEvidence $bead1
$snapshotP2R1=@($snapshot|Where-Object{[string]$_.id-ceq'dwm-p2r.1'})[0]
$snapshotClosure=Assert-P2R1ClosureEvidence $snapshotP2R1
if((ConvertTo-Json $snapshotClosure -Depth 20 -Compress)-cne(ConvertTo-Json $closureReceipt -Depth 20 -Compress)){throw 'BEADS_P2R1_SNAPSHOT_CLOSURE_DRIFT'}
$beadCommand=Invoke-TextCommand 'bd' @('show','dwm-p2r.2','--json','--readonly') 'bd-show-p2r2';Require-Zero $beadCommand
[void](Read-ExactIssueRecord ([string]$beadCommand.stdout_utf8) 'dwm-p2r.2' 'bd show dwm-p2r.2')
$docsOutput=@(& (Join-Path $repositoryRoot 'tools\testing\Invoke-IsolatedGodot.ps1') -SuiteId 'task5-codegraph-prereq-docs' -LogName 'phase2r-codegraph-prereq-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') 2>&1)
if($LASTEXITCODE-ne 0){throw 'CODEGRAPH_DOC_LOOKUP_FAILED'}
$docsRecord=[string]::Join([Environment]::NewLine,$docsOutput).Trim();[void](ConvertFrom-Phase2RStrictJson -Json $docsRecord -Label 'docs helper record')
$indexBytes=[IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'prompt_docs\INDEX.md'))
if($utf8Strict.GetString($indexBytes)-notmatch 'req\.codegraph\.removal.*prompt_docs/requirements/documentation_tooling\.md'){throw 'CODEGRAPH_REQUIREMENT_INDEX_LOOKUP_FAILED'}

$rgVersion=Invoke-TextCommand 'rg' @('--version') 'rg-version';Require-Zero $rgVersion
$rgFiles=Invoke-TextCommand 'rg' @('--files','autoload','scripts','scenes') 'rg-source-inventory';Require-Zero $rgFiles
$sourceFiles=@(([string]$rgFiles.stdout_utf8 -split "`r?`n")|Where-Object{$_ -match '\.(?:gd|tscn)$'}|Sort-Object -Unique)
if($sourceFiles.Count-eq 0){throw 'RG_SOURCE_INVENTORY_EMPTY'}
$activeAudit=Invoke-ActiveCodeGraphInstructionAudit $repositoryRoot
$activeSearch=$activeAudit.command

$registryDir=Get-CanonicalPath (Join-Path $HOME '.codegraph\daemons')
$registrySnapshots=@();$matching=@()
if(Test-Path -LiteralPath $registryDir -PathType Container){
    foreach($file in @(Get-ChildItem -Force -LiteralPath $registryDir -File -Filter '*.json'|Sort-Object FullName)){
        [byte[]]$bytes=[IO.File]::ReadAllBytes($file.FullName);$record=ConvertFrom-Phase2RStrictJson -Json ($utf8Strict.GetString($bytes)) -Label $file.FullName
        $entry=[ordered]@{path=Get-CanonicalPath $file.FullName;content_base64=[Convert]::ToBase64String($bytes);sha256=Get-Sha256Hex $bytes;root=[string]$record.root;pid=[int]$record.pid;version=[string]$record.version;socket_path=[string]$record.socketPath;live=$null-ne(Get-Process -Id ([int]$record.pid) -ErrorAction SilentlyContinue)}
        $registrySnapshots+=,$entry;if((Get-CanonicalPath ([string]$record.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)){$matching+=,@{record=$record;snapshot=$entry}}
    }
}
$lockPath=Join-Path $target 'daemon.pid';$daemon=[ordered]@{state='absent';pid=$null;registry_path=$null;process_path=$null}
if(Test-Path -LiteralPath $lockPath -PathType Leaf){
    $lock=Read-StrictJsonFile $lockPath 'repository daemon lock';$pid=[int]$lock.pid;$process=Get-Process -Id $pid -ErrorAction SilentlyContinue
    if($null-ne $process){
        if($matching.Count-ne 1){throw 'PROJECT_DAEMON_REGISTRY_IDENTITY_COUNT'};$registry=$matching[0].record
        if([int]$registry.pid-ne $pid -or [string]$registry.version-cne [string]$lock.version -or [string]$registry.socketPath-cne [string]$lock.socketPath){throw 'PROJECT_DAEMON_LOCK_REGISTRY_DRIFT'}
        $processPath=Get-CanonicalPath $process.Path
        if(-not $processPath.Equals($nodePath,[StringComparison]::OrdinalIgnoreCase)){throw 'PROJECT_DAEMON_NODE_IDENTITY_DRIFT'}
        $daemon=[ordered]@{state='live';pid=$pid;registry_path=[string]$matching[0].snapshot.path;process_path=$processPath}
    }else{if($matching.Count-gt 1){throw 'PROJECT_DAEMON_STALE_REGISTRY_DUPLICATE'};$daemon=[ordered]@{state='stale';pid=$pid;registry_path=if($matching.Count-eq 1){[string]$matching[0].snapshot.path}else{$null};process_path=$null}}
}elseif($matching.Count-ne0){throw 'PROJECT_DAEMON_REGISTRY_WITHOUT_LOCK'}

$evidence=[ordered]@{
    schema_version=1;canonical_root=$repositoryRoot;canonical_target=$target
    beads_issue_lookup_operational=$true;documentation_issue_closed_with_bound_evidence=$true;requirement_index_lookup_operational=$true;verified_rg_inspection_operational=$true
    rg_source_inventory_covers_project_gdscript_and_scenes=$true;global_codegraph_identity_matches_baseline=$true
    repository_root_identity_proven=$true;repository_codegraph_tree_reparse_free=$true;daemon_identity_proven_or_absent=$true
    codegraph_command=[ordered]@{path=Get-CanonicalPath $codegraphCommand;sha256=Get-Sha256Hex $commandBytes;version=$codegraphVersion;package_root=$packageRoot;package_version=[string]$package.version;node_path=$nodePath;node_sha256=Get-Sha256Hex $nodeBytes;daemon_module_path=$modulePath;daemon_module_sha256=Get-Sha256Hex $moduleBytes}
    p2r1_closure=$closureReceipt;daemon=$daemon;registry_records=@($registrySnapshots);source_inventory=@($sourceFiles)
    commands=@($gitRootCommand,$prefixCommand,$sentinelCommand,$bead1Command,$beadCommand,$rgVersion,$rgFiles,$activeSearch)
}
$evidenceFull=Assert-NonReparseChain $repositoryRoot $(if([IO.Path]::IsPathRooted($EvidencePath)){$EvidencePath}else{Join-Path $repositoryRoot $EvidencePath}) -Strict
$parent=Split-Path -Parent $evidenceFull;[void](Assert-NonReparseChain $repositoryRoot $parent -Strict);[IO.Directory]::CreateDirectory($parent)|Out-Null;[void](Assert-NonReparseChain $repositoryRoot $parent -Strict)
$temporary=$evidenceFull+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
try{[IO.File]::WriteAllBytes($temporary,$utf8NoBom.GetBytes((ConvertTo-Json $evidence -Depth 100 -Compress)+"`n"));if(Test-Path -LiteralPath $evidenceFull){[IO.File]::Replace($temporary,$evidenceFull,$null)}else{[IO.File]::Move($temporary,$evidenceFull)}}finally{if(Test-Path -LiteralPath $temporary){[IO.File]::Delete($temporary)}}
[void](Read-StrictJsonFile $evidenceFull 'written CodeGraph prerequisites')
Write-Output 'CODEGRAPH_PREREQUISITES: PASS'
~~~

Run:

~~~powershell
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task5-codegraph-docs' -LogName 'phase2r-codegraph-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\tooling\Verify-CodeGraphPrerequisites.ps1 -EvidencePath 'evidence/phase_2r/tooling/codegraph_prerequisites.json'
~~~

Expected: all nine booleans have the exact values above, including the bound closed-documentation receipt. Exact domain manifests and later behavioral tests are deliberately not prerequisites for removing an index that the approved discovery evidence found has no project GDScript/scene relationships.

- [ ] **Step 5.3: Stop only the proven project daemon and run official repository uninitialization**

Implement `Remove-RepositoryCodeGraph.ps1` with exactly:

~~~powershell
param(
    [string]$PrerequisiteEvidencePath = 'evidence/phase_2r/tooling/codegraph_prerequisites.json',
    [string]$RemovalEvidencePath = 'evidence/phase_2r/tooling/codegraph_removal.json'
)
~~~

Immediately after that parameter block, use this complete body:

~~~powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8Strict=New-Object Text.UTF8Encoding($false,$true);$utf8NoBom=New-Object Text.UTF8Encoding($false);$sha=[Security.Cryptography.SHA256]::Create()
function Get-CanonicalPath{param([string]$Path)return [IO.Path]::GetFullPath($Path).TrimEnd('\','/')}
function Get-Sha256Hex{param([byte[]]$Bytes)return([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}
function Test-StrictDescendant{param([string]$Root,[string]$Candidate)$r=Get-CanonicalPath $Root;$c=Get-CanonicalPath $Candidate;return $c.StartsWith($r+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)}
function Assert-PathChain{
    param([string]$Root,[string]$Candidate,[switch]$Strict)
    $r=Get-CanonicalPath $Root;$c=Get-CanonicalPath $Candidate
    if(-not($c.Equals($r,[StringComparison]::OrdinalIgnoreCase)-or(Test-StrictDescendant $r $c))-or($Strict-and$c.Equals($r,[StringComparison]::OrdinalIgnoreCase))){throw "REMOVE_PATH_OUTSIDE_ROOT: $c"}
    $relative=$c.Substring($r.Length).TrimStart('\','/');$cursor=$r
    foreach($part in @('')+@(if($relative){$relative-split '[\/]'}else{@()})){if($part){$cursor=Join-Path $cursor $part};if(Test-Path -LiteralPath $cursor){$item=Get-Item -Force -LiteralPath $cursor;if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "REMOVE_REPARSE: $cursor"}}}
    return $c
}
function Assert-TreeSafe{param([string]$Root)foreach($item in @(Get-Item -Force -LiteralPath $Root)+@(Get-ChildItem -Force -Recurse -LiteralPath $Root)){if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "REMOVE_TREE_REPARSE: $($item.FullName)"}}}
function Read-StrictFile{param([string]$Path,[string]$Label)[byte[]]$bytes=[IO.File]::ReadAllBytes($Path);if($bytes.Length-ge 3-and$bytes[0]-eq 0xef-and$bytes[1]-eq 0xbb-and$bytes[2]-eq 0xbf){throw "UTF8_BOM_FORBIDDEN: $Label"};return ConvertFrom-Phase2RStrictJson -Json($utf8Strict.GetString($bytes))-Label $Label}
function ConvertTo-RemovalArgument{
    param([AllowEmptyString()][string]$Value)
    if($Value-notmatch'[\s"]'){return $Value};$builder=New-Object Text.StringBuilder;[void]$builder.Append('"');$slashes=0
    foreach($character in $Value.ToCharArray()){if($character-eq'\'){$slashes+=1;continue};if($character-eq'"'){[void]$builder.Append(('\'*(($slashes*2)+1))+'"');$slashes=0;continue};if($slashes-ne0){[void]$builder.Append('\'*$slashes);$slashes=0};[void]$builder.Append($character)}
    if($slashes-ne0){[void]$builder.Append('\'*($slashes*2))};[void]$builder.Append('"');return $builder.ToString()
}
function Invoke-RemovalCommand{
    param([string]$Command,[string[]]$Arguments)
    $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$Command;$start.Arguments=[string]::Join(' ',@($Arguments|ForEach-Object{ConvertTo-RemovalArgument([string]$_)}));$start.WorkingDirectory=$repositoryRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;if(-not$process.Start()){throw 'UNINIT_PROCESS_START_FAILED'};$stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync();$process.WaitForExit();$stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult();return[ordered]@{exit_code=[int]$process.ExitCode;stdout=$stdout;stderr=$stderr;stdout_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stdout));stderr_sha256=Get-Sha256Hex($utf8NoBom.GetBytes($stderr))}
}
function Write-AtomicJson{
    param([string]$Path,[object]$Value)
    $parent=Split-Path -Parent $Path;[void](Assert-PathChain $repositoryRoot $parent -Strict);[IO.Directory]::CreateDirectory($parent)|Out-Null;[void](Assert-PathChain $repositoryRoot $parent -Strict)
    $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp';[void](Assert-PathChain $repositoryRoot $temp -Strict)
    try{[IO.File]::WriteAllBytes($temp,$utf8NoBom.GetBytes((ConvertTo-Json $Value -Depth 100 -Compress)+"`n"));if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temp,$Path,$null)}else{[IO.File]::Move($temp,$Path)}}finally{if(Test-Path -LiteralPath $temp){[IO.File]::Delete($temp)}}
}
function Get-RegistrySnapshot{
    param([string]$Directory)
    $items=@();if(Test-Path -LiteralPath $Directory -PathType Container){foreach($file in @(Get-ChildItem -Force -LiteralPath $Directory -File -Filter '*.json'|Sort-Object FullName)){[byte[]]$bytes=[IO.File]::ReadAllBytes($file.FullName);$record=ConvertFrom-Phase2RStrictJson -Json($utf8Strict.GetString($bytes))-Label $file.FullName;$items+=,[ordered]@{path=Get-CanonicalPath $file.FullName;sha256=Get-Sha256Hex $bytes;content_base64=[Convert]::ToBase64String($bytes);root=[string]$record.root;pid=[int]$record.pid;live=$null-ne(Get-Process -Id([int]$record.pid)-ErrorAction SilentlyContinue)}}};return @($items)
}
function Assert-OtherRegistryEqual{
    param([object[]]$Before,[object[]]$After,[string]$Root)
    $beforeOther=@($Before|Where-Object{-not(Get-CanonicalPath([string]$_.root)).Equals($Root,[StringComparison]::OrdinalIgnoreCase)});$afterOther=@($After|Where-Object{-not(Get-CanonicalPath([string]$_.root)).Equals($Root,[StringComparison]::OrdinalIgnoreCase)})
    $a=@($beforeOther|ForEach-Object{"$($_.path)|$($_.sha256)|$($_.pid)|$($_.live)"}|Sort-Object);$b=@($afterOther|ForEach-Object{"$($_.path)|$($_.sha256)|$($_.pid)|$($_.live)"}|Sort-Object)
    if([string]::Join("`n",$a)-cne[string]::Join("`n",$b)){throw 'OTHER_DAEMON_REGISTRY_DRIFT'}
}
function Get-HookSnapshot{
    $hooksValue=[string]::Join('',@(git -C $repositoryRoot rev-parse --git-path hooks)).Trim();if($LASTEXITCODE-ne 0-or[string]::IsNullOrWhiteSpace($hooksValue)){throw 'GIT_HOOK_PATH_FAILED'}
    $hooksDir=Get-CanonicalPath $(if([IO.Path]::IsPathRooted($hooksValue)){$hooksValue}else{Join-Path $repositoryRoot $hooksValue})
    [void](Assert-PathChain $repositoryRoot $hooksDir -Strict)
    if(-not(Test-Path -LiteralPath $hooksDir -PathType Container)){throw 'GIT_HOOK_DIRECTORY_MISSING_OR_NOT_DIRECTORY'}
    $result=@()
    foreach($name in @('post-commit','post-merge','post-checkout')){
        $path=Assert-PathChain $repositoryRoot (Join-Path $hooksDir $name) -Strict
        if(Test-Path -LiteralPath $path){
            if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "GIT_HOOK_NOT_REGULAR_FILE: $name"}
            $item=Get-Item -Force -LiteralPath $path;if($item.PSIsContainer-or($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "GIT_HOOK_REPARSE_OR_DIRECTORY: $name"}
            [byte[]]$bytes=[IO.File]::ReadAllBytes($path);$content=$utf8Strict.GetString($bytes)
            $beginCount=@([regex]::Matches($content,'(?m)^[ \t]*# >>> codegraph sync hook >>>[^\r\n]*(?=\r?$)')).Count
            $endCount=@([regex]::Matches($content,'(?m)^[ \t]*# <<< codegraph sync hook <<<[^\r\n]*(?=\r?$)')).Count
            if($beginCount-ne$endCount-or$beginCount-gt1){throw "GIT_HOOK_CODEGRAPH_MARKER_SHAPE: $name"}
            if($beginCount-eq1){[void](Get-CodeGraphOwnedHookRemainderBytes $content $name)}
            $result+=,[ordered]@{name=$name;path=$path;exists=$true;content=$content;content_base64=[Convert]::ToBase64String($bytes);sha256=Get-Sha256Hex $bytes}
        }else{$result+=,[ordered]@{name=$name;path=$path;exists=$false;content='';content_base64='';sha256=Get-Sha256Hex([byte[]]@())}}
    }
    return @($result)
}
function Get-CodeGraphOwnedHookRemainderBytes{
    param([string]$Text,[string]$Name)
    $pattern='(?ms)^[ \t]*# >>> codegraph sync hook >>>[^\r\n]*(?:\r\n|\n|\r).*?^[ \t]*# <<< codegraph sync hook <<<[^\r\n]*(?:(?:\r\n|\n|\r)|$)'
    $regex=[regex]::new($pattern)
    $matches=$regex.Matches($Text)
    if($matches.Count-ne1){throw "GIT_HOOK_OWNED_BLOCK_NOT_EXACTLY_ONE: $Name"}
    $remaining=$regex.Replace($Text,'',1)
    return ,([byte[]]$utf8NoBom.GetBytes($remaining))
}
function Assert-HookChangesBounded{
    param([object[]]$Before,[object[]]$After)
    if($Before.Count-ne3-or$After.Count-ne3){throw 'GIT_HOOK_SNAPSHOT_CARDINALITY'}
    foreach($old in $Before){
        $newMatches=@($After|Where-Object{$_.name-ceq$old.name});if($newMatches.Count-ne1){throw "GIT_HOOK_SNAPSHOT_IDENTITY: $($old.name)"};$new=$newMatches[0]
        if([string]$old.sha256-ceq[string]$new.sha256-and[bool]$old.exists-eq[bool]$new.exists){continue}
        if(-not[bool]$old.exists){throw "UNBOUNDED_GIT_HOOK_CREATED: $($old.name)"}
        [byte[]]$expected=@(Get-CodeGraphOwnedHookRemainderBytes ([string]$old.content) ([string]$old.name))
        if($expected.Length-eq0){
            if([bool]$new.exists-and[string]$new.content_base64-cne''){throw "GIT_HOOK_EXPECTED_EMPTY_AFTER_OWNED_BLOCK: $($old.name)"}
        }else{
            if(-not[bool]$new.exists-or[string]$new.content_base64-cne[Convert]::ToBase64String($expected)){throw "GIT_HOOK_NON_CODEGRAPH_BYTES_CHANGED_OR_DELETED: $($old.name)"}
        }
    }
}

$repositoryRoot=Get-CanonicalPath(Join-Path $PSScriptRoot '..\..');$reader=Assert-PathChain $repositoryRoot(Join-Path $repositoryRoot 'tools\testing\Read-StrictJson.ps1')-Strict;. $reader
$target=Get-CanonicalPath(Join-Path $repositoryRoot '.codegraph');$prerequisiteFull=Assert-PathChain $repositoryRoot $(if([IO.Path]::IsPathRooted($PrerequisiteEvidencePath)){$PrerequisiteEvidencePath}else{Join-Path $repositoryRoot $PrerequisiteEvidencePath}) -Strict
$removalFull=Assert-PathChain $repositoryRoot $(if([IO.Path]::IsPathRooted($RemovalEvidencePath)){$RemovalEvidencePath}else{Join-Path $repositoryRoot $RemovalEvidencePath}) -Strict

if(-not(Test-Path -LiteralPath $target)){
    if(-not(Test-Path -LiteralPath $removalFull -PathType Leaf)){throw 'VERIFY_ONLY_REMOVAL_EVIDENCE_MISSING'}
    [void](Assert-PathChain $repositoryRoot $repositoryRoot)
    [void](Assert-PathChain $repositoryRoot $target -Strict)
    if(Test-Path -LiteralPath $target){throw 'VERIFY_ONLY_CODEGRAPH_TARGET_REAPPEARED'}
    $project=Assert-PathChain $repositoryRoot (Join-Path $repositoryRoot 'project.godot') -Strict
    if(-not(Test-Path -LiteralPath $project -PathType Leaf)){throw 'VERIFY_ONLY_PROJECT_GODOT_MISSING'}
    $projectItem=Get-Item -Force -LiteralPath $project;if($projectItem.PSIsContainer-or($projectItem.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'VERIFY_ONLY_PROJECT_GODOT_NOT_REGULAR'}
    $gitResolution=Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue
    if($null-eq$gitResolution){$gitResolution=Get-Command git -CommandType Application -ErrorAction Stop}
    $gitCommand=$gitResolution.Source
    $gitRootResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--show-toplevel')
    if([int]$gitRootResult.exit_code-ne0-or-not(Get-CanonicalPath([string]$gitRootResult.stdout.Trim())).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'VERIFY_ONLY_GIT_ROOT_MISMATCH'}
    $gitPrefixResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--show-prefix')
    if([int]$gitPrefixResult.exit_code-ne0-or-not[string]::IsNullOrWhiteSpace([string]$gitPrefixResult.stdout)){throw 'VERIFY_ONLY_GIT_PREFIX_NOT_EMPTY'}
    $insideResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--is-inside-work-tree')
    if([int]$insideResult.exit_code-ne0-or([string]$insideResult.stdout).Trim()-cne'true'){throw 'VERIFY_ONLY_NOT_GIT_WORKTREE'}
    $existing=Read-StrictFile $removalFull 'CodeGraph removal evidence';if([int]$existing.schema_version-ne1-or-not(Get-CanonicalPath([string]$existing.canonical_root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)-or-not(Get-CanonicalPath([string]$existing.canonical_target)).Equals($target,[StringComparison]::OrdinalIgnoreCase)){throw 'VERIFY_ONLY_REMOVAL_IDENTITY_DRIFT'};$checks=@($existing.absent_checks)
    if([string]::Join("`n",$checks)-cne'immediate'){throw 'VERIFY_ONLY_ABSENT_CHECK_STATE_INVALID'}
    if(-not(Test-Path -LiteralPath $prerequisiteFull -PathType Leaf)){throw 'VERIFY_ONLY_PREREQUISITE_EVIDENCE_MISSING'}
    $prerequisiteItem=Get-Item -Force -LiteralPath $prerequisiteFull;if($prerequisiteItem.PSIsContainer-or($prerequisiteItem.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'VERIFY_ONLY_PREREQUISITE_NOT_REGULAR'}
    if((Get-Sha256Hex([IO.File]::ReadAllBytes($prerequisiteFull)))-cne[string]$existing.prerequisite_sha256){throw 'VERIFY_ONLY_PREREQUISITE_SHA256_DRIFT'}
    $verifiedPrerequisite=Read-StrictFile $prerequisiteFull 'verify-only CodeGraph prerequisite evidence'
    foreach($name in @('beads_issue_lookup_operational','documentation_issue_closed_with_bound_evidence','requirement_index_lookup_operational','verified_rg_inspection_operational','rg_source_inventory_covers_project_gdscript_and_scenes','global_codegraph_identity_matches_baseline','repository_root_identity_proven','repository_codegraph_tree_reparse_free','daemon_identity_proven_or_absent')){if($verifiedPrerequisite.$name-ne$true){throw "VERIFY_ONLY_PREREQUISITE_FALSE: $name"}}
    $sentinelResult=Invoke-RemovalCommand $gitCommand @('rev-parse','--verify','HEAD:.codegraph/.gitignore')
    if([int]$sentinelResult.exit_code-ne0-or([string]$sentinelResult.stdout).Trim()-cne[string]$existing.tracked_sentinel_blob){throw 'VERIFY_ONLY_TRACKED_SENTINEL_IDENTITY_DRIFT'}
    $currentCommand=(Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop).Source;[byte[]]$bytes=[IO.File]::ReadAllBytes($currentCommand);$versionOutput=@(& $currentCommand --version 2>&1);if($LASTEXITCODE-ne0){throw 'VERIFY_ONLY_CODEGRAPH_VERSION_FAILED'};$version=([string]::Join([Environment]::NewLine,$versionOutput)).Trim()
    if(-not(Get-CanonicalPath $currentCommand).Equals((Get-CanonicalPath([string]$existing.codegraph_after.path)),[StringComparison]::OrdinalIgnoreCase)-or(Get-Sha256Hex $bytes)-cne[string]$existing.codegraph_after.sha256-or$version-cne[string]$existing.codegraph_after.version){throw 'VERIFY_ONLY_GLOBAL_CODEGRAPH_DRIFT'}
    $registry=Get-RegistrySnapshot(Get-CanonicalPath(Join-Path $HOME '.codegraph\daemons'));if(@($registry|Where-Object{(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)}).Count-ne 0){throw 'VERIFY_ONLY_PROJECT_DAEMON_RECORD_SURVIVED'}
    Assert-OtherRegistryEqual @($existing.other_registry_records) $registry $repositoryRoot
    $existing.absent_checks=@('immediate','post_tooling_suite');Write-AtomicJson $removalFull $existing
    $written=Read-StrictFile $removalFull 'written verify-only CodeGraph removal evidence';if([string]::Join("`n",@($written.absent_checks))-cne[string]::Join("`n",@('immediate','post_tooling_suite'))){throw 'VERIFY_ONLY_WRITTEN_ABSENT_CHECK_DRIFT'}
    Write-Output 'CODEGRAPH_REMOVAL: PASS verify-only';exit 0
}

$prerequisite=Read-StrictFile $prerequisiteFull 'CodeGraph prerequisite evidence'
if([Environment]::GetEnvironmentVariable('DWM_CODEGRAPH_REMOVAL_AUTHORIZED')-cne'1'){throw 'CODEGRAPH_REMOVAL_AUTHORITY_REQUIRED'}
[void](Assert-PathChain $repositoryRoot $target -Strict);Assert-TreeSafe $target
foreach($name in @('beads_issue_lookup_operational','documentation_issue_closed_with_bound_evidence','requirement_index_lookup_operational','verified_rg_inspection_operational','rg_source_inventory_covers_project_gdscript_and_scenes','global_codegraph_identity_matches_baseline','repository_root_identity_proven','repository_codegraph_tree_reparse_free','daemon_identity_proven_or_absent')){if($prerequisite.$name-ne$true){throw "PREREQUISITE_FALSE: $name"}}
if(-not(Get-CanonicalPath([string]$prerequisite.canonical_root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)-or-not(Get-CanonicalPath([string]$prerequisite.canonical_target)).Equals($target,[StringComparison]::OrdinalIgnoreCase)){throw 'PREREQUISITE_ROOT_DRIFT'}
$freshPath=Join-Path $repositoryRoot('.godot\phase2r_tests\'+[guid]::NewGuid().ToString('D')+'\codegraph-prerequisites.json');$verifyScript=Assert-PathChain $repositoryRoot(Join-Path $repositoryRoot 'tools\tooling\Verify-CodeGraphPrerequisites.ps1')-Strict
& $verifyScript -EvidencePath $freshPath;if($LASTEXITCODE-ne 0){throw 'FRESH_PREREQUISITE_RECHECK_FAILED'};$fresh=Read-StrictFile $freshPath 'fresh prerequisite evidence'
foreach($field in @('canonical_root','canonical_target')){if([string]$fresh.$field-cne[string]$prerequisite.$field){throw "FRESH_PREREQUISITE_DRIFT: $field"}}
foreach($field in @('path','sha256','version','package_root','package_version','node_path','node_sha256','daemon_module_path','daemon_module_sha256')){if([string]$fresh.codegraph_command.$field-cne[string]$prerequisite.codegraph_command.$field){throw "FRESH_CODEGRAPH_IDENTITY_DRIFT: $field"}}
if((ConvertTo-Json $fresh.p2r1_closure -Depth 20 -Compress)-cne(ConvertTo-Json $prerequisite.p2r1_closure -Depth 20 -Compress)){throw 'FRESH_P2R1_CLOSURE_EVIDENCE_DRIFT'}
[IO.File]::Delete($freshPath);$freshParent=Split-Path -Parent $freshPath;if(Test-Path -LiteralPath $freshParent){[void](Assert-PathChain $repositoryRoot $freshParent -Strict);Assert-TreeSafe $freshParent;Remove-Item -LiteralPath $freshParent -Recurse -Force;if(Test-Path -LiteralPath $freshParent){throw 'FRESH_PREREQUISITE_SCRATCH_SURVIVED'}}

$statusBefore=@(git -C $repositoryRoot status --porcelain=v1);if($LASTEXITCODE-ne 0){throw 'GIT_STATUS_BEFORE_FAILED'};if(@($statusBefore|Where-Object{$_-match '[ /]\.codegraph/\.gitignore$'}).Count-ne0){throw 'CODEGRAPH_SENTINEL_ALREADY_DIRTY'};$hooksBefore=Get-HookSnapshot;$registryDir=Get-CanonicalPath(Join-Path $HOME '.codegraph\daemons');$registryBefore=Get-RegistrySnapshot $registryDir
$daemonOutcome=[ordered]@{root=$repositoryRoot;pid=$null;outcome='absent'}
$daemonState=[string]$fresh.daemon.state
if($daemonState-in@('live','stale')){
    $helper=Assert-PathChain $repositoryRoot(Join-Path $repositoryRoot 'tools\tooling\stop_repository_codegraph_daemon.cjs')-Strict;$node=[string]$fresh.codegraph_command.node_path;$module=[string]$fresh.codegraph_command.daemon_module_path;$moduleHash=[string]$fresh.codegraph_command.daemon_module_sha256
    $lines=@(& $node $helper $module $moduleHash $repositoryRoot 2>&1);if($LASTEXITCODE-ne 0){throw('PROJECT_DAEMON_STOP_FAILED: '+([string]::Join("`n",$lines)))}
    $json=[string]::Join([Environment]::NewLine,$lines).Trim();$daemonOutcome=ConvertFrom-Phase2RStrictJson -Json $json -Label 'root-scoped daemon stop';$keys=@($daemonOutcome.PSObject.Properties.Name)
    if([string]::Join("`n",$keys)-cne[string]::Join("`n",@('root','pid','outcome'))){throw 'DAEMON_STOP_RESULT_SHAPE'}
    $allowedOutcome=if($daemonState-ceq'live'){@('term','kill')}else{@('not-running')}
    if(-not(Get-CanonicalPath([string]$daemonOutcome.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)-or[int]$daemonOutcome.pid-ne[int]$fresh.daemon.pid-or[string]$daemonOutcome.outcome-notin$allowedOutcome){throw 'DAEMON_STOP_RESULT_DRIFT'}
}elseif($daemonState-cne'absent'){throw "DAEMON_STATE_INVALID: $daemonState"}
$registryAfterStop=Get-RegistrySnapshot $registryDir
if(@($registryAfterStop|Where-Object{(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)}).Count-ne0){throw 'PROJECT_DAEMON_REGISTRY_SURVIVED'}
Assert-OtherRegistryEqual $registryBefore $registryAfterStop $repositoryRoot

[void](Assert-PathChain $repositoryRoot $target -Strict);Assert-TreeSafe $target
$codegraphCommand=[string]$fresh.codegraph_command.path;$uninitArgv=@('uninit','--force',$repositoryRoot);$uninitResult=Invoke-RemovalCommand $codegraphCommand $uninitArgv;$uninitExit=[int]$uninitResult.exit_code;$uninitText=[string]$uninitResult.stdout
if($uninitExit-ne 0-or-not$uninitText.Contains($repositoryRoot)){throw "CODEGRAPH_UNINIT_FAILED_OR_WRONG_ROOT: exit=$uninitExit stdout=$uninitText stderr=$($uninitResult.stderr)"}
if(Test-Path -LiteralPath $target){throw 'CODEGRAPH_TARGET_SURVIVED'};if(-not(Test-Path -LiteralPath(Join-Path $repositoryRoot 'project.godot'))){throw 'PROJECT_GODOT_REMOVED'}
$statusAfter=@(git -C $repositoryRoot status --porcelain=v1);if($LASTEXITCODE-ne 0){throw 'GIT_STATUS_AFTER_FAILED'};$addedStatus=@($statusAfter|Where-Object{$_-notin$statusBefore});$removedStatus=@($statusBefore|Where-Object{$_-notin$statusAfter});if($removedStatus.Count-ne 0-or@($addedStatus|Where-Object{$_-cne' D .codegraph/.gitignore'}).Count-ne 0-or' D .codegraph/.gitignore'-notin$addedStatus){throw 'UNINIT_WORKTREE_SCOPE_DRIFT'}
$hooksAfter=Get-HookSnapshot;Assert-HookChangesBounded $hooksBefore $hooksAfter
$afterCommand=(Get-Command codegraph.cmd -CommandType Application -ErrorAction Stop).Source;[byte[]]$afterBytes=[IO.File]::ReadAllBytes($afterCommand);$afterVersion=([string]::Join([Environment]::NewLine,@(& $afterCommand --version))).Trim();if((Get-Sha256Hex $afterBytes)-cne[string]$fresh.codegraph_command.sha256-or$afterVersion-cne[string]$fresh.codegraph_command.version){throw 'GLOBAL_CODEGRAPH_CHANGED_BY_UNINIT'}
$registryAfter=Get-RegistrySnapshot $registryDir;Assert-OtherRegistryEqual $registryBefore $registryAfter $repositoryRoot
$sentinelBlob=[string]::Join('',@(git -C $repositoryRoot rev-parse 'HEAD:.codegraph/.gitignore')).Trim();if($LASTEXITCODE-ne 0){throw 'TRACKED_SENTINEL_BLOB_MISSING'}
$otherRegistry=@($registryAfter|Where-Object{-not(Get-CanonicalPath([string]$_.root)).Equals($repositoryRoot,[StringComparison]::OrdinalIgnoreCase)})
$removal=[ordered]@{schema_version=1;canonical_root=$repositoryRoot;canonical_target=$target;tracked_sentinel_blob=$sentinelBlob;prerequisite_sha256=Get-Sha256Hex([IO.File]::ReadAllBytes($prerequisiteFull));daemon=$daemonOutcome;uninit=[ordered]@{argv=@($codegraphCommand)+$uninitArgv;exit_code=[int]$uninitExit;stdout_sha256=[string]$uninitResult.stdout_sha256;stderr_sha256=[string]$uninitResult.stderr_sha256};codegraph_before=$fresh.codegraph_command;codegraph_after=[ordered]@{path=Get-CanonicalPath $afterCommand;sha256=Get-Sha256Hex $afterBytes;version=$afterVersion};other_daemons_equal=$true;other_registry_records=@($otherRegistry);git_status_before=@($statusBefore);git_status_after=@($statusAfter);absent_checks=@('immediate')}
Write-AtomicJson $removalFull $removal;Write-Output("CODEGRAPH_REMOVAL: PASS outcome={0}"-f$daemonOutcome.outcome)
~~~

Run the script only after plan approval, `dwm-p2r.1` closure, strict validation of GREEN prerequisite evidence, and explicit authority for the exact repository `.codegraph/` removal. Its behavior is closed:

1. Recompute every Git/project-root, direct-child, tracked-sentinel, baseline global-command identity, and complete nested-reparse proof from Step 5.2; compare the recomputed values to `codegraph_prerequisites.json`. Never trust the evidence path alone. Capture `git status --short` and the current `.codegraph/.gitignore` Git blob before mutation.
2. Strict-parse `.codegraph/daemon.pid` when present and resolve its PID. If live, require the exact lock/registry/process identity proof from Step 5.2 immediately before stopping it; if stale, require at most the one root-matching stale registry record before cleanup. Do not use `Stop-Process`, a name-based kill, a stop-all operation, or the interactive `codegraph daemon` command.
3. The prerequisite evidence pins the installed package version plus the SHA-256 and resolved path of its exported `dist/mcp/daemon-registry.js`. Run the checked-in `stop_repository_codegraph_daemon.cjs` with the baseline-matched launcher’s resolved Node executable, that exact module path/hash, and the canonical repository root. The helper imports only the exported `stopDaemonAt(root)`, invokes it for that one root, requires the exact `{root,pid,outcome}` API shape, and preserves the package’s real outcome: `term` or `kill` for a live PID, `not-running` for a stale PID, and helper-owned `absent` only when no lock exists. Reject a missing export, hash/version/path drift, a returned root/PID/outcome mismatch, or a still-live PID. Verify that the project daemon lock and every root-matching registry record are gone and every other registry record/process is byte-for-byte/pid-for-pid unchanged. This is the package's own root-scoped daemon cleanup; it neither edits nor uninstalls package files.
4. Re-run the complete canonical root/direct-child/nested-reparse check. Invoke the supported repository command with an explicit canonical path: `& $codegraphCommandPath uninit --force $repositoryRoot`. Require exit zero and output naming the exact repository root. Do not call `uninstall`, do not call `Remove-Item`, and do not remove a parent, package cache, global registry directory, `codegraph.cmd`, or global module file.
5. Require `.codegraph` absent immediately. Prove `project.godot` and the Git root still exist; prove the only worktree changes caused by the command are deletion of the tracked `.codegraph/.gitignore` and, if the official command had installed one, removal of its own bounded CodeGraph block from this repository's Git sync hook. Before mutation, require the configured hooks directory and all three candidate hook paths to be repository-contained and reparse-free. A changed hook may be deleted only when removing exactly one byte-delimited owned CodeGraph block leaves zero bytes; otherwise the new regular-file bytes must exactly equal the old bytes minus that one block. Any marker imbalance, second block, unrelated byte change, hook creation, unsafe path, or other worktree mutation is fatal and must be reported without cleanup.
6. Re-resolve `codegraph.cmd`, hash it, and run `--version`; require exact equality with the immutable baseline. Re-read all other daemon registry records and process IDs and require equality with their pre-stop snapshot.
7. Write `codegraph_removal.json` atomically as primitive-only JSON containing canonical root/target, tracked sentinel blob, prerequisite evidence SHA-256, daemon identity/outcome, exact `uninit` argv/exit/stdout/stderr hashes, before/after global-command identity, other-daemon equality, Git diff, and `absent_checks: ["immediate"]`. The script never recreates `.codegraph` to write evidence.

`stop_repository_codegraph_daemon.cjs` is not a generic process killer. Use this paste-ready CommonJS body; it verifies its own module bytes again, strict-parses the one repository lock, imports only the pinned module, calls only `stopDaemonAt(canonicalRoot)`, and emits exactly one JSON line:

~~~javascript
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
  throw new Error(message);
}

function canonicalExisting(input, label) {
  const absolute = path.resolve(input);
  if (!fs.existsSync(absolute)) fail(`${label}_MISSING: ${absolute}`);
  return fs.realpathSync.native(absolute);
}

function parseStrictJson(text, label) {
  let i = 0;
  function whitespace() { while (i < text.length && /[\x20\t\r\n]/.test(text[i])) i += 1; }
  function stringToken() {
    const start = i;
    if (text[i++] !== '"') fail(`${label}_JSON_STRING`);
    while (i < text.length) {
      if (text.charCodeAt(i) < 0x20) fail(`${label}_JSON_CONTROL`);
      if (text[i] === '"') { i += 1; return JSON.parse(text.slice(start, i)); }
      if (text[i] === '\\') {
        i += 1;
        if (!/^["\\/bfnrtu]$/.test(text[i] || '')) fail(`${label}_JSON_ESCAPE`);
        if (text[i] === 'u') {
          if (!/^[0-9a-fA-F]{4}$/.test(text.slice(i + 1, i + 5))) fail(`${label}_JSON_UNICODE`);
          i += 4;
        }
      }
      i += 1;
    }
    fail(`${label}_JSON_UNTERMINATED_STRING`);
  }
  function value() {
    whitespace();
    if (text[i] === '{') return object();
    if (text[i] === '[') return array();
    if (text[i] === '"') return stringToken();
    const remaining = text.slice(i);
    const token = /^(?:true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)/.exec(remaining);
    if (!token) fail(`${label}_JSON_VALUE`);
    i += token[0].length;
    return JSON.parse(token[0]);
  }
  function object() {
    i += 1; whitespace();
    const output = {}; const seen = new Set();
    if (text[i] === '}') { i += 1; return output; }
    while (true) {
      whitespace();
      if (text[i] !== '"') fail(`${label}_JSON_KEY`);
      const key = stringToken();
      if (seen.has(key)) fail(`${label}_JSON_DUPLICATE_MEMBER: ${key}`);
      seen.add(key); whitespace();
      if (text[i++] !== ':') fail(`${label}_JSON_COLON`);
      output[key] = value(); whitespace();
      if (text[i] === '}') { i += 1; return output; }
      if (text[i++] !== ',') fail(`${label}_JSON_COMMA`);
    }
  }
  function array() {
    i += 1; whitespace();
    const output = [];
    if (text[i] === ']') { i += 1; return output; }
    while (true) {
      output.push(value()); whitespace();
      if (text[i] === ']') { i += 1; return output; }
      if (text[i++] !== ',') fail(`${label}_JSON_COMMA`);
    }
  }
  const parsed = value(); whitespace();
  if (i !== text.length) fail(`${label}_JSON_TRAILING_DATA`);
  return parsed;
}

function live(pid) {
  try { process.kill(pid, 0); return true; }
  catch (error) {
    if (error && error.code === 'ESRCH') return false;
    throw error;
  }
}

async function waitForExit(pid) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    if (!live(pid)) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  fail(`DAEMON_STILL_LIVE: ${pid}`);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 3) fail('USAGE: stop_repository_codegraph_daemon.cjs <module-path> <module-sha256> <repository-root>');
  const [moduleArgument, expectedHash, rootArgument] = args;
  if (!/^[0-9a-f]{64}$/.test(expectedHash)) fail('MODULE_SHA256_INVALID');
  const modulePath = canonicalExisting(moduleArgument, 'MODULE');
  const repositoryRoot = canonicalExisting(rootArgument, 'REPOSITORY_ROOT');
  if (path.basename(modulePath).toLowerCase() !== 'daemon-registry.js') fail('MODULE_BASENAME_INVALID');
  const actualHash = crypto.createHash('sha256').update(fs.readFileSync(modulePath)).digest('hex');
  if (actualHash !== expectedHash) fail(`MODULE_SHA256_DRIFT: ${actualHash}`);
  const projectFile = path.join(repositoryRoot, 'project.godot');
  if (!fs.statSync(projectFile).isFile()) fail('REPOSITORY_PROJECT_MISSING');
  const lockPath = path.join(repositoryRoot, '.codegraph', 'daemon.pid');
  if (!fs.existsSync(lockPath)) {
    process.stdout.write(`${JSON.stringify({ root: repositoryRoot, pid: null, outcome: 'absent' })}\n`);
    return;
  }
  const lock = parseStrictJson(fs.readFileSync(lockPath, 'utf8'), 'DAEMON_LOCK');
  if (!lock || typeof lock !== 'object' || Array.isArray(lock)) fail('DAEMON_LOCK_OBJECT_REQUIRED');
  const pid = Number(lock.pid);
  if (!Number.isSafeInteger(pid) || pid <= 0) fail('DAEMON_LOCK_PID_INVALID');
  if (typeof lock.root === 'string' && canonicalExisting(lock.root, 'DAEMON_LOCK_ROOT') !== repositoryRoot) fail('DAEMON_LOCK_ROOT_MISMATCH');
  const wasLive = live(pid);

  const imported = await import(pathToFileURL(modulePath).href);
  const stopDaemonAt = imported.stopDaemonAt || (imported.default && imported.default.stopDaemonAt);
  if (typeof stopDaemonAt !== 'function') fail('STOP_DAEMON_AT_EXPORT_MISSING');
  const returned = await stopDaemonAt(repositoryRoot);
  if (!returned || typeof returned !== 'object' || Array.isArray(returned)) fail('STOP_DAEMON_AT_RESULT_OBJECT_REQUIRED');
  const returnedKeys = Object.keys(returned).sort();
  if (JSON.stringify(returnedKeys) !== JSON.stringify(['outcome', 'pid', 'root'])) fail('STOP_DAEMON_AT_RESULT_KEYS');
  if (typeof returned.root !== 'string' || canonicalExisting(returned.root, 'RETURNED_ROOT') !== repositoryRoot) fail('RETURNED_ROOT_MISMATCH');
  if (!Number.isSafeInteger(Number(returned.pid)) || Number(returned.pid) !== pid) fail('RETURNED_PID_MISMATCH');
  const allowedOutcomes = wasLive ? ['term', 'kill'] : ['not-running'];
  if (!allowedOutcomes.includes(returned.outcome)) fail(`RETURNED_OUTCOME_INVALID: ${String(returned.outcome)}`);
  if (wasLive) await waitForExit(pid);
  if (fs.existsSync(lockPath)) fail('DAEMON_LOCK_SURVIVED');
  process.stdout.write(`${JSON.stringify({ root: repositoryRoot, pid, outcome: returned.outcome })}\n`);
}

main().catch((error) => {
  if (!process.exitCode) {
    process.stderr.write(`${error && error.message ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
});
~~~

The helper RED fixture is already complete in Step 5.1 and MUST be run before creating this file. It uses only a fake module and isolated temporary root; it never points at the installed package or a live daemon.

Run:

~~~powershell
& .\tests\tooling\Test-CodeGraphRemovalScripts.ps1
& .\tools\tooling\Remove-RepositoryCodeGraph.ps1 -PrerequisiteEvidencePath 'evidence/phase_2r/tooling/codegraph_prerequisites.json' -RemovalEvidencePath 'evidence/phase_2r/tooling/codegraph_removal.json'
~~~

Expected: only the identity-proven daemon for this root is stopped; official `codegraph uninit --force <canonical-root>` succeeds; repository `.codegraph/` is absent; other daemons and every global install byte are unchanged.

- [ ] **Step 5.4: Verify removal and active-reference scope**

Run the focused test again:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task5-codegraph-green' -LogName 'phase2r-green-codegraph.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_repository_tooling.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

Search authoritative project-consumer paths only:

~~~powershell
rg -n -i 'codegraph|\.codegraph' Prompt.md prompt_docs autoload scripts scenes tests tools project.godot
~~~

Expected active matches are limited to the completed `req.codegraph.removal` record plus its test/evidence tooling. There are zero import, command, configuration, or CodeGraph-first consumers. Historical specifications/plans/evidence and preserved-outside-authority `CLAUDE.md` are excluded from active context.

Re-resolve `codegraph.cmd`, recompute its SHA-256 and version, and require exact equality with `baseline.json.external_tools.codegraph_command`. A missing or changed global command is a failing Task 5 result.

Then run:

~~~powershell
bd dep cycles
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task5-tooling-suite' -LogName 'phase2r-green-tooling-suite.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests/unit/tooling','-ginclude_subdirs','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
if (Test-Path -LiteralPath '.codegraph') { throw 'Repository CodeGraph was recreated during verification.' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'task5-codegraph-stays-absent' -LogName 'phase2r-codegraph-stays-absent.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_repository_tooling.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\tooling\Remove-RepositoryCodeGraph.ps1 -PrerequisiteEvidencePath 'evidence/phase_2r/tooling/codegraph_prerequisites.json' -RemovalEvidencePath 'evidence/phase_2r/tooling/codegraph_removal.json'
git status --short
~~~

On this second `Remove-RepositoryCodeGraph.ps1` invocation, an absent target plus an existing valid removal record selects verify-only mode: it MUST NOT stop any process or call `uninit`. It independently re-proves the canonical reparse-free repository root, empty Git prefix, inside-worktree identity, regular `project.godot`, direct-child target absence, committed sentinel blob identity, current prerequisite-evidence SHA-256 and all nine booleans, no project daemon record, exact other-daemon equality, and global-command identity. Only then does it atomically change `absent_checks` from exactly `["immediate"]` to exactly `["immediate","post_tooling_suite"]` and strict-parse the written record. Any other prior state fails closed. Expected: no Beads dependency cycles, both absence tests and all tooling tests GREEN, `.codegraph/` stayed absent across the entire suite, and the final Phase 2R gate will prove absence once more before closing `dwm-p2r.2`.
- [ ] **Step 5.5: Path-specific proposed commit boundary**

Do not run without exact commit authority and DWM_CODEGRAPH_REMOVAL_AUTHORIZED=1. The three active-document paths are conditional modifications, not optional UIDs: add each one to the required map only after its own Git quiet result is classified as unchanged 0, changed 1, or fatal error.

~~~powershell
$required = [ordered]@{
  'tools/tooling/Verify-CodeGraphPrerequisites.ps1'='A'
  'tools/tooling/Remove-RepositoryCodeGraph.ps1'='A'
  'tools/tooling/stop_repository_codegraph_daemon.cjs'='A'
  'tests/unit/tooling/test_repository_tooling.gd'='A'
  'tests/tooling/Test-CodeGraphRemovalScripts.ps1'='A'
  'evidence/phase_2r/tooling/codegraph_prerequisites.json'='A'
  'evidence/phase_2r/tooling/codegraph_removal.json'='A'
  '.codegraph/.gitignore'='D'
}
foreach ($path in @(
  'Prompt.md',
  'prompt_docs/phases/phase_2r.md',
  'prompt_docs/requirements/documentation_tooling.md'
)) {
  & git diff --quiet -- $path
  $quietExit = $LASTEXITCODE
  if ($quietExit -eq 1) {
    $required[$path] = 'M'
  } elseif ($quietExit -ne 0) {
    throw ('Cannot classify conditional Task 5 path with Git exit {0}: {1}' -f $quietExit,$path)
  }
}
$optionalUids = [ordered]@{
  'tests/unit/tooling/test_repository_tooling.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Task 5 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -RequiredAuthorityVariables @('DWM_CODEGRAPH_REMOVAL_AUTHORIZED') -ExpectedHead $expectedHead -Message 'chore: remove ineffective repository CodeGraph metadata'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 5 removal commit boundary failed.' }
~~~

## Issue Completion Checks

- [ ] Close `dwm-p2r.1` only after Tasks 1–4 are GREEN; every child metadata record validates; deferred decision `dwm-eob` validates without becoming a Phase 2R blocker; exactly one `phase2r_archive_commit=<object-id>` note is present; and `.1` has exactly one hashed evidence-link path binding for each of the four path/requirement pairs frozen in `Assert-P2R1ClosureEvidence`. Before closing, compute each SHA-256 from the current regular reparse-free file, retain a nonempty isolated command-record ID, update only `metadata.phase2r.evidence_links`, run `Sync-Phase2RMetadata.ps1` plus a strict all-status export, and prove all unrelated metadata is semantically unchanged. Close `.1` only after that GREEN snapshot and permit no file/metadata changes between it and Task 5's independent closed-record proof.
- [ ] If archival commit or deletion authority is absent, leave `dwm-p2r.1` open and all deletion targets intact. This is an authorization gate, not a test failure.
- [ ] Close `dwm-p2r.2` only after Task 5 is GREEN, active CodeGraph-first references are absent, repository `.codegraph/` is absent, and the global installation is proven untouched.
- [ ] Run `bd list --status all --json --readonly` and validate the exact structured metadata contract for `dwm-p2r.1` through `dwm-p2r.10` plus deferred `dwm-eob`.
- [ ] Run `bd ready --json --readonly`; `dwm-p2r.3` and `dwm-p2r.4` should be ready only after `.1` closes, while downstream issues remain blocked.
- [ ] Do not claim either runtime issue until the implementation-plan approval gate has passed.
