# Snapshot validation source audit — 2026-10-22

Outcome: locate repeated work in the measured ending path without changing runtime behavior. Build Lead owns integration; independent semantic audit completed. No Director architecture decision is needed for the next observation preparation.

## Evidence and source
Tested product5a506a9768287762b2a0e86f94d5eb0006562cc5; measured run39754741908. Five fetched source files match the retained tested-worktree SHA256 and Git blob identities in source-identities.json. Root AGENTS.md is absent; tested tree contains no AGENTS.md paths.

Accepted timing: Accept23.084004s; physical proofs188calls/1.438335s; snapshot24calls/22.095315s (pre-semantic10.005792s, semantic11.857665s, guards0.226114s). Categories overlap. This source audit assigns no new elapsed time.

## Independently reconstructed call graph
RunSnapshotSchema._validate_scene_observed_body directly invokes validate_scene_receipts, then _validate_scene_reading.
For a nonempty terminal checkpoint, _validate_scene_reading invokes terminal-admission authentication (one ledger traversal) and FrozenRunContext.validate_reading_checkpoint. Frozen's terminal helper authenticates terminal admission (one traversal) and the retained source scene checkpoint (one traversal). Total pre-semantic:4.

GameState.validate_scene_snapshot_semantics directly invokes the ledger validator, then FrozenRunContext.validate. Frozen.validate invokes the terminal helper, then its public validate_reading_checkpoint invokes that helper again. Each helper has two ledger traversals. Total semantic:5.

| Snapshot shape | Complete ledger traversals |
|---|---:|
| PLAYING | 3 |
| Empty PRIMARY_PENDING | 5 |
| Nonempty terminal ENDING/COMPLETED | 9 |

This predicts the observed physical-proof counts for the actual fixture:
- sequences4,4,2,3:9+9+3+5=26
- sequences5,5,3,4:9+9+5+9=32
- sequences6,6,4,5:9+9+9+9=36

The count agreement supports the source reconstruction, not timing attribution or permission to remove calls.

## Proof ownership and failure risks
- SceneEventContract.validate_scene_receipts: shape, canonical reconstruction, installed bundle, issuer custody, ordering, admissions and cross-command joins.
- Terminal admission: actual source admission/trigger, issuer ordering and reconstructed target.
- FrozenRunContext: retained source frames, source/active occurrence correspondence, ending presentation and reading frontier.
- GameState: live Profile assignment/current-byte references and actual retained-reading anchors.
- RunSnapshotSchema: full shape/lifecycle/owner sections, callback mutation and reentry rejection.

The complete ledger validator is not pure: committed initial admission calls SaveManager.capture_committed_scene_creation, validates initial material and reads issuer root custody. Reusing an old successful result can miss changed authority, alter callback count or first-refusal ordering. Public Frozen entry points also serve independent callers; removing their validation would weaken those callers. Saved bytes and all three recovery checkpoints remain binding obligations.

## Concrete repeated computation
Within SceneEventContract, validate_bundle_structure walks JSON/header/nested registries, builds tables and markers, validates cross-references, canonicalizes the complete bundle, computes its fingerprint and returns detached tables.

make_scene_receipt reaches bundle validation via inspect_scene, directly, through validate_scene_result (which also uses inspect_scene), and for transitions through scene_completion_request (which also uses inspect_scene plus its own bundle validation). This is a source-derived repeated-computation candidate; its cost has not yet been isolated. Do not label it the established root cause.

## Next bounded implementation
Prepare one opt-in observation candidate covering BOTH complete validate_scene_receipts and validate_bundle_structure, with calls/us/failures in existing writer scopes. Preserve one delegation to each unchanged original body and all calls/results/early refusals. Measuring parent and nested leaf in the same run avoids separate speculative retries; durations overlap and must never be summed.

Finish independent source/caller and packet review before one cloud execution. Retain unchanged120s child deadline, engine/input route and all existing source/custody/durable-state gates. No production simplification, cache, bypass, checkpoint coalescing, timeout extension or export replay is authorized by this audit.

Before any later simplification: test valid PLAYING/empty PRIMARY_PENDING/nonempty ENDING/COMPLETED; forged source/trigger/retained frame/frontier/command anchor; corrupt creation/Profile/issuer proof; combined-fault first refusal; direct callers of both Frozen entry points; mutation/reentry protections; and a matched complete-operation performance comparison. A static duplication finding is not a performance result.

## Checkpoint
Master41592fcc792aa615e47ee2ce2f05008ca195b311, PR36c8358870d3ece92d5f8cc7ba65aefe34a746be5c and integration3ae6d9138fb53c388380c78550cf6082eafc0ea3 remain unchanged. No runtime edit, new cloud run, local Godot/PowerShell execution, merge or release. General CI remains separately unqualified.
