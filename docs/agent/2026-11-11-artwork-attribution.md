# First artwork refresh: measure before trimming

Source: master 56bedbdc0aa5a7d36e82ebf7ad06c8fd99fb18dd (PR #267).
Outcome: identify removable first-scene work without changing artwork or moving a
pause into the next layout. SceneArtView owns portrait clipping; ArtManifest owns
texture lookup and retention. No production change is justified by this pass.

## Observation

Three serial diagnostic fresh-process runs on Linux, Godot 4.6.3, headless,
production staged startup, fresh profile, click New Game after runtime readiness.
Temporary synchronous timing wrappers were restored byte-for-byte after each run.
All processes exited 0 without script/runtime errors and reached the same visible,
acknowledged, fully revealed opening caption with input unblocked. The first two
logs were warning-free. The combined diagnostic emitted an ObjectDB leak warning
at shutdown; it is timing evidence, not clean acceptance evidence. No production
fix or leak-origin claim is inferred from that diagnostic.

| Work | First attribution | Combined confirmation |
| --- | ---: | ---: |
| Obtain portrait pixels | 0.022 ms | 0.014 ms |
| Detect transparency | 1.622 ms | 1.725 ms |
| Split-change notification | 0.336 ms | 0.264 ms |
| Two required texture loads | 66.901 ms | 67.157 ms |
| Artwork refresh, inclusive | 70.452 ms | 70.454 ms |
| Caption dating-layout refresh | 10.247 ms | 10.224 ms |

The first three initial values come from probe.log; other initial values come
from deep.log. Combined values are from one run, combined.log. Nested spans are
not additive. The combined click-to-usable-caption interval was 818.814 ms;
this is an instrumented diagnostic, not a before/after speed comparison.

## Decision

Do not add conditional alpha state or delete the scan for a measured ~1.7 ms.
Its result determines whether two opaque portraits need separate clipped slots.
Any future lazy scan must handle the same texture surviving solo-to-pair,
non-split-to-split and CG-to-pair changes. Existing pair/resize tests alone would
not cover all those retained-texture transitions.

The main artwork cost is required texture loading. The five images already use
VRAM Uncompressed imports from the earlier artwork optimization; do not repeat
that change. Loading and retaining the first scene textures during title idle is
a possible next experiment, using the existing StartupLoader and authored asset
mapping. Compare earliest click and idle-title cases, plus immediate Computer
opening, before accepting it. Moving work earlier is not deleting its cost.

Linux headless results do not rule out a different GPU readback cost in exported
Windows. No new Windows build, unit suite, fault injection or broad matrix ran:
production code is unchanged. Previous Windows acceptance remains that of PR #267.

## Reproduction

Evidence: tools/player_latency/evidence/2026-11-11-artwork-attribution.
In an imported checkout of the source revision, copy observe.gd.txt from the
2026-11-11-story-font-reuse evidence to .godot/ci/first-caption/observe.gd.
Create .godot/ci/art-alpha, use a fresh combined-user directory, then run measure.py
from the repository root with godot on PATH. The script applies temporary wrappers
and restores every touched source file in finally. Do not run it alongside other
Godot tests or editing agents.
