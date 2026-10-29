# DTL-first story authoring

DTL owns entry/start/day declarations, story routing, presentation commands,
checkpoint arrival, and Gallery membership. Reusable image/layout/audio data and
translations stay in catalogues. Edit DTL, run cloud export/validation, then build.
There is no runtime source scan or hot reload.

## Entries and routes

`data/manifests/authored_week_source.json` selects one `timeline_root`. Export
recursively discovers `.dtl` files in sorted order. Every registered entry needs
an explicit declaration immediately after its label; ordinary labels stay local.
Exactly one entry says `start`. Days remain integers 1–7.

```text
label room.opening
# story entry day=1 start
# art scene draft.reading.early
# audio music quiet_room fade=0.4
A caption. #id:line.room.opening.001
```

Keep stable explicit line IDs. Inserting an unrelated line needs a new ID, not
renumbering subsequent captions. Keep commands before a complete caption/self-talk
pair, never between its caption and `# self-talk` text.

Existing route owners consume explicit typed marker payloads. Put a marker
annotation immediately after its marker label; the exporter derives its marker
ID and preceding caption anchor. Examples:

```text
label room.choice
# story marker {"kind":"thought.pass","payload":{"opportunity_id":"room.ask","yes_target_id":"target.room.yes","pass_target_id":"target.room.default"}}
return

label room.yes
# story entry day=1
An answer. #id:line.room.yes.001
label room.yes.next
# story marker {"kind":"scene.transition","payload":{"target_id":"target.room.default"}}
return
```

Supported marker kinds retain their existing gameplay semantics: `thought.pass`,
`thought.options`, `scene.transition`, `challenge.playable`, `challenge.end`,
`challenge.recall`, `passage.start`, and `passage.finish`. JSON contains only
`kind` and `payload`; it is data for the existing owners, never arbitrary code.
Existing migrated Day1–Day7 files are complete examples of each payload shape.

A Challenge declaration belongs under its owning entry:

```text
# story challenge {"challenge_id":"room.challenge","playable_marker_id":"room.playable","end_marker_id":"room.end","board_profile_id":"week.canonical_solo","targets":{"never_started":"target.room.A","unfinished":"target.room.B","won":"target.room.C","lost":"target.room.D","perfect":"target.room.E"}}
```

Define the playable/end markers in that entry. Board rules remain reusable; DTL
owns where the Challenge occurs and its outcome destinations. Export reports
missing targets and malformed declarations with source locations.

## Artwork and checkpoints

```text
# art scene draft.reading.early
# art background picture3
# art show portrait_neutral slot=portrait
# art hide portrait
# checkpoint room.arrival
The next caption. #id:line.room.arrival.001
```

- `scene` selects a reusable `art_placements.json` `scenes` preset (background,
  portraits, CG, split-panel layout). It preserves named overlays and music.
- `background` changes only the background to an existing asset ID.
- `show` selects an `overlay_labels` preset (asset ID and normalized rectangle)
  for a named slot. Replacing a slot preserves its drawing position; a new slot
  draws after earlier slots.
- `hide` removes the slot; hiding an absent slot has no effect.
- `checkpoint` declares a stable checkpoint ID and requests an Autosave at the
  next accepted caption. It does not reset artwork or music.

Commands before the same caption form one reading boundary: the checkpoint saves
that caption's final visible artwork and selected BGM. Put a checkpoint before a
caption, not before a jump, held control, or return. Artwork alone never requests
an Autosave. Reaching a checkpoint again is another arrival; Gallery membership
alone is not an arrival. Load restores saved composition and BGM directly without
replaying commands or one-shot SFX. Incoming transitions stage their composition
until acceptance; History, Gallery and language changes do not execute commands.

Add new image files/assets or reusable overlay layouts to the catalogue once.
Moving their usage requires only DTL. Example reusable overlay:

```json
"overlay_labels": {
  "portrait_neutral": {"asset_id":"picture1","rect":[0.1,0.1,0.4,0.8]}
}
```

Audio syntax and Skip behavior remain documented in
[the audio guide](dtl-audio-authoring.md).

## Gallery membership and localized labels

Declare membership under each participating entry, separately from checkpoint
arrival. The first member supplies a title key; later members may omit it.

```text
# story passage {"id":"room.arrival","title_key":"room"}
# checkpoint room.arrival
```

A branch can instead declare only:

```text
# story passage {"id":"room.arrival","requirements":{"all":[{"label":"ask"},{"any":[{"label":"won"},{"label":"perfect"}]}]}}
```

The source catalogue supplies reusable display text:

```json
"library_titles": {"room":{"en":"Room","zh_HK":"房間"}},
"condition_labels": {
  "ask":{"en":"Ask"}, "won":{"en":"Win"}, "perfect":{"en":"Perfect"}
}
```

An actual `# checkpoint room.arrival` must exist somewhere in the compiled story.
Membership includes that entry's native captions and paired thoughts; no prose or
read identities are copied manually. Conditions describe branches using the
existing `all`/`any` semantics; friendly names do not create gameplay conditions.
Current prose translations remain in `localization/story`.

## Generated outputs and cloud checks

`ExportSevenDayRegistration.gd` writes `scene_story_registration.json`,
`dialogue_library_registration.json`, and `story_start.json`. The latter selects
the actual starting target; the old seven-day test order is not the production
start owner. Never hand-edit these generated files to repair a DTL declaration.

The DTL-first cloud preflight imports once, exports twice to check determinism,
validates in a fresh process, exercises synthetic replacement content, and retains
generated outputs and exact candidate evidence. Finish caller/save reviews and
inspect focused screenshots before freezing a candidate for full acceptance.

For preparation, dispatch the preflight with `check_generated=false`. It collects
behavioral results and both public inventories even when generated files are stale.
Take the three manifests and two inventories from that same candidate's artifact
and commit them together. PR acceptance checks all five against committed bytes
after collecting results; regenerating an inventory is not acceptance by itself.

DTL-only changes under `dialogic/timelines/authored_week/` (including nested files)
may accompany the three generated manifests and this guide. They select the 29 DTL
runtime suites plus all 12 manual-content-update Save/Load suites. Changes to the
source-root configuration or unrelated runtime owners retain broader coverage.
Export, Gallery rendering and desktop/dialogue rendering start after coverage
selection, alongside public-contract checks; every applicable result must pass.
Draft-content replacement does not migrate or delete existing user saves.

Compatible earlier saves that omit resolved presentation use only the current entry's declared `# art scene` base preset on Load. This preserves the existing caption's background, portraits and split layout without replaying checkpoints, inline artwork, or audio cues, and without rewriting the saved file. It does not infer later artwork or migrate replaced draft story content.

For an optional timing baseline, dispatch with `reading_baseline=true`. This probe
is tied to the current shipped Day1 opening: three isolated processes each record
New Acc and three next-caption inputs, with first visible drawing and fully
revealed/input-ready drawing measured separately. Raw samples, source/content
fingerprints and screenshots are retained. It is not a story acceptance contract
or a speed threshold; update the probe deliberately when replacing that opening.
Fresh processes do not establish cold OS caches. These software-rendered editor
measurements do not establish exported-player, cross-entry transition or Load
latency.

[The initial observation](../../evidence/phase_2r/dtl_feedback_20261029/reading-baseline/summary.json)
and [preparation provenance](../../evidence/phase_2r/dtl_feedback_20261029/preparation.json)
retain the first baseline; they do not demonstrate a speedup.

CI feedback improvements and current regression-fixture repairs are complete in
[PR #156](https://github.com/Siuuuers/dwm/pull/156). The
[acceptance record](../../evidence/phase_2r/dtl_feedback_20261029/acceptance.json)
links the exact tested tree, successful cloud runs and measurement limits.
