# Native game audio

The game uses unmodified gd_libvgm v0.3, pinned with its dependencies in
`tools/audio_prototype/build_gd_libvgm.py`. Build and install it before opening
native audio content or exporting the game:

```sh
python -m pip install scons==4.11.1
python tools/audio_prototype/build_gd_libvgm.py --install
```

Use Python 3.12 and GCC on Linux or Visual Studio 2022 C++ on Windows. The ignored
`addons/gd_libvgm/` directory contains the extension, platform binaries and licence
notices. Windows builds both debug and release libraries; exports select release.
The export preset includes raw NSF/NSFe assets and the dependency notices.

The extension registers Godot's resource loader. The existing AudioPlaybackPort
loads its AudioStream resources; no separate music manager or custom loader is
needed. Each cue is a single-track file, using the default track and native
playback settings. Do not mutate a shared resource to select another track.

Version 3 audio catalogues accept `.nsf` music under `audio/bgm/` with
`duration_ms: 0`, meaning unbounded native playback. Entrance and load-anchor
positions must be nonnegative. Sound effects use `.nsfe` under `audio/sfx/` with
authored timing and a positive duration matching the resource. Timed NSFe files
are finite and cannot serve as looping bed plans. The authoring compiler validates
these rules; existing recorded formats retain their existing validation.

When a music change fails, the prior selection restarts at its authored entrance
and gain. Pause/resume preserves the existing playback. Save/restore transaction
compensation retains its exact restoration behavior. Normal Quit stops players,
clears streams and waits for native playback references to be released before
exiting. A playback that cannot start returns through the existing failure path.

Run the focused checks after installation:

```sh
python tools/audio_prototype/verify_game.py
```

The verifier checks native authoring and the real manager's music, pause/resume,
finite SFX and shutdown. It stages original test fixtures temporarily and runs the
actual game export on Windows. Reports are in `.godot/ci/native-audio/`. Run it in
a disposable checkout: failed checks retain staged fixtures for diagnosis. These
fixtures are not production soundtrack choices, and the existing recorded assets
remain in use until a separate content cutover.

The Godot 4.6.3 cold-import crash remains unresolved. Verification uses the observed
`--frame-delay 800` import workaround; that is not an engine fix. Dummy-audio checks
establish lifecycle and packaging behavior, not physical-device audibility.
The original comparison and its measured timing differences remain in
`tools/audio_prototype/GD_LIBVGM_EVALUATION.md` as historical evidence.

Initial integration acceptance: [run 41718755394](https://github.com/Siuuuers/dwm/actions/runs/41718755394)
passed 94 tests and 1,078 assertions on each platform at
`1ccba0ac003417e72a274dd08a8499262a40ab14`. Windows also exported and launched
successfully, completed application startup, played native music and a finite
effect, and exited cleanly. The verifier temporarily makes its smoke scene the
export's main scene because the release template disables command-line scene
overrides. The game autoloads, resources and shutdown owner remain in that export.
