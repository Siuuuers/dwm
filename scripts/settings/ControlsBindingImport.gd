extends RefCounted
## Pure import of the three legacy actions whose semantic identities survive.
## ProfileSchema validates and retains the complete source document separately.
const RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const TRANSFER_ACTIONS := ["game_quick_save", "game_quick_load", "game_new_board"]


static func prepare(legacy: Dictionary) -> Dictionary:
	var candidate := RULES.defaults()
	var issues: Array[Dictionary] = []
	for action: String in TRANSFER_ACTIONS:
		if not legacy.has(action) or not legacy[action] is Array:
			issues.append({"code": &"invalid_legacy_action", "action": action})
			continue
		var slots := {"keyboard": [], "controller": []}
		for index: int in range(legacy[action].size()):
			var record: Variant = legacy[action][index]
			if not record is Dictionary or record.get("kind") not in ["key", "joypad_button"]:
				issues.append({"code": &"unsupported_legacy_record", "action": action, "index": index})
				continue
			var slot := "keyboard" if record.kind == "key" else "controller"
			slots[slot].append(record)
		for slot: String in slots:
			if slots[slot].is_empty():
				continue
			if slots[slot].size() > 1:
				issues.append({"code": &"multiple_legacy_records", "action": action, "slot": slot, "count": slots[slot].size()})
				continue
			var record: Dictionary = slots[slot][0]
			var probe := RULES.defaults()
			probe[action][slot] = record.duplicate(true)
			var supported := RULES.validate(probe)
			# A transferred binding may collide with a default that another imported
			# record replaces. Judge collisions only on the complete candidate.
			if not supported.ok and supported.code != &"binding_conflict":
				issues.append(supported.duplicate(true))
				continue
			candidate[action][slot] = record.duplicate(true)
	var complete := RULES.validate(candidate)
	if not complete.ok:
		issues.append(complete.duplicate(true))
	var pending := not issues.is_empty()
	return {"bindings": RULES.defaults() if pending else candidate, "pending": pending, "issues": issues}
