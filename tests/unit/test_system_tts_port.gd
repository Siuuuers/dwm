extends GutTest

const PORT_PATH := "res://scripts/accessibility/SystemTtsPort.gd"


class DisplayBackend extends RefCounted:
	var available := true
	var voices: Array[Dictionary] = [
		{"id": "english", "language": "en_US", "name": "English"},
	]
	var callbacks: Dictionary = {}
	var requests: Array[Dictionary] = []
	var stops := 0

	func has_feature(_feature: int) -> bool:
		return available

	func tts_get_voices() -> Array[Dictionary]:
		return voices.duplicate(true)

	func tts_set_utterance_callback(event: int, callback: Callable) -> void:
		callbacks[event] = callback

	func tts_speak(text: String, voice: String, volume: int, pitch: float,
			rate: float, token: int, interrupt: bool) -> void:
		requests.append({"text": text, "voice": voice, "volume": volume,
			"pitch": pitch, "rate": rate, "token": token, "interrupt": interrupt})

	func tts_stop() -> void:
		stops += 1

	func finish(event: int, token: int) -> void:
		var callback: Callable = callbacks.get(event, Callable())
		if callback.is_valid(): callback.call(token)


func _port(backend: DisplayBackend) -> Node:
	if not ResourceLoader.exists(PORT_PATH, "Script"): return null
	var port: Node = load(PORT_PATH).new(backend)
	add_child_autofree(port)
	return port


func test_system_tts_port_contract_exists() -> void:
	assert_true(ResourceLoader.exists(PORT_PATH, "Script"),
		"the native DisplayServer speech port must exist")


func test_supported_voice_query_and_speak_forward_exact_native_arguments() -> void:
	var backend := DisplayBackend.new()
	var port := _port(backend)
	if port == null: return
	assert_eq(port.get_voices(), backend.voices)
	var spoken: Dictionary = port.speak("Primary text.", "english", 1.2, 41)
	assert_true(spoken.get("ok", false), str(spoken))
	assert_eq(backend.requests, [{"text": "Primary text.", "voice": "english",
		"volume": 100, "pitch": 1.0, "rate": 1.2, "token": 41,
		"interrupt": false}])


func test_unsupported_or_invalid_requests_never_reach_the_native_queue() -> void:
	var backend := DisplayBackend.new()
	backend.available = false
	var port := _port(backend)
	if port == null: return
	assert_eq(port.get_voices(), [])
	assert_false(port.speak("Primary text.", "english", 1.0, 1).get("ok", false))
	backend.available = true
	assert_false(port.speak("", "english", 1.0, 2).get("ok", false))
	assert_false(port.speak("Primary text.", "missing", 1.0, 3).get("ok", false))
	assert_false(port.speak("Primary text.", "english", 0.0, 4).get("ok", false))
	assert_eq(backend.requests, [])


func test_terminal_callbacks_are_token_bound_and_finish_exactly_once() -> void:
	var backend := DisplayBackend.new()
	var port := _port(backend)
	if port == null: return
	watch_signals(port)
	assert_true(port.speak("Primary text.", "english", 1.0, 7).get("ok", false))
	backend.finish(DisplayServer.TTS_UTTERANCE_ENDED, 6)
	assert_signal_not_emitted(port, "utterance_finished")
	backend.finish(DisplayServer.TTS_UTTERANCE_ENDED, 7)
	assert_signal_emitted_with_parameters(port, "utterance_finished", [7, &"completed"])
	backend.finish(DisplayServer.TTS_UTTERANCE_CANCELED, 7)
	assert_signal_emit_count(port, "utterance_finished", 1,
		"a duplicate or late terminal callback cannot finish the token twice")
	assert_false(port.speak("Reused.", "english", 1.0, 7).get("ok", false),
		"utterance IDs are never rebound to late native callbacks")


func test_cancel_without_explicit_stop_is_failure_but_stop_retires_before_callback() -> void:
	var backend := DisplayBackend.new()
	var port := _port(backend)
	if port == null: return
	watch_signals(port)
	assert_true(port.speak("Failure.", "english", 0.8, 8).get("ok", false))
	backend.finish(DisplayServer.TTS_UTTERANCE_CANCELED, 8)
	assert_signal_emitted_with_parameters(port, "utterance_finished", [8, &"failed"])
	assert_true(port.speak("Stopped.", "english", 1.0, 9).get("ok", false))
	assert_true(port.stop().get("ok", false))
	assert_eq(backend.stops, 1)
	backend.finish(DisplayServer.TTS_UTTERANCE_CANCELED, 9)
	assert_signal_emit_count(port, "utterance_finished", 1,
		"the coordinator already retired an explicitly stopped token")
	assert_true(port.speak("Successor.", "english", 1.0, 10).get("ok", false))
	backend.finish(DisplayServer.TTS_UTTERANCE_ENDED, 9)
	assert_signal_emit_count(port, "utterance_finished", 1,
		"an old callback cannot finish the current utterance")
	backend.finish(DisplayServer.TTS_UTTERANCE_ENDED, 10)
	assert_signal_emitted_with_parameters(port, "utterance_finished", [10, &"completed"])


func test_token_high_water_rejects_older_unseen_id_and_accepts_newer_id() -> void:
	var backend := DisplayBackend.new()
	var port := _port(backend)
	if port == null: return
	assert_true(port.speak("First.", "english", 1.0, 50).get("ok", false))
	backend.finish(DisplayServer.TTS_UTTERANCE_ENDED, 50)
	var older: Dictionary = port.speak("Older.", "english", 1.0, 49)
	assert_false(older.get("ok", true),
		"an unseen ID below the high-water mark remains vulnerable to a late callback")
	if older.get("ok", false): port.stop()
	assert_true(port.speak("Newer.", "english", 1.0, 51).get("ok", false))
	backend.finish(DisplayServer.TTS_UTTERANCE_ENDED, 51)
