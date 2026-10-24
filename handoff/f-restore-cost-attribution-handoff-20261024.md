# Restore cost attribution and the next measured target

Continues [restore preparation](e-restore-preparation-proof-handoff-20261024.md). All Godot and PowerShell execution was cloud-only. Local work was static source review, Git and evidence verification. This batch changes no production runtime and claims no performance improvement.

## What was established

The observable goal was to identify which remaining validations run during a real fresh-process Load, and where the synchronous restore transaction spends its time. SaveManager owns transaction orchestration; the existing native helper owns Load-press and Ready observations. Diagnostic stack metadata and phase markers add no validation, hashing or storage operations.

The caller-only [run 40070845864](https://github.com/Siuuuers/dwm/actions/runs/40070845864), source `e421fb585ef655bd5a913c723731e4b724576cbf`, passed the native journey. Eight full snapshot validations all fell between Load press and Ready. Their disjoint intervals totalled 32.923014 seconds of the 84.867476-second wait (38.79%). They were production work triggered by the UI click, not later test verification.

| Caller | Seconds in caller-only run |
| --- | ---: |
| SaveMigrations source admission | 4.052045 |
| RunSnapshotSchema.derive_route_restore_context | 3.959299 |
| NarrativeRestoreParticipant.prepare | 4.030820 |
| Continuation journal prepare_intent | 3.922247 |
| Continuation journal commit_intent | 3.954287 |
| Identity allocation through load_restore_context | 4.097447 |
| GameState.apply_restore_silent | 4.378249 |
| CheckpointJournal.commit_prepared | 4.528620 |

The route-context helper was missing from the earlier static caller map. The stacks correct that omission. They do not establish that any of these checks is safely removable.

The second [run 40071569303](https://github.com/Siuuuers/dwm/actions/runs/40071569303), source `3adfc26238ba13cfa005d925fd9189aa71d83765`, adds exclusive phase markers to the scene branch of SaveManager's existing transaction profile. Its native journey and phase-sum assertion passed. The synchronous transaction took 52.152770 seconds; Load press to Ready took 100.056530 seconds. A normal `scene_activation_pending` return ends this synchronous profile; subsequent asynchronous activation remains outside it.

Ten continuation-progress intervals—eight participant advances, the applied-stage transition and completion—dominate this transaction. They each took approximately 4.1 seconds, together 41.495799 seconds (79.57% of the synchronous transaction). Run application and checkpoint-journal installation each took about five seconds. Exact values and independent calculations are in the retained phase review. Phase intervals are exclusive within the transaction; nested snapshot durations must not be added to them.

Do not compare absolute times between these two instrumented runs as evidence of regression or improvement. Runner conditions differ and caller collection adds enclosing-operation overhead. Neither run is a matched product benchmark or latency distribution.

## Why the extra route validation remains

The user specifically asked whether the extra full validation can be removed. The current answer is: not safely with the existing first-participant admission guard.

Between initial admission and route-context derivation, built-in preparation can invoke configurable window output, registered localization roots and an audio playback port. Those callbacks can change physical Profile content, issuer state, registrations or owners while leaving the snapshot and owner object identities unchanged. Snapshot equality and exact participant scripts therefore do not establish continued validity.

RunRestoreParticipant's plan is a detached copy of the original input, not the normalized candidate returned by validation. The route helper projects from that normalized candidate, including terminal ending context. Moving projection earlier or using the run plan would also change the existing post-callback refusal boundary.

A future bypass needs tests for identical detached scene/terminal contexts and integral-number normalization, plus refusal when window/localization/audio callbacks change physical Profile, same-object issuer state or registration. Changed snapshots, custom participants and absent/mismatched admission material must retain full validation. Merely extracting a pure projection helper while still validating saves no proof, so no such refactor was made.

Intent preparation likewise does not discharge all commit checks: commit additionally validates issuer-receipt details, SHA-256 form and operation stage relationships. Cold journal loading may reconcile storage and invoke owners between the two calls. Preserve retry and recovery behavior; do not blanket-skip commit validation.

## Next task and acceptance

Prioritize the measured continuation-journal progress cost. Start with one observable outcome: recording the same ordered durable restore progress takes less time while preserving exact recovery state, retry behavior and player Ready state. DesktopContinuationOperationJournal owns legal progress and serialization; JsonFileStorage owns atomic durability.

Instrument one level deeper on the same diagnostic branch: split advance transition/copy/equality work, document serialization, proof-cache bookkeeping and atomic storage. Inspect existing operation-text and exact-text caches first; they already avoid some repeated work. A four-second progress interval does not prove that physical disk writes are the cause. Preserve every durable boundary until evidence and interruption/retry tests justify a specific change. Do not batch away progress records merely to reduce write count.

After selecting one minimal change, use focused owner tests and integration fault/retry checks, then a matched cloud native Save/fresh-process Load comparison with unchanged state and captures. Run broader required acceptance on the final coherent candidate. Diagnostic code remains on `codex/restore-validation-attribution-20261024`, not master.

A fresh session is useful now: the caller-attribution question is resolved, the route-check removal has a concrete safety answer, and the next task concerns a different owner. No product design question blocks that investigation. Read this handoff and the retained evidence rather than repeating the two completed runs. Historical draft PRs #14, #30 and #50 remain deliberately unmerged.

## Evidence

Each run passes two native cases / 213 assertions across three successful processes. Each archive also contains one historical input case / 112 assertions; those are excluded from current passing coverage. No full product CI suite was run for this diagnostic-only batch.

[results.json](../evidence/phase_2r/restore_attribution_20261024/results.json) identifies sources, counts and the archive checksum. [exact-evidence.zip](../evidence/phase_2r/restore_attribution_20261024/exact-evidence.zip) retains selected exact reports, logs, source patches, independent reviews and native captures, with a manifest recording every original member and omission. Both original artifact ZIPs were size/hash/CRC verified. Original distribution containers and historical fixture contents are not duplicated.
