# Minesweeper view controls — 2026-09-13

Acceptance evidence for `dwm-vky.5`, built on the feature branch after integrating
the concurrent clicking-lag changes through `c8aedfe78` (merge `0aea36565`).

- `automated-20260913.log`: 31 relevant suites, 446 tests, 13,068 assertions;
  all passed. Includes four preference scopes, strict old-profile migration,
  failed writes, new-account/save retention, all manual sizes, Fit geometry,
  real GUI input routing, held-input safety, and the affected gameplay/storage suites.
- `native-controls-20260913.log`: real final bootstrap and New Account, all three
  app tiers, explicit Fit activation from the new manual default, text sizes,
  actual 960×540/640×360 window resizing, rendered grid-line checks, flag-mode
  Chord, terminal difficulty change, Space for New Board, and normal round costs.
- `latency-20260913.log`: observation only, not a latency acceptance gate.
  App routine medians were 31.6 ms and 37.7 ms. The winning click's immediate
  handler took 34.3 ms, but processing across two frames took 1.78 s. Dating
  first Reveal/loss remained about 0.92/0.97 s. The parallel chat completed
  `dwm-634.1`; remaining latency belongs to its open parent `dwm-634`.
  View controls do not establish that clicking lag is solved.
- `runs.jsonl`: isolated runner commands, timestamps, exit codes, and evidence roots.

The screenshots show Expert manual 36, Traditional Chinese 150% with Large Targets,
and Expert fitted in a 640×360 window. The two manual captures precede the final
minor toolbar reorder to minus / size / plus / Fit; the native Fit capture includes it.
Native captures used Godot 4.6.3, OpenGL compatibility, and isolated test user data.

Touch and controller events exercised Godot GUI/focus routing synthetically.
Physical touchscreen/gamepad checks remain device acceptance work. The 24 Dialogic
orphans reported by these suites are the existing test-runtime teardown output.
This is focused feature/integration evidence, not a claim that the full repository
test tree or every open Bead passes.
