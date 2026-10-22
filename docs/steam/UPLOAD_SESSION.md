# Steam upload session — 2026-10-23

Goal: an authenticated private Steam installation that launches DWM.exe and
loads the intended PCK. Steam API integration is optional; start with the SDK's
SteamPipe tools. This is not a public release or Valve approval.

## Prepared

app_build_windows.vdf.example maps only DWM.exe, DWM.pck and licenses/**.
It excludes repository files and the administrative Markdown inside game-build.
Copy it beside a validated game-build folder, replace both explicit ID placeholders,
and use a separate output/cache directory. Preview=1 performs mapping preparation
without content upload. No SetLive directive is included.

## Required account inputs

Actual AppID, Windows content DepotID, and an upload environment authenticated
with an account authorized for this app. Do not commit credentials or session
files. The connected GitHub service returned 404 for Siuuuers/dwm-steam; this does
not establish whether it was deleted, renamed or merely inaccessible.

Configure the Steamworks installation directory and DWM.exe launch option,
publish configuration, and ensure the testing package includes the depot.
Use SteamPipe GUI from the SDK or SteamCMD +run_app_build with the finalized VDF.
After a successful Preview, inspect the mapped manifest, then change Preview to 0
for an authorized upload. Select a private test branch in Steamworks and protect
it before setting the uploaded BuildID live. Never choose default for this test.

## Build choice and remaining work

The existing delivery branch contains a PR #43 authored-week export.
The integration branch contains later user artwork and Bach music, with
registration validated at 3b23d8fc6b2798340af0b688323be3eee99458f7.
These are different source snapshots. Before a new final export, compose the
intended authored-week/runtime work with those media updates, or explicitly
use the existing delivery build for upload plumbing only. Do not export the
integration template and label it the authored-week game.

Then run the focused package-content/startup checks, upload the validated content,
record BuildID and source SHA, and verify a clean Steam install plus Save/Load.
Do not repeat unrelated qualification. Use fresh saves after content fingerprints
change. Localization proceeds in its own branch; its completion is not required
for an English-only private upload exercise.

Official procedure:
https://partner.steamgames.com/doc/sdk/uploading
https://partner.steamgames.com/doc/store/testing
https://partner.steamgames.com/doc/sdk/api
