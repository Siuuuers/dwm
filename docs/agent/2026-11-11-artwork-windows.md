# Artwork loading and exported Windows observation

Date: 11 November 2026 (Hong Kong).
Runtime baseline: `9f292b71ab401d7a1b79cedd9b3b89217a97659d` (PR #260).
Windows observation source: `41912e0ddf6455ec6f4b5925f7b21f1b71ae4618`.

## Why first artwork refresh costs time

The previous 157.943 ms span included all artwork refresh work. One new Linux
headless diagnostic separated resource loading from view configuration and
portrait transparency scanning:

| First nonempty refresh span | Time |
| --- | ---: |
| Complete artwork refresh | 175.702 ms |
| `picture1` resource load | 93.657 ms |
| `picture2` resource load | 79.876 ms |
| View configuration, including opacity check | 1.746 ms |
| Portrait image readback, inside view configuration | 0.012 ms |
| Alpha scan, inside view configuration | 1.111 ms |

The two resource loads account for 173.533 ms, about 98.8% of this refresh. This
is a separate run from the earlier 157.943 ms observation. Both textures are
1920 by 1080 RGBA images; imported files are 2,499,130 and 2,488,270 bytes.
Runtime loads the imported texture resources. The measured load spans include
engine file access, decoding and resource construction; those internal costs
were not separated. Headless evidence says nothing about GPU upload time.

Later cached texture requests took 6–18 microseconds. Nonempty repeated artwork
refreshes were 2.073–2.157 ms. `ArtManifest` already retains these five gallery
textures, so another cache would duplicate an existing owner. The large first-use
cost is not recurring fixed-layout measurement or the alpha scan. No asset
quality, artwork, import settings, cache, layout or production code changed.

The diagnostic loader passed 143 assertions and exited 0 without warnings or
errors. All three instrumented runtime files were restored byte for byte. The
[evidence directory](../../tools/player_latency/evidence/2026-11-11-artwork-windows/)
contains raw logs, JUnit, source/seed hashes, diagnostic patch and runner source.
To reproduce, first use `tools/player_latency/run_checkpoint_load.py` to create
the seed, then copy `art-profile.py.txt` to `.godot/ci/art-attribution/profile.py`.
The script retains existing user data before restoring that seed; use a fresh
owned diagnostic output folder. Instrumentation is removed in `finally`.

## Windows observation scope

Reuse the existing focused release smoke, triggered by a dedicated branch push.
This avoids the unrelated PR matrix. The workflow imports/exports with the pinned
Godot 4.6.3 editor and templates, verifies the package, then runs external UI
Capability, Create and fresh-process Load against the ordinary release executable.
No diagnostic script is inserted into the shipped package.

The observation requests ProjectDefault renderer. Accessibility Always and Dummy
audio remain explicit cloud harness settings. The harness requests a 1280 by 720 window; actual captured size is recorded below.
This is not 1920 by 1080 fullscreen or physical audio qualification.

The external harness records monotonic time before process start and when the
enabled New Acc control is observed. This includes process inspection and UIA
provider work. For caption observations it records time just before UIA Invoke,
after Invoke returns, and at the first matching caption name. These include the
existing 200 ms post-invoke wait and 100 ms polling. Captures and the following
1600 ms settled screenshot wait occur afterward.

Use `restored-opening` for Load observation. Later observations follow Back and
save/profile verification; they are not Save/Load durations. UIA text appearance
does not prove full glyph rendering or input readiness. The existing native
state checks and independent screenshot review provide separate evidence.

## Windows results

[Run 42950929242](https://github.com/Siuuuers/dwm/actions/runs/42950929242)
succeeded. Tested tree: `7ccad92b88ccffe2f50551646748cec3684d38a4`.
The actual log identifies **D3D12 12_0, Forward+, Microsoft Basic Render Driver**.
This is software rendering on a cloud runner, not a representative gaming GPU.
Although the harness requests 1280 by 720, actual captured window bounds/images
are **1024 by 576**. Neither requested nor captured size qualifies fullscreen.

| External observation | Time |
| --- | ---: |
| Capability fresh-profile launch to enabled title control | 9.710 s |
| Creator fresh-profile launch to enabled title control | 8.936 s |
| Loader existing-profile launch to enabled title control | 6.860 s |
| Fresh-process Load invoke to restored caption name | 1.010 s |
| New Game invoke to caption name, capability / creator | 1.346 / 1.441 s |

These are small-sample UIA upper bounds. Startup includes native process inspection,
provider work and polling. Load includes UIA calls, the post-invoke wait and polling.
No subtraction estimates engine timing. Caption naming is not proof of text
reveal completion, drawn pixels or input readiness. The phases have different
profiles and shared OS/renderer caches; do not pool them or compare them as a
speedup over Linux source measurements.

All three modes completed successfully and shut down normally with exit 0.
The package audit verified 137 runtime data files. A fresh Load restored the
opening checkpoint and physical state; a subsequent witness Save matched the
source narrative checkpoint, gameplay, Scene, Contacts, desktop and lifecycle.
Only the new witness Save's checkpoint identifier/sequence differ. Profile bytes
were unchanged. This Windows opening fixture does not add later discoveries;
that scenario remains covered by the Linux compact-history diagnostic.

Reviewed the title, saved-opening and restored-opening screenshots. Both artworks,
the complete two-row opening caption and all seven bottom controls are visible;
the saved and restored scene presentation agrees. The saved shot has Save focus,
while the restored shot does not. Still screenshots do not establish frame pacing.
The selected original PNGs are retained in the evidence directory.

Gameplay, headless player smoke and package-audit logs have no errors or warnings.
Editor import/export reports the ignored nested audio-prototype project; export
console also reports ObjectDB instances leaked at editor exit. These editor
warnings are retained and are not described as clean player behavior failures.

## Acceptance and next decision

Only the workflow trigger/renderer request and external timing observations changed.
No production GDScript, images, import settings or game behavior changed. Independent
reviews checked timing scope, receipts, package hashes, source/restored save fields,
profile hashes, diagnostic spans and restored runtime bytes. Windows PowerShell
parse, complete release smoke, comment/live-transition lints and whitespace checks
passed. Final documentation/evidence commits do not rerun the unchanged package.

We now know the Linux artwork cost is first resource loading, and the current
Windows export can render and restore the scene successfully. A meaningful next
performance experiment must compare the same exported workload on the same runner,
with engine-level timing isolated from UIA waits. First investigate exported
startup and texture loading there; do not infer which engine substage consumes the
9-second external title observation. A quality-preserving import experiment can
then be judged by complete first-Load time and visual equivalence. Preloading alone
moves work earlier; it does not remove it.

Skipped: broad suites, other story routes, played-board restoration, audible output,
physical GPU timing, full-resolution acceptance, lossier artwork, asynchronous
loading infrastructure and speculative alpha-scan optimization. No fault injection.
