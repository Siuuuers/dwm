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
