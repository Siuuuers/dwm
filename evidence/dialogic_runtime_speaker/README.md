# Runtime speaker shutdown repair — dwm-so4

2026-09-13, isolated branch `fix/dialogic-runtime-speaker-lifecycle` from
`b7da8a7a2`, installed Godot 4.6.3 mono. Engine runs are serialized and isolated by
`Invoke-IsolatedGodot.ps1`; actual process exit codes are recorded in
`invocations.jsonl`.

The original crash needs no playback or Skip: parsing
`UnregisteredProbeSpeaker: Probe.` creates a `DialogicCharacter` and registers the
live scripted resource in the global `dch_directory`. That dictionary was shared
with ProjectSettings and retained in Engine metadata after normal scene cleanup.

| Ablation | Actual process exit |
| --- | --- |
| Parse unknown speaker, no manual cleanup | `-1073741819` |
| Same parse, explicitly erase its runtime directory entry | `0` |
| Detach ProjectSettings dictionary only, keep Engine resource reference | `-1073741819` |
| Production fix, same original parse, no manual cleanup | `0`; ProjectSettings no longer contains the runtime Resource |

The production fix is confined to `DialogicResourceUtil.gd`. It detaches the
shipped path dictionary when caching it and registers one process-root
`tree_exiting` cleanup for runtime resource extensions. Cleanup removes live
Resource entries while the scripting runtime is still available, preserving path
strings. Ordinary timeline, scene, and Dialogic-handler removal do not trigger
this cleanup, so runtime speakers remain reusable across playback. No special
case for the name Narrator, manual test cleanup, forced process exit, or suppression
of exit status is used by the fix.

`speaker_lifetime_probe.gd.txt` preserves the small ablation script. Its
`--cleanup` and `--detach-settings` switches are diagnostic controls; neither is
used for the fixed production run. The observed failure is prevented by changing
resource retention lifetime. The exact native crash stack was not captured.

## Verification

- The original named-speaker fixture from `evidence/dialogic_production_skip`
  passed **13/13**, **233 assertions**, and exited **0** with the production fix.
  The fixture was temporarily installed by a `try/finally` probe, then restored
  exactly; the shipped anonymous Skip fixture remains unchanged.
- The combined narrative, Skip, caption, Pause, restore and profile-reset suites
  passed **157/157**, **5,719 assertions**, and exited **0**. Their existing
  addon/GUT orphan and NUL diagnostics remain; no script errors occurred.
- `tests/manual/dialogic_runtime_speaker_probe.gd` passed **66 checks** through
  **six lifecycles**: anonymous, path-registered and unknown speakers, each
  cancelled, restarted and completed naturally. It verifies exact runtime speaker
  reuse and unchanged ProjectSettings, leaves runtime registrations intact for the
  production process-root cleanup, and exits **0**. The registered fixture is
  written only under the required isolated `DWM_TEST_ROOT`.
- Public-surface inventories were regenerated from the final source/test tree and
  remained unchanged. Their validation and documentation gate passed **14/14**,
  **410 assertions**, exit **0**.

An independent source review checked path preservation, repeated registration,
runtime reuse and the process-root lifecycle boundary; no blocker remained.

No GameState, SaveManager, Minesweeper or active dating latency source is changed.
This fixes the separately discovered shutdown bug; it does not complete the
Witnessed transport rail, story authoring, or the broader Beads goal.
