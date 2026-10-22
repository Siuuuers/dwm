# Run39262225003 — failed preflight, no native timing outcome

[Original run](https://github.com/Siuuuers/dwm/actions/runs/39262225003), job118092558755, controller34abf2cdd8f7dd8bd03e91fdccd90d68b047495f/tree8a1d34f7a9653efe67589de1f005743063482d5f. Installed exact reviewed workflow blob4090fdc6 once after C6268583165; no extra dispatch. The run is terminal failure.

Both checkouts, source/evidence custody and retained Corrected package download passed. The focused Python suite ran27 tests:26 passed, one failed (the backslash subcase in test_unsafe_and_colliding_archives). Godot installation, overlay application/PowerShell parse, export, smoke, Capability/Create/Load all skipped. The final outcome gate correctly reports missing player results. This is not a Title causal negative or native acceptance; no phase timeline exists and the Title cause remains inconclusive.

## Original evidence

`original.zip` is the untouched downloaded Actions artifact12189998709:2151 bytes, SHA-256 `25c2fe98da1ba1ec4e53ebd7590dfd5b0eda582465bb2141b5e58803c343e139`. ZIP CRC succeeds; all3 payload manifest entries verify (four total members including manifest). `verification.json` records checks. `terminal-jobs.json` records step outcomes. `job.log` is the connector-decoded job log normalized to LF, not a claim of original downloadable log ZIP bytes. Prior paired archives and failed results are untouched.

## Concrete cause and smallest proposal

Cloud error: test_unsafe_and_colliding_archives requested an `x\\y` member and expected extraction to raise ValueError; Windows observed no exception. Python ZipInfo normalizes os.sep to `/` in its filename field. The fixture writer therefore writes an ordinary `x/y` member on Windows.

Offline controlled separator emulation also exposes a second issue: a crafted raw backslash member is normalized again by the reader, while `orig_filename` retains the raw name. The extractor currently validates `entry.filename`, so it misses its intended raw-backslash rejection on Windows. This is a diagnostic package validation-rule bypass, not demonstrated directory traversal or a game/save defect. A focused independent helper reproduced both writer and reader behavior read-only.

Smallest correction proposal: validate `entry.orig_filename`, reject normalization differences before extraction, and construct the negative fixture with an actual raw backslash in both ZIP name headers. Add a regression covering reader normalization as well as the fixture writer. Keep the strict path rule, package hashes and outcome gates; do not simply remove the failing test. `reproduce_name_normalization.py` reproduces `fixture-diagnosis.json` using the published source/new-title-tools directory as its argument. It is offline Python emulation, not a second Windows run.

No patch/controller revision or automatic retry is included. Director/C's explicit single-run stop applies even at preflight. Next C/Director can review this concrete diagnosis and decide the bounded tooling correction/retry scope. No conclusion about checkpoint latency, menu readiness or UIA can be drawn from this run. Product runtime, master and integration unchanged; no engine promotion/merge/release.
