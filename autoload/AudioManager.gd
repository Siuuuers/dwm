extends Node

const PLAYBACK_PORT := preload("res://scripts/audio/AudioPlaybackPort.gd")
const VOLUME_SILENCE_THRESHOLD := 0.0001
const SILENCE_DB := -80.0
const CHANNELS := {
	&"master": {"bus": &"Master", "volume": &"preferences.audio.master_volume", "muted": &"preferences.audio.master_muted"},
	&"music": {"bus": &"Music", "volume": &"preferences.audio.music_volume", "muted": &"preferences.audio.music_muted"},
	&"ambience": {"bus": &"Ambience", "volume": &"preferences.audio.ambience_volume", "muted": &"preferences.audio.ambience_muted"},
	&"sfx": {"bus": &"SFX", "volume": &"preferences.audio.sfx_volume", "muted": &"preferences.audio.sfx_muted"},
}
const AUDIO_DEFAULTS := {
	"master_volume":1.0,"master_muted":false,
	"music_volume":0.8,"music_muted":false,
	"ambience_volume":0.65,"ambience_muted":false,
	"sfx_volume":0.8,"sfx_muted":false,
	"mute_when_inactive":true,"output_mode":"stereo",
}
const MUSIC_PLAYERS: Array[StringName] = [&"MusicA", &"MusicB"]
const AMBIENCE_PLAYERS: Array[StringName] = [&"AmbienceA", &"AmbienceB"]
const SFX_PLAYERS: Array[StringName] = [&"SFX0", &"SFX1", &"SFX2", &"SFX3", &"SFX4", &"SFX5", &"SFX6", &"SFX7"]
const UI_PLAYERS: Array[StringName] = [&"UI0", &"UI1", &"UI2", &"UI3"]
const VOICE_PLAYERS: Array[StringName] = [&"Voice0", &"Voice1"]

signal music_context_changed(context_id: String, context: Dictionary)
signal ambience_context_changed(context_id: String, context: Dictionary)
signal sfx_requested(cue_id: String, receipt: Dictionary)
signal audio_settings_applied(settings: Dictionary)
signal audio_warning(result: Dictionary)

var _manifest := AudioManifest.new()
var _profile: Node
var _playback_port: RefCounted
var _mutation_gate: Object
var _initialized := false
var _fatal := false
var _focus_loss_mute := false
var _semantic := {
	"music_context_id": "", "music_context": {},
	"ambience_context_id": "", "ambience_context": {},
}
var _records := {&"music": {}, &"ambience": {}}
var _active_players := {&"music": &"MusicA", &"ambience": &"AmbienceA"}
var _settings := {}
var _pool_play_sequence := {&"SFX": {}, &"UI": {}, &"Voice": {}}
var _play_sequence := 0
var _restore_backup := {}
var _pause_handle: Dictionary = {}
var _pause_frontier_id := ""


func _init(playback_port: RefCounted = null) -> void:
	_playback_port = playback_port


func _ready() -> void:
	pass


func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _failure(&"invalid_mutation_gate")
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method):
			return _failure(&"invalid_mutation_gate")
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id():
		return _failure(&"mutation_gate_already_configured")
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}


func initialize(profile: Node) -> Dictionary:
	if _initialized:
		return _failure(&"already_initialized")
	if profile == null or not profile.has_method("get_preference"):
		return _failure(&"invalid_profile_manager")
	_profile = profile
	if _playback_port == null:
		_playback_port = PLAYBACK_PORT.new()
	for bus_name in [&"Master", &"Music", &"Ambience", &"SFX", &"UI", &"Voice"]:
		var bus_result: Dictionary = _playback_port.call(&"ensure_bus", bus_name)
		if not bus_result.get("ok", false):
			return bus_result
	for player_id in MUSIC_PLAYERS:
		var result: Dictionary = _playback_port.call(&"ensure_player", player_id, &"Music")
		if not result.get("ok", false):
			return result
	for player_id in AMBIENCE_PLAYERS:
		var result: Dictionary = _playback_port.call(&"ensure_player", player_id, &"Ambience")
		if not result.get("ok", false):
			return result
	for player_id in SFX_PLAYERS:
		var result: Dictionary = _playback_port.call(&"ensure_player", player_id, &"SFX")
		if not result.get("ok", false):
			return result
	for player_id in UI_PLAYERS:
		var result: Dictionary = _playback_port.call(&"ensure_player", player_id, &"UI")
		if not result.get("ok", false):
			return result
	for player_id in VOICE_PLAYERS:
		var result: Dictionary = _playback_port.call(&"ensure_player", player_id, &"Voice")
		if not result.get("ok", false):
			return result
	var applied := apply_profile_preferences()
	if not applied.get("ok", false):
		_profile = null
		return applied
	_initialized = true
	if profile.has_signal("preference_changed") and not profile.preference_changed.is_connected(_on_preference_changed):
		profile.preference_changed.connect(_on_preference_changed)
	if _playback_port.has_signal("runtime_failure") and not _playback_port.is_connected("runtime_failure", _on_port_runtime_failure):
		_playback_port.connect("runtime_failure", _on_port_runtime_failure)
	return applied


func set_music_context(context_id: String, context: Dictionary = {}) -> Dictionary:
	return _set_context(&"music", context_id, context, -1.0, false)


func set_ambience_context(context_id: String, context: Dictionary = {}) -> Dictionary:
	return _set_context(&"ambience", context_id, context, -1.0, false)


## Lifecycle suspension is transient process custody. It never enters the semantic audio snapshot.
func begin_suspend(handle: Dictionary) -> Dictionary:
	if not _valid_pause_handle(handle):
		return _lifecycle_failure(&"invalid_suspension_handle")
	if not _initialized:
		return _lifecycle_failure(&"not_initialized")
	if _fatal:
		return _lifecycle_failure(&"audio_runtime_indeterminate")
	if not _pause_handle.is_empty():
		if _pause_handle == handle:
			return _lifecycle_success({"frontier_id": _pause_frontier_id})
		return _lifecycle_failure(&"audio_suspended")
	if not _playback_port.has_method(&"begin_pause_suspension") \
			or not _playback_port.has_method(&"resume_pause_suspension") \
			or not _playback_port.has_method(&"get_pause_suspension_state"):
		return _lifecycle_failure(&"invalid_audio_runtime")
	var suspended: Variant = _playback_port.call(
		&"begin_pause_suspension", MUSIC_PLAYERS + AMBIENCE_PLAYERS,
		SFX_PLAYERS + VOICE_PLAYERS
	)
	if not _valid_port_pause_result(suspended, &"suspended") \
			or _port_pause_state() != &"Suspended":
		if not _prove_or_recover_port_active():
			_latch_consumer_fatal(&"pause_begin", _failure(&"audio_runtime_indeterminate"))
			return _lifecycle_failure(&"audio_runtime_indeterminate")
		return _lifecycle_failure(_port_failure_code(suspended, &"audio_suspend_failed"))
	_pause_handle = handle.duplicate(true)
	_pause_frontier_id = "audio:%s:%d" % [handle.handle_id, int(handle.generation)]
	return _lifecycle_success({"frontier_id": _pause_frontier_id})


func resume(handle: Dictionary) -> Dictionary:
	if not _valid_pause_handle(handle) or _pause_handle.is_empty() \
			or handle != _pause_handle:
		return _lifecycle_failure(&"invalid_suspension_handle")
	var resumed: Variant = _playback_port.call(&"resume_pause_suspension")
	if not _valid_port_pause_result(resumed, &"resumed") \
			or _port_pause_state() != &"Active":
		if not _prove_or_recover_port_suspended():
			_latch_consumer_fatal(&"pause_resume", _failure(&"audio_runtime_indeterminate"))
			return _lifecycle_failure(&"audio_runtime_indeterminate")
		return _lifecycle_failure(_port_failure_code(resumed, &"audio_resume_failed"))
	_pause_handle = {}
	_pause_frontier_id = ""
	return _lifecycle_success({"resumed": true})


func get_state() -> Dictionary:
	if _fatal:
		return _lifecycle_failure(&"audio_runtime_indeterminate")
	return _lifecycle_success({
		"state": &"Suspended" if not _pause_handle.is_empty() else &"Active",
	})


func play_sfx(cue_id: String, context: Dictionary = {}) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized")
	if _fatal:
		return _failure(&"audio_runtime_indeterminate")
	if not context.is_empty():
		return _failure(&"invalid_audio_context")
	var resolved := _manifest.get_cue(cue_id)
	if not resolved.get("ok", false):
		return resolved
	var record: Dictionary = resolved["value"]
	if not _pause_handle.is_empty() and record["bus"] != &"UI":
		return _failure(&"audio_suspended")
	var loaded: Dictionary = _playback_port.call(&"load_stream", record["path"])
	if not loaded.get("ok", false):
		return _warn_missing(cue_id)
	var captured: Dictionary = _playback_port.call(&"capture_runtime")
	if not captured.get("ok", false):
		return captured
	var bus: StringName = record["bus"]
	var pool: Array[StringName] = UI_PLAYERS if bus == &"UI" else SFX_PLAYERS
	var play_sequences: Dictionary = _pool_play_sequence[bus]
	var cursor := -1
	var captured_players: Dictionary = captured["value"].get("players", {})
	for index in range(pool.size()):
		if not bool(captured_players.get(pool[index], {}).get("playing", false)):
			cursor = index
			break
	if cursor < 0:
		var oldest_sequence := 9223372036854775807
		for index in range(pool.size()):
			var sequence := int(play_sequences.get(pool[index], 0))
			if sequence < oldest_sequence:
				oldest_sequence = sequence
				cursor = index
	var player_id := pool[cursor]
	for operation in [
		[&"stop", [player_id]],
		[&"assign_stream", [player_id, loaded["value"]]],
		[&"set_player_db", [player_id, 0.0]],
		[&"play", [player_id]],
	]:
		var result: Dictionary = _playback_port.callv(operation[0], operation[1])
		if not result.get("ok", false):
			var rollback: Dictionary = _playback_port.call(&"restore_runtime", captured["value"])
			if not rollback.get("ok", false):
				_latch_consumer_fatal(&"sfx_rollback", rollback)
				var fatal := _failure(&"audio_runtime_indeterminate")
				fatal["fatal"] = true
				return fatal
			return result
	_play_sequence += 1
	play_sequences[player_id] = _play_sequence
	var receipt := {"cue_id": cue_id, "bus": bus, "player_slot": cursor}
	sfx_requested.emit(cue_id, receipt.duplicate(true))
	return {"ok": true, "code": &"ok", "value": receipt.duplicate(true), "receipt": receipt.duplicate(true)}


func get_music_context_id() -> String:
	return _semantic["music_context_id"]


func get_ambience_context_id() -> String:
	return _semantic["ambience_context_id"]


func get_semantic_audio_context() -> Dictionary:
	return _semantic.duplicate(true)


func set_channel_volume(channel_id: StringName, linear: float) -> Dictionary:
	if not _initialized or _profile == null:
		return _failure(&"not_initialized")
	if not CHANNELS.has(channel_id) or not is_finite(linear):
		return _failure(&"invalid_audio_channel")
	return _profile.set_preference(CHANNELS[channel_id]["volume"], clampf(linear, 0.0, 1.0))


func set_channel_muted(channel_id: StringName, muted: bool) -> Dictionary:
	if not _initialized or _profile == null:
		return _failure(&"not_initialized")
	if not CHANNELS.has(channel_id):
		return _failure(&"invalid_audio_channel")
	return _profile.set_preference(CHANNELS[channel_id]["muted"], muted)


func apply_profile_preferences(changed_path: StringName = &"") -> Dictionary:
	if _profile == null:
		return _failure(&"not_initialized")
	if changed_path != &"" and not String(changed_path).begins_with("preferences.audio."):
		return {"ok": true, "code": &"ok", "value": _settings.duplicate(true), "receipt": {}, "unchanged": true}
	var audio := {}
	for key: String in AUDIO_DEFAULTS:
		audio[key] = _profile.get_preference(StringName("preferences.audio."+key),AUDIO_DEFAULTS[key])
	if not _valid_prepared_audio(audio): return _failure(&"invalid_audio_settings")
	var candidate := _settings_from_audio(audio)
	var applied := _apply_settings_silent(candidate)
	if not applied.get("ok", false):
		return applied
	_settings = candidate.duplicate(true)
	audio_settings_applied.emit(_settings.duplicate(true))
	return {"ok": true, "code": &"ok", "value": _settings.duplicate(true), "receipt": {}}


func prepare_semantic_restore(snapshot: Dictionary, prepared_profile: Dictionary) -> Dictionary:
	var validated := _validate_snapshot(snapshot)
	if not validated.get("ok", false):
		return validated
	var preferences: Dictionary = prepared_profile.get("preferences", prepared_profile)
	var audio: Dictionary = preferences.get("audio", {})
	if not _valid_prepared_audio(audio):
		return _failure(&"invalid_restore_plan")
	if not _supports_output_mode(audio.output_mode): return _failure(&"unsupported_audio_output_mode")
	return {"ok": true, "code": &"ok", "value": {"snapshot": snapshot.duplicate(true), "audio": audio.duplicate(true)}, "receipt": {}}


func capture_restore_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"snapshot": _semantic.duplicate(true), "settings": _settings.duplicate(true)}, "receipt": {}}


func apply_restore_silent(plan: Dictionary) -> Dictionary:
	var snapshot: Variant = plan.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _failure(&"invalid_restore_plan")
	var validated := _validate_snapshot(snapshot)
	if not validated.get("ok", false):
		return validated
	var audio_value: Variant = plan.get("audio", {})
	if not audio_value is Dictionary: return _failure(&"invalid_restore_plan")
	var audio: Dictionary = audio_value
	if not audio.is_empty():
		if not _valid_prepared_audio(audio): return _failure(&"invalid_restore_plan")
		if not _supports_output_mode(audio.output_mode): return _failure(&"unsupported_audio_output_mode")
	_restore_backup = capture_restore_state()["value"].duplicate(true)
	var music := _set_context(&"music", snapshot["music_context_id"], snapshot["music_context"], 0.0, true, true)
	if not music.get("ok", false):
		return music
	var ambience := _set_context(&"ambience", snapshot["ambience_context_id"], snapshot["ambience_context"], 0.0, true, true)
	if not ambience.get("ok", false):
		return ambience
	if not audio.is_empty():
		var candidate := _settings_from_audio(audio)
		var settings_result := _apply_settings_silent(candidate)
		if not settings_result.get("ok", false):
			return settings_result
		_settings = candidate
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var source: Dictionary = backup if not backup.is_empty() else _restore_backup
	if not source.has("snapshot") or not source.has("settings"):
		return _failure(&"invalid_restore_backup")
	var snapshot: Dictionary = source["snapshot"]
	var settings_result := _apply_settings_silent(source["settings"])
	if not settings_result.get("ok", false):
		return settings_result
	_settings = source["settings"].duplicate(true)
	var ambience := _set_context(&"ambience", snapshot["ambience_context_id"], snapshot["ambience_context"], 0.0, true, true)
	if not ambience.get("ok", false):
		return ambience
	var music := _set_context(&"music", snapshot["music_context_id"], snapshot["music_context"], 0.0, true, true)
	if not music.get("ok", false):
		return music
	_restore_backup = {}
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func finalize_restore() -> Dictionary:
	_restore_backup = {}
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func get_missing_audio_report() -> Array:
	return _manifest.get_missing_audio_paths()


func _notification(what: int) -> void:
	if not _initialized: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_loss_mute = true
		_apply_settings_silent(_settings)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _focus_loss_mute:
		_focus_loss_mute = false
		_apply_settings_silent(_settings)


func _set_context(channel_id: StringName, context_id: String, context: Dictionary, duration_override: float, silent: bool, force_restart: bool = false) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized")
	if _fatal:
		return _failure(&"audio_runtime_indeterminate")
	if not _pause_handle.is_empty():
		return _failure(&"audio_suspended")
	if context_id.is_empty():
		if not context.is_empty():
			return _failure(&"invalid_audio_snapshot")
		return _clear_channel(channel_id, silent)
	var resolved: Dictionary = _manifest.resolve_music_context(context_id, context) if channel_id == &"music" else _manifest.resolve_ambience_context(context_id, context)
	if not resolved.get("ok", false):
		return resolved
	var record: Dictionary = resolved["value"]
	var id_key := "%s_context_id" % channel_id
	var context_key := "%s_context" % channel_id
	if not force_restart and _semantic[id_key] == context_id and _semantic[context_key] == context and _records[channel_id].get("path", "") == record["path"]:
		return {"ok": true, "code": &"ok", "value": _semantic.duplicate(true), "receipt": {}, "unchanged": true}
	var loaded: Dictionary = _playback_port.call(&"load_stream", record["path"])
	if not loaded.get("ok", false):
		return _warn_missing(context_id)
	var captured: Dictionary = _playback_port.call(&"capture_runtime")
	if not captured.get("ok", false):
		return captured
	var prior_semantic := _semantic.duplicate(true)
	var prior_record: Dictionary = _records[channel_id].duplicate(true)
	var old_player: StringName = _active_players[channel_id]
	var players := MUSIC_PLAYERS if channel_id == &"music" else AMBIENCE_PLAYERS
	var new_player: StringName = players[1] if old_player == players[0] else players[0]
	var target_db := _channel_db(channel_id)
	var duration := duration_override if duration_override >= 0.0 else maxf(float(prior_record.get("fade_out_seconds", 0.0)), float(record["fade_in_seconds"]))
	var operations: Array = [
		[&"kill_tween", [channel_id]],
		[&"assign_stream", [new_player, loaded["value"]]],
		[&"set_player_db", [new_player, SILENCE_DB]],
		[&"play", [new_player]],
	]
	for operation in operations:
		var result: Dictionary = _playback_port.callv(operation[0], operation[1])
		if not result.get("ok", false):
			return _rollback_failed_context(channel_id, captured["value"], prior_semantic, result)
	if duration <= 0.0:
		for operation in [
			[&"set_player_db", [new_player, target_db]],
			[&"set_player_db", [old_player, SILENCE_DB]],
			[&"stop_and_clear", [old_player]],
		]:
			var result: Dictionary = _playback_port.callv(operation[0], operation[1])
			if not result.get("ok", false):
				return _rollback_failed_context(channel_id, captured["value"], prior_semantic, result)
	else:
		var captured_players: Dictionary = captured["value"].get("players", {})
		var old_from_db := float(captured_players.get(old_player, {}).get("volume_db", target_db))
		var tracks: Array[Dictionary] = [
			{"player_id": new_player, "from_db": SILENCE_DB, "to_db": target_db},
			{"player_id": old_player, "from_db": old_from_db, "to_db": SILENCE_DB, "stop_on_complete": true},
		]
		var tweened: Dictionary = _playback_port.call(&"create_parallel_tween", channel_id, tracks, duration)
		if not tweened.get("ok", false):
			return _rollback_failed_context(channel_id, captured["value"], prior_semantic, tweened)
	_active_players[channel_id] = new_player
	_records[channel_id] = record.duplicate(true)
	_semantic[id_key] = context_id
	_semantic[context_key] = context.duplicate(true)
	if not silent:
		if channel_id == &"music":
			music_context_changed.emit(context_id, context.duplicate(true))
		else:
			ambience_context_changed.emit(context_id, context.duplicate(true))
	return {"ok": true, "code": &"ok", "value": _semantic.duplicate(true), "receipt": {}}


func _clear_channel(channel_id: StringName, silent: bool) -> Dictionary:
	var captured: Dictionary = _playback_port.call(&"capture_runtime")
	if not captured.get("ok", false):
		return captured
	var prior_semantic := _semantic.duplicate(true)
	var players := MUSIC_PLAYERS if channel_id == &"music" else AMBIENCE_PLAYERS
	var operations: Array = [[&"kill_tween", [channel_id]]]
	for player_id in players:
		operations.append([&"set_player_db", [player_id, SILENCE_DB]])
		operations.append([&"stop_and_clear", [player_id]])
	for operation in operations:
		var result: Dictionary = _playback_port.callv(operation[0], operation[1])
		if not result.get("ok", false):
			return _rollback_failed_context(channel_id, captured["value"], prior_semantic, result)
	var id_key := "%s_context_id" % channel_id
	var context_key := "%s_context" % channel_id
	_semantic[id_key] = ""
	_semantic[context_key] = {}
	_records[channel_id] = {}
	if not silent:
		if channel_id == &"music":
			music_context_changed.emit("", {})
		else:
			ambience_context_changed.emit("", {})
	return {"ok": true, "code": &"ok", "value": _semantic.duplicate(true), "receipt": {}}


func _rollback_failed_context(channel_id: StringName, backup: Dictionary, prior_semantic: Dictionary, cause: Dictionary) -> Dictionary:
	var rollback: Dictionary = _playback_port.call(&"restore_runtime", backup.duplicate(true))
	_semantic = prior_semantic.duplicate(true)
	if not rollback.get("ok", false):
		_playback_port.call(&"kill_tween", channel_id)
		var players := MUSIC_PLAYERS if channel_id == &"music" else AMBIENCE_PLAYERS
		for player_id in players:
			_playback_port.call(&"stop", player_id)
		var bus_name: StringName = CHANNELS[channel_id]["bus"]
		_playback_port.call(&"set_bus_state", bus_name, SILENCE_DB, true)
		_latch_consumer_fatal(&"context_rollback", rollback)
		var fatal := _failure(&"audio_runtime_indeterminate")
		fatal["fatal"] = true
		return fatal
	return cause.duplicate(true)


func _apply_settings_silent(candidate: Dictionary) -> Dictionary:
	var output_mode: String = candidate.get(&"output_mode", "stereo")
	if not _supports_output_mode(output_mode): return _failure(&"unsupported_audio_output_mode")
	var captured: Dictionary = _playback_port.call(&"capture_runtime")
	if not captured.get("ok", false):
		return captured
	if _playback_port.has_method(&"set_output_mode"):
		var output_result: Dictionary = _playback_port.call(&"set_output_mode",output_mode)
		if not output_result.get("ok",false): return _rollback_settings(captured["value"],output_result)
	for channel_id in CHANNELS:
		var setting: Dictionary = candidate.get(channel_id, {})
		if setting.is_empty():
			return _failure(&"invalid_audio_settings")
		var linear := clampf(float(setting["volume"]), 0.0, 1.0)
		var muted := bool(setting["muted"]) or linear <= VOLUME_SILENCE_THRESHOLD or (_focus_loss_mute and bool(candidate.get(&"mute_when_inactive",true)))
		var db := SILENCE_DB if linear <= VOLUME_SILENCE_THRESHOLD else linear_to_db(linear)
		var bus_name: StringName = CHANNELS[channel_id]["bus"]
		var applied: Dictionary = _playback_port.call(&"set_bus_state", bus_name, db, muted)
		if not applied.get("ok", false):
			return _rollback_settings(captured["value"], applied)
		if channel_id == &"sfx":
			var ui_applied: Dictionary = _playback_port.call(&"set_bus_state", &"UI", db, muted)
			if not ui_applied.get("ok", false):
				return _rollback_settings(captured["value"], ui_applied)
	return {"ok": true, "code": &"ok", "value": candidate.duplicate(true), "receipt": {}}


func _rollback_settings(backup: Dictionary, cause: Dictionary) -> Dictionary:
	var rollback: Dictionary = _playback_port.call(&"restore_runtime", backup.duplicate(true))
	if rollback.get("ok", false):
		return cause.duplicate(true)
	_latch_consumer_fatal(&"settings_rollback", rollback)
	var fatal := _failure(&"audio_runtime_indeterminate")
	fatal["fatal"] = true
	return fatal


func _channel_db(channel_id: StringName) -> float:
	var linear := float(_settings.get(channel_id, {}).get("volume", 1.0))
	return SILENCE_DB if linear <= VOLUME_SILENCE_THRESHOLD else linear_to_db(linear)


func _validate_snapshot(snapshot: Dictionary) -> Dictionary:
	var exact := ["ambience_context", "ambience_context_id", "music_context", "music_context_id"]
	var keys: Array = snapshot.keys()
	keys.sort()
	if keys != exact:
		return _failure(&"invalid_audio_snapshot")
	if typeof(snapshot["music_context_id"]) != TYPE_STRING or typeof(snapshot["ambience_context_id"]) != TYPE_STRING or typeof(snapshot["music_context"]) != TYPE_DICTIONARY or typeof(snapshot["ambience_context"]) != TYPE_DICTIONARY:
		return _failure(&"invalid_audio_snapshot")
	if snapshot["music_context_id"].is_empty() and not snapshot["music_context"].is_empty():
		return _failure(&"invalid_audio_snapshot")
	if snapshot["ambience_context_id"].is_empty() and not snapshot["ambience_context"].is_empty():
		return _failure(&"invalid_audio_snapshot")
	if not snapshot["music_context_id"].is_empty() and not _manifest.resolve_music_context(snapshot["music_context_id"], snapshot["music_context"]).get("ok", false):
		return _failure(&"invalid_audio_snapshot")
	if not snapshot["ambience_context_id"].is_empty() and not _manifest.resolve_ambience_context(snapshot["ambience_context_id"], snapshot["ambience_context"]).get("ok", false):
		return _failure(&"invalid_audio_snapshot")
	return {"ok": true, "code": &"ok", "value": snapshot.duplicate(true), "receipt": {}}


func _settings_from_audio(audio: Dictionary) -> Dictionary:
	var result := {}
	for channel_id in CHANNELS:
		result[channel_id] = {"volume":audio[String(channel_id)+"_volume"],"muted":audio[String(channel_id)+"_muted"]}
	result[&"mute_when_inactive"] = audio.mute_when_inactive
	result[&"output_mode"] = audio.output_mode
	return result


func _supports_output_mode(mode: String) -> bool:
	return mode == "stereo" or (mode == "mono" and _playback_port != null and _playback_port.has_method(&"set_output_mode"))


func _valid_prepared_audio(audio: Dictionary) -> bool:
	if audio.size() != AUDIO_DEFAULTS.size(): return false
	for key: String in AUDIO_DEFAULTS:
		if not audio.has(key): return false
	for channel_id in ["master","music","ambience","sfx"]:
		var volume: Variant = audio[channel_id+"_volume"]
		if typeof(volume) != TYPE_FLOAT or not is_finite(volume) or volume < 0.0 or volume > 1.0:
			return false
		if typeof(audio[channel_id+"_muted"]) != TYPE_BOOL: return false
	return (typeof(audio.mute_when_inactive) == TYPE_BOOL
		and typeof(audio.output_mode) == TYPE_STRING and audio.output_mode in ["stereo","mono"])


func _warn_missing(semantic_id: String) -> Dictionary:
	var result := _failure(&"missing_audio")
	result["semantic_id"] = semantic_id
	audio_warning.emit(result.duplicate(true))
	return result


func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if String(path).begins_with("preferences.audio."):
		var applied := apply_profile_preferences(path)
		if not applied.get("ok", false):
			_latch_consumer_fatal(&"committed_preference_apply", applied)


func _on_port_runtime_failure(channel_id: StringName, result: Dictionary) -> void:
	_latch_consumer_fatal(&"playback_completion", {"code": result.get("code", &"audio_runtime_failure"), "channel_id": channel_id, "details": result.duplicate(true)})


func _latch_consumer_fatal(phase: StringName, result: Dictionary) -> void:
	_fatal = true
	var failure := {
		"source": "AudioManager",
		"phase": String(phase),
		"code": String(result.get("code", &"audio_consumer_failure")),
		"details": result.duplicate(true),
	}
	if _mutation_gate != null:
		_mutation_gate.call(&"latch_fatal", failure.duplicate(true))
	var warning := _failure(&"audio_runtime_indeterminate")
	warning["fatal"] = true
	warning["details"] = failure.duplicate(true)
	audio_warning.emit(warning.duplicate(true))


func _valid_pause_handle(handle: Dictionary) -> bool:
	var keys: Array = handle.keys()
	keys.sort()
	return keys == ["generation", "handle_id", "holder", "reason"] \
			and typeof(handle.generation) == TYPE_INT and int(handle.generation) > 0 \
			and typeof(handle.handle_id) == TYPE_STRING \
			and not str(handle.handle_id).is_empty() \
			and str(handle.handle_id) == str(handle.handle_id).strip_edges() \
			and typeof(handle.holder) == TYPE_STRING_NAME \
			and not String(handle.holder).is_empty() \
			and String(handle.holder) == String(handle.holder).strip_edges() \
			and typeof(handle.reason) == TYPE_STRING_NAME \
			and handle.reason == &"universal_pause"


func _valid_port_pause_result(result: Variant, member: StringName) -> bool:
	var key := String(member)
	return typeof(result) == TYPE_DICTIONARY \
			and typeof(result.get("ok")) == TYPE_BOOL and result.ok \
			and result.get("code") == &"ok" \
			and typeof(result.get("value")) == TYPE_DICTIONARY \
			and result.value.size() == 1 and typeof(result.value.get(key)) == TYPE_BOOL \
			and bool(result.value[key])


func _port_pause_state() -> StringName:
	var state: Variant = _playback_port.call(&"get_pause_suspension_state")
	if typeof(state) != TYPE_DICTIONARY \
			or typeof(state.get("ok")) != TYPE_BOOL or not state.ok \
			or state.get("code") != &"ok" \
			or typeof(state.get("value")) != TYPE_DICTIONARY \
			or state.value.size() != 1 \
			or typeof(state.value.get("state")) != TYPE_STRING_NAME \
			or state.value.state not in [&"Active", &"Suspended"]:
		return &""
	return state.value.state


func _port_failure_code(result: Variant, fallback: StringName) -> StringName:
	if typeof(result) != TYPE_DICTIONARY or result.get("ok", true) \
			or typeof(result.get("code")) != TYPE_STRING_NAME \
			or String(result.code).is_empty():
		return fallback
	return result.code


func _prove_or_recover_port_active() -> bool:
	var state := _port_pause_state()
	if state == &"Active":
		return true
	if state != &"Suspended":
		return false
	var recovered: Variant = _playback_port.call(&"resume_pause_suspension")
	return _valid_port_pause_result(recovered, &"resumed") \
			and _port_pause_state() == &"Active"


func _prove_or_recover_port_suspended() -> bool:
	var state := _port_pause_state()
	if state == &"Suspended":
		return true
	if state != &"Active":
		return false
	var recovered: Variant = _playback_port.call(
		&"begin_pause_suspension", MUSIC_PLAYERS + AMBIENCE_PLAYERS,
		SFX_PLAYERS + VOICE_PLAYERS
	)
	return _valid_port_pause_result(recovered, &"suspended") \
			and _port_pause_state() == &"Suspended"


func _lifecycle_success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value.duplicate(true)}


func _lifecycle_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": null}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
