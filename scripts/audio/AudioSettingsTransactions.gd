class_name AudioSettingsTransactions
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

func _init(owner: Node) -> void:
	_owner = owner

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
	var settings := _candidate(candidate)
	var applied: Dictionary = _owner._apply_settings_output(settings)
	if not applied.get("ok", false): return _recover(applied)
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

func _settle_latest() -> Dictionary:
	# A hostile output callback must not make settlement an unbounded loop.
	for _attempt in range(8):
		if _owner._fatal: return _failure(&"audio_runtime_indeterminate")
		var revision := _revision()
		var generation := _generation
		var snapshot := _snapshot()
		var settings := _candidate(snapshot)
		var result: Dictionary = _owner._apply_settings_output(settings)
		if not result.get("ok", false): return result
		if _generation == generation and _revision() == revision and _snapshot() == snapshot:
			_owner._settings = settings.duplicate(true)
			return _success({})
	return _failure(&"settings_audio_settlement_conflict")

func _recover(cause: Dictionary) -> Dictionary:
	invalidate_preview()
	var settled := _settle_latest()
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
	_busy = false
	return result

func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}

func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
