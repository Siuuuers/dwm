# Native reading baseline and screenshot follow-up

Measured 29 October 2026, Hong Kong time.

Run [40827427676](https://github.com/Siuuuers/dwm/actions/runs/40827427676)
completed 16 independent rendered Windows game processes on one runner. The
production runtime was identical in both labels: master
`2b58ab1a0d2becac3f91d76ac7a9b25f165b9c96`. Diagnostic revision
`7698b9579fd8949728558c2b985bfedb6032ac2f` supplied the same observer and native
journey to both worktrees. This was an A/A baseline, not a speedup comparison.

Each process advanced through actual Day 1 captions 002–030 with physical Enter,
then opened History after 30 encountered captions. The existing instant reveal
preference isolated delivery time from the selected typewriter delay. Imports,
assertions, snapshots and screenshots were outside the elapsed-time spans.
Advance measures key-down to the first post-draw after native text publication;
History measures focused-button key-up to the first visible History draw.

| Case | Advance baseline / observer median (ms) | History baseline / observer median (ms) |
| --- | ---: | ---: |
| Dual 100% | 92.14 / 93.03 | 523.24 / 534.92 |
| Mono 100% | 90.46 / 89.16 | 500.96 / 489.72 |
| Dual 150% | 93.21 / 92.14 | 724.13 / 720.02 |
| Mono 150% | 91.12 / 92.41 | 718.62 / 720.37 |

Each table cell aggregates two separate processes. Per-process results and source
IDs are in [summary.json](summary.json). All 464 advances used one observed draw
and two completed layout generations. Inclusive method observations overlap and
must not be summed: `_on_text_started` took about 77–79 ms; bilingual refresh about
0.71 ms; aggregate layout method time per action about 1.4–3.4 ms. These measurements do not justify
presenting removal of one layout pass as the leading responsiveness improvement.
History's unobserved first-draw work also needs attribution before selecting a fix.
These are instrumented editor-run cloud results, not release/device guarantees.

The same real-story screenshots revealed a separate concrete layout issue:
at 150%, a wrapped English thought plus Chinese translation competed with space
reserved for a two-line choice although the generic Yes label is single-language.
PR [#152](https://github.com/Siuuuers/dwm/pull/152) corrects that choice allocation
and uses the available space above the caption field. This is a readability fix,
not a claimed performance optimization. Consult the PR for final acceptance.

The diagnostic tooling remains on `codex/reading-latency-20261029`; production
runtime changes are isolated in the two-file PR. No new translation framework,
Save/Load rewrite or speculative external-input protection was added.

## Screenshot acceptance

Run [40829035654](https://github.com/Siuuuers/dwm/actions/runs/40829035654)
passed focused self-talk tests and fresh dual-language native journeys at 100% and
150%. Capture revision `50311f10ebd79e45de1a89281bbcdcc138ede75f` uses the same
runtime and unit-test changes as PR #152 candidate
`2f501b99e86b85833562cbbe0377917f7892ce1d`.
The inspected 150% capture shows both wrapped English rows and the Chinese row
above the ordinary Yes button, ending above the caption field. History and
language Settings screenshots were also captured outside timed spans.

PR #152 runtime acceptance passed on `2f501b99e86b85833562cbbe0377917f7892ce1d`
in [run40829043751](https://github.com/Siuuuers/dwm/actions/runs/40829043751):
17 focused regression suites, public/inventory contracts, Windows exported startup,
Linux Gallery and desktop/dialogue rendering, and UI literal ownership (22 successful
jobs; one historical comparison intentionally skipped). The subsequent evidence
commit changes documentation only.
