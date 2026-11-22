class_name ScheduleRegistryFixtures
extends RefCounted

const ORDINARY_DAYS: Array[int] = [1, 2, 3, 4, 5, 6]
const GROUP_PAIR: Array[String] = ["priscilla", "lavinia"]

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
