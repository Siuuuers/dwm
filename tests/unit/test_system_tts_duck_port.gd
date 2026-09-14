extends GutTest

const PORT_PATH := "res://scripts/audio/SystemTtsDuckPort.gd"
const GAME_BUSES: Array[StringName] = [&"Music", &"Ambience", &"SFX", &"UI", &"Voice"]


class AudioBackend extends RefCounted:
	var buses: Array[Dictionary] = []
	var ignore_mix_volume_writes := false
	var bus_count: int:
		get: return buses.size()

	func _init() -> void:
		buses.append({"name": &"Master", "send": &"", "db": -2.0, "muted": false})
		for index: int in GAME_BUSES.size():
			buses.append({"name": GAME_BUSES[index], "send": &"Master",
				"db": -3.0 - index, "muted": index == 2})

	func get_bus_index(name: StringName) -> int:
		for index: int in buses.size():
			if buses[index].name == name: return index
		return -1

	func add_bus(index: int = -1) -> void:
		var record := {"name": &"", "send": &"Master", "db": 0.0, "muted": false}
		if index < 0 or index >= buses.size(): buses.append(record)
		else: buses.insert(index, record)

	func remove_bus(index: int) -> void: buses.remove_at(index)
	func get_bus_name(index: int) -> StringName: return buses[index].name
	func set_bus_name(index: int, name: StringName) -> void: buses[index].name = name
	func get_bus_send(index: int) -> StringName: return buses[index].send
	func set_bus_send(index: int, send: StringName) -> void: buses[index].send = send
	func get_bus_volume_db(index: int) -> float: return buses[index].db
	func set_bus_volume_db(index: int, db: float) -> void:
		if ignore_mix_volume_writes and buses[index].name == &"Game Mix": return
		buses[index].db = db
	func is_bus_mute(index: int) -> bool: return buses[index].muted


class TransitionBackend extends RefCounted:
	var calls: Array[Dictionary] = []
	var canceled := 0
	var complete_synchronously := false
	var _completion := Callable()

	func start(from_db: float, to_db: float, duration: float, completion: Callable) -> void:
		calls.append({"from_db": from_db, "to_db": to_db, "duration": duration})
		if complete_synchronously:
			completion.call()
			return
		_completion = completion

	func cancel() -> void:
		canceled += 1
		_completion = Callable()

	func complete() -> void:
		var completion := _completion
		_completion = Callable()
		if completion.is_valid(): completion.call()


var _async_results: Dictionary = {}


func before_each() -> void:
	_async_results.clear()


func _port(audio: AudioBackend, transitions: TransitionBackend) -> Node:
	if not ResourceLoader.exists(PORT_PATH, "Script"): return null
	var port: Node = load(PORT_PATH).new(audio, transitions)
	add_child_autofree(port)
	return port


func _begin_async(port: Node, token: int, key: StringName) -> void:
	_async_results[key] = await port.begin(token)


func _finish_async(port: Node, token: int, key: StringName) -> void:
	_async_results[key] = await port.finish(token)


func test_system_tts_duck_port_contract_exists() -> void:
	assert_true(ResourceLoader.exists(PORT_PATH, "Script"),
		"the transient Game Mix duck owner must exist")


func test_begin_routes_uniform_game_mix_and_finish_uses_accepted_fades() -> void:
	var audio := AudioBackend.new()
	var transitions := TransitionBackend.new()
	var original := audio.buses.duplicate(true)
	var port := _port(audio, transitions)
	if port == null: return
	_begin_async(port, 11, &"begin")
	assert_eq(audio.get_bus_index(&"Game Mix"), 1)
	assert_eq(audio.get_bus_send(1), &"Master")
	for index: int in GAME_BUSES.size():
		var bus := audio.get_bus_index(GAME_BUSES[index])
		assert_eq(audio.get_bus_send(bus), &"Game Mix")
		assert_eq(audio.get_bus_volume_db(bus), original[index + 1].db)
		assert_eq(audio.is_bus_mute(bus), original[index + 1].muted)
	assert_eq(transitions.calls, [{"from_db": 0.0, "to_db": -12.0,
		"duration": 0.12}])
	transitions.complete()
	await get_tree().process_frame
	assert_true(_async_results.begin.get("ok", false), str(_async_results))
	assert_eq(audio.get_bus_volume_db(1), -12.0)
	_finish_async(port, 11, &"finish")
	assert_eq(transitions.calls[-1], {"from_db": -12.0, "to_db": 0.0,
		"duration": 0.18})
	transitions.complete()
	await get_tree().process_frame
	assert_true(_async_results.finish.get("ok", false), str(_async_results))
	assert_eq(audio.get_bus_volume_db(1), 0.0)


func test_superseding_begin_resolves_recovery_and_stale_finish_cannot_unduck() -> void:
	var audio := AudioBackend.new()
	var transitions := TransitionBackend.new()
	var port := _port(audio, transitions)
	if port == null: return
	_begin_async(port, 21, &"first")
	transitions.complete()
	await get_tree().process_frame
	_finish_async(port, 21, &"old_finish")
	_begin_async(port, 22, &"successor")
	await get_tree().process_frame
	assert_false(_async_results.old_finish.get("ok", true),
		"a canceled recovery awaiter settles as superseded")
	assert_eq(transitions.calls[-1].to_db, -12.0)
	transitions.complete()
	await get_tree().process_frame
	assert_true(_async_results.successor.get("ok", false))
	assert_false((await port.finish(21)).get("ok", true),
		"the predecessor token cannot recover the successor's duck")
	assert_eq(audio.get_bus_volume_db(1), -12.0)


func test_reset_resolves_pending_awaiter_and_restores_routes_without_gain_mutation() -> void:
	var audio := AudioBackend.new()
	var transitions := TransitionBackend.new()
	var original := audio.buses.duplicate(true)
	var port := _port(audio, transitions)
	if port == null: return
	_begin_async(port, 31, &"pending")
	port.reset()
	await get_tree().process_frame
	assert_false(_async_results.pending.get("ok", true))
	assert_eq(audio.buses, original)
	assert_eq(transitions.canceled, 1)


func test_synchronous_transition_completion_cannot_outrun_async_settlement() -> void:
	var audio := AudioBackend.new()
	var transitions := TransitionBackend.new()
	transitions.complete_synchronously = true
	var port := _port(audio, transitions)
	if port == null: return
	_begin_async(port, 35, &"begin")
	await get_tree().process_frame
	assert_true(_async_results.has(&"begin"),
		"a backend completion before the await must still settle begin")
	var begin_result: Dictionary = _async_results.get(&"begin", {})
	assert_true(begin_result.get("ok", false))
	_finish_async(port, 35, &"finish")
	await get_tree().process_frame
	assert_true(_async_results.has(&"finish"),
		"a backend completion before the await must still settle finish")
	var finish_result: Dictionary = _async_results.get(&"finish", {})
	assert_true(finish_result.get("ok", false))
	assert_eq(audio.get_bus_volume_db(1), 0.0)


func test_failed_recovery_readback_releases_children_from_partial_duck() -> void:
	var audio := AudioBackend.new()
	var transitions := TransitionBackend.new()
	var original := audio.buses.duplicate(true)
	var port := _port(audio, transitions)
	if port == null: return
	_begin_async(port, 36, &"begin")
	transitions.complete()
	await get_tree().process_frame
	audio.ignore_mix_volume_writes = true
	_finish_async(port, 36, &"finish")
	transitions.complete()
	await get_tree().process_frame
	assert_false(_async_results.finish.get("ok", true),
		"unproven recovery is reported as failure")
	assert_eq(audio.buses, original,
		"a failed gain readback restores original sends and removes the duck bus")


func test_failed_recovery_start_releases_routing_instead_of_leaving_duck() -> void:
	if not ResourceLoader.exists(PORT_PATH, "Script"): return
	var audio := AudioBackend.new()
	var original := audio.buses.duplicate(true)
	var port: Node = load(PORT_PATH).new(audio)
	var begun: Dictionary = await port.begin(37)
	assert_false(begun.get("ok", true), "a detached native tween cannot start")
	var finished: Dictionary = await port.finish(37)
	assert_false(finished.get("ok", true), "failed recovery is not reported as success")
	assert_eq(audio.buses, original,
		"failed recovery start restores original sends and removes the duck bus")
	port.free()


func test_invalid_or_reused_tokens_do_not_mutate_routing() -> void:
	var audio := AudioBackend.new()
	var transitions := TransitionBackend.new()
	var original := audio.buses.duplicate(true)
	var port := _port(audio, transitions)
	if port == null: return
	assert_false((await port.begin(0)).get("ok", true))
	assert_false((await port.finish(44)).get("ok", true))
	assert_eq(audio.buses, original)
	_begin_async(port, 44, &"begin")
	transitions.complete()
	await get_tree().process_frame
	_finish_async(port, 44, &"finish")
	transitions.complete()
	await get_tree().process_frame
	assert_false((await port.begin(44)).get("ok", true))
	assert_eq(transitions.calls.size(), 2)


func test_token_high_water_rejects_older_unseen_id_and_accepts_newer_id() -> void:
	var audio := AudioBackend.new()
	var transitions := TransitionBackend.new()
	transitions.complete_synchronously = true
	var port := _port(audio, transitions)
	if port == null: return
	assert_true((await port.begin(50)).get("ok", false))
	assert_true((await port.finish(50)).get("ok", false))
	var older: Dictionary = await port.begin(49)
	assert_false(older.get("ok", true),
		"an unseen ID below the high-water mark cannot own a later duck")
	if older.get("ok", false): await port.finish(49)
	assert_true((await port.begin(51)).get("ok", false))
	assert_true((await port.finish(51)).get("ok", false))
