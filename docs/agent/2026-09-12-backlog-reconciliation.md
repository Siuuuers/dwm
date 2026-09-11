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
| `dwm-15h`, `dwm-sf7` | Historical closeout/index digest and generated-surface evidence are stale. No resealing or repaired-evidence claim is made. |
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
