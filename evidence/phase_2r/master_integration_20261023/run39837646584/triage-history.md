# History and performance triage — run39837646584

Read-only triage of candidate `d1d8313cff343a46733c021ad9125d6c0702eeff` / tested merge `3b171dbb60f6edc9cd267e6244f786893b146e76`. No Godot/PowerShell execution, product edits or remote writes. Read AGENTS.md and CLAUDE.md. Current-source Python baseline derivation was inspected/replayed without writing product source.

## Observed failures

| Job | First causal failure | Evidence / scope |
| --- | --- | --- |
| Seven-day retained history producer120033199435 | `derive_save_admission_baseline.py`: `ValueError: Expected 3 current-source admission anchors` | The exception occurs before any history probe. Import passed. No Day7 producer payload/provenance exists from this job. |
| Paired checkpoint performance120033199791 | `PLAYABLE_STARTUP_FAIL: benchmark desktop ready`; baseline-zh-CN exits1 | The one baseline process ran official Godot4.6.3, then the fresh-account desktop wait failed. Candidate variant, localized payload comparisons and timing comparison were not reached. |
| Seven-day aggregate120034291813 | Dependency requirement fails | Consequence of missing producer/comparison jobs, not independent gameplay evidence. |

The second job's original log was fetched through GitHub connector. Its isolated process ran19:17:23.556–19:18:01.747UTC with `--phase2r-bootstrap-mode=final --reply-locale=zh-CN --dating-ending=win`. No script-error explanation accompanies the desktop wait failure. This is not measured lag or evidence to widen the30-second deadline.

## Admission baseline cause

`tools/testing/derive_save_admission_baseline.py` retains current SaveManager and adds four redundant validations for a paired comparison. Its first two exact transformations still match. Its third transformation expects3 copies of `# Admission already returned the validated, detached document.`; current source has2, at `_prepare_restore` and `_prepare_source_bundle`. The former third comment in `_reconstruct_restore_materials` was removed by `4b21a420a` (`Implement bounded scene restore durability and activation; compose F/G successors`). Direct Git diff shows that commit added the authenticated `scene_restore` retained-document branch and moved legacy re-reading/migration into `else`, then removed the comment after the shared document assignment. No admission validation was accidentally removed by this CI correction.

Static Python replay reproduces the exact exception. The subsequent `derive_save_prepare_baseline.py` currently derives successfully, so it is not the immediate blocker. No historical hash needs resealing.

Minimal baseline maintenance: replace the global three-comment assumption with two exact retained sites plus one uniquely scoped current `_reconstruct_restore_materials` insertion site. Review the current retained-scene and legacy branches before adding the redundant validation after their shared document assignment. Preserve current source, schemas, recovery, and branch selection in both variants; baseline adds only the intended validation/copy work. Do not simply lower3 to2, which silently changes the claimed four-validation ablation, or restore historical SaveManager. Require exact changed-site census and equivalence of resulting admissions before accepting performance observations. This is a test/tool maintenance proposal, not a patch or cloud qualification.

## Journey mismatch extends beyond the first wait

`benchmark_minesweeper_click_latency.gd` starts New Account and waits for ComputerDesktop, then commits the old `reply.ordinary.lavinia.day1.a` receipt and routes through Contacts/Schedule Done into a Priscilla Dating board whose pre-DTL is expected empty. Current startup selects shipped scene registration; ApplicationBootstrap configures scene title NewRun using the registered first target and SceneHost. The benchmark does not advance that opening. The source therefore explains the observed missing desktop without showing a product startup defect. Source inspection alone does not prove the eventual current route is successful.

`benchmark_seven_day_history.gd` inherits that legacy benchmark and similarly assumes immediate desktop, calendar `game.day`1–7, Schedule Done per day, and legacy expected gameplay/history shape. Its admission-deriver error currently masks these later incompatible assumptions. Fixing the marker count alone is unlikely to qualify the producer.

Safe next work should explicitly preserve the existing measurement obligations while rebasing their fixture journey: matched current-source variants, identical saved payloads for direct comparisons, cold fresh-process recovery, exact retained checkpoint custody/counts, localized receipt evidence, and bounded real board actions. Use the existing supported current scene producer/reader journey where appropriate; do not pretend old Schedule/calendar steps executed under the new scene programme. Alternatively an explicitly named historical-fixture benchmark may retain legacy adapter coverage, but it cannot stand in for current shipped gameplay and must be clearly scoped. No production reversion, private-state shortcut, deadline expansion, baseline hash substitution, or skipped-gate pass is justified by these failures.

This is broader than the finite admission-anchor repair: selecting a current-scene benchmark fixture requires mapping the old timing/retention obligations onto supported current owners. The user has already authorized minimal test surgery; a new product design decision is not shown by this evidence. If an old measurement has no current counterpart, report that precise qualification gap rather than silently deleting it.
