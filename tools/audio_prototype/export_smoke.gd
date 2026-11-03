extends Node


func _ready() -> void:
	var timing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/manifest.json"))
	var cue: Dictionary = timing.fixtures.confirm
	var stream = DwmNsfStream.create(FileAccess.get_file_as_bytes("res://fixtures/confirm.nsf"), cue.end_seconds)
	if stream == null:
		get_tree().quit(1)
		return
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	playback.start()
	var samples := playback.mix_audio(1.0, 8820)
	var peak := 0.0
	for sample: Vector2 in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	if peak <= 0.001:
		get_tree().quit(1)
		return
	playback.stop()
	playback = null
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.play()
	var retiring := weakref(player.get_stream_playback())
	await get_tree().create_timer(0.7).timeout
	if player.playing:
		get_tree().quit(1)
		return
	player.stop()
	player.stream = null
	player.queue_free()
	stream = null
	var deadline := Time.get_ticks_msec() + 2000
	while retiring.get_ref() != null and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.01).timeout
	if retiring.get_ref() != null:
		push_error("audio mixer retained playback at shutdown")
		get_tree().quit(1)
		return
	print("EXPORTED_AUDIO_PROTOTYPE_PASS peak=", peak)
	get_tree().quit()
