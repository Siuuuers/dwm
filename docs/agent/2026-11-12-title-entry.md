# Title to first usable caption: current baseline

Revision: `5f26b3b09b0ea40309f273eae36d2372692db3e2` (PR #295).
Outcome: identify the largest avoidable part of the complete title New Acc action
before changing startup. No runtime change was justified or made in this pass.

## Method

Four sequential fresh-process runs, Linux Godot 4.6.3 headless, fresh XDG data per
run, shipped startup owners and authored first caption. Two click New Acc as soon
as the title mounts; two wait until runtime readiness plus two seconds. The probe
invokes the real button pressed signal, not physical pointer input. Completion
requires the expected full caption, current-line acknowledgement/completion,
visible caption and unblocked native input. It then opens Computer and verifies
that the caption stays unchanged. All four processes exited 0 without ERROR lines;
the Python runner asserted exact authored caption and parsed each result.

| Mode | Run 1 | Run 2 |
| --- | ---: | ---: |
| Early title click to usable caption | 2689.474 ms | 2360.247 ms |
| Settled title click to usable caption | 289.818 ms | 293.142 ms |
| Early click to runtime ready | 2330.145 ms | 2042.456 ms |

The runtime-readiness wait dominates early clicks. Early runtime-ready to caption
is 359.329 / 317.791 ms. The settled mode deliberately waits two seconds after
runtime readiness; that idle time is outside action timing.

## Attribution and independent audit

Read current StartupLoader, ApplicationBootstrap, MenuScene and SaveManager
new-run paths and the current Scene contract; independent read-only review agrees:

- Resource requests are serial; completion is harvested on process frames.
- Runtime owners install one per frame; bootstrap stages advance one per frame.
- First title draw precedes background runtime loading by design.
- Current Scene new-run settlement calls its pair settlement with responsive=false.
  The six conditional SaveManager frame yields are not active on this path.
- MenuScene's busy presentation uses two process frames. These are a smaller part
  of the operation and provide presentation/custody boundaries.
- Native caption input readiness remains an independent requirement.

Trace intervals labeled GameState resource loading span roughly 704–835 ms;
SceneRouter roughly 338–400 ms. These identify dependency-loading candidates,
not isolated function profiles. An interval labeled Gallery spans 186–204 ms,
but overlaps runtime construction: it must not be claimed as Gallery's isolated
cost or used to justify dropping it from readiness. Gallery is already loaded via
title destination prefetch, not the bootstrap RUNTIME_RESOURCES list.

## Decision and next bounded investigation

Keep startup scheduling and all persistence/recovery checks unchanged. A new
batching/budget mechanism would add complexity before showing it fixes the largest
cost. Next investigate the GameState/SceneRouter preload dependency graph and
attribute load versus owner construction with temporary spans. Compare complete
early and settled click operations, and title readiness, before accepting changes.
Do not trade faster first caption for a longer frozen frame or slower title.

No speedup claim, rendered screenshot, Windows export, cold OS-cache guarantee,
broad test matrix or injection campaign. Existing input pacing remains unchanged.
This documentation-only result needs no unrelated test suites; git diff --check
passed. The four real-startup probe runs are the evidence.

## Reproduce

Copy evidence startup.gd and run.py into `.godot/ci/title-entry`. On fresh output
and user directories run `python .godot/ci/title-entry/run.py early`, then the same
command with `settled`. Preserve fresh user state: rerunning the same directory
can trigger replacement confirmation and changes the measured journey. JSON
contains monotonic engine timestamps and loader transitions; logs are gzip files.
