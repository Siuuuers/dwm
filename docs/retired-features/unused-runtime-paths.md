# Unused runtime paths

The prior implementations are available at `cf188a1`. This pass traced code, scenes, resource UIDs, registrations, saved fields and test callers.

| Removed code | Former purpose and retained owner |
| --- | --- |
| BoxMeter, ChatBubble, ContactBox, DialogueBox, IconButton, SaveSlotRow, and the challenge-panel scene wrapper | Six standalone widgets had no mounted scene. ApplicationBootstrap creates the live challenge panel directly from its script. |
| NotesCatalogProjection and FriendData | Built catalog rows without a runtime consumer. The shop still handles saved purchases, and Contacts still uses the domain roster. |
| Solo test-marker dispatch and restore prototypes | Drove a test-configured marker document. Authored scene events use the scene marker and checkpoint owners. |
| Day 7 prelude owner and unused dating playback hooks | Earlier wiring for invitation presentation and playback. Replay still mounts the prelude surface. Existing saved attempts, day transitions and their receipts have live owners. |
| Desktop notification callbacks and schedule-departure configuration | The completion path persists the notification intent. The discarded subscribers were never installed. |
| Unused GameState accessors and queue commands | Projected stats, updated now-unused date queues or exposed generic flags and save summaries. Existing save fields still serialize and restore. |
| UI layout adapters, settings queries and listening-reminder timer | The mounted panels own layout and input. Settings reads the profile and presents its localized listening-comfort note. |
| Save and route helpers, timeline lookups, extra snapshot builder and profile flag | The Title starts a prepared scene run. SaveManager still restores the selected checkpoint, and ProfileManager initializes the persisted profile. |

The ordinary Day 7 passage completes at its registered final caption on the scene route. The retained completed-scene remap test covers saved completion, and the connected passage tests cover save, restart and Gallery replay. The retired test expected a separate ending host for a scene snapshot.

## Scene scrollback

At `2aa1712`, only tests called the reading session’s raw-ledger caption-memory projection. It filtered publications by occurrence and reconstructed their text. The displayed scrollback and History already follow the encountered checkpoint sections through the authored programme. Scene playback keeps the current publication for exact Load and continuation. Both removed projection functions produced transient display rows.

## Live effect and variable backup

GameState previously copied gameplay, contacts, scene progress and transaction history before applying an effect or variable. Both commands now validate their inputs before changing state. Their private backup and restore methods had no remaining runtime callers and wrote no save fields. The run restore participant still owns Load and its compensation.

## Active plan reversal

At `92d5a12`, only tests called RunLifecycle.rollback_active_plan. GameState reads the active plan through capture_active_plan and the restore participant installs saved lifecycle state during Load. Neither operation uses a separate plan reversal.

## Dialogic preference backup

Only tests called DialogicPreferenceAdapter.capture_state, rollback_silent and finalize. Those methods kept a second copy of the reading preference plan. DialogicBridge already retains the applied Profile plan and reapplies it when Dialogic clears its native settings. The removed methods wrote no save or Profile fields.

## Desktop and shop reversal commands

Only tests requested reversal from DesktopCausalSequencePort, DesktopBoardFatePort and MinesweeperShopPurchaseParticipant. The sequence port’s reservation backup and the board port’s capture-hash generations existed solely for those commands. Desktop departure still reads the current board. Admission and shop recovery use their recorded transaction and checkpoint to finish an interrupted operation. Shop confirmation retains its lease-release path, and pricing reads current economy and consequence facts. The removed commands and private bookkeeping wrote no save fields.

## Minesweeper generator manifest snapshots

Only cache tests requested full copies of the generator budget and certified fallback manifests. Those tests now load the same private caches used for board generation. Public board replay checks that mutating a returned layout leaves the certified fallback intact. Both manifest validators return the validation result directly.

## Minesweeper rules sheet

Only the rules sheet called MinesweeperSheetCopy.get_copy. It now reads its localized text and examples directly from the constant table. The selected language and displayed rules use the same entries.

## Minesweeper schema results

Board and spec callers now use check_board and check_spec to validate the values they already hold. The former validate_board and validate_spec wrappers returned whole copies after the same checks. The generator kernel has a separate validate_spec method covered by its hardware calibration.

## Editable Minesweeper shell query

First reveal and flag commands read shared shell flags and action history through `DesktopBoardState.read_shell()`. The former `shell_state()` copied that history for each lookup. Callers that need to edit a board still own the result of `capture()`.


## Minesweeper preparation and Windows budget provenance

Only tests called MinesweeperBoardGenerator.validate_prepared to revalidate an already certified search. The game checks preparation fields and transitions in MinesweeperPreparationState.check and check_advance. Current callers can use those checks directly. The retired validate and advance wrappers copied the checked preparation.

The checked-in Windows benchmark records the reducer, generator kernel and verifier source hashes that produced its operation budgets. The benchmark tool still records those hashes when a new calibration is made. The game checks the exact RNG, difficulty manifest, fallback manifest and budget schema used by that calibration. Ordinary code edits can reuse the budgets. Changes to the search algorithm, operation accounting or target hardware require a fresh calibration before making a performance claim.

## Dismissed Minesweeper inspection

The board-fate port uses `project_dismissed_inspection()` to clear the board slots and retain the existing receipt history. Its public command result already owns a separate editable copy. This replaces the extra detached `dismissed_inspection_snapshot()` between those two steps.

## Round recovery success receipts

Desktop consequence recovery already holds the action receipt when it commits a Minesweeper round. The commit now reports success directly and retains the validator-owned receipt for retry comparisons. The former success envelope returned two editable receipts that the game discarded.

## Previous development builds

Profile initialization adopts the current document validated by storage. Earlier Profile schema upgrades, standalone input-binding imports, the old Run-to-Profile patch and startup repair of an earlier Dark-mode writer are retired. Current ending completion grants Dark mode when the discoveries qualify. Load keeps the current Profile, including Global reading history. New Account prepares its current Profile candidate through the same participant API as the other restore owners.

Minesweeper certification clears flags before it publishes a required first reveal. Loading and revealing that cell use the saved board directly. Dating Challenge no longer accepts the retired v2 board record or its scoring calculation. Backup and Quick Load no longer render the retired day-slot label.

Save9 and Run9 use the current writer's fields. Opening a checkpoint no longer converts an older development layout or supplies a missing physical slot. Dialogue content revisions still use the game's checkpoint fallback. Minesweeper records each new move in its saved form and shares the read-only entries between successive boards.
