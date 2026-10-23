# Steam cloud export and upload

Workflow: [Steam private upload](https://github.com/Siuuuers/dwm/actions/workflows/steam-upload.yml).

## Selected source

The owner authorized the newer integrated build despite unfinished UI functions.
Selected source: e5cf80a5417c05bd0bb7fa2f60f59e8905e839a6 from PR #52.
It includes the localized authored week, later scene Apps and Save/Load work,
current paintings and Bach Title/story music. Panel, six-reading-control and
caption-layout discrepancies remain; this selection does not fix them.
The workflow always exports this exact source anew. It cannot reuse the old
cc40aee package or the previous binary delivery branch.
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

## Historical: old-source export and upload retry — 2026-10-23

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

At that historical checkpoint, the workflow reused run 39867537354 with rebuild
off. That option has now been removed: the current workflow always builds the
new selected source and downloads artifacts only from its own run.
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

## Integrated replacement prepared — 2026-10-24 Hong Kong time

Source e5cf80a5417c05bd0bb7fa2f60f59e8905e839a6 is pinned in checkout and both
receipt checks. A successful build job is mandatory before Steam preview/upload;
there is no skipped-build or old-run artifact fallback. Existing authentication,
file-hash, license and package checks remain. YAML, embedded Python, source pin,
artifact selection, success gate and audit-patch anchors were checked locally.
New cloud export/upload is pending. No replacement BuildID has been reported.

Start a NEW Run workflow on master with mode upload. There is no rebuild input.
The GitHub connector has no workflow-dispatch operation, so the owner must click
Run workflow. This uploads a build without setting any Steam branch live.
