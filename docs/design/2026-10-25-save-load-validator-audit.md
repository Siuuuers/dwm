# Save/Load validator audit — 25 October 2026

## Observable outcome

Loading a current save restores the same playable board and complete visible caption, with the recorded consequences applied once. Invalid persisted state is refused before live owners adopt it. This audit does not introduce migration, recovery or injected mid-call mutation requirements.

Validation is not inherently untouchable. Retain the facts needed for the outcome, give each fact one owner, and remove repeated execution when the existing owner's successful result is available within the same unchanged operation. Function names and test counts alone do not justify retaining code.

## What the current checks establish

| Owner and check | Concrete reason to retain the behavior | Simplification boundary |
| --- | --- | --- |
| `SaveManager._prepare_restore`: selected bytes, JSON, current format and revision | A truncated file, unsupported document or changed selected slot must not become live state. | Keep simple refusal. No old-save conversion is required. `SaveMigrations` currently also owns admission and locator checks; its name does not make the whole file obsolete. |
| `RunSnapshotSchema._validate_scene_observed_body`: structure, Run identity, lifecycle and gameplay ranges | Missing members, mixed Run records and inconsistent gameplay state cannot be applied safely. | Keep necessary shape checks before typed reads. Audit repeated checks separately. |
| `DesktopBoardState.prepare_restore_scene`: board state and identity | Load must restore the saved playable board. | Prefer this canonical owner; do not add another board validator. |
| `SceneEventContract.validate_scene_receipts`: command/admission relationships | Recorded transitions and effects must agree with their source and order; otherwise restoration can disagree with recorded consequences. | Keep one authoritative traversal of unchanged receipts. This is a consistency obligation, not a claim of anti-cheat security. |
| `FrozenRunContext` and the reading session: frame, caption and cursor | A valid command history can still be paired with another occurrence's displayed caption or reading position. | Reuse admitted material, but receipt validity alone cannot replace the frame checks. |
| `GameState` and the reading bridge: command-to-reading anchors | A command's claimed publication must exist in the retained reading ledger. | Reuse the restored session where possible. Preserve this cross-owner join. |
| `ProfileManager.prove_scene_assignment` and `GameState` Profile references | A restored Run must agree with the persisted assignment and relevant Challenge history. | Current physical Profile proof is distinct from in-memory history. Historical reconstruction can be measured independently. |

## What PR83 removes

Normalization already returns a detached candidate, and registration already returns a detached bundle. The concrete semantic validators read these synchronously. The extra copies and before/after whole-tree hashes existed to detect injected callback mutation during that call. That scenario is outside the approved product contract, so those guards can be removed without deleting the actual receipt, Profile or reading checks.

PR83 retains result validation, reentrancy protection, owner matching and fallback. Its replacement integration tests cover nested detachment, unchanged live gameplay state, and fresh refusal after later corruption. See the [qualified evidence](../../evidence/phase_2r/snapshot_semantics_20261025/README.md).

## Next removal candidate: outer terminal receipt traversal

In the qualified candidate, `RunSnapshotSchema._validate_scene_observed_body` explicitly traverses receipts for terminal snapshots. For a nonempty terminal checkpoint, it then calls `_validate_scene_reading`, which reaches `FrozenRunContext._validate_scene_terminal` and `SceneEventContract._validate_selected_scene_terminal_with_ledger`. That inner path traverses the same ledger and uses its result to prove the ending trigger and source frame. The outer result is only checked for success.

Investigate deferring the outer traversal when the canonical owners match and a nonempty terminal checkpoint guarantees the inner validation. Keep the earlier cheap receipt-shape checks, the inner traversal, and independent behavior for unmatched owners and empty terminal boundaries. This is separate from the inner terminal/source duplication already removed by PR82.

Before editing, measure both passes in one complete Save/Load workload. After editing, verify the exact restored state, complete caption, consequence behavior, current Profile checks, and refusal after later invalid input. Compare complete operations in both orders. Combined-invalid-input refusal ordering can change and must be recorded. No persistent cache or new manager is needed by this proposal.

This audit identifies a candidate; it does not claim that the next removal is implemented or faster. A broader redesign could remove further historical requirements, but that would require identifying the player-visible behavior being changed rather than silently dropping checks.
