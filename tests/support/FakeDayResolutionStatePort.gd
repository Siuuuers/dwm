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

func _init(calls: Array[String]) -> void:
	_calls = calls

func seed_playing_day(run_id: String, day: int, _schedule: Array) -> void:
	_run_id = run_id
	_source_day = day
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

func set_failure(phase: StringName) -> void:
	_failure = phase

func set_registered_stage(stage_id: String) -> void:
	_registered_stage = stage_id

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
	var begun: Dictionary = _lifecycle.begin_day_resolution(command_id, [])
	if not begun.get("ok", false):
		return begun
	return {"ok": true, "code": &"ok", "value": {"run_id": _run_id}}

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
			"command": {
				"transaction_id": str(stage["transaction_id"]),
				"stage_id": stage_id,
				"owner_id": str(_immediate_receipt(stage_id)["owner_id"]),
				"kind": str(_immediate_receipt(stage_id)["kind"]),
			},
		}}
	return {"ok": true, "code": &"ok", "value": {
		"mode": &"complete_immediately",
		"stage": stage.duplicate(true),
		"receipt": _immediate_receipt(stage_id),
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
				duplicate = true
				record = {"receipt": stage["receipt"]}
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

func _immediate_receipt(stage_id: String) -> Dictionary:
	var day := _source_day
	match stage_id:
		"lock_day":
			return _envelope("day_resolution_coordinator", "day_lock", {"locked": true})
		"validate_schedule":
			return _envelope("schedule_rules", "schedule_validation",
				{"schedule_digest": "digest-day-%d" % day, "ordered_entry_ids": []})
		"execute_schedule_entries":
			return _envelope("schedule_rules", "schedule_entries_complete", {"entry_receipt_ids": []})
		"commit_outcomes":
			return _envelope("game_state", "outcomes_commit", {"outcome_ids": [], "effect_transaction_ids": []})
		"hospital_if_triggered":
			return _envelope("dating_ending_rules", "hospital_resolution",
				{"required": false, "route_receipt_id": null, "prevented_entry_id": null})
		"twofriends_if_deferred":
			return _envelope("contact_invitation_state", "twofriends_resolution",
				{"required": false, "route_receipt_id": null, "message_transaction_ids": []})
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
