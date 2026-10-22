# Windows playable template build

Launch game-build/DWM.exe with DWM.pck beside it. Keep licenses/.
This branch contains only the validated Windows x64 build and its receipt.
Runtime source: 82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc.
Export evidence: https://github.com/Siuuuers/dwm/actions/runs/39825608353

This is a playable template, not a Steam-approved final-content build.
Replace art, music, and Day1-Day7 scripts in source branch codex/art-media-20261023,
then re-export. Loose source assets beside the EXE do not override its PCK.
Upload the contents of game-build as the Steam Windows depot content.
Configure DWM.exe as the launch executable. Steam AppID and DepotID are account-specific.
Steam API integration is optional; no SDK directory belongs in this build.
Do not merge this binary delivery branch into the source branches.
