# Runtime dependency loading: attribution and rejected threading trial

Base: `125cd6257d9fc6be959ec6fcd52d2399400412c8` (PR #296).
The transient checkout was restored from GitHub; Godot 4.6.3 reimported assets.
Current master matched the recorded base. No runtime change is retained.

Outcome: reduce early title-to-caption wait without postponing the title or
increasing frame stalls/first-use pauses. Read current Scene contract, StartupLoader,
GameState, SceneRouter, pause controller and title resource prefetch. Independent
read-only audit traced the dependency ownership before the trial.

## Attribution

Temporary StartupLoader spans, one fresh-process early-click run:

| Operation | Elapsed |
| --- | ---: |
| GameState threaded request to completion observation | 716.281 ms |
| GameState construction / tree attachment | 0.190 / 0.021 ms |
| SceneRouter threaded request to completion observation | 255.260 ms |
| SceneRouter construction / tree attachment | 0.020 / 0.011 ms |
| Dialogic tree attachment | 128.852 ms |
| Runtime preparation | 0.152 ms |
| Five runtime advance calls | 16.831 / 0.301 / 0.053 / 0.131 / 4.562 ms |

Request spans include polling latency and dependency work, not pure I/O or parser
CPU time. Tree attachment includes ready callbacks. These inclusive spans are not
additive across overlapping work. Construction is not the dominant cost.

GameState's literal preload graph is mostly domain/schema/narrative code, with no
clear unused UI edge. SceneRouter preloads ProductionPauseController, which pulls
PauseSurface, BackupApp, SettingsApp, WitnessedCaptionLayer, Day7PreludeSurface and
PauseQuickCommands. Method-local preload is still eager. Settings/Backup instances
are already lazy, but their resource dependencies load early. Shared dependencies
overlap title/runtime loading; raw graph size is not unique overhead.

## One-line trial, rejected

Changed only `ResourceLoader.load_threaded_request(_active)` to
`ResourceLoader.load_threaded_request(_active, "", true)` to allow dependency
subthreads. Four sequential fresh processes, A/B/B/A, identical early-click probe:

| Run | Engine start to title | Click to usable caption | Largest observed frame gap | First Computer |
| --- | ---: | ---: | ---: | ---: |
| Base A | 3405.614 ms | 2229.117 ms | 143.107 ms | 98.493 ms |
| Candidate A | 3548.019 ms | 2335.470 ms | 160.349 ms | 116.841 ms |
| Candidate B | 2797.581 ms | 1990.527 ms | 125.213 ms | 102.485 ms |
| Base B | 3524.335 ms | 2269.927 ms | 156.074 ms | 101.852 ms |

Results are variable and overlap. Candidate A worsens all four observations;
Candidate B is faster from before the title too. This does not establish a reliable
end-to-end benefit. Restore the original call; do not ship the setting based on a
small favorable median. No settled-case expansion was needed after rejection.

## Checks, limits and next step

One instrumented plus four uninstrumented real-startup probes exited 0, with no
ERROR lines, exact authored first-caption text, acknowledgement/input readiness,
and unchanged caption after Computer opens. The runner asserts these observations.
No runtime tests were changed; all temporary instrumentation/trial edits restored.
`git diff --check` passed. Asset import had an unrelated GUT online version-check
error and shutdown leak warning; all measured runtime logs passed their checks.

Linux headless only, fresh process but not guaranteed cold OS caches. No rendered
or Windows smoothness claim, broad matrix, export or injection campaign. No new
cache, manager, lint rule or runtime code. The result is attribution and a rejected
optimization, not a claimed speedup.

Next candidate: measure deferring optional pause Settings/Backup resources through
existing idle prefetch, checking early/settled startup AND first Settings/Backup
opening together. Do not defer the whole pause controller: it is configured during
startup and would simply shift work. Audit shared preload edges before any edit.

Reproduce: copy startup.gd, run.py and profile.py to `.godot/ci/dependency-audit`.
Run `python .godot/ci/dependency-audit/run.py early <fresh-label>` once per revision.
`profile.py` temporarily instruments StartupLoader and restores it in finally.
Each label owns fresh user data; do not reuse labels for startup comparisons.
