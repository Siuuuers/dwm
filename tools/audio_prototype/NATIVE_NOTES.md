# Native prototype boundary

`DwmNsfStream.create(bytes, duration_seconds=0, intro_seconds=0, loop_seconds=0)`
creates an immutable stream from trusted, single-song, NTSC, VRC6 NSF build output.
A zero duration delegates looping to the NSF program. A positive duration gives
an exact sample endpoint (rounded to 44,100 Hz) including the intended release.
The fixture exporter owns unsupported instrument/sample validation.

Each instantiated playback opens its own libgme emulator and owns a fixed 2,048
sample work buffer. Silence skipping and automatic playback limits are disabled.
`_mix_resampled` synthesizes chunks without adapter allocation, file access, or
seek work. Godot resamples 44,100 Hz output to its configured output rate.

Elapsed position is monotonic across loops. Loop count uses the supplied authored
intro and loop durations; without loop metadata it reports zero. Position includes
Godot's resampler prefetch, as for other resampled streams, rather than claiming
physical speaker presentation time.

Use `AudioStreamPlayer.play(position)` and `AudioStreamPlayer.seek(position)`.
The inspected Godot 4.5 player implementation creates a new playback for these
operations, invokes its start before registering it with AudioServer, and retains
the old one until the server releases it. Allocations, start, and libgme seeking
therefore happen on the calling thread outside this adapter's mixing callback.
The prototype accepts only main-thread player control; do not directly call
`start`, `seek`, or `mix_audio` on a playback already owned by a live player.
Standalone offline playback may use these methods for checks.

Before extension shutdown, stop players and wait for AudioServer to release their
playback objects. A game frame alone does not establish mixer completion. The
port harness observes weak references with a bounded wait and fails if native
instances remain; production shutdown integration must preserve this lifetime.

Seeking renders and discards emulator output synchronously in fixed chunks. A
focused check showed libgme's fast sample seek produced a different waveform after
120 seconds; replay/discard restores the exact sequential waveform after the four
frames of fresh Godot interpolation history. This replay is outside the mixer.
Its cost grows with elapsed position and must be measured before integration.
The prototype accepts positions and authored durations up to 24 hours and does
not implement cached synthesizer state. A long-running production session may
need retained temporary state to avoid a main-thread pause.

On the local Linux Godot 4.6.3 run, all 18 focused native checks passed. Rendering
120 seconds through Godot's offline mixing API took 46,470 us; preparing playback
at 120 seconds by exact replay took 20,638 us. These are one diagnostic run, not a
performance guarantee or a Windows result. The actual production playback-port
harness separately passed 34 checks with the exact-replay amendment.

No production catalogue, music policy, or fallback behavior is changed. Runtime
backend errors end playback; the prototype does not yet forward native failures
through AudioPlaybackPort.runtime_failure. Production integration must decide
that existing error channel before replacing recorded assets.
