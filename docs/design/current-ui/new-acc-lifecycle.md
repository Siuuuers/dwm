# Canonical New Acc lifecycle

The accepted shared-shell dossier sections 5.3 and 6 define the target. This record
tracks implementation evidence for dwm-eei.20; it does not replace that acceptance.
The all-family UI goal remains open.

## Required behavior

New Acc asks for replacement consent only when an actual live continuation or
nonempty Autosave will be replaced. The trusted sheet owns Warning, Cancel has
initial focus, Back cancels, and Start has Danger. Capability and consent freshness
must come from lifecycle, storage and Profile owners rather than title visibility.
Unreadable existing storage is not evidence of an empty slot.

The lifecycle freezes pending Dark intent and relevant revisions, allocates a
Day-1 run/branch, captures Dark immutably, selects main with no active app, seeds
only valid Day-1 facts, and durably commits the initial Autosave and Profile selector
consumption before publishing the launcher with Minesweeper focus. Cancel and
reversible failure preserve old state. Retry retains the prepared identity and
frozen materials. Indeterminate durability retains recovery custody.

The final product removes Opening/tutorial routes, scenes, timelines, audio,
preferences and receipts without aliases, converters or hidden replacements.
Historical planning documents are references, not production compatibility needs.

## Current owner evidence

At baseline 9adec2cf2faeaac98d382f3921dcab14018482fe:

- SaveManager.start_new_run and DesktopContinuationOperationJournal require Opening.
  New Run constructs a raw route plan instead of using RouteRestoreParticipant's
  preparation of the retained desktop day and active-app state.
- CheckpointJournal is an in-memory journal. The initial New Run path does not write
  Autosave. Its commit precedes fallible finalization, while rollback restores only
  participants, allowing a failed New Run to replace the current checkpoint.
- Profile contains pending Dark preferences, but the run schema has no captured
  Dark configuration. Profile restore publication does not persist selector changes.
- Each start_new_run call allocates a fresh transaction. Startup continuation replay
  is not a targeted, frozen same-operation Retry, and reconstructs Profile material
  from current preferences.
- No explicit live-session presence/abandonment read contract was found. A retained
  journal, route, or title view must not stand in for that fact.

These are production owner gaps, not problems a title confirmation can conceal.

## First prerequisite: reversible checkpoint rollback

The first change restores CheckpointJournal state when a transaction fails after
its journal commit, alongside the already captured participant state. Successful
transactions retain their new checkpoint. Failure to restore the journal must
retain fatal recovery custody instead of reporting an ordinary reversible failure.
Tests must exercise a real nonempty prior checkpoint/history, post-commit finalize
failure, pre-commit failure, successful replacement, and rollback failure handling.
Shared restore and continuation behavior must also be checked.

Verification: the unchanged-code RED run failed exactly on lost journal/history
and absent fatal compensation. The final nine suites pass 78 tests / 1295 assertions,
including a real populated New Run journal and directly seeded Load failure.
The stale restore finalize-order assertion now requires route dispatch last; the
Bootstrap fixture now initializes the existing shared Settings/window owner graph
and retains all previous failure checks plus a missing-window-stage case.
See [checkpoint evidence](../../../evidence/new_acc_journal_rollback/summary.json).

This prerequisite does not claim durable Autosave, Dark capture, canonical title
entry, prepared retry, or Opening retirement. Those requirements stay on dwm-eei.20.
No merge/push or changes to other worktrees are part of this checkpoint.

## Durable handshake implementation direction

Reuse DesktopContinuationOperationJournal and JsonFileStorage. The current journal
has closed v1 operation/context keys and a fixed eight-participant order; its
post-apply receipt dictionaries cannot retain a pre-mutation prepared operation.
A validated New Run materials extension must retain the frozen source revisions,
run/Autosave/Profile candidates and hashes, a durable decision, and target proofs.
Selected-Load recovery keeps its existing separate contract.

JsonFileStorage already exposes raw-byte revision inspection, conditional atomic
replacement of one file, and artifact reconciliation. It does not promise atomic
replacement of two files. Before the durable decision, cancellation leaves player
files and live state untouched. After that decision, recovery finishes the frozen
pair under retained custody. On replay, each target must match the exact old bytes
or exact outgoing bytes; foreign bytes require recovery rather than overwrite.
Readback handles a crash between a physical write and its completion receipt.

Profile needs a narrow owner-authorized persistence/reconciliation seam separated
from live adoption/publication. Its current ordinary commit guards against New Run's
held gate and adopts memory immediately; releasing the gate to call it is invalid.
Startup currently initializes Profile before continuation reconciliation, so joint
disk settlement must precede Profile-dependent consumers. The initial Autosave can
use existing SaveDocumentSchema day_start support with one frozen saved-time.
Captured Dark belongs in the closed run schema and must survive restore.

Fault tests must stop at every decision/target-write boundary, restart over the
same isolated storage, and prove one identity, frozen intent, exact Profile/Autosave
agreement, no premature signal/route, and refusal of changed foreign bytes.
This direction is based on current source inspection, not a completed feature.

## Opening/tutorial retirement inventory

A read-only inventory at the same baseline found 24 directly coupled textual
production/content/schema artifacts, four UID companions, and 24 direct test/fixture
files. The current manifests contain 139 semantic entries and 10 Day-1 entries;
removing the two retired entries yields the accepted 137 and 8.

- Runtime/schema: GameState's exact fields/defaults/mark methods, RunSnapshotSchema,
  both New Run validators, SceneRouter, MenuScene, and MainGameScene's dead overlay host.
- Resources: OpeningScene.gd, TutorialOverlay.gd and their UIDs; both scenes; the
  opening_day1 and tutorial_desktop_day1 English core timelines and their UIDs.
- Registration: day_1.dtl, project.godot, dialogic_entries.json, timelines.json,
  the evidence-only dialogic_61_to_8 inventory, dialogic-entries schema roles,
  and DialogicBridge's opening_done/tutorial_done callbacks.
- Audio: AudioManifest IDs and context maps only; no corresponding physical assets
  were found by the inventory.
- Profile: legacy tutorial_replay_available validation/import in ProfileSchema and
  ProfileMigration plus the English UI label. Modern Settings has no such control.

Direct tests span New Run/continuation/crash recovery, Dialogic admission and signal
boundaries, Pause frontier, save/load capture/loop, title resume, scene smoke,
manifest/registry/master structure, GameState/snapshot production, Hospital adapter,
and Profile upgrade/import. Retained story fixtures replace arbitrary Opening
fixtures; retired routes/fields must be rejected, never normalized away.

Main routing and launcher focus already have real production seams. Captured palette
does not: DesktopTheme currently supplies After-Hours, and ComputerDesktop has no
run-owned palette dependency. That must be connected before canonical Midnight entry
can be accepted. Complete transaction/route/palette prerequisites, prove real main
entry, then remove resources/closed-schema fields and registry/audio/Profile remnants
with focused absence and behavior checks. No retirement is claimed in this checkpoint.
