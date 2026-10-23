# Current-save follow-up — 24 October 2026

## Accepted scope

This work implements the current-build-only Backup contract from [the original policy](a-startup-load-handoff-20261024.md). Opening Backup reads basic slot metadata; Load restores the selected current snapshot without searching older checkpoints; Save and Delete do not require the overwritten file to be restorable. The game remains unshipped. Compatibility, repair and old-checkpoint fallback are not product requirements.

PR [#59](https://github.com/Siuuuers/dwm/pull/59) delivered that split. Its accepted source, measurements and exact evidence are in [the preceding handoff](b-current-save-simplification-20261024.md). This continuation removes additional unused work while preserving the active transaction that applies current state.

## PR #60: accepted restore simplification

PR [#60](https://github.com/Siuuuers/dwm/pull/60) merged as `1e1ff7be7ff84a0e57a3ece9f8064ed6cc17e854`. Qualified head `2a5d99e4a7e43eb90adfe0e47a526e6c75e96c28` and merge have identical tree `88d6a43b2967a2aecf3f9167cf3b593e5e82022d`.

Title and Load/Delete confirmations no longer capture unrelated live Save capability. Full in-run listings still project all available actions. Current-scene Load omits source board/consequence plans that were discarded after destination identity allocation; destination plans still own actual application. The continuation journal avoids revalidating the selected bundle immediately after full-document admission. Source hashes, unique checkpoint identity, request fingerprint and mutation checks remain.

A preflight exposed a real legacy validation boundary: its participant preparation still rejects a receipt failure that the older schema path loses when reducing an error to an empty message. Those legacy source checks remain. This is a reason to follow current callers before deleting a component, not a reinstatement of compatibility as a product requirement.

Full cloud run [40016618456](https://github.com/Siuuuers/dwm/actions/runs/40016618456) passed all 31 jobs: 2,824 primary executions / 155,636 case assertions, plus three fresh-process Load cases / 206 assertions. Two intentional storage-refusal children are separate: 166 cases with 160 expected failure elements and six storage-free passes. They are not counted as passing primary coverage. Each native comparison added two cases / 224 assertions; repeated executions are not distinct-behavior counts.

### Matched performance

Seconds, baseline → candidate; each row is a separate runner pair using the same retained 40-file input.

| Order / run | Boot helper | Complete Load | Load → Ready | Complete Save | Save press return |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline first / 40016618456 | 62.466 → 53.006 | 172.018 → 156.555 | 168.770 → 153.305 | 107.068 → 109.357 | 95.533 → 97.642 |
| Candidate first / 40018514503 | 63.897 → 52.595 | 177.145 → 156.226 | 173.843 → 152.926 | 111.130 → 113.845 | 99.092 → 101.674 |

Load improved 9.0–11.8% in both orders. Complete Save was 2.1–2.4% slower in both, with unchanged Save validation counts. Acceptance is for the Load/startup improvement with that explicit Save tradeoff; this is not a universal speedup or evidence that the slowdown is merely noise. In the first pair, Load receipt calls fell 114 → 93, bundle checks 236 → 191 and snapshot checks 24 → 21. Save retained 108 receipt calls, 226 bundle checks and 18 snapshot checks. Nested timings overlap and must not be summed.

The boot helper starts after process launch. Complete operation clocks include verification and captures; press-return includes the helper's existing five frame waits. Two ordered pairs do not establish a latency distribution. These absolute timings must not be compared across different runners as if they were one continuous benchmark.

Both pairs preserve the reported snapshot, checkpoint, Profile, native presentation, Profile hash, registration hash and autosave hash. The root reviewer checked all eight rendered post-Load/post-Save captures: the same fully revealed courtyard/rain caption and expected post-Save focus. Output slot bytes are not asserted identical. Current-scene destination success and preparation integrity are tested; injected destination preparation failure/retry coverage uses the legacy route.

### Provenance and evidence

The first comparison records candidate event ref `ba2a841449b8e05057c4b20f1b361af0684800db`; the reverse diagnostic records `d785834f70994e1609497bf26ff6119ead006d81`. Neither should be relabeled as the PR head. The three measured runtime-file hashes were independently matched to qualified head `2a5d99e` and baseline `87ed3a1aafb68aafccfaf3faa7aeb1bdec8bc75c`. The reverse diagnostic changes measurement order only and is not a product branch to merge.

The unchanged helper archive SHA256 is `c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670`; source slot SHA256 is `17934c8199a7d25f97c69890f0ca609e5106c6bb6dc187464d58c40d2baf987c`. Individual helper/runtime hashes, exact timings, run metadata and merge proof are in [results.json](../evidence/phase_2r/current_save_followup_20261024/results.json).

[Exact compact evidence](../evidence/phase_2r/current_save_followup_20261024/exact-evidence.zip): 2,915,063 bytes, SHA256 `0c45366dda5af43535b334127a58625958b3c177ab3c91b50fca9f766b46e2db`. All 38 downloaded source archives were verified by size, SHA256 and ZIP CRC. The bundle retains 235 selected members, including both complete native artifacts, as 201 deduplicated objects with ten supplemental records. Its manifest explicitly lists 326 excluded members. The 110,864,667-byte export distribution is excluded; metadata and the successful export log are retained. Original ZIP containers and excluded member bytes are not retained.

## PR #61: accepted current-snapshot writes and terminal validation

PR [#61](https://github.com/Siuuuers/dwm/pull/61) merged as `47adfe8d0ba7edde4bd073a05f7cf0405cfca302`. Qualified source `524d6fe1cbf524384348b248f327c79a09ea177f` and merge have identical tree `070aa3bdff9f2696ca36a17a8405d62ae4a6b35a`.

Final cloud run [40020424693](https://github.com/Siuuuers/dwm/actions/runs/40020424693) passed all 32 jobs. The 27 primary reports contain 2,826 cases / 155,753 assertions. Three fresh-process Load cases / 206 assertions and two native cases / 224 assertions are separate. Intentional storage-refusal children contain 166 cases / 198 assertions with 160 expected failure elements; they are excluded from passing primary coverage. Historical fixture XML is excluded from current execution counts.

New Run9 checkpoints and direct Save writes omit obsolete full fallback snapshots while keeping the complete current snapshot, its dialogue history and consequence receipts. The checkpoint journal still owns sequence allocation and rollback. Existing admitted history, immutable continuation/creation documents and legacy retention remain intact.

Terminal semantic validation reuses fresh authenticated commands from the same successful frame-validation call under the existing issuer/creation-owner identity guard. Physical Profile validation and native anchor joins remain. There is no cross-call validation cache. Terminal success dictionaries gain `scene_commands`; combined invalid-input failure priority can follow terminal/frame validation before physical Profile checks.

The previously unwired terminal-admission test now has an explicit regular CI suite using the pinned genuine save root. The existing `authored_week` suite is registration-unit coverage; its name must not be taken as evidence of an uninterrupted authored-week journey.

Preflight [40018723234](https://github.com/Siuuuers/dwm/actions/runs/40018723234) passed eight primary cases / 329 assertions plus one fresh-process Load / 116 assertions. The historical 112-assertion XML packaged inside the retained input is excluded. Terminal full/checkpoint/semantic validation each used two receipt and two physical-proof calls; changed Profile bytes were refused and restored. Caller, result-shape, journal and runner reviews found no blocker. The retained fixture covers genuine PRIMARY_PENDING lifecycle with a native DONE caption; it does not establish a separate completed-lifecycle case.

### PR #61 matched native result

One baseline-first pair in [run 40020424693](https://github.com/Siuuuers/dwm/actions/runs/40020424693) compares the merged #60 baseline with the three changed runtime files in #61. Both variants passed the retained 112-assertion ending Save/Load/Continue case. All three measured hashes match the intended source; the recorded candidate event ref is `43cce02398621e86b2258d20a08ef46825c93628`, not the qualified PR head.

| Operation | Baseline seconds | Candidate seconds |
| --- | ---: | ---: |
| Boot helper | 42.011553 | 41.498765 |
| Complete Load helper | 125.175229 | 123.297095 |
| Load action → Ready | 122.235155 | 120.320636 |
| Complete Save helper | 83.229983 | 59.192789 |
| Save press return | 73.794799 | 50.342934 |
| Whole variant wall time | 275.834397 | 247.968580 |

The complete Save helper improves 28.9% in this pair. The 1.5% Load change is small and is not a broad Load-speed claim. Save receipt validations fall 108 → 70, bundle validations 226 → 150 and snapshot validations 18 → 10; Load receipt validations fall 93 → 80 while snapshot validations remain 21. This supports removal of repeated work but does not separately attribute timing to each of the two changes. No additional global manager or cross-call validation cache was introduced.

Reported snapshot, checkpoint, Profile, native caption state, Profile hash, registration hash and autosave hash match. Output slot bytes differ; the actual-write tests establish the intended empty fallback history. All four native PNGs were inspected. This benchmark uses the retained older history-bearing input; it does not establish a performance distribution for newly written history-free saves. Remaining Load-to-Ready of 120.3 seconds and Save press-return of 50.3 seconds are substantial. Do not call the game smooth on this workload.

### PR #61 durable evidence

[Results and merge proof](../evidence/phase_2r/current_save_final_20261024/results.json) record final CI counts, input/runtime hashes, comparison limits and the identical qualified/merged tree. [Exact compact evidence](../evidence/phase_2r/current_save_final_20261024/exact-evidence.zip) is 2,755,756 bytes, SHA256 `cbcc7e77ce2eae1d11da599130f48f00680cf25b1a6923e2eaaea1c44a3c3b6b`. All 38 downloaded source archives passed size, hash and ZIP CRC verification. The compact bundle retains current XML, reports, logs, every native-comparison member, preflight evidence and final run/merge metadata. Its manifest lists 326 omitted members; original archive containers and the export distribution are not retained.

## Next bounded retirement boundary

Before another latency change, measure a freshly written Save9 → fresh-process Load using the current build. The retained comparison input still contains old full history, so its 120-second Ready measurement is not a clean measurement of only the new history-free save shape. Keep the old matched workload for comparability, but do not infer the fresh-save result without measuring it.

A read-only caller audit found that normal MenuScene/bootstrap new-game creation uses Save9, while SaveMigrations and Backup Load can still admit Save8. Bootstrap also installs legacy restore participants and invokes older cold-recovery paths. The approved current-build-only policy permits retiring that old player admission; it does not authorize indiscriminately deleting shared state.

Start a separate retirement pass at the Save9-only player admission boundary, with a simple unsupported-format result. Audit startup pending operations before removing their reader. Do not automatically erase Profile or creation chronology: current receipts and continuation authority still use immutable creation records, and current scene challenges still use shared dating/desktop owners. Names such as “non-scene,” “dating,” or `schema_version != 9` are not sufficient proof that a whole component is dead. This pass is a broader caller/ownership change than the completed performance batch and should have its own observable outcome and acceptance evidence.

## Continuation rules

All Godot and PowerShell execution is cloud-only. Do not replace an accepted source with a diagnostic controller, or rerun successful coverage without a new change or unresolved concern. Historical drafts #14, #30 and #50 and their branches remain preserved; their earlier integration is not waiting to be reapplied. No gameplay design question blocks the current approved Backup scope. This completed, merged and documented batch is a useful new-session boundary before the broader Save9-only admission work. Start that session from this handoff and verify current master before editing.
