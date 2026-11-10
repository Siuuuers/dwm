# Settings first-open initialization

Date: 11 November 2026 (Hong Kong).
Follow-up to the [Linux investigation](2026-11-11-linux-latency-investigation.md).

## Result and scope

Follow-up: [remaining-latency investigation](2026-11-11-remaining-latency.md)
measures Settings subparts, retains unchanged computer-shell presentation, and
records current fresh Load, F5 Save, startup and aged-route results.

Scene Settings now receives its actual run palette and dayless Scene context
before entering the tree. Its first `_ready` builds the presentation it will use,
rather than building default calendar presentation and replacing it afterward.
The existing post-mount dependency/readiness check still precedes caching/showing.
Other apps retain their existing preparation order. No new cache or manager.

`ApplicationBootstrap` still owns current run palette selection; `ComputerDesktop`
still owns mounting and readiness admission; `SettingsContent` still owns theme
construction and current preference application. Reopening, preference refresh,
large targets, focus and accessibility behavior are retained. Settings defaults
still require controls, fonts and layout: default values do not imply zero cost.

## Matched measurement

Baseline: `6233dbd76acc14bce0588d32b45088942b786eeb`.
Measured candidate: `bb37abb5a906f60286b90997981cb29158ba66ac`.
Godot 4.6.3 standard, Linux headless, shared AMD EPYC 9V74 host. Four serial fresh
processes ran in **B/C/C/B** order with fresh isolated profiles and the unchanged
`benchmark_settings_reopen.gd`. English, instant reveal, Auto off, 125% text.
No runtime instrumentation. Preparation, assertions and close-helper waits are
outside the input-dispatch timer. First use does not mean cold OS file cache.

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| First dispatch, process 1 | 305.432 ms | 230.905 ms |
| First dispatch, process 2 | 271.729 ms | 224.963 ms |
| First dispatch median | 288.581 ms | 227.934 ms |
| Repeated dispatch median, eight samples | 56.431 ms | 56.317 ms |
| Repeated dispatch range | 54.104–65.762 ms | 53.489–69.299 ms |

The approximately 61 ms first-open median reduction supports this bounded cut.
Repeated opening is effectively unchanged; some candidate repeated samples were
slower. Two first-use samples per variant do not establish a universal percentage
or tail latency. These are synchronous viewport-input dispatch measurements,
not Windows input-to-photon timing. Settings still has remaining first-use cost.

[Raw samples and logs](../../tools/player_latency/evidence/2026-11-11-settings-first-open/)
include following-frame endpoints, runtime/probe hashes and exact run order.

## Focused checks

The new regression uses real Settings, Profile and Localization with memory
storage. It checks pre-tree/pre-ready Scene configuration, midnight/dayless
presentation, retention of the first ready theme, successful post-mount readiness,
and reuse of the same app/theme on reopening. It fails on baseline (16/23
assertions passed, exit 1) and passes in the candidate consumer suite.

- Four matched benchmark processes: 105 assertions each, exit 0.
- Scene desktop consumer suite: 12 tests, 154 assertions, exit 0.
- Existing real Settings presentation test: 12 assertions, including 150% text
  and large targets, exit 0.
- Comment lint, live-transition lint and whitespace checks pass.

The final review retains the pre-existing Scene preparation refusal codes when
moving configuration earlier; successful opening is unchanged by that correction.
Final runtime revision: `84d38d4627a420eb93b77ab8efda09adf7e239e9`. Its consumer suite
passed 154 assertions and its production-path benchmark passed 105 assertions,
both exit 0. The full naturally aged route on `bb37abb` passed 4,285 assertions
before the refusal-code-only correction; no full-route rerun was needed for
that unchanged success path. Day7 Settings harness samples were 71.851, 64.113
and 81.232 ms. This is aged behavioral evidence, not a matched aged speedup
claim. Raw logs include the expected failing baseline regression.

## Reproduce

Import once, restore any editor-generated `project.godot` directory-map change,
and use a new isolated root per run. Do not overlap timing processes.

```bash
DWM_TEST_ROOT="$PWD/.godot/phase2r_tests/settings-comparison" \
XDG_DATA_HOME="$PWD/.godot/phase2r_tests/settings-comparison/xdg" \
DWM_BENCHMARK_REVISION="$(git rev-parse HEAD)" \
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/manual/benchmark_settings_reopen.gd -gexit
```

Use `test_scene_desktop_consumer.gd` for the focused consumer suite. Select
`test_settings_scene_presentation` in `test_scene_app_preparation.gd` for the
existing current-preference/layout configuration check. The naturally aged
journey uses `benchmark_player_latency.gd`, selecting `test_player_latency`.

No broad matrix or fault-injection campaign is needed for this ordering change.
No save format, story timing, rendering layout or API signature changes. Windows
exported display, rendered pixels, audio continuity and other routes remain
unqualified. This improvement does not establish that all other gameplay has no
visible latency. Keep the intentional 100 ms Advance input guard unchanged.
