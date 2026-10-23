# Manual Dialogic preview (temporary, noncanonical)

Open **`tests/manual/dialogic_preview/DialogicPreview.tscn`** in Godot and press **F6 (Run Current Scene)**. No command-line options or test wrapper are needed. Press **F8** to stop.

The first sample uses one fixed portrait; finishing it opens a two-character sample. The bottom selector contains **all 32 registered Dating pre/post scenes**, including solo, group, and deferred two-friend scenes, plus **seven Sylvia-present Hospital day variants**. These use the existing `hospital.faint.day1` through `day7` artwork, with an explicit visual-only Sylvia-present fixture. Ordinary fainting is excluded; this does not claim an actual Hospital receipt or introduce a gameplay route.

Click the current caption or press Enter to reveal/advance. Select another scene or use **Replay** to restart. The text-size picker shows the production 100/125/150% caption layouts.

**Edit dialogue:** open the matching file in `timelines/`, for example `dating.solo.priscilla.day1.pre_challenge.dtl`. Each selected scene has its own ordinary Dialogic DTL, with a comment linking its production source. These are explicitly noncanonical placeholders, outside the game's canonical timeline folders and manifests. Keep the visual test free of game signals, variable changes, save events, and progression calls.

**Try artwork:** select the root `DialogicPreview` node and assign **Background**, **First Portrait**, and **Second Portrait** textures in the Inspector. When unset, the preview reads the selected scene's existing art placement; absent images use existing colored test silhouettes. It reuses `SceneArtView` and `witnessed_caption_style.tres`, with one fixed image per solo scene and two per group/two-friend scene. It previews the dialogue presentation, not the playable Minesweeper worksheet.

**Isolation:** `_enter_tree` claims the existing explicit `test_manual` Bootstrap mode before deferred startup. Profile, SaveManager, gameplay owners, and DialogicBridge are not initialized. Dialogic autosave and persistent visited-history writes are disabled in memory. No game save/Profile files, unlocks, story flags, canonical manifests, or settings are written. Godot may still create its normal runtime log and shader cache. Before any main scene loads, the Dialogic autoload creates an empty `dialogic/saves/global_info.txt` when absent; existing files are not replaced, and this preview writes no settings to it. Run directly with F6, not by changing scenes inside a live game.

Delete this folder when no longer useful; production code does not reference it. The optional `--verify-manual-preview` flag is for the isolated automated visual smoke test only.
