# Load validation handoff — 24 October 2026

## Status

[PR #79](https://github.com/Siuuuers/dwm/pull/79) contains the qualified change. This record precedes the merge. Check the PR for its merge status.

Ordinary terminal-save Load is faster in both comparison orders. The complete saved caption and save bytes remain correct. Long pauses remain.

| Source | Revision |
| --- | --- |
| Baseline master | `1cf751ffebd8336b53732c56ef7488873e3ab2a8` |
| Tested runtime and tests | `b8383c64941eb58ed55195531510f565af41d65a` |
| Final source and inventories | `3e4162ae5be27c7d997a48c0adaea543a7a8f8c9` |

The final source changes only the generated inventories after the tested revision. Later publication changes contain evidence, this handoff, and the task record.

No test job is pending. No Steam upload occurred. The diagnostic controllers must stay outside master.

## Accepted change

`RunSnapshotSchema` checks a terminal reading checkpoint before it calls the semantic owner. Previously, `GameState` repeated the same Frozen validation.

The private path now uses the first result when these conditions remain true:

- The terminal checkpoint is not empty.
- The original GameState, issuer, SaveManager, and Frozen bindings still match.
- The candidate bytes did not change during the first validation.

The code records the owners and input hash before the first validation. It checks the original owners again at result use.

If a condition fails, the code uses fresh validation. Public semantic calls always use fresh validation. Empty checkpoints retain their existing path.

Profile checks and dialogue-anchor checks remain in place. Input mutation still takes precedence over a later semantic refusal.

The change adds no persistent cache, save field, manager, or public trust flag. SaveManager remains the save/load owner.

## Test evidence

[Run 40100173179](https://github.com/Siuuuers/dwm/actions/runs/40100173179) used controller `261559ec5548ef93253b88b4f65286f8103be0a3`.

- Nine isolated focused suites passed 80 cases and 911 assertions.
- The genuine terminal-save case passed 184 assertions.
- These ten suites passed 81 cases and 1,095 assertions, with no failures or skips.
- Both native comparison pairs passed eight current case executions and 852 assertions.
- All twelve native processes exited with code 0.
- All twelve current screenshots were reviewed.

The terminal test compares the complete result against fresh validation. Receipt and physical-proof counts fall from five to three. Coordinated owner replacement restores five checks.

A callback test changes the actual candidate receipt during nested source validation. Fresh semantic validation rejects that change. The caller's snapshot remains unchanged.

Existing tests retain public-call freshness, Profile checks, empty-checkpoint behavior, anchor refusals, detached commands, and mutation precedence.

Each native writer creates a new slot. A separate process loads that exact slot. Saved snapshots, slot hashes, Profile hashes, and complete caption observations agree.

[Run 40100495757](https://github.com/Siuuuers/dwm/actions/runs/40100495757) checks the committed inventories without regeneration. Its controller is `c0511c0c07655da8a2cda2ed2dca7ee5bc19d63e`.

Public signatures and required contracts are unchanged. Reference changes are line locations and four expected test references.

| Inventory | SHA-256 |
| --- | --- |
| GameState | `d6e9579b1b280c1222525286b5f839f8a1c106658496ad524404e71d8744f183` |
| SaveManager | `08dc0c802484d9cf22fe1d8044b32c98bb5bc98b57eb373d95b3ce8d669a640f` |

## Complete-operation measurements

Values are seconds. Each cell shows baseline → candidate on the same runner.

| Operation | Baseline first | Candidate first |
| --- | ---: | ---: |
| Fresh Load press → Ready | 44.191 → 38.093 | 35.971 → 32.308 |
| Retained Load press → Ready | 70.840 → 63.500 | 60.072 → 55.881 |
| Save press → return | 38.218 → 30.519 | 31.350 → 26.678 |

Fresh Load improves by 10.18–13.80% in these observations. Retained Load and Save also improve in both pairs.

These are two ordered pairs, not a latency distribution. Fresh user data does not establish a cold operating-system cache.

The tests use checksum-pinned Godot 4.6.3 on Windows software rendering. They do not establish installed Steam performance or player-GPU performance.

Import logs contain ObjectDB leak warnings. Native logs contain the recorded OpenGL-to-ANGLE fallback.

The candidate-first baseline import also reports a GUT update-check HTTP 403. That error occurs before the timed native processes.

Intermediate `scene_activation_pending` results precede successful final Ready checks. They are not final Load failures.

## Next investigation

Fresh Load still performs eight snapshot validations. Candidate pre-semantic time totals 16.732 seconds in baseline-first and 13.854 seconds in candidate-first.

These timings include nested work. Do not add them to the complete-operation times.

The next possible duplication is inside `FrozenRunContext._validate_scene_terminal`. The terminal admission checks the ledger. The retained source checkpoint then checks the ledger again.

The following locations use revision `3e4162ae`:

| Boundary | Source location |
| --- | --- |
| First ledger validation | `scripts/domain/narrative/SceneEventContract.gd:1416` |
| Admission reconstruction | `scripts/domain/narrative/SceneEventContract.gd:1430` |
| Intervening issuer calls | `SceneEventContract.gd:1319`, `1321`, `1335`, `1339` |
| Source checkpoint validation | `scripts/narrative/FrozenRunContext.gd:908` |
| Second ledger validation | `FrozenRunContext.gd:128` |
| Source frame derivation | `FrozenRunContext.gd:135` |

This interval crosses issuer/root callbacks. Those callbacks can change physical Profile or root data while input hashes and owner identities remain unchanged.

The current change's guards do not prove safety across that interval. No further result reuse is approved by this evidence.

Use this procedure for the next investigation:

1. Read the live PR and master revision.
2. Read the retained results and the listed source boundaries.
3. Measure the first ledger validation, admission reconstruction, and second ledger validation separately.
4. Record input hashes, owner identities, caller identities, and physical-proof counts outside the timed intervals.
5. Use the same genuine fresh-save Load workload.
6. Keep diagnostic instrumentation separate from the product candidate.
7. Test callbacks that change physical data without changing owners or input bytes.
8. Preserve terminal, source-checkpoint, ledger, context, and frame refusal order.
9. Compare complete operations before accepting another optimization.

No design answer blocks that investigation. Current-build-only saves remain the approved product scope. Legacy migration and repair are not required.

## Evidence and session boundary

[Results](../evidence/phase_2r/load_terminal_reuse_20261024/results.json) contain exact measurements and source hashes.

[The artifact manifest](../evidence/phase_2r/load_terminal_reuse_20261024/artifact-manifest.json) identifies all six original ZIP archives and every member. Original ZIP bytes are retained.

Both controller patches are retained beside the results. Runtime, tests, evidence, and rendered states received independent review.

The repository task record is `dwm-load-terminal-20261024`. It is an offline record; no live Beads/Dolt synchronization is claimed.

A new session is useful now. One change has complete evidence. The next investigation has a different callback and physical-state boundary.

Writing basis: [ASD-STE100 Issue 9](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf), with short sentences and one instruction per step. Repository identifiers remain unchanged.
