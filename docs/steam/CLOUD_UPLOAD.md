# Steam cloud export and upload

Workflow: [Steam private upload](https://github.com/Siuuuers/dwm/actions/workflows/steam-upload.yml).

## Selected source

The owner selected cc40aee5722afaa24e8a8daa556e8c27bc956810 from PR #42.
It integrates PR #43's English authored week, Traditional/Simplified Chinese,
Japanese and Korean display catalogs, current paintings and Bach Title/story music.
The previous delivery commit 1b988866 is no longer selected by this workflow.
AppID: 5199120. DepotID: 5199121.

## Start a new run

Open the workflow, choose Run workflow, branch master, mode upload. Do not use
Re-run jobs on the old failed run: it retains the old workflow revision.
Mode preview performs export and SteamPipe preview without a content upload.
Mode upload performs the same checks, then uploads. Neither mode sets a Steam
branch live or submits release review.

The build job checks out the exact source, checks story catalogs, imports and
exports with the existing pinned Godot 4.6.3 toolchain. It reuses the existing
Windows export validation helper and extends only its package audit in the
disposable runner: both music files, five imported paintings, new font, and
additional development-directory exclusions. Runtime source remains pinned.
The existing audit hashes the packaged localization JSON and authored DTL.
The executable must pass isolated headless startup. This is not a complete
Windows graphical playthrough or listening assessment.

Only after export success does a separate Steam job download that run's clean
runtime artifact and receipt, verify every file's hash, preview and upload.
The validation JSON is kept outside the uploaded runtime package. Required
engine sidecars, if produced by the validated exporter, are retained along with
EXE, PCK and licenses. Music and DejaVu font notices are required.
Artifacts steam-localized-package and steam-localized-receipt are retained for
seven days, including when a later Steam login/upload fails. The old binary
delivery branch is not overwritten by this workflow.

## Authentication and results

Repository secrets: STEAM_USERNAME and STEAM_CONFIG_VDF (Base64 of authenticated
SteamCMD config/config.vdf, without certificate wrapper lines). Authentication
contents are not committed, uploaded as artifacts or printed. Bootstrap diagnostics
are printed before any account/configuration is supplied; authenticated stages
report only stage, exit code and fixed error categories. Temporary files are deleted.
Steam may refresh cached tokens; this workflow does not publish or cache those
files. If login expires, authenticate privately and update the secret.

A successful upload reports a Steam BuildID. If a run finishes without a confirmed
BuildID, inspect Steamworks Builds before retrying; do not assume no upload occurred.
After upload, configure DWM.exe as the Windows launch executable, include depot
5199121 in the testing package, select the build for a protected test branch,
and test installation and Save/Load through Steam with fresh saves.

## Evidence and pending execution

Old upload run 39866148728 failed with an unclassified SteamCMD error before a
successful preview or upload was reported. Secrets were present and Base64 parsing
passed, but the old log does not establish the failing SteamCMD stage or valid login.
The revised workflow adds stage/exit diagnostics; it does not claim an authentication fix.
YAML, embedded Python, the audit patch against the exact-source helper, fixed-source
selection, export-before-upload dependency and no SetLive were checked locally.
A new cloud run is required to verify Windows export and Steam authentication/upload.
The GitHub connector does not expose new-run dispatch; use Run workflow in GitHub.

References:
- https://partner.steamgames.com/doc/sdk/uploading
- https://game.ci/docs/github/deployment/steam/

## Verified export and upload retry — 2026-10-23

Run 39867537354 passed the localized Windows export, package audit, isolated
startup, license checks and staged-file integrity. Clean package artifact:
https://github.com/Siuuuers/dwm/actions/runs/39867537354/artifacts/12465201065
Receipt artifact: 12465265774. Runtime source remains cc40aee5722afaa24e8a8daa556e8c27bc956810.
PCK SHA256: cb2f1410546563ad39563decb2ec8f383e959f327062992670b4a2e33bf9cb15.

SteamCMD failed during unauthenticated bootstrap with exit 7 after printing
Update complete, launching. No login, preview or upload was attempted in that run.
The workflow now retries that specific bootstrap result once and requires the
second invocation to pass normal exit/error checks; authenticated commands are
never retried automatically. Five mocked success/failure cases passed locally.
A cloud retry is still required; this is not evidence of working Steam authentication.

For the next NEW Run workflow, select master and upload, leaving rebuild off.
The default reuses package and receipt from run 39867537354, validates all hashes,
and skips Godot export. Select rebuild only if that artifact has expired or a
fresh export of the same pinned source is needed. Failed exports still block upload.
The artifact expires 2026-10-30 at approximately 06:50 Hong Kong time.

## Confirmed Steam upload — 2026-10-23 06:56 Hong Kong time

Run https://github.com/Siuuuers/dwm/actions/runs/39868383769 succeeded.
Steam job 120136280417 verified the existing package hashes, passed SteamPipe
preview and reported Uploaded BuildID: 26146382. No Steam branch was set live.
AppID 5199120; DepotID 5199121; runtime source
cc40aee5722afaa24e8a8daa556e8c27bc956810.
This reused the verified export from run 39867537354; no new game export was needed.

The prior bootstrap/authentication/upload pending status above is historical.
Authentication and upload are now confirmed. Still pending: select this BuildID
on a protected Steam test branch, verify the Windows launch option DWM.exe and
testing-package depot access, then install through Steam and check language,
art/music and Save/Load with fresh saves. No Steam installation, graphical
whole-game acceptance, public release or Valve review approval is claimed.
