class_name DesktopBoardRestoreParticipant
extends RefCounted


const DESKTOP_BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

var _state: Object = null
var _issuer: Object = null

func _init(state: Object, issuer: Object = null) -> void:
	_state = state
	_issuer = issuer

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_board_input", "board participant requires input.state")
	var prepared: Dictionary
	if input.get("schema_version") == 9:
		if _issuer == null: return _fail(&"scene_payment_issuer_required", "scene restore requires the retained issuer")
		prepared = _state.prepare_player_restore_scene(input["state"], _issuer)
	else:
		prepared = _state.prepare_restore(input["state"])
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "code": &"ok", "value": {
		"board_plan": {"candidate": (prepared["value"] as Dictionary)["candidate"]},
	}}

func capture() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"snapshot": _state.capture()}}

func apply_silent(plan: Dictionary) -> Dictionary:
	if typeof(plan.get("candidate")) != TYPE_DICTIONARY:
		return _fail(&"invalid_board_plan", "apply_silent requires plan.candidate")
	return _state.commit(plan["candidate"])

func rollback_silent(backup: Dictionary) -> Dictionary:
	if typeof(backup.get("snapshot")) != TYPE_DICTIONARY:
		return _fail(&"invalid_board_backup", "rollback_silent requires backup.snapshot")
	var restored: Dictionary = _state.prepare_restore(backup["snapshot"])
	if not restored.get("ok", false):
		return restored
	return _state.commit((restored["value"] as Dictionary)["candidate"])

func finalize() -> Dictionary:
	return {"ok": true, "code": &"ok"}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

