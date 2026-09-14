extends GutTest

const OWNER_PATH := "res://autoload/SystemTtsCoordinator.gd"

class SpeechPort extends RefCounted:
	signal utterance_finished(token: int, outcome: StringName)
	var voices: Array[Dictionary] = [
		{"id": "english", "language": "en-US", "name": "English"},
		{"id": "mandarin", "language": "zh-CN", "name": "Mandarin"},
		{"id": "cantonese", "language": "zh-HK", "name": "Cantonese"},
	]
	var requests: Array[Dictionary] = []
	var stops := 0
	var refuse := false
	func get_voices() -> Array[Dictionary]: return voices.duplicate(true)
	func speak(text: String, voice_id: String, rate: float, token: int) -> Dictionary:
		requests.append({"text": text, "voice": voice_id, "rate": rate, "token": token})
		return {"ok": not refuse}
	func stop() -> Dictionary:
		stops += 1
		return {"ok": true}

class DuckPort extends RefCounted:
	signal down_ready
	signal up_ready
	var hold_down := false
	var hold_up := false
	var fail_recovery := false
	var begins: Array[int] = []
	var finishes: Array[int] = []
	func begin(token: int) -> Dictionary:
		begins.append(token)
		if hold_down: await down_ready
		return {"ok": true}
	func finish(token: int) -> Dictionary:
		finishes.append(token)
		if hold_up: await up_ready
		return {"ok": not fail_recovery}
	func reset() -> void: pass

func _owner(port: SpeechPort, duck: DuckPort = null) -> Node:
	assert_true(ResourceLoader.exists(OWNER_PATH), "the shared production speech owner must exist")
	if not ResourceLoader.exists(OWNER_PATH): return null
	var owner: Node = load(OWNER_PATH).new(port, DuckPort.new() if duck == null else duck)
	add_child_autofree(owner)
	return owner

func test_compatible_voice_and_rate_preserve_primary_text_without_speaker_prefix() -> void:
	var port := SpeechPort.new()
	var owner := _owner(port)
	if owner == null: return
	assert_true(owner.refresh_capability("zh_HK").value.available)
	var result: Dictionary = owner.request_speech("Primary sample.", "zh_HK", &"fast", "settings.test.1")
	assert_true(result.get("ok", false))
	await wait_process_frames(2)
	assert_eq(port.requests.size(), 1)
	assert_eq(port.requests[0].text, "Primary sample.")
	assert_eq(port.requests[0].voice, "cantonese")
	assert_eq(port.requests[0].rate, 1.2)
	assert_true(owner.is_speaking("settings.test.1"))

func test_missing_compatible_voice_never_substitutes_another_language() -> void:
	var port := SpeechPort.new()
	port.voices = [{"id": "english", "language": "en-US", "name": "English"}]
	var owner := _owner(port)
	if owner == null: return
	assert_false(owner.refresh_capability("zh_CN").value.available)
	assert_false(owner.request_speech("Primary sample.", "zh_CN", &"normal", "settings.test.1").ok)
	assert_eq(port.requests.size(), 0)
	assert_false(owner.is_speaking("settings.test.1"))

func test_replacement_retires_one_utterance_and_late_completion_cannot_finish_successor() -> void:
	var port := SpeechPort.new()
	var owner := _owner(port)
	if owner == null: return
	var first: Dictionary = owner.request_speech("First.", "en", &"normal", "line.1")
	await wait_process_frames(2)
	var second: Dictionary = owner.request_speech("Second.", "en", &"slow", "line.2")
	await wait_process_frames(2)
	assert_true(first.ok and second.ok)
	assert_ne(first.value.token, second.value.token)
	assert_eq(port.stops, 1)
	assert_false(owner.is_speaking("line.1"))
	assert_true(owner.is_speaking("line.2"))
	port.utterance_finished.emit(first.value.token, &"completed")
	assert_true(owner.is_speaking("line.2"))
	port.utterance_finished.emit(second.value.token, &"completed")
	assert_false(owner.is_speaking("line.2"))

func test_stale_source_stop_cannot_cancel_a_settings_sample() -> void:
	var port := SpeechPort.new()
	var owner := _owner(port)
	if owner == null: return
	assert_true(owner.request_speech("Line.", "en", &"normal", "line.1").ok)
	await wait_process_frames(2)
	assert_true(owner.request_speech("Test.", "en", &"normal", "settings.test.1").ok)
	await wait_process_frames(2)
	owner.stop_source("line.1", &"source_hidden")
	assert_true(owner.is_speaking("settings.test.1"))
	assert_eq(port.stops, 1)
	owner.stop_source("settings.test.1", &"settings_departure")
	assert_false(owner.is_speaking("settings.test.1"))
	assert_eq(port.stops, 2)

func test_reentrant_admission_stop_prevents_native_speech_and_completes_once() -> void:
	var port := SpeechPort.new()
	var owner := _owner(port)
	if owner == null: return
	watch_signals(owner)
	owner.speech_admitted.connect(func(_token: int, _source: String): owner.stop(&"source_retired"))
	owner.request_speech("Never dispatched.", "en", &"normal", "line.1")
	assert_eq(port.requests.size(), 0)
	assert_false(owner.is_speaking("line.1"))
	assert_signal_emit_count(owner, "speech_completed", 1)

func test_speech_waits_for_duck_and_stop_during_fade_never_dispatches() -> void:
	var port := SpeechPort.new()
	var duck := DuckPort.new()
	duck.hold_down = true
	var owner := _owner(port, duck)
	if owner == null: return
	var result: Dictionary = owner.request_speech("Pending.", "en", &"normal", "line.1")
	await wait_process_frames(2)
	assert_eq(duck.begins, [result.value.token])
	assert_eq(port.requests.size(), 0)
	owner.stop_source("line.1", &"accept")
	duck.down_ready.emit()
	await wait_process_frames(2)
	assert_eq(port.requests.size(), 0, "A stopped fade cannot enqueue speech later")
	assert_eq(duck.finishes, [result.value.token])

func test_completion_and_replacement_wait_for_confirmed_duck_recovery() -> void:
	var port := SpeechPort.new()
	var duck := DuckPort.new()
	duck.hold_up = true
	var owner := _owner(port, duck)
	if owner == null: return
	watch_signals(owner)
	var first: Dictionary = owner.request_speech("First.", "en", &"normal", "line.1")
	await wait_process_frames(2)
	owner.request_speech("Second.", "en", &"normal", "line.2")
	await wait_process_frames(2)
	assert_eq(port.stops, 1)
	assert_eq(port.requests.size(), 1, "Replacement waits until old duck recovery finishes")
	assert_signal_not_emitted(owner, "speech_completed")
	duck.up_ready.emit()
	await wait_process_frames(2)
	assert_eq(port.requests.size(), 2)
	assert_signal_emitted_with_parameters(owner, "speech_completed", [first.value.token, &"replaced"])
	duck.hold_up = false
	owner.stop()

func test_native_failure_releases_duck_and_reports_failure_without_replay() -> void:
	var port := SpeechPort.new()
	port.refuse = true
	var duck := DuckPort.new()
	var owner := _owner(port, duck)
	if owner == null: return
	watch_signals(owner)
	var result: Dictionary = owner.request_speech("Unavailable.", "en", &"normal", "line.1")
	await wait_process_frames(2)
	assert_eq(duck.finishes, [result.value.token])
	assert_false(owner.is_speaking("line.1"))
	assert_signal_emitted_with_parameters(owner, "speech_completed", [result.value.token, &"failed"])
	owner.refresh_capability("en")
	await wait_process_frames(2)
	assert_eq(port.requests.size(), 1)

func test_invalid_request_does_not_replace_current_owner_and_focus_loss_stops_it() -> void:
	var port := SpeechPort.new()
	var owner := _owner(port)
	if owner == null: return
	owner.request_speech("First.", "en", &"normal", "line.1")
	await wait_process_frames(2)
	assert_false(owner.request_speech("", "en", &"normal", "line.2").ok)
	assert_false(owner.request_speech("Second.", "en", &"instant", "line.2").ok)
	assert_true(owner.is_speaking("line.1"))
	owner.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(owner.is_speaking("line.1"))
	assert_eq(port.stops, 1)

func test_failed_duck_recovery_cannot_be_reported_as_a_successful_stop_confirmation() -> void:
	var port := SpeechPort.new()
	var duck := DuckPort.new()
	duck.fail_recovery = true
	var owner := _owner(port, duck)
	if owner == null: return
	watch_signals(owner)
	var admitted: Dictionary = owner.request_speech("A line.", "en", &"normal", "line.1")
	await wait_process_frames(2)
	owner.stop()
	var recovered: Variant = await owner.wait_until_recovered()
	assert_true(recovered is Dictionary, "Recovery must expose a truthful outcome to confirmation callers")
	if recovered is Dictionary: assert_false(recovered.get("ok", true))
	assert_signal_emitted_with_parameters(owner, "speech_completed", [admitted.value.token, &"failed"])

func test_reentrant_completion_cannot_erase_failure_of_the_recovery_wave() -> void:
	var port := SpeechPort.new()
	var duck := DuckPort.new()
	duck.fail_recovery = true
	var owner := _owner(port, duck)
	if owner == null: return
	var first: Dictionary = owner.request_speech("First.", "en", &"normal", "line.1")
	await wait_process_frames(2)
	owner.speech_completed.connect(func(token: int, _outcome: StringName):
		if token == first.value.token:
			owner.request_speech("Successor.", "en", &"normal", "line.2")
			owner.stop())
	owner.stop()
	var recovered: Dictionary = await owner.wait_until_recovered()
	assert_false(recovered.ok, "A nested canceled admission cannot turn failed recovery into success")
	await wait_process_frames(2)
	assert_eq(port.requests.size(), 1)
