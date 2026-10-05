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

# Current handoff: 5 October 2026

Continue `Siuuuers/dwm` PR #1 on `codex/windows-cloud-ux`. Keep PR #1 draft and
unmerged; do not change master. Read this handoff, the [execution map](execution-map.md),
the selected Bead and its approved design before editing. Beads owns status and
dependencies; approved design owns behavior. These documents are navigation,
not a second backlog or an acceptance receipt.

## Current accepted implementation and next outcome

The accepted implementation remains `04ca9baf44e5a93183abd490d473615a33b81630`.
[Run 171](https://github.com/Siuuuers/dwm/actions/runs/37242534975), attempt 1,
completed successfully, with all 26 jobs passing. Its actual tested PR merge is
`d923dafe0cc100818e4d63475019adb28c6ada86`, with actual master parent
`dded76aee2e85aeea94f65218de043b1f4fdce7b`. Use the actual master ref rather
than the normalized PR-base metadata. Recheck both live refs before new work.

The [bounded collection review](https://github.com/Siuuuers/dwm/pull/1#issuecomment-5985720209)
and [completion/scope record](https://github.com/Siuuuers/dwm/pull/1#issuecomment-5988614205)
own the evidence and its limits. They retain 644 reading-delivery cases including
11 collection cases, 169 ending cases and 11 public-surface cases, with zero
failures/errors/skips in those selected reports, plus 42 rendered collection
checks and three inspected captures. This navigation reuses those records; it
is not a fresh all-suite census, visual audit, performance result or engine pass.
Run 170 remains a separate diagnostic: the new rendered command lacked the
explicit `-- --phase2r-bootstrap-mode=final` used with isolated test roots.
Run 171 corrected that argument without weakening game code or assertions.

**Do not rebuild the visible version register, atomic Profile union or temporary
caption collection.** Exact fixture admission and actually-presented,
session-bound eligible collection are implemented. Publication, registry
membership or a detached query alone does not establish presentation. Run 171
still discards that temporary collection on exit; it does not implement durable
exit merging or the player-facing History notice.

The next bounded outcome under `dwm-7wj` is: leaving an admitted ending replay
commits eligible, actually-presented captions through the existing
`ProfileManager.merge_caption_history()` operation, and announces additions
only when new base-line History visits are durably confirmed. Retain exact
session custody through refusal/uncertainty and recheck it after synchronous
Profile publication. A new exact variant of an already visited base line does
not count as a newly added base History line. Duplicate-only replay stays silent.
Reuse Bridge, GalleryReplayOwner and Profile; do not add another store or recovery
owner. Inspect natural completion, explicit close and failure separately.

The current Gallery close path clears its status and hides the view. Follow the
approved notice/host lifetime before selecting a presentation seam; setting a
status immediately before hiding is not visible-notice proof. Preserve no-write
assertions during replay and unrelated-state checks. Evolve only the deliberate
exit expectations when durable merging is introduced, with stronger durability
and refusal checks, not removed coverage.

## Parallel continuation

The [first-wave allocation](execution-map.md#first-wave-allocation) names three
worker branches and their initial file boundaries. A gets one bounded core
implementation; B and D begin read-only. C waits for a concrete disjoint outcome.
These allocations do not mean workers have launched or Beads changed status.
The coordinator publishes the exact common records-only launch commit in PR #1;
workers start from that commit, not an assumed moving head. The launch commit
contains this navigation refresh but has no independent engine acceptance.

Workers never push to master or the integration branch, merge their own PRs,
change PR #1's draft/base state, or edit outside their allocation. Child PRs target
`codex/windows-cloud-ux`. One coordinator handles shared files, inventories,
workflow, aggregate evidence and Beads. One session per branch; another session
must take an explicit handoff rather than silently sharing it. Check live refs
and existing work before acting; never reset a branch to this historical anchor.

## Accepted prerequisites to reuse

| Bounded field | Source-bound record and remaining limits |
|---|---|
| Atomic Profile caption-History union, Run 168 | [Receipt](../../evidence/phase_2r/profile_caption_history_union_2026_10_05/receipt.json) and [review](../../evidence/phase_2r/profile_caption_history_union_2026_10_05/review.md). Source `1cce6ff5424c3438e45b311407216a24fb144d59`; all 26 jobs passed. Complete batch validation, one existing atomic commit, revision/custody/uncertainty fences even for no-op calls. `history_added` means newly durable base visits. |
| Visible witnessed-version register, Run 166 | [Receipt](../../evidence/phase_2r/gallery_version_register_2026_10_05/receipt.json). Source `097fc17cc0d48889f076f63921e55997a41b8e07`; all 26 jobs passed. Fixture-backed register, chronology/selection/Retry and write-free inspection. Production cues/cutover, native ScrollPattern and whole Gallery acceptance remain separate. |
| Exact cue catalogue prerequisite, Run 162 | [Receipt](../../evidence/phase_2r/gallery_version_cue_catalogue_2026_10_05/receipt.json). Exact-only TEST cue lookup preceded Run 166; missing production cues remain absent. Its original bounded record is not a later all-job seal. |
| Visible Settings keyboard route, Run 161 | [Receipt](../../evidence/phase_2r/settings_keyboard_navigation_2026_10_05/receipt.json). Source `5959cb7abf30c1cf546e1b0dfa0de372aa7d0b36`; all 26 jobs passed. English 100% AfterHours, Viewport key input and in-memory FileOps, not native OS/UIA or whole Settings acceptance. |
| Truthful Settings write failure, Run 157 | [Receipt](../../evidence/phase_2r/settings_write_failure_2026_10_04/receipt.json). Source `07492163071a6dbe24d881b7c7fe17f7a3236be7`; all 26 jobs passed. Shared uncertainty presentation/custody and both host close refusals; proven uncommitted failure permits a fresh action. No new live Retry/unlatch or forced restart. |
| Native review-current return, Run 152 | [Receipt](../../evidence/phase_2r/caption_native_review_2026_10_04/receipt.json). Source `845ec12c83cecfab1bfe3b5b4a194537c783aa7e`; all 26 jobs passed. Nine UIA invocations, unchanged return snapshot at zero visible characters. Review entry was fixture setup; arbitrary partial reveal, full native navigation/speech and production routes remain separate. Signal counts are not gameplay consequence counts. |

The [immutable pre-refresh handoff](https://github.com/Siuuuers/dwm/blob/04ca9baf44e5a93183abd490d473615a33b81630/docs/agent/2026-09-23-next-session-handoff.md)
retains full historical counts, negative controls, hashes, diagnostic limits and
older receipt links. Its old "next" directions are historical, not today's queue.
No receipt is rewritten or resealed by this compact navigation refresh.

## Scope and owner decisions

The active [August 24 Gallery Standard](../design/2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md)
retains current Endings-only Gallery; `docs/design/current-ui/gallery.md` has not
cut over. Ending Replay is not future Rehearsal. Scenes, Full Dates, sandbox
behavior and anticipatory Rehearsal UI/runtime/test scaffolding remain excluded.
Production catalogue registration, prose, exact replay inputs and exhaustive
variants stay deferred. TEST engineering is not production-content admission.
Existing names alone do not authorize deleting shared Practice or replay code.

Apply the [software responsibility boundary](../design/2026-10-04-software-responsibility-boundary.md):
fulfill promised software behavior, report failure truthfully and retain data
protections. No external-system repair, elaborate live reconciliation or forced
automatic restart is required. Later owner decisions supersede old recovery wording.

All fainting uses shared Hospital DTL and ordinary Dating-style captions, without
a challenge, special Continue button or automatic no-Sylvia completion. Final
ordinary advance completes presentation. Fainting still prevents an accepted
Sylvia solo appointment that day; her absence changes art/content, not playback
ownership. Hospital manual Save/Load/Next, including paused F5/F9 through Settings,
remain disabled. Preserve independent History, global autosave timing and internal
completion/recovery. Test-only fixtures do not authorize player Hospital saving.
The [Hospital disposition](../design/2026-08-22-hospital-ordered-ending-current-v1-ui-disposition.md#owner-correction--3-october-2026-hospital-manual-saveload)
retains this correction. Shared Hospital placeholders and the 16 post-challenge
DTLs use committed frozen results, not predicted outcomes or invented exact prose.

Preserve movie-style centered outlined captions over visible artwork, without
caption panels, seams or focus rectangles. The [movie-caption correction](../design/2026-10-04-movie-caption-correction.md)
supersedes old opaque materials. Preserve requested fonts and accepted fixed
64px reading-rail allocations; do not redo the Chinese geometry diagnosis.

## Save, recovery and reading guarantees

The [unshipped development-save policy](../design/2026-09-29-unshipped-development-save-policy.md)
permits retiring obsolete formats with explicit admission boundaries, never weaker
correctness for supported formats. One semantic ledger owns captions and History.
Membership uses the full registered variant and pre-publication baseline; a witness
recorded now does not make the same unseen activation retrospectively traversable.
Run/attempt/publication IDs establish custody, not wording.

One History spans a date; Hospital starts fresh; ordered endings retain continuity.
Ordinary Next retains witnessed traversed captions; Hospital/ending History admits
actual publications only. Auto preserves manual terminal boundaries. Ordinary
board handoff is automatic, without Continue/Done or special mines. Save completes
only the current reveal; fresh Load restores the exact semantic point silently,
without repeated speech or consequences. Inspection grants no credit.

Plain Pause, Return Cancel and Backup preview preserve partial reveal. Admitted
Backup entry or Save completes only the current line. Replay uses recorded facts;
missing exact replay remains unavailable. Preserve full Git ancestry, strict
revisions/bytes/hashes, consent, chronology, complete-action recovery, unrelated
slots and Profile History. Whole-entry reached signatures and individual caption
variants remain distinct. Keep `attempt_residue_id` null; do not promote legacy
`special_mine_phase` or `promotion_result` into selector authority.

## Working method and cloud verification

State one observable outcome, canonical owner, concrete failure cases and success
evidence before editing. Prefer the smallest coherent change. Inspect actual
callers, current approved behavior and saved-data obligations before deletion.
Use unit tests for isolated rules, integration for cooperating owners/storage and
rendered E2E for connected presentation. A script's existence is not execution.
Finish compatible caller/test-body reviews before final acceptance. Claim agents
or independent reviews only when they actually ran.

Godot 4.6.3 standard GDScript and PowerShell run only in GitHub Actions. Start with
affected suites using existing cloud entry points; retain the strict workflow,
public inventories and UI literal audit. Stabilize the candidate before required
broad acceptance. Preserve deliberate duplicate test executions and separate
negative controls. Records-only work gets structural review, not a relabeled
engine pass. The [execution map](execution-map.md#cloud-verification) retains the
final eight UI fixture records and retained-History fanout obligations.

Measure complete operations with matched baselines and separate cold/warm modes
before performance surgery. Use ablation to answer a concrete causal question;
shorter code and historical elapsed times alone are not speedup evidence.

Inspect original PNG bytes and identities before diagnosing visuals. Containment
does not establish readable glyphs; minimum-size queries may shape text. Check
fixture meaning before runtime changes. Use neutral frames after semantic or
foreground changes before fresh input. Never retry native activation merely
because observation timed out.

Keep typed malformed-version checks and strict JSON provider validation; normalize
runtime StringName IDs at primitive boundaries. Natural Return retires caption
layout before settlement: surviving Bridge owns completion, departed views publish
nothing and async fixtures retain weak references. Before cold Load read leases,
inspect revisions with `inspect_revision`, not `read_text`. Distinguish setup
timeouts from import and test failures. Linux software rendering or Windows
headless startup proves neither native graphics nor input-to-paint/accessibility.
FileOps faults are not OS-crash tests; entry recovery does not prove a board played.

## Task accounting and historical routes

The committed [reconciliation](../../evidence/beads_reconciliation_2026_10_04/review.json)
records 191 total Beads and 23 unfinished records. This refresh does not recount
live Dolt, alter statuses/dependencies, close a Bead or synchronize the export.
All unfinished IDs remain represented in the map, including deferred clauses.
Compare live records before any later import; never overwrite newer live work.

`Prompt.md`, `CLAUDE.md` and `docs/agent/AGENT_WORKFLOW.md` were retired on
2 October. Master's `AGENTS.md` still links to the retired CLAUDE route; correct
that only when master integration is separately authorized, preserving story
routes. Do not change master or story in this continuation.
