class_name DesktopBoardRestoreParticipant
extends RefCounted

## Restore participant wrapping a live DesktopBoardState (Plan 02 Task 6, dwm-p2r.32, Phase C).
## Mirrors DesktopConsequenceRestoreParticipant's shape: no owner indirection, silent apply
## (brief line 382, Step 6.8 -- "applying consequence before board lets a restored SETTLING board
## validate its pending journal owner", so this participant is always driven AFTER the consequence
## one in SaveManager's participant order and never publishes anything itself).
##
## DesktopBoardState.capture() returns its state dict directly (no {ok,value} envelope, unlike most
## of this codebase's other prepare/commit seams) -- this participant wraps that raw dict into the
## uniform {ok,value} shape every SaveManager participant is required to return.

const DESKTOP_BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

var _state: Object = null

func _init(state: Object) -> void:
	_state = state

## `input.state` is a schema-valid v4 board capture (already remapped, for a restore, by
## DesktopContinuationRemapper before this participant ever sees it).
func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_board_input", "board participant requires input.state")
	var prepared: Dictionary = _state.prepare_restore(input["state"])
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
