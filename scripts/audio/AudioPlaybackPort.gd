class_name AudioPlaybackPort
extends RefCounted

signal runtime_failure(channel_id: StringName, result: Dictionary)

var _root: Node
var _players: Dictionary = {}
var _tweens: Dictionary = {}
var _tween_specs: Dictionary = {}
var _bus_states: Dictionary = {}
var _pause_capture: Dictionary = {}
var _mono_effect: AudioEffectStereoEnhance


func ensure_bus(bus_name: StringName) -> Dictionary:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	_bus_states[bus_name] = {"db":AudioServer.get_bus_volume_db(index),"muted":AudioServer.is_bus_mute(index)}
	return _ok({"bus": bus_name})


func ensure_player(player_id: StringName, bus_name: StringName) -> Dictionary:
	if _players.has(player_id):
		return _ok({"player_id": player_id, "already_exists": true})
	_ensure_root()
	var player := AudioStreamPlayer.new()
	player.name = String(player_id)
	player.bus = bus_name
	_root.add_child(player)
	_players[player_id] = player
	return _ok({"player_id": player_id, "already_exists": false})


func load_stream(registered_path: String) -> Dictionary:
	if not ResourceLoader.exists(registered_path):
		return _failure(&"missing_audio")
	var stream := ResourceLoader.load(registered_path)
	if not stream is AudioStream:
		return _failure(&"missing_audio")
	return _ok(stream)


func assign_stream(player_id: StringName, stream: AudioStream) -> Dictionary:
	var player: AudioStreamPlayer = _players.get(player_id)
	if player == null or stream == null:
		return _failure(&"invalid_audio_runtime")
	player.stream = stream
	return _ok({})


func set_player_db(player_id: StringName, value_db: float) -> Dictionary:
	var player: AudioStreamPlayer = _players.get(player_id)
	if player == null:
		return _failure(&"invalid_audio_runtime")
	player.volume_db = value_db
	return _ok({})


func play(player_id: StringName) -> Dictionary:
	var player: AudioStreamPlayer = _players.get(player_id)
	if player == null:
		return _failure(&"invalid_audio_runtime")
	player.play()
	return _ok({})


func stop(player_id: StringName) -> Dictionary:
	var player: AudioStreamPlayer = _players.get(player_id)
	if player == null:
		return _failure(&"invalid_audio_runtime")
	player.stop()
	return _ok({})


func stop_and_clear(player_id: StringName) -> Dictionary:
	var player: AudioStreamPlayer = _players.get(player_id)
	if player == null:
		return _failure(&"invalid_audio_runtime")
	player.stop()
	player.stream = null
	return _ok({})


func kill_tween(channel_id: StringName) -> Dictionary:
	var tween: Tween = _tweens.get(channel_id)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(channel_id)
	_tween_specs.erase(channel_id)
	return _ok({})


func create_parallel_tween(channel_id: StringName, tracks: Array[Dictionary], duration: float) -> Dictionary:
	if duration <= 0.0:
		for track in tracks:
			var immediate := set_player_db(track["player_id"], float(track["to_db"]))
			if not immediate.get("ok", false):
				return immediate
			if track.get("stop_on_complete", false):
				var stopped := stop_and_clear(track["player_id"])
				if not stopped.get("ok", false):
					return stopped
		return _ok({"duration": 0.0})
	_ensure_root()
	var tween := _root.create_tween().set_parallel(true)
	for track in tracks:
		var player: AudioStreamPlayer = _players.get(track["player_id"])
		if player == null:
			return _failure(&"invalid_audio_runtime")
		player.volume_db = float(track.get("from_db", player.volume_db))
		tween.tween_property(player, "volume_db", float(track["to_db"]), duration)
	tween.chain().tween_callback(func() -> void: _complete_tween(channel_id))
	_tweens[channel_id] = tween
	_tween_specs[channel_id] = {"tracks": tracks.duplicate(true), "duration": duration}
	return _ok({"duration": duration})


## Freezes long-lived semantic playback without seeking or reconstructing it. Transient story
## players are stopped and deliberately are not part of the resume capsule; Pause UI remains on
## its separate, untouched pool.
func begin_pause_suspension(
		freeze_player_ids: Array[StringName], stop_player_ids: Array[StringName]
) -> Dictionary:
	if not _pause_capture.is_empty():
		return _failure(&"audio_suspended")
	var seen: Dictionary = {}
	for player_id: StringName in freeze_player_ids + stop_player_ids:
		if seen.has(player_id) or not _players.has(player_id) \
				or not is_instance_valid(_players[player_id]):
			return _failure(&"invalid_audio_runtime")
		seen[player_id] = true
	var capture := {"players": {}, "running_tweens": []}
	for player_id: StringName in freeze_player_ids:
		var player: AudioStreamPlayer = _players[player_id]
		var has_stream_playback := player.has_stream_playback()
		capture.players[player_id] = {
			"instance_id": player.get_instance_id(),
			"has_stream_playback": has_stream_playback,
			"stream": player.stream,
			"stream_playback": player.get_stream_playback() if has_stream_playback else null,
			"stream_paused": player.stream_paused,
		}
	for channel_value: Variant in _tweens.keys():
		var channel_id: StringName = channel_value
		var tween: Tween = _tweens[channel_id]
		if tween != null and tween.is_valid() and tween.is_running():
			(capture.running_tweens as Array).append(channel_id)

	for player_id: StringName in freeze_player_ids:
		var player: AudioStreamPlayer = _players[player_id]
		if bool(capture.players[player_id].has_stream_playback):
			player.stream_paused = true
			if not player.stream_paused:
				_restore_pause_capture(capture)
				return _failure(&"invalid_audio_runtime")
	for channel_id: StringName in capture.running_tweens:
		var tween: Tween = _tweens.get(channel_id)
		if tween == null or not tween.is_valid():
			_restore_pause_capture(capture)
			return _failure(&"invalid_audio_runtime")
		tween.pause()
		if tween.is_running():
			_restore_pause_capture(capture)
			return _failure(&"invalid_audio_runtime")
	# Do irreversible transient stops last, after every fallible reversible readback.
	for player_id: StringName in stop_player_ids:
		var player: AudioStreamPlayer = _players[player_id]
		player.stop()
		player.stream_paused = false
		if player.playing or player.stream_paused:
			_restore_pause_capture(capture)
			return _failure(&"invalid_audio_runtime")
	_pause_capture = capture
	return _ok({"suspended": true})


func resume_pause_suspension() -> Dictionary:
	if _pause_capture.is_empty():
		return _failure(&"invalid_suspension_handle")
	var capture := _pause_capture
	var resumed_players: Array[StringName] = []
	var resumed_tweens: Array[StringName] = []
	for player_value: Variant in capture.players.keys():
		var player_id: StringName = player_value
		var player: AudioStreamPlayer = _players.get(player_id)
		var prior: Dictionary = capture.players[player_id]
		if player == null or not is_instance_valid(player) \
				or player.get_instance_id() != int(prior.instance_id) \
				or player.stream != prior.stream \
				or player.has_stream_playback() != bool(prior.has_stream_playback) \
				or (bool(prior.has_stream_playback) \
						and player.get_stream_playback() != prior.stream_playback):
			_resuspend_pause_capture(capture, resumed_players, resumed_tweens)
			return _failure(&"invalid_audio_runtime")
		player.stream_paused = bool(prior.stream_paused)
		if player.stream_paused != bool(prior.stream_paused):
			_resuspend_pause_capture(capture, resumed_players, resumed_tweens)
			return _failure(&"invalid_audio_runtime")
		resumed_players.append(player_id)
	for channel_id: StringName in capture.running_tweens:
		var tween: Tween = _tweens.get(channel_id)
		if tween == null or not tween.is_valid():
			_resuspend_pause_capture(capture, resumed_players, resumed_tweens)
			return _failure(&"invalid_audio_runtime")
		tween.play()
		if not tween.is_running():
			_resuspend_pause_capture(capture, resumed_players, resumed_tweens)
			return _failure(&"invalid_audio_runtime")
		resumed_tweens.append(channel_id)
	_pause_capture = {}
	return _ok({"resumed": true})


func get_pause_suspension_state() -> Dictionary:
	return _ok({"state": &"Suspended" if not _pause_capture.is_empty() else &"Active"})


func _restore_pause_capture(capture: Dictionary) -> void:
	for player_value: Variant in capture.players.keys():
		var player_id: StringName = player_value
		var player: AudioStreamPlayer = _players.get(player_id)
		if player != null and is_instance_valid(player):
			player.stream_paused = bool(capture.players[player_id].stream_paused)
	for channel_id: StringName in capture.running_tweens:
		var tween: Tween = _tweens.get(channel_id)
		if tween != null and tween.is_valid() and not tween.is_running():
			tween.play()


func _resuspend_pause_capture(
		capture: Dictionary,
		resumed_players: Array[StringName],
		resumed_tweens: Array[StringName]
) -> void:
	for player_id: StringName in resumed_players:
		var player: AudioStreamPlayer = _players.get(player_id)
		if player != null and is_instance_valid(player) \
				and bool(capture.players[player_id].has_stream_playback):
			player.stream_paused = true
	for channel_id: StringName in resumed_tweens:
		var tween: Tween = _tweens.get(channel_id)
		if tween != null and tween.is_valid() and tween.is_running():
			tween.pause()


func _complete_tween(channel_id: StringName) -> void:
	var specification: Dictionary = _tween_specs.get(channel_id, {})
	for track: Dictionary in specification.get("tracks", []):
		if not track.get("stop_on_complete", false):
			continue
		var stopped := stop_and_clear(track["player_id"])
		if not stopped.get("ok", false):
			runtime_failure.emit(channel_id, stopped.duplicate(true))
			continue
	_tweens.erase(channel_id)
	_tween_specs.erase(channel_id)


func set_bus_state(bus_name: StringName, value_db: float, muted: bool) -> Dictionary:
	var ensured := ensure_bus(bus_name)
	if not ensured.get("ok", false):
		return ensured
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(index, value_db)
	AudioServer.set_bus_mute(index, muted)
	_bus_states[bus_name] = {"db": value_db, "muted": muted}
	return _ok({})


func set_output_mode(mode: String) -> Dictionary:
	if mode not in ["stereo","mono"]: return _failure(&"invalid_audio_output_mode")
	var ensured := ensure_bus(&"Master")
	if not ensured.ok: return ensured
	var bus := AudioServer.get_bus_index(&"Master")
	var index := _mono_effect_index(bus)
	if mode == "stereo" and index < 0: return _ok({"output_mode":mode})
	if _mono_effect == null:
		_mono_effect = AudioEffectStereoEnhance.new()
		_mono_effect.resource_name = "DWM owned mono output"
	# Godot 4.6 AudioEffectStereoEnhance: pan_pullout=0 downmixes stereo to mono.
	# https://docs.godotengine.org/en/4.6/classes/class_audioeffectstereoenhance.html
	_mono_effect.pan_pullout = 0.0
	_mono_effect.surround = 0.0
	_mono_effect.time_pullout_ms = 0.0
	if index < 0:
		AudioServer.add_bus_effect(bus,_mono_effect)
		index = _mono_effect_index(bus)
	if index < 0: return _failure(&"invalid_audio_runtime")
	AudioServer.set_bus_effect_enabled(bus,index,mode == "mono")
	return _ok({"output_mode":mode})


func _mono_effect_index(bus: int) -> int:
	if bus < 0 or _mono_effect == null: return -1
	for index in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus,index) == _mono_effect: return index
	return -1


func _capture_output_state() -> Dictionary:
	var bus := AudioServer.get_bus_index(&"Master")
	var index := _mono_effect_index(bus)
	return {"owner_id":get_instance_id(),"present":index >= 0,"index":index,
		"enabled":AudioServer.is_bus_effect_enabled(bus,index) if index >= 0 else false}


func _restore_output_state(state: Dictionary) -> Dictionary:
	if state.get("owner_id") != get_instance_id(): return _failure(&"invalid_audio_runtime")
	var bus := AudioServer.get_bus_index(&"Master")
	if bus < 0: return _failure(&"invalid_audio_runtime")
	var index := _mono_effect_index(bus)
	if not state.get("present",false):
		if index >= 0: AudioServer.remove_bus_effect(bus,index)
		return _ok({})
	if _mono_effect == null: return _failure(&"invalid_audio_runtime")
	if index < 0:
		AudioServer.add_bus_effect(bus,_mono_effect,mini(int(state.index),AudioServer.get_bus_effect_count(bus)))
		index = _mono_effect_index(bus)
	if index < 0: return _failure(&"invalid_audio_runtime")
	AudioServer.set_bus_effect_enabled(bus,index,bool(state.enabled))
	return _ok({})


func capture_runtime() -> Dictionary:
	ensure_bus(&"Master")
	for bus_name in _bus_states.keys():
		ensure_bus(bus_name)
	var players := {}
	for id in _players:
		var player: AudioStreamPlayer = _players[id]
		players[id] = {
			"stream": player.stream,
			"volume_db": player.volume_db,
			"playing": player.playing,
			"playback_position": player.get_playback_position(),
			"stream_paused": player.stream_paused,
			"bus": player.bus,
		}
	var transitions := {}
	for channel_id in _tween_specs:
		var tween: Tween = _tweens.get(channel_id)
		var specification: Dictionary = _tween_specs[channel_id]
		transitions[channel_id] = {
			"tracks": specification["tracks"].duplicate(true),
			"remaining": maxf(0.0, float(specification["duration"]) - (tween.get_total_elapsed_time() if tween != null and tween.is_valid() else 0.0)),
		}
	return _ok({"players": players, "bus_states": _bus_states.duplicate(true), "transitions": transitions, "output_state":_capture_output_state()})


func restore_runtime(backup: Dictionary) -> Dictionary:
	if backup.has("output_state"):
		var output_result := _restore_output_state(backup.output_state)
		if not output_result.ok: return output_result
	for channel_id in _tweens.keys():
		kill_tween(channel_id)
	for id in backup.get("players", {}):
		if not _players.has(id):
			continue
		var record: Dictionary = backup["players"][id]
		var player: AudioStreamPlayer = _players[id]
		player.stream = record.get("stream")
		player.volume_db = float(record.get("volume_db", 0.0))
		player.bus = record.get("bus", player.bus)
		if record.get("playing", false):
			player.play(float(record.get("playback_position", 0.0)))
		else:
			player.stop()
		player.stream_paused = bool(record.get("stream_paused", false))
	for bus_name in backup.get("bus_states", {}):
		var state: Dictionary = backup["bus_states"][bus_name]
		set_bus_state(bus_name, state["db"], state["muted"])
	for channel_id in backup.get("transitions", {}):
		var transition: Dictionary = backup["transitions"][channel_id]
		var tracks: Array[Dictionary] = transition["tracks"].duplicate(true)
		for track in tracks:
			var player: AudioStreamPlayer = _players.get(track["player_id"])
			if player != null:
				track["from_db"] = player.volume_db
		var recreated := create_parallel_tween(channel_id, tracks, float(transition["remaining"]))
		if not recreated.get("ok", false):
			return recreated
	return _ok({})


func _ensure_root() -> void:
	if is_instance_valid(_root):
		return
	_root = Node.new()
	_root.name = "AudioPlaybackRuntime"
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).root.add_child(_root)


func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
