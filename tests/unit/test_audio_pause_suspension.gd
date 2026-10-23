extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/AudioManager.gd")
const PORT := preload("res://scripts/audio/AudioPlaybackPort.gd")
const FAKE_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")


class Profile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var values := {
		&"preferences.audio.music_volume": 0.8,
		&"preferences.audio.music_muted": false,
		&"preferences.audio.ambience_volume": 0.65,
		&"preferences.audio.ambience_muted": false,
		&"preferences.audio.sfx_volume": 0.8,
		&"preferences.audio.sfx_muted": false,
		&"preferences.audio.master_volume": 1.0,
		&"preferences.audio.master_muted": false,
		&"preferences.audio.mute_when_inactive": false,
		&"preferences.audio.output_mode": "stereo",
	}

	func get_preference(path: StringName, default_value: Variant = null) -> Variant:
		return values.get(path, default_value)

	func set_preference(path: StringName, value: Variant) -> Dictionary:
		values[path] = value
		preference_changed.emit(path, value)
		return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


class FaultPort extends FAKE_PORT:
	var pause_state: StringName = &"Active"
	var begin_failure := false
	var begin_mutates_before_failure := false
	var resume_failure := false
	var resume_mutates_before_failure := false
	var state_failure := false
	var begin_count := 0
	var resume_count := 0

	func begin_pause_suspension(
			_freeze_player_ids: Array[StringName], _stop_player_ids: Array[StringName]
	) -> Dictionary:
		begin_count += 1
		if begin_failure:
			if begin_mutates_before_failure:
				pause_state = &"Suspended"
			return {"ok": false, "code": &"injected_audio_failure", "value": null}
		pause_state = &"Suspended"
		return {"ok": true, "code": &"ok", "value": {"suspended": true}}

	func resume_pause_suspension() -> Dictionary:
		resume_count += 1
		if resume_failure:
			if resume_mutates_before_failure:
				pause_state = &"Active"
			return {"ok": false, "code": &"injected_audio_failure", "value": null}
		pause_state = &"Active"
		return {"ok": true, "code": &"ok", "value": {"resumed": true}}

	func get_pause_suspension_state() -> Dictionary:
		if state_failure:
			return {"ok": false, "code": &"injected_audio_failure", "value": null}
		return {"ok": true, "code": &"ok", "value": {"state": pause_state}}


var _manager: Node
var _profile: Profile
var _port: RefCounted


func after_each() -> void:
	if _port != null and _port.get_script() == PORT:
		var root: Node = _port.get("_root")
		if is_instance_valid(root):
			root.queue_free()
			await get_tree().process_frame
	_manager = null
	_profile = null
	_port = null


func _handle(id: String = "pause.audio.1", generation: int = 1) -> Dictionary:
	return {
		"generation": generation,
		"handle_id": id,
		"holder": &"canonical-pause",
		"reason": &"universal_pause",
	}


func _initialize(port: RefCounted) -> void:
	_port = port
	_profile = Profile.new()
	add_child_autofree(_profile)
	_manager = MANAGER.new(port)
	add_child_autofree(_manager)
	assert_true(_manager.initialize(_profile).get("ok", false))


func _looping_stream(seconds: float = 2.0) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(seconds * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(stream.loop_end * 2)
	stream.data = bytes
	return stream


func test_real_players_and_native_crossfade_suspend_and_resume_in_place() -> void:
	_initialize(PORT.new())
	var stream := _looping_stream()
	var players: Dictionary = _port.get("_players")
	for player_id: StringName in [&"MusicA", &"AmbienceA", &"SFX0", &"Voice0", &"UI0"]:
		assert_true(_port.assign_stream(player_id, stream).get("ok", false))
		assert_true(_port.play(player_id).get("ok", false))
	(players[&"MusicA"] as AudioStreamPlayer).seek(0.75)
	var tracks: Array[Dictionary] = [{
		"player_id": &"MusicA", "from_db": -30.0, "to_db": 0.0,
	}]
	assert_true(_port.create_parallel_tween(&"music", tracks, 1.0).get("ok", false))
	await get_tree().create_timer(0.05).timeout
	var music: AudioStreamPlayer = players[&"MusicA"]
	var ambience: AudioStreamPlayer = players[&"AmbienceA"]
	var ui: AudioStreamPlayer = players[&"UI0"]
	var tween: Tween = (_port.get("_tweens") as Dictionary)[&"music"]
	var music_instance := music.get_instance_id()
	var music_stream := music.stream
	var music_playback := music.get_stream_playback()
	ambience.stream_paused = true
	var handle := _handle()
	var begun: Dictionary = _manager.begin_suspend(handle)
	assert_eq(begun, {"ok": true, "code": &"ok", "value": {
		"frontier_id": "audio:pause.audio.1:1",
	}})
	assert_true(music.stream_paused)
	assert_true(music.has_stream_playback(),
		"paused playback stays physically retained even when playing becomes false")
	assert_true(ambience.stream_paused)
	assert_false(players[&"MusicB"].stream_paused)
	assert_false(players[&"AmbienceB"].stream_paused)
	assert_false(players[&"SFX0"].playing)
	assert_false(players[&"Voice0"].playing)
	assert_true(ui.playing)
	assert_false(ui.stream_paused,"the Pause UI lane remains physically available")
	assert_false(tween.is_running())
	var paused_position := music.get_playback_position()
	var paused_elapsed := tween.get_total_elapsed_time()
	await get_tree().create_timer(0.08).timeout
	assert_almost_eq(music.get_playback_position(),paused_position,0.03)
	assert_almost_eq(tween.get_total_elapsed_time(),paused_elapsed,0.02)
	assert_eq(_manager.set_music_context("hospital").get("code"),&"audio_suspended")
	assert_eq(_manager.set_ambience_context("hospital").get("code"),&"audio_suspended")
	assert_eq(_manager.play_sfx("jealous_mine_stinger").get("code"),&"audio_suspended")
	assert_ne(_manager.play_sfx("button_accept").get("code"),&"audio_suspended",
		"registered UI cues retain admission while the test asset is absent")
	assert_eq(_manager.get_state().value.state,&"Suspended")
	assert_eq(_manager.resume(handle),{
		"ok": true, "code": &"ok", "value": {"resumed": true},
	})
	assert_eq(music.get_instance_id(),music_instance)
	assert_same(music.stream,music_stream)
	assert_same(music.get_stream_playback(),music_playback,
		"resume keeps the original native playback object")
	assert_false(music.stream_paused)
	assert_true(ambience.stream_paused,"resume restores an already-paused stream's prior bit")
	assert_true(tween.is_running())
	assert_almost_eq(music.get_playback_position(),paused_position,0.03,
		"resume preserves the frozen playhead instead of restarting playback")
	await get_tree().create_timer(0.08).timeout
	assert_gt(music.get_playback_position(),paused_position)
	assert_gt(tween.get_total_elapsed_time(),paused_elapsed)
	assert_eq(_manager.get_state().value.state,&"Active")


func test_handle_contract_is_exact_idempotent_and_consumed_once() -> void:
	var fault := FaultPort.new()
	_initialize(fault)
	assert_eq(_manager.get_state(),{
		"ok": true, "code": &"ok", "value": {"state": &"Active"},
	})
	for malformed: Dictionary in [
		{},
		{"generation":0,"handle_id":"pause.audio.0","holder":&"canonical-pause","reason":&"universal_pause"},
		{"generation":1,"handle_id":"pause.audio.0","holder":&"canonical-pause","reason":&"focus_inactive_muted"},
		{"generation":1,"handle_id":"pause.audio.0","holder":"canonical-pause","reason":&"universal_pause"},
		{"generation":1,"handle_id":"pause.audio.0","holder":&"canonical-pause","reason":&"universal_pause","extra":true},
	]:
		assert_eq(_manager.begin_suspend(malformed).get("code"),&"invalid_suspension_handle")
	var handle := _handle()
	var first: Dictionary = _manager.begin_suspend(handle)
	assert_true(first.get("ok",false))
	assert_eq(_manager.begin_suspend(handle),first,"the exact live handle joins idempotently")
	assert_eq(_manager.begin_suspend(_handle("pause.audio.2",2)).get("code"),&"audio_suspended")
	assert_eq(fault.begin_count,1,"join and refused replacement do not touch the port")
	assert_eq(_manager.resume(_handle("pause.audio.2",2)).get("code"),&"invalid_suspension_handle")
	assert_eq(fault.resume_count,0,"a mismatched handle cannot touch the port")
	assert_true(_manager.resume(handle).get("ok",false))
	assert_eq(fault.resume_count,1)
	assert_eq(_manager.resume(handle).get("code"),&"invalid_suspension_handle",
		"a consumed handle cannot resume twice")
	assert_eq(_manager.get_state().value.state,&"Active")


func test_failed_begin_compensates_an_ambiguous_physical_suspend() -> void:
	var fault := FaultPort.new()
	fault.begin_failure = true
	fault.begin_mutates_before_failure = true
	_initialize(fault)
	var failed: Dictionary = _manager.begin_suspend(_handle())
	assert_eq(failed.get("code"),&"injected_audio_failure")
	assert_eq(fault.pause_state,&"Active","manager compensates a port that failed after mutation")
	assert_eq(_manager.get_state().value.state,&"Active")


func test_unproved_begin_latches_a_truthful_indeterminate_state() -> void:
	var fault := FaultPort.new()
	fault.begin_failure = true
	fault.begin_mutates_before_failure = true
	fault.state_failure = true
	_initialize(fault)
	assert_eq(_manager.begin_suspend(_handle()),{
		"ok": false, "code": &"audio_runtime_indeterminate", "value": null,
	})
	assert_eq(_manager.get_state(),{
		"ok": false, "code": &"audio_runtime_indeterminate", "value": null,
	},"fatal physical uncertainty cannot be reported as Active")


func test_failed_resume_stays_suspended_and_exact_retry_resumes_once() -> void:
	var fault := FaultPort.new()
	_initialize(fault)
	var handle := _handle()
	assert_true(_manager.begin_suspend(handle).get("ok",false))
	fault.resume_failure = true
	assert_eq(_manager.resume(handle).get("code"),&"injected_audio_failure")
	assert_eq(_manager.get_state().value.state,&"Suspended")
	assert_eq(fault.pause_state,&"Suspended")
	fault.resume_failure = false
	assert_true(_manager.resume(handle).get("ok",false))
	assert_eq(_manager.get_state().value.state,&"Active")


func test_failed_resume_compensates_an_ambiguous_physical_resume() -> void:
	var fault := FaultPort.new()
	_initialize(fault)
	var handle := _handle()
	assert_true(_manager.begin_suspend(handle).get("ok",false))
	fault.resume_failure = true
	fault.resume_mutates_before_failure = true
	assert_eq(_manager.resume(handle).get("code"),&"injected_audio_failure")
	assert_eq(fault.pause_state,&"Suspended",
		"manager re-suspends a port that failed after physically resuming")
	assert_eq(fault.begin_count,2)
	assert_eq(fault.resume_count,1)
	assert_eq(_manager.get_state().value.state,&"Suspended")
	fault.resume_failure = false
	assert_true(_manager.resume(handle).get("ok",false))
	assert_eq(fault.resume_count,2)
	assert_eq(_manager.get_state().value.state,&"Active")
