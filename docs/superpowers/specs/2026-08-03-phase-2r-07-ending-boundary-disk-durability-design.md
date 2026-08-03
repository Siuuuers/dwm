# Ending-Boundary Disk Durability (dwm-p2r.7 Task 6 closeout)

Status: approved design (refined 2026-08-03), pending implementation plan
Date: 2026-08-03
Scope: dwm-p2r.7 Task 6 (endings) — the recovery closeout for `.7`

## Goal

A crash immediately after the run enters the ENDING state on day 7 must be
recoverable *from disk* through the intended durable mechanism. After restore,
the run is in ENDING with the exact `ending_plan` (primary id, optional epilogue
id, `playback_stage = PRIMARY_PENDING`, `source_day = 7`), day stays 7, and the
ending can be re-walked to COMPLETED.

Per-transition, exact-stage recovery (resuming mid-playback at `PRIMARY_PLAYED` /
`EPILOGUE_PLAYED` / `GALLERY_RECORDED` without re-walking) is deferred to `.8`.
Wiring checkpoint-recording into live gameplay is a separate integration, also
out of scope here. See "Deferred / out of scope".

## Context and findings

The ending playback machine is already complete and hardened (this session):
resumable in-memory round-trip, exactly-once forward recovery on partial profile
failure, semantic validation of a restored `ending_plan`, and table-driven
coverage of all eight canonical primaries × epilogue × every resume point.

Relevant to disk durability specifically:

- Every playback transition is **idempotent**. Duplicate completions return the
  stored receipt; gallery unlocks dedupe through the transaction ledger. A crash
  mid-ending can safely resume from the ENDING boundary and *re-walk* to
  completion without double-recording.
- `SaveManager.autosave()` → `_write_latest()` writes the checkpoint journal's
  **latest stable checkpoint** (`_journal.get_current_bundle()`), not a fresh
  capture of live GameState. The autosave carries the `ending_plan` only if a
  stable checkpoint containing it was recorded.
- **Stable checkpoints are recorded exclusively by `DayResolutionCoordinator`**
  (via `SaveManagerCheckpointPort.prepare`). The coordinator already defines the
  ending-entry stages `resolve_ending_plan` → `enter_ending` → `ending_autosave`
  (a `disk_checkpoint_request` with `save_reason = "ending"`, an existing
  `AUTOSAVE_REASONS` value). This coordinator sequence is the **intended durable
  mechanism** for entering ENDING.
- **The coordinator is not yet driven by live scenes.** Its facade
  (`request_schedule_done`, `resume_day_resolution`, `begin_day_resolution_stage`,
  `complete_day_resolution_stage`) is called only by tests. Live scenes end the
  day through the *direct* GameState path
  (`apply_hospital_recovery_and_advance_day`, `advance_date_queue_or_day` →
  `advance_day_or_end`), which enters ENDING via `_lifecycle_ensure_ending()` and
  then calls `SaveManager.autosave()` — but since no stable checkpoint is
  recorded in live play, that autosave currently returns `no_stable_checkpoint`
  and persists nothing (the result is intentionally ignored).
- Therefore verifying durability through the *live scene* path is not meaningful
  yet: live play persists nothing to disk. The verification targets the
  **coordinator mechanism** (the intended durable path). Wiring checkpoint
  recording into live gameplay is a separate, larger integration tracked
  independently.
- Production ending *playback* is a `.8` deliverable: plan-04 states `.7` uses
  recording fakes and "leaves production startup explicitly incomplete; Plan
  `.8` implements the Dialogic-backed port." Exact-stage mid-playback resume only
  becomes meaningful once real playback exists.

## Approach (test-first, integration)

1. An integration test drives the coordinator's ending-entry sequence
   (`resolve_ending_plan` → `enter_ending` → `ending_autosave`) through a
   `SaveManager` initialized with injected `FakeFileOps` storage, so the
   `ending_autosave` stage writes a disk autosave. It then simulates a crash by
   loading the autosave (`load_autosave` / restore) and asserts the restored run
   is in ENDING with the exact `ending_plan` (primary + optional epilogue,
   `PRIMARY_PENDING`, `source_day = 7`) and day 7.
2. A second assertion: the restored run resumes at `PRIMARY_PENDING`
   (`request_next_ending_command`) and is driven to COMPLETED — proving the
   idempotent re-walk from the boundary reaches the menu with the gallery
   recorded.

The test drives the coordinator mechanism (not the not-yet-durable direct scene
path), because that is the path whose disk persistence is real and is the
intended production route once scene-wired.

## The decision the test forces

- **The coordinator's `ending_autosave` correctly persists the `ending_plan`** →
  the round-trip works; the test is pure proof of the durable boundary with
  **zero production change**.
- **The `ending_autosave` snapshot is missing or malformed** (e.g. the captured
  snapshot does not carry the fresh `ending_plan`) → the test goes RED; the
  **minimal, targeted fix** lives inside the coordinator/checkpoint-port capture
  so the `ending_autosave` stage records a stable checkpoint whose snapshot
  contains the `ending_plan`. No new save-core machinery, and no live-scene
  rewiring.

## Testing

Integration test under `tests/integration/`, following the existing
`test_restore_*` and `test_day_resolution_coordinator` patterns: `SaveManager`
initialized with injected `FakeFileOps` storage, the coordinator driven through
the ending-entry stages, then `load_autosave()` / restore and assertions on the
reconstructed lifecycle. Run in isolation via `Invoke-IsolatedGodot.ps1`. Full
blast-radius re-run of the save/restore and game_state clusters before commit
(no regressions).

## Success criteria

- A passing integration test proving: the coordinator's ending-entry sequence
  writes an autosave to disk → loading that autosave restores the run to ENDING
  with the exact `ending_plan`, day 7; and the restored run re-walks to COMPLETED
  at the menu with the gallery recorded.
- If the test was RED, the minimal fix that makes it GREEN, with no regressions
  across the save/restore/migration and game_state clusters.
- Task 6's disk-recovery story for `.7` is closed at the coordinator boundary;
  per-transition disk checkpoints and live-scene checkpoint-wiring are recorded
  as tracked later items.

## Deferred / out of scope

- **Per-transition disk checkpoints** so a crash resumes at the exact
  mid-playback stage without re-walking. Coupled to the real Dialogic playback
  port and its restore-resume — `.8` deliverables. Until then, re-walk from the
  ENDING boundary (idempotent) is the recovery behavior; for a visual-novel
  ending that means replaying from the ending's start after a crash — an accepted
  `.7` trade-off.
- **Wiring checkpoint-recording into live gameplay** (driving the coordinator
  from scenes and/or Dialogic line-checkpoints) so `autosave()` persists during
  normal play. A separate, larger integration tracked independently. This spec
  verifies the durable *mechanism*, not its scene wiring.
