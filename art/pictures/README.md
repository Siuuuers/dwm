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

| File | Plays in |
|---|---|
| `audio/bgm/menu_theme.ogg` | Title/menu |
| `audio/bgm/story_theme.ogg` | Days 1–7 and the template ending |

The paths stay separate. You may export the same recording to both files, or use
different music. Supply actual Ogg Vorbis files. The Title uses Bach / Kimiko Ishizaka, Prelude No. 9 in E major (BWV 854).
The story uses Prelude No. 14 in F-sharp minor (BWV 859), reduced by 6 dB.
Both are complete movements repeated by the existing loop setting; they are not
claimed seamless loops. Credits and exact sources: `audio/bgm/CLASSICAL_MUSIC_NOTICES.txt`. Both use the Music
volume control. Scene admission restarts at the authored entrance; loading uses
the authored load anchor rather than saving a playback timestamp.

After changing story music, run the existing cloud authoring/build flow, including
`tools/authoring/ExportSevenDayRegistration.gd`, before exporting. It records the
new audio hash and duration in the story registration. An old registration with
different music bytes will reject that media; replacing music only inside an
already exported package is not supported. The generated content fingerprint
changes, so use a fresh presentation save after rebuilding content.

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
