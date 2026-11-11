# Settings construction: stop after two low-value trials

Base: master `5331e69bd4fba9cc57915aa8aaf3878ed83b78e5` (PR #289). No runtime changes retained. The prepared-font improvement remains intact.

Goal: reduce the complete first Settings opening without changing first appearance, focus, controls or loading behavior. Existing Godot 4.6.3 Linux headless authored Day1 probe, fresh profiles, default 125%, English instant captions; first Settings also constructs Computer. Timings include the click helper's frame waits. No concurrent engines.

## Attribution

Two diagnostic processes measured SettingsContent._ready:

| Stage | Observed cost |
| --- | ---: |
| Build controls | 26.9–27.5 ms |
| Populate labels | 7.4–7.6 ms |
| Bind controller and initial presentation | 97.2–104.7 ms |
| Select initial category | 2.4–2.7 ms |

A second diagnostic split on the off-tree trial found theme construction 39–41 ms, theme attachment 17–20 ms, initial scroll/category styling 3–7 ms. These spans overlap the earlier binding span and must not be added as independent totals.

## Rejected candidates

1. Build each category's rows before attaching it; set initial visibility before attachment. Source review found no lifecycle blocker. Ordered base/candidate/candidate/base first opens: 392.208 / 394.371 / 411.486 / 398.990 ms. No benefit established; revert.

2. Prepare the existing canonical theme before building controls; reuse that same helper from apply_text_size. No new cache. Source review found no blocker; registry 125% default was used after review caught the exploratory 100% fallback mismatch. Complete production profiles made that fallback change irrelevant to the timing probes.

First ordered comparison:

| Revision | First opening |
| --- | ---: |
| Base | 399.686 ms |
| Candidate | 410.105 ms |
| Candidate | 379.391 ms |
| Base | 421.284 ms |

Reverse-order confirmation:

| Revision | First opening |
| --- | ---: |
| Candidate | 389.511 ms |
| Base | 394.552 ms |
| Base | 394.821 ms |
| Candidate | 390.760 ms |

The reverse-order medians differ by only 4.551 ms (~1.15%). The earlier samples overlapped and showed larger variation. This does not establish a compelling whole-operation improvement for an initialization refactor. Reject it rather than claiming a meaningful player-visible gain or adding lifecycle complexity for the small effect.

## Verification and disposition

All 16 diagnostic/comparison processes passed 52 assertions each (832 total): actual viewport Settings/Computer cycles, committed preference display, caption admission after close and unchanged reading history. Candidate-specific broader UI suites were not run after rejection. No new tests/lint rules or runtime code retained; source restored exactly to base. `git diff --check` passes. No Windows/rendered claim.

Evidence, raw logs/XML, probes and rejected patches: `tools/player_latency/evidence/2026-11-12-settings-construction/`. Copy scripts/probe to `.godot/ci/settings-open/`, use fresh run labels, and apply the appropriate archived patch in an isolated checkout before comparison. Comparison runners restore candidate source in `finally`; restore base when finished.

Recommendation: stop further micro-optimization of this Settings initialization path for now. Preserve the PR #289 font improvement. Return to larger measured gameplay pauses, such as first checkpoint activation or entry transitions; confirm they still reproduce on current master before proposing a change. A larger Settings redesign or lazy category creation is not justified by these results.
