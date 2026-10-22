# Steam cloud upload

Workflow: [Steam private upload](https://github.com/Siuuuers/dwm/actions/workflows/steam-upload.yml).

## Run

Open Actions, select Steam private upload, choose Run workflow on master.
Mode `preview` checks the mapping without uploading. Mode `upload` performs
that preview first, then uploads only if it succeeds. Neither mode sets a
Steam branch live. This workflow never submits release review.

Repository secrets: STEAM_USERNAME and STEAM_CONFIG_VDF (Base64 of an
authenticated SteamCMD config/config.vdf, without certificate wrapper lines).
Do not put passwords, configuration contents or Steam Guard codes in chat,
source, logs or artifacts. Authentication is not verified until a run succeeds.

## Pinned package

AppID: 5199120. DepotID: 5199121.
Delivery commit: 1b98886628c3e042c5a7c5738ddb2912f27d7ae8.
Runtime source: 2146c4435041c2b4ccc467a526f7b127d3980a2f (PR #43 authored week).
Only DWM.exe, DWM.pck and licenses/** are staged; the administrative Markdown
is omitted. The workflow records file hashes in its summary. This is the
existing upload-test package, not the newer integration art/music export.
Update the pinned checkout and recorded source together after a new validated
export; no automatic latest-branch deployment is configured.

## Results and next step

A successful upload summary reports the Steam BuildID. If no confirmed BuildID
is found, inspect Steamworks Builds before retrying to avoid a duplicate upload.
Raw SteamCMD output is withheld because it may contain account information.
The workflow reports only known error categories and deletes temporary files.
SteamCMD may refresh its cached token. This workflow deliberately does not
publish or cache authentication files; if future login fails, authenticate
privately again and replace the GitHub secret.

After upload, configure DWM.exe as the Windows launch executable, ensure depot
5199121 is in the testing package, select the build for a protected test branch,
and test installation and Save/Load through Steam. Upload success alone does
not establish installation, gameplay acceptance or Valve approval.

## Validation at creation

YAML and embedded Python parsed successfully; read-only GitHub permissions,
fixed package ref, staged file allowlist and absence of SetLive checked.
No cloud execution or authenticated Steam result was available at creation.
The connected GitHub tool can save workflows but does not expose new-run dispatch;
the owner starts this manual workflow through GitHub's Run workflow button.

References:
- https://partner.steamgames.com/doc/sdk/uploading
- https://game.ci/docs/github/deployment/steam/
