# Title clock, navigation and Shut down

The title has a persistent strip at logical `(320,0,960,64)`. Its routine local
clock remains visible whether the workfield is empty, Backup is open, or the
existing Settings panel is open. Return and the destination title appear only
while a surface is hosted. Missing optional artwork remains intentionally absent.

`RoutineClock` is a small read-only Label with tabular digits and a one-shot
timer. It shows local `HH:MM`, schedules the next minute boundary, suspends reads
when the application loses focus and refreshes on return. Invalid/unavailable
time becomes `--:--` with a localized accessibility description. The clock owns
no gameplay state, saved timestamps, anomaly allocation or live announcements.
The existing desktop clock is unchanged.

Visible title rows have explicit Up/Down traversal with no endpoint wrapping.
Tab cycles the unhosted ledger; a visible Return provides a declared bridge into
the hosted content. Switching Backup to Settings replaces Return's focus paths,
so keyboard navigation cannot enter the hidden Backup tree. Closing or returning
from Settings restores its initiating row and its cached panel reopens visibly.

Shut down now uses the existing trusted confirmation sheet. Its neutral variant
has no Warning glyph, reserved Warning gap or governing Warning edge. Cancel
receives initial focus, Escape cancels one layer and returns focus to Shut down,
and only explicit confirmation calls the existing quit operation. Backup's
default Warning confirmations retain their original behavior. Modal/recovery
input masks do not rewrite the underlying title commands as Disabled.

Run `python tools/title_shell/verify.py` for focused actual Menu/controller,
clock and shared-sheet tests with fake locale/profile and external command
counters. Only the process-quit seam is overridden, so confirmation can be tested
without terminating the test driver. Run `python tools/title_resume/verify.py`
for the real production two-process save/resume regression with title shutdown
cancellation and hosted Settings navigation. `python tools/backup_ui/verify.py`
checks the unchanged default sheet and title/in-run Backup matrices.

[Final verification](result.json) records 326 passing title-shell checks, 103
passing production restart-flow checks, 3,870 passing Backup UI checks, and the
passing clock component suite. Every listed source binding matches the final
files. [Independent review](review.md) found no remaining material issue in the
bounded scope. Raw receipts and logs retain their exact verification limits.

Scope remains the existing fresh-title commands. Dark entitlement, New Acc
replacement policy, Gallery hosting, title artwork, the larger Settings redesign
and full UI-00/UI-00R cutover remain separate work. These headless geometry/input
checks do not certify physical devices, GPU raster appearance, or a palette matte
at every aspect ratio. Inherited shutdown diagnostics are retained under the
existing exact observer-free comparison; no leak-free shutdown claim is made.

All changes are uncommitted in `contacts-ui-build`. Tests use disposable storage;
actual player saves, unrelated worktrees, refs and Beads are untouched.
