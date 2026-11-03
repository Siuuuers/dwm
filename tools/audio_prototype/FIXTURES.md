# Prototype score fixtures

These are original test phrases, not production soundtrack selections. They were
written directly in FamiStudio text for this prototype; no existing composition,
recording, demo-song notes, or sampled instrument is included. Edit the `.txt`
files; NSF payloads and `manifest.json` are generated outputs.

| Cue | Purpose | Authored timing |
| --- | --- | --- |
| `loop_a` | VRC6 pulse, one-time introduction, initial silence and a full silent pattern inside the repeating section | Intro 96 ticks; loop 192 ticks |
| `loop_b` | NES pulse plus VRC6 saw; different concurrent playback | Loop 192 ticks |
| `confirm` | Short VRC6 pulse effect and release to silence | Finite endpoint 24 ticks |

The NSF header specifies 16,639 microseconds per NTSC playback tick. The manifest
contains tick counts and derived seconds, independent of mixer sample rate. The
compiler's uniform groove and pattern lengths own timing; the build script does
not support custom pattern timing or tempo changes. Extend its timing derivation
before adding those features. A finite endpoint includes the final silent tail;
the native adapter must release the effect at that endpoint even if the NSF stays
silent indefinitely. Music looping belongs to the compiled program.

## Rebuild

Use the official [FamiStudio 4.5.3 Linux AMD64 archive](https://github.com/BleuBleu/FamiStudio/releases/download/4.5.3/FamiStudio453-LinuxAMD64.zip).
Its SHA-256 is
`9133afed2fb384663b0735d8e950cdc2714849f4fd476b16de8d56e5e81da0ad`.
The build script also checks the compiler DLL hash. The tested runtime was
.NET 8.0.16, downloaded from
<https://builds.dotnet.microsoft.com/dotnet/Runtime/8.0.16/dotnet-runtime-8.0.16-linux-x64.tar.gz>
(SHA-256 `8659010470ea4d17aa546d08f6c43aa7fa8b67a3cea49e0e7e61a87f4e31b998`).
Install these tools outside the repository. On Linux, make `FamiStudio` executable
and set `DOTNET_ROOT` if the runtime is installed in a private directory.

```sh
python3 tools/audio_prototype/compile_fixtures.py /path/to/FamiStudio
```

This compiles into a temporary directory and compares all three NSF payloads,
source hashes and generated timing against committed output. After changing a
score, run the same command with `--write`, then run without it to verify.
The actual compiler operation is:

```sh
FamiStudio loop_a.txt nsf-export loop_a.nsf -nsf-export-mode:ntsc
```

No compiler, .NET runtime, or WAV preview is needed in the shipped game. The NSF
files contain the FamiStudio sound driver; its MIT notice is preserved in
[FamiStudio-LICENSE.txt](FamiStudio-LICENSE.txt). The original fixture text is part
of this repository. libgme has separate licensing obligations handled by the
native backend packaging.

## Initial evidence

FamiStudio 4.5.3 exported each fixture to 4,224 bytes. Repeated exports were
byte-identical. Linux libgme 0.6.3 rendered all three at 48 kHz with silence
heuristics disabled: the introduction silence remained, the silent loop section
resumed with music, and the effect was silent after its endpoint. These checks
establish generated playback data and PCM behavior, not Windows device output
or production musical suitability.
