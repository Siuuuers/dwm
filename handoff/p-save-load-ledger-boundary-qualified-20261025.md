# Save replacement and Load ledger handoff — 25 October 2026

## Product result

This record precedes publication merge. Check the live PR for branch `codex/save-load-boundaries-20261024` before applying any work.

SaveManager now replaces an existing Autosave or slot without requiring the old bytes to pass restore validation. This applies to `_write_latest`, including save-on-exit. Backup already used this storage operation.

The writer inspects the exact destination revision. It uses `write_atomic_if_revision` to refuse a competing replacement. Outgoing validation and the final schema/hash readback remain. The exit coordinator still owns session retirement. A failed save does not retire the live session.

This change adds no manager, cache, save field, migration, or recovery system. It makes the public save family follow the approved current-build-only policy.

## Revisions and tests

| Role | Revision |
| --- | --- |
| Baseline master | `08e9471a589fde0ebc9e460ab650047f465aef93` |
| Initial product | `7e89b349407b46fca889da19e67b6f60e86761cd` |
| Corrected tests, unchanged runtime | `7d002b728f045c6380ed5100129bdea2831dbdcb` |
| Committed inventories | `ebcf566a809d97799b4a7b440f9ed77b782ac041` |
| Separate diagnostic source | `1864369b38dd1660406f843440bbd32682d50f7e` |

[Run 40109171228](https://github.com/Siuuuers/dwm/actions/runs/40109171228) passed the terminal regression, inventory generation, and diagnostic journey. Its focused job failed two test observations. Both used lease-gated `read_text` after a refused revision write. The correction uses `inspect_revision` to prove exact preserved bytes and hash. The exit test also compares the entire persisted file set. No runtime correction was needed.

[Run 40109497833](https://github.com/Siuuuers/dwm/actions/runs/40109497833) passed both corrected suites and regenerated their inventories.

| Current suite | Cases | Case assertions |
| --- | ---: | ---: |
| Backup current build, corrected | 5 | 63 |
| SaveManager public boundaries, corrected | 6 | 273 |
| SaveManager unit, unchanged | 7 | 87 |
| Session exit coordinator, unchanged | 5 | 53 |
| Genuine terminal admission | 1 | 213 |
| Total | 24 | 689 |

These counts use current testcase XML. They exclude retained historical fixture XML and setup assertions outside testcases. The accepted cases have no failures or skips. The unchanged suites retain their first-run evidence. [Run 40110921861](https://github.com/Siuuuers/dwm/actions/runs/40110921861) verified both committed inventories without regeneration at `ebcf566a`. No qualification job is pending.

Independent reviews covered the runtime change, tests, controller, current test evidence, and generated inventories. Public signatures, required contracts, and dispositions are unchanged. Inventory differences are test references and line locations.

## Load safety result

The new terminal regression changes external proof state after the first ledger validation succeeds and before source-checkpoint validation begins:

- One case changes physical Profile bytes on disk. The second ledger returns `invalid_profile`.
- One case changes the authoritative root allocation in memory. The second ledger returns `scene_creation_allocation_unproven`.

Both cases retain the same issuer and owner objects and the same caller snapshot. Each observes two ledger validations and one source creation-proof call after mutation. The test restores proof state before its assertions. The original save then validates again. Profile bytes and the retained slot remain unchanged at completion.

These results show why input hashes and owner identities alone cannot authorize reuse across this callback interval. Do not remove the second ledger validation on that basis.

## Diagnostic result

The diagnostic branch adds observations only. Do not merge it or its controllers into master.

There are 171 current diagnostic rows and 43 correlated terminal triplets. All observed rows succeed. Their input/context hashes and owner identities remain unchanged within each measured phase. This describes this execution; it does not prove that callbacks cannot change external state.

| Operation | Terminal triplets | First ledger | Reconstruction | Second ledger |
| --- | ---: | ---: | ---: | ---: |
| Fresh Load | 9 | 3.799649 s | 0.051987 s | 3.818651 s |
| Retained Load | 13 | 5.303432 s | 0.067186 s | 5.371667 s |
| Save | 15 | 6.298961 s | 0.081570 s | 6.335370 s |

Fresh Load has eight snapshot validations and one direct reading-restore validation. Each ledger phase performs one initial physical-proof attempt. Reconstruction performs none. Metadata collection occurs outside each phase timer. Operation totals still contain diagnostic overhead. Nested timings must not be added to complete-operation timings.

The diagnostic journey passes two current native cases with 213 assertions. Its seed, writer, and separate loader exit with code 0. Saved slot bytes match the loader's source. Three current screenshots show the complete same caption. These results use diagnostic baseline runtime, not the product save-change revision.

This is Windows source-project evidence with checksum-pinned Godot 4.6.3 and software rendering. It does not establish installed Steam performance. No speedup or latency-distribution claim is made. Import logs retain a GUT version-check HTTP 403 and ObjectDB warning. Native logs retain the OpenGL-to-ANGLE fallback. No Steam upload occurred.

## Next investigation

The next measured target is ledger work, not terminal reconstruction.

1. Check live master and this change's merge status.
2. Read `diagnostic-analysis.json` and the current evidence manifest.
3. Separate pure receipt/ledger derivation from fresh Profile and root proof work inside `SceneEventContract.validate_selected_scene_receipts`.
4. Record which callbacks can change each input or external proof.
5. Preserve receipt, terminal, source-checkpoint, context, and frame refusal order.
6. Keep the new Profile and root mutation regressions.
7. Introduce no persistent trust cache or public bypass flag.
8. Qualify any runtime candidate with focused tests and matched complete Save/Load comparisons in both orders.

No product-design question blocks this investigation. Current-build-only saves remain the scope. A new session is useful after this bounded save correction and callback investigation are accepted: the next task needs a different decomposition of ledger calculation and mutable proof ownership.

## Durable records

[Results](../evidence/phase_2r/save_ledger_boundary_20261024/results.json) retain source and inventory hashes and qualification reports. [Diagnostic analysis](../evidence/phase_2r/save_ledger_boundary_20261024/diagnostic-analysis.json) contains exact phase correlations and observations.

`exact-evidence.zip` retains each unique uncompressed artifact-member byte sequence under its SHA-256. Its manifest maps original archive names and member paths to those objects. Original ZIP container hashes are recorded; original ZIP containers are not retained in the compact bundle. Controller and diagnostic patches are retained alongside it.

The repository task record is `dwm-save-ledger-boundary-20261024`. It is an offline record. No live Beads/Dolt synchronization is claimed.
