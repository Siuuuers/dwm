# Seven-Day Constellation Documentation Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan.

**Goal:** Reconcile the seven-day narrative documents with the approved Two-Pass Constellation, preserving all current creative provenance while producing a plot-free fixed-week skeleton that is safe to use for Day 1 candidate auditions.

**Architecture:** Preserve the owner-approved dirty story baseline first, archive the complete named Production Map verbatim, then separate authority into five layers: August mechanical law, Bible canon, Handbook performance guidance, a plot-neutral Production Map, and an inspectable causal matrix. Room 2.17 survives as an approved but unplaced causal core. All other named premises remain noncanonical audition history until explicit owner approval promotes a compact record into the matrix.

**Tech Stack:** Markdown narrative artifacts, PowerShell 5.1 verification scripts, Git, repository exact-path commit helper, Godot 4.x documentation validator where applicable.

**Spec:** [`docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md`](../specs/2026-08-28-seven-day-two-pass-constellation-design.md)

## Global Constraints

- This plan is documentation reconciliation only. Do not edit Godot, GDScript, Dialogic timelines, `prompt_docs/`, save data, Beads records, or generated evidence.
- Do not start Day 1 creative auditions, select a new date premise, write final dialogue, or assign Room 2.17 to Day 2 or Day 6 while executing this plan.
- The implementation plan must be owner-approved and its specification metadata must say `implementation_authorized: true` before Task 0 begins. The plan is initially `proposed`.
- Treat [`docs/design/2026-08-07-seven-day-dialogic-flow-design.md`](../../design/2026-08-07-seven-day-dialogic-flow-design.md) as mechanical authority and [`story/01-core-story-bible.md`](../../../story/01-core-story-bible.md) as narrative authority.
- Preserve user-authored dirty work. Stage and commit only the exact paths named in each task. Never use broad `git add`, `git reset`, `git checkout`, or destructive cleanup.
- Make all prose edits with `apply_patch`. Mechanical formatting may be run only after reviewing its exact target and diff.
- Stop if the Task 0 status or canonical-LF hashes do not match the recorded baseline. Drift means the owner has changed the source since planning; inspect and amend the plan rather than overwriting it.
- Keep candidate status exact: `UNSELECTED → AUDITIONING → SELECTED FOR APPROVAL → APPROVED`; use `REOPENED` only for a previously approved row. `SURVIVES`, `MUTATE`, and `REJECT` are audition verdicts, not canon states.
- Every active authority statement must distinguish fact, inference, and current runtime drift. Executable behavior does not silently amend approved design.
- All illustrative Room 2.17 language remains `REACTION TEST`, never final DTL.
- Do not install plugins or use external services. Beads currently reports `database not found: dwm`; this plan does not depend on Beads.

---

## Shared Interfaces

### Authority ladder

1. August 7 design: calendar, messages, promotion, pair protocol, Hospital, Day 7, ending, and Dialogic law.
2. Core Story Bible: character, relationship, atmosphere, hidden history, protected narrative facts, and intended meaning.
3. Character & Relationship Handbook: derived performance guidance only.
4. Seven-Day Causal Matrix: fixed Pass One obligations plus explicitly approved premise records.
5. Plot-neutral Production Map: reusable production-card and rendering schema only.
6. Scene Beatbook: detailed execution only after a premise earns expansion; Room 2.17 is the sole approved-but-unplaced exception.
7. Plot Material Library and July amendments: noncanonical or historical provenance, never active authority.

### Stable encounter-window IDs

The causal matrix must use these fourteen authoring IDs exactly once in its marked encounter registry:

```text
solo.priscilla.day_1
solo.sylvia.day_1
solo.priscilla.day_2
solo.lavinia.day_2
pair.priscilla_lavinia.day_2
solo.lavinia.day_3
solo.sylvia.day_3
solo.priscilla.day_4
solo.sylvia.day_4
solo.lavinia.day_5
solo.sylvia.day_5
solo.priscilla.day_6
solo.lavinia.day_6
pair.priscilla_lavinia.day_6
```

These are documentation identities, not promises about final runtime DTL labels.

### Stable ordinary-contact IDs

The message/echo ledger must use these six IDs exactly once in its marked registry:

```text
contact.ordinary.lavinia.day1
contact.ordinary.sylvia.day2
contact.ordinary.priscilla.day3
contact.ordinary.lavinia.day4
contact.ordinary.priscilla.day5
contact.ordinary.sylvia.day6
```

Each message record owns a contextual echo carrier and an unavoidable Day 7 fallback.

### Approved matrix-row interface

An approved premise row contains exactly these fields:

- stable encounter/window ID and exact day;
- `APPROVED` status and dated approval record;
- compact premise and ordinary task;
- participants and authorized visibility modes;
- incoming cause and lawful knowledge;
- smallest irreversible change;
- concrete evidence and guaranteed fallback carrier;
- outgoing consequence and Day 7 debt;
- absence, missed, Hospital, private, and prevented behavior where applicable;
- abnormality allowance and unresolved cause;
- promotion or protected-anchor obligation;
- Beatbook link only when expansion is earned.

No approved placed premise exists at the start of this implementation.

### Exact-path commit contract

Every commit task uses `tools/git/Invoke-ExactPathCommit.ps1`. Run it from a PowerShell process with execution policy bypassed, an empty index, a freshly captured `HEAD`, `DWM_COMMIT_AUTHORIZED=1`, and an ordered map containing only that task's paths. A successful call ends with:

```text
EXACT_PATH_COMMIT: PASS <40-character commit>
```

Never add `-RequireRemainingDirtyExact`; unrelated owner work may remain dirty.

## Execution Checklist

- [ ] Owner Approval Transaction binds this exact plan digest and execution mode before implementation.
- [ ] Task 0 preserves the exact current story baseline behind hash and authority gates.
- [ ] Task 1 archives that baseline's complete named Production Map verbatim.
- [ ] Task 2 establishes the active authority/navigation map.
- [ ] Task 3 corrects active relationship-state and performance law.
- [ ] Task 4 demotes unapproved premises and aligns ending law.
- [ ] Task 5 rewrites the Production Map as a plot-neutral template.
- [ ] Task 6 creates the fixed, open Causal Matrix.
- [ ] Task 7 repairs Scene Beatbook authority while keeping Room 2.17 unplaced.
- [ ] Task 8 preserves July reasoning beneath historical supersession notices.
- [ ] Task 9 runs fresh integrated gates and freezes only the plot-free Pass One lattice.

---

## Owner Approval Transaction: Bind this exact plan before Task 0

This transaction is not authorized by the existence of this proposed plan. It
occurs only after the owner selects Subagent-Driven or Inline execution. Before
that selection, the proposal commit must already contain this plan, its approved
written specification, and
`docs/research/2026-08-27-room-217-narrative-theory-check.md`, so a clean checkout
cannot lose an authority or craft-reference link.

After the owner selects a mode:

1. Capture the proposal commit as `implementation_base_commit`.
2. Recompute the plan's canonical-text SHA-256: strict UTF-8 without BOM, with
   CRLF or CR normalized to LF.
3. Use `apply_patch` to change only the specification frontmatter and its section
   14 authorization sentence:
   `implementation_plan_status: approved`, `implementation_authorized: true`,
   the exact selected `implementation_execution_mode`, owner/date/scope fields,
   the captured base commit, exact plan path, and matching digest.
4. Confirm specification section 14 says the written specification is approved
   and this exact plan is authorized; it must contain no surviving pre-approval
   prohibition.
5. Commit only the specification. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command {
     $env:DWM_COMMIT_AUTHORIZED = '1'
     $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
     & '.\tools\git\Invoke-ExactPathCommit.ps1' `
       -RequiredStatus ([ordered]@{ 'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' = 'M' }) `
       -ExpectedHead $head `
       -Message 'docs: authorize seven-day documentation reconciliation'
   }
   ```

   Expected: one exact-path commit pass for the specification only.
6. Do not edit the plan after approval. Any plan-byte change invalidates the
   digest and returns the transaction to owner review.

This transaction makes the repository binding legible to
`AgentWorkflowAuthorityResolver`; plan prose alone never grants authority.

---

## Task 0: Preserve the exact collaborative story baseline

**Files:**

- Modify/commit as already authored: `story/01-core-story-bible.md`
- Modify/commit as already authored: `story/02-character-relationship-handbook.md`
- Modify/commit as already authored: `story/03-seven-day-production-map.md`
- Add/commit as already authored: `story/06-seven-day-scene-beatbook.md`
- Verify only: `docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md`

**Step 1: Verify implementation authority**

Run:

```powershell
$specPath = 'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md'
$planPath = 'docs/superpowers/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md'
$researchPath = 'docs/research/2026-08-27-room-217-narrative-theory-check.md'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$specBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $specPath))
$planBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $planPath))
function Assert-NoBom([string]$path, [byte[]]$bytes) {
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
    throw "Authority artifact has a BOM: $path"
  }
}
Assert-NoBom $specPath $specBytes
Assert-NoBom $planPath $planBytes
$spec = $utf8.GetString($specBytes).Replace("`r`n", "`n").Replace("`r", "`n")
$plan = $utf8.GetString($planBytes).Replace("`r`n", "`n").Replace("`r", "`n")
if (-not $spec.StartsWith("---`n", [StringComparison]::Ordinal)) { throw 'Specification lacks YAML frontmatter.' }
$frontmatterEnd = $spec.IndexOf("`n---`n", 4, [StringComparison]::Ordinal)
if ($frontmatterEnd -lt 0) { throw 'Specification frontmatter is unclosed.' }
$frontmatter = $spec.Substring(4, $frontmatterEnd - 4)
function Get-ExactField([string]$name) {
  $pattern = '(?m)^' + [regex]::Escape($name) + ':\s*(?:"(?<quoted>[^"]+)"|(?<bare>[A-Za-z0-9_.\-/]+))\s*$'
  $matches = @([regex]::Matches($frontmatter, $pattern))
  if ($matches.Count -ne 1) { throw "Authority field must occur exactly once: $name" }
  return $(if ($matches[0].Groups['quoted'].Success) { $matches[0].Groups['quoted'].Value } else { $matches[0].Groups['bare'].Value })
}
$required = [ordered]@{
  id = 'spec.seven_day_two_pass_constellation'
  conversational_design_status = 'approved'
  written_spec_status = 'approved'
  implementation_authorized = 'true'
  implementation_plan_path = $planPath
  implementation_plan_status = 'approved'
}
foreach ($name in $required.Keys) {
  if ((Get-ExactField $name) -cne $required[$name]) { throw "Authority field differs: $name" }
}
if ((Get-ExactField 'implementation_execution_mode') -notin @('subagent_driven', 'inline')) {
  throw 'Approved execution mode is invalid.'
}
$sha = [Security.Cryptography.SHA256]::Create()
try {
  $planDigest = -join ($sha.ComputeHash($utf8.GetBytes($plan)) | ForEach-Object { $_.ToString('x2') })
} finally {
  $sha.Dispose()
}
if ((Get-ExactField 'implementation_plan_sha256') -cne $planDigest) { throw 'Approved plan digest does not match plan bytes.' }
$implementationBase = Get-ExactField 'implementation_base_commit'
if ($implementationBase -notmatch '^[0-9a-f]{40}$') { throw 'Implementation base is not a 40-character commit.' }
& git merge-base --is-ancestor $implementationBase HEAD
if ($LASTEXITCODE -ne 0) { throw 'Implementation base is not an ancestor of HEAD.' }
$authorizationCount = [int]((& git rev-list --count "${implementationBase}..HEAD").Trim())
if ($authorizationCount -ne 1) { throw 'Task 0 must begin at the sole authorization child of the proposal base.' }
$authorizationDiff = @(& git diff --name-status --no-renames "${implementationBase}..HEAD")
if ($authorizationDiff.Count -ne 1 -or $authorizationDiff[0] -cne "M`tdocs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md") {
  throw 'Authorization boundary changed paths other than the specification.'
}
foreach ($path in @($specPath, $planPath, $researchPath)) {
  & git ls-files --error-unmatch -- $path *> $null
  if ($LASTEXITCODE -ne 0) { throw "Authority dependency is not tracked in HEAD: $path" }
  & git diff --quiet HEAD -- $path
  if ($LASTEXITCODE -ne 0) { throw "Authority dependency differs from HEAD: $path" }
}
if ($spec -match 'written artifact\s+still requires owner review|do not invoke the implementation-planning stage') {
  throw 'Specification prose still contradicts approved implementation authority.'
}
```

Expected: no output. This checks the same plan path/status/digest facts consumed by the repository authority resolver, plus explicit implementation authorization, mode, base ancestry, and tracked dependencies. If it throws, stop before changing any story file.

**Step 2: Verify exact statuses**

Run:

```powershell
git status --short -- `
  'story/01-core-story-bible.md' `
  'story/02-character-relationship-handbook.md' `
  'story/03-seven-day-production-map.md' `
  'story/06-seven-day-scene-beatbook.md'
```

Expected paths and worktree states: the first three are modified tracked files; `story/06-seven-day-scene-beatbook.md` is an untracked file. No file may be partially staged; the repository index must be empty.

**Step 3: Verify canonical-LF content hashes**

Run:

```powershell
$expected = [ordered]@{
  'story/01-core-story-bible.md' = '8ec7cc50f5e77fdf1f0c9c56488d8f61d0efb448ed1d2cdfd3a80347f6c1b87b'
  'story/02-character-relationship-handbook.md' = 'b9db4e63237360e46b69e643d7152deabc781a0ce4fa00d16929b339bfb0355c'
  'story/03-seven-day-production-map.md' = '7448db36f724d7acfe50f2479884c03209648c5adc2a1cb6cb641b0af152b4ff'
  'story/06-seven-day-scene-beatbook.md' = 'e1b7ee5ca02246765dd934a2d9b83a29c5baafdf54dee3ba25974173110b0c30'
}
$sha = [Security.Cryptography.SHA256]::Create()
try {
  foreach ($path in $expected.Keys) {
    $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path))
    $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($normalized)
    $actual = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    if ($actual -cne $expected[$path]) { throw "Baseline drift: $path`nexpected $($expected[$path])`nactual   $actual" }
  }
} finally {
  $sha.Dispose()
}
```

Expected: no output. Any mismatch stops execution and requires a new provenance review.

**Step 4: Commit only the preserved baseline**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{
      'story/01-core-story-bible.md' = 'M'
      'story/02-character-relationship-handbook.md' = 'M'
      'story/03-seven-day-production-map.md' = 'M'
      'story/06-seven-day-scene-beatbook.md' = 'A'
    }) `
    -ExpectedHead $head `
    -Message 'docs(story): preserve current story development baseline'
}
```

Expected: `EXACT_PATH_COMMIT: PASS ...` and a commit containing exactly the four story paths.

**Step 5: Record the baseline commit for archive provenance**

Run:

```powershell
git rev-parse --verify 'HEAD^{commit}'
git diff-tree --no-commit-id --name-status -r HEAD
```

Expected: one 40-character commit ID and exactly the four paths above. Preserve this ID for Task 1's `Source commit` field.

**Step 6: Establish execution isolation if using Subagent-Driven execution**

After Task 0 only, use `superpowers:using-git-worktrees` to create an isolated worktree at the new baseline commit. Do not create the worktree before Task 0, because a clean checkout would omit the owner-approved baseline. Inline execution may continue in the current worktree while preserving all unrelated dirty paths.

---

## Task 1: Archive the complete named Production Map before rewriting it

**Files:**

- Create: `story/library/03-seven-day-plot-material-library.md`
- Read only: `story/03-seven-day-production-map.md`

**Step 1: Create the archive with an exact wrapper and verbatim body**

Use `apply_patch` to add the new file. Its opening must be:

```markdown
# Seven-Day Plot Material Library

> **Authority status: NONCANONICAL AUDITION HISTORY.** Nothing in the archived
> snapshot below defines active mechanics, calendar placement, narrative canon,
> production instructions, or shipped dialogue. Consult the August mechanical
> design and the approved Two-Pass Constellation specification for current
> authority.

- **Captured source:** [`../03-seven-day-production-map.md`](../03-seven-day-production-map.md)
- **Capture date:** 2026-08-28
- **Capture scope:** Complete then-current source, including the owner-approved
  collaborative additions, preserved without correction.
- **Use rule:** Material may return only through Pass Two audition and explicit
  owner approval.
- **Room 2.17 distinction:** Archived Event 13 is noncanonical as a Production Map
  card. Its separately approved causal core survives only through the
  Two-Pass specification and Scene Beatbook, with placement still unselected.

<!-- BEGIN VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->
```

Between `Capture date` and `Capture scope`, add three literal provenance lines:

```markdown
- **Source commit:** the 40-character Task 0 commit ID
- **Source blob:** the 40-character result of `git rev-parse <source-commit>:story/03-seven-day-production-map.md`
- **Source UTF-8 SHA-256:** the 64-character lowercase digest of the exact source bytes
```

Replace each descriptive value with its actual hexadecimal result; the archive accepts no explanatory value. The Task 0 hash gate proves the expected source SHA-256 is `7448db36f724d7acfe50f2479884c03209648c5adc2a1cb6cb641b0af152b4ff`. After the exact source text, close with:

```markdown
<!-- END VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->

## Later candidate archive records

Append later `MUTATE`, `REJECT`, superseded `APPROVED`, and `REOPENED` records
below this heading. Each record must preserve its former status, source window,
decision date, and reason. Nothing in this section is active merely because it is
retained.
```

The source body must be copied without correction, reformatting, heading changes, status repair, BOM insertion, line-ending conversion, or final-newline change.

**Step 2: Verify strict UTF-8 identity before the source can be rewritten**

Run:

```powershell
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$sourcePath = 'story/03-seven-day-production-map.md'
$archivePath = 'story/library/03-seven-day-plot-material-library.md'
$beginMarker = '<!-- BEGIN VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
$endMarker = '<!-- END VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
function Read-StrictUtf8([string]$path) {
  $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path))
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
    throw "UTF-8 BOM is forbidden: $path"
  }
  return [pscustomobject]@{ Bytes = $bytes; Text = $utf8.GetString($bytes) }
}
$source = Read-StrictUtf8 $sourcePath
$archive = Read-StrictUtf8 $archivePath
if (-not $source.Text.EndsWith("`n", [StringComparison]::Ordinal) -or $source.Text.Contains("`r")) {
  throw 'The hash-gated source must remain LF-only with its final newline.'
}
$prefix = $beginMarker + "`n"
$start = $archive.Text.IndexOf($prefix, [StringComparison]::Ordinal)
$finish = $archive.Text.IndexOf($endMarker, $start + $prefix.Length, [StringComparison]::Ordinal)
if ($start -lt 0 -or $finish -lt 0 -or
    $archive.Text.LastIndexOf($beginMarker, [StringComparison]::Ordinal) -ne $start -or
    $archive.Text.LastIndexOf($endMarker, [StringComparison]::Ordinal) -ne $finish) {
  throw 'Archive markers must each occur exactly once and in order.'
}
$snapshotText = $archive.Text.Substring($start + $prefix.Length, $finish - ($start + $prefix.Length))
if ($snapshotText -cne $source.Text) { throw 'Archive snapshot is not exact source text.' }
$sha = [Security.Cryptography.SHA256]::Create()
try {
  $snapshotBytes = $utf8.GetBytes($snapshotText)
  $snapshotSha = -join ($sha.ComputeHash($snapshotBytes) | ForEach-Object { $_.ToString('x2') })
} finally {
  $sha.Dispose()
}
$commitMatch = [regex]::Match($archive.Text, '(?m)^- \*\*Source commit:\*\* (?<value>[0-9a-f]{40})$')
$blobMatch = [regex]::Match($archive.Text, '(?m)^- \*\*Source blob:\*\* (?<value>[0-9a-f]{40})$')
$shaMatch = [regex]::Match($archive.Text, '(?m)^- \*\*Source UTF-8 SHA-256:\*\* (?<value>[0-9a-f]{64})$')
if (-not $commitMatch.Success -or -not $blobMatch.Success -or -not $shaMatch.Success) { throw 'Archive provenance fields are missing or malformed.' }
$sourceCommit = $commitMatch.Groups['value'].Value
$sourceBlob = $blobMatch.Groups['value'].Value
if ($sourceCommit -cne (& git rev-parse --verify 'HEAD^{commit}').Trim()) {
  throw 'Archive Source commit does not equal the Task 0 baseline commit.'
}
$resolvedBlob = (& git rev-parse --verify "${sourceCommit}:story/03-seven-day-production-map.md").Trim()
if ($resolvedBlob -cne $sourceBlob) { throw 'Archive Source blob does not resolve from Source commit.' }
& git diff --quiet HEAD -- $sourcePath
if ($LASTEXITCODE -ne 0) { throw 'Live source differs from the recorded Task 0 commit before archiving.' }
if ($snapshotSha -cne $shaMatch.Groups['value'].Value -or
    $snapshotSha -cne '7448db36f724d7acfe50f2479884c03209648c5adc2a1cb6cb641b0af152b4ff') {
  throw 'Archive snapshot SHA-256 differs from recorded or planned source identity.'
}
if ((& git cat-file -t $sourceBlob).Trim() -cne 'blob' -or [int64](& git cat-file -s $sourceBlob) -ne $snapshotBytes.LongLength) {
  throw 'Recorded Git blob type or byte length differs from the archived snapshot.'
}
```

Expected: no output. This is the only step that compares the snapshot to the live Map.

**Step 3: Define the immutable archive recheck used after the Map rewrite**

After Task 1, every later archive gate must repeat the strict UTF-8 extraction and metadata checks above without comparing to live `story/03`. It must prove: one marker pair; no BOM or CR; snapshot SHA-256 equals the recorded value and `7448...`; Source commit resolves Source blob; Git reports that object as a blob; and blob byte length equals snapshot byte length. This immutable check is what Tasks 5 and 9 re-run.

Run this exact persistent form:

```powershell
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$path = 'story/library/03-seven-day-plot-material-library.md'
$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path))
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) { throw 'Archive has a UTF-8 BOM.' }
$text = $utf8.GetString($bytes)
if ($text.Contains("`r")) { throw 'Archive is not LF-only.' }
$begin = '<!-- BEGIN VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
$end = '<!-- END VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
$prefix = $begin + "`n"
$start = $text.IndexOf($prefix, [StringComparison]::Ordinal)
$stop = $text.IndexOf($end, $start + $prefix.Length, [StringComparison]::Ordinal)
if ($start -lt 0 -or $stop -lt 0 -or
    $text.LastIndexOf($begin, [StringComparison]::Ordinal) -ne $start -or
    $text.LastIndexOf($end, [StringComparison]::Ordinal) -ne $stop) {
  throw 'Archive marker identity drift.'
}
$snapshotText = $text.Substring($start + $prefix.Length, $stop - ($start + $prefix.Length))
$snapshotBytes = $utf8.GetBytes($snapshotText)
$sha = [Security.Cryptography.SHA256]::Create()
try { $digest = -join ($sha.ComputeHash($snapshotBytes) | ForEach-Object { $_.ToString('x2') }) } finally { $sha.Dispose() }
$commit = [regex]::Match($text, '(?m)^- \*\*Source commit:\*\* (?<value>[0-9a-f]{40})$').Groups['value'].Value
$blob = [regex]::Match($text, '(?m)^- \*\*Source blob:\*\* (?<value>[0-9a-f]{40})$').Groups['value'].Value
$recordedDigest = [regex]::Match($text, '(?m)^- \*\*Source UTF-8 SHA-256:\*\* (?<value>[0-9a-f]{64})$').Groups['value'].Value
if ($commit -notmatch '^[0-9a-f]{40}$' -or $blob -notmatch '^[0-9a-f]{40}$' -or $recordedDigest -notmatch '^[0-9a-f]{64}$') { throw 'Archive provenance metadata drift.' }
& git merge-base --is-ancestor $commit HEAD
if ($LASTEXITCODE -ne 0) { throw 'Archive source commit is not an ancestor of current HEAD.' }
if ((& git rev-parse --verify "${commit}:story/03-seven-day-production-map.md").Trim() -cne $blob) { throw 'Archive source blob no longer resolves from source commit.' }
if ((& git cat-file -t $blob).Trim() -cne 'blob') { throw 'Archive source object is not a Git blob.' }
$blobSize = [int64]((& git cat-file -s $blob).Trim())
if ($blobSize -ne $snapshotBytes.LongLength) { throw 'Archive snapshot byte length differs from source blob.' }
if ($digest -cne $recordedDigest -or $digest -cne '7448db36f724d7acfe50f2479884c03209648c5adc2a1cb6cb641b0af152b4ff') { throw 'Archive snapshot digest differs from its immutable source identity.' }
```

Expected: no output in Task 1 and after every later commit.

**Step 4: Commit the archive alone**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{ 'story/library/03-seven-day-plot-material-library.md' = 'A' }) `
    -ExpectedHead $head `
    -Message 'docs(story): preserve seven-day plot material history'
}
```

Expected: exact-path commit pass for the library only.

---

## Task 2: Establish the reconciled documentation authority map

**Files:**

- Modify: `docs/design/README.md`
- Modify: `story/01-core-story-bible.md` (`Document Authority`, `Open Week Structure`, and the opening of `Seven-Day Fixed Spine` only)

**Step 1: Replace the recovered-only design index with the active navigation map**

Use `apply_patch` to make `docs/design/README.md` distinguish:

- active intended mechanics: August 7 design;
- narrative canon: Core Story Bible;
- derived performance: Character & Relationship Handbook;
- selection workflow: approved Two-Pass specification;
- fixed obligations and approved placements: Seven-Day Causal Matrix;
- plot-neutral production rendering: Production Map;
- detailed load-bearing execution: Scene Beatbook;
- noncanonical named history: Plot Material Library;
- historical amendments: July amendment file;
- recovered documents: evidence only;
- runtime code: physical implementation and possible drift, never silent narrative authority.

Link every local artifact directly. Do not describe the Map or July amendments as current mechanics.

**Step 2: Bound the Bible's authority and fixed-window statements**

Use `apply_patch` within the three named Bible regions. They must state:

- August design owns intended mechanics and Dialogic flow;
- runtime owns physically implemented behavior and may expose drift;
- the Bible remains sole narrative authority;
- Handbook is derived;
- Causal Matrix owns approved placements;
- Production Map is plot-neutral;
- Scene Beatbook expands approved load-bearing scenes;
- Plot Material Library and July amendments are provenance, not active authority.
- the August design fixes twelve solo and two conditional pair windows;
- runtime decides what is physically implemented and is checked for drift, but
  phrases such as `code-available women`, `fourteen event premises`, and exact
  availability being code-authoritative do not survive as intended law.

Preserve the fixed Day 1 presence, Day 2 return, Day 7 choice, ending-eligibility,
Alone, and all narrative spine facts. Do not reproduce the full calendar here.

**Step 3: Verify links and bounded scope**

Run:

```powershell
git diff --check -- 'docs/design/README.md' 'story/01-core-story-bible.md'
git diff --stat -- 'docs/design/README.md' 'story/01-core-story-bible.md'
git diff -- 'story/01-core-story-bible.md'
```

Expected: clean diff check; Bible changes are confined to the three named authority/window regions and preserve their narrative facts; the README is an active authority index rather than a recovered-only notice.

**Step 4: Commit the authority map**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{
      'docs/design/README.md' = 'M'
      'story/01-core-story-bible.md' = 'M'
    }) `
    -ExpectedHead $head `
    -Message 'docs(story): establish seven-day authority map'
}
```

Expected statuses: `M` for both paths.

---

## Task 3: Correct active relationship-state and character-performance law

**Files:**

- Modify: `story/01-core-story-bible.md` (`Relationship State and Tone`)
- Modify: `story/02-character-relationship-handbook.md` (`How to Use`, `State and Tone Performance Rules`, dossier template, four character dossiers, relevant reaction principles, final checklist)

**Step 1: Correct the Bible's active state law**

Use `apply_patch` to replace the active progression with:

```text
Friend → Ambiguous → Love
```

Record these exact mechanical consequences without rewriting character prose:

- Priscilla, Lavinia, and Sylvia each begin at Friend in Angela's relationship state.
- Hate is not a reachable tier; hostility, refusal, and resistance remain attitudes that can occur at any tier.
- Affection is eligibility fuel, not a movable promotion event.
- Ordinary promotion valves are fixed at Priscilla Day 4 and Day 6, Lavinia Day 5 and Day 6, and Sylvia Day 4 and Day 5.
- A valve moves one tier only when that exact challenge is attended and eligibility is met.
- Unread, missed, prevented, and Hospital-superseded ordinary valves do not move.
- Sylvia's separately authorized Hospital witness is the sole exception defined by the August design.
- State never grants consent, rewrites desire, or erases refusal.

Keep Sweet/Totally Dark definitions and unlabeled-relationship law unless an exact conflict requires a narrow wording adjustment.
Replace any claim that state or tone is code-owned with the narrower fact that
August design owns intended mechanics while runtime is inspected for drift.

**Step 2: Correct the Handbook without flattening the dossiers**

Use `apply_patch` to:

- mark the Handbook as derived from Bible canon and August mechanics;
- change the performance range to Friend through Love;
- add a separate current attitude/resistance field to the dossier template;
- replace each `At hate` variation with character-specific Hostile-attitude guidance:
  - Angela remains functionally exact and verifies claims;
  - Priscilla becomes formal, prosecutorial, and controlling through procedure;
  - Lavinia makes refusal unmistakable rather than manufacturing intimacy;
  - Sylvia limits help to her role and leaves refusal physically possible;
- replace any claim that intimacy advances from Hate with the rule that Hostile attitude is not a lower relationship tier and cannot smuggle reciprocity or consent;
- add initial Friend, Hostile-attitude, and fixed-valve checks to the final consistency checklist.

Preserve every character's motive, knowledge limit, consent boundary, control signature, language pattern, and established relationship history.

**Step 3: Verify active terminology**

Run:

```powershell
& rg -n "At hate|hate → friend|cannot occur intimately from hate|Relationship-state variation: What changes from hate" `
  'story/01-core-story-bible.md' 'story/02-character-relationship-handbook.md'
if ($LASTEXITCODE -eq 0) { throw 'Active Hate-tier language remains.' }
if ($LASTEXITCODE -ne 1) { throw "Active-state negative scan failed with rg exit $LASTEXITCODE." }
& rg -n "Friend → Ambiguous → Love|Hostile|fixed.*valve|Day 4|Day 5|Day 6" `
  'story/01-core-story-bible.md' 'story/02-character-relationship-handbook.md'
if ($LASTEXITCODE -ne 0) { throw 'Corrected state, attitude, or valve evidence is missing.' }
git diff --check -- 'story/01-core-story-bible.md' 'story/02-character-relationship-handbook.md'
```

Expected: the first search has no matches. The second shows the new progression, character-specific Hostile guidance, and exact valve days. Diff check passes.

**Step 4: Commit the state-law correction**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{
      'story/01-core-story-bible.md' = 'M'
      'story/02-character-relationship-handbook.md' = 'M'
    }) `
    -ExpectedHead $head `
    -Message 'docs(story): align relationship state and performance law'
}
```

Expected statuses: `M` for both paths.

---

## Task 4: Demote unapproved Bible premises and align ending law

**Files:**

- Modify: `story/01-core-story-bible.md` (`Event Architecture`, `Ending Architecture`, `Ending Gallery Behavior`, `Observer Languages`, `Canon Maintenance Rules`)
- Read only: `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`

**Step 1: Add the narrow narrative-scope notice**

At the start of `Event Architecture`, state that:

- the twelve solo and two pair windows are mechanically fixed;
- named Events 1–12 and 14 are noncanonical audition material preserved in the library;
- the former Event 13 Production Map card is likewise noncanonical;
- Room 2.17 is a separate approved causal core with Day 2/Day 6 placement unselected;
- the four mystery anchors, Day 2 umbrella pickup, character canon, and hidden histories remain protected;
- exact production cards arise only from an `APPROVED` Causal Matrix row.

Keep the existing named premise summaries and arc notes only as an explicitly bounded audition-history catalogue. They must not read as the active fourteen-event plot.

**Step 2: Replace the old production formula with the Two-Pass boundary**

Remove any statement that every named card already derives from a settled production formula. Point instead to Pass One obligations, Pass Two audition, matrix approval, and Beatbook expansion. Keep the Day 2 umbrella micro-scene visibly outside the fourteen-window audition catalogue and outside the pair counter.

**Step 3: Align Day 7 and ending precedence to August sections 11.1–11.10**

Use `apply_patch` so the Bible states:

- due Day 6 follow-ups and unavoidable echo fallback occur before boardless ending invitation rounds;
- Priscilla, Lavinia, and Sylvia invitations unlock in fixed rounds, then one selected solo destination or Alone resolves;
- a qualifying solo Observer postscript follows its matching Sweet ending rather than acting as a destination;
- a qualified P–L visible ending follows the solo layer, then its Observer postscript when eligible;
- a Priscilla or Lavinia solo Observer and a counted P–L ending cannot coexist in
  one run because their attendance evidence is mechanically incompatible;
- Sylvia Special is a prelude triggered only by a qualifying pre-Done faint after Sylvia's invitation has been read; it then forces Sylvia Totally Dark;
- when Dark mode is enabled, Dark-mode Alone has faint precedence;
- otherwise a qualifying faint without a previously read eligible Sylvia invitation resolves through Hospital-flavored normal Alone;
- Day 7 creates no missed-date record or Day 8 follow-up;
- remove the superseded trigger requiring selection and completion of a Sylvia destination;
- full-once behavior follows August section 11.10 exactly: first discovery is
  full; the hidden setting defaults Off; Off uses residue and On uses full on
  later qualification; the choice is frozen into the ending plan; Gallery replay
  is always full. Do not promise full History replay.

Do not change the protected imagery, Sylvia's fixed intent, unresolved immediate cause, or the meanings of existing visible ending scenes except where an old trigger/order sentence conflicts.

**Step 4: Correct maintenance language**

`Canon Maintenance Rules` must require the August design, fixed valves, ordered ending plan, explicit premise approval, and provenance-safe reopening. It must not let the Map or current runtime silently amend narrative canon.

**Step 5: Verify protected content and removed conflicts**

Run:

```powershell
$text = Get-Content -LiteralPath 'story/01-core-story-bible.md' -Raw
$protected = [ordered]@{
  roster = 'Lavinia.s name appears prematurely|premature.*roster'
  unsent_message = 'Lavinia is back'
  premature_reply = 'I know'
  prefilled_slip = 'welfare[^\r\n]*slip|slip[^\r\n]*prefill'
  location_prompt = 'location[^\r\n]*prompt|confirmation or expiry'
  umbrella = 'umbrella'
  room_core = 'Room 2\.17'
}
foreach ($name in $protected.Keys) {
  if ($text -notmatch $protected[$name]) { throw "Protected Bible evidence is missing: $name" }
}
& rg -n "select an eligible Sylvia destination|complete its visible Sweet|decisive board|hate → friend|Observer and Special identities are postscripts|Sylvia.s Special postscript|selected Sylvia ending|code-owned health condition|exact four-layer order|randomized residue|replayable through history|code-available women|fourteen event premises|Exact schedule availability remains code-owned|code-owned tone|existing code is authoritative|existing implementation remains authoritative|Existing code owns|code-authoritative" 'story/01-core-story-bible.md'
if ($LASTEXITCODE -eq 0) { throw 'Superseded ending or tier language remains active in the Bible.' }
if ($LASTEXITCODE -ne 1) { throw "Bible conflict scan failed with rg exit $LASTEXITCODE." }
$corrected = [ordered]@{
  pre_done = 'pre-Done'
  dark_precedence = 'Dark-mode Alone'
  special_then_dark = '(?s)Sylvia Special.{0,300}Sylvia (?:Totally )?Dark'
  no_day8_debt = 'no Day 8|zero Day 8'
  matrix_approval = 'APPROVED[^\r\n]*Causal Matrix|Causal Matrix[^\r\n]*APPROVED'
  audition_status = 'audition'
  observer_pair_incompatibility = 'solo Observer[^\r\n]*cannot coexist|mechanically incompatible'
  full_once_setting = 'hidden setting[^\r\n]*Off'
  gallery_full = 'Gallery[^\r\n]*full'
}
foreach ($name in $corrected.Keys) {
  if ($text -notmatch $corrected[$name]) { throw "Corrected Bible evidence is missing: $name" }
}
git diff --check -- 'story/01-core-story-bible.md'
```

Expected: protected anchors, umbrella, and Room 2.17 notice remain. The second search has no matches. Any former Event 13 wording is confined to the visibly noncanonical audition-history block. The third search shows the corrected precedence and authority language. Diff check passes.

**Step 6: Commit the Bible reconciliation**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{ 'story/01-core-story-bible.md' = 'M' }) `
    -ExpectedHead $head `
    -Message 'docs(story): reconcile premise and ending authority'
}
```

Expected status: `M` for the Bible only.

---

## Task 5: Rewrite the Production Map as a genuinely plot-neutral template

**Files:**

- Modify: `story/03-seven-day-production-map.md`
- Read only: `story/library/03-seven-day-plot-material-library.md`
- Future link target: `story/07-seven-day-causal-matrix.md`, created in Task 6; link its intended path without inventing a row

**Step 1: Replace the complete Map body**

Use `apply_patch` to rewrite `story/03` with exactly these top-level sections:

1. `Derived Authority and Entry Condition`
2. `Day-Slot Record Schema`
3. `Approved Production-Card Schema`
4. `Production Rendering Contract`
5. `Change Lifecycle`
6. `Plot-Neutral Review Gate`

The Map must say:

- August design supplies mechanics; Bible supplies narrative canon; Handbook supplies performance;
- a card can be instantiated only from an explicitly `APPROVED` `story/07` row;
- old, mutated, rejected, and reopened premises live in the library;
- an approved causal core whose placement remains unselected cannot instantiate a card until an exact matrix row receives explicit approval;
- the slot schema records IDs, mechanical obligations, approved matrix link, state/tone rendering inputs, visibility, absence behavior, evidence, echo/debt, Beatbook link, and production status without filling any story premise;
- the card schema consumes an approved premise but never alters it;
- production rendering separates fixed causal spine, compact state insert, tone action, contextual echo, and lawful visibility;
- lifecycle changes return to the matrix and library rather than being silently corrected in production prose.

Enclose each schema table in literal markers:

```markdown
<!-- BEGIN DAY SLOT SCHEMA -->
<!-- END DAY SLOT SCHEMA -->
<!-- BEGIN PRODUCTION CARD SCHEMA -->
<!-- END PRODUCTION CARD SCHEMA -->
```

The Day-Slot table's first-column field labels are exact and ordered:
`Upstream slot identity`, `Approved matrix record`, `Mechanical reference`,
`Relationship function`, `Promotion obligation`, `Incoming causality`,
`Delivery obligation`, `Guaranteed fallback`, `Outgoing causality`,
`Absence/interruption behavior`, `Abnormality allowance`, `Ending-day debt`, and
`Production status`.

The Approved Production-Card table's first-column field labels are exact and
ordered: `Approval record`, `Matrix link`, `Ordinary activity and setting`,
`Participants and visibility`, `Causal/action spine`, `Smallest irreversible
change`, `Relationship pressure`, `Choice/refusal/consent`, `State insert input`,
`Tone action input`, `Contextual echo input`, `Evidence and fallback`,
`Unresolved cause`, `Outgoing consequence`, `Absence/interruption forms`,
`Beatbook disposition`, and `Final-authoring status`. Every instruction cell
states what an approved row supplies; no cell contains an example premise.

Do not include a real day assignment, character-specific card, named event, fixed anchor, ending premise, Room 2.17 execution detail, candidate, dialogue, or duplicated calendar mechanic.

**Step 2: Run the plot-neutral negative gate**

Run:

```powershell
& rg -n "Angela|Priscilla|Lavinia|Sylvia|Room 2\.17|Event [0-9]+|Day [1-7]\b|Open Week roster|welfare slip|Lavinia is back|I know|CAPTURE|COMPARE|Minesweeper|affection|Hate|Friend\s*→|Ambiguous\s*→|fixed third|fixed fourth|pair counter|Hospital|Group|Missed|Private-visible|Private-offscreen|Prevented|Perfect|Solved|Exploded|ending invitation|faint" `
  'story/03-seven-day-production-map.md'
if ($LASTEXITCODE -eq 0) { throw 'The Production Map contains plot or duplicated mechanical material.' }
if ($LASTEXITCODE -ne 1) { throw "Production Map negative scan failed with rg exit $LASTEXITCODE." }
```

Expected: no matches.

**Step 3: Verify required schema and archive integrity**

Run:

```powershell
$sections = @(Select-String -LiteralPath 'story/03-seven-day-production-map.md' -Pattern '^## (Derived Authority and Entry Condition|Day-Slot Record Schema|Approved Production-Card Schema|Production Rendering Contract|Change Lifecycle|Plot-Neutral Review Gate)$' -CaseSensitive)
if ($sections.Count -ne 6) { throw "Expected six exact Production Map sections; found $($sections.Count)." }
$text = (Get-Content -LiteralPath 'story/03-seven-day-production-map.md' -Raw).Replace("`r`n", "`n").Replace("`r", "`n")
function Assert-Schema([string]$begin, [string]$end, [string[]]$expected) {
  $start = $text.IndexOf($begin, [StringComparison]::Ordinal)
  $stop = $text.IndexOf($end, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $stop -le $start -or $text.LastIndexOf($begin, [StringComparison]::Ordinal) -ne $start -or $text.LastIndexOf($end, [StringComparison]::Ordinal) -ne $stop) {
    throw "Schema markers must each occur exactly once: $begin"
  }
  $block = $text.Substring($start + $begin.Length, $stop - ($start + $begin.Length))
  $labels = @([regex]::Matches($block, '(?m)^\| `(?<label>[^`]+)` \|') | ForEach-Object { $_.Groups['label'].Value })
  if ([string]::Join("`n", $labels) -cne [string]::Join("`n", $expected)) { throw "Schema fields or order differ: $begin" }
}
Assert-Schema '<!-- BEGIN DAY SLOT SCHEMA -->' '<!-- END DAY SLOT SCHEMA -->' @(
  'Upstream slot identity','Approved matrix record','Mechanical reference','Relationship function','Promotion obligation','Incoming causality','Delivery obligation','Guaranteed fallback','Outgoing causality','Absence/interruption behavior','Abnormality allowance','Ending-day debt','Production status'
)
Assert-Schema '<!-- BEGIN PRODUCTION CARD SCHEMA -->' '<!-- END PRODUCTION CARD SCHEMA -->' @(
  'Approval record','Matrix link','Ordinary activity and setting','Participants and visibility','Causal/action spine','Smallest irreversible change','Relationship pressure','Choice/refusal/consent','State insert input','Tone action input','Contextual echo input','Evidence and fallback','Unresolved cause','Outgoing consequence','Absence/interruption forms','Beatbook disposition','Final-authoring status'
)
git diff --check -- 'story/03-seven-day-production-map.md'
```

Expected: exactly six section matches and a clean diff check. Re-run Task 1 Step 3's immutable archive recheck; never compare the archive with the now-rewritten live Map.

**Step 4: Commit the neutral Map**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{ 'story/03-seven-day-production-map.md' = 'M' }) `
    -ExpectedHead $head `
    -Message 'docs(story): make production map plot-neutral'
}
```

Expected status: `M` for the Map only.

---

## Task 6: Create the fixed Seven-Day Causal Matrix

**Files:**

- Create: `story/07-seven-day-causal-matrix.md`
- Read only: `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`
- Read only: `docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md`

**Step 1: Create the authority and lifecycle header**

Use `apply_patch` to create the matrix with these sections in order:

1. `Authority and Status`
2. `Selection Lifecycle`
3. `Fixed Seven-Day Obligation Lattice`
4. `Day-Causality Ledger`
5. `Encounter-Window Registry`
6. `Ordinary-Message and Echo Ledger`
7. `Priscilla–Lavinia Pair-Mode Disposition`
8. `Day 2 Umbrella Continuity`
9. `Approved Causal Cores Awaiting Placement`
10. `Approved Placed Premises`
11. `Approved Row Schema`
12. `Pass One Freeze Evidence`

Place `PASS ONE OPEN` on its own line exactly once until Task 9 proves every
freeze condition. State that all fourteen encounter-window records remain
`UNSELECTED` and that no approved placed premise exists.

**Step 2: Transcribe the fixed obligation lattice without adding plot**

Copy the approved seven-day lattice from specification section 6, preserving:

- Days 1–6 ordinary-contact rotation: Lavinia, Sylvia, Priscilla, Lavinia, Priscilla, Sylvia;
- twelve solo windows in fixed round order;
- conditional pair activation at Day 2 R3 and Day 6 R3 only;
- promotion valves: Priscilla D4/D6, Lavinia D5/D6, Sylvia D4/D5;
- four protected anchors on Days 1, 2, 4, and 6;
- exact `NONE — NEGATIVE SPACE` exports on both Day 3 and Day 5 at this initial
  checkpoint. A later approved premise may reopen one of these day records and
  replace the marker only with an explicitly approved necessary residue;
- Day 7's ordered receipt/payoff obligations and zero Day 8 debt.

The day-causality ledger must name incoming residue, protected delivery duty, guaranteed fallback class, outgoing residue, absence behavior, and Day 7 debt for every day. It may name protected facts, but may not select an encounter premise to carry them.

Within `Pass One Freeze Evidence`, add a `Protected-Anchor Carrier Audit` table
with one row each for Day 1 roster, Day 2 premature reply, Day 4 prefilled slip,
and Day 6 location prompt. Its columns are: upstream authority citation, primary
carrier class, zero-date carrier, alternate-solo-selection carrier, applicable
pair-mode carrier, Hospital/supersession carrier, Angela-absence or unseen
carrier, lawful recipient/knowledge route, exported residue, and unresolved
fact/inference boundary. Every cell must be filled without selecting a date
premise. If an axis is mechanically impossible, write the cited reason rather
than `N/A`.

Add a `Causal-Agency Invariants` table covering all seven days. It records which
upstream rule, if any, authorizes offscreen progress; what cannot become Angela's
knowledge; why no single anomaly proves or solves the global cause; the relevant
consent/medical/institutional/geographic/scheduling/physical fact-versus-inference
boundary; and how reaction-test or sparse-perception status remains explicit.

**Step 3: Add the fourteen-window marked registry**

Enclose the registry table in these literal markers:

```markdown
<!-- BEGIN ENCOUNTER WINDOW REGISTRY -->
<!-- END ENCOUNTER WINDOW REGISTRY -->
```

The table columns are exact and ordered: stable ID, numeric day, round, type/participants, solo ordinal or `N/A`, relationship function without premise, promotion role, incoming day-causality reference, delivery/fallback duty, outgoing-causality reference, absence or pair rule, abnormality allowance, Day 7 debt, and status. Every non-`N/A` field is populated, and every status is `UNSELECTED`.

Promotion cells are exact:

- `solo.priscilla.day_4`: `Friend→Ambiguous; attended third plus eligibility`;
- `solo.priscilla.day_6`: `Ambiguous→Love; attended fourth plus eligibility`;
- `solo.lavinia.day_5`: `Friend→Ambiguous; attended third plus eligibility`;
- `solo.lavinia.day_6`: `Ambiguous→Love; attended fourth plus eligibility`;
- `solo.sylvia.day_4`: `Friend→Ambiguous; attended third plus eligibility`;
- `solo.sylvia.day_5`: `Ambiguous→Love; attended fourth plus eligibility`;
- every other row: `None`.

**Step 4: Add the six-message marked ledger**

Enclose the ledger table in:

```markdown
<!-- BEGIN ORDINARY MESSAGE REGISTRY -->
<!-- END ORDINARY MESSAGE REGISTRY -->
```

For each stable contact ID, record its day, sender, allowed reply family without writing final surface text, contextual echo opportunities, lawful visibility, and unavoidable Day 7 fallback. Day 7 has no ordinary message.

**Step 5: Record pair-mode law exactly**

The pair disposition table must contain:

| Mode | Meeting counts | Visible scene | Pair board | Witnessed-combination credit |
|---|---:|---:|---:|---:|
| Group | Yes | Yes | Yes | Yes, subject to board-result law |
| Missed | Yes | Yes | Yes | Yes, subject to board-result law |
| Private-visible | Yes | Yes | Yes | Yes, subject to board-result law |
| Private-offscreen | Yes | No | No | No |
| Prevented | No | No | No | No |

State that R3 activation is attempted once only while both same-day solo offers remain available and unread; opened-but-unanswered is a Private-visible presentation subvariant, not a sixth mode; an accepted Group offer superseded by Hospital resolves Missed; offscreen grants no board or witness credit; Prevented cannot imply a meeting.

**Step 6: Protect the umbrella and Room 2.17 boundaries**

The umbrella section must record its fixed trigger, independent continuity, later residue when unseen, and that it grants no pair count, relationship level, gate, board, or seen-combination credit.

The only named item in `Approved Causal Cores Awaiting Placement` is:

```text
Room 2.17 — APPROVED CAUSAL CORE — PLACEMENT UNSELECTED
```

Record Day 2 and Day 6 pair windows as the eligible set, not as a placement. Link the specification and Beatbook. Do not repeat chair/folder/`will` execution, assign a day, create an approval row, allocate an anchor, create Day 7 debt, or invent a runtime ID.

Enclose `Approved Placed Premises` in these literal markers, with exactly `None.`
between them:

```markdown
<!-- BEGIN APPROVED PLACED PREMISES -->
None.
<!-- END APPROVED PLACED PREMISES -->
```

**Step 7: Verify exact registry sets**

Run:

```powershell
$text = (Get-Content -LiteralPath 'story/07-seven-day-causal-matrix.md' -Raw).Replace("`r`n", "`n").Replace("`r", "`n")
function Get-MarkedBlock([string]$begin, [string]$end) {
  $start = $text.IndexOf($begin, [StringComparison]::Ordinal)
  $stop = $text.IndexOf($end, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $stop -le $start -or
      $text.LastIndexOf($begin, [StringComparison]::Ordinal) -ne $start -or
      $text.LastIndexOf($end, [StringComparison]::Ordinal) -ne $stop) {
    throw "Registry markers must each occur exactly once and in order: $begin"
  }
  return $text.Substring($start + $begin.Length, $stop - ($start + $begin.Length))
}
$none = 'None'
$third = 'Friend→Ambiguous; attended third plus eligibility'
$fourth = 'Ambiguous→Love; attended fourth plus eligibility'
$expectedWindows = [ordered]@{
  'solo.priscilla.day_1' = @('1','R1','1',$none)
  'solo.sylvia.day_1' = @('1','R2','1',$none)
  'solo.priscilla.day_2' = @('2','R1','2',$none)
  'solo.lavinia.day_2' = @('2','R2','1',$none)
  'pair.priscilla_lavinia.day_2' = @('2','R3','N/A',$none)
  'solo.lavinia.day_3' = @('3','R1','2',$none)
  'solo.sylvia.day_3' = @('3','R2','2',$none)
  'solo.priscilla.day_4' = @('4','R1','3',$third)
  'solo.sylvia.day_4' = @('4','R2','3',$third)
  'solo.lavinia.day_5' = @('5','R1','3',$third)
  'solo.sylvia.day_5' = @('5','R2','4',$fourth)
  'solo.priscilla.day_6' = @('6','R1','4',$fourth)
  'solo.lavinia.day_6' = @('6','R2','4',$fourth)
  'pair.priscilla_lavinia.day_6' = @('6','R3','N/A',$none)
}
$windowBlock = Get-MarkedBlock '<!-- BEGIN ENCOUNTER WINDOW REGISTRY -->' '<!-- END ENCOUNTER WINDOW REGISTRY -->'
if ($windowBlock -match 'Room 2\.17') { throw 'Room 2.17 leaked into an encounter-window row.' }
$windowRows = @($windowBlock -split "`n" | Where-Object { $_ -match '^\| `' })
if ($windowRows.Count -ne 14) { throw "Expected 14 physical encounter rows; found $($windowRows.Count)." }
$seenWindows = @{}
foreach ($line in $windowRows) {
  $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
  if ($cells.Count -ne 14) { throw "Encounter row must have 14 cells: $line" }
  if ($cells[0] -notmatch '^`(?<id>(?:solo\.(?:priscilla|lavinia|sylvia)\.day_[1-6]|pair\.priscilla_lavinia\.day_[26]))`$') { throw "Malformed encounter ID cell: $($cells[0])" }
  $id = $Matches['id']
  if (-not $expectedWindows.Contains($id) -or $seenWindows.ContainsKey($id)) { throw "Unexpected or duplicate encounter row: $id" }
  $seenWindows[$id] = $true
  $shape = $expectedWindows[$id]
  if ($cells[1] -cne $shape[0] -or $cells[2] -cne $shape[1] -or $cells[4] -cne $shape[2] -or $cells[6] -cne $shape[3]) { throw "Day, round, ordinal, or promotion drift: $id" }
  if ($cells[13] -cne 'UNSELECTED') { throw "Encounter status is not UNSELECTED: $id" }
  foreach ($index in @(3,5,7,8,9,10,11,12)) {
    if ([string]::IsNullOrWhiteSpace($cells[$index])) { throw "Encounter row has an empty required cell: $id index=$index" }
  }
}
if ($seenWindows.Count -ne $expectedWindows.Count) { throw 'Encounter registry is incomplete.' }
$expectedMessages = [ordered]@{
  'contact.ordinary.lavinia.day1' = @('1','Lavinia')
  'contact.ordinary.sylvia.day2' = @('2','Sylvia')
  'contact.ordinary.priscilla.day3' = @('3','Priscilla')
  'contact.ordinary.lavinia.day4' = @('4','Lavinia')
  'contact.ordinary.priscilla.day5' = @('5','Priscilla')
  'contact.ordinary.sylvia.day6' = @('6','Sylvia')
}
$messageBlock = Get-MarkedBlock '<!-- BEGIN ORDINARY MESSAGE REGISTRY -->' '<!-- END ORDINARY MESSAGE REGISTRY -->'
$messageRows = @($messageBlock -split "`n" | Where-Object { $_ -match '^\| `' })
if ($messageRows.Count -ne 6) { throw "Expected 6 physical message rows; found $($messageRows.Count)." }
$seenMessages = @{}
foreach ($line in $messageRows) {
  $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
  if ($cells.Count -ne 7) { throw "Message row must have 7 cells: $line" }
  if ($cells[0] -notmatch '^`(?<id>contact\.ordinary\.(?:priscilla|lavinia|sylvia)\.day[1-6])`$') { throw "Malformed message ID cell: $($cells[0])" }
  $id = $Matches['id']
  if (-not $expectedMessages.Contains($id) -or $seenMessages.ContainsKey($id)) { throw "Unexpected or duplicate message row: $id" }
  $seenMessages[$id] = $true
  if ($cells[1] -cne $expectedMessages[$id][0] -or $cells[2] -cne $expectedMessages[$id][1]) { throw "Message day or sender drift: $id" }
  foreach ($index in 3..6) { if ([string]::IsNullOrWhiteSpace($cells[$index])) { throw "Message row has an empty required cell: $id index=$index" } }
}
if ($seenMessages.Count -ne $expectedMessages.Count) { throw 'Message registry is incomplete.' }
```

Expected: no output.

**Step 8: Verify status and named-premise boundary**

Run:

```powershell
$text = (Get-Content -LiteralPath 'story/07-seven-day-causal-matrix.md' -Raw).Replace("`r`n", "`n").Replace("`r", "`n")
if ([regex]::Matches($text, '(?m)^PASS ONE OPEN$').Count -ne 1) { throw 'Matrix must contain exactly one open authoring status before freeze.' }
if ($text -match '(?m)^PASS ONE FROZEN') { throw 'Matrix was frozen before integrated verification.' }
if ([regex]::Matches($text, 'NONE — NEGATIVE SPACE').Count -ne 2 -or
    $text -notmatch '(?m)^\| 3 \|[^\r\n]*NONE — NEGATIVE SPACE[^\r\n]*\|$' -or
    $text -notmatch '(?m)^\| 5 \|[^\r\n]*NONE — NEGATIVE SPACE[^\r\n]*\|$') {
  throw 'Day 3 and Day 5 must be the only exact negative-space exports.'
}
$placedBegin = '<!-- BEGIN APPROVED PLACED PREMISES -->'
$placedEnd = '<!-- END APPROVED PLACED PREMISES -->'
$placedStart = $text.IndexOf($placedBegin, [StringComparison]::Ordinal)
$placedStop = $text.IndexOf($placedEnd, [StringComparison]::Ordinal)
if ($placedStart -lt 0 -or $placedStop -le $placedStart -or
    $text.LastIndexOf($placedBegin, [StringComparison]::Ordinal) -ne $placedStart -or
    $text.LastIndexOf($placedEnd, [StringComparison]::Ordinal) -ne $placedStop) {
  throw 'Approved-placement markers must each occur exactly once.'
}
$placedBody = $text.Substring($placedStart + $placedBegin.Length, $placedStop - ($placedStart + $placedBegin.Length)).Trim()
if ($placedBody -cne 'None.') { throw 'Approved Placed Premises is not exactly empty.' }
if ([regex]::Matches($text, 'Room 2\.17 — APPROVED CAUSAL CORE — PLACEMENT UNSELECTED').Count -ne 1) { throw 'Room 2.17 must have exactly one approved-unplaced status.' }
& rg -n "Programme Table|Borrowed Book|Public Question|No Task Left|Returned Seat|Borrowed Gravity|After the Music|Before It Hurts|Exactly on Time|Quiet Table|Caretaker|Contingency|After the Run-Through|Three Versions of the Sky|Project Folder|Before the Introduction|Someone Else.s Kitchen|Revised Form|Four Months Away" 'story/07-seven-day-causal-matrix.md'
if ($LASTEXITCODE -eq 0) { throw 'A named audition premise leaked into the causal matrix.' }
if ($LASTEXITCODE -ne 1) { throw "Matrix premise-leak scan failed with rg exit $LASTEXITCODE." }
git diff --check -- 'story/07-seven-day-causal-matrix.md'
```

Expected: every exact status/cardinality assertion passes, the named-material search has no matches, and diff check passes. Then review every remaining non-mechanical noun in the matrix: it must be a protected anchor, umbrella continuity, or the bounded Room 2.17 exception—not a title-stripped candidate premise.

**Step 9: Commit the open matrix**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{ 'story/07-seven-day-causal-matrix.md' = 'A' }) `
    -ExpectedHead $head `
    -Message 'docs(story): create seven-day causal constellation'
}
```

Expected status: `A` for `story/07-seven-day-causal-matrix.md` only.

---

## Task 7: Rebase the Scene Beatbook on approved authority

**Files:**

- Modify: `story/06-seven-day-scene-beatbook.md`
- Read only: `story/07-seven-day-causal-matrix.md`
- Read only: `story/library/03-seven-day-plot-material-library.md`

**Step 1: Repair the Beatbook authority ladder and entry interface**

Use `apply_patch` so `Authority and Use` says:

- August design owns mechanics;
- Bible owns canon;
- Handbook owns derived performance;
- an `APPROVED` matrix row normally owns placement;
- Beatbook owns detailed execution only;
- July amendments and the library are historical/noncanonical;
- Production Map owns no plot;
- runtime may reveal drift but cannot amend the scene.

Update `Entry Shape` to require approval record, status, matrix link, causal obligations, mode coverage, evidence, absence behavior, and reaction-test labeling.

**Step 2: Rename and bound Room 2.17**

Replace the active `Event 13` heading with a non-numbered Room 2.17 heading. Add exact status:

```text
APPROVED CAUSAL CORE — PLACEMENT UNSELECTED
```

State:

- eligible windows are the Day 2 and Day 6 P–L pair windows;
- neither window is selected and no matrix approval row exists;
- the former Event 13 card survives only in the library as audition history;
- no exact weekday, anchor assignment, later debt, or runtime identifier may be inferred.

Keep the causal spine, character reaction tests, tone hinge, Love-state return boundary, rejected readings, ordinary-room rule, and theory note link.

**Step 3: Correct visibility and adaptation boundaries**

Record that:

- the detailed chair/folder/`will` execution is approved only for neutral Private-visible;
- Group and Missed may test the same ordinary work and third-result spine, but their Angela/guilt/Hospital adaptations remain unapproved;
- Private-offscreen inherits only lawful result and counter, with no displayed scene or board;
- Prevented contains no meeting;
- Sylvia's occupancy mark is optional, offscreen, causally inert unless a later approved contradiction needs it, and gets no standalone scene.
- existing `code-owned` availability, window, guilt, Hospital, or scene-boundary
  wording is replaced with August-owned intended law plus a separate runtime
  drift check.

Keep the literal Friday reference clearly provisional pending August-authorized
placement/calendar validation and explicit premise approval; runtime is checked
only for implementation drift.

**Step 4: Verify no fabricated placement or Map authority**

Run:

```powershell
& rg -n "Map-authorized|defined in the Map|governed by the Map|Map anchor|Room 2\.17 is scheduled|scheduled production identity|code-owned" 'story/06-seven-day-scene-beatbook.md'
if ($LASTEXITCODE -eq 0) { throw 'The Beatbook still claims Map authority or fabricated Room 2.17 placement.' }
if ($LASTEXITCODE -ne 1) { throw "Beatbook authority scan failed with rg exit $LASTEXITCODE." }
$text = Get-Content -LiteralPath 'story/06-seven-day-scene-beatbook.md' -Raw
$required = [ordered]@{
  status = 'APPROVED CAUSAL CORE — PLACEMENT UNSELECTED'
  day2 = 'Day 2'
  day6 = 'Day 6'
  group = 'Group'
  missed = 'Missed'
  private_visible = 'Private-visible'
  private_offscreen = 'Private-offscreen'
  prevented = 'Prevented'
  reaction_test = 'REACTION TEST'
  provisional = 'provisional'
  runtime_drift = 'runtime[^\r\n]*drift'
}
foreach ($name in $required.Keys) {
  if ($text -notmatch $required[$name]) { throw "Required Beatbook evidence is missing: $name" }
}
& rg -n "Event 13" 'story/06-seven-day-scene-beatbook.md'
if ($LASTEXITCODE -notin @(0, 1)) { throw "Beatbook historical-ID scan failed with rg exit $LASTEXITCODE." }
git diff --check -- 'story/06-seven-day-scene-beatbook.md'
```

Expected: the first search has no active-authority or scheduled-placement match. The positive scan proves the bounded execution modes and status. If the final `Event 13` scan prints a match, human review confirms it occurs only in an explicit historical-library sentence. Diff check passes.

**Step 5: Commit the Beatbook authority repair**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{ 'story/06-seven-day-scene-beatbook.md' = 'M' }) `
    -ExpectedHead $head `
    -Message 'docs(story): align scene beatbook authority'
}
```

Expected status: `M` for the Beatbook only.

---

## Task 8: Mark the July amendment document as historical evidence

**Files:**

- Modify: `story/05-canon-amendments-2026-07-19.md`
- Read only: `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`

**Step 1: Add a global historical status without erasing the old record**

Use `apply_patch` to add an opening status of:

```text
HISTORICAL AMENDMENT EVIDENCE — NOT CURRENT MECHANICAL AUTHORITY
```

Preserve the original July `approved canon` wording as a quoted or clearly labeled historical status. State that August 7 supersedes conflicting mechanics and that the document remains useful for decision provenance.

**Step 2: Add narrow inline supersession notices**

Add notices without deleting or rewriting the July body:

- sections 1–3: current Observer, board, and gate law is August sections 10.4 and 11.2–11.7;
- section 4: all three start Friend and use only the fixed third/fourth valves in August sections 8.2 and 7.2;
- section 5: no Day 7 decisive board; stored dark `0–1` selects Sweet and `2–4`
  selects Totally Dark; Day 7 never asks for another board;
- section 7: pair model is partly historical; August section 7.5 is normative, and opened-but-unanswered is Private-visible rather than a sixth outcome;
- section 8: Sylvia's current pre-Done trigger and ordered consequence follow August sections 11.5 and 11.8; Event 9 is audition history;
- section 9: Dark-mode scope and faint precedence follow August section 11.8;
- section 12: Phase 2R wording is a historical tracking snapshot;
- section 13: opening a solo invitation is acceptance under current law; the old reply-required model is superseded.

Use the exact lead `> **Current status: SUPERSEDED MECHANICS.**` immediately
after the headings of sections 1, 2, 3, 4, 5, 8, 9, 12, and 13. Use
`> **Current status: PARTIALLY SUPERSEDED MECHANICS.**` after section 7.
Sections 6, 10, and 11 need only the global banner unless a sentence directly
asserts current conflicting authority.

**Step 3: Prove the change is addition-only**

Run:

```powershell
$numstat = git diff --numstat -- 'story/05-canon-amendments-2026-07-19.md'
if (-not $numstat) { throw 'No July amendment diff exists.' }
$parts = $numstat -split "`t"
if ($parts[1] -ne '0') { throw "Historical amendment reconciliation deleted $($parts[1]) lines; restore them and use notices only." }
$text = (Get-Content -LiteralPath 'story/05-canon-amendments-2026-07-19.md' -Raw).Replace("`r`n", "`n").Replace("`r", "`n")
if ([regex]::Matches($text, 'HISTORICAL AMENDMENT EVIDENCE').Count -lt 1) { throw 'Global historical status is missing.' }
function Get-JulySection([int]$number) {
  $match = [regex]::Match($text, "(?ms)^## $number\..*?(?=^## \d+\.|\z)")
  if (-not $match.Success) { throw "July section is missing: $number" }
  return $match.Value
}
foreach ($number in @(1,2,3,4,5,8,9,12,13)) {
  $section = Get-JulySection $number
  if ($section -notmatch '(?m)^> \*\*Current status: SUPERSEDED MECHANICS\.\*\*$' -or $section -notmatch 'August') {
    throw "Exact supersession notice or August reference is missing from July section $number."
  }
}
$section7 = Get-JulySection 7
if ($section7 -notmatch '(?m)^> \*\*Current status: PARTIALLY SUPERSEDED MECHANICS\.\*\*$' -or $section7 -notmatch '7\.5') {
  throw 'Exact partial-supersession notice or August section 7.5 reference is missing from July section 7.'
}
$requiredReferences = @('10.4','11.2','11.7','8.2','11.5','11.8')
foreach ($reference in $requiredReferences) {
  if ($text -notmatch [regex]::Escape($reference)) { throw "Required August section reference is missing: $reference" }
}
git diff --check -- 'story/05-canon-amendments-2026-07-19.md'
```

Expected: zero deleted lines, bounded supersession notices at the required sections, and a clean diff check.

**Step 4: Commit the historical notices**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{ 'story/05-canon-amendments-2026-07-19.md' = 'M' }) `
    -ExpectedHead $head `
    -Message 'docs(story): mark July mechanics as historical'
}
```

Expected status: `M` for the July amendments only.

---

## Task 9: Run the integrated reconciliation gates and freeze Pass One

**Files:**

- Modify after all gates pass: `story/07-seven-day-causal-matrix.md`
- Verify: `docs/design/README.md`
- Verify: `story/01-core-story-bible.md`
- Verify: `story/02-character-relationship-handbook.md`
- Verify: `story/03-seven-day-production-map.md`
- Verify: `story/05-canon-amendments-2026-07-19.md`
- Verify: `story/06-seven-day-scene-beatbook.md`
- Verify: `story/07-seven-day-causal-matrix.md`
- Verify: `story/library/03-seven-day-plot-material-library.md`
- Verify: `docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md`

**Step 1: Re-run all task-local gates**

Re-run:

- Task 1 Step 3 immutable archive recheck;
- Task 3 state terminology scans;
- Task 4 protected-anchor and ending-conflict scans;
- Task 5 plot-neutral negative scan;
- Task 6 exact window/message registry script and named-premise scan;
- Task 7 unplaced Room 2.17 checks;
- Task 8 per-section historical-content assertions.

For the committed Task 8 addition-only proof, run:

```powershell
$path = 'story/05-canon-amendments-2026-07-19.md'
$historicalCommit = (& git log -1 --format='%H' -- $path).Trim()
if ($historicalCommit -notmatch '^[0-9a-f]{40}$') { throw 'Cannot resolve the historical-notice commit.' }
$status = @(& git diff-tree --no-commit-id --name-status -r $historicalCommit -- $path)
if ($status.Count -ne 1 -or $status[0] -cne "M`t$path") { throw 'Historical-notice commit did not modify exactly the expected path record.' }
$numstat = @(& git show --numstat --format= $historicalCommit -- $path)
if ($numstat.Count -ne 1) { throw 'Historical-notice commit has no unique numstat record.' }
$parts = $numstat[0] -split "`t"
if ($parts.Count -ne 3 -or $parts[1] -ne '0') { throw 'Historical-notice commit was not addition-only.' }
```

Expected: every gate passes from the final tree, not from cached output.

**Step 2: Validate every touched local Markdown link**

Run:

```powershell
$files = @(
  'docs/design/README.md',
  'story/01-core-story-bible.md',
  'story/02-character-relationship-handbook.md',
  'story/03-seven-day-production-map.md',
  'story/05-canon-amendments-2026-07-19.md',
  'story/06-seven-day-scene-beatbook.md',
  'story/07-seven-day-causal-matrix.md',
  'story/library/03-seven-day-plot-material-library.md',
  'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md'
)
$repositoryRoot = (Resolve-Path -LiteralPath '.').Path.TrimEnd('\', '/')
$failures = [Collections.Generic.List[string]]::new()
foreach ($file in $files) {
  & git ls-files --error-unmatch -- $file *> $null
  if ($LASTEXITCODE -ne 0) { $failures.Add("untracked document: $file"); continue }
  $raw = Get-Content -LiteralPath $file -Raw
  $linkSurface = $raw
  if ($file -eq 'story/library/03-seven-day-plot-material-library.md') {
    $begin = '<!-- BEGIN VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
    $end = '<!-- END VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
    $beginIndex = $raw.IndexOf($begin, [StringComparison]::Ordinal)
    $endIndex = $raw.IndexOf($end, [StringComparison]::Ordinal)
    if ($beginIndex -lt 0 -or $endIndex -le $beginIndex) { throw 'Archive markers are unavailable during link validation.' }
    $linkSurface = $raw.Substring(0, $beginIndex + $begin.Length) + $raw.Substring($endIndex)
  }
  foreach ($match in [regex]::Matches($linkSurface, '\[[^\]]+\]\((?<target>[^)]+)\)')) {
    $target = $match.Groups['target'].Value.Trim()
    if ($target.StartsWith('<') -and $target.EndsWith('>')) { $target = $target.Substring(1, $target.Length - 2) }
    if ($target -match '^(?:https?://|mailto:|res://|#)') { continue }
    $target = ($target -split '#', 2)[0]
    if ([string]::IsNullOrWhiteSpace($target)) { continue }
    $decoded = [Uri]::UnescapeDataString($target)
    $base = Split-Path -Parent (Resolve-Path -LiteralPath $file)
    $resolved = [IO.Path]::GetFullPath((Join-Path $base $decoded))
    $insideRepository = $resolved.Equals($repositoryRoot, [StringComparison]::OrdinalIgnoreCase) -or
      $resolved.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    if (-not $insideRepository -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
      $failures.Add("$file -> $target")
      continue
    }
    $relative = $resolved.Substring($repositoryRoot.Length).TrimStart('\', '/').Replace('\', '/')
    & git ls-files --error-unmatch -- $relative *> $null
    if ($LASTEXITCODE -ne 0) { $failures.Add("$file -> untracked target $target") }
  }
}
if ($failures.Count -gt 0) { throw "Broken local Markdown links:`n$($failures -join "`n")" }
```

Expected: no output.

**Step 3: Check for unfinished drafting tokens**

Run:

```powershell
$unfinishedPattern = @('TO' + 'DO', 'T' + 'BD', 'FIX' + 'ME', 'X' + 'XX', 'INSERT' + ' HERE', 'fill' + ' this', 'to be' + ' decided') -join '|'
& rg -n $unfinishedPattern `
  'docs/design/README.md' `
  'story/01-core-story-bible.md' `
  'story/02-character-relationship-handbook.md' `
  'story/03-seven-day-production-map.md' `
  'story/05-canon-amendments-2026-07-19.md' `
  'story/06-seven-day-scene-beatbook.md' `
  'story/07-seven-day-causal-matrix.md' `
  'story/library/03-seven-day-plot-material-library.md'
if ($LASTEXITCODE -eq 0) { throw 'Unfinished drafting language remains in an active reconciliation artifact.' }
if ($LASTEXITCODE -ne 1) { throw "Unfinished-token scan failed with rg exit $LASTEXITCODE." }
```

Expected: no matches. `PLACEMENT UNSELECTED`, encounter `UNSELECTED`, provisional Friday, and `PASS ONE OPEN` are deliberate bounded statuses, not unfinished prose.

**Step 4: Prove protected narrative blocks survived the reconciliation**

Run this normalized section comparison against the Task 0 baseline commit stored
in the archive:

```powershell
$library = Get-Content -LiteralPath 'story/library/03-seven-day-plot-material-library.md' -Raw
$commitMatch = [regex]::Match($library, '(?m)^- \*\*Source commit:\*\* (?<value>[0-9a-f]{40})$')
if (-not $commitMatch.Success) { throw 'Cannot recover the Task 0 baseline commit from the library.' }
$baseline = $commitMatch.Groups['value'].Value
function Get-BaselineText([string]$path) {
  $lines = @(& git show "${baseline}:$path")
  if ($LASTEXITCODE -ne 0) { throw "Cannot read protected baseline path: $path" }
  return ([string]::Join("`n", $lines)).Replace("`r`n", "`n").Replace("`r", "`n")
}
function Get-CurrentText([string]$path) {
  return (Get-Content -LiteralPath $path -Raw).Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
}
function Get-HeadingBlock([string]$text, [int]$level, [string]$title) {
  $prefix = '#' * $level
  $escaped = [regex]::Escape($title)
  $pattern = "(?ms)^$prefix $escaped`n.*?(?=^#{1,$level} |\z)"
  $matches = @([regex]::Matches($text, $pattern))
  if ($matches.Count -ne 1) { throw "Protected heading must occur exactly once: $prefix $title" }
  return $matches[0].Value.TrimEnd("`n")
}
function Assert-BlocksUnchanged([string]$path, [object[]]$records) {
  $before = Get-BaselineText $path
  $after = Get-CurrentText $path
  foreach ($record in $records) {
    $level = [int]$record[0]
    $title = [string]$record[1]
    if ((Get-HeadingBlock $before $level $title) -cne (Get-HeadingBlock $after $level $title)) {
      throw "Protected narrative block changed: $path -> $title"
    }
  }
}
Assert-BlocksUnchanged 'story/01-core-story-bible.md' @(
  @(2,'Experience Contract'), @(2,'Dramatic Questions'), @(2,'Canon Vocabulary'),
  @(2,'East Harbour University and Conservatory'), @(2,'Physical-Reality Rules'),
  @(2,'Observer Pressure'), @(2,'Mystery Fairness and Abnormality Budget'),
  @(2,'Character Canon Essentials'), @(2,'Fixed Hidden Histories'),
  @(2,'Priscilla–Lavinia Four-State Deck'), @(2,'Unowned Past Fragments'),
  @(3,'Day 1 — Institutional Uncertainty'), @(3,"Day 2 — Priscilla’s Concealed Knowledge"),
  @(3,"Day 4 — Sylvia’s Preparation"), @(3,'Day 6 — Audience Implication'),
  @(3,'Day 2 Non-Counting Micro-Scene — The Umbrella Pickup')
)
Assert-BlocksUnchanged 'story/02-character-relationship-handbook.md' @(
  @(2,'Angela–Priscilla'), @(2,'Angela–Lavinia'), @(2,'Angela–Sylvia'),
  @(2,'Priscilla–Lavinia'), @(2,'Priscilla–Sylvia'), @(2,'Lavinia–Sylvia'),
  @(2,'Character Interpretations of Anomalous Clustering'),
  @(2,'Cross-Character Dialogue Tests'), @(2,'Body-Language Contrast Tests'),
  @(2,'Common Flattening Errors'), @(2,'Reaction-Test Dialogue Samples')
)
Assert-BlocksUnchanged 'story/06-seven-day-scene-beatbook.md' @(
  @(3,'Entry Conditions'), @(3,'Private Causal Spine'),
  @(3,'Reaction Test: Chair, Folder, and `will`'),
  @(3,'Tone Hinge: The Same Second Folder'), @(3,'Later Evidence and Residue'),
  @(3,'Rejected Interpretations and Lines'), @(3,'Non-Canon Craft Reference')
)
git diff --unified=1 $baseline -- 'story/02-character-relationship-handbook.md'
```

Expected: every exact protected block matches. Human review of the final Handbook
diff confirms dossier edits are confined to authority, state/attitude fields,
the template, and the final checklist; all motive, knowledge, consent, control,
voice, language, body, history, and relationship substance remains intact.

**Step 5: Run repository documentation validation with honest scope**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  & '.\tools\testing\Invoke-IsolatedGodot.ps1' `
    -SuiteId 'seven-day-constellation-docs' `
    -LogName 'seven-day-constellation-docs.log' `
    -GodotArgs @(
      '-s',
      'res://tools/docs/validate_docs.gd',
      '--',
      '--beads-snapshot=res://.godot/beads/phase2r-all.json'
    )
}
```

Expected when the accepted read-only `.godot/beads/phase2r-all.json` snapshot is present: isolated Godot process exits 0 and reports a passing repository documentation validation. This exact command passed at planning time on 2026-08-28. Record explicitly that the validator does not inspect story semantics or prove local-link correctness; the preceding gates supply that evidence.

In a new worktree where the ignored snapshot is absent, do not manufacture or copy authority evidence and do not mutate Beads. Run this global regression from a checkout containing the accepted snapshot against the same committed tree, or record it as unavailable. Snapshot absence cannot be substituted for any story-specific gate above and does not block this narrative-only reconciliation because the validator has no story coverage.

**Step 6: Perform the human causal-agency audit**

Compare the final tree against specification section 12 and record a short evidence table under `Pass One Freeze Evidence` covering:

- exactly twelve solo and two pair windows;
- all three initial Friend states and exact valves;
- each protected anchor across zero-date schedules, alternate selections,
  applicable pair outcomes, Hospital/supersession, and unseen carriers, with a
  lawful knowledge route and exported residue in every case;
- six contacts with contextual echo and Day 7 fallback;
- five distinct pair modes;
- exact Day 7 order and faint precedence;
- no unlawful knowledge from unseen scenes;
- no progress caused merely by non-attendance unless a cited upstream rule owns
  an offscreen counterpart;
- one necessary residue or explicit negative space per day;
- at least one ordinary, anomaly-free option remains possible for every future audition;
- no single anomaly proves a supernatural cause or solves the week;
- knowledge, consent, medical, institutional, geographic, scheduling, and
  physical statements separate established fact from character inference and
  unresolved cause;
- essential relationship action remains dialogue-led, sparse perceptual prose is
  bounded, and every illustrative line remains visibly `REACTION TEST`;
- active/audition/historical authority is unmistakable.

This is an evidence audit, not a claim that any unselected premise has been approved.
The specification section 12 staging clarification assigns the check requiring
an ordinary candidate to have been considered for every window to Pass Two.
Record it as `DEFERRED TO PASS TWO`, not passed: Pass One proves that an
anomaly-free candidate remains possible and that no candidate has leaked into
the skeleton. This deferral blocks declaring the seven-day plot finished, but it
does not block freezing the approved plot-free obligation lattice under section
6.2.

**Step 7: Freeze the plot-free constellation**

Only after Steps 1–5 pass, use `apply_patch` to change the matrix authoring status from:

```text
PASS ONE OPEN
```

to:

```text
PASS ONE FROZEN — 2026-08-28
```

Keep all fourteen encounter-window records `UNSELECTED`, keep `Approved Placed Premises` as `None.`, and keep Room 2.17 `APPROVED CAUSAL CORE — PLACEMENT UNSELECTED`.

Before committing, re-run Task 6 Step 7's exact registry-row script, Task 6's
named-premise negative scan, Task 9's local-link and unfinished-token gates, and
the protected-block comparison. Then run:

```powershell
$text = (Get-Content -LiteralPath 'story/07-seven-day-causal-matrix.md' -Raw).Replace("`r`n", "`n").Replace("`r", "`n")
if ([regex]::Matches($text, '(?m)^PASS ONE FROZEN — 2026-08-28$').Count -ne 1) { throw 'Matrix must contain exactly one frozen status.' }
if ($text -match '(?m)^PASS ONE OPEN$') { throw 'Open status survived the freeze edit.' }
if ([regex]::Matches($text, 'Room 2\.17 — APPROVED CAUSAL CORE — PLACEMENT UNSELECTED').Count -ne 1) { throw 'Room 2.17 placement status drifted during freeze.' }
$begin = '<!-- BEGIN APPROVED PLACED PREMISES -->'
$end = '<!-- END APPROVED PLACED PREMISES -->'
$start = $text.IndexOf($begin, [StringComparison]::Ordinal)
$stop = $text.IndexOf($end, [StringComparison]::Ordinal)
if ($start -lt 0 -or $stop -le $start) { throw 'Approved-placement markers are missing.' }
if ($text.Substring($start + $begin.Length, $stop - ($start + $begin.Length)).Trim() -cne 'None.') { throw 'A premise became placed during freeze.' }
if ([regex]::Matches($text, '(?m)^\| `(?:solo\.(?:priscilla|lavinia|sylvia)\.day_[1-6]|pair\.priscilla_lavinia\.day_[26])` \|[^\r\n]*\| UNSELECTED \|$').Count -ne 14) {
  throw 'Not all fourteen encounter rows remain UNSELECTED.'
}
```

Expected: all pre-commit gates pass against the bytes that will be committed.

**Step 8: Commit the freeze evidence**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command {
  $env:DWM_COMMIT_AUTHORIZED = '1'
  $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
  & '.\tools\git\Invoke-ExactPathCommit.ps1' `
    -RequiredStatus ([ordered]@{ 'story/07-seven-day-causal-matrix.md' = 'M' }) `
    -ExpectedHead $head `
    -Message 'docs(story): freeze seven-day causal constellation'
}
```

Expected status: `M` for the matrix only.

After the exact-path helper succeeds, run `git diff --quiet HEAD --
story/07-seven-day-causal-matrix.md`, then re-run Task 6 Step 7's registry script,
the final frozen-status script above, the local-link gate, the unfinished-token
gate, and the immutable archive recheck. Every result must pass against the clean
committed matrix before completion is claimed.

**Step 9: Verify final commit and worktree boundaries**

Run:

```powershell
git log --oneline --decorate -12
git status --short
$spec = Get-Content -LiteralPath 'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' -Raw
$baseMatch = [regex]::Match($spec, '(?m)^implementation_base_commit:\s*"?(?<value>[0-9a-f]{40})"?\s*$')
if (-not $baseMatch.Success) { throw 'Implementation base commit is unavailable.' }
$base = $baseMatch.Groups['value'].Value
$expected = @(
  "M`tdocs/design/README.md",
  "M`tdocs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md",
  "M`tstory/01-core-story-bible.md",
  "M`tstory/02-character-relationship-handbook.md",
  "M`tstory/03-seven-day-production-map.md",
  "M`tstory/05-canon-amendments-2026-07-19.md",
  "A`tstory/06-seven-day-scene-beatbook.md",
  "A`tstory/07-seven-day-causal-matrix.md",
  "A`tstory/library/03-seven-day-plot-material-library.md"
) | Sort-Object
$actual = @(& git -c core.quotepath=false diff --name-status --no-renames "$base..HEAD") | Sort-Object
if ([string]::Join("`n", $actual) -cne [string]::Join("`n", $expected)) {
  throw "Final implementation path ledger differs from the authorized scope.`n$($actual -join "`n")"
}
$paths = @($expected | ForEach-Object { ($_ -split "`t", 2)[1] })
& git diff --check "$base..HEAD" -- @paths
if ($LASTEXITCODE -ne 0) { throw 'Final implementation range failed diff check.' }
```

Expected: the reconciliation commits are visible in order; diff check passes; any remaining dirty paths are pre-existing owner work outside this plan. Do not clean or include them.

---

## Completion Boundary

The bounded documentation reconciliation is complete only when:

- the current named Map exists verbatim in the noncanonical library with a real source commit;
- the active Production Map contains no selected plot;
- the matrix contains the exact fixed fourteen-window and six-message constellations;
- every active state and ending statement agrees with August law;
- Room 2.17 is protected but unplaced;
- July conflicts are visibly historical without erasing their reasoning;
- all local links and task-specific scans pass;
- Pass One is explicitly frozen while all encounter-window records remain unselected.

The next authorized creative act is the full Day 1 candidate audition described in specification section 13. It requires a new collaborative selection cycle; this plan does not pre-authorize or preselect its universes.
The full seven-day plot remains incomplete until Pass Two has considered an
ordinary candidate for every window and the owner has explicitly approved the
selected causal records.
