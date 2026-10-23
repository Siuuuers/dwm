# Windows raw-name preflight correction — ready for external C review

Director authorization: https://github.com/Siuuuers/dwm/pull/30#issuecomment-6268770485

Exact corrected source commit: `5399e8a90d192b2f4ab4dfde56ad77f17c45b461`, tree `e3a4d517ca4fad9239c6250f8f1780294838f4b5`. Only package_timing.py and test_package_timing.py change in that commit. controller.yml changes only the two occurrences of the tool-source commit. It is prepared, NOT installed. PR30 remains 34abf2cdd8f7dd8bd03e91fdccd90d68b047495f.

The extractor checks ZipInfo.orig_filename against unchanged safe_name rules and requires exact equality with filename before extraction. The malformed fixture sets the raw names after ZipInfo construction and verifies the names read from the resulting archive. A new reader-normalization regression checks backslash conversion and NUL truncation, and proves extraction is not called. Existing valid package, collision, path, SDK, PCK and smoke checks remain.

28 Python preparation tests pass: 8 game, 10 harness, 10 package. No local Godot/PowerShell execution. An initial local full-suite attempt caught an extra newline introduced while materializing reference files; correcting the local copies to their pinned hashes restored both source checks without repository source changes. Windows preflight is still required.

Reuse C6268583165 for unchanged timing/game/harness files. External Coordinator C must review this concrete correction and changed pins before the ONE corrected retry authorized by Director6268770485. Internal preparation tests do not replace that external review. Then reconcile live heads, active/queued runs and artifact12184205891 availability; install the exact controller once. Preserve 30s/480s, original gates, reused EXE/new PCK custody, no engine rebuild or Baseline repeat. Stop after that retry with retained outcome and smallest supported proposal; missing anchors remain inconclusive.

Original run39262225003 failure and archive remain unchanged. No Title timeline or native acceptance exists from that run. Master was rechecked at 0c8b2384415d71bd3de4ff7408640bbf60b63740, matching the recorded baseline; no related repair is integrated there. Product runtime and save/recovery/history owners are unchanged. No merge/release/master/integration change.
