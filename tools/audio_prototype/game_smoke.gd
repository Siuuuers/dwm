extends Node

const PlaybackPort = preload("res://scripts/audio/AudioPlaybackPort.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var bootstrap := get_node("/root/ApplicationBootstrap")
	if not OS.is_debug_build() and not bootstrap.get_startup_state().ready:
		push_error("Native export did not complete application startup")
		get_tree().quit(1)
		return
	var port := PlaybackPort.new()
	var music: Dictionary = port.load_stream("res://audio/bgm/_native_verify.nsf")
	var effect: Dictionary = port.load_stream("res://audio/sfx/_native_verify.nsfe")
	if not music.ok or not effect.ok:
		push_error("Native smoke resource load failed: %s / %s" % [music, effect])
		get_tree().quit(1)
		return
	if not music.value.is_class("VGMStream") or not effect.value.is_class("VGMStream"):
		push_error("Native smoke loaded an unexpected stream class")
		get_tree().quit(1)
		return
	port.ensure_player(&"NativeMusic", &"Master")
	port.ensure_player(&"NativeEffect", &"Master")
	port.assign_stream(&"NativeMusic", music.value)
	port.assign_stream(&"NativeEffect", effect.value)
	if not port.play(&"NativeMusic").ok or not port.play(&"NativeEffect").ok:
		push_error("Native smoke could not start playback")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.7).timeout
	if not port._players[&"NativeMusic"].playing or port._players[&"NativeEffect"].playing:
		push_error("Native smoke completion mismatch: music=%s effect=%s effect_position=%s paused=%s" % [
			port._players[&"NativeMusic"].playing, port._players[&"NativeEffect"].playing,
			port._players[&"NativeEffect"].get_playback_position(), get_tree().paused])
		get_tree().quit(1)
		return
	var stopped: Dictionary = await port.shutdown()
	if not stopped.ok:
		push_error("Native smoke shutdown failed: %s" % stopped)
		get_tree().quit(1)
		return
	print("NATIVE_GAME_EXPORT_PASS")
	bootstrap.request_quit()
