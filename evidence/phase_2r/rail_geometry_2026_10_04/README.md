# Reading-control rail geometry — 4 October 2026

The source-bound [receipt](receipt.json) owns final acceptance status. Godot and
PowerShell execution took place only in GitHub Actions.

Both Simplified and Traditional Chinese at 150% exposed a shared height defect:
buttons required 68 pixels inside a 64-pixel strip. Full labels fit horizontally.
Forced text reshaping did not change the captured RGB pixels. The fix preserves
requested font selection and size, reduces vertical margins, and restores each
button to its fixed bay after projection.

The [source review](source-review.md) and [diagnostic measurements](diagnostic-summary.json)
record hypotheses, before/after geometry and source identities. The
[render verification](final-render-verification.json) records final captures.
The [test summary](test-summary.json) counts actual primary testcase elements;
two deliberate storage-refusal negative controls are excluded and retained separately.

`test-evidence.tar.gz` contains raw primary XML, negative controls, diagnostic and
render results/logs, selected screenshots and Windows native invocation records.
[archive-manifest.json](archive-manifest.json) records every member hash plus the
archive hash. Cloud metadata records the source, jobs and expiring artifact origins;
the retained archive does not depend on those artifact download links remaining live.

This bounded correction does not complete production caption, whole screen-reader
or native review-current acceptance. Master and all unfinished Beads statuses and
dependencies remain unchanged; this is not a live Dolt synchronization.
