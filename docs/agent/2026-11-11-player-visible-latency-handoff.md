# Player-visible latency handoff

Date: 11 November 2026 (Hong Kong). Reviewed master:
`5ee8ea15b4cfacc33d70ff8df1e71213f1326c49`.

## Outcome and status

Determine whether players encounter noticeable stalls in the exported Windows
game, then reduce the largest reproducible unintended stall without changing
approved behavior. One performance-session coordinator owns measurements,
overlapping runtime edits and publication.

This is a handoff, not a completed performance assessment. No new Windows run,
rendered measurement or audio capture accompanied it. Execution remains deferred
until planned features settle or the user chooses to start this assignment.
Refresh master, open work and the export revision before measuring.

We have not established either that gameplay is free of noticeable latency or
that it currently has a serious latency problem. The recent test cleanup in
[PR #254](https://github.com/Siuuuers/dwm/pull/254) and
[PR #255](https://github.com/Siuuuers/dwm/pull/255) reduces test preparation only.
Passing assertions and shorter test runs do not establish player responsiveness.

## Measure these actions first

| Action | Observable completion |
| --- | --- |
| Ordinary Advance and passage/Challenge-result handoff | Correct next caption is displayed and the intended input becomes available |
| Save / quick Save | Feedback appears; separately record durable completion and whether input/rendering stalls |
| Load | Correct saved scene is displayed and usable, with current global preferences and discoveries preserved |
| History and Settings | Requested content is visible and usable; close returns control correctly |
| New game / startup | First intended interactive screen or caption is visible and usable |

Distinguish authored reveal, dissolve, audio and input holds from unintended work.
Do not remove deliberate presentation timing to improve a number. Inspect both
first use and repeated use. Include a naturally aged late-game session for the
worst reproducible transition; loading an old checkpoint into a fresh process
is a different workload.

## Evidence and method

1. Reuse existing probes before adding tooling. Start with
   `tests/manual/benchmark_player_latency.gd`,
   `tests/manual/benchmark_aged_scene_advance.gd`,
   `tools/testing/Invoke-ExportedGameplay.ps1`,
   `tools/testing/Probe-ExportedWindow.ps1`, and
   `tools/testing/Invoke-StartupLoadComparison.ps1`.
   Inspect their actual timing endpoints and supported environments first;
   none should be assumed to measure physical display latency.
2. Use cloud Linux for source-level attribution and focused behavioral checks.
   Use an exported Windows build for Windows conclusions. Record commit, build
   hash, Godot version, OS, CPU/GPU, resolution, refresh rate, display/VSync mode,
   language, text size, reveal/Auto settings, and the starting save/profile.
   Start with the intended 1920x1080 borderless presentation and default 125%
   text; add 150% only where changed layout behavior needs it.
3. Record input dispatch, logical readiness and the first correct rendered
   result separately where available. A frame callback is not physical
   input-to-photon evidence. Remote-stream delay also differs from game delay.
   State capture frame rate and uncertainty; use synchronized input/video
   evidence for visible-response claims, or report the narrower endpoint.
   Inspect frame stalls and capture audio continuity across the same actions.
4. Keep first-use, repeated-use and naturally aged results separate. A fresh
   process does not imply a cold OS cache. Match content, profile/discoveries,
   save bytes, machine and settings; record sample counts and run order.
   Use a small repeatable batch first, extending it only if variability prevents
   a conclusion. Report individual samples, median and range; do not manufacture
   a tail percentile from a tiny sample or declare a universal millisecond limit.
5. If a stall reproduces, identify its dominant operation before editing.
   Keep expected-data construction, assertions and screenshots outside timers.
   Label helper waits and nested profiling spans; do not sum inclusive spans.
   Change one demonstrated cause, then compare alternating baseline/candidate
   runs with diagnostic instrumentation removed. Keep a no-change result when
   measurements do not justify surgery.

If an interactive Windows environment or suitable capture is unavailable,
continue useful Linux attribution and record that limit. Request the missing
environment only when necessary; do not substitute headless timing for visible
Windows qualification or make the user repeat setup already available in cloud.

## Failures to preserve checks for

- Early feedback hides a continuing freeze or precedes durable Save completion.
- Load looks ready but shows the wrong beat, repeats a consequence, changes the
  board, loses local History, or rolls back global preferences/discoveries.
- A faster transition drops authored effects, input holds, choices or audio.
- First use improves while repeated use or naturally aged play regresses.

Retain existing data-loss handling, boundary validation and accessibility.
Do not add injection campaigns, speculative managers or broad test matrices.
Run focused unit checks for isolated logic, integration checks for ownership or
storage changes, and a rendered affected journey for visible behavior changes.
Verify selected tests ran with positive assertions on the candidate revision.

## Acceptance and publication

For each investigated action, preserve: tested revision/build, reproduction,
commands and exit codes, raw timing/capture evidence, behavior checks, and limits.
A performance fix needs a repeatable improvement in the complete affected
operation with no material regression in its relevant first-use/repeated/aged
cases. Report unchanged and slower cases as well as improvements. Do not add
host-sensitive timing gates or claim all-game smoothness from a narrow route.

Publish a focused PR with linked evidence and remaining gaps. If no worthwhile
stall reproduces, record that bounded result and stop; no rewrite is required.
Ask for a product decision only if a solution would change intended presentation
or an unresolved acceptable-delay requirement becomes necessary.

## Existing context: do not redo completed work

The [passage performance handoff](2026-11-05-passage-latency-handoff.md) contains
historical Linux Challenge-transition and Load measurements, completed runtime
optimizations, preserved behavior, probes and durable report links. Its numbers
are not a current Windows baseline. Its implementation details remain useful;
this document is the entry point for the broader visible-experience follow-up.

The [CI handoff](2026-11-10-challenge-ci-coverage-handoff.md) tracks completed
selection/checkout changes. CI duration is a separate concern from gameplay
latency. The remaining public-surfaces checkout lead requires its own measured
cost before work. No new lint framework or further blanket test deletion is
part of this assignment.
