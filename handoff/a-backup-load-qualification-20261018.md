# Coordinator A — detached Backup Load qualification, 2026-10-18

## Outcome
The tested Backup lifetime correction is ready for draft integration. Full exported journey acceptance remains blocked by loss of the native accessibility tree after the restored game's witness Save. Do not call the ending, saved-state equivalence, or clean loader exit passed.

## Minimal change and ownership
- Runtime candidate: bb167aa1b5692f6bf5ceb6789201f38d4f86360a, parent dac2d3e6fd3fb0308b0d289b3b5519507a062521.
- BackupApp._commit_pending now checks whether its view has left the tree immediately after retaining the commit result and clearing the operation flag, before either failure or success presentation.
- Scene activation can return scene_activation_pending after removing Title. Previously that failure rebuilt outgoing actions and focused Cancel while the pressed Load signal was unwinding. The existing lifetime guard covered only success.
- SaveManager, SceneRouter, persistence schemas, history, and recovery custody are unchanged. Attached failures retain Retry/Cancel. Pending remains pending.
- Two focused tests use the real Backup scene/button and a fake port that detaches the host during commit; the second keeps the host attached and verifies recovery actions/focus.
- Independent review caught and rejected an earlier unpublished misplaced guard (9f9b174). It is not an ancestor of the accepted candidate. Corrected bb167aa passed source review.
- External driver candidate: b30ab2c09ca3d67ec11bff294b183f93337f5035. Visible rejects and records non-Rect bounds and rejects non-finite rectangles during bounded discovery. Actual evidence records null bounds during scene replacement. PID, ancestry, uniqueness, package pins, timeouts, and action checks remain intact. Independent driver review passed.

## Cloud evidence
| Run / job | Evidence |
| --- | --- |
| 39103297607 / 117603807372 | Original exact export and driver3c57: Capability/Create clean exits0, fresh Load repeats native 0xC0000005 before cleanup. WER per-executable LocalDumps and installed CDB were available, but no dump or Application event was captured. No native stack is claimed. |
| 39103588380 / 117604671730 | Corrected runtime: six focused tests, 3,432 assertions, strict logs and exit0. Existing export validator passes 117 runtime resources and isolated startup. Capability/Create pass. Fresh Load remains alive and the failure capture visibly shows restored Day4 closing; driver fails on unavailable BoundingRectangle.IsEmpty, then deliberately cleans up the still-live child. |
| 39104031600 / 117605976589 | Same exact guarded export, corrected driver b30ab2c. Capability/Create clean exits0. Load observes Day4 closing, opens ordinary Backup, selects empty slot2, invokes scoped Save, and Wait-File reads the resulting document. Then Saved-status UIA polling times out. Failure capture visibly shows Saved and occupied slot2, but native descendants are empty. Child is still alive before forced cleanup; exit-1 is cleanup, not the original access violation. |

The corrected runtime passed the previously crashing boundary in both subsequent runs. This supports the lifetime correction, but without a native stack does not prove a unique engine-level cause.

## Exact exported package
Built once by the existing Invoke-WindowsExportValidation.ps1 in run39103588380; reused unchanged in run39104031600.
- Source: bb167aa1b5692f6bf5ceb6789201f38d4f86360a.
- Artifact: exported-backup-package-39103588380-1, ID12127144275, seven-day retention.
- ZIP SHA256: 625fad0d7ab746c6413192f82db6b461e9db05f40634772e0b1e387dcdb017bf.
- EXE SHA256: 91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6.
- PCK SHA256: e6fe5dab1eb7588704c24ae5d7eb231f7e475dff62cb663b637cbd5ea1baa22d.
- Godot4.6.3 standard, accessibility Always, audio Dummy, ProjectDefault D3D12 Forward+ / Microsoft Basic Render Driver.
- No source runtime, script override, direct port invocation, profile seeding, or alternate export pipeline.

Three original evidence ZIPs and qualification-verification.json under evidence/phase_2r/exported_gameplay_20261018/ preserve these outcomes. Verification checks outer member sizes/hashes, inner driver manifests, successful process exits, retained runtime/test/driver blobs, and the six-test census. Earlier failures remain unchanged.

## Next bounded investigation
Determine why the native UIA descendants disappear after witness Save while the rendered window still shows Saved. Distinguish an unresponsive provider, an accessibility lifecycle transition, and stale native root state using process-bound diagnostics. Do not replace native Saved/Back observations with file existence, bypass PID/uniqueness checks, or extend timeouts to manufacture success.

The witness document was read by Wait-File, but the driver failed before returning it from Save-Slot; its full saved-state comparison and profile comparison were not reached, and that witness file is not retained in this failure bundle. Add read-only failure evidence capture of the relevant existing save/profile before repeating this boundary. Source slot mutation check, ending/gallery award, and normal loader shutdown also remain unproven.

The Backup Back/Check Computer visual overlap remains. Prior broad integration run39090268581 remains failed with historical context-fixture work outstanding; this slice does not repair those tests or establish historical save compatibility. PR30 is workflow-only; PR36 remains draft. No master update, merge, or release.
