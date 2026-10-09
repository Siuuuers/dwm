# Exact process-interruption recovery — 9 October 2026

Coordinator A continues Director21:07 dispatch5994622489 and D6080676857. The accepted ae82ccd receipt/happy-path restart checkpoint remains unchanged. No production owner code was edited in this batch.

## Observable outcome and owner
An interrupted committed scene Load must resume the same operation, identity allocation and selected document, preserve its historical participant receipt prefix, reconstruct fresh live owners and publish readiness only after actual mount/native acknowledgement. SaveManager and its existing durable continuation journal own this behavior.

The two test modes:
1. prefix: immediate process termination after real route receipt is durable, seven nonnull participant receipts, before narrative/APPLIED; activation_state is still null.
2. completed: immediate termination after COMPLETED/pending is durable and before finalization/mount/native acknowledgement. The live source first enters actual Bridge suspension and pending pause restore.

The test subclasses the real journal only to intercept a successful advance. It independently reopens the physical journal, flushes an exact witness, then calls OS.kill on its own PID. Official pinned Godot4.6.3 platform/windows/os_windows.cpp confirms TerminateProcess(...,0), so the wrapper's existing zero exit contract is unchanged. Zero exit is not acceptance: the runner additionally requires the stop marker/JSON, no completed stop-child XML, sequential distinct PIDs in one isolation root, precise durable stage, and a nonempty clean resume-child XML. A failed assertion guard prevents prior test failure reaching the intentional kill.

## Sources
Product ancestry: ae82ccd951ca4c6797b5ea18dcbfba6035fd60fb →432cf8db15046262c76b830379b4933ee4811a2c (five new test/tool paths) →934b15f21b6ae5310c24944aa869aa9c04bdc63c (two explicit bool annotations and fixture scope comment) →63a70e37a6653b622f12336af0da75d13ad50bd6 (completed-only authentic source suspension).
Final tree: 9820db9429f78a36864b307e4407acc5a31a2bf8.
No edits to SaveManager, Run/Profile/reading schemas, production Bootstrap, C-exclusive UI files, F-owned retirement paths or the already-tested isolation wrapper.

Workflow controller initial bc3ed1a6c75258374591aae75628645f77534f4f/event bef30e8b2f32c22973a67741d7e21cd511956921 share a42042ac169cc3ec2cba91e6d60f4dfa9ba2481b.
Typed-fixture controller9b967e517d105e8282652fe148847ff67bd65b5f/event f7bd2e9b853461ca70730b304ce8937eb976fdff share d02312c4f682463870a69b7cb617e902b508e1e4.
Final controller b736ad3661ed12195d9e56ff2e7aedcc0f9a06ae runs completed only; it is workflow-only relative to final product. Exact source/tree/sole parent/changed path/blob pins, original engine pins, import and error gates, tracked-source check and original artifact manifests retained.

## Successful evidence
Prefix run37939676468/job113850553638 passed: one resume testcase /74 XML assertions. Stop PID4348; resume PID1536. Physical stage participants_applying/index7, activation null. Recovery acknowledges the same operation with retained source/allocation/receipts, old route generation2 preserved in its historical receipt while fresh live route generation1 actually mounts. Issuer root hash and selected Autosave hash unchanged. Actual native frontier/ledger preserved; restored publication is duplicate; no later authored marker or duplicate readiness after retry/reconciliation.

Only completed mode's stop setup changed after this passing source934b15f2; prefix dependencies remain unchanged, so its run is retained without repetition. Prior accepted happy path and tooling lanes were not rerun.

Completed run37940240596/job113852480294 passed: one resume testcase /75 XML assertions. Stop PID6472; resume PID7412. Physical stage COMPLETED/index8/pending, no original activation confirmations; fresh recovery preserves all eight receipts and acknowledges actual mount/native activation once. Same issuer/source hashes and immutable operation material.

Retained aggregate: **2 resume testcases /149 XML assertions** (151 including their GUT setup). Intentionally terminated setup children are not counted as passing testcases. Successful lanes have zero test failures/errors/skips or gated script/import errors. Five original ZIPs and all46 manifest members were rehashed and preserved, including the three failed artifacts.

Final controller/event b736ad3661ed12195d9e56ff2e7aedcc0f9a06ae/e01f3fd142b1db33b01fd6533083ee39a1062d58 share exact workflow blob ac9a1145640efeb74707ec7094804f697688c50b.

## Original failed attempts
- Run37939391271, jobs113849576304(completed)/113849576647(prefix): new fixture failed compilation because two predicates needed explicit bool types. Original stop XMLs each show one failed testcase; they are not accepted execution evidence.
- Run37939676468/job113850554384(completed): actual NewRun and Load preparation succeeded, but the live narrative source was not suspended before Load. It refused before the intended completed hook, followed by rollback diagnostics from ancillary test participants; original stop XML is failed. Corrected only completed-mode setup to use real configure_mutation_gate, begin_suspend, get_state Suspended and begin_pause_restore. No fake frontier and no assertion weakening. Overall run37939676468 failed despite its separately retained passing prefix lane.
The original ZIPs remain unmodified and adjacent to this report.

## Review and boundaries
Independent read-only source review corrected the public scene_activation_pending envelope expectation before execution, verified padded receipt keys/null handling and exact durable interception, and checked the completed-only suspension correction. The transient test-owned pause handle is explicitly scoped; actual native source state is captured and verified by existing Bridge APIs. No production Pause-controller/UI acceptance is claimed.

Actual FileOps, issuer/Profile/GameState/SaveManager, journal, identity participant, router and installed native Dialogic execute. Board/consequence/audio/localization remain inherited diagnostic participants. This proves two specific process-interruption windows in the test-selected mount/native integration; it does not prove physical gameplay effects, arbitrary power-loss semantics, uncertain promoted writes, rendered UX, production startup, all recovery windows or canonical/release readiness.

## Next concrete prerequisite
Director's Profile-output-before-Run-checkpoint and genuine prestart selected-absence/source-overwrite scenarios remain OPEN. DatingPhysicalOwner.configure_scene_challenges requires real GameState methods currently absent: validate_scene_challenge_command, validate_scene_challenge_end, capture_scene_challenge_closure, commit_scene_challenge_checkpoint, commit_scene_challenge_closure. _prepare_scene_absence additionally requires prepare_selected_scene_absence and validate_selected_scene_absence, with the real four-argument Profile absence validator binding. Implement A-owned admitted event/Run authority first; do not fabricate a physical record or positive absence in a test double. SaveManager.capture_committed_scene_restore already supplies the acknowledged retained selected bundle.

Then prove real Slot/Quick/Autosave overwrite, destination-branch Profile-ahead recovery, another save/restart before explicit Start, and no future-state borrowing. Challenge/end and Contact producers, C exact desktop/app integration, A dayless Backup projection/Bootstrap, F deletion fence, rendered/canonical/inventory gates remain. C/F work proceeds on its existing ownership split; no new architecture question or generic prior-evidence audit is needed.

All Godot and PowerShell ran only in GitHub Actions on pinned standard4.6.3. No merge, release, protected-ref, master or PR1 branch movement. Original evidence branch preserves previous85c60c5 content.
