# DTL music and one-shot SFX authoring handoff

Date: 29 October 2026, Hong Kong.
Status: design/authoring guidance; runtime implementation pending.
Reviewed master: `dcfb578139567737eb68f6ad2bf60858d51aede0`.
Read AGENTS.md, CLAUDE.md and relevant technical owners before implementation.

## Goal

Place explicit music start/change/stop and one-shot sound cues between dialogue units in the existing DTL. Authors should not split/register a new entry or create an Autosave checkpoint solely to play a sound. Reuse the existing AudioManager and one story execution path.

A DTL label identifies a position. A registered entry additionally has an entry definition, locator and compiled target in the game's story registration. A named presentation checkpoint is a separate authored binding which may change presentation and create an Autosave. These concepts must remain distinct. New audio directives are executable instructions within an already registered entry, not new navigation targets or checkpoint arrivals.

## Owner decisions from this interview

- First version: **music + one-shot SFX**. Independent looping ambience authoring is deferred; existing ambience functionality is not removed.
- Support optional fade durations. Zero is an immediate cut. Changing music with a nonzero duration crossfades.
- Suppress one-shot story SFX during Skip. Still apply music state changes. Ordinary manual reading and Auto play SFX.
- Save the **currently active BGM label/ID, or explicit silence**.
- Owner clarified **label only**, not elapsed playback time. Load restores the selected track at its authored start. Do not add a saved playhead or serialize an unfinished fade.
- Load must not replay previously crossed one-shot effects.

These choices concern the reusable system, not placement of production sounds or selection of new recordings. No new music composition, sound generation, or unrelated cosmetic changes are requested.

## Proposed author-facing spelling — not implemented syntax

The following is a small illustrative syntax proposal, not a set of commands that currently works:

```text
# audio music quiet_room fade=0.4
# audio sfx door_knock
# audio music uneasy_room fade=0.8
# audio music stop fade=0.4
```

“music <id>” starts or changes the one logical BGM track. The ID refers to an authored asset catalogue, not a navigation label. “music stop” selects silence. “sfx <id>” plays once and finishes naturally; no separate SFX stop command is required in this slice.

The implementation may refine spelling after inspecting native Dialogic event facilities, but must document and test one consistent form. If using the existing comment-marker convention, parse the reserved audio prefix explicitly during compilation; reject malformed/unknown audio directives rather than silently treating them as harmless comments. Ordinary comments remain ordinary comments. Do not present these examples as working before the compiler, execution and restoration paths support them.

Place a cue before the caption it accompanies: it executes when reading crosses that position, before publishing that caption, with no extra Advance. Initial entry cues must work. A cue between a caption and its attached self-talk must not split the existing simultaneous pair: define an authoring rule to place such cues before the whole pair and reject ambiguous placement.

## Existing code and gaps

- `scripts/narrative/DialogicRuntimeAdapter.gd` compiles labels, supported comments, caption events, jumps, returns and registered signals. Other executable events currently return `scene_executable_event_refused`. Installing Dialogic audio events alone is insufficient.
- `tools/authoring/AuthoredWeekRegistration.gd` currently assigns `BASE.MUSIC_PLAN_ID` to every entry. Trace/update that implicit per-entry selection so it cannot unexpectedly replace an explicit inline selection.
- `scripts/data/AudioManifest.gd` validates scene catalogue versions 1/2. Version 2 admits one music OR ambience bed, requires an empty cue list, and restricts asset paths. Extend only the relevant authored audio contract. Do not misuse the fixed UI cue registry for unrelated narrative sounds.
- `autoload/AudioManager.gd` already has playback, channel preferences, SFX playback and restore ownership. Its scene installation currently stops both music/ambience player pairs and installs the selected bed directly; scene crossfades require an intentional integration, not merely adding a fade field.
- Current named checkpoint `audio_plan_id` selects an existing plan; empty means silence. The [presentation authoring template](../../tests/fixtures/presentation/README.md) explains the entry/manifest bindings. Preserve explicit checkpoint meaning and Autosave rules.
- Save/Load presently owns a semantic audio selection with registered restoration offsets. Reuse/adapt that owner to retain the latest inline music selection. It must no longer assume that the current track can only be derived from entry/checkpoint default music.

Inspect GameState, SaveManager, scene restore validation and existing AudioPlaybackPort before changing saved semantics. Old interface documents describe historical bounded slices; current code and the owner decisions here take precedence.

## Minimal behavior and recommended defaults

1. One logical BGM selection persists across ordinary caption and entry progression until explicitly changed or stopped. Existing story default supplies initial music, not an automatic reset on every entry.
2. Existing explicit named-checkpoint audio selection remains an intentional override at that checkpoint. If a checkpoint and an inline cue occur at the same arrival, define deterministic ordering: checkpoint base first, inline cue afterward. The saved state must match the actual admitted frontier; do not fabricate an Autosave for each cue or save a contradictory audio selection.
3. Re-selecting an already active BGM ID is a no-op by default, preventing accidental restarts. An explicit stop followed by play can restart it. This is an implementation default, not a request for a new restart flag.
4. Fades affect playback, not story timing: do not stall reading while a fade finishes. Keep logical selection current as soon as its command is accepted. Saving during A-to-B crossfade records B; saving during fade-out records silence.
5. A later command supersedes an unfinished fade, retiring old tweens/callbacks so they cannot stop the newest track. Bound playback players; a crossfade needs only outgoing/incoming music players, not an accumulating track list.
6. Apply authored gain/fades underneath existing user volume/mute settings. No cue may override the user's preferences.
7. One-shot cues execute once per actual forward encounter, not once forever. Revisiting through genuine story flow can play them again. Repaint, language switch, History, library browsing and Load must not replay them.
8. Suppressed Skip SFX are consumed, never queued for a later burst. Preserve the current Skip/Next distinction; inspect fast Next traversal and suppress bypassed intermediate SFX as a recommended default, without changing its existing stop rules.
9. Computer open/close and language changes do not restart BGM or retrigger SFX. Preserve existing suspension/audio focus behavior.
10. Loading stops transient outgoing SFX/fades from the abandoned state, then restores the saved logical track from its authored start, or silence. Do not replay the DTL from the entry start just to reconstruct audio.
11. Keep semantic audio state at the existing authoritative runtime/save boundary. No separate audio history database, parallel journal, timestamp schema, or profile-global BGM state.
12. Compile/validate static assets and references at authoring/export boundaries. Missing required IDs are authoring errors; follow documented optional-media behavior for unavailable files. No repeated full-catalogue validation or source scans per caption.

No independent ambience layer, spatial sound, voice dialogue system, randomized playlists, procedural music, or per-cue UI editor is part of this slice.

## Authoring workflow to deliver

- Register a music/SFX asset once with a stable ID and the metadata required by the existing media contract. Provide a copyable example and distinguish music looping from one-shot playback.
- Add/move/delete the inline cue in DTL; no hand-maintained per-cue source manifest list unless the existing compiler genuinely requires it. Prefer generating cue identities/programme data through the exporter.
- Preserve line IDs and self-talk pairing. Audio directives are not captions, translated prose, History entries or library unlocks.
- Run the cloud registration export and its fresh-process validation. Regenerate affected story/library outputs with the existing tools; do not manually edit generated programmes.
- Build/start a fresh process. Document the usual unshipped-content limitation when deleting IDs referenced by old draft saves, without adding speculative migration infrastructure.
- Include a small test-only timeline demonstrating play, change, stop, SFX, Skip and Save/Load. Do not rewrite production prose or scatter new effects through the current story without authoring selection.

## Cloud acceptance

Run Godot and PowerShell only in GitHub Actions. Verify actual playback owner effects alongside saved data; a parsed cue or emitted signal alone is insufficient.

- Native DTL compiles the chosen cue syntax and rejects malformed IDs/options/durations, while ordinary comments and existing markers remain valid.
- Cue placement before captions, at entry start, before/after branches and at completion follows authored order. Caption/self-talk pairs remain atomic.
- Music starts/changes/stops on the expected encounter without additional Advance or Autosave. Same-ID/default entry behavior does not unexpectedly restart it.
- Zero-duration cuts, fades, crossfades and superseding commands leave only intended active players. Test user volume/mute and existing computer/focus behavior.
- One-shot effects play once under manual/Auto, are suppressed during Skip without delayed bursts, and can play again on a genuine later encounter.
- Fresh-process Save/Load restores BGM ID or silence from the saved frontier, independent of entry default. Include save during crossfade and stop fade; no playhead persistence or old one-shot replay.
- No audio retriggers or read/unlock changes on language switch, History, library, redraw or Settings return.
- Correct branch-specific audio state survives return and Load. Keep current Save/Load restoration and control-boundary validation coherent.
- Preserve bilingual reading, pixel transition input holds and checkpoint Autosave semantics. Define cue timing around the existing transition preparation/commit boundary so hidden destination preparation cannot emit early sounds.
- Exported Windows build includes referenced audio files and launches correctly. Use small deterministic test assets; audible artistic quality is a separate review from timing/custody tests.

Carry forward CI guidance: measure repository-download/setup/test/wait overhead, keep sparse coverage selection, group short related suites only with isolated test data, and remove unnecessary dependencies. This feature changes compilation and saved semantics, so it is not visual-only: retain relevant compiler, audio, Save/Load, input and transition coverage. Record tested SHA, accepted cloud run and limitations.

## Delivery

Implement in reviewable stages: compiler/catalogue; runtime cue traversal and music persistence; fades/SFX; authoring examples and cloud tests. Reuse existing owners and remove only directly superseded/orphaned work. Update this handoff and the feature plan with actual PR/evidence after acceptance. This document does not claim runtime completion.
