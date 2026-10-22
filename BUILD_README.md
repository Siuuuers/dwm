# Authored seven-day Windows development build

Launch game-build/DWM.exe with DWM.pck beside it. Keep licenses/.
Runtime source: 2146c4435041c2b4ccc467a526f7b127d3980a2f.
Source branch: codex/seven-day-story-20261023 (draft PR #43).
Export evidence: https://github.com/Siuuuers/dwm/actions/runs/39843283227
Export artifact: https://github.com/Siuuuers/dwm/actions/runs/39843283227/artifacts/12454556049
Validated input ZIP SHA256: b766618089b74b65bfc25475287ae2b7873da38d07e51f6a7a78c437d88bec5c.

This unsigned Windows x64 development build contains the authored Day1–Day7
adaptation. Export evidence covers package-data integrity and isolated
headless startup. It is not Steam approval, an installed Steam test, or
whole-game graphical acceptance. See the source PR for scoped test evidence
and remaining limitations. No public release or source merge is performed.

Edit story source in dialogic/timelines/authored_week/Day1.dtl through
Day7.dtl via its authoring pipeline, regenerate registration, then re-export.
Loose source assets beside the executable do not override the PCK.
This content revision requires fresh test saves; older saves are retained,
and no automatic migration is claimed.

Upload only DWM.exe, DWM.pck, and licenses/** as Steam depot content.
Configure DWM.exe as the launch executable. Steam AppID and DepotID are
account-specific. Steam API integration is optional; no SDK belongs here.

game-build/STEAM_BUILD_REVIEW.md is retained from the preceding template
build as a checklist; its recorded source hashes, paths, and earlier
qualification describe that historical build. This README and the adjacent
package-receipt.json identify the current package.
Do not merge this binary delivery branch into source branches.
