# Skip hidden Settings departure refresh and repeated Computer state

Base: master `45e852f45df2e1a9e3178e8bfb6cfc35c83175be` (PR286).

Outcome: Settings closes with the same preview cleanup and focus restoration, without refreshing its hidden controls. Repeated Computer state publication does not rebuild unchanged presentation.

Two runtime lines implement the change:

- `SceneHost.set_computer_open` returns if its owned state is unchanged. Content visibility, busy controls and preference/localization updates have their own owners and update paths. Retain the first bootstrap open publication for held-caption/error recovery.
- `SettingsPanelController.depart` performs all existing detach, cancellation and await operations; it refreshes only if the content is still valid and currently visible. A reopen during cleanup is evaluated after the await. Normal show refresh remains. Hidden bind initialization remains, preserving the correct theme before first display.

## Investigation and measurement

Godot 4.6.3, headless Linux, English, instant reading. Fresh profile in each process, authored Day1 new game, Settings first (also constructs Computer), then alternating Settings and Computer three times. Both revisions used the identical probe. Two baseline processes followed by two candidate processes. Open/close samples include the existing click helper's frame waits; startup and route preparation are excluded.

Diagnostic wrappers measured repeated Computer setters around 0.7–2.1 ms each. First hidden Settings initialization took 198–213 ms and the immediate visible refresh 38–44 ms. Hidden departure refresh alone cost about 38–46 ms. These instrumented diagnostics are separate from the matched totals below.

| Action | Baseline median | Candidate median |
| --- | ---: | ---: |
| Settings close (6 each) | 76.803 ms | 38.703 ms |
| Warm Computer open (6 each) | 15.707 ms | 14.470 ms |
| Computer close (6 each) | 18.521 ms | 18.418 ms |
| Settings reopen (4 each) | 56.498 ms | 60.952 ms |

Settings close improved about 38.1 ms (50%) in this sample. Computer opening changed only slightly. No Settings opening improvement is established: first openings were 496/515 ms baseline versus 483/554 ms candidate, including first Computer construction. Reopen measurements were noisier and slightly slower. Do not present these headless numbers as rendered Windows smoothness or as a general opening speedup.

## Focused validation

- Scene host controls: 6 tests, 40 assertions. Includes unchanged-state presentation counter, mount switching and existing close-focus restoration/refused callbacks.
- Settings panel: 4 tests, 62 assertions. Includes no hidden departure refresh, current committed values on reopen and physical preview cancellation without committing.
- Scene desktop consumer: 13 tests, 183 assertions. Retains first-ready theme and reuse on first show/reopen.
- Live settings audio: 5 tests, 76 assertions.
- Delayed sample cleanup: 1 test, 48 assertions from `test_settings_host_geometry`; input and reopen remain blocked until cleanup completes.
- Two candidate authored Day1 probes: 52 assertions each; actual viewport open/close, current preference, caption admission restored and unchanged reading history.

Total final acceptance: 513 assertions. All passed, no engine errors. `git diff --check` passed. Independent review found no blocker. Baseline measurement and diagnostic runs also passed; they are not included in the final acceptance total.

Evidence and reproduction: `tools/player_latency/evidence/2026-11-12-settings-departure/`. Copy `probe.gd.txt` to `.godot/ci/settings-open/probe.gd` and runners to that scratch folder; run `python .godot/ci/settings-open/run.py fresh-label` from the repository. Use a fresh label per pair. `profile.py` temporarily instruments both methods and restores source in `finally`; its original diagnostics preceded the close-timing addition to the probe. The first exploratory probe used the wrong desktop cache field; it was corrected before the archived matched runs.

Skipped: full language/font matrix, full-week story, save-format suites, rendered/Windows testing and new lint rules. Existing behavior tests are the precise regression checks. No dependencies, caches, save changes or initial-theme changes.

Next investigation: split first Settings initialization into theme construction and repeated control/layout work. Its hundreds of milliseconds remain; do not remove required first-ready setup merely to move the work later.
