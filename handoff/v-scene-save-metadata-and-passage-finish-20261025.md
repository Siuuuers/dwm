# Scene saves and passage Finish — 25 October 2026

## Start here

1. Read `AGENTS.md` and `CLAUDE.md`.
2. Read [the save design](../docs/design/2026-10-25-save-load-validator-audit.md).
3. Check the current `master` commit on GitHub.
4. Check the merge state and final cloud result for [PR #95](https://github.com/Siuuuers/dwm/pull/95).
5. Continue from current `master`.

This record uses short sentences and direct instructions in ASD-STE100 style.
Code names are technical terms.
The [official Issue 9](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf) is the language reference.

## Completed changes

[PR #93](https://github.com/Siuuuers/dwm/pull/93) removed three fields from current Scene saves:

- `save_reason`
- `audio_context`
- `active_app_id`

Load derives audio from the installed Scene registration and the current entry.
A registration without audio restores the complete silent context.
Load opens Minesweeper when the saved board must be visible.
Other open windows do not define player progress.
Legacy calendar saves keep their previous contract.

[PR #94](https://github.com/Siuuuers/dwm/pull/94) added paired passage markers.
The start marker has no effect on progress.
The finish marker unlocks Gallery and saves completion.
The game then returns to title automatically.
Load of a completed passage also returns to title.
Gallery replays the passage without changes to Run or Profile data.

The marker tests use temporary dialogue.
Production Day 7 text and marker positions are unchanged.
The current contract permits one linear passage in each Scene entry.
Registration rejects native jumps and controls inside that passage.

## Finish failures

Profile owns the global Gallery record.
Finish writes Profile before it writes Run.
If the Profile write fails, the game keeps the last caption without an unlock.
If the Run write fails, the game keeps the last caption with the global unlock.
The Retry command repeats the operation safely.
The game returns to title only after the completion save succeeds.

Next and normal Accept use the same Finish command path.
Cloud tests found an earlier Next path that did not dispatch Finish.
The corrected candidate passed the complete cloud run.

## Optional save time

PR #95 makes `saved_time` optional for current Scene saves.
Check that PR for final acceptance and merge evidence.
A valid timestamp remains available for Backup display.
A missing or invalid timestamp becomes unknown.
The game does not substitute the current clock time.

`SaveDocumentSchema.normalize_optional_saved_time` owns this conversion.
Initial creation, retained operation checks, and Backup use the same rule.
Retained operations keep their original bytes, hashes, and request fingerprints.
Required progress checks remain active.
Legacy timestamp admission remains strict.

## Cloud evidence

| Change | Accepted evidence |
| --- | --- |
| PR #93 | [Run 40171218473](https://github.com/Siuuuers/dwm/actions/runs/40171218473): 42 successful jobs. |
| PR #94 | [Run 40172781985](https://github.com/Siuuuers/dwm/actions/runs/40172781985): 44 successful jobs. |
| Passage journey | Three processes, 135 assertions, and inspected screenshots. Artifact `12591560085`. |
| Passage catalogue | Six passing cases. Artifact `12591475412`. |
| PR #95 | Use the final head and cloud run in the PR description. |

The historical timing comparison was intentionally skipped.
No timing result proves a speed improvement.
No local Godot test qualifies these changes.

## Next task: replace saved command receipts

Current Scene saves still contain `command_receipts`.
These receipts still support active Challenge state, recalls, control retries, and Contacts returns.
Do not remove their checks without replacement state for these consumers.
Do not add invented receipts to satisfy an old validator.

The user requires Contacts support.
Production currently has no authored Contacts entries.
Keep the existing Contacts tests when the save format changes.

1. Start with one complete player journey.
2. List each remaining reader of saved command receipts.
3. Identify the current facts that each reader needs.
4. Give each fact one owner.
5. Separate live retry data from saved player progress.
6. Restore current facts without past gameplay actions.
7. Remove the old ledger only after the replacement passes cloud tests.

Test the same full caption, active board, later branch, and Contacts return.
Test that Load does not repeat a purchase, charge, or reward.
Keep global read history and Gallery records when an older Run loads.
Keep safe file writes and exact selected-source checks.

## Limits and decisions

The user permits reviewed PR merges after cloud tests pass.
Use parallel agents for independent work.
Use one coordinator for shared files and publication.
Measure complete Save and Load operations before a performance claim.
Do not add old-save migration without a concrete requirement.
Do not choose new dialogue, fork rules, or production passage positions during save cleanup.

The previous [History handoff](u-compact-reading-and-current-day-history-20261025.md) explains the compact reading position.
History reconstructs the current day's passage from current position, choices, and Challenge outcomes.
History display rows are not evidence for gameplay command admission.
