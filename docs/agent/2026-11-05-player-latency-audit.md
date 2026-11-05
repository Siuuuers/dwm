# Player latency audit — 2026-11-05

Save is the strongest repeated in-play optimization candidate in this run. Its median action duration was 889 ms and its largest observed engine-frame interval was 1,048 ms. This is a Linux headless diagnostic, not a measurement of the Windows release's display or audio latency.

## Revision and proof

- Production revision: `69949519880c1ed4449ef0361377ef287809b9e9`.
- Godot 4.6.3 stable standard build; imported source project; isolated user files.
- One complete authored Day 1–7 route: 830 caption positions across 28 entries, followed by Gallery navigation and Load of a saved Day 7 challenge boundary.
- Final journey: **4,285 assertions passed**, GUT exit 0, 121.329 seconds inside the test. Three startup processes also exited 0.
- Raw action samples, SaveManager profiles, probe hashes and limits: [headless evidence](../../tools/player_latency/evidence/2026-11-05-headless.json).
- Only the final successful journey is included. Earlier probe-development attempts are excluded.

## Measurements

All durations below are milliseconds. These are state-observation timings with headless frame pacing; they include input dispatch and the probe's frame waits. They do not establish on-screen response time. Percentiles describe this route, not a population estimate.

| Operation | Samples | Median | Observed range |
|---|---:|---:|---:|
| Process launch → title ready, fresh profile | 3 | 10,563 | 9,124–11,823 |
| Title mount → New Game flow, automated confirmation | 1 | 1,628 | 1,628 |
| Save/overwrite flow | 6 | 889 | 810–1,910 |
| History open | 6 | 153 | 61–844 |
| Settings open | 6 | 139 | 129–709 |
| Passage/entry transition → input ready | 27 | 180 | 106–451 |
| Ordinary caption → input ready | 802 | 112 | 92–158 |
| Ordinary caption presentation acknowledgment | 802 | 18.6 | p95: 36.3 |
| Save menu open | 6 | 77.6 | 62–226 |
| Computer reopen | 6 | 46.2 | 26–137 |
| Gallery open | 3 | 12.5 | 12–37 |
| Dialogue Library tab | 3 | 13.5 | 13–14 |
| Load menu open | 1 | 22.0 | 22 |
| Load action → restored live session and caption content | 1 | 401 | 401 |

The startup observer loads the normal main scene through a SceneTree script and waits for bootstrap readiness and an enabled New Game button. It excludes rendering and does not flush the OS file cache. Its source-project startup number needs exported Windows confirmation before it becomes a release-performance claim.

Save samples were 810/1,910/912 ms on Day 1 and 1,134/865/850 ms on Day 7. This run does **not** establish growth with story age. First-use History was 844 ms; subsequent opens were 61–178 ms. First-use Settings was 709 ms; subsequent opens were 129–272 ms. Cold and warm actions should remain separate in follow-up comparisons.

The slowest entry transitions were the ending entry (451 ms), Day 1 result A (351 ms), and Day 4 entry (308 ms). Entry p95 was 351 ms. This does not cover every route or outcome.

## Investigation

`node_dialog_text` applies `dialogic/text/advance_delay`, default 0.1 seconds, after organic reveal completion. The probe therefore records presentation acknowledgment separately from eligibility for another input. Removing the guard to improve the input-ready number would change skip protection rather than remove rendering work.

For six successful saves, the existing SaveManager profiler reported these median phase durations:

| Phase | Median ms |
|---|---:|
| Snapshot capture | 292 |
| Document construction | 157 |
| Atomic write, including its validation callback | 178 |
| Journal commit | 163 |
| Serialization | 0.925 |
| Physical reread | 0.109 |

The saved slot was approximately 6.2 KiB by Day 7. Serialization and raw bytes are not the leading observed costs. The atomic-write scope includes validation, so its duration must not be described as disk I/O alone. Scope totals are inclusive, and medians of phases must not be added to reconstruct a median action duration.

`SaveManager._commit_backup_action_profiled` validates outgoing document text through `_document_text_validator`; `CheckpointJournal.commit_prepared` also calls `_validate_candidate`, which validates the current snapshot. These are concrete targets for deeper profiling and checking whether already admitted validation results can be reused. The audit does not prove every repeated check is redundant.

Next bounded optimization: isolate repeated snapshot validation during Save and carry valid preparation results through the owning transaction where justified, retaining source-revision checks and durable publication. Compare the same action and largest-frame metrics on one host before and after, with the authored Save/Load checks still passing. Investigate first-use History/Settings separately; this audit does not identify their exact internal cost owner.

## Limits

Xvfb could not provide a usable display in this environment. Artwork-viewer attempts could not validate unlocked image presentation headlessly and were excluded. GPU texture upload, actual Windows input-to-photon latency, audio start/crossfade gaps, physical Minesweeper interactions, other branches, other languages and text-size combinations remain unmeasured. Gallery numbers cover navigation, not fullscreen image decoding/rendering. Load is a same-process restored-session measurement at a control boundary, not a fresh-process load or an ordinary-dialogue input-ready measurement.

## Reproduce

Import with the pinned Godot build first, then restore any import-only changes to `project.godot`. Use a new directory for every journey:

```bash
audit_root="$PWD/.godot/phase2r_tests/player-latency-run"
mkdir -p "$audit_root/data" "$audit_root/test-root"
XDG_DATA_HOME="$audit_root/data" \
DWM_TEST_ROOT="$audit_root/test-root" \
DWM_BENCHMARK_REVISION="$(git rev-parse HEAD)" \
DWM_SAVE_LOAD_PROFILE=1 \
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gconfig= -gtest=res://tests/manual/benchmark_player_latency.gd -gexit
```

The journey writes `.godot/ci/player-latency.json` and emits `PLAYER_LATENCY` and `DWM_SAVE_LOAD_PROFILE` records. A successful GUT exit is required before accepting a dataset. The probe supports a display, but its rendered path has not been verified here.

For startup, use three new XDG directories, unset `DWM_TEST_ROOT`, and run:

```bash
XDG_DATA_HOME="$PWD/.godot/phase2r_tests/startup-run" \
DWM_STARTUP_AUDIT=1 DWM_BENCHMARK_REVISION="$(git rev-parse HEAD)" \
"$GODOT" --headless --path . -s res://tests/manual/benchmark_player_startup.gd
```

`PLAYER_STARTUP.engine_ticks_us` reports engine-relative readiness. The recorded process-to-marker measurements additionally use the parent process's monotonic clock. No performance threshold or automatic CI matrix was added.
