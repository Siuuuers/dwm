# Playable-build backlog reconciliation - September 12

This audit answers the owner's request to retire obsolete Beads and choose the next useful work. The starting build was `5671a1cf9` on `master`: 18 open, 4 in progress, and 11 deferred records. A closed historical plan is not a claim that every old acceptance gate passed or that the game is release-ready.

## Retirements

These nine records were closed with explicit replacement reasons:

| Record | Reason |
| --- | --- |
| `dwm-4yv`, `dwm-4yv.1` | The owner replaced the UI-00/UI-00R recovery workflow with the simpler integrated runtime route. Historical projector/census/grant acceptance is not claimed. |
| `dwm-eei.3` | Canonical Pause, stable desktop/Dating Backup, Return and recovery now run through the integrated owners. |
| `dwm-eei.6` | Gallery registrar, reached ending replay and private Practice are integrated. |
| `dwm-eei.7` | Shop is integrated, with two pages and the deliberately hidden Supportz slot. |
| `dwm-eei.8` | Schedule is integrated; the September 11 draft Save/Load and editable Motivation refusal flows pass. |
| `dwm-eei.9` | Minesweeper worksheet and controls are integrated, including board fitting and Flag-mode chord. |
| `dwm-eei.20` | New Account, replacement, durable startup and real Day-1 routing are integrated. |
| `dwm-ihm` | Canonical `observer.full/residue` entries resolve in the per-scene DTL architecture. Registered legacy `observation` resources remain compatible. |

The six retired UI integration plans are replaced by the current playable implementation. Remaining shared accessibility, content and release acceptance stay with `dwm-eei` and `dwm-oyo.7`; retirement does not erase those requirements. Existing checkpoint branches and working files are preserved.

Evidence: `docs/design/current-ui/working-design.md`, `evidence/integration_readiness/README.md`, the September 7 whole-game reconciliation and September 11 playtest reports. These record main-checkout integration, 26-scene smoke, real startup and seven-day journeys, Gallery/Practice, native Pause and strict Save/Load. Art bindings are implemented; their current map is `art/README.md`.

## Work that remains

| Records | Current work |
| --- | --- |
| `dwm-bap` | The demonstrated Day-2 to Day-6 continuity bug is repaired. The original acceptance still requires four calendar/echo/group/drain dispositions and three requirement evidence arrays; these are not silently marked complete. |
| `dwm-nsr` | Minesweeper Debug generation still has a stale reducer fingerprint in its measured budget manifest. The committed reducer really differs; this is not a line-ending mismatch. Keep the validated benchmark refresh separate from ordinary-board latency work. |
| `dwm-634` | Long-history seven-day performance and completion/load latency. Recent improvements are real, but they do not establish bounded performance for all histories. |
| `dwm-hsi` | Ordinary-reply save investigation: real A/B/C flows passed, but the originally reported failure has no confirmed matching cause. Diagnostics remain; do not call non-reproduction a fix. |
| `dwm-eei.5` | Controls advertises New Board rebinding/controller input, while current consumers hardcode Space. Validate Quick Save/Load across the advertised contexts too. |
| `dwm-eei.2`, `dwm-nqn` | Settings audio/TTS preview and the richer exact-cue audio/save contract remain separate from the working minimal audio context. |
| `dwm-eei.10`, `dwm-eei.11`, `dwm-eei` | Canonical witnessed History, retained-caption restore/retranslation, transport and complete assistive behavior remain. Current transient captions are not proof of these features. |
| `dwm-idz`, `dwm-3an` | Production visited-line registry and skip wiring are missing; the runtime adapter lacks the `current_line_id` method called by Skip. |
| `dwm-n3h` | Some presentation-signature checks exist, but the full frozen narrative context contract is not implemented for every start/resume. |
| `dwm-oyo.2.1`, `dwm-oyo.2.2` | Retired-entry negative-test reachability and current scene-validator CLI/diagnostic coverage. Eight-master generator/count obligations are superseded and must not return. |
| `dwm-15h`, `dwm-sf7` | At the September 12 audit, historical closeout/index digest and generated-surface evidence were stale. The September 13 disposition for `dwm-15h` is recorded below; it does not re-seal historical evidence. |
| `dwm-eei.17` | One native renderer shutdown stall remains unexplained; clean repetitions do not prove its cause was fixed. |
| `dwm-eob`, `dwm-5ht` | Deferred narrative translation adapter and dual-language rendering. Primary-language UI remains supported. |
| `dwm-oyo.5`, `dwm-oyo.6`, `dwm-oyo.7`, `dwm-oyo` | Persistence/Rehearsal and endings have substantial implementation evidence, but outstanding behavior and whole-game release acceptance prevent an all-complete claim. |

## Recommended order

1. Verify one uninterrupted seven-day run, including both group windows, ordinary echoes, save/reload, ending and Gallery return. Start from actual earlier state, not independent day fixtures.
2. Fix advertised Controls behavior and refresh the Debug-generation budget; measure long-history performance on the same player journey.
3. Add final art and dialogue through the existing placement map. Complete narrative transport, translated narrative, richer audio and full accessibility against representative content.

Beads remains the task source of truth. This document records the audit rationale rather than introducing a second TODO system. After these changes there are **15 open, 2 in progress and 7 deferred records: 24 total**, including parent tasks. This is not a count of 24 confirmed bugs. Narrative translation and dual-language rendering are explicitly deferred; eight-master DTL consolidation remains superseded.

## Repair and verification

`GameState` now checks the requested day before suppressing solo messages. `ContactInvitationState` permits a resolved earlier group window to give way to the later window while preserving original receipts and messages. Earlier group state is reconstructed only for validation from those existing receipts; no persistent schema or second history store was added. Unresolved, same-day, backward and run-end replacement remain refused. A reused Day-2 activation command cannot masquerade as Day 6.

Fresh isolated Godot runs:

| Check | Result | Local log under `.godot/phase2r_logs/` |
| --- | --- | --- |
| Contact invitation continuity, source receipts, ordinary correspondence, round transactions and day-end Contacts | 81/81 tests, 1,694 assertions; exit 0 | `bap-final-current-regressions-20260912.log` |
| Current per-scene DTL/Observer structure | 7/7 tests, 178 assertions; exit 0 | `ihm-scene-layout-audit-20260912.log` |
| Broader surrounding batch including legacy GameState tests | 90/101 tests; 11 failures | `bap-surrounding-regressions-20260912.log` |

The new regression first reproduced later solo suppression and the missing Day-6 group. Its passing form continues the same game state through both windows and retains Day-2 messages/receipts. Separate accepted-history and tamper checks preserve schedule sources and reject missing activation, missing closure, or fabricated prior state. The JSON roundtrip uses Contacts plus `RunSnapshotSchema` integral-number normalization; it is not full SaveManager disk-restore evidence for this new two-window journey.

The 11 legacy `test_game_state.gd` failures concern faint/Sylvia thresholds and old ending/Gallery flows. Their complete failure block exactly matches the September 9 `dwm634-checkpoint-cache-focused-20260909.log` record. They remain unresolved under release acceptance; the broader suite is not green. Runs also report 24 Dialogic orphan nodes and existing NUL diagnostics. Independent review approved the three-file runtime/test diff with these limits, and `git diff --check` passed for the owned changes.

No player save data was used or modified. No worktree was removed: a clean Git status alone does not prove that ignored artifacts or saved handoffs can be discarded. Unrelated working edits remain preserved.

## September 13: historical closeout/index disposition (`dwm-15h`)

Under the owner's delegated authority to resolve the remaining backlog, retain the Phase-2R closeout as frozen historical evidence and record its live-index deviation. Do not re-seal it. `evidence/phase_2r/closeout/gate.json` attests subject `a5381ba1b5ab014dcc8249563decf7b01040e40f`; its evidence commit is `ce3deea1a4ca46eec87e2388c41721533934055d`. The gate, receipt, command record, logs and original Beads closure binding remain unchanged.

The sealed `prompt_docs/INDEX.md` digest is `156a32468c65b2a852276f4630b42408839cedd635e08efba81f1e0f13c40db4`. The approved reconciliation in `ed037cb2b1781a02905a232b0747b093abc377c7` changed the generated index; the September 13 live digest is `d014d9db543ddacce12c6749acc96b4fa545bf7e6b269ffe89d9b675c1cf908e`. This expected mismatch does not invalidate the original subject's bytes, and the old test run does not prove today's index or gameplay. The existing closeout CLI continues to reject the current checkout with `gate_digest_mismatch` for `requirement_index`; its live-digest and exact evidence-commit checks are unchanged.

`tests/unit/tooling/test_phase2r_closeout_gate_validator.gd` now checks the real four authority blobs at the sealed subject, the retained evidence-commit bytes and seal hash chain, and the CLI validation path's refusal of the live index (through `Script.run`). These checks supplement its existing negative fixtures. Current index correctness is checked separately by `tools/docs/validate_docs.gd` with a fresh Beads snapshot: `DocValidator` compares the live index byte-for-byte with output generated from validated current packets. This is an explicit historical disposition with a current verification path, not a repaired August seal or a new full-game closeout. Verification records are in `evidence/historical_closeout_disposition/README.md`.
