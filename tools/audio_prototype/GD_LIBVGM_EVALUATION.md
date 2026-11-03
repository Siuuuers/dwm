# gd_libvgm comparison

## Decision

Prototype comparison complete; prefer gd_libvgm for the next integration step.
It passes Windows playback and exported startup/clean exit. Its raw cold editor
import still crashes, so the documented import delay remains a workaround, not
an engine fix. The main game has not been switched to either native backend.
See the final acceptance and user decision below before applying older gates.

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

The comparison's committed `fixtures/confirm.nsfe` is that direct export from
pinned FamiStudio 4.5.3: 4235 bytes, SHA-256
`84e71d644c17f4a26c8ae389e992c214efc50bc28b35022f69b830e90a44710e`.
The runner verifies it before using it; these remain original test assets.

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
| Windows candidate build/playback | Debug/release built; 34 port checks and in-editor smoke passed |
| Windows candidate export/startup | Passed in run 41707225580 with Dummy audio |

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
guarantee under different runner load. The isolated comparison now uses the delay
in CI while retaining an unmodified cold-import control. Production is unchanged.
The candidate remains unadopted pending target-platform verification and the
restoration decision below; an extension rewrite is not justified by this evidence.

Before adoption, resolve or identify a supported version combination for the
fresh-import failure, then run the focused Windows export check. Decide whether
millisecond endpoint reporting is acceptable and measure the actual temporary
rollback operation. Native error forwarding and production shutdown integration
remain required cutover work for either backend. Physical-device sound quality
and latency have not been evaluated. No unrelated gameplay suites were run.

## Actual restoration callers

Read-only audit against master `57dec14142bfaebaee6bc41f52d5335a598f18be`:

| Operation | Current owner and behavior |
| --- | --- |
| Pause/Resume | `AudioPlaybackPort.gd` retains the same playback; no seek |
| Successful Load | `AudioManager.apply_restore_silent` uses the authored entrance via `AudioManifest`; not the elapsed session playhead |
| New cue | Starts at authored entrance; the current registered music plan uses zero |
| Settings/focus | Production output-only restoration does not reconstruct streams |
| Failed audio operation/restore transaction | `AudioPlaybackPort.restore_runtime` reconstructs active players at captured elapsed positions |

`tests/unit/test_audio_manager.gd` explicitly requires failed-operation rollback
to preserve streams, physical positions, fades and identities. Restarting music
on failure would change that contract. No such change is made by this trial.

A diagnostic measured the complete unchanged `restore_runtime()` call for one
active `loop_b` at a constructed captured position of 120 seconds: 1,351,688 us
(about 1.35 s), with immediate reported position 120.002899 s. Only the position
in a real capture was changed; this is not a real two-minute player journey or a
statistical benchmark. It shows a synchronous recovery cost, not normal Load
latency. Do not modulo the playhead by loop length without proving equivalent
emulator state. Retaining playback during transactions could avoid replay, but
would require its own ownership design and focused recovery tests.

## Automated Windows trial

`build_gd_libvgm.py` builds the pinned upstream debug/release libraries under
`.build/gd_trial`. `compare_gd_libvgm.py` stages the unchanged production port and
adapts only fixture factories in copies of the existing tests. It records a raw
cold-import control, then requires a separate fresh project to import using the
documented timing workaround. Strict native assertions remain unchanged: exactly
the two recorded differences are recognized as unresolved diagnostics; additional
failures stop the trial. Port checks, finite-output smoke, and Windows exported
startup must pass. No binary package is published and no game backend is changed.

## Windows cloud follow-up, 2026-11-04

[Run 41705709768](https://github.com/Siuuuers/dwm/actions/runs/41705709768)
built both candidate configurations and passed all 34 playback-port checks on
Windows. Strict native results remained 16/18 with exactly the known differences.
The raw cold import exited 3221225477; the independent delayed import passed.
A 120-second seek took 1,738,491 us in that single run. This is diagnostic timing,
not a matched benchmark or physical-device result.

Candidate export stopped because its generated preset omitted `exclude_filter`.
The preset now supplies empty exclusion and export-path fields. Exported startup
still requires a new successful run; the earlier smoke marker came from the editor.

The custom adapter's Linux import also aborted. On Windows, its compiler `.obj`
was additionally misidentified as a mesh. The native source directory now has
`.gdignore`, and the custom verifier uses the same explicitly named import
workaround as the candidate. Neither change proves the engine race fixed.

No production restoration contract is changed. The current audit supports keeping
pause, Load and failure rollback separate; expensive recovery alone does not
justify redesigning normal playback or silently restarting music after a failure.

## Export result and shutdown follow-up

[Run 41707225580](https://github.com/Siuuuers/dwm/actions/runs/41707225580)
passed the gd_libvgm Windows job, including release export and actual executable
startup/clean exit. All 34 port checks passed; the strict native result remains
16/18. The cold control still crashes; the delayed import is only a workaround.
The custom adapter passed Linux verification and Windows native/port checks, but
its Windows exported process exited 3221226356 after printing the smoke marker.
A success marker without exit 0 is not a passing export.

The smoke now releases its offline playback, stops/clears its player, and waits
for an observed weak playback reference to expire before quitting, matching the
existing controller harness. Upstream [issue #76745](https://github.com/godotengine/godot/issues/76745)
describes audio references surviving extension shutdown. This motivates the
change but does not establish the root cause of the Windows heap-corruption exit.
The updated smoke requires cloud verification for both backends.

## Final prototype acceptance, 2026-11-04

[Run 41711933664](https://github.com/Siuuuers/dwm/actions/runs/41711933664)
is green for custom Linux, custom Windows and gd_libvgm Windows at
`ff85e50c63e48f2117500cdfbc4bf91e48b56fa5`. Both Windows backends export and
exit cleanly. The custom adapter now builds a separate `template_release` DLL
and selects it with `windows.release.x86_64`; that resolved its observed export
failure in this run. Releasing playback alone had not resolved it. This is not
a claim that the underlying heap-corruption mechanism was independently proven.

The merged CI selector passed 38 local tests; cloud source lint and selected CI
tooling checks passed. Broad gameplay, rendering and localization were skipped.
Two native reporting differences remain explicit gd_libvgm diagnostics, not
functional playback passes. Raw cold-import failure remains unresolved. Dummy
audio does not establish physical-device audibility or latency.

The user selected **restart the previous cue at its authored entrance after a
failed music change**. This supersedes the earlier exact-position recovery
requirement for that operation. Implement it through the existing music owner
and authored entrance metadata; do not assume every cue starts at zero. Pause
continues to retain playback. Successful persistent Load already uses the
entrance. Other restore transactions are not silently redefined by this decision.

Prefer gd_libvgm for integration because the existing add-on supplies playback
and finite NSFe completion without maintaining our custom C++ adapter. Integrate
catalogue/export, native error reporting and shutdown ownership with focused
checks; update the failed-music-change tests for the approved restart behavior.
The prototype acceptance does not authorize treating the timing workaround as a
permanent engine fix. Remove the redundant custom adapter when the chosen
production integration passes. Test tunes remain disposable authoring fixtures.
