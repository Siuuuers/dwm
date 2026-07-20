class_name DayResolutionPlan
extends RefCounted

## Persisted, idempotent day-resolution stage plan
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 2).

const DAY_1_6_STAGES: Array[String] = [
	"lock_day", "validate_schedule", "execute_schedule_entries", "commit_outcomes",
	"hospital_if_triggered", "twofriends_if_deferred", "invitation_rollover",
	"increment_day", "reset_day_scope", "new_day_autosave", "unlock_day",
]
const DAY_7_STAGES: Array[String] = [
	"lock_day", "validate_schedule", "execute_schedule_entries", "commit_outcomes",
	"hospital_if_triggered", "close_invitations_run_end", "resolve_ending_plan",
	"enter_ending", "ending_autosave",
]
const STAGE_STATES: Array[String] = ["pending", "active", "completed"]
const STAGE_KEYS: Array[String] = ["stage_id", "transaction_id", "route_id", "state", "receipt", "substages"]
const SUBSTAGE_KEYS: Array[String] = ["substage_id", "transaction_id", "state", "receipt"]

var _resolution_id := ""
var _source_day := 0
var _stages: Array[Dictionary] = []

static func stage_allowlist(source_day: int) -> Array[String]:
	return DAY_7_STAGES.duplicate() if source_day == 7 else DAY_1_6_STAGES.duplicate()

static func create(resolution_id: String, source_day: int, schedule_entries: Array) -> Dictionary:
	if resolution_id.is_empty():
		return _fail(&"invalid_resolution_id", "resolution_id must be nonempty")
	if source_day < 1 or source_day > 7:
		return _fail(&"invalid_source_day", "source_day must be 1..7: %d" % source_day)
	var seen_slots := {}
	var detached: Array[Dictionary] = []
	for entry_value: Variant in schedule_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			return _fail(&"invalid_schedule_entry", "schedule entries must be objects")
		var entry := entry_value as Dictionary
		var entry_id := str(entry.get("entry_id", ""))
		if entry_id.is_empty():
			return _fail(&"invalid_schedule_entry", "entry_id must be nonempty")
		if typeof(entry.get("slot_index")) != TYPE_INT:
			return _fail(&"invalid_schedule_entry", "slot_index must be an integer: " + entry_id)
		var slot_index := int(entry["slot_index"])
		if seen_slots.has(slot_index):
			return _fail(&"invalid_schedule_entry", "duplicate slot_index: %d" % slot_index)
		seen_slots[slot_index] = true
		detached.append({"entry_id": entry_id, "slot_index": slot_index})
	detached.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["slot_index"]) < int(b["slot_index"]))
	var stages: Array = []
	for stage_id: String in stage_allowlist(source_day):
		var substages: Array = []
		if stage_id == "execute_schedule_entries":
			for entry: Dictionary in detached:
				var substage_id := "schedule:%d:%d:%s" % [source_day, int(entry["slot_index"]), str(entry["entry_id"])]
				substages.append({
					"substage_id": substage_id,
					"transaction_id": resolution_id + ":" + substage_id,
					"state": "pending",
					"receipt": null,
				})
		stages.append({
			"stage_id": stage_id,
			"transaction_id": resolution_id + ":" + stage_id,
			"route_id": null,
			"state": "pending",
			"receipt": null,
			"substages": substages,
		})
	return from_dict({"resolution_id": resolution_id, "source_day": source_day, "stages": stages})

static func from_dict(data: Dictionary) -> Dictionary:
	var keys := data.keys()
	keys.sort()
	if keys != ["resolution_id", "source_day", "stages"]:
		return _fail(&"invalid_plan_shape", "unexpected top-level keys: " + str(keys))
	var resolution_id := str(data["resolution_id"])
	if resolution_id.is_empty():
		return _fail(&"invalid_resolution_id", "resolution_id must be nonempty")
	if typeof(data["source_day"]) != TYPE_INT:
		return _fail(&"invalid_source_day", "source_day must be an integer")
	var source_day := int(data["source_day"])
	if source_day < 1 or source_day > 7:
		return _fail(&"invalid_source_day", "source_day must be 1..7: %d" % source_day)
	if typeof(data["stages"]) != TYPE_ARRAY:
		return _fail(&"invalid_plan_shape", "stages must be an array")
	var expected := stage_allowlist(source_day)
	var raw_stages: Array = data["stages"]
	if raw_stages.size() != expected.size():
		return _fail(&"invalid_stage_order", "expected %d stages" % expected.size())
	var stages: Array[Dictionary] = []
	var phase := "completed"
	var active_count := 0
	for index: int in range(raw_stages.size()):
		if typeof(raw_stages[index]) != TYPE_DICTIONARY:
			return _fail(&"invalid_stage_shape", "stage %d is not an object" % index)
		var stage := (raw_stages[index] as Dictionary).duplicate(true)
		var stage_keys := stage.keys()
		stage_keys.sort()
		var expected_stage_keys := STAGE_KEYS.duplicate()
		expected_stage_keys.sort()
		if stage_keys != expected_stage_keys:
			return _fail(&"invalid_stage_shape", "unexpected stage keys: " + str(stage_keys))
		var stage_id := str(stage["stage_id"])
		if stage_id != expected[index]:
			return _fail(&"invalid_stage_order", "stage %d must be %s, found %s" % [index, expected[index], stage_id])
		if str(stage["transaction_id"]) != resolution_id + ":" + stage_id:
			return _fail(&"invalid_transaction_id", stage_id)
		if stage["route_id"] != null and typeof(stage["route_id"]) != TYPE_STRING:
			return _fail(&"invalid_stage_shape", "route_id must be null or String: " + stage_id)
		var state := str(stage["state"])
		if state not in STAGE_STATES:
			return _fail(&"invalid_stage_state", stage_id + ": " + state)
		var receipt_error := _validate_receipt_field(stage["receipt"], state, stage_id)
		if receipt_error != "":
			return _fail(&"invalid_receipt", receipt_error)
		if typeof(stage["substages"]) != TYPE_ARRAY:
			return _fail(&"invalid_stage_shape", "substages must be an array: " + stage_id)
		if stage_id != "execute_schedule_entries" and not (stage["substages"] as Array).is_empty():
			return _fail(&"invalid_stage_shape", "only execute_schedule_entries may hold substages")
		var substage_phase := "completed"
		var previous_slot := -1
		for sub_index: int in range((stage["substages"] as Array).size()):
			if typeof(stage["substages"][sub_index]) != TYPE_DICTIONARY:
				return _fail(&"invalid_substage_shape", "substage %d is not an object" % sub_index)
			var substage := stage["substages"][sub_index] as Dictionary
			var substage_keys := substage.keys()
			substage_keys.sort()
			var expected_substage_keys := SUBSTAGE_KEYS.duplicate()
			expected_substage_keys.sort()
			if substage_keys != expected_substage_keys:
				return _fail(&"invalid_substage_shape", "unexpected substage keys: " + str(substage_keys))
			var substage_id := str(substage["substage_id"])
			var parts := substage_id.split(":")
			if parts.size() != 4 or parts[0] != "schedule" or str(int(parts[1])) != parts[1] \
					or int(parts[1]) != source_day or str(int(parts[2])) != parts[2] or parts[3].is_empty():
				return _fail(&"invalid_substage_shape", "malformed substage_id: " + substage_id)
			if int(parts[2]) <= previous_slot:
				return _fail(&"invalid_substage_shape", "substages must ascend by slot_index")
			previous_slot = int(parts[2])
			if str(substage["transaction_id"]) != resolution_id + ":" + substage_id:
				return _fail(&"invalid_transaction_id", substage_id)
			var substage_state := str(substage["state"])
			if substage_state not in STAGE_STATES:
				return _fail(&"invalid_stage_state", substage_id + ": " + substage_state)
			var substage_receipt_error := _validate_receipt_field(substage["receipt"], substage_state, substage_id)
			if substage_receipt_error != "":
				return _fail(&"invalid_receipt", substage_receipt_error)
			if substage_state == "active":
				active_count += 1
			var scan_error := _scan_order(substage_phase, substage_state, substage_id)
			if scan_error.begins_with("!"):
				return _fail(&"invalid_stage_order", scan_error.trim_prefix("!"))
			substage_phase = scan_error
		if state == "completed":
			for substage: Dictionary in stage["substages"]:
				if str(substage["state"]) != "completed":
					return _fail(&"invalid_stage_order", "completed stage with incomplete substage: " + stage_id)
		if state == "active":
			active_count += 1
		var stage_scan := _scan_order(phase, state, stage_id)
		if stage_scan.begins_with("!"):
			return _fail(&"invalid_stage_order", stage_scan.trim_prefix("!"))
		phase = stage_scan
		stages.append(stage)
	if active_count > 1:
		return _fail(&"invalid_stage_order", "more than one active record")
	var plan: RefCounted = (load("res://scripts/domain/run/DayResolutionPlan.gd") as GDScript).new()
	plan._resolution_id = resolution_id
	plan._source_day = source_day
	plan._stages = stages
	return {"ok": true, "code": &"ok", "value": {"plan": plan}}

func to_dict() -> Dictionary:
	return {
		"resolution_id": _resolution_id,
		"source_day": _source_day,
		"stages": _stages.duplicate(true),
	}

func get_next_incomplete_stage() -> Dictionary:
	for stage: Dictionary in _stages:
		if str(stage["state"]) == "completed":
			continue
		var pending_substage: Dictionary = {}
		for substage: Dictionary in stage["substages"]:
			if str(substage["state"]) == "active":
				return _cursor_value(_substage_record(stage, substage))
			if str(substage["state"]) == "pending" and pending_substage.is_empty():
				pending_substage = substage
		if not pending_substage.is_empty():
			return _cursor_value(_substage_record(stage, pending_substage))
		return _cursor_value(_stage_record(stage))
	return {"ok": true, "code": &"ok", "value": {"has_stage": false, "stage": null}}

func begin_stage(stage_id: String, transaction_id: String) -> Dictionary:
	var cursor := get_next_incomplete_stage()
	if not cursor["value"]["has_stage"]:
		return _fail(&"plan_complete", "no incomplete stage")
	var record: Dictionary = cursor["value"]["stage"]
	if record.has("substage_id") or str(record["stage_id"]) != stage_id:
		return _fail(&"stage_not_current", stage_id)
	var stage := _find_stage(stage_id)
	if str(stage["transaction_id"]) != transaction_id:
		return _fail(&"transaction_mismatch", stage_id)
	if str(stage["state"]) == "active":
		return {"ok": true, "code": &"ok", "value": {"stage": _stage_record(stage)}}
	stage["state"] = "active"
	return {"ok": true, "code": &"ok", "value": {"stage": _stage_record(stage)}}

func begin_substage(stage_id: String, substage_id: String, transaction_id: String) -> Dictionary:
	var cursor := get_next_incomplete_stage()
	if not cursor["value"]["has_stage"]:
		return _fail(&"plan_complete", "no incomplete stage")
	var record: Dictionary = cursor["value"]["stage"]
	if not record.has("substage_id") or str(record["stage_id"]) != stage_id \
			or str(record["substage_id"]) != substage_id:
		return _fail(&"stage_not_current", substage_id)
	var substage := _find_substage(stage_id, substage_id)
	if str(substage["transaction_id"]) != transaction_id:
		return _fail(&"transaction_mismatch", substage_id)
	if str(substage["state"]) == "active":
		return {"ok": true, "code": &"ok", "value": {"stage": _substage_record(_find_stage(stage_id), substage)}}
	substage["state"] = "active"
	return {"ok": true, "code": &"ok", "value": {"stage": _substage_record(_find_stage(stage_id), substage)}}

func complete_substage(stage_id: String, substage_id: String, transaction_id: String, receipt: Dictionary) -> Dictionary:
	var substage := _find_substage(stage_id, substage_id)
	if substage.is_empty():
		return _fail(&"unknown_stage", substage_id)
	return _complete_record(substage, transaction_id, receipt)

func complete_stage(stage_id: String, transaction_id: String, receipt: Dictionary) -> Dictionary:
	var stage := _find_stage(stage_id)
	if stage.is_empty():
		return _fail(&"unknown_stage", stage_id)
	if str(stage["state"]) != "completed":
		for substage: Dictionary in stage["substages"]:
			if str(substage["state"]) != "completed":
				return _fail(&"substages_incomplete", stage_id)
	return _complete_record(stage, transaction_id, receipt)

func is_complete() -> bool:
	for stage: Dictionary in _stages:
		if str(stage["state"]) != "completed":
			return false
	return true

func get_resolution_id() -> String:
	return _resolution_id

func get_source_day() -> int:
	return _source_day

func find_record_by_transaction(transaction_id: String) -> Dictionary:
	for stage: Dictionary in _stages:
		if str(stage["transaction_id"]) == transaction_id:
			return {"kind": "stage", "stage_id": str(stage["stage_id"]), "state": str(stage["state"])}
		for substage: Dictionary in stage["substages"]:
			if str(substage["transaction_id"]) == transaction_id:
				return {
					"kind": "substage",
					"stage_id": str(stage["stage_id"]),
					"substage_id": str(substage["substage_id"]),
					"state": str(substage["state"]),
				}
	return {}

func _complete_record(record: Dictionary, transaction_id: String, receipt: Dictionary) -> Dictionary:
	if str(record["transaction_id"]) != transaction_id:
		return _fail(&"transaction_mismatch", str(record["transaction_id"]))
	var normalized := _normalize_receipt(receipt)
	if normalized.is_empty():
		return _fail(&"invalid_receipt", "receipt must be {\"value\": Dictionary}")
	if str(record["state"]) == "completed":
		if record["receipt"] == normalized:
			return {"ok": true, "code": &"ok", "receipt": (record["receipt"] as Dictionary).duplicate(true)}
		return {"ok": false, "code": &"duplicate_transaction_conflict", "message": transaction_id}
	if str(record["state"]) != "active":
		return _fail(&"stage_not_active", transaction_id)
	record["state"] = "completed"
	record["receipt"] = normalized
	return {"ok": true, "code": &"ok", "receipt": normalized.duplicate(true)}

static func _normalize_receipt(receipt: Dictionary) -> Dictionary:
	var keys := receipt.keys()
	if keys != ["value"] or typeof(receipt["value"]) != TYPE_DICTIONARY:
		return {}
	return receipt.duplicate(true)

static func _validate_receipt_field(receipt: Variant, state: String, owner_id: String) -> String:
	if state == "completed":
		if typeof(receipt) != TYPE_DICTIONARY or _normalize_receipt(receipt).is_empty():
			return "completed record requires a receipt: " + owner_id
		return ""
	if receipt != null:
		return "pending/active record must hold a null receipt: " + owner_id
	return ""

static func _scan_order(phase: String, state: String, owner_id: String) -> String:
	match phase:
		"completed":
			if state == "completed":
				return "completed"
			if state == "active":
				return "active"
			return "pending"
		"active":
			if state == "pending":
				return "pending"
			return "!active record followed by " + state + ": " + owner_id
		"pending":
			if state == "pending":
				return "pending"
			return "!" + state + " record after pending: " + owner_id
	return "!unknown phase"

func _find_stage(stage_id: String) -> Dictionary:
	for stage: Dictionary in _stages:
		if str(stage["stage_id"]) == stage_id:
			return stage
	return {}

func _find_substage(stage_id: String, substage_id: String) -> Dictionary:
	var stage := _find_stage(stage_id)
	if stage.is_empty():
		return {}
	for substage: Dictionary in stage["substages"]:
		if str(substage["substage_id"]) == substage_id:
			return substage
	return {}

func _stage_record(stage: Dictionary) -> Dictionary:
	return {
		"stage_id": str(stage["stage_id"]),
		"transaction_id": str(stage["transaction_id"]),
		"state": str(stage["state"]),
	}

func _substage_record(stage: Dictionary, substage: Dictionary) -> Dictionary:
	return {
		"stage_id": str(stage["stage_id"]),
		"substage_id": str(substage["substage_id"]),
		"transaction_id": str(substage["transaction_id"]),
		"state": str(substage["state"]),
	}

func _cursor_value(record: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"has_stage": true, "stage": record}}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
