class_name SystemTtsPort
extends Node
## Thin owner of Godot's DisplayServer text-to-speech queue. Voice choice,
## source lifetime, and reading-rate policy belong to the coordinator.

signal utterance_finished(token: int, outcome: StringName)

const REQUIRED_METHODS: Array[StringName] = [
	&"has_feature", &"tts_get_voices", &"tts_set_utterance_callback",
	&"tts_speak", &"tts_stop",
]
const MIN_RATE := 0.1
const MAX_RATE := 10.0

var _display: Object
var _callbacks_bound := false
var _active_token := 0
var _highest_token := 0


func _init(display_backend: Object = null) -> void:
	_display = DisplayServer if display_backend == null else display_backend


func _ready() -> void:
	_ensure_callbacks()


func get_voices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _speech_available(): return result
	var reported: Variant = _display.tts_get_voices()
	if typeof(reported) != TYPE_ARRAY: return result
	for candidate: Variant in reported:
		if typeof(candidate) != TYPE_DICTIONARY: continue
		var voice: Dictionary = candidate
		if not voice.has("id") or not voice.has("language") or not voice.has("name"): continue
		if typeof(voice.id) != TYPE_STRING or typeof(voice.language) != TYPE_STRING \
				or typeof(voice.name) != TYPE_STRING: continue
		if String(voice.id).strip_edges().is_empty() \
				or String(voice.language).strip_edges().is_empty() \
				or String(voice.name).strip_edges().is_empty(): continue
		result.append({"id": String(voice.id), "language": String(voice.language),
			"name": String(voice.name)})
	return result


func speak(text: String, voice_id: String, rate: float, token: int) -> Dictionary:
	if not _speech_available(): return _failure(&"text_to_speech_unavailable")
	if text.strip_edges().is_empty(): return _failure(&"empty_speech_text")
	if voice_id.strip_edges().is_empty() or not _voice_exists(voice_id):
		return _failure(&"speech_voice_unavailable")
	if is_nan(rate) or is_inf(rate) or rate < MIN_RATE or rate > MAX_RATE:
		return _failure(&"invalid_speech_rate")
	if token <= 0: return _failure(&"invalid_utterance_token")
	if token <= _highest_token: return _failure(&"utterance_token_reused")
	if _active_token != 0: return _failure(&"utterance_active")
	if not _ensure_callbacks(): return _failure(&"text_to_speech_unavailable")

	# Godot's enqueue call has no completion result. Register custody first so a
	# synchronous test backend or prompt native callback cannot outrun the token.
	_highest_token = token
	_active_token = token
	_display.tts_speak(text, voice_id, 100, 1.0, rate, token, false)
	return _success({"token": token})


func stop() -> Dictionary:
	var retired_token := _active_token
	_active_token = 0
	if not _display_contract_available(): return _failure(&"text_to_speech_unavailable")
	# Retire before calling Godot: Windows can report CANCELED for the current
	# utterance and every queued utterance as a consequence of this call.
	_display.tts_stop()
	return _success({"token": retired_token})


func _ensure_callbacks() -> bool:
	if _callbacks_bound: return true
	if not _speech_available(): return false
	_display.tts_set_utterance_callback(
		DisplayServer.TTS_UTTERANCE_ENDED, _on_utterance_ended)
	_display.tts_set_utterance_callback(
		DisplayServer.TTS_UTTERANCE_CANCELED, _on_utterance_canceled)
	_callbacks_bound = true
	return true


func _on_utterance_ended(token: int) -> void:
	_finish_active(token, &"completed")


func _on_utterance_canceled(token: int) -> void:
	_finish_active(token, &"failed")


func _finish_active(token: int, outcome: StringName) -> void:
	if token <= 0 or token != _active_token: return
	_active_token = 0
	utterance_finished.emit(token, outcome)


func _voice_exists(voice_id: String) -> bool:
	for voice: Dictionary in get_voices():
		if voice.id == voice_id: return true
	return false


func _speech_available() -> bool:
	return _display_contract_available() \
		and _display.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)


func _display_contract_available() -> bool:
	if not is_instance_valid(_display): return false
	for method: StringName in REQUIRED_METHODS:
		if not _display.has_method(method): return false
	return true


func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
