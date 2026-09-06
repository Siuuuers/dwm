class_name FakeAudioPlaybackPort
extends RefCounted

signal runtime_failure(channel_id: StringName, result: Dictionary)

var operations: Array[Dictionary] = []
var players: Dictionary = {}
var bus_states: Dictionary = {}
var active_tweens: Dictionary = {}
var output_mode := "stereo"
var _owned_mono_present := false
var _owned_mono_created := false
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

func set_output_mode(mode: String) -> Dictionary:
	if mode not in ["stereo", "mono"]: return _output_failure(&"invalid_audio_output_mode")
	var result := _record(&"set_output_mode", {"mode": mode}, {"output_mode": mode})
	if result.get("ok", false):
		output_mode = mode
		_owned_mono_present = _owned_mono_present or mode == "mono"
		_owned_mono_created = _owned_mono_created or mode == "mono"
	return result


func capture_output() -> Dictionary:
	var buses := bus_states.duplicate(true)
	if not buses.has(&"Master"): buses[&"Master"] = {"db": 0.0, "muted": false}
	if not _valid_output_buses(buses) or output_mode not in ["stereo", "mono"] \
			or (output_mode == "mono" and not _owned_mono_present): return _output_failure()
	return _record(&"capture_output", {}, {"bus_states": buses, "output_state": {
		"owner_id": get_instance_id(), "present": _owned_mono_present,
		"index": 0 if _owned_mono_present else -1, "enabled": output_mode == "mono",
	}})


func restore_output(snapshot: Dictionary) -> Dictionary:
	if snapshot.size() != 2 or not snapshot.has_all(["bus_states", "output_state"]) \
			or typeof(snapshot.bus_states) != TYPE_DICTIONARY or typeof(snapshot.output_state) != TYPE_DICTIONARY \
			or not _valid_output_buses(snapshot.bus_states): return _output_failure()
	var state: Dictionary = snapshot.output_state
	if state.size() != 4 or not state.has_all(["owner_id", "present", "index", "enabled"]) \
			or typeof(state.owner_id) != TYPE_INT or state.owner_id != get_instance_id() \
			or typeof(state.present) != TYPE_BOOL or typeof(state.index) != TYPE_INT \
			or typeof(state.enabled) != TYPE_BOOL \
			or (state.present and (state.index != 0 or not _owned_mono_created)) \
			or (not state.present and (state.index != -1 or state.enabled)): return _output_failure()
	var names: Array = bus_states.keys()
	if &"Master" not in names: names.append(&"Master")
	if snapshot.bus_states.size() != names.size(): return _output_failure()
	for name: Variant in names:
		if not snapshot.bus_states.has(name): return _output_failure()
	var result := _record(&"restore_output", {"snapshot": snapshot.duplicate(true)}, {})
	if not result.get("ok", false): return result
	var mode := "mono" if state.enabled else "stereo"
	var output := set_output_mode(mode)
	if not output.get("ok", false): return output
	_owned_mono_present = state.present
	for name: Variant in snapshot.bus_states:
		var applied := set_bus_state(name, snapshot.bus_states[name].db, snapshot.bus_states[name].muted)
		if not applied.get("ok", false): return applied
	if not output_matches(snapshot.bus_states, mode) or _owned_mono_present != state.present:
		return _output_failure(&"audio_output_restore_unproven")
	return result


func output_matches(expected_bus_states: Dictionary, mode: String) -> bool:
	if mode not in ["stereo", "mono"] or not _valid_output_buses(expected_bus_states): return false
	for name: Variant in expected_bus_states:
		var actual: Dictionary = bus_states.get(name, {"db": 0.0, "muted": false})
		var expected: Dictionary = expected_bus_states[name]
		if not is_equal_approx(actual.db, expected.db) or actual.muted != expected.muted: return false
	return output_mode == mode and (mode != "mono" or _owned_mono_present)


func _valid_output_buses(buses: Dictionary) -> bool:
	if buses.is_empty(): return false
	for name: Variant in buses:
		if typeof(name) not in [TYPE_STRING, TYPE_STRING_NAME] \
				or (name != &"Master" and not bus_states.has(name)): return false
		var state: Variant = buses[name]
		if typeof(state) != TYPE_DICTIONARY or state.size() != 2 or not state.has_all(["db", "muted"]) \
				or typeof(state.db) != TYPE_FLOAT or not is_finite(state.db) or typeof(state.muted) != TYPE_BOOL: return false
	return true


func _output_failure(code: StringName = &"invalid_audio_runtime") -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}


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
