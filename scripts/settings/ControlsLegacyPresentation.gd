extends RefCounted
## Read-only display of stored input records; never converts them into live input.
const REGISTRY := preload("res://scripts/settings/ControlsActionRegistry.gd")
const TRANSFER_ACTIONS := ["game_quick_save", "game_quick_load", "game_new_board"]

static func rows(legacy: Dictionary, locale: String, lookup: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var actions: Array = legacy.keys()
	actions.sort()
	for action: String in actions:
		var label := _text(lookup, "settings.action." + action)
		for registered in REGISTRY.records():
			if registered.id == action:
				label = registered.labels.get(locale.replace("_", "-"), registered.labels.en)
		var bindings: Array[String] = []
		for record: Dictionary in legacy[action]:
			bindings.append(_record_label(record, lookup))
		if bindings.is_empty(): bindings.append(_text(lookup, "settings.controls.import.no_binding"))
		result.append({"action_id": action, "label": label, "bindings": bindings, "retired": action not in TRANSFER_ACTIONS})
	return result

static func _record_label(record: Dictionary, lookup: Callable) -> String:
	if record.get("kind") == "joypad_button":
		var device := _text(lookup, "settings.controls.import.any_controller") if record.device == -1 else _text(lookup, "settings.controls.import.saved_controller", {"device": record.device})
		return _text(lookup, "settings.controls.import.controller_record", {"button": record.button_index, "device": device})
	var physical: int = record.physical_keycode
	var logical: int = record.keycode
	var key := _key_name(physical, lookup)
	if physical == 0 and logical != 0:
		key = _text(lookup, "settings.controls.import.logical_key", {"key": _key_name(logical, lookup)})
	elif physical != 0 and logical != 0:
		key = _text(lookup, "settings.controls.import.physical_key", {"key": _key_name(physical, lookup)}) + "; " + _text(lookup, "settings.controls.import.logical_key", {"key": _key_name(logical, lookup)})
	var parts: Array[String] = []
	for modifier in [["ctrl", "Ctrl"], ["alt", "Alt"], ["shift", "Shift"], ["meta", "Meta"]]:
		if record[modifier[0]]: parts.append(modifier[1])
	parts.append(key)
	return " + ".join(parts)

static func _key_name(code: int, lookup: Callable) -> String:
	if code == 0: return _text(lookup, "settings.controls.import.no_key")
	if code > 0 and code & KEY_MODIFIER_MASK == 0:
		var name := OS.get_keycode_string(code)
		if not name.is_empty() and OS.find_keycode_from_string(name) == code:
			return name
	return _text(lookup, "settings.controls.import.unknown_key", {"code": code})

static func _text(lookup: Callable, key: String, parameters: Dictionary = {}) -> String:
	return lookup.call(key, parameters)
