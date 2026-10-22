# Steam build review checklist and next-session handoff

Updated: 2026-10-23 (Hong Kong). Scope: game build and upload only.

This checklist prepares a submission; only Valve can approve it. The current executable is a playable template with placeholder content, not a near-final release submission.

## Current delivery and evidence

- Build branch: `builds/windows-playable-20261023`. Do not merge this binary-delivery branch into source.
- Runtime source: `82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc`.
- Source branch: `codex/art-media-20261023`; last observed source/docs head `5eee8406f4c2c466ac05d03c489c7cdd1cbc1164`.
- [Windows export and isolated headless startup passed](https://github.com/Siuuuers/dwm/actions/runs/39825608353).
- [Gallery and connected Day4-to-ending source tests passed](https://github.com/Siuuuers/dwm/actions/runs/39824610874).
- [Build publication and byte-integrity checks passed](https://github.com/Siuuuers/dwm/actions/runs/39828804324).
- The full graphical exported game has not yet been qualified through a Steam installation.
- Existing package-receipt.json describes the 17 runtime/license files. This new Markdown guide is administrative documentation, outside that runtime receipt.
- EXE SHA256: `91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6`.
- PCK SHA256: `6e33144ce59585ed1d50320bf695bc7c7411ae388f1fc53e4b501390a864cdb5`.

## Prepare the actual release content

- [ ] Replace temporary Day1–Day7 dialogue, paintings, and music with the intended release content.
- [ ] Use source paths: `tests/fixtures/dialogic/Day1.dtl` through `Day7.dtl`, `art/pictures/picture1.jpg` through `picture5.jpg`, `audio/bgm/menu_theme.ogg`, and `audio/bgm/story_theme.ogg`.
- [ ] Follow source guide `art/pictures/README.md`: import changed assets, regenerate registration using `tools/authoring/ExportSevenDayRegistration.gd`, validate affected content, then export.
- [ ] Keep the paired EXE/PCK and license notices together. Loose replacement art or DTL files beside the EXE do not override the packed game.
- [ ] Preserve save/recovery/history behavior. Current unshipped content-fingerprint changes require fresh test saves; do not claim a migration exists.
- [ ] Ensure every claimed supported feature and operating system works in the submitted build. Current deliverable is Windows x64 only.

Steam's product-build review requires proper launch on supported operating systems and implementation of listed features. Submit a near-final build. If in-game purchases are introduced, Steam's review rules require Steam Wallet for those transactions. Internal art formats are governed by our engine/import pipeline, rather than the store-capsule image specifications.

## Steam SDK and upload setup

The SDK's SteamPipe tools upload the build. Integrating the Steamworks API into the game is optional. Do not add GodotSteam, achievements, or other new functionality solely to enable basic distribution.

- [ ] Obtain the actual Steam AppID and content DepotID, and an authorized upload account. Never commit passwords, Steam Guard codes, or login/session files.
- [ ] Download the SDK on the authorized upload machine/runner; use `tools/ContentBuilder` or the supplied SteamPipe GUI.
- [ ] Configure an installation directory and launch option pointing to `DWM.exe` at the depot root.
- [ ] Configure the depot and ensure the testing package grants access to it; publish the installation/depot configuration.
- [ ] Prepare app-build/depot VDF files using the real IDs. Map the contents of this folder to the depot root.
- [ ] Upload only `DWM.exe`, `DWM.pck`, and `licenses/**`. Exclude this Markdown guide and repository/CI files from the depot.
- [ ] Do not ship the whole SDK or development-only `steam_appid.txt`. If Steam API integration is later added, include its correct platform runtime DLL and verify initialization.
- [ ] Upload to a private test branch. Set its password before making a build live there. Do not make the release/default branch live as part of a test upload.
- [ ] Record Steam BuildID, source SHA, depot manifest, and test result together.

## Minimum final check

Reuse completed source qualification. Do not rerun unchanged tests for documentation or packaging-only edits.

On the final candidate, perform one connected graphical smoke journey from a clean Steam installation: launch from Steam, start Day1, verify both art panels and music, progress through all seven days to the ending, save at a representative intermediate point, quit/relaunch and load, check history and Gallery unlocks/fullscreen/H/Esc, then return to Title and quit. Check that the installation is self-contained and saves remain available after relaunch. This is our risk-based recommendation, not a Valve-mandated test script.

Fix launch failures, blocked progression, missing required content, and save/recovery defects before submission. Repeat only affected checks. If source changes invalidate earlier qualification, run the relevant focused integration checks.

- [ ] Complete that installed-build check and record any limitations.
- [ ] Submit the near-final product build for Valve review through Steamworks. Uploading alone does not request review or constitute approval.
- [ ] Address review feedback. Valve currently says review typically takes 3–5 business days and recommends allowing at least 7.

## Source PRs: remaining work

As observed on 2026-10-23: 28 open PRs, all drafts. These are stacked implementation/integration branches, not 28 unfinished game features. The latest playable source branch has no PR of its own. It is 582 commits ahead of and 62 behind master (`41592fcc792aa615e47ee2ce2f05008ca195b311`). Commit counts alone do not prove conflicts.

1. Compare the latest playable source with current master; preserve master's newer story/documents and identify genuinely conflicting runtime changes.
2. Map existing PR changes to the integrated source by ancestry/diff. Identify superseded PRs; do not merge each old branch blindly.
3. Prepare one coherent source integration candidate and review it. PR #30 is a cloud workflow controller, not the complete product.
4. Run only checks justified by integration changes, plus one final export/install smoke check. Previous scoped test success does not establish that every legacy PR/check is green.
5. Present the concrete merge candidate for approval, merge the approved source PR, and close superseded drafts after confirming their changes are retained. Do not silently close or merge unrelated work.

A Steam private-upload exercise can proceed using the existing build while source reconciliation is pending. A new runtime export is needed after final content or runtime changes.

## Start the next session

> Continue Siuuuers/dwm Steam build preparation. Read game-build/STEAM_BUILD_REVIEW.md on builds/windows-playable-20261023. Use the existing validated Windows build for a private Steam installation test. Keep Godot/PowerShell verification cloud-only and reuse completed evidence. Start with SteamPipe configuration; Steam API integration is optional. Obtain the real AppID/DepotID and authorized upload access before uploading; never invent IDs or put credentials in GitHub. Do not publish a public release or merge/close PRs without approval. Keep source reconciliation distinct from the build-only branch.

## Official references

- [Product-build review](https://partner.steamgames.com/doc/store/review_process)
- [SteamPipe upload and depot configuration](https://partner.steamgames.com/doc/sdk/uploading)
- [Steamworks API: optional integration and runtime distribution](https://partner.steamgames.com/doc/sdk/api)
- [Builds and beta branches](https://partner.steamgames.com/doc/store/application/builds)
