# Startup and Load efficiency handoff — 2026-10-24 (Hong Kong)

## Latest approved policy — implementations accepted in PRs #59–#61

Current acceptance and remaining work are in [the final current-save handoff](c-current-save-final-handoff-20261024.md). The measurements and implementation plan below are retained as historical context from before PR #59.

The user approved a current-build-only save contract for this unshipped game. Valid saves produced by the current build are the supported input; older development saves may be discarded when development changes the format or state model. Backward compatibility, legacy migration, repair, recovery and searching older checkpoints are not product requirements. Incomplete files, unsupported formats and state the current game cannot restore are outside this contract.

This decision supersedes the previous question about when Backup should perform a full compatibility check, and earlier guidance to preserve compatibility/recovery machinery for future save work. It does **not** remove Save/Load: Load must still apply the selected saved state correctly. The code and measurements below describe the accepted implementation before this simplification; they are not acceptance evidence for the proposed design. This handoff update changes documentation only.

## Accepted source

PR [#55](https://github.com/Siuuuers/dwm/pull/55) merged as `153f17bbe7ed8d6b4080e8c7991a06658108202b`, tree `3f3a43fc892fd078c4b6bfae6d1a5be9d716f96a`. PR [#56](https://github.com/Siuuuers/dwm/pull/56) merged as `10a4dae0ae50ddc4f28158347261ec9be558a49a`, tree `2f69e073325c111a634ba440a4e964eaa8cd8573`. Both merged trees equal their qualified source trees. Duplicate post-merge CI was skipped; this did not bypass an unpassed test.

The compiler now performs its resource-type load only when its existing per-path cache is absent or physical text changes. Fresh file reads and argument-sensitive, detached compiled results remain. The registration has 92 entries sharing seven Day files: 10, 12, 13, 12, 13, 12 and 20 references respectively. Repeated loader messages were redundant calls, not evidence by themselves of repeated physical disk reads.

Hidden Backup windows invalidate their projection on changed notifications instead of inspecting all slots. Preview, entry, reopening, actions and visible updates keep their existing fresh checks. ProfileManager reuses one strict-JSON parse for exact matching text up to 1 MiB; this bounds source size, not exact heap memory. Schema validation still runs on detached input every time. Physical storage reads, revision/hash checks, canonical serialization, mutable registry checks and receipt comparison remain intact.

CI selects a small suite set only for the exact reviewed private-method/test/tool scope. Changes elsewhere and manual dispatch retain full validation. This is not a new claim of full-game acceptance beyond the prior integrated handoff.

## Cloud acceptance and measurements

- [Run 39996703616](https://github.com/Siuuuers/dwm/actions/runs/39996703616): five suites, 72 cases / 5,131 assertions, plus two native variants with 112 assertions each.
- [Run 39997322266](https://github.com/Siuuuers/dwm/actions/runs/39997322266): six suites, 116 cases / 5,711 assertions, plus two native variants with 112 assertions each. This includes the prior five-suite coverage; do not sum it as disjoint coverage.
- [Run 39999976015](https://github.com/Siuuuers/dwm/actions/runs/39999976015): candidate-first repeat, two native variants with 112 assertions each. Diagnostic source `8a90bec16706eefb7cd94429c6f3d9a251eb0a36` changes only the measurement order and adds its isolated workflow. It is not product source.

All selected cases passed, with no failed, errored or skipped cases. Broad jobs were intentionally not selected. All native runs used fresh processes and isolated user roots, the identical retained 40-file input, four checked helper hashes, and source slot SHA-256 `17934c8199a7d25f97c69890f0ca609e5106c6bb6dc187464d58c40d2baf987c`. The retained helper archive SHA-256 is `c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670`. Actual runtime hashes were checked against the intended revisions. Rendered post-Load and post-Save captures were inspected for every variant.

Seconds, baseline → candidate, each comparison on its own runner:

| Comparison | Boot helper | Complete Load | Load to Ready | Complete Save |
| --- | ---: | ---: | ---: | ---: |
| #55, baseline first | 53.522 → 52.625 | 343.961 → 333.758 | 253.091 → 246.447 | 221.537 → 210.812 |
| #56, baseline first | 40.702 → 38.406 | 275.353 → 245.603 | 207.495 → 181.184 | 167.240 → 175.062 |
| #56, candidate first | 53.035 → 51.988 | 338.395 → 317.397 | 250.372 → 235.182 | 225.074 → 207.274 |

The #55 complete-journey Day loader-message count fell 20,772 → 15. Both #56 variants retain 15 messages. This is not a startup-only count. Boot begins inside the helper after process startup; it is not launch-to-Title latency. Complete Load/Save include the helper's verification and capture. Ready is the existing live-session signal. Press-return timings include five existing frame waits. Nested timings overlap and must not be added.

Accept #56 for Load improvement reproduced in both orders (6.2–10.8% for the complete helper). Save observations are mixed: +4.7% time in the first pair, −7.9% in the reversed pair. Corresponding validation call counts match in all four executions; physical-proof work improves in both orders. Unchanged routines slowed later in the first candidate, which suggests variability but does not establish its cause. No universal Save-speed or latency-distribution claim is warranted. The substantial remaining pauses are real; the game is not yet smooth on this workload.

The native helper verifies restored caption visibility/full reveal/DONE state, exact ledger/checkpoint semantics, preserved gameplay and unchanged Profile, then Save and Continue. It does not rerun the full uninterrupted authored week, every branch, Steam packaging or release installation.

## Durable evidence

See [`results.json`](../evidence/phase_2r/startup_load_20261024/results.json) and [`exact-evidence.zip`](../evidence/phase_2r/startup_load_20261024/exact-evidence.zip). The ZIP preserves exact uncompressed bytes of every member of all 14 original Actions artifacts, deduplicated as `objects/<sha256>`. Its `manifest.json` maps each original member path to the object, records original archive hashes and GitHub artifact metadata, and permits member-by-member verification. Original ZIP container bytes are not preserved in this compact bundle. Bundle SHA-256: `995ab5831653ef1d5d1d19c16471ceade8ade14ab5027f66b52286931cbcbbbe`.

## Approved minimal Backup behavior

Observable outcome: opening Backup presents basic slot information without preparing restoration; loading a valid current-build save restores the selected gameplay state without replaying its consequences. SaveManager remains the canonical owner of save/load behavior.

| Operation | Required behavior |
| --- | --- |
| Open Backup | Read only the basic slot information needed for display; do not build restore plans or run full compatibility preflight for listed slots. |
| Save | Write the current game state. An existing save being overwritten does not need to pass a restoration check. |
| Load | Read the selected current-format save and apply its state. Do not search for an older compatible checkpoint or introduce a separate full compatibility preflight. |
| Delete | Remove the selected save without preparing restoration or checking compatibility. |
| File operation fails | Report failure simply; no repair or recovery framework is required. |

The decision to omit malformed/incompatible-save support does not claim such files are physically impossible. It deliberately excludes them from the supported product contract while the game is unshipped. Permission to discard old development saves is a policy, not an instruction for this documentation update to delete any files.

## Next implementation and acceptance

Replace the shared full-inspection path with operation-specific work. Today, list inspection prepares restore participants and then discards the plan, while action preparation performs full inspection before choosing Save, Load or Delete. Remove obsolete compatibility/recovery behavior together with its dependent callers and tests; do not leave the normal current-save path dependent on preparation that was removed. Update Title selection and Backup labels/buttons to match the supported current-save contract rather than retaining a promise of full compatibility certification.

Keep one owner for each fact, with no additional manager or global “already safe” cache. Preserve ordinary gameplay correctness: board state, flags/reveals, dialogue position and complete-line presentation, choices, and exactly-once rewards/consequences. Checks or copies retained in the simplified flow should have a concrete purpose in that contract rather than preserve retired compatibility obligations.

Use the smallest meaningful automatic coverage: verify that listing and Save/Delete do not prepare restoration; verify a current-build Save → Load round trip across cooperating owners; cover simple file-operation failure where relevant; and verify the connected rendered journey preserves the visible beat and does not repeat consequences. Retire tests for excluded compatibility/recovery behavior coherently with the code. Complete compatible caller/test reviews before final acceptance, then run one coherent candidate rather than overlapping acceptance batches.

All Godot execution remains on cloud runners. Measure the complete operation with a matched comparison before claiming a performance gain; shorter code alone does not establish less lag. Existing evidence remains historical and must not be relabeled as acceptance of this pending implementation.

The policy question is resolved. Proceed with this scope without asking again about selection-time versus click-time full compatibility validation. Ask only if a newly discovered design choice would materially change the supported gameplay contract. No new session is required solely to continue this work.

## Branch and PR preservation

Historical drafts #14, #30 and #50 remain preserved; they are not finished product changes waiting to be blindly merged. Earlier functional integration already reached master through #52. All branches remain intact, including the new diagnostic branch `codex/profile-parse-reverse-check-20261024`. Do not merge that diagnostic controller into product source or reapply older superseded implementations.
