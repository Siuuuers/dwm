# Initial scene creation — bounded cloud evidence, 9 October 2026

Final source **109309cc0770760ee53c15389659430dbb767a9b**, tree **b66fb81a6b91bdeea6add418d8ce0c8247634ff0**.
Ancestry: preserved 6f42a504 -> implementation 0b7865dbd8e4d914b7b6c7d1b4e6a8f09fe01166 (tree e8cbf88cc55cd1901ad037e254bd624e10a63494) -> test-name correction 3076d1d156d677b2f21970bdfc315b85a21c3081 -> final four-path correction 109309cc.
Final controller **71ca9bad225addf58d365777301da534289d337a**, tree **b124374e16437d3cc2568747590020a947018b4a**; PR30 remains workflow-only relative to product.
PR27 remains draft/unmerged. PR14 remains b37d662403398139fc2b1029853b236c334f59a0. Master checked at 44dda79440392d14c95ea6ce4e94d579094f76e5; no related runtime work imported. No merge/release/protected-ref changes.

## Retained passing lanes

| Run | Job | Source | Suite | Cases | Log assertions | XML assertions |
|---|---|---|---|---:|---:|---:|
|37916848337|113775021260|0b7865db|initialcontract|4|72|71|
|37916848337|113775020978|0b7865db|initialcandidate|4|84|83|
|37916848337|113775021267|0b7865db|initialfrozen|3|39|38|
|37916848337|113775021164|0b7865db|initialjournal|6|96|96|
|37917370070|113776739757|109309cc|initialjoint|1|47|46|

Retained **18 cases / 338 log assertions / 334 XML testcase assertions**, zero failures, errors, skips or script errors. No cross-checkpoint whole-game total is claimed. Four passing lanes were not repeated: later changes only SaveManager initial entropy, physical Profile proof readiness, and the two joint-test paths; their candidate/contract/Frozen/journal bodies remain unchanged.

## Failed originals and corrections

- Run37916848337 initialjoint/job113775021422: script parse failure because test variable ready conflicts with Node.ready. Zero executed cases; strictly rejected despite empty XML. One test-only rename at3076d1d.
- Run37917082232 initialjoint/job113775803912: one failed testcase,32/33 log assertions and32 XML assertions. First actual joint creation/ack/ordinary Save9 validation succeeded; second creation correctly refused the fixture passing another nonce. The test now supplies null for alternating creation.
- Final109309cc also supplies first-run entropy from four Crypto bytes when no controlled nonce is provided, freezing it before durable intent, and allows physical assignment proof before in-memory Profile initialization. The final test exercises default first entropy, opposite second assignment, and a storage-bound but uninitialized Profile reader. Wrong physical assignment is refused.
- Controllers f19bb4a45a0231aac856c08fcdb8b67b21e4137a and0d3672196409f9de456081c1c8f2d3e567463d89 and all original failed archives remain preserved.

## What this proves

Schema3 initial admission binds the existing creation transaction, exact allocator candidate, G assignment, installed registration and registered initial target without a fictional prior checkpoint. Dedicated candidate APIs validate complete pristine Run9/Save9 and reconstruct the actual compiled first-caption reading/frame. Ordinary committed validation requires the actual completed+acknowledged creation, matching root allocation and physical retained Profile assignment.

Journal5 scene_new_run retains identity→Autosave→Profile targets and eight participants; pending completion is discoverable and acknowledged explicitly. Legacy journal/schema2 receipt bytes and child preimages remain separate. The journal validates creation records before resolving initial authority for retained scene sources, avoiding recursive cold-load trust.

Joint test uses real FileOps, issuer/root store, Profile and its restore participant, GameState/run participant, SaveManager, actual compiled Bridge initial checkpoint and actual NarrativeRestoreParticipant preparation. It writes and rereads physical Autosave/Profile/journal, rejects ordinary Save admission while activation is pending, acknowledges diagnostic activation, validates Save9, creates an opposite second assignment and still validates the first Save after Profile changes.

Route/native apply and activation confirmations, board, localization and audio are deliberately diagnostic participants. Six journal state-machine tests explicitly inject candidate admission; Frozen tests prove structural derivation only. Neither these cases nor passing counts establish rendered or cold-process recovery acceptance.

## Next connected work and limits

Production scene host/content stays unconfigured; no production target or form-to-target mapping invented. Actual fresh-process SaveManager Load, interruption/retry matrix, mounted native activation, retained selected absence, forward Challenge/Contact execution, desktop cutover and final retirement/inventories/canonical gates remain.

Next connected fixture should run two Godot processes under one existing isolated wrapper root: writer genuine NewRun and actual mounted route/native acknowledgement, reader reconstructs owners from the same real files and calls public prepare_restore_autosave then commit_prepared_restore. Existing wrapper invocations each allocate a new GUID root, and TemporaryStorage adds process ID; ordinary separate invocations cannot silently claim shared storage. Require distinct PIDs, exact phase-one file hashes, actual DesktopIdentityAllocationRestoreParticipant, and canonical GameState/Bridge singleton replacement. Preserve all nonzero XML/script-error/clean-source gates.

C owns scripts/ui/ComputerDesktop.gd and scripts/domain/desktop/DesktopAppRegistry.gd in its separate lane; neither changed here. A remains the sole shared integration/controller writer.

## Original integrity

All seven downloaded ZIP SHA256 digests match GitHub metadata. Every one of **61** original manifest members was independently rehashed locally; size and SHA256 agree. Verification includes source and pinned engine receipts. Godot standard4.6.3 archive e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90; console63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a.
All Godot/PowerShell runs occurred in GitHub Actions. Original ZIP bytes and verification.json are alongside this README. No engine rerun was used for artifact access.
