# DTL editor: optional audio and artwork references

Date: 30 October 2026 (Hong Kong).
Status: planned; documentation only. Owner requested discussion and an implementation handoff, not runtime changes.
Reviewed current default-branch sources; latest observed merge is PR #172, 7b1da538febd762e520fb77c60af5bb0b3dfd953. Recheck master before implementing. PR #166 is merged, but is not the latest baseline.

## Goal and confirmed decision

The offline pocket editor should optionally import existing project catalogues for convenient audio/art ID reference. Unknown IDs, missing catalogues, stale references, and reference-import errors MUST NOT prevent DTL download. References do not register assets, alter DTL automatically, or relax the cloud compiler.

Keep the existing small workflow: import DTL, choose a quick control, select or type an ID, inspect the cue, insert, export. No catalogue-management application, asset uploader, runtime rewrite, or new authoring format is requested.

## Current implementation and source owners

- tools/dtl-editor/index.html already inserts music/change, music stop, one-shot SFX, scene/background/show/hide and checkpoint directives. IDs are currently free text; no catalogue import exists.
- tools/dtl-editor/README.md describes offline operation, exact source preservation, caption/self-talk placement and advisory checks.
- docs/agent/dtl-audio-authoring.md and dtl-story-authoring.md are current syntax authorities.
- data/manifests/authored_week_source.json: optional audio.music[] and audio.sfx[] contain authored id/path/gain_db; music supports entrance_ms. audio.initial_music chooses the initial plan. Current file contains only kind/schema_version/timeline_root: it has NO explicit audio object.
- tools/authoring/AuthoredWeekRegistration.gd, prepare_audio_catalogue: absent audio uses the template catalogue. An explicit audio object REPLACES it, rather than extending it. Do not suggest editing generated records.
- data/manifests/scene_story_registration.json: generated audio_catalogue contains the resolved assets and plans. Current music plan ID is template.shared.music.plan, pointing to asset template.shared.music at res://audio/bgm/story_theme.ogg. Plan IDs and asset IDs are different here. This is a useful optional fallback reference import, never an authored source to edit.
- data/manifests/art_placements.json: assets keys identify images and their paths; scenes keys identify compositions; optional overlay_labels keys identify show presets. Current file has assets and scenes but no overlay_labels. Empty overlay references are legitimate.
- Slot names in art show/hide are authored names, not image IDs. Checkpoints and ordinary DTL labels are story identities, not imported media catalogue entries.

## Existing audio behavior to preserve

Music persists until changed/stopped; optional fade crossfades a change or fades out a stop. SFX is one-shot, with no stop/fade option. Skip applies BGM changes but suppresses SFX. Manual reading and Auto play encountered SFX. Saves retain selected music or silence; Load starts at the authored entrance, not elapsed time, and does not replay old SFX. Adding a sound requires no new checkpoint or Autosave.

For the current default catalogue a valid music cue is:
```text
# audio music template.shared.music.plan fade=0.4
```
The quiet_room/door_knock names in the guide are illustrative, not currently registered production IDs.

## Recommended first implementation

1. Add optional "Import references" file selection supporting authored_week_source.json, art_placements.json and scene_story_registration.json. Detect recognized structure, not filename alone. Parse as JSON data, never execute it.
2. Keep separate replaceable source slots for authored audio, generated audio snapshot and artwork. Show filename, source type and counts; provide clear/remove. Re-import replaces that slot instead of silently accumulating stale IDs. Session-only is sufficient; preserve offline operation and make no network requests.
3. Present a compact command-specific list, with filtering if necessary. Show exact ID, kind, source and path when available. Selecting a result fills the relevant field; it does not insert a cue until the existing Insert action. Manual typing remains available.
4. Music suggestions use authored audio.music[].id or generated audio_catalogue.plans[].plan_id; resolve plan.music to assets[].asset_id for display paths. SFX suggestions use authored audio.sfx[].id. For generated assets, inspect AudioManifest validation to determine SFX eligibility; do not invent type information or advertise every image/audio ID for every command.
5. Scene suggestions use scenes keys, background uses assets keys, show uses overlay_labels keys. Show referenced asset paths where available. Do not invent overlays when absent. Keep slots free text (local slot suggestions can wait).
6. Explicit authored audio takes precedence over generated audio references because runtime export replaces the fallback catalogue. If authored audio is absent, use an imported generated snapshot if provided. Otherwise explain "No audio catalogue loaded; this project may use its default catalogue." Never embed a second hardcoded default catalogue in the editor.
7. Use neutral wording: "Not found in imported references; you can still export. Check registration before building." Distinguish no catalogue loaded from an imported catalogue with no match. Show mismatches/conflicts without coercing source IDs or asserting the whole project is invalid.
8. A failed import leaves existing references, DTL, selection, dirty state and undo history intact. Reference import/clear must not edit DTL, create undo entries, or mark it dirty. Keep reference notices separate from syntax and writing-length notices.
9. Preserve exact DTL export behavior, UTF-8/BOM/newlines, unknown syntax, stable IDs, undo and caption/self-talk pairing. Preserve all readability guidance.

Importing JSON does not import the actual sound/image files. Asset playback/thumbnails, catalogue editing, automatic repository synchronization and persistent browser storage are deferred proposals, not required scope.

## Validation and delivery

Read AGENTS.md and CLAUDE.md. Keep implementation changes focused on the editor, fixtures/tests and its guide. No story prose rewrite or game audio change is needed.

- Use small synthetic catalogues plus the actual current schemas: explicit music/SFX, absent audio, empty catalogues, generated plan-to-asset mapping, artwork without overlays, optional overlay presets.
- Prove arbitrary validly spelled unknown IDs remain insertable and exportable with and without references; malformed draft source remains downloadable as before.
- Test import failure, replacement, clear, precedence, mismatched IDs and unsafe-looking text displayed as text.
- Assert source bytes unchanged after reference operations; preserve existing insertion/undo/line-ending tests.
- Browser journey: import DTL and references, select music/art IDs, manually type an unknown ID, export and inspect bytes. Verify keyboard focus, mobile layout and readable long IDs.
- Run existing node tools/dtl-editor/test.cjs and browser checks as applicable. Cloud Godot export validates a fixture with registered assets; a separate unknown-ID fixture should still fail project validation, demonstrating that only editor advice is nonblocking.
- Retain cloud-only Godot/PowerShell conventions. Share setup for short related suites while isolating data; avoid broad game suites for an editor-only change unless shared owners change. Keep relevant editor placement/export and accessibility checks.
- Update README with the three import sources, optional nature, default-catalogue case and distinction between DTL download and project compilation.

Deliver a focused implementation PR with before/after editor captures and exact validation evidence. This handoff itself does not claim implementation or fresh playback testing.
