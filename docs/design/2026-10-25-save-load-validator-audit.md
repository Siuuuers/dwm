# Save/Load validator audit — 25 October 2026

## Ordinary passage marker experiment — corrected owner decision

The owner clarified that two markers bracket an ordinary DTL ending passage. Start is passive; Finish unlocks its Gallery passage and returns to title. There is no separate ending selector or extra ending text screen. Production DTL and boundaries remain undecided: this increment uses explicitly temporary test prose only.

The initial supported range is one paired `passage.start` / `passage.finish` per ordinary scene entry, identified by the same `passage_id`. Start follows the preceding caption (exclusive); Finish follows the last passage caption (inclusive). Native registration rejects jumps anywhere in that entry and non-caption controls within the range. Gallery displays exactly those registered captions through the existing read-only card surface; it dispatches no gameplay controls and writes neither Run nor Profile.

Finish first durably records the idempotent Profile unlock, then saves the ordinary current-caption checkpoint with lifecycle `COMPLETED`. No `ending_plan` or copied source checkpoint is introduced. A Profile failure leaves no unlock or Run completion. A subsequent Run write failure leaves the reached-Finish discovery global, retains the last caption and PLAYING state, and offers Retry; only successful Run completion permits title return. Fresh Load of a pre-Finish save restores the caption; Load of a completed save retires to title after restoration. Loading never rewinds Gallery discovery.

This is a mechanism experiment, not completion of the larger compact-save migration: existing command receipts still authenticate Finish and all other scene commands. Legacy ending fixtures retain their current compatibility path. Cloud qualification is required before acceptance; see `evidence/phase_2r/ordinary_passage_markers_20261025/README.md`.

## Owner-approved replacement direction — later 25 October discussion

**Status:** requirements approved by the owner in the Save/Load discussion after PR83; implementation and performance qualification are pending. The audit below describes the existing architecture. Its reasons for retaining historical proofs do not require keeping that architecture. This section supersedes the earlier preference to optimize only duplicate terminal traversals as the immediate design direction.

The owner requires a compact save of current state, restored without replaying past actions. Preserve the current DTL beat (restore the full caption), current Challenge/board, earlier choices and Challenge outcomes that affect later play, money, owned inventory/capabilities, shop purchases, pressure, penalties and daily round limits. Preserve the necessary counters and reward-claim state of those active mechanics; do not silently reset them because they were not individually named. Do not infer retirement of coins or active rewards from the shorter list of headline requirements.

Global storage keeps gallery unlocks and previously read text. Run loading must not rewind those global records. Latest owner correction: retire `affection` as well as `friend_attitude`, `friends`, and `inter_friend_affection` from gameplay, capture, restoration and validation. This supersedes the earlier affection-retention decision in PR84. Identify dependent callers and tests rather than deleting identifiers by substring; signals may also have unrelated consumers.

Remove `save_reason`, `audio_context`, and `active_app_id` from the proposed player-save payload. Save reason may remain an operation/logging label, not a load-admission condition. The owner states that music is determined by the DTL position; derive the applicable music without replaying gameplay effects. Exact audio playback-offset restoration is not required by this decision. Resume the required gameplay surface without persisting the previously open application. Do not discard the active board.

Remove the ending's retained source-reading checkpoint from the replacement save. The owner has confirmed one ending for each of two earlier DTL forks, two endings total; the [story owner](../../story/09-priscilla-foundation-amendment.md#save-and-ending-scope-refinement-2026-10-25) records that scoped change. Latest clarification: play proceeds directly to Day 7, where the selected fork determines the dialogue shown in DTL. There is no separate ending selection. Save ordinary DTL position and the choice/fork state; do not introduce a replacement ending selector, separate ending assignment, or ending-resume subsystem. This records intended behavior, not a claim that current DTL already implements both endpoints.

The recommended implementation is to eliminate the saved command-history ledger and its historical validators after establishing direct state restoration. The owner asked for this recommendation; do not represent the current ledger as already deleted. Preserve any small required choice/outcome state independently before removing the history that currently carries it. Keep minimal required-field/type/range/position checks and safe file writing. Missing or incompatible optional metadata must not reject otherwise usable required state. Do not silently reinterpret incompatible required gameplay data. No old-save migration or injected mid-call mutation requirement is introduced.

### Existing implementation evidence and unresolved details

Inspected baseline: PR83 merge `2ebb30a450a832ad892bd08cc4ae968d39dfff9f`.

- `SceneEventContract` already supports `thought.select`, `choice_id`, target selection and `thought_resolved` results; `DialogicBridge` accepts these scene envelopes. This establishes an existing choice mechanism, not implementation of the owner's new, not-yet-announced choice design. Record stable choice/opportunity and selected-option identifiers in the replacement save. The new choice rules, placement and presentation remain unspecified.
- `RunNotePurchaseRules` uses `shop_purchase_counts` for note purchasing and caps. `GameStateMinesweeperShopPort` also grants inventory, and `MinesweeperCapabilityRules.resolve_owned` reads it. Current purchase counts do not prove all owned capabilities. Retain inventory until a caller audit establishes a single complete owner; do not reconstruct it from incomplete purchase counts.
- DTL position must resolve the correct background/music/presentation without executing preceding consequences. Inspect actual authored commands and branching before choosing a reconstruction method; a line number alone is not assumed sufficient.
- Day 7 is ordinary DTL continuation governed by the saved fork. Do not block the save replacement on selecting ending identifiers or designing an ending dispatcher. Exact new choice UI/rules remain unspecified.

### Save fields to omit, simplify, or retain

This is a replacement-schema audit, not permission to erase fields from current Run9 while its consumers still require them. The owner asked which fields do not benefit player progress before handing work to a new session.

| Existing data | Replacement disposition and reason |
| --- | --- |
| `save_reason` | Omit from player payload. Optional diagnostic label only. |
| `audio_context`, `active_app_id` | Omit as approved. Resolve music/presentation from DTL; resume the required gameplay surface. |
| `affection`, `friend_attitude`, `friends`, `inter_friend_affection` | Remove with the retired mechanics and callers. |
| Ending plan/source-reading checkpoint/assignment proofs | Replace with ordinary Day 7 DTL position and the saved fork, with no separate ending selector. |
| `command_receipts`, `applied_effect_transaction_ids`, `applied_variable_transaction_ids` | Candidates to remove when direct restoration and explicit choice/outcome/reward state replace their needed functions. These are currently active bookkeeping, not harmless unused keys. |
| `checkpoint_id`, `checkpoint_sequence`, branch/generation/issuer receipts, `restore_provenance`, occurrence/admission proof IDs | Audit and remove historical transaction identity that the new self-contained save no longer needs. Preserve a small identity only if a concrete remaining global-state operation requires it; do not recreate the old proof system. |
| Full `reading_session` history, `frozen_context`, registration/manifest fingerprints | Derive presentation from authored DTL plus saved choice/outcome state. Retain a stable resume locator and a compact format/content compatibility marker where needed, not duplicated history or full registration proofs. Exact content changes still need meaningful position handling. |
| `recovery_journal` | No recovery feature is requested. The inspected current player-save fixture has an empty journal; omit the empty player-payload field and its recovery-only obligations in the replacement. This does not remove safe file-write behavior. |
| `kind`, `slot_id`, repeated route/day fields | Candidates to derive from selected storage location and DTL state. Check UI/storage callers before removing duplicated ownership. |
| `saved_time` | Useful optional UI metadata: BackupApp displays the saved time. Recommend retaining one timestamp for slot recognition; absence/malformed optional time must not block usable progress. This is not a requirement for extra frozen display strings or redundant time fields. |
| Format version, stable DTL position, selected choices/outcomes, board state, inventory/economy/counters | Retain the minimal authoritative values needed to interpret the save and continue identical gameplay. Board RNG state/seed, revealed/flagged cells, reward claims and active limits are not diagnostic metadata. |
| Contacts/messages/read positions and remaining story flags | Do not label unused from their names. Audit whether active authored/UI behavior needs them; optional presentation defaults must not erase meaningful choices or retained player-visible state. |

File size and validation cost are different measurements. Small metadata removal improves ownership/compatibility but is not a measured speedup. Prioritize eliminating repeated historical reconstruction; preserve optional slot usability metadata where it benefits the player.

### First replacement acceptance journey

Save during a real DTL beat with an unfinished Challenge/board, earlier choice/outcome state and active economy values. Load in a fresh Windows cloud process. Verify the same full caption, correct background/music derived from DTL, exact board and values, normal input, and the same subsequent branch. Verify loading does not repeat purchases, charges or rewards; global unlocks/read history remain. Cover Day 7 dialogue under both saved fork values as authored DTL permits. Compare complete Save/Load operations against PR83. Do not claim a speedup or remove the old production path solely because a smaller JSON example works.

## Current-day History refinement — 25 October 2026

The owner clarified that History preserves the current day's read passage and caption
scrolling uses the same History source. Clear the displayed passage when the next day
begins; global read flags and Gallery unlocks remain. The earlier three-caption-only
Load preference was superseded in the same discussion. Contacts are excluded from
this reconstruction task.

The selected design reconstructs the authored passage up to the current stable
position from saved choices and Challenge outcomes, without executing story controls.
The inspected production registration contains 92 entries, unique choice opportunities,
no Contacts and no cycles. Choices alone are insufficient: Challenge result branches
and recalls also determine the passage. Resolve text from the installed caption catalogue;
do not persist duplicate passage text or a historical transaction log solely for History.
Both the History overlay and caption scrolling consume this one display projection.
Reconstructed display rows are never native publication or command-admission evidence.

The first implementation increment retains the existing genuine top-level story receipts
for their active Challenge/Contacts consumers. Compact scene reading uses schema 6,
a stable line/control locator and one current caption reference. Its publication high-water
prevents new live captions from reusing earlier IDs. Full live reading capture and genuine
retry data remain separate for traversal and rollback. This is not yet elimination of every
story receipt, ending-source field, audio context or saved application field, nor a measured
performance improvement.

## Current-scene relationship-field removal candidate

The first runtime increment removes `affection`, `friend_attitude`, `friends`,
and `inter_friend_affection` from Scene9 defaults, capture, restoration input,
and required-field validation. Legacy calendar gameplay remains outside this
increment. Current authored scene callers do not consume these four fields.

This deliberately changes the current-build Scene9 member contract. Existing
exact-member checks refuse previous development saves containing these fields;
no migration or silent field conversion is added. The numeric scene family
remains 9. Keep progress, contacts, inventory, economy, rewards and board data.

This increment does not implement compact direct restoration, remove command
history, retire the legacy relationship subsystem, or establish a speedup.
Current-build acceptance must create its input under the changed source.
The retained terminal archive used by `terminal_admission`,
`Invoke-FreshSaveLoad.ps1`, and related comparisons contains the previous field
contract and cannot qualify this candidate unchanged. Current CI uses the short,
explicitly synthetic rendered seven-day terminal fixture with newly created saves.
The archived startup/Load timing lane is selected only when both compared
revisions have the archive's gameplay member contract. An incompatible lane is
not measured and is not a passing performance result. The historical archive
and its diagnostic commands remain available at the preceding revision.

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
