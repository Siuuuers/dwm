# Divergent proposal disposition — 23 October 2026

Read-only audit against current playable source `5eee8406f4c2c466ac05d03c489c7cdd1cbc1164` (the documentation descendant of runtime `82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc`). PR metadata and changed-file lists were fetched live. Existing and absent paths were compared using Git tree blob IDs; the accompanying `proposal-blobs.json` retains exact heads and per-file values. No engine execution or PR closure occurred.

| PR | Exact existing files | Absent in both | Evolved files | Missing from current | Disposition |
|---|---:|---:|---:|---:|---|
| #8 | 3 | 0 | 2 | 0 | Three exact files. Rules now extract shared counts-only validation; two additional rule tests cover it. Original catalogue validation delegates to that seam. Static review only. |
| #9 | 9 | 0 | 8 | 0 | Nine exact files; state/schema/shop owners, restore tests and generated inventories evolved. No wholesale merge or complete behavioral equivalence claim. |
| #11 | 3 | 0 | 0 | 0 | All three proposal files match exactly. No source reapplication needed. |
| #12 | 15 | 8 | 2 | 0 | Fifteen existing files match exactly and eight PR-deleted paths remain absent. Only two generated public inventories differ. Preserve newer inventories. |
| #17 | 9 | 0 | 3 | 0 | Nine exact files; continuation remapper, scene event contract and its unit test evolved. Retain current versions pending behavior disposition. |
| #22 | 3 | 0 | 8 | 0 | Three exact files; eight owner/fixture/checkpoint files evolved. No missing path, but no complete behavioral equivalence claim. |
| #26 | 19 | 0 | 4 | 0 | Nineteen exact files; art placement, first-reveal composer and test, and ShopApp evolved. Preserve later composition. |
| #28 | 7 | 0 | 10 | 0 | Seven exact files; ten state/checkpoint/contact/remap/assignment files evolved. Preserve later composition; no whole-lane acceptance inferred. |
| #31 | 3 | 0 | 1 | 0 | Three exact files. ComputerDesktop differs only by deletion of one trailing blank line (direct diff reviewed). Implementation is present; no new test execution. |
| #32 | 24 | 0 | 2 | 1 | Twenty-four exact files. ComputerDesktop differs only by one trailing blank line. BackupApp adds projection-revision refresh suppression and moves detached-view guarding before result handling. Three-case desktop-entry test is absent; preserve this coverage obligation. |

## PR #32 coverage obligation

`tests/integration/test_scene_backup_desktop_entry.gd` at PR head `424e0a917e77c13c143088a1e018e01a8cac0c31` is absent from current playable source. No history for that path or matches for its three test names were found in current source. This is an unconsumed authored test/coverage obligation, **not a demonstrated runtime defect**. Do not close the whole PR as fully incorporated on file-equivalence evidence.

Its three authored cases cover: uncached real desktop Backup entry with consent cancellation and cached reopening; refused configuration without admission/cache and then retry; and missing confirmation host canceling a prepared action without commit. The fixture injects Bootstrap/app preparation/board dispatch/lower save owner and does not prove production Bootstrap or physical disk behavior. Current `test_scene_backup_inspection.gd` has two differently scoped inspection/cancelled-consent and unadmitted-bytes cases; this audit does not claim they replace the missing desktop-entry cases.

## Limits and next integration action

Do not reapply divergent branches wholesale: that would overwrite later runtime and inventory evolution. PR #11 is exact-content incorporated; #12 is incorporated apart from later generated inventory state; #31 has only a trailing blank-line difference. Other rows require explicit disposition of evolved obligations before closure. These static results do not add cloud acceptance, prove performance, or certify full-game behavior.
