class_name SettingsPanelController
extends RefCounted

signal _preview_operation_finished()

const REGISTRY := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
const PRIMARY := &"preferences.language.primary_locale_id"
const REDUCED_MOTION := &"preferences.accessibility.reduced_motion"
const SCREEN_SHAKE := &"preferences.accessibility.screen_shake"
const WINDOW_MODE := &"preferences.display.window_mode"
const WINDOW_SIZE := &"preferences.display.window_size"
const SPECIMENS := {"en": "This is a reading test.", "zh_CN": "这是朗读测试。", "zh_HK": "這是朗讀測試。"}

var _content: Control
var _profile: Object
var _localization: Object
var _audio: Object
var _tts: Object
var _volume: Object
var _window: Object
var _input: Object
var _controls: Dictionary = {}
var _holder: StringName
var _generation: int = 0
var _busy: bool = false
var _drag: Dictionary = {}
# Native mouse contact can outlive its admitted preview after cancellation.
var _pointer_path: StringName = &""
var _preview_operations: Array[RefCounted] = []
var _test_kind: String = ""
var _audio_handle: Variant = null
var _tts_token: int = -1
var _tts_source: String = ""
var _test_generation: int = 0
var _unavailable: Dictionary = {}
var _tts_available: bool = false


func bind(content: Control, services: Dictionary) -> Dictionary:
	_content = content
	_profile = services.get("profile")
	_localization = services.get("localization")
	_audio = services.get("audio")
	_tts = services.get("tts")
	_volume = services.get("volume")
	_window = services.get("window")
	_input = services.get("input")
	_holder = StringName("settings_ui_" + str(content.get_instance_id()))
	_controls = content.controls
	if _profile == null or _localization == null:
		return _failure()
	_connect(_profile, "preference_changed", _on_preference_changed)
	_connect(_localization, "locale_changed", _on_locale_changed)
	_connect(_input, "input_bindings_changed", _on_input_bindings_changed)
	_connect(_audio, "settings_preview_finished", _on_preview_finished)
	_connect(_tts, "speech_admitted", _on_speech_admitted)
	_connect(_tts, "speech_completed", _on_speech_completed)
	for path: StringName in _controls:
		var control: Control = _controls[path]
		if control is HSlider:
			control.drag_started.connect(begin_volume_drag.bind(path))
			control.drag_ended.connect(finish_volume_drag.bind(path))
			control.value_changed.connect(_on_volume_changed.bind(path))
			control.focus_exited.connect(_on_volume_focus_exited.bind(path))
			control.visibility_changed.connect(_on_volume_visibility_changed.bind(path))
		elif control is OptionButton:
			control.item_selected.connect(func(index: int) -> void: await commit_preference(path, control.get_item_metadata(index)))
			if path == WINDOW_SIZE:
				control.get_popup().about_to_popup.connect(refresh)
		elif control is CheckBox and REGISTRY.is_player_writable(path):
			control.toggled.connect(func(value: bool) -> void: await commit_preference(path, value))
	refresh()
	return {"ok": true}


func unbind() -> void:
	depart()
	_pointer_path = &""
	_disconnect(_profile, "preference_changed", _on_preference_changed)
	_disconnect(_localization, "locale_changed", _on_locale_changed)
	_disconnect(_input, "input_bindings_changed", _on_input_bindings_changed)
	_disconnect(_audio, "settings_preview_finished", _on_preview_finished)
	_disconnect(_tts, "speech_admitted", _on_speech_admitted)
	_disconnect(_tts, "speech_completed", _on_speech_completed)
	_content = null


func refresh() -> void:
	if not is_instance_valid(_content) or _profile == null:
		return
	_content.refresh_reset_admission(_busy)
	_tts_available = false
	if _tts != null and _tts.has_method("refresh_capability"):
		var capability: Dictionary = _tts.refresh_capability(_content.current_locale())
		_tts_available = capability.get("ok", false) and capability.get("value", {}).get("available", false)
	for path: StringName in _controls:
		var control: Control = _controls[path]
		var value: Variant = _value(path)
		var disabled: bool = _busy or not REGISTRY.is_player_writable(path)
		var reason := ""
		if String(path).begins_with("preferences.audio.") and not _has_audio_sink():
			disabled = true
			reason = "settings.status.unavailable"
		elif path in [WINDOW_MODE, WINDOW_SIZE] and not _has_window_sink():
			disabled = true
			reason = "settings.status.unavailable"
		elif path == WINDOW_SIZE and _value(WINDOW_MODE) != "windowed":
			disabled = true
			reason = "settings.status.window_size_borderless"
		elif path == &"preferences.language.secondary_locale_id" and not _value(&"preferences.language.dual_enabled"):
			disabled = true
			reason = "settings.status.dual_off"
		elif path == &"preferences.reading.auto_delay" and not _value(&"preferences.reading.auto_enabled"):
			disabled = true
			reason = "settings.status.auto_off"
		elif path == SCREEN_SHAKE and _value(REDUCED_MOTION):
			disabled = true
			reason = "settings.status.reduced_motion_on"
		elif path in [&"preferences.reading.read_aloud_enabled", &"preferences.reading.read_aloud_rate"] and not _tts_available:
			disabled = true
			reason = "settings.status.unavailable" if _tts == null else "settings.status.no_compatible_voice"
		if path in [PRIMARY, &"preferences.language.secondary_locale_id", &"preferences.language.dual_enabled"]:
			if _localization.get_selectable_locales().size() < 2 and path != PRIMARY:
				disabled = true
				reason = "settings.status.locales_unavailable"
		if control is OptionButton:
			if path == WINDOW_SIZE:
				var sizes: Array = _window.get_available_window_sizes() if _has_window_sink() and _window.has_method("get_available_window_sizes") else []
				for index: int in range(control.item_count):
					control.set_item_disabled(index, control.get_item_metadata(index) not in sizes)
				if sizes.is_empty():
					disabled = true
					if reason.is_empty(): reason = "settings.status.window_size_fitted"
				if not disabled and value not in sizes: reason = "settings.status.window_size_fitted"
			if path == SCREEN_SHAKE:
				var motion_blocked: bool = bool(_value(REDUCED_MOTION))
				var retire_focus: bool = motion_blocked and (control.has_focus() or control.get_popup().visible)
				control.focus_mode = Control.FOCUS_NONE if motion_blocked else Control.FOCUS_ALL
				if motion_blocked:
					control.get_popup().hide()
				if retire_focus:
					control.release_focus()
					call_deferred("_focus_motion_control")
			for index: int in range(control.item_count):
				if control.get_item_metadata(index) == value:
					control.select(index)
			control.disabled = disabled
		elif control is CheckBox:
			control.set_pressed_no_signal(bool(value))
			control.disabled = disabled
		elif control is HSlider:
			if _drag.get("path") != path:
				control.set_value_no_signal(float(value))
			control.editable = not disabled
		var status: Label = _content.statuses[path]
		status.text = _content.text(reason) if not reason.is_empty() else ""
		if control is HSlider:
			_refresh_volume_presentation(path, reason)
		elif path == PRIMARY and control.item_count > 0:
			status.text = control.get_item_text(control.selected)
		status.visible = not status.text.is_empty()
	_content.rows[&"preferences.exceptional_replay.replay_full"].visible = bool(_value(&"preferences.exceptional_replay.available"))
	_content.apply_text_size(int(_value(&"preferences.accessibility.text_size")), bool(_value(&"preferences.accessibility.large_targets")))
	_refresh_tests()


func commit_preference(path: StringName, value: Variant, preview_handle: Variant = null) -> Dictionary:
	if not _interactive() or not _controls.has(path) or not REGISTRY.is_player_writable(path) or not REGISTRY.validate(path, value).get("ok", false) or _busy:
		refresh()
		return _failure()
	if path == SCREEN_SHAKE and _value(REDUCED_MOTION):
		refresh()
		return _failure()
	_busy = true
	refresh()
	var result: Dictionary
	if String(path).begins_with("preferences.audio."):
		result = await _volume.commit_settings_audio_preference(_holder, path, value, preview_handle) if _has_audio_sink() else _failure()
	elif path == WINDOW_SIZE:
		result = await _window.commit_settings_window_size(_holder, value) if _has_window_sink() and _value(WINDOW_MODE) == "windowed" and _window.has_method("commit_settings_window_size") else _failure()
	elif path == WINDOW_MODE:
		result = await _window.commit_settings_window_preference(_holder, value) if _has_window_sink() else _failure()
	elif path == PRIMARY:
		result = _localization.set_locale(str(value))
	elif path == &"preferences.language.secondary_locale_id" and value == _value(PRIMARY):
		# The locale owner already swaps the complete language tuple atomically.
		result = _localization.set_locale(str(_value(&"preferences.language.secondary_locale_id")))
	else:
		result = _profile.set_preference(path, value)
	_busy = false
	refresh()
	if is_instance_valid(_content):
		_content.set_general_status("" if result.get("ok", false) else "settings.status.failed")
	return result


func _has_window_sink() -> bool:
	if not is_instance_valid(_window) or not _window.has_method("get_settings_window_capability") \
		or not _window.has_method("commit_settings_window_preference"): return false
	var capability: Dictionary = _window.get_settings_window_capability()
	return capability.get("ok", false) and capability.get("value", {}).get("available", false)


func _focus_motion_control() -> void:
	if not _interactive() or not bool(_value(REDUCED_MOTION)):
		return
	var control: CheckBox = _controls[REDUCED_MOTION]
	if control.is_visible_in_tree() and not control.disabled \
			and control.get_viewport().gui_get_focus_owner() == null:
		control.grab_focus()


func step_volume(path: StringName, direction: int) -> Dictionary:
	if not _interactive() or _busy or not _controls.has(path) or not _controls[path] is HSlider \
			or not _controls[path].editable or not String(path).ends_with("_volume") or direction not in [-1, 1]:
		return _failure()
	if not _drag.is_empty():
		var handle: Variant = _detach_volume_drag()
		var generation := _generation
		if handle != null and _has_audio_sink():
			await _cancel_volume_preview(handle)
		if generation != _generation or not _interactive():
			return _failure()
	return await commit_preference(path, clampf(snappedf(float(_value(path)) + direction * 0.05, 0.05), 0.0, 1.0))


func begin_volume_drag(path: StringName) -> void:
	_pointer_path = path
	if not _interactive() or not _has_audio_sink() or _busy or not _controls.has(path) or not _controls[path] is HSlider or not _controls[path].editable:
		return
	cancel_volume_drag()
	_generation += 1
	_drag = {"path": path, "handle": null, "generation": _generation, "value": float(_value(path)), "pending": null, "busy": false, "ending": false}
	_refresh_volume_presentation(path)


func _refresh_volume_presentation(path: StringName, reason: String = "") -> void:
	if not is_instance_valid(_content):
		return
	var preview: bool = _interactive() and _drag.get("path") == path and not _drag.get("ending", false)
	var value: float = float(_drag["value"]) if preview else float(_value(path))
	_content.set_volume_value_presentation(path, value, preview, reason)


func _on_volume_focus_exited(path: StringName) -> void:
	if _drag.get("path") == path and not _drag.get("ending", false):
		await cancel_volume_drag()


func _on_volume_visibility_changed(path: StringName) -> void:
	if _controls[path].is_visible_in_tree():
		return
	# Godot drops the native grab on hide without emitting drag_ended.
	if _pointer_path == path:
		_pointer_path = &""
	if _drag.get("path") == path and not _drag.get("ending", false):
		await cancel_volume_drag()


func _on_volume_changed(value: float, path: StringName) -> void:
	if not _interactive():
		refresh()
		return
	if (_pointer_path == path and _drag.get("path") != path) \
			or (_drag.get("path") == path and _drag.get("ending", false)):
		# Cancelled contact is still physically held: it cannot become immediate steps.
		_controls[path].set_value_no_signal(float(_value(path)))
		_refresh_volume_presentation(path)
		return
	if _drag.get("path") == path:
		_drag["value"] = value
		_drag["pending"] = value
		_refresh_volume_presentation(path)
		await _flush_preview()
	else:
		await commit_preference(path, value)


func _flush_preview() -> void:
	if not _interactive() or _drag.is_empty() or _drag["busy"]:
		return
	while not _drag.is_empty() and _drag["pending"] != null:
		var generation: int = _drag["generation"]
		var value: float = _drag["pending"]
		_drag["pending"] = null
		_drag["busy"] = true
		var operation := _begin_preview_operation()
		var result: Dictionary = await _volume.preview_settings_volume(_holder, _drag["path"], value, _drag["handle"])
		var handle: Variant = result.get("value", {}).get("preview_handle")
		if generation != _generation or _drag.is_empty():
			if handle != null:
				await _cancel_volume_preview(handle)
			_finish_preview_operation(operation)
			return
		_drag["busy"] = false
		if not result.get("ok", false) or handle == null:
			await cancel_volume_drag()
			_finish_preview_operation(operation)
			if is_instance_valid(_content):
				_content.set_general_status("settings.status.failed")
			return
		_drag["handle"] = handle
		_finish_preview_operation(operation)
	if not _drag.is_empty() and _drag["ending"]:
		await _commit_drag()


func finish_volume_drag(changed: bool, path: StringName = &"") -> void:
	var ended_path := _pointer_path if path.is_empty() else path
	if _pointer_path == ended_path:
		_pointer_path = &""
	if not ended_path.is_empty() and _drag.get("path") != ended_path:
		return
	if _drag.is_empty():
		return
	_drag["ending"] = true
	_refresh_volume_presentation(_drag["path"])
	if not changed or not _interactive():
		await cancel_volume_drag()
		return
	if not _drag["busy"]:
		await _flush_preview()


func _commit_drag() -> void:
	var drag := _drag
	_drag = {}
	await commit_preference(drag["path"], drag["value"], drag["handle"])


func _detach_volume_drag() -> Variant:
	_generation += 1
	var handle: Variant = _drag.get("handle")
	var path: StringName = _drag.get("path", &"")
	_drag = {}
	if not path.is_empty() and is_instance_valid(_content):
		_controls[path].set_value_no_signal(float(_value(path)))
		_controls[path].queue_redraw()
		_refresh_volume_presentation(path)
	return handle


func cancel_volume_drag() -> void:
	var handle: Variant = _detach_volume_drag()
	if handle != null and _has_audio_sink():
		await _cancel_volume_preview(handle)
	refresh()


func _begin_preview_operation() -> RefCounted:
	var operation := RefCounted.new()
	_preview_operations.append(operation)
	return operation


func _finish_preview_operation(operation: RefCounted) -> void:
	_preview_operations.erase(operation)
	_preview_operation_finished.emit()


func _cancel_volume_preview(handle: Variant) -> void:
	var operation := _begin_preview_operation()
	await _volume.cancel_settings_volume_preview(handle)
	_finish_preview_operation(operation)


func _await_preview_operations(operations: Array[RefCounted]) -> void:
	# Await only work already issued by the departing presentation. A later
	# presentation's operations neither extend this wait nor get cancelled here.
	for operation: RefCounted in operations:
		while operation in _preview_operations:
			await _preview_operation_finished


func toggle_test(kind: String) -> void:
	if kind not in ["Music", "Ambience", "SFX", "TTS"]:
		return
	if _test_kind == kind:
		await stop_test(kind == "TTS")
		return
	if not _interactive():
		return
	var old_test := _detach_test()
	var generation := _test_generation
	await _stop_detached_test(old_test)
	if generation != _test_generation or not _interactive():
		return
	refresh()
	if kind == "TTS":
		if not _tts_available:
			return
	else:
		if not _channel_reason(kind).is_empty() or not _has_audio_samples():
			return
	_test_kind = kind
	var result: Dictionary
	if kind == "TTS":
		_tts_source = String(_holder) + ".test." + str(generation)
		result = _tts.request_speech(SPECIMENS[_content.current_locale()], _content.current_locale(), StringName(_value(&"preferences.reading.read_aloud_rate")), _tts_source)
		if generation != _test_generation or _test_kind != kind:
			return
		var token := int(result.get("value", {}).get("token", -1))
		if token >= 0:
			_tts_token = token
	else:
		var operation := _begin_preview_operation()
		result = await _audio.start_settings_preview(_holder, StringName(kind))
		var handle: Variant = result.get("value", {}).get("handle")
		if generation != _test_generation:
			if handle != null:
				await _audio.stop_settings_preview(handle)
			_finish_preview_operation(operation)
			return
		_audio_handle = handle
		_finish_preview_operation(operation)
	if not result.get("ok", false):
		_test_kind = ""
		_unavailable[kind] = true
	_refresh_tests()


func _detach_test() -> Dictionary:
	_test_generation += 1
	var test := {"kind": _test_kind, "handle": _audio_handle, "tts_source": _tts_source}
	_test_kind = ""
	_audio_handle = null
	_tts_token = -1
	_tts_source = ""
	return test


func _stop_detached_test(test: Dictionary) -> Dictionary:
	var stopped := {"ok": true, "value": {"stopped": false}}
	if test["kind"] == "TTS" and _tts != null:
		var source := String(test.get("tts_source", ""))
		var stop_result: Variant
		if not source.is_empty() and _tts.has_method("stop_source"):
			stop_result = _tts.stop_source(source, &"settings_departure")
		else:
			stop_result = _tts.stop(&"settings_departure")
		if stop_result is Dictionary: stopped = stop_result
		if _tts.has_method("wait_until_recovered"):
			var recovery: Variant = await _tts.wait_until_recovered()
			if recovery is Dictionary and not recovery.get("ok", false):
				stopped["ok"] = false
				stopped["code"] = recovery.get("code", &"speech_recovery_failed")
	elif test["handle"] != null and _audio != null:
		var operation := _begin_preview_operation()
		await _audio.stop_settings_preview(test["handle"])
		_finish_preview_operation(operation)
	_refresh_tests()
	return stopped


func stop_test(confirm_deliberate_tts_stop: bool = false) -> void:
	var test := _detach_test()
	var generation := _test_generation
	var stopped: Dictionary = await _stop_detached_test(test)
	if not stopped.get("ok", false) and generation == _test_generation \
			and is_instance_valid(_content):
		_content.set_general_status("settings.status.failed")
	if confirm_deliberate_tts_stop and test.get("kind") == "TTS" \
			and stopped.get("ok", false) and stopped.get("value", {}).get("stopped", false) \
			and generation == _test_generation and _test_kind.is_empty() and _interactive() \
			and is_instance_valid(_audio) and _audio.has_method("play_sfx"):
		_audio.play_sfx("button_accept")


func back() -> bool:
	if is_instance_valid(_content):
		if _content._controls_sheet != null and _content._controls_sheet.handle_back():
			return true
		for id: String in _content.confirmations:
			var dialog: ConfirmationDialog = _content.confirmations[id]
			if dialog.visible:
				dialog.hide()
				_content.restore_reset_focus(id)
				return true
	if not _drag.is_empty():
		await cancel_volume_drag()
		return true
	if not _test_kind.is_empty():
		await stop_test()
		return true
	return false


func depart() -> void:
	# Invalidate both identities before cleanup can yield to a reopened panel.
	var handle: Variant = _detach_volume_drag()
	var test := _detach_test()
	var pending_previews: Array[RefCounted] = _preview_operations.duplicate()
	if is_instance_valid(_content):
		if _content._controls_sheet != null:
			_content._controls_sheet.depart()
		for dialog: ConfirmationDialog in _content.confirmations.values():
			dialog.hide()
		for control: Control in _controls.values():
			if control is OptionButton:
				control.get_popup().hide()
	# Retire the detached source before the first await. A reopened presentation may
	# own a different speech source while the old duck finishes recovering.
	await _stop_detached_test(test)
	if handle != null and _has_audio_sink():
		await _cancel_volume_preview(handle)
	await _await_preview_operations(pending_previews)
	refresh()


func get_reset_revision() -> int:
	return int(_profile.get_profile_revision()) if _profile != null and _profile.has_method("get_profile_revision") else -1


func is_commit_pending() -> bool:
	return _busy


func reset_profile(method: String, expected_revision: int = -1) -> void:
	if not _interactive() or _busy or method not in ["reset_controls", "reset_preferences", "reset_visited_history", "reset_gallery", "reset_entire_profile"] or not _profile.has_method(method):
		return
	if method == "reset_entire_profile" and not _content.can_reset_entire_profile():
		_content.set_general_status("settings.status.failed")
		return
	if expected_revision >= 0 and get_reset_revision() != expected_revision:
		_content.set_general_status("settings.status.failed")
		return
	_busy = true
	refresh()
	await depart()
	if not is_instance_valid(_content):
		_busy = false
		return
	if not _interactive():
		_busy = false
		refresh()
		return
	if method == "reset_entire_profile" and not _content.can_reset_entire_profile():
		_busy = false
		refresh()
		_content.set_general_status("settings.status.failed")
		return
	if expected_revision >= 0 and get_reset_revision() != expected_revision:
		_busy = false
		refresh()
		_content.set_general_status("settings.status.failed")
		return
	var result: Dictionary
	if method in ["reset_preferences", "reset_entire_profile"]:
		if _volume == null or not _volume.has_method("commit_settings_profile_reset"):
			result = _failure()
		elif expected_revision >= 0:
			result = await _volume.commit_settings_profile_reset(_holder, StringName(method), expected_revision)
		else:
			result = await _volume.commit_settings_profile_reset(_holder, StringName(method))
	else:
		result = _profile.call(method, expected_revision) if expected_revision >= 0 else _profile.call(method)
	_busy = false
	refresh()
	if is_instance_valid(_content):
		_content.set_general_status("" if result.get("ok", false) else "settings.status.failed")


func _refresh_tests() -> void:
	if not is_instance_valid(_content):
		return
	for kind: String in _content.test_buttons:
		var active := _test_kind == kind
		var reason := ""
		if kind == "TTS":
			if not _tts_available:
				reason = "settings.status.unavailable" if _tts == null else "settings.status.no_compatible_voice"
		else:
			reason = _channel_reason(kind)
			if reason.is_empty() and (not _has_audio_samples() or _unavailable.has(kind)):
				reason = "settings.status.unavailable"
		var button: Button = _content.test_buttons[kind]
		button.text = _content.text("settings.stop" if active else "settings.test")
		button.disabled = not active and not reason.is_empty()
		_content.test_statuses[kind].text = "" if active or reason.is_empty() else _content.text(reason)


func _channel_reason(kind: String) -> String:
	var channel := kind.to_lower()
	if bool(_value(&"preferences.audio.master_muted")) or bool(_value(StringName("preferences.audio." + channel + "_muted"))):
		return "settings.status.muted"
	if float(_value(&"preferences.audio.master_volume")) <= 0.0 or float(_value(StringName("preferences.audio." + channel + "_volume"))) <= 0.0:
		return "settings.status.zero"
	return ""


func _has_audio_sink() -> bool:
	if _volume != null and _volume.has_method("get_settings_audio_capability"):
		var capability: Dictionary = _volume.get_settings_audio_capability()
		if not capability.get("ok", false) or not capability.get("value", {}).get("volume", false): return false
	return _volume != null and _volume.has_method("preview_settings_volume") and _volume.has_method("commit_settings_audio_preference") and _volume.has_method("cancel_settings_volume_preview")

func _has_audio_samples() -> bool:
	return _audio != null and _audio.has_method("start_settings_preview") and _audio.has_method("stop_settings_preview")


func _interactive() -> bool:
	return is_instance_valid(_content) and _content.is_interaction_enabled()


func _value(path: StringName) -> Variant:
	return _profile.get_preference(path, REGISTRY.default_value(path)) if _profile != null else REGISTRY.default_value(path)


func _on_preference_changed(_path: StringName, _value_changed: Variant) -> void:
	refresh()


func _on_locale_changed(_locale: String) -> void:
	stop_test()
	if is_instance_valid(_content):
		_content.refresh_labels()


func _on_input_bindings_changed() -> void:
	if is_instance_valid(_content):
		_content.refresh_binding_labels()


func _on_preview_finished(handle: Dictionary, _result: Dictionary) -> void:
	if handle == _audio_handle:
		_audio_handle = null
		_test_kind = ""
		_refresh_tests()


func _on_speech_admitted(token: int, source: String) -> void:
	if _test_kind == "TTS" and source == _tts_source:
		_tts_token = token


func _on_speech_completed(token: int, outcome: StringName) -> void:
	if _test_kind == "TTS" and token == _tts_token:
		_test_kind = ""
		_tts_token = -1
		_tts_source = ""
		if outcome == &"failed" and is_instance_valid(_content):
			_content.set_general_status("settings.status.failed")
		_refresh_tests()


static func _connect(object: Object, signal_name: String, callback: Callable) -> void:
	if object != null and object.has_signal(signal_name) and not object.is_connected(signal_name, callback):
		object.connect(signal_name, callback)


static func _disconnect(object: Variant, signal_name: String, callback: Callable) -> void:
	if is_instance_valid(object) and object.has_signal(signal_name) and object.is_connected(signal_name, callback):
		object.disconnect(signal_name, callback)


static func _failure() -> Dictionary:
	return {"ok": false, "code": &"settings_unavailable"}
