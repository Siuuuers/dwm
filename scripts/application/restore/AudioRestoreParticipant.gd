class_name AudioRestoreParticipant
extends RefCounted

## Restore participant wrapping AudioManager, driven by the prepared profile
## preferences plus the bundle audio context
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

var _owner: Object = null

func _init(owner: Object) -> void:
	_owner = owner

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("preferences")) != TYPE_DICTIONARY:
		return _fail(&"invalid_audio_input", "audio participant requires prepared preferences")
	if typeof(input.get("audio_context")) != TYPE_DICTIONARY:
		return _fail(&"invalid_audio_input", "audio participant requires an audio_context")
	var prepared: Dictionary = _owner.prepare_semantic_restore(
		input["audio_context"], {"preferences": input["preferences"]})
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "code": &"ok", "value": {"audio_plan": prepared.get("value", {})}}

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
