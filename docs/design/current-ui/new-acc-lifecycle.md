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

Reuse DesktopContinuationOperationJournal and JsonFileStorage. At the initial audit the journal
had closed v1 operation/context keys and a fixed eight-participant order; its
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


## Captured configuration and retirement cutover (2026-09-07)

This local checkpoint is verified. RunSnapshot and SaveDocument now use
v5 and require an explicit Boolean `lifecycle.dark_mode`. RunLifecycle owns this
fact; GameState publishes it only after a validated run installation. A reset
placeholder does not count as an installed run, and full rollback restores both
configuration and availability. Old unshipped save versions are unsupported:
SaveMigrations admits validated current records without stripping unknown fields,
inventing a Dark value, relabeling slots, or consulting current Profile settings.
Profile itself remains v4.

New Run samples validated prepared Profile Dark intent under its mutation gate,
before durable identity intent. The v2 continuation journal binds that Boolean in
its exact context and hash. Restart recovery uses this captured value even when
pending Profile intent has changed. The caller cannot supply a Dark override.
Both initial and resumed New Run prepare the real main route with Day 1 and no
active app, so the retained desktop host participates in apply and rollback.

ComputerDesktop binds the installed run before app restoration. It masks early
production mounting until Bootstrap and captured configuration are available,
applies the palette before reveal, and then restores guarded Minesweeper launcher
focus. Schedule, Minesweeper and Shop receive the same captured palette; changing
pending next-run Dark, locale or text size cannot recolor the existing run.
Native proof uses actual lifecycle/schema installation and real app hosts, with
explicit test catalog/art/names and board generation/checkpoint fixtures.

Opening/tutorial production scenes, scripts, timelines, callbacks, route entries,
audio identifiers and retired Profile/gameplay fields are removed. Historical
sealed evidence remains byte-for-byte history. The current handoff guard verifies
live versions against the current schema owners while retaining the historical
v4 seal and its structural/identity/publication invariants.

This cutover does not complete New Acc. Initial Autosave plus Profile selector
consumption still need a joint durable decision/recovery path. Truthful replacement
consent, live-session presence and frozen same-operation Retry remain open. The
all-family goal and dwm-eei.20 remain in progress. No merge or push is included.


### Concurrent integration frontier

During validation, the independently owned destination advanced to clean commit
`101fe2b9815af4682d1318d0a7cc2d93442b6e2d` (code parent `914bc4f3`). Its
Schedule/Hospital changes also use snapshot/document v5 and continuation journal v2,
but with different exact fields and nine participants including ScheduleView.
Those formats are incompatible with this isolated captured-Dark checkpoint despite
the matching numbers. A later semantic integration must combine both owner shapes,
preserve saved-time/manual-save behavior, and assign unambiguous schema and journal
admission. It must not infer Dark or replay an Opening context. No external changes
were merged, and dwm-oyo.3 remains in progress with its next task still open.

Old Profile records containing the retired tutorial preference, including an
archived legacy preference object, are refused strictly rather than rewritten.


Verification: 993 tests across 52 distinct GUT suites have passing latest results;
24 final native captures pass 130 checks. Real Backup and retained-scene probes
pass, save capture passes 136 checks, the production save/load loop passes 39,
and two fresh production processes pass 56 seed plus 71 cold-resume checks,
including saved Dark equality. [All evidence and attempts](../../../evidence/run_dark_cutover/summary.json)
remain recorded with current source hashes and known diagnostic limitations.


## Joint durability checkpoint

This implementation extends the continuation journal to v3. A New Run intent
retains the complete allocation candidate, exact initial Autosave bytes, and exact
Profile before/consumed documents. Profile source revisions bind the original raw
bytes, including valid noncanonical formatting; outgoing Profile bytes are canonical.
The consumed document differs only by setting the pending Dark selector to Off.

The committed intent is the durable decision. Allocation, Autosave, and Profile
proofs must be recorded in that order before live participant application. Recovery
accepts only the retained source or outgoing file revisions; an unrelated pending
write or foreign file is refused without reconciliation or overwrite. After the
pair is durable, live failure retains the same operation and mutation lease for
forward recovery. The generic selected-Load rollback contract remains separate.

Profile now exposes pure preparation, quiet conditional persistence, and read-only
proof of consumed bytes. Empty restore patches preserve current validated Profile
preferences instead of invoking the first-process legacy import path. Bootstrap
settles retained New Run storage before initializing Profile or preference consumers;
the later continuation phase remains responsible for installing live owners.

Verification: 159 distinct tests across 18 GUT suites pass, including the full
journal transition matrix, real Profile preservation, both target write failures,
same-operation retries, foreign-byte refusal, and real-file restart/Load regression.
The standalone Backup operations probe passes. The actual production title and
second-process resume pass 56 seed and 71 resume checks. All player files are
isolated; existing Unicode parser and exact baseline Dialogic shutdown diagnostics
remain visible. Full evidence and source bindings are in
[evidence/new_run_pair/summary.json](../../../evidence/new_run_pair/summary.json).

This checkpoint completes the retained-pair prerequisite. Prepared Start, truthful
replacement consent, live-session presence, and mounted Retry/recovery remain open.
The all-ten-family UI goal remains active; no merge or push is included.
