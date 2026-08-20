class_name FakeDayResolutionStatePort
extends RefCounted

## State-port double backed by the real RunLifecycle for coordinator tests
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).

const LIFECYCLE_SCRIPT := preload("res://scripts/domain/run/RunLifecycle.gd")
const RECEIPTS := preload("res://tests/support/DayResolutionReceiptFixtures.gd")

var _calls: Array[String]
var _lifecycle: RefCounted = null
var _run_id := ""
var _source_day := 1
var _publications := 0
var _failure: StringName = &""
var _registered_stage := ""
## Committed entries the seeded plan is built from; `[]` means a plan with no substages at all.
var _entries: Array = []

func _init(calls: Array[String]) -> void:
	_calls = calls

## `entries` was declared and ignored from the start, so every plan this fake built had NO
## substages and the coordinator's substage branches were unreachable from this suite (dwm-p2r.20).
## Honouring it is backward compatible: both pre-existing call sites pass `[]`, which still yields
## the byte-identical `{"entries": []}` aggregate.
##
## The domain boundary is what it accepts, not the port boundary: `DayResolutionPlan.create` reads
## exactly `schedule_entry_id`, `slot_index` and `action_kind` off each entry and discards the rest,
## so a three-key entry is the honest minimum here rather than an under-built `ScheduleStateSchema`
## aggregate pretending to be one.
func seed_playing_day(run_id: String, day: int, entries: Array) -> void:
	_run_id = run_id
	_source_day = day
	_entries = entries.duplicate(true)
	_lifecycle = LIFECYCLE_SCRIPT.new()
	_lifecycle.reset(run_id)
	var restored: Dictionary = _lifecycle.prepare_restore({
		"run_id": run_id,
		"day": day,
		"state": "PLAYING",
		"active_resolution_plan": null,
		"ending_plan": null,
	})
	assert(restored["ok"])
	assert(_lifecycle.commit_restore(restored["value"]["candidate"])["ok"])

## Nonempty only while the registered stage is a presentation site.
var _registered_completion_transaction_id := ""
## Models a producer that emits a presentation command carrying NO transaction id.
## The coordinator must refuse it rather than let it collide with any sentinel.
var _blank_transaction_id := false


func set_failure(phase: StringName) -> void:
	_failure = phase

func set_registered_stage(stage_id: String) -> void:
	_registered_stage = stage_id


## Makes the registered stage await a PRESENTATION rather than a bare route command, so the
## coordinator's `complete_presentation_stage()` has a request to settle against. Without this the
## awaiting command carries no `completion_transaction_id` and the coordinator's
## "does this receipt settle THIS command" check would pass vacuously on two empty strings.
func set_registered_presentation(completion_transaction_id: String) -> void:
	_registered_completion_transaction_id = completion_transaction_id


func set_blank_transaction_id(blank: bool) -> void:
	_blank_transaction_id = blank

func get_publication_count() -> int:
	return _publications

func peek_state() -> Dictionary:
	# Committed observable state only: the in-flight resolution plan is durable
	# resumable progress (receipts), never rolled back by recoverable failures.
	if _lifecycle == null:
		return {"lifecycle": {}, "publications": _publications}
	var snapshot: Dictionary = _lifecycle.to_dict()
	return {
		"lifecycle": {
			"run_id": str(snapshot["run_id"]),
			"day": int(snapshot["day"]),
			"state": str(snapshot["state"]),
			"has_ending_plan": snapshot["ending_plan"] != null,
		},
		"publications": _publications,
	}

func begin_or_resume(command_id: String) -> Dictionary:
	_calls.append("state.begin_or_resume")
	if command_id.is_empty():
		return {"ok": false, "code": &"invalid_command_id", "message": "", "details": {}}
	if _failure == &"begin_or_resume":
		return {"ok": false, "code": &"begin_failed", "message": "forced", "details": {}}
	# Step 6.6 (dwm-p2r.13): the fake models the same transport as production -- a committed
	# Schedule aggregate, never a bare array -- so it cannot pass a shape production would refuse.
	var begun: Dictionary = _lifecycle.begin_day_resolution(command_id, {"entries": _entries.duplicate(true)})
	if not begun.get("ok", false):
		return begun
	return {"ok": true, "code": &"ok", "value": {"run_id": _run_id}}

## The awaiting command, with the presentation request attached when one is registered -- the same
## two shapes the production port returns.
## A SUBSTAGE answers to `SUBSTAGE_CONTRACTS` by its own receipt kind, never to the parent stage's
## aggregate envelope -- the Task-7 split the production port made.
##
## Honesty, not correctness: nothing in the coordinator or any test reads `owner_id`/`kind` back off
## a registered command, so this changes no outcome. It is here so the fake does not document a
## conflation production removed.
func _registered_command(stage: Dictionary, stage_id: String) -> Dictionary:
	var envelope: Dictionary = _substage_receipt(stage) if stage.has("substage_id") \
		else _immediate_receipt(stage_id)
	var command: Dictionary = {
		"transaction_id": "" if _blank_transaction_id else str(stage["transaction_id"]),
		"stage_id": stage_id,
		"owner_id": str(envelope["owner_id"]),
		"kind": str(envelope["kind"]),
	}
	if not _registered_completion_transaction_id.is_empty():
		command["route_id"] = "hospital"
		command["presentation_request"] = {
			"completion_transaction_id": _registered_completion_transaction_id,
			"route_id": "hospital",
		}
	return command


func inspect_next_stage() -> Dictionary:
	var cursor: Dictionary = _lifecycle.resume_resolution()
	return cursor

func begin_next_stage() -> Dictionary:
	_calls.append("state.begin_next_stage")
	var begun: Dictionary = _lifecycle.begin_next_stage()
	if not begun.get("ok", false):
		return begun
	var stage: Dictionary = begun["value"]["stage"]
	var stage_id := str(stage["stage_id"])
	if stage_id == _registered_stage:
		return {"ok": true, "code": &"ok", "value": {
			"mode": &"await_registered_command",
			"stage": stage.duplicate(true),
			"command": _registered_command(stage, stage_id),
		}}
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _substage_receipt(stage) if stage.has("substage_id") \
			else _immediate_receipt(stage_id),
	}}

func prepare_completion(transaction_id: String, receipt: Dictionary) -> Dictionary:
	_calls.append("state.prepare_completion")
	if _failure == &"prepare_completion":
		return {"ok": false, "code": &"prepare_completion_failed", "message": "forced", "details": {}}
	var record: Dictionary = {}
	var duplicate := false
	var snapshot: Dictionary = _lifecycle.to_dict()
	if snapshot["active_resolution_plan"] != null:
		for stage: Dictionary in snapshot["active_resolution_plan"]["stages"]:
			if str(stage["transaction_id"]) == transaction_id and str(stage["state"]) == "completed":
				# Mirrors the production port (dwm-p2r.22 for substages, dwm-p2r.25 for stages):
				# byte-identical replays of a durable record are duplicates, DIFFERENT bytes
				# surface the domain's conflict at PREPARE time. Production reaches that conflict
				# through `_completed_lifecycle`; this fake's prepare never touches its lifecycle,
				# so the direct return is the faithful shape.
				if _plan_receipt_from_envelope(receipt) == stage["receipt"]:
					duplicate = true
					record = {"receipt": stage["receipt"]}
				else:
					return {"ok": false, "code": &"duplicate_transaction_conflict",
						"message": transaction_id}
			for substage: Dictionary in stage["substages"]:
				if str(substage["transaction_id"]) != transaction_id \
						or str(substage["state"]) != "completed":
					continue
				# The same law one level down.
				if _plan_receipt_from_envelope(receipt) == substage["receipt"]:
					duplicate = true
					record = {"receipt": substage["receipt"]}
				else:
					return {"ok": false, "code": &"duplicate_transaction_conflict",
						"message": transaction_id}
	return {"ok": true, "code": &"ok", "value": {
		"run_candidate": {"transaction_id": transaction_id, "receipt": receipt.duplicate(true)},
		"snapshot_input": {"run_id": _run_id, "day": int(snapshot["day"])},
		"stage": {"transaction_id": transaction_id},
		"publication": {"transaction_id": transaction_id, "signals": ["day_resolution_stage_completed"]},
		"duplicate": duplicate,
		"stored_receipt": record.get("receipt", null),
	}}

func capture() -> Dictionary:
	_calls.append("state.capture")
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"lifecycle": _lifecycle.to_dict(),
		"publications": _publications,
	}}}

func commit(candidate: Dictionary) -> Dictionary:
	_calls.append("state.commit")
	if _failure == &"commit":
		return {"ok": false, "code": &"state_commit_failed", "message": "forced", "details": {}}
	var envelope: Dictionary = candidate["receipt"]
	var completed: Dictionary = _lifecycle.complete_active_stage(
		str(candidate["transaction_id"]), _plan_receipt_from_envelope(envelope))
	return completed

func rollback(backup: Dictionary) -> Dictionary:
	_calls.append("state.rollback")
	if _failure == &"rollback":
		return {"ok": false, "code": &"state_rollback_failed", "message": "forced", "details": {}}
	var restored: Dictionary = _lifecycle.prepare_restore(backup["lifecycle"])
	if not restored.get("ok", false):
		return restored
	var committed: Dictionary = _lifecycle.commit_restore(restored["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	_publications = int(backup["publications"])
	return {"ok": true, "code": &"ok"}

func publish(_publication: Dictionary) -> Dictionary:
	_calls.append("state.publish")
	if _failure == &"publish":
		return {"ok": false, "code": &"publish_failed", "message": "forced", "details": {}}
	_publications += 1
	return {"ok": true, "code": &"ok"}

## Shape-valid stand-in for the real port's presentation envelope (dwm-p2r.18, dwm-p2r.24,
## dwm-p2r.26, dwm-p2r.27). A top-level stage gets the published completion folded onto the envelope this
## fake already produces for it. A SUBSTAGE is answered only for the surviving_date KIND --
## every other kind is refused with `invalid_presentation_substage`, mirroring the production
## kind gate -- and a date gets the `schedule_date_complete` shape with the entry id derived
## from its own substage id, NOT `_substage_receipt`'s per-stage envelope, which models the
## route door, a different seam. This fake models no Hospital, so production's superseded-date
## REFUSAL (dwm-p2r.27) is NOT represented here -- its hardcoded hospital receipt carries an
## empty supersession set, so the two ports agree on every input the coordinator suite can
## build. It anchors nothing and no test treats its ids as issuer-derived.
func presentation_stage_receipt(transaction_id: String, completion: Dictionary) -> Dictionary:
	_calls.append("state.presentation_stage_receipt")
	var plan: Variant = _lifecycle.to_dict().get("active_resolution_plan")
	if typeof(plan) == TYPE_DICTIONARY:
		for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
			var stage: Dictionary = stage_value
			if str(stage.get("transaction_id", "")) == transaction_id:
				var envelope := _immediate_receipt(str(stage["stage_id"]))
				(envelope["value"] as Dictionary)["presentation_completion_receipt"] = 				completion.duplicate(true)
				return {"ok": true, "code": &"ok", "value": {"receipt": envelope}}
			for substage_value: Variant in (stage.get("substages", []) as Array):
				var substage: Dictionary = substage_value
				if str(substage.get("transaction_id", "")) != transaction_id:
					continue
				var substage_id := str(substage["substage_id"])
				if not substage_id.begins_with("surviving_date:"):
					return {"ok": false, "code": &"invalid_presentation_substage",
						"message": substage_id, "details": {}}
				return {"ok": true, "code": &"ok", "value": {"receipt": _envelope(
					"schedule_rules", "schedule_date_complete", {
						"entry_receipt_id": substage_id.split(":")[3],
						"superseded": false,
						"reason": null,
						"presentation_completion_receipt": completion.duplicate(true),
					})}}
	return {"ok": false, "code": &"unknown_transaction", "message": transaction_id,
		"details": {}}


## The envelope a substage returns, keyed to `DayResolutionCoordinator`'s `SUBSTAGE_CONTRACTS`.
## Deliberately NOT the parent's aggregate shape.
##
## The entry id is derived from the substage id's fourth field, exactly as the production port does,
## rather than invented -- otherwise no test could tell an implementation that routed one entry's
## receipt to another entry's substage.
func _substage_receipt(stage: Dictionary) -> Dictionary:
	var entry_id := str(stage["substage_id"]).split(":")[3]
	match str(stage["stage_id"]):
		"execute_schedule_actions":
			return _envelope("schedule_rules", "schedule_entry_complete",
				{"entry_receipt_id": entry_id, "outcome_ids": []})
		"execute_schedule_dates":
			return _envelope("schedule_rules", "schedule_date_complete",
				{"entry_receipt_id": entry_id, "superseded": false, "reason": null,
					"presentation_completion_receipt": null})
	return _immediate_receipt(str(stage["stage_id"]))


func _immediate_receipt(stage_id: String) -> Dictionary:
	var day := _source_day
	match stage_id:
		"lock_day":
			return _envelope("day_resolution_coordinator", "day_lock", {"locked": true})
		"validate_schedule":
			return _envelope("schedule_rules", "schedule_validation",
				{"schedule_digest": "digest-day-%d" % day, "ordered_entry_ids": []})
		"execute_schedule_actions":
			return _envelope("schedule_rules", "schedule_actions_complete", {"entry_receipt_ids": []})
		"execute_schedule_dates":
			return _envelope("schedule_rules", "schedule_dates_complete",
				{"entry_receipt_ids": [], "superseded_entry_ids": []})
		"commit_outcomes":
			return _envelope("game_state", "outcomes_commit", {"outcome_ids": [], "effect_transaction_ids": []})
		"hospital_if_triggered":
			return _envelope("hospital_rules", "hospital_resolution",
				{"required": false, "date_schedule_entry_ids": [],
					"superseded_entry_ids": [], "witness_entry_id": null,
					"presentation_completion_receipt": null})
		"twofriends_if_deferred":
			return _envelope("contact_invitation_state", "twofriends_resolution",
				{"required": false, "route_receipt_id": null, "message_transaction_ids": [],
					"presentation_completion_receipt": null})
		"invitation_rollover":
			return _envelope("contact_invitation_state", "invitation_rollover",
				{"target_day": day + 1, "message_transaction_ids": []})
		"increment_day":
			return _envelope("run_lifecycle", "day_increment", {"source_day": day, "target_day": day + 1})
		"reset_day_scope":
			return _envelope("game_state", "day_scope_reset", {"target_day": day + 1, "reset_ids": []})
		"new_day_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "day_start"})
		"unlock_day":
			return _envelope("day_resolution_coordinator", "day_unlock", {"locked": false})
		"validate_day7_provenance":
			return _envelope("day7_schedule_provenance", "day7_provenance_validation",
				{"cause": "empty_done", "schedule_entry_id": null, "source_receipt_id": null})
		"checkpoint_day7_provenance":
			# Task 8 Step 8.7 (dwm-p2r.14): the checkpoint carries the derived
			# P01.schedule.day7_provenance child. This fake supplies a SHAPE-valid stand-in only --
			# it is not an anchored id, and no test here treats it as one. The real derivation is
			# proved against the real issuer in tests/scenario/test_day7_schedule_provenance.gd.
			return _envelope("day7_schedule_provenance", "day7_provenance_checkpoint", {
				"cause": "empty_done",
				"schedule_commit_receipt_id": null,
				"day7_provenance_receipt_id": "fake.day7_provenance",
				"day7_provenance_receipt_provenance": {},
			})
		"close_invitations_run_end":
			return _envelope("contact_invitation_state", "run_end_close", {"resolved_action_ids": []})
		"resolve_ending_plan":
			return _envelope("dating_ending_rules", "ending_resolution", {"ending_plan": RECEIPTS.ending_plan()})
		"enter_ending":
			return _envelope("run_lifecycle", "enter_ending",
				{"state": "ENDING", "primary_id": "ending.alone", "epilogue_id": null})
		"ending_autosave":
			return _envelope("save_manager", "disk_checkpoint_request",
				{"save_kind": "autosave", "save_reason": "ending"})
	return _envelope("unknown", "unknown", {})

static func _envelope(owner_id: String, kind: String, value: Dictionary) -> Dictionary:
	return {"owner_id": owner_id, "kind": kind, "value": value}

static func _plan_receipt_from_envelope(envelope: Dictionary) -> Dictionary:
	var value: Dictionary = envelope["value"]
	match str(envelope["kind"]):
		"day_increment":
			return {"value": {"day": int(value["target_day"])}}
		"enter_ending":
			var epilogue: Variant = value.get("epilogue_id")
			return {"value": {"ending_plan": {
				"ending_id": str(value["primary_id"]),
				"epilogue_ending_id": str(epilogue) if epilogue != null else "",
				"source_day": 7,
				"playback_stage": "PRIMARY_PENDING",
				"playback_receipts": {},
			}}}
	return {"value": value.duplicate(true)}
