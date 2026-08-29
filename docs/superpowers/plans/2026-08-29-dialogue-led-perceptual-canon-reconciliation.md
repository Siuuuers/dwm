# Dialogue-Led Perceptual Canon Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan.

**Goal:** Establish one active story-delivery law in which dialogue remains the dramatic engine while rare, character-bound perceptual prose may reach the audience, and promote the approved reusable seven-day and relationship laws into their proper authorities without selecting any plot candidate.

**Architecture:** The Core Story Bible owns the complete narrative and perceptual contract. The Character & Relationship Handbook derives performance tests from it. The August design, Two-Pass specification, Public Project Profile, Scene Beatbook, Causal Matrix, Room-Owned Aperture specification, and five UI amendments receive only the minimum projection or recital correction needed to stop contradicting that authority. No narrator system, new viewpoint surface, scene premise, runtime schema, or accessibility feature is created.

**Tech Stack:** Markdown narrative and design artifacts, PowerShell 5.1 verification, Git exact-path commits, repository documentation validation through Godot 4.x.

**Spec:** [`docs/superpowers/specs/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md`](../specs/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md)

## Global Constraints

- This is documentation reconciliation only. Do not edit Godot scenes, GDScript, Dialogic timelines, `prompt_docs/`, assets, localization, save data, Beads records, or generated evidence.
- Do not audition or approve a Day 1 premise, place Room 2.17, author final DTL, promote `The Bright Point`, define attachment-card behavior, or create a route, ending, triad, supporting-character subplot, or new audience-visible surface.
- The implementation plan must be owner-approved and the specification metadata must say `implementation_authorized: true` before Task 0 begins. This committed plan is initially `proposed`.
- Treat [`story/01-core-story-bible.md`](../../../story/01-core-story-bible.md) as the sole narrative authority and [`docs/design/2026-08-07-seven-day-dialogic-flow-design.md`](../../design/2026-08-07-seven-day-dialogic-flow-design.md) as intended mechanical authority.
- Keep dialogue primary. Sparse prose may register only what an eligible, conscious, on-scene anchor physically perceives and immediately judges. It may not diagnose emotion, state another person's motive, solve symbolism, identify an unresolved cause, grant hidden knowledge, or head-hop.
- Preserve all existing bans on narrator identity, omniscient or explanatory narration, unrestricted thought transcription, invisible stage directions, UI-authored story prose, offscreen knowledge, and player-authored Angela.
- Keep the single lawful/unlawful prose contrast in the approved specification only. Add no new example catalogue and add no illustrative prose to the Bible.
- Preserve user-authored work and stage only the exact paths named by each task. Never use broad `git add`, `git reset`, `git checkout`, or destructive cleanup.
- Make every prose edit with `apply_patch`. Use formatting tools only after reviewing their exact target and diff.
- Preserve the active Production Map, July historical amendments, Plot Material Library, immutable 65,496-byte source snapshot, prior approved plan bytes and digest, all runtime files, and every unrelated design document.
- Preserve exactly twelve solo plus two conditional pair windows, six ordinary-message slots, seventeen freeze axes, zero approved placed premises, and `Room 2.17 — APPROVED CAUSAL CORE — PLACEMENT UNSELECTED`.
- Preserve Day 2 as ordinary roster fulfillment with no dedicated message pair, pre-echo, timing contradiction, or replacement anomaly. Lavinia returns because her agreed sponsored company attachment has ordinarily concluded.
- Keep the branch `docs/seven-day-constellation-reconciliation` unmerged and unpushed. Integration remains a later owner choice.
- Do not install plugins or use external services.

---

## Shared Interfaces

### Perceptual-prose predicate

A passage may contain character-bound perceptual prose only when every answer in the left column is satisfied and every prohibition in the right column remains false.

| Required | Forbidden |
|---|---|
| The passage is already an authorized audience-visible surface. | Prose creates a scene, viewpoint, playable character, or archive consciousness. |
| One eligible character is conscious, present, and physically perceives the fact. | The line reports an unseen fact, another person's private motive, or an unresolved cause. |
| The anchor is declared by the surface law and remains stable through the continuous passage. | The passage head-hops or silently changes memory ownership. |
| The prose registers an exact object, sensation, position, line of sight, repetition, replacement, omission, or immediate judgment. | The prose explains emotion, symbolism, horror, mechanics, or the correct interpretation. |
| Omission remains lawful; not every visible or audible fact must be restated. | Accessibility is used to force explanatory prose into the base story surface. |

Surface ownership remains exact:

- Angela-attended solo/group scenes, Angela-owned endings/postscripts, and Hospital use Angela only while she is conscious and perceiving.
- Authorized visible Priscilla–Lavinia private counterparts, pair endings/postscripts, and the Day 2 umbrella cutaway may declare Priscilla or Lavinia. Group presentation with Angela defaults to Angela.
- Unowned past fragments have no character-bound prose.
- Gallery and Rehearsal inherit the source passage's anchor and add none.
- Private-offscreen events and any passage without an eligible conscious perceiver have no character-bound prose.

### Authority projection

1. Bible: complete canon and story-delivery law.
2. Handbook: derived writer tests; no new facts.
3. August design and Two-Pass specification: minimal mechanical/workflow terminology correction.
4. Public Profile: spoiler-safe feature language.
5. Beatbook and Matrix: approved-unplaced execution and audit wording only.
6. Aperture and UI amendments: inherited recital correction only; no behavior change.

### Exact-path commit contract

Every commit task uses `tools/git/Invoke-ExactPathCommit.ps1` from the feature worktree with an empty index, a freshly captured `HEAD`, `DWM_COMMIT_AUTHORIZED=1`, and an ordered map containing only that task's paths. A successful call ends with `EXACT_PATH_COMMIT: PASS` followed by the created commit hash. Never add `-RequireRemainingDirtyExact`.

## Execution Checklist

- [ ] Owner Approval Transaction binds this exact plan digest and execution mode.
- [ ] Task 0 installs and runs the ignored verification harness against the authorized baseline.
- [ ] Task 1 makes the Core Story Bible the complete narrative authority.
- [ ] Task 2 derives the Character & Relationship Handbook from the Bible.
- [ ] Task 3 reconciles active story/workflow projections without changing mechanics or premise status.
- [ ] Task 4 repairs inherited aperture and UI recitals without changing behavior.
- [ ] Task 5 runs full invariant validation and obtains a fresh independent whole-range review.

---

## Owner Approval Transaction: Bind this exact plan before Task 0

This transaction occurs only after the owner selects Subagent-Driven or Inline execution. Before selection, the proposal commit must contain this plan and the approved written specification, while the specification remains `implementation_authorized: false`.

1. Capture the proposal commit as `implementation_base_commit`.
2. Compute the plan's canonical SHA-256 from strict UTF-8 without BOM after normalizing CRLF and CR to LF:

   ```powershell
   $planPath = 'docs/superpowers/plans/2026-08-29-dialogue-led-perceptual-canon-reconciliation.md'
   $plan = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $planPath))
   $plan = $plan.Replace("`r`n", "`n").Replace("`r", "`n")
   $utf8 = [Text.UTF8Encoding]::new($false)
   $sha = [Security.Cryptography.SHA256]::Create()
   try {
     $planDigest = -join ($sha.ComputeHash($utf8.GetBytes($plan)) | ForEach-Object { $_.ToString('x2') })
   } finally {
     $sha.Dispose()
   }
   $planDigest
   ```

   Expected: one lowercase 64-character digest.
3. Use `apply_patch` to change only the specification frontmatter. Add or set:

   ```yaml
   implementation_plan_status: approved
   implementation_plan_sha256: "the computed lowercase digest"
   implementation_execution_mode: subagent_driven
   implementation_approved_by: project_owner
   implementation_authorization_state: approved
   implementation_authorization_scope: dialogue_led_perceptual_canon_reconciliation_tasks_0_through_5_only
   implementation_base_commit: "the captured full proposal commit"
   implementation_plan_approved_on: 2026-08-29
   implementation_authorized_on: 2026-08-29
   implementation_authorized: true
   implementation_commit_authorized: true
   implementation_commit_approved_by: project_owner
   implementation_commit_scope: exact_path_boundaries_in_approved_plan_only
   implementation_commit_authorized_on: 2026-08-29
   ```

   Use `inline` instead of `subagent_driven` only if the owner selects Inline execution. The quoted descriptions above are instructions; write the actual digest and commit, not those descriptions.
4. Recompute the digest and prove that it equals the recorded metadata. Confirm the plan itself is unchanged.
5. Commit only the specification:

   ```powershell
   $env:DWM_COMMIT_AUTHORIZED = '1'
   $head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
   & '.\tools\git\Invoke-ExactPathCommit.ps1' `
     -RequiredStatus ([ordered]@{ 'docs/superpowers/specs/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md' = 'M' }) `
     -ExpectedHead $head `
     -Message 'docs: authorize perceptual canon reconciliation'
   ```

   Expected: one exact-path commit pass for the specification only.
6. Do not edit the plan after authorization. Any plan-byte change invalidates the digest and returns the transaction to owner review.

---

## Task 0: Establish the verification harness and baseline gates

**Files:**

- Add, ignored and not committed: `C:\Users\glori\Documents\dwm\.superpowers\sdd\2026-08-29-dialogue-led-perceptual-canon-reconciliation\verification.ps1`
- Verify only: all fifteen proposal and implementation paths listed in Tasks 1–4, the specification, and this plan
- Verify unchanged: `story/03-seven-day-production-map.md`, `story/05-canon-amendments-2026-07-19.md`, `story/library/03-seven-day-plot-material-library.md`, `docs/superpowers/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md`, runtime, and all other tracked paths

- [ ] **Step 1: Prove authorization and clean starting state**

Run:

```powershell
git status --short --branch
git rev-parse --verify 'HEAD^{commit}'
git diff --name-status --no-renames HEAD~1..HEAD
```

Expected: branch `docs/seven-day-constellation-reconciliation`, a clean worktree, and the authorization commit changes only the August 29 specification.

- [ ] **Step 2: Create the ignored verifier with `apply_patch`**

Copy Appendix A exactly into the ignored verifier with `apply_patch`; do not redesign or abbreviate its gates. The script accepts `-Phase BeforeContent` or `-Phase Final` and an optional full `-ExpectedHead`. Both phases must fail on a precise assertion. `BeforeContent` exits zero only after emitting:

```text
AUTHORIZATION_AND_PLAN_DIGEST: PASS
AUTHORIZED_SCOPE: PASS (proposal only)
PROTECTED_BYTES: PASS
IMMUTABLE_ARCHIVE: PASS
STALE_BASELINE: PASS
CANDIDATE_EXCLUSION: PASS
DAY2_RETIREMENT: PASS
FROZEN_REGISTRIES: PASS
TRACKED_LOCAL_LINKS: PASS
UNFINISHED_TOKEN_SCAN: PASS
BEFORE_CONTENT_VERIFICATION: PASS
```

`Final` exits zero only after emitting:

```text
AUTHORIZATION_AND_PLAN_DIGEST: PASS
AUTHORIZED_SCOPE: PASS
PROTECTED_BYTES: PASS
IMMUTABLE_ARCHIVE: PASS
PERCEPTUAL_AUTHORITY: PASS
ANCHOR_AND_EPISTEMIC_LAW: PASS
REUSABLE_CANON_PACKAGE: PASS
CANDIDATE_EXCLUSION: PASS
DAY2_RETIREMENT: PASS
FROZEN_REGISTRIES: PASS
TRACKED_LOCAL_LINKS: PASS
UNFINISHED_TOKEN_SCAN: PASS
FINAL_STATIC_VERIFICATION: PASS
```

- [ ] **Step 3: Run the fail-first baseline**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\glori\Documents\dwm\.superpowers\sdd\2026-08-29-dialogue-led-perceptual-canon-reconciliation\verification.ps1' -Phase BeforeContent
```

Expected: all baseline, authorization, archive, Day 2, and frozen-registry gates pass; the script confirms that the exact stale recitals still exist and that the corrected required canon is not yet complete.

- [ ] **Step 4: Record the baseline report outside Git**

Save the command output in the same ignored audit directory as `baseline-report.md` using `apply_patch`. Record the authorization HEAD, plan digest, the fifteen allowed final paths, protected-path hashes, and the fail-first findings. Do not stage either audit file.

---

## Task 1: Make the Core Story Bible the complete authority

**Files:**

- Modify: `story/01-core-story-bible.md`
- Verify: `docs/superpowers/specs/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md`

- [ ] **Step 1: Confirm the stale Bible contract**

Run:

```powershell
rg -n '## Dialogue-Only Writing Contract|The released game contains no narrator, thought boxes, invisible explanatory prose|Production descriptions in private documents are staging instructions, not in-game prose' 'story/01-core-story-bible.md'
```

Expected: all three stale contract statements are present.

- [ ] **Step 2: Add the approved reusable canon in its owning sections**

Use `apply_patch` and make only these Bible changes:

- In `Open Week Structure`, add that neutral institutional duties place existing familiarity, desire, curiosity, investment, receptivity, care, and control methods into a shared timetable; records, expectations, attendance, absence, and practical consequences make postponement harder. Observer Pressure may amplify clustering or urgency but cannot originate desire, consent, obligation, or decision. Day 7 culminates accumulated pressure; it is not sudden love, compulsory confession, an official label, or the end of the characters' lives.
- In `Day 2 — Ordinary Return, Not a Separate Anchor`, state that Lavinia returns because the agreed period of her sponsored company attachment ordinarily concluded. Preserve every existing no-replacement-anomaly sentence.
- In `Angela`, begin the addition with the exact sentence `Recognition is not classification.` She may notice abnormality, flirtation, control, or preparation and decline to classify, investigate, or answer when doing so creates an obligation she prefers to postpone. Ignoring noticed evidence is a consequential choice; `troublesome` is a writer threshold, not a catchphrase.
- In `Relationship State and Tone`, define `Friend` as the starting degree of reciprocal enactment, not the absence of attraction, flirtation, history, dangerous comfort, or one-sided investment. Promotion changes legibility and consequence; it does not manufacture desire or personality.
- In the same section, state the unequal Day 1 temperatures exactly: Angela–Priscilla have a familiar charged correction/verification/delegation rhythm without agreed romance or blanket permission; Angela–Lavinia's astronomy friendship permits natural knowingly understood teasing and flirtation, Lavinia does not habitually retain a prepared “only joking” escape, and Angela may recognize the register without knowing all desire or owing reciprocity; Angela–Sylvia is asymmetric, with Sylvia personally and erotically invested while Angela brings childhood recognition, occasional familiarity, and possible receptivity rather than established reciprocal romantic intent.
- In `Event Architecture`, begin with `Date is production shorthand for an Angela-attended solo encounter` and state that it may surface as deliberate, practical, obligatory, or incidental but cannot bypass invitation, scheduling, attendance, Hospital, or absence law. Begin the paired clarification with `Group remains the authorized Angela–Priscilla–Lavinia presentation`; its private counterparts remain Priscilla and Lavinia, with no triad.
- Add an `Incidental Cast Economy` section: no individuated speaking extra exists merely to carry exposition, logistics, causality, or interpretation; routine labor may appear through records, objects, queues, rooms, schedules, messages, and changed circumstances. Preserve already established parents, culprit, pursuer, visitors, and physically necessary qualified help in bounded roles.
- Add a `Character Agency and Author Greed` section containing the seven approved volition, knowledge, control-signature, refusal, consequence, autonomy, and author-greed questions. State that dossiers constrain but do not exhaust a person and that elegance cannot excuse a failed gate.
- Add the approved aesthetic and physical restraint: exact facts with unsettled meaning; behavior and consequence before explanation; attractive sweetness beside danger; normalized procedure; no brutality-only escalation, sentimental reconciliation, ornate symbolic decoding, coy feyness, melodramatic declaration, dialogue-as-solution-key, or causality-free randomness. Craft references are diagnostics, not recipes. Mechanics are neither explained nor praised by characters. Plot-bearing medical, astronomical, geographic, technological, scheduling, and institutional claims require verification and lawful knowledge channels before premise approval.

Do not add proofing-room, Bright Point, photo, Room placement, or final-dialogue material.

- [ ] **Step 3: Replace the story-delivery contract**

Rename the heading to `## Dialogue-Led Perceptual Writing Contract` and encode sections 4.1, 4.2, and 4.4 of the approved specification without copying its chair/folder contrast. The Bible contract must state:

- dialogue is the dramatic engine; visible action, diegetic text, objects, and sound remain primary evidence;
- sparse perceptual prose may register exact object, bodily sensation, position, line of sight, repetition, replacement, omission, or immediate judgment salient to one eligible consciousness;
- it may not diagnose emotion, state another's motive, reveal an unperceived fact, explain symbolism, identify an unresolved cause, dictate interpretation, or head-hop;
- every authorized surface uses the exact anchor rules in `Shared Interfaces` above;
- separately presented visual/audio evidence may exceed what the anchor notices only through its already approved external channel and cannot become prose or character knowledge;
- missing, unseen, and unreceived evidence proves only absence of that carrier unless an authorized system records more;
- base prose need not restate every fact for TTS; any optional description layer needs later design;
- production descriptions remain private staging unless explicitly authored and separately approved as audience-visible perceptual prose; reaction tests and complete scenes do not become final DTL by proximity.

- [ ] **Step 4: Verify the Bible alone**

Run:

```powershell
rg -n '## Dialogue-Led Perceptual Writing Contract|Dialogue remains the dramatic engine|unowned past fragment|head-hopping|Open Week does not manufacture|sponsored company attachment|only joking|Incidental Cast Economy|Character Agency and Author Greed|plot-bearing medical' 'story/01-core-story-bible.md'
rg -n '## Dialogue-Only Writing Contract|The released game contains no narrator, thought boxes, invisible explanatory prose' 'story/01-core-story-bible.md'
git diff --check -- 'story/01-core-story-bible.md'
```

Expected: the first command finds every required concept; the second returns exit code 1; diff check passes. Inspect the diff and confirm no example prose, candidate, placement, mechanic, or unrelated canon changed.

- [ ] **Step 5: Commit the Bible**

```powershell
$env:DWM_COMMIT_AUTHORIZED = '1'
$head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
& '.\tools\git\Invoke-ExactPathCommit.ps1' `
  -RequiredStatus ([ordered]@{ 'story/01-core-story-bible.md' = 'M' }) `
  -ExpectedHead $head `
  -Message 'docs(story): establish dialogue-led perceptual canon'
```

Expected: one exact-path commit pass for the Bible only.

---

## Task 2: Derive the Handbook without creating new canon

**Files:**

- Modify: `story/02-character-relationship-handbook.md`
- Verify: `story/01-core-story-bible.md`

- [ ] **Step 1: Confirm the stale Handbook surface**

Run:

```powershell
rg -n 'All production prose below is staging guidance, not narration|## Dialogue-Only Character Writing|The released game has no narrator, thought box, or invisible explanatory prose' 'story/02-character-relationship-handbook.md'
```

Expected: all three stale statements are present.

- [ ] **Step 2: Derive a dialogue-led performance section**

Use `apply_patch` to rename the heading `## Dialogue-Led Character Writing` and replace only the stale opening recital. Preserve the existing spoken, audible-self-talk, diegetic-text, visible-action, and diegetic-sound channels, then add derived tests:

- dialogue must carry the relationship turn; sparse prose supports exact perceived evidence rather than translating the dossier;
- name the eligible anchor before drafting and keep it stable;
- the anchor must consciously and physically perceive the fact;
- immediate judgment may be partial, irritated, mistaken, or withholding, but cannot state another's private motive or settle interpretation;
- an unowned fragment, private-offscreen event, unconscious Angela-owned passage, or UI/archive surface without inherited source prose supplies none;
- omission is permitted and accessibility description remains a later layer;
- reaction tests remain illustrative rather than final DTL.

Do not add a second lawful/unlawful prose example.

- [ ] **Step 3: Derive relationship and agency tests**

Use `apply_patch` to make these bounded additions:

- Expand `Friend` performance so chosen familiarity, teasing, flirtation, dangerous comfort, and uneven investment may predate Day 1; state changes mutual legibility and consequence, not desire.
- Under Angela–Priscilla, preserve their correction/verification/delegation rhythm while testing consent and whether Angela keeps, revises, or refuses Priscilla's wording.
- Under Angela–Lavinia, record natural knowingly understood teasing/flirtation and Lavinia's lack of a prepared “only joking” escape; never use that to assert Angela's reciprocal desire.
- Under Angela–Sylvia, retain the asymmetric investment and reject any implication of established reciprocal romantic intent.
- Add the seven-question character-faithfulness gate as a checklist, plus the lawful-knowledge channel and physical-world verification test.
- Add the incidental-cast economy and the distinction between `Date` as encounter shorthand and romantic diegetic meaning.
- Add a whole-scene consistency check for diagnostic craft references, normalized abnormality, exact causality, missable evidence, mechanics not praised by characters, and refusal of explanatory or symbolic solution dialogue.

Every addition must cite or clearly derive from the Bible. Do not add history, diagnosis, motive, route, mechanism, candidate, or confirmed relationship label.

- [ ] **Step 4: Verify derivation and commit**

Run:

```powershell
rg -n '## Dialogue-Led Character Writing|eligible anchor|head-hop|Friend.*flirt|only joking|character-faithfulness|lawful knowledge|Incidental.*Cast|production shorthand|diagnostic' 'story/02-character-relationship-handbook.md'
rg -n '## Dialogue-Only Character Writing|All production prose below is staging guidance, not narration' 'story/02-character-relationship-handbook.md'
git diff --check -- 'story/02-character-relationship-handbook.md'
```

Expected: required derived guidance is present, both stale phrases are absent, and diff check passes.

Commit:

```powershell
$env:DWM_COMMIT_AUTHORIZED = '1'
$head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
& '.\tools\git\Invoke-ExactPathCommit.ps1' `
  -RequiredStatus ([ordered]@{ 'story/02-character-relationship-handbook.md' = 'M' }) `
  -ExpectedHead $head `
  -Message 'docs(story): derive perceptual character guidance'
```

Expected: one exact-path commit pass for the Handbook only.

---

## Task 3: Reconcile active story and workflow projections

**Files:**

- Modify: `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`
- Modify: `docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md`
- Modify: `story/04-public-project-profile.md`
- Modify: `story/06-seven-day-scene-beatbook.md`
- Modify: `story/07-seven-day-causal-matrix.md`

- [ ] **Step 1: Confirm the five projection defects**

Run:

```powershell
rg -n 'Only character dialogue and executable character action presentation may tell|physical plausibility, dialogue-only|Dialogue-only communicability|Dialogue-only storytelling|Under the current Dialogue-Only Writing Contract|Prose is staging guidance under the current Dialogue-Only Writing Contract|sparse staging evidence|writer-facing staging' `
  'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' `
  'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' `
  'story/04-public-project-profile.md' `
  'story/06-seven-day-scene-beatbook.md' `
  'story/07-seven-day-causal-matrix.md'
```

Expected: every listed stale projection appears; no other file is in scope.

- [ ] **Step 2: Apply minimum projections**

Use `apply_patch`:

- August design: replace `Only character dialogue and executable character action presentation may tell the story. Do not add an explanatory narrator.` with `Dialogue and executable character action remain the primary story carriers. Sparse character-bound perceptual prose may support them under the Core Story Bible's anchor and epistemic law. Do not add an explanatory narrator.` Also replace only `dialogue-only story delivery` in the craft-lens boundary with `dialogue-led story delivery with sparse, character-bound perceptual prose`; preserve all calendar, message, promotion, Hospital, pair, Day 7, ending, and Dialogic mechanics.
- Two-Pass specification: rename only the gate label `Dialogue-only communicability` to `Dialogue-led perceptual communicability`. Preserve its already-correct question and section 8 sparse-perception law byte-for-byte.
- Public Profile: replace the feature bullet with spoiler-safe wording: dialogue-led storytelling through speech, messages, visible action, objects, body language, sound, interface behavior, and rare character-bound perception, without an explanatory narrator telling the audience what to believe.
- Beatbook authority paragraph: permit reference prose to be tested as audience-visible anchor-bound perception while keeping every exchange `REACTION TEST`, not final DTL. Update the Room reaction-test label accordingly without promoting its prose. In `Visibility Boundary`, state that Lavinia is the declared anchor for the Private-visible reaction test; audience-visible use still requires its separate final approval. Preserve placement-unselected status and every Group/Missed/Private-offscreen/Prevented boundary.
- Matrix: change only the presentation audit and reaction-test column wording needed to call sparse perception anchor-bound audience evidence rather than staging. Do not select a final perceptual solution, rewrite any carrier, or change a row count, status, freeze axis, anomaly, or Day 2 fact.

- [ ] **Step 3: Verify projections and frozen mechanics**

Run:

```powershell
rg -n 'Sparse character-bound perceptual prose|physical plausibility, dialogue-led|Dialogue-led perceptual communicability|rare character-bound perception|anchor-bound perception|declared anchor|anchor-bound audience evidence' `
  'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' `
  'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' `
  'story/04-public-project-profile.md' `
  'story/06-seven-day-scene-beatbook.md' `
  'story/07-seven-day-causal-matrix.md'
rg -n 'Only character dialogue and executable character action presentation may tell|physical plausibility, dialogue-only|Dialogue-only communicability|Dialogue-only storytelling|Under the current Dialogue-Only Writing Contract|sparse staging evidence|writer-facing staging' `
  'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' `
  'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' `
  'story/04-public-project-profile.md' `
  'story/06-seven-day-scene-beatbook.md' `
  'story/07-seven-day-causal-matrix.md'
git diff --check -- `
  'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' `
  'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' `
  'story/04-public-project-profile.md' `
  'story/06-seven-day-scene-beatbook.md' `
  'story/07-seven-day-causal-matrix.md'
```

Expected: corrected phrases are present, stale phrases return exit code 1, and diff check passes. Run the Task 0 verifier's frozen-registry and Day 2 functions before committing; all counts and ordinary-return gates must pass.

- [ ] **Step 4: Commit the projections**

```powershell
$env:DWM_COMMIT_AUTHORIZED = '1'
$head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
& '.\tools\git\Invoke-ExactPathCommit.ps1' `
  -RequiredStatus ([ordered]@{
    'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' = 'M'
    'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' = 'M'
    'story/04-public-project-profile.md' = 'M'
    'story/06-seven-day-scene-beatbook.md' = 'M'
    'story/07-seven-day-causal-matrix.md' = 'M'
  }) `
  -ExpectedHead $head `
  -Message 'docs(story): reconcile perceptual prose projections'
```

Expected: one exact-path commit pass for exactly five files.

---

## Task 4: Repair inherited aperture and UI recitals

**Files:**

- Modify: `docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md`
- Modify: `docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md`
- Modify: `docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md`
- Modify: `docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md`
- Modify: `docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md`
- Modify: `docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md`

- [ ] **Step 1: Confirm only the inherited recitals need correction**

Run:

```powershell
rg -n 'no narrator, thought box, invisible|does not permit narration, thought transcription, prose interpretation|narrator prose, thoughts, invisible stage directions|no-narrator, no-thought-box|dialogue-only, no-narrator|story dialogue-only|no-narrator law, no private-thought prose|narrator or private-thought material|no-narrator and no-private-thought law|no narrator, no private thought box|offscreen speaker treatment, narrator|no-narrator, no-private-thought' `
  'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md' `
  'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md' `
  'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md' `
  'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md' `
  'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md' `
  'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md'
```

Expected: matches occur only at the inherited authority, exclusion, and verification recitals identified by the specification review.

- [ ] **Step 2: Correct the Aperture specification without changing behavior**

Use `apply_patch` to make these distinctions:

- The game has no narrator identity, thought box, omniscient/explanatory prose, or invisible stage direction; it may contain approved sparse anchor-bound perception.
- Angela's visual absence does not permit unanchored narration, unrestricted thought transcription, explanatory interpretation, or action brackets. Angela-bound prose is legal only when the source passage authorizes it and she is conscious and perceiving.
- Accessibility action/scene metadata remains modality-equivalent and is not rendered as captions, History, narrator UI, stage direction, or interpretation; it does not become story prose or add knowledge.
- The prohibited-feature list continues to reject a narrator system, unrestricted thoughts, invisible stage directions, and explanatory labels; it does not prohibit the Bible's sparse source-authored perception.

Do not alter geometry, speaker disclosure, input, challenge, caption, History, assistive metadata fields, asset recovery, or implementation schema.

- [ ] **Step 3: Correct the five UI recitals without changing behavior**

Use `apply_patch` and preserve each document's scope:

- Contacts: replace the inherited `no-narrator, no-thought-box` recital with no narrator identity, no unrestricted thought box, sparse source-authored anchor-bound perception, and the existing hidden-stat/technical-trust laws.
- Main Menu: replace both `dialogue-only/no-narrator` recitals with dialogue-led story delivery, no narrator identity or unrestricted thought box, and the same audible-self-talk, visual, sound, epistemic, and Observer boundaries.
- Gallery/Rehearsal: source replay inherits already-approved perceptual prose and its anchor; the archive adds no narrator, private thought, viewpoint, interpretation, or new prose. Change the excluded-material bullet to reject archive-authored narrator/private-thought material without stripping legal source prose.
- Narrative Scene Host: distinguish source-authored anchor-bound perception from narrator identity, thought boxes, and player-authored Angela in the authority recital, preserved-laws list, and visual/failure verification. No prose receives a speaker nameplate or makes Angela a visible avatar.
- Ordered Ending Host: inherit the source ending's lawful perceptual anchor while continuing to prohibit a narrator identity, unrestricted private-thought transcription, and UI-authored content. Preserve physical presence for every spoken line.

- [ ] **Step 4: Verify recital consistency and scope**

Run:

```powershell
rg -n 'sparse.*anchor-bound perception|source.*anchor|inherits.*anchor|no narrator identity|unrestricted.*thought' `
  'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md' `
  'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md' `
  'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md' `
  'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md' `
  'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md' `
  'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md'
rg -n 'dialogue-only, no-narrator|story dialogue-only|no-narrator law, no private-thought prose|no-narrator and no-private-thought law|no narrator, no private thought box|no-narrator, no-private-thought' `
  'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md' `
  'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md' `
  'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md' `
  'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md' `
  'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md' `
  'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md'
git diff --check -- `
  'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md' `
  'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md' `
  'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md' `
  'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md' `
  'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md' `
  'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md'
```

Expected: every document states the shared distinction, the ambiguous old recitals are absent, and diff check passes. Inspect each diff to confirm no behavior, field, geometry, order, accessibility atom, or runtime requirement changed.

- [ ] **Step 5: Commit the recital repairs**

```powershell
$env:DWM_COMMIT_AUTHORIZED = '1'
$head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
& '.\tools\git\Invoke-ExactPathCommit.ps1' `
  -RequiredStatus ([ordered]@{
    'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md' = 'M'
    'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md' = 'M'
    'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md' = 'M'
    'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md' = 'M'
    'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md' = 'M'
    'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md' = 'M'
  }) `
  -ExpectedHead $head `
  -Message 'docs(design): align perceptual prose recitals'
```

Expected: one exact-path commit pass for exactly six files.

---

## Task 5: Run integrated verification and fresh independent review

**Files:**

- Verify only: all tracked files
- Add, ignored and not committed: `C:\Users\glori\Documents\dwm\.superpowers\sdd\2026-08-29-dialogue-led-perceptual-canon-reconciliation\final-report.md`
- Add, ignored and not committed: `C:\Users\glori\Documents\dwm\.superpowers\sdd\2026-08-29-dialogue-led-perceptual-canon-reconciliation\final-review.md`

- [ ] **Step 1: Run the complete static verifier**

Run:

```powershell
$head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\glori\Documents\dwm\.superpowers\sdd\2026-08-29-dialogue-led-perceptual-canon-reconciliation\verification.ps1' -Phase Final -ExpectedHead $head
git diff --check 'ec6b4cbcd843856d4c8475bfe294aed5ec59ebad..HEAD'
```

Expected: every named pass from Task 0, a clean exact fifteen-path scope, and no whitespace error.

The exact final range from `ec6b4cbcd843856d4c8475bfe294aed5ec59ebad` must contain only:

```text
A docs/superpowers/plans/2026-08-29-dialogue-led-perceptual-canon-reconciliation.md
A docs/superpowers/specs/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md
M docs/design/2026-08-07-seven-day-dialogic-flow-design.md
M docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md
M docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md
M docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md
M docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md
M docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md
M docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md
M docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md
M story/01-core-story-bible.md
M story/02-character-relationship-handbook.md
M story/04-public-project-profile.md
M story/06-seven-day-scene-beatbook.md
M story/07-seven-day-causal-matrix.md
```

- [ ] **Step 2: Run documentation validation without mutating accepted state**

Capture feature-worktree HEAD/status, original-checkout HEAD/status, and the accepted Beads snapshot byte hash, length, and timestamp before and after this command:

```powershell
& '.\tools\testing\Invoke-IsolatedGodot.ps1' `
  -SuiteId 'dialogue-led-perceptual-canon-reconciliation' `
  -LogName 'dialogue-led-perceptual-canon-reconciliation.log' `
  -GodotArgs @(
    '-s',
    'res://tools/docs/validate_docs.gd',
    '--',
    '--beads-snapshot=C:/Users/glori/Documents/dwm/.godot/beads/phase2r-all.json'
  )
```

Expected: exit code 0, the log contains `DOC_VALIDATION: PASS`, and feature worktree, original checkout, and snapshot remain byte/status-identical.

- [ ] **Step 3: Obtain a fresh independent whole-range review**

Ask a fresh reviewer to examine the complete range:

```text
51c7aeb6fc8dd1eafb4ef6b5623c095f38a7b702..HEAD
```

The reviewer must read the August 29 specification and this plan, then test:

1. one coherent dialogue-led, character-bound perceptual contract across all active authorities;
2. eligible conscious anchors for every visible surface, with no head-hopping, omniscience, hidden knowledge, memory reassignment, or new viewpoint surface;
3. Bible ownership and Handbook derivation of the entire reusable canon package;
4. no proofing-room, Bright Point, Room-placement, final-dialogue, UI-behavior, route, ending, or runtime promotion;
5. byte preservation of protected artifacts and unrelated blocks;
6. Day 2 retirement and ordinary attachment-completion return;
7. unchanged windows, messages, freeze axes, placements, Room status, and prior archive provenance;
8. exact fifteen-path post-design scope, links, unfinished-token scan, and documentation validation.

The review must return either `READY TO INTEGRATE` or exact blocking findings with file and line evidence. A stale pre-Day-2 review is not sufficient.

- [ ] **Step 4: Resolve findings and rerun all gates**

If the reviewer finds a blocker, use `apply_patch` only on an already authorized implementation path and commit the smallest exact-path correction with a message describing the finding. The approved plan itself remains immutable; any finding against its instructions, or any requested change outside the authorized paths or exclusions, returns to owner approval instead of being implemented. Rerun Steps 1–3 with a fresh reviewer until the verdict is `READY TO INTEGRATE`.

- [ ] **Step 5: Record the final evidence and stop before integration**

Use `apply_patch` to write the ignored `final-report.md` and `final-review.md`. Record final HEAD, exact changed paths, all verifier outputs, Godot log result, reviewer verdict, remaining honest boundary, and the fact that the branch is unmerged and unpushed.

Run:

```powershell
git status --short --branch
git log -6 --oneline
```

Expected: clean `docs/seven-day-constellation-reconciliation`, final implementation commits visible, no merge or push performed.

The honest completion boundary remains: this reconciliation establishes the plot-writing law and reusable canon package. It does not finish the Day 1–7 plot; Pass Two candidate audition still begins separately.

---

## Appendix A: Exact ignored verification script

Copy this block verbatim to the Task 0 `verification.ps1` path with `apply_patch`:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('BeforeContent', 'Final')]
    [string]$Phase,
    [string]$ExpectedHead = ''
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Read-Normalized([string]$Path) {
    return (Get-Content -LiteralPath $Path -Raw).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-ExactField([string]$Text, [string]$Name) {
    $match = [regex]::Match($Text, '(?m)^' + [regex]::Escape($Name) + ':\s*"?(?<value>[^"\r\n]+?)"?\s*$')
    Assert-True $match.Success "Missing metadata field: $Name"
    return $match.Groups['value'].Value
}

function Get-CanonicalSha256([string]$Text) {
    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($normalized)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

function Normalize-SearchText([string]$Text) {
    return [regex]::Replace($Text, '\s+', ' ').Trim()
}

function Assert-Contains([string]$Text, [string]$Phrase, [string]$Label) {
    $haystack = Normalize-SearchText $Text
    $needle = Normalize-SearchText $Phrase
    Assert-True ($haystack.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) "$Label missing: $Phrase"
}

function Assert-NotContains([string]$Text, [string]$Phrase, [string]$Label) {
    $haystack = Normalize-SearchText $Text
    $needle = Normalize-SearchText $Phrase
    Assert-True ($haystack.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) "$Label retains: $Phrase"
}

function Strip-MarkedBlock([string]$Text, [string]$Begin, [string]$End) {
    $start = $Text.IndexOf($Begin, [StringComparison]::Ordinal)
    $stop = $Text.IndexOf($End, $start + $Begin.Length, [StringComparison]::Ordinal)
    Assert-True ($start -ge 0 -and $stop -gt $start) "Marked block missing or reversed: $Begin"
    return $Text.Substring(0, $start) + $Text.Substring($stop + $End.Length)
}

$designBase = 'ec6b4cbcd843856d4c8475bfe294aed5ec59ebad'
$reviewBase = '51c7aeb6fc8dd1eafb4ef6b5623c095f38a7b702'
$specPath = 'docs/superpowers/specs/2026-08-29-dialogue-led-perceptual-canon-reconciliation-design.md'
$planPath = 'docs/superpowers/plans/2026-08-29-dialogue-led-perceptual-canon-reconciliation.md'
$verificationIgnore = 'C:/Users/glori/Documents/dwm/.superpowers/sdd/2026-08-28-seven-day-constellation-documentation-reconciliation/verification-empty-ignore'

$implementationPaths = @(
    'docs/design/2026-08-07-seven-day-dialogic-flow-design.md',
    'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md',
    'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md',
    'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md',
    'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md',
    'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md',
    'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md',
    'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md',
    'story/01-core-story-bible.md',
    'story/02-character-relationship-handbook.md',
    'story/04-public-project-profile.md',
    'story/06-seven-day-scene-beatbook.md',
    'story/07-seven-day-causal-matrix.md'
)
$allChangedPaths = @($implementationPaths + $planPath + $specPath | Sort-Object -Unique)
Assert-True ($allChangedPaths.Count -eq 15) 'Authorized final path list is not exactly fifteen.'

$protectedPaths = @(
    'story/03-seven-day-production-map.md',
    'story/05-canon-amendments-2026-07-19.md',
    'story/library/03-seven-day-plot-material-library.md',
    'docs/superpowers/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md'
)

$head = (& git rev-parse --verify 'HEAD^{commit}').Trim()
Assert-True ($head -match '^[0-9a-f]{40}$') 'HEAD is not a full commit.'
if ($ExpectedHead) { Assert-True ($head -ceq $ExpectedHead) "HEAD differs from ExpectedHead: $head" }
Assert-True ((& git branch --show-current).Trim() -ceq 'docs/seven-day-constellation-reconciliation') 'Wrong branch.'
& git merge-base --is-ancestor $designBase $head
Assert-True ($LASTEXITCODE -eq 0) 'Design base is not an ancestor of HEAD.'
& git merge-base --is-ancestor $reviewBase $head
Assert-True ($LASTEXITCODE -eq 0) 'Review base is not an ancestor of HEAD.'
$status = @(& git -c "core.excludesFile=$verificationIgnore" status --porcelain=v1 --untracked-files=all)
Assert-True ($LASTEXITCODE -eq 0 -and $status.Count -eq 0) "Worktree is dirty:`n$($status -join "`n")"

$spec = Read-Normalized $specPath
$plan = Read-Normalized $planPath
foreach ($pair in @(
    @('written_spec_status', 'approved'),
    @('implementation_plan_status', 'approved'),
    @('implementation_approved_by', 'project_owner'),
    @('implementation_authorization_state', 'approved'),
    @('implementation_authorization_scope', 'dialogue_led_perceptual_canon_reconciliation_tasks_0_through_5_only'),
    @('implementation_authorized', 'true'),
    @('implementation_commit_authorized', 'true')
)) {
    Assert-True ((Get-ExactField $spec $pair[0]) -ceq $pair[1]) "Authorization metadata differs: $($pair[0])"
}
Assert-True ((Get-ExactField $spec 'implementation_execution_mode') -in @('subagent_driven', 'inline')) 'Execution mode is invalid.'
Assert-True ((Get-ExactField $spec 'implementation_plan_path') -ceq $planPath) 'Plan path metadata differs.'
Assert-True ((Get-ExactField $spec 'implementation_plan_sha256') -ceq (Get-CanonicalSha256 $plan)) 'Plan digest metadata differs.'
$implementationBase = Get-ExactField $spec 'implementation_base_commit'
Assert-True ($implementationBase -match '^[0-9a-f]{40}$') 'Implementation base is not a full commit.'
& git merge-base --is-ancestor $implementationBase $head
Assert-True ($LASTEXITCODE -eq 0) 'Implementation base is not an ancestor of HEAD.'
$authorizationPath = @(& git rev-list --reverse --ancestry-path "$implementationBase..$head")
Assert-True ($authorizationPath.Count -ge 1) 'Authorization commit is missing.'
$authorizationCommit = $authorizationPath[0].Trim()
$authorizationParent = (& git rev-parse --verify "$authorizationCommit^1").Trim()
Assert-True ($authorizationParent -ceq $implementationBase) 'Authorization commit is not the direct proposal child.'
$authorizationDiff = @(& git diff-tree --no-commit-id --name-status -r $authorizationCommit)
Assert-True ($authorizationDiff.Count -eq 1 -and $authorizationDiff[0] -ceq "M`t$specPath") 'Authorization commit changed more than the specification.'
if ($Phase -eq 'BeforeContent') { Assert-True ($authorizationPath.Count -eq 1) 'Content commits exist before the fail-first gate.' }
Write-Output 'AUTHORIZATION_AND_PLAN_DIGEST: PASS'

$actualScope = @(& git -c core.quotepath=false diff --name-status --no-renames "$designBase..$head" | Sort-Object)
if ($Phase -eq 'BeforeContent') {
    $expectedScope = @("A`t$planPath", "A`t$specPath") | Sort-Object
} else {
    $expectedScope = @($allChangedPaths | ForEach-Object {
        if ($_ -in @($planPath, $specPath)) { "A`t$_" } else { "M`t$_" }
    }) | Sort-Object
}
Assert-True ([string]::Join("`n", $actualScope) -ceq [string]::Join("`n", $expectedScope)) "Authorized scope differs:`n$($actualScope -join "`n")"
if ($Phase -eq 'BeforeContent') { Write-Output 'AUTHORIZED_SCOPE: PASS (proposal only)' }
else { Write-Output 'AUTHORIZED_SCOPE: PASS' }

foreach ($path in $protectedPaths) {
    & git diff --quiet "$designBase..$head" -- $path
    Assert-True ($LASTEXITCODE -eq 0) "Protected bytes changed: $path"
}
$oldSpec = Read-Normalized 'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md'
$oldDigest = Get-ExactField $oldSpec 'implementation_plan_sha256'
$oldActual = (Get-FileHash -LiteralPath 'docs/superpowers/plans/2026-08-28-seven-day-constellation-documentation-reconciliation.md' -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-True ($oldDigest -ceq $oldActual) 'Prior approved plan digest changed.'
Write-Output 'PROTECTED_BYTES: PASS'

$archivePath = 'story/library/03-seven-day-plot-material-library.md'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$archiveBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $archivePath))
Assert-True (-not ($archiveBytes.Length -ge 3 -and $archiveBytes[0] -eq 0xef -and $archiveBytes[1] -eq 0xbb -and $archiveBytes[2] -eq 0xbf)) 'Archive has a UTF-8 BOM.'
$archive = $utf8.GetString($archiveBytes)
Assert-True (-not $archive.Contains("`r")) 'Archive is not LF-only.'
$archiveBegin = '<!-- BEGIN VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
$archiveEnd = '<!-- END VERBATIM SOURCE SNAPSHOT: story/03-seven-day-production-map.md -->'
$archiveStart = $archive.IndexOf($archiveBegin + "`n", [StringComparison]::Ordinal)
$archiveStop = $archive.IndexOf($archiveEnd, $archiveStart + $archiveBegin.Length + 1, [StringComparison]::Ordinal)
Assert-True ($archiveStart -ge 0 -and $archiveStop -gt $archiveStart) 'Archive snapshot markers are invalid.'
$snapshot = $utf8.GetBytes($archive.Substring($archiveStart + $archiveBegin.Length + 1, $archiveStop - ($archiveStart + $archiveBegin.Length + 1)))
$snapshotSha = [Security.Cryptography.SHA256]::Create()
try { $snapshotDigest = -join ($snapshotSha.ComputeHash($snapshot) | ForEach-Object { $_.ToString('x2') }) }
finally { $snapshotSha.Dispose() }
Assert-True ($snapshot.LongLength -eq 65496) 'Archive snapshot length changed.'
Assert-True ($snapshotDigest -ceq '7448db36f724d7acfe50f2479884c03209648c5adc2a1cb6cb641b0af152b4ff') 'Archive snapshot digest changed.'
Write-Output 'IMMUTABLE_ARCHIVE: PASS'

$stale = [ordered]@{
    'story/01-core-story-bible.md' = @('## Dialogue-Only Writing Contract')
    'story/02-character-relationship-handbook.md' = @('## Dialogue-Only Character Writing', 'All production prose below is staging guidance, not narration')
    'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' = @('Only character dialogue and executable character action presentation may tell', 'dialogue-only story delivery')
    'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' = @('Dialogue-only communicability')
    'story/04-public-project-profile.md' = @('Dialogue-only storytelling')
    'story/06-seven-day-scene-beatbook.md' = @('Under the current Dialogue-Only Writing Contract', 'Prose is staging guidance under the current Dialogue-Only Writing Contract', 'writer-facing staging')
    'story/07-seven-day-causal-matrix.md' = @('sparse staging evidence')
    'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md' = @('the released game still contains no narrator, thought box, invisible', 'Her visual absence does not permit narration, thought transcription, prose interpretation', 'They are not rendered as captions, History entries, narrator prose, stage directions, or interpretation', 'narrator prose, thoughts, invisible stage directions, or explanatory labels')
    'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md' = @('the no-narrator, no-thought-box, no-hidden-stat')
    'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md' = @('dialogue-only, no-narrator, no-thought-box', 'story dialogue-only, no-narrator')
    'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md' = @('no-narrator law, no private-thought prose', 'narrator or private-thought material')
    'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md' = @('no-narrator and no-private-thought law', 'no narrator, no private thought box', 'offscreen speaker treatment, narrator')
    'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md' = @('no-narrator, no-private-thought')
}
foreach ($path in $stale.Keys) {
    $text = Read-Normalized $path
    foreach ($phrase in $stale[$path]) {
        if ($Phase -eq 'BeforeContent') { Assert-Contains $text $phrase "Stale baseline $path" }
        else { Assert-NotContains $text $phrase "Final authority $path" }
    }
}

$bible = Read-Normalized 'story/01-core-story-bible.md'
$handbook = Read-Normalized 'story/02-character-relationship-handbook.md'
if ($Phase -eq 'BeforeContent') {
    Assert-NotContains $bible '## Dialogue-Led Perceptual Writing Contract' 'Pre-content Bible'
    Write-Output 'STALE_BASELINE: PASS'
} else {
    $required = [ordered]@{
        'story/01-core-story-bible.md' = @('## Dialogue-Led Perceptual Writing Contract', 'Dialogue remains the dramatic engine', 'Open Week does not manufacture attraction', 'agreed period of her sponsored company attachment has ordinarily concluded', 'Friend names the starting degree of reciprocal enactment', 'only joking', '## Incidental Cast Economy', '## Character Agency and Author Greed', 'A plot-bearing medical')
        'story/02-character-relationship-handbook.md' = @('## Dialogue-Led Character Writing', 'eligible anchor', 'head-hop', 'only joking', 'character-faithfulness', 'lawful knowledge', 'production shorthand')
        'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' = @('Sparse character-bound perceptual prose may support them', 'dialogue-led story delivery with sparse, character-bound perceptual prose')
        'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md' = @('Dialogue-led perceptual communicability')
        'story/04-public-project-profile.md' = @('rare character-bound perception')
        'story/06-seven-day-scene-beatbook.md' = @('audience-visible anchor-bound perception', 'declared anchor')
        'story/07-seven-day-causal-matrix.md' = @('anchor-bound audience evidence')
        'docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md' = @('no narrator identity', 'approved sparse anchor-bound perception')
        'docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md' = @('sparse source-authored anchor-bound perception')
        'docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md' = @('dialogue-led story delivery', 'no narrator identity')
        'docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md' = @('source replay inherits', 'anchor', 'archive adds no narrator')
        'docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md' = @('source-authored anchor-bound perception', 'no narrator identity')
        'docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md' = @('source ending', 'perceptual anchor', 'no narrator identity')
    }
    foreach ($path in $required.Keys) {
        $text = Read-Normalized $path
        foreach ($phrase in $required[$path]) { Assert-Contains $text $phrase "Required authority $path" }
    }
    Write-Output 'PERCEPTUAL_AUTHORITY: PASS'

    foreach ($phrase in @(
        'An Angela-attended solo or group scene',
        'authorized audience-visible Priscilla–Lavinia surface',
        'An unowned past fragment has no character-bound prose',
        'Gallery and Rehearsal replay inherit',
        'When no eligible character is conscious and perceiving',
        'The active anchor remains stable through a continuous passage',
        'A private-offscreen event supplies no prose',
        'Missing, unseen, or unreceived evidence proves only',
        'not required to restate every visual fact for TTS'
    )) { Assert-Contains $bible $phrase 'Bible anchor law' }
    Write-Output 'ANCHOR_AND_EPISTEMIC_LAW: PASS'

    foreach ($phrase in @('Observer Pressure may amplify', 'Angela–Priscilla', 'Angela–Lavinia', 'Angela–Sylvia', 'Recognition is not classification', 'Date is production shorthand', 'Group remains', 'Incidental Cast Economy', 'Character Agency and Author Greed')) {
        Assert-Contains $bible $phrase 'Bible reusable canon'
    }
    foreach ($phrase in @('Friend', 'Angela–Lavinia', 'eligible anchor', 'character-faithfulness', 'lawful knowledge')) {
        Assert-Contains $handbook $phrase 'Handbook derivation'
    }
    Write-Output 'REUSABLE_CANON_PACKAGE: PASS'
}

$catalogueBegin = '<!-- BEGIN NONCANONICAL AUDITION-HISTORY CATALOGUE -->'
$catalogueEnd = '<!-- END NONCANONICAL AUDITION-HISTORY CATALOGUE -->'
$activeBible = Strip-MarkedBlock $bible $catalogueBegin $catalogueEnd
$candidateSurface = [string]::Join("`n", @(
    $activeBible,
    $handbook,
    (Read-Normalized 'story/04-public-project-profile.md'),
    (Read-Normalized 'story/07-seven-day-causal-matrix.md'),
    (Read-Normalized 'docs/design/2026-08-07-seven-day-dialogic-flow-design.md'),
    (Read-Normalized 'docs/superpowers/specs/2026-08-28-seven-day-two-pass-constellation-design.md')
))
Assert-True (-not [regex]::IsMatch($candidateSurface, 'The Bright Point|Behind glass|Literal,\s*Absurd,\s*Evidential|proofing[- ]room|permission to see|attachment[- ]card|\[photo\]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'A scene candidate leaked into active global canon.'
Assert-NotContains $bible 'The chair was comfortable. This was not a useful answer.' 'Bible example boundary'
Assert-NotContains $handbook 'The chair was comfortable. This was not a useful answer.' 'Handbook example boundary'
Write-Output 'CANDIDATE_EXCLUSION: PASS'

Assert-Contains $bible '### Day 2 — Ordinary Return, Not a Separate Anchor' 'Bible Day 2'
Assert-Contains $bible 'Day 2 adds no dedicated message pair, timing' 'Bible Day 2'
Assert-Contains (Read-Normalized 'story/07-seven-day-causal-matrix.md') 'Day 2 contains no dedicated contact pair or timing anomaly' 'Matrix Day 2'
Assert-True (-not [regex]::IsMatch($activeBible, 'Lavinia is back|unsent-message anomaly|premature reply|Priscilla.s concealed knowledge', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'Retired Day 2 pre-echo survives in active Bible canon.'
Write-Output 'DAY2_RETIREMENT: PASS'

$matrix = Read-Normalized 'story/07-seven-day-causal-matrix.md'
$encounters = @([regex]::Matches($matrix, '(?m)^\| `(?<id>(?:solo\.(?:priscilla|lavinia|sylvia)\.day_[1-6]|pair\.priscilla_lavinia\.day_[26]))` \|[^\r\n]*\| UNSELECTED \|$'))
Assert-True ($encounters.Count -eq 14) 'Encounter registry is not fourteen all-UNSELECTED rows.'
$ids = @($encounters | ForEach-Object { $_.Groups['id'].Value })
Assert-True (@($ids | Where-Object { $_ -like 'solo.*' }).Count -eq 12 -and @($ids | Where-Object { $_ -like 'pair.*' }).Count -eq 2) 'Encounter split is not twelve plus two.'
$messages = @([regex]::Matches($matrix, '(?m)^\| `contact\.ordinary\.(?:priscilla|lavinia|sylvia)\.day[1-6]` \|[^\r\n]+$'))
Assert-True ($messages.Count -eq 6) 'Ordinary-message registry is not six rows.'
$freezeStart = $matrix.IndexOf('| Axis | Freeze evidence and staged verdict |', [StringComparison]::Ordinal)
$freezeStop = $matrix.IndexOf('### Protected-Anchor and Fixed-Continuity Carrier Audit', $freezeStart, [StringComparison]::Ordinal)
Assert-True ($freezeStart -ge 0 -and $freezeStop -gt $freezeStart) 'Freeze evidence table is missing.'
$freezeRows = @([regex]::Matches($matrix.Substring($freezeStart, $freezeStop - $freezeStart), '(?m)^\| (?!Axis |---)(?<axis>[^|\r\n]+) \|[^\r\n]+\|$'))
Assert-True ($freezeRows.Count -eq 17) 'Freeze evidence is not seventeen axes.'
$placedBegin = '<!-- BEGIN APPROVED PLACED PREMISES -->'
$placedEnd = '<!-- END APPROVED PLACED PREMISES -->'
$placedStart = $matrix.IndexOf($placedBegin, [StringComparison]::Ordinal)
$placedStop = $matrix.IndexOf($placedEnd, $placedStart + $placedBegin.Length, [StringComparison]::Ordinal)
Assert-True ($placedStart -ge 0 -and $placedStop -gt $placedStart -and $matrix.Substring($placedStart + $placedBegin.Length, $placedStop - ($placedStart + $placedBegin.Length)).Trim() -ceq 'None.') 'Approved placed-premise block changed.'
Assert-True ([regex]::Matches($matrix, 'Room 2\.17 — APPROVED CAUSAL CORE — PLACEMENT UNSELECTED').Count -eq 1) 'Room 2.17 placement status changed.'
Write-Output 'FROZEN_REGISTRIES: PASS'

$repositoryRoot = (Resolve-Path -LiteralPath '.').Path.TrimEnd('\', '/')
$linkFailures = [Collections.Generic.List[string]]::new()
$linkCount = 0
foreach ($file in $allChangedPaths) {
    & git ls-files --error-unmatch -- $file *> $null
    Assert-True ($LASTEXITCODE -eq 0) "Required tracked file missing: $file"
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $file -Raw), '\[[^\]]+\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target.StartsWith('<') -and $target.EndsWith('>')) { $target = $target.Substring(1, $target.Length - 2) }
        if ($target -match '^(?:https?://|mailto:|res://|#)') { continue }
        $target = ($target -split '#', 2)[0]
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        $linkCount++
        $decoded = [Uri]::UnescapeDataString($target)
        $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $file)) $decoded))
        $inside = $resolved.Equals($repositoryRoot, [StringComparison]::OrdinalIgnoreCase) -or $resolved.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        if (-not $inside -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) { $linkFailures.Add("$file -> $target"); continue }
        $relative = $resolved.Substring($repositoryRoot.Length).TrimStart('\', '/').Replace('\', '/')
        & git ls-files --error-unmatch -- $relative *> $null
        if ($LASTEXITCODE -ne 0) { $linkFailures.Add("$file -> untracked $target") }
    }
}
Assert-True ($linkFailures.Count -eq 0) "Broken tracked local links:`n$($linkFailures -join "`n")"
Write-Output "TRACKED_LOCAL_LINKS: PASS ($linkCount)"

$unfinished = @('TO' + 'DO', 'T' + 'BD', 'FIX' + 'ME', 'X' + 'XX', 'INSERT' + ' HERE', 'fill' + ' this', 'to be' + ' decided') -join '|'
& rg -n $unfinished @allChangedPaths *> $null
Assert-True ($LASTEXITCODE -eq 1) 'Unfinished drafting token remains.'
Write-Output 'UNFINISHED_TOKEN_SCAN: PASS'

if ($Phase -eq 'BeforeContent') { Write-Output 'BEFORE_CONTENT_VERIFICATION: PASS' }
else { Write-Output 'FINAL_STATIC_VERIFICATION: PASS' }
```
