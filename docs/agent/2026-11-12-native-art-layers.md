# Remove duplicate native art holders

Base: `a07e358866ca5e2774c2dcb232c90a143833e465` (PR #293).

## Outcome and scope

Mount only the custom art, caption and Choices layers for witnessed playback.
WitnessedArtLayer / SceneArtView remain the sole current art UI owner. Remove
unused native Background layer 10 and VN Portraits layer 11 from the style.
Keep addon subsystems, example files, current Scene save schema and IDs 12/13/15.

Before editing, fetched master and reviewed current Scene contract, style,
application/native callers, authored DTL, frozen presentation and art tests.
Independent read-only audit found no current native background/character commands
or callers populating these holders. Hospital/dating and previews use the custom
owner. Current save restoration installs semantic Scene art, not native portrait
snapshots. Retired-feature record states the limit for future native authoring.

## Complete Load timing

Linux Godot 4.6.3 headless, sequential fresh processes, identical authored seed
restored to the same absolute user path. No profiling flags. A/B/B/A order.

| Run | First action to usable (ms) | Repeat commit to usable (ms) |
| --- | ---: | --- |
| Baseline A | 234.389 | 140.998 / 118.641 / 118.230 |
| Candidate A | 226.902 | 126.473 / 126.301 / 127.148 |
| Candidate B | 196.340 | 129.776 / 125.329 / 126.752 |
| Baseline B | 225.060 | 124.459 / 122.759 / 125.460 |

Timings overlap and repeat results do not establish improvement. No speedup claim.
Keep this as a concrete UI reduction: no unused background holder, five native
portrait containers, their transform setup or resize subscriptions. No new runtime
code, caches, helpers or managers. Fresh process does not imply cold OS caches.

## Focused checks

Candidate passed 450 assertions: two checkpoint Load processes (286), retained art
ownership/layer ordering (8), deferred first caption mount (27), and headless
inline-art/checkpoint/Load semantic journey (129). Passing commands exited 0,
XML reported pass and logs contained no ERROR lines. `git diff --check` passed.

The existing inline-art journey requires a non-headless renderer and stopped at
its renderer assertion (0/1) before exercising behavior. No display/Xvfb was
available. The attached separate semantic probe inherits that test and overrides
only _begin_inline to omit the renderer requirement; all service setup and
semantic assertions remain. It proves art composition changes, mounted custom
art, checkpoint persistence, restored composition, and no replayed one-shots or
checkpoint writes. It is NOT rendered acceptance and does not replace that lane.
Original test unchanged. No screenshots or Windows export/rendering claim.

Copy evidence runners/probe to `.godot/ci/art-layer-trim`. `load.py <label>` expects
the authored seed produced by tools/player_latency/run_checkpoint_load.py.
`focused.py <label> <unit-or-integration/path-without-extension> <test-filter>`
runs one selected case. `semantic.py <label> unused
test_inline_art_checkpoint_and_load_keep_current_composition_without_replay`
runs the separate headless diagnostic. Use fresh labels for isolated user data.

Skipped broad CI matrix, unrelated suites, rendered acceptance, injection tests
and new lint rules. The other style layers have known owners/callers; stop layer
trimming here unless new evidence identifies another unused responsibility.
