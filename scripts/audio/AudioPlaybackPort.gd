class_name AudioPlaybackPort
extends RefCounted

signal runtime_failure(channel_id: StringName, result: Dictionary)

var _root: Node
var _players: Dictionary = {}
var _tweens: Dictionary = {}
var _tween_specs: Dictionary = {}
var _bus_states: Dictionary = {}


func ensure_bus(bus_name: StringName) -> Dictionary:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
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


func capture_runtime() -> Dictionary:
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
	return _ok({"players": players, "bus_states": _bus_states.duplicate(true), "transitions": transitions})


func restore_runtime(backup: Dictionary) -> Dictionary:
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
