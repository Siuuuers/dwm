# Synthetic scene audio fixture — TEST only

Prepared under PR30 Director6176804775 and B reservation6176845019, from
integration `b32cab3ec7d283100195e4053a962ab470d854b1`.
This asset is not installed in a scene registration or production catalogue.
It does not define a save format, plan API, or narrative binding.

`scene_test_bed.tres` is an original, mathematically generated AudioStreamWAV:

| Property | Value |
| --- | --- |
| Encoding | Signed 16-bit little-endian PCM, mono |
| Sample rate / frames | 8,000 Hz / 32,000 frames |
| Duration | 4 seconds |
| Loop | Forward, frames 0 through 32,000 (exclusive end) |
| Waveform | Triangle; successive seconds alternate 250/500/250/500 Hz |
| Peak / mean | 512 of 32,768; zero mean |
| Intended TEST forward entrance | 0 seconds / frame 0 |
| Proposed TEST Load anchor | 1 second / frame 8,000 |

Both candidate entrance points start at zero amplitude. Their subsequent sample
patterns differ, so an eventual waveform assertion can distinguish the authored
one-second anchor from accidental restart-at-zero. The phase repeats at the
four-second loop boundary. This is a quiet test signal, not designed ambience,
story evidence, a production soundtrack or a subjective listening test.

The resource contains the PCM directly, with no import sidecar, external media,
generated resource UID, player node or script. AudioManager remains the sole
live playback owner. Do not add a fixture-local player to bypass that owner.

## Reproduction and integrity

The asset was generated using Python's standard library, without Godot or
PowerShell. The following code reproduces its exact bytes; execute from the
repository root only when intentionally regenerating this fixture.

```python
from pathlib import Path
import struct

samples = []
for i in range(32000):
    period = 32 if (i // 8000) % 2 == 0 else 16
    phase = i % period
    q = period // 4
    value = phase if phase <= q else (2*q-phase if phase <= 3*q else phase-4*q)
    samples.append(value * (512 // q))
pcm = struct.pack('<32000h', *samples)
text = ('[gd_resource type="AudioStreamWAV" format=3]\n\n[resource]\n'
        'resource_name = "TEST synthetic scene bed"\nformat = 1\n'
        'loop_mode = 1\nloop_begin = 0\nloop_end = 32000\n'
        'mix_rate = 8000\nstereo = false\ndata = PackedByteArray('
        + ', '.join(map(str, pcm)) + ')\n')
Path('tests/fixtures/audio/scene_test_bed.tres').write_bytes(text.encode('utf-8'))
```

- PCM SHA256: `1f8ec0521e5f1911919259460de7fec2dd4468c4d6e9e80ff6727d1fb6f5b2f6`
- Resource SHA256: `f85a90530be2a8f0dad87f80844e6b79d5bdf171975f4c9044a770dc4c2d32aa`

Static checks cover exact byte count, signed sample range, zero mean, distinct
entrance/anchor patterns, hashes and reproduction. These are asset checks, not
engine parse, playback, canonical Save/Load, or cloud acceptance evidence.

## Integration handoff

A first releases the accepted canonical registration/save interface requested in
[B's proposal](https://github.com/Siuuuers/dwm/blob/67defeec2f7ffe21fa9965c945c778ffe279cca0/handoff/b-scene-audio-interface.md).
This asset supplies only media; the registered plan/anchor and its immutable
content identity must come from that interface. No new global registry or
invented durable fields are introduced here.

Once the interface is released, B can use this path with the existing audio
owners. The connected cloud lane must prove registered entrance, advancing
playback across computer open/close, canonical Save, distinct-process Load at
the registered anchor, and no second restart during native scene readiness.
Physical player timing needs a documented tolerance. Confirm actual engine
resource loading, four-second duration, loop settings and sample data before
claiming playback acceptance. Missing registered ambience uses authored silence
and a factual diagnostic, not this asset as a universal fallback.

A alone schedules the shared cloud controller. No speculative stand-alone cloud
run is requested for this static preparation. No production or Beads completion
is claimed; the audio feature remains pending implementation and cloud evidence.
