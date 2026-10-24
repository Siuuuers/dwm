# Restore preparation: same-call source proof

Continues [the Save9 and terminal-proof handoff](d-save9-admission-terminal-handoff-20261024.md). All Godot and PowerShell execution remains cloud-only. Local work is static inspection, Git and evidence verification. The game remains unshipped.

## Behavior and owner

SaveManager now avoids one repeated RunSnapshot validation between successful Save9 admission and the first built-in restore participant. Admission already provides a detached validated document. The private `_prepare_run_restore` seam may reuse it only when the participant, GameState and DialogicBridge are the exact built-in implementations, issuer/creation/participant owners match, and type-strict deep equality confirms the unchanged document and its current bundle.

RunRestoreParticipant still owns construction of a deeply detached plan. Both the admitted path and ordinary preparation clear stale scene-creation state; ordinary preparation clears it before validation, including refusal. Custom/subclass participants, absent admission material, mismatched owners and changed inputs retain ordinary validation. Recovery reconstruction has no same-call material and retains its existing path. Later checks after callbacks, durable operations, allocation and application are unchanged. No saved-data field, global proof cache or extra manager was introduced.

The runtime change adds 24 lines and removes two across SaveManager and RunRestoreParticipant. The scope is reduced repeated work, not a claim that shorter source automatically runs faster.

## Source and acceptance

[PR #66](https://github.com/Siuuuers/dwm/pull/66) final head: `5ed4a85ec6e9e24d24111277b3db05405acbe1a2`; tree: `317fc698150559d74b9de92118fbcd7cf2909bb6`.

Merged as `e31b9bf400743ccde44490df07853b3738af7f1b`. Git API verification confirms its tree exactly equals the qualified head. The merge skips redundant CI on the identical accepted tree.

[Full cloud run 40056342262](https://github.com/Siuuuers/dwm/actions/runs/40056342262) passed all 33 jobs, with no skipped or failed jobs. The primary census is 28 reports / 2,833 cases / 155,948 assertions; separate fresh-process checks pass 3 cases / 206 assertions. Intentional storage-refusal children are counted separately: 2 reports / 166 cases / 198 assertions with 160 expected failure nodes, verified by their parent wrapper. These are not primary passing cases.

Three added integration cases establish identical detached plans with one fewer schema validation, reset of stale creation state on success/refusal, generic fallback for absent material/changed input/foreign participant owner, a valid retry after refusal, and custom subclass refusal through public Load. The existing participant-mutation guard and legacy/recovery checks remain. The focused preflight passes 13 cases / 320 assertions: 12 Save9 cases / 250 assertions and one current Quick Load case / 70 assertions.

## Matched native results

Both fresh experiments use the same baseline `97a3e5c2b48c4ae82a30ebb62083c5ea1bff5932`, pinned engine, input and helpers in separate worktrees. Each writes actual Save9 bytes and loads them in another process. A fresh process does not mean an empty Profile; the root has retained creation history. Each experiment passes four native cases / 426 assertions across six successful processes.

The first [baseline-first run 40055223802](https://github.com/Siuuuers/dwm/actions/runs/40055223802) measures diagnostic source `12b259ee0dee26b54c002e5db9460a667cef80e5`. Final source differs only in generated inventories and making its workflow manual-only. The [candidate-first repeat 40056369380](https://github.com/Siuuuers/dwm/actions/runs/40056369380) uses diagnostic source `300a5c4df42c9ec082d9612d67dbeea9f8b6c86b`, whose workflow reverses order without changing runtime.

| Seconds, baseline → candidate | Baseline-first pair | Candidate-first pair |
| --- | ---: | ---: |
| Fresh Load to Ready | 75.620652 → 71.499396 | 104.674825 → 99.740621 |
| Complete fresh Load helper | 78.238035 → 74.060343 | 108.246852 → 103.325146 |
| Complete Save helper | 38.378830 → 47.113134 | 61.543106 → 62.595558 |
| Whole variant | 319.1041107 → 331.463161 | 464.1524374 → 453.1512987 |

Accept this as a bounded Load optimization: fresh Load improves in both execution orders, with the intended one-proof reduction and preserved behavior. The first pair had a substantial Save slowdown and a slower whole sequence, which justified the reverse-order repeat. Save was still slightly slower in that repeat; the whole sequence was faster. Manual Save does not invoke the changed helper and its proof counts are unchanged, but that does not establish the cause of its slower observations. Keep the tradeoff explicit; do not label it noise, claim an overall speedup, or promise zero cost.

Two ordered pairs are not a latency distribution or a statistical guarantee. Absolute times differ materially between runners, so compare within each pair rather than crediting cross-run differences to code. Helper clocks include validation and verification work. Loading remains tens of seconds and is not smooth.

Fresh Load full snapshot validations fall from nine to eight; receipt/physical proofs fall from 47 to 42 and bundle validations from 103 to 92. Save retains ten snapshot checks, 60 receipt/physical proofs and 130 bundle checks. Snapshot, checkpoint, Profile, native saved state and fresh Ready state agree within each pair. The fresh slot files differ only in `saved_time`. Native screenshots retain the same fully revealed courtyard/rain caption and transport controls, with expected Save focus.

The separate full-CI retained-workload benchmark passes two cases / 224 assertions. It measures a prior retained slot rather than a freshly written slot loaded in another process. Its Load-to-Ready is 138.545904 → 136.354837 seconds, complete Load 142.028285 → 139.821016 and Save 64.153991 → 65.238760. It uses GitHub test-merge source `2b5c07bc76a7f66b8c7d228999eb88674211ddca`; both measured runtime files match the qualified head. Do not combine its intervals with the fresh experiments.

## Evidence and next task

[`results.json`](../evidence/phase_2r/restore_preparation_20261024/results.json) records counts, sources and archive hash/size. [`exact-evidence.zip`](../evidence/phase_2r/restore_preparation_20261024/exact-evidence.zip) retains selected exact report/log/proof/capture bytes with an original-member manifest, archive metadata, size/hash/CRC verification, omissions and separate execution groups. It includes the mixed first result. Historical input and intentional refusal reports are not passing primary coverage. Original ZIP containers and export binaries are not duplicated; broader CI screenshots are not all claimed as visually reviewed.

The next task is measurement, not another speculative deletion: attribute remaining full snapshot validations to their caller and transaction phase during this same native journey. The [static caller map](../evidence/phase_2r/restore_preparation_20261024/caller-map.md) distinguishes selected admission, narrative preparation, intent preparation/commit, retained-source loading and journal installation, plus recovery branches. It does not pretend to map historical timing ordinals to those callers.

Use the existing opt-in timing observation, first checking whether compact debug caller stacks are available; otherwise add explicit labels. Add no validation or hashing solely for observation, and do not compare instrumented times as though they were uninstrumented measurements. This should identify whether another substantial duplicate exists within one unchanged synchronous ownership interval.

Profile syntax already has exact-text reuse up to 1 MiB. Physical proof still reads/hashes current bytes, validates detached Profile data and canonicalizes it. Immutable assignment rows do not make the whole Profile immutable. Nested timing categories overlap and must not be summed. No product decision blocks this next audit. Historical draft PRs #14, #30 and #50 remain deliberately unmerged.
