# Remove unused readable-font preloads before title

Baseline: c13d92ae4b7af8c23c72f56b0bbafdd7bb161bf2 (PR #277).
Outcome: make the default English pixel-font title ready sooner without changing
selected fonts, fallbacks, first-click behavior or saved preferences.

## Investigation

Two fresh-profile Linux diagnostic runs attribute startup to:

| Operation | Observed time |
| --- | --- |
| Bootstrap script loading and construction, including dependencies | 1.33–1.54 s |
| Dialogue bridge script loading, including dependencies | 0.78–0.80 s |
| Save initialization | 0.43–0.48 s |
| Localization initialization | 0.087–0.088 s |
| Title shell construction | 0.056–0.090 s |

Script-load spans include dependent resources, not only script parsing. Three
shared theme scripts still preloaded the SC and HC readable font files even
though font selection already uses UiTypography's path-based loader. Removing
only one declaration leaves the other eager paths active.

## Small change

Remove SIMPLIFIED and TRADITIONAL constants from UiTypography, DesktopTheme and
SettingsTheme. No production caller used SIMPLIFIED. Only UiTypography's Japanese
and Korean story fallback used TRADITIONAL; it now loads the identical HC resource
inside that existing branch. Keep the English constants with their real callers.
The shop-card metric fixture now requests its SC/HC faces through the existing
font function. No new font cache, dependency, manager or fallback rule.

A separate title-cache observation confirms both SC/HC readable resources were
cached on the baseline English title and neither was cached on the candidate.
Japanese/Korean story fallbacks retain resource identity/order; selected readable
Chinese fonts still load when requested. Assets remain included in exports.

## Matched launch measurement

Godot 4.6.3, Linux headless, fresh profile per process, same imported checkout,
sequential B,C,C,B,C,B order. Times use the engine monotonic clock. Title readiness
requires a ready menu and visible available New Game button; this is not physical
paint. Background readiness is the existing bootstrap ready state.

| Revision | Title ready samples (s) | Median (s) | Runtime-ready median (s) |
| --- | --- | --- | --- |
| Baseline | 4.227334, 4.059018, 3.799012 | 4.059018 | 6.144837 |
| Candidate | 3.531488, 3.610936, 3.960874 | 3.610936 | 5.645920 |

Observed title median reduction: 0.448082 s (about 11%). Ranges overlap and the
cloud host varies; do not promise that exact saving on a player's Windows PC.
One baseline logged an ObjectDB shutdown warning; candidates were clean. Cache
probe runs are attribution evidence, excluded from these six timing samples.

## Focused validation

Linux font-style suite: 7 tests / 1,621 assertions passed with clean logs. It covers
five languages, pixel/readable styles, 100/125/150%, all themes, glyph coverage,
shared-face isolation and story fallback metrics.

Rendered Windows [run 43029814654](https://github.com/Siuuuers/dwm/actions/runs/43029814654)
on 6fbf527921cbb490d9490bc2358c0f54e3799da3 passed the same 7 tests / 1,621 assertions
plus the Chinese shop-font metric case (1 test / 54 assertions). Exact runtime and
test files match this candidate; the temporary verification workflow is excluded
from the final change. Windows used ANGLE / Microsoft Basic Render Driver after
an OpenGL fallback warning. Import reported the existing nested audio-prototype
and ObjectDB shutdown warnings; focused test processes had no engine errors.
Independent caller/fallback review found no remaining removed-constant consumers.

Four settled-title New Game/Computer runs passed (B,C,C,B). Caption latency:
baseline 320.887/282.606 ms, candidate 264.153/318.219 ms; no clear first-click
regression, not a proven speedup. One baseline shutdown warning, candidates clean.
A further immediate-title-click pair passed exact usable-caption and Computer
checks while background loading continued. These diagnostic early-click runs
are excluded from the settled-title timing samples; raw results are retained.

## Reproduction and limits

Evidence: tools/player_latency/evidence/2026-11-11-launch-font-preloads. Copy the
scripts/probes into .godot/ci/launch-breakdown; rename .gd.txt probes to .gd.
profile.py instruments the CURRENT revision. compare.py and font-probe.py swap the
three production files against the baseline and restore candidate bytes in finally.
journey.py does the same for complete New Game/Computer checks. Use fresh output
and user folders and run engines sequentially. Original startup probe is the
unchanged tests/manual/benchmark_player_startup.gd.

Skipped unrelated suites, a broad screenshot matrix, new injection checks and a
new exported build. These timings are Linux source-project startup, not matched
Windows executable timings; export uses script_export_mode=2. A larger startup
owner reorganization is not justified by this small font fix. Save recovery and
all title-phase owners remain unchanged.
