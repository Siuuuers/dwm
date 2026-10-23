class_name ProfileRestoreParticipant
extends RefCounted

## Restore participant wrapping ProfileManager's legacy-patch and restore seams
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

var _owner: Object = null
var _window_output: Node = null

func _init(owner: Object) -> void:
	_owner = owner

func configure_window_output(window_output: Node) -> Dictionary:
	if not is_instance_valid(window_output):
		return _fail(&"invalid_window_output", "window output must be a live node")
	for method: StringName in [&"prepare_restore", &"capture_restore_state", &"apply_restore_silent",
			&"rollback_restore_silent", &"finalize_restore", &"latch_output_failure"]:
		if not window_output.has_method(method):
			return _fail(&"invalid_window_output", "window output does not expose the restore contract")
	if _window_output != null:
		if window_output == _window_output:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"window_output_already_configured", "a window output is already configured")
	_window_output = window_output
	return {"ok": true, "code": &"ok", "value": {
		"window_output_instance_id": window_output.get_instance_id(),
	}, "receipt": {}}

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("legacy_profile_patch_input")) != TYPE_DICTIONARY:
		return _fail(&"invalid_profile_input", "profile participant requires legacy_profile_patch_input")
	var patch_input: Dictionary = input["legacy_profile_patch_input"]
	if patch_input.is_empty():
		if not is_instance_valid(_owner) or not _owner.has_method("get_profile_snapshot"):
			return _fail(&"invalid_profile_owner", "current profile snapshot is unavailable")
		return prepare_frozen_profile(_owner.get_profile_snapshot())
	var legacy_run_state: Dictionary = patch_input.get("legacy_run_state", {}) \
		if typeof(patch_input.get("legacy_run_state")) == TYPE_DICTIONARY else {}
	var legacy_input_mappings: Dictionary = patch_input.get("legacy_input_mappings", {}) \
		if typeof(patch_input.get("legacy_input_mappings")) == TYPE_DICTIONARY else {}
	var prepared: Dictionary = _owner.prepare_legacy_profile_patch(legacy_run_state, legacy_input_mappings)
	if not prepared.get("ok", false):
		return prepared
	return _prepare_profile_plan(prepared.get("value", {}))

func prepare_frozen_profile(candidate: Dictionary) -> Dictionary:
	if not is_instance_valid(_owner) or not _owner.has_method("prepare_profile_document"):
		return _fail(&"invalid_profile_owner", "profile document validation is unavailable")
	var prepared: Dictionary = _owner.prepare_profile_document(candidate.duplicate(true))
	if not prepared.get("ok", false):
		return prepared
	return _prepare_profile_plan(prepared.get("value", {}))

func _prepare_profile_plan(candidate: Dictionary) -> Dictionary:
	var profile_plan := {"profile": candidate.duplicate(true)}
	if _window_output != null:
		var available := _require_window_output()
		if not available.get("ok", false):
			return available
		var preferences: Variant = candidate.get("preferences")
		if typeof(preferences) != TYPE_DICTIONARY:
			return _fail(&"invalid_profile_plan", "prepared profile requires preferences")
		var window_prepared: Dictionary = _window_output.prepare_restore((preferences as Dictionary).duplicate(true))
		if not window_prepared.get("ok", false):
			return window_prepared
		var window_plan: Variant = window_prepared.get("value")
		if typeof(window_plan) != TYPE_DICTIONARY:
			return _fail(&"invalid_window_restore_plan", "window preparation returned no plan")
		profile_plan["window_plan"] = (window_plan as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {
		"profile_plan": profile_plan,
		"locale_id": str(((candidate.get("preferences", {}) as Dictionary).get("language", {}) as Dictionary).get("primary_locale_id", "")),
		"font_style": str(candidate["preferences"]["accessibility"]["font_style"]),
		"text_size": int(candidate["preferences"]["accessibility"]["text_size"]),
	}}

func capture() -> Dictionary:
	var captured: Dictionary = _owner.capture_restore_state()
	if not captured.get("ok", false) or _window_output == null:
		return captured
	var available := _require_window_output()
	if not available.get("ok", false):
		return available
	var window_captured: Dictionary = _window_output.capture_restore_state()
	if not window_captured.get("ok", false):
		return window_captured
	if typeof(captured.get("value")) != TYPE_DICTIONARY or typeof(window_captured.get("value")) != TYPE_DICTIONARY:
		return _fail(&"invalid_restore_backup", "restore owners returned no backup")
	var value: Dictionary = (captured["value"] as Dictionary).duplicate(true)
	value["window_backup"] = (window_captured["value"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": value}

func apply_silent(plan: Dictionary) -> Dictionary:
	if _window_output == null:
		return _owner.apply_restore_silent(plan)
	var available := _require_window_output()
	if not available.get("ok", false):
		return available
	if typeof(plan.get("profile")) != TYPE_DICTIONARY or typeof(plan.get("window_plan")) != TYPE_DICTIONARY:
		return _fail(&"invalid_profile_window_restore_plan", "composite restore requires profile and window plans")
	var before := capture()
	if not before.get("ok", false):
		return before
	var backup: Dictionary = before["value"]
	var window_applied: Dictionary = _window_output.apply_restore_silent((plan["window_plan"] as Dictionary).duplicate(true))
	if not window_applied.get("ok", false):
		var restored_window: Dictionary = _window_output.rollback_restore_silent(backup["window_backup"])
		if not restored_window.get("ok", false):
			return _fatal_recovery(&"profile_window_apply_rollback", window_applied, restored_window)
		return window_applied
	var profile_applied: Dictionary = _owner.apply_restore_silent({"profile": (plan["profile"] as Dictionary).duplicate(true)})
	if not profile_applied.get("ok", false):
		var restored_window: Dictionary = _window_output.rollback_restore_silent(backup["window_backup"])
		var restored_profile := _restore_profile_if_changed(backup)
		if not restored_window.get("ok", false) or not restored_profile.get("ok", false):
			return _fatal_recovery(&"profile_apply_rollback", profile_applied,
				restored_window if not restored_window.get("ok", false) else restored_profile)
		return profile_applied
	return {"ok": true, "code": &"ok", "value": {}}

func rollback_silent(backup: Dictionary) -> Dictionary:
	if _window_output == null:
		return _owner.rollback_restore_silent(backup)
	var available := _require_window_output()
	if not available.get("ok", false):
		return available
	if typeof(backup.get("profile")) != TYPE_DICTIONARY or typeof(backup.get("window_backup")) != TYPE_DICTIONARY:
		return _fail(&"invalid_profile_window_restore_backup", "composite restore requires profile and window backups")
	var restored_window: Dictionary = _window_output.rollback_restore_silent((backup["window_backup"] as Dictionary).duplicate(true))
	var restored_profile: Dictionary = _owner.rollback_restore_silent({"profile": (backup["profile"] as Dictionary).duplicate(true)})
	if not restored_window.get("ok", false) or not restored_profile.get("ok", false):
		return _fatal_recovery(&"profile_window_rollback", restored_window,
			restored_window if not restored_window.get("ok", false) else restored_profile)
	return {"ok": true, "code": &"ok", "value": {}}

func finalize() -> Dictionary:
	if _window_output != null:
		var available := _require_window_output()
		if not available.get("ok", false):
			return available
		var window_finalized: Dictionary = _window_output.finalize_restore()
		if not window_finalized.get("ok", false):
			return window_finalized
	return _owner.finalize_restore()

func _restore_profile_if_changed(backup: Dictionary) -> Dictionary:
	var current: Dictionary = _owner.capture_restore_state()
	if not current.get("ok", false):
		return _owner.rollback_restore_silent({"profile": (backup["profile"] as Dictionary).duplicate(true)})
	if current.get("value") == {"profile": backup["profile"]}:
		return {"ok": true, "code": &"ok"}
	return _owner.rollback_restore_silent({"profile": (backup["profile"] as Dictionary).duplicate(true)})

func _require_window_output() -> Dictionary:
	if is_instance_valid(_window_output):
		return {"ok": true, "code": &"ok"}
	return {"ok": false, "code": &"window_output_indeterminate",
		"message": "configured window output is no longer available", "fatal": true}

func _fatal_recovery(phase: StringName, cause: Dictionary, recovery: Dictionary) -> Dictionary:
	if is_instance_valid(_window_output):
		_window_output.latch_output_failure(phase, recovery.duplicate(true))
	return {"ok": false, "code": &"profile_window_restore_indeterminate",
		"message": "profile/window restore compensation could not be proven", "fatal": true,
		"cause": cause.duplicate(true), "recovery": recovery.duplicate(true)}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
