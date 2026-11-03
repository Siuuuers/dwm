extends Node

const PlaybackPort = preload("res://scripts/audio/AudioPlaybackPort.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var port := PlaybackPort.new()
	var music: Dictionary = port.load_stream("res://audio/bgm/_native_verify.nsf")
	var effect: Dictionary = port.load_stream("res://audio/sfx/_native_verify.nsfe")
	if not music.ok or not effect.ok:
		get_tree().quit(1)
		return
	if not music.value.is_class("VGMStream") or not effect.value.is_class("VGMStream"):
		get_tree().quit(1)
		return
	port.ensure_player(&"NativeMusic", &"Master")
	port.ensure_player(&"NativeEffect", &"Master")
	port.assign_stream(&"NativeMusic", music.value)
	port.assign_stream(&"NativeEffect", effect.value)
	if not port.play(&"NativeMusic").ok or not port.play(&"NativeEffect").ok:
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.7).timeout
	if not port._players[&"NativeMusic"].playing or port._players[&"NativeEffect"].playing:
		get_tree().quit(1)
		return
	var stopped: Dictionary = await port.shutdown()
	if not stopped.ok:
		get_tree().quit(1)
		return
	print("NATIVE_GAME_EXPORT_PASS")
	get_node("/root/ApplicationBootstrap").request_quit()
