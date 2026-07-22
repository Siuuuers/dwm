class_name LocalizationRestoreParticipant
extends RefCounted

## Restore participant wrapping LocalizationManager, driven only by the prepared
## profile candidate's language
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

var _owner: Object = null

func _init(owner: Object) -> void:
	_owner = owner

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("locale_id")) != TYPE_STRING or str(input["locale_id"]).is_empty():
		return _fail(&"invalid_localization_input", "localization participant requires a locale_id")
	var prepared: Dictionary = _owner.prepare_locale(str(input["locale_id"]))
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "code": &"ok", "value": {"localization_plan": prepared.get("value", {})}}

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func apply_silent(plan: Dictionary) -> Dictionary:
	return _owner.apply_restore_silent(plan)

func rollback_silent(backup: Dictionary) -> Dictionary:
	return _owner.rollback_restore_silent(backup)

func finalize() -> Dictionary:
	return _owner.finalize_restore()

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
