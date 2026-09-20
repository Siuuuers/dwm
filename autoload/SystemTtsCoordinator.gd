extends Node
## One transient Primary speech owner, independent of profile and story receipts.
## Admission is synchronous; native speech waits for the shared game-mix fade.

signal speech_admitted(token: int, source: String)
signal speech_completed(token: int, outcome: StringName)
signal recovery_changed

const RATES := {&"slow": 0.8, &"normal": 1.0, &"fast": 1.2}

var _port: Object
var _duck: Object
var _sequence := 0
var _active: Dictionary = {}
var _recovering: Dictionary = {}
var _recovery_ok := true
var _exiting := false


func _init(speech_port: Object = null, duck_port: Object = null) -> void:
	_port = speech_port
	_duck = duck_port


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _port == null:
		_port = load("res://scripts/accessibility/SystemTtsPort.gd").new()
		add_child(_port)
	if _duck == null:
		_duck = load("res://scripts/audio/SystemTtsDuckPort.gd").new()
		add_child(_duck)
	_port.connect("utterance_finished", _on_utterance_finished)


func refresh_capability(locale: String) -> Dictionary:
	return _success({"available": not _compatible_voice(locale).is_empty()})


func request_speech(text: String, locale: String, rate: StringName, source: String) -> Dictionary:
	if _exiting or not is_inside_tree() or not is_instance_valid(_duck):
		return _failure(&"speech_unavailable")
	if text.strip_edges().is_empty() or source.strip_edges().is_empty():
		return _failure(&"invalid_speech_request")
	if not RATES.has(rate): return _failure(&"invalid_speech_rate")
	var voice := _compatible_voice(locale)
	if voice.is_empty(): return _failure(&"no_compatible_voice")
	_sequence += 1
	var token := _sequence
	stop(&"replaced")
	# A completion listener may synchronously admit a newer owner.
	if token != _sequence: return _failure(&"speech_request_superseded")
	_active = {"token": token, "source": source, "text": text,
		"voice": voice, "rate": RATES[rate], "duck_started": false, "dispatched": false}
	speech_admitted.emit(token, source)
	if _is_current(token): _launch.call_deferred(token)
	return _success({"token": token})


func is_speaking(source: String = "") -> bool:
	return not _active.is_empty() and (source.is_empty() or source == _active.source)


func stop_source(source: String, reason: StringName = &"stopped") -> Dictionary:
	if source.is_empty() or not is_speaking(source): return _success({"stopped": false})
	return stop(reason)


func stop(reason: StringName = &"stopped") -> Dictionary:
	if _active.is_empty(): return _success({"stopped": false})
	var token: int = _active.token
	_retire(reason, true)
	return _success({"stopped": true, "token": token})


func wait_until_recovered() -> Dictionary:
	while not _recovering.is_empty() and not _exiting:
		await recovery_changed
	return {"ok": _recovery_ok and not _exiting}


func _launch(token: int) -> void:
	await wait_until_recovered()
	if not _is_current(token): return
	_active.duck_started = true
	var faded: Dictionary = await _duck.begin(token)
	if not _is_current(token): return
	if not faded.get("ok", false):
		_retire(&"failed", false)
		return
	_active.dispatched = true
	var result: Dictionary = _port.speak(_active.text, _active.voice, _active.rate, token)
	if _is_current(token) and not result.get("ok", false): _retire(&"failed", true)


func _retire(outcome: StringName, stop_native: bool) -> void:
	var old := _active
	_active = {}
	var token: int = old.token
	# Reserve recovery before any native stop can synchronously call listeners.
	if _recovering.is_empty(): _recovery_ok = true
	_recovering[token] = true
	if stop_native and old.dispatched:
		var stopped: Dictionary = _port.stop()
		if not stopped.get("ok", false): outcome = &"failed"
	_recover(token, outcome, old.duck_started)


func _recover(token: int, outcome: StringName, had_duck: bool) -> void:
	if had_duck:
		var released: Dictionary = await _duck.finish(token)
		if not released.get("ok", false): outcome = &"failed"
	if _exiting: return
	if outcome == &"failed": _recovery_ok = false
	speech_completed.emit(token, outcome)
	_recovering.erase(token)
	recovery_changed.emit()


func _on_utterance_finished(token: int, outcome: StringName) -> void:
	if _is_current(token):
		_retire(&"completed" if outcome == &"completed" else &"failed", false)


func _compatible_voice(locale: String) -> String:
	if not is_instance_valid(_port): return ""
	var normalized := locale.replace("-", "_").to_lower()
	if normalized not in ["en", "zh_cn", "zh_hk", "ja", "ko"]: return ""
	var matches: Array[String] = []
	for voice: Dictionary in _port.get_voices():
		var language := str(voice.get("language", "")).replace("-", "_").to_lower()
		if language == normalized or (normalized in ["en", "ja", "ko"] and language.begins_with(normalized + "_")):
			var id := str(voice.get("id", ""))
			if not id.is_empty(): matches.append(id)
	matches.sort()
	return "" if matches.is_empty() else matches[0]


func _is_current(token: int) -> bool:
	return not _exiting and not _active.is_empty() and _active.token == token


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: stop(&"focus_lost")


func _exit_tree() -> void:
	_exiting = true
	if not _active.is_empty() and _active.dispatched and is_instance_valid(_port): _port.stop()
	_active.clear()
	if is_instance_valid(_duck): _duck.reset()
	_recovering.clear()
	recovery_changed.emit()
	if is_instance_valid(_port) and _port.is_connected("utterance_finished", _on_utterance_finished):
		_port.disconnect("utterance_finished", _on_utterance_finished)


func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": {}}
