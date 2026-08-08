# Schedule Validation Consolidation + Done-Flow Design (dwm-p2r.7 Task 4, validation slice)

Status: approved design, pending implementation plan
Date: 2026-08-03
Scope: dwm-p2r.7 Task 4 — the *validation-correctness* slice only. Persistence,
strict entry shape, Day-7 candidate validation, and the full `validate_candidate`
are deferred to the `.8` save integration (dwm-7e6). The Done-flow UI is designed
here but built later.

## Goal

Make `ScheduleRules` the single source of truth for the schedule **date rules**
in live play (Days 1-6), correcting latent inconsistencies in today's date
validation, while keeping the current loose entry shape. Separately, record the
intended **Done-flow** design (advisory, dismissible warnings) so the future
`ScheduleApp` Done-handler task builds it faithfully.

## Context and findings

- Two validators exist. GameState's live `_can_add_date_entry` and the pure
  `ScheduleRules` encode the **same core date rules** — too-many-dates, Day-4
  Priscilla-first-slot, one-date-per-friend (solo) / per-pair (group). They were
  built to match canon, so this slice is a consolidation, not a rules change.
- **Latent inconsistency to correct.** `_can_add_date_entry` is an *add-time*
  guard (`get_scheduled_date_count() >= max` → cannot add another). But
  `validate_schedule` and the remove-cascade **reuse it on entries already in the
  schedule**. That double-counts (a full, valid 2-date week evaluates each entry
  with `count(2) >= max(2)` → `invalid_date`) and the duplicate-friend loop
  self-matches an entry against itself. It is latent because no current test
  schedules dates, so the buggy path is unexercised.
- **Resolution hard-blocks invalid schedules.** `execute_schedule_sequence_until_
  route_needed()` returns `reason: "invalid_schedule"` if `validate_schedule()`
  fails. The "strict placement" model below keeps the schedule valid by
  construction, so this invariant is never threatened.
- **`ScheduleApp` (the Done UI) is a skeleton** — no Done handler, no warning
  overlay wired. Both the placement flow and the Done flow are unbuilt; the logic
  lives in GameState. So the Done-flow here is *recorded*, not built.
- **`twofriends` is system-deferred**, created by
  `create_missed_group_twofriends_entry` during resolution, never user-scheduled.
  It stays outside `ScheduleRules` (the callers bypass it).
- Persistence and the strict entry shape (`slot_index`, `unlock_receipt_id`) are
  motivated by the coordinator/save path, which is `.8`-blocked (dwm-7e6).

## The buildable slice (build now)

### New pure function

`ScheduleRules.validate_date_candidate(existing: Array, candidate: Dictionary,
day: int) -> Dictionary` returning `{ok: true}` or `{ok: false, code}` with a
**specific** code: `too_many_dates`, `priscilla_first_slot_required`, or
`duplicate_friend_date`.

- Operates over the **loose** date shape: `type` in `solo`/`group`; friends read
  from `friend_id` (solo) or `friend_ids` (group).
- Contract: `existing` is the **other** entries — the candidate is excluded — so
  there is no self-match ambiguity.
- Rules (mirroring canon and the live intent):
  - `too_many_dates`: current date count `>= max_dates_for_day(day)`.
  - `priscilla_first_slot_required`: a Day-4 `solo` Priscilla date when `existing`
    is non-empty (Priscilla must take the first slot on Day 4).
  - `duplicate_friend_date`: a same-type entry already names the same friend
    (solo) or same pair (group).
- Not `twofriends`' concern; callers never route `twofriends` here.

### Delegation — single source of truth + correction

`_can_add_date_entry(entry)` becomes: `twofriends` → `true` (unchanged);
otherwise compute `existing = schedule_entries` **excluding this entry** (by
identity/position) and return `validate_date_candidate(existing, entry, day).ok`.

This yields correct semantics at **both** call sites: add-time (candidate not yet
in the schedule → `existing` = all current entries) and validate-time / remove-
cascade (candidate already present → excluded). All callers
(`can_add_schedule_action`, `add_schedule_date_entry`, `validate_schedule`, the
remove-cascade) now share the one canon implementation, and the latent
double-count / self-match is corrected as a byproduct.

### Reason codes

`validate_date_candidate` returns the specific codes above. `_can_add_date_entry`
keeps returning a bool so existing callers are source-compatible;
`can_add_schedule_action` maps to its current reasons as today. The specific
codes exist for the future Done warning to render helpful messages ("you can only
plan 2 dates that day", "Priscilla goes first on Day 4", "you already planned a
date with her") rather than a generic reason.

### Characterization first

Before delegating, extend the characterization net to pin the current date-path
behavior — adding a solo/group date, a duplicate, an at-max schedule, a Day-4
Priscilla placement, and `validate_schedule` on a full week — capturing the OLD
behavior *including the latent bugs*. Then delegate and update those tests to the
NEW correct behavior, so the correction is explicit, intentional, and reviewable
in the diff.

### Scope boundary

Loose entry shape kept. No `RunSnapshotSchema` / `SaveMigrations` changes. Day-7
candidate validation (`unlock_receipt_id` / `day7_candidate` chain), the full
`ScheduleRules.validate_candidate`, and persistence all stay for `.8`.

## Recorded Done-flow design (built later, in the ScheduleApp Done-handler task)

- **Strict placement.** You cannot *place* a rule-breaking date — the 7-box bar
  stays valid by construction, so resolution's "no invalid schedule" invariant
  holds and no sanitization is needed at Done.
- **Soft, advisory Done warnings.** The Done overlay warns about non-structural
  things only: unplayed Minesweeper rounds, empty/unused slots, and
  accepted-but-unscheduled invitations (missed dates). Never a structural error.
- **The X is the only door.** On Done, if a warning applies, the overlay appears.
  Pressing Done/Yes again does **not** dismiss it and does **not** proceed. Only
  the overlay's X dismisses it; *then* a Done press proceeds. Validation re-runs
  on each Done press, so if a warning still applies it reappears and again demands
  the X. (A `_done_pressed_guard` prevents a double-press double-resolving.)
- **Empty week allowed; no nanny-gate.** Doing nothing is a valid, if suboptimal,
  choice. Everything is advisory.
- Renders the specific reason/warning codes the validation layer produces.

## Testing

- Pure unit tests for `validate_date_candidate` in
  `tests/unit/test_schedule_rules_phase2r.gd`: OK cases, `too_many_dates`, Day-4
  `priscilla_first_slot_required`, `duplicate_friend_date` (solo and group), and
  the candidate-excluded-from-existing contract (a valid at-max schedule does not
  self-reject).
- GameState characterization/delegation tests: the date-path OLD→NEW behavior
  (documenting the correction) plus behavior-compatibility for action entries and
  `can_add_schedule_action` reasons.
- Run in isolation via `Invoke-IsolatedGodot.ps1`; full blast-radius re-run of the
  schedule and game_state clusters before commit (no regressions elsewhere).

## Success criteria

- `validate_date_candidate` is the single source of truth for the date rules;
  `_can_add_date_entry` delegates to it; the latent validate-time inconsistency is
  corrected and documented by the characterization diff.
- No regressions in action scheduling or `can_add_schedule_action` reasons; the
  date-path behavior is canon-correct.
- The Done-flow design is recorded for the future `ScheduleApp` task.

## Deferred / out of scope

- The `.8` save integration (dwm-7e6): strict entry shape, `RunSnapshotSchema` /
  `SaveMigrations`, Day-7 candidate validation, and the full `validate_candidate`.
- Building the `ScheduleApp` Done-flow UI (advisory warnings, X-only dismissal,
  the overlay and guard). Designed here; built in its own task.
