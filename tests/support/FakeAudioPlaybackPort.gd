class_name FakeAudioPlaybackPort
extends RefCounted

signal runtime_failure(channel_id: StringName, result: Dictionary)

var operations: Array[Dictionary] = []
var players: Dictionary = {}
var bus_states: Dictionary = {}
var active_tweens: Dictionary = {}
var _fail_ordinal := -1
var _fail_ordinals: Array[int] = []


func fail_after(ordinal: int) -> void:
	_fail_ordinal = ordinal


func fail_on(ordinals: Array[int]) -> void:
	_fail_ordinals = ordinals.duplicate()


func ensure_bus(bus_name: StringName) -> Dictionary:
	return _record(&"ensure_bus", {"bus_name": bus_name}, {})


func ensure_player(player_id: StringName, bus_name: StringName) -> Dictionary:
	players[player_id] = {"bus": bus_name, "stream": null, "db": 0.0, "playing": false}
	return _record(&"ensure_player", {"player_id": player_id, "bus_name": bus_name}, {})


func load_stream(registered_path: String) -> Dictionary:
	var stream := AudioStreamGenerator.new()
	var result := _record(&"load_stream", {"registered_path": registered_path}, stream)
	return result


func assign_stream(player_id: StringName, stream: AudioStream) -> Dictionary:
	if players.has(player_id):
		players[player_id]["stream"] = stream
	return _record(&"assign_stream", {"player_id": player_id, "stream": stream}, {})


func set_player_db(player_id: StringName, value_db: float) -> Dictionary:
	if players.has(player_id):
		players[player_id]["db"] = value_db
	return _record(&"set_player_db", {"player_id": player_id, "value_db": value_db}, {})


func play(player_id: StringName) -> Dictionary:
	if players.has(player_id):
		players[player_id]["playing"] = true
	return _record(&"play", {"player_id": player_id}, {})


func stop(player_id: StringName) -> Dictionary:
	if players.has(player_id):
		players[player_id]["playing"] = false
	return _record(&"stop", {"player_id": player_id}, {})


func stop_and_clear(player_id: StringName) -> Dictionary:
	var result := _record(&"stop_and_clear", {"player_id": player_id}, {})
	if result.get("ok", false) and players.has(player_id):
		players[player_id]["playing"] = false
		players[player_id]["stream"] = null
	return result


func kill_tween(channel_id: StringName) -> Dictionary:
	active_tweens.erase(channel_id)
	return _record(&"kill_tween", {"channel_id": channel_id}, {})


func create_parallel_tween(channel_id: StringName, tracks: Array[Dictionary], duration: float) -> Dictionary:
	var result := _record(&"create_parallel_tween", {"channel_id": channel_id, "tracks": tracks.duplicate(true), "duration": duration}, {})
	if result.get("ok", false):
		active_tweens[channel_id] = {"tracks": tracks.duplicate(true), "duration": duration}
	return result


func complete_tween(channel_id: StringName) -> Dictionary:
	var specification: Dictionary = active_tweens.get(channel_id, {})
	for track: Dictionary in specification.get("tracks", []):
		if players.has(track["player_id"]):
			players[track["player_id"]]["db"] = track["to_db"]
		if track.get("stop_on_complete", false):
			var stopped := stop_and_clear(track["player_id"])
			if not stopped.get("ok", false):
				runtime_failure.emit(channel_id, stopped.duplicate(true))
				return stopped
	active_tweens.erase(channel_id)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func set_bus_state(bus_name: StringName, value_db: float, muted: bool) -> Dictionary:
	bus_states[bus_name] = {"db": value_db, "muted": muted}
	return _record(&"set_bus_state", {"bus_name": bus_name, "value_db": value_db, "muted": muted}, {})


func capture_runtime() -> Dictionary:
	return _record(&"capture_runtime", {}, {"players": players.duplicate(true), "bus_states": bus_states.duplicate(true), "transitions": active_tweens.duplicate(true)})


func restore_runtime(backup: Dictionary) -> Dictionary:
	players = backup.get("players", {}).duplicate(true)
	bus_states = backup.get("bus_states", {}).duplicate(true)
	active_tweens = backup.get("transitions", {}).duplicate(true)
	return _record(&"restore_runtime", {"backup": backup.duplicate(true)}, {})


func _record(operation: StringName, arguments: Dictionary, value: Variant) -> Dictionary:
	operations.append({"operation": operation, "arguments": arguments.duplicate(true)})
	if (_fail_ordinal > 0 and operations.size() == _fail_ordinal) or operations.size() in _fail_ordinals:
		return {"ok": false, "code": &"injected_audio_failure", "details": {}, "receipt": {}}
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}
