# Pure scene-receipt reconstruction: matched comparison

Updated 19 October 2026 Hong Kong time (18 October UTC).

**Decision: retain the candidate as a promising isolated experiment. Do not promote its runtime to PR36 yet.** The exact new guard tests pass on both the original contract and candidate. All four measured complete forward operations are faster in this one same-host pair. Both original exported Load journeys still fail the ending gate, so ending, Gallery and normal Load exit remain unqualified.

## Observable outcome and ownership

SceneEventContract should construct the same detached receipt, or return the same first refusal, while avoiding repeated pure reconstruction from values already validated within that invocation. SceneEventContract remains the owner. Public wrappers still validate standalone callers fully. Independent receipt authorities, SaveManager/Profile authentication, recovery, history and both durable checkpoints remain.

The candidate changes exactly two files relative to the diagnostic baseline:

- scripts/domain/narrative/SceneEventContract.gd: extract the result and completion field-construction tails; consume the same-call inspection and registered tables in make_scene_receipt.
- tests/unit/test_scene_event_contract.gd: add conflicting-invalid-input refusal tests and strengthen complete output/nonmutation/detachment checks.

The runtime diff is 22 added / 11 removed lines. The test diff is 127 added / 4 removed lines. Three tests were added (25 to 28); existing terminal and detachment tests were expanded. No public authentication call is shared or deleted, no cross-call cache or new manager is introduced, and the rejected fused-normalization experiment remains excluded.

Important failure ordering remains envelope/registration, source anchor, result, completion source/target, matching, detached output. Independent review checked the fixed JSON/manifest validators for yields, caller callbacks and mutation before the cloud run. Public source refusal and terminal responsibilities remain separate.

## Exact identities

| Item | Identity |
| --- | --- |
| Cloud run | https://github.com/Siuuuers/dwm/actions/runs/39149704882 |
| Job | 117740646294 |
| Baseline source | 7d427a8bd2ef94210662c3dbfa0b1c3b958f1ab1 |
| Baseline tree | c11bcd745193342bbc3270cb103a5be7ce90e234 |
| Candidate source | 4963a847f0a7e2da82a87f29d1a27a7b8256eae1 |
| Candidate tree | 588074015df4dec61b01941c4db08efd4d379911 |
| Candidate branch | codex/a-receipt-reconstruction-20261019 |
| Controller | fc798c47bf124e0d7a482e1231f58b75091e4e09 |
| Controller workflow | .github/workflows/scene-first-reveal-profile-diagnostic.yml |
| PR36 runtime at checkpoint | bf1c46715f0698dbcf9c2b9d1ca6e946a6dde74f |
| Godot | 4.6.3 standard GDScript, 4.6.3.stable |
| Candidate package artifact | 12144741833, forward-profile-package-39149704882-1 |
| Candidate inner executable ZIP SHA256 | 7bf135deca3dea79564548cae6637a9f7b6c71f9607748b9b62573bf4e003674 |
| Baseline package artifact | 12142044709 from run39145021649 |
| Baseline inner executable ZIP SHA256 | 61b04151e54ccb379de9cb0e199715c83002ab0cf7025c7ccfeeb2340ef820f3 |

Both retained executable artifacts expire 25 October UTC. This repository retains the original diagnostic evidence ZIP, not a substitute build. Candidate and baseline executable binary SHA256 match because the engine is unchanged; their PCK hashes differ as expected.

The candidate contract Git blob is 30a65a65cab298b36e01eeee82362888339f2ed1 (80860 bytes). The new unit-test blob is cde011002b3332325f58afe5c2f79f33af7b8468 (31847 bytes). Remote refetch and original archived source match these pins.

## Matched method

One Windows2022 host ran baseline Capability → Create → Load, then candidate Capability → Create → Load, in separate profile roots. Driver bytes are identical: Invoke-ExportedGameplay.ps1 SHA256 0e819db31a69824934b771442b7a19c540b54b4c706192fcb152556c2f7a116b. Settings remain Always accessibility, Dummy audio, ProjectDefault renderer, 30-second original step deadline and 480-second journey deadline. Load uses ProfileSaveLoad, ContinueAfterQuiet, TraceDay5 and NativeReadyCaptions.

The baseline executable came from the exact previously retained artifact and its source receipt/inner ZIP hash were verified. The candidate was freshly exported and retained. Import, parser checks and four original-deadline test cases passed. No Godot or PowerShell ran locally.

The two three-mode steps used continue-on-error to ensure both variants retained original results. GitHub's normalized step conclusions therefore displayed success even though both driver outcomes were failure. **Use result.json, process records and comparison-acceptance.json, never those normalized step conclusions, as the outcome authority.** The final workflow correctly failed. Neither composite step hit its 10-minute outer ceiling; that ceiling did not cause or truncate these failures. A subsequent single-source diagnostic will use three explicit mode steps without changing player deadlines.

## Focused qualification

| Suite | Candidate tests | Candidate XML assertions |
| --- | ---: | ---: |
| Scene event contract | 28 | 317 |
| Scene receipt validation | 9 | 99 |
| Scene transition identity | 7 | 68 |
| Scene terminal lifecycle | 5 | 120 |
| Saved scene event anchor integration | 8 | 173 |
| Total | 57 | 777 |

The exact new contract and receipt-validation test bodies also ran against the original baseline contract: **37 tests / 416 assertions**, both isolated exits0. This is a compatibility execution, not 37 additional distinct tests. The shared cases have identical per-test assertion counts. All seven executions have source-derived exact test-method censuses, clean isolated and wrapper exits0, no failure/error/skip or zero-assertion methods.

The new multi-fault coverage checks five invalid envelope/registration combinations across all three public APIs, six maker refusal-order cases and five standalone completion cases. Complete returned dictionaries, retry behavior, terminal projections and both directions of deep detachment are covered. This bounded suite is not a claim of arbitrary interruption or whole-game coverage.

## Original exported outcomes

| Variant | Mode | Raw result | Clean player exit | Forced cleanup | Player / driver exit |
| --- | --- | --- | --- | --- | --- |
| Baseline | Capability | Pass | Yes | No | 0 / 0 |
| Baseline | Create | Pass | Yes | No | 0 / 0 |
| Baseline | Load | Fail | No | Yes | -1 / 1 |
| Candidate | Capability | Pass | Yes | No | 0 / 0 |
| Candidate | Create | Pass | Yes | No | 0 / 0 |
| Candidate | Load | Fail | No | Yes | -1 / 1 |

Both Load failures are UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending. Original Load process elapsed times are 275.1382115 seconds baseline and 228.0628225 seconds candidate. Those totals include diagnostics and forced cleanup, and are not successful journey durations.

In each variant, the created slot1 is byte-identical in the quiet-before, quiet-after and failure snapshots. Slot2 is byte-identical across quiet-before, quiet-after, restored and failure snapshots. These concrete immutable-slot observations do not establish arbitrary saved documents are identical. The ending failure occurs before the requested Gallery/Title/normal-exit journey is accepted.

## Timing results

Use only each primary Load game.stdout.log once. Each contains 112 profile records and identical scope counts. Do not combine those records with the duplicated engine log or nested mode receipts.

| Complete forward operation in driver order | Baseline seconds | Candidate seconds | Reduction |
| --- | ---: | ---: | ---: |
| Day4 → Day5 | 28.612525 | 20.871939 | 27.05% |
| Day5 → Day6 | 25.467650 | 18.370583 | 27.87% |
| Day6 → Day7 | 28.853933 | 20.785976 | 27.96% |
| Day7 → ending | 35.676444 | 24.781450 | 30.54% |
| Four disjoint complete operations | 118.610552 | 84.809948 | 28.50% |

These are complete scene_forward_total scopes, not UI-ready timings. The ending row is a completed internal forward operation inside an exported journey that failed its external gate.

| Nested diagnostic group | Samples per variant | Baseline seconds | Candidate seconds |
| --- | ---: | ---: | ---: |
| Checkpoint preparation elapsed | 8 | 53.871776 | 38.492171 |
| Checkpoint commit elapsed | 8 | 53.307675 | 38.096150 |
| Prepare receipt event reconstruction/authentication/group | 8 | 4.261062 | 1.581803 |
| Commit receipt event reconstruction/authentication/group | 8 | 4.307449 | 1.591468 |

**Do not add these nested rows to one another or to complete forward totals.** The event subgroup falls approximately63%; initial and other admission timing remains within about1%, supporting targeted attribution. Each prepare and commit stream still records32 receipt calls,32 completions,124 events,32 initial admissions and116 other admissions. Both commit streams retain32 history bundles and1533828 document bytes. All eight checkpoint commits, including the first nonspliced one, improved in this sample.

This is one fixed-order, same-host pair. It supports a promising measured reduction and preserves a falsifiable candidate. It does not establish a population speedup, default nonprofiled performance, an ending fix or whole-game acceptance.

## Ending evidence and next discriminator

Baseline's last forward takes35.676444 seconds. Its original ending wait contains261 native samples, none responsive, and no action enumerations. The gate fails after30.0073665 seconds.

Candidate's last forward takes24.781450 seconds. Its original HWND590140/PID7924 is responsive by24.8780832 seconds;21 subsequent ending action enumerations return zero matches through29.8759667 seconds. The unchanged gate fails at30.0209089 seconds.

Both later failure screenshots have SHA25679ce1d4123d93cb6f37290ddc8e9bec6ef560c60652db7457d7fc3c7bfe5adc4 and visibly show the ending text plus History/Save/Load/Skip/Auto/Next. The screenshots and accessibility observations occur sequentially. They do not prove simultaneous disagreement or a particular engine cache/container cause.

This extends the earlier retained ending discriminator; do not repeat equivalent Raw/FindAll polling merely to restate it. The next bounded diagnostic observes existing caption/control publication: actual parent/order/generation, hidden/withdrawn state and pending Next state during existing accessibility notifications. It must not request an accessibility refresh, allocate an extra RID just for observation, change input/checkpoint/timer behavior, or weaken any deadline. The candidate remains isolated while this is resolved.

## Safe future composition boundary

The diagnostic branch has nine pre-existing source/tool differences from PR36's common ancestor. An independent audit found five GDScript runtime profiling files plus one meaningful integration test compatible with the new unit test. No rejected normalization patch or competing product runtime edit exists.

The diagnostic PowerShell driver also changes bare Load behavior: every Load slot2 save enters a quiet observation and stops unless ContinueAfterQuiet is supplied. PR36's ordinary driver does not do this. Therefore do not blindly transplant the diagnostic tools or install their new deadline test alone against the older driver.

If later acceptance supports promotion, use exact tested whole blobs for DialogicBridge.gd, GameState.gd, SceneEventContract.gd, RunSnapshotSchema.gd, SaveDocumentSchema.gd, test_scene_saved_event_anchor.gd and test_scene_event_contract.gd. Preserve PR36's reports and ordinary PowerShell tools, and pin the diagnostic driver separately. Report runtime/test source equivalence precisely; a composed repository tree is not the complete tested experiment tree.

## Evidence verification and limits

Original archive: **4458612 bytes**, SHA256 **77fc1b8b8506df4cec89542a2762a7b954deb7174d465ff549bcbd11eb01c6c4**. There are411 exact ZIP members:410 outer-manifest entries plus the manifest. All298 per-mode manifest entries were rehashed. All25 baseline and25 candidate source blobs plus the controller match pinned source identities. No unexpected tracked product source changes remain after import/export; the two predeclared disposable-checkout gitlink removals and generated untracked imports are retained in the original status record. Original failed results remain unchanged.

Run the retained verifier without executing game or driver code:

    python3 verify.py original-evidence.zip archive-receipt.json verification-recheck.json

The adjacent diagnostic-tree-index.json is the25-source subset of the GitHub baseline tree needed by this verifier. **Verifier exit0 means archive authenticity plus focused qualification, not E2E acceptance.** Read original_journeys_passed, which is false. verification.json retains the original independent analysis, including failures and original timing fields grouped by scope/action.

The coordinator and two independent internal agents inspected source, original outcomes and timing evidence. This is not a claim that external Coordinator C reviewed this run. PR36 stays draft/unmerged. Master and integration are unchanged. Broad CI, the queued historical-fixture corrections, relevant integration cleanup and final existing-author-guide reconciliation remain open.
