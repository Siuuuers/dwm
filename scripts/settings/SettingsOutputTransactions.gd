class_name SettingsOutputTransactions
extends RefCounted
## Settings output transactions. The Audio owner retains playback and committed state.

const PATHS := [
	"preferences.audio.master_volume", "preferences.audio.music_volume",
	"preferences.audio.ambience_volume", "preferences.audio.sfx_volume",
	"preferences.audio.master_muted", "preferences.audio.music_muted",
	"preferences.audio.ambience_muted", "preferences.audio.sfx_muted",
	"preferences.audio.output_mode", "preferences.audio.mute_when_inactive",
]
var _owner: Node
var _busy := false
var _drag: Dictionary = {}
var _generation := 0
var _window: Node
var _window_bound := false
var _window_backup: Dictionary = {}
var _window_baseline: Dictionary = {}

func _init(owner: Node) -> void:
	_owner = owner

## One physical window owner shares this helper and the Audio owner's Profile.
func bind_window_output(window: Node) -> Dictionary:
	if _busy or has_preview(): return _failure(&"settings_audio_busy")
	if _window_bound:
		return _success({"already_bound": true}) if is_instance_valid(_window) and window == _window else _failure(&"settings_window_already_bound")
	if not is_instance_valid(window) or not is_instance_valid(_owner._profile) or window.get("_profile") != _owner._profile:
		return _failure(&"invalid_settings_window_output")
	for method: StringName in [&"get_settings_window_capability", &"get_applied_mode", &"capture_restore_state", &"apply_restore_silent", &"rollback_restore_silent", &"latch_output_failure"]:
		if not window.has_method(method): return _failure(&"invalid_settings_window_output")
	_window = window
	_window_bound = true
	return _success({"already_bound": false})

func commit_settings_window_preference(holder_id: Variant, value: Variant, path: StringName = &"preferences.display.window_mode") -> Dictionary:
	if path not in [&"preferences.display.window_mode", &"preferences.display.window_size"] or not _valid_path(holder_id, &"preferences.audio.master_volume"):
		return _failure(&"invalid_settings_window_preference")
	if has_preview(): return _failure(&"settings_audio_busy")
	var admitted := _begin()
	if not admitted.ok: return admitted
	if not _window_available(): return _finish(_failure(&"settings_window_unavailable"))
	var revision := _revision()
	var baseline := _snapshot()
	var prepared: Dictionary = _owner._profile.prepare_preferences({path: value})
	if not prepared.get("ok", false): return _finish(prepared)
	return _commit(prepared.value, baseline, revision)

func is_busy() -> bool:
	return _busy

func has_preview() -> bool:
	return not _drag.is_empty()

## Trusted owner invalidation; caller owns subsequent physical settlement.
func invalidate_preview() -> void:
	_drag.clear()
	_generation += 1

func cancel_current_preview() -> Dictionary:
	if _busy: return _failure(&"settings_audio_busy")
	if _drag.is_empty(): return _success({"cancelled": false})
	return cancel_settings_volume_preview(_drag.handle)

func preview_settings_volume(holder_id: Variant, path: Variant, value: Variant, preview_handle: Variant = null) -> Dictionary:
	if not _valid_path(holder_id, path) or not String(path).ends_with("_volume"):
		return _failure(&"invalid_settings_audio_preference")
	if not _matches(holder_id, path, preview_handle): return _failure(&"stale_settings_volume_preview")
	var admitted := _begin()
	if not admitted.ok: return admitted
	var revision := _revision()
	var generation := _generation
	var baseline := _snapshot()
	var prepared: Dictionary = _owner._profile.prepare_preferences({StringName(path): value})
	if not prepared.get("ok", false): return _finish(prepared)
	var applied: Dictionary = _owner._apply_settings_output(_candidate(prepared.value))
	if not applied.get("ok", false): return _recover(applied)
	if not _unchanged(revision, baseline, generation): return _recover(_failure(&"settings_audio_preview_conflict"))
	if _drag.is_empty():
		_drag = {"handle": RefCounted.new(), "holder": String(holder_id), "path": StringName(path)}
	return _finish(_success({"preview_handle": _drag.handle}))

func commit_settings_audio_preference(holder_id: Variant, path: Variant, value: Variant, preview_handle: Variant = null) -> Dictionary:
	if not _valid_path(holder_id, path): return _failure(&"invalid_settings_audio_preference")
	if not _matches(holder_id, path, preview_handle): return _failure(&"stale_settings_volume_preview")
	var admitted := _begin()
	if not admitted.ok: return admitted
	var revision := _revision()
	var baseline := _snapshot()
	var prepared: Dictionary = _owner._profile.prepare_preferences({StringName(path): value})
	if not prepared.get("ok", false):
		return _recover(prepared) if has_preview() else _finish(prepared)
	return _commit(prepared.value, baseline, revision)

func commit_settings_profile_reset(holder_id: Variant, method: Variant, expected_revision: int = -1) -> Dictionary:
	if (not _valid_path(holder_id, &"preferences.audio.master_volume")
		or typeof(method) not in [TYPE_STRING, TYPE_STRING_NAME]
		or String(method) not in ["reset_preferences", "reset_entire_profile"]):
		return _failure(&"invalid_settings_profile_reset")
	if has_preview(): return _failure(&"settings_audio_busy")
	var admitted := _begin([&"_prepare_preferences_reset", &"_prepare_entire_profile_reset", &"_commit_prepared_reset"])
	if not admitted.ok: return admitted
	var revision := _revision()
	if expected_revision != -1 and expected_revision != revision:
		return _finish(_failure(&"profile_revision_changed"))
	var baseline := _snapshot()
	var preferences := String(method) == "reset_preferences"
	var prepared: Dictionary = _owner._profile.call(&"_prepare_preferences_reset" if preferences else &"_prepare_entire_profile_reset")
	if not prepared.get("ok", false): return _finish(prepared)
	return _commit(prepared.value, baseline, revision, &"preferences" if preferences else &"entire_profile")

func cancel_settings_volume_preview(preview_handle: Variant) -> Dictionary:
	if _drag.is_empty() or preview_handle != _drag.handle:
		return _failure(&"stale_settings_volume_preview")
	var admitted := _begin()
	if not admitted.ok: return admitted
	invalidate_preview()
	var settled := _settle_latest()
	if not settled.ok: return _fatal(settled)
	return _finish(_success({"cancelled": true}))

func _commit(candidate: Dictionary, baseline: Dictionary, revision: int, section: StringName = &"") -> Dictionary:
	var generation := _generation
	if not _unchanged(revision, baseline, generation):
		var conflict := _failure(&"settings_audio_commit_conflict")
		return _recover(conflict) if has_preview() else _finish(conflict)
	if _window_plan(candidate) != _window_plan(baseline) and not _window_available():
		return _finish(_failure(&"settings_window_unavailable"))
	if _window_bound:
		if not _window_identity_valid(): return _finish(_failure(&"settings_window_unavailable"))
		if _window_plan(candidate) != _applied_window_plan():
			if not _window_available(): return _finish(_failure(&"settings_window_unavailable"))
			var captured: Dictionary = _window.capture_restore_state()
			if not captured.get("ok", false): return _finish(captured)
			_window_backup = captured.value.duplicate(true)
			_window_baseline = _window_plan(baseline)
			if not _unchanged(revision, baseline, generation): return _recover(_failure(&"settings_audio_commit_conflict"))
	var settings := _candidate(candidate)
	var applied: Dictionary = _owner._apply_settings_output(settings)
	if not applied.get("ok", false): return _recover(applied)
	if not _unchanged(revision, baseline, generation): return _recover(_failure(&"settings_audio_commit_conflict"))
	var window_applied := _apply_window(candidate)
	if not window_applied.ok: return _recover(window_applied)
	if not _unchanged(revision, baseline, generation): return _recover(_failure(&"settings_audio_commit_conflict"))
	var committed: Dictionary
	if section.is_empty():
		committed = _owner._profile.commit_prepared_profile(candidate, true, revision)
	else:
		committed = _owner._profile._commit_prepared_reset(candidate, section, revision)
	if not committed.get("ok", false): return _recover(committed)
	_owner._settings = settings.duplicate(true)
	invalidate_preview()
	# Publication may synchronously commit another preference. Keep the local gate
	# closed until that latest committed state has also been physically proved.
	var published: Dictionary = _owner._profile.publish_deferred_profile_signals(committed.value.publication_id)
	var settled := _settle_latest()
	if not settled.ok: return _fatal(settled)
	return _finish(published)

func _settle_latest(restore_original_window: bool = false) -> Dictionary:
	# A hostile output callback must not make settlement an unbounded loop.
	for _attempt in range(8):
		if _owner._fatal: return _failure(&"audio_runtime_indeterminate")
		var revision := _revision()
		var generation := _generation
		var snapshot := _snapshot()
		var settings := _candidate(snapshot)
		# Reverse compensation order: window was applied after audio.
		if restore_original_window:
			var restored := _apply_window(snapshot, true)
			if not restored.ok: return restored
			if _generation != generation or _revision() != revision or _snapshot() != snapshot: continue
		var result: Dictionary = _owner._apply_settings_output(settings)
		if not result.get("ok", false): return result
		# Never write a window target made stale by an audio callback.
		if _generation != generation or _revision() != revision or _snapshot() != snapshot: continue
		if not restore_original_window:
			var window_result := _apply_window(snapshot)
			if not window_result.ok: return window_result
		if _generation == generation and _revision() == revision and _snapshot() == snapshot:
			_owner._settings = settings.duplicate(true)
			return _success({})
	return _failure(&"settings_audio_settlement_conflict")

func _window_identity_valid() -> bool:
	return is_instance_valid(_window) and is_instance_valid(_window._profile) and _window._profile == _owner._profile

func _window_available() -> bool:
	if not _window_bound or not _window_identity_valid() or _window._fatal: return false
	var capability: Dictionary = _window.get_settings_window_capability()
	return capability.get("ok", false) and capability.get("value", {}).get("available", false)

func _apply_window(profile: Dictionary, restore_original: bool = false) -> Dictionary:
	if not _window_bound: return _success({})
	if not _window_identity_valid(): return _failure(&"settings_window_unavailable")
	var plan := _window_plan(profile)
	if restore_original and not _window_backup.is_empty() and plan == _window_baseline:
		return _window.rollback_restore_silent(_window_backup.duplicate(true))
	if _window._fatal: return _failure(&"settings_window_unavailable")
	if plan == _applied_window_plan(): return _success({})
	if not _window_available(): return _failure(&"settings_window_unavailable")
	return _window.apply_restore_silent(plan)

func _window_plan(profile: Dictionary) -> Dictionary:
	return {"window_mode": String(profile.preferences.display.window_mode),
		"window_size": String(profile.preferences.display.get("window_size", "1280x720"))}

func _applied_window_plan() -> Dictionary:
	return {"window_mode": _window.get_applied_mode(), "window_size": _window.get_applied_size() if _window.has_method("get_applied_size") else "1280x720"}

func _recover(cause: Dictionary) -> Dictionary:
	invalidate_preview()
	var settled := _settle_latest(true)
	if not settled.ok: return _fatal(settled)
	return _finish(cause)

func _fatal(cause: Dictionary) -> Dictionary:
	invalidate_preview()
	if not _owner._fatal: _owner._latch_consumer_fatal(&"settings_output_settlement", cause)
	return _finish(_failure(&"audio_runtime_indeterminate"))

func _begin(required_methods: Array[StringName] = []) -> Dictionary:
	if not is_instance_valid(_owner) or _busy or not _owner._initialized:
		return _failure(&"settings_audio_busy")
	if _owner._fatal: return _failure(&"audio_runtime_indeterminate")
	if not is_instance_valid(_owner._profile) or not is_instance_valid(_owner._playback_port):
		return _failure(&"settings_audio_unavailable")
	var capability: Dictionary = _owner.get_settings_audio_capability()
	if not capability.get("ok", false) or not capability.get("value", {}).get("volume", false):
		return _failure(&"settings_audio_unavailable")
	for method: StringName in required_methods:
		if not _owner._profile.has_method(method): return _failure(&"settings_audio_unavailable")
	if _owner._mutation_gate != null:
		var admitted: Dictionary = _owner._mutation_gate.guard_external(&"settings_audio_output")
		if not admitted.get("ok", false): return admitted
	_busy = true
	return _success({})

func _unchanged(revision: int, baseline: Dictionary, generation: int) -> bool:
	return not _owner._fatal and generation == _generation and _revision() == revision and _snapshot() == baseline

func _revision() -> int:
	return _owner._profile.get_profile_revision()

func _snapshot() -> Dictionary:
	return _owner._profile.get_profile_snapshot()

func _candidate(profile: Dictionary) -> Dictionary:
	return _owner._settings_from_audio(profile.preferences.audio)

func _matches(holder_id: Variant, path: Variant, handle: Variant) -> bool:
	if _drag.is_empty(): return handle == null
	return handle != null and handle == _drag.handle and String(holder_id) == _drag.holder and StringName(path) == _drag.path

func _valid_path(holder_id: Variant, path: Variant) -> bool:
	return (typeof(holder_id) in [TYPE_STRING, TYPE_STRING_NAME]
		and not String(holder_id).is_empty() and String(holder_id) == String(holder_id).strip_edges()
		and typeof(path) in [TYPE_STRING, TYPE_STRING_NAME] and String(path) in PATHS)

func _finish(result: Dictionary) -> Dictionary:
	_window_backup.clear()
	_window_baseline.clear()
	_busy = false
	return result

func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}

func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
