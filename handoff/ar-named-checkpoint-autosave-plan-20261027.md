# Named presentation checkpoints and checkpoint-only Autosave

Date: 2026-10-27, Hong Kong time.
Status: User-approved behavior and implementation plan. Runtime implementation is pending.
Baseline reviewed: master `c122bf55dd1595d219ed7add4a3d811ddf52cc23`.

## Scope and precedence

Continue [aq](aq-trusted-reading-accepted-20261027.md).
This amendment changes when current-game Autosave is required. It does not claim a new runtime or performance result.
It supersedes instructions to retain automatic game saves at every ordinary passage, choice, Challenge or intermediate action.
The named presentation feature from [ai](ai-direct-load-and-settings-back-20261026.md#separate-next-feature-named-presentation-checkpoints) now belongs to this work plan.
Do not repeat the rejected History-refresh coalescing experiment from [am](am-trusted-capture-and-passage-20261027.md).
Keep the accepted edited-DTL behavior from aq. Do not restore nonblocking error-and-skip or deleted-line rewinds.

## Observable outcome

Ordinary reading and intermediate actions update the live Run without an automatic game-save write.
Entering an explicitly authored named presentation checkpoint applies its presentation and creates an Autosave of the actual Run.
Manual Save remains available between checkpoints and restores the exact saved position.
The first visible caption, art and available input must belong to the same live Run.

## Confirmed user decisions

- An Autosave checkpoint is a named authored checkpoint with predefined art, background and music.
- An existing internal snapshot, scene-entry label, recovery anchor, choice boundary or Challenge boundary is not automatically an Autosave trigger.
- Between named checkpoints, progress remains in memory unless the player uses manual Save.
- Closing the game loses progress after the last successful Autosave or manual Save.
- New Account still starts in memory. Do not create an initial Autosave, even when the starting presentation uses a named checkpoint.
- Keep existing saves when starting a new Run. Do not reinstate a durable creation journal.
- Remove confirmed redundancy first. Do not optimize an automatic write that this policy makes unnecessary.

A day start, resolved choice or completed Challenge can be an Autosave point only when the authored flow explicitly enters a named presentation checkpoint there.
Do not silently classify all such boundaries as checkpoints.
This policy concerns game progress saves. It does not disable independent Profile/settings persistence.

## Planned presentation behavior

Use the existing art manifest as the presentation owner. Extend its authored data only as necessary to identify a named checkpoint and its base art/background/music.
Choose the concrete authoring syntax after reviewing the current compiler and manifest. Do not add another manager merely to hold this mapping.

- Entering a named checkpoint installs its predefined presentation and clears active overlays.
- Keep one ordered overlay container. Each art label can appear at most once.
- Showing an already active overlay label does nothing. Removing an absent label does nothing.
- Save the current presentation checkpoint ID and ordered active overlay labels with the actual reading position.
- Manual Save between checkpoints must retain intervening presentation state needed for exact restoration.
- Load resolves the saved presentation directly. It does not replay previous dialogue, choices or effects to reconstruct the screen.
- Restoring a checkpoint from a save is not a new authored arrival. Load must not trigger Autosave or erase saved overlays by re-running entry behavior.

Presentation defaults do not replace actual player state. Preserve choices, gameplay values, Challenge results, current board state when applicable, publication identity and encountered History.
Do not reset these values to checkpoint defaults. Do not assume that a checkpoint ID alone is a complete game save.
Keep existing History section semantics unless a concrete requirement justifies a separate change. Autosave scheduling is not permission to change History retention.

## Planned ownership and implementation

1. Audit automatic game-save callers and distinguish live state publication from durable storage.
   Start with `SaveManagerNarrativeCheckpointPort.gd`: `commit_reading_next`, `commit_scene_event`, `commit_scene_control`, `commit_scene_challenge`, and the contact/shop/round mutation paths.
   Trace their Bridge, Run and lower save-port callers. Include source and destination saves inside one control operation.
2. Define named presentation checkpoint data through the existing authored presentation owner.
   Reuse existing stable ID and compiler conventions. Do not infer checkpoint arrival from every generic scene entry.
3. Keep normal action effects and reading progression in memory between checkpoints.
   Remove automatic storage preparation, writes and readback that serve only the now-unwanted intermediate Autosave.
   Retain the in-memory state transitions needed for correct continuation, manual Save and later checkpoint Autosave.
4. Separate live-state acknowledgments from durable-save acknowledgments where callers currently couple them.
   Do not skip a write and return a fabricated committed checkpoint reference.
   Do not compare a changed live Run with an older disk snapshot as if they must still be identical.
   Prefer the existing canonical owners and the smallest change. Keep unrelated manual-save and real-write failure behavior.
5. At a genuine authored checkpoint arrival, prepare one coherent resumable state with its presentation installed and its dialogue position established.
   Write that state through the existing save owner. After successful acknowledgment, repeated callbacks for that arrival must not trigger another save. Preserve existing handling for failed or uncertain writes.
   Do not add a new persistent deduplication system by default. Review existing operation identity first.
6. Restore manual saves and checkpoint Autosaves directly, with the correct current caption, presentation, gameplay and input owner.
   Check the existing save-format policy before changing fields. Do not silently break accepted saves or invent a migration format in this handoff.
7. Remove helpers and tests made obsolete by this approved scheduling change after reviewing their callers and saved-data obligations.
   Rewrite tests that require intermediate Autosave. Preserve the player outcomes they also cover.

Do not remove the whole Autosave transaction blindly. Its measured span includes live preparation and correctness work as well as storage.
Do not bypass existing storage failure handling at the checkpoints and manual saves that still write.
Do not add background saving in this change. Moving the write after visible continuation would introduce a separate durability decision.

## Failure cases and acceptance

Use cloud-only Godot and exported-game execution. Complete compatible caller and test reviews before final acceptance.

| Scenario | Required evidence |
| --- | --- |
| New Account installs starting presentation | Correct caption/art/music; no initial Autosave or creation journal; existing saves unchanged. |
| Ordinary passage, choice, Challenge or intermediate gameplay action | Live outcome is correct; no automatic game-save storage preparation or write unless an explicit named checkpoint is entered. |
| Several unsaved actions followed by manual Save | Exact current position, choices, History, presentation and active board restore. No dependence on an obsolete disk snapshot. |
| Named checkpoint arrival | Defaults are installed, overlays clear, actual Run state is saved, and one Autosave is produced for that arrival. |
| Checkpoint follows an action with consequences | The saved result includes the completed action. Load does not apply its consequences again. |
| Repeated arrival callbacks or retry | No duplicate durable commit or gameplay effect after successful acknowledgment. Failed or uncertain writes retain existing retry/reconciliation behavior. |
| Close before the next checkpoint without manual Save | Previous durable save remains unchanged; reopening cannot restore the unsaved intervening progress. |
| Load a checkpoint Autosave or mid-section manual Save | Direct, correct presentation restoration; no Autosave caused by Load; saved overlays are preserved. |
| Actual checkpoint/manual write fails | Existing failure handling remains effective; no false durable-success acknowledgment and no silently corrupted previous save. |
| Required edited-DTL reference fails | Keep the visible error and Quit behavior; do not overwrite saves with the failed state. |

Use focused tests for checkpoint selection and overlay rules.
Use integration tests for live versus durable state, manual Save, checkpoint Autosave, close/reopen, write failures and unchanged file bytes.
Use rendered journeys for ordinary reading, named checkpoint arrival, direct Load, overlays, art/music state and responsive input.
Count real storage preparation and write calls. A faster timestamp alone does not prove intermediate writes were removed.

## Performance plan and current evidence

Keep Load, ordinary caption advance, passage transition and named checkpoint arrival as separate measurements.
The earlier 1.377-second result measured a new-passage transition, not pressing Load.
The latest accepted run measured approximately 658 ms to first Load drawing, 687 ms to complete loaded caption, and 1,747 ms to first new-passage drawing.
These are instrumented cloud results, not device guarantees.

The latest passage Autosave path costs about 1,094 ms inclusive. Saved-reading validation totals about 518 ms, restoration about 498 ms and projection about 189 ms. These spans overlap; do not add them or promise that removing a write saves the whole span.
The current source also rebuilds caption-registry lookup state for 1,666 records during ledger initialization. Its separate cost is not yet established.

Priority:

1. Audit and remove confirmed redundancy and automatic intermediate storage work made unnecessary by this decision.
2. Implement and test named-checkpoint presentation and Autosave as one coherent player behavior.
3. Compare complete actions on the same runner, with the same observer and saved input. Include ordinary transitions, checkpoint transitions, manual Save and Load.
4. If remaining timings warrant it, measure registry initialization separately before changing it. Do not preserve the old write-heavy route only to optimize its internals.

For the historical 1.377-versus-1.747-second concern, compare the PR 124 runtime and current accepted runtime directly under one matched run if a cumulative regression conclusion is needed.
The PR 124 candidate and PR 127 baseline differ only in documentation/evidence, yet their separate runs recorded 1.377 and 1.932 seconds. Cross-run absolute differences therefore cannot be assigned solely to later code changes.
Report mixed or slower cases. Do not claim a universal gain from fewer calls or move a pause into the first interactive frame.

## Next-session entry

Read this amendment and aq, then inspect current master and applicable repository instructions.
The two product questions are settled: use named presentation checkpoints, and retain only manual Save between them.
Implementation and matched cloud acceptance remain pending. This document changes no runtime code.
