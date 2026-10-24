# Save/Load validator audit — 25 October 2026

## Owner-approved replacement direction — later 25 October discussion

**Status:** requirements approved by the owner in the Save/Load discussion after PR83; implementation and performance qualification are pending. The audit below describes the existing architecture. Its reasons for retaining historical proofs do not require keeping that architecture. This section supersedes the earlier preference to optimize only duplicate terminal traversals as the immediate design direction.

The owner requires a compact save of current state, restored without replaying past actions. Preserve the current DTL beat (restore the full caption), current Challenge/board, affection, earlier choices and Challenge outcomes that affect later play, money, owned inventory/capabilities, shop purchases, pressure, penalties and daily round limits. Preserve the necessary counters and reward-claim state of those active mechanics; do not silently reset them because they were not individually named. Do not infer retirement of coins or active rewards from the shorter list of headline requirements.

Global storage keeps gallery unlocks and previously read text. Run loading must not rewind those global records. Retire `friend_attitude`, `friends`, and `inter_friend_affection` from gameplay, capture, restoration and validation; affection remains. Identify dependent presentation paths and tests rather than deleting identifiers by substring (`friends_changed` currently also signals affection).

Remove `save_reason`, `audio_context`, and `active_app_id` from the proposed player-save payload. Save reason may remain an operation/logging label, not a load-admission condition. The owner states that music is determined by the DTL position; derive the applicable music without replaying gameplay effects. Exact audio playback-offset restoration is not required by this decision. Resume the required gameplay surface without persisting the previously open application. Do not discard the active board.

Remove the ending's retained source-reading checkpoint from the replacement save. The owner has confirmed one ending for each of two earlier DTL forks, two endings total; the [story owner](../../story/09-priscilla-foundation-amendment.md#save-and-ending-scope-refinement-2026-10-25) records that scoped change. Use the chosen fork and direct ending resume position rather than historical source-reading proof. This records intended behavior, not a claim that current DTL already implements both endpoints.

The recommended implementation is to eliminate the saved command-history ledger and its historical validators after establishing direct state restoration. The owner asked for this recommendation; do not represent the current ledger as already deleted. Preserve any small required choice/outcome state independently before removing the history that currently carries it. Keep minimal required-field/type/range/position checks and safe file writing. Missing or incompatible optional metadata must not reject otherwise usable required state. Do not silently reinterpret incompatible required gameplay data. No old-save migration or injected mid-call mutation requirement is introduced.

### Existing implementation evidence and unresolved details

Inspected baseline: PR83 merge `2ebb30a450a832ad892bd08cc4ae968d39dfff9f`.

- `SceneEventContract` already supports `thought.select`, `choice_id`, target selection and `thought_resolved` results; `DialogicBridge` accepts these scene envelopes. This establishes an existing choice mechanism, not implementation of the owner's new, not-yet-announced choice design. Record stable choice/opportunity and selected-option identifiers in the replacement save. The new choice rules, placement and presentation remain unspecified.
- `RunNotePurchaseRules` uses `shop_purchase_counts` for note purchasing and caps. `GameStateMinesweeperShopPort` also grants inventory, and `MinesweeperCapabilityRules.resolve_owned` reads it. Current purchase counts do not prove all owned capabilities. Retain inventory until a caller audit establishes a single complete owner; do not reconstruct it from incomplete purchase counts.
- DTL position must resolve the correct background/music/presentation without executing preceding consequences. Inspect actual authored commands and branching before choosing a reconstruction method; a line number alone is not assumed sufficient.
- The two fork endpoint identifiers and any unfinished authored route remain implementation questions. The owner did not specify replacement ending text, new choice UI, or a mapping for obsolete endpoint identifiers.

### First replacement acceptance journey

Save during a real DTL beat with an unfinished Challenge/board, non-default affection, earlier choice/outcome state and active economy values. Load in a fresh Windows cloud process. Verify the same full caption, correct background/music derived from DTL, exact board and values, normal input, and the same subsequent branch. Verify loading does not repeat purchases, charges, rewards or affection changes; global unlocks/read history remain. Cover both ending forks when their authored endpoints are available. Compare complete Save/Load operations against PR83. Do not claim a speedup or remove the old production path solely because a smaller JSON example works.

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
