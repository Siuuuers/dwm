# PR reconciliation and integration review — 2026-10-23

Read-only independent review. No PR states, refs, comments, or runtime files changed.

## Pins and ancestry

- Playable source: `82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc`.
- Product PR36: `c8358870d3ece92d5f8cc7ba65aefe34a746be5c`.
- Master: `41592fcc792aa615e47ee2ce2f05008ca195b311`.
- Pre-documentation-repair integration tree reviewed: `81a2e63330fbf817ed08aafa3de0d31d21466935`, prepared from source descendant `5eee8406` and master.
- Playable source is 38 commits ahead / zero behind PR36. Versus master it is 580 ahead / 62 behind; common ancestor `9e43b52c9884ccd59e82245d2168c3113ee4d037`.
- All 28 observed open PRs are drafts. Conflict metadata is not test acceptance.

## PR disposition map

| PRs | Verified relationship to playable source | Next disposition |
| --- | --- | --- |
| #1, #4, #5, #6, #7, #10, #14, #16, #18, #20, #23, #27, #36 | Complete PR head is already an ancestor | Do not reapply code; reconcile statuses after qualified integration |
| #40 | Diverged ancestry, but sole changed handoff file exactly matches blob `e9f1ce8503052e1deea3e4a4c4d4dd86c871485b` | Incorporated-content closure candidate |
| #37 | DTL and unit test exact matches; README differs | Review newer guide evolution, then incorporated/superseded disposition |
| #39 | Helper, unit test, authoring fixture, option-slot fixture, order JSON exact matches; seven-day DTL and three guides differ | Review later evolution; do not merge stale content wholesale; current mergeable=false |
| #38 | Dated remaining-work doc absent; shared report differs | Reconcile or supersede historical status, preserving useful evidence |
| #8, #9, #11, #12, #17, #22, #26, #28, #31, #32 | Diverged ancestry | Content/behavior equivalence review needed; divergence alone does not prove missing work |
| #30 | Workflow controller, separately diverged | Keep diagnostic controller outside product merge |

## Candidate isolation review

Independent `git diff-tree` checks found zero differences from source HEAD in `.github`, `scripts`, `autoload`, `scenes`, `tests`, `data`, `assets`, `project.godot`, and `export_presets.cfg`. The candidate's entire `story` subtree is identical to master. This supports preserving source runtime and master's story consolidation without reintroducing controller changes. It does not itself qualify runtime behavior.

The candidate imports master's `AGENTS.md`, which routes implementation work to `CLAUDE.md`; that file is absent in the pre-repair candidate. Restoring the exact master `CLAUDE.md` is a narrow, justified documentation repair. This review read both files. Recheck final tree isolation after this repair and report additions.

## Broad CI gate

The retained canonical `.github/workflows/windows-tests.yml` runs on pull requests, pushes to master, and workflow_dispatch. It has 26 expanded jobs: 12 focused Windows suites, Windows export, public surfaces, paired checkpoint performance, seven-day history producer, four history comparisons, their aggregate, and five rendered Linux jobs.

`public-surfaces` gates the downstream jobs. It imports the project, exercises native caption discovery/Accept, checks isolation contracts, validates committed inventories without regeneration, and tests inventory drift/read-only contracts. If this gate fails, skipped downstream jobs are unqualified, not passed. Preserve its raw logs and diagnose the exact failing step before broad reruns.

The historical source-qualified playable journey/export does not establish this 26-job gate. In particular the canonical workflow additionally exercises historical fixture/provenance contracts, inventory coordinates, retained-history producer/consumer custody and comparisons, legacy rendered Hospital/Solo paths, and UI literal audits. A clean Git merge does not resolve those previously open risks. Do not weaken or regenerate historical evidence merely to make CI green.

Cloud execution uses pinned official Godot 4.6.3 standard builds. Focused jobs preserve full history for new_account and desktop immutable-seal checks. Linux rendering has native speech setup. Artifact retention is seven days; retain failures and acceptance receipts promptly. The default pull-request checkout tests the merge result, so record that exact checkout SHA and its parent/source pins when interpreting results.

No engine/PowerShell execution was performed by this review. No full integration or release acceptance is claimed.

## Evidence method

Fresh GitHub metadata for all 28 open PRs; compare_commits for every PR against PR36 and playable source; direct file SHA comparisons for #37–#40; local Git object/diff inspection of the integration tree and canonical workflow. Older divergent proposals are not claimed content-equivalent without their remaining review.
