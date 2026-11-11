# Title-idle artwork warming: rejected experiment

Source: master 4bfc17a081e722a689cb9ce36a980dd3dc30d7be (PR #268).
Goal: reduce click-to-usable opening caption without delaying early New Game or
immediate Computer opening. Existing StartupLoader owns the resource queue.

## Experiment

Append picture1.png and picture2.png to the existing optional queue, after all
BACKGROUND_RESOURCES. Keep required runtime readiness and Computer priority
unchanged. These explicit paths are an experimental control for the current
opening, not a production authoring contract. The candidate was restored after
measurement; no runtime change is retained.

Deriving these paths for production must account for authored opening commands,
not merely ArtManifest.get_scene_art("Day1"). Existing canonical APIs can resolve
the selected first target and prepare its initial presentation, but this may also
compile its dialogue programme. Do not add that synchronous work without measuring
it. The simpler experimental candidate below did not establish an idle-title gain.

## Matched observation

Godot 4.6.3, Linux headless, fresh process and fresh profile for each run. Serial
B/C/C/B for each case, no concurrent engine jobs. Early clicks occur as soon as
the title is ready; settled clicks occur two seconds after runtime readiness.
This is warm OS cache/fresh process measurement, not cold disk or input-to-photon.
The unchanged next action opens Computer and verifies the same caption remains.

| Case | Baseline samples | Warming samples | Baseline / warming medians |
| --- | --- | --- | --- |
| Early click to caption | 4125.908 / 3240.136 ms | 3284.151 / 3348.233 ms | 3683.022 / 3316.192 ms |
| Settled click to caption | 646.141 / 644.604 ms | 675.030 / 618.405 ms | 645.373 / 646.718 ms |
| Computer after early caption | 111.925 / 112.096 ms | 98.663 / 118.777 ms | 112.011 / 108.720 ms |
| Computer after settled caption | 31.847 / 31.003 ms | 34.244 / 34.948 ms | 31.425 / 34.596 ms |

Both candidate settled traces confirm the images finished loading about 1.4 seconds
before the click. The intended prewarm happened, but complete operation latency
was effectively unchanged. Early samples overlap substantially and include a slow
baseline sample; their median difference is not a reliable speedup claim.

All eight runs exited 0, reached the exact acknowledged, visible, fully revealed
opening with input unblocked, and opened Computer without changing the caption.
No script/runtime errors. Three runs emitted an ObjectDB leak warning at shutdown
(early baseline 0, early candidate 2, settled candidate 1). These remain qualified
diagnostics, not clean Windows acceptance or proof of a production leak's cause.

## Decision and next scope

Reject the warmup candidate. Do not ship extra retained resources or opening-path
derivation for an unproven player-visible gain. Existing loading, save behavior,
artwork, test suites and configuration remain unchanged. No new Windows build or
broad regression matrix is warranted for this docs/evidence-only result.

Next measure the current New Game preparation spans: snapshot input, initial
reading checkpoint, snapshot construction and restore-plan preparation. Prior
attribution suggests meaningful synchronous work there, but fresh attribution is
required before changing canonical owners or copying/validation behavior.

## Evidence and reproduction

Evidence: tools/player_latency/evidence/2026-11-11-title-art-warmup.
Copy observe.gd.txt into .godot/ci/title-art/observe.gd in an imported source
checkout. Use fresh early-user0..3 and settled-user0..3 directories, then run
compare.py from the repository root with godot on PATH. The script applies only
the temporary queue change and restores StartupLoader in finally. Do not run it
alongside editing agents or other Godot jobs. matched.json.gz retains full queue
traces; sha256.json identifies the committed evidence bytes.
