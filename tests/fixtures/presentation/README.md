# Named presentation authoring template

`named_checkpoints.json` is a test fixture and copyable shape, not a production
checkpoint list. Copy the `presentation_checkpoints` and `overlay_labels` members
into the existing `data/manifests/art_placements.json` when authoring a checkpoint.
Do not replace the existing assets or scenes with this fixture.

- Replace `template.checkpoint` with the stable checkpoint ID.
- Set `scene_entry_id` to an existing art `scenes` key. That record supplies the
  background, base portraits, CG and split-panel preference.
- Set `audio_plan_id` to an existing AudioManifest plan ID, or an empty string for
  silence. The test example references the synthetic `template.shared.music.plan`; replace
  it with a plan from your installed story registration.
- Add each overlay label once under `overlay_labels`. Set `asset_id` to an existing
  art asset. Two labels may use the same image at different positions.
- `rect` is `[x, y, width, height]` relative to the full scene art aperture. Values
  `0` and `1` name its edges; positive width and height are required. The image
  keeps its aspect ratio inside the rectangle. Later active labels draw on top.

The live Run retains `{checkpoint_id, overlays}`. Showing an active label
and removing an absent label are no-ops. A new checkpoint clears that ordered
list. Loading resolves the retained list directly and does not enter a checkpoint.

The fixture is not installed in the production catalog and designates no story
location. Installing an explicit checkpoint binding makes that authored arrival
produce one Autosave; overlay-only bindings do not save.

## Bind existing entry labels

Add `presentation_entries` beside the other members. Each key is an explicitly
authored entry ID from the story registration (which resolves its DTL label). Its value is an ordered array of commands:

```json
{
  "your.registered.entry.id": [
    {"kind": "checkpoint", "id": "your.checkpoint"},
    {"kind": "show", "id": "your.art.label"},
    {"kind": "remove", "id": "another.art.label"}
  ]
}
```

Use only the commands needed at that entry. Split an authored entry at a registered
label when a presentation change is needed within a longer passage. An unlisted
entry carries the active named presentation forward; it does not create an
Autosave point. Before the first named checkpoint, existing entry presentation
continues to work. New Account may install its explicitly bound checkpoint
without creating an initial Autosave.
