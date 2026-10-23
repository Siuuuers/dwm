# DWM: minimal Windows build and asset replacement

Prepared from product commit `82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc`.
This is a playable template build for private upload/launch testing, not a claim
of Valve review approval or finished story content.

## What to upload

Extract `game-build.zip` into a folder named `game-build`. Its root contains
`DWM.exe`, `DWM.pck`, and `licenses/`. Keep the executable and PCK together.
The license notices are retained. Validation reports, CI logs, project files,
authoring tools and source-control history are not loose depot files.

Use this folder as SteamPipe's content root, map its contents to the depot root,
and configure the Windows launch executable as `DWM.exe` (working directory is
the install root; no special launch arguments). Use your own App ID and Depot ID.
Then install and launch through the Steam client on a private test branch.
This package has not been uploaded or submitted to Valve by this task.
See https://partner.steamgames.com/doc/sdk/uploading and
https://partner.steamgames.com/doc/store/testing .

Only `validation.json` was removed from the already validated inner export ZIP.
All 17 retained files were checked byte-for-byte against its recorded hashes.
The existing cloud export passed the PCK audit and isolated headless startup;
the source's connected rendered story and Gallery checks also passed.
Packaging did not alter runtime bytes, so no duplicate engine run was needed.

## Replace art, music and templates

The editable project remains on GitHub branch `codex/art-media-20261023`.
The exported PCK is a compiled/imported snapshot. Adding a loose JPG or DTL
next to `DWM.exe` does not override it.

| Source file | Purpose |
|---|---|
| `tests/fixtures/dialogic/Day1.dtl` through `Day7.dtl` | Seven daily story templates; Day7 also contains the template ending |
| `art/pictures/picture1.jpg` through `picture5.jpg` | Five story/Gallery art slots |
| `audio/bgm/menu_theme.ogg` | Title music |
| `audio/bgm/story_theme.ogg` | Story music |

Replace files in the project, preserving identifiers/markers in DTLs. Use real
JPEG files for these five existing `.jpg` paths and real Ogg Vorbis music.
Renaming a PNG extension to JPG does not convert the file. Transparent art would
need a PNG path and a corresponding manifest update; the current five paintings
do not need transparency.

Run cloud Godot import, regenerate story registration with
`tools/authoring/ExportSevenDayRegistration.gd`, validate, and export again.
DTL and story-music edits change registered hashes; use fresh presentation saves
after content changes. Then replace the old build folder with the newly exported
files together. Keep store graphics outside this runtime folder.

Full mapping and Gallery unlocks:
https://github.com/Siuuuers/dwm/blob/codex/art-media-20261023/art/pictures/README.md

For future validated exports, run the repository packaging helper with the inner
Actions ZIP and a new destination directory:

`python tools/packaging/prepare_steam_build.py DWM-windows-x86_64-validation.zip output-directory`

It produces `game-build/`, a flat-root `game-build.zip`, and a separate packaging
receipt. It does not upload to Steam or change game content.

## Steam graphics are separate from in-game images

Steam's storefront/library artwork specifications do not set the format of our
internal game textures. Keep the five current JPG slots. For marketing artwork,
use the current Steamworks upload templates; PNG is a convenient working/export
choice, with the explicit formats below where Valve specifies them.

| Steam asset | Current dimensions / format |
|---|---|
| Store header capsule | 920 × 430 |
| Store small capsule | 462 × 174 |
| Store main capsule | 1232 × 706 |
| Store vertical capsule | 748 × 896 |
| Library capsule | 600 × 900 |
| Library header | 920 × 430 |
| Library hero | 3840 × 1240 PNG; artwork without text |
| Library logo | Transparent PNG, 1280 wide and/or 720 tall |
| App icon | 184 × 184 JPG |
| Shortcut icon | 256 × 256 ICO or PNG |
| Gameplay screenshots | At least five; minimum 1920 × 1080, 16:9 |

Base capsules should contain game artwork, title and optional official subtitle,
not review scores, discounts or promotional calls to action. Capture actual
gameplay for screenshots. Existing CI captures are test evidence, not a finished
Steam screenshot set. Sources checked 2026-10-22:

- https://partner.steamgames.com/doc/store/assets
- https://partner.steamgames.com/doc/store/assets/standard
- https://partner.steamgames.com/doc/store/assets/libraryassets
- https://partner.steamgames.com/doc/store/assets/rules

## Before release review

Valve asks for a near-final build that launches on each advertised operating
system and implements advertised features. Our placeholder dialogue, paintings
and music still need replacement before presenting this as the finished game.
Describe only what the submitted version actually contains; complete the Content
Survey and the app-specific Steamworks checklists. We have not inspected your
Steamworks account configuration or tested a Steam-installed copy.

Sources:
https://partner.steamgames.com/doc/store/review_process
https://partner.steamgames.com/doc/gettingstarted/contentsurvey
