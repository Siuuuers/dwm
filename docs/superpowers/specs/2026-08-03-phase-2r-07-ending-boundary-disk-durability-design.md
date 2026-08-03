# Ending-Boundary Disk Durability (dwm-p2r.7 Task 6 closeout)

Status: approved design, pending implementation plan
Date: 2026-08-03
Scope: dwm-p2r.7 Task 6 (endings) — the recovery closeout for `.7`

## Goal

A crash immediately after the run enters the ENDING state on day 7 must be
recoverable *from disk*. After restore, the run is in ENDING with the exact
`ending_plan` (primary id, optional epilogue id, `playback_stage =
PRIMARY_PENDING`, `source_day = 7`), day stays 7, and the ending can be
re-walked to COMPLETED.

Per-transition, exact-stage recovery (resuming mid-playback at
`PRIMARY_PLAYED` / `EPILOGUE_PLAYED` / `GALLERY_RECORDED` without re-walking) is
explicitly **out of scope** for `.7` and deferred to `.8`. See "Deferred".

## Context and findings

The ending playback machine is already complete and hardened (this session):
resumable in-memory round-trip, exactly-once forward recovery on partial profile
failure, semantic validation of a restored `ending_plan`, and table-driven
coverage of all eight canonical primaries × epilogue × every resume point.

Relevant to disk durability specifically:

- Every playback transition is **idempotent**. Duplicate completions return the
  stored receipt (no timeline replay side effects at the state layer); gallery
  unlocks dedupe through the transaction ledger. Therefore a crash mid-ending
  can safely resume from the ENDING boundary and *re-walk* to completion without
  double-recording.
- `SaveManager.autosave()` → `_write_latest()` writes the checkpoint journal's
  **latest stable checkpoint** (`_journal.get_current_bundle()`), not a fresh
  capture of live GameState. So the autosave carries the `ending_plan` only if a
  stable checkpoint containing it was recorded when the run entered ENDING.
- Stable checkpoints are recorded by `DayResolutionCoordinator` through
  `SaveManagerCheckpointPort`. The coordinator already defines the ending-entry
  stages `resolve_ending_plan` → `enter_ending` → `ending_autosave` (a
  `disk_checkpoint_request` with `save_reason = "ending"`, an existing
  `AUTOSAVE_REASONS` value). GameState owns the coordinator and drives it via
  `begin_day_resolution_stage()` → `_day_resolution_coordinator.resume()`.
- A second, direct path also exists: `GameState.advance_day_or_end()` (and the
  sibling day-7 branch) enters ENDING via `_lifecycle_ensure_ending()` and then
  calls `_autosave_after_advance()` → `SaveManager.autosave()` **without** going
  through the coordinator. If that path is live at end-of-day-7, its autosave
  writes a **stale** bundle that predates the `ending_plan`.

Which path production actually uses at end-of-day-7 is the empirical question the
verification resolves.

- Production ending *playback* is a `.8` deliverable: plan-04 states `.7` uses
  recording fakes and "leaves production startup explicitly incomplete; Plan
  `.8` implements the Dialogic-backed port." Exact-stage mid-playback resume only
  becomes meaningful once real playback exists, i.e. in `.8`.

## Approach (test-first, integration)

1. An integration test drives the **production** end-of-day-7 flow so the run
   enters ENDING and the autosave fires. It then simulates a crash by loading the
   autosave and asserts the restored run is in ENDING with the exact `ending_plan`
   (primary + optional epilogue, `PRIMARY_PENDING`, `source_day = 7`) and day 7.
2. A second assertion: the restored run resumes at `PRIMARY_PENDING`
   (`request_next_ending_command`) and can be driven to COMPLETED — proving the
   idempotent re-walk from the boundary reaches the menu with the gallery
   recorded.

The test must drive the same entry path the game uses at end-of-day-7 (identified
during implementation by reading the scene/flow that ends day 7), so that a stale
autosave is actually caught rather than bypassed by manually recording a
checkpoint in the test.

## The decision the test forces

- **Coordinator path is production** → a fresh checkpoint carrying the
  `ending_plan` is recorded at `ending_autosave`; the round-trip works; the test
  is pure proof with **zero production change**.
- **`advance_day_or_end()` direct path is production** → the autosave is stale
  (no `ending_plan`); the test goes RED; the **minimal, targeted fix** is to
  record a stable checkpoint carrying the `ending_plan` at the ENDING boundary
  before the autosave (or route that entry through the coordinator so the
  existing `ending_autosave` stage records it). No new save-core machinery.

## Testing

Integration test under `tests/integration/`, following the existing
`test_restore_*` patterns: SaveManager initialized with injected `FakeFileOps`
storage, GameState driven through the real end-of-day-7 flow, then
`load_autosave()` / restore and assertions on the reconstructed lifecycle. Run in
isolation via `Invoke-IsolatedGodot.ps1`. Full blast-radius re-run of the
save/restore and game_state clusters before commit (no regressions).

## Success criteria

- A passing integration test proving: enter ENDING on day 7 → autosave → load
  autosave → run is ENDING with the exact `ending_plan`, day 7; and the restored
  run re-walks to COMPLETED at the menu with the gallery recorded.
- If the test was RED, the minimal fix that makes it GREEN, with no regressions
  across the save/restore/migration and game_state clusters.
- Task 6's disk-recovery story for `.7` is closed; per-transition disk
  checkpoints are recorded as a tracked `.8` item.

## Deferred to `.8`

- Per-transition disk checkpoints so a crash resumes at the exact mid-playback
  stage without re-walking. This is coupled to the real Dialogic playback port
  and its restore-resume, both `.8` deliverables. Until then, re-walk from the
  ENDING boundary (idempotent) is the recovery behavior, which for a
  visual-novel ending means replaying from the ending's start after a crash — an
  accepted trade-off for `.7`.
