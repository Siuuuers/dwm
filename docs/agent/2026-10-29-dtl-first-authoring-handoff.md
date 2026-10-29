# DTL-first story authoring

Date: 29 October 2026, Hong Kong.
Status: complete; merged in [PR #155](https://github.com/Siuuuers/dwm/pull/155).
Reviewed master: `19276f9f5f28490e1b1eba0d654c8a27f1accb39`.

The design and baseline below are retained as the implementation requirements.
Use the [DTL story authoring guide](dtl-story-authoring.md) for current syntax and
the completion record below for candidate evidence.

## Owner goal and interview

Replacing the draft story should primarily mean editing DTL, followed by cloud export/validation/build. DTL should declare the story's structure and where supported actions occur, generating registrations instead of requiring duplicate hand-maintained entry/marker/presentation lists.

Owner selected:
- Artwork changes may occur between any two dialogue units, independently of checkpoints or Autosaves.
- Retain the current seven-day structure for this slice.
- The owner delegated entry-discovery policy. Selected recommendation: **explicit entry declarations in DTL**; ordinary internal jump labels do not automatically become registered entries.

Use declarative, typed commands routed to existing application owners. The author's “call a function” idea is served by a documented set of story operations, not arbitrary node paths, GDScript expressions or unrestricted method calls. Stable IDs and explicit operation arguments let export validation and Save/Load understand the effect.

## Ownership after this change

| Authored source | Owns |
| --- | --- |
| DTL | Explicit entry declarations/day/start point, dialogue/IDs, choices and Challenge routing, checkpoint arrival, presentation commands, music/SFX placement, library passage membership/condition references |
| Reusable asset/gameplay catalogues | Image/audio IDs and files, reusable artwork layouts, audio gains/loop/start metadata, reusable Challenge/board definitions |
| Localization catalogues | Translated prose and localized display keys, including passage/condition descriptions |
| Generated outputs | Entry/target/marker registration, compiled programmes, presentation bindings and Gallery projection |

Do not infer branching conditions from friendly label names or automatically translate new prose. The intended simplification is no duplicate story-structure editing, not elimination of reusable asset and translation data. New files/assets may need their catalogue entry once; moving an existing cue should require only DTL.

Use one explicitly configured source directory or existing source-file inventory. If all timelines remain under that root, discover them deterministically so adding a DTL file does not require repeating each entry in JSON. Scan only at export, never every frame/caption. Do not guess the starting entry from file sort order: require one explicit start declaration.

## Original proposed surface

Illustrative commands, subject to parser integration review:

```text
label day1.room
# story entry day=1 start
# art background room_day
# art show portrait_neutral slot=portrait
# checkpoint room_arrival
# audio music quiet_room fade=0.4
Example caption. #id:line.day1.room.001
# art hide portrait
# audio sfx door_knock
Another caption. #id:line.day1.room.002
```

At handoff time, only the audio spellings above were implemented. PR #155 implements
the story/art/checkpoint surface and adds explicit reusable scene presets, typed
marker/Challenge declarations, and Gallery membership metadata. The
[current guide](dtl-story-authoring.md) is the syntax authority; audio, self-talk
and transition conventions retain their existing meanings.

A label plus explicit entry metadata generates its registration and target. It is not an Autosave. Artwork commands change persistent presentation without an Autosave. An explicit checkpoint invokes existing checkpoint semantics. A music command uses the implemented AudioManager path.

Keep commands on the reached side of their destination label, so jumping and sequential arrival agree. Do not split a caption/self-talk pair. Place commands before the complete pair.

## Required implementation behavior

1. Compile explicit entries, day assignment (1–7) and exactly one start into current registration structures. Reject duplicate entry IDs, missing start, invalid days and dangling targets with source filename/line diagnostics.
2. Move existing choice/Challenge marker binding authoring into explicit DTL declarations without changing the gameplay meaning. Generate current marker payloads and allowed signals; retain reusable board rules externally. Do not stop after entry discovery and claim all story dependencies became DTL-owned.
3. Support background selection and named artwork show/hide anywhere between reading units. Use stable slot/overlay identity for replacement and removal. Assets/layout presets remain in the existing art catalogue. Avoid hard-coded per-scene callbacks.
4. Persist current background and active artwork through the existing presentation owner. Do not make arbitrary artwork changes implicitly install a checkpoint, clear unrelated art, change BGM, unlock a library passage or save.
5. Define checkpoint behavior explicitly in relation to inline art: recommended minimal rule is to checkpoint the fully resolved presentation at that authored point. Existing base-presentation checkpoint definitions may be referenced if needed; compile their arrival from DTL instead of a second manual entry list. Do not let a hidden default reset inline art/audio unexpectedly.
6. Put Gallery grouping/membership and condition references in DTL metadata, separate from executing checkpoint arrivals. A branch may belong to an existing passage without arriving at the checkpoint again or triggering another Autosave. Requirements use existing all/any semantics; actual choice execution remains owned by existing gameplay logic.
7. Save/Load restores current resolved presentation and BGM selection directly; it must not re-execute earlier commands, SFX, choices or checkpoints to rebuild them. Language switch, History, Gallery, repaint and scrollback do not trigger story commands.
8. Preserve existing transition semantics. Preparing an incoming scene cannot prematurely show artwork, emit audio or mark dialogue read. Commit commands at the correct accepted reading boundary.
9. Maintain one authoritative source for migrated structure. Do not leave both manual JSON and DTL lists active with unclear precedence. Generated presentation data must not overwrite hand-authored reusable asset/layout records.
10. Keep existing stable explicit line IDs. New unrelated lines receive new IDs. Do not introduce positional IDs that invalidate all later lines on insertion.
11. Preserve seven-day gameplay, selected-language rendering, current control layout, and audio behavior. No arbitrary-length chapter system, new scripting VM or live runtime compiler.
12. Ordinary comments remain ordinary comments. Recognized directive prefixes must validate strictly; typos must not silently disappear as comments. Use the native compiler and source locations where possible rather than maintaining a competing full DTL parser.

## Implementation baseline

- `tools/authoring/AuthoredWeekRegistration.gd` currently reads `data/manifests/authored_week_source.json` for entries, start, days, markers and Challenge definitions, compiles each entry, and validates day 1–7.
- Its audio catalogue export now accepts stable music/SFX asset definitions and generates hashes/durations. Keep this ability; music/SFX placement is already DTL-owned.
- `scripts/narrative/DialogicRuntimeAdapter.gd` owns native compilation and supported commands. Extend the relevant compiled event model without executing arbitrary methods.
- `scripts/data/ArtManifest.gd` and GameState own named/ordered presentation. Inspect restore schemas and application paths before adding independent background state.
- `data/manifests/art_placements.json` currently mixes reusable assets/scenes with story-bound presentation/library metadata. Separate source ownership carefully instead of deleting the asset catalogue.
- `tools/authoring/ExportSevenDayRegistration.gd` generates story/library registrations and has fresh-process validation. Extend this existing path.
- [Current presentation guide](../../tests/fixtures/presentation/README.md) documents the old manual bindings. Update it when the new workflow actually works.
- [Audio guide](dtl-audio-authoring.md) is the existing cue syntax authority; do not replace it with the earlier proposed syntax in historical handoffs.

Recheck master before implementation. Read AGENTS.md and CLAUDE.md; read story guidance before changing narrative prose. No production story rewrite is selected here.

## Delivery stages and acceptance

1. Entry/start/day discovery and generated registration; prove adding, renaming and removing an entry from DTL without manually synchronizing JSON.
2. Inline artwork plus exact Save/Load state, independent from checkpoints.
3. DTL checkpoint/library metadata and choice/Challenge routing; remove duplicate authored structure after parity checks.
4. Complete replacement-story fixture, documentation, export/build acceptance.

A stage is not full completion until the end-to-end authoring objective is proved.

Cloud tests must demonstrate:
- A replacement synthetic seven-day story can be exported using the documented DTL declarations and unchanged reusable catalogues, without hand-editing generated files or per-entry marker lists.
- Entry/branch targets, selected start, choice/Challenge outcomes and day progression remain correct; malformed directives report useful locations.
- Background/show/hide at mid-entry, branches, repeated visits and Save/Load preserve actual visible art and ordering; no unintended Autosaves.
- A later Load restores a changed background/overlay/BGM combination without replaying one-shot SFX or earlier actions.
- Caption/self-talk pairing, bilingual text, read identity and library masks/reset rules remain intact.
- Checkpoint arrival and ordinary library membership remain distinct; combined/alternative requirements are correct.
- Existing audio Skip/Auto, input ownership and pixel transition tests remain meaningful.
- Export is deterministic, stale generated output is detected, registered assets are included in the Windows build, and the fresh exported game starts.
- No performance claim from code deletion alone. Preserve sparse coverage checkout and isolate suites that share setup. This is compiler/save/runtime work, not visual-only coverage.

All Godot and PowerShell execution runs in GitHub Actions. Inspect rendered artwork/transition/large-text examples and retain exact candidate/run evidence. Do not build migrations for replaced unshipped draft content or automatically delete user saves.

## Completion record

Completed on 29 October 2026 in [PR #155](https://github.com/Siuuuers/dwm/pull/155),
merged as `9a157d1ea39fed92fa14c7f2ba828929809b5d7f`.
Accepted source candidate: `f3bff8c75fbfe06f98e82cf68ec828846810c206`;
tested PR merge: `2c3c222ee85c3a13801b4fb7e8255a77912fc5cd`.

DTL owns 92 explicit entries, start/day declarations, 102 routing markers and nine
Challenge definitions. Duplicate structural JSON lists and per-entry artwork rows
are removed; three reusable art presets retain the existing appearance. Prose and
stable line IDs are unchanged. Registered entries must begin at a caption, and
manual declaration errors report source locations. Export derives the start target,
story registration and Gallery projection. The [authoring guide](dtl-story-authoring.md)
is the working syntax authority.

Inline scene/background/show/hide commands preserve named-slot ordering and do not
save or reset music. A checkpoint saves the final resolved artwork and selected BGM
of the next accepted caption. Gallery membership remains separate from arrival.
Load restores state without replaying commands, SFX or checkpoint writes. Compatible
saved captions that omit presentation resolve only their declared entry base; no
later commands are inferred and source save bytes remain unchanged. Draft-content
replacement has no migration or automatic save deletion.

Gallery caption-layer ownership no longer depends on optional artwork. Its synthetic
render fixture explicitly selects the reusable ending backdrop rather than relying
on a removed production entry row. The painting and readable caption were visually
checked against retained baseline evidence.

Acceptance:
- [Linux preflight 40862336277](https://github.com/Siuuuers/dwm/actions/runs/40862336277):
  104 tests, 1,714 assertions and 729 Gallery checks pass. Import, deterministic
  double export, fresh-process validation and synthetic seven-day replacement pass.
  All three generated registrations/start outputs and both public inventories match
  committed bytes exactly. Rendered assertion counts can vary with polling duration;
  the retained exact method list records this run.
- [Windows acceptance 40862336559](https://github.com/Siuuuers/dwm/actions/runs/40862336559):
  34 successful jobs, including all 29 selected gameplay suites, public contracts,
  fresh exported Windows startup and Linux desktop/dialogue/Gallery rendering.
  The unrelated archived matched-performance comparison is intentionally skipped.
  Export verifies 137 runtime data files. All Godot and PowerShell execution was cloud-only.
- Save/Load tests include a separate OS process, unchanged source saves, no replayed
  SFX/Autosaves, compatible missing-presentation Load, and continuing to the next
  checkpoint with exactly one new Autosave. Large-text controls and transition frames
  were inspected. [Durable evidence](../../evidence/phase_2r/dtl_first_20261029/acceptance.json)
  retains exact runs, artifacts, hashes, method counts, Load proof and selected captures.

Preflight shares import/setup across isolated related groups and checks Gallery replay
early. PR coverage retains the relevant 29 suites and existing sparse coverage checkout;
the temporary duplicate branch-push preflight trigger is removed. No gameplay-latency
improvement is claimed without a matched benchmark.

The reusable authoring workflow is complete. Final story prose, production checkpoint
placement and Gallery population remain content-authoring work rather than pending
runtime implementation.
