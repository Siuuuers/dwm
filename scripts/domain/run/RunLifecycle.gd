class_name RunLifecycle
extends RefCounted

## Pure run lifecycle state machine behind the GameState facade
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 2).

const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")

const PLAYING := &"PLAYING"
const ENDING := &"ENDING"
const COMPLETED := &"COMPLETED"

const STATE_NAMES: Array[String] = ["PLAYING", "ENDING", "COMPLETED"]
const LIFECYCLE_KEYS: Array[String] = ["run_id", "day", "state", "active_resolution_plan", "ending_plan"]
const PLAYBACK_SEQUENCE: Array[String] = ["PRIMARY_PENDING", "PRIMARY_PLAYED", "EPILOGUE_PLAYED", "GALLERY_RECORDED"]
const ENDING_PLAN_KEYS: Array[String] = ["ending_id", "epilogue_ending_id", "source_day", "playback_stage", "playback_receipts"]

var _run_id := ""
var _day := 1
var _state: StringName = PLAYING
var _plan: RefCounted = null
var _ending_plan: Dictionary = {}
var _has_ending_plan := false

func reset(run_id: String) -> void:
	_run_id = run_id
	_day = 1
	_state = PLAYING
	_plan = null
	_ending_plan = {}
	_has_ending_plan = false

func get_day() -> int:
	return _day

func get_state() -> StringName:
	return _state

func begin_day_resolution(resolution_id: String, schedule_entries: Array) -> Dictionary:
	if _state != PLAYING:
		return _fail(&"invalid_state", "begin_day_resolution requires PLAYING")
	if _has_ending_plan:
		return _fail(&"invalid_state", "begin_day_resolution requires no ending plan")
	if _plan != null:
		if _plan.get_resolution_id() == resolution_id:
			return {"ok": true, "code": &"ok", "value": {"plan": _plan.to_dict()}}
		return {"ok": false, "code": &"resolution_conflict", "message": _plan.get_resolution_id()}
	var created: Dictionary = DAY_RESOLUTION_PLAN.create(resolution_id, _day, schedule_entries.duplicate(true))
	if not created.get("ok", false):
		return created
	_plan = created["value"]["plan"]
	return {"ok": true, "code": &"ok", "value": {"plan": _plan.to_dict()}}

func resume_resolution() -> Dictionary:
	if _state == COMPLETED:
		return _fail(&"invalid_state", "resume_resolution is unavailable after COMPLETED")
	if _plan == null:
		return _fail(&"no_active_plan", "resume_resolution requires an active plan")
	var cursor: Dictionary = _plan.get_next_incomplete_stage()
	return cursor

func begin_next_stage() -> Dictionary:
	var cursor := resume_resolution()
	if not cursor.get("ok", false):
		return cursor
	if not cursor["value"]["has_stage"]:
		return _fail(&"plan_complete", "no incomplete stage")
	var record: Dictionary = cursor["value"]["stage"]
	var begun: Dictionary
	if record.has("substage_id"):
		begun = _plan.begin_substage(str(record["stage_id"]), str(record["substage_id"]), str(record["transaction_id"]))
	else:
		begun = _plan.begin_stage(str(record["stage_id"]), str(record["transaction_id"]))
	return begun

func complete_active_stage(transaction_id: String, receipt: Dictionary) -> Dictionary:
	if _state == COMPLETED:
		return _fail(&"invalid_state", "complete_active_stage is unavailable after COMPLETED")
	if _plan == null:
		return _fail(&"no_active_plan", "complete_active_stage requires an active plan")
	var record: Dictionary = _plan.find_record_by_transaction(transaction_id)
	if record.is_empty():
		return _fail(&"unknown_transaction", transaction_id)
	var fresh_completion: bool = str(record["state"]) == "active"
	if fresh_completion and record["kind"] == "stage":
		var validation := _validate_owner_receipt(str(record["stage_id"]), receipt)
		if not validation.get("ok", false):
			return validation
	var completed: Dictionary
	if record["kind"] == "substage":
		completed = _plan.complete_substage(str(record["stage_id"]), str(record["substage_id"]), transaction_id, receipt)
	else:
		completed = _plan.complete_stage(str(record["stage_id"]), transaction_id, receipt)
	if not completed.get("ok", false) or not fresh_completion or record["kind"] != "stage":
		return completed
	match str(record["stage_id"]):
		"increment_day":
			_day += 1
		"enter_ending":
			_state = ENDING
			_ending_plan = (receipt["value"]["ending_plan"] as Dictionary).duplicate(true)
			_has_ending_plan = true
	return completed

func enter_ending(ending_plan: Dictionary) -> Dictionary:
	if _state != PLAYING:
		return _fail(&"invalid_state", "enter_ending requires PLAYING")
	if _day != 7:
		return _fail(&"invalid_state", "enter_ending requires Day 7")
	var error := _validate_ending_plan(ending_plan)
	if error != "":
		return _fail(&"invalid_ending_plan", error)
	_state = ENDING
	_ending_plan = ending_plan.duplicate(true)
	_has_ending_plan = true
	return {"ok": true, "code": &"ok"}

func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
	if _state != ENDING:
		return _fail(&"invalid_state", "playback requires ENDING")
	var expected := String(expected_stage)
	if expected not in PLAYBACK_SEQUENCE:
		return _fail(&"invalid_playback_stage", expected)
	if str(_ending_plan["playback_stage"]) != expected:
		return _fail(&"playback_stage_mismatch", "expected %s, current %s" % [expected, str(_ending_plan["playback_stage"])])
	if expected == "GALLERY_RECORDED":
		return _fail(&"invalid_playback_stage", "no edge beyond GALLERY_RECORDED")
	if transaction_id != "ending:" + expected:
		return _fail(&"transaction_mismatch", transaction_id)
	var receipt_keys := receipt.keys()
	if receipt_keys != ["value"] or typeof(receipt["value"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_receipt", "receipt must be {\"value\": Dictionary}")
	var next := PLAYBACK_SEQUENCE[PLAYBACK_SEQUENCE.find(expected) + 1]
	_ending_plan["playback_stage"] = next
	(_ending_plan["playback_receipts"] as Dictionary)[expected] = receipt.duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"playback_stage": next}}

func complete_ending() -> Dictionary:
	if _state != ENDING:
		return _fail(&"invalid_state", "complete_ending requires ENDING")
	if str(_ending_plan["playback_stage"]) != "GALLERY_RECORDED":
		return _fail(&"playback_incomplete", "complete_ending requires GALLERY_RECORDED")
	_state = COMPLETED
	return {"ok": true, "code": &"ok"}

func to_dict() -> Dictionary:
	return {
		"run_id": _run_id,
		"day": _day,
		"state": String(_state),
		"active_resolution_plan": _plan.to_dict() if _plan != null else null,
		"ending_plan": _ending_plan.duplicate(true) if _has_ending_plan else null,
	}

func prepare_restore(data: Dictionary) -> Dictionary:
	var error := _validate_lifecycle_dict(data)
	if error != "":
		return _fail(&"invalid_lifecycle", error)
	return {"ok": true, "code": &"ok", "value": {"candidate": data.duplicate(true)}}

func commit_restore(candidate: Dictionary) -> Dictionary:
	var error := _validate_lifecycle_dict(candidate)
	if error != "":
		return _fail(&"invalid_candidate", error)
	var plan: RefCounted = null
	if candidate["active_resolution_plan"] != null:
		var restored: Dictionary = DAY_RESOLUTION_PLAN.from_dict(candidate["active_resolution_plan"])
		if not restored.get("ok", false):
			return restored
		plan = restored["value"]["plan"]
	_run_id = str(candidate["run_id"])
	_day = int(candidate["day"])
	_state = StringName(str(candidate["state"]))
	_plan = plan
	_has_ending_plan = candidate["ending_plan"] != null
	_ending_plan = (candidate["ending_plan"] as Dictionary).duplicate(true) if _has_ending_plan else {}
	return {"ok": true, "code": &"ok"}

func _validate_lifecycle_dict(data: Dictionary) -> String:
	var keys := data.keys()
	keys.sort()
	var expected := LIFECYCLE_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "unexpected lifecycle keys: " + str(keys)
	if str(data["run_id"]).is_empty():
		return "run_id must be nonempty"
	if typeof(data["day"]) != TYPE_INT or int(data["day"]) < 1 or int(data["day"]) > 7:
		return "day must be an integer 1..7: " + str(data["day"])
	var state := str(data["state"])
	if state not in STATE_NAMES:
		return "unknown state: " + state
	if data["active_resolution_plan"] != null:
		if typeof(data["active_resolution_plan"]) != TYPE_DICTIONARY:
			return "active_resolution_plan must be null or an object"
		var restored: Dictionary = DAY_RESOLUTION_PLAN.from_dict(data["active_resolution_plan"])
		if not restored.get("ok", false):
			return "invalid active_resolution_plan: " + str(restored.get("message", restored.get("code", "")))
		if (restored["value"]["plan"] as RefCounted).get_source_day() != int(data["day"]):
			return "active_resolution_plan source_day must match day"
	if data["ending_plan"] == null:
		if state != "PLAYING":
			return state + " requires an ending plan"
	else:
		if typeof(data["ending_plan"]) != TYPE_DICTIONARY:
			return "ending_plan must be null or an object"
		var ending_error := _validate_ending_plan(data["ending_plan"])
		if ending_error != "":
			return ending_error
		if state == "PLAYING":
			return "PLAYING requires a null ending plan"
		if int(data["day"]) != 7:
			return "an ending plan requires day 7"
		if state == "COMPLETED" and str((data["ending_plan"] as Dictionary)["playback_stage"]) != "GALLERY_RECORDED":
			return "COMPLETED requires GALLERY_RECORDED playback"
	return ""

static func _validate_ending_plan(plan: Dictionary) -> String:
	var keys := plan.keys()
	keys.sort()
	var expected := ENDING_PLAN_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "unexpected ending-plan keys: " + str(keys)
	if str(plan["ending_id"]).is_empty():
		return "ending_id must be nonempty"
	if typeof(plan["epilogue_ending_id"]) != TYPE_STRING:
		return "epilogue_ending_id must be a String"
	if typeof(plan["source_day"]) != TYPE_INT or int(plan["source_day"]) != 7:
		return "ending-plan source_day must be 7"
	if str(plan["playback_stage"]) not in PLAYBACK_SEQUENCE:
		return "unknown playback_stage: " + str(plan["playback_stage"])
	if typeof(plan["playback_receipts"]) != TYPE_DICTIONARY:
		return "playback_receipts must be a Dictionary"
	return ""

func _validate_owner_receipt(stage_id: String, receipt: Dictionary) -> Dictionary:
	var receipt_keys := receipt.keys()
	if receipt_keys != ["value"] or typeof(receipt["value"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_receipt", "receipt must be {\"value\": Dictionary}")
	var value: Dictionary = receipt["value"]
	match stage_id:
		"invitation_rollover":
			if typeof(value.get("target_day")) != TYPE_INT or int(value["target_day"]) != _day + 1:
				return _fail(&"invalid_receipt", "rollover target_day must equal source_day + 1")
		"increment_day":
			if _day < 1 or _day > 6:
				return _fail(&"invalid_receipt", "increment_day permitted only from days 1..6")
			if typeof(value.get("day")) != TYPE_INT or int(value["day"]) != _day + 1:
				return _fail(&"invalid_receipt", "increment_day receipt must carry day = source + 1")
		"resolve_ending_plan", "enter_ending":
			if typeof(value.get("ending_plan")) != TYPE_DICTIONARY:
				return _fail(&"invalid_receipt", stage_id + " receipt requires an ending_plan")
			var error := _validate_ending_plan(value["ending_plan"])
			if error != "":
				return _fail(&"invalid_ending_plan", error)
	return {"ok": true, "code": &"ok"}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
