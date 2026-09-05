# Cold title resume verification

Run `python tools/title_resume/verify.py` when production and its observer are
ready. This thin wrapper reuses the isolated full-startup runner. It imports once,
starts a seed process, waits for its successful exit, then starts a separate
resume process with the same APPDATA and user directory. Both run the original
production startup and main scene with a first, path-guarding observer.

The seed process checks title Backup with empty storage, creates a run through
New Account and opening Continue, applies a registered money effect through the
real transaction owner, and saves through Backup. The fresh process checks title
navigation and resumes that durable slot through Log in, then waits for the
actual ready Main scene and compares saved progress and usable Backup state.
An invalid document is briefly written to a separate unused isolated slot to
verify that corrupt records cannot Load, then removed before resuming slot 1.
The resume phase also changes only whitespace in isolated slot 1 after preparing
Delete, verifies stale rejection and title input custody, restores the original
bytes, and checks that one Escape cancels recovery while a second closes Backup.
Ordinary title Load is direct; this test does not require a replace-progress
confirmation when no live run exists. Test expectations and process IDs are
stored only under the already proven isolated root.

Both phases require their own success marker and no unexpected engine errors.
The shared runner retains the strict inherited-shutdown comparison, full logs,
source hashes, original/executed project settings and exact temporary changes.
It requires 500 MiB free before copying and removes only its verified copied
project/import cache after exit. Receipts remain here in `evidence/`; isolated
user data remains in `.godot/title-resume-*` for inspection.
