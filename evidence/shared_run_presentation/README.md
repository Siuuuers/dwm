# Shared run presentation

`dwm-vky.8`, 2026-09-13. Source base: `4f9684caaea0d5e73514536673d8934d200f74c3`.

Settings, Backup and Pause now use the installed run's captured palette and day. Their existing theme roles receive the authored High Contrast/CVD tuple and week tint. Day 1 remains exact; High Contrast has zero tint; CVD tint preserves hue/chroma. Title Settings retains its Day 1 pending-mode preview, and title Backup retains its existing Day 1 default.

Backup appearance changes use the retained record projection. They do not inspect save files or prepare, cancel or commit an action. A pending confirmation or operation defers the new appearance until its existing completion/cancellation boundary. Unchanged context does not rebuild the view. No gameplay, save schema, checkpoint or Minesweeper latency source changed.

## Verification

The final isolated Godot 4.6.3 run passes **59/59 tests, 11,768 assertions, nine suites** (`shared-run-presentation-verified-20260913.log`):

- All sixteen palette/accessibility tuples across seven days: exact Day 1 colors, protected roles, CVD behavior, text and state contrast, invalid-context rejection.
- Actual Settings controls and shared Pause hosts: captured palette independent of next-run intent, title preview, live accessibility, focus and custody.
- Actual Desktop `open_app` routes after a Day 6 restored host and Day 7 eviction, plus production Pause reopening with current day and captured palette.
- Backup preparation survives appearance updates and still commits or cancels normally without additional appearance-driven projection reads.

The standalone Backup UI regression passes **3,872 checks** (`backup-ui-presentation-verified-20260913.log`). Its save/load/delete/confirmation/retry, selection/scroll, locale/size, cache eviction and title-login checks all execute. The separate operations suite emits `BACKUP_OPERATIONS_PASS`. Independent read-only review found no remaining correctness defect after adding the Desktop route test.

All engine invocations used `Invoke-IsolatedGodot.ps1`, with isolated APPDATA, LOCALAPPDATA and DWM_TEST_ROOT. `runs.jsonl` records terminal status and exact arguments. The native run retained its isolated root for capture. No player storage was used.

## Native samples

Six inspected 640×360 Windows/OpenGL3 captures pass **78 checks**, using real SettingsApp, PauseSurface, BackupApp and shared confirmation controls. They show Day 1 AfterHours, Day 7 Midnight, Pause-hosted Settings, Backup, a retained confirmation during an appearance change, and High Contrast after Cancel. Layout, readable copy and focus marks remain coherent. The isolated port's records remain unchanged; one explicit Cancel releases the prepared token.

`summary.json` records the native sample scope and measurements; `native-probe.gd.txt` preserves the probe. These English 100% samples are representative, not a full native locale/scale matrix or physical-device/assistive-technology acceptance. Day restoration tests exercise already-restored owners and routes, not a new end-to-end disk Load gesture.

## Failed attempts and fixture corrections

Earlier logs are retained. The first Backup test had an inferred-type parse error, then passed after correction. The first combined invocation used three wrong suite paths; the wrapper rejected the missing executions. The corrected invocation exposed stale Settings assertions forbidding the already-shipped next-run Dark row. The unchanged HEAD test file reproduced three of four failures against this implementation; the fixture now follows amendment Section 5.3 while retaining role, persistence and captured-palette independence checks. This was a retained-test comparison, not a pristine-checkout baseline run.

The new Desktop test initially lacked initialized isolated Settings owners; it now injects them before child readiness while retaining the real opening path. The older Backup UI fixture initially hit `run_configuration_unavailable`; it now installs its explicit captured run and bypasses only the player bootstrap. An intermediate fixture incorrectly looked for the dynamically mounted Desktop before readiness, causing a null-instance script error; that isolated engine process was terminated and the fixture corrected to bind at `child_entered_tree`. Direct fake record mutations now explicitly publish a refresh instead of relying on an accessibility change to inspect records. No production admission guard was relaxed.

Final successful logs have no script errors. Existing Unexpected NUL character diagnostics and the GUT suite's 24 Dialogic orphans remain; this increment does not claim to fix them. The broader UI amendment, other palette owners and concurrent `dwm-634.2` clicking-lag work remain separate and unfinished.
