# Native audio prototype

This isolated project proves the first implementation step in [PR #187](https://github.com/Siuuuers/dwm/pull/187).
The two music loops and one effect are original test fixtures, not production
soundtrack choices. The main game keeps its existing audio system and recordings.
The `.gdignore` prevents the root game from importing this nested project.

[The gd_libvgm comparison](GD_LIBVGM_EVALUATION.md) records a working playback
trial and a reproducible clean-import blocker; that candidate is not adopted.

## Build and check

Use Python 3.12, a C++ compiler (GCC on Linux or Visual Studio 2022 C++ on Windows),
and these pinned build tools:

```sh
python -m pip install scons==4.11.1 cmake==4.4.4
python tools/audio_prototype/build.py
python tools/audio_prototype/verify.py
```

The build fetches checksum-pinned godot-cpp and libgme source into ignored
`.build/`, builds only the NSF emulator, and dynamically links it. No dependency
is added to the main game. The verifier downloads checksum-pinned Godot 4.6.3;
`--godot /path/to/godot` reuses that version when already installed.

The verifier stages the current production `AudioPlaybackPort.gd` unchanged,
imports only this project, then runs 18 native checks, 34 playback-port checks,
and a startup smoke check. On Windows it also downloads verified export templates,
exports this project, and starts the actual executable from its output directory.
Logs go to `reports/`. CI publishes logs only, not redistributable binary packages.
No physical-device audibility or latency is established by Dummy-audio checks.

For text-score edits, follow [FIXTURES.md](FIXTURES.md). The Linux CI job rebuilds
and compares all three committed NSF files and their timing/hash manifest with
the pinned FamiStudio compiler. Windows tests use those same payloads.

## What this proves

- One immutable resource creates independent emulator instances.
- Introductions, intentional silence, looping and finite effects retain their timing.
- The existing playback port handles crossfade, pause/resume and temporary restoration.
- Playback clocks follow audio frames, not rendering frames.
- Exact replay preparation restores the waveform after Godot's four interpolation-history frames.

The native callback uses a fixed work buffer. Loading and restoration preparation
happen before Godot registers a new playback with its mixer. The implementation
does not add a second music manager or change DTL cues, saves, preferences or pools.

## Limits before production integration

See [NATIVE_NOTES.md](NATIVE_NOTES.md) for the measured restoration cost and API
boundary. Restoration replays elapsed time synchronously; a long-session policy
must be resolved before replacing game audio. Native error forwarding also remains
an integration task. These are prototype limits, not accepted production shortcuts.

Next: use the Windows results to accept or reject this backend, then integrate
the existing catalogue/export owners and address long-session rollback. Keep
production composition and removal of recorded assets as a separate cutover.

Dependency licences and binary-redistribution requirements are in [licenses](licenses/README.md).
The compiler and its generated sound driver have their [MIT notice](FamiStudio-LICENSE.txt).
