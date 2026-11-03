# Text music creation guide

Status: planned authoring workflow. Date: 2026-11-04.

Use this guide to write editable music and sound-effect scores for live
NES + VRC6 synthesis. The playback and build work is specified in the
[implementation handoff](2026-11-04-vrc6-audio-implementation-handoff.md).

The game already supports DTL music and one-shot sound cues. Its current
authoring path uses registered audio assets. This document does not add a
working score compiler, a synthesizer, or a new DTL command. Follow
[DTL audio authoring](dtl-audio-authoring.md) for the implemented cue rules.

## Scope

- Edit music and SFX as text.
- Use authored tracks. The game selects, loops, stops, and crossfades them.
- Allow independent virtual chips so an effect can overlap the music.
- Use chip oscillators and noise. Music/SFX payloads must not contain PCM/DPCM
  sample assets, sampled instrument banks, recorded audio, or pre-rendered
  playback audio. Internal numerical lookup/filter tables, transient output
  buffers, and review-only listening captures are allowed.
- Keep music data outside DTL. DTL refers to stable cue IDs.

A visual editor, runtime MIDI support, an import screen, and automatic
composition are not requirements. Do not create a custom music language or an
extra framework for this guide. The handoff recommends FamiStudio text, compiled
to NSF, as the first path to prove. The exact release, command, and playback
adapter remain subject to that prototype; no toolchain is installed by this PR.

## What each part means

| Part | Meaning | Example decision |
| --- | --- | --- |
| Score | Instructions for notes, rests, timing, and expression. | Play a short melody twice, then enter the loop. |
| Instrument | Rules that shape a voice over time. | Use a soft pulse attack and a short release. |
| Voice | One independently controlled sound channel; a melodic chip voice plays one pitch at a time. | Give the melody and bass separate voices. |
| Pattern | A reusable passage of score data. | Repeat a four-bar accompaniment. |
| Cue | The stable ID that story or game code selects. | Select a room theme or play a confirmation sound. |

An instrument includes more than a waveform. Its envelope can change volume,
pitch, or pulse width during a note. These changes control articulation and
texture. See the [FamiStudio instrument documentation](https://famistudio.org/doc/instruments/)
for examples of these concepts. Not every voice supports every control. Use
the selected compiler's rules for each chip channel. Chords need several
melodic voices, or an arpeggio that plays their notes in sequence.

The synthesizer produces audio samples from the score while the game runs.
The planned build may compile text into compact playback data first. Editable
text does not mean that every shipped byte must remain text. Generated audio
buffers are still required to send sound to the speakers.

## Start with a short musical brief

Specify the intended result before writing notes:

1. Give the cue a stable ID and choose music or one-shot SFX.
2. Name the scene, action, or emotion it supports.
3. Set a rough tempo, register, density, and texture.
4. Describe the introduction, repeated section, and ending.
5. State which changes are welcome and which details must remain.
6. List any references and how they may be used.

Example brief for an original track:

> Create a quiet room theme for reading dialogue. Use a slow pulse melody,
> a low, sparse bass, and little percussion. Start gently, then repeat a
> sixteen-bar section. Keep the mood intimate with a slight unease. Leave
> space for interface sounds. Use original musical material. Deliver editable
> text and a listening preview after the synthesis pipeline is available.

Useful revision requests include "reduce the high notes in the loop", "leave
more rests under the melody", and "make the final two bars return naturally
to the first bar". These requests identify a musical result without requiring
the author to prescribe chip registers.

## A small teaching example

This is a plain-language worksheet. It is not runnable score syntax, a parser
specification, or an approved composition for the game.

Assume 84 beats per minute and four quarter-note beats per bar:

| Voice | Position | Musical instruction |
| --- | --- | --- |
| Pulse melody | Bar 1, beats 1 and 2 | Play C5, then E5, one beat each. |
| Pulse melody | Bar 1, beats 3 and 4 | Hold G5 for two beats with a gentle release. |
| Bass | Bar 1, beats 1 to 4 | Hold C3 quietly for the bar. |
| Pulse melody | Bar 2, beats 1 and 2 | Rest for two beats. |
| Pulse melody | Bar 2, beats 3 and 4 | Play E5, then D5, one beat each. |
| Bass | Bar 2, beats 1 to 4 | Hold G2 quietly for the bar. |

The score must also define the instruments and what happens after bar 2.
For example, the passage could repeat or stop after the final release. A list
of pitches alone does not define a complete sound.

## Write, compile, listen, revise

Use this workflow after the implementation handoff establishes the toolchain:

1. Write the score in the selected compiler's supported text format.
2. Keep the accepted text as the source of truth. Edit that source for changes.
3. Use the exact compiler version and export settings pinned by the project.
4. Compile and inspect every warning. Correct unsupported or discarded data.
5. Listen to the result, including its introduction, loop boundary, and end.
6. Register the generated playback asset under its stable cue ID through the
   implemented authoring path. Do not invent manifest fields in advance.
7. Place or update DTL cues using the existing DTL authoring guide.
8. Review the music with the scene and normal SFX active. Use the exported
   Windows game for backend integration and release acceptance. Once that
   pipeline is validated, a note-only revision can use its pinned renderer and
   listening preview with the affected catalogue checks.

The implementation must supply the actual compiler command and file locations.
This guide deliberately supplies no unverified command or example source file.
Do not edit generated playback data or generated story registration by hand.

Rebuild after each accepted score change. A text change does not update an
already running game's cached content. Keep listening previews out of the
runtime soundtrack unless a separate task explicitly requires recorded audio.

## Make patterns and loops deliberate

- Write rests explicitly. Silence is part of the music.
- Use note releases that fit the intended articulation.
- Give sustained notes a defined end or continuation across a pattern boundary.
- Mark the introduction and loop section separately when the format supports it.
- Check the return from the loop's last bar to its first bar.
- Check all voices at that boundary, including envelope state and percussion.
- Avoid an unexpected attack, missing note, or sudden volume jump on repetition.
- Listen through several repeats while reading; reduce distracting repetition.

A short release can make a note distinct. A longer release can connect phrases,
but it can also crowd the next note. Review the rendered result instead of
assuming that equal note lengths produce equal articulation.

Keep musical time explicit in the score. Do not tie note durations to the
game's rendered frame rate. The runtime owns playback timing and crossfades.

## Create an SFX as a small score

An effect can contain one note, a pitch movement, a short chord, noise, or a
small sequence. Define its attack, body, release, and end. Use the same text
authoring pipeline as music where the selected format permits it.

For example, a confirmation brief can ask for two short rising pulse notes
with a quiet release. An error brief can ask for one lower, softer descending
note. These are design examples, not approved assets or required durations.

- Use a non-looping score with an explicit end.
- Leave headroom so overlapping effects do not clip.
- Keep frequent interface effects short and comfortable after repeated use.
- Give important game events a distinct sound without making every event loud.
- Test the effect with music, then with music muted.
- Test rapid repeated triggers and overlapping effects.

Independent virtual chips permit overlap, but the mix still needs a voice
limit and a volume policy. The implementation handoff owns those runtime rules.
Authoring an effect does not change when DTL is allowed to trigger it.

## Use references to describe a direction

Describe the qualities to retain: mood, tempo, texture, register, density,
phrase length, or overall structure. For example, "a sparse low accompaniment
with a hesitant high melody" is a useful direction for original material.
No particular external piece is approved by this guide.

Existing notation, MIDI, or recordings may help prepare a reference outside
the game. They do not create a first-version importer requirement. A recording
is not an editable score. Recovering its notes is transcription; choosing how
chip voices perform those notes is arrangement. Neither task is automatic or
required when the reference only describes an atmosphere.

Do not promise that a chiptune arrangement will reproduce the original piano,
orchestra, voice, effects, or recording. Review the musical result we intend
to keep, such as a mood, melody, rhythm, or harmonic movement.

## Check the source before copying musical material

When a reference contributes recognizable melody, authored harmonic treatment,
or arrangement, check the exact source and permission before adapting it.
A [composition and its recording](https://www.copyright.gov/register/pa-sr.html)
have separate rights. A [later original arrangement](https://www.copyright.gov/prereg/music.html)
can add rights of its own. New synthesized audio does not itself clear those rights.

Prefer verified public-domain or [CC0](https://creativecommons.org/publicdomain/zero/1.0/) material, or a license that permits the
intended adaptation and distribution. Check required credit and any commercial,
adaptation, or share-alike conditions. "Royalty-free" alone does not describe
the permission we need. A public-domain claim also needs its source and scope.
For example, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) requires
credit, a license link, and identification of changes.

Keep this check specific to the chosen material and release territories. This
guide does not grant worldwide clearance. Record the source before work starts.

## Keep a minimum source record

Store the record with the score in the location selected by the handoff:

- Cue ID, cue type, score path, and author or contributor.
- Original work, reference-only work, or an adaptation.
- Reference title, creator, exact source URL, and date checked, when applicable.
- What was borrowed, if anything, and the exact permission or public-domain basis.
- Required credit text and a retained copy of the applicable license or permission.
- Compiler version, export settings, and playback artifact identification.
- Intended introduction, loop, ending, and any useful listening notes.

These are record contents, not a new file format. Reuse the project convention
chosen during implementation. Do not maintain generated hashes by hand.

## Review before accepting a cue

- The score compiles with the pinned toolchain and has no unexplained warnings.
- The exported sound follows the intended notes, rhythm, rests, and articulation.
- The loop is intentional and does not create an accidental gap or restart.
- A one-shot effect ends and does not repeat indefinitely.
- The mix remains clear when music and effects overlap.
- Loudness, high notes, and repeated attacks remain comfortable during reading.
- DTL placement, mute, volume, crossfade, Skip, and Load follow the existing rules.
- The cue has a recorded listening review; a successful compile is not listening
  proof. Backend and release acceptance also need the exported Windows review.
- The source record and required credits are complete.

Keep source changes and required generated outputs consistent with the build
policy chosen in the handoff.
State what was heard, which build was used, and any review still outstanding.
Record physical Windows output or device-latency checks as pending when the
required audio path is unavailable; cloud rendering does not establish them.
