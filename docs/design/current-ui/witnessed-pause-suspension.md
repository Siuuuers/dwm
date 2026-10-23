# Preserving dialogue pause time during suspension

The accepted witnessed-scene behavior preserves remaining foreground time when playback is suspended. An authored native `[pause]` previously continued its `SceneTreeTimer` while the Dialogic owner was paused or the caption was hidden. When that timer expired, following effects and one character could advance even though normal node processing had stopped.

Two real-runtime regressions reproduce this with an authored 0.4-second pause, a 0.6-second suspension, and native signals before and after the pause. The RED run `witnessed-pause-red-20260906a` failed 14 assertions across those two tests: 15 of 17 tests passed, 920 of 934 assertions passed, exit 1. Effects and character count changed during suspension, and the delay was already spent before resume.

The correction belongs in the installed Text subsystem. It counts remaining delay only while the existing Dialogic owner is unpaused and the text node is visible in the tree. The non-skipping effect executor also waits before inspecting its queue, including an empty queue, so its caller cannot resume character reveal while suspended. Explicit skip retains its existing authorized execution path.

The countdown and effect executor validate node lifetime, reveal generation and effect-batch generation before waiting again. Clear or replacement therefore cancels suspended work rather than keeping it alive until a later resume. Temporary hiding leaves the reveal identity intact.

Timing uses the engine's process delta, preserving native simulation-time and time-scale behavior. Eligibility is checked on both sides of a frame; transition frames are conservatively excluded. This is frame-granular timing, not a wall-clock precision guarantee. Godot documents process delta separately from real-world elapsed time, and its scene-tree timer has no individual pause property. See the official [Node timing reference](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-get-process-delta-time) and [SceneTreeTimer reference](https://docs.godotengine.org/en/stable/classes/class_scenetreetimer.html).

This does not install application-focus or Universal Pause admission. Those owners must still pause playback or hide the source at the accepted stable frontier. It also does not suspend arbitrary custom callback internals; their own asynchronous side effects require cooperative cancellation. The existing [replacement-generation correction](witnessed-text-effect-cancellation.md) remains in place.

## Verification

The final run `witnessed-pause-final-20260906a` passed **160 tests / 2,407 assertions across eleven suites**, exit 0. The strengthened timing fixtures use a 600 ms pause, spend 221 ms before suspension, and hold the source for 800 ms. With 379 ms remaining, the next native effect occurred 392 ms after runtime resume and 385 ms after showing the caption. Both satisfy the measured remainder bounds; restarting the full 600 ms delay would fail. Effects and character count stayed unchanged throughout suspension, and both captions finished naturally exactly once.

Existing replacement/clear cancellation, legitimate skip effects, append, presentation, Hospital, bridge, skip, restore and effect-boundary tests also passed. Independent source review found no blocker. No script error occurred; the installed addon's known eager-constructor overhead remains 432 orphan subsystem objects (24 per handler), alongside the existing environment certificate-store and Unicode-NUL diagnostics. Player saves were not used.

The RED and final GREEN logs and exact invocation receipts are in [`evidence/witnessed_pause`](../../../evidence/witnessed_pause). Presentation geometry is unchanged, so prior stack images remain the visual evidence; this checkpoint adds timing behavior rather than a new visual treatment. The local addon correction must be reviewed alongside these regressions during future Dialogic updates.

Durable task: `dwm-eei.13`.
