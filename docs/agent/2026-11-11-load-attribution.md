# Fresh-process Load attribution

Date: 11 November 2026 (Hong Kong).
Runtime: master `6a1d5ad6e7e8ab0f062248b774573d8765a645e2` (PR #259).
Measured local probe revision: `ba408e8f15fa1419adc65610fac8e638a2cbda86`.

## Outcome and decision

Separate Load's synchronous dispatch, asynchronous restoration and input readiness
before choosing surgery. No production code changed. The largest identified cold
span was artwork refresh, followed by first story-font setup. Those spans do not
prove redundant work. Keep current restore validation, complete-caption readiness,
asset quality and input behavior. Measure an exported Windows build before changing
asset import/loading or typography.

Master already contains both Settings improvements. No open PR overlapped this
work when checked. The relevant owners are BackupApp/BackupPresentationPort,
SaveManager, SceneRouter, DialogicBridge and DialogicRuntimeAdapter. Caption and
artwork surfaces own their presentation. No saved-data or public API changed.

## Measurement correction

The old native click helper waits one frame after mouse-down, one after release,
then three more. Those waits overlap activation; subtracting five frame durations
from the old total would be incorrect. Title Load commits directly, whereas
in-game Load requires confirmation.

The new manual probe constructs real viewport mouse packets before timing and
sends them together without helper waits. Timers begin before that packet batch,
not at physical button release. Preparation-action dispatch and final committing
dispatch are separate. The total action-to-usable field includes one layout frame
before confirmation; commit-to-ready and commit-to-usable do not.

The ready observer records time first, then lightweight native-caption facts.
Usability requires the exact saved line, completed reveal, presentation
acknowledgement, visible caption and unblocked native input. Full text, ledger,
checkpoint, gameplay, Scene, profile and saved-file comparisons follow timing.
The probe also checks exactly one ready signal, and that the caption was already
visible and complete at that signal. No heavyweight snapshot observer delays
that timestamp.

Service setup and expected Day1 compilation precede timing. This is a fresh process,
not cold OS cache or cold content compilation. Backup opening/slot selection are
outside these Load timers. The fixture restores an early authored caption after
later global discoveries; it does not exercise an active played board or all routes.

## Uninstrumented final samples

Godot 4.6.3 standard, Linux headless source project, English, instant reveal, Auto
off. One creator and two serial fresh loaders; the entire identical seed directory
is restored to the same absolute user-data path before each loader. Each loader
also performs three correlated in-game Loads. No other Godot process ran alongside
the measurements.

| Endpoint from committing dispatch start | First Load, two processes | Repeated Load, six samples |
| --- | --- | --- |
| Synchronous dispatch | 55.985, 57.355 ms | median 43.083 ms |
| Session-ready signal | 406.919, 487.703 ms | median 171.854 ms |
| Caption input ready | 444.045, 527.060 ms | median 193.026 ms; range 178.068–237.554 ms |

These endpoints are nested, not additive. The spread is material. Do not compare
them as a regression against the previous session's ~325 ms harness total: this
session restored a checkout/import, uses a different observer, and is not a matched
same-runner candidate comparison. There is no claimed runtime speedup.

## Separate diagnostic findings

Temporary wrappers were removed before final acceptance. The second diagnostic
recorded these inclusive first-use spans:

- Artwork refresh: **157.943 ms**. This includes presentation and texture work;
  decoding alone was not isolated. Later refreshes were roughly 0.3–2.3 ms.
- First `UiTypography.story_font`: **64.896 ms**, inside the host presentation
  refresh of 65.929 ms. It creates the cached story face/fallback configuration;
  later calls were small cached lookups. Do not add another font cache.
- Witnessed caption `_ready`: **40.895 ms**, including a presentation application
  of **27.139 ms**. These values must not be summed.
- Witnessed-style preparation: **5.818 ms**; native frontier installation:
  **3.099 ms**. They exclude later deferred caption/artwork mounting.

The first diagnostic separately recorded Backup preparation 15.691 ms and commit
47.493 ms; commit returns `scene_activation_pending`, not completion. It also
observed first host presentation at 90.477 ms, illustrating run-to-run variance.
Do not combine stages from the two diagnostic runs into a synthetic total.

The hidden ComputerHome button receives a desktop theme, but the host's warm
presentation refresh was about 1 ms in the first diagnostic. This is not the
large first-load cause. We did not delete its action or change its UI contract.
Existing style, compiled-programme, font and gallery-texture caches already exist.
Boundary validations before/after native callbacks establish different facts;
no safe blanket deletion emerged from the caller audit.

## Verification and reproduction

- Final creator: one selected test, **3,748 assertions**, exit 0.
- Final loaders: one selected test each, **143 assertions each**, exit 0.
- Both diagnostic loaders: **135 assertions each**, exit 0; preliminary observer,
  excluded from final ready-time acceptance. Exact preliminary source is retained.
- Independent probe/runner review; comment/live-transition lints and whitespace
  check pass. Only a runner limit-description sentence changed after the measured
  commit; executable logic and probe are identical.

After importing the source project with Godot 4.6.3, run:

```sh
python tools/player_latency/run_checkpoint_load.py
```

The runner uses `.godot/ci/checkpoint-load/results` and
`.godot/phase2r_tests/checkpoint-load`. It refuses existing owned roots. Preserve
old evidence before removing those two disposable roots for a deliberate rerun.
It checks the exact selected JUnit test, positive assertions, successful exit,
four samples, seed hashes and user-directory identity. Each process has a timeout.

[Evidence](../../tools/player_latency/evidence/2026-11-11-load-attribution/)
contains commands, revision/source/seed hashes, raw compressed logs, JUnit results,
temporary diagnostic patches and diagnostic probe source. The historical
`profile.py.txt` retains its original temporary paths; patches are compressed to
preserve exact whitespace. They are not production changes. Final measured runner
source is available at the local probe revision and differs from current only in
one explanatory string.

## Next useful work and omissions

Next: qualify the current exported Windows build's first Load and startup, then
attribute artwork/typography there. Compare complete readiness on the same runner
before retaining any asset-loading change; preserve the existing artwork and
readability. Preloading merely moves cost to startup unless total work improves.

No Windows export, rendered display, input-to-photon, audio-continuity, full route,
played-board or broad matrix was run for this probe-only change. Headless
visibility flags do not prove the pixels were drawn. No fault injection, new
cache, speculative manager, save-format change, authored-delay change or runtime
optimization was added. No new session is needed solely for context length.
