# Checkpoint activation and entry pause audit

Base: `dbaef2dabc689e89ad2e43b32cdabf5fa35fa7a7` (PR #290).

## Outcome and scope

Restore the same full caption and held control without replaying consequences.
DialogicBridge owns activation; the runtime adapter owns native position capture.
One redundant `_scene_restore_current()` check is removed from confirmation:
`_capture_scene_restore_position()` already performs it immediately before the
synchronous capture. The line and control capture implementations do not yield or
emit callbacks. Existing failure handling and position equality remain.

Only this confirmation call site changes. The similar validation check remains
because removing it would change a public diagnostic failure code. No save format,
input timing, source ownership, compilation cache or style cache changes.

## Investigation before editing

- Fetched master; it matched the base. Reviewed current scene contract, both
  position-capture callers and concrete line/control capture implementations.
- Fresh-process checkpoint Load: 187.587 and 214.008 ms from action to usable.
  Repeated Load: commit to usable 122.084–132.779 ms; confirmation action timing
  is separate in the evidence.
- Two Day1 through first Day2 journeys: first Day2 caption usable in 98.779 and
  99.579 ms. One earlier Day1 result transition was 165.890 ms in the second run;
  the other measured transitions were 92.755–99.197 ms. Do not call all transitions
  uniformly fast from this small sample.
- Instrumented base: current-state proof calls cost roughly 0.28–0.98 ms each;
  first style preparation 29.150 ms (warm 3.224–3.583 ms); native restore call
  3.624 ms (warm 2.698–3.018 ms). Spans can nest and must not be summed blindly.
- Text-section installation starts Dialogic `text_reveal_skip_delay` (default
  0.1 seconds). Instant full-caption restoration does not clear it. The usability
  benchmark waits for input unblocking. This is separate from organic-reveal
  `advance_delay`; neither is removed as a performance optimization.
- Repeated proof calls come from confirmation, phase validation and publication,
  rather than frame polling. Compilation and same-style reuse already have caches.

## Focused verification

Candidate: existing checkpoint benchmark, 143 assertions, passed. First usable
213.747 ms; repeat commit-to-usable 123.311 / 125.410 / 124.034 ms. This overlaps
baseline; **no complete-operation speedup or visible improvement is claimed**.
Candidate profiling flags match the existing-hook diagnostic configuration;
this is not an uninstrumented matched performance experiment.

Native integration filter `test_real_native_restores` passed both tests, 76
assertions: restores the saved second caption without replay; restores the held
control predecessor and consumes its source once. Total candidate assertions: 219.
Both commands exited 0, XML reported passes, logs contained no ERROR lines.
`git diff --check` passed.

Earlier baseline evidence includes two entry journeys (1,180 assertions each),
two checkpoint loader processes (143 each), and the creator (3,748 assertions).
Temporary profiling wrappers were restored before the final candidate tests.

## Reproduction and limits

Run `python tools/player_latency/run_checkpoint_load.py` on a clean measurement
output directory. It creates the authored seed and restores the same absolute
user path before each loader. Attached scratch probes expect the existing seed
under `.godot/ci/checkpoint-load/results/seed-root`; copy probes into
`.godot/ci/activation-pause` before use. `load_profile.py` restores that seed and
runs one instrumented loader; `restore_spans.py` temporarily wraps three methods
and restores them afterward. `entry_run.py <fresh-label>` runs two authored
journeys. `focused.py <fresh-label>` runs the two native integration cases.

Linux Godot 4.6.3 headless, sequential processes. Fresh process does not imply
cold OS caches. No Windows rendering, exported build, screenshots, broad CI matrix,
injection campaign or new lint rule. No behavior is retired. A generic lint rule
cannot prove this synchronous call-chain duplication safely.

Next design decision, if faster restored-caption input is wanted: whether Load
should retain the same 100 ms input block as newly displayed text. Treat that as
an input-behavior change and check click-through/advance intent, not code trimming.
