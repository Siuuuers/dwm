# Official Windows delivery candidate — prepared, not executed

20 October 2026. Replacement Coordinator A follows [Director6293127731](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6293127731). The observable outcome is ordinary exported completion → Title → separate-process Load of the actual completed autosave → Title → clean exit, with no duplicate Profile/Gallery effects. Product lifecycle, SaveManager, and existing continuation journal remain authoritative; only the external harness is extended.

## Pins and review gate

- Product/export source: `c8358870d3ece92d5f8cc7ba65aefe34a746be5c` (PR36). No runtime changes.
- Driver source: `8adc8c78fcbf25fa0df030391bac6f1d64073a01`, this directory's `Invoke-ExportedGameplay.proposed.ps1`.
- Driver SHA256: `7a4bcd31aa4f340e76e0aee34c5857565d672ed38b3c66275fab525ea40ac21c`.
- Exact proposed controller SHA256: `320fdfa49b652c43dfdc18c153782745b3a398a168c726bf75e972dcd3476d06`, `controller.proposed.yml`.
- Active PR30 controller remains `9f7fe38ad6255b8b094d96024e77750f074c13f4`. Do not push an incidental change that reruns the completed deadline fixture. After external C clears this exact preparation, A replaces its workflow with the proposed controller in one protected update; that PR event is the one selected attempt. No extra dispatch/retry.
- Official Godot 4.6.3 standard editor SHA256 `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90`; templates `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`.

External C source review precedes execution; internal helper review is not C acceptance. If the run fails, retain the first boundary and stop. If it passes, C reviews original results before integration or delivery acceptance. Draft/unmerged; no master/integration/release change. No performance improvement is asserted. Historical diagnostic 33.179067s is not a current official-build measurement.

## Correct terminal source and expected behavior

The selected physical source is `appdata/Godot/app_userdata/DWM/saves/autosave.json` under the creator's isolated UserRoot, produced by the preceding normal Day4 Load → ending completion. It must already contain `COMPLETED/GALLERY_RECORDED`; the completed phase hashes it after clean shutdown. Slot1 is the older Day4 checkpoint and Slot2 is the restoration witness. Neither is silently treated as completed or overwritten.

`BackupPresentationPort.LOCATORS` exposes autosave. `RunSnapshotSchema.is_scene_terminal` admits COMPLETED. `GameState.request_next_ending_command` returns `return_completed`; `complete_ending_playback_stage` takes the completed-return branch without new playback receipts, checkpoint writer or Gallery award. `EndingScene.resume_ending` routes to Title. Thus completed autosave Load returns automatically to Title, whereas an old ENDING manual slot would replay its remaining ending. Existing older-slot coverage is not substituted for this test.

Title alone could falsely pass because it already existed before Load. The new phase also verifies one new normal-product `scene_restore` operation in `saves/desktop-continuation-operations.json`, completed and activation-acknowledged, selecting autosave's exact checkpoint and canonical full document. Prior operations must remain unchanged. This is read-only observation of genuine product output, not seeded saves or injected game commands.

## Phase and acceptance map

| Phase | Action and success evidence | Prerequisite |
| --- | --- | --- |
| Package | Exact product import, unchanged export/package audit and isolated startup; retain official hashes, EXE/PCK/archive receipts | Exact source and parser |
| Capability | Existing ordinary UI capability probe, separate empty profile, clean exit | Package success |
| Create | Existing normal New Game → Day4, Slot1 Save, clean exit | Capability receipt |
| Load | Existing distinct-process Day4 Load and Slot2 witness; existing full state checks; remaining week → ending → Title, durable completed autosave and Gallery receipt, clean exit | Create receipt and exact saved hashes |
| TerminalLoad | New process, same profile, exact completed autosave via normal Title Log in/Autosave/Load; no drawer remains, Title observed, exact new acknowledged restore operation; unchanged autosave, Profile/Gallery and both manual slots; normal shutdown/exit0 | Successful Load receipt plus original Create receipt |

All phases bind package, source, driver hash, renderer/audio/accessibility settings and deadlines. Step30s/journey480s are unchanged. Each mode is a fresh pwsh and native process. Project renderer, accessibility Always, audio Dummy remain explicit scope limits. Screenshots still require visual review. Load witness and creator journey bodies and the accepted Wait-One function are byte-identical to product.

The external reviewed driver runs outside the product checkout with the unchanged adjacent Probe-ExportedWindow helper. No instrumentation overlay or engine rebuild. The workflow reuses the existing exporter and official download/hash/cache steps. Later phases use default success gating and are marked unexecuted after prerequisite failure. Separate phase receipts retain process identity, actual exit, forced cleanup, commands, logs, screenshots and manifests. Failure capture now includes the continuation journal under the existing bounded read-only capture policy; capture failures remain explicit.

## Failure boundaries

- Failed import, parser, export or capability: no creator or later journey.
- Failed creator or Day4 restore: no completed-state claim and no terminal phase.
- Ending timeout/crash or non-COMPLETED autosave: retain bytes, process exit and cleanup state; do not extend waits.
- Changed prerequisite package/profile/save/driver: refuse before launch.
- Wrong selected source, fallback, missing acknowledged operation, duplicate award, mutated manual slot or nonzero/forced exit: fail terminal qualification.
- UIA/provider error retains its actual evidence; do not automatically label it a product defect or restore success.

## Validation performed in this preparation

Local source inspection, Python YAML parsing, four-phase census, byte comparisons of retained journey bodies and Wait-One, exact hashes, and an independent read-only terminal-contract/driver review. That review identified the need to retain failed restore-journal bytes; the one-line capture addition is included. No Godot, PowerShell parser or PowerShell execution occurred locally or in cloud for this candidate. No result pass is claimed. The accepted two-parser/four-fake-provider deadline result remains closed and is not rerun.

`preparation.json` records source blobs, hashes and static checks; `driver.patch` is the complete external-driver delta. Existing restart/inventory files are updated only on this isolated candidate. Master inspection found `41592fcc792aa615e47ee2ce2f05008ca195b311` (narrative consolidation); the retained reconciliation found no relevant delivery implementation to import.
