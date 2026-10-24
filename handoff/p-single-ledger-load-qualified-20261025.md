# Single-pass terminal Load handoff — 25 October 2026

## Publication status

Qualified for publication with PR #82. Consult live PR metadata for the merge revision.

[PR #81](https://github.com/Siuuuers/dwm/pull/81) is merged at `3cd9d7e82dd04a4553362a34507d47d2fafa4397`. It removes repeated story-registration derivation for selected Challenge recalls. Its evidence is in `evidence/phase_2r/selected_recall_20261025/`.

[PR #82](https://github.com/Siuuuers/dwm/pull/82) contains the separate terminal ledger change described here. Its runtime and committed inventories were qualified at `e31ebf580db251b01c5417ce1171b99d13b5da8d`; the enclosing publication adds evidence and this handoff. Check live master and PR metadata before resuming. Do not repeat either change if already merged.

- Final publication and merge revisions: see the enclosing commit and live PR #82 metadata; no self-referential SHA is embedded here.
- Durable evidence directory: `evidence/phase_2r/terminal_single_ledger_20261025/`.
- Repository task record: `dwm-terminal-single-ledger-20261025`; offline record only, no live Beads/Dolt synchronization claimed.

## Product result and supported boundary

Terminal validation previously authenticated the complete scene receipt ledger, reconstructed terminal admission, and authenticated that same ledger again while validating the retained source checkpoint. The source checkpoint now uses the first authenticated ledger within that same synchronous call.

The selected terminal validator's private core returns its authenticated admissions and commands to FrozenRunContext. Its public wrapper keeps the original success and failure results. FrozenRunContext still checks source-checkpoint shape, registration, active occurrence, historical immutable frames, and the native caption/anchor relationships. Independent public calls and later restore phases obtain fresh validation. No persistent cache, manager, save field, migration, or public skip flag was added.

This change follows inspection of the actual production interval, not an assumption that matching hashes or owner identities establish freshness. Between the first ledger return and source validation, terminal reconstruction calls issuer verification/derivation and reads the concrete DesktopIssuerRootStore. Its verification reads the loaded document; capture returns a detached copy. The inspected interval has no await, signal publication, write, allocation commit, or queued-event processing. Profile and creation-journal proof calls occur inside ledger validation, not between the two former passes.

The earlier [ledger boundary handoff](p-save-load-ledger-boundary-qualified-20261025.md) retained injected-root mutation tests. Those tests replaced the production root with a stack-aware proxy that deliberately changed Profile bytes or root state during reconstruction. They proved a broader callback contract, not a reachable ordinary player action. Their requirement for the second traversal is now explicitly superseded by the [25 October policy clarification](../docs/design/2026-09-29-unshipped-development-save-policy.md). Concurrent external edits and injected mid-call mutations are outside this supported gameplay boundary. Invalid state present before a public call remains refused.

If production reconstruction later yields, publishes signals, writes state, or introduces mutable callbacks, review this local reuse boundary. Do not preserve a second traversal solely to satisfy a retired injected-owner test; do not remove source-reading validation itself.

## Revisions and current correctness evidence

| Role | Revision |
| --- | --- |
| Qualified first-stage comparison baseline | `6c8b5bcf01b6264253d8d918558a005ac941a770` |
| Single-pass runtime and tests | `2c014e11198b853278be4fd1e63b8fbd0e68133f` |
| Committed inventories; runtime/tests unchanged | `e31ebf580db251b01c5417ce1171b99d13b5da8d` |
| Initial qualification controller | `09b3cc34507865723bceb132a03dc161e212ae92` |

[Run 40115954165](https://github.com/Siuuuers/dwm/actions/runs/40115954165) supplies the reviewed current correctness evidence:

| Current suite group | Cases | Testcase assertions |
| --- | ---: | ---: |
| Twelve focused suites | 133 | 1,529 |
| Genuine terminal admission | 1 | 190 |
| Rendered recall Save and separate-process Load | 2 | 168 |
| Total | 136 | 1,887 |

The current XML has no failures or skips. These counts exclude retained historical fixture XML and assertions outside testcases. All 25 recorded source hashes match the reviewed candidate, and the executable hash matches pinned Godot 4.6.3.

Full Frozen, direct terminal-checkpoint, semantic reading, and independent standalone source validation each observe one receipt-ledger traversal and one current physical Profile proof. A root changed before a later public call returns `scene_creation_allocation_unproven`; invalid Profile bytes return `invalid_profile`. Restoring original state admits the original save. Tests retain source-frame corruption refusal, detached returned commands, native anchor checks, and unchanged gameplay state.

The rendered recall screenshots show the complete caption `TEST later memory before recall.` before recall, then `TEST recall_a selected.` both before and after fresh-process Load. No clipped or partially revealed caption was observed. These are authored test fixtures, not a production-art review.

Inventory differences are call-site references in the two changed runtime files and terminal test. Public signatures, dispositions, required contracts, and record counts are unchanged. Read-only [run 40116348959](https://github.com/Siuuuers/dwm/actions/runs/40116348959), controller `089762e7bb4a26b1ac969a38805eb098d2c1dd64`, passed on the committed inventories at `e31ebf580db251b01c5417ce1171b99d13b5da8d`; both returned JSON files byte-match the committed files.

## Complete-operation comparison

Both ordered comparisons passed: eight native test executions / 852 testcase assertions, counted separately from the correctness census. All reported complete operations improved in these two pairs; this is a small measured sample.

Record both execution orders against `6c8b5bcf`, not against pre-PR81 master. Each variant must perform a current Save followed by a separate-process Load of its new slot, with identical measurement helpers and retained input bytes.

| Operation | Baseline-first: baseline → candidate | Candidate-first: baseline → candidate |
| --- | --- | --- |
| Save press-return | 23.284 → 19.037 s (−18.24%) | 27.854 → 24.013 s (−13.79%) |
| Retained-slot Load Ready | 51.025 → 47.447 s (−7.01%) | 59.897 → 56.112 s (−6.32%) |
| Fresh-slot Load Ready | 28.525 → 26.806 s (−6.03%) | 34.843 → 32.219 s (−7.53%) |

Report mixed results honestly. Do not add nested phase times to operation totals, combine the two PRs' percentage improvements, or describe two ordered comparisons as a latency distribution. This is Windows source-project evidence with software rendering, not installed Steam performance. No Steam upload is part of this work.

## Useful next session

A fresh session is useful after this bounded change is qualified and merged. The next investigation concerns remaining ledger costs, rather than the now-removed second traversal.

1. Verify live master contains PRs #81 and #82 and read the final evidence manifest.
2. Start with one observable slow Save or Load operation and a reproducible retained workload.
3. Measure sibling intervals for committed initial-creation proof, initial-material validation, and the remaining receipt traversal. Count and time root captures without adding nested timings to the full-operation total.
4. Use the existing SaveManager, ProfileManager, and issuer-root owners. Distinguish a required current physical read from repeated deterministic reconstruction or whole-root copying. The journal and initial-Autosave parser already have reuse; do not add another cache by default.
5. Change only the measured cost that matters. Retain exact dialogue/board restoration and no repeated consequences. Qualify with focused owner tests and matched complete Save/Load comparisons in both orders.

No product-design question blocks that investigation. Current-build-only saves remain the scope; old development compatibility and injected mid-call mutation behavior must not silently become requirements again.

## Durable evidence completion

See [durable evidence](../evidence/phase_2r/terminal_single_ledger_20261025/README.md) for results, current case census, exact artifact-member bytes, original ZIP hashes, mapping manifest, and isolated controller patches. Controller branches are measurement machinery and are not merged into the game.
