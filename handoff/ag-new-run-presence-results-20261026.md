# AG: New Acc presence check

Date: 2026-10-26, Hong Kong.
Writing reference: [ASD-STE100, Issue 9](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf).

## Result

[PR #112](https://github.com/Siuuuers/dwm/pull/112) is merged.
Master commit: `a5ecd04ecb2724aaaf8c7462aa2b41e9f895ccc5`.
Tested commit: `60e1d47484fc33073935d6e5e1ba05cceb2a48d5`.
Both commits have the same tree.

Windows test result: 61 passed; one intentional skip.
The final comparison passed all 24 processes.
The leak and error checks passed.

New Acc now checks whether an unfinished run exists.
It no longer copies or hashes that run for consent.
GameState owns this fact.
SaveManager reads it through RunRestoreParticipant.
The legacy path still uses the full hash.

An installed PLAYING or ENDING run requires consent.
A raw menu route does not abandon that run.
Logout retires the run without a save.
A completed run does not require consent.

The preparation step saves approximately 1 ms.
The two batches do not show a reliable decrease in whole-action time.
This change does not explain the remaining long frame.

| Preparation case | Baseline median | Candidate median |
|---|---:|---:|
| Fresh New Acc | 1.315 ms | 0.325 ms |
| Retained New Acc | 1.177 ms | 0.151 ms |

Do not spend more time on this hash without new evidence.

## Next task

Find the cause of the remaining long frame before another product change.

1. Read AGENTS.md and CLAUDE.md.
2. Check current master and open pull requests.
3. Use merged master as the comparison baseline.
4. Measure SaveManager._start_scene_new_run_in_memory.
5. Measure SaveManager._prepare_scene_new_run_plans.
6. Record route confirmation, narrative confirmation, and live_session_ready times.
7. Compare these times with the longest frame.
8. Select one measured cost for the next change.

Use the same observer for both builds.
Do not add waits or polling to the observer.
Do not add overlapping phase times.
Keep the whole-action measurements and leak checks.

Do not bypass Profile restoration before you measure its cost.
Include Profile preparation, apply, and finalize in that measurement.
If you change Profile restoration, test settings, read history, and unlocks.
Include key bindings, window mode, locale, font, and audio in those tests.

## Test boundary

The tests cover the normal rendered New Acc and Logout journeys.
The raw-menu case tests the save owner directly.
Its earlier native-click test did not show a confirmation sheet.
The cause of that click result remains unknown.
This work does not establish native UI behavior after a raw menu route.

## User instructions

Use cloud runners for Godot tests.
Do not run Godot on the local computer.
Local source checks and Python analysis are permitted.
Keep existing save files and global progress.
Keep Logout unsaved.
Do not add repeated checks of approved game content.
Do not add checks for failures without evidence.

The user permits parallel agents and direct merges of verified changes.
Use one coordinator for shared files and publication.
Use one change for each performance comparison.
Ask for a design decision only when that decision blocks the work.
Use ASD-STE100 for new handoff documents.

## Project terms

| Term | Meaning |
|---|---|
| Baseline | The code used for comparison. |
| Candidate | The code under test. |
| Hash | A value that represents source data. |
| Raw menu route | SceneRouter.goto_menu() without Logout. |
| Profile | The owner of settings and global progress. |
| Observer | Code that records times and results for a test. |

## References

- [Results and evidence](../evidence/phase_2r/new_run_presence_20261026/README.md).
- [Previous handoff](https://github.com/Siuuuers/dwm/blob/87f4a1b882ff9ac4cc438846ed508e737c2e98df/handoff/af-in-memory-new-run-results-20261026.md).

A new session can start with the next task above.
No repeat design interview is necessary.
