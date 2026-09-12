# Publication-ledger and tooling fixture root guards

`dwm-ryl.1`, 2026-09-13. Source base: `623af640f5dbd674941f40def91219ee744646f2`.

Six suites now obtain native fixture roots through `TemporaryStorage.create` and stop before using a failed allocation. The two ledger suites also reset the previous root and storage before each setup. Secondary fixture roots and callers that inspect a successful fixture are guarded. No production code is part of this change.

## Verification

| Run | Suites | Passing / total | Result |
| --- | ---: | ---: | --- |
| Original normal baseline | 6 | 43 / 45 | Two existing live public-surface inventory failures |
| Final normal source | 6 | 43 / 45 | Same failures, no new runtime errors |
| Empty root | 6 | 9 / 45 | Expected root-admission failures; no writes or process attempts |
| Whitespace root | 6 | 9 / 45 | Same expected refusal behavior |
| Valid then missing root | 2 | 2 / 25 | First test of each ledger passes; later setups refuse without reusing storage |
| Process positive control | 1 | 2 / 2 | Both helper process call sites reached with a valid root |

The two normal failures are `test_task3_required_surface_realizes_authenticated_contacts_and_retires_legacy_reply` and `test_task4_committed_schedule_seams_carry_their_exact_frozen_signatures`. They report unclassified current GameState APIs and four retired required symbols, related to the open inventory reconciliation work (`dwm-sf7`). Their assertions and historical evidence remain unchanged. **`dwm-ryl.1` remains open because its all-six-suites-green acceptance is not yet met.** The parent also retains the other 42 audited fixture files.

The normal assertion count changes from 803/805 to 748/750 because repeated root checks are replaced by the existing centralized allocator; behavioral assertions remain. Each run retains the baseline 24 Dialogic orphans. Final normal and negative logs contain no script, parse, or engine errors.

## Negative probe method

A disposable `git archive` of the source base received only the six changed tests and the existing imported-resource/class caches. Its own `Invoke-IsolatedGodot.ps1` isolated application data and `DWM_TEST_ROOT`. The pre-run hook in `probe-hook.gd.txt` cleared the environment after wrapper admission, without aborting GUT. All requested suite headers and refusal assertions were checked.

Only the copied repository-tooling test was instrumented: `print("ROOT_GUARD_EXEC_ATTEMPT")` at the start of `_node_path()`, which both `OS.execute` expressions evaluate. The valid control prints twice; empty and whitespace runs print zero times. No instrumentation is in the shipped test.

For stale setup, the hook restores the valid root at each ledger suite start, snapshots files and directories after its first test, clears the environment, and compares at suite end. Both inventories remain unchanged. Missing-root runs leave their original isolated root empty. Across the probes, all **8,437 file hashes and 522 directories outside `.godot` remain unchanged**. Details are in `probe-verification.json`; invocation records and logs are retained here.

The first empty-root attempt exposed a missed caller that indexed `call_sites[0]` after failed fixture creation. Its log is retained as `root-probe-empty.log`; the final source adds the early return and the corrected empty/whitespace probes have no runtime errors.

Committed log copies normalize trailing whitespace only; original runner logs remain in the ignored worktree evidence directory.
