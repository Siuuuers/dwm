# Put your artwork here

These are optional, working image slots. Start with a few pictures; the game does not require all 132 distinct paths to be filled. Final artwork is not included. Minesweeper cells, flags, mines, numbers, and their state effects remain drawn in code.

## First three steps

1. Export a PNG to an exact path below, replacing `<friend>` with `priscilla`, `lavinia`, or `sylvia`. Use transparent backgrounds for portraits and overlays. Keep editable Krita/PSD files in `art_source/`.
2. Open the project in Godot and let imports finish. Restart the running game after changing a picture. PNG names and case must match the catalog.
3. Visit the relevant screen. Missing images retain the existing background or procedural/neutral fallback. Small UI images with the wrong dimensions also fall back.

| Picture | Place the PNG here, relative to the project | Export size | Display |
|---|---|---|---|
| Title illustration | `art/ui/title/background.png` | 960 ? 656 suggested | Right of the title menu; fills/crops its slot |
| Desktop wallpaper | `art/ui/desktop/background.png` | 800 ? 656 suggested | Below the desktop's top strip; fills/crops |
| Shell background | `art/shell/background.png` | 480 ? 504 suggested | Below the live statistics |
| Angela in the shell | `art/shell/angela.png` | Same transparent canvas | Above shell background |
| Shell keepsakes overlay | `art/shell/keepsakes.png` | Same transparent canvas | Above Angela; one decorative overlay for now |
| Fixed scene portrait | `art/characters/<friend>/scene.png` | 320 ? 448 suggested | One portrait in a solo scene; two in a pair scene |
| Contacts portrait | `art/characters/<friend>/contact.png` | **32 ? 64 exact** | Reused by the contact row and header |
| Launcher icon | `art/ui/launcher/<app>.png` | **48 ? 48 exact** | Existing button keeps its text/focus/hit area |
| Shop card picture | `art/shop/items/<item>-card.png` | **28 ? 28 exact** | Drawn at 2? |
| Shop inspector picture | `art/shop/items/<item>-inspector.png` | **56 ? 56 exact** | Drawn at 2? |
| Schedule compact picture | `art/schedule/folios/<name>-compact.png` | **24 ? 24 exact** | Shared across corresponding actions/days |
| Schedule folio picture | `art/schedule/folios/<name>-folio.png` | **64 ? 64 exact** | Shared across corresponding actions/days |
| Scene background | `art/environments/<DTL folder>/<scene>.png` | 1280 ? 448 suggested | Above the caption; fills/crops |
| Ending CG | `art/narrative/cgs/<exact-entry-id>.png` | 1280 ? 448 suggested | Replaces portrait composition; fits without cropping |

Launcher names: `minesweeper`, `contacts`, `schedule`, `shop`, `backup`, `settings`, `logout`.
Shop and Schedule filenames are listed in [asset-paths.csv](asset-paths.csv); these tables include every exact filename, including reused paths.

## Find a particular DTL scene

[scene-map.csv](scene-map.csv) lists all 137 registered semantic entries plus Opening and Tutorial, with the original `.dtl` path, day, background, up to two fixed portraits, and optional ending CG. The game still uses the existing scene-based DTL organization. No eight-master conversion is needed.

For example, the Priscilla Day 1 date uses `art/environments/dating/solo/priscilla_day1.png` and `art/characters/priscilla/scene.png`. Check the CSV for the exact background path before exporting. Its pre- and post-challenge entries share the same pictures. A pair scene uses the same two character files throughout, without expression or result variants. Solitude scenes have no companion portrait. Hospital only shows Sylvia when the current route proves her attendance; merely adding her portrait never creates attendance.

When a return-only or empty DTL entry has a loaded background, portrait, or CG, it stays visible until you press Continue. Text-bearing scenes keep their normal dialogue flow. Art-only scenes also honor Pause and live text-size/language changes. Opening and Tutorial have registered placements for their existing timeline IDs; this change does not add a new intro route to the current direct-to-desktop New Account flow.

The catalog is [data/manifests/art_placements.json](../data/manifests/art_placements.json). Its `assets` section maps IDs to paths, and `scenes` assigns those IDs to exact entries. You can reuse any image by pointing several asset records at one path, or assign a different fixed portrait to one scene. No GDScript change is needed. Only imported PNG, SVG, WebP, JPG, and JPEG images are accepted; if you use another supported extension, update the catalog path too.

## Composition and Gallery

The narrative artwork area is 1280 ? 448 at 100% text size, 1280 ? 392 at 125%, and 1280 ? 328 at 150%. Keep important faces and objects near the central safe area; backgrounds may crop as the caption grows. Portraits and CGs fit inside the available area. A loaded CG replaces portraits, so paint its characters into that single image if desired.

During a Minesweeper date, the board retains its current dimensions. Character pictures fit inside the left and right 160-pixel margins; avoid tiny facial details that depend on a large portrait. The background fills the scene behind the board. Images never receive mouse or keyboard input.

Gallery uses the exact reached ending's CG, or the reached Dating scene's background. Reached-date replay and Day 7 echo cards also use their exact entry's scene art above the existing reading panel. Full/residue and normal/dark entries have separate optional CG slots. Installing a picture does not unlock a record or invent a reached version. Unreached or missing pictures remain hidden. A CG also stays centered inside Gallery's 520 ? 512 preview area.

## Import and export

Use lossless import for small UI artwork; keep text and functional hover/focus/selection marks out of the pictures. Larger-image sizes above are composition recommendations, not hard rejection rules. Align the three shell files on the same transparent canvas so their fitted layers line up. The shell keepsakes image is decorative, not a new inventory-state renderer.

`art_source/.gdignore` prevents editable source files from entering Godot. Before packaging a build, include the runtime `art/` resources and `*.json` in the export preset's non-resource include filter: the artwork catalog is loaded as JSON, like the existing gameplay manifests. This repository currently has no export preset; placement tests verify the editor/runtime project, not a packaged release.

The two artist CSV maps use Godot's Keep File import mode so they are not interpreted as translation tables. Keep their `.import` sidecars beside them. See [Godot's import process](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html).

Test-only geometric images in `tests/fixtures/art/` are verification fixtures, not your final assets.
