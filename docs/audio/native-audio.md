# Native game audio

The repository ships the Linux and Windows x86_64 libraries from gd_libvgm v0.3.
A normal Godot checkout and the Windows export use these libraries directly. The
editor and exported player use the same library for their platform, following
the upstream release descriptor.

The libraries come from the tagged release archive `gd_libvgm.zip`, SHA-256
`53b1215e8abef221908c223ed108894a8e456025fc8e943d219bb82b736fab20`.
The extension's license, third-party notices and godot-cpp license are under
`addons/gd_libvgm/`. Windows packaging copies the notices beside the game.

[Upstream release](https://github.com/PurpBatBoi/gd_libvgm/releases/tag/v0.3)

The extension registers Godot's resource loader. The existing AudioPlaybackPort
loads its AudioStream resources; no separate music manager or custom loader is
needed. Each cue is a single-track file, using the default track and native
playback settings. Do not mutate a shared resource to select another track.

Version 3 audio catalogues accept `.nsf` music under `audio/bgm/` with
`duration_ms: 0`, meaning unbounded native playback. Entrance and load-anchor
positions must be nonnegative. Sound effects use `.nsfe` under `audio/sfx/` with
authored timing and a positive duration matching the resource. Timed NSFe files
are finite and cannot serve as looping bed plans. The authoring compiler validates
these rules. Title and story select `menu_theme.nsf` and `story_theme.nsf`.

When a music change fails, the prior selection restarts at its authored entrance
and gain. Pause/resume preserves the existing playback. Save/restore transaction
compensation retains its exact restoration behavior. Normal Quit stops players,
clears streams and waits for native playback references to be released before
exiting. A playback that cannot start returns through the existing failure path.

Run the focused checks with Python 3.12:

```sh
python tools/audio_prototype/verify_game.py
```

The verifier checks native authoring and the real manager's music, pause/resume,
finite SFX and shutdown. It stages original test fixtures temporarily and runs the
actual game export on Windows. Reports are in `.godot/ci/native-audio/`. Run it in
a disposable checkout: failed checks retain staged fixtures for diagnosis.

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
