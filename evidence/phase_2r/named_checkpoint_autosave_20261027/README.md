# Named checkpoint autosave: matched cloud evidence

[Comparison run 40472873648](https://github.com/Siuuuers/dwm/actions/runs/40472873648) passed all 24 instrumented exported journeys and strict ordinary-storage assertions. This is a four-pair, same-Windows-runner AB/BA/AB/BA comparison; OS caches were not cleared.

- Baseline: `249b66bc0158353e0e576daf89768096665e95b7`, tree `c6bbdb0afddaafb11084c019b9f7686053b83d32`.
- Measured candidate: `29809590a2792529445d75bacbb5939d30fc7927`, tree `dbf2415cd03f74bbd7c59f93c41914074d5fe169`.
- Observer source: `d72b67506e05c03f161201df7b9fc5430e2b136e`; hashes in [harness.json](harness.json). Both variants use the same observation-only overlay.
- [Evidence artifact 12719828149](https://github.com/Siuuuers/dwm/actions/runs/40472873648/artifacts/12719828149), 27,217,994 bytes; downloaded ZIP SHA-256 verified as `2063eadd81d5e28c80ee72904ff3b91859b8dfee0058633d0158e21ef7f99d51`.
- Exact diagnostic exports: [package artifact 12719568613](https://github.com/Siuuuers/dwm/actions/runs/40472873648/artifacts/12719568613), reported ZIP SHA-256 `df75f604009e7bd851909526fb134dcf55d04e9bedf2d8c136a87e25b88a9bb5`. Packages were not downloaded for this analysis. Cloud verified measured package files remained unchanged.

## Results

Times are milliseconds. Each median uses four runs per variant. “Slower pairs” counts candidate values greater than their same-repetition baseline, not a significance test.

| Complete operation / observed response | Baseline median | Candidate median | Median change | Slower pairs |
| --- | ---: | ---: | ---: | ---: |
| Passage first correct drawing | 1707.52 | 617.78 | -63.8% | 0/4 |
| Passage complete reveal and input readiness | 1727.94 | 638.42 | -63.1% | 0/4 |
| Load first correct drawing | 679.54 | 678.67 | -0.1% | 1/4 |
| Load complete caption | 705.28 | 704.49 | -0.1% | 1/4 |
| Load input readiness | 706.78 | 705.98 | -0.1% | 1/4 |
| First Accept drawing | 62.44 | 63.46 | +1.6% | 3/4 |
| Typical caption (median of each run's captions 003–030) | 115.65 | 115.13 | -0.4% | 1/4 |
| Manual Save after long-history Load journey | 2380.86 | 2428.50 | +2.0% | 4/4 |
| Manual Save after fresh New Acc | 2368.67 | 2360.24 | -0.4% | 2/4 |
| Manual Save after retained New Acc | 2394.62 | 2405.43 | +0.5% | 2/4 |

The passage transition improved in every pair. Load and ordinary caption results are nearly unchanged and mixed. Long-history manual Save regressed in every pair: +113.45, +3.58, +13.41, and +53.17 ms. Do not infer a universal speedup.

All four candidate passages have zero lower checkpoint capture/prepare/commit calls and zero non-Profile storage calls; Autosave bytes remain unchanged. Each retains one independent `profile.json` write. Subsequent actual manual Save writes the pending issuer root once, then its slot once. Baseline passage instrumentation positively observes four lower captures, one prepare, one commit, one Autosave write, and two issuer-root writes. Nested storage counters overlap and must not be summed as independent writes.

Manual Save timing includes `open_scene_backup` live capture, preparation and commit. It measures an API operation, not physical-button-to-painted-confirmation latency. Load includes matched observer capture/hash work. Named checkpoint arrival timing has no matched baseline and is not measured here; separate connected runtime tests establish that feature. Four pairs describe this runner, not statistical certainty or a device guarantee.

## Retained evidence and review

[paired-analysis.json](paired-analysis.json) is the exact verified analysis report, including raw paired values, all 28 caption values per Load sample, storage profiles, source identity, and limitations. [source.json](source.json) and [harness.json](harness.json) retain the artifact JSON values; Git normalizes their line endings. The full strict acceptance summary (`named-checkpoint-summary.json`) and passage summary (`passage-summary.json`) remain in the linked artifact. Full inherited startup/Load and history summaries, screenshots, per-journey observations, profiles, and hashes remain in the linked artifact.

The r1 baseline/candidate `measurements/r1-{baseline,candidate}-load/passage/destination.png` pair was visually reviewed: the same authored caption stack, controls, side menu and background layout are present; desktop clock differs. The two PNGs total 1,545,174 bytes, so they are retained in the artifact rather than duplicated here. Other repetitions passed semantic and integrity checks but were not individually visually inspected.

Runtime-equivalence review: measured commit `29809590a2792529445d75bacbb5939d30fc7927` and subsequent candidate `835e812bab64add8ad4b8aa627110322d4ab23cd` have an empty `git diff -- autoload scripts`. Their intervening changes correct connected tests and regenerate public-surface inventories. This comparison measures the runtime shared by those candidates; it does not claim the later test corrections were themselves run in this benchmark or bind future runtime edits.
