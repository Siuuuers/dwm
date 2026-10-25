# Reading configuration and Replay acceptance — 26 October 2026

Product candidate: `4f1698ed39e41508e7559fb7e35066491c1d0cbf`, PR #104.
Cloud correctness run: https://github.com/Siuuuers/dwm/actions/runs/40223513652

The connected passage suite passed all three fresh-process phases: creation (42 assertions),
Load/finish-failure/retry (67 assertions), and Gallery Replay (79 assertions). Replay checks
actual displayed read marks, cancellation before Next, unseen captions, language changes via
the canonical presentation owner, physical Profile-write refusal and Retry, unchanged Run and
autosave, and loading an earlier Run without erasing global Gallery discovery.

The coordinator visually reviewed the Gallery selection and both Replay caption screenshots.
The expected first and last fixture text and controls are visible without clipping. This is a
focused fixture journey, not a review of all authored passages or every locale's layout.

`connected-replay.zip` is the complete original cloud artifact `12610602225` (166,827 bytes),
SHA-256 `2b986f2ea5712c1aa3137c9a1eabe8581580d383aba154bd8b1748555945de49`.
It retains logs, JUnit/acceptance records, proof JSON and screenshots; no profile/save directory
or executable package is included. The downloaded ZIP hash was checked before inspection.

The full run passed: 50 successful jobs and one intentionally skipped separate measurement job.
One slow runner timed out in preliminary user-directory proof before save-metadata tests ran;
its single-job retry passed with unchanged code and limits (run attempt 2). PR #104 merged as
`8b8e73929801a9527872b1485a289a1ffca6e5a8`. Runtime source is unchanged from the measured candidates.
Performance evidence is separate: see `../reading_configuration_20261026/README.md` and
`../reading_load_20261026/README.md`. No content-update save migration is claimed here.
