extends "res://addons/gut/test.gd"
## Native output proof with a silent, unqueued generator. Preserve the process bus
## layout and dispose test players before restoring it; no audible fixture assets.

const PORT := preload("res://scripts/audio/AudioPlaybackPort.gd")
const FAKE := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const BUS := &"OutputCustodyFixture"

class SetterProbe extends "res://scripts/audio/AudioPlaybackPort.gd":
	var setter_mode := "normal"
	var setter_calls := 0
	func set_bus_state(name: StringName, db: float, muted: bool) -> Dictionary:
		setter_calls += 1
		if setter_mode == "fail": return {"ok": false, "code": &"injected_output_setter_failure"}
		if setter_mode == "lie": return {"ok": true}
		return super.set_bus_state(name, db, muted)

var _layout: AudioBusLayout
var _ports: Array[RefCounted] = []

func before_each() -> void:
	_layout = AudioServer.generate_bus_layout()

func after_each() -> void:
	for port: RefCounted in _ports:
		for channel: Variant in port.get("_tweens").keys(): port.kill_tween(channel)
		var runtime: Node = port.get("_root")
		if is_instance_valid(runtime): runtime.free()
	_ports.clear()
	AudioServer.set_bus_layout(_layout)
	_layout = null

func _port(probe: bool = false) -> RefCounted:
	var port: RefCounted = SetterProbe.new() if probe else PORT.new()
	_ports.append(port)
	assert_true(port.ensure_bus(&"Master").get("ok", false))
	assert_true(port.ensure_bus(BUS).get("ok", false))
	assert_true(port.set_bus_state(BUS, -3.0, false).get("ok", false))
	return port

func test_capture_reads_actual_server_values_and_returns_detached_output_only() -> void:
	var port := _port()
	var index := AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_volume_db(index, -17.0)
	AudioServer.set_bus_mute(index, true)
	var result: Dictionary = port.capture_output()
	assert_true(result.get("ok", false))
	assert_eq(result.value.size(), 2)
	assert_eq(result.value.bus_states[BUS], {"db": -17.0, "muted": true})
	assert_false(result.value.has("players"))
	assert_false(result.value.has("transitions"))
	result.value.bus_states[BUS].db = -40.0
	assert_eq(AudioServer.get_bus_volume_db(index), -17.0)
	assert_false(port.output_matches({BUS: {"db": -3.0, "muted": false}}, "stereo"), "cached setter state cannot prove current output")
	assert_true(port.output_matches({BUS: {"db": -17.0, "muted": true}}, "stereo"))

func test_output_restore_retains_paused_player_playhead_tween_and_foreign_effect() -> void:
	var port := _port()
	var master := AudioServer.get_bus_index(&"Master")
	var foreign := AudioEffectStereoEnhance.new()
	foreign.pan_pullout = 0.75
	var foreign_index := AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, foreign)
	AudioServer.set_bus_effect_enabled(master, foreign_index, false)
	assert_true(port.ensure_player(&"MusicA", BUS).get("ok", false))
	var stream := AudioStreamGenerator.new()
	assert_true(port.assign_stream(&"MusicA", stream).get("ok", false))
	assert_true(port.play(&"MusicA").get("ok", false))
	var tracks: Array[Dictionary] = [{"player_id": &"MusicA", "from_db": -30.0, "to_db": -20.0}]
	assert_true(port.create_parallel_tween(&"music", tracks, 10.0).get("ok", false))
	var frozen: Array[StringName] = [&"MusicA"]
	var stopped: Array[StringName] = []
	assert_true(port.begin_pause_suspension(frozen, stopped).get("ok", false))
	var player: AudioStreamPlayer = port.get("_players")[&"MusicA"]
	var tween: Tween = port.get("_tweens")[&"music"]
	assert_true(player.has_stream_playback())
	assert_true(player.stream_paused)
	var playback := player.get_stream_playback()
	var position := player.get_playback_position()
	var player_db := player.volume_db
	var pause_before: Dictionary = port.get("_pause_capture").duplicate(true)
	var captured: Dictionary = port.capture_output()
	assert_true(captured.get("ok", false))
	assert_true(port.set_output_mode("mono").get("ok", false))
	assert_true(port.set_bus_state(BUS, -24.0, true).get("ok", false))
	assert_true(port.restore_output(captured.value).get("ok", false))
	assert_true(port.output_matches(captured.value.bus_states, "stereo"))
	assert_same(player.stream, stream)
	assert_same(player.get_stream_playback(), playback)
	assert_eq(player.get_playback_position(), position)
	assert_eq(player.volume_db, player_db)
	assert_true(player.stream_paused)
	assert_same(port.get("_tweens")[&"music"], tween)
	assert_true(tween.is_valid())
	assert_false(tween.is_running())
	assert_eq(port.get("_pause_capture"), pause_before)
	assert_eq(port.get_pause_suspension_state().value.state, &"Suspended")
	assert_eq(AudioServer.get_bus_effect_count(master), foreign_index + 1)
	assert_same(AudioServer.get_bus_effect(master, foreign_index), foreign)
	assert_false(AudioServer.is_bus_effect_enabled(master, foreign_index))
	assert_eq(foreign.pan_pullout, 0.75)
	assert_true(port.resume_pause_suspension().get("ok", false))
	assert_same(port.get("_tweens")[&"music"], tween)

func test_owned_mono_snapshot_restores_enabled_state_without_touching_foreign_effects() -> void:
	var port := _port()
	assert_true(port.set_output_mode("mono").get("ok", false))
	var captured: Dictionary = port.capture_output()
	assert_true(captured.get("ok", false))
	var owned: AudioEffect = port.get("_mono_effect")
	var master := AudioServer.get_bus_index(&"Master")
	var foreign := AudioEffectAmplify.new()
	AudioServer.add_bus_effect(master, foreign)
	var foreign_index := AudioServer.get_bus_effect_count(master) - 1
	assert_true(port.set_output_mode("stereo").get("ok", false))
	assert_false(port.output_matches(captured.value.bus_states, "mono"))
	assert_true(port.restore_output(captured.value).get("ok", false))
	assert_true(port.output_matches(captured.value.bus_states, "mono"))
	assert_same(AudioServer.get_bus_effect(master, captured.value.output_state.index), owned)
	assert_same(AudioServer.get_bus_effect(master, foreign_index), foreign)
	assert_true(AudioServer.is_bus_effect_enabled(master, foreign_index))

func test_malformed_and_other_owner_capsules_refuse_before_any_setter() -> void:
	var port := _port(true)
	var captured: Dictionary = port.capture_output().value
	var invalid: Array[Dictionary] = []
	var candidate := captured.duplicate(true)
	candidate.output_state.owner_id += 1
	invalid.append(candidate)
	candidate = captured.duplicate(true)
	candidate.output_state.enabled = 1
	invalid.append(candidate)
	candidate = captured.duplicate(true)
	candidate.output_state.index = 0
	invalid.append(candidate)
	candidate = captured.duplicate(true)
	candidate.bus_states[BUS].db = NAN
	invalid.append(candidate)
	candidate = captured.duplicate(true)
	candidate.bus_states[BUS].db = 0
	invalid.append(candidate)
	candidate = captured.duplicate(true)
	candidate.bus_states.erase(BUS)
	invalid.append(candidate)
	candidate = captured.duplicate(true)
	candidate.players = {}
	invalid.append(candidate)
	var calls: int = port.setter_calls
	for snapshot: Dictionary in invalid:
		assert_false(port.restore_output(snapshot).get("ok", true))
		assert_eq(port.setter_calls, calls)
		assert_eq(port.capture_output().value, captured)

func test_restore_propagates_failed_setter_and_refuses_success_without_readback() -> void:
	var port := _port(true)
	var snapshot: Dictionary = port.capture_output().value
	assert_true(port.set_bus_state(BUS, -31.0, true).get("ok", false))
	port.setter_mode = "fail"
	assert_eq(port.restore_output(snapshot).get("code"), &"injected_output_setter_failure")
	port.setter_mode = "lie"
	assert_eq(port.restore_output(snapshot).get("code"), &"audio_output_restore_unproven")
	assert_false(port.output_matches(snapshot.bus_states, "stereo"))
	port.setter_mode = "normal"
	assert_true(port.restore_output(snapshot).get("ok", false))
	assert_true(port.output_matches(snapshot.bus_states, "stereo"))

func test_output_proof_observes_native_owned_effect_disable_and_parameter_tamper() -> void:
	var port := _port()
	assert_true(port.set_output_mode("mono").get("ok", false))
	var snapshot: Dictionary = port.capture_output().value
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_effect_enabled(master, snapshot.output_state.index, false)
	assert_false(port.output_matches(snapshot.bus_states, "mono"))
	assert_true(port.output_matches(snapshot.bus_states, "stereo"))
	AudioServer.set_bus_effect_enabled(master, snapshot.output_state.index, true)
	var effect: AudioEffectStereoEnhance = port.get("_mono_effect")
	effect.pan_pullout = 1.0
	assert_false(port.output_matches(snapshot.bus_states, "mono"))
	assert_false(port.capture_output().get("ok", true))
	assert_false(port.restore_output(snapshot).get("ok", true))

func test_fake_output_capsule_failure_ordinals_do_not_reconstruct_playback() -> void:
	var port := FAKE.new()
	assert_true(port.set_bus_state(&"Master", -4.0, false).get("ok", false))
	port.players = {&"MusicA": {"stream": AudioStreamGenerator.new(), "playing": true, "paused": true}}
	port.active_tweens = {&"music": {"remaining": 3.0}}
	var players := port.players.duplicate(true)
	var tweens := port.active_tweens.duplicate(true)
	var snapshot: Dictionary = port.capture_output().value
	assert_true(port.set_output_mode("mono").get("ok", false))
	assert_true(port.set_bus_state(&"Master", -18.0, true).get("ok", false))
	port.fail_after(port.operations.size() + 2) # restore entry, then output-mode setter
	assert_eq(port.restore_output(snapshot).get("code"), &"injected_audio_failure")
	assert_false(port.output_matches(snapshot.bus_states, "stereo"))
	assert_true(port.restore_output(snapshot).get("ok", false))
	assert_true(port.output_matches(snapshot.bus_states, "stereo"))
	assert_eq(port.players, players)
	assert_eq(port.active_tweens, tweens)
	var runtime: Dictionary = port.capture_runtime().value
	assert_eq(runtime.keys().size(), 3, "existing full-runtime fake capsule is unchanged")
	for operation: Dictionary in port.operations:
		assert_false(operation.operation in [&"play", &"stop", &"assign_stream", &"kill_tween", &"create_parallel_tween", &"restore_runtime"])
