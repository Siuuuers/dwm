extends RefCounted
## A read-only scene-boundary projection. Preferences for a future run are not consulted.

static func read(owner: Object) -> Dictionary:
	if not is_instance_valid(owner) or not owner.has_method("get_run_configuration"):
		return {}
	var configured: Variant = owner.call("get_run_configuration")
	if not configured is Dictionary or not configured.get("ok") is bool or not configured.ok \
			or not configured.get("value") is Dictionary \
			or not configured.value.get("dark_mode") is bool:
		return {}
	var day: Variant = owner.get("day")
	if not day is int or day < 1 or day > 7:
		return {}
	return {"palette": "Midnight" if configured.value.dark_mode else "AfterHours", "day": day}
