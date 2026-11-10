# Linux player-latency investigation

Date: 11 November 2026 (Hong Kong).
Runtime revision: `02cb4ddaf038db8bcd6d920f268c201dab232f46` (master, PR #256).
No open PRs were listed at investigation start; master was checked again before publication.

## Outcome

Follow-up: [Settings first-open implementation](2026-11-11-settings-first-open.md)
removes the measured default-to-Scene presentation rebuild and records matched
results. The no-runtime-change statements below describe this initial pass.

Completed the first source-level measurement pass requested by the
[player-visible handoff](2026-11-11-player-visible-latency-handoff.md).
No production code changed and no speedup is claimed. Added one focused Settings
probe so subsequent work can compare dispatch separately from frame observations.
Current master already includes the earlier Save, texture, theme and live-anchor
optimizations; this work does not repeat them.

The full authored route passed 4,285 assertions across 830 caption positions.
Two fresh-process Settings probes passed 105 assertions each. A separate
instrumented Settings run also passed 105 assertions; its timings are attribution
only. Fresh and fourth-save F5 probes passed 24 assertions each. Every accepted
process exited 0. Startup reached an enabled New Account control and exited 0.

## Investigation before editing

| Question | Evidence gathered |
| --- | --- |
| What do existing probes measure? | Audited inherited frame waits, assertions, presentation acknowledgement and native input readiness. |
| Is ordinary Advance slow computation? | 802 within-entry samples; inspected the intentional 100 ms advance guard. |
| Does long-session work grow? | One naturally traversed authored Day1–Day7 route; early/late UI samples. No fresh-Load substitution for aging. |
| Which UI action warrants narrower attribution? | History, Save, Settings, computer, Gallery and same-process Load; Settings isolated in two fresh processes. |
| Does quick Save retain the position? | Fresh/fourth-save fixture checks read durable bytes and compare canonical position after timing. |
| Can the target display experience be qualified? | No Windows runner/capture in this workspace. Linux Xorg dummy startup failed to establish listening sockets. No rendered or audio claim. |

## Baseline observations

Godot 4.6.3 standard, Linux headless, AMD EPYC 9V74 shared host. Imported source
project; English, instant reveal, Auto off, default 125% text. Optional challenge
boards were unplayed. The focused probe reports a headless window of 64×64;
this is not the intended 1920×1080 borderless presentation. GPU, refresh, VSync,
physical display and audio continuity were not measured. Fresh processes do not
imply cold OS caches. Expected route construction precedes measurement.

Times below are **harness endpoints**, not input-to-photon latency. Individual
samples are retained in [baseline JSON](../../tools/player_latency/evidence/2026-11-11-linux-investigation/baseline.json).

| Action | Samples | Median ms | Range ms |
| --- | ---: | ---: | ---: |
| Ordinary caption, fully ready | 802 | 111.248 | 94.674–132.258 |
| Passage entry, fully ready | 27 | 100.998 | 94.081–196.381 |
| History | 6 | 44.757 | 22.666–75.927 |
| Save write UI flow | 6 | 87.736 | 71.636–253.691 |
| Settings | 6 | 60.575 | 58.612–282.581 |
| Computer reopen | 6 | 18.663 | 12.030–51.406 |
| Same-process title → saved Day7 Load | 1 | 155.681 | — |
| New game flow after setup | 1 | 576.310 | — |

Ordinary presentation acknowledgements were typically about 14 ms. Their endpoint
precedes input readiness. `node_dialog_text.gd` applies the existing default
`dialogic/text/advance_delay = 0.1` after organic reveal; there is no project
override. Do not remove this anti-accidental-skip behavior as a performance fix.
The slowest entry in this route was `line.ending.alone.normal.001` at 196.381 ms.
These small heterogeneous populations do not support tail percentiles or general
all-game smoothness claims.

Save totals differ in operations: the first Day1 sample writes an empty slot;
subsequent samples include overwrite confirmation. `_click` includes frame waits.
The full-route caption elapsed endpoint also includes inherited readiness
assertions. Its acknowledgement endpoint is not the input-ready endpoint. The
separate aged probe adds seven helper frames through `_accept`; it was inspected,
not run as a second purported independent measurement.

Standalone startup took 5,253.100 ms from engine ticks to its ready-control
endpoint (one sample). It excludes pre-engine launch overhead. F5 synchronous
dispatch was 25.961 ms fresh and 23.514 ms on the fourth Save in separate short
fixture processes; maximum observed process-frame gaps were 37.598 and 33.750 ms.
F5 profiling was disabled. This fixture does not model aged gameplay and has no
rendered Saved-feedback measurement.

## Settings attribution and next bounded candidate

The new `benchmark_settings_reopen.gd` constructs input events before timing,
measures native viewport dispatch, then records a following process frame (and
post-draw if rendered). Assertions run afterward. It checks enabled/visible
controls, retained Settings instance, the canonical publication during suspension,
and restored native caption after closing. Theme identity is observed within a
process; identity is not compared across processes.

| Fresh process | First dispatch ms | Repeated dispatch samples ms |
| --- | ---: | --- |
| A | 277.229 | 69.399, 61.979, 56.667, 61.531 |
| B | 308.872 | 53.888, 57.991, 55.552, 58.585 |

Both use identical source and fresh profiles, serially, with no diagnostic
wrappers. There is no candidate variant or before/after speedup here.

Temporary synchronous wrappers bracketed by dispatch markers attributed one
repeated open to a single controller refresh: approximately 31 ms inclusive,
including approximately 25 ms in `apply_text_size`. Reset-dialog presentation
calls in that sample were approximately 0.8 ms each; ControlsSheet presentation
was 8.2 ms inclusive of its 5.9 ms binding refresh. Nested spans must not be added.
Closing separately refreshes the panel too; two neighboring spans are **not**
proof of duplicate opening work.

First open performs default presentation setup, Scene presentation setup, and
visibility refresh. This follows `ComputerDesktop.open_app` adding Settings to
the tree before the bootstrap callback applies the Scene palette/dayless context.
A next candidate can preconfigure only Settings before `_ready`, using the existing
presentation owner. Other app callbacks require ready nodes and must not all move.
For repeated opens, isolate unchanged styling only after preserving live binding,
capability, status, preview and preference updates. Large targets, locale and
accessibility changes must still refresh. Do not introduce a general cache or
remove the controller refresh wholesale.

Runtime surgery is deferred, not declared unnecessary: this pass establishes a
measurable Settings lead but does not yet prove a complete safe optimization.
Next acceptance requires matched alternating baseline/candidate runs, first and
repeated opens plus aged use, focused current-preference/focus checks, and a
rendered affected journey when display behavior is changed. Windows conclusions
still require an exported Windows run. No product/architecture decision blocks
this narrower follow-up; preserve existing presentation and save semantics.

## Reproduce and evidence

Import once with `godot --headless --editor --path . --import`. Restore the
editor's generated `project.godot` timeline-directory rewrite before measuring.
Do not run import or other timing probes concurrently. Use a new isolated root
for each run. Example from the repository root:

```bash
DWM_TEST_ROOT="$PWD/.godot/phase2r_tests/settings-run" \
XDG_DATA_HOME="$PWD/.godot/phase2r_tests/settings-run/xdg" \
DWM_BENCHMARK_REVISION="$(git rev-parse HEAD)" \
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/manual/benchmark_settings_reopen.gd -gexit
```

For the full route replace the test with `benchmark_player_latency.gd`; accepted
run used `-gunit_test_name=test_player_latency`. For F5 use
`benchmark_f5_save_latency.gd`, `-gunit_test_name=test_rendered_f5_latency`,
`DWM_F5_CASE=fresh` or `repeated`, `DWM_F5_PROFILE=0`, and
`DWM_F5_HEADLESS_DIAGNOSTIC=1` with fresh isolated roots.

Standalone startup must **omit `DWM_TEST_ROOT`**, which otherwise selects manual
bootstrap requiring an injected gate. Use isolated `XDG_DATA_HOME`,
`DWM_STARTUP_AUDIT=1` and `godot --headless --path . --script
res://tests/manual/benchmark_player_startup.gd`.

[Evidence directory](../../tools/player_latency/evidence/2026-11-11-linux-investigation/)
contains raw accepted logs, scalar samples, probe hashes and the temporary
instrumentation patch. The patch is evidence only; runtime wrappers were removed.
A preliminary run with editor-rewritten config was interrupted; the first Settings
probe wrongly queried the paused native adapter and failed five assertions;
a misconfigured startup attempt was interrupted. None counts as passing evidence.
The corrected probe checks the canonical ledger while playback is suspended.

Skipped: broad CI matrix, injection tests, runtime rewrites, other branches/locales,
150% layout, played-board journeys, fresh-process checkpoint Load, actual durable
Save latency separated from feedback in the full route, Windows/rendered/audio
qualification. No new timing gate or lint framework was added.
