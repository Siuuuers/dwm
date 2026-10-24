# Run9 snapshot semantic validation handoff — 25 October 2026

## Publication

Qualified for publication with [PR #83](https://github.com/Siuuuers/dwm/pull/83). Consult live PR/master metadata for the final merge revision. PRs #81 and #82 were already merged before this work; do not repeat their changes.

Runtime/test candidate: `13b6853a6f66b92022a589489bf5f0187c18d1e3`. Inventory-only successor: `0ccaaed82bb0f896e998118ee8b5db5d2a25a7e3`. Evidence: [snapshot_semantics_20261025](../evidence/phase_2r/snapshot_semantics_20261025/README.md). Task record: `dwm-snapshot-semantics-20261025` (offline repository record; no live Beads/Dolt synchronization claimed).

## Product result

Run9 normalization already detaches the snapshot, and installed registration returns a detached bundle. RunSnapshotSchema now passes these existing copies into its synchronous read-only semantic validation, removing repeated full-tree hashes and second copies whose purpose was detecting injected callback mutations.

Keep all pre-call registration, shape, receipt, current physical Profile, frame and native-anchor checks. Keep the reentrancy guard, result checks, cheap owner matching and custom-owner fallback. No cache, manager, public bypass, migration or save-field change was added. `_scene_hash` remains used by registration equality; it is not dead code.

The retired test deliberately replaced owners and mutated the checkpoint during validation. Its replacement verifies nested returned-candidate detachment in both directions, fresh refusal after later corruption, exact admitted data and unchanged actual gameplay state. The [current policy](../docs/design/2026-09-29-unshipped-development-save-policy.md) records this supported boundary.

## Qualification

168 current cases / 2,117 testcase assertions pass. Comparisons separately contain 8 executions / 852 assertions. The initial stale inventory lane is superseded by passing read-only verification on the committed inventory; only caller locations changed. All 26 candidate source hashes and the pinned Godot executable match. Current XML has no failures or skips. All four Ready payloads agree, and reviewed terminal/recall captions remain complete.

| Operation | Baseline-first: baseline → candidate | Candidate-first: baseline → candidate |
| --- | --- | --- |
| Save press-return | 24.759 → 21.690 s (-12.39%) | 25.660 → 22.207 s (-13.46%) |
| Retained-slot Load Ready | 57.811 → 51.387 s (-11.11%) | 59.732 → 51.840 s (-13.21%) |
| Fresh-slot Load Ready | 33.513 → 30.852 s (-7.94%) | 33.919 → 30.670 s (-9.58%) |

Do not combine these percentages with earlier PRs. Two ordered pairs are not a latency distribution. This is Windows source-project/software-rendering evidence, not installed Steam acceptance. The earlier Linux diagnostic failed on missing native speech support and is excluded from qualification; the successful Windows diagnostic is retained separately.

## Most useful next investigation

A fresh session is useful after this bounded candidate is merged: it starts from a qualified baseline and a different remaining ownership boundary. No product-design question blocks the following investigation.

1. Confirm live master contains PR83 and read the evidence results. Start from one retained terminal Save/Load workload and measure the complete operation.
2. Inspect `RunSnapshotSchema._validate_scene_observed_body`: terminal snapshots currently authenticate receipts explicitly before `_validate_scene_reading` reaches Frozen terminal validation, which authenticates the ledger again. Measure those sibling passes. This is outside the inner terminal/source duplicate already removed by PR82.
3. Determine whether the first terminal pass can defer only when the matching canonical Frozen owner necessarily performs the second. Preserve independent validation for unmatched owners, empty-terminal boundaries, native anchors, exact restored state and no repeated consequences. Audit before editing and compare complete operations in both orders.
4. Keep current physical Profile proof. Historical initial-Profile reconstruction is another measured candidate only if an existing owner has already admitted the same immutable material. Do not introduce a persistent cache by default.
5. Root captures were numerous but small: the instrumented retained Load scope spent about 0.480 seconds on 3,963 captures. Do not prioritize a new root lookup API solely because the copying looks repetitive.

`SaveMigrations.gd` currently performs admission/version/locator checks, not old-save conversion; its name alone is not grounds to delete it. Some cheap injected-owner identity tests remain, but they should not expand the supported product contract or trigger speculative refactoring. Current-build-only saves remain the scope; migration, recovery and injected mid-call mutation must not silently return as requirements.

Export presets already exclude evidence, handoffs, tests and tools. Retaining qualification records does not add them to the game export. Controller branches are measurement machinery and are not product branches.
