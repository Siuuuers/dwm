class_name ProfileRestoreParticipant
extends RefCounted

## Restore participant wrapping ProfileManager's legacy-patch and restore seams
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

var _owner: Object = null

func _init(owner: Object) -> void:
	_owner = owner

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("legacy_profile_patch_input")) != TYPE_DICTIONARY:
		return _fail(&"invalid_profile_input", "profile participant requires legacy_profile_patch_input")
	var patch_input: Dictionary = input["legacy_profile_patch_input"]
	var legacy_run_state: Dictionary = patch_input.get("legacy_run_state", {}) \
		if typeof(patch_input.get("legacy_run_state")) == TYPE_DICTIONARY else {}
	var legacy_input_mappings: Dictionary = patch_input.get("legacy_input_mappings", {}) \
		if typeof(patch_input.get("legacy_input_mappings")) == TYPE_DICTIONARY else {}
	var prepared: Dictionary = _owner.prepare_legacy_profile_patch(legacy_run_state, legacy_input_mappings)
	if not prepared.get("ok", false):
		return prepared
	var candidate: Dictionary = prepared.get("value", {})
	return {"ok": true, "code": &"ok", "value": {
		"profile_plan": {"profile": candidate.duplicate(true)},
		"locale_id": str((candidate.get("preferences", {}) as Dictionary).get("language", "")),
	}}

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
