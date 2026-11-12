# Focused selection for public-surface CI edits

Base: `9e120d04bd7a003335598c1c9a37ef2fa708d960` (PR #299).
Outcome: a public-surfaces job edit with its selector regression and reviewed audit
note selects `public-surfaces` and `test-scope`, without unrelated game jobs.
Owner: the existing test-scope selector in windows-tests.yml.

## Cause and smallest change

PR #299 ran the full fallback for two reasons: its companion agent note was not
allowed in the CI-only path set, and public-surfaces was not a recognized owner
block. Reuse the existing reviewed-prose predicate and exclusions, and add this
job to the existing block comparison. Companion prose still receives whitespace
validation. Add the explicit public-surfaces condition so the selected job runs.
No new job, dependency, source download, package or gameplay behavior is introduced.

Scope: workflow selector, public-surfaces condition, existing selector tests and
this report. Other job gates already suppress unrelated jobs for nonempty ci_jobs.
Independent read-only review checked the downstream conditions and fallback paths.

## Focused evidence

- `python tools/testing/test_windows_coverage.py`: 49 tests pass, including PR/push
  owner selection, reviewed companion prose, whitespace failure, docs-only,
  shared-workflow changes, unrelated runtime files and missing-base/source cases.
- Replay actual PR #299 source blobs and changed paths from `0c138db` to `9e120d0`
  through the candidate selector: exactly `["public-surfaces", "test-scope"]`;
  docs_only and inventory_tooling false, prose whitespace command observed.
- Replay this selector edit against its base: ci_jobs remains empty, correctly
  retaining broad fallback for changes to shared selection logic.
- actionlint 1.7.12 passes (same pinned binary/checksum as source-lint).
- `git diff --check` passes.

The initial test edit placed one assertion in the wrong test; corrected before
final verification. No production defect was inferred from that test-edit error.

Publication skips automatic broad CI for this shared-selector change after focused
local checks. No new Godot, Windows native, rendering, export or whole-game run is
claimed. PR #299 already passed the affected public-surfaces Windows job; this PR
changes which job is selected, not its contents. No execution-time or gameplay
speedup is claimed. Future matching job-only changes use the narrower selection;
shared workflow and unrelated runtime edits retain their existing broader checks.
