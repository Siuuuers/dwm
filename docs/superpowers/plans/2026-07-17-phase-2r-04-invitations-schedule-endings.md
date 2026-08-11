# Phase 2R Invitations, Schedule, and Endings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Implement append-only contact history and exact solo/group invitation state machines, separate candidate/existing schedule validation, Hospital-before-twofriends resolution, canonical Day-7 endings, optional group epilogue playback, and idempotent gallery completion.

**Architecture:** ContactInvitationState, ScheduleRules, and DatingEndingRules are pure RefCounted modules behind GameState. DayResolutionPlan owns cross-scene ordering and receipts. Contact history stores semantic message IDs/variants rather than invented prose. Hospital, dating, and ending scenes report completion receipts; they never advance day or decide outcomes.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, pure domain tests, injected scene/narrative playback adapters, and consequential scenario tests.

## Global Constraints

- This plan owns dwm-p2r.6 and dwm-p2r.7.
- .6 starts after .4 and .5 close. .7 starts only after .4, .5, and .6 close.
- History is append-only. Opening changes one read watermark; it never answers an invitation.
- Read-only queries mutate nothing and emit no signal.
- Every append, reply, resolution, outcome, gallery unlock, and playback transition uses a stable transaction ID.
- No message prose is invented. Domain records use registered message IDs, types, variants, and parameters; Dialogic/content work supplies presentation later.
- Day 7 closes actions as RESOLVED_RUN_END and generates no next-day content.
- Hospital and dating scenes return receipts; only RunLifecycle changes day.
- The group ending is never a primary in current state.
- Issue `.7` tests ending playback through an injected `EndingPlaybackPort`; issue `.8` owns the production Dialogic ending manifest/adapter and final `EndingScene` wiring. `.7` MUST NOT consume an API or manifest that `.8` has not implemented yet.
- `implementation_authorized: true` as of 2026-07-18 for the exact task-scoped runtime, scene, test, manifest, and `project.godot` edits below after blockers close. Every commit block remains additionally gated by separate commit authority.
- Proposed commits require separate explicit authority.
- Every proposed commit invokes Plan 01's checked-in `tools/git/Invoke-ExactPathCommit.ps1`. The helper requires `DWM_COMMIT_AUTHORIZED=1`, distinguishes an empty index from Git inspection failure, stages every literal non-UID requirement plus only explicitly listed newly generated `.uid` companions that are present, accepts only the declared `A`/`M`/`D` status for every path, and rejects an empty/missing/extra/malformed/duplicate/rename/copy/type/unmerged staged record. Unless a map explicitly supplies another frozen mode, every Plan-04 entry requires regular-file mode `100644` before and after; symlink, gitlink, executable-bit, and other mode/type drift reject. It also runs the cached diff check, creates one direct child of the supplied `ExpectedHead`, and verifies the new commit's exact path/status/mode/cardinality contract. `.beads/issues.jsonl` and `.beads/interactions.jsonl` may remain as explicit unstaged Beads worktree changes until their owning evidence boundary; no Plan-04 runtime commit stages them.

---

## Task 1: Create append-only contact state and solo invitation rules

**Beads:** dwm-p2r.6

**Files:**

- Create: scripts/domain/contact/ContactInvitationState.gd
- Create: tests/unit/test_contact_invitation_state.gd
- Create: tests/fixtures/invitations/solo_cases.json
- Modify later: autoload/GameState.gd
- Modify later: scripts/ui/ContactListApp.gd

**Interfaces:**

- Consumes: master `CommandResult`; primitive contact-state Dictionary; `RunSnapshotSchema`/checkpoint port from `dwm-p2r.5`.
- Produces: pure static `ContactInvitationState.validate_state/prepare_offer_solo/prepare_open_contact/prepare_reply/prepare_resolve_day_end/prepare_close_for_run_end` plus query methods exactly declared in the master registry. Every prepare success is exactly `{"ok":true,"code":&"ok","value":{"candidate":Dictionary,"message_batch":Array[Dictionary]},"receipt":Dictionary}`. Every failure is exactly `{"ok":false,"code":StringName,"message":String,"details":Dictionary}` and contains no candidate. Closed contact failure codes are `invalid_state`, `invalid_friend`, `invalid_day`, `invalid_message`, `unknown_action`, `invalid_transition`, `invalid_attendance`, `duplicate_transaction_conflict`, and `receipt_invariant_failed`.

- [ ] **Step 1.1: Claim .6 and write the first RED test**

- [ ] Run:

~~~powershell
bd show dwm-p2r.4 --json
bd show dwm-p2r.5 --json
bd show dwm-p2r.6 --json
bd update dwm-p2r.6 --claim
~~~

Both blockers must be closed.

- [ ] Start with these complete behavioral tests:

~~~gdscript
extends "res://addons/gut/test.gd"

const CONTACT_STATE_PATH := \
	"res://scripts/domain/contact/ContactInvitationState.gd"

func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys

func test_defaults_are_empty_and_valid() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	assert_not_null(state_script, "ContactInvitationState must exist")
	if state_script == null:
		return
	var state: Dictionary = state_script.make_defaults()
	assert_eq(state["messages"]["priscilla"], [])
	assert_eq(state["messages"]["lavinia"], [])
	assert_eq(state["messages"]["sylvia"], [])
	assert_eq(state["solo_actions"], {})
	assert_eq(state["transaction_receipts"], {})
	assert_eq(state["next_sequence"], 1)
	assert_null(state["group_action"]["action_id"])
	assert_null(state["group_action"]["day"])
	assert_true(state_script.validate_state(state).get("ok", false))

func test_solo_offer_returns_linked_candidate_batch_and_parent_receipt() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	assert_not_null(state_script, "ContactInvitationState must exist")
	if state_script == null:
		return
	var result: Dictionary = state_script.prepare_offer_solo(
		state_script.make_defaults(),
		"priscilla",
		1,
		"msg.solo.priscilla.day1",
		"tx.solo.p.d1"
	)
	assert_eq(_sorted_keys(result), ["code", "ok", "receipt", "value"])
	assert_true(result["ok"])
	assert_eq(_sorted_keys(result["value"]), ["candidate", "message_batch"])
	assert_eq(result["value"]["message_batch"].size(), 1)
	assert_eq(result["receipt"]["transaction_id"], "tx.solo.p.d1")
	assert_eq(result["receipt"]["action_id"], "solo:priscilla:day1")
	assert_eq(result["receipt"]["child_transaction_ids"], [
		"tx.solo.p.d1:message:0"
	])
	var candidate: Dictionary = result["value"]["candidate"]
	assert_eq(candidate["solo_actions"]["solo:priscilla:day1"]
		["offer_message_id"], "msg.solo.priscilla.day1")
	assert_eq(candidate["messages"]["priscilla"][0]
		["transaction_id"], "tx.solo.p.d1:message:0")
	assert_eq(candidate["transaction_receipts"]["tx.solo.p.d1"],
		result["receipt"])

func test_opening_solo_offer_marks_read_without_answering() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	assert_not_null(state_script, "ContactInvitationState must exist")
	if state_script == null:
		return
	var state: Dictionary = state_script.make_defaults()
	var offered: Dictionary = state_script.prepare_offer_solo(
		state, "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1"
	)
	assert_true(offered.get("ok", false))
	state = offered["value"]["candidate"]
	assert_eq(state_script.get_unread_count(state, "priscilla", 1), 1)
	var opened: Dictionary = state_script.prepare_open_contact(
		state, "priscilla", 1, "tx.open.p.d1"
	)
	assert_true(opened.get("ok", false))
	state = opened["value"]["candidate"]
	assert_eq(state_script.get_unread_count(state, "priscilla", 1), 0)
	assert_true(state_script.is_reply_required(state, "priscilla"))
	assert_false(state_script.is_date_addable(state, "solo:priscilla:day1"))
~~~

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'contact_solo_red' -LogName 'phase2r-red-contact-solo.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_contact_invitation_state.gd','-gexit')
~~~

Expected RED: ContactInvitationState must exist.

- [ ] **Step 1.2: Implement the canonical state shape**

- [ ] ContactInvitationState is stateless and exposes the shared master methods plus:

~~~gdscript
static func make_defaults() -> Dictionary
static func prepare_append_messages(
	state: Dictionary,
	message_batch: Array[Dictionary],
	transaction_id: String
) -> Dictionary
~~~

- [ ] `make_defaults()` returns this exact valid serialized state; it contains no fabricated offer or receipt:

~~~json
{
  "messages": {
    "priscilla": [],
    "lavinia": [],
    "sylvia": []
  },
  "read_watermarks": {
    "priscilla": 0,
    "lavinia": 0,
    "sylvia": 0
  },
  "solo_actions": {},
  "group_action": {
    "state": "INACTIVE",
    "action_id": null,
    "day": null,
    "participant_ids": ["priscilla", "lavinia"],
    "inviter_id": null,
    "opened_ids": [],
    "replied_ids": [],
    "history_generated": false,
    "transaction_id": null
  },
  "transaction_receipts": {},
  "next_sequence": 1
}
~~~

After the first solo offer, the exact linked fragment is:

~~~json
{
  "messages": {
    "priscilla": [{
      "message_id": "msg.solo.priscilla.day1",
      "sequence": 1,
      "type": "solo_offer",
      "variant": "default",
      "target_day": 1,
      "parameters": {},
      "visibility": "visible",
      "transaction_id": "tx.solo.p.d1:message:0"
    }],
    "lavinia": [],
    "sylvia": []
  },
  "solo_actions": {
    "solo:priscilla:day1": {
      "action_id": "solo:priscilla:day1",
      "friend_id": "priscilla",
      "day": 1,
      "state": "AVAILABLE",
      "offer_message_id": "msg.solo.priscilla.day1",
      "reply_transaction_id": null,
      "transaction_id": "tx.solo.p.d1"
    }
  },
  "transaction_receipts": {
    "tx.solo.p.d1": {
      "transaction_id": "tx.solo.p.d1",
      "kind": "offer_solo",
      "action_id": "solo:priscilla:day1",
      "child_transaction_ids": ["tx.solo.p.d1:message:0"],
      "message_ids": ["msg.solo.priscilla.day1"],
      "message_sequences": [1]
    }
  },
  "next_sequence": 2
}
~~~

The omitted `read_watermarks` and `group_action` remain exactly equal to defaults. Each message sequence is globally monotonic and immutable; `next_sequence` is the next allocatable value and therefore exceeds every stored sequence. `visibility` is `visible` or `superseded_hidden`. A message contributes to history/unread only when visible and `target_day <= queried day`. Every invitation message has a deterministic child transaction ID present in its parent receipt; every offer action points to exactly one message whose parent transaction equals the action transaction. `validate_state()` rejects an orphan offer, orphan receipt, duplicate message ID/sequence/child transaction, a mismatched action/receipt/message link, unknown key, or aliased nested container. Group activation retains both solo records but marks their offer messages `superseded_hidden`, so they disappear from contact view and unread badges without deletion. Opening advances only that contact's watermark through its greatest visible sequence.

- [ ] A solo action is exactly:

~~~json
{
  "action_id": "solo:priscilla:day1",
  "friend_id": "priscilla",
  "day": 1,
  "state": "AVAILABLE",
  "offer_message_id": "msg.solo.priscilla.day1",
  "reply_transaction_id": null,
  "transaction_id": "tx.solo.p.d1"
}
~~~

Allowed states are AVAILABLE, ACCEPTED, RESOLVED_UNANSWERED, RESOLVED_ATTENDED, RESOLVED_MISSED, SUPERSEDED, and RESOLVED_RUN_END. reply_required is derived and true only for AVAILABLE. The first reply changes AVAILABLE -> ACCEPTED and enables its action ID for Schedule; duplicate replies return the original receipt.

`prepare_append_messages()` allocates deterministic child transaction IDs `<parent>:message:<index>`, validates the whole batch against a detached state, and commits none when any member fails. A parent receipt stores `transaction_id`, `kind`, `action_id`, ordered `child_transaction_ids`, ordered `message_ids`, and ordered `message_sequences`; replay returns the stored receipt and a detached unchanged candidate with an empty `message_batch`. Reusing the parent ID with different normalized input returns `duplicate_transaction_conflict`.

- [ ] Implement the constructors/result helpers exactly; all returned containers are recursively duplicated:

~~~gdscript
static func make_defaults() -> Dictionary:
	return {
		"messages": {"priscilla": [], "lavinia": [], "sylvia": []},
		"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
		"solo_actions": {},
		"group_action": {
			"state": "INACTIVE",
			"action_id": null,
			"day": null,
			"participant_ids": ["priscilla", "lavinia"],
			"inviter_id": null,
			"opened_ids": [],
			"replied_ids": [],
			"history_generated": false,
			"transaction_id": null,
		},
		"transaction_receipts": {},
		"next_sequence": 1,
	}

static func _success(candidate: Dictionary, message_batch: Array[Dictionary],
		receipt: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"code": &"ok",
		"value": {
			"candidate": candidate.duplicate(true),
			"message_batch": message_batch.duplicate(true),
		},
		"receipt": receipt.duplicate(true),
	}

static func _failure(code: StringName, message: String,
		details: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message,
		"details": details.duplicate(true),
	}
~~~

- [ ] Implement `prepare_offer_solo()` with this complete ordering: validate and detach state; validate `friend_id`, `day in 1..7`, nonempty IDs, and absence of another action with the same derived action ID; normalize the one-message batch; detect same-ID replay/conflict from the parent receipt; allocate its child ID and sequence; insert the action and parent receipt into the detached candidate; validate the final candidate; return `_success(candidate, appended_records, receipt)`. No live input is mutated on any branch.

- [ ] **Step 1.3: Implement every solo day-end branch**

- [ ] Add this RED test before implementing day-end resolution:

~~~gdscript
func test_unanswered_solo_appends_one_linked_nevermind_next_day() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	var state: Dictionary = state_script.prepare_offer_solo(
		state_script.make_defaults(), "priscilla", 1,
		"msg.solo.priscilla.day1", "tx.solo.p.d1"
	)["value"]["candidate"]
	var resolved: Dictionary = state_script.prepare_resolve_day_end(
		state,
		1,
		{"solo_attended_action_ids": [], "group_outcome": "not_scheduled",
			"scheduled_group_action_id": null, "group_route_receipt_id": null},
		"tx.day1.invitation_resolution"
	)
	assert_true(resolved.get("ok", false))
	assert_eq(_sorted_keys(resolved), ["code", "ok", "receipt", "value"])
	assert_eq(resolved["value"]["message_batch"].size(), 1)
	assert_eq(resolved["value"]["message_batch"][0]["type"], "nevermind")
	assert_eq(resolved["value"]["message_batch"][0]["target_day"], 2)
	assert_eq(resolved["value"]["candidate"]["solo_actions"]
		["solo:priscilla:day1"]["state"], "RESOLVED_UNANSWERED")
	assert_eq(resolved["value"]["candidate"]["transaction_receipts"]
		["tx.day1.invitation_resolution"], resolved["receipt"])
~~~

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'contact_solo_day_end_red' -LogName 'phase2r-red-contact-solo-day-end.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_contact_invitation_state.gd','-gexit')
~~~

Expected RED: `prepare_resolve_day_end()` is missing or does not append the linked nevermind record.

- [ ] On Days 1–6:

| Condition | State | Appended next-day message |
|---|---|---|
| unopened and unanswered | RESOLVED_UNANSWERED | nevermind to that friend |
| opened and unanswered | RESOLVED_UNANSWERED | the same nevermind |
| replied and attended | RESOLVED_ATTENDED | none |
| replied and not attended | RESOLVED_MISSED | missed_question to that friend |
| replied and prevented by fainting | RESOLVED_MISSED | missed_question to that friend |

nevermind uses one reusable type. Solo never produces busy, judge, or twofriends. New messages use target_day = source_day + 1 and begin unread.

- [ ] Day 7 sends no message and changes every unresolved solo action to RESOLVED_RUN_END.

- [ ] Implement opening, replying, and solo resolution with this exact state-transition algorithm:

~~~text
prepare_open_contact(state, friend_id, day, tx)
  validate/detach the state and validate friend/day/transaction
  if tx receipt exists with identical kind+friend+day: return unchanged candidate/empty batch/stored receipt
  reject a conflicting reuse
  set only read_watermarks[friend_id] to max visible sequence with target_day <= day
  store receipt {transaction_id, kind="open_contact", friend_id, day, prior_watermark, new_watermark,
                 child_transaction_ids=[], message_ids=[], message_sequences=[]}
  validate candidate and return frozen success

prepare_reply(state, friend_id, day, tx) for a solo action
  select the unique AVAILABLE solo action for friend_id and day
  reject none/multiple or a nonreplyable state
  set state=ACCEPTED and reply_transaction_id=tx
  store receipt {transaction_id, kind="reply_solo", action_id, friend_id, day,
                 from_state="AVAILABLE", to_state="ACCEPTED",
                 child_transaction_ids=[], message_ids=[], message_sequences=[]}
  validate candidate and return frozen success

prepare_resolve_day_end(state, day, attendance, tx), solo portion
  process actions whose action.day == day in sorted action_id order
  AVAILABLE -> RESOLVED_UNANSWERED and queue nevermind(target_day=day+1) on days 1..6
  ACCEPTED + action_id in solo_attended_action_ids -> RESOLVED_ATTENDED, no message
  ACCEPTED + action_id absent -> RESOLVED_MISSED and queue missed_question(target_day=day+1)
  on day 7, AVAILABLE or ACCEPTED -> RESOLVED_RUN_END and queue nothing
  allocate every queued record through the one tx parent in deterministic action_id order
  store one receipt with kind="resolve_day_end", day, ordered state_transitions,
    child_transaction_ids, message_ids, message_sequences, date_outcome_ids, and counter_deltas
  validate once; return candidate + the ordered newly appended records + the parent receipt
~~~

- [ ] Tests prove all rows, opening/non-opening equivalence, idempotent resolution, immutable history, independent watermarks, target-day invisibility, and mutation-free queries.

- [ ] Run the focused suite and require all assertions GREEN:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'contact_solo_green' -LogName 'phase2r-contact-solo-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_contact_invitation_state.gd','-gexit')
~~~

- [ ] **Step 1.4: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 1 Step 1.4 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$') {
	throw 'Task 1 Step 1.4 could not bind the prerequisite HEAD.'
}
$required = [ordered]@{
	'scripts/domain/contact/ContactInvitationState.gd' = 'A'
	'tests/unit/test_contact_invitation_state.gd' = 'A'
	'tests/fixtures/invitations/solo_cases.json' = 'A'
}
$optionalUids = [ordered]@{
	'scripts/domain/contact/ContactInvitationState.gd.uid' = 'A'
	'tests/unit/test_contact_invitation_state.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'feat(contacts): separate solo invitation actions from message history'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 1 commit boundary failed.' }
~~~

## Task 2: Implement exact group activation, opening, and reply semantics

**Beads:** dwm-p2r.6

**Files:**

- Extend: scripts/domain/contact/ContactInvitationState.gd
- Extend: tests/unit/test_contact_invitation_state.gd
- Create: tests/fixtures/invitations/group_activation_cases.json

**Interfaces:**

- Consumes: Task 1 canonical state and message-batch receipt.
- Produces: `prepare_activate_group_after_round()` and group branches of `prepare_open_contact/prepare_reply`; group state is exactly `INACTIVE|AVAILABLE_UNOPENED|REPLY_REQUIRED|ACCEPTED|RESOLVED_UNANSWERED|RESOLVED_ATTENDED|RESOLVED_MISSED|RESOLVED_RUN_END` and always contains `action_id:String|null` plus `day:int|null`. Non-INACTIVE state requires `action_id="group:priscilla_lavinia:day<day>"` and `day in [2,6]`; INACTIVE requires both null.

- [ ] **Step 2.1: Write the either-participant RED test**

- [ ] Add:

~~~gdscript
func test_either_group_participant_can_reply_first() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	var state: Dictionary = state_script.make_defaults()
	state = state_script.prepare_offer_solo(
		state, "priscilla", 2, "offer-p", "solo-p"
	)["value"]["candidate"]
	state = state_script.prepare_offer_solo(
		state, "lavinia", 2, "offer-l", "solo-l"
	)["value"]["candidate"]

	var activated: Dictionary = state_script.prepare_activate_group_after_round(
		state, 2, 2, 3, "group-day2"
	)
	assert_true(activated.get("ok", false))
	state = activated["value"]["candidate"]
	assert_eq(state["group_action"]["action_id"],
		"group:priscilla_lavinia:day2")
	assert_eq(state["group_action"]["day"], 2)
	assert_null(state["group_action"]["inviter_id"])
	assert_eq(state_script.get_contact_view(
		state, "priscilla", 2
	)["messages"].size(), 0)

	var opened: Dictionary = state_script.prepare_open_contact(
		state, "priscilla", 2, "open-group-priscilla"
	)
	state = opened["value"]["candidate"]
	assert_eq(state["group_action"]["inviter_id"], "priscilla")
	assert_eq(state_script.get_unread_count(state, "priscilla", 2), 0)
	assert_eq(state_script.get_unread_count(state, "lavinia", 2), 1)

	var replied: Dictionary = state_script.prepare_reply(
		state, "lavinia", 2, "reply-lavinia"
	)
	assert_true(replied.get("ok", false))
	state = replied["value"]["candidate"]
	assert_true(state_script.is_date_addable(state,
		"group:priscilla_lavinia:day2"
	))
~~~

Current behavior should fail because it requires replying to the inviter first.

- [ ] Run the RED test before changing group behavior:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'contact_group_red' -LogName 'phase2r-red-contact-group.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_contact_invitation_state.gd','-gexit')
~~~

Expected RED: either the group action lacks `action_id/day`, activation generates the wrong visible history, or Lavinia cannot reply first.

- [ ] **Step 2.2: Enforce the complete activation predicate atomically**

- [ ] activate_group_after_round() succeeds only when all are true:

~~~text
day is 2 or 6
rounds_before == 2
rounds_after == 3
Priscilla solo state is AVAILABLE
Lavinia solo state is AVAILABLE
each solo has zero replies
each solo offer_message_id belongs to its action transaction
each offer sequence is greater than that contact read watermark
~~~

A failed predicate changes nothing. Success atomically marks both solos SUPERSEDED, marks their offer messages `superseded_hidden`, and creates group state AVAILABLE_UNOPENED with `action_id=group:priscilla_lavinia:day<day>`, the supplied day, fixed participants, null inviter_id, empty opened/replied arrays, history_generated=false, and the supplied stable transaction ID. It generates no group-offer text. While AVAILABLE_UNOPENED, each participant has one derived unread group opportunity; this replaces, rather than adds to, the hidden solo unread.

- [ ] Implement activation as one pure candidate operation:

~~~text
prepare_activate_group_after_round(state, day, rounds_before, rounds_after, tx)
  validate/detach state; validate tx and day
  on identical stored tx receipt: return unchanged detached candidate/empty batch/stored receipt
  reject conflicting tx reuse
  require day in {2,6}, rounds_before=2, rounds_after=3, group.state=INACTIVE
  derive action_id="group:priscilla_lavinia:day" + str(day)
  for participant in [priscilla, lavinia]:
    require the unique solo:<participant>:day<day> action is AVAILABLE with no reply tx
    resolve its offer record by offer_message_id
    require record.sequence > participant watermark and parent receipt links record to action transaction
  set both solo states SUPERSEDED and their exact offer records visibility=superseded_hidden
  replace group_action with AVAILABLE_UNOPENED plus action_id/day and canonical empty fields
  store receipt {transaction_id, kind="activate_group", action_id, day,
                 superseded_action_ids=[priscilla action, lavinia action],
                 child_transaction_ids=[], message_ids=[], message_sequences=[]}
  validate once; return success with empty message_batch
~~~

- [ ] **Step 2.3: Generate history only on first participant open**

- [ ] First open:

1. Assigns that participant as presentation-only inviter_id.
2. Appends paired group-offer messages through one parent batch transaction.
3. Uses first_open for that contact and second_open for the other.
4. Adds the participant to opened_ids.
5. Changes AVAILABLE_UNOPENED -> REPLY_REQUIRED.
6. Advances only the opened participant's read watermark.

- [ ] Second open reuses the group transaction, keeps inviter_id, appends nothing, adds that participant to opened_ids, and advances only that participant's watermark.

- [ ] The first unique reply to either participant adds that ID, changes REPLY_REQUIRED -> ACCEPTED, and makes the group date addable. A second unique reply adds its ID while state remains ACCEPTED. Repeats are idempotent.

- [ ] Per-participant reply is enabled only when state is REPLY_REQUIRED or ACCEPTED and that participant is absent from replied_ids. Group reply_required remains true while at least one participant is replyable.

- [ ] inviter_id affects only first/second message presentation and the image-position field in the later dating route. It never controls who may reply or whether Schedule can add the date.

- [ ] Implement group open/reply with these exact operations:

~~~text
first prepare_open_contact participant while AVAILABLE_UNOPENED
  set inviter_id=participant, opened_ids=[participant], history_generated=true,
      state=REPLY_REQUIRED; retain action_id/day/activation transaction_id
  append exactly two visible group_offer records through the open command parent tx:
    inviter record variant=first_open; other record variant=second_open;
    both target_day=group.day and parameters={action_id, inviter_id}
  advance only inviter watermark through that participant's new record
  receipt kind=open_group_first contains action_id/day/friend_id and both child/message IDs

second prepare_open_contact participant while REPLY_REQUIRED or ACCEPTED
  add participant once to opened_ids, append no records, retain inviter_id
  advance only that participant watermark through the already generated second_open record
  receipt kind=open_group_second has empty child/message arrays

prepare_reply participant while REPLY_REQUIRED or ACCEPTED
  require participant belongs to group and is absent from replied_ids
  append participant to replied_ids in canonical participant order
  set state=ACCEPTED; append no message
  receipt kind=reply_group contains action_id/day/friend_id/from_state/to_state
  replay of the same tx returns its stored receipt; a second tx for an already replied
  participant returns invalid_transition rather than fabricating another receipt
~~~

- [ ] **Step 2.4: Run focused activation tests**

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'contact_group_activation' -LogName 'phase2r-contact-group-activation.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_contact_invitation_state.gd','-gexit')
~~~

Expected GREEN: every activation predicate edge, first/second open ordering, either-first reply, second reply, and duplicate command passes.

- [ ] **Step 2.5: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 2 Step 2.5 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'feat(contacts): separate solo invitation actions from message history')) {
	throw 'Task 2 requires the exact Task 1 commit boundary as HEAD.'
}
$required = [ordered]@{
	'scripts/domain/contact/ContactInvitationState.gd' = 'M'
	'tests/unit/test_contact_invitation_state.gd' = 'M'
	'tests/fixtures/invitations/group_activation_cases.json' = 'A'
}
$optionalUids = [ordered]@{}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'feat(invitations): activate and open group offers atomically'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 2 commit boundary failed.' }
~~~

## Task 3: Implement every group-resolution branch and facade integration

**Beads:** dwm-p2r.6

**Files:**

- Extend: scripts/domain/contact/ContactInvitationState.gd
- Create: tests/scenario/test_invitation_branches.gd
- Create: tests/fixtures/invitations/group_resolution_cases.json
- Modify: autoload/GameState.gd
- Modify: scripts/ui/ContactListApp.gd
- Modify: tests/unit/test_game_state.gd
- Modify: scripts/domain/run/RunSnapshotSchema.gd
- Modify: scripts/infrastructure/save/SaveMigrations.gd
- Modify: tests/unit/test_run_snapshot_schema.gd
- Modify: tests/unit/test_save_migrations.gd
- Modify: tests/integration/test_restore_transaction.gd
- Extend: tests/integration/test_restore_mutation_gate.gd
- Consume without modification: scripts/application/transaction/FatalDiagnosticProjector.gd
- Re-run without modification: tests/unit/test_fatal_diagnostic_projector.gd

**Interfaces:**

- Consumes: pure candidate-returning contact functions, GameState detached-run transaction seam, SaveManager checkpoint port, and Plan-03 Task-3's one shared `FatalDiagnosticProjector` plus its already-passing unit contract.
- Produces: `GameState.open_contact(friend_id:String, command_id:String) -> Dictionary`, `GameState.reply_invitation(friend_id:String, command_id:String) -> Dictionary`, and `GameState.resolve_invitations_for_day(attendance:Dictionary, command_id:String) -> Dictionary`. Each facade command prepares the run/contact candidate, counter deltas encoded in the contact parent receipt, receipt ledger, and required checkpoint before committing either port; it then commits checkpoint followed by run and publishes signals only after both. A later failure invokes the exact reverse rollback. If any required recovery step cannot prove the pre-command run/checkpoint pair, GameState calls the one injected `ApplicationMutationGate.latch_fatal()` and returns that gate's `APPLICATION_FATAL`; it never acquires or retains a contact-specific gate owner. Query calls remain pure.

- [ ] **Step 3.1: Define exact attendance input and result events**

- [ ] Add this RED branch test before implementing group day-end resolution:

~~~gdscript
extends "res://addons/gut/test.gd"

const CONTACT_STATE := preload(
	"res://scripts/domain/contact/ContactInvitationState.gd"
)

func _available_unopened_day2() -> Dictionary:
	var state: Dictionary = CONTACT_STATE.make_defaults()
	state = CONTACT_STATE.prepare_offer_solo(
		state, "priscilla", 2, "offer-p", "solo-p"
	)["value"]["candidate"]
	state = CONTACT_STATE.prepare_offer_solo(
		state, "lavinia", 2, "offer-l", "solo-l"
	)["value"]["candidate"]
	return CONTACT_STATE.prepare_activate_group_after_round(
		state, 2, 2, 3, "group-day2"
	)["value"]["candidate"]

func test_untouched_group_returns_candidate_receipt_and_two_busy_records() -> void:
	var result: Dictionary = CONTACT_STATE.prepare_resolve_day_end(
		_available_unopened_day2(),
		2,
		{
			"solo_attended_action_ids": [],
			"scheduled_group_action_id": null,
			"group_route_receipt_id": null,
			"group_outcome": "not_scheduled",
		},
		"tx.resolve.day2"
	)
	assert_true(result.get("ok", false))
	assert_eq(result.keys().size(), 4)
	assert_true(result.has("value"))
	assert_true(result.has("receipt"))
	assert_eq(result["value"]["candidate"]["group_action"]["state"],
		"RESOLVED_UNANSWERED")
	assert_eq(result["value"]["message_batch"].size(), 2)
	assert_eq(result["value"]["message_batch"][0]["type"], "busy")
	assert_eq(result["value"]["message_batch"][1]["type"], "busy")
	assert_eq(result["receipt"]["date_outcome_ids"], [])
	assert_eq(result["receipt"]["counter_deltas"], {})
~~~

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'invitation_group_resolution_red' -LogName 'phase2r-red-invitation-group-resolution.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scenario/test_invitation_branches.gd','-gexit')
~~~

Expected RED: `prepare_resolve_day_end()` lacks the exact group candidate/receipt/message batch.

- [ ] `prepare_resolve_day_end()` receives exactly:

~~~json
{
  "solo_attended_action_ids": [],
  "scheduled_group_action_id": "group:priscilla_lavinia:day2",
  "group_route_receipt_id": "route.group.day2:completed",
  "group_outcome": "not_attended"
}
~~~

The attendance Dictionary has exactly those four keys. `solo_attended_action_ids` is a sorted unique array. `group_outcome` is exactly `not_scheduled`, `attended`, `not_attended`, or `prevented_by_fainting`; it is the sole fainting source. Exact mappings are:

| `group_outcome` | `scheduled_group_action_id` | `group_route_receipt_id` | Meaning |
|---|---|---|---|
| `not_scheduled` | null | null | No group entry was committed. For ACCEPTED this is the missed-date branch; for zero replies it is the busy/nevermind branch; for INACTIVE it is a no-op. |
| `attended` | exact current group `action_id` | nonempty completed route receipt | The accepted group entry completed normally. |
| `not_attended` | exact current group `action_id` | nonempty cancelled/not-attended route receipt | The accepted group entry existed but completed without attendance for a non-fainting reason. |
| `prevented_by_fainting` | exact current group `action_id` | nonempty fainting route receipt | The accepted group entry was prevented by the one canonical fainting event. |

`attended`, `not_attended`, and `prevented_by_fainting` reject unless group state is ACCEPTED and the receipt belongs to the active DayResolutionPlan entry for the same action/day. `not_scheduled` rejects a non-null schedule or route receipt. A zero-reply action rejects every outcome except `not_scheduled`. GameState constructs this trusted Dictionary from persisted schedule/route receipts; UI callers never supply it.

Every successful prepare still uses the frozen `CommandResult`. Semantic events live in the parent receipt, never in a second top-level result shape:

~~~gdscript
{
  "ok": true,
  "code": &"ok",
  "value": {
    "candidate": Dictionary,
    "message_batch": Array[Dictionary]
  },
  "receipt": {
    "transaction_id": "tx.resolve.day2",
    "kind": "resolve_day_end",
    "day": 2,
    "state_transitions": [],
    "date_outcome_ids": [],
    "deferred_twofriends": null,
    "counter_deltas": {},
    "group_date_variation": null,
    "child_transaction_ids": [],
    "message_ids": [],
    "message_sequences": []
  }
}
~~~

`candidate` is the complete validated detached contact state defined in Task 1. `counter_deltas` is either `{}` or exactly `{"missed_group_date_counts.priscilla_lavinia":1}`. The contact module returns events only through the receipt; the GameState facade applies counter deltas and append receipts in the same candidate. It does not route scenes.

- [ ] **Step 3.2: Implement the mutually exclusive group table**

- [ ] On Days 1–6:

| Condition | Final state | Required consequence |
|---|---|---|
| neither opened, zero replies | RESOLVED_UNANSWERED | no group-offer history; busy unread to both next day |
| at least one opened, zero replies | RESOLVED_UNANSWERED | retain offer history; nevermind to both next day |
| one reply, attended | RESOLVED_ATTENDED | judgmental date variation; judge from unreplied participant next day |
| both replied, attended | RESOLVED_ATTENDED | normal date variation; no next-day message |
| one/two replies, `not_scheduled` | RESOLVED_MISSED | increment missed-group count; defer twofriends; missed_question to both next day |
| one/two replies, scheduled `not_attended` | RESOLVED_MISSED | increment missed-group count; defer twofriends; missed_question to both next day |
| one/two replies, fainted | RESOLVED_MISSED | same missed branch; Hospital must play before deferred twofriends |

busy is only the wholly untouched group opportunity. nevermind is only opened/visible and unanswered. judge is only one-reply attendance. missed_question is only accepted non-attendance. Branches cannot combine.

- [ ] Implement group resolution from the validated attendance mapping with this complete decision order:

~~~text
if day == 7:
  every AVAILABLE_UNOPENED/REPLY_REQUIRED/ACCEPTED group -> RESOLVED_RUN_END
  no messages, counter delta, date outcome, variation, or twofriends
else if group.state == AVAILABLE_UNOPENED and replied_ids is empty:
  require group_outcome=not_scheduled
  -> RESOLVED_UNANSWERED; append busy to priscilla then lavinia for day+1
else if group.state == REPLY_REQUIRED and replied_ids is empty:
  require group_outcome=not_scheduled
  -> RESOLVED_UNANSWERED; append nevermind to priscilla then lavinia for day+1
else if group.state == ACCEPTED and group_outcome == attended:
  -> RESOLVED_ATTENDED
  if replied_ids.size()==1: group_date_variation=judgmental and append judge only
    to the canonical unreplied participant for day+1
  if replied_ids.size()==2: group_date_variation=normal and append nothing
else if group.state == ACCEPTED and group_outcome in
    [not_scheduled, not_attended, prevented_by_fainting]:
  -> RESOLVED_MISSED
  date_outcome_ids=["date.group.priscilla_lavinia.missed.day" + str(day)]
  deferred_twofriends={"route_id":"twofriends","action_id":group.action_id,
                       "after_hospital":group_outcome==prevented_by_fainting}
  counter_deltas={"missed_group_date_counts.priscilla_lavinia":1}
  append missed_question to priscilla then lavinia for day+1
else:
  resolved/INACTIVE states are unchanged only when attendance is not_scheduled;
  every other combination returns invalid_attendance

All message records are allocated through the resolution parent transaction in the
listed participant order. Store ordered state_transitions and every semantic event
in that parent receipt, validate the whole candidate once, then return the frozen
CommandResult. No branch can append more than one message type.
~~~

- [ ] Day 7 changes any unresolved group action to RESOLVED_RUN_END and generates no busy, nevermind, judge, missed_question, twofriends, missed count, rollover, or other next-day event. Existing history remains.

- [ ] **Step 3.3: Integrate through GameState without legacy parallel state**

- [ ] GameState owns one canonical primitive `contacts` Dictionary. It calls the stateless ContactInvitationState functions and never stores a second module-owned copy.
- [ ] Replace daily_opened_contacts, daily_group_invitation_generated, daily_group_invitation_pair, contact-choice reply conflation, and deletion/supersession behavior after every caller migrates.
- [ ] ContactListApp renders get_contact_view(); opening a contact calls open_contact() exactly once. It does not mutate reply state from ready/render callbacks.
- [ ] Group activation is invoked only from complete_minesweeper_round() with the atomic rounds-before/after receipt. Contact opening never activates a group offer.
- [ ] `complete_minesweeper_round()` prepares the gameplay/contact candidate and post-result checkpoint together. Injected failure after candidate validation, contact activation, counter update, or checkpoint preparation leaves live run, contacts, receipts, journal, signals, and active board unchanged.

- [ ] Extend aggregate persistence in the same task: `RunSnapshotSchema` validates `contacts` exclusively through `ContactInvitationState.validate_state()` and rejects unknown/malformed nested contact fields before a restore participant applies. Because schema v2 has not shipped before the Phase 2R gate, keep `schema_version=2` and replace its provisional `{}` contact default with `ContactInvitationState.make_defaults()` in the legacy/v1 migration. A table-driven round trip covers every solo/group state, visible and `superseded_hidden` history, watermarks, inviter/opened/replied IDs, transaction receipts, and next sequence. Mutation after snapshot capture cannot alias live contact state. Re-run schema, migration, journal, and production restore-adapter tests here; no later task may rely on generic primitive-only contact validation.

- [ ] Implement each GameState facade transaction with the already-defined checkpoint-port contract from plan 03:

~~~text
guard external mutation and capture run_backup + checkpoint_backup
call the pure contact prepare function
if failure: return it unchanged
duplicate capture_run_snapshot_input(); replace contacts with contact_result.value.candidate
apply only receipt.counter_deltas to the detached run counters
insert the same parent receipt into the run-level command receipt ledger
validate prepare_run_candidate(snapshot_input)
checkpoint_port.prepare(exact checkpoint inputs, checkpoint_kind,
  {"kind":&"none","reason":&"stage"})
if any preparation fails: return failure with live backups unchanged
checkpoint_port.commit(prepared checkpoint candidate)
if checkpoint commit fails:
  call checkpoint_port.rollback(checkpoint_backup) even when commit reports failure after mutation
  record that rollback result as the sole raw rollback diagnostic
  if rollback failed: call _latch_facade_recovery_fatal(original_phase, command_id,
    rollback diagnostics) and return APPLICATION_FATAL
  otherwise return the original checkpoint-commit failure plus the successful rollback diagnostic
commit_run_candidate(prepared run candidate)
if run commit fails:
  call restore_live_run_state(run_backup), then checkpoint_port.rollback(checkpoint_backup)
    in that exact reverse-commit order, attempting checkpoint rollback even if run restore fails
  record both raw results in that same order
  if either recovery failed: call _latch_facade_recovery_fatal(original_phase, command_id,
    rollback diagnostics) and return APPLICATION_FATAL
  otherwise return the original run-commit failure plus both successful rollback diagnostics
emit contact/counter signals and return the facade result with committed checkpoint_id
on identical command_id: return the stored facade receipt/checkpoint_id without another commit
~~~

`_latch_facade_recovery_fatal(original_phase: StringName, command_id: String, raw_rollback_diagnostics: Array[Dictionary]) -> Dictionary` remains only a private GameState call-order helper, not a projector, lock, or fatal Boolean. `original_phase` is exactly `&"checkpoint_commit"` or `&"run_commit"`; `command_id` is a nonempty String. `raw_rollback_diagnostics` contains one entry for every attempted recovery in call order; each raw entry has exactly `owner_id`, `operation`, and `result`, where `owner_id` is `save_checkpoint` or `game_state`, `operation` is `rollback` or `restore_live_run_state`, and `result` is the returned CommandResult. Raw results never enter `FatalFailure` directly.

After every required recovery attempt completes, the helper calls the Plan-03-owned shared boundary exactly once:

~~~gdscript
var projected: Dictionary = FatalDiagnosticProjector.project_failure(
	"game_state_facade",
	original_phase,
	"fatal_rollback_failed",
	{"command_id": command_id},
	raw_rollback_diagnostics
)
~~~

It requires the frozen success `value={"failure":FatalFailure}`, then calls `FatalDiagnosticProjector.validate_failure(failure)`. The shared projector alone performs recursive detachment, StringName normalization, invalid-subtree/diagnostic sentinel replacement, and invariant fallback construction; Plan 04 MUST NOT implement a private projection method, recursive walker, sentinel schema, or projector test owner. If projection or validation returns an invariant failure, the helper uses only `FatalDiagnosticProjector.get_invariant_fallback()` and validates that constant failure before latching. No rejected raw byte or alias is copied.

Only after projection/validation does the helper call `guard_external(&"game_state_facade")` once as the post-recovery fatal probe. A successful probe selects the projected/fallback failure. Exact `APPLICATION_FATAL details={"failure":FatalFailure}` means a dependency—specifically failed Plan-03 `SaveManagerCheckpointPort.rollback()`—already latched the same gate; the helper reuses that exact detached retained failure instead of constructing a competing one. Any other probe result is an implementation invariant failure and selects the shared constant fallback. The helper calls the injected gate's `latch_fatal(selected_failure)` exactly once, then calls `guard_external(&"game_state_facade")` exactly once and returns that final exact retained `APPLICATION_FATAL`. A first latch disables InputManager once; an identical repeat emits nothing; a different concurrent latch may make the intermediate latch return `APPLICATION_FATAL_CONFLICT`, but the final guard preserves the first failure. The helper never calls `acquire()`, creates no contact owner/local fatal state, emits no contact/counter signal, and leaves the local facade transaction fence plus InputManager blocked.

The required run-command anchors are:

| Command | Anchor |
|---|---|
| contact open/read-watermark change | `choice` |
| solo/group reply | `choice` |
| group activation from round completion | `post_result` |
| invitation day-end resolution | `day_resolution_stage` |
| schedule add/remove | `choice` |
| date outcome receipt | `day_resolution_stage` |
| direct registered scene transition | `scene_transition` |

No mutating command reports success until its candidate and anchor are committed as one in-memory transaction.

- [ ] Add a table-driven checkpoint-port spy for every facade row above. It requires the third argument's keys to be exactly sorted `kind,reason`, its values to be exactly `&"none",&"stage"`, and its recursive primitive copy to remain byte-equal after the caller mutates its source. Missing/extra keys, String/StringName value drift, or the retired `mode` key fails before either port commits.
- [ ] Add named failpoint cases `test_facade_checkpoint_rollback_failure_latches_shared_fatal_gate`, `test_facade_run_restore_failure_still_attempts_checkpoint_rollback_then_latches`, `test_facade_fatal_projection_normalizes_and_rejects_nonprimitive_details`, and `test_facade_fatal_latch_rejects_next_command_before_validation_and_keeps_input_blocked`. Cover checkpoint commit failure-after-mutation plus failed checkpoint rollback; run commit failure-after-mutation plus failed run restore; failed checkpoint rollback after successful run restore; and both reverse recoveries failing. Assert exact order: complete every recovery attempt → one shared-projector call → shared validation/fallback → post-recovery guard probe → facade-helper latch → final guard. Re-run Plan 03's unchanged projector unit suite, then have the facade projection case supply StringName codes/messages/nested keys, non-finite float, Object, Callable, packed bytes, non-string key, and normalized-key collision and require the shared projector's exact primitive sentinel/no-alias result. Pass the selected projected or fallback `FatalFailure` directly to the real Plan-03 gate and require first/idempotent acceptance—never `INVALID_FATAL_FAILURE`. Assert the exact normalized `game_state_facade/checkpoint_commit|run_commit/fatal_rollback_failed` failure when GameState is the first latch source, and the exact retained Plan-03 `save_checkpoint` failure when the checkpoint port latches first. Assert one first-latch capability emission, one facade-helper latch invocation (idempotent when the port already latched), zero domain signals, no private projection helper/recursive walker/sentinel copy, and no second mutation gate/fatal Boolean. After each latch, issue invalid and otherwise-valid facade commands and assert both return the retained `APPLICATION_FATAL` before contact validation, receipt lookup, snapshot capture, or checkpoint calls. Inject stale enabled/release capability events and assert InputManager remains blocked with no scene callback.

- [ ] **Step 3.4: Run the full branch matrix twice**

- [ ] For every table row, scenario tests run once normally and once by serializing/restoring immediately before day-end completion. Both runs must have identical history, counters, states, route event, and transaction receipts with no duplicates.

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'invitation_branches' -LogName 'phase2r-invitation-branches.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_contact_invitation_state.gd,res://tests/unit/test_game_state.gd,res://tests/scenario/test_invitation_branches.gd,res://tests/integration/test_restore_mutation_gate.gd','-gexit')
~~~

Expected GREEN: every solo and group row, Day 7 closure, and resumed idempotence.

- [ ] **Step 3.5: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 3 Step 3.5 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'feat(invitations): activate and open group offers atomically')) {
	throw 'Task 3 requires the exact Task 2 commit boundary as HEAD.'
}
$required = [ordered]@{
	'scripts/domain/contact/ContactInvitationState.gd' = 'M'
	'tests/scenario/test_invitation_branches.gd' = 'A'
	'tests/fixtures/invitations/group_resolution_cases.json' = 'A'
	'autoload/GameState.gd' = 'M'
	'scripts/ui/ContactListApp.gd' = 'M'
	'tests/unit/test_game_state.gd' = 'M'
	'scripts/domain/run/RunSnapshotSchema.gd' = 'M'
	'scripts/infrastructure/save/SaveMigrations.gd' = 'M'
	'tests/unit/test_run_snapshot_schema.gd' = 'M'
	'tests/unit/test_save_migrations.gd' = 'M'
	'tests/integration/test_restore_transaction.gd' = 'M'
	'tests/integration/test_restore_mutation_gate.gd' = 'M'
}
$optionalUids = [ordered]@{
	'tests/scenario/test_invitation_branches.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'feat(invitations): resolve exact solo and group rollover branches'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 3 commit boundary failed.' }
~~~

- [ ] **Step 3.6: Close .6**

- [ ] Append the branch-matrix evidence, confirm all query purity tests, and close dwm-p2r.6 only when every acceptance criterion passes.

## Task 4: Separate schedule-candidate and existing-schedule validation

**Beads:** dwm-p2r.7

**Files:**

- Create: scripts/domain/schedule/ScheduleRules.gd
- Create: tests/unit/test_schedule_rules_phase2r.gd
- Modify: tests/unit/test_schedule_strict_validation.gd (already tracked; created in 49947e5)
- Modify: tests/unit/test_schedule_route_plan.gd (already tracked; created in 1c25aba)
- Modify: tests/unit/test_schedule_characterization.gd (already tracked; Step 4.1a net)
- Modify: autoload/GameState.gd
- Modify: tests/unit/test_schedule_rules.gd
- Create: tests/fixtures/schedules/valid_cases.json
- Create: tests/fixtures/schedules/invalid_cases.json
- Modify: scripts/domain/run/RunSnapshotSchema.gd
- Modify: scripts/infrastructure/save/SaveMigrations.gd
- Modify: tests/unit/test_run_snapshot_schema.gd
- Modify: tests/unit/test_save_migrations.gd
- Modify: tests/integration/test_restore_transaction.gd

**Interfaces:**

- Consumes: registered action IDs plus an immutable eligibility snapshot from GameState.
- Produces: pure `validate_candidate(existing,candidate,day,motivation,eligibility)`, `validate_existing(schedule,day)`, and `build_route_plan(schedule,day)` CommandResults. Day-7 schedule entries persist `unlock_receipt_id`; aggregate snapshot validation proves it against the exact receipt index below.

- [ ] **Step 4.1: Claim .7 and write self-validation RED tests**

- [ ] Run:

~~~powershell
bd show dwm-p2r.4 --json
bd show dwm-p2r.5 --json
bd show dwm-p2r.6 --json
bd update dwm-p2r.7 --claim
~~~

All three blockers must be closed.

- [ ] Add a test that validates a one-entry existing schedule as valid even though validating the same entry as a new candidate is a duplicate:

~~~gdscript
func test_existing_entry_does_not_invalidate_itself() -> void:
	var existing := [{
		"entry_id": "solo-p-d3",
		"slot_index": 0,
		"day": 3,
		"type": "solo",
		"friend_ids": ["priscilla"],
		"action_id": "solo:priscilla:day3",
		"route_id": "dating",
		"effect_ids": [],
		"unlock_receipt_id": null,
	}]
	assert_true(ScheduleRules.validate_existing(
		existing, 3
	).get("ok", false))
	assert_false(ScheduleRules.validate_candidate(
			existing, existing[0], 3, 6, {
			"registered_action_ids": ["solo:priscilla:day3"],
			"day7_candidate": null,
			"receipt_index": {},
		}
	).get("ok", false))
~~~

- [ ] Add this Day-7 receipt-chain RED test to the same test file:

~~~gdscript
func test_day7_candidate_requires_matching_unlock_receipt_record() -> void:
	var candidate := {
		"entry_id": "ending-sylvia-d7",
		"slot_index": 0,
		"day": 7,
		"type": "solo",
		"friend_ids": ["sylvia"],
		"action_id": "ending-date:sylvia:day7",
		"route_id": "dating",
		"effect_ids": [],
		"unlock_receipt_id": "unlock:sylvia:day7",
	}
	var eligibility := {
		"registered_action_ids": ["ending-date:sylvia:day7"],
		"day7_candidate": {
			"action_id": "ending-date:sylvia:day7",
			"friend_id": "sylvia",
			"unlock_receipt_id": "unlock:sylvia:day7",
		},
		"receipt_index": {
			"unlock:sylvia:day7": {
				"receipt_id": "unlock:sylvia:day7",
				"kind": "day7_unlock",
				"action_id": "ending-date:sylvia:day7",
				"friend_id": "sylvia",
				"day": 7,
				"previous_receipt_id": null,
			}
		},
	}
	assert_true(ScheduleRules.validate_candidate(
		[], candidate, 7, 6, eligibility
	).get("ok", false))
	var mismatched: Dictionary = eligibility.duplicate(true)
	mismatched["receipt_index"]["unlock:sylvia:day7"]["friend_id"] = "lavinia"
	var rejected: Dictionary = ScheduleRules.validate_candidate(
		[], candidate, 7, 6, mismatched
	)
	assert_false(rejected.get("ok", false))
	assert_eq(rejected.get("code"), &"day7_candidate_not_synchronized")
~~~

- [ ] Run both RED tests before creating/replacing `ScheduleRules.gd`:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'schedule_rules_red' -LogName 'phase2r-red-schedule-rules.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_rules_phase2r.gd','-gexit')
~~~

Expected RED: the missing/new validator does not yet distinguish existing entries or validate the receipt record.

- [ ] **Step 4.1a: Freeze the characterization net (MANDATORY, amended 2026-08-10)**

This step is mandatory and must be complete and green BEFORE any GameState wiring in Step 4.2b. It was added by plan-author ruling and by the August schedule-consolidation work; it is not optional hardening.

Use GREEN characterization tests for the semantic behaviours below, then RED target tests for the new exact result and signal contracts.

- [ ] Freeze these public behaviours exactly as they are today:
  - A successful add costs exactly one motivation.
  - Removing one entry refunds exactly one.
  - Clear-with-refund refunds once per entry; clear-without-refund does not.
  - Rejections cause no mutation and emit no signals.
  - Empty schedule, date limits, duplicate-friend rules, and the Day-4 Priscilla ordering rule behave consistently.
  - Existing validation never rejects an entry by comparing it with itself.
  - Slot order is stable.
  - Stored and returned structures are deeply detached.
  - Done passes the exact frozen live schedule into `DayResolutionPlan`, NOT `[]`.

- [ ] Do NOT preserve these legacy accidents; they are defects the net must not lock in:
  - Loose entry dictionaries.
  - Player-scheduled `twofriends`.
  - Caller-owned dictionaries being mutated.
  - Removal-time cascade sanitation.
  - Generic `date_invalid` masking.
  - Boolean-only command results, or `executed`.
  - Direct external mutation of `schedule_entries`.
  - Duplicate `save_relevant_state_changed` emissions.

- [ ] **Step 4.2: Implement exact entry and result contracts**

- [ ] Schedule entry keys are exactly `entry_id`, `slot_index`, `day`, `type`, `action_id`, `friend_ids`, `route_id`, `effect_ids`, and `unlock_receipt_id`. `type` is `action`, `solo`, or `group`. Days 1–6 require JSON null `unlock_receipt_id`; a Day-7 solo requires a nonempty receipt ID. Unknown keys/IDs, wrong day, duplicate slot_index, negative slot, and duplicate entry_id reject.
- [ ] Preserve validated current rules through facade contract tests: motivation cost/refund, maximum two dates on Days 1–6, maximum one solo ending candidate on Day 7, Day-4 Priscilla first-slot rule, no duplicate solo/group friend set, and known non-date actions.
- [ ] Day 7 rejects non-date actions and any date without synchronized unlock/candidate evidence.
- [ ] Implement:

~~~gdscript
static func validate_candidate(
	existing: Array[Dictionary],
	candidate: Dictionary,
	day: int,
	motivation: int,
	eligibility: Dictionary
) -> Dictionary
static func validate_existing(
	schedule: Array[Dictionary],
	day: int
) -> Dictionary
static func build_route_plan(
	schedule: Array[Dictionary],
	day: int
) -> Dictionary
~~~

validate_existing compares each pair at most once and never compares an entry with itself.

#### build_route_plan contract (amended 2026-08-10, plan-author ruling)

A "registered semantic route ID" means a key in `SceneRouter._SCENE_PATHS`; [routes.json](../../../data/manifests/routes.json) is its generated, parity-checked mirror. Schedule routing is closed:

- `action` -> `route_id = null`; omitted from the route plan entirely.
- `solo` -> `route_id = "dating"`.
- `group` -> `route_id = "dating"`.
- `twofriends` is never schedulable and is never emitted here.
- `"none"` and `"advance"` are retired control sentinels, not route IDs.

Success is exactly:

~~~gdscript
{
	"ok": true,
	"code": &"ok",
	"value": {
		"route_plan": [
			{
				"entry_id": String,
				"slot_index": int,
				"route_id": String,
			}
		]
	},
	"receipt": {},
}
~~~

Rules:

- First call `validate_existing(schedule, day)` and propagate its failure unchanged.
- Emit only routed entries, ascending by `slot_index`.
- Return recursively detached data.
- Reject an `action` entry that carries a route.
- Reject a `solo`/`group` route other than `"dating"`.
- Return no partial plan on failure.
- Do not invent transaction IDs, resolution IDs, or presentation context; the coordinator adds those later.

For the current `.7` contract, Day-7 solo still follows the existing Phase-2R `dating` route. The approved boardless Day-7 model belongs to the seven-day reconciliation plan (`dwm-oyo`); backporting it here would rewrite `.7` mid-completion.

`eligibility` contains exactly `registered_action_ids:Array[String]`, `day7_candidate:Dictionary|null`, and `receipt_index:Dictionary`. `day7_candidate`, when non-null, has exactly `action_id:String`, `friend_id:String`, and `unlock_receipt_id:String`. `receipt_index` maps each receipt ID to exactly:

~~~json
{
  "receipt_id": "unlock:sylvia:day7",
  "kind": "day7_unlock",
  "action_id": "ending-date:sylvia:day7",
  "friend_id": "sylvia",
  "day": 7,
  "previous_receipt_id": null
}
~~~

For schedule eligibility, `kind` must be `day7_unlock`, `day` must be 7, and `previous_receipt_id` must be null. The map key must equal `receipt_id`. On Day 7, the candidate's action ID, sole friend ID, `unlock_receipt_id`, `day7_candidate`, and indexed receipt record must all match exactly; missing/mismatched evidence fails with `day7_candidate_not_synchronized`. Days 1–6 require `day7_candidate=null`, `receipt_index={}`, and `unlock_receipt_id=null`.

When GameState commits the add, its facade receipt is exactly `{receipt_id,kind="schedule_add",action_id,friend_id,day=7,previous_receipt_id=<unlock_receipt_id>}` and is stored in the run receipt ledger. When the date later completes, the DayResolutionPlan receipt is exactly `{receipt_id,kind="date_completed",action_id,friend_id,day=7,previous_receipt_id=<schedule_add receipt>,outcome="attended"}`. Task 6 accepts a primary candidate only by walking these three exact records; no ID naming convention is treated as proof.

- [ ] Implement the validator in this order:

~~~text
validate_candidate
  validate exact candidate keys/types and validate_existing(existing, day)
  reject duplicate entry_id/slot/action/friend set and insufficient motivation
  require action_id in registered_action_ids and enforce retained day-specific rules
  for day 1..6 require no Day-7 evidence
  for day 7 require type=solo, one friend, slot 0, matching day7_candidate,
    resolve candidate.unlock_receipt_id in receipt_index, validate the exact receipt
    keys/types, and compare every action/friend/day/ID field
  return frozen CommandResult with a detached normalized candidate

validate_existing
  validate each entry's exact keys/types and day
  compare each unordered pair once for duplicate slot/entry/action/friend-set rules
  require Day-7 structural unlock_receipt_id and Day-1..6 null
  do not authenticate receipt ownership here because this pure signature has no ledger

RunSnapshotSchema aggregate validation
  after ScheduleRules.validate_existing succeeds, resolve each Day-7 entry's
  unlock_receipt_id in the persisted run receipt index and apply the same exact record
  validation before any restore participant applies
~~~

- [ ] **Gaps confirmed present in the shipped module (audit 2026-08-10).** `scripts/domain/schedule/ScheduleRules.gd` already carries `validate_existing`, `validate_candidate`, `validate_date_candidate` and the Day-7 desync chain, but each of the following is still MISSING and needs RED coverage before GameState delegates to the module:
  - Duplicate `action_id` detection.
  - Duplicate solo/group friend-set detection in `validate_existing`.
  - Validation of the existing schedule BEFORE candidate validation.
  - Exact eligibility keys and types.
  - Rejection of stray Day-7 evidence on Days 1-6.
  - Day-7 `action`/`group` and nonzero-slot rejection.
  - Strict `action_id`, `route_id`, friend/effect element validation.
  - A detached normalized candidate in successful results.
  - `build_route_plan` itself, which does not exist in the tree at all.

- [ ] Replace the provisional aggregate `schedule` validation/default with `ScheduleRules.validate_existing()` plus exact entry-key/type validation. Update the not-yet-shipped v2 migration to emit `[]`; round-trip empty, one-entry, two-entry, Day-7, group, and rejected malformed schedules through SaveDocumentSchema and all six production restore participants. The restored schedule and eligibility/receipt inputs are detached and cannot alias the selected bundle.

- [ ] GameState add/remove/Done results use:

~~~gdscript
{
	"ok": bool,
	"code": StringName,
	"reason": String,
	"committed_effects": Array[Dictionary],
	"date_outcome_ids": Array[String],
	"route_plan": Array[Dictionary],
	"checkpoint_id": String,
}
~~~

Remove the ambiguous executed boolean after zero callers remain.

- [ ] **Step 4.2a: Define and persist the Day-7 receipt-index owner (amended 2026-08-10)**

Architecture gap found during the dwm-7e6 audit: no production owner currently creates the required chain

~~~text
day7_unlock -> schedule_add -> date_completed
~~~

Task 6 accepts a primary candidate only by walking these three exact records, so without an owner that chain can never be satisfied in production.

- [ ] Do NOT place these receipts in `command_receipts`. That ledger is strictly effect/variable-only; widening it would break the receipt-partition invariant `RunSnapshotSchema` enforces.
- [ ] The causal owners emit the three receipts. GameState transactionally persists their index inside the run-local `dating` aggregate that `DatingEndingRules` already reads.
- [ ] Cover the chain with RED tests before wiring, including a Day-7 candidate whose `unlock_receipt_id` resolves to a record with the wrong `kind`, wrong `day`, or a non-null `previous_receipt_id`.

- [ ] **Step 4.2b: Wire GameState and pass the real frozen schedule**

- [ ] Only after Step 4.1a is green. Delegate GameState's schedule validation to `ScheduleRules`.
- [ ] `GameStateDayResolutionPort` currently passes `[]` into the lifecycle (`begin_day_resolution(command_id, [])`). Replace it with the exact frozen live schedule, so the production port stops resolving days against an empty schedule.
- [ ] **Acceptance (added 2026-08-11, plan-author ruling): retire `ScheduleRules.validate_date_candidate()`.** It is a transitional production adapter kept deliberately loose while the strict API was built, and it is the last method still returning the legacy bare `{ok, code, message}` result. Once GameState consumes the strict API, prove zero callers with `rg 'validate_date_candidate' --type gd` and DELETE the method, its `_legacy_fail` helper, and the legacy-shape contract test. Step 4.2b is not complete while it survives.
- [ ] **Acceptance (added 2026-08-11, plan-author ruling): registry parity before wiring.** Registry membership proves only that an action ID exists. Bind each registered action ID to its exact day, type, friends, route, and effects before GameState delegation or restore validation lands, otherwise a valid action ID can carry another action's effects. Tracked as a hard blocker in Beads.

- [ ] **Step 4.3: Verify focused schedule behavior**

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'schedule_rules' -LogName 'phase2r-schedule-rules.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_characterization.gd,res://tests/unit/test_schedule_route_plan.gd,res://tests/unit/test_schedule_rules.gd,res://tests/unit/test_schedule_rules_phase2r.gd,res://tests/unit/test_schedule_strict_validation.gd','-gexit')
~~~

The gate is all five schedule suites, not two (corrected 2026-08-11): the strict-validation and route-plan suites were added after this step was first written, and the characterization net from Step 4.1a must not be allowed to rot unwatched.

Expected GREEN: candidate and existing validation differ only where they should; duplicate slots reject; all retained rules have contract evidence.

A fresh worktree has no `.godot` import cache, so Godot's global `class_name` registry does not exist and autoloads fail to instantiate while the runner still reports exit 0 — a false green. Build the cache once before the first run:

~~~powershell
& $env:GODOT_CONSOLE_PATH --headless --path . --import --quit-after 200
git checkout -- project.godot   # MANDATORY, see below
~~~

**`--import` is destructive to `project.godot`.** It rewrites `[dialogic] directories/dtl_directory` to `{}`, discarding every registered timeline path, because the Dialogic directory is rebuilt before the `.dtl` files finish importing. Always `git checkout -- project.godot` immediately after, and never let that deletion reach a commit. The GUT runs themselves do not dirty `project.godot`; only `--import` does.

Documentation validation (`tools/docs/validate_docs.gd`, required before the final commit of any sequence) has three non-obvious invocation requirements, all of which fail closed with unhelpful codes:

~~~powershell
$snap = Join-Path $env:TEMP 'beads-snapshot.json'
# --status=all: bd list defaults to OPEN issues, so closed beads referenced by prompt_docs
# packets report DOC_BEAD_UNKNOWN.
$json = (bd list --status=all --json | Out-String)
# BOM-free UTF-8: Windows PowerShell 5.1's -Encoding utf8 writes a BOM, and the validator's
# strict round-trip check rejects it as DOC_BEAD_SNAPSHOT_INVALID: UTF-8.
[IO.File]::WriteAllText($snap, $json, (New-Object Text.UTF8Encoding($false)))
# The snapshot path is a USER arg, so it must follow a bare `--` separator.
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'docs_validate' -LogName 'phase2r-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--',"--beads-snapshot=$snap")
~~~

Expected: `DOC_VALIDATION: PASS packets=14 agent_workflow=1`. Note this validator covers `res://prompt_docs` and `Prompt.md` only — it does NOT validate this plan file.

- [ ] **Step 4.4: Commit boundaries (rewritten 2026-08-11, plan-author ruling)**

The single-commit map this step used to carry was stale. `ScheduleRules.gd` and the schedule suites are already tracked, so their old `A` statuses were wrong, and Task 4 has since become a multi-commit sequence. Each commit records its own literal path/status boundary below; no aggregate assumption applies.

**Sequence 1 — the pure-validator slice.** RED then GREEN per commit, checklist tick in the same commit, one rule per commit. Every commit in this slice touches `scripts/domain/schedule/ScheduleRules.gd = M` and `tests/unit/test_schedule_strict_validation.gd = M`; the additional paths are:

| # | Subject | Additional paths |
|---|---|---|
| A | `refactor(schedule): freeze the master command result contracts` | this plan = `M` |
| B | `feat(schedule): validate the existing and prospective schedule at add time` | — |
| D | `refactor(schedule): return typed codes from entry shape validation` | — |
| E1 | `feat(schedule): validate entry element types, arity and day range` | `tests/unit/test_schedule_route_plan.gd = M` |
| C | `feat(schedule): reject duplicate friend sets in an existing schedule` | — |
| E2 | `feat(schedule): validate schedule routes semantically` | `tests/unit/test_schedule_rules_phase2r.gd = M`, `tests/unit/test_schedule_route_plan.gd = M` |
| F | `feat(schedule): restrict day 7 to a single solo entry at slot zero` | `tests/unit/test_schedule_rules_phase2r.gd = M` |
| G | `feat(schedule): validate the eligibility graph exactly` | — |
| H | `feat(schedule): reject day 7 evidence outside day 7` | — |
| I | `feat(schedule): seat day 4 priscilla by slot index` | — |
| J | `feat(schedule): return a detached validated candidate` | — |

Any deviation from a row above must be recorded here rather than silently committed.

**Sequence 2 — the remainder of Task 4**, still outstanding after the slice above: Step 4.2a Day-7 receipt ownership, Step 4.2b GameState delegation plus the real frozen schedule into Done and the `validate_date_candidate` retirement, and the snapshot/migration/restore validation named in this task's Files list. `dwm-p2r.7` does not close until those land.

**Identity is a SHA, never a subject.** After ALL Task-4 work is committed and verified, record that final commit's full SHA in Beads and require exact SHA equality downstream. A commit subject is not identity: subjects repeat, get amended, and cannot distinguish a rebase. Task 5's guard is repointed at that recorded SHA at that time — not by any commit inside this slice.

Committing any boundary still requires explicit commit authority (`DWM_COMMIT_AUTHORIZED -ceq '1'` for the scripted exact-path path, or a direct human grant recorded in the session).

## Task 5: Make Hospital and dating report resumable receipts

**Beads:** dwm-p2r.7

> **Amended 2026-08-10 (plan-author ruling):** Task 5 must resolve the existing `twofriends` contradiction. The plan and the contact receipt already use `twofriends` as a semantic ID, but it is not a registered route, while Task 4's `build_route_plan` is forbidden from emitting it. Recommended resolution: register
>
> ~~~gdscript
> "twofriends": "res://scenes/dating/DatingScene.tscn"
> ~~~
>
> in `SceneRouter._SCENE_PATHS` and regenerate `routes.json`. It may share `DatingScene` physically while retaining a distinct semantic identity. `twofriends` remains never player-schedulable.

**Files:**

- Modify: scripts/ui/HospitalScene.gd
- Modify: scripts/ui/DatingScene.gd
- Modify: autoload/SceneRouter.gd
- Extend: scripts/domain/ending/DatingEndingRules.gd
- Create: tests/scenario/test_hospital_twofriends_order.gd
- Create: tests/integration/test_route_receipts.gd

**Interfaces:**

- Consumes: DayResolutionCoordinator route command/receipt schema and DatingEndingRules pure Hospital result.
- Produces: Hospital/Dating presentation adapters that validate registered physical route receipts, then report only the frozen `scene_router/route_complete` substage envelope to GameState; no scene mutates day, schedule queues, invitation state, or EndingPlan.

- [ ] **Step 5.1: Add the pure Hospital outcome seam**

- [ ] Create this RED test first in `tests/scenario/test_hospital_twofriends_order.gd`:

~~~gdscript
extends "res://addons/gut/test.gd"

const RULES_PATH := "res://scripts/domain/ending/DatingEndingRules.gd"

func test_hospital_outcome_is_pure_and_records_skipped_sylvia() -> void:
	var rules: Script = load(RULES_PATH)
	assert_not_null(rules)
	if rules == null:
		return
	var input := {
		"day": 7,
		"health": 0,
		"pressure": 6,
		"condition_effect_ids": ["condition.danger"],
		"scheduled_date_outcomes": [{
			"action_id": "ending-date:sylvia:day7",
			"friend_ids": ["sylvia"],
			"outcome": "prevented_by_fainting",
		}],
		"transaction_id": "hospital:run-1:day7",
	}
	var before: Dictionary = input.duplicate(true)
	var result: Dictionary = rules.resolve_hospital_outcome(input)
	assert_true(result.get("ok", false))
	assert_eq(input, before)
	assert_eq(result["value"]["health"], 6)
	assert_eq(result["value"]["pressure"], 3)
	assert_eq(result["value"]["condition_effect_ids"], [])
	assert_eq(result["value"]["hospital_skipped_sylvia_solo_count_delta"], 1)
	assert_eq(result["receipt"]["transaction_id"], "hospital:run-1:day7")

func test_hospital_accepts_group_outcome_but_counts_only_sylvia_solo() -> void:
	var rules: Script = load(RULES_PATH)
	var result: Dictionary = rules.resolve_hospital_outcome({
		"day": 3,
		"health": 0,
		"pressure": 6,
		"condition_effect_ids": ["condition.danger"],
		"scheduled_date_outcomes": [
			{
				"action_id": "solo:sylvia:day3",
				"friend_ids": ["sylvia"],
				"outcome": "prevented_by_fainting",
			},
			{
				"action_id": "group:priscilla_lavinia:day2",
				"friend_ids": ["priscilla", "lavinia"],
				"outcome": "cancelled_by_fainting",
			},
		],
		"transaction_id": "hospital:run-1:day3",
	})
	assert_true(result.get("ok", false))
	assert_eq(result["value"]["hospital_skipped_sylvia_solo_count_delta"], 1)
	assert_eq(result["receipt"]["skipped_action_ids"], ["solo:sylvia:day3"])
~~~

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'hospital_outcome_red' -LogName 'phase2r-red-hospital-outcome.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scenario/test_hospital_twofriends_order.gd','-gexit')
~~~

Expected RED: `resolve_hospital_outcome()` is missing or returns the legacy day-advancing mutation.

- [ ] DatingEndingRules adds:

~~~gdscript
static func resolve_hospital_outcome(input: Dictionary) -> Dictionary
~~~

Input has exactly `day:int`, `health:int`, `pressure:int`, `condition_effect_ids:Array[String]`, `scheduled_date_outcomes:Array[Dictionary]`, and `transaction_id:String`. Each scheduled outcome has exactly `action_id`, `friend_ids`, and `outcome=attended|not_attended|prevented_by_fainting|cancelled_by_fainting`. A solo outcome has exactly one registered friend and its action ID must identify that same solo action; a group outcome has the canonical sorted `friend_ids=["priscilla","lavinia"]` and a registered Day-2/Day-6 group-offer action ID. The offer day embedded in that group action may precede the current scheduled-route day. Output is the frozen CommandResult whose value has exactly `health=6`, `pressure=3`, `condition_effect_ids=[]`, and `hospital_skipped_sylvia_solo_count_delta:int`; its receipt has `transaction_id`, `kind="hospital_outcome"`, `day`, and sorted `skipped_action_ids`. It records only Sylvia **solo** entries whose outcome is `prevented_by_fainting` or `cancelled_by_fainting`, ignores every valid group record for that counter, and never changes day.

- [ ] Implement it as a pure fold over a detached input: validate exact keys/types/day/IDs and the solo/group action-to-participant correspondence; collect unique Sylvia solo action IDs with an allowed faint-cancel outcome; ignore valid group records for the counter; return the fixed restored stats plus count delta and receipt. Reject duplicate action IDs, malformed solo or group records, unknown outcomes, wrong participant ordering, or a non-Sylvia ID paired with `friend_ids=["sylvia"]`; do not reject a structurally valid group record.

- [ ] **Step 5.2: Replace scene-owned day advancement**

- [ ] Write the route-completion RED test first in `tests/integration/test_route_receipts.gd`:

~~~gdscript
extends "res://addons/gut/test.gd"

class FakeResolutionPort:
	extends RefCounted
	var calls: Array[Dictionary] = []
	func complete_day_resolution_stage(transaction_id: String,
			receipt: Dictionary) -> Dictionary:
		calls.append({"transaction_id": transaction_id, "receipt": receipt.duplicate(true)})
		return {"ok": true, "code": &"ok", "value": {}, "receipt": receipt}

class FakePresentationPort:
	extends RefCounted
	signal presentation_completed(receipt: Dictionary)
	func start_route_id(route_id: StringName, context: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {
			"route_id": route_id, "context": context.duplicate(true)}, "receipt": {}}

func test_hospital_reports_only_after_physical_completion() -> void:
	var scene_script: Script = load("res://scripts/ui/HospitalScene.gd")
	var scene: Node = scene_script.new()
	add_child_autofree(scene)
	var resolution := FakeResolutionPort.new()
	var presentation := FakePresentationPort.new()
	assert_true(scene.configure_resolution_ports(
		resolution, presentation
	).get("ok", false))
	var command := {
		"resolution_id": "resolution:run-1:day3",
		"stage_id": &"hospital_if_triggered",
		"route_id": &"hospital",
		"entry_id": "",
		"transaction_id": "hospital:run-1:day3",
		"context": {},
	}
	assert_true(scene.begin_resolution_route(command).get("ok", false))
	assert_eq(resolution.calls.size(), 0)
	presentation.presentation_completed.emit({
		"receipt_id": "hospital:run-1:day3:completed",
		"transaction_id": "hospital:run-1:day3",
		"resolution_id": "resolution:run-1:day3",
		"stage_id": &"hospital_if_triggered",
		"route_id": &"hospital",
		"entry_id": "",
		"outcome": &"completed",
		"details": {},
	})
	assert_eq(resolution.calls.size(), 1)
	assert_eq(resolution.calls[0], {
		"transaction_id": "hospital:run-1:day3",
		"receipt": {
			"owner_id": "scene_router",
			"kind": "route_complete",
			"value": {
				"route_receipt_id": "hospital:run-1:day3:completed",
			},
		},
	})
~~~

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'route_receipts_red' -LogName 'phase2r-red-route-receipts.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_route_receipts.gd','-gexit')
~~~

Expected RED: the scenes do not yet expose the injected completion-only route seam.

- [ ] HospitalScene starts its registered narrative/presentation, then reports a route receipt to complete hospital_if_triggered. It never calls apply_hospital_recovery_and_advance_day(), resolve_day7_ending(), or a day increment.
- [ ] DatingScene reports each route-segment/date-outcome receipt to the active schedule substage. It never advances the pending queue or day itself.
- [ ] SceneRouter.finish_current_dating_and_route() is replaced by resume_day_resolution(); the next incomplete plan stage decides Hospital, twofriends, another date segment, ending, or main route.
- [ ] Group dating input includes inviter_id only for image_position_variant and includes replied_ids for normal versus judgmental dialogue variation.

Both scenes implement exactly `configure_resolution_ports(state_port:Object, presentation_port:Object) -> Dictionary` and `begin_resolution_route(command:Dictionary) -> Dictionary`. Configuration requires `state_port.complete_day_resolution_stage(transaction_id,receipt)`, `presentation_port.start_route_id(route_id,context)`, and the presentation port's `presentation_completed(receipt)` signal; it rejects replacement by different instances after configuration. Begin validates the command, stores one detached active command, connects once, and starts presentation. The completion callback strict-validates the full presentation receipt against that active command, then converts it to the frozen DayResolution substage envelope below. Only that envelope and the command's separate `transaction_id` cross the GameState/DayResolution boundary. The scene never forwards the flat presentation receipt. It clears the active command only after the state port returns success and retains a detached completed binding/result solely for identical duplicate callbacks.

- [ ] Use this exact route command/receipt contract between coordinator and presentation scenes:

~~~gdscript
#registered-command returned by DayResolutionCoordinator
{
	"ok": true,
	"code": &"route_required",
	"value": {
		"resolution_id": String,
		"stage_id": StringName,
		"route_id": StringName,
		"entry_id": String,
		"transaction_id": String,
		"context": Dictionary,
	},
	"receipt": {},
}

#completion-receipt reported only after presentation has physically completed
{
	"receipt_id": String,
	"transaction_id": String,
	"resolution_id": String,
	"stage_id": StringName,
	"route_id": StringName,
	"entry_id": String,
	"outcome": StringName,
	"details": Dictionary,
}

#only value passed as the receipt argument to GameState/DayResolution after validation
{
	"owner_id": "scene_router",
	"kind": "route_complete",
	"value": {
		"route_receipt_id": String,
	},
}
~~~

`HospitalScene` and `DatingScene` retain the active command. Only their physical presentation-completed callback may first validate the receipt's exact eight keys/types and equality of `transaction_id`, `resolution_id`, `stage_id`, `route_id`, and `entry_id` to the active command, require `outcome=&"completed"`, and require a nonempty unique `receipt_id`. The callback then constructs exactly `{"owner_id":"scene_router","kind":"route_complete","value":{"route_receipt_id":receipt.receipt_id}}` and calls `GameState.complete_day_resolution_stage(command.transaction_id, envelope)`. The facade delegates that envelope to `DayResolutionCoordinator.complete_route_stage()`; it never receives presentation-only routing/details fields. A mismatch returns `route_receipt_mismatch`, makes zero state-port calls, and leaves the active command intact. An identical physical duplicate after success returns the stored copied state-port result with zero second call; the same `receipt_id` with different bytes returns `duplicate_receipt_conflict`. A receipt received with neither an active nor identical completed binding returns `no_active_route`. Scene exit, `_ready()`, button focus, and route instantiation never synthesize completion.

- [ ] Extend `test_route_receipts.gd` with table-driven mismatches for every compared field, missing/extra key, wrong `outcome`, empty `receipt_id`, and wrong scalar type. Assert zero facade calls and retained active command. Then emit an exact success twice and assert one facade call plus byte-equal copied results; mutate one field under the same receipt ID and assert `duplicate_receipt_conflict`. The fake resolution port rejects any receipt argument whose exact keys are not `owner_id,kind,value` or whose nested value is not exactly `route_receipt_id`.

- [ ] **Step 5.3: Prove ordering and mid-route restore**

- [ ] Scenario input combines fainting and an accepted missed group date on Day 3. Assert committed route sequence:

~~~text
hospital
twofriends
invitation_rollover
increment_day
day_start checkpoint/autosave
~~~

There is one day increment. Restoring after Hospital completion resumes at twofriends and never replays recovery or a prior scheduled entry.

The scenario includes the valid cancelled Priscilla/Lavinia group outcome in `scheduled_date_outcomes`. Hospital's pure counter result ignores it, while the persisted DayResolutionPlan retains its separate group route receipt and therefore still produces the required `Hospital -> twofriends` order. A malformed group record rejects before Hospital begins; a valid group record can never suppress twofriends merely because it contributes zero to the Sylvia-only counter.

- [ ] Day 7 fainting sequence is Hospital -> ending resolution, day remains 7, and no twofriends or next-day message exists.
- [ ] Add two distinct Day-7 cases: fainting before Schedule Done and fainting during a scheduled route. `commit_fainting_event()` creates/resumes the terminal DayResolutionPlan immediately. The active entry records `prevented_by_fainting`; every not-yet-started scheduled entry is still resolved in slot order with a `cancelled_by_fainting` receipt and no effect/refund, satisfying the requirement that scheduled content receive a persisted resolution rather than silently disappear. The coordinator then runs Hospital, closes invitations, resolves the ending, enters ENDING, and writes ending autosave. This is separate from an ordinary completed schedule and never waits for another Done press.

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'hospital_routes' -LogName 'phase2r-hospital-routes.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scenario/test_hospital_twofriends_order.gd,res://tests/integration/test_route_receipts.gd','-gexit')
~~~

- [ ] **Step 5.4: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 5 Step 5.4 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'refactor(schedule): separate candidate and committed schedule validation')) {
	throw 'Task 5 requires the exact Task 4 commit boundary as HEAD.'
}
$required = [ordered]@{
	'scripts/ui/HospitalScene.gd' = 'M'
	'scripts/ui/DatingScene.gd' = 'M'
	'autoload/SceneRouter.gd' = 'M'
	'scripts/domain/ending/DatingEndingRules.gd' = 'M'
	'tests/scenario/test_hospital_twofriends_order.gd' = 'A'
	'tests/integration/test_route_receipts.gd' = 'A'
}
$optionalUids = [ordered]@{
	'tests/scenario/test_hospital_twofriends_order.gd.uid' = 'A'
	'tests/integration/test_route_receipts.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'refactor(flow): resume Hospital and dating from stage receipts'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 5 commit boundary failed.' }
~~~

## Task 6: Resolve canonical primary endings and optional group epilogue

**Beads:** dwm-p2r.7

**Files:**

- Modify: scripts/domain/ending/DatingEndingRules.gd (created by `.5` for Day-8 migration)
- Create: scripts/application/ending/EndingPlaybackPort.gd
- Create: tests/unit/test_dating_ending_rules.gd
- Create: tests/scenario/test_day7_endings.gd
- Modify: autoload/GameState.gd
- Modify: scripts/ui/EndingScene.gd
- Modify: scripts/ui/GalleryScene.gd
- Modify: tests/unit/test_game_state.gd
- Modify: scripts/domain/run/RunSnapshotSchema.gd
- Modify: scripts/infrastructure/save/SaveMigrations.gd
- Modify: tests/unit/test_run_snapshot_schema.gd
- Modify: tests/unit/test_save_migrations.gd
- Modify: tests/integration/test_restore_transaction.gd

**Interfaces:**

- Consumes: DatingEndingRules core from `.5`, ProfileManager `prepare_ending_unlock` plus deferred profile commit/publication, RunLifecycle `complete_ending_playback_stage`, an injected `EndingPlaybackPort`, and checkpoint port.
- Produces: validated EndingPlan and GameState playback command whose stage transition, gallery receipt(s), and stable checkpoint commit occur before signals/routing; a fake playback port proves `.7`, while `.8` supplies the real Dialogic adapter. `EndingPlaybackPort.start_ending_id()` reports start only; the stage can advance only from its separately validated `playback_completed` callback.

- [ ] **Step 6.1: Freeze canonical IDs and RED precedence tests**

- [ ] Create this runnable RED test first in `tests/unit/test_dating_ending_rules.gd`:

~~~gdscript
extends "res://addons/gut/test.gd"

const RULES_PATH := "res://scripts/domain/ending/DatingEndingRules.gd"

func test_sylvia_special_precedes_a_valid_completed_candidate() -> void:
	var rules: Script = load(RULES_PATH)
	assert_not_null(rules)
	if rules == null:
		return
	var result: Dictionary = rules.resolve_primary_ending({
		"day": 7,
		"hospital_skipped_sylvia_solo_count": 2,
		"completed_candidate": {
			"friend_id": "priscilla",
			"action_id": "ending-date:priscilla:day7",
			"unlock_receipt_id": "unlock:p:d7",
			"schedule_receipt_id": "schedule:p:d7",
			"completion_receipt_id": "complete:p:d7",
		},
		"receipt_index": {
			"unlock:p:d7": {"receipt_id":"unlock:p:d7", "kind":"day7_unlock",
				"action_id":"ending-date:priscilla:day7", "friend_id":"priscilla",
				"day":7, "previous_receipt_id":null},
			"schedule:p:d7": {"receipt_id":"schedule:p:d7", "kind":"schedule_add",
				"action_id":"ending-date:priscilla:day7", "friend_id":"priscilla",
				"day":7, "previous_receipt_id":"unlock:p:d7"},
			"complete:p:d7": {"receipt_id":"complete:p:d7", "kind":"date_completed",
				"action_id":"ending-date:priscilla:day7", "friend_id":"priscilla",
				"day":7, "previous_receipt_id":"schedule:p:d7", "outcome":"attended"},
		},
		"true_path_count": 4,
		"affection_tier": "love",
		"dark_points": 0,
	})
	assert_true(result.get("ok", false))
	assert_eq(result["value"], "ending.sylvia.special")
~~~

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ending_rules_red' -LogName 'phase2r-red-ending-rules.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dating_ending_rules.gd','-gexit')
~~~

Expected RED: the canonical primary resolver or synchronized receipt-chain validation is absent.

- [ ] CANONICAL_ENDING_IDS contains exactly:

~~~text
ending.alone
ending.priscilla.sweet
ending.priscilla.dark
ending.priscilla.true
ending.lavinia.sweet
ending.lavinia.dark
ending.lavinia.true
ending.sylvia.sweet
ending.sylvia.dark
ending.sylvia.true
ending.sylvia.special
ending.priscilla_lavinia
~~~

The first eleven are the only valid primary IDs. ending.priscilla_lavinia is only a nullable epilogue.

- [ ] Tests cover special Sylvia precedence, each friend's true/dark/sweet path, alone fallback, unknown friend, multiple candidates, fainted/noncompleted candidate, group-primary rejection, epilogue threshold, and primary unaffected by epilogue.

- [ ] **Step 6.2: Implement synchronized ending input**

- [ ] DatingEndingRules exposes the master methods plus:

~~~gdscript
static func resolve_hospital_outcome(input: Dictionary) -> Dictionary
static func next_playback_command(plan: Dictionary) -> Dictionary
~~~

- [ ] resolve_primary_ending() uses only a completed Day-7 outcome whose friend is priscilla, lavinia, or sylvia and whose unlock, schedule, and successful completion evidence share the same DayResolutionPlan receipts. A scheduled-only or faint-prevented date is not a candidate. More than one candidate rejects.

The input uses the Task-4 `receipt_index`. `completed_candidate` is null or exactly `{friend_id,action_id,unlock_receipt_id,schedule_receipt_id,completion_receipt_id}`. Validation resolves all three IDs and requires this exact chain:

~~~text
day7_unlock(previous=null)
  <- schedule_add(previous=unlock receipt ID)
    <- date_completed(previous=schedule receipt ID, outcome=attended)
~~~

All three records must have the same `day=7`, `action_id`, and `friend_id`, every map key must equal its record's `receipt_id`, and the candidate fields must equal those records. `date_completed.outcome` of `not_attended`, `prevented_by_fainting`, or `cancelled_by_fainting` cannot become a primary candidate. Unknown or extra record keys reject before precedence is evaluated.

Precedence is exact:

1. ending.sylvia.special when hospital_skipped_sylvia_solo_count >= 2.
2. Completed candidate true when true_path_count >= 4 and affection_tier == love.
3. Completed candidate dark when the true rule failed and dark_points >= 2.
4. Completed candidate sweet when earlier rules failed and dark_points <= 1.
5. ending.alone when no completed candidate exists.

resolve_epilogue() returns ending.priscilla_lavinia only when missed_group_date_counts.priscilla_lavinia >= 2.

- [ ] Implement `resolve_primary_ending()` as: exact-key/type validation; special-Sylvia counter check; zero-or-one candidate validation by the receipt walk above; then true/dark/sweet precedence for that candidate; finally alone when candidate is null. Return the frozen CommandResult with the canonical ending ID in `value` and a detached receipt describing the matched precedence rule. `build_ending_plan()` calls primary and epilogue resolvers, creates `playback_stage=PRIMARY_PENDING`, then calls `validate_ending_plan()` before returning.

- [ ] **Step 6.3: Implement resumable playback and independent gallery receipts**

- [ ] Write this completion-boundary RED test first in `tests/scenario/test_day7_endings.gd`:

~~~gdscript
extends "res://addons/gut/test.gd"

class FakeEndingStatePort:
	extends RefCounted
	var completion_calls: Array[Dictionary] = []
	func request_next_ending_command() -> Dictionary:
		return {"ok":true, "code":&"play_ending", "value":{
			"kind":&"play_ending", "ending_id":"ending.alone",
			"playback_context":{
				"playback_id":"run-1:primary",
				"transaction_id":"run-1:primary:complete",
				"expected_stage":&"PRIMARY_PENDING",
				"role":&"primary",
			}}, "receipt":{}}
	func complete_ending_playback_stage(transaction_id: String,
			expected_stage: StringName, receipt: Dictionary) -> Dictionary:
		completion_calls.append({"transaction_id":transaction_id,
			"expected_stage":expected_stage, "receipt":receipt.duplicate(true)})
		return {"ok":true, "code":&"ok", "value":{}, "receipt":receipt}

class FakeEndingPlaybackPort:
	extends RefCounted
	signal playback_completed(completion: Dictionary)
	signal playback_failed(failure: Dictionary)
	var starts: Array[Dictionary] = []
	func is_ready() -> bool: return true
	func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary:
		starts.append({"ending_id":ending_id, "context":context.duplicate(true)})
		return {"ok":true, "code":&"started", "value":{}, "receipt":{
			"playback_id":context["playback_id"],
			"transaction_id":context["transaction_id"],
			"expected_stage":context["expected_stage"],
			"role":context["role"],
			"ending_id":ending_id,
			"playback_token":"fake-token-1",
			"started":true,
		}}

func test_stage_does_not_advance_until_matching_playback_completed() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	assert_true(scene.configure_ending_ports(state, playback).get("ok", false))
	assert_true(scene.resume_ending().get("ok", false))
	assert_eq(playback.starts.size(), 1)
	assert_eq(playback.starts[0]["context"], {
		"playback_id":"run-1:primary",
		"transaction_id":"run-1:primary:complete",
		"expected_stage":&"PRIMARY_PENDING",
		"role":&"primary",
	})
	assert_eq(state.completion_calls.size(), 0)
	playback.playback_completed.emit({"playback_id":"run-1:primary",
		"ending_id":"ending.alone", "expected_stage":&"PRIMARY_PENDING",
		"transaction_id":"run-1:primary:complete",
		"timeline_completion_receipt_id":"timeline:alone:complete",
		"outcome":&"completed"})
	assert_eq(state.completion_calls.size(), 1)
~~~

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ending_playback_boundary_red' -LogName 'phase2r-red-ending-playback-boundary.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scenario/test_day7_endings.gd','-gexit')
~~~

Expected RED: EndingScene advances on start or lacks the completion-only injected seam.

- [ ] EndingPlan is exactly:

~~~json
{
  "primary_id": "ending.priscilla.true",
  "epilogue_id": "ending.priscilla_lavinia",
  "playback_stage": "PRIMARY_PENDING"
}
~~~

Allowed playback stages are PRIMARY_PENDING, PRIMARY_COMPLETED, EPILOGUE_COMPLETED, and GALLERY_RECORDED.

`DatingEndingRules.next_playback_command()` returns exactly one of:

~~~text
PRIMARY_PENDING                         -> {kind=play_ending, ending_id=primary_id, role=primary, expected_stage=PRIMARY_PENDING}
PRIMARY_COMPLETED with epilogue         -> {kind=play_ending, ending_id=epilogue_id, role=epilogue, expected_stage=PRIMARY_COMPLETED}
PRIMARY_COMPLETED without epilogue      -> {kind=record_gallery, expected_stage=PRIMARY_COMPLETED}
EPILOGUE_COMPLETED                      -> {kind=record_gallery, expected_stage=EPILOGUE_COMPLETED}
GALLERY_RECORDED                        -> {kind=complete_run, expected_stage=GALLERY_RECORDED}
~~~

`GameState.request_next_ending_command() -> Dictionary` validates the live EndingPlan and returns one frozen `CommandResult`. For `kind=play_ending`, `value` has exactly `kind`, `ending_id`, and `playback_context`; `playback_context` has exactly `playback_id`, `transaction_id`, `expected_stage`, and `role`. GameState derives the two IDs from run ID plus role, copies the pure command's expected stage/role, and rejects any mismatch. EndingScene passes that dictionary unchanged to `EndingPlaybackPort.start_ending_id(ending_id, playback_context)` and stores the same detached command for completion comparison. This is the only state-port query used by EndingScene.

- [ ] EndingScene resumes the first incomplete command:

~~~text
PRIMARY_PENDING -> play primary -> checkpoint PRIMARY_COMPLETED
PRIMARY_COMPLETED + epilogue -> play epilogue -> checkpoint EPILOGUE_COMPLETED
PRIMARY_COMPLETED + no epilogue -> record gallery transactions
EPILOGUE_COMPLETED -> record gallery transactions
record primary and optional epilogue as independent ProfileManager transactions
checkpoint GALLERY_RECORDED
RunLifecycle ENDING -> COMPLETED
SceneRouter menu
~~~

The ending_autosave stage has already written the ENDING checkpoint before primary playback starts. Each later transition creates an in-memory stable checkpoint. Repeated completion signals return existing receipts and do not replay timelines or gallery unlocks.

`EndingScene` never writes `playback_stage` directly. It implements `configure_ending_ports(state_port:Object, playback_port:Object)`, `resume_ending()`, `on_ending_playback_completed(completion:Dictionary)`, and `on_ending_playback_failed(failure:Dictionary)`. The structural playback-port contract is exactly `signal playback_completed(completion:Dictionary)`, `signal playback_failed(failure:Dictionary)`, `start_ending_id(ending_id:String,context:Dictionary={})->Dictionary`, and `is_ready()->bool`; dependency initialization belongs to the production adapter and is not overloaded onto the scene-owner seam. `configure_ending_ports()` validates both ports, connects each playback signal to the matching callback exactly once, and rejects replacement while a command is pending. `resume_ending()` passes the frozen `playback_context` unchanged. Start returns an outer `code=started`, empty `value`, and the seven-field receipt `playback_id/transaction_id/expected_stage/role/ending_id/playback_token/started`; it MUST NOT advance state. Completion has exactly `playback_id`, `ending_id`, `expected_stage`, `transaction_id`, `timeline_completion_receipt_id`, and `outcome=completed`; EndingScene compares every field with its pending command and `playback_context` before calling `GameState.complete_ending_playback_stage()`. Failure has exactly `playback_id`, `ending_id`, `expected_stage`, `transaction_id`, `code`, and `result`; a matching failure leaves the command and EndingPlan stage pending for an explicit retry, while a mismatch halts. A duplicate identical completion callback returns the stored receipt. `.7` uses the recording fake and leaves production startup explicitly incomplete. Plan `.8` implements the Dialogic-backed port, emitting completion only from the matching physical timeline-ended event.

For `kind=complete_run`, the same facade method receives a `complete_run` receipt while current stage is GALLERY_RECORDED, calls `RunLifecycle.complete_ending()`, commits the COMPLETED checkpoint, and returns the registered Menu route. Thus no scene calls RunLifecycle directly and no additional GameState completion method is implicit.

For gallery recording, GameState processes primary then optional epilogue. Each ID uses transaction `ending:<run_id>:gallery:<ending_id>` and is prepared from the latest committed profile, so the second candidate includes the first receipt. Each durable profile commit defers its signal and records its publication ID. If a later profile write or checkpoint fails, GameState publishes every already durable deferred notification and returns `profile_ahead_profile_batch_failed` or `profile_ahead_checkpoint_failed`; stage remains pending and retry reuses stored receipts. After both profile writes, it commits lifecycle stage + checkpoint, then publishes both deferred notifications in order. Publication failure returns a fatal pending-publication result and retry publishes the same IDs before accepting another ending command. Tests inject first/second prepare/write, checkpoint prepare/commit, and first/second publication failures and prove exactly-once forward recovery.

- [ ] Replace the provisional aggregate `dating` validation/default with the exact DatingEndingRules-owned counter/outcome/receipt schema and validate `lifecycle.ending_plan` through `validate_ending_plan()`. Keep unshipped schema v2, update migrations to canonical defaults, and round-trip every primary, optional epilogue, playback stage, Hospital-derived counter, and rejected malformed nested field through SaveManager restore.

- [ ] **Step 6.4: Test all endings and resume points**

- [ ] Generate one table-driven case for each of the eleven primaries, then cases with/without epilogue. For each playback stage, serialize/restore and assert only the remaining actions occur.
- [ ] Assert final gallery unlocks are two independent canonical IDs when epilogue exists, lifecycle is COMPLETED, day remains 7, and the final route is menu.

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'day7_endings' -LogName 'phase2r-day7-endings.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dating_ending_rules.gd,res://tests/scenario/test_day7_endings.gd','-gexit')
~~~

Expected GREEN: all primary/epilogue combinations and every resume point pass with no Day 8.

- [ ] **Step 6.5: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 6 Step 6.5 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'refactor(flow): resume Hospital and dating from stage receipts')) {
	throw 'Task 6 requires the exact Task 5 commit boundary as HEAD.'
}
$required = [ordered]@{
	'scripts/domain/ending/DatingEndingRules.gd' = 'M'
	'scripts/application/ending/EndingPlaybackPort.gd' = 'A'
	'tests/unit/test_dating_ending_rules.gd' = 'A'
	'tests/scenario/test_day7_endings.gd' = 'A'
	'autoload/GameState.gd' = 'M'
	'scripts/ui/EndingScene.gd' = 'M'
	'scripts/ui/GalleryScene.gd' = 'M'
	'tests/unit/test_game_state.gd' = 'M'
	'scripts/domain/run/RunSnapshotSchema.gd' = 'M'
	'scripts/infrastructure/save/SaveMigrations.gd' = 'M'
	'tests/unit/test_run_snapshot_schema.gd' = 'M'
	'tests/unit/test_save_migrations.gd' = 'M'
	'tests/integration/test_restore_transaction.gd' = 'M'
}
$optionalUids = [ordered]@{
	'scripts/application/ending/EndingPlaybackPort.gd.uid' = 'A'
	'tests/unit/test_dating_ending_rules.gd.uid' = 'A'
	'tests/scenario/test_day7_endings.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'feat(endings): play canonical primary and optional group epilogue'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 6 commit boundary failed.' }
~~~

## Task 7: Run the invitations/flow subsystem gate

**Files:**

- Generate: `evidence/phase_2r/logs/isolated-godot.jsonl`
- Generate: `.godot/phase2r_logs/phase2r-invitations-flow-gate.log`
- Consume without modification: scripts/application/transaction/FatalDiagnosticProjector.gd
- Re-run without modification: tests/unit/test_fatal_diagnostic_projector.gd
- Modify through `bd update` only: `.beads/issues.jsonl`

**Interfaces:**

- Consumes: Tasks 1–6 and lifecycle/save regression suites.
- Produces: requirement-linked test/evidence records for `dwm-p2r.6` and `dwm-p2r.7`, including aggregate schema/migration/restore coverage for the canonical contact, schedule, dating, and ending models; no runtime API.

- [ ] **Step 7.1: Run the invitations/flow gate**

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'invitations_flow_gate' -LogName 'phase2r-invitations-flow-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_contact_invitation_state.gd,res://tests/unit/test_schedule_rules.gd,res://tests/unit/test_schedule_rules_phase2r.gd,res://tests/unit/test_dating_ending_rules.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/scenario/test_invitation_branches.gd,res://tests/scenario/test_hospital_twofriends_order.gd,res://tests/scenario/test_day7_endings.gd,res://tests/integration/test_route_receipts.gd,res://tests/integration/test_restore_transaction.gd','-gexit')
~~~

- [ ] **Step 7.2: Re-run lifecycle and restore regressions**

- [ ] Re-run the lifecycle and restore transaction tests because these tasks changed GameState and routes.

- [ ] **Step 7.3: Record evidence and release the dependency**

- [ ] Append logs and exact branch coverage to `.7` with `bd update`; close only with all acceptance criteria GREEN.
- [ ] Confirm `.8` becomes ready.
