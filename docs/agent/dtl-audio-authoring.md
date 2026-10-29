# Music and one-shot sounds in DTL

Add sounds to an existing registered entry. A sound cue does not need a new
entry, navigation label, presentation checkpoint, or Autosave.

## Register each sound once

The optional `audio` object in
`data/manifests/authored_week_source.json` supplies the catalogue. This example
uses illustrative filenames; provide the files before exporting:

```json
"audio": {
  "initial_music": "quiet_room",
  "music": [
    {"id": "quiet_room", "path": "res://audio/bgm/quiet_room.ogg", "gain_db": -3},
    {"id": "uneasy_room", "path": "res://audio/bgm/uneasy_room.ogg"}
  ],
  "sfx": [
    {"id": "door_knock", "path": "res://audio/sfx/door_knock.ogg", "gain_db": -6}
  ]
}
```

Use stable, unique IDs across both lists. `stop` is reserved. Music IDs become
music plan IDs; SFX IDs identify individual assets. They are not DTL labels.
Enable looping on imported music. SFX playback makes a non-looping copy of its
stream, so each encounter plays it once. Authored gain defaults to 0 dB and is
applied underneath the player's volume and mute preferences.

`initial_music` selects the new game's default; `""` starts in silence. It does
not reset music at each entry. Omitting the entire `audio` object preserves the
existing template soundtrack as the initial default. Providing it replaces that
default catalogue, so retain any plan IDs also referenced by named presentation
checkpoints. An optional integer `entrance_ms` on a music row sets its authored
starting position; the default is 0. Load uses this same starting position.

The exporter generates source hashes, durations, catalogue records and entry
bindings. Do not maintain these derived fields or a list of cue positions by
hand. Missing files prevent authoring export because their metadata cannot be
generated. A registered optional file unavailable at playback follows the
existing silent-media policy.

## Place cues in DTL

```text
label example.entry
# audio music quiet_room fade=0.4
A quiet room. #id:line.example.room
# audio sfx door_knock
# audio music uneasy_room fade=0.8
Someone is outside. #id:line.example.door
# audio music stop fade=0.4
Only silence remains. #id:line.example.silence
return
```

Put a cue before its accompanying caption. Consecutive cues execute in authored
order before that caption, without another Advance. Music accepts optional
`fade=<seconds>`; omitting it or using 0 cuts immediately. A nonzero music change
crossfades. Fades never delay reading. SFX has no fade or stop option.

Place cues before the **whole caption/self-talk pair**, never between the
caption and `# self-talk` or between that marker and its thought. The pair is one
simultaneous presentation. Preserve existing line IDs when adding or moving cues.
Audio directives do not create translated text, History entries, or library
unlocks. Ordinary comments retain their existing meaning. Misspelled reserved
audio commands, options, durations and unknown IDs fail compilation/registration.

Put a destination cue **after its label**. It then runs both when a jump reaches
that label and when reading reaches it in order. A cue immediately before a
label is rejected because a jump would bypass it while sequential
reading would cross it. A cue before a jump belongs to that outgoing branch;
a cue after the destination label belongs to the arrival.

For an existing registered control marker, place its cues between the label
and its registered signal. Cues after that signal belong to the next caption.
For a registered Finish, put the final music/SFX cues before its Finish signal;
Finish leaves the passage, so a trailing Return is not another encounter.

Music persists until another cue changes or stops it. Selecting the active ID
again does not restart it; stop then play to restart. Explicit named-checkpoint
audio still overrides the previous selection, followed by any inline arrival cue.
Hidden transition preparation must not emit sounds.

Manual reading and Auto play one-shot effects. Skip consumes them silently;
Next retains its existing stop rules: reached destination cues play normally;
ordinary Scene captions retain their existing unavailable Next behavior. A genuine later
story encounter can play the sound again. Load, language changes, repaint,
History, library browsing and Settings return do not replay crossed effects.

Save records the selected music ID or explicit silence, never elapsed playback
time or an unfinished fade. Saving during a change records the destination;
saving during fade-out records silence. Load clears abandoned transient playback
and starts the saved track at its authored entrance.

## Export and check in the cloud

After importing the project, run these in separate Godot processes on the cloud
runner:

```text
godot --headless --path . --script res://tools/authoring/ExportSevenDayRegistration.gd
godot --headless --path . --script res://tools/authoring/ExportSevenDayRegistration.gd -- --validate-seven-day-export
```

Commit the generated story and dialogue-library registrations alongside the DTL
and asset changes. Build and start a fresh game process so its immutable content
cache uses the new registration. The cloud audio suites check compilation,
playback, traversal and Save/Load; listening for artistic suitability remains an
author review. Deleting or renaming IDs used by old draft saves can make those
unshipped saves unusable; keep IDs stable or start a new draft run.
