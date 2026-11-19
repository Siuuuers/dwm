# Replace the seven-day artwork and music

All paths below are relative to the folder containing `project.godot`.
Replace the files, keeping their exact names and formats. Rebuild/import and restart
the game to see replacements. Renaming a PNG to `.jpg` does not convert its format.

| File | Story placement | Gallery unlock |
|---|---|---|
| `art/pictures/picture1.jpg` | Left panel, Days 1–7 | First visible caption of Day 1 |
| `art/pictures/picture2.jpg` | Right panel, Days 1 and 3; also the temporary Day 2 choice | First visible caption of Day 1 |
| `art/pictures/picture3.jpg` | Right panel, Days 4–7 | First visible caption of Day 4 |
| `art/pictures/picture4.jpg` | Gallery only | First visible caption of Day 2 |
| `art/pictures/picture5.jpg` | Gallery only | First visible caption of Day 3 |

There is no fixed image resolution. Scene panels fit/crop to their available area;
Gallery previews and fullscreen views preserve the whole image's proportions.
The placement owner is `data/manifests/art_placements.json`. The left/right divider
uses the existing scene split preference.

Open Gallery → Artwork, select a thumbnail, then click the right preview.
Fullscreen shows only the artwork and `H — Hide · Esc — Exit`.
H toggles those words; Esc returns to the preview. Records remains the default tab.
Unlocks use the existing persistent visited-line history; opening art does not write
progress. Clearing that history also clears these artwork unlocks.

## Music

| Shipped track | Source score | Use |
|---|---|---|
| `audio/bgm/menu_theme.nsf` | `tools/audio_prototype/fixtures/loop_a.txt` | Title, with a pulse intro and a rest in the loop |
| `audio/bgm/story_theme.nsf` | `tools/audio_prototype/fixtures/loop_b.txt` | Story, with a pulse-and-saw loop |

Both use the Music volume control. After changing the story track, regenerate the
story registration so its digest matches the shipped bytes. See
[DTL audio authoring](../../docs/agent/dtl-audio-authoring.md) for the export commands.

## Temporary painting sources

These slots are exact copies of existing repository paintings under
`art/environments/paintings/`, retaining their existing provenance:

1. `degas_frieze_rehearsal.jpg`
2. `gwen_john_interior.jpg`
3. `hammershoi_interior_easel.jpg`
4. `monet_red_kerchief_window.jpg`
5. `morisot_reading_field.jpg`

The older broad art guide remains at `art/README.md`. These five slots are the
ones used by the seven-day template flow.
