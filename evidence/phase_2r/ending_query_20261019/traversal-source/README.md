# Pinned sibling traversal defect — focused cloud proof

Observable outcome: a reachable included sibling remains discoverable after a transparent leaf followed by an excluded subtree. AccessKit consumer's sibling iterator owns this behavior. The fixture calls the actual pinned library; it does not implement a substitute traversal algorithm.

[Cloud run39234407866](https://github.com/Siuuuers/dwm/actions/runs/39234407866), job117999882218, completed success on Windows2022 / Rust1.85.0. Source27dd7a7d0e2c064451d40aa4ce44fdca751be878, tree133a34ae5445e67764241a62b268b14ef74d5ac7; controllerf5942c8eeda16e5463872fddb743f335ea423083. The source lives on isolated branch codex/a-consumer-traversal-regression-20261019. No Godot/game/PowerShell test or native engine build was executed in this experiment.

| Same selected tests | Original consumer | Two-assignment candidate |
|---|---:|---:|
| Existing iterator tests | 12 pass | 12 pass |
| Excluded-leaf controls | 2 pass | 2 pass |
| New excluded-child regressions | 4 fail | 4 pass |
| Total | 14 pass / 4 fail; exit101 | 18 pass / 0 fail; exit0 |

All four failures are the forward/reverse explicit-filter/common-filter cases. Both runs use identical six added test bodies and the same resolved dependency lock with `--locked`. The178 filtered-out tests were not executed and are not counted. Original failure is expected by the experiment, retained intact, and is not relabeled as a passing baseline.

## Correction and limits

In `next_filtered_sibling` and `previous_filtered_sibling`, the original sibling branch only sets `consider_children=true` for ExcludeNode. It fails to reset a previous true value for ExcludeSubtree. This enters a subtree that must be skipped, then can terminate at its excluded parent before reaching a visible sibling. The candidate replaces exactly those two conditional assignments with `consider_children = result == FilterResult::ExcludeNode;`.

The executed cases establish the pinned library defect and bounded correction. They do **not** establish its responsibility for the game's live ending failure, qualify an official Godot export, or justify changing saves/history. Query requests71/145 are consistent with erroneous descent and ascent, but lack same-query topology and phase identities. Do not count constructor back-boundary evaluations as a single forward walk.

Next useful evidence: consume the concrete native-result review, then inspect ordered children and reciprocal parents at the affected layout/art boundary within the same natural Navigate read snapshot, including the actual branch/termination decision. A bounded causal comparison with the corrected iterator is now a concrete option, but remains a separately identified diagnostic requiring source/dependency custody and the unchanged30s/480s gates. Do not promote this Rust source into product or replace the official engine solely on these synthetic results.

## Provenance and reproducibility

Original Actions ZIP `cloud-evidence.zip`, artifact12178388829:74,081 bytes, SHA256ba2ad11d2e89e1d8b2047bcf3e7261e5d6edf9800fe6fec97fc831513727bd2b. All14 manifest payloads are present and hash/size matching; ZIP CRC passes. Archive retains original crate, original/corrected source, six tests, runner, seed/resolved locks, baseline/candidate logs, controller/source origin, and receipt.

Published accesskit_consumer0.35.0 crate checksum53cf47daed85312e763fbf85ceca136e0d7abc68e0a7e12abe11f48172bc3b10 is checked before extraction. Its iterator bytes exactly match the primary source at AccessKit/accesskit1bbcf100942bac96c2c3a4a91cb67b0b20201a24, Git blobf9783f130806435d53ba276192c3bb324236839a, SHA25622233da2a6c999c355b74edddbf80fc98c6f32bd52f55de2bacd523f013824a7. Candidate source SHA2567d2f876b4744af77b576ea35726ebb5c3943bf8f01b61595e61a9ad8dd1f4fa5. The adjacent source-ref.json and source-review.md distinguish upstream source, internal review, execution and unproven game causality.

Initial controllerbe68fe519ce7153ab715bd545351c652f46a092e/run39234300874/job117999539210 failed checkout on pre-existing broken skill gitlinks. No test compiled/executed and no evidence artifact existed. `checkout-failed.log` preserves the decoded connector log with normalized line endings. The corrected controller uses the established persist-credentials/index-cleanup pattern; source and test bodies were unchanged. Do not count the checkout attempt as a baseline test failure.

Product PR36 receives this evidence/restart update only. The isolated correction is not shipped. Master/integration remain unchanged, PRs stay draft/unmerged, broad CI and official ending/durable Gallery/Title/normal Load exit remain unqualified.
