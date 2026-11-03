# Native audio tools and comparison fixtures

The game uses the pinned gd_libvgm add-on through its existing audio owner.
Build, integration verification and packaging instructions live in
[Native game audio](../../docs/audio/native-audio.md).
The original test tunes here are authoring fixtures, not production soundtrack
selections. Follow [FIXTURES.md](FIXTURES.md) to rebuild them from text scores.

## Game verification

With Python 3.12 and the platform C++ build tools installed:

```sh
python -m pip install scons==4.11.1
python tools/audio_prototype/build_gd_libvgm.py --install
python tools/audio_prototype/verify_game.py
```

The verifier uses checksum-pinned Godot 4.6.3, runs the focused game audio suites,
and checks native game startup. On Windows it also exports and launches the game.
Dummy-audio checks do not establish physical-device audibility or latency.

## Optional historical comparison

The manual `Native audio comparison` workflow retains the isolated gd_libvgm
comparison. To run it locally:

```sh
python tools/audio_prototype/build_gd_libvgm.py
python tools/audio_prototype/compare_gd_libvgm.py
```

`test_native.gd`, `test_port.gd`, `export_smoke.gd`, `project.godot`, and
`export_smoke.tscn` are source templates for that runner. It replaces the historic
custom stream factories with gd_libvgm factories and stages a temporary project.
Do not launch this directory as a standalone Godot project. `verify.py` supplies
shared download and process-checking helpers; it is not a standalone verifier.
The `.gdignore` keeps these templates out of the game's imports.

Comparison reports go to `reports/gd_libvgm/`. The comparison retains two known
strict native reporting differences and the documented import-delay workaround;
it is historical diagnostic evidence, separate from game integration acceptance.
See [GD_LIBVGM_EVALUATION.md](GD_LIBVGM_EVALUATION.md) for the recorded results.

The redundant custom C++ adapter and its build were retired after native game
integration passed. Its implementation, tests and build instructions remain at
[the archived revision](https://github.com/Siuuuers/dwm/tree/a91b013b51653c6e4830911a650d6730d184ca48/tools/audio_prototype).
[NATIVE_NOTES.md](NATIVE_NOTES.md) and [the historical licence notices](licenses/README.md)
preserve that prototype's boundary and attribution. The fixture compiler and its
generated sound driver retain their [MIT notice](FamiStudio-LICENSE.txt).
