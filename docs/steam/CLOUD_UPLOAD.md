# Steam cloud export and upload

## Current verified build — 28 October 2026

Steam BuildID: **26265268**. AppID: **5199120**. DepotID: **5199121**.
Runtime source: `5cc02fd261c8c837c70b50f381a79f1894415be4`.
Executable: `game.exe`, with `game.pck`.

[Run 40655556276](https://github.com/Siuuuers/dwm/actions/runs/40655556276)
passed fresh Windows export, isolated executable startup, package hashes,
license/media checks, SteamPipe preview and upload. Steam returned the BuildID
above. This includes merged self-talk and bottom controls (PR #140), Shop
cosmetics (#141), pixel transitions (#142), and save-slot ink (#143).
The final runtime tree passed [run 40653276347](https://github.com/Siuuuers/dwm/actions/runs/40653276347).

No Steam branch was set live. Select BuildID **26265268** on the intended private
test branch and retain the Windows launch option `game.exe` before installing.
Installed-client testing and public release are not established by this upload.

The current implementation batch is complete. Notes and note unlocks, keepsake
ambient sounds, dual-language display, further Contacts/story content, and
production named-checkpoint/overlay authoring remain deferred; see the
[current feature plan](../agent/2026-10-28-current-and-future-feature-plan.md).
Do not interpret the upload as completion of the whole game.

The exact-message trigger on `build/steam-20261028` was used once for this
authorized upload and removed after success. The retained manual workflow now
pins this exact runtime source. Existing repository secrets supplied credentials;
authentication material was not published. Do not rerun merely to obtain BuildID.

## Historical verified build — 27 October 2026

Steam BuildID: **26245899**. AppID: **5199120**. DepotID: **5199121**.
Runtime source: `4db5cff4576be4163b40ff383062a6cd0284042f`.
Executable: `game.exe`, with `game.pck`.

[Run 40521206789](https://github.com/Siuuuers/dwm/actions/runs/40521206789) passed
fresh Windows export, package hashes, license/media checks, isolated executable
startup, SteamPipe preview and upload. It contains the accepted Save/Load and
Quick completion changes from PRs 136 and 137. No Steam branch was set live.
Select this BuildID on the intended test branch before installing it.
Confirm that the Windows launch option is `game.exe`.

The gameplay changes passed 67 cloud jobs on PR 137's final candidate; the selected
source also contains the subsequent documentation updates. The upload separately
validated the freshly exported package. It does not establish installed-client
acceptance or completion of unfinished UI and story authoring.

[Current scoped feature audit](../../handoff/ay-al-status-and-steam-build-20261027.md)
records the status of handoff al. Named checkpoint/overlay machinery exists, but
production story bindings are not yet authored. Further Save/Load optimization is deferred.

The authorized upload used a one-time exact-message trigger on its dedicated
branch. That trigger was removed after success. The retained manual workflow pins
the source above. Do not rerun the successful upload just to obtain its BuildID.
Future uploads need a deliberate source selection; dispatching this pinned workflow
does not automatically build future master.


## Historical verified build — 25 October 2026

Steam BuildID: **26196642**. AppID: **5199120**. DepotID: **5199121**.
Runtime source: `cf60203f077ad0bb39a0d2b06068988153fb53c3` (merged PR #97).
Executable: `game.exe`, with `game.pck`.

[Run 40191013566](https://github.com/Siuuuers/dwm/actions/runs/40191013566)
passed Windows export, package hashes, license/media checks, isolated executable
startup, SteamPipe preview and Steam upload. No branch was set live.
Select this BuildID on the intended Steam test branch before installing it.
Confirm that the Windows launch option is `game.exe`.

The source passed [50 cloud jobs](https://github.com/Siuuuers/dwm/actions/runs/40187985765).
One obsolete timing comparison was intentionally skipped. The upload does not
certify the installed Steam client, unfinished UI or older development data.
Older saves and retained operation journals are not migrated. If startup fails,
retain the diagnostic and data before choosing an archive/reset scope.
Do not silently erase the Profile or claim that reinstalling Steam clears it.

[Current feature inventory](../agent/2026-10-25-current-feature-status.md)
separates missing implementation, open design, unresolved reports and retired
requirements.

The upload used a one-time, exact-message-gated push on the dedicated build
branch because browser workflow dispatch required sign-in. That trigger was
removed after success. The retained workflow is manual-only and pins the source
above. For a later authorized upload, run `Steam private upload` with mode
`upload`; mode `preview` does not upload. Do not rerun this successful upload
merely to retrieve its BuildID.

## Historical procedures and results

The sections below record previous builds and their then-current instructions.
Their source hashes, pending states and launch names do not override the current
verified build above.

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
After the renamed build upload, configure game.exe as the Windows launch executable, include depot
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

## Startup report and executable rename — 2026-10-24

Integrated run https://github.com/Siuuuers/dwm/actions/runs/39990090541 passed
fresh export, headless startup, package checks and upload: BuildID 26165878.
Source remains e5cf80a5417c05bd0bb7fa2f60f59e8905e839a6. The owner subsequently
reported startup failure; its exact error and Windows versus Winlator environment
are not yet known. Headless startup does not establish graphical/client startup.

The owner requested game.exe. The workflow now patches only the disposable export
helper to export game.exe and game.pck together, then runs its existing startup
and pack checks on those final names. Receipt hashes and both staging/upload gates
require the renamed pair. The DWM application/profile directory is unchanged.
Static YAML/Python and helper filename checks pass; cloud execution is pending.
The rename is not yet a confirmed fix for the reported startup failure.

Run a NEW workflow on master with mode upload. After success, select the new
BuildID on the testing branch and update Steamworks General Installation's
Windows executable to game.exe (root relative), saving and publishing the app
configuration changes. Update the client installation before testing.
Do not point the client at game.exe while still using old BuildID 26165878,
which contains DWM.exe/DWM.pck. No Steam branch or configuration was changed here.
