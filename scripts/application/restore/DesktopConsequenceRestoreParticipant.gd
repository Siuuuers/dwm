class_name DesktopConsequenceRestoreParticipant
extends RefCounted

## Restore participant wrapping a live DesktopConsequenceState (Plan 02 Task 6, dwm-p2r.32, Phase C).
## Unlike the profile/localization/audio/route/narrative participants, there is no GameState-style
## owner indirection here: DesktopConsequenceState is itself the pure domain object, so this
## participant drives its prepare_restore()/capture()/commit()/rollback() seams directly.
##
## Silent by design (brief line 382, Step 6.8): apply_silent() only commits the candidate onto the
## live state -- it never publishes, never touches the outbox, and never emits anything. Publication
## happens later, at the sole aggregate restore publication point this participant does not own.

const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

var _state: Object = null

func _init(state: Object) -> void:
	_state = state

## `input.state` is a schema-valid v4 consequence capture (already remapped, when this run of the
## transaction is a restore, by DesktopContinuationRemapper -- this participant does not remap
## anything itself; it only proves the candidate it is handed is a valid consequence state).
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
