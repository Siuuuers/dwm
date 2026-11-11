# Faster first artwork loading without pixel changes

Date: 11 November 2026 (Hong Kong).
Baseline: `9d1af70f2676bab1406426949d64e2b1527f7e53` (PR #261).
Candidate source: `0a0bdb6d01e6f16cfcb1c2eb98e3bea4731bbcb5`.
Candidate tree: `04be616c36e0b18ff02d22e4961eb383dec3210c`.

## Outcome and smallest change

First scene artwork should load sooner while displaying identical pixels. Change
`compress/mode` from 0 (Lossless) to 3 (VRAM Uncompressed) in exactly five
`art/pictures/pictureN.png.import` files. Keep source PNG bytes, paths, UIDs,
dimensions, mipmaps and all other import options unchanged. Runtime code, artwork
placement, save formats and the existing ArtManifest texture cache do not change.

The previous diagnostic attributed about 99% of first artwork refresh to the two
resource loads. This change stores imported pixel data without the lossless image
decoding step at load time. It trades installed file size for less first-use work.
It does not add preloading or move the same decode pause into startup.

Callers remain ArtManifest, SceneArtView and ArtworkGallery. Save/Profile records
use unchanged artwork IDs; no migration is needed. The main failures to check are
changed decoded pixels, broken authored placements, incorrect restored state or a
size increase disproportionate to the complete-Load gain.

## Matched Linux comparison

Four serial fresh loader processes in **B/C/C/B** order, same Godot 4.6.3 standard,
same machine, unchanged probe, English/instant reveal/Auto off. Restore the entire
identical seed to the same absolute user-data path before every loader. The seed
contains an earlier saved caption and later global discoveries.

Import each mode and run a separate five-image pixel scan before its loader. OS
cache is not cleared; this is first use in a fresh process, not cold storage. The
pixel-scan resource times are separate observations and not added to Load totals.
Each loader also performs three correlated repeated Loads. No production timing
wrappers are applied.

| Endpoint | Lossless | Uncompressed |
| --- | ---: | ---: |
| First Load to caption input ready, samples | 381.774 / 440.307 ms | 328.926 / 333.896 ms |
| First Load median | 411.041 ms | 331.411 ms |
| First Load to session-ready median | 375.618 ms | 294.844 ms |
| Repeated Load to caption input ready median | 188.891 ms | 187.651 ms |
| Separate first two texture-load sum, median | 150.241 ms | 38.576 ms |

The matched first-Load median is **79.630 ms lower (~19.4%)**; repeated Load is
essentially unchanged. Two first-use samples per mode support this bounded change,
not a tail percentile or universal percentage. Headless input readiness is not
physical screen latency. Preparation and expected-content setup precede timing;
confirmation and ready/input endpoints retain the definitions from PR #260.

## Exact visual data and size tradeoff

Across all four runs, all five textures have identical canonical RGBA8 pixel
SHA256 hashes. Their native formats also remain RGBA8, with 1920 by 1080 dimensions
and no mipmaps. This is exact decoded-data equality, not a subjective claim of
similar appearance. All original PNG hashes are retained in the evidence.

The five imported resources increase from **13,075,200 to 41,472,260 bytes**:
**+28,397,060 bytes (28.4 MB / 27.1 MiB)**. This is on-disk resource size, not an
additional 28.4 MB of decoded texture memory: both modes expose the same pixel
format and dimensions. Downloadable ZIP and exported PCK sizes are recorded
separately below.

## Focused verification

- Four Load runs: one selected test each, **143 assertions each**, exit 0; exact
  checkpoint, gameplay/Scene, saved-file integrity and current global discoveries
  retained. Loader logs contain no errors or warnings.
- Selected seven-day artwork/placement test: **96 assertions**, exit 0. It loads
  all five assets and checks real authored scene placements and split panels.
- Pixel equality: 20 texture observations across B/C/C/B, all equal to baseline.
- Independent caller, evidence and numerical review; comment/live-transition
  lints and whitespace check pass.

The initial editor import stopped on GUT's unavailable network version check.
Exclude only its editor plugin during subsequent imports, then restore committed
project settings before every measurement. No runtime/plugin source changed and
no failed-import sample entered the comparison. Accepted editor imports retain
the known nested-project/ObjectDB editor warnings; player measurement logs are clean.

[Evidence](../../tools/player_latency/evidence/2026-11-11-art-import/) includes raw
compressed logs, JUnit, hashes, measurements and the runner/probe. To reproduce,
start from a fresh imported checkout with Godot 4.6.3 available as `godot` in PATH;
first create the seed with `tools/player_latency/run_checkpoint_load.py`, then copy
`compare.py.txt` and `pixels.gd.txt` into `.godot/ci/art-import/` without `.txt`.
Run `python .godot/ci/art-import/compare.py`. Use an empty comparison output
directory; the runner refuses an existing result. The seed runner also refuses
existing owned result/user roots; preserve prior evidence before a deliberate rerun.
It restores original settings in `finally`. After measurement, its mode substitution
was made usable from either committed mode (four combinations self-checked).
Comparison variants are defined by
the five import-mode values, not different runtime scripts.

## Exported Windows acceptance and decision

[Run 42953369363](https://github.com/Siuuuers/dwm/actions/runs/42953369363)
passed on the candidate source above: release export, 137-file pack audit,
isolated startup, ordinary opening/Save and fresh-process Load. All three player
processes exited cleanly with code 0. Restored checkpoint matched and the global
profile was preserved. Retained compressed receipts/logs preserve downloaded bytes;
the complete build and screenshots are in the run artifact.

The restored-opening screenshot was reviewed: both artworks, the complete two-line
caption and seven bottom controls are visible without observed clipping. Actual
capture is 1024 by 576 despite the requested 1280 by 720 window. The cloud renderer
is D3D12 Forward+ on Microsoft Basic Render Driver (software), with Dummy audio.
This establishes exported functionality, not hardware performance or audio quality.
External UIA timings are unmatched and include polling/waits; no Windows speedup
percentage is inferred from them.

| Windows deliverable | Previous lossless export | Candidate |
| --- | ---: | ---: |
| PCK | 85,996,116 bytes | 114,393,476 bytes |
| Playable ZIP | 117,652,670 bytes | 130,041,694 bytes |

The PCK grows 28,397,360 bytes; the playable ZIP grows **12,389,024 bytes
(12.4 MB, 10.5%)**. The executable is byte-identical. The Actions evidence artifact
is a separate larger ZIP, not the downloadable game ZIP listed above.

Retain the five import changes: exact artwork pixels and a measured first-Load
improvement justify this bounded size tradeoff for the project's latency priority.
No runtime cache, preload, helper or dependency was added. Skip unrelated Settings,
translation and broad regression matrices. Native GPU timing, cold disk startup,
fullscreen and audible playback were not measured. Opening-to-title remains a
separate investigation; this change does not establish its cause or remove it.
