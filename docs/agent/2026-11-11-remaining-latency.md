# Remaining latency: measured computer-theme reuse

Date: 11 November 2026 (Hong Kong).
Baseline: `a7cb921b078047079a62a045269bce5641ee0f9e` (merged PR #258).
Runtime candidate: `ffba1b00d2a18752e1d95a9be5dcb46c4eb129b1`.

## Outcome

The computer shell rebuilt its theme whenever Settings opened, even when all
presentation inputs were unchanged. `ComputerDesktop` now retains its current
theme and notification style until one of the seven actual builder inputs
changes. This is one current resource and its input tuple, not an accumulating
cache. No other production file changed.

Locale, text size, palette, resolved calendar/Scene tint, contrast, colour preset
and font style invalidate the theme. Large targets, layout, live titles, Home
availability, notification copy and accessibility descriptions still update on
every refresh. Scene presentation remains dayless. A missing theme still rebuilds.
No caller was found replacing this owner's theme or mutating its notification
style externally.

## Investigate before changing

The previous [first-open cut](2026-11-11-settings-first-open.md) is already in
master. New diagnostic wrappers split Settings construction and presentation,
then inspected the surrounding computer shell. They were removed before matched
comparison. Nested spans are inclusive and must not be added.

- In one diagnostic first open, Settings content `_ready` took 161.7 ms, including
  24.8 ms building controls and 127.1 ms in controller refresh. Theme construction
  was 49.6 ms inside a 120.4 ms presentation application, not an additional cost.
- A separate section-timing run found roughly 0.1–0.2 ms for rail measurements,
  4.7–5.7 ms for fixed controls, about 5 ms for reset-dialog styling, and roughly
  7–10 ms for live values. Those figures are from a different run; do not combine
  them with the preceding first-open total.
- The shell theme assignment/build repeatedly took about 11–12 ms within a
  12–16 ms launcher refresh. Replacing a theme can invalidate child presentation;
  this timer includes assignment, not only the pure builder.

We kept the inexpensive rail measurements and required live updates. Hidden
confirmation dialogs remain; this change does not move their cost into first
use. No additional font cache was added: `UiTypography` already retains fonts.

## Matched Settings comparison

Four serial fresh-profile processes in **B/C/C/B** order, unchanged probe, same
source content. Godot 4.6.3 standard, Linux headless, shared AMD EPYC 9V74 host.
English, instant reveal, Auto off, 125% text. First use does not imply cold OS
cache. Each process opens Settings five times; repeated samples are correlated.

| Synchronous viewport dispatch | Baseline | Candidate |
| --- | ---: | ---: |
| First opens | 243.483, 251.838 ms | 201.509, 239.320 ms |
| First-open median | 247.661 ms | 220.415 ms |
| Repeated-open median, eight samples | 57.159 ms | 45.244 ms |
| Repeated-open range | 55.778–85.066 ms | 43.133–48.905 ms |

The small matched sample supports retaining the unchanged theme. It does not
establish a universal percentage, tail percentile, rendered latency or a Windows
speedup. Event construction and correctness assertions are outside dispatch
timing. Following process-frame observations are recorded separately.

## Other requested measurements

These are current-source baselines, not before/after claims for Save or Load.

| Workload | Observation | Important boundary |
| --- | --- | --- |
| Fresh-process Load | 321.084 and 328.960 ms; median 325.022 ms | Identical seed bytes restored to the same user-data path; service/expected-content setup precedes timing. |
| Subsequent Load | Six samples, median 190.521 ms, range 179.196–202.029 ms | Three correlated samples per process; different UI surface from first Title Load. |
| F5 Save | 21.201 ms fresh; 25.583 ms fourth Save | Short real-storage fixture; synchronous dispatch, not visible feedback timing or aged Save. |
| Source startup | Engine readiness 5028.542 and 5100.099 ms | Separate processes, fresh isolated profiles, imported source project. |
| Process launch through exit | 5206.493 and 5286.198 ms | Includes teardown; not an alternate name for readiness. |

Fresh Load uses the existing embedded probe from the 5 November texture-recovery
report. Expected-checkpoint expansion is outside the timer; native input-helper
waits and readiness assertions remain inside. A creator makes an early checkpoint
and later global discoveries; the runner restores the entire identical seed
before each loader. This preserves the distinction from same-process Day7 Load.

Separate Load profiling: first preparation 12.330 ms inclusive, synchronous commit
42.265 ms; subsequent preparation about 4.2–4.5 ms and commit 34.6–38.1 ms. Commit
returns `scene_activation_pending`, not completion. Deferred activation and probe
waits are outside those synchronous spans. No validation was removed based on the
larger harness total.

F5 profiling was disabled for reported samples. A separate diagnostic recorded
preparation 6.108 ms and commit 5.544 ms, including atomic write 0.569 ms and journal
commit 0.520 ms. This does not make those small writes the cause of all Save time.
All F5 cases read and verify durable position after timing.

Startup stage profiling began at engine tick 4467.381 ms. The largest measured
application stages were Save initialization 329.897 ms and localization 261.819 ms.
The engine's own `--benchmark-file` diagnostic attributed 3.969 s to Load Autoloads.
That diagnostic reached the ready marker and exited 0 **but emitted 18 engine
StringName teardown errors**; it is informational evidence, not a clean acceptance
run. The two uninstrumented startup runs were clean. No engine workaround or
speculative startup refactor was added. Exported startup still needs its own
measurement before moving source-project initialization costs around.

## Naturally aged route

One full authored Day1–Day7 journey on the candidate passed 4,285 assertions,
covering 830 caption positions, early/late UI, Save and same-process Load.
Ordinary caption readiness: 802 samples, median 111.266 ms, range 97.365–123.600 ms.
The intentional 100 ms advance input guard remains; this is not 111 ms of pure
computation. Across 27 entry transitions the median was 103.261 ms and maximum
201.142 ms. Seven unplayed-board Challenge-result handoffs ranged 95.718–109.870 ms;
played-board transitions and other branches were not exercised.

Day7 Settings samples were 52.080, 48.238 and 51.575 ms. These harness endpoints
include frame waits and are not pooled with the narrow dispatch benchmark.
History median was 57.730 ms (six samples); manual Save flow median 95.165 ms,
range 74.768–279.947 ms (six samples). First slot creation and subsequent overwrite
confirmation differ. New Game flow after setup was 510.492 ms; same-process
Title-to-Day7 Load was 170.694 ms. Single samples are not tail distributions.
These remaining totals do not establish invisible latency or justify deleting
storage checks; feedback, durable completion and helper waits need separation
before a further Save/New Game cut.

## Verification and reproduction

- Matched Settings runs: four × 105 assertions, exit 0.
- Full naturally aged journey: 4,285 assertions, exit 0.
- Desktop consumer suite: 13 tests, 183 assertions, exit 0. Checks stable theme
  with live Home/title updates, all builder-input changes, large targets, Scene
  daylessness and calendar tint.
- Load creator: 3,748 assertions; two independent loaders: 118 each; diagnostic
  loader: 118. All exit 0, exact checkpoint/global discoveries retained.
- F5 fresh, fourth Save, and separate profile run: 24 assertions each, exit 0.
- Two startup baselines plus application-stage diagnostic reach enabled New Acc,
  exit 0. Engine benchmark teardown errors are excluded from clean acceptance.
- Comment/live-transition lints and whitespace checks pass.

[Evidence directory](../../tools/player_latency/evidence/2026-11-11-remaining-latency/)
contains raw compressed logs, measurements, source hashes, diagnostic patches and
runner/probe source. Diagnostic patches are gzip-compressed to preserve their
exact whitespace and are not applied to production. Copy the
`.py.txt`/`.gd.txt` runner sources to their original `.godot/ci/remaining/` paths
without the `.txt` suffix before reproduction. `run_load.py` refuses existing owned
output/isolated roots; retain old evidence and choose fresh roots before another
run. Its original embedded source is also named in `load-results.json`.

Use the same command as the first-open report for Settings with a fresh
`.godot/phase2r_tests/` root per run. Run timing processes serially, after import.
Standalone startup must omit `DWM_TEST_ROOT`; its runner isolates `XDG_DATA_HOME`.
No production instrumentation is present in the matched or uninstrumented baselines.

## Windows boundary and omissions

Cloud Windows workflow capability exists, but the available browser is signed
out and no Run workflow control is available. The connected GitHub tools do not
expose workflow dispatch. No Windows job was launched. The existing historical
comparison workflow is not evidence for this current revision:
https://github.com/Siuuuers/dwm/actions/workflows/trusted-runtime-comparison.yml

No claim that other gameplay is free of visible latency follows from these
headless samples. Windows exported display, frame pacing, audio continuity and
physical input-to-photon timing remain open. No broad matrix, fault injection,
new manager, save-format change, authored-delay change or general layout rewrite.
