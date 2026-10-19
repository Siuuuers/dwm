# Reading-anchor algorithm candidate — prepared, not executed

Director [6273617462](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6273617462) assigns one algorithmic target after external C [6273570515](https://github.com/Siuuuers/dwm/pull/36#issuecomment-6273570515) closed the cost/authority review. This packet does not reopen cached-success reuse.

**Observable outcome:** the existing complete scene5 anchor validator returns the same complete result and first refusal on identical input, while avoiding a full restored-ledger copy and caption scan solely to establish one publication's membership. Independent authentication and full restore remain mandatory. Performance improvement is unmeasured.

## Exact isolated source

- Base/current product: `8f59bcc76894bef8856dd2f7c62ca99b50f8c8f7`.
- Candidate: [`08dd31c37375d72214157f53eaa1c38f4eae762b`](https://github.com/Siuuuers/dwm/commit/08dd31c37375d72214157f53eaa1c38f4eae762b), tree `ae8f26b6411d36fcb483a6555ba6e37e034d5141`.
- Branch: `codex/a-scene-anchor-index-20261019`. Six changed/added files; only two runtime files. PR36 receives this packet/restart only, not candidate runtime.
- Bridge blob `fdf0be768ff7172d754ecc8a688089b1a2965420`; ledger `710c0437bee72da1bb7746949a5d668ab70cdf0d`.
- Differential test `9a814ed25abe072fa30f84edab14781a5d530891`; exact-original oracle `99e998cd7a856ac23a0411919283f5361a9357ab`; fixture `52b04d5b40256f8f55e7af5648b6a430a80025ad`; benchmark `257a3e5167d9b99489efba5c900cc4c6105407b0`.

All six published files were read back and exactly matched prepared content. `runtime.patch` is the complete two-file runtime delta. The oracle's method body was compared byte-for-byte with the original product function. Local work was Python/source inspection only; no Godot/PowerShell execution, compiler pass, test pass or speedup is claimed.

## Existing path and minimal change

GameState.validate_scene_snapshot_semantics authenticates receipts, Profile/physical references and Frozen context, then calls DialogicBridge.validate_scene_event_anchor for each authenticated event. For scene5, Bridge validates anchor shape, configures the current registered programme, restores the complete saved reading session, checks catalogue/version, then resolves occurrence frame and publication membership.

The old final portion calls ledger.snapshot(), deep-copying frozen context, all frames and all captions, then scans captions for the matching publication/occurrence/entry/line. The new ledger-owned `has_scene_publication` resolves the same frame first, then checks the existing `_published` map. It returns only a Boolean; Bridge preserves the original success or event_anchor_invalid result. The legacy Solo path is untouched.

There is no new index, cache, authority object, remembered verdict or new manager. No configure, programme compilation/file read, restore, validator, live authority lookup, callback, mutation guard, checkpoint, storage or historical-boundary check is removed. The method retains the small frame validation/detachment work; only whole-ledger projection and the final scan disappear. This may be an immaterial fraction of the measured0.74s historical semantic anchor scope; that is a falsifiable risk, not a reason to claim a gain.

## Equivalence and failure order

NarrativeCaptionLedger.publish_caption puts the same registered beat/occurrence in `_sequence` and `_published`. `_restore_scene_snapshot` validates every frame and every row before installing both structures from one private candidate. An identical repeated publication refuses with caption_snapshot_duplicate; a conflicting duplicate refuses earlier with caption_publication_conflict. Thus a successful restored ledger has unique publication IDs, and map lookup is equivalent to the old existential scan. A late malformed row cannot be hidden by an earlier matching row.

The replacement occurs after all existing anchor/configuration/restore/catalogue checks. `resolve_scene_frame` still precedes publication lookup, so missing/invalid occurrence frames retain their original precedence and Bridge refusal. The logical occurrence remains anchor.session_id; it is not substituted with the ledger session token. No native/live-frontier shortcut is used.

The candidate ledger is newly allocated within each complete validator call and is not exposed before lookup. No await, signal emission or external callback is added between full restoration and lookup. The queried structures therefore belong to that invocation; changing the caller checkpoint between calls triggers a fresh configure/restore. Caller inputs and authority reads are unchanged. The new method exports no internal containers.

## Existing work and PR1 comparison

The earlier SceneEventContract pure-construction experiment and rejected proof-normalization experiment remain distinct. Frozen81847 already includes the former; neither changes this membership tail. The new candidate is based on current product, not a wholesale transplant of diagnostic tooling or engine code.

PR1 rechecked at `a6decec3693ee4d57df9f879b90ace3e118c9d1d`; its Bridge has no `_validate_scene5_event_anchor`, and its ledger has no `has_scene_publication`. Current master lacks this scene integration as previously recorded. No equivalent completed change was found in these exact owners. No broader PR1 merge is proposed.

## Prepared checks and execution gate

External Coordinator C must review this **actual candidate and equivalence argument** before dispatch under Director6273617462. Internal independent source review found no blocker; it is not external C approval or compiler qualification. Controller929423d0 remains unchanged and no run was dispatched.

1. Cloud-only Godot4.6.3 standard GDScript: import with strict script/error gates; run the same differential test inputs against original and candidate. The dedicated synthetic scene process requires DWM_SCENE_READING_FIXTURE=1. Compare complete return dictionaries/types and caller bytes, with first/middle/last historical/current publications; missing/crossed identity; malformed/duplicate/conflicting late rows; invalid/noncanonical frames; multi-fault refusal ordering; and same-object edits between invocations. The terminal-source case tests the checkpoint passed to this routine, not terminal authentication.
2. Retain existing ledger, full saved-event-anchor, receipt and terminal-lifecycle suites as separate integration/authority guards. Test bodies must run against the appropriate process registration/owner fixture. In particular, full terminal/source-reading and unavailable/changed authority obligations remain with the unchanged owners; the component differential suite does not claim to cover those by itself. Input/output mutation checks are bounded; adding a top-level key is not comprehensive deep-detachment qualification.
3. Only after clean correctness outcomes, use the prepared complete-routine benchmark in a fresh process with **normal story registration**, fixture flag unset, profiling flags identical/disabled for both implementations. DWM_ANCHOR_INPUT_PATH must point to the exact retained run39279335309 `exported-load/failure-saves-autosave.json`, SHA256 `253bda51ce175b6bad6345a8932aad3dd70b22640c12f2223a8d9ba6dd58871e`. Extract from the already-retained original archive; do not fabricate post17 bytes. The script refuses a wrong hash/registration and has no synthetic fallback.
4. That file contains checkpoint sequences `[16,8,9,14,15]`, all PLAYING; scene-event counts `[7,3,3,6,6]` produce25 anchor calls per sample. Both routines receive the same ordered current/history inputs and same engine/settings in one process. Each call still configures and restores. Untimed full-corpus comparison/warmup precedes six alternating-order pairs. Parsing/setup are outside the timing; identical result collection is inside. Retain raw samples, source/engine/input pins, XML and clean process exits. **Printed timings alone are invalid evidence if any test/process/log gate fails.** No terminal-state or new native journey is measured here.
5. Predeclared bounded screen: require at least5% median complete-routine reduction and improvement in at least5 of6 pairs, with all correctness gates clean. Treat a smaller/inconsistent result as immaterial and stop; these thresholds are an engineering screen, not statistical or population proof. Any regression stops the candidate. No repeated search for a favorable sample.
6. Only if that screen passes, Director permits ONE matched complete-transition check on an explicitly reconciled coherent source pair. Preserve original player deadlines, failures, save/refusal/recovery/history semantics, and separate readiness/durable lifecycle/clean exit. A routine result alone cannot promote this change or the diagnostic engine; the native controller/package will require exact source custody before use.

The measured0.74s parent includes configure/restore and many other checks that remain. Do not multiply a microbenchmark improvement into assumed whole-game savings. No further validator, engine rebuild, checkpoint consolidation, timeout change or profiling campaign is part of this candidate.

## Status and remaining product gates

Prepared only; external C exact review is next. Prior offline review is complete and must not be repeated. Official exported ending/durable completion/Title/normal exit, observed latency and relevant integration failures, and final verified build-reference handoff remain open. TEST story coverage is not final production prose completion. No product promotion, merge/release/master/integration movement.
