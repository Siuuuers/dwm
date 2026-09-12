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

For example, the Priscilla Day 1 date uses `art/environments/dating/solo/priscilla_day1.png` and `art/characters/priscilla/scene.png`. Check the CSV for the exact background path before exporting. Its pre- and post-challenge entries share the same pictures. A pair scene uses the same two character files throughout, without expression or result variants. Solitude scenes have no companion portrait. Only a Hospital visit with proven Sylvia attendance uses the Hospital DTL, background, and portrait. Ordinary fainting shows a short "You fainted." notice with Continue; it needs no artwork or dialogue, and its recovery effects are unchanged. Merely adding Sylvia's portrait never creates attendance.

When a return-only or empty DTL entry has a loaded background, portrait, or CG, it stays visible until you press Continue. Text-bearing scenes keep their normal dialogue flow. Art-only scenes also honor Pause and live text-size/language changes. Opening and Tutorial have registered placements for their existing timeline IDs; this change does not add a new intro route to the current direct-to-desktop New Account flow.

The catalog is [data/manifests/art_placements.json](../data/manifests/art_placements.json). Its `assets` section maps IDs to paths, and `scenes` assigns those IDs to exact entries. You can reuse any image by pointing several asset records at one path, or assign a different fixed portrait to one scene. No GDScript change is needed. Only imported PNG, SVG, WebP, JPG, and JPEG images are accepted; if you use another supported extension, update the catalog path too.

## Preview Dating scenes before writing dialogue

Open [DialogicPreview.tscn](../tests/manual/dialogic_preview/DialogicPreview.tscn) and press **F6**. The separate preview folder contains editable placeholder DTLs for all 32 Dating entries and seven Sylvia-present Hospital day variants. It reads the same art placements, with optional Inspector texture overrides and test silhouettes for missing pictures. See its [short guide](../tests/manual/dialogic_preview/README.md). Run it directly as a scene; it does not advance your game.

The title now places **DWM**, **Welcome! :)**, and account-startup status over the right-side illustration slot. Keep that text area legible when painting `art/ui/title/background.png`.

## Composition and Gallery

The narrative artwork area is 1280 ? 448 at 100% text size, 1280 ? 392 at 125%, and 1280 ? 328 at 150%. Keep important faces and objects near the central safe area; backgrounds may crop as the caption grows. Portraits and CGs fit inside the available area. A loaded CG replaces portraits, so paint its characters into that single image if desired.

During a Minesweeper date, the board retains its current dimensions. Character pictures fit inside the left and right 160-pixel margins; avoid tiny facial details that depend on a large portrait. The background fills the scene behind the board. Images never receive mouse or keyboard input.

Gallery uses the exact reached ending's CG, or the reached Dating scene's background. Reached-date replay and Day 7 echo cards also use their exact entry's scene art above the existing reading panel. Full/residue and normal/dark entries have separate optional CG slots. Installing a picture does not unlock a record or invent a reached version. Unreached or missing pictures remain hidden. A CG also stays centered inside Gallery's 520 ? 512 preview area.

## Import and export

Use lossless import for small UI artwork; keep text and functional hover/focus/selection marks out of the pictures. Larger-image sizes above are composition recommendations, not hard rejection rules. Align the three shell files on the same transparent canvas so their fitted layers line up. The shell keepsakes image is decorative, not a new inventory-state renderer.

`art_source/.gdignore` prevents editable source files from entering Godot. Before packaging a build, include the runtime `art/` resources and `*.json` in the export preset's non-resource include filter: the artwork catalog is loaded as JSON, like the existing gameplay manifests. This repository currently has no export preset; placement tests verify the editor/runtime project, not a packaged release.

The two artist CSV maps use Godot's Keep File import mode so they are not interpreted as translation tables. Keep their `.import` sidecars beside them. See [Godot's import process](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html).

Test-only geometric images in `tests/fixtures/art/` are verification fixtures, not your final assets.

## Found paintings currently installed (2026-09-12)

The portraits, the shell room and the shared scene backgrounds are crops of
public-domain museum paintings, installed for vibe and testing under the
owner's 2026-09-12 ruling (see the design amendment of that date, Section 9).
They are not final art. Originals, museum credit lines, licence statements,
source URLs, checksums and the crop recipe live in
`art_source/found_paintings/sources.json`; the research trail is
`docs/research/art/2026-09-12-found-paintings-candidate-ledger.md`.

| Slot | Painting | Museum credit |
|---|---|---|
| Priscilla scene and contact | Berthe Morisot, *Reading*, 1873 | The Cleveland Museum of Art, Gift of the Hanna Fund 1950.89 (CC0) |
| Lavinia scene and contact | Edgar Degas, *Frieze of Dancers*, c. 1895 | The Cleveland Museum of Art, Gift of the Hanna Fund 1946.83 (CC0) |
| Sylvia scene and contact | Mary Cassatt, *After the Bath*, 1901 | The Cleveland Museum of Art, Gift of J. H. Wade 1920.379 (CC0) |
| Shell room (`art/shell/background.png`) | Vilhelm Hammershoi, *Interior with an Easel, Bredgade 25*, 1912 | The J. Paul Getty Museum, 2018.59, Getty Open Content Program (CC0) |
| Contacts scene backgrounds | Claude Monet, *The Red Kerchief*, c. 1868-73 | The Cleveland Museum of Art, Bequest of Leonard C. Hanna Jr. 1958.39 (CC0) |
| Priscilla dating and ending backgrounds | Morisot, *Reading* (field band) | as above |
| Lavinia dating and ending backgrounds | Degas, *Frieze of Dancers* (full frieze) | as above |
| Sylvia dating, Hospital and ending backgrounds | Gwen John, *Interior*, 1915 | The Cleveland Museum of Art, Mr. and Mrs. William H. Marlatt Fund 1982.6 (CC0) |
| Group and twofriends backgrounds | Edouard Vuillard, *At the Cafe*, c. 1897-99 | The Cleveland Museum of Art, Bequest of Leonard C. Hanna Jr. 1958.57 (CC0) |
| Opening, tutorial, echo and Alone-ending backgrounds | Hammershoi, *Interior with an Easel* (floor band) | as above |

The shared backgrounds live in `art/environments/paintings/` and the catalog
records point at them; the per-scene PNG paths listed earlier in this file
remain valid drop-in slots if you later paint a scene-specific picture and
repoint its record. The desktop wallpaper and the title illustration are
deliberately left empty: the 2026-09-12 amendment keeps wallpaper code-drawn
and leaves the title presenter for a later ruling.
