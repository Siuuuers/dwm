class_name ScheduleRegistryFixtures
extends RefCounted

## Injected Schedule action registry for Plan-01 Task 1 (dwm-p2r.12).
##
## ScheduleRules is pure: it never reads DataCatalog, GameState, Contacts, scenes, or files. It
## receives a registry OBJECT and asks it exactly two questions, which is the whole surface Task 2
## (`dwm-wks`, ScheduleActionRegistry.gd) must later satisfy when it replaces this fixture:
##
##     func fingerprint() -> String
##     func find_record(action_id: String) -> Dictionary   # CommandResult, value={record}, no receipt
##
## The records below are the frozen v1 table from Plan 01. The fingerprint is genuinely computed
## from canonical JSON rather than asserted, so a tampered fixture cannot quietly claim authority.

const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const ORDINARY_DAYS: Array[int] = [1, 2, 3, 4, 5, 6]
const GROUP_PAIR: Array[String] = ["priscilla", "lavinia"]

var _records: Dictionary = {}
var _fingerprint: String = ""


func _init(records: Array = []) -> void:
	var source: Array = records if not records.is_empty() else default_records()
	for record: Dictionary in source:
		_records[str(record["action_id"])] = record.duplicate(true)
	_fingerprint = _compute_fingerprint(source)


## The exact 20-record v1 registry (Plan 01, "Versioned Schedule action registry").
static func default_records() -> Array:
	var records: Array = [
		_ordinary("training", [{"id": "pressure:+1"}, {"id": "health:+2"}]),
		_ordinary("working", [{"id": "pressure:+2"}, {"id": "health:-2"}, {"id": "money:+30"}]),
		_ordinary("rest", [{"id": "pressure:-2"}, {"id": "health:+1"}]),
	]
	# Days 1-6 dates route to `dating`; Day-7 solos carry no physical route.
	for spec: Array in [
		["priscilla", 1], ["priscilla", 2], ["priscilla", 4], ["priscilla", 6], ["priscilla", 7],
		["lavinia", 2], ["lavinia", 3], ["lavinia", 5], ["lavinia", 6], ["lavinia", 7],
		["sylvia", 1], ["sylvia", 3], ["sylvia", 4], ["sylvia", 5], ["sylvia", 7],
	]:
		records.append(_solo(str(spec[0]), int(spec[1])))
	records.append(_group(2))
	records.append(_group(6))
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["action_id"]) < str(right["action_id"]))
	return records


static func _ordinary(action_id: String, effects: Array) -> Dictionary:
	var effect_ids: Array[String] = []
	for effect: Dictionary in effects:
		effect_ids.append(str(effect["id"]))
	return {
		"action_id": action_id,
		"allowed_days": ORDINARY_DAYS.duplicate(),
		"action_kind": "ordinary",
		"participants": [],
		"repeatable": true,
		"motivation_cost": 1,
		"route_id": null,
		"effect_ids": effect_ids,
		"source_receipt_kind": null,
	}


static func _solo(friend_id: String, day: int) -> Dictionary:
	return {
		"action_id": "solo:%s:day%d" % [friend_id, day],
		"allowed_days": [day],
		"action_kind": "solo",
		"participants": [friend_id],
		"repeatable": false,
		"motivation_cost": 1,
		"route_id": null if day == 7 else "dating",
		"effect_ids": [],
		"source_receipt_kind": "solo_read_acceptance",
	}


static func _group(day: int) -> Dictionary:
	return {
		"action_id": "group:priscilla_lavinia:day%d" % day,
		"allowed_days": [day],
		"action_kind": "group",
		# Canonical order is Priscilla then Lavinia; a reversed pair is a tamper, not a synonym.
		"participants": GROUP_PAIR.duplicate(),
		"repeatable": false,
		"motivation_cost": 1,
		"route_id": "dating",
		"effect_ids": [],
		"source_receipt_kind": "group_reply_acceptance",
	}


static func _compute_fingerprint(records: Array) -> String:
	var manifest := {
		"schema_version": 1,
		"kind": "schedule_actions",
		"registry_version": 1,
		"records": records,
	}
	var canonical: Dictionary = CANONICAL_JSON.stringify(manifest)
	if not canonical.get("ok", false):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(str(canonical["value"]).to_utf8_buffer())
	return context.finish().hex_encode()


# ---- the surface ScheduleRules consumes ----

func fingerprint() -> String:
	return _fingerprint


func find_record(action_id: String) -> Dictionary:
	if not _records.has(action_id):
		return {"ok": false, "code": &"unregistered_action", "message": action_id,
			"details": {"action_id": action_id}}
	return {"ok": true, "code": &"ok", "value": {"record": _records[action_id].duplicate(true)},
		"receipt": {}}


## Records whose canonical bytes differ, for stale-fingerprint rejection tests. Returned as records
## rather than an instance so this file never depends on its own global class-name registration,
## which is not yet present in a freshly created worktree.
static func stale_records() -> Array:
	var records: Array = default_records()
	(records[0] as Dictionary)["effect_ids"] = ["pressure:+99"]
	return records
