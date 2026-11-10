class_name DesktopConsequenceRestoreParticipant
extends RefCounted


const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

var _state: Object = null

func _init(state: Object) -> void:
	_state = state

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_consequence_input", "consequence participant requires input.state")
	var validated: Dictionary = DESKTOP_CONSEQUENCE_STATE.validate(input["state"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {
		"consequence_plan": {"state": (validated["value"] as Dictionary)["state"]},
	}}

func capture() -> Dictionary:
	return _state.capture()

func apply_silent(plan: Dictionary) -> Dictionary:
	if typeof(plan.get("state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_consequence_plan", "apply_silent requires plan.state")
	var restored: Dictionary = _state.prepare_restore(plan["state"])
	if not restored.get("ok", false):
		return restored
	return _state.commit((restored["value"] as Dictionary)["candidate"])

func rollback_silent(backup: Dictionary) -> Dictionary:
	if typeof(backup.get("state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_consequence_backup", "rollback_silent requires backup.state")
	return _state.rollback(backup)

func finalize() -> Dictionary:
	return {"ok": true, "code": &"ok"}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
