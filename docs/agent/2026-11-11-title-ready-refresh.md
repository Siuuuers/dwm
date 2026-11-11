# Keep the initialized title presentation at runtime readiness

Base: 49aa8a23219d671b32f589d8d7709bef250a8e9f (PR #279).
Outcome: normal gameplay readiness must not rebuild an already initialized title;
startup recovery must still apply the saved locale, size and font.

## Owner and change

MenuScene builds its presentation when mounted. Normal start_title has already
initialized Profile and Localization. The later application_ready signal repeated
the full title theme, clock, welcome and navigation refresh without new inputs.
Connect that signal only when bootstrap.title_ready is false at mount time.
Keep the existing preference and locale signal listeners and destination gating.

Unconditional deletion was rejected during caller review. Recovery after the
initialize_saves stage can mount the title before Profile and Localization are
initialized. Those initializers do not normally emit the preference/locale signals
the title listens to; application_ready must refresh that fallback presentation.
Manual startup retains the same connection. No save format or data owner changes.

Scope: one production condition in scripts/ui/MenuScene.gd; focused title test
and evidence. The standalone title test also needed the current StartupLoader
resource seam. Its fixture loads real destination resources synchronously; it
does not test background scheduling. The real early-click journeys cover that.

## Measurement

Godot 4.6.3, Linux headless source project with imported assets, fresh user folders,
one engine at a time. Two diagnostic baseline runs observed two title refreshes:
initial 39.562/24.571 ms, redundant 1.701/1.850 ms. Two candidate diagnostic runs
observed only the initial refresh. This removes measured work, but does not
establish a perceptible startup speedup.

Six uninstrumented startup runs: B,C,C,B,C,B. Four immediate-title-click journeys:
B,C,C,B. These are ready-control observations, not rendered first-paint timings.

| Observation | Baseline | Candidate |
| --- | --- | --- |
| Title-ready median, three samples | 3.550047 s | 3.645742 s |
| Runtime-ready median, three samples | 5.407062 s | 5.533861 s |
| Launch to usable caption, two samples | 6.088431 / 6.431147 s | 5.730339 / 6.156624 s |

Ranges overlap and cloud variation exceeds the removed work. Do not attribute
the whole-operation differences to this condition or claim an overall speedup.
All four early journeys reached the exact opening caption, fully revealed,
acknowledged, native-complete and input-unblocked. Computer opened without changing
the caption. One candidate journey logged ObjectDB instances leaked at exit;
the other journeys and all six startup runs had no warnings. No engine errors.

## Focused checks

GODOT_CONSOLE_PATH=/usr/local/bin/godot python tools/title_shell/verify.py
passed 351 checks: normal readiness retains theme identity and focus; recovery
adopts zh-HK, 150% and readable font without preference signals; existing title
navigation, typography, clock, Settings and shutdown checks pass. The disposable
project logs UID-to-path fallback warnings. Its first attempt exposed the missing
loader fixture; the retained result is the corrected passing run.

Independent read-only review checked normal, recovery and manual startup ordering,
title destination gating and the focused test. No blocking findings remained.
Skipped Windows export, rendered raster checks, broad suites and new lint rules:
the change concerns signal subscription, with no layout or pixel-style changes.
No production cache, manager, dependency or new preference was added.

Evidence: tools/player_latency/evidence/2026-11-11-title-ready-refresh. Copy the
scripts into .godot/ci/title-refresh and rename observe.gd.txt to observe.gd.
Use fresh output/user folders. compare.py and early.py capture current candidate
bytes, alternate against the pinned base and restore candidate bytes in finally.
profile.py instruments current bytes; run on base for the baseline trace and
profile_candidate.py on candidate for its trace. Source is restored in finally.

The remaining multi-second startup is not explained by this duplicate refresh.
Further work needs attribution of the larger dependency-loading spans or current
packaged-Windows evidence, rather than extending this small presentation change.
