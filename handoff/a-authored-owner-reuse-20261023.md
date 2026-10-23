# Authored validation owner reuse — 23 October 2026

Continue cloud-only Godot 4.6.3 standard and PowerShell. Read AGENTS.md and CLAUDE.md. User requests minimal meaningful verification, smooth player flow, and a useful handoff. No design question currently blocks progress. No merge, master/PR51 alteration, or Steam upload.

## Source and ownership

- Product branch: `codex/authored-week-followup-20261023`.
- Final runtime/test candidate: `609f0f2be6957f6ee33b8b70cc6fbd06e0cb7207`, tree `cd0a235191abad8d370109e613866a432fa0708c`.
- PR50 is the diagnostic controller; PR30 is historical. Do not merge diagnostic workflow overrides into product.
- Master independently checked at `d2062f8d9807f7f06935f86065640ff14a5400d6`, tree `e40cc24abd2ab3df16ca417dfd89bc9136711f3e`; it does not contain SceneEventContract. PR50 base remains `328edfe082c84bd9f6ca0a9d45e6603e0902695c` (PR51 integration). Neither changed here.
- Previous handoff: [receipt reuse](a-authored-receipt-reuse-20261023.md).

## Observable outcome and implementation

The first photograph boundary repeatedly authenticates the same receipts within each snapshot validation. Reduce that duplicate work while retaining fresh public validation, physical Profile proof, issuer provenance, and reading-anchor joins.

1. SceneEventContract reuses already-checked detached registration tables for v3 initial-receipt reconstruction, as it already did for v2. Public initial preparation/candidate APIs still validate their own registration. SaveManager still proves actual committed creation and physical Profile material on every receipt-validation call. Stage-one commit `a1f2062e24312502aaaecc74bd92d173b50137ad`, tree `e619b4600a96e7ece26547777d526874061c274c`.
2. FrozenRunContext returns fresh authenticated detached commands alongside derived frames. GameState consumes this output only when its issuer and creation owner match Frozen's already-bound owners. Terminal/mismatched paths retain independent receipt validation. Physical Profile references and each command's bridge anchor join remain.
3. RunSnapshotSchema defers duplicate receipt authentication only to the exact GameState script with the same issuer and root SaveManager. Custom authorities, mismatched owners, and terminal snapshots retain the old independent proof. The mandatory semantic callback, detached-input mutation hashes, and reentrancy guard remain.

No saved-data schema change, global cache, new manager, caller-controlled trust flag, or cross-operation reuse. For multiply corrupt input, refusal priority may now be audio/reading before receipt authentication, or frame errors before Profile errors; these cases still refuse.

Independent runtime and test-body audits completed before acceptance runs. Tests cover returned-output mutation, fresh-input tampering, changed registration, damaged physical Profile, different issuer, permissive custom semantic authority, and missing creation authority. New positive prerequisites explicitly exercise the actual deferral path; default older fixtures alone would have exercised fallback.

## Cloud evidence and measurements

All retained directories below are under `evidence/phase_2r/authored_followup_20261023/`. Each contains original outer and inner ZIP archives plus `inspection.json`; screenshots, logs, source manifests, native save roots and UID provenance remain inside the originals.

| Run | Scope/result | First photo boundary | Bundle / receipt / physical / snapshot checks |
| --- | --- | --- | --- |
| [39896652757](https://github.com/Siuuuers/dwm/actions/runs/39896652757) | Previous receipt-reuse candidate; 41 tests / 810 assertions | 25,363 ms | 117 / 55 / 55 / 16 |
| [39897763358](https://github.com/Siuuuers/dwm/actions/runs/39897763358) | Stage one; 53 tests / 1,046 assertions; five clean exits | 32,576.842 ms | 62 / 55 / 55 / 16 |
| [39900441794](https://github.com/Siuuuers/dwm/actions/runs/39900441794) | Final candidate; 16 tests / 582 assertions; three clean exits | 26,469.916 ms | 30 / 23 / 23 / 16 |

Stage one's ordinary-caption median was 304.0405 ms; final candidate's was 303.707 ms. The final boundary measured 18.75% faster than stage one with similar ordinary timing, but hosted-runner timings vary and the earlier candidate measured 25,363 ms. Deterministic work removal is established; the remaining 26-second stall is unresolved. Inclusive timing scopes overlap: never add their totals. Original baseline before receipt reuse was 52,765 ms / 173 bundle checks, recorded in the preceding handoff.

Stage-one evidence: `run39897763358_initial`, controller `0c8818a6c896b8adde2745b8700e2f4257d54580`. Both ZIP CRCs passed, outer digest matched fresh GitHub metadata, all 110 retained member hashes rechecked, exact source-tree/census verified. Native 992x558 screenshot inspected: both paintings and “Send it to me.” visible.

Final evidence: `run39900441794_semantic`, controller `dea0603f7059010b45b91f2681731f7bd8ad3ebb`, event/workflow `909576e770963c92b97dc1007bf8d2328837c568`. Both ZIP CRCs passed, outer digest matched fresh GitHub metadata, all 74 retained members rehashed, exact source-tree and test names verified independently. Census: saved-event-anchor 10 tests / 117 assertions; joint-new-run 5 / 94; rendered first-32-caption profile 1 / 371. Native screenshot inspected with expected artwork and caption. No repeated artwork suite or whole-week run.

Final outer SHA256: `4fcc0cc7f49f48d68fde12227f8b9935b1a817dd05d59deed6c3b0c6a7100b68`.
Final inner SHA256: `61a1daf9e267511344660bd7e63deef1eb816980bfb7ba93b17717ce95db74ea`.

### Retained failed attempt

[39897540329](https://github.com/Siuuuers/dwm/actions/runs/39897540329), controller `29e07604fe728125412e282fb484c8280ee6d144`, is retained at `run39897540329_initial_failure`. Import passed, but combining fixtures with process-wide registration produced `registration_already_selected` setup errors and four failed cases (52 cases / 597 assertions). Profile did not execute. Controller correction isolated fixtures into separate processes; runtime checks were not weakened. Both archives and all 46 manifest members independently verified. This run remains a failure.

Cloud checkout status deliberately records removal of two legacy skill gitlinks from the disposable index to permit credential cleanup; source commit/files remain pinned. Do not claim the diagnostic working tree was completely clean.

## Useful fresh-session starting point

The next observable outcome is: **a fresh process restores the genuine interrupted Day2 save through the real recovery/Load owners, without repeating consequences, and records bounded late-history timing.** Establish that before predicting whole-week performance or choosing more surgery.

Use the authentic durable root from failed authored journey [39888749357](https://github.com/Siuuuers/dwm/actions/runs/39888749357). `run39888749357_journey/original-artifact.zip` contains `original-evidence.zip`; inside it, `ci/native/authored-week/0/appdata/Godot/app_userdata/DWM/` contains Profile, issuer root, autosave, continuation operations and backups. Preserve the whole root and provenance, not only autosave. Copy into an isolated cloud test root; never invent history or edit receipt authority to make it load.

Static inspection: checkpoint sequence 19, 17 receipts, 290 retained captions, entry `Day2.answer`, boundary `control`, program index 19, pending `next_operation.phase = destination`. Its source frontier is `line.Day2.answer.019`. This is an interrupted control transition, not an ordinary visible-line checkpoint. The probe must exercise actual recovery and verify no repeated consequences. The original creator timed out at 1,800 seconds after 290 verified captions; fresh Load/replay never ran. That failed journey remains failed. Do not blindly increase deadlines.

After the bounded probe and any measured fix: complete authored Day4 Save, fresh Load to ending, fresh ending replay, then final-source export. Existing `authored_week_create/load/replay.gd` wrappers and `authored_week_child.gd` define the 836-caption route: creator checks 469 captions through Day4; Load checks 368 including resumed Day4; replay checks 22 plus fresh New Game. Early 32-caption profiling is not late-history, full-week, Save/Load, export, or release acceptance. Prior artwork qualification remains accepted within its scope; do not repeat the whole artwork suite. Earlier export predates the artwork correction.

## Avoid redundant work

The 16 snapshot validations span two autosave commits and outgoing/journal/storage boundaries, with checkpoint sequences `[2,2,1,1,2,1,2,1,3,3,1,2,3,1,2,3]`. Do not cache proof across these operations blindly. SaveManager's omitted `proven_candidate` in stable-checkpoint/backup paths affects logout/manual saving, not this photograph boundary. SaveDocumentSchema `_validate_journal` performs primitive checks, not another full snapshot validation. Avoid unrelated cleanup.

Automatic diagnostic PR triggering was retired after collection at controller `de096b1744ef2382be3b5dd36867d043c0d74b72`. The workflow retains `workflow_dispatch` and a branch-specific manual guard. Keep cumulative PR path triggers disabled before unrelated controller updates. Runtime was not changed after the final passing candidate; subsequent product commits preserve evidence and this handoff only.
