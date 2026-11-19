extends Node

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	var deadline := Time.get_ticks_msec() + 60000
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	while bootstrap == null or not bootstrap.get_startup_state().ready:
		if Time.get_ticks_msec() >= deadline:
			push_error("Native smoke timed out waiting for application startup")
			tree.quit(1)
			return
		await tree.process_frame
		bootstrap = get_node_or_null("/root/ApplicationBootstrap")
	var menu := tree.current_scene
	if menu == null or menu.scene_file_path != "res://scenes/menu/MenuScene.tscn":
		push_error("Native smoke expected the title screen")
		tree.quit(1)
		return
	var manager := get_node("/root/AudioManager")
	if not _check_playing(manager, "res://audio/bgm/menu_theme.nsf"):
		tree.quit(1)
		return
	menu.get_node("%NewAccButton").pressed.emit()
	var bridge := get_node("/root/DialogicBridge")
	deadline = Time.get_ticks_msec() + 30000
	while not bridge.is_current_line_presentation_acknowledged():
		if Time.get_ticks_msec() >= deadline:
			push_error("Native smoke timed out waiting for the opening caption")
			tree.quit(1)
			return
		await tree.process_frame
	if not _check_playing(manager, "res://audio/bgm/story_theme.nsf"):
		tree.quit(1)
		return
	print("NATIVE_GAME_EXPORT_PASS")
	bootstrap.request_quit()


func _check_playing(manager: Node, path: String) -> bool:
	var player: AudioStreamPlayer = manager._playback_port._players[manager._active_players[&"music"]]
	if not player.playing or player.stream == null or not player.stream.is_class("VGMStream") or player.stream != load(path):
		push_error("Expected active VRC6 music: " + path)
		return false
	var playback := player.stream.instantiate_playback()
	playback.start()
	var frames := playback.mix_audio(1.0, 44100)
	playback.stop()
	for frame: Vector2 in frames:
		if maxf(absf(frame.x), absf(frame.y)) > 0.001:
			return true
	push_error("First second of music was silent: " + path)
	return false
