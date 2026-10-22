# Seven-file playable template handoff

The requested playable-template milestone is complete: seven active Day1.dtl through Day7.dtl files, with the ending label inside Day7. Finished story/art and performance polish remain future work.

## Accepted source and evidence

- Rendered journey: https://github.com/Siuuuers/dwm/actions/runs/39817290512 — 5 tests, 419 assertions. Three template tests (83), New Game through Day4 Save (102), and fresh-process Day4 Load / witness Save / Back / Days5–7 / ending / durable completion / Title / fresh New Game (234). Saved slots and history preserved.
- Authored source: 606cf0b5a1b90a590babe16682d7a45afc58b568. Exact cloud-generated registration and metadata published at d5eb03ef2d72c5b7cad4265bc83d0d4a969c3e29.
- Final export source: fa8cf991fcf57d5657c789de522a95e3bb1450bd. Adds only 11 exact native-generated DTL UID sidecars; independent review approved no repeated rendered qualification.
- Windows export: https://github.com/Siuuuers/dwm/actions/runs/39819038999 — PASS. Release package, 122-file runtime-data audit, exact seven DTL resources plus order JSON, isolated headless startup and unchanged-source check.
- Build: https://github.com/Siuuuers/dwm/actions/runs/39819038999/artifacts/12442519330 (Actions expiry 2026-10-29).
- Final controller: 4af9a28d157921f38a1c1527ea8374252af947c3 on PR30. Actual event workflow verified text-exact.

Accepted and original failure evidence lives under evidence/phase_2r/seven_files_20261023/. Do not repeat completed qualification. No active focused run remains.

## Corrections and compatibility

The first split incorrectly used day content_version 2 while Run9/global narrative content version stayed 1. The save validator refused the mismatch. Reverting the introduced bump restored the existing contract; no runtime or save-owner changes were needed. Temporary diagnostics were removed. Changed locators, content hashes and full registration fingerprint still reject older monolithic saves; originals are untouched, with no automatic migration.

First export passed packaging/startup but failed source custody because Godot generated 11 new DTL UID files. Those exact files were committed; the export-only rerun passed the unchanged-source gate. Keep the earlier run labeled failed.

## Next work and scope

Replace template dialogue/art using tests/templates/seven_day/README.md; regenerate registration with the existing cloud path after authoring. A new session is unnecessary for this completed milestone. Further scope should be driven by authored content or a concrete blocker; general latency work remains deferred as requested.

The Windows package has headless startup/package evidence; no exported graphical seven-day journey, accessibility or full-release claim. No merge/release performed. Source branch codex/seven-dtl-playable-20261023 owns code/evidence. PR30 remains workflow-only controller.

Master 41592fcc792aa615e47ee2ce2f05008ca195b311 (rechecked unchanged), PR36 c8358870d3ece92d5f8cc7ba65aefe34a746be5c and integration 3ae6d9138fb53c388380c78550cf6082eafc0ea3 held. Cloud Godot/PowerShell only. Workspace /workspace/scratch/90888f00e1d3.
