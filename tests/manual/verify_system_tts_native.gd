extends SceneTree
## Native Windows API/callback and Game Mix timing probe. A passing receipt does
## not claim that a human heard, understood, or approved the synthesized voice.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
const GAME_BUSES: Array[StringName] = [&"Music", &"Ambience", &"SFX", &"UI", &"Voice"]
const DEADLINE_USEC := 15_000_000

var _result_path := ""
var _failures: Array[String] = []
var _admissions: Dictionary = {}
var _native_terminals: Dictionary = {}
var _completions: Dictionary = {}
var _coordinator: Node
var _duck: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var allocated: Dictionary = TEMPORARY_STORAGE.create("system-tts-native")
	if not allocated.get("ok", false):
		printerr("SYSTEM_TTS_NATIVE_RESULT " + JSON.stringify({"ok": false,
			"failures": ["isolated_test_root_unavailable"]}))
		quit(1)
		return
	var isolated := str(allocated.value)
	_result_path = isolated.path_join("system-tts-native-result.json")
	if DisplayServer.get_name() != "Windows":
		_failures.append("windows_display_server_required")
		await _finish({})
		return
	if not bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)):
		_failures.append("text_to_speech_project_flag_disabled")
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_failures.append("native_text_to_speech_feature_unavailable")

	var profile: Node = root.get_node_or_null("ProfileManager")
	var audio_manager: Node = root.get_node_or_null("AudioManager")
	_coordinator = root.get_node_or_null("SystemTtsCoordinator")
	if profile == null or audio_manager == null or _coordinator == null:
		_failures.append("production_autoload_missing")
		await _finish({})
		return
	var profile_result: Dictionary = profile.call(&"initialize",
		STORAGE.new(isolated.path_join("profile")))
	if not profile_result.get("ok", false): _failures.append("profile_initialize_failed")
	var audio_result: Dictionary = audio_manager.call(&"initialize", profile)
	if not audio_result.get("ok", false): _failures.append("audio_initialize_failed")
	if not await _wait_services_ready():
		_failures.append("speech_services_ready_timeout")
		await _finish({})
		return

	var speech_port: Node = _coordinator.get("_port") as Node
	_duck = _coordinator.get("_duck") as Node
	var speech_script: Script = speech_port.get_script() if speech_port != null else null
	var duck_script: Script = _duck.get_script() if _duck != null else null
	if speech_port == null or _duck == null \
			or speech_script == null or duck_script == null \
			or speech_script.resource_path \
					!= "res://scripts/accessibility/SystemTtsPort.gd" \
			or duck_script.resource_path \
					!= "res://scripts/audio/SystemTtsDuckPort.gd":
		_failures.append("production_ports_not_mounted")
		await _finish({})
		return
	if not speech_port.is_connected(&"utterance_finished", _on_native_terminal):
		speech_port.connect(&"utterance_finished", _on_native_terminal)
	if not _coordinator.is_connected(&"speech_admitted", _on_admitted):
		_coordinator.connect(&"speech_admitted", _on_admitted)
	if not _coordinator.is_connected(&"speech_completed", _on_completed):
		_coordinator.connect(&"speech_completed", _on_completed)

	var selected_locale: String = await _wait_compatible_locale()
	var voices: Array[Dictionary] = speech_port.call(&"get_voices")
	var report := {
		"display_server": DisplayServer.get_name(),
		"feature_text_to_speech": DisplayServer.has_feature(
			DisplayServer.FEATURE_TEXT_TO_SPEECH),
		"project_flag": bool(ProjectSettings.get_setting(
			"audio/general/text_to_speech", false)),
		"voices": voices.duplicate(true),
		"selected_locale": selected_locale,
		"human_audibility_claimed": false,
		"expected": {"duck_db": -12.0, "down_ms": 120, "recovery_ms": 180},
	}
	if selected_locale.is_empty():
		_failures.append("no_compatible_native_voice")
		await _finish(report)
		return
	var before := _capture_game_buses()
	if before.size() != GAME_BUSES.size(): _failures.append("game_bus_missing")
	report["buses_before"] = before.duplicate(true)

	var natural: Dictionary = _coordinator.call(&"request_speech",
		_specimen(selected_locale, false), selected_locale,
		&"normal", "native.probe.natural")
	if not natural.get("ok", false):
		_failures.append("natural_request_refused")
		await _finish(report)
		return
	var natural_token := int(natural.value.token)
	if not await _wait_dispatched(natural_token):
		_failures.append("natural_dispatch_timeout")
		await _finish(report)
		return
	var natural_dispatch := Time.get_ticks_usec()
	var natural_dispatch_state := _capture_duck_state(before)
	_check_dispatch_state(natural_dispatch_state, "natural")
	var natural_active: Dictionary = _coordinator.get("_active")
	report["selected_voice_id"] = str(natural_active.get("voice", ""))
	if not await _wait_completed(natural_token):
		_failures.append("natural_completion_timeout")
		await _finish(report)
		return
	var natural_terminal: Dictionary = _native_terminals.get(natural_token, {})
	var natural_completion: Dictionary = _completions.get(natural_token, {})
	if natural_terminal.get("outcome") != "completed":
		_failures.append("native_ended_callback_not_completed")
	if natural_completion.get("outcome") != "completed":
		_failures.append("natural_coordinator_outcome_not_completed")
	var natural_admission: Dictionary = _admissions.get(natural_token, {})
	var natural_down_ms := (natural_dispatch \
		- int(natural_admission.get("at_usec", natural_dispatch))) / 1000.0
	var natural_recovery_ms := _elapsed_ms(natural_terminal, natural_completion)
	if natural_down_ms < 100.0: _failures.append("native_down_fade_too_short")
	if natural_recovery_ms < 160.0: _failures.append("native_recovery_fade_too_short")
	if not _mix_matches(0.0): _failures.append("natural_recovery_gain_not_restored")
	report["natural"] = {
		"token": natural_token,
		"admission": natural_admission,
		"dispatch_observed_at_usec": natural_dispatch,
		"down_observed_ms": natural_down_ms,
		"dispatch_state": natural_dispatch_state,
		"native_terminal": natural_terminal,
		"coordinator_completion": natural_completion,
		"terminal_to_completion_ms": natural_recovery_ms,
		"mix_db_after_recovery": _mix_db(),
	}

	var stopped: Dictionary = _coordinator.call(&"request_speech",
		_specimen(selected_locale, true),
		selected_locale, &"normal", "native.probe.stop")
	if not stopped.get("ok", false):
		_failures.append("stop_request_refused")
		await _finish(report)
		return
	var stopped_token := int(stopped.value.token)
	if not await _wait_dispatched(stopped_token):
		_failures.append("stop_dispatch_timeout")
		await _finish(report)
		return
	var stopped_dispatch := Time.get_ticks_usec()
	var stopped_dispatch_state := _capture_duck_state(before)
	_check_dispatch_state(stopped_dispatch_state, "stopped")
	var stopped_admission: Dictionary = _admissions.get(stopped_token, {})
	var stopped_down_ms := (stopped_dispatch \
		- int(stopped_admission.get("at_usec", stopped_dispatch))) / 1000.0
	if stopped_down_ms < 100.0: _failures.append("stop_down_fade_too_short")
	var stop_requested := Time.get_ticks_usec()
	var stopped_result: Dictionary = _coordinator.call(&"stop", &"native_probe_stop")
	if not stopped_result.get("ok", false) or not stopped_result.value.get("stopped", false):
		_failures.append("native_stop_refused")
	if not await _wait_completed(stopped_token):
		_failures.append("stop_recovery_timeout")
		await _finish(report)
		return
	var stopped_completion: Dictionary = _completions.get(stopped_token, {})
	var stop_recovery_ms := (int(stopped_completion.get("at_usec", 0)) \
		- stop_requested) / 1000.0
	if stopped_completion.get("outcome") != "native_probe_stop":
		_failures.append("explicit_stop_outcome_changed")
	if stop_recovery_ms < 160.0: _failures.append("stop_recovery_fade_too_short")
	if _native_terminals.has(stopped_token):
		_failures.append("explicit_stop_native_callback_was_not_retired")
	if not _mix_matches(0.0): _failures.append("stop_recovery_gain_not_restored")
	report["stopped"] = {
		"token": stopped_token,
		"admission": stopped_admission,
		"dispatch_observed_at_usec": stopped_dispatch,
		"down_observed_ms": stopped_down_ms,
		"dispatch_state": stopped_dispatch_state,
		"stop_requested_at_usec": stop_requested,
		"coordinator_completion": stopped_completion,
		"stop_to_completion_ms": stop_recovery_ms,
		"mix_db_after_recovery": _mix_db(),
		"port_terminal_emitted": _native_terminals.has(stopped_token),
	}
	await _finish(report)


func _select_locale() -> String:
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		var capability: Dictionary = _coordinator.call(&"refresh_capability", locale)
		if capability.get("ok", false) and capability.value.get("available", false):
			return locale
	return ""


func _wait_services_ready() -> bool:
	var deadline: int = Time.get_ticks_usec() + 1_000_000
	while Time.get_ticks_usec() < deadline:
		if _coordinator.is_node_ready() \
				and is_instance_valid(_coordinator.get("_port")) \
				and is_instance_valid(_coordinator.get("_duck")):
			return true
		await process_frame
	return false


func _wait_compatible_locale() -> String:
	var deadline: int = Time.get_ticks_usec() + 3_000_000
	while Time.get_ticks_usec() < deadline:
		var locale := _select_locale()
		if not locale.is_empty(): return locale
		await process_frame
	return ""


func _specimen(locale: String, long_form: bool) -> String:
	if locale == "zh_CN":
		return "系统语音停止验证将在测试请求停止前保持活动。" if long_form \
			else "系统语音回调验证完成。"
	if locale == "zh_HK":
		return "系統語音停止驗證會在測試要求停止前維持運作。" if long_form \
			else "系統語音回調驗證完成。"
	return "This system speech stop verification remains active until stopped." \
		if long_form else "System speech callback verification complete."


func _capture_game_buses() -> Dictionary:
	var result := {}
	for bus_name: StringName in GAME_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0: continue
		result[bus_name] = {"send": AudioServer.get_bus_send(index),
			"db": AudioServer.get_bus_volume_db(index),
			"muted": AudioServer.is_bus_mute(index)}
	return result


func _capture_duck_state(before: Dictionary) -> Dictionary:
	var mix_index := AudioServer.get_bus_index(&"Game Mix")
	var children := {}
	for bus_name: StringName in GAME_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0: continue
		children[bus_name] = {"send": AudioServer.get_bus_send(index),
			"db": AudioServer.get_bus_volume_db(index),
			"muted": AudioServer.is_bus_mute(index),
			"gain_unchanged": before.has(bus_name) \
				and is_equal_approx(AudioServer.get_bus_volume_db(index), before[bus_name].db),
			"mute_unchanged": before.has(bus_name) \
				and AudioServer.is_bus_mute(index) == before[bus_name].muted}
	return {"mix_index": mix_index,
		"mix_send": AudioServer.get_bus_send(mix_index) if mix_index >= 0 else &"",
		"mix_db": AudioServer.get_bus_volume_db(mix_index) if mix_index >= 0 else NAN,
		"children": children}


func _check_dispatch_state(state: Dictionary, label: String) -> void:
	if state.mix_index != 1 or state.mix_send != &"Master" \
			or not is_equal_approx(float(state.mix_db), -12.0):
		_failures.append(label + "_game_mix_not_fully_ducked")
	for bus_name: StringName in GAME_BUSES:
		if not state.children.has(bus_name) \
				or state.children[bus_name].send != &"Game Mix" \
				or not state.children[bus_name].gain_unchanged \
				or not state.children[bus_name].mute_unchanged:
			_failures.append(label + "_child_bus_contract_failed_" + String(bus_name))


func _wait_dispatched(token: int) -> bool:
	var deadline := Time.get_ticks_usec() + DEADLINE_USEC
	while Time.get_ticks_usec() < deadline:
		var active: Variant = _coordinator.get("_active")
		if typeof(active) == TYPE_DICTIONARY and int(active.get("token", 0)) == token \
				and bool(active.get("dispatched", false)):
			return true
		if _completions.has(token): return false
		await process_frame
	return false


func _wait_completed(token: int) -> bool:
	var deadline := Time.get_ticks_usec() + DEADLINE_USEC
	while Time.get_ticks_usec() < deadline:
		if _completions.has(token): return true
		await process_frame
	return false


func _on_admitted(token: int, source: String) -> void:
	_admissions[token] = {"at_usec": Time.get_ticks_usec(), "source": source}


func _on_native_terminal(token: int, outcome: StringName) -> void:
	_native_terminals[token] = {"at_usec": Time.get_ticks_usec(),
		"outcome": String(outcome)}


func _on_completed(token: int, outcome: StringName) -> void:
	_completions[token] = {"at_usec": Time.get_ticks_usec(),
		"outcome": String(outcome), "mix_db": _mix_db()}


func _elapsed_ms(start: Dictionary, finish: Dictionary) -> float:
	if not start.has("at_usec") or not finish.has("at_usec"): return -1.0
	return (int(finish.at_usec) - int(start.at_usec)) / 1000.0


func _mix_matches(expected: float) -> bool:
	var actual: float = _mix_db()
	return is_finite(actual) and is_equal_approx(actual, expected)


func _mix_db() -> float:
	var index := AudioServer.get_bus_index(&"Game Mix")
	return NAN if index < 0 else AudioServer.get_bus_volume_db(index)


func _finish(report: Dictionary) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.call(&"stop", &"native_probe_cleanup")
		var deadline: int = Time.get_ticks_usec() + 1_000_000
		var recovering: Dictionary = _coordinator.get("_recovering")
		while not recovering.is_empty() \
				and Time.get_ticks_usec() < deadline:
			await process_frame
			recovering = _coordinator.get("_recovering")
	if is_instance_valid(_duck): _duck.call(&"reset")
	report["routing_restored"] = _routing_restored(report.get("buses_before", {}))
	report["failures"] = _failures.duplicate()
	report["ok"] = _failures.is_empty()
	report["result_path"] = _result_path
	var file := FileAccess.open(_result_path, FileAccess.WRITE)
	if file == null:
		_failures.append("result_write_failed")
	else:
		file.store_string(JSON.stringify(report) + "\n")
		file.close()
	report["failures"] = _failures.duplicate()
	report["ok"] = _failures.is_empty()
	print("SYSTEM_TTS_NATIVE_RESULT " + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _routing_restored(before: Variant) -> bool:
	if typeof(before) != TYPE_DICTIONARY or AudioServer.get_bus_index(&"Game Mix") >= 0:
		return false
	var expected: Dictionary = before
	for bus_name: StringName in GAME_BUSES:
		if not expected.has(bus_name): return false
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0 or AudioServer.get_bus_send(index) != expected[bus_name].send \
				or not is_equal_approx(AudioServer.get_bus_volume_db(index), expected[bus_name].db) \
				or AudioServer.is_bus_mute(index) != expected[bus_name].muted:
			return false
	return true
