---
schema_version: 1
document_id: dwm_current_handoff
document_role: navigation_only
execution_authority: false
status_authority: false
behavior_authority: false
verification_authority: false
execution_map: "docs/agent/execution-map.md"
issue_authority: beads
---

# Current handoff: 4 October 2026

Continue `Siuuuers/dwm` PR #1 on `codex/windows-cloud-ux`. Keep it draft and
unmerged; do not change master. Read this handoff, the [execution map](execution-map.md),
the selected Bead and its current approved design before editing. Beads owns
status and dependencies; these documents are navigation, not a second backlog.

## Accepted checkpoint and evidence

**Accepted bounded native Windows review-current return-to-live proof.**
Source `845ec12c83cecfab1bfe3b5b4a194537c783aa7e`; actual tested PR merge
`bd4a3806769954663c46aed1064a076a0276865e`, whose master parent is
`dded76aee2e85aeea94f65218de043b1f4fdce7b`.
[Run 152](https://github.com/Siuuuers/dwm/actions/runs/37190011572), attempt 1,
completed successfully. All 26 jobs passed. The downloaded 13 primary XML
reports contain 2,602 executions, 2,598 unique classname/name pairs and no
failures, errors or skipped test cases. Four deliberate duplicate executions
remain. The two storage-refusal controls have expected failures and are counted
separately. Conditional skipped setup steps are not skipped primary test cases.

The [receipt](../../evidence/phase_2r/caption_native_review_2026_10_04/receipt.json)
and [review](../../evidence/phase_2r/caption_native_review_2026_10_04/review.md)
own exact artifact hashes, observations, retention and limits. Nine actual
Windows UIA invocations build three previous captions, return from review without
revealing or advancing, then independently reveal and advance once. Before and
after return, event index 3, visible characters 0, reveal generation 7, both
native History snapshots and Text.text_finished count 3 are unchanged. The final
guard caption is still revealing. Four native PNGs were visually inspected.

This is an English mounted synthetic fixture with elapsed-time reveal disabled.
The observed partial position is zero visible characters, not mid-sentence.
Review entry is fixture setup; exit is native UIA. Text-finished and timeline-ended
signals are not gameplay consequence counters. Full screen-reader navigation,
speech and authored production-route acceptance remain separate. Other broad
rendered jobs were checked through successful job/step metadata, not a new visual
review of all their captures. No runtime file changed in the accepted source.

This publication changes records only. It does not inherit an independent engine
pass for the records-only descendant and does not require another benchmark run.
Master was checked through its actual ref, not normalized PR-base metadata.

## Next work and task accounting

**Next field: minimal truthful Settings failure handling under `dwm-eei.2`.**
Apply the [owner-approved software responsibility boundary](../design/2026-10-04-software-responsibility-boundary.md).
We own correct software behavior and truthful failure reporting, not hardware
diagnosis, external-system repair or guaranteed recovery from every external fault.
Do not force an automatic restart or add live recovery as a new requirement.
Preserve existing save/recovery/History guarantees and canonical mutation fences.

Observable outcome: an ordinary supported Settings change applies and saves
correctly. A proven uncommitted change retains/restores the previous value and
reports failure. An uncertain write reports uncertainty and refuses conflicting
actions rather than assuming a winner. A message alone does not prove settlement.
Reuse existing reconciliation; do not create a new live Retry/unlatch architecture.

The read-only source/host audit at `fb4d10f` found a reachable storage result:
new Profile bytes can win while transaction-marker cleanup still fails.
ProfileManager blocks its own mutations and emits `profile_write_failed`;
Title/Desktop/Pause Settings lack a corresponding failure subscription.
Profile has no general live reconciliation API; initialize is single-use and the
application fatal gate is intentionally irreversible. The existing witnessed
recovery widget provides a presentation-only no-Retry mode, not reconciliation.
These are static findings, not executed acceptance or a chosen implementation.

Next inspect the smallest shared presentation/custody connection needed to fulfill
the narrowed promise. Preserve ProfileManager and SettingsOutputTransactions
ownership. Verify reachable determinate/uncertain result handling and relevant
repeated input/departure/output behavior; do not expand into external repair or
a new broad fault-injection campaign. Use affected owner tests and a foreground
journey in cloud Godot/PowerShell. Reuse accepted paused F5/F9 evidence.
This bounded field does not close all Settings preview, native speech/display
or authored sample obligations.

The [records reconciliation](../../evidence/beads_reconciliation_2026_10_04/review.json)
covers all **23 unfinished records** in the complete **191-record committed
export**. The Git blob route recovered the 2,032,918-byte source export after the
contents route returned empty; that earlier limitation is resolved. Historical
notes, closed records and all dependency edges are preserved. No Bead is closed
or retired as complete: obsolete current wording/requirements are reconciled with
later approved decisions instead. `dwm-eei.2` moves deferred -> open for the next
session; `dwm-n3h.2`, `dwm-hsi` and `dwm-eei.17` become deferred with explicit
authored-input or recurrence resume conditions. They remain unfinished.

The `bd` CLI is unavailable in this environment. These are retained-export
updates, not live Dolt queries or synchronization. Before a later live import,
compare live records against this revision; do not overwrite newer work. The
Beads records own scope/status; the execution map and this handoff remain navigation.

Reading remainder stays under `dwm-vky.14` with linked `dwm-eei.10/.11/.5`
clauses. Do not redo accepted native review-current, History, Save/Load, paused
Settings Quick, ending continuity or geometry work. Broader native navigation,
speech, arbitrary partial reveal and production replay retain separate evidence
gates. Settings is selected next because its recovery field is independent of
deferred production content; Gallery/latency remain available later.

This session changes records only and performs structural validation, not a new
engine acceptance run. Two independent read-only audits informed the reconciliation.
The later source audit exposed the absence of general live Profile recovery.
The owner's subsequent scope clarification above excludes adding elaborate live
recovery or forcing an automatic restart. Ask only if a remaining implementation
choice would change that narrowed player-facing promise.

## Current owner decisions

- The [software responsibility boundary](../design/2026-10-04-software-responsibility-boundary.md)
  applies to future work: fulfill promised software behavior, report failures
  truthfully, retain existing data protections, and exclude external repair.

- All fainting uses the shared Hospital DTL and ordinary Dating-style captions,
  without a challenge, special Continue button or automatic no-Sylvia completion.
  Final ordinary advance completes the presentation. Fainting still prevents an
  accepted Sylvia solo appointment that day; her absence changes art/content,
  not the playback owner. The old timed-hold proof remains infrastructure only.
- Hospital manual Save/Load/Next, including F5/F9 through Pause and Settings,
  remain disabled. Preserve independent History, global autosave timing and
  internal completion/recovery. Test-only saved fixtures do not authorize player
  Hospital saving. See the [Hospital disposition](../design/2026-08-22-hospital-ordered-ending-current-v1-ui-disposition.md#owner-correction--3-october-2026-hospital-manual-saveload).
- Minimal playable functions come first. Production catalogue registration stays
  disabled; production prose and comprehensive exact authored variants are
  deferred. The shared Hospital DTL has placeholder captions and frozen Sylvia
  selection; the 16 post-challenge DTLs dispatch already committed frozen results.
  Do not predict outcomes or treat label scaffolding as exact production replay.
- Preserve movie-style centered outlined captions over visible artwork, without
  caption panels, seams or focus rectangles. The [movie-caption correction](../design/2026-10-04-movie-caption-correction.md)
  supersedes older opaque-material instructions. The accepted Chinese rail fix
  preserves requested fonts and fixed 64px allocations; do not redo that diagnosis.

## Preserve these guarantees

The game is unshipped. The [development-save policy](../design/2026-09-29-unshipped-development-save-policy.md)
permits retiring obsolete formats with an explicit admission boundary, not
weakening correctness for supported formats. One semantic ledger owns captions
and History. Profile membership uses the full registered variant and the
pre-publication baseline; a witness recorded now does not make that same unseen
activation traversable. Run/attempt/publication IDs establish custody, not wording.

One History spans a date; Hospital starts fresh; ordered endings retain continuity.
Ordinary Next retains witnessed traversed captions, while Hospital/ending History
admits actual publications only. Auto retains manual terminal boundaries. Ordinary
board handoff is automatic, without Continue/Done or special mines. Save completes
only the current reveal; fresh Load restores the exact semantic point silently,
without repeated speech or consequences. Inspection grants no credit.

Plain Pause, Return Cancel and Backup preview preserve partial reveal. Admitted
Backup entry or Save completes only the current line. Gallery replay uses recorded
facts; missing exact replay remains unavailable. Preserve full Git ancestry,
strict revisions/bytes/hashes, consent, chronology, complete-action recovery,
unrelated slots and Profile history. Whole-entry reached signatures and individual
caption variants remain distinct. Keep `attempt_residue_id` null; do not promote
legacy `special_mine_phase` or `promotion_result` into selector authority.

## Working method and verification

Define one observable outcome, its existing owner, concrete failure cases and
success evidence. Prefer the smallest coherent change. Inspect callers, approved
behavior and saved-data obligations before deletion; a stale name is not proof of
obsolescence. Use unit tests for pure rules, integration for ownership/storage,
and rendered E2E for connected presentation. A script's existence is not execution.

Measure a reproducible complete operation before performance surgery. Use matched
baselines, separate cache modes and an ablation only to answer a specific causal
question. Parallelize disjoint work when available; keep one integrator for shared
owners, publication and Beads. No independent subagent review occurred in this
acceptance continuation. Finish compatible audits before the final stable gate.

Run **Godot 4.6.3 standard GDScript and PowerShell only in GitHub Actions**. Start
with affected suites, register new fixtures, include the UI literal audit for UI
changes, adopt reviewed generated inventories after stabilization, then run the
required broad gate once. Stop optional testing after acceptance. Records-only
changes get structural review, not a relabeled engine pass.

Inspect original PNG bytes and receipt identities before diagnosing visual defects.
Geometry containment does not prove readable glyphs; minimum-size queries may
shape text. Check fixture meaning before changing runtime. Input transport needs
neutral frames after semantic/foreground changes before a fresh action. Never
retry a native activation simply because observation timed out.

Keep typed malformed-version checks and strict JSON provider validation; normalize
runtime StringName IDs at primitive boundaries. Natural Return retires the caption
layout before settlement: the surviving Bridge owns completion, departed views
publish nothing, and async fixtures retain weak references. Before a cold Load
read lease, inspect revisions with `inspect_revision`, not `read_text`. Separate
setup timeouts from import and test failures.

Linux software rendering and Windows headless startup do not establish native
Windows graphics, accessibility or input-to-paint acceptance. FileOps faults do
not establish an OS-crash test; entry recovery does not imply a board was played.

## Historical evidence and retired guidance

Prior receipts remain unchanged: [rail geometry / Run151](../../evidence/phase_2r/rail_geometry_2026_10_04/receipt.json),
[movie captions / Run149](../../evidence/phase_2r/movie_caption_2026_10_04/receipt.json),
[native live caption / Run145](../../evidence/phase_2r/caption_native_2026_10_04/receipt.json),
and [assistive callbacks](../../evidence/phase_2r/caption_assistive_2026_10_04/receipt.json).
The complete earlier chronology, exact source identities and further receipt links
remain in the [immutable pre-publication handoff](https://github.com/Siuuuers/dwm/blob/845ec12c83cecfab1bfe3b5b4a194537c783aa7e/docs/agent/2026-09-23-next-session-handoff.md).
Its historical "next" directions are not today's queue. This shorter navigation
replaces repeated narratives, not their evidence or unfulfilled acceptance clauses.

`Prompt.md`, `CLAUDE.md` and `docs/agent/AGENT_WORKFLOW.md` were retired on
2 October; they are not current startup authority. Their originals remain at
`96f95c67db6c7358b5f846651fef5c88babfbf92`. Master's newer `AGENTS.md` still links
to `CLAUDE.md`; correct that technical route only when integration is separately
authorized, preserving its story routes. Do not modify master/story here.
