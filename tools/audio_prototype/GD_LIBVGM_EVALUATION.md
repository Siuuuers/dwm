# gd_libvgm comparison

## Decision

Do not adopt yet. Unmodified gd_libvgm v0.3 plays the fixtures through the
existing playback port, but a fresh editor import aborts on exit. Retrying with
the generated cache succeeds; that is not a clean-checkout pass. The main game
and the current libgme prototype have not been switched to this candidate.

## Evaluated sources and environment

- gd_libvgm v0.3: `b9e7d7e21d914f5547a2e51d97ec3abd6edd0495`
- godot-cpp submodule: `1e7926375b62b445fa79db6851f7105b644831f2`
- libvgm submodule: `784f55b50904ebae25d541afde7657f56432a68b`
- zlib submodule: `51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf`
- Godot 4.6.3, Linux x86_64, headless Dummy audio, 44,100 Hz.

Built upstream without retained source changes:

```sh
CI=1 python -m SCons platform=linux target=template_debug arch=x86_64 -j2
```

The resulting extension was about 1.8 MB; SHA-256:
`4d512ca9df72a79e06f662507d6c574fa2bef3748eeeffec5924de0bf2757204`.
It includes broad emulator support and needs no separate libgme shared library.
That packaging difference alone does not establish lower total complexity or cost.

## Fixture adaptation

Only stream construction changed in the comparison tests: create `VGMStream`,
assign fixture bytes, set `loop_count = 0` and `fade_time = 0.0`. The production
AudioPlaybackPort and all assertions were unchanged. Music uses the committed
raw NSF payloads. The finite effect uses FamiStudio's direct NSFe export:

```sh
FamiStudio fixtures/confirm.txt nsf-export confirm-nsfe.nsf -nsf-export-mode:ntsc -nsf-nsfe
```

The compiler requires a `.nsf` output name even for NSFe; rename it afterward.
The NSFe `time` chunk carries 399 ms, versus 399.336 ms in the authored manifest.
The effect is already silent at its end. No custom NSFe wrapper is necessary.

## Observed results

| Check | Result |
| --- | --- |
| Production playback-port checks | 34 passed; clean process exit |
| Strict native checks | 16 of 18 passed |
| Initial and mid-loop authored silence | Preserved |
| Independent players, fades, pause/resume, finite release | Passed |
| 120-second restored waveform after four interpolation frames | Exact match |
| Fresh editor import | SIGABRT on exit, reproducible |
| Warm editor import | Exit 0; does not resolve fresh-import failure |
| Windows candidate build/export | Not tested |

The two native assertion failures remain visible. Raw NSF exposes loop count 0
rather than the expected three completed loops; actual looping works. The finite
playback position ends at 0.40054421768707 s, rather than the sample-rounded
endpoint, although playback becomes inactive and the effect releases correctly.
Production loop intent would need to remain owned by authored cue metadata.

A diagnostic run measured 120-second rendering at 1,183,022 microseconds and
seeking at 1,063,428 microseconds. Earlier custom-libgme measurements on the same
host were 46,470 and 20,638 microseconds respectively. These are separate single
runs, not a controlled performance benchmark. They establish no universal speed
ratio, but give no basis to promise faster restoration. Candidate NSF seeking
replays elapsed audio and uses millisecond positions; long rollback remains work.

## Import blocker and next gate

Fresh full-project and add-on-only imports aborted. A no-add-on baseline exited
normally. Disabling reloadability, removing icons, using fresh XDG caches and
omitting generated editor docs did not resolve it. A running editor remained
alive until asked to quit, narrowing this observation to editor shutdown.
No engine or extension fork was retained, and the exact root cause is unknown.

### Upstream research follow-up, 2026-11-04

Godot [issue #111048](https://github.com/godotengine/godot/issues/111048)
documents a confirmed cold-import shutdown race involving deferred extension
documentation callbacks. Its cold/warm behavior resembles this trial; this is
evidence for an engine-level explanation, not a symbolized diagnosis of our abort.
The proposed [fix #123658](https://github.com/godotengine/godot/pull/123658)
was still open when checked. Do not assume upgrading has resolved it.

The issue describes `--frame-delay 800` as a timing workaround. With the same
unmodified binary and Godot 4.6.3, separate fresh add-on-only temporary projects
gave these results:

| Import flags | Exit | Elapsed seconds |
| --- | --- | --- |
| `--headless --import --frame-delay 0` | SIGABRT | 3.14 |
| `--headless --import --frame-delay 800` | 0 | 5.04 |
| `--headless --import --frame-delay 800` | 0 | 5.02 |

These were independent cold imports, not retries against an already-created
project cache. The delay is a diagnostic workaround, not an engine fix or a
guarantee under different runner load. No production or CI delay was added.
The candidate remains unadopted pending target-platform verification and the
restoration decision below; an extension rewrite is not justified by this evidence.

Before adoption, resolve or identify a supported version combination for the
fresh-import failure, then run the focused Windows export check. Decide whether
millisecond endpoint reporting is acceptable and measure the actual temporary
rollback operation. Native error forwarding and production shutdown integration
remain required cutover work for either backend. Physical-device sound quality
and latency have not been evaluated. No unrelated gameplay suites were run.
