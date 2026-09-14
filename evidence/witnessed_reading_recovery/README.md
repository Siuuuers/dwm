# Witnessed reading preference recovery

2026-09-14; partial `dwm-vky.14` checkpoint, based on
`97b0f6d6cb668ccf13d39e7eb76bac0eea974d15`.

Failed Auto and Skip preference changes now open a separate recovery overlay above
the retained scene. Retry keeps the original explicit target; Cancel preserves the
committed preference. While recovery owns input, dialogue Accept, the rail and
automatic advancement are suspended. Pause covers and restores recovery with a
fresh input generation. Source changes, replacement owners and profile restores
retire the pending command. The retained profile revision and owner generation
also reject a synchronous restore during Retry. The newly current caption receives
keyboard focus after stale recovery is dismissed.

An indeterminate/fatal result exposes restart-required copy with no Retry or
Cancel. This is an inert local presentation, not a completed application-wide
fatal reconciliation or restart flow. No persistence protocol, save schema,
GameState, SaveManager, DatingScene or `dwm-634*` task/implementation is changed.

## Verification

| Check | Observed result |
| --- | --- |
| Final 10 focused and surrounding GUT suites | 148/148 tests; 6,306 assertions; exit 0 |
| Real mounted Dialogic failure/retry cases | Determinate Auto failure, Skip arbitration, Cancel, Pause, source replacement, same-owner restore, reentrant restore and fatal suppression pass |
| Strict catalog validation | Exit 0; matching English, Simplified Chinese and Traditional Chinese keys |
| Recovery presentation matrix | 100%, 125%, 150% across all three locales pass |
| Final mounted synthetic captures | Three 150% renders pass; byte-identical to the visually inspected images |
| Windows UIA final probe | Source label visible before recovery and absent during recovery; one enabled Retry; one native Invoke produces one activation, zero Button.pressed emissions and zero physical contacts; exit 0 |

The Windows probe mounts the production source-canvas script and recovery prefab
over an image captured through the installed Dialogic style. It authenticates the
exact native window handle, PID, title and command line before acting. Its hidden
Recovery instance exists before the source baseline is observed. The receipt and
engine RESULT jointly establish native provider admission and source withdrawal.
They do not prove a real storage Retry, human screen-reader behavior, another OS,
or native source reappearance after dismissal. The latter is checked only as a
cleared GDScript flag. Real profile failure/retry behavior is separately covered
by the mounted GUT tests with injected file-operation failures.

## Accessibility ordering and unsuccessful checks

With the source container hidden, this Godot 4.6.3 Windows provider omitted the
later recovery sibling. Removing the modal flag did not repair it; leaving the
source exposed made both source and recovery available. Placing RecoveryLayer
before Canvas repaired the native probe while preserving source withdrawal.
The production scene uses that order, with CanvasLayer level 3 preserving visual
stacking. The final native run also verifies that an initially hidden recovery
does not hide the ordinary source baseline.

All 23 engine attempts are retained in `runs.jsonl` and their named logs, including
RED failures and unsuccessful probes. Intermediate issues included a test type
warning, a same-frame synthetic press correctly rejected by the fresh-input gate,
Chinese catalog bytes damaged by shell encoding, a missing test-lambda parenthesis,
and a render check that incorrectly expected one center pixel to change. The final
render check compares complete image data while independently preserving source
state. Lifecycle RED tests reproduced missing focus and stale post-restore Retry
before their production fixes. Native probes that lacked an admitted action ended
at their bounded deadline; they are not counted as successes.

The UI literal audit remains exit 1: exactly 19 existing literals in the excluded
DatingScene, with no failure in these new files. Its regenerated evidence remains
honest about that limitation. The public GameState inventory only refreshes call
locations and the new test references; its required contracts are unchanged.
Existing Unicode NUL diagnostics and Dialogic orphan reports remain in the logs;
the final GUT batch reports 2,016 orphans. This is not a warning-free or leak-free
claim. Archived logs normalize trailing whitespace and final newlines only.

`source-sha256.json` records the implemented source, test and helper bytes.
`dwm-vky.14` stays in progress: session History, Backup Save/Load, exact-variant Next,
shared primary speech and broader recovery acceptance remain separate work.
