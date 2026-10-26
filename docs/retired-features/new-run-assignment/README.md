# New Run assignment retirement and template decision

Decision date: 2026-10-26 (Hong Kong).
Status: owner-approved replacement direction; documentation and source archive only. Runtime removal is not implemented by this commit.
Inspected master: `ff5b327a5433867f33c85644e3173d15cdef01d0`.

## Approved behavior

- New Run starts at the same authored entry. Subsequent choices and Challenge outcomes determine progression.
- Temporarily retire the run-level Sweet/Dark assignment. Preserve its design and related source for possible future work. Do not retain a runtime switch merely for possible restoration.
- The New Run template is separate from player settings. Keep preferences, read history and unlocks in their existing profile owner.
- Do not write the initial Autosave merely to create a run. Interrupted creation need not recover; the player can start another run.
- Focus tests on ordinary product behavior, saved progress and measured reading latency. Do not expand this work into external-tampering or injected-crash recovery.
- Trust shipped authored content after build checks. Do not add repeated runtime content validation.

Keep the previous Autosave until an actual later save as the non-destructive implementation default. The owner has not explicitly selected different handling of the previous Autosave. Audit actual logout, day-advance, completion and deferred-save callers before stating the final save-trigger contract.

## Observable implementation outcome

New Acc activates the authored Day 1 start from fresh mutable defaults without an initial Autosave or a Sweet/Dark draw. Player preferences and existing saved progress remain intact. A later normal save and Load restore the current run and visible beat.

Compare complete click-to-first-caption latency with the merged baseline. Do not promise a speedup from fewer lines or from a template copy alone. Cloud Windows tests must cover New Run, later save/Load, normal exit, day advancement, choices and Challenge behavior. Reuse existing tests where appropriate. Delete creation-recovery expectations only where this decision supersedes them.

## Fresh values: current implementation versus target

| Value | Current behavior | Intended treatment |
|---|---|---|
| Run ID | Allocator issues a new identity and receipt | Keep one fresh run identity |
| Branch and causal-day IDs | Allocator issues both and receipts | Trace surviving save/board/day consumers before removing or deriving |
| Desktop timeline generation | Starts at zero with an issued receipt | Zero is a default; receipt machinery is a removal candidate |
| Creation transaction | Issued before allocation | Durable creation recovery no longer requires it; other consumers still exist |
| Occurrence/playback/admission identity | Reuses creation transaction | Keep only identity needed for live reading/commands; do not mint several equivalent IDs |
| Initial checkpoint ID | Derived as run ID plus `:1` | Derive if retained; not a separate random draw |
| Money, inventory, flags, counters | Small default-state constructor | Fresh mutable containers per run |
| Dialogue start | Manifest first target, currently `target.Day1` | Authored template/reference, not randomized |
| Minesweeper RNG | Default zero before a board exists | Generate board data when needed, not during New Run |
| Assignment nonce | Four random bytes for first Sweet/Dark assignment | Remove with assignment |
| Save time / serialized document / hashes | Built during creation | Build when a real save occurs |
| Profile preferences/read marks/unlocks | Existing player profile | Preserve; never put into the pristine New Run template |

## Active work to remove or simplify

- `SaveManager._prepare_scene_new_run_decision` builds plans and discards the returned plans; `_resume_scene_new_run` builds them again. Both are active, not dead functions.
- `prepare_new_run_action` and `_commit_prepared_new_run` prepare legacy profile-consumption candidates before the scene path prepares its own assignment candidate. Their current baseline/staleness role must be accounted for when removing the work.
- Initial Autosave serialization, persistence, proof and reparsing serve the old creation contract. `_settle_new_run_pair` coordinates Autosave and Profile; it is not a dialogue-pair selector.
- Sweet/Dark chronology, nonce, predecessor hashes and profile ledger support the retired assignment. They are not needed for selecting the current Day 1 start.

`SaveManager.start_new_run` has no ordinary product caller found in the inspected runtime directories; Title uses `prepare_new_run_action`. Integration tests still call the legacy method, including dynamic calls. Its fallback remains reachable without a configured scene target. Treat this as a legacy/test-path candidate, not proven dead code.

The current first-target lookup reads `tests/templates/scene_sequence/seven_day_order.json`. This is a production source despite its directory name. Keep one authoritative starting-entry definition; do not add a competing template owner.

## Coupling that must be removed coherently

`scene_assignment` also acts as a runtime-family discriminator. `GameState`, `RunLifecycle` and `ApplicationBootstrap` branch on its presence. Deleting the field alone sends some operations through legacy paths. Replace those checks with the existing authoritative scene-runtime state before deleting assignment data.

`GameState.capture_run_configuration` still reads `scene_assignment.form` to supply `dark_mode`. Trace consumers before replacing this with fixed behavior. Current saves and normal Load also compare assignment against Profile. Do not strand saved progress by deleting only the draw function.

This is a scoped caller audit, not proof that every legacy function or scene is unused. GDScript uses dynamic calls, signal connections and injected participants. A single textual reference search is not sufficient evidence for deletion.

## Preserved source and restoration boundary

`PairDeckDraw.gd.txt` is the exact complete selector source from the inspected master. The `.txt` extension prevents it from becoming an executable script. The whole `docs/` folder is excluded by the Windows export preset.

Related code remains retrievable at the pinned revision:

- [SaveManager](https://github.com/Siuuuers/dwm/blob/ff5b327a5433867f33c85644e3173d15cdef01d0/autoload/SaveManager.gd): preparation, chronology, paired persistence and activation.
- [ProfileManager](https://github.com/Siuuuers/dwm/blob/ff5b327a5433867f33c85644e3173d15cdef01d0/autoload/ProfileManager.gd): assignment ledger preparation, persistence and proof.
- [GameState](https://github.com/Siuuuers/dwm/blob/ff5b327a5433867f33c85644e3173d15cdef01d0/autoload/GameState.gd): defaults, lifecycle discrimination and configuration.
- [SceneEventContract](https://github.com/Siuuuers/dwm/blob/ff5b327a5433867f33c85644e3173d15cdef01d0/scripts/domain/narrative/SceneEventContract.gd): admission and assignment references.

The archive is historical material, not permission to reactivate assignment or its old durability requirements. Any future restoration must specify its player-visible purpose and fit the then-current save model.
