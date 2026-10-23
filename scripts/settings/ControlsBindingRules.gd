extends RefCounted
## Pure binding proposals. ProfileManager still owns revision checks and commits.
const REGISTRY := preload("res://scripts/settings/ControlsActionRegistry.gd")
const SLOTS := ["keyboard", "controller"]
const KEY_FIELDS := ["kind", "physical_keycode", "keycode", "shift", "alt", "ctrl", "meta"]
const BUTTON_FIELDS := ["kind", "button_index", "device"]
const PROTECTED_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_TAB, KEY_BACKTAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
const PROTECTED_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_GUIDE]

static func defaults() -> Dictionary:
	var result := {}
	for record in REGISTRY.records():
		result[String(record.id)] = {"keyboard": record.keyboard, "controller": record.controller}
	return result

static func validate(bindings: Variant) -> Dictionary:
	var records := REGISTRY.records()
	var ids: Array = []
	for record in records: ids.append(String(record.id))
	if not _exact_fields(bindings, ids): return _failure(&"invalid_binding_inventory")
	for record in records:
		var action := String(record.id)
		if not _exact_fields(bindings[action], SLOTS): return _failure(&"invalid_binding_slots", action)
		for slot in SLOTS:
			var checked := _validate_binding(bindings[action][slot], slot, record.contexts)
			if not checked.ok:
				checked.action = action
				checked.slot = slot
				return checked
	for left in range(records.size()):
		for right in range(left + 1, records.size()):
			if not _contexts_overlap(records[left].contexts, records[right].contexts): continue
			for slot in SLOTS:
				var left_id := String(records[left].id)
				var right_id := String(records[right].id)
				if bindings[left_id][slot] == bindings[right_id][slot]:
					return {"ok": false, "code": &"binding_conflict", "action": left_id, "other_action": right_id, "slot": slot}
	return {"ok": true, "code": &"ok"}

static func propose(bindings: Variant, action: String, slot: String, binding: Variant, revision: Variant) -> Dictionary:
	var checked := validate(bindings)
	if not checked.ok: return checked
	if typeof(revision) != TYPE_INT or revision < 0: return _failure(&"invalid_profile_revision")
	if not bindings.has(action): return _failure(&"unknown_action", action)
	if slot not in SLOTS: return _failure(&"invalid_binding_slot", action)
	var records := REGISTRY.records()
	var source: Dictionary = {}
	for record in records:
		if record.id == action: source = record
	checked = _validate_binding(binding, slot, source.contexts)
	if not checked.ok:
		checked.action = action
		checked.slot = slot
		return checked
	var before: Dictionary = bindings.duplicate(true)
	var after := before.duplicate(true)
	var conflicts: Array[String] = []
	for record in records:
		var other := String(record.id)
		if other != action and _contexts_overlap(source.contexts, record.contexts) and before[other][slot] == binding:
			conflicts.append(other)
			after[other][slot] = before[action][slot].duplicate(true)
	after[action][slot] = binding.duplicate(true)
	# Inspectable even when displacement is illegal. The owner must never commit
	# an unchecked candidate just because a conflict sheet can display it.
	checked = validate(after)
	return {"ok": true, "code": &"ok", "value": {
		"action": action, "slot": slot, "revision": revision,
		"before": before, "after": after, "conflicts": conflicts,
		"operation": &"rebind" if conflicts.is_empty() else &"swap",
		"can_commit": checked.ok, "validation": checked,
	}}

static func _validate_binding(binding: Variant, slot: String, contexts: Array) -> Dictionary:
	if slot == "keyboard":
		if not _exact_fields(binding, KEY_FIELDS): return _failure(&"invalid_keyboard_binding")
		if binding.kind != "key" or typeof(binding.physical_keycode) != TYPE_INT or typeof(binding.keycode) != TYPE_INT or binding.keycode != 0:
			return _failure(&"invalid_keyboard_binding")
		var key: int = binding.physical_keycode
		if key <= 0 or key & KEY_MODIFIER_MASK != 0 or OS.find_keycode_from_string(OS.get_keycode_string(key)) != key:
			return _failure(&"unsupported_key")
		for modifier in ["shift", "alt", "ctrl", "meta"]:
			if typeof(binding[modifier]) != TYPE_BOOL: return _failure(&"invalid_keyboard_binding")
			# Native Controls can match unmodified actions non-exactly. Chords remain
			# unavailable until the shared input boundary arbitrates exact modifiers.
			if binding[modifier]: return _failure(&"modifier_arbitration_unavailable")
		if key in PROTECTED_KEYS: return _failure(&"protected_binding")
		if key == KEY_SPACE:
			for context in contexts:
				if context not in [&"run_desktop_grid", &"run_challenge_grid"]: return _failure(&"protected_binding")
	else:
		if not _exact_fields(binding, BUTTON_FIELDS): return _failure(&"invalid_controller_binding")
		if binding.kind != "joypad_button" or typeof(binding.button_index) != TYPE_INT or typeof(binding.device) != TYPE_INT or binding.device != -1:
			return _failure(&"invalid_controller_binding")
		if binding.button_index < 0 or binding.button_index >= JOY_BUTTON_SDL_MAX: return _failure(&"unsupported_button")
		if binding.button_index in PROTECTED_BUTTONS: return _failure(&"protected_binding")
	return {"ok": true, "code": &"ok"}

static func _contexts_overlap(left: Array, right: Array) -> bool:
	for context in left:
		if context in right: return true
	return false

static func _exact_fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size(): return false
	for field in fields:
		if not value.has(field): return false
	return true

static func _failure(code: StringName, action := "") -> Dictionary:
	return {"ok": false, "code": code, "action": action}
