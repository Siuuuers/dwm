# Current cleanup handoff

## Outcome and baseline

Every selected check verifies current behavior and passes, or has a documented retirement reason and replacement coverage where required. Remove production code only after proving it is unused and recording its former purpose.

Reviewed master: `26dbcd42acf82f419b350a84e1237cbcfb09bc38` (PR #249).
This handoff records read-only findings, not newly reproduced failures or completed implementation. Recheck master, repository instructions and open work before editing. PR #215 was closed without merging at the user's request; this assignment supersedes its active queue.

## Confirmed decisions

- Keep development and focused verification cloud Linux-first.
- Defer Windows packaged player-experience, visible latency and audio-continuity qualification until the user's planned game features settle. This remains a later release task, not a passing result. Do not launch it as part of this assignment.
- Preserve current approved player behavior. Development saves may be incompatible when an authorized simplification requires it; do not introduce migrations solely for unshipped formats.
- Record each proven retirement in the existing `docs/retired-features/` structure before deleting implementation and its exclusive tests.
- Improve names only when their meaning becomes clearer. Update direct, dynamic, serialized and test references.
- Remove explanatory comments in touched first-party scope, preserving required legal notices and machine directives. Avoid an unrelated repository-wide sweep.
- Use focused checks. No new injection campaign, broad matrix, generic state-machine framework, speculative hardening, or host-sensitive timing gate.
- This conversation is coordination; a new implementation session can execute the mission below.

## Completed work: do not repeat

- #183, #185 and #187 are closed. Their old plans must not be reopened as unfinished implementations without reviewing successors.
- #225–230 retired disconnected Dating/Schedule components and automatic day-resolution owners; #228 repaired retained desktop contracts and #229 repaired fixture teardown.
- #241 bounded local History; #244 added narrow live-transition lint.
- #245 optimized Save, History, Settings and Load, including bounded picture retention and deferred recovery styling.
- #246 simplified Challenge transitions; #247 added shared focused CI classification; #248 narrowed checkout; #249 shortened Day1 probe preparation.
- Progression TLA+ already models command coordination and fatal acknowledgement. It is not automatic verification of arbitrary runtime changes.

## Mission A: reconcile current records

Owner: implementation coordinator. Scope: current handoff status and source links only.

The passage handoff still says CI selection correction is planned. Replace that current-status statement with links to #247–249. Preserve historical measurements and their limits. The Challenge CI handoff also retains historical instructions describing its now-committed probe as temporary: label historical instructions clearly or update current guidance.

Reconcile #215's former Dating history and public-surfaces checkout leads against current source and merged work. Carry forward only proven unresolved items. Do not confuse #248's Challenge checkout improvement with proof that public-surfaces checkout is solved. Keep that separate investigation deferred unless current measured cost justifies it.

Acceptance: each active assignment has an accurate status, successor evidence or one bounded remaining owner. No historical test result is relabeled as current validation.

## Mission B: reproduce and resolve known test debt

Owner: one test/runtime session. Start with the caption-presentation fixture lead; finish one cause before widening scope.

Sources report:
- #245 / player latency audit: three older `test_witnessed_run_presentation.gd` cases encountered a `MemoryLocale` fake missing `t` / `get_readiness`.
- #237 / #239: older scene-day/held-source fixtures had stale expectations, node lookup issues and acknowledgement-count failures.
- Progression implementation record: a historical connected-marker fixture used an obsolete snapshot lacking lifecycle data.

These are historical leads, not confirmed current failures. Locate each file with repository search; do not assume its directory or continued existence.

1. Read the current requirement, fixture and production owner. Check whether later PRs already resolved it.
2. Run only the relevant methods in isolated registrations/data roots. Record exact revision, method selection, assertion count and exit status.
3. Group reproducible failures by cause.
4. Repair fixtures that represent current behavior. Retire obsolete exclusive tests only after documenting what they used to prove and where required behavior is now checked.
5. If a genuine current runtime bug appears, make a bounded fix with its reproducer; do not weaken assertions or restore retired behavior merely to get green.
6. Update runners, selectors, fixtures and generated inventories only where affected.

Acceptance: selected methods actually execute with positive assertions; applicable normal journeys remain covered; no unresolved failure is counted as a pass. Keep nonreproducing historical reports explicitly closed or superseded.

## Mission C: conditional legacy retirement

Depends on current reference evidence, not merely successful Mission B.

#230 explicitly retained `GameStateDayResolutionPort`, `DayResolutionPlan`, `RunLifecycle` and `SaveManagerCheckpointPort` because fixtures and shared save validation still used them. They are audit targets, not a deletion list.

Trace production composition, direct/dynamic calls, scenes, signals, resource paths/UIDs, inheritance, schemas, serialized contracts and mixed suites. Distinguish current runtime requirements from test-only legacy ownership. Remove only a complete proven-unused cohort. Preserve shared save validation and current DTL causal-day/challenge ownership.

Before deletion, record former purpose, current reachability evidence, replacement owner if any, affected tests/resources and acceptance evidence. If ownership remains unclear, retain the code and report the precise uncertainty.

Acceptance: affected parse/import, owner checks and relevant positive Save/Load or challenge journey pass; current inventories and registrations remain coherent. No speed claim from line-count reduction.

## Formal model and lint

Review the model-to-code mapping only when touched progression behavior requires it. Current model excludes restoration/backward traversal and abstracts native completion. Do not expand it merely because this audit exists.

Reuse existing comment, History and live-transition guards. Add a rule only for a demonstrated recurring violation with a precise fix and a small selector/regression test. No naming-quality rule or automatic dead-code deletion.

## Delivery

Use small reviewable commits/PRs: current-record reconciliation, one fixture cause, then any proven retirement. Keep overlapping runtime files under one owner.

Report: tested revision/tree, original reproduction, changed behavior or preserved behavior, commands and exit codes, selected tests/assertions, retirement record, skipped checks and remaining limits. Merge authority exists in the conversation; merge only a completed, reviewed slice with its required evidence.

Windows player-experience work stays deferred until the feature scope settles. No additional feature request is inferred from that deferral.

## Sources

- [Closed prior queue #215](https://github.com/Siuuuers/dwm/pull/215)
- [Retained day-resolution dependencies #230](https://github.com/Siuuuers/dwm/pull/230)
- [Legacy fixture findings #237](https://github.com/Siuuuers/dwm/pull/237) and [#239](https://github.com/Siuuuers/dwm/pull/239)
- [Latency implementation #245](https://github.com/Siuuuers/dwm/pull/245)
- [Player latency audit](2026-11-05-player-latency-audit.md)
- [Passage handoff](2026-11-05-passage-latency-handoff.md)
- [Challenge CI handoff](2026-11-10-challenge-ci-coverage-handoff.md)
- [Progression implementation](2026-11-03-story-progression-implementation.md)
- [Model mapping and limitations](../../tools/verification/story_progression/README.md)

## New-session starter

Read this handoff and repository instructions, verify current master and concurrent work, then reconcile stale current guidance and reproduce the caption-presentation fixture lead. Complete one cause with focused checks before expanding. Investigate conditional retirements using current reference evidence and record their former purpose before deletion. Keep Windows player-experience qualification deferred until the planned features settle. Report exact candidate evidence and skipped checks; do not repeat completed PR work.
