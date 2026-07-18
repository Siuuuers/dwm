class_name DialogicPreferenceAdapter
extends RefCounted

var _dialogic: Node
var _plan: Dictionary = {}


func bind(dialogic: Node) -> Dictionary:
	if dialogic == null:
		return _failure(&"dialogic_missing")
	if _dialogic != null and _dialogic.get_instance_id() != dialogic.get_instance_id():
		return _failure(&"dialogic_already_bound")
	var already_bound := _dialogic != null
	_dialogic = dialogic
	return _ok({"already_bound": already_bound})


func prepare(profile: Dictionary) -> Dictionary:
	var preferences: Dictionary = profile.get("preferences", profile)
	var dialogue: Dictionary = preferences.get("dialogue", {})
	var text_speed := float(dialogue.get("text_speed", 0.0))
	var auto_speed := float(dialogue.get("auto_text_speed", 0.0))
	if not is_finite(text_speed) or not is_finite(auto_speed) or text_speed <= 0.0 or auto_speed <= 0.0:
		return _failure(&"invalid_dialogic_preferences")
	return _ok({
		"text_delay_multiplier": 1.0 / text_speed,
		"auto_delay_multiplier": 1.0 / auto_speed,
		"auto_advance_enabled": bool(dialogue.get("auto_advance_dialogue", false)),
	})


func capture_state() -> Dictionary:
	if _dialogic == null:
		return _failure(&"dialogic_missing")
	var settings := _subsystem(&"Settings")
	var inputs := _subsystem(&"Inputs")
	if settings == null or inputs == null or typeof(settings.get("settings")) != TYPE_DICTIONARY:
		return _failure(&"dialogic_subsystem_missing")
	var auto_advance: Variant = inputs.get("auto_advance")
	if auto_advance == null:
		return _failure(&"dialogic_subsystem_missing")
	var settings_cache: Dictionary = settings.get("settings")
	return _ok({"plan": {
		"text_delay_multiplier": float(settings_cache.get(&"text_speed", _plan.get("text_delay_multiplier", 1.0))),
		"auto_delay_multiplier": float(settings_cache.get(&"autoadvance_delay_modifier", _plan.get("auto_delay_multiplier", 1.0))),
		"auto_advance_enabled": bool(auto_advance.get("enabled_until_user_input")),
	}})


func apply_silent(plan: Dictionary) -> Dictionary:
	if _dialogic == null:
		return _failure(&"dialogic_missing")
	for key in ["text_delay_multiplier", "auto_delay_multiplier", "auto_advance_enabled"]:
		if not plan.has(key):
			return _failure(&"invalid_dialogic_preferences")
	var settings := _subsystem(&"Settings")
	var text := _subsystem(&"Text")
	var inputs := _subsystem(&"Inputs")
	if settings == null or text == null or inputs == null:
		return _failure(&"dialogic_subsystem_missing")
	var settings_cache: Variant = settings.get("settings")
	if typeof(settings_cache) != TYPE_DICTIONARY:
		return _failure(&"dialogic_subsystem_missing")
	if not text.has_method("update_text_speed"):
		return _failure(&"dialogic_subsystem_missing")
	var auto_advance: Variant = inputs.get("auto_advance")
	if auto_advance == null:
		return _failure(&"dialogic_subsystem_missing")
	settings_cache[&"text_speed"] = float(plan["text_delay_multiplier"])
	settings_cache[&"autoadvance_delay_modifier"] = float(plan["auto_delay_multiplier"])
	settings.set("settings", settings_cache)
	text.call(&"update_text_speed", -1.0, false, 1.0, float(plan["text_delay_multiplier"]))
	auto_advance.set("delay_modifier", float(plan["auto_delay_multiplier"]))
	auto_advance.set("enabled_until_user_input", bool(plan["auto_advance_enabled"]))
	_plan = plan.duplicate(true)
	return _ok({})


func rollback_silent(backup: Dictionary) -> Dictionary:
	var plan: Variant = backup.get("plan")
	if typeof(plan) != TYPE_DICTIONARY:
		return _failure(&"invalid_dialogic_backup")
	return apply_silent(plan)


func finalize() -> Dictionary:
	return _ok({})


func _subsystem(name: StringName) -> Object:
	var child := _dialogic.get_node_or_null(String(name))
	if child != null:
		return child
	var direct: Variant = _dialogic.get(name)
	if direct is Object:
		return direct
	return null


func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
