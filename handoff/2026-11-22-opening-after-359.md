# Handoff · Early New Game after #359

Start from master at `16fecfaa2bdd85e41379179464179bb32658fff5` or newer. Check open PRs before editing. At the investigation baseline, #359 was merged and there was no open PR. The hourly cleanup was disabled by request. This handoff changes documentation only.

## Observable outcome

An immediate press on New Game at Title should reach Sylvia’s first complete, input-ready caption sooner. Opening the Computer immediately afterward must preserve that caption. Also compare first Title availability, settled New Game, the largest frame gap after the click, and first Computer open so a change cannot conceal a delay by moving it to another action.

## Rendered Linux baseline

Godot 4.6.3, imported source project, X11 virtual display, software OpenGL compatibility rendering and dummy audio. Six separate processes with fresh user directories, alternating early and settled. An early press is emitted as soon as the Title node is ready. A settled press waits two seconds after runtime readiness. That intentional wait is excluded from click timing. The Title timestamp measures node readiness on the engine clock. The caption measurement includes a rendered frame after acknowledgement and input readiness.

| Click mode | Engine to Title (ms) | Click to runtime ready (ms) | Click to usable caption (ms) | Largest observed post-click frame gap (ms) | First Computer open (ms) |
|---|---|---|---|---|---|
| Early, runs 1–3 | 3837 / 3074 / 3120 | 2623 / 2339 / 1999 | 2957 / 2678 / 2365 | 200 / 198 / 219 | 89 / 86 / 87 |
| Settled, runs 1–3 | 2908 / 3143 / 2995 | Already ready | 299 / 311 / 278 | 180 / 159 / 159 | 16 / 18 / 16 |

All six processes exited successfully, showed the exact shipped teacup caption and retained it after opening the Computer. The early wait for runtime readiness accounts for 85–89% of click-to-caption time. These are source-build observations on cloud Linux. OS caches were uncontrolled. Windows release timing and physical input latency remain unmeasured.

## First investigation

1. Trace the two longest recurring early resource intervals in `autoload/StartupLoader.gd`. The observed GameState intervals were 740 / 634 / 412 ms and SceneRouter intervals were 506 / 364 / 308 ms. These labels include dependency and polling time. Use temporary spans around request, completion harvest and owner attachment before attributing cost. Compare the current graph with the [previous dependency investigation](../docs/agent/2026-11-12-runtime-dependencies.md).
2. Look for one dependency in either graph whose first actual consumer occurs after the first caption. Trace direct and transitive preload paths from both Title and runtime. For example, HospitalFrozenContext also enters via DialogicBridge and FrozenRunContext. Removing one GameState reference alone would leave it reachable. DatingPhysicalOwner participates in startup wiring and recovery, so its name alone is insufficient evidence for deletion.
3. If there is a uniquely deferrable dependency, change only that edge on a disposable branch. Alternate baseline/candidate/candidate/baseline in both click modes, then exercise its first actual consumer. Retain a change only if the complete early journey improves reproducibly and the settled journey, frame pacing and first-use action remain acceptable. If the spread obscures the effect, report the uncertainty. Previous trials already rejected blanket dependency subthreading and [optional Settings/Backup deferral](../docs/agent/2026-11-12-optional-pause.md).
4. If the dependency audit yields no candidate, profile settled New Game with fresh and representative populated Global profiles. `SaveManager._start_scene_new_run_in_memory` captures a full profile and `ProfileRestoreParticipant.prepare_frozen_profile` copies and validates it. The same plan builder also consumes the durable journal candidate on recovery. Time the whole operation first. Any change must preserve pending reading marks, frozen recovery material and rollback isolation. Use the existing prepared-New-Game and creation-storage-recovery tests for that path. Skip this change if its cost is negligible.

## Reproduce the current baseline

From an imported checkout with Godot 4.6.3 on PATH, use a fresh Linux X11 display with software rendering. Run the following once per sample, switching `early` to `settled` on alternate runs. Use the project’s probe under its ignored scratch directory so the historical evidence directory need not be imported.

```bash
mkdir -p .godot/ci/title-handoff
cp docs/agent/evidence/2026-11-12-title-entry/startup.gd .godot/ci/title-handoff/probe.gd
sample_home=$(mktemp -d)
mkdir -p "$sample_home/godot/app_userdata/DWM"
XDG_DATA_HOME="$sample_home" LIBGL_ALWAYS_SOFTWARE=1 DWM_STARTUP_AUDIT=1 \
  DWM_CLICK_MODE=early DWM_EARLY_COMPUTER=normal \
  godot --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy \
  -s res://.godot/ci/title-handoff/probe.gd
```

Check the exit code and engine errors. In `FIRST_CAPTION`, subtract `click_us` from `caption_us` and divide by 1000. Confirm the caption is “Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself.” In `EARLY_COMPUTER`, verify `same_caption` is true. Retain the complete trace with each candidate comparison.

Recent changes already cover Global reading on Quit (#353), save recovery dispatch (#354), Title commit/retry and consent (#355–356), focused workflow checks (#357–358), and narrow preference reads at startup and Load (#359). No new lint rule or broad test run is needed for this baseline.
