# Remove unused caption prompts

Base: `a5beed3394326fae0f134d3b2290eafc0acc400e` (PR #292).

## Outcome and investigation

Mount the existing caption, art and Choices UI without unused Glossary and
TextInput widgets. The witnessed style owns the layer list. Fetched master and
reviewed current Scene contract, style resources, addon UI/subsystems, authored
DTLs, application callers, preview checks and relevant tests before editing.
Independent read-only review confirmed no authored text-input events, configured
glossary resources or application registration/show calls. Current Scene
compilation refuses native TextInput events. Neither widget owns save data.

Remove only layers 14 and 16 and their resource references. Keep remaining IDs,
editor latest-layer counter, Choices, addon subsystem registration, example files,
and all persistence/input behavior. A retirement record states that future native
text-entry prompts or glossary popups need UI supplied before authoring them.

## Measurement

Sequential fresh Linux Godot 4.6.3 headless processes, same absolute user path
restored from the authored checkpoint seed. No profiling flags. Order A/B/B/A.

| Run | First Load action to usable | Repeat commit to usable (ms) |
| --- | ---: | --- |
| Baseline A | 256.966 ms | 117.729 / 134.430 / 117.570 |
| Candidate A | 195.750 ms | 127.440 / 128.618 / 126.566 |
| Candidate B | 207.434 ms | 119.258 / 117.604 / 119.241 |
| Baseline B | 227.573 ms | 123.258 / 126.930 / 119.071 |

Only two samples per version; first-load timings favor the candidate but overlap
prior-session baseline observations. Do not claim a stable speedup percentage.
Repeat timings overlap. The definite reduction is two hidden widget trees,
glossary hover listeners/per-frame callback and text-entry signals. No Windows
or rendered smoothness claim; fresh process is not a cold OS-cache measurement.

## Checks and qualification

Final candidate passing checks: two checkpoint Load processes (286 assertions),
deferred first-caption initialization (27), focused GUI button priority over
caption acceptance (11), actual native choice UI and selected branch (13).
Total: 337 passing assertions. Logs/XML included; each passed command exited 0
with no ERROR lines. `git diff --check` passed. Independent audit completed before
final acceptance checks.

The existing production-skip choice test failed identically on base/candidate:
`entry_record_missing` for `contact.ordinary.lavinia.day1`, before choice UI is
reached. It remains unresolved and is not counted as a passing check. The bounded
native probe instead loads the real style and timeline, verifies five remaining
layers, single caption owner and absent text-input group, waits the existing
choice delay, invokes the native button callback and checks selected branch text.
It is a native callback probe, not a rendered physical-input E2E test. Its initial
attempt incorrectly emitted Button.pressed instead of invoking the native
_pressed callback; the corrected probe passes. An isolated-fixture localization
warning for witnessed.self_talk.name was observed; no product localization changes.

Copy attached probes/runners to `.godot/ci/optional-layers`. `load.py <label>`
expects the seed produced by tools/player_latency/run_checkpoint_load.py.
`focused.py <label> <integration-suite-name> <test-filter>` uses fresh test data;
`choice.py <label> unused test_trimmed_style_choice` runs the bounded native probe.

Skipped unrelated full suites, broad CI matrix, export, screenshots, injection
campaigns and new lint rules. No new runtime helper, cache or manager.
