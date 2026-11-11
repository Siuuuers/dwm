# Reuse caption theme when layout mode changes

Baseline: 5affa3d0dea8c31178450445de9ad53e65e53055 (PR #276).
Outcome: retain the same caption, split panel and input behavior while avoiding
full presentation setup when only dating/split-panel layout mode changes.

## Cause and change

WitnessedCaptionLayer.configure_dating_overlay rebuilt presentation through
configure_presentation. WitnessedCaptionTheme.build does not use its dating-mode
argument. No locale, font, size, palette, day or accessibility preference changes
at this transition. Rebuilding also repeated transport, speech and history setup.

Replace that call with _layout_self_talk. Keep the split-surface binding, mode flag,
canvas guard and _layout_stack. The latter handles the mode-dependent scrollbar
inset and existing font/layout work. The self-talk call retains sizing against the
newly bound portrait surface. Real preference and run-presentation changes still
use their existing configure_presentation owner. No cache, new state or helper.

## Measurements

Current baseline attribution: the first caption _ready cost about 25 ms, including
about 10 ms of initial preference/presentation configuration. Initial theme setup
is necessary and remains. At art publication, a second mode configuration cost
7.686 and 7.783 ms. With the one-line change, the corresponding diagnostic span
was 0.454 ms. The redundant second configure_presentation call disappeared.
These are instrumented nested spans, not additive whole-action measurements.

Six uninstrumented fresh-user Linux headless runs used B,C,C,B,C,B order:

| Revision | New Game to usable caption (ms) | Median (ms) |
| --- | --- | --- |
| Baseline | 292.778, 295.084, 252.290 | 292.778 |
| Candidate | 309.688, 294.954, 275.031 | 294.954 |

There is **no measured whole-action improvement** in this small noisy sample.
The evidence supports removing repeated setup, not a promised startup saving.
All six runs preserved the exact fully revealed opening caption, native completion,
acknowledgement, input readiness and caption after opening Computer. No warnings
or errors occurred. Two baseline diagnostic runs and one candidate diagnostic run
also completed the same journey.

## Focused checks

Linux mode-reset test: 1 test / 59 assertions passed. The existing native-text and
history preservation test now also requires the identical theme object when
switching out of and back into dating layout. This checks the targeted ownership
rule without adding a new test framework. No source text or saved-data format changes.

Rendered Windows [run 43026507130](https://github.com/Siuuuers/dwm/actions/runs/43026507130)
passed on f89695032fde133c28fc12efe4043dbfda855805, with identical runtime/test
files and a temporary verification-only workflow. Five selected tests / 339
assertions cover transparent centered captions at 100/125/150%, long-text scrolling
with both target sizes, mode reset/history, mouse split dragging, and touch/keyboard
input custody. The fixture reports its missing self-talk localization key; no engine
errors. Windows uses ANGLE / Microsoft Basic Render Driver after an OpenGL fallback
warning. Import also reports nested audio-prototype and shutdown-leak warnings.
This is rendered layout/input evidence, not physical-GPU performance qualification.
Independent side-effect/caller review passed. The temporary workflow is not merged.

## Reproduction and omissions

Evidence: tools/player_latency/evidence/2026-11-11-caption-mode-theme. Copy scripts
and probes to .godot/ci/caption-mount; rename .gd.txt probes to .gd. compare.py swaps
only WitnessedCaptionLayer.gd against the recorded baseline and restores candidate
bytes in finally. attribute.py and attribute-candidate.py instrument the CURRENT
source, so select the intended revision first and use fresh output/user folders.
Run engines sequentially. Run the existing GUT test_dating_caption_style.gd with
-gunit_test_name=test_dating_review_and_hospital_scope_reset for the local check.

Skipped unrelated suites, new injection checks, a broad rendering matrix and a
new exported build. Only layout mode setup changed. Initial preferences, fonts,
artwork loading and necessary input guards remain. Headless times are not physical
first-paint or Windows timing evidence.
