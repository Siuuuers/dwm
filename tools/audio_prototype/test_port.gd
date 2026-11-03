extends SceneTree

const PlaybackPort = preload("res://production_audio_playback_port.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/manifest.json"))
	var streams := {}
	for cue: String in ["loop_a", "loop_b", "confirm"]:
		var timing: Dictionary = manifest.fixtures[cue]
		streams[cue] = DwmNsfStream.create(
			FileAccess.get_file_as_bytes("res://fixtures/" + cue + ".nsf"),
			float(timing.end_seconds), float(timing.intro_seconds), float(timing.loop_seconds))
		_check(streams[cue] != null, "create " + cue)
	if failures:
		quit(1)
		return
	var port = PlaybackPort.new()
	for id: StringName in [&"a", &"b", &"peer", &"sfx"]:
		_check(port.ensure_player(id, &"Master").ok, "ensure " + String(id))
	_check(port.assign_stream(&"a", streams.loop_a).ok, "assign first music")
	_check(port.assign_stream(&"peer", streams.loop_a).ok, "share immutable music resource")
	_check(port.assign_stream(&"b", streams.loop_b).ok, "assign second music")
	_check(port.assign_stream(&"sfx", streams.confirm).ok, "assign finite effect")
	_check(port.play(&"a").ok, "start first music")
	await create_timer(0.25).timeout
	_check(port.play(&"peer").ok, "start independent peer later")
	await create_timer(0.15).timeout
	var a: AudioStreamPlayer = port._players[&"a"]
	var peer: AudioStreamPlayer = port._players[&"peer"]
	var b: AudioStreamPlayer = port._players[&"b"]
	var sfx: AudioStreamPlayer = port._players[&"sfx"]
	_check(a.get_stream_playback() != peer.get_stream_playback(), "shared resource creates separate playback instances")
	_check(a.get_playback_position() - peer.get_playback_position() > 0.12, "starting peer does not reset first playback clock")
	_check(port.stop_and_clear(&"peer").ok, "release independent peer")

	_check(port.play(&"b").ok, "start crossfade destination")
	var fade_tracks: Array[Dictionary] = [
		{"player_id": &"a", "from_db": 0.0, "to_db": -60.0, "stop_on_complete": true},
		{"player_id": &"b", "from_db": -60.0, "to_db": -6.0},
	]
	_check(port.create_parallel_tween(&"music", fade_tracks, 0.2).ok, "existing port starts crossfade")
	await create_timer(0.4).timeout
	_check(not a.playing and a.stream == null, "crossfade clears outgoing stream")
	_check(b.playing and absf(b.volume_db + 6.0) < 0.01, "crossfade retains destination at target gain")

	_check(port.play(&"sfx").ok, "play finite effect")
	await create_timer(0.65).timeout
	_check(not sfx.playing and not sfx.has_stream_playback(), "finite effect releases active playback")

	_check(port.play(&"sfx").ok, "restart transient for pause")
	await create_timer(0.05).timeout
	var retained: AudioStreamPlayback = b.get_stream_playback()
	var freeze: Array[StringName] = [&"b"]
	var stop_transient: Array[StringName] = [&"sfx"]
	_check(port.begin_pause_suspension(freeze, stop_transient).ok, "existing port suspends native playback")
	await create_timer(0.1).timeout
	var paused_position := retained.get_playback_position()
	await create_timer(0.25).timeout
	_check(absf(retained.get_playback_position() - paused_position) < 0.03, "pause freezes retained musical clock")
	_check(not sfx.playing, "pause stops transient effect")
	_check(port.resume_pause_suspension().ok, "existing port resumes native playback")
	_check(b.get_stream_playback() == retained, "resume retains exact playback instance")
	await create_timer(0.2).timeout
	_check(retained.get_playback_position() > paused_position + 0.08, "resume advances retained clock")

	var captured: Dictionary = port.capture_runtime()
	_check(captured.ok, "capture runtime")
	var saved_position: float = captured.value.players[&"b"].playback_position
	await create_timer(0.3).timeout
	_check(b.get_playback_position() > saved_position + 0.1, "clock advances after capture")
	_check(port.restore_runtime(captured.value).ok, "restore through existing playback port")
	await create_timer(0.05).timeout
	_check(absf(b.get_playback_position() - saved_position) < 0.15, "restore seeks to captured elapsed position")
	var retiring: Array[WeakRef] = [weakref(retained)]
	retained = null
	for id: StringName in [&"a", &"b", &"peer", &"sfx"]:
		var player: AudioStreamPlayer = port._players[id]
		if player.has_stream_playback():
			retiring.append(weakref(player.get_stream_playback()))
		port.stop_and_clear(id)
	port._root.queue_free()
	var deadline := Time.get_ticks_msec() + 2000
	while retiring.any(func(item: WeakRef) -> bool: return item.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	_check(retiring.all(func(item: WeakRef) -> bool: return item.get_ref() == null), "audio mixer releases native playback before extension shutdown")
	print("PORT_INTEGRATION failures=", failures)
	quit(1 if failures else 0)
