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

## Replaceable DTL and the Gallery library

The current playable DTL is draft material. Checkpoint placement is editable data,
not final story approval. Keep all authored presentation/library choices in
`data/manifests/art_placements.json`; never copy dialogue into that file.

Alongside `presentation_checkpoints` and `presentation_entries`, add the optional
`dialogue_library` member. This example uses placeholder registered-entry IDs;
replace them with your own existing entry labels before exporting:

```json
"dialogue_library": {
  "condition_labels": {
    "ask_again": {"en": "Ask for another photograph"}
  },
  "passages": [
    {
      "id": "your.checkpoint",
      "title": {"en": "Photograph"},
      "entries": [
        {"entry_id": "your.opening.entry"},
        {
          "entry_id": "your.optional.entry",
          "requirements": {"label": "ask_again"}
        }
      ]
    }
  ]
}
```

The passage ID names an existing `presentation_checkpoints` definition and must
have an explicit checkpoint command in `presentation_entries`. List entry groups
in desired reading order; ordinary entries carry the active checkpoint forward.
Do not repeat a checkpoint command on every variant merely to include it in the
library: each checkpoint command is an actual arrival/Autosave boundary.

Requirements describe the actual authored branches; the exporter does not guess
choice or Challenge conditions from entry names. Omitted requirements mean none.
Use `{"all": [{"label": "choice"}, {"any": [{"label": "win"}, {"label": "perfect"}]}]}`
for combined/alternative requirements, defining every label in `condition_labels`.
Titles and conditions accept localized strings with English fallback.

The exporter takes caption text, line IDs, revisions, and paired self-talk directly
from the current native-compiled DTL. New/deleted/reordered lines follow the DTL;
there is no handwritten line list to synchronize. Story translations reuse
`localization/story` and its existing English-source match: changed draft text
falls back to current English until its translation is updated.

| Edit | Change |
| --- | --- |
| Add a checkpoint | Add its definition, bind the arrival entry, and optionally add its library passage. |
| Move a checkpoint | Move its checkpoint command to the desired registered entry; update library entry groups to match. |
| Rename the visible passage | Change `title`; keep its stable checkpoint ID. |
| Replace draft dialogue | Edit DTL, keep IDs for retained lines, give new lines new IDs, then export. |
| Remove a passage from Gallery | Remove its library passage; its presentation/Autosave binding can remain. |
| Remove a checkpoint entirely | Remove its commands, definition, and library passage together. |

A position inside an entry must first become a registered DTL entry label; a raw
label alone is not an entry registration. Update `authored_week_source.json` entry
and marker bindings when splitting an entry. Its historical `lines` text is
provenance, not the authority for exported dialogue. Do not rerun the historical
`build_playable_week.py` importer over edited DTL.

Run the existing `tools/authoring/ExportSevenDayRegistration.gd` on the **cloud
Godot runner**, then its `--validate-seven-day-export` fresh-process check. It
writes both `scene_story_registration.json` and
`dialogue_library_registration.json`. Commit both generated outputs with their
source changes, then launch a fresh build/process. The Gallery uses the exported
content; raw DTL edits without export and in-process hot reload are not a Gallery
preview workflow. The normal authored-week tests compare installed outputs with a
fresh compilation. Do not edit generated library prose by hand.

Changing wording creates a new exact witness revision; it does not inherit the
old wording's read credit. Unchanged lines retain their revisions. Renaming a
checkpoint ID creates a different discovery identity. Removing IDs can invalidate
old draft saves that reference them; this workflow does not add save migrations
or silently reset Profile history. Use a fresh draft run where necessary.

No real checkpoint placement is installed by this template. An absent or empty
`dialogue_library` produces an empty library, with no runtime authoring dependency.
