class_name SystemTtsDuckPort
extends Node
## Transient, uniform game-mix duck for system speech. It owns only routing,
## fade custody, and per-instance utterance tokens.

signal _transition_settled(generation: int)

const MIX_BUS := &"Game Mix"
const MASTER_BUS := &"Master"
const GAME_BUSES: Array[StringName] = [&"Music", &"Ambience", &"SFX", &"UI", &"Voice"]
const DUCK_DB := -12.0
const DOWN_SECONDS := 0.12
const UP_SECONDS := 0.18
const AUDIO_METHODS: Array[StringName] = [
	&"get_bus_index", &"add_bus", &"remove_bus", &"get_bus_name",
	&"set_bus_name", &"get_bus_send", &"set_bus_send",
	&"get_bus_volume_db", &"set_bus_volume_db",
]

var _audio: Object
var _transition_backend: Object
var _native_transition: Dictionary = {}
var _generation := 0
var _pending_generation := 0
var _active_token := 0
var _recovering_token := 0
var _highest_token := 0
var _original_sends: Dictionary = {}
var _routing_ready := false
var _created_mix := false


func _init(audio_backend: Object = null, transition_backend: Object = null) -> void:
	_audio = AudioServer if audio_backend == null else audio_backend
	_transition_backend = transition_backend


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _process(_delta: float) -> void:
	if _native_transition.is_empty():
		set_process(false)
		return
	var generation: int = _native_transition.generation
	if generation != _generation or generation != _pending_generation:
		_native_transition.clear()
		set_process(false)
		return
	var elapsed_usec: int = Time.get_ticks_usec() - int(_native_transition.started_usec)
	var duration_usec: int = int(_native_transition.duration_usec)
	var progress: float = clampf(float(elapsed_usec) / duration_usec, 0.0, 1.0)
	_set_mix_db(lerpf(float(_native_transition.from_db),
		float(_native_transition.target_db), progress))
	if elapsed_usec < duration_usec: return
	var target_db: float = float(_native_transition.target_db)
	_native_transition.clear()
	set_process(false)
	_complete_transition(generation, target_db)


func begin(token: int) -> Dictionary:
	if token <= 0: return _failure(&"invalid_duck_token")
	if token <= _highest_token: return _failure(&"duck_token_reused")
	if not _transition_available(): return _failure(&"duck_output_unavailable")
	var routed: Dictionary = _ensure_routing()
	if not routed.get("ok", false): return routed
	_highest_token = token
	_active_token = token
	_recovering_token = 0
	var faded: Dictionary = await _fade_to(DUCK_DB, DOWN_SECONDS)
	if token != _active_token: return _failure(&"duck_superseded")
	if not faded.get("ok", false): return faded
	return _success({"token": token, "db": DUCK_DB})


func finish(token: int) -> Dictionary:
	if token <= 0 or token != _active_token: return _failure(&"stale_duck_token")
	_active_token = 0
	_recovering_token = token
	var faded: Dictionary = await _fade_to(0.0, UP_SECONDS)
	if token != _recovering_token: return _failure(&"duck_superseded")
	_recovering_token = 0
	if not faded.get("ok", false):
		if not _restore_routing(): return _failure(&"duck_release_unproven")
		return faded
	return _success({"token": token, "db": 0.0})


func reset() -> void:
	_generation += 1
	_cancel_transition()
	_active_token = 0
	_recovering_token = 0
	if _routing_ready: _set_mix_db(0.0)
	_restore_routing()


func _exit_tree() -> void:
	reset()


func _fade_to(target_db: float, duration: float) -> Dictionary:
	_generation += 1
	var generation: int = _generation
	_cancel_transition()
	_pending_generation = generation
	var from_db: float = _get_mix_db()
	if not is_finite(from_db):
		_pending_generation = 0
		return _failure(&"duck_output_unavailable")
	if not _start_transition(from_db, target_db, duration, generation):
		_pending_generation = 0
		return _failure(&"duck_output_unavailable")
	# An injected or future backend may complete during start(). Do not wait for
	# a signal which has already settled this generation.
	if _pending_generation != 0: await _transition_settled
	if generation != _generation: return _failure(&"duck_superseded")
	if _pending_generation != 0 or not is_equal_approx(_get_mix_db(), target_db):
		return _failure(&"duck_output_unproven")
	return _success({"db": target_db})


func _start_transition(
		from_db: float, target_db: float, duration: float, generation: int
) -> bool:
	var completion: Callable = _complete_transition.bind(generation, target_db)
	if _transition_backend != null:
		_transition_backend.start(from_db, target_db, duration, completion)
		return true
	if not is_inside_tree(): return false
	_native_transition = {"generation": generation, "from_db": from_db,
		"target_db": target_db, "started_usec": Time.get_ticks_usec(),
		"duration_usec": int(round(duration * 1_000_000.0))}
	set_process(true)
	return true


func _complete_transition(generation: int, target_db: float) -> void:
	if generation != _generation or generation != _pending_generation: return
	_set_mix_db(target_db)
	_pending_generation = 0
	_transition_settled.emit(generation)


func _cancel_transition() -> void:
	if _pending_generation == 0: return
	var canceled_generation: int = _pending_generation
	_pending_generation = 0
	if _transition_backend != null:
		_transition_backend.cancel()
	else:
		_native_transition.clear()
		set_process(false)
	# Settle the displaced generation explicitly; its caller observes the newer
	# generation and fails instead of remaining suspended.
	_transition_settled.emit(canceled_generation)


func _ensure_routing() -> Dictionary:
	if _routing_ready: return _success({"already_routed": true})
	if not _audio_available(): return _failure(&"duck_output_unavailable")
	if _audio.get_bus_index(MASTER_BUS) != 0: return _failure(&"duck_output_unavailable")
	if _audio.get_bus_index(MIX_BUS) >= 0: return _failure(&"game_mix_conflict")
	_audio.add_bus(1)
	_created_mix = true
	_audio.set_bus_name(1, MIX_BUS)
	_audio.set_bus_send(1, MASTER_BUS)
	_audio.set_bus_volume_db(1, 0.0)
	if _audio.get_bus_index(MIX_BUS) != 1 or _audio.get_bus_send(1) != MASTER_BUS:
		_restore_routing()
		return _failure(&"duck_output_unavailable")

	_original_sends.clear()
	for bus_name: StringName in GAME_BUSES:
		var index: int = _audio.get_bus_index(bus_name)
		if index < 0:
			_restore_routing()
			return _failure(&"duck_output_unavailable")
		_original_sends[bus_name] = _audio.get_bus_send(index)
		_audio.set_bus_send(index, MIX_BUS)
		if _audio.get_bus_send(index) != MIX_BUS:
			_restore_routing()
			return _failure(&"duck_output_unavailable")
	_routing_ready = true
	return _success({"routed_buses": _original_sends.size()})


func _restore_routing() -> bool:
	if not _audio_available():
		return false
	for bus_value: Variant in _original_sends:
		var bus_name: StringName = bus_value
		var index: int = _audio.get_bus_index(bus_name)
		if index < 0: return false
		_audio.set_bus_send(index, _original_sends[bus_name])
		if _audio.get_bus_send(index) != _original_sends[bus_name]: return false
	if _created_mix:
		var mix_index: int = _audio.get_bus_index(MIX_BUS)
		if mix_index >= 0: _audio.remove_bus(mix_index)
		if _audio.get_bus_index(MIX_BUS) >= 0: return false
	_original_sends.clear()
	_created_mix = false
	_routing_ready = false
	return true


func _set_mix_db(value_db: float) -> void:
	if not _audio_available(): return
	var index: int = _audio.get_bus_index(MIX_BUS)
	if index >= 0: _audio.set_bus_volume_db(index, value_db)


func _get_mix_db() -> float:
	if not _audio_available(): return NAN
	var index: int = _audio.get_bus_index(MIX_BUS)
	return NAN if index < 0 else float(_audio.get_bus_volume_db(index))


func _transition_available() -> bool:
	if _transition_backend == null: return true
	return is_instance_valid(_transition_backend) \
		and _transition_backend.has_method(&"start") \
		and _transition_backend.has_method(&"cancel")


func _audio_available() -> bool:
	if not is_instance_valid(_audio): return false
	for method: StringName in AUDIO_METHODS:
		if not _audio.has_method(method): return false
	return typeof(_audio.bus_count) == TYPE_INT and _audio.bus_count > 0


func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": {}}
