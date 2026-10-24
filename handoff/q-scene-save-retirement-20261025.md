# Current scene-save field retirement — 25 October 2026

## Status

PR: https://github.com/Siuuuers/dwm/pull/86
Runtime candidate: `bbe41f05e98fabaf2170eee7c7d3bbdad7c223dc`.
Current qualification candidate: `0dcd92579ce8db28fdc31414b9bb1bcea88ba8b3`.
Qualified for merge after successful Windows run 40131013035.
Check live PR metadata for the final merge revision.

Master at entry was `a1858992e4fc0e520f467b22c87f9e8391915c9e` and included PRs
83–85. Those changes must not be repeated. The owner confirmed that the compact
save work must preserve existing choices. New choice rules remain a later task.

## Implemented boundary

Current Scene9 defaults, capture, restoration input and validation omit
`affection`, `friend_attitude`, `friends`, and `inter_friend_affection`.
Legacy calendar properties and callers remain. This is not full retirement of
the legacy relationship subsystem. Current scene consumers use the retained
18 gameplay fields. Inventory, money, coins, pressure, penalties, rewards,
limits, contacts, board data and current choices remain supported.

The exact-member contract deliberately refuses prior development saves that
contain the removed fields. The numeric scene family remains 9. No migration
was added. No command history, audio context or ending machinery was removed
by this bounded increment. Compact direct restoration is still outstanding.

## Evidence and testing

[evidence](../evidence/phase_2r/scene_relationship_retirement_20261025/README.md)
contains source hashes and 35 passing diagnostic cases / 505 testcase
assertions, plus four passing fixture-setup assertions. These Linux cloud
headless checks cover schema, current Backup adoption, event anchors and cold
rollback. They do not establish Windows rendering or installed Steam behavior.

The current-title Windows journey checks omitted fields during real Save and
fresh-process Load. The new `current_terminal_fixture` suite uses the existing
short TEST seven-day graph in three rendered processes. It checks terminal
Save/Load and completion. It restores both authored manifests in `finally`.
It is not full authored-week or two-fork Day7 acceptance.

Qualification run: https://github.com/Siuuuers/dwm/actions/runs/40131013035
The run completed successfully. The earlier run 40130452512 is superseded.
Do not call the deliberately skipped archived measurement a passing measurement.
The retained Windows subset contains 34 cases / 1,225 testcase assertions,
including native authored Title Save/Load and three terminal-fixture processes.
Runtime and test bytes stay unchanged in the evidence-only successor. The only
workflow change extends the terminal step budget; this run passed its prior
stricter limit.

The old terminal archive contains the prior field contract. Current CI retains
its diagnostics as historical work and selects the archived timing comparison
only when both revisions match its saved member set. No speedup is claimed.
A proposed full authored input regeneration was rejected: historical evidence
showed about 46 minutes for the full route. No new full-week producer was kept.

## Next observable outcome

Save a real dialogue beat with an unfinished board, an earlier choice and
Challenge outcome, and non-default economy values. Load in a fresh Windows
process. Restore the full caption and exact board/values. Continue through the
same branch. Do not repeat purchases, rewards or previous commands. Global
read records and Gallery unlocks must remain monotonic.

Use the approved requirements in
[the save audit](../docs/design/2026-10-25-save-load-validator-audit.md).
Do not spend another increment optimizing historical validation by default.

## Concrete owners for compact restoration

- `GameState.capture_run_snapshot_input` and `SCENE_GAMEPLAY_KEYS` own current
  gameplay. Start with their retained fields; do not add another state manager.
- `SceneHost._process` reads `thought_resolved` receipts to hide resolved
  opportunities. Replace this with `choices[opportunity_id] = selected_choice`.
- `SceneEventContract.thought_result` supplies the choice and target mapping.
  Validate the selected choice against registration; derive its target.
- `GameState._advance_scene_registered_marker` retries committed transitions.
  Install choice and destination together. A held control is distinct from a
  displayed caption; Load must not offer an already committed choice again.
- `SceneEventContract._resolve_scene_challenge_recall_inspected` reads prior
  closure receipts. Replace this with an outcome map by Challenge ID. Missing
  is distinct from `never_started`; preserve all five existing outcome values.
- `GameState.capture_scene_challenge_command` and closure helpers need the
  active Challenge/physical board. Keep `route_context.active_dating_challenge`
  until those consumers have a complete replacement.
- `GameState._commit_scene_round_owned` and
  `DesktopBoardState.is_settled_inspection` prevent duplicate settlement.
  Preserve board-bound settlement/reward-applied state and round ordinal.
  The task reward map alone is insufficient.
- Keep task reward claims, inventory, purchase counts and current balances.
  Restore absolute values. Do not replay purchases or rewards.

`DialogicRuntimeAdapter._install_scene_frontier` already starts at a saved
caption without executing preceding markers, but requires the historical
reading ledger. `SoloReadingSession` supports internal caption admission.
A compact entry point must derive art/music from installed registration and
create the necessary present reading state without rebuilding past commands.

Current authored Day7 still converges on one legacy ending trigger. The two
forks/two endings are approved intent, not both implemented content. Do not
invent a second endpoint or add an ending selector. This does not block the
first compact restoration journey with existing choices.
