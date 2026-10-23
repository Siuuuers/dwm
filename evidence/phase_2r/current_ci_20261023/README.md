# Current cloud qualification, 2026-10-23

## Matched Backup-opening experiment

These original GitHub artifact archives were downloaded, SHA-256 hashed, and ZIP CRC checked. Each run directory retains the original archive, its source/controller provenance, and inspection metadata. No local engine run was used.

| Role | Run | Source | Controller |
|---|---|---|---|
| Baseline | [39971355500](https://github.com/Siuuuers/dwm/actions/runs/39971355500) | `f29c5482f0a5e80d89e9ad3ec8566e7a761848db` | `527258a8fd7885429641e13796776df71f24ef83` |
| Candidate | [39972595648](https://github.com/Siuuuers/dwm/actions/runs/39972595648) | `3ce24fffcae5f235af935fc484615206f813d99a` | `2f62301b1fce84a3e509570ccbe9760acf10308b` |
| Combined inventories | [39973757077](https://github.com/Siuuuers/dwm/actions/runs/39973757077) | `0493deb8bb7a5fc2f99c254db80b29ddf3dcf91a` | `a32deb130ea2d5f73e4c597a7747895892b70863` |

Both performance runs use Godot 4.6.3 standard on Windows, identical diagnostic helpers from `cc66fd97f4f004d578f4f5208f2f331d0f970397`, and the same authentic forty-file post-replay root (archive SHA-256 `82251bc333baaccdc4c1de38fb175f72b411466b8c4583d41e8fc7fc09edc029`). All forty input hashes match. The flags are `DWM_SCENE_VALIDATION_PROFILE=1` and `DWM_SAVE_LOAD_PROFILE=1`.

| Complete measured phase / marker | Baseline seconds | Candidate seconds |
|---|---:|---:|
| Boot | 65.303092 | 67.238331 |
| Load phase | 526.361689 | 543.462862 |
| Save phase | 427.421896 | 363.537523 |
| Ending Backup opening | 172.400136 | 92.852614 |
| Title Backup opening | 75.415598 | 77.726042 |
| Load action ready | 373.647611 | 383.108364 |
| Load press return | 450.076961 | 464.914922 |
| Save press return | 252.940721 | 268.560588 |

Opening the ending Backup surface was 46.14% faster in this single matched pair; the complete Save phase was 14.95% faster. Load was 3.25% slower and Save press return was 6.18% slower. This supports the narrow removal of eager hidden-surface inspection, not a general speedup claim or statistical guarantee. Nested timings must not be added to complete phase timings. Multi-minute pauses remain unresolved.

Inspection calls fell from 65 to 56, exactly one per each of nine locators; restore preparations 23 to 20; document parses 834 to 757. Both native checks passed 1 case / 112 assertions. Candidate host + public-surface + native checks passed 76 cases / 2094 assertions with no skips. The native completion flag here covers boot/load/save only, not completion of the full authored week.

The earlier candidate preflight failure was not accepted. Diagnostic controllers remain outside the product branch. The combined inventory archive is provenance for the initial generated surfaces; later source changes require another native regeneration before acceptance.

## Completion and visual qualification

[Run 39973922887](https://github.com/Siuuuers/dwm/actions/runs/39973922887) passed the uninterrupted default authored week: 836 captions, 835 transitions, 7615 assertions, durable completion, exactly one Gallery receipt, and return to Title. Its original archive and selected summary are in `run39973922887/`. Elapsed time was 45m55.8s, with a worst transition of 216.631s; correctness does not establish acceptable responsiveness.

[Run 39977776938](https://github.com/Siuuuers/dwm/actions/runs/39977776938) passed 43 cases / 2030 assertions across the repaired fixtures and regenerated/verified native inventories, subsequently adopted by `e5cf80a5`.

[Run 39981619080](https://github.com/Siuuuers/dwm/actions/runs/39981619080), source `d2e737d2`, passed all 133 captures: desktop 38, delivery 25, HUD 10, Japanese/Korean 30, fonts 30. `run39981619080/` retains every artifact's metadata, JSON reports, and the original delivery ZIP. The change corrected the test's transparent-pixel boundary; it changed no game runtime.

## Seed preparation diagnostic

[Run 39979681421](https://github.com/Siuuuers/dwm/actions/runs/39979681421) uses the same forty-file root and helpers, with instrumentation only. Its 112-assertion native journey passed. Twenty seed preparations across 57 bundles consumed 180.881935s inclusive: 111.575281s during Load and 69.306654s during Save. These figures include required work and do not predict an optimization's savings. The archive and summary are retained in `run39979681421/`.

## Current Settings and first-reveal qualification

[Run39989387087](https://github.com/Siuuuers/dwm/actions/runs/39989387087), source `d74663635f04f63d3bb3e12f1811fee175cadbf7`, passed 366 Settings primary cases/21,934 assertions, both expected invalid-root refusal censuses, 61,180 manual storage assertions and three rendered captures. Its separate ordinary-board first-reveal creator/loader pair passed two cases/143 assertions. The legacy seven-case first-reveal file remains byte-preserved; four compatible adapter cases and the current paired journey are the selected coverage, not an identical reproduction of the retired legacy crash-injection matrix.

## Measured scene seed reuse

[Run39988834004](https://github.com/Siuuuers/dwm/actions/runs/39988834004), source `8ced88776993efecf3229b603dbd9671d7584549`, passed 66 focused/public cases/2188 assertions and the matched native journey's 112 assertions. It reuses detached current-scene admission material only while document and selected bundle remain exactly equal; legacy, recovery and changed inputs use generic validation. Both measured runs use the same four helper hashes, authentic input root and profiling flags.

| Complete phase | Previous candidate seconds | Seed reuse seconds |
|---|---:|---:|
| Boot | 67.238331 | 60.130351 |
| Load | 543.462862 | 397.534697 |
| Save | 363.537523 | 246.436326 |

Load improved 26.85% and Save 32.21% in this single matched pair. Multi-minute pauses remain; no statistical guarantee or smooth-gameplay acceptance is claimed. The original native archive SHA-256 is `c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670`.

The combined source preserves current master Steam changes. Final combined inventories and canonical acceptance are tracked in the current qualification handoff. The final integration status is recorded below.


## Final integration and acceptance

PR #52 merged as `5e3f1e0bb3ac251e88ea8a7b87c5a0616e3f7d5a`. The [final handoff](../../../handoff/a-integrated-ci-handoff-20261024.md) records 2,739 passing primary cases/154,403 assertions across 21 canonical suites and the corrected Settings suite. Canonical run39992202440 passed 25 jobs; its Settings script-load failure is superseded by full replacement run39993602893 after a two-line test-double signature fix. Game/tool code is unchanged by that fix. Both runs and the later preserved Steam-only master changes are distinguished in the handoff.

`run39992202440/` contains compact summaries, exact JUnit and auxiliary report bundles, original artifact/member hashes, the PR reconciliation record and residual performance analysis. Diagnostics and excluded attempts remain labeled; do not count them as accepted tests. The exported Windows startup, 133 desktop/dialogue captures and 113 Gallery captures passed. Multi-minute late-game pauses remain.
