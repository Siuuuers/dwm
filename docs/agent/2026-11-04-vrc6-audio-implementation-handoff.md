# Live NES + VRC6 audio implementation handoff

Date: 4 November 2026, Hong Kong.
Status: design handoff. This documentation change adds no synthesis runtime.
Reviewed source: `a1be5930f07adf3a12801e4ae156d371d0fe5637` on `master`.

## Outcome and owner decisions

Create music and one-shot SFX as editable text. Compile the scores into compact
playback data and synthesize their sound while the game runs. The intended
soundtrack needs no recorded music or SFX files. Audio sample buffers still
exist at runtime; generated playback data is still an asset.

The owner selected these requirements:

- Text is the authoring interface. The later text-only choice supersedes the
  earlier interest in notation import and a visual editor.
- Music and SFX may use independent virtual chips. The complete mix need not
  fit one physical NES + VRC6 machine's channel limit.
- Gameplay selects, loops, stops, and crossfades authored tracks.
- Existing music may be an artistic reference. No particular work has been
  selected for transcription, adaptation, or replacement in this task.

The recommended first palette is sample-free NES + VRC6: four pulse voices,
one triangle, one noise, and one saw per virtual machine. VRC6 supplies two
of those pulse voices and the saw. Exclude DPCM sample data and other expansion
chips. Music/SFX payloads must not contain sampled instruments or recorded or
pre-rendered playback audio. Internal numerical lookup/filter tables and
transient PCM output buffers are allowed. This is an implementation default,
not a claim that the owner requested cycle-exact hardware certification. See
[FamiStudio's expansion reference](https://famistudio.org/doc/expansion/).

Keep the existing DTL cue language and one logical music selection. A new
score language, runtime MIDI import, in-game tracker, adaptive composition,
beat-synchronized transitions, and saved synthesizer state are outside this
first version. Read the [music creation guide](music-creation-guide.md) for
the author workflow and [DTL audio authoring](dtl-audio-authoring.md) for current
implemented behavior. This handoff does not change narrative content.

## Recommended pipeline and the first proof

Evaluate **FamiStudio text -> NSF -> a native Godot AudioStream adapter** first.
Use a thin adapter over **libgme** as the initial playback candidate. This
recommendation is not an installed dependency, a selected version, or a passed
compatibility test. Prove it with two short original loops and one original
one-shot before converting production content.

[FamiStudio text](https://famistudio.org/doc/export/#famistudio-text) represents
its project data and has a major/minor version compatibility constraint.
Pin an exact compiler release, checksum, and export settings. Use its supported
[command-line interface](https://famistudio.org/doc/cmdline/) in the build;
record the actual tested invocation after reading that release's help.
Keep text as the sole editable score authority. Binary project copies must
not become a second source of truth. No visual-editor installation is required
for the author's normal workflow.

Start with one cue per generated NSF file, a single selected song, and NTSC
timing. Generate the ID-to-payload mapping. Do not make authors maintain song
indices that change when a project is reordered. NSF is the first candidate
because the exporter supports VRC6 there; its VGM export does not list VRC6.
NSFe is an alternative if its metadata materially simplifies the proven path,
not a second format that the first implementation must support.

[libgme](https://github.com/libgme/game-music-emu) documents NSF/NSFe with VRC6,
a C interface, and band-limited synthesis. Its normal license is LGPL; optional
cores can change the applicable license. Build only the needed cores, inspect
the selected revision and linkage, and carry the applicable notices and source
or relinking obligations into packaging. Do not infer obligations from the
top-level license label alone.

The existing [gd_libvgm Godot extension](https://store.godotengine.org/asset/purpbatboi/gd-libvgm/)
is a comparison candidate if it reduces integration work. Its inspected v0.3
listing advertises NSF/VRC6, marks the version unstable, and says only Linux
x86_64 has been built and tested. Those claims do not establish a working
Windows dependency for this game. Recheck the selected revision before use.

The current project uses standard Godot 4.6.3 and GDScript, as documented in
[cloud testing](../cloud-testing.md). Add native synthesis through GDExtension;
do not require a project-wide .NET migration. A frame-fed GDScript oscillator
is not the proposed production backend. Keep dependency selection open until
the prototype demonstrates the behavior below, including Windows export.

## Integrate through the existing owners

Read [AGENTS.md](../../AGENTS.md), [CLAUDE.md](../../CLAUDE.md), and these current
owners before implementation. Recheck them against the implementation base.

| Owner | Existing responsibility | Required integration |
| --- | --- | --- |
| [AudioManager](../../autoload/AudioManager.gd) | Music selection, crossfades, SFX pools, preferences, scene admission | Preserve those policies. Extend `_prepare_scene_asset` and `play_scene_sfx` for synthesized resources. |
| [AudioPlaybackPort](../../scripts/audio/AudioPlaybackPort.gd) | Stream loading, player operations, pause, temporary capture/restore | Admit the native stream and prove independent playback, seeking or equivalent restoration, and lifecycle behavior. |
| [AuthoredWeekRegistration](../../tools/authoring/AuthoredWeekRegistration.gd) | Authored catalogue and generated registration | Compile/validate score assets and generate their identity, timing, and bindings. |
| [AudioManifest](../../scripts/data/AudioManifest.gd) | Catalogue validation, path rules, scene and legacy contexts | Extend the explicit asset contract for synthesized payloads. Retain stable semantic cue IDs. |
| [GameState](../../autoload/GameState.gd) | DTL cue dispatch, arrival ordering, saved music selection | Preserve existing meaning; avoid a parallel cue execution path. |
| [SevenDayTemplates](../../tests/templates/seven_day/SevenDayTemplates.gd) | Default story catalogue construction | Remove its unconditional dependency on recorded story music when making the final sample-free build. |

Current catalogue paths and validation assume imported audio, including `.ogg`
production scene paths. Export derives hashes and finite durations from files
that load as `AudioStream`. Runtime checks the hash and duration, with a 1 ms
tolerance. Music loop validation and SFX loop removal contain WAV/Ogg/MP3 type
branches. An endless generator with an unhelpful length cannot satisfy this
contract by changing a filename or bypassing validation.

There is also a hidden default dependency: `AuthoredWeekRegistration.prepare()`
calls `SevenDayTemplates.prepare()` before installing explicit authored audio.
The template requires `res://audio/bgm/story_theme.ogg` to load as a looping
`AudioStreamOggVorbis`. An explicit score catalogue alone will not remove this
requirement. Decouple default catalogue construction as part of the cutover.

## Score and generated asset contract

Use the existing catalogue/export owner. Define the smallest schema extension
needed for synthesized assets during the prototype; this document does not
declare new JSON fields to be implemented already.

- Author stable cue ID, music or SFX role, score, instruments, gain, and musical
  entrance/loop/end intent. Retain the existing authored entrance semantics.
- Generate payload path/type, source identity, payload hash, compiler identity,
  and timing metadata from the accepted source and build settings. Include
  referenced instrument data in the source identity.
- Derive timing from the selected score/compiler model. Prove how intro length,
  loop range, and finite SFX duration are obtained; NSF playback alone does not
  supply a reliable finite duration for every track. If a value must be authored,
  keep one authoritative value and validate it against the rendered behavior.
- Define the custom stream's reported length, position, looping, and completion
  semantics explicitly. Extend the validator accordingly; do not fabricate a
  duration to pass the recorded-media checks.
- Reject duplicate or reserved IDs, malformed text, missing instruments,
  unsupported expansions, DPCM data, invalid timing, and missing payloads at
  export. Diagnose the cue and source location. Do not silently drop features.
- Key immutable caches by validated content identity. A source, instrument, or
  compiler change must invalidate the derived playback artifact.

Recommended first layout: text sources and their source records under
`audio/scores/`, with compiled payloads and generated metadata under
`audio/generated/`. These are proposed directories, not existing commands.
Commit the small derived payloads with the source, as the project does with
other registrations. Cloud validation rebuilds in a temporary location and
rejects stale committed output. First prove repeatable export with the pinned
toolchain; handle volatile metadata explicitly rather than ignoring a mismatch.
Do not commit WAV previews as runtime dependencies.

The shipped game reads generated playback data. It does not need the compiler,
a network service, or a parser for a new music language. Restrict v1 to trusted
project-built scores; arbitrary player-supplied NSF programs are not a feature.

## Playback, timing, and mixing

Use an immutable custom `AudioStream` resource for the payload and metadata.
Each [AudioStreamPlayback](https://docs.godotengine.org/en/4.6/classes/class_audiostreamplayback.html)
instance owns its mutable emulator, sequence position, envelopes, noise state,
and buffers. Two players using the same resource must not share that state.
Crossfading tracks and overlapping effects therefore have separate emulators.

Drive synthesis from requested audio frames with a fixed chip timing mode.
Rendered game frames must not determine note duration. Prepare files, compiler
work, emulator allocation, and large seek work outside the audio callback.
Use preallocated buffers and a bounded command handoff. Keep resource lifetime
and thread ownership explicit; stop, replace, and free without racing the mixer.

Let the compiled music program handle its authored loop. Do not restart the
whole file on every loop or repeat its one-time introduction. Preserve long
rests, note tails, and envelope behavior at loop boundaries. Disable or account
for the backend's silence heuristics: [libgme's playback documentation](https://github.com/libgme/game-music-emu/blob/master/gme.txt)
describes initial-silence skipping and silence-based end detection. Neither
may override the score's intended silence or lifetime.

An SFX has a finite authored endpoint including its intended release. The
adapter must stop rendering and release its pool slot at that endpoint, even
if the underlying NSF program continues producing silence forever. Repeated
triggers create fresh playback state. Preserve the existing bounded music,
story SFX, UI, ambience, and voice allocation policies; independent chips do
not mean unbounded players. Test the existing overflow/steal policy explicitly.

Keep bus routing, authored gain, volume preferences, mute, mono, focus behavior,
and speech ducking under their current owners. Reserve mix headroom for two
music tracks during a crossfade plus active effects. Measure CPU, allocation,
buffer starvation, and output latency at that overlap, on the stated build and
machine. Record actual queue depth; buffer capacity alone is not latency.
Do not promise negligible cost, perfect analog identity, or a latency target
before measurement and listening.

## Preserve story, pause, and restoration behavior

The [existing DTL rules](dtl-audio-authoring.md) remain authoritative:

- Music persists until changed or stopped. Selecting the active ID again does
  not restart it. A nonzero fade crossfades without delaying reading.
- Skip applies music selection but consumes crossed story SFX silently.
  Manual and Auto encounters retain their normal SFX behavior.
- Keep destination cues after their label and before the whole caption/self-talk
  pair. Keep named-checkpoint selection before inline arrival cues.
- Save records music ID or explicit silence. During a crossfade it records the
  destination; during fade-out it records silence. Load starts at the authored
  entrance and clears abandoned effects. Do not persist phase or playhead.
- Load, language changes, repaint, History, library browsing, and Settings
  return must not replay previously crossed SFX.

Persisted Load, pause, and failed-operation rollback are different contracts:

| Operation | Required behavior |
| --- | --- |
| Persisted Load | Start the saved music selection at its authored entrance. |
| Pause/resume | Retain the current long-lived playback objects and freeze their musical clocks and fades. Stop transient story/voice effects as today; UI remains usable. |
| Temporary rollback | Restore the captured playback position and fade state through the existing playback boundary, preserving its compensation contract. |

`AudioPlaybackPort.capture_runtime()` currently captures streams, playheads,
gains/buses, and remaining fades; restore reconstructs playback with a position.
A synthetic stream cannot assume that `play(position)` restores its emulator
and pending buffers correctly. Prove a valid seek/replay or retained-state
strategy before choosing the adapter. Include that cost in the prototype.
This work does not add synthesizer internals to persistent save files.

For the initial adapter, report monotonic elapsed playback time and track loop
count separately. Prove rollback after several loop passes; a loop-relative
offset alone must not replay the introduction or reconstruct the wrong state.
Measure restoration after a long elapsed run. If replay from the beginning is
too costly, retain suitable temporary playback state through the existing port
rather than doing an unbounded seek in a callback. Document any alternate
position convention and its restoration mapping together.

## Cutover coverage

Inventory current references before replacing or removing media. Include the
default story track and template, title/menu catalogue, live UI sounds, authored
story SFX, and any active ambience paths. The legacy catalogue includes names
that may be unused; its existence does not require composing every entry or
reviving retired mechanics. Preserve TTS/accessibility output as its separate
feature. A sample-free music/SFX target is not a ban on synthesized speech.

The title catalogue resolves `menu_theme`; this review did not establish a
current title-start call. Check actual call sites before assigning replacement
work. The current authored-week source has no explicit `audio` object and uses
the default story catalogue. An explicit catalogue replaces that default, so
retain all still-referenced plan IDs or update their owners together.

For final acceptance, export and start the scoped game with superseded recorded
music/SFX excluded from the package. This must exercise the default construction
path too. Preserve source/credit evidence for retained work. This documentation
PR does not delete recordings or select production compositions.

## Implementation order and evidence

1. **Prove the pipeline.** Pin the compiler/backend, compile two original loops
   and one finite SFX from text, and load them through the native Godot adapter.
   Demonstrate a loop with an introduction, intentional silence, concurrent
   playback isolation, finite completion, pause, and temporary restoration.
   Build and load the extension in a Windows export before broad integration.
2. **Integrate existing owners.** Extend catalogue/export validation and the
   playback port. Route music and SFX through the existing manager. Keep DTL,
   Save/Load, preferences, and bounded pools intact. Add focused regressions for
   new behavior and refresh generated registrations/inventories when required.
3. **Create and migrate content.** Follow the music guide, record the source of
   each cue, inventory active references, and remove the template's recording
   dependency. Convert only the agreed current music/SFX scope.
4. **Accept the export.** Rebuild generated assets, run affected cloud suites,
   inspect the packed assets and native dependencies, and listen in the actual
   Windows build. Record exact commit, tool versions, hardware, and limitations.

Select checks by changed behavior using the current
[cloud runner](../../tools/testing/Invoke-CloudTests.ps1):

| Risk | Existing entry to reuse or extend |
| --- | --- |
| Authoring, catalogue, compilation, playback | `-Suite scene_inline_audio_unit` |
| Fresh-process Save/Load and authored entrance | `-Suite scene_inline_audio` |
| Skip, Auto, manual traversal | `-Suite scene_inline_audio_transport` |
| Arrival, checkpoint, crossfade selection | `-Suite scene_inline_audio_transition` |
| Manager, settings, audio policy | `-Suite audio` |
| Native pause and fades | [test_audio_pause_suspension.gd](../../tests/unit/test_audio_pause_suspension.gd); this is not included in the current `audio` suite, so select it explicitly when affected. |
| Seek and rollback | [test_scene_audio_playback_port.gd](../../tests/unit/test_scene_audio_playback_port.gd) and [test_audio_settings_transactions.gd](../../tests/unit/test_audio_settings_transactions.gd) |
| Title, New Account, Load entry paths | `-Suite current_title` when those paths change |

Add focused synthesis checks for unsupported sample/expansion data, stale
generated output, shared-resource isolation, long rests, loop tails, SFX
completion, pool pressure, and recovery. Compare renders under a pinned build;
do not assume cross-platform bit identity without evidence. A headless export
or PCM render does not prove physical Windows audible output or device latency.
Record device-specific acceptance as pending when that path is unavailable.
After the backend is accepted, a note-only edit can use the pinned renderer,
listening preview, and affected catalogue checks. Repeat native Windows checks
for backend, packaging, timing, or other changes that put that behavior at risk,
and include an exported-build listening review before release acceptance.
Do not broaden unrelated UI/localization checks for a score-only edit without
an affected behavior or required gate.

For this documentation PR, source review, relative-link checks, consistency,
and whitespace checks are sufficient. No synthesis, performance, listening,
or game-runtime acceptance has been performed by these documents.
