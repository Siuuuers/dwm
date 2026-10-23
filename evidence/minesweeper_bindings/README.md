# Minesweeper binding verification

[summary.json](summary.json) records the final combined test counts, exact tested
source hashes and Git blobs. [invocations.jsonl](invocations.jsonl) and `logs/`
retain all isolated runs, including the initial failures. Logs are normalized to
UTF-8/LF; the summary also records the original log byte hashes.

The regression evidence covers real Profile/InputManager binding publication,
focused Grid and cached Desktop/App input routing, simultaneous/held contacts,
Pause and processing boundaries, the real Rules sheet, and Controls capture in
an embedded Window. These are engine event-routing tests, not a claim of testing
every physical keyboard/controller model. Existing UI/input/save suites run on
the same source candidate. There are no new typography or GPU captures.

Initial failures identified a disabled grid retaining focus and a parent contact
whose release was consumed in Controls capture. Both have production fixes and
regressions. Fixture corrections supplied canonical physical-only rebind records,
used supported unmodified bindings, and allowed Desktop's initial deferred focus
to settle before launcher activation. They did not remove the behavior checks.

Certificate-store and fixture orphan diagnostics remain in the logs. This is not
leak-free acceptance. All tests use isolated user directories; Profile fixtures
use memory storage. Existing generated files and protected dirty worktrees remain
outside the checkpoint. Full Controls, Minesweeper and all-ten-family UI completion
are not claimed. No merge or push occurred.
