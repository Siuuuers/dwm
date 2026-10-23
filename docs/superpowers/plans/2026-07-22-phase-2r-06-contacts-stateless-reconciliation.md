# dwm-p2r.6 — Stateless contact-module rebuild (reconciliation overlay)

**Status:** approved direction (2026-07-22). Supersedes the holistic *stateful* build committed at `125f247`.
**Base plan:** `docs/superpowers/plans/2026-07-17-phase-2r-04-invitations-schedule-endings.md` Tasks 1–3 — execute those **exact-path** steps verbatim for the stateless architecture, with only the deltas enumerated here.
**Beads:** dwm-p2r.6.

## Why this exists

The session build shipped `ContactInvitationState.gd` as a **stateful `RefCounted`** (`generate_message`/`open_solo_offer`/`resolve_pl_window`/`to_dict`/`from_dict`), then wired an instance into `GameState` as `_contacts`. That diverges from plan-04's frozen architecture and from the reserved surface-inventory signatures. We adopt plan-04's **stateless** design:

- `ContactInvitationState.make_defaults() -> Dictionary` and pure `prepare_*(state, …, tx)` functions returning a **frozen `CommandResult`** `{ok, code, value:{candidate, message_batch}, receipt:{…}}`.
- `GameState` owns **one primitive `contacts` Dictionary**, never a module instance (plan-04 Task 3: "never stores a second module-owned copy").
- Idempotency/rollback are **by construction**: prepare returns a candidate; the facade commits or discards it through the checkpoint+run two-port seam.

The stateful module's **rule logic is canon-correct and salvageable** — transliterate it into the stateless functions; discard only its *shape*.

## What this session already established (carry forward)

- The save seam round-trips a contact bag through the real JSON path (verified: scratch 2/2, `test_game_state` 28/28, `run_snapshot_schema` 8/8, `save_migrations` 11/11, `facade_contract` 5/5, `save_manager` 7/7 — no regressions).
- **JSON int→float constraint (reusable):** `JSON.parse_string` turns integers into floats. Any restore/validate path over the `contacts` dict (watermarks, sequences, `day`, `pair_counter`) MUST accept an *integral float*, not require `TYPE_INT`. Apply in `make_defaults`/validation exactly as the reverted `_is_integral_number` fix did.
- Working tree reverted to `125f247` (throwaway `_contacts` wiring + `contact_invitation` save field + JSON fix removed).

## Reconciliation deltas vs plan-04 (the only places plan-04 is stale)

Plan-04 predates the 2026-07-19/07-21 canon amendments (`story/05-canon-amendments-2026-07-19.md` §7, §13) and the `.6` grilling. Audited against them:

1. **Solo nevermind-for-both — ALREADY aligned; no change.** Plan-04 Task 1 table (lines 342–343) queues the same nevermind for both `unopened-and-unanswered` and `opened-and-unanswered`. This is exactly the amended `req.invitation.solo`. Keep verbatim.
2. **Append-only history + watermarks — ALREADY aligned; no change.** Plan-04's `read_watermarks[friend_id]` + immutable appended records satisfy `req.contact.history_watermark`. Keep verbatim.
3. **Group PL window — RECONCILE (the real delta).** Plan-04's group day-end (`group_outcome ∈ not_scheduled|attended|not_attended|prevented_by_fainting`) resolves the group **date's** attendance, but does NOT encode the §7 amended **four-way counted Priscilla–Lavinia window**. Extend `prepare_resolve_day_end`'s group portion to resolve the amended window on the one rule *"did Angela solo-date either participant?"*:
   - **prevented** — Angela solo-dated exactly one of {priscilla, lavinia}: the pair does NOT meet, NO count, pair_counter unchanged. (Overrides any `group_outcome`.)
   - Angela solo-dated **neither** → the window counts exactly once, as one of:
     - **group** — offer generated + attended (`group_outcome=attended`).
     - **missed** — offer generated + accepted-then-unattended (`group_outcome=not_attended`/`prevented_by_fainting`); guilt flavor.
     - **private-visible** — offer generated + **both** participants' group messages left unread; neutral-flavor scene.
     - **private-offscreen** — offer **never generated**; the pair meets with no player-visible scene; counts invisibly.
   - Only the three offer-generated outcomes (group/missed/private-visible) are audience-visible and mark the seen state/tone combination; **private-offscreen counts but is invisible**. A **prevented** window MUST NOT increment `pair_counter`. Port this decision table from the reverted module's `resolve_pl_window`; it is canon-correct.
4. **`group_outcome` stays the group-date attendance signal**; the four-way window is computed *from* `group_outcome` + generation/read state + solo-date facts, not by widening the enum. `counter_deltas` in the resolve receipt carries the pair-counter increment (0 for prevented/no-count).

### §3a — Composition with plan-04's group-resolution table (decided 2026-07-23)

Reading plan-04's actual Days-1–6 group table (base-plan lines 744–791) against §7 exposed two *overlapping* mechanisms for the same twofriends/epilogue feature. Resolution (canon precedence: §7 is later and approved):

- **Keep** plan-04's message-effect layer unchanged: `busy` (wholly untouched), `nevermind` (opened/visible, zero replies), `judge` (one-reply attended, to the canonical unreplied participant), `missed_question` (accepted non-attendance); plus `deferred_twofriends` routing and `after_hospital` on `prevented_by_fainting`; plus `date_outcome_ids`; plus Day-7 → `RESOLVED_RUN_END` silent. These are the message/history/routing layer and are orthogonal to counting.
- **Replace** plan-04's `missed_group_date_counts.priscilla_lavinia` counter with §7's four-way **pair-meeting** counter. The window counts once (pair meets) in group/missed/private-visible/private-offscreen; `prevented` does not count. `should_route_pl_epilogue` at `pair_counter >= 2` (both day-2 and day-6 windows met) is the twofriends/epilogue trigger, superseding the missed-count trigger.
- **private-visible** = group offer generated but both participants' group messages left unread at day-end (plan-04's `busy`/untouched case still emits its `busy` messages, but for counting it is a private-visible meeting that counts). **private-offscreen** = offer never generated (group never activated on a window day): no messages, counts invisibly.
- `counter_deltas` therefore carries `{"pl_window_counts.priscilla_lavinia": 1}` on any counting outcome, `{}` on `prevented`/day-7. (Rename from plan-04's `missed_group_date_counts` key to reflect the meeting-count semantics.)

Port the decision table from git `125f247`'s `_classify_pl_window`; it already encodes exactly this four-way logic (prevented → no count; not-activated → private_offscreen; attended → group; schedulable-but-unattended → missed; else → private_visible). This §3a interaction is canon-critical — implement it test-first with an explicit case per row before the facade work.

## Execution order (plan-04 exact-path, test-first)

Run each plan-04 task's RED→GREEN→commit boundary as written. Commit boundaries require `DWM_COMMIT_AUTHORIZED=1` (currently unset — the user sets it per boundary).

- **Task 1 — solo.** `make_defaults`, `prepare_offer_solo`, `prepare_open_contact` (sets `read_watermarks` only), `prepare_reply` (AVAILABLE→ACCEPTED), `prepare_resolve_day_end` solo portion. Files/tests/fixtures per plan-04 Task 1. Commit: `feat(contacts): separate solo invitation actions from message history`.
- **Task 2 — group activate/open/reply.** `prepare_activate_group_after_round`, first/second-participant group open (inviter_id assignment), either-participant reply → ACCEPTED. Group state enum `INACTIVE|AVAILABLE_UNOPENED|REPLY_REQUIRED|ACCEPTED|RESOLVED_*` with `action_id`/`day`. Commit: `feat(invitations): activate and open group offers atomically`.
- **Task 3 — group resolution + facade.** `prepare_resolve_day_end` group portion **with delta §3 above**; then the facade: `GameState.open_contact(friend_id, command_id)`, `reply_invitation(friend_id, command_id)`, `resolve_invitations_for_day(attendance, command_id)` → each prepares run/contact candidate + receipt ledger + checkpoint, commits checkpoint-then-run, publishes signals only after both, reverse-rolls-back on later failure, and on unprovable recovery calls the injected `ApplicationMutationGate.latch_fatal()` → `APPLICATION_FATAL`. Commit: `feat(invitations): resolve exact solo and group rollover branches`.

## Save + readers + surface (Task 3 scope)

- **State home:** `GameState` holds one primitive `contacts` Dictionary (from `make_defaults`); query methods call stateless functions, never mutate from ready/render.
- **Snapshot:** `RunSnapshotSchema.GAMEPLAY_FIELDS` carries `contacts` (replaces the reverted `contact_invitation`). Retire `contact_message_unlocks` and `contact_choice_state`.
- **Migration:** `SaveMigrations` maps legacy `daily_opened_contacts`/`daily_group_invitation_*`/`contact_message_unlocks`/`contact_choice_state` forward into the `contacts` bag (or drops with a documented default for pre-.6 saves).
- **Readers to rewire:** `is_date_unlocked`, `get_day7_ending_candidates_from_schedule`, `read_group_offer`/`is_group_date_unlocked`, `collect_unscheduled_accepted_invitations_for_day_end`, `ScheduleApp`, day-resolution (`DayResolutionCoordinator`/`GameStateDayResolutionPort`), `ContactListApp` (renders `get_contact_view()`; opening calls `open_contact()` once), `InputManager`.
- **Surface inventory:** promote `open_contact`/`reply_invitation`/`resolve_invitations_for_day` from RESERVED to implemented in `tests/unit/tooling/test_public_surface_inventory.gd`; regenerate `evidence/phase_2r/runtime/game_state_required_surface.json`.

## Acceptance (from the bead)

All solo/group activation, opening, reply, schedule-addability, attended, missed, fainted, untouched, unanswered, one-reply, two-reply, and Day-7 run-end branches pass; history never disappears; reads do not answer; messages are unread on their target day; duplicate commands and resume cannot duplicate history or effects. Verify via `tests/scenario/test_invitation_branches.gd` (run the full matrix twice for resumed idempotence) plus the updated unit suites.
