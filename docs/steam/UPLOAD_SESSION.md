# Steam upload session — 2026-10-23

Goal: an authenticated private Steam installation that launches DWM.exe and
loads the intended PCK. Steam API integration is optional; start with the SDK's
SteamPipe tools. This is not a public release or Valve approval.

## Prepared

app_build_5199120.vdf maps only DWM.exe, DWM.pck and licenses/**.
It excludes repository files and the administrative Markdown inside game-build.
Copy it beside a validated game-build folder and use a separate output/cache directory. Preview=1 performs mapping preparation
without content upload. No SetLive directive is included.

## Required account inputs

Owner-supplied AppID: 5199120. Windows content DepotID: 5199121.
The owner has downloaded the SDK. IDs are configured, but their Steam account
permissions and depot ownership have not been verified. Still needed: an upload
environment authenticated with an account authorized for this app. Do not commit credentials or session
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

## Cloud upload route

SteamPipe can run on an authenticated cloud machine or CI runner. GitHub Actions
can build/export this project already, but the GitHub connector is not a Steam
login and this session currently has no authenticated Steam upload environment.
Downloading the SDK alone does not establish upload access.

For CI, use a dedicated Steam build account scoped to this app, with Valve's
required Edit App Metadata and Publish App Changes To Steam permissions.
Complete Steam authentication privately. Store required authentication material
in the CI secret store, never in repository files, chat, logs, or artifacts.
This GitHub connector cannot create/read repository secrets; the owner must
configure them through GitHub settings before an authenticated CI upload.
No Steam credentials or authenticated session have been supplied or installed.

Keep upload workflows manually triggered and separate from pull-request tests.
Use a pinned validated build, first run the Preview=1 configuration, then inspect
the resulting mappings. Change Preview to 0 only for the upload step. Keep
SetLive absent so upload does not select a live branch automatically.

The VDF can also run on the owner's already prepared SDK machine. Place it
beside game-build, authenticate with SteamCMD, and use run_app_build with the
absolute VDF path. This is an upload-only operation; Godot testing stays in cloud.
