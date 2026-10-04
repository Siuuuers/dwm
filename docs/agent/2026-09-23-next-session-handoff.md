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

Continue `Siuuuers/dwm` PR #1 on `codex/windows-cloud-ux`. Keep it draft and
unmerged; do not change master. Read this handoff, the [execution map](execution-map.md),
the selected Bead and its current approved design before editing. Beads owns
status and dependencies; these documents are navigation, not a second backlog.

## Latest atomic History storage prerequisite

The atomic Profile caption-History union prerequisite is accepted at source
`1cce6ff5424c3438e45b311407216a24fb144d59`, tested merge
`7936c4be314e2b2e1b5d95df86a1cb4ca4902409`. [Run 168](https://github.com/Siuuuers/dwm/actions/runs/37236784020)
passed all 26 jobs. Settings XML verifies 368 cases, including 17 caption-witness
cases with seven new atomic-union tests; public XML verifies 11 cases. All have
zero failures/errors/skips. The [receipt](../../evidence/phase_2r/profile_caption_history_union_2026_10_05/receipt.json)
and [review](../../evidence/phase_2r/profile_caption_history_union_2026_10_05/review.md)
own the exact evidence and limits. Reuse `ProfileManager.merge_caption_history()`;
do not rebuild its transaction or introduce another History persistence owner.

The method validates the complete batch before one existing atomic Profile commit,
changes only exact-caption witnesses/base visited-line IDs, and fences even empty
or duplicate calls under stale revision, mutation custody or uncertainty. Its
`history_added` result means a newly durable base-line visit; a new exact variant
of an already visited line does not claim a new-History notice.

Replay does not call this method yet. Next bind an explicitly admitted TEST exact
replay signature and collectable lines to the existing NarrativeCaptionLedger and
visible-caption acknowledgement under Bridge's reached-replay session. Do not
fabricate canonical causal fields or treat publication/registry membership as
actual presentation. Retain session custody through merge failure/uncertainty and
revalidate after synchronous Profile publication before a truthful notice. The
existing strict workflow is restored unchanged. No Bead is closed; all 23
unfinished records remain open, including `dwm-7wj`.

## Latest bounded Gallery register checkpoint

Fixture-backed visible version selection is accepted at source
`097fc17cc0d48889f076f63921e55997a41b8e07`, tested merge
`a74cb4520b3b6e6848e98c3ac89da54cb95b009a`. [Run 166](https://github.com/Siuuuers/dwm/actions/runs/37231841772)
passes 169 ending tests, 154 localization tests and 11 public-contract tests, all
without failures/errors/skips, plus 390 rendered-register checks across 18 tuples.
The UI literal audit passes; final images match the reviewed captures exactly.
The [receipt](../../evidence/phase_2r/gallery_version_register_2026_10_05/receipt.json)
and [review](../../evidence/phase_2r/gallery_version_register_2026_10_05/review.md)
own scope, hashes, diagnostic corrections and limits. Run 166 completed successfully: all 26 jobs passed, including the retained-history producer, four comparisons and aggregate. This supports the bounded register checkpoint; no new performance-improvement or whole Gallery completion claim is made.

GalleryScene remains selection/Retry owner; Paper alone owns record scrolling.
The register reuses existing row input/paint and exact catalogue cues. Selection,
focus, locale refresh and inspection do not write Profile or start playback.
Production cue sets remain absent, so existing picker/Replay access stays intact
for incomplete sets. This is not production cutover, native UIA/ScrollPattern or
whole Gallery acceptance. `dwm-7wj` and all 23 unfinished Beads remain open.

Next integration: collect actually presented, valid session-bound replay lines
and reuse the accepted ProfileManager.merge_caption_history atomic union.
Registry membership alone is not presentation proof. A success notice requires
newly durable additions; duplicate replay stays silent, refusal adds nothing, and
uncertainty retains custody. Reuse Bridge, Profile and GalleryReplayOwner; no new
History store, recovery framework or external-system repair. Production exact
replay admission and authored content remain separate from fixture engineering.

## Previous bounded Gallery catalogue checkpoint

Exact authored version-cue lookup is accepted at source
`ed2161cc3d4e74143c1b8a24840c7b5d2a1ff0e6`, tested merge
`55251ffa3db3f229162bd558d6573b51edee224b`.
[Run 162](https://github.com/Siuuuers/dwm/actions/runs/37226011217) passed the
ending suite (126 cases, including 14 catalogue and 6 Gallery integration cases)
and public-surface suite (11 cases), with no failures/errors/skips.
The [receipt](../../evidence/phase_2r/gallery_version_cue_catalogue_2026_10_05/receipt.json)
and [review](../../evidence/phase_2r/gallery_version_cue_catalogue_2026_10_05/review.md)
record source, artifact hashes and the bounded acceptance. The wider workflow was
still running at this checkpoint; do not infer an all-job or performance seal.

`GalleryRecordCatalog.version_cue()` accepts only exact authored metadata and
keeps missing cues absent. General record projection and production replay are
unchanged. Clearly marked TEST cues prove the lookup contract; production overrides
remain empty. This catalogue-only checkpoint preceded the visible register accepted above.
Production cue authoring remains separate; `dwm-7wj` stays in progress.

## Latest accepted Settings visible-keyboard checkpoint

The bounded Pause → Settings → High Contrast keyboard route is accepted at
source `5959cb7abf30c1cf546e1b0dfa0de372aa7d0b36`, tested merge
`80a7249203beee5106cdc38bf8bc35a2f2d122cd`.
[Run 161](https://github.com/Siuuuers/dwm/actions/runs/37220956097) passed all
26 jobs, including the four retained-history comparisons and their aggregate.
The [receipt](../../evidence/phase_2r/settings_keyboard_navigation_2026_10_05/receipt.json)
and [review](../../evidence/phase_2r/settings_keyboard_navigation_2026_10_05/review.md)
own exact scope, artifact hashes and limits. Final Settings XML verifies 361
cases with zero failures/errors/skips; no new all-suite execution total is claimed.

The existing rendered fixture now uses separate settled key events to reach the
visible checkbox. Every sheet target and its focus perimeter fits inside the
viewport; Profile contents/revision, durable bytes and 45 FileOps are unchanged
by navigation. The three PNGs were independently reviewed through the diagnostic
and final-run byte identity. Uncertainty/repeated-refusal retain identical images
and 64 FileOps. This closes the previous pre-action visible-target evidence gap
for English 100% AfterHours Standard, using Viewport key events rather than native
OS keyboard/UIA. It does not establish a runtime defect or full accessibility.

No runtime, save, recovery or History owner changed. Net implementation changes
are the existing fixture and three cloud-generated inventory caller coordinates.
The complete strict workflow is restored byte-for-byte. Run157's failure-handling
receipt remains unchanged. This records-only publication is not independently
engine-tested; `dwm-eei.2` remains open and all 23 unfinished records remain so.

## Accepted Settings write-failure checkpoint

The bounded field under `dwm-eei.2` is complete at source
`07492163071a6dbe24d881b7c7fe17f7a3236be7`, tested merge
`635e833cb345fa12089f0a3b795ef0d49dd5e6aa`.
[Run 157](https://github.com/Siuuuers/dwm/actions/runs/37215097884) supplies the
cloud evidence; all 26 jobs passed. The [receipt](../../evidence/phase_2r/settings_write_failure_2026_10_04/receipt.json) and
[review](../../evidence/phase_2r/settings_write_failure_2026_10_04/review.md) own exact results and limits.
Thirteen downloaded primary XML reports verify 2,606 executions, 2,602 unique
cases, and zero failures, errors or skipped cases; four deliberate duplicates
remain. Negative storage-refusal controls are counted separately.

Shared Settings now reports Profile write uncertainty and retains custody;
both Title and Desktop/Pause wrappers refuse closing. Proven uncommitted failure
retains/restores the prior value and admits a fresh action. Immediate admission
blocking precedes deferred presentation cleanup, preserving existing output
compensation. Profile/storage/output transaction owners and save/History formats
are unchanged. There is no new live Retry/unlatch, external repair or forced restart.

Three rendered English 100% AfterHours captures were visually inspected. The
uncertainty and repeated-refusal images are byte-identical, readable and contain
no Retry/Cancel. FileOps remain at 64 after repeated keys/departure requests.
The pre-action image does not show its offscreen focused checkbox; this is
bounded foreground-failure evidence, not visible-target navigation or OS UIA
acceptance. Broader rendered jobs retain their existing gates, without a new
visual review of all captures.

This publication updates evidence/navigation and the selected retained Bead only.
It is not an independent engine pass for the records-only descendant. The complete
strict workflow is restored, with no diagnostic exclusions.

## Prior accepted native reading checkpoint

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

**Do not redo the accepted bounded Settings failure or visible-keyboard fields.**
`dwm-eei.2` stays open: remaining authored sample, native speech/display and
broader preview clauses are separate. Select one demonstrated remaining outcome
from the Bead and accepted evidence before another implementation; no new
architecture choice is implied by this checkpoint.

Recommended next bounded implementation: `dwm-7wj`, the already approved visible
plural witnessed-version register, preserving existing newest-first chronology,
exact selection/Retry and write-free inspection. Use the active August 24 Gallery
Standard; `docs/design/current-ui/gallery.md` has not cut over. Noncanonical
fixture cues may prove engineering; production exact-version cues remain an
authored-input gate. Do not reopen the existing replay or chronology owners.

Apply the [owner-approved software responsibility boundary](../design/2026-10-04-software-responsibility-boundary.md).
Preserve canonical mutation/recovery fences and truthful save reporting. Reuse
accepted paused F5/F9, Save/Load, History and reading evidence. Do not add live
reconciliation or force restarts to satisfy superseded recovery wording.

The [records reconciliation](../../evidence/beads_reconciliation_2026_10_04/review.json)
covers all **23 unfinished records** in the complete **191-record committed
export**. The Git blob route recovered the 2,032,918-byte source export after the
contents route returned empty; that earlier limitation is resolved. Historical
notes, closed records and all dependency edges are preserved. No Bead is closed
or retired as complete: obsolete current wording/requirements are reconciled with
later approved decisions instead. That reconciliation moved `dwm-eei.2` from
deferred to open; it remains open after this bounded field. `dwm-n3h.2`, `dwm-hsi`
and `dwm-eei.17` became deferred with explicit authored-input or recurrence resume conditions. They remain unfinished.

The `bd` CLI is unavailable in this environment. These are retained-export
updates, not live Dolt queries or synchronization. Before a later live import,
compare live records against this revision; do not overwrite newer work. The
Beads records own scope/status; the execution map and this handoff remain navigation.

Reading remainder stays under `dwm-vky.14` with linked `dwm-eei.10/.11/.5`
clauses. Do not redo accepted native review-current, History, Save/Load, paused
Settings Quick, ending continuity or geometry work. Broader native navigation,
speech, arbitrary partial reveal and production replay retain separate evidence
gates. The bounded Settings write-failure field is now accepted. Gallery/latency and
other existing remaining clauses stay available for a separately selected outcome.

The earlier reconciliation session changed records only and performed structural
validation, not a new engine acceptance run. Two independent read-only audits informed the reconciliation.
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
owners, publication and Beads. This Settings continuation received independent
source/caller/test/inventory review, plus independent XML, capture and
record-consistency review. Finish compatible source audits before
the final stable gate.

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
