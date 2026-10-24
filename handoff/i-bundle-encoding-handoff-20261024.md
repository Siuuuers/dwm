# Same-call bundle encoding reuse — 24 October 2026

Continues [the recall-local handoff](h-recall-local-proof-handoff-20261024.md). Base master is `ba7ecd57afaadac5f25df14d24300037e57edec6`; the preceding recall and journal work was already present and was not repeated. All Godot and PowerShell execution remained on Windows GitHub Actions. Local work was source review, Git, artifact verification and retention.

## Outcome and ownership

The selected current save restores the same complete visible caption and exact saved bytes while spending less time encoding its registration bundle. `SceneEventContract` remains the structural-validation owner; `CanonicalJsonWriter` remains the scalar/container encoding owner.

Runtime product `88e44efbf6d65cc3b70118e73923eb408db98b7e` changes only `_validate_bundle_structure_observed_body`. It retains the four successful nested-registry encodings that the same invocation already computed. At the existing final encoding stage, it sorts the header's exact ASCII keys, reuses those four strings, and passes every remaining value through the existing writer. The final SHA-256 remains the canonical whole-bundle fingerprint.

There is no persistent or cross-call cache, trust flag, new public API, manager, or saved field. JSON-domain admission, header/Contacts/audio checks, early nested refusals, all table/marker checks, fresh public admission, post-callback boundaries, and detached returned tables remain. The interval between retained encodings and composition is synchronous, read-only and callback-free. Do not broaden this reuse across an issuer or creation-owner callback.

## Attribution that selected the change

[Diagnostic run 40089000697](https://github.com/Siuuuers/dwm/actions/runs/40089000697), source `2ac7401b97f5029cd2aae3f4c90153d41a44af07`, passes two current native cases / 213 assertions / three clean process exits. In its `fresh_save_load` scope, 50 bundle validations total 9.925913 s:

| Phase | Seconds |
| --- | ---: |
| JSON-domain traversal | 1.368903 |
| Header and delegated owners | 0.035260 |
| Four nested registry encodings | 3.617857 |
| Final whole-bundle encoding | 4.153181 |
| Fingerprint preparation/hash | 0.132700 |
| Detached return copy | 0.041835 |

Nested and final encoding account for 78.29% of bundle time. Nested child timings are included in the nested total; do not add them twice. Instrumented phase counters report completed successful intervals, not independent validation proofs; early refusals would not emit a completed phase. The enclosing bundle counter retains actual failure tracking. Diagnostic totals include instrumentation overhead and are not performance-comparison evidence.

## Qualification and matched complete operations

[Run 40089558681](https://github.com/Siuuuers/dwm/actions/runs/40089558681), controller `bc6a43041c76996c3f3d8bdb6e0b801af97f9fdd`, passes all four jobs. Its only difference from the product is its isolated workflow override:

- Focused contract/canonical tests: 65 cases / 1,440 assertions. Five new cases contribute 81 assertions and cover versions 1–3, canonical encoding equivalence, Unicode/control/float content, depth-dependent encoder selection, refusal precedence, next-call freshness and detachment.
- Installed synthetic-registration composition: four cases / 47 assertions / one clean process exit.
- Rendered native recall: create 81 assertions and distinct-process Load 47 assertions, two current cases / two clean exits. The example is `never_started`; focused tests cover all five outcomes. Selected/restored captions agree; clock/focus differences mean those captures are not byte-identical.
- Matched complete Save/Load: baseline master and candidate on one Windows runner, baseline first, exact separate worktrees, identical helpers and retained input, checksum-pinned Godot 4.6.3. Four current cases / 426 assertions / six clean exits. Historical input reports are excluded.

| Complete observation | Baseline | Candidate | Reduction |
| --- | ---: | ---: | ---: |
| Fresh-process Load press to Ready | 43.850640 s | 40.554829 s | 7.52% |
| Retained-input Load press to Ready | 70.255430 s | 64.788440 s | 7.78% |
| Save press to return | 39.880089 s | 34.117912 s | 14.45% |
| Complete helper journey | 308.258550 s | 287.949512 s | 6.59% |

Both variants retain 50 bundle, 42 receipt and 42 physical-proof calls in `fresh_save_load`, with zero failures. Bundle time falls 8.822777 → 5.648775 s; receipt time falls 19.589145 → 16.440625 s. These are inclusive overlapping totals. Do not add their savings. Final restored captions are complete/readable; comparison captures are byte-identical, SHA-256 `518dc6bccd41ef7ef77da8963cb6ba7216de4b48a2f8f81b892262dd25e4502a`.

This is one ordered pair, not a latency distribution or hardware guarantee. A 40.55-second fresh Load remains far from smooth. This qualification is not an uninterrupted authored-week test, exported-gameplay test, or Steam upload. Steam BuildID 26179529 from the preceding handoff does not contain this new change.

Four inventory generate/check processes pass. The generated inventories refresh only 34 caller line references (GameState 33, SaveManager 1); no public surface or required contract changes. Final publication adds only those inventories, this handoff, and evidence to the qualified runtime/tests. Diagnostic and qualification workflow overrides stay off master.

## Evidence and continuing work

[Attribution](../evidence/phase_2r/bundle_encoding_20261024/attribution-results.json), [focused tests](../evidence/phase_2r/bundle_encoding_20261024/focused-results.json), [installed compatibility](../evidence/phase_2r/bundle_encoding_20261024/compatibility-results.json), [native recall](../evidence/phase_2r/bundle_encoding_20261024/recall-results.json), and [matched comparison](../evidence/phase_2r/bundle_encoding_20261024/comparison-results.json) retain source/artifact provenance. Adjacent compact ZIPs preserve exact retained bytes; manifests account for all original members, their hashes, and retention/omission. Original archive sizes/SHA-256/CRC and every retained member were independently verified. Source/refusal review completed before qualification; evidence review completed before publication.

The owner added two investigations during this batch:

1. Some numbers are unreadable, and text reportedly becomes broadly corrupted at 125%/150%, especially non-English. The exact user build, font style and display conditions remain unconfirmed; the owner has not yet tested Readable mode. Pixel 100/125/150 selects separate 8/10/12px Fusion faces, while Readable resizes its regional family. Initial [Windows diagnostic 40090259974](https://github.com/Siuuuers/dwm/actions/runs/40090259974), source `ad82c5f3857bb564a1d670ba7075a5fecc611f3c`, produced 12 legible synthetic panels covering both modes, all three sizes and five languages, with production Minesweeper cells. Both native D3D12/Forward+ and OpenGL/ANGLE ran successfully on Microsoft software adapters. This does not reproduce or dismiss the user's symptom. The real Settings font stack and main-window scaling require follow-up. Issue #73 was closed administratively after the owner clarified that no separate GitHub issue was requested; the defect is **not** marked fixed. Keep findings here and use a PR for a concrete fix.
2. Measure process launch → usable Title and the actual **New Acc** menu action → first complete visible caption. Resource loading is a hypothesis, not an established cause. Distinguish clean first launch, retained profile, confirmation preparation and accepted creation. Existing Save/Load timings are not launch-to-Title or New Acc evidence. A separate investigation is assigned; no product change is selected yet.

For remaining Load work, retain the candidate's complete log and its eight snapshot-validation observations. Equal checkpoint sequence numbers alone do not establish identical inputs or permit reuse across callbacks. Attribute exact caller/input boundaries before selecting further surgery. Do not rerun completed comparisons merely to rediscover their conclusions.
