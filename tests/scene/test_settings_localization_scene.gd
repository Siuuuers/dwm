extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_OPS := preload("res://tests/support/FakeFileOps.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const REGISTRY_PATH := "res://scripts/settings/SettingsPreferenceRegistry.gd"
const RESET_LINE_ID := "line.contact.ordinary.lavinia.day1.reply.a"

var _surface: SubViewport

func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(1000, 760)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)

func before_all() -> void:
	var profile := get_node("/root/ProfileManager")
	if not bool(profile.get("_initialized")):
		assert_true(profile.initialize(STORAGE.new("settings-scene-tests", FAKE_OPS.new())).get("ok", false))
	var entries: Dictionary = MANIFEST.load_default()
	var ids: Dictionary = MANIFEST.load_ids_default()
	assert_true(entries.get("ok", false) and ids.get("ok", false))
	if not entries.get("ok", false) or not ids.get("ok", false): return
	assert_true(MANIFEST.validate_document(entries.value).get("ok", false))
	assert_true(MANIFEST.validate_ids_document(ids.value).get("ok", false))
	assert_true(profile.configure_line_registry(ids.value).get("ok", false))
	var localization := get_node("/root/LocalizationManager")
	if localization.get_readiness() == &"uninitialized":
		assert_true(localization.initialize(profile).get("ok", false))

func test_settings_controller_and_scenes_exist_with_shared_contract() -> void:
	var loaded := PROBE.load_script("res://scripts/ui/SettingsPanelController.gd")
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return
	var controller: RefCounted = loaded["value"].new()
	assert_true(controller.has_method("bind"))
	assert_true(controller.has_method("unbind"))
	for path in ["res://scenes/menu/Setting.tscn", "res://scenes/apps/SettingsApp.tscn"]:
		var scene: PackedScene = load(path)
		assert_not_null(scene, path)
		var instance: Node = scene.instantiate()
		_surface.add_child(instance)
		assert_not_null(instance.get_node_or_null("LocalePresentationRoot"), path)
		assert_not_null(instance.find_child("LanguageStatus", true, false), path)

func test_both_settings_hosts_share_languages_skip_modes_and_confirmed_resets() -> void:
	for path in ["res://scenes/menu/Setting.tscn", "res://scenes/apps/SettingsApp.tscn"]:
		var instance: Node = load(path).instantiate()
		_configure_reset_test_sink(instance)
		_surface.add_child(instance)
		var language: OptionButton = instance.find_child("LanguageOption", true, false)
		assert_eq(language.item_count, 3, path)
		assert_true(language.get_item_text(1).ends_with("[draft]"), path)
		var controls: Dictionary = instance.find_child("SettingsContent", true, false).get_controller().get("_controls")
		var skip: OptionButton = controls.get(&"preferences.reading.skip_mode")
		assert_not_null(skip, path)
		if skip == null:
			instance.free()
			continue
		assert_eq([skip.get_item_metadata(0), skip.get_item_metadata(1)], ["read_only", "all_text"])
		var profile := get_node("/root/ProfileManager")
		assert_true(profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
		var reset_button: Button = instance.find_child("PreferencesResetButton", true, false)
		var confirmation: ConfirmationDialog = instance.find_child("PreferencesResetConfirmation", true, false)
		assert_not_null(reset_button, path)
		assert_not_null(confirmation, path)
		reset_button.pressed.emit()
		assert_true(profile.get_preference(&"preferences.accessibility.high_contrast"), path)
		confirmation.confirmed.emit()
		assert_false(profile.get_preference(&"preferences.accessibility.high_contrast"), path)
		instance.free()

func test_shared_controller_exposes_closed_settings_allowlist_without_dark_or_legacy_aliases() -> void:
	var instance: Node = load("res://scenes/menu/Setting.tscn").instantiate()
	_surface.add_child(instance)
	var controller: RefCounted = instance.find_child("SettingsContent", true, false).get_controller()
	var controls: Dictionary = controller.get("_controls")
	var expected: Array = _accepted_settings_paths()
	assert_eq(controls.size(), expected.size())
	if controls.size() != expected.size():
		instance.free()
		return
	for path in expected:
		assert_true(controls.has(StringName(path)), path)
	for forbidden in [
		&"preferences.language",
		&"preferences.language.dual_enabled",
		&"preferences.language.secondary_locale_id",
		&"preferences.dialogue.skip_mode",
		&"preferences.audio.voice_volume",
		&"preferences.display.fullscreen",
		&"preferences.accessibility.colorblind_mode",
	]:
		assert_false(controls.has(forbidden), "%s must not be rendered" % forbidden)
	if not controls.has(&"preferences.reading.skip_mode"):
		instance.free()
		return
	var profile := get_node("/root/ProfileManager")
	var music_slider: HSlider = controls[&"preferences.audio.music_volume"]
	assert_not_null(music_slider)
	var skip: OptionButton = controls[&"preferences.reading.skip_mode"]
	skip.select(1)
	skip.item_selected.emit(1)
	assert_eq(profile.get_preference(&"preferences.reading.skip_mode"), "all_text")
	var colorblind: OptionButton = controls[&"preferences.accessibility.colour_differentiation"]
	colorblind.select(2)
	colorblind.item_selected.emit(2)
	assert_eq(profile.get_preference(&"preferences.accessibility.colour_differentiation"), "deutan")
	instance.free()

func test_each_reset_is_inert_until_its_own_confirmation() -> void:
	var instance: Node = load("res://scenes/menu/Setting.tscn").instantiate()
	_configure_reset_test_sink(instance)
	_surface.add_child(instance)
	var profile := get_node("/root/ProfileManager")
	assert_true(profile.mark_line_visited(RESET_LINE_ID).get("ok", false))
	assert_true(profile.unlock_ending("ending.alone", "settings-reset-gallery").get("ok", false))
	var window_mode: Dictionary = profile.set_preference(&"preferences.display.window_mode", "borderless")
	assert_true(window_mode.get("ok", false), str(window_mode))
	if not window_mode.get("ok", false):
		instance.free()
		return
	_assert_reset_requires_confirmation(instance, "VisitedHistory", func() -> bool: return profile.is_line_visited(RESET_LINE_ID))
	assert_false(profile.is_line_visited(RESET_LINE_ID))
	_assert_reset_requires_confirmation(instance, "Gallery", func() -> bool: return profile.has_gallery_unlock("ending.alone"))
	assert_false(profile.has_gallery_unlock("ending.alone"))
	_assert_reset_requires_confirmation(instance, "Preferences", func() -> bool: return profile.get_preference(&"preferences.display.window_mode") == "borderless")
	assert_eq(profile.get_preference(&"preferences.display.window_mode"), "windowed")
	assert_true(profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
	_assert_reset_requires_confirmation(instance, "EntireProfile", func() -> bool: return profile.get_preference(&"preferences.accessibility.high_contrast"))
	assert_false(profile.get_preference(&"preferences.accessibility.high_contrast"))
	instance.free()

func _assert_reset_requires_confirmation(instance: Node, prefix: String, still_present: Callable) -> void:
	var button: Button = instance.find_child("%sResetButton" % prefix, true, false)
	var confirmation: ConfirmationDialog = instance.find_child("%sResetConfirmation" % prefix, true, false)
	assert_not_null(button, prefix)
	assert_not_null(confirmation, prefix)
	button.pressed.emit()
	assert_true(still_present.call(), "%s mutated before confirmation" % prefix)
	confirmation.confirmed.emit()
	confirmation.hide()


func _accepted_settings_paths() -> Array:
	var suffixes: Array = [
		"language.primary_locale_id",
		"reading.reveal_speed", "reading.auto_enabled", "reading.auto_delay", "reading.skip_mode",
		"reading.read_aloud_enabled", "reading.read_aloud_rate",
		"audio.master_volume", "audio.master_muted", "audio.music_volume", "audio.music_muted",
		"audio.ambience_volume", "audio.ambience_muted", "audio.sfx_volume", "audio.sfx_muted",
		"audio.mute_when_inactive", "audio.output_mode", "display.window_mode",
		"accessibility.text_size", "accessibility.large_targets", "accessibility.high_contrast",
		"accessibility.reduced_motion", "accessibility.steady_interface", "accessibility.screen_shake", "accessibility.colour_differentiation",
		"accessibility.sound_detail_text", "exceptional_replay.available", "exceptional_replay.replay_full", "dark_mode.next_run_enabled",
	]
	return suffixes.map(func(suffix: String) -> String: return "preferences." + suffix)

func test_task9_hosts_instance_the_same_shared_content_scene() -> void:
	var shared: PackedScene = load("res://scenes/shared/SettingsContent.tscn")
	assert_not_null(shared)
	for path: String in ["res://scenes/menu/Setting.tscn", "res://scenes/apps/SettingsApp.tscn"]:
		var instance: Node = autofree(load(path).instantiate())
		var content: Node = instance.find_child("SettingsContent", true, false)
		assert_not_null(content, "Both hosts must instance the shared SettingsContent: " + path)
		if content != null:
			assert_eq(content.scene_file_path, "res://scenes/shared/SettingsContent.tscn")

class FakeSettingsProfile:
	extends RefCounted
	signal preference_changed(path: StringName, value: Variant)
	const PREFERENCES := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
	var values: Dictionary = {}
	var commits: Array = []
	var direct_resets: Array = []
	var reset_revisions: Array = []
	func get_profile_revision() -> int:
		return commits.size() + direct_resets.size()
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return values.get(path, PREFERENCES.default_value(path) if PREFERENCES.default_value(path) != null else fallback)
	func set_preference(path: StringName, value: Variant) -> Dictionary:
		var valid: Dictionary = PREFERENCES.validate(path, value)
		if not valid["ok"]:
			return valid
		values[path] = value
		commits.append({"path": path, "value": value})
		preference_changed.emit(path, value)
		return {"ok": true, "code": &"ok"}
	func reset_preferences(expected_revision: int = -1) -> Dictionary:
		direct_resets.append("reset_preferences")
		reset_revisions.append(expected_revision)
		return {"ok": true}
	func reset_entire_profile(expected_revision: int = -1) -> Dictionary:
		direct_resets.append("reset_entire_profile")
		reset_revisions.append(expected_revision)
		return {"ok": true}

class FakeVolumeSink:
	extends RefCounted
	var profile: RefCounted
	var previews: Array = []
	var resets: Array = []
	var commits: Array = []
	var cancellations: Array = []
	var effective: float = 0.8
	var reject_commit: bool = false
	var next_id: int = 0
	var active_handle: Variant = null
	func preview_settings_volume(holder: StringName, path: StringName, value: float, handle: Variant = null) -> Dictionary:
		if handle == null:
			next_id += 1
			handle = {"id": next_id, "holder": holder, "path": path}
		previews.append({"value": value, "handle": handle})
		active_handle = handle
		effective = value
		return {"ok": true, "code": &"ok", "value": {"preview_handle": handle}}
	func commit_settings_audio_preference(holder: StringName, path: StringName, value: Variant, handle: Variant = null) -> Dictionary:
		commits.append({"holder": holder, "path": path, "value": value, "handle": handle})
		if reject_commit:
			effective = float(profile.get_preference(path)) if value is float else effective
			return {"ok": false, "code": &"settings_publication_failed"}
		return profile.set_preference(path, value)
	func cancel_settings_volume_preview(handle: Variant) -> Dictionary:
		cancellations.append(handle)
		if handle == active_handle:
			effective = float(profile.get_preference(handle["path"]))
			active_handle = null
		return {"ok": true, "code": &"ok"}
	func commit_settings_profile_reset(holder: StringName, method: StringName, expected_revision: int = -1) -> Dictionary:
		resets.append({"holder": holder, "method": method, "expected_revision": expected_revision})
		return {"ok": false, "code": &"synthetic_reset_refused"}

class FakeSettingsAudio:
	extends RefCounted
	signal settings_preview_finished(handle: Dictionary, result: Dictionary)
	var starts: Array = []
	var stops: Array = []
	var sfx: Array[String] = []
	var available: bool = false
	func start_settings_preview(holder: StringName, channel: StringName) -> Dictionary:
		starts.append(channel)
		if not available:
			return {"ok": false, "code": &"audio_preview_unavailable"}
		return {"ok": true, "code": &"ok", "value": {"channel": channel, "handle": {"holder": holder, "channel": channel, "id": starts.size()}}}
	func stop_settings_preview(handle: Variant) -> Dictionary:
		stops.append(handle)
		return {"ok": true, "code": &"ok"}
	func play_sfx(cue_id: String, _context: Dictionary = {}) -> Dictionary:
		sfx.append(cue_id)
		return {"ok": true, "code": &"ok"}

class FakeSettingsTts:
	extends RefCounted
	signal speech_admitted(token: int, source_id: String)
	signal speech_completed(token: int, outcome: StringName)
	var available: bool = true
	var requests: Array = []
	var stops: Array = []
	var source_stops: Array = []
	var active_source: String = ""
	var recovery_waits: int = 0
	func refresh_capability(_locale: String) -> Dictionary:
		return {"ok": true, "value": {"available": available}}
	func request_speech(text: String, locale: String, rate: StringName, source: String) -> Dictionary:
		requests.append({"text": text, "locale": locale, "rate": rate, "source": source})
		active_source = source
		return {"ok": true, "value": {"token": requests.size()}}
	func stop_source(source: String, reason: StringName) -> Dictionary:
		source_stops.append({"source": source, "reason": reason})
		var stopped := source == active_source
		if source == active_source:
			active_source = ""
		return {"ok": true, "value": {"stopped": stopped}}
	func is_speaking(source: String) -> bool:
		return not source.is_empty() and source == active_source
	func wait_until_recovered():
		recovery_waits += 1
	func stop(reason: StringName) -> Dictionary:
		stops.append(reason)
		active_source = ""
		return {"ok": true}
	func get_state() -> Dictionary:
		return {"available": available, "state": &"IDLE"}

class DelayedSettingsTts:
	extends FakeSettingsTts
	signal recovery_completed()
	var delay_recovery: bool = false
	func wait_until_recovered():
		recovery_waits += 1
		if delay_recovery:
			await recovery_completed

class FailedRecoverySettingsTts:
	extends FakeSettingsTts
	func wait_until_recovered():
		recovery_waits += 1
		return {"ok": false, "code": &"duck_recovery_failed"}

class SettingsProductionSpeechPort:
	extends RefCounted
	signal utterance_finished(token: int, outcome: StringName)
	var requests: Array[Dictionary] = []
	var stops: int = 0
	func get_voices() -> Array[Dictionary]:
		return [{"id": "english", "language": "en-US", "name": "English"}]
	func speak(text: String, voice_id: String, rate: float, token: int) -> Dictionary:
		requests.append({"text": text, "voice": voice_id, "rate": rate, "token": token})
		return {"ok": true}
	func stop() -> Dictionary:
		stops += 1
		return {"ok": true}

class SettingsProductionDuckPort:
	extends RefCounted
	var begins: Array[int] = []
	var finishes: Array[int] = []
	func begin(token: int) -> Dictionary:
		begins.append(token)
		return {"ok": true}
	func finish(token: int) -> Dictionary:
		finishes.append(token)
		return {"ok": true}
	func reset() -> void:
		pass

func test_task9_pointer_drag_previews_then_commits_once_with_exact_handle() -> void:
	var fixture: Dictionary = _task9_fixture()
	var content: Control = fixture["content"]
	var controller: Variant = content.get_controller()
	assert_not_null(controller)
	if controller == null:
		return
	var slider: HSlider = content.control_for(&"preferences.audio.music_volume")
	assert_not_null(slider)
	slider.drag_started.emit()
	slider.value = 0.4
	slider.value = 0.5
	assert_eq(fixture["profile"].get_preference(&"preferences.audio.music_volume"), 0.8)
	assert_eq(fixture["volume"].commits.size(), 0)
	slider.drag_ended.emit(true)
	assert_eq(fixture["volume"].commits.size(), 1)
	assert_eq(fixture["profile"].get_preference(&"preferences.audio.music_volume"), 0.5)
	assert_eq(fixture["volume"].commits[0]["handle"], fixture["volume"].previews[0]["handle"])

func test_task9_discrete_volume_steps_and_failure_restore_committed_visible_value() -> void:
	var fixture: Dictionary = _task9_fixture()
	var controller: Variant = fixture["content"].get_controller()
	assert_not_null(controller)
	if controller == null:
		return
	await controller.step_volume(&"preferences.audio.music_volume", 1)
	assert_almost_eq(fixture["profile"].get_preference(&"preferences.audio.music_volume"), 0.85, 0.00001)
	fixture["volume"].reject_commit = true
	await controller.step_volume(&"preferences.audio.music_volume", 1)
	assert_almost_eq(fixture["content"].control_for(&"preferences.audio.music_volume").value, 0.85, 0.00001)
	assert_almost_eq(fixture["volume"].effective, 0.85, 0.00001)

func test_task9_mute_and_output_mode_use_atomic_audio_sink() -> void:
	var fixture: Dictionary = _task9_fixture()
	var controller: Variant = fixture["content"].get_controller()
	assert_not_null(controller)
	if controller == null:
		return
	await controller.commit_preference(&"preferences.audio.music_muted", true)
	await controller.commit_preference(&"preferences.audio.output_mode", "mono")
	assert_eq(fixture["volume"].commits.size(), 2)
	assert_eq(fixture["profile"].get_preference(&"preferences.audio.output_mode"), "mono")

func test_task9_audio_tests_never_autoplay_and_muted_or_zero_prevent_admission() -> void:
	var fixture: Dictionary = _task9_fixture()
	var controller: Variant = fixture["content"].get_controller()
	assert_not_null(controller)
	if controller == null:
		return
	assert_eq(fixture["audio"].starts, [])
	await controller.toggle_test("Music")
	assert_eq(fixture["content"].test_status("Music"), _settings_text("settings.status.unavailable"))
	fixture["profile"].set_preference(&"preferences.audio.master_muted", true)
	await controller.toggle_test("Music")
	assert_eq(fixture["audio"].starts.size(), 1)
	assert_eq(fixture["content"].test_status("Music"), _settings_text("settings.status.muted"))
	fixture["profile"].set_preference(&"preferences.audio.master_muted", false)
	fixture["profile"].set_preference(&"preferences.audio.music_volume", 0.0)
	await controller.toggle_test("Music")
	assert_eq(fixture["audio"].starts.size(), 1)
	assert_eq(fixture["content"].test_status("Music"), _settings_text("settings.status.zero"))

func test_task9_test_replacement_and_back_precedence_preserve_host() -> void:
	var fixture: Dictionary = _task9_fixture()
	var content: Control = fixture["content"]
	var controller: Variant = content.get_controller()
	assert_not_null(controller)
	if controller == null:
		return
	fixture["audio"].available = true
	content.select_category("audio")
	content.focus_sheet()
	await controller.toggle_test("Music")
	await controller.toggle_test("Ambience")
	assert_eq(fixture["audio"].stops.size(), 1)
	assert_eq(fixture["audio"].starts, [&"Music", &"Ambience"])
	await content.handle_back()
	assert_eq(fixture["audio"].stops.size(), 2)
	assert_true(content.sheet_has_focus())
	await content.handle_back()
	assert_false(content.sheet_has_focus())

func test_task9_tts_test_works_while_read_aloud_off_and_uses_frozen_specimen() -> void:
	var fixture: Dictionary = _task9_fixture()
	var controller: Variant = fixture["content"].get_controller()
	assert_not_null(controller)
	if controller == null:
		return
	assert_false(fixture["profile"].get_preference(&"preferences.reading.read_aloud_enabled"))
	assert_eq(fixture["tts"].requests, [])
	await controller.toggle_test("TTS")
	assert_eq(fixture["tts"].requests[0]["text"], "This is a reading test.")
	assert_eq(fixture["tts"].requests[0]["rate"], &"normal")
	assert_eq(fixture["profile"].commits, [])

func test_task9_reading_omits_internal_duck_preference_but_registry_retains_it() -> void:
	var fixture: Dictionary = _task9_fixture()
	var path := &"preferences.reading.lower_background_during_narration"
	assert_null(fixture["content"].control_for(path), "The uniform TTS duck has no visible preference row")
	var registry: GDScript = load(REGISTRY_PATH)
	assert_true(registry.validate(path, false).get("ok", false), "Existing stored values remain registered")
	assert_eq(registry.default_value(path), true)

func test_task9_settings_stops_only_the_source_owned_by_its_detached_test() -> void:
	var fixture: Dictionary = _task9_fixture()
	var controller: RefCounted = fixture["content"].get_controller()
	await controller.toggle_test("TTS")
	var source: String = fixture["tts"].requests[0]["source"]
	assert_true(fixture["tts"].is_speaking(source))
	await controller.stop_test()
	assert_eq(fixture["tts"].source_stops, [{"source": source, "reason": &"settings_departure"}])
	assert_eq(fixture["tts"].stops, [], "A Settings departure must not issue an unowned global stop")
	assert_eq(fixture["tts"].recovery_waits, 1)
	assert_false(fixture["tts"].is_speaking(source))

func test_task9_deliberate_tts_stop_confirms_only_after_owned_recovery() -> void:
	var fixture: Dictionary = _task9_fixture()
	var controller: RefCounted = fixture["content"].get_controller()
	await controller.toggle_test("TTS")
	await controller.toggle_test("TTS")
	assert_eq(fixture["tts"].source_stops.size(), 1)
	assert_eq(fixture["tts"].recovery_waits, 1)
	assert_eq(fixture["audio"].sfx, ["button_accept"],
		"Only the deliberate visible Stop confirms after speech and duck settlement")
	await controller.toggle_test("TTS")
	await controller.stop_test()
	assert_eq(fixture["audio"].sfx, ["button_accept"],
		"Lifecycle/source retirement has no positive confirmation")

func test_task9_failed_duck_recovery_suppresses_stop_confirmation_and_reports_failure() -> void:
	var tts := FailedRecoverySettingsTts.new()
	var fixture: Dictionary = _task9_fixture(true, false, false, tts)
	var controller: RefCounted = fixture["content"].get_controller()
	await controller.toggle_test("TTS")
	await controller.toggle_test("TTS")
	assert_eq(tts.source_stops.size(), 1, "The exact owned speech is still retired")
	assert_eq(tts.recovery_waits, 1)
	assert_eq(fixture["audio"].sfx, [], "Failed duck recovery cannot emit a positive confirmation")
	assert_eq(fixture["content"].get_node("SheetScroll/Sheets/SettingsStatus").text,
		_settings_text("settings.status.failed"))

func test_task9_old_recovery_wait_cannot_stop_a_newer_settings_source() -> void:
	var tts := DelayedSettingsTts.new()
	var fixture: Dictionary = _task9_fixture(true, false, false, tts)
	var controller: RefCounted = fixture["content"].get_controller()
	await controller.toggle_test("TTS")
	var old_source: String = tts.requests[0]["source"]
	tts.delay_recovery = true
	controller.toggle_test("TTS")
	assert_eq(tts.source_stops, [{"source": old_source, "reason": &"settings_departure"}])
	await controller.toggle_test("TTS")
	var new_source: String = tts.requests[1]["source"]
	assert_ne(new_source, old_source)
	assert_true(tts.is_speaking(new_source))
	tts.recovery_completed.emit()
	await get_tree().process_frame
	assert_true(tts.is_speaking(new_source), "Old recovery completion cannot retire replacement speech")
	assert_eq(tts.source_stops.size(), 1)
	assert_eq(tts.stops, [])
	assert_eq(fixture["audio"].sfx, [], "A stale Stop interaction cannot confirm over its successor")

func test_task9_shared_settings_uses_real_speech_owner_and_projects_async_failure() -> void:
	var path := "res://autoload/SystemTtsCoordinator.gd"
	assert_true(FileAccess.file_exists(path), "The installed Primary speech owner is required")
	if not FileAccess.file_exists(path):
		return
	var loaded: Dictionary = PROBE.load_script(path)
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false):
		return
	var port := SettingsProductionSpeechPort.new()
	var duck := SettingsProductionDuckPort.new()
	var coordinator: Node = loaded["value"].new(port, duck)
	_surface.add_child(coordinator)
	for method: StringName in [&"refresh_capability", &"request_speech", &"stop_source", &"is_speaking", &"stop"]:
		assert_true(coordinator.has_method(method), String(method))
	for signal_name: StringName in [&"speech_admitted", &"speech_completed"]:
		assert_true(coordinator.has_signal(signal_name), String(signal_name))
	var fixture: Dictionary = _task9_fixture(true, false, false, coordinator)
	var controller: RefCounted = fixture["content"].get_controller()
	assert_false(fixture["content"].control_for(&"preferences.reading.read_aloud_enabled").disabled)
	var test_button: Button = fixture["content"].test_buttons["TTS"]
	assert_false(test_button.disabled, "an available OS voice admits the visible TTS Test control")
	assert_eq(fixture["content"].test_status("TTS"), "")
	test_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(port.requests.size(), 1)
	if port.requests.is_empty():
		return
	var request: Dictionary = port.requests[0]
	assert_eq(request.text, "This is a reading test.")
	assert_eq(request.voice, "english")
	assert_eq(request.rate, 1.0)
	assert_eq(duck.begins, [request.token])
	var source := String(controller.get("_tts_source"))
	assert_true(coordinator.is_speaking(source))
	port.utterance_finished.emit(request.token, &"failed")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(duck.finishes, [request.token])
	assert_eq(fixture["content"].test_buttons["TTS"].text, _settings_text("settings.test"))
	assert_eq(fixture["content"].get_node("SheetScroll/Sheets/SettingsStatus").text, _settings_text("settings.status.failed"))
	assert_eq(fixture["profile"].commits, [], "Speech failure never mutates the desired preference")

func test_task9_unavailable_tts_preserves_desired_preference_and_disables_controls() -> void:
	var fixture: Dictionary = _task9_fixture(false)
	assert_not_null(fixture["content"].get_controller())
	if fixture["content"].get_controller() == null:
		return
	fixture["profile"].set_preference(&"preferences.reading.read_aloud_enabled", true)
	assert_true(fixture["content"].control_for(&"preferences.reading.read_aloud_enabled").disabled)
	assert_true(fixture["content"].control_for(&"preferences.reading.read_aloud_rate").disabled)
	assert_true(fixture["content"].test_buttons["TTS"].disabled,
		"a missing compatible OS voice keeps Test truthful and unavailable")
	assert_eq(fixture["content"].test_status("TTS"),
		_settings_text("settings.status.no_compatible_voice"))
	assert_true(fixture["profile"].get_preference(&"preferences.reading.read_aloud_enabled"))
	assert_eq(fixture["tts"].requests, [])

func test_task9_independent_scroll_wrapping_and_exact_rail_at_all_text_sizes() -> void:
	var fixture: Dictionary = _task9_fixture()
	var content: Control = fixture["content"]
	assert_not_null(content.get_controller())
	if content.get_controller() == null:
		return
	assert_eq(content.get_category_ids(), ["language", "reading", "audio", "display", "controls", "accessibility", "records"])
	for percent: int in [100, 125, 150]:
		fixture["profile"].set_preference(&"preferences.accessibility.text_size", percent)
		content.select_category("accessibility")
		await get_tree().process_frame
		var rail: ScrollContainer = content.get_node("RailScroll")
		var sheet: ScrollContainer = content.get_node("SheetScroll")
		assert_eq(rail.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
		assert_eq(sheet.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
		assert_ne(rail, sheet)
		for label: Label in content.wrapping_labels():
			assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)

func _task9_fixture(tts_available: bool = true, delayed_volume: bool = false, title_admission: bool = false, tts_override: Object = null) -> Dictionary:
	var profile := FakeSettingsProfile.new()
	var volume: RefCounted = DelayedVolumeSink.new() if delayed_volume else FakeVolumeSink.new()
	volume.profile = profile
	var audio := FakeSettingsAudio.new()
	var tts: Object = tts_override if tts_override != null else FakeSettingsTts.new()
	if tts_override == null:
		tts.available = tts_available
	var content: Control = load("res://scenes/shared/SettingsContent.tscn").instantiate()
	if title_admission:
		content.host_context = "title"
	var services := {"profile": profile, "localization": get_node("/root/LocalizationManager"), "audio": audio, "tts": tts, "volume": volume, "input": null}
	if title_admission:
		services["profile_reset_admission"] = func() -> bool: return true
	content.configure_services(services)
	_surface.add_child(content)
	return {"content": content, "profile": profile, "volume": volume, "audio": audio, "tts": tts}

func _settings_text(key: String) -> String:
	return get_node("/root/LocalizationManager").t(key)

class DelayedVolumeSink:
	extends FakeVolumeSink
	signal release_first()
	var delayed: bool = false
	func preview_settings_volume(holder: StringName, path: StringName, value: float, handle: Variant = null) -> Dictionary:
		var result: Dictionary = super.preview_settings_volume(holder, path, value, handle)
		if not delayed:
			delayed = true
			await release_first
		return result

func test_task9_stale_drag_completion_cancels_only_its_old_handle() -> void:
	var fixture: Dictionary = _task9_fixture(true, true)
	var slider: HSlider = fixture["content"].control_for(&"preferences.audio.music_volume")
	var controller: RefCounted = fixture["content"].get_controller()
	slider.drag_started.emit()
	slider.value = 0.4
	await controller.cancel_volume_drag()
	slider.drag_started.emit()
	slider.value = 0.6
	fixture["volume"].release_first.emit()
	assert_eq(fixture["volume"].cancellations, [fixture["volume"].previews[0]["handle"]])
	assert_ne(fixture["volume"].previews[0]["handle"], fixture["volume"].previews[1]["handle"])
	slider.drag_ended.emit(true)
	assert_eq(fixture["volume"].commits.size(), 1)
	assert_eq(fixture["volume"].commits[0]["handle"], fixture["volume"].previews[1]["handle"])

func test_task9_missing_audio_sink_has_no_direct_profile_write_fallback() -> void:
	var profile := FakeSettingsProfile.new()
	var content: Control = load("res://scenes/shared/SettingsContent.tscn").instantiate()
	content.configure_services({"profile": profile, "localization": get_node("/root/LocalizationManager"), "audio": null, "tts": null, "volume": null, "input": null})
	_surface.add_child(content)
	assert_false(content.control_for(&"preferences.audio.music_volume").editable)
	assert_true(content.control_for(&"preferences.audio.master_muted").disabled)
	await content.get_controller().commit_preference(&"preferences.audio.music_volume", 0.25)
	assert_eq(profile.commits, [])
	assert_eq(profile.get_preference(&"preferences.audio.music_volume"), 0.8)

func test_task9_exact_localized_tts_specimens_and_rates_use_no_receipt_api() -> void:
	var fixture: Dictionary = _task9_fixture()
	var specimens: Dictionary = {"en": "This is a reading test.", "zh_CN": "这是朗读测试。", "zh_HK": "這是朗讀測試。"}
	for locale: String in specimens:
		fixture["profile"].values[&"preferences.language.primary_locale_id"] = locale
		fixture["profile"].values[&"preferences.reading.read_aloud_rate"] = "fast"
		await fixture["content"].get_controller().toggle_test("TTS")
		assert_eq(fixture["tts"].requests.back()["text"], specimens[locale])
		assert_eq(fixture["tts"].requests.back()["rate"], &"fast")
		await fixture["content"].get_controller().stop_test()
	assert_eq(fixture["profile"].commits, [])

func test_task9_committed_primary_locale_refreshes_shared_rail_labels() -> void:
	var instance: Node = load("res://scenes/menu/Setting.tscn").instantiate()
	_surface.add_child(instance)
	var content: Control = instance.find_child("SettingsContent", true, false)
	var localization: Node = get_node("/root/LocalizationManager")
	var original: String = localization.get_locale()
	var result: Dictionary = localization.set_locale("zh_CN")
	assert_true(result["ok"])
	assert_eq(content.get_node("RailScroll/Rail/LanguageCategory").get_child(0).text, "语言")
	assert_true(localization.set_locale(original)["ok"])
func test_task9_title_settings_reopens_after_closing_its_cached_host() -> void:
	var host := Control.new()
	host.name = "SettingHost"
	_surface.add_child(host)
	var panel: Control = load("res://scenes/menu/Setting.tscn").instantiate()
	host.add_child(panel)
	# MenuScene owns the surrounding host; the cached wrapper owns its visibility.
	panel.window_hidden.connect(host.hide)
	await panel.hide_window()
	assert_false(host.visible, "Closing title Settings closes the host that MenuScene reopens.")
	host.show()
	panel.show_window()
	assert_true(panel.is_visible_in_tree(), "Reopening the cached host must reveal its existing panel.")
class ReviewDelayedSink:
	extends FakeVolumeSink
	signal commit_ready()
	signal cancel_ready()
	var delay_commit := false
	var delay_cancel := false
	var commit_attempts := 0
	func commit_settings_audio_preference(holder: StringName, path: StringName, value: Variant, handle: Variant = null) -> Dictionary:
		commit_attempts += 1
		if delay_commit:
			await commit_ready
		return super.commit_settings_audio_preference(holder, path, value, handle)
	func cancel_settings_volume_preview(handle: Variant) -> Dictionary:
		if delay_cancel:
			await cancel_ready
		return super.cancel_settings_volume_preview(handle)

func _review_fixture() -> Dictionary:
	var profile := FakeSettingsProfile.new()
	var volume := ReviewDelayedSink.new()
	volume.profile = profile
	var audio := FakeSettingsAudio.new()
	var tts := FakeSettingsTts.new()
	var content: Control = load("res://scenes/shared/SettingsContent.tscn").instantiate()
	content.configure_services({"profile": profile, "localization": get_node("/root/LocalizationManager"), "audio": audio, "tts": tts, "volume": volume, "input": null})
	_surface.add_child(content)
	return {"content": content, "profile": profile, "volume": volume, "audio": audio, "tts": tts}

func test_review_back_cancels_pending_drag_before_returning_focus() -> void:
	var fixture := _task9_fixture(true, true)
	var controller: RefCounted = fixture["content"].get_controller()
	var slider: HSlider = fixture["content"].control_for(&"preferences.audio.music_volume")
	slider.drag_started.emit()
	slider.value = 0.4
	assert_true(await controller.back(), "Back consumes the drag before moving sheet focus")
	fixture["volume"].release_first.emit()
	assert_eq(fixture["volume"].cancellations, [fixture["volume"].previews[0]["handle"]])
	assert_eq(fixture["volume"].commits.size(), 0)

func test_review_late_tts_admission_cannot_rebind_new_test() -> void:
	var fixture := _review_fixture()
	var controller: RefCounted = fixture["content"].get_controller()
	await controller.toggle_test("TTS")
	var old_source: String = fixture["tts"].requests[0]["source"]
	await controller.stop_test()
	await controller.toggle_test("TTS")
	var new_source: String = fixture["tts"].requests[1]["source"]
	assert_ne(old_source, new_source)
	fixture["tts"].speech_admitted.emit(1, old_source)
	fixture["tts"].speech_completed.emit(1, &"DELIBERATELY_STOPPED")
	assert_eq(fixture["content"].test_buttons["TTS"].text, _settings_text("settings.stop"))
	fixture["tts"].speech_completed.emit(2, &"COMPLETED")
	assert_eq(fixture["content"].test_buttons["TTS"].text, _settings_text("settings.test"))

func test_review_old_departure_cannot_stop_test_started_after_reopen() -> void:
	var fixture := _review_fixture()
	var controller: RefCounted = fixture["content"].get_controller()
	var slider: HSlider = fixture["content"].control_for(&"preferences.audio.music_volume")
	slider.drag_started.emit()
	slider.value = 0.4
	await controller.toggle_test("TTS")
	fixture["volume"].delay_cancel = true
	controller.depart()
	await controller.toggle_test("TTS")
	var stops_before_cleanup: int = fixture["tts"].stops.size()
	fixture["volume"].cancel_ready.emit()
	fixture["volume"].delay_cancel = false
	assert_eq(fixture["tts"].requests.size(), 2)
	assert_eq(fixture["tts"].stops.size(), stops_before_cleanup, "Old departure must not stop a newly admitted Test")
	assert_eq(fixture["content"].test_buttons["TTS"].text, _settings_text("settings.stop"))

func test_review_busy_commit_restores_rejected_control_value() -> void:
	var fixture := _review_fixture()
	var controller: RefCounted = fixture["content"].get_controller()
	fixture["volume"].delay_commit = true
	controller.commit_preference(&"preferences.audio.music_volume", 0.4)
	var checkbox: CheckBox = fixture["content"].control_for(&"preferences.accessibility.high_contrast")
	checkbox.button_pressed = true
	assert_false(fixture["profile"].get_preference(&"preferences.accessibility.high_contrast"))
	assert_false(checkbox.button_pressed, "Rejected input must not appear committed")
	fixture["volume"].commit_ready.emit()
	fixture["volume"].delay_commit = false

func test_review_drag_cancel_cannot_release_unrelated_pending_commit() -> void:
	var fixture := _review_fixture()
	var controller: RefCounted = fixture["content"].get_controller()
	fixture["volume"].delay_commit = true
	controller.commit_preference(&"preferences.audio.music_volume", 0.4)
	await controller.cancel_volume_drag()
	controller.commit_preference(&"preferences.audio.output_mode", "mono")
	assert_eq(fixture["volume"].commit_attempts, 1)
	fixture["volume"].commit_ready.emit()
	fixture["volume"].delay_commit = false

func test_review_reset_labels_exist_in_each_locale_without_fallback() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/" + locale + ".json"))
		var found: Dictionary = {}
		for record: Dictionary in document["messages"]:
			found[record["id"]] = record["text"]
		for suffix: String in ["preferences", "visited_history", "gallery", "entire_profile"]:
			assert_true(found.has("settings.reset." + suffix), locale + ": " + suffix)
			assert_false(str(found.get("settings.reset." + suffix, "")).contains("?"), "Localized label must not contain encoding replacements")

func test_review_confirmation_body_and_buttons_follow_accessibility_size() -> void:
	var fixture := _review_fixture()
	fixture["content"].apply_text_size(150, true)
	for dialog: ConfirmationDialog in fixture["content"].confirmations.values():
		assert_eq(dialog.get_label().get_theme_font_size("font_size"), 36)
		for button: Button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
			assert_eq(button.get_theme_font_size("font_size"), 36)
			assert_gte(button.custom_minimum_size.y, 64.0)
func test_audio_affecting_reset_uses_physical_sink_and_never_falls_back_after_refusal() -> void:
	var f := _task9_fixture(true, false, true)
	for method: String in ["reset_preferences", "reset_entire_profile"]:
		await f["content"].get_controller().reset_profile(method)
	assert_eq(f["volume"].resets.size(), 2)
	if f["volume"].resets.size() == 2:
		assert_eq(f["volume"].resets[0]["method"], &"reset_preferences")
		assert_eq(f["volume"].resets[1]["method"], &"reset_entire_profile")
	assert_eq(f["profile"].direct_resets, [])

func test_audio_affecting_reset_without_sink_does_not_write_profile() -> void:
	var f := _task9_fixture(true, false, true)
	f["content"].get_controller().set("_volume", null)
	await f["content"].get_controller().reset_profile("reset_preferences")
	await f["content"].get_controller().reset_profile("reset_entire_profile")
	assert_eq(f["profile"].direct_resets, [])

class ConfirmedResetSink extends RefCounted:
	var profile: Object
	func commit_settings_profile_reset(_holder: StringName, method: StringName, expected_revision: int = -1) -> Dictionary:
		return profile.call(method, expected_revision) if expected_revision >= 0 else profile.call(method)

func _configure_reset_test_sink(host: Node) -> void:
	# UI confirmation routing is isolated here; physical reset proof lives in
	# test_audio_settings_transactions with real AudioManager/ProfileManager.
	var sink := ConfirmedResetSink.new()
	sink.profile = get_node("/root/ProfileManager")
	host.find_child("SettingsContent", true, false).configure_services({
		"profile": sink.profile, "localization": get_node("/root/LocalizationManager"),
		"audio": null, "tts": null, "volume": sink, "input": null,
		"profile_reset_admission": func() -> bool: return true,
	})
