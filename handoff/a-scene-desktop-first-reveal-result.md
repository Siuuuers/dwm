# Coordinator A — resumable first-Reveal handoff
Updated 2026-10-16 (Hong Kong). Replacement Coordinator A completed the pending independent artifact verification and exact-tree reconstruction.

## Current qualification — completed on resume

Qualified source commit: `9946a86938e16ef7b6d984bc43cc78fc283097e7`, parent `b418eeaa8362ba84b9ba565bdcb476963748e853`, exact cloud-tested tree `1b0c76af723a5c8661d238d9dcc7936a241dc893`. This source commit restores only the two generated inventories and identity-test UID from the retained archive. All 15 other captured source files byte-match the candidate. The following evidence/report commit retains the six original archives without changing runtime or tests.

Independent verification of run38780774096 is now complete: ZIP byte count/SHA/CRC, all 67 retained manifest entries, exact source-derived eight-suite census of **31 tests / 515 assertions**, positive assertions per case, no missing/duplicate/skipped/failed/errored cases, eight test child exits0 and six surface child exits0. Engine4.6.3.stable.official.7d41c59c4 and archive SHA match the recorded pin. Final source status is clean.

Desktop creator/loader share their user directory but use PIDs7864/4692; Run, reading session, profile and saved-file hashes agree. The fixture records one refused write and one ready event. Optional-never-started creator/loader use PIDs7960/3508 and matching creator proof fields. These are bounded connected recovery proofs, not desktop mouse-click or whole-game acceptance. No Godot/PowerShell was run locally and no cloud campaign was repeated on resume.

Machine-readable independent verification: [verification.json](../evidence/scene_desktop_first_reveal/run38780774096/verification.json).

Publication target remains draft PR36 with expected old head281c7008; PR30 is the coordination index. Master was rechecked at0c8b2384 and integration at3ae6d913. Required broader CI qualification and the separate600-second Challenge timeout remain unresolved. Next owner A should select a concrete remaining integration gate from the existing CI report before the later-caption fix, then PR37 runtime composition. Do not repeat this successful campaign solely for context recovery.

The remaining sections preserve the original handoff and its precise implementation/limits. Their pending-verification/resume steps1–4 describe the pre-resume checkpoint and are superseded by this completed qualification.

## Start here
Continue Siuuuers/dwm as replacement Coordinator A. Read latest PR30 Conversation first, then PR36. Director comment https://github.com/Siuuuers/dwm/pull/30#issuecomment-6197370451 is the recorded assignment: registered TEST scene NewRun → retained desktop first Reveal → durable accounting checkpoint → existing recovery. PR30 is the coordination index; detailed results/reservations belong on PR36 with a short linked receipt on PR30.

Cloud-only Godot 4.6.3 standard GDScript and Windows PowerShell. Never run Godot/PowerShell locally. Local git/Python/static inspection is allowed. Preserve save, recovery and history guarantees, authentic scene/narrative providers, strict scene snapshot shape and pressure-only contract. No legacy calendar/Hospital fabrication. No master merge/release or production story choice.

## Exact checkpoint and status
- PR36 remains draft at 281c70086033fe7100e12a6d28f186bae8d3c4a8, branch codex/a-optional-challenge-20261015. Implementation is NOT yet promoted there.
- Latest implementation candidate: b418eeaa8362ba84b9ba565bdcb476963748e853; tree 78d3d2d3464222c58740fe0df7e3dd70a463d862; parent e90edb42ce3934b6ae7582e07da0f0bf98df238e.
- This handoff/evidence commit descends from that candidate. All implementation edits are in its ancestry.
- Separate PR30 controller: ae787df22b6169fca3b840921a4fdd692ab96cbd; tree 31f099e88a8f603e242977329dd876fa52e33b8a; branch codex/scene-runtime-integration-controller-20261009; workflow .github/workflows/scene-first-reveal-profile-diagnostic.yml.
- Run https://github.com/Siuuuers/dwm/actions/runs/38780774096 / job116580083988 COMPLETED SUCCESS. All steps, including exact census/proofs/frozen-source gate and artifact upload, passed.
- Cloud frozen source eff531ef6780f167342ac8b76c1a4e09d27bc306, tree 1b0c76af723a5c8661d238d9dcc7936a241dc893. This runner-created commit may not exist remotely: reconstruct from candidate plus exactly the three generated files in the ZIP.
- Generated paths: evidence/phase_2r/runtime/game_state_surface.json; evidence/phase_2r/runtime/save_manager_surface.json; tests/unit/test_scene_save_identity_flush.gd.uid.
- Gate reports 31 tests /515 assertions. This is the cloud gate result, not yet independently rechecked from extracted final XML/hash manifests.
- Final ZIP is preserved alongside this handoff: evidence/scene_desktop_first_reveal/run38780774096/evidence.zip. Reported975156 bytes, SHA256 2af9b8a9eccf5f81ffd0f2ccccd150e1678af155107fc28126752a1e2ff03a8c. Git blob528e1fc95137176dbd01c9f532d0f70a13df550b.
- Final handoff session's local executor became unavailable (exec-server No such file or directory); GitHub API remained available. Final ZIP was recovered from actual log DWM_EVIDENCE_CHUNK lines; base64 length1300208 checked and stored through GitHub. Independent SHA/ZIP/member verification is deliberately left as the first resume step. Do not depend on /tmp files or agents surviving.

## Resume in this order
1. Fetch this handoff branch/commit and candidate b418eeaa. Re-read latest PR30/36 and branch heads to avoid other coordinator conflicts. Use an isolated worktree; do not reset another worker's edits.
2. Extract final evidence ZIP. Verify byte count/SHA above and every retained-hashes.json entry (manifest paths .godot/ci/... and .godot/phase2r_logs/... map to ZIP ci/... and phase2r_logs/...). Inspect gate.json, candidate-commit.json, engine.json, all XML/logs and child JSONL. Derive exact case names from source; no missing/duplicate/skipped/failure/error cases, assertions>0, child exit0. Check both creator/loader pairs share user dirs but use new PIDs, proof equality, and final source cleanliness. Godot archive pinned SHA e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90, version4.6.3.stable.official.7d41c59c4.
3. Restore ONLY the three cloud-generated source files listed above from ci/source. Compare all other captured source bytes with candidate. Build a tree on b418eeaa and require exact frozen tree1b0c76af723a5c8661d238d9dcc7936a241dc893. Publish a same-tree source commit with b418eeaa parent. Do not silently publish stale inventories or manufacture UID.
4. Attach evidence and finalized report as descendants of the qualified source commit. This handoff commit is a preservation branch, not the qualified tree; reuse its docs/evidence blobs. Advance PR36 only with expected current head and no force after verifying ancestry and current coordination.
5. Post detailed exact-source/results receipt to PR36 and short linked lane/head/status/next-owner receipt to PR30. Keep PR36 draft: broader CI and the earlier600s Challenge timeout remain unresolved.
6. Then address required remaining qualification. Later-caption coherence is next implementation slice after this first-Reveal qualification; use B's existing diagnosis below, do not redo it. PR37 prepared partner fork follows later. No architectural question is currently blocking this bounded work.

## Cloud gate census (latest run)
| Suite | Tests | Assertions |
|---|---:|---:|
| unit-first-reveal-port |6|79|
| unit-desktop-board-audio |4|57|
| unit-desktop-composer |15|114|
| unit-scene-save-identity-flush |2|22|
| desktop-first-reveal-create |1|92|
| desktop-first-reveal-load |1|51|
| optional-never-started-create |1|59|
| optional-never-started-load |1|41|
| Total |31|515|

Do not add counts across retries. This refreshes the included never-started regression, not every earlier optional-Challenge suite.

## Implementation and ownership
1. autoload/ApplicationBootstrap.gd binds one retained SaveManagerDesktopBoardPort scene-context callback. It captures authentic current SceneHost, current scene route, live session/run, active app and native reading checkpoint; rejects stale provenance and restore/NewRun/session-abandonment gates; permits existing internal causal transaction lease; revalidates admission after capture. It supplies semantic context only and never replaces the detached composed board/accounting candidate.
2. scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd configures callback once/idempotently; rejects missing/refused/malformed/replacement providers before lower prepare. Passes a deep duplicate to callback. Exact semantic keys route_id/active_app_id/content_version/dialogic_checkpoint are checked, existing strict audio semantics preserved, legacy route stays main.
3. scripts/application/run/SaveManagerCheckpointPort.gd uses existing copy-on-change StringName→JSON String normalization on outgoing scene input before strict Run9 build. Actual run38777005068 diagnosed invalid_primitive at $.desktop.board.board.board.outcome. Runtime reducer retains StringName; persisted JSON has String. No saved-schema/Load validation or numeric/object coercion relaxation.
4. MinesweeperRoundCoordinator.gd builds canonical successful first-Reveal result_override BEFORE composing the snapshot. DesktopFirstRevealSnapshotComposer.gd requires and validates that exact result envelope and projects it, so durable/live command receipt results match. Scene outer-key and pressure-only rules unchanged. Existing board-state parser accepted legacy raw-state result, so receipt repair was a separate durable/live divergence, not the original StringName failure.
5. ApplicationBootstrap.gd startup fix: STAGE_ORDER builds identity before initialize_saves. The old hook registration was attempted while _saves_storage was null. Registration now immediately follows JSON_STORAGE construction and precedes SaveManager.initialize. Existing _flush_before_run_save still flushes issuer first, then Dating pending attempt, propagating refusal. Independent source review found existing in-flight scene checkpoint guard prevents direct recursive saves. Hook now affects all save writes: do not imply all prior regression suites were refreshed.
6. Tests: new tests/unit/test_save_manager_desktop_first_reveal_port.gd(+UID); updated test_desktop_first_reveal_snapshot_composer.gd; new tests/unit/test_scene_save_identity_flush.gd (UID from latest cloud). Two hook tests use real initialization stage and JsonFileStorage with probe issuer; assert flush-before-publication and refusal leaves no artifacts.
7. Connected fixture tests/integration/scene_desktop_first_reveal_child.gd and test_scene_desktop_first_reveal_{create,load}.gd(+UIDs). Real registered TEST target_a, real FINAL bootstrap/SceneHost and first native caption. Production MinesweeperPresentationPort and retained coordinator; this is NOT desktop UI clicking coverage. Real autosave.json.next directory obstruction produces physical write refusal; no debit/install/history/profile/slot mutation; remove obstruction and retry; one round debit, exact durable/live Run and paid receipt, same-process runtime StringName retained. Separate process uses actual title Backup Load slot1, verifies branch remap without recharging/replaying, same board/layout/history/reading and unchanged saved files.
8. Failure-only diagnostics remain in fixture. First-Reveal raw command diagnostic only executes after unexpected pre-write refusal, then fails. Cold-load diagnostic reproduces StrictJson→SaveMigrations→_prepare_restore_document matching Backup path, reports bounded structured failure, never commits or counts as acceptance. Earlier public prepare_restore_slot diagnostic returned reconcile_required because it lacked a fresh reconciliation lease; this was NOT the original Backup refusal. Avoid claiming it proved identity cause. Latest success follows hook relocation plus corrected diagnostic; only hook changes production behavior.

## Scope and review limits
Independent final static review found no new blocker for bounded first-board acceptance, subject to final evidence verification.
- First-board fresh fixture only. Composer does not compact older board-command/visibility receipts exactly as later actual commits may; later-board/long-journey coverage is not claimed.
- No desktop UI interaction claim, no performance claim.
- No final story text; TEST fixture is replaceable content.
- All Minesweeper optional: close Computer, then manual Accept/Next may leave unstarted/unfinished; closing alone does not advance; genuine completion continues. Preserve this accepted behavior.
- Broader CI is not green. Do not mark PR36 ready/merge.

## Earlier attempts preserved (not additive)
Each ZIP is evidence/scene_desktop_first_reveal/run<ID>/evidence.zip in this handoff commit.
| Run / job | Source | Result |
|---|---|---|
|38773783369 /116556058796|b40e689a2897e1f97372dc3e1ea132cbef16e07a|22 tests/202 assertions completed; extra test_scene_first_reveal.gd timed out600s exit124, no final XML, connected pairs skipped|
|38776206168 /116564378017|dca44f662ec939c1c547c79a15a8f6da12c6929e|same frozen tree connected-only retry; creator53/55, no writes, generic refusal|
|38777005068 /116567143472|ad0ca81cf1e9818f5e3b1a6de1f6e43b1de73511|22 short units passed; raw invalid_primitive StringName board outcome|
|38778225278 /116571313402|7524eeb91e218db2f0987b6e87b090aec9d6022a|25 short units250 assertions +creator92 =26/342 passed; loader failed1test17assertions; optional skipped|
|38779379225 /116575301612|e90edb42ce3934b6ae7582e07da0f0bf98df238e|same26/342 completed subset; loader failed; public diagnostic reconcile_required not original failure|

ZIP hashes:
- run38773783369:517263 bytes,e1be16dc36eeb61dbdf3164260dc5f7316b277181a4e4f78f72290f577178a55,42members.
- run38776206168:473895 bytes,6066dbd33867a91fd4d9d79536ef1080c4d9f811e433a96fa5aec0358e629596,29members.
- run38777005068:487119 bytes,7a1287ac317af152028f76bcd4d6c9a743ba412d9a707b0eabc322b17b8934ae,42members.
- run38778225278:553878 bytes,93b6fa8fbcb6bd723545a76af0f8e2666fc8cb6b0ee987852cb57eeb95ca8303,49members.
- run38779379225:554160 bytes,207e894c754ae01efadffe938882ded3f7e8b5cd002d76c6979f383addfe0589,49members.
All earlier retained manifests independently checked; last two48/48 files each, exact source-derived XML census, completed children0, failed loader child1. Loader assertions excluded from passed totals.

Frozen earlier trees: run1=2231b0aeefe8c48c33727d46a80ea8e5f2bb8cde (same-tree published dca44f66); run3=072aed0ed6731d58cafad9dee9e4d88452ac029a; run4=965f717c2841fef66809d6efe7ef30ff75e8ac9c; run5=6e597afe7efb44759afb3c81d129191f8f4c8421.

The extra timed-out suite's final test is test_debug_certification_applies_retained_reveal_and_recovers_checkpoint_refusal (4096-slice certification/refusal/reconstruct/retry loop). Its source/fixture/physical owner are unchanged relative to earlier optional candidate, but this is NOT an executed baseline timing proof. The earlier77-case optional acceptance ran test_scene_challenge.gd, not this suite. Leave timeout unresolved; no credit.

## Prior accepted work and remaining CI
Do not redo:
- Optional campaign source0d3464691bfa13f4cd0fdfe368906b0de2079e53/treea4cb2a7694df188b6c863f807dfe91987f4dea6e: same-tree77tests1868assertions across run38723457603 (32/824 completed subset, overall timeout) and38725775354 (45/1044 passed). See evidence/optional_challenge and handoff/a-optional-challenge-result.md.
- Future-schema fixture correction in test_save_migrations.gd and test_save_document_schema.gd uses SCENE_DOCUMENT_VERSION+1. Run38766739347/job116531805522 passed33tests613assertions on6f837d85e35dcd803d3328531798ce24e302d66f/treeb7fd26ea718e0777594289e963a0cece00ede36e.
- Legacy first-Reveal diagnostic rejected unexpected committed_schedule/dating both on integration3ae6d9138fb53c388380c78550cf6082eafc0ea3 and candidate6f837d85, proving that narrow legacy fixture incompatibility predates PR36. See evidence/ci_qualification_2026_10_16 and handoff/a-ci-qualification-20261016.md.
- BroaderCI38725742391 had9success11failure2cancel1skip. Known categories include notes provenance, old issuer/census, retired health, localized count308vs310, shop old IDs, Day7 baseline3vs2, desktop unmounted GameState/global issuer. Cancelled is not passed. Use existing report to choose concrete remaining gates.
- Last inspected master0c8b2384415d71bd3de4ff7408640bbf60b63740; recheck before next edits.

## Later-caption task already diagnosed by B
https://github.com/Siuuuers/dwm/pull/36#issuecomment-6196086346
Native Accept A first→A loop publishes line.two while SoloReadingSession.scene_index remains line.one; subsequent capture returns reading_frontier_invalid. Same source as integration, not an executed baseline. Existing optional fixture saves on coherent A first and misses this.
A should add focused connected native Accept/save/new-process Load/continue proof, then repair existing Bridge/adapter/SoloReadingSession ownership via authenticated compiled semantic/native mapping. Do not increment index blindly, search prose, relax frontier validation, reset history, cross uncommitted controls, introduce a second manager, or add per-caption disk writes. Duplicate activation and loop re-entry require correct publication identity. Auto plain-text advancement uses same path but existing label/jump loop is not an Auto reproduction; use an adjacent-caption fixture if needed. Rail Next is separately planned/restored. B owns read-only provider review; C docs reconciliation separate; A owns shared source/integration/publication.

## Relevant coordination comments
PR36 reservations/results:6197478151,6197624545,6197637981,6197978608,6198216712,6198513510.
PR30 previous receipt6197978866. New handoff receipt will link this document.
