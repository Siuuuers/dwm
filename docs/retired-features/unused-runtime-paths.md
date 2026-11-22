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
