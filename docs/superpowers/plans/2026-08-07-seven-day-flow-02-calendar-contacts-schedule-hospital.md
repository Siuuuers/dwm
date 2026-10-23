# Seven-Day Flow Phase 02: Calendar, Contacts, Schedule, and Hospital Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the exact seven-day calendar, ordinary-message/echo obligations, read-as-acceptance invitations, ephemeral schedule draft with Done commit, both P–L group windows, and idempotent Hospital closures through the existing day-resolution transaction shell.

**Architecture:** One pure `SevenDayCalendar` owns fixed slots. `ContactInvitationState` remains the single detached contact bag and gains ordinary messages, echo obligations, per-window group actions, and exact closure reasons. `ScheduleRules` validates UI-local drafts and committed schedules. `HospitalRules` derives one detached resolution receipt. `GameStateDayResolutionPort` composes these owners through `DayResolutionCoordinator`; UI wiring waits until Plan 05.

**Tech Stack:** Godot 4.6.3, GDScript pure `RefCounted` modules, existing `GameState` facade, GUT model/table tests, injected checkpoint port.

## Global Constraints

- [ ] Required skills: `domain-modeling`, `api-and-interface-design`, `godot-master` with `autoload-architecture`, `state-machine`, `save-load-systems`, and `testing-patterns`, plus `test-driven-development`, `incremental-implementation`, and `superpowers:verification-before-completion`.
- [ ] Phase 00 requirements must be green; use Plan 01's stable entry/reply/echo IDs.
- [ ] Do not wire or author DTL presentation in this plan.
- [ ] Ordinary replies are stat-neutral. They may create only a selected reply record and pending echo obligation.
- [ ] Solo invitation read commits acceptance. There is no separate solo accept/decline/reply command.
- [ ] Preserve `REPLY_REQUIRED` only for the original P–L group invitation.
- [ ] Schedule-bar contents before Done are UI-local and reversible. Run state receives committed entries only inside `request_schedule_done()`.
- [ ] Hospital is derived only from the approved sequela/danger predicate and timing. It is never random.
- [ ] Every command is prepare/commit with an idempotent receipt. Presentation completion cannot create or erase contact/schedule/Hospital consequences.

---

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Approved fixed calendar | One validated calendar owner and stable slot IDs |
| 2 | Calendar plus Plan 01 reply/line/atom IDs | Ordinary records and guaranteed echo obligations |
| 3 | Calendar/contact state | Read-as-acceptance solo actions and two group-window states |
| 4 | Accepted actions | UI-local draft and one atomic Done schedule commit |
| 5 | Committed schedule/contact facts | Hospital closures, Sylvia witness receipt, typed pair input |
| 6 | Tasks 1–5 plus checkpoint contract | Hospital-before-date day stages and typed date/pair pending intents |

## Task 1: Centralize the fixed seven-day calendar

**Specification:** Sections 7.1–7.2, 11.1.

**Files:**

- Create: `scripts/domain/calendar/SevenDayCalendar.gd`
- Create: `tests/unit/test_seven_day_calendar.gd`
- Modify after parity: `scripts/data/DataCatalog.gd`
- Modify after parity: `autoload/GameState.gd`

- [ ] Write RED tests for this exact data:

```gdscript
const ORDINARY_BY_DAY := {
	1: "lavinia", 2: "sylvia", 3: "priscilla",
	4: "lavinia", 5: "priscilla", 6: "sylvia",
}
const SOLO_BY_DAY := {
	1: ["priscilla", "sylvia"],
	2: ["priscilla", "lavinia"],
	3: ["lavinia", "sylvia"],
	4: ["priscilla", "sylvia"],
	5: ["lavinia", "sylvia"],
	6: ["priscilla", "lavinia"],
}
const SOLO_ROUND_BY_DAY := {
	1: {1: "priscilla", 2: "sylvia"},
	2: {1: "priscilla", 2: "lavinia"},
	3: {1: "lavinia", 2: "sylvia"},
	4: {1: "priscilla", 2: "sylvia"},
	5: {1: "lavinia", 2: "sylvia"},
	6: {1: "priscilla", 2: "lavinia"},
}
```

- [ ] Test friend windows exactly: Priscilla `1,2,4,6`; Lavinia `2,3,5,6`; Sylvia `1,3,4,5`. Day 7 has no ordinary message or challenge slot.
- [ ] Implement closed static queries:

```gdscript
class_name SevenDayCalendar
extends RefCounted

static func validate() -> Dictionary
static func ordinary_friend(day: int) -> String
static func ordinary_entry_id(day: int) -> String
static func solo_friend_for_round(day: int, round_number: int) -> String
static func solo_invitation_entry_id(day: int, friend_id: String) -> String
static func challenge_slot_id(day: int, friend_id: String) -> String
static func group_window_for_day(day: int) -> Dictionary
static func day7_invitation_round(friend_id: String) -> int
```

- [ ] Reject day outside `1..7`, round outside its allowed set, unknown friend, and friend/day mismatch. Return empty/failed values; never infer a nearest day.
- [ ] Replace duplicate `_INVITATION_DAYS`, `_CONTACT_MESSAGE_ORDER`, and `DataCatalog` calendar literals only after characterization tests prove every current caller now delegates to `SevenDayCalendar`.
- [ ] Run GREEN and commit:

```text
refactor(calendar): centralize seven-day message and invitation slots
```

## Task 2: Add ordinary messages and guaranteed echo obligations

**Specification:** Sections 7.1, 7.3, 9, 12.5, 12.8.

**Files:**

- Modify: `scripts/domain/contact/ContactInvitationState.gd`
- Modify: `tests/unit/test_contact_invitation_state.gd`
- Create: `tests/unit/test_ordinary_message_echoes.gd`
- Modify: `autoload/GameState.gd`

- [ ] Extend `make_defaults()` with exact primitive fields:

```gdscript
{
	"ordinary_by_day": {},
	"ordinary_expiry_tombstones": {},
	"reply_receipts": {},
	"pending_echoes": [],
	"satisfied_echo_receipts": {},
	# existing solo/group/history/watermark fields remain
}
```

- [ ] Write RED tests for six generated messages, exactly three registered reply IDs each, one reply maximum, stat neutrality, ignored midnight expiry, no player-facing ignored history record, internal expiry tombstone idempotency, and no D7 ordinary message.
- [ ] Add pure methods:

```gdscript
static func prepare_generate_ordinary(state: Dictionary, day: int, transaction_id: String) -> Dictionary
static func prepare_reply_ordinary(state: Dictionary, day: int, reply_id: String, witnessed_line_id: String, witnessed_plain_text: String, content_version: int, transaction_id: String) -> Dictionary
static func prepare_expire_ordinary(state: Dictionary, day: int, transaction_id: String) -> Dictionary
static func prepare_satisfy_echo(state: Dictionary, echo_id: String, presentation_atom_id: String, transaction_id: String) -> Dictionary
static func pending_echoes_oldest_first(state: Dictionary, up_to_day: int) -> Array[Dictionary]
```

- [ ] Derive the `echo_id` by replacing the exact leading `reply.` of a Plan 01 reply ID with `echo.`; callers cannot supply an arbitrary echo. `prepare_reply_ordinary()` stores the exact registered reply, authoritative line ID, content version, and an inert plain-text snapshot. Validate the snapshot against the registered rendered line, cap it at 512 UTF-8 bytes, normalize line endings, reject control characters, escape markup delimiters, and never parse it as DTL, BBCode, a path, or a command. Migration initializes no fabricated snapshot when old data lacks one.
- [ ] A first valid echo atom satisfies the mandatory obligation exactly once. Later authored callbacks may reference the reply but cannot reactivate or duplicate the guarantee receipt.
- [ ] Add `GameState` facade commands that prepare the contact candidate, checkpoint it, commit it, and publish only after success. `ContactListApp` may open the registered ordinary-message entry, but only Plan 05's `DialogicSignalCommandPort` may invoke the reply facade after validating `message.reply.commit` against the active playback token, source entry, stage, and payload. `ContactListApp` never commits an A/B/C reply or mutates the bag.
- [ ] Assert all 18 replies leave affection, dark, tier, attitude, schedule, invitation availability, pair count, and ending eligibility byte-equal.
- [ ] Run GREEN and commit:

```text
feat(contacts): add stat-neutral messages and echo obligations
```

## Task 3: Make solo opening acceptance and group state per-window

**Specification:** Sections 6.3, 7.2–7.5.

**Files:**

- Modify: `scripts/domain/contact/ContactInvitationState.gd`
- Modify: `tests/unit/test_contact_invitation_state.gd`
- Create: `tests/scenario/test_contact_calendar_lifecycle.gd`
- Modify: `autoload/GameState.gd`

- [ ] Write RED tests for each solo window:

  - round 1/2 creates one unread offer idempotently;
  - opening records read + scripted acceptance and makes it addable;
  - no `prepare_reply()` is needed or legal for a solo action;
  - unread expiry queues one next-day nevermind;
  - accepted/unfulfilled queues one next-day missed question;
  - accepted/attended queues neither;
  - Day 7 creates no Day 8 follow-up.

- [ ] Change `prepare_open_contact()` so a solo `AVAILABLE_UNOPENED` action transitions directly to `ACCEPTED`, with one acceptance receipt. Retire solo use of `prepare_reply()`; retain its group-only validation.
- [ ] Replace the single `group_action` with `group_actions_by_window` keyed by stable window ID (`pair.priscilla_lavinia.day2`, `.day6`). Migrate queries to require a day/window and prove D2 resolution does not prevent D6 activation.
- [ ] Add and RED-test `ContactInvitationState.migrate_v2_to_current(v2_state)`. It preserves messages, read watermarks, solo action IDs, transaction receipts, and `next_sequence`; maps old solo `AVAILABLE` to `AVAILABLE_UNOPENED` and retains recognized terminal states; creates both exact group-window records; maps an `INACTIVE` old group to two inactive defaults, or requires an active/resolved old group's `day` to be exactly 2 or 6 and places it only in that matching window while the other remains inactive. Unknown state/day/key shapes reject non-destructively rather than guessing.
- [ ] Exhaust the original group protocol:

  - round 3 activates only if both same-day solo offers remain unread/available;
  - activation atomically supersedes those solos;
  - first open fixes presentation-only inviter and moves to `REPLY_REQUIRED`;
  - either participant reply accepts the single group action;
  - second distinct reply changes only judgment variation;
  - repeat receipt is idempotent;
  - group uses one schedule slot and cannot coexist with superseded solos.

- [ ] Keep contact presentation order data as `carryover -> ordinary -> invitation`. All items append; none replaces another.
- [ ] Run the scenario twice from the same transaction IDs to prove no duplicate history or closure.
- [ ] Commit:

```text
feat(invitations): accept solo reads and persist both group windows
```

## Task 4: Make schedule draft ephemeral and Done atomic

**Specification:** Sections 6.3, 7.2, 11.1, 12.5.

**Files:**

- Modify: `scripts/domain/schedule/ScheduleRules.gd`
- Create: `scripts/ui/ScheduleDraftController.gd`
- Modify: `tests/unit/test_schedule_rules_phase2r.gd`
- Create: `tests/unit/test_schedule_draft_controller.gd`
- Modify: `autoload/GameState.gd`
- Modify: `scripts/application/run/DayResolutionCoordinator.gd`

- [ ] Characterize and then remove the unapproved Day-4-Priscilla-first-slot special case from `ScheduleRules`.
- [ ] Write RED tests for:

  - Days 1–6 max two distinct solo friends, in player-chosen order;
  - one accepted group action occupies one date slot;
  - existing non-date `action` entries remain legal under their characterized slot/cost rules and never count as a romantic date;
  - superseded solos are ineligible;
  - duplicate action/slot/friend entries reject;
  - draft add/remove/reorder changes no `GameState` or motivation;
  - closing Schedule without Done discards the draft;
  - Done validates the whole draft, then commits it once;
  - Day 7 max one eligible destination or empty Done for Alone.

- [ ] Use an exact committed entry schema and remove pre-Done canonical writes/refunds.

```gdscript
{
	"schedule_entry_id": String,
	"day": int,
	"slot_index": int,
	"action_id": String,
	"action_kind": "solo" or "group" or "action",
	"participants": Array[String],
	"source_receipt_id": String,
	"commit_transaction_id": String,
	"state": "committed",
}
```

Reject extra keys; `participants` is one friend for solo, exactly `priscilla, lavinia` in that order for group, and empty for a non-date action. `source_receipt_id` is the invitation-acceptance receipt for dates or the registered availability receipt for an action. The v2 migration mapping is exact: old `day`, `slot_index`, `action_id`, `type`, and `friend_ids` become `day`, `slot_index`, `action_id`, `action_kind`, and `participants`. `schedule_entry_id` is `schedule.migrated.v2.` plus the lowercase canonical SHA-256 of `run_id`, old `entry_id`, day, and slot; `commit_transaction_id` is `migration.v2.schedule.` plus the same digest; `state` is `committed`. A nonempty old `unlock_receipt_id` (legal only for a validated Day-7 solo) becomes `source_receipt_id` byte-for-byte. The required v2 `null` on D1–6 and non-date entries produces `source_receipt_id = migration.v2.availability.` plus the same digest and an exact matching migration-only availability receipt in the appropriate migrated contact/action owner; duplicate replay reuses that receipt, while a conflict rejects. Old `route_id` and sorted `effect_ids` must equal the current registered action record and are then omitted as redundant derived data; a mismatch, illegal receipt shape, duplicate digest, or unknown old action fails migration non-destructively. This maps current `type = action` to the third kind without discarding or misclassifying it as romance. Date-count/Dark-mode gates inspect only solo/group kinds.
- [ ] Implement `ScheduleDraftController` as a scene-local `RefCounted`:

```gdscript
class_name ScheduleDraftController
extends RefCounted

func reset_from_available(available: Array[Dictionary], day: int) -> void
func try_add(entry: Dictionary, motivation: int, eligibility: Dictionary) -> Dictionary
func remove_at(index: int) -> Dictionary
func move(from_index: int, to_index: int) -> Dictionary
func snapshot() -> Array[Dictionary]
```

- [ ] Change the facade to `request_schedule_done(command_id: String, draft_entries: Array) -> Dictionary`. Validate and deep-copy the complete draft inside the transaction; starting the request is the schedule commit boundary.
- [ ] Keep a migration-only compatibility path for old saves that already contain pre-Done entries; it applies only the exact mapping above at restore and treats the normalized entries as the already committed historical schedule. It never recreates pre-Done canonical editing or refunds.
- [ ] Run GREEN and commit:

```text
feat(schedule): commit ephemeral drafts only on Done
```

## Task 5: Implement exact Hospital cause and closure rules

**Specification:** Sections 7.3–7.5, 11.1, 12.5.

**Files:**

- Create: `scripts/domain/hospital/HospitalRules.gd`
- Create: `scripts/domain/run/DesktopActionReceipt.gd`
- Create: `scripts/application/run/DesktopActionConditionCoordinator.gd`
- Create: `tests/unit/test_hospital_rules.gd`
- Create: `tests/unit/test_desktop_action_receipt.gd`
- Create: `tests/integration/test_desktop_action_condition_coordinator.gd`
- Modify: `scripts/domain/contact/ContactInvitationState.gd`
- Modify: `tests/scenario/test_hospital_twofriends_order.gd`
- Create: `tests/scenario/test_hospital_invitation_closures.gd`
- Modify: `scripts/domain/ending/DatingEndingRules.gd` only to delegate old Hospital queries during migration

- [ ] Write RED tests for the exact predicate:

```gdscript
danger := pressure >= 10 or health <= 0
trigger := carried_sequela and danger
```

Test real-time checks only after a committed desktop Minesweeper app round or Shop purchase; test Days 1–6 end-of-day check after Done and before dates; test D7 Done bypass.
- [ ] Implement:

```gdscript
class_name HospitalRules
extends RefCounted

static func prepare_condition_check(input: Dictionary, transaction_id: String) -> Dictionary
static func prepare_day_resolution(input: Dictionary, transaction_id: String) -> Dictionary
```

The detached receipt owns cause, internal health/pressure inputs, carried-sequela state, trigger, accepted/unfulfilled action IDs, closure records, Sylvia witness result, and deferred pair scene identity.
- [ ] `DesktopActionReceipt` validates the common app/Shop handoff with exact keys `schema_version`, `action_id`, `action_kind`, `day`, `transaction_id`, `source_commit_receipt_id`, `condition_before`, `condition_after`, `unlock_receipt_ids`, and `commit_receipt_id`. Kind is `minesweeper_round | shop_purchase`; each condition record has only health, pressure, and carried-sequela; arrays are sorted unique strings.
- [ ] `DesktopActionConditionCoordinator.accept_committed_action()` durably marks the receipt `condition_check_pending` before evaluation. On Days 1–6 it calls `prepare_condition_check()` immediately, before enabling another desktop action. Triggered results lock the desktop, close/queue every invitation through the same Hospital day transaction, retain the Sylvia witness receipt for Plan 03, route the day-specific Hospital entry, and never launch a date board. Non-triggered results mark the check complete and then publish the no-faint notification. Crash/reload resumes the pending check before any input.
- [ ] The coordinator exposes a Day-7 policy port but does not invent Day-7 precedence here. Plan 05 binds `DaySevenRules` into that port; the same pending-action durability and no-next-action law applies on every day.
- [ ] For every accepted/unfulfilled solo action, create exactly one `missed_reason = hospital` closure; never add a generic duplicate. Unread offers still create normal nevermind closures.
- [ ] For Priscilla/Lavinia, queue one next-day Hospital-reason missed question each. For Sylvia, create no missed question; queue one scripted caring message next day and one `sylvia_hospital_witness` effect receipt.
- [ ] The Sylvia receipt derives, never accepts from DTL: `affection +2` clamped, `dark +1` capped, attitude Fixated, and exactly one tier step regardless of affection. It records no board/result/mastery.
- [ ] Hospital records the actual committed-attendance facts and emits one typed `pair_resolution_input` for D2/D6: a superseded solo is not attended; accepted group maps to visible Missed; unaccepted generated group maps to Private-visible; never-generated group maps to Private-offscreen. It does not calculate pair count/deck state; Plan 03's pure rules consume this receipt and Plan 04 owns the profile-backed draw/commit.
- [ ] Run GREEN and commit:

```text
feat(hospital): close accepted dates with exact witness receipts
```

## Task 6: Replace synthetic day-resolution receipts with real domain composition

**Specification:** Sections 7.3–7.5, 12.5, 14.3–14.4.

**Files:**

- Modify: `scripts/application/run/GameStateDayResolutionPort.gd`
- Modify: `scripts/domain/run/DayResolutionPlan.gd`
- Modify: `scripts/application/run/DayResolutionCoordinator.gd`
- Modify: `scripts/application/run/SaveManagerCheckpointPort.gd`
- Modify: `autoload/GameState.gd`
- Modify: `tests/unit/test_day_resolution_coordinator.gd`
- Modify: `tests/unit/test_game_state.gd`
- Create: `tests/integration/test_day_resolution_production_port.gd`

- [ ] Write RED tests proving the current synthetic `_immediate_receipt()` cannot count as success: live schedule, invitation closures, condition result, Hospital, date-launch intents, deferred P–L request, and day transition must appear in exact stage receipts.
- [ ] Make `begin_or_resume()` capture the committed schedule and exact current state, not `[]`.
- [ ] Change `DayResolutionPlan.DAY_1_6_STAGES` so `validate_and_close_schedule -> evaluate_condition_and_hospital -> launch_solo_dates -> resolve_pair_window -> publish_followups -> advance_day`. Hospital therefore resolves after Done and before any solo/group date launch. Add an exact order assertion; no legacy stage may execute dates before the condition result.
- [ ] At each stage, call the pure owner and return a candidate + receipt. Keep commit order checkpoint-first then run-state, publication last, with reverse rollback and fatal latch on unprovable recovery.
- [ ] A date stage emits a typed engine `launch_date` intent and remains pending; it never fabricates a board result. Plan 03 adds the terminal challenge adapter without changing this stage order. Pair resolution remains a typed request until Plan 04 supplies the profile-backed draw/commit.
- [ ] Hospital completes before every solo date and every deferred visible P–L scene. Hospital-triggered plans launch no date board; a deferred pair scene may still follow only when its approved encounter form requires it.
- [ ] Produce the full `SaveManagerCheckpointPort.CHECKPOINT_INPUT_KEYS` bundle required by `dwm-7e6`; remove the `{run_id, day}` stub. If the Dialogic checkpoint dependency from Plan 01 is unavailable, stop this task rather than weakening validation.
- [ ] Exhaust crash/retry around prepare, checkpoint commit, run commit, publication, and stage completion.
- [ ] Run GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_flow_transactions' -LogName 'seven-day-flow-transactions.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_seven_day_calendar.gd,res://tests/unit/test_contact_invitation_state.gd,res://tests/unit/test_ordinary_message_echoes.gd,res://tests/unit/test_schedule_rules_phase2r.gd,res://tests/unit/test_hospital_rules.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/integration/test_day_resolution_production_port.gd,res://tests/scenario/test_contact_calendar_lifecycle.gd,res://tests/scenario/test_hospital_invitation_closures.gd,res://tests/scenario/test_hospital_twofriends_order.gd','-gexit')
```

- [ ] Commit:

```text
feat(run): execute calendar schedule and Hospital receipts
```

## Phase 02 Verification Gate

- [ ] The exact six ordinary-message and twelve solo-invitation windows validate from one owner.
- [ ] All 18 replies are stat-neutral and create one oldest-first echo obligation.
- [ ] Solo open is acceptance; group alone uses `REPLY_REQUIRED`.
- [ ] D2 and D6 group actions both activate in one persisted run.
- [ ] Draft schedule changes are noncanonical; Done commits at most two ordered dates.
- [ ] Hospital uses exact cause/timing, independent miss records, an exact detached Sylvia witness/care receipt, and no fabricated challenge; Plan 03 binds that receipt to the relationship owner once.
- [ ] Every committed D1–6 app/Shop action leaves a durable pending check, performs Hospital routing before another action, and resumes safely after a crash.
- [ ] Every non-board day-resolution stage contains real state and full checkpoint inputs; date/pair work is a typed pending intent rather than a synthetic success receipt.
- [ ] DTL/UI still cannot mutate these owners directly.
