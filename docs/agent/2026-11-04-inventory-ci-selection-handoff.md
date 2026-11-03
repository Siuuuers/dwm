# Focused inventory-tooling CI selection handoff

Date: 2026-11-04
Repository: Siuuuers/dwm
Status: planning only. This document changes no CI behavior.

## Observable outcome

An inventory-tooling-only PR runs source lint, the inventory tooling tests,
project import and both read-only API inventory checks without selecting unrelated
gameplay, rendering, audio or export jobs. A mixed tooling/gameplay PR retains
both tooling checks and the coverage required by its gameplay changes.

Use the existing coverage selectors and workflow owners. Do not create a general
dependency graph or a second test-selection system.

## Evidence to preserve

Merged PR #184 made inventories insensitive to comment and line shifts.
Merged PR #191 removed redundant generation during normal PR checks.
Neither changed broad suite selection.

The current record at
[read-only inventory acceptance](2026-11-04-inventory-preflight-efficiency.md)
reports that cleanup PRs #186, #188 and #189 selected full validation, whose
default Windows matrix has 67 suite entries plus other jobs.

Its measured PR #188 authoring job took 495.31 seconds, including 230.67 seconds
of checkout and about 22.98 seconds of import. The separate selector took only
7.20 seconds. Those are historical measurements, not a new benchmark or a
promised speedup. Do not optimize the small selector checkout again without
new evidence.

## First implementation slice

Inspect current master, repository instructions, open PRs and the complete
workflow dependency chains before editing.

Primary inspection paths:

- .github/workflows/windows-tests.yml
- .github/workflows/dtl-first-preflight.yml
- .github/workflows/source-lint.yml
- tools/testing/test_windows_coverage.py
- tools/testing/Invoke-PublicSurfaceValidation.ps1
- tools/runtime/PublicSurfaceInventory.gd
- tools/runtime/generate_public_surface_inventory.gd
- tests/unit/tooling/test_public_surface_inventory.gd
- Existing preflight regression tests introduced by PR #191.
- Both committed public inventories and required-symbol manifests under
  evidence/phase_2r/runtime/.

Audit every consumer of selector outputs, including aggregate jobs and independent
workflows. A narrow selector in one workflow must not leave another workflow
launching the same unrelated matrix.

Define one explicit inventory-tooling classification with a small audited path
set. An inventory implementation file or its focused test must be present;
documentation or generated output alone must not imply tooling-only scope.
Include companion documentation and generated inventories only where justified.

Do not exempt whole tools/, tests/, evidence/ or workflow directories.
Required-symbol manifest changes alter contracts and need their appropriate
validation; do not silently classify them as cosmetic. Generic runner/workflow
changes must retain existing fallback coverage unless their scope is independently
established. A file being in a proposed allowlist is not permission to ignore its
actual responsibilities.

Normal PR acceptance must remain read-only. Preserve PR #191's explicit
regeneration mode, stale-output failure, error-log checks and both targets.
Source lint and focused selector tests must always run when their own files change.

Emit a short selection summary: classification, relevant changed paths, selected
checks, skipped groups and reason. Prefer the existing log or job summary;
do not create another committed generated report.

## Focused acceptance

Use tests against the actual selector/workflow logic, not a duplicate mock
implementation of the predicate.

| Change fixture | Required result |
|---|---|
| Inventory scanner or generator only | Focused tooling, import and both inventory checks |
| Inventory tooling test only | Tooling test actually executes |
| Tooling plus its legitimate generated output | Same relevant tooling validation |
| Tooling plus GameState or SaveManager behavior | Tooling checks plus existing relevant runtime coverage |
| Tooling plus scene, authored DTL or audio change | Retain the relevant existing non-tooling coverage |
| Unclassified file or unavailable comparison base | Explicit existing conservative fallback |
| Deleted or renamed relevant file | Inspect old and new paths; no silent loss of coverage |
| Selector/workflow changes | Selector regression and workflow validation; no blanket shortcut |
| Stale inventory | Failure without rewriting the committed output |
| Successful or failed narrow checks | Aggregates reflect actual execution; no false green from skipped dependencies |

Test the supported PR, push and manual-dispatch event paths. Preserve explicit
full/manual validation. Compare the intended PR change range rather than including
unrelated commits from an advancing base.

Run existing selector and preflight tests, Python syntax/comment lint and workflow
validation. Exercise one actual inventory-tooling-only cloud run on the final
candidate to establish import, focused tests and both inventory checks really
execute and unrelated jobs are skipped. Verify mixed-change selection with
representative fixtures; a full-game run is not required just to prove selection.

Record selected job names and available setup/execution/total timings from the
same run. Retrieve all pages if making aggregate job-count or time claims.
Do not equate summed job time with wall time or estimate runtime speed from code size.

## Boundaries and follow-up

No runtime code deletion or renaming, save changes, audio changes, TLA+ changes,
new dependencies, repository-wide lint rules, or general CI redesign. The separate
audio session retains audio ownership.

Keep shared workflow edits with one coordinator. Reconcile old handoff PRs #183
and #185 with their landed implementation links separately; their open status does
not mean their runtime missions are unfinished.

After this slice lands, use its measured run to choose whether full-checkout
payload reduction or another narrow coverage class is the next worthwhile change.
Do not commit to either before confirming remaining cost.

## Starter prompt

Implement this handoff on current master after checking open work and repository
instructions. Add the smallest exact inventory-tooling classification to the
existing CI selection flow, preserve mixed-change coverage and read-only inventory
acceptance, test the real selector, and verify one focused cloud run. Open a
separate implementation PR. Report selected/skipped checks, measurements and
limitations; this documentation PR is not implementation acceptance.
