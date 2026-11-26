extends RefCounted


const FIRST_DAY := 1
const LAST_DAY := 7


static func make_empty(day: int, causal_day_instance: String) -> Dictionary:
	if day < FIRST_DAY or day > LAST_DAY:
		return _fail(&"invalid_day", "day must be an int in %d..%d" % [FIRST_DAY, LAST_DAY],
			{"day": day})
	if causal_day_instance.is_empty():
		return _fail(&"invalid_causal_day_instance",
			"a nonempty causal day instance is required", {})
	return {"ok": true, "code": &"ok", "receipt": {}, "value": {"view": {
		"day": day,
		"causal_day_instance": causal_day_instance,
		"entries": [],
		"date_entry_seen": false,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": {},
	}}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
