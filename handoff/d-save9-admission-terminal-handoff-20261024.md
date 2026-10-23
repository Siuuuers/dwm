# Save9 player admission and terminal proof: accepted handoff

Continues [the previous handoff](c-current-save-final-handoff-20261024.md). The game remains unshipped. All Godot and PowerShell execution in this batch used cloud Windows runners; local work was static inspection, Git and evidence verification.

## Accepted result

Player Load accepts the current SaveDocument9 format. Older/newer slots remain inspectable, replaceable and deletable, but cannot enter player restore. SaveManager owns this boundary, including direct preparation, Quick Load and autosave entry points. Internal migration and recovery paths remain because pending operations still depend on them.

Terminal reading validation now delegates one repeated full admission proof to the existing FrozenRunContext checkpoint validator when the checkpoint is nonempty and issuer/creation owners agree. Local shape and source-reference checks remain. Empty checkpoints and mismatched owners retain independent full validation. No cross-call cache or new manager was introduced.

| Work | Qualified head | Merge |
| --- | --- | --- |
| [PR #63](https://github.com/Siuuuers/dwm/pull/63), current player format | `f50ed34bf9edd4423a567cd157b2164bb097e217` | `469e0d68f6d42bf36a0d00e9fe5f437fa79df600` |
| [PR #64](https://github.com/Siuuuers/dwm/pull/64), repeated terminal proof | `31059f4204c62debd2140b865d8fdefc74f341ac` | `de5a92e35754762ab8ecad7eb5230bcaa74864d1` |

Git API verification established identical head/merge trees for each: respectively `8be2a37bbe8647327ab4003a92839c0ea1c4e0c0` and `5e21a7ae325b878390f856c866133b6dc7421999`. Merge commits skip redundant CI; the exact candidate trees had already passed. Historical draft PRs #14, #30 and #50 remain deliberately unmerged.

## Cloud acceptance

| Run | Primary reports / cases / assertions | Separate fresh-process cases / assertions | Jobs |
| --- | --- | --- | --- |
| [Final #63: 40026669085](https://github.com/Siuuuers/dwm/actions/runs/40026669085) | 28 / 2,830 / 155,928 | 3 / 206 | 32 passed, 1 intended skip |
| [Final #64: 40026684924](https://github.com/Siuuuers/dwm/actions/runs/40026684924) | 28 / 2,830 / 155,910 | 3 / 206 | 32 passed, 1 intended skip |

Passing groups have no failures, errors or skipped cases. Each run separately contains intentional storage-refusal children: 2 reports, 166 cases, 198 assertions and 160 expected failure nodes. Their wrapper requires the `test_root_missing` refusal; those nodes are not counted as passing primary coverage. The skipped job is the redundant matched-startup comparison, not a skipped test case.

The real Save9 Quick Load test is now in the canonical suite (1 case / 70 assertions), covering pending identity, consumed consent and Profile preservation. `RetainedLegacyRestore.gd` is a test-only adapter retaining internal transaction/retry coverage below the new player boundary; it does not restore player compatibility. The first full #63 run (40025003835) failed two fixtures; final source fixes revision inspection in the quick-action double and uses Save overwrite for the existing-confirmation/F5 test. The earlier failed run remains diagnostic evidence.

The terminal boundary case passes 141 assertions, including forged/missing triggers, malformed admission, owner mismatch, empty-checkpoint rules, source changes and physical Profile tampering. Its genuine fixture is ENDING/PRIMARY_PENDING with a native DONE caption. It does not prove a valid COMPLETED/nonempty lifecycle fixture. Multiple simultaneous errors can now report a source-reference error before a deeper ledger error, while still refusing invalid state.

## Native measurement and its limits

The new `Invoke-FreshSaveLoad.ps1` writes a real current slot and loads those exact bytes in a distinct native process. It checks Save9, empty recovery history, writer snapshot equality, Profile, registration, receipts and visible state. This is a fresh process with retained Profile history, not a fresh empty profile.

[Matched run 40025922576](https://github.com/Siuuuers/dwm/actions/runs/40025922576) compared baseline `869fcef537167f84e1b534324daaabdc3d715fb0` with candidate `45b6b2bf096dac9b722ef74a54439b0659178ef2`. Separate temporary worktrees used the same pinned engine, helpers and input. Candidate runtime bytes equal final #64 runtime bytes; workflow/test/inventory changes are listed in the evidence provenance. Four native cases / 426 assertions passed across six successful processes.

| Seconds, one baseline-first pair | Baseline | Candidate |
| --- | ---: | ---: |
| Fresh Load to Ready | 115.027796 | 110.515481 |
| Complete fresh Load helper | 118.715843 | 114.208669 |
| Complete Save helper | 75.652039 | 70.341078 |
| Save press-return | 64.785685 | 59.986368 |
| Fresh boot helper | 73.923332 | 71.840995 |
| Whole variant | 517.8652421 | 497.8148505 |

Fresh Load receipt/physical proof calls fall from 56 to 47; all nine full snapshot checks remain. Save receipt/physical proof calls fall from 70 to 60; all ten snapshot checks remain. Snapshot, checkpoint, Profile and native saved/Ready state agree across variants. Both new slots are 448,631 bytes with empty recovery history; their only top-level difference is `saved_time`. All six comparison captures were viewed and preserve the courtyard/rain caption and controls.

This establishes a bounded redundant-work reduction and one observed improvement, not a latency distribution or guaranteed speedup. Helper times include verification work; press-return includes inherited frame waits. Loading remains far too slow to call smooth. Shorter source code alone is not evidence of lower latency.

The earlier Save9 preflight (40023232755) passed 13 current cases / 316 assertions plus 2 native cases / 213 assertions. Its fresh Load-to-Ready was 113.550169 seconds, an unmatched observation. Initial terminal preflight 40025416369 passed its 141-assertion boundary case but failed comparison setup on Windows path length; the corrected matched run supersedes that setup failure. The old #63 matched benchmark showed essentially unchanged Load time and is not evidence of a meaningful admission-policy speedup.

## Durable evidence

See [`results.json`](../evidence/phase_2r/save9_admission_terminal_20261024/results.json) for archive size, SHA256 and execution groups, and [`exact-evidence.zip`](../evidence/phase_2r/save9_admission_terminal_20261024/exact-evidence.zip) for exact selected bytes. Its manifest maps original paths to content-addressed objects and lists every omitted member, original archive metadata/hash/size, CRC verification and separate execution groups. Current XML, logs, JSON, source provenance, merge proofs and native captures are retained. Original ZIP containers, repeated historical input and distribution binaries are not duplicated. Counts represent executions, not unique behaviors. Broader CI screenshots were not all visually reviewed.

## Next bounded investigation

The next observable outcome is unchanged fresh native state, caption and receipts with one fewer source-snapshot proof during uninterrupted restore preparation. Audit SaveManager `_prepare_restore`: full admission of the detached current document is immediately followed by built-in RunRestoreParticipant preparation validating the same snapshot.

Existing same-call admission material may permit reuse only for the exact document, owners and built-in participant before callbacks or mutation. First establish refusal/retry, changed-input, custom-participant, missing-material, owner-mismatch and legacy fallback coverage. Public participant preparation must remain fully validating. Preserve private creation-plan reset and all later checks that cross storage, callbacks, allocation or live application. Never reuse proof merely because checkpoint IDs match.

One observed full proof costs roughly 5.7–6.1 seconds; this is a hypothesis about potential benefit, not measured end-to-end savings. Measure the complete operation with matched cloud runs before accepting further surgery. If safe ownership requires more machinery than it removes, keep the current design. No unresolved product decision blocks that audit; this handoff is a clean context boundary, not a claim that all performance work is finished.
