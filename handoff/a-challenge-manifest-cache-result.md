# Challenge timeout diagnosis and manifest-cache qualification

Owner: Coordinator A. Base PR36 source `f8b873bd5e0df1dbab2ffaec9301c87d487de74e`.
Scope: the existing debug certification / refused checkpoint / owner reconstruction / retry test. Accepted first-Reveal campaign is not repeated. No broad CI, merge or release claim.

## Observable outcome and ownership

The existing certification/recovery test must finish within its unchanged 600-second child limit with its original assertions. MinesweeperBoardGenerator owns runtime manifest admission; DatingChallengeEnvelope retains replay validation; Profile and Run retain existing durability ordering. No saved schema, RNG, search budget, fallback adoption or history guarantee changes.

## Diagnosis and ablations

| Cloud run | Candidate | Result |
| --- | --- | --- |
| 38834205151 | f8b873bd, observation-only test patch | First debug Reveal 95.798s; 180s timeout before first prepare returned. |
| 38834692618 | 35dffc25, budget cache and initial safety tests | Invalid campaign: 180s safety timeout caused by huge success diagnostics; matched probe skipped. Shallow source checkout also prevented complete evidence capture. Original artifact retained. No tests credited. |
| 38835195782 | 2e619cde, identical runtime with concise safety diagnostics | 6 tests / 97 assertions pass; first Reveal 86.821s; same 180s timeout before first prepare returned. |
| 38836581369 | 92cac934, budget and fallback caches | 12 safety tests / 238 assertions pass. First Reveal 4.931s; three recovery cycles complete and active board reached. Sole intended probe failure. |
| 38836949881 | 92cac934, strict acceptance setup | Stopped before tests: canonical GameState inventory stale. Exactly three new lexical test references identified across both inventories; no runtime caller change. |
| 38837389156 | 92cac934 plus guarded cloud-generated inventories | Accepted bounded gate: 50 passed / 455 assertions; two explicitly allowed historical absence-only pending cases. Original recovery case passes in 22.175s. |

The observation-only test selects the existing final test, caps its loop at three, and deliberately fails if completed. It is never gameplay acceptance. First Reveal ends at slice 0 / operations 0; its delay precedes candidate search replay. This motivated the fallback parse-cache ablation. Search-prefix replay and source freshness still run as before.

## Change boundaries

Each cache retains only a successful strict-JSON parse and schema validation for exactly matching current bytes. Missing resources still refuse, changed bytes are reparsed and checked, and caller-visible data is deeply detached. Budget freshness is checked on every read including warm cache hits. Fallback adoption independently validates its record as before. No failed result is cached. Only one successful content version is retained per manifest.

Twelve focused tests exercise cold/warm mutation isolation, same-length malformed input, invalid schema, absence, valid replacement bytes, dependency drift, and public stale-fallback rejection even after modified fallback data has been cached. Every test restores exact resource bytes. The generated test UID comes from actual Godot cloud import, not invention.

Independent source review found no blocker in either bounded cache change. Cloud runtime qualification is recorded below.

## Evidence limits

The failed verbose campaign lacks a manifest/full captured source and cannot establish a frozen-tree census. The baseline and concise budget-only runs have independently checked archive manifests and reconstructed frozen trees. No baseline or bounded probe is counted as a successful gameplay test. All engine execution is cloud-only with Godot 4.6.3 standard, version and download SHA pinned.

PR36 remains draft. Broader CI and later-caption coherence remain separate work.

## PR1 duplicate-work check

User asked whether first Reveal was already fixed in PR1. Current PR1 head `a6decec3693ee4d57df9f879b90ace3e118c9d1d` has byte-identical `_read_budget_manifest` and `_read_fallback_manifest` function sections to the pre-change PR36 source, without caches. The scene-specific test file is absent there. This work addresses the separate Challenge timeout, not a redo of accepted first-Reveal behavior. Current master remained `0c8b2384415d71bd3de4ff7408640bbf60b63740`; integration remained `3ae6d9138fb53c388380c78550cf6082eafc0ea3`.

## Final bounded acceptance

Published source `3de1b6cf2b37a47d018867ad67ad91f2a150c8d1` exactly reproduces tested tree `3563b4ba7101ca264e73ff7affe911c09e5af6f7`. Cloud-frozen commit `4576a3964d8645e7127f62de0cbcbf73bc921b57`; run [38837389156](https://github.com/Siuuuers/dwm/actions/runs/38837389156), job116769449970, controller9076f385ebe164b2fa7e5351b88c2e63c7b14511.

Independent audit verifies ZIP 461556 bytes / SHA256 `afd0871b7a9c9691c4f692514721a7986038784324128cd10e690a9359d8fedc`, CRC clean, all 33 manifest entries, clean final source, exact source-derived XML census, positive assertions, no failure/error markers, and all seven subprocess exits 0 (four canonical-surface generation/check children plus three test suites).

| Suite | Passed | Pending | Assertions |
| --- | ---: | ---: | ---: |
| Manifest cache safety | 12 | 0 | 238 |
| Existing board generator | 28 | 2 | 75 |
| Original scene first-Reveal suite | 10 | 0 | 142 |
| Total | 50 | 2 | 455 |

The two historical pending tests apply only when generated manifests are absent. This checkout contains the manifests; new real-path safety tests explicitly remove and restore them to exercise refusal. Pending cases are not counted as passes.

The original certification/refusal/reconstruction/retry case passes 36 assertions in 22.175197 seconds. Its full 10-test scene child finishes in 40.368643 seconds, under the unchanged 600-second ceiling. The test source remains byte-identical to f8b873bd (SHA256 `5f4c3f7ce4ebb4998d4f6f0c80dae6b80165160006a9090a166b92281ebd764f`); no shortened loop or weakened assertions entered the product source.

Two canonical inventory files contain only three lexical test-site additions: GameState `penalty_points_today` at new test line185; SaveManager `STRICT_JSON` at lines5 and113. The workflow refuses any other semantic JSON change, runs the existing strict generators/checks, freezes the files, and then tests that exact source. This is metadata maintenance, not additional public runtime callers.

The matched first-Reveal intervals 95.798s →86.821s →4.931s are single diagnostic observations, not a general frame-time, cold/warm distribution or whole-game performance guarantee. The completed original recovery test establishes closure of this concrete timeout on this exact candidate.

## Retention and next owner

All six original cloud evidence archives and their independent audits are preserved under [evidence/challenge_manifest_cache](../evidence/challenge_manifest_cache), including both failed qualification attempts. No prior first-Reveal receipt is replaced. No local Godot or PowerShell was run.

Next owner A: continue remaining concrete integration gates and the already diagnosed ordinary later-caption coherence slice, then PR37 composition. PR36 remains draft/unmerged; master and integration are unchanged. No full CI, rendered player-journey, production route, release or whole-game completion claim is made by this focused campaign.
