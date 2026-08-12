class_name ScheduleRegistryFixtures
extends RefCounted

## Injected Schedule action registry for Schedule tests.
##
## ScheduleRules is pure: it never reads DataCatalog, GameState, Contacts, scenes, or files. It
## receives a registry OBJECT and asks it exactly two questions:
##
##     func fingerprint() -> String
##     func find_record(action_id: String) -> Dictionary   # CommandResult, value={record}, no receipt
##
## Task 2 (dwm-wks) made this fixture registry-BACKED: it no longer computes anything itself but
## builds a real ScheduleActionRegistry through the production from_manifest() path, so the same
## schema, the same semantic laws, the same canonicalization and the same SHA-256 run here as in
## production. A fixture cannot claim a record is trusted; it has to earn it.
##
## The PUBLIC surface below is pinned by tests Task 2 may not edit (test_schedule_strict_validation
## constructs both `.new()` and `.new(stale_records())` and reads `fingerprint()` as a bare String).
## Change it only with those suites in scope.

const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

const ORDINARY_DAYS: Array[int] = [1, 2, 3, 4, 5, 6]
const GROUP_PAIR: Array[String] = ["priscilla", "lavinia"]

var _registry: RefCounted = null
var _fingerprint: String = ""


func _init(records: Array = []) -> void:
	var source: Array = records if not records.is_empty() else default_records()
	var built: Dictionary = REGISTRY.from_manifest({
		"schema_version": 1,
		"kind": "schedule_actions",
		"registry_version": 1,
		"records": source,
	})
	if not built.get("ok", false):
		return
	var value: Dictionary = built["value"]
	_registry = value["registry"]
	_fingerprint = str(value["registry_fingerprint"])


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


# ---- the surface ScheduleRules consumes ----

func fingerprint() -> String:
	return _fingerprint


func find_record(action_id: String) -> Dictionary:
	if _registry == null:
		return {"ok": false, "code": &"invalid_registry",
			"message": "the fixture manifest failed the production registry validation",
			"details": {"action_id": action_id}}
	return _registry.find_record(action_id)


## Records whose canonical bytes differ, for stale-fingerprint rejection tests. Returned as records
## rather than an instance so this file never depends on its own global class-name registration,
## which is not yet present in a freshly created worktree. The substituted effect id is deliberately
## outside the effects.json vocabulary: that vocabulary is checked by the TOOLING validator, never
## by the registry load path, so these records still build a valid registry with a different digest.
static func stale_records() -> Array:
	var records: Array = default_records()
	(records[0] as Dictionary)["effect_ids"] = ["pressure:+99"]
	return records
