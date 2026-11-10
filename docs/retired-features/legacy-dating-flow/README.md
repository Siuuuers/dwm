# DTL-only production progression

The user retired separate Dating scheduling/progression, Gallery Practice, and the
whole automatic Schedule/Hospital/day-resolution flow on 2026-11-04. DTL controls
challenge entry, outcome continuation, day transitions, and story endings.

The existing authored-week implementation already owns these behaviors. This
change removes the parallel production composition; it does not replace the DTL
compiler, create another flow manager, or change authored story text.

## Removed

- Bootstrap composition and resumption of automatic Schedule/day resolution,
  Hospital/condition progression, and Dating pre/post-challenge playback.
- Hospital/Dating scene routes and their presentation-port injection/startup holds.
- Uncalled Dating queue routing methods and the old previous-dialogue list.
- Unconstructed Dating narrative phase adapter; mixed caption tests use Bridge directly.
- Gallery Practice, its rehearsal owner/admission/UI, and exclusive runner entries.
- Standalone DatingScene challenge UI and its exclusive mounted tests. DTL mounts
  SceneChallengePanel; GalleryRecordCatalog retains the unchanged read-only date
  presentation copy used by Gallery and Dialogic replay.
- Tests that required the retired production composition. Current startup,
  shared board identity, restore, Gallery reading, and DTL checks remain.

## Retained deliberately

`DatingPhysicalOwner` and `DatingPresentationPort` still execute DTL scene
challenges. Their scene-challenge branch, generation owner, checkpoint flushing,
restore reconciler, and shared saved-data envelope are live dependencies.

The eight-participant DTL bootstrap no longer constructs the ScheduleView restore
participant or day-resolution state/start ports. The dead GameState facade and
standalone DatingScene have also been removed. Current saves use Run9/Save9 and the eight scene restore participants. The legacy
calendar save builders, nine-participant restore path, and version4 operation
journal have been removed. Current creation recovery and selected Load keep
their existing validation, rollback, and activation owners. Historical sealed
evidence remains unchanged and is not current acceptance.

The old reading-rail, Hospital-reading, ending-reading, and automatic-ending
journey runners and their challenge-layout probe required the retired Schedule
flow and have been removed. Their generated evidence remains historical.

Artwork, read-only dialogue library/replay, DTL challenges, ordinary desktop
Minesweeper, and current save/load remain supported. No runtime speedup is claimed
from the source deletion count.

## Verification scope

Focused checks cover startup/scene composition, shared board and restore owners,
DTL challenge/panel behavior, Gallery layout/navigation, and startup/return routing.
The authored-week rendered create/load journey exercises real DTL progression and
physical saves. The PR records final results and limitations for its candidate.

Three failures in the full profile-stage suite also reproduce on unchanged master:
`test_profile_stage_validates_and_binds_shipped_visited_registry_before_initialize`,
`test_final_contact_stage_reuses_profile_storage_and_retains_one_identity_graph`,
and `test_ready_callbacks_are_side_effect_free_or_deferred_only`. They are outside
this retirement; their assertions are not weakened here.

## Persistence coverage after retirement

SaveManager now admits only the current scene graph. Its old nine-owner restore
and automatic Autosave/Profile NewRun transactions have no production callers.
Tests for those contracts are retired rather than rebuilding a compatibility graph.

| Retired contract | Retained current coverage |
| --- | --- |
| Schedule participation and raw, caller-built restore plans | `test_scene_direct_load`, `test_scene_restore_activation_protocol`, and `test_scene_native_activation` cover selected current restoration and acknowledged activation; direct narrative preparation and rollback diagnostics remain in the mixed restore suites. |
| Automatic NewRun Autosave/Profile pair and legacy startup publication | `test_scene_joint_new_run` covers unchanged disk/Profile at creation and later save/load; `test_scene_new_run_journal` and `test_scene_creation_storage_recovery` cover current durable operations. Prepared-title and live-session tests use the existing scene fixture. |
| Desktop restore identity remapping and pre-board automatic saves | `test_scene_desktop_first_reveal_create/load` and the connected first-reveal suites cover current paid board persistence, preserved selected identities, and no repeated payment. |
| Legacy desktop quick-command graph | `test_production_pause_controller`, `test_backup_quick_actions`, `test_quick_status_edge`, and `test_scene_pause_quick_load` retain input, focus, status lifetime, and current quick-load coverage. |
| Earlier-checkpoint fallback history on new saves | `test_scene_backup_inspection` covers current proof history and omission of fallback snapshots. Parse-cache tests retain detached values and exact-write validation using a genuine current scene snapshot. |

The public-boundary suite retains current session-exit checkpoint ownership and
exact, detached `load_context` reads across slot, quick, and autosave storage.
Removed legacy NewRun/Dating cases are covered by current creation and DTL
contact tests; no old progression graph is reconstructed for these checks.

## Retired Schedule continuation source, 2026-11-11

At baseline `26dbcd42acf82f419b350a84e1237cbcfb09bc38`, the automatic
Schedule/day-resolution composition is already absent.
`DesktopContinuationRemapper.schedule_day_advance_source` derived a Schedule
start or restored continuation receipt for that retired flow. Its private
`_verified_schedule_start_child` helper served only that method.

A search of all 1,453 checked-out tracked runtime, scene/resource, fixture and
tooling text files found only the two declarations and their internal call; no
relevant source files were missing. No dynamic method-name, serialized resource,
runner, or fixture caller remains. Both methods are removed together. No fields,
resource paths, UIDs, or save formats change. The retained, nonwired
`scene_day_advance_source` remains exercised by the existing scene identity
fixtures; it is not evidence of current production DTL wiring. No replacement
owner is introduced. GameState/SaveManager public-surface inventories do not describe
these methods, and the deletion removes no calls to those owners.

Focused acceptance uses the existing positive scene-transition identity cases:
original completion, restored completion/retry, and repeated selected Load.
On Godot 4.6.3 Linux, those three selected methods passed with 9, 14 and 13
assertions respectively (36 total), each in a separate process/data root with
exit 0 and no script errors. The original-completion baseline also passed
9 assertions before deletion. These are semantic identity checks, not rendered
player or full Save/Load qualification. No runtime speedup is claimed; shared
lifecycle, DayResolutionPlan validation and checkpoint owners remain in place.


## Retired detached admission fixture, 2026-11-11

`test_scene_day_reading.test_full_run_validation_stays_closed_without_scene_receipt_owner`
constructed a legacy detached checkpoint to prove that a checkpoint cannot admit
its own full Run. Current context validation rejects that fixture earlier with
`reading_entry_context_mismatch`, so it no longer reaches its claimed assertion.
Remove that obsolete test rather than rebuilding the retired snapshot format.
The adjacent unchanged `test_compact_position_does_not_supply_its_own_run_admission`
checks the same requirement using the current compact saved position: exact
`reading_saved_run_required`, `scene_envelope` phase, and unchanged input bytes.
It passes 12 per-test assertions in isolated Godot 4.6.3 Linux (13 including
fixture setup), exit 0. No production validation or failure handling changes.
