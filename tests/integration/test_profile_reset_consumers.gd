extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_OPS := preload("res://tests/support/FakeFileOps.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const ACCESSIBILITY := preload("res://autoload/AccessibilityManager.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const FAKE_AUDIO := preload("res://tests/support/FakeAudioPlaybackPort.gd")

func test_profile_reset_consumer_contracts_are_present() -> void:
	for path in [
		"res://autoload/LocalizationManager.gd",
		"res://autoload/AudioManager.gd",
		"res://autoload/InputManager.gd",
		"res://autoload/AccessibilityManager.gd",
		"res://autoload/DialogicBridge.gd",
	]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "%s: %s" % [path, loaded])
		if not loaded.get("ok", false):
			continue
		var consumer: Node = autofree(loaded["value"].new())
		assert_true(consumer.has_method("configure_mutation_gate"), path)


func test_preference_reset_updates_every_plan02_consumer_in_same_frame() -> void:
	var profile: Node = PROFILE.new()
	add_child_autofree(profile)
	var storage: RefCounted = STORAGE.new("profile-reset-consumers", FAKE_OPS.new())
	assert_true(profile.initialize(storage).get("ok", false))
	var localization: Node = LOCALIZATION.new()
	var input: Node = INPUT.new()
	var accessibility: Node = ACCESSIBILITY.new()
	var port: RefCounted = FAKE_AUDIO.new()
	var audio: Node = AUDIO.new(port)
	var bridge: Node = BRIDGE.new()
	for consumer in [localization, input, accessibility, audio, bridge]:
		add_child_autofree(consumer)
	assert_true(localization.initialize(profile).get("ok", false))
	assert_true(input.initialize(profile).get("ok", false))
	assert_true(accessibility.initialize(profile).get("ok", false))
	assert_true(audio.initialize(profile).get("ok", false))
	assert_true(bridge.bind_profile_preferences(profile).get("ok", false))
	assert_true(localization.set_locale("zh_HK").get("ok", false))
	var custom_mapping: Array[Dictionary] = [{
		"kind": "key", "physical_keycode": KEY_F6, "keycode": 0,
		"shift": false, "alt": false, "ctrl": false, "meta": false,
	}]
	var proposed: Dictionary = profile.prepare_controls_change("game_quick_save", "keyboard", custom_mapping[0])
	assert_true(proposed.get("ok", false))
	assert_true(profile.commit_controls_change(proposed["value"]).get("ok", false))
	assert_eq(input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))
	var changed: Dictionary = profile.set_preferences({
		&"preferences.audio.music_volume": 0.2,
		&"preferences.audio.music_muted": true,
		&"preferences.reading.reveal_speed": "fast",
		&"preferences.reading.auto_delay": "short",
		&"preferences.reading.auto_enabled": true,
		&"preferences.reading.skip_mode": "all_text",
		&"preferences.accessibility.text_size": 150,
	})
	assert_true(changed.get("ok", false), str(changed))
	var retained_language: Dictionary = _profile_language(profile)
	assert_true(profile.reset_preferences().get("ok", false))
	assert_eq(localization.get_locale(), "zh_HK", "Reset Preferences preserves the language tuple")
	assert_eq(_profile_language(profile), retained_language)
	assert_eq(profile.get_preference(&"preferences.accessibility.text_size"), 125)
	assert_eq(profile.get_preference(&"preferences.reading.skip_mode"), "read_only")
	assert_eq(input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6), "preference reset retains canonical Controls")
	assert_eq(port.bus_states[&"Music"]["muted"], false)
	assert_almost_eq(port.bus_states[&"Music"]["db"], linear_to_db(0.8), 0.001)
	assert_almost_eq(accessibility.get_text_delay(), 0.03, 0.001)
	var dialogic := get_node("/root/Dialogic")
	assert_almost_eq(float(dialogic.Settings.settings[&"text_speed"]), 1.0, 0.001)
	assert_almost_eq(float(dialogic.Inputs.auto_advance.delay_modifier), 1.0, 0.001)
	assert_false(dialogic.Inputs.auto_advance.enabled_until_user_input)
	dialogic.Settings.settings[&"text_speed"] = 9.0
	dialogic.Inputs.auto_advance.delay_modifier = 9.0
	dialogic.Inputs.auto_advance.enabled_until_user_input = true
	dialogic.timeline_started.emit()
	assert_almost_eq(float(dialogic.Settings.settings[&"text_speed"]), 1.0, 0.001)
	assert_almost_eq(float(dialogic.Inputs.auto_advance.delay_modifier), 1.0, 0.001)
	assert_false(dialogic.Inputs.auto_advance.enabled_until_user_input)
	assert_true(profile.configure_line_registry({"reply_lines": [{"line_id": "line.reset-proof"}]}).get("ok", false))
	assert_true(profile.mark_line_visited("line.reset-proof").get("ok", false))
	assert_true(profile.unlock_ending("ending.alone", "reset-retained-receipt").get("ok", false))
	var preferences_before_nonpreference_resets: Dictionary = profile.get_profile_snapshot()["preferences"]
	assert_true(profile.reset_visited_history().get("ok", false))
	assert_eq(profile.get_profile_snapshot()["visited_line_ids"], [])
	assert_eq(profile.get_profile_snapshot()["preferences"], preferences_before_nonpreference_resets)
	assert_true(profile.reset_gallery().get("ok", false))
	assert_eq(profile.get_profile_snapshot()["gallery_unlocks"], [])
	assert_true(profile.get_profile_snapshot()["gallery_transaction_receipts"].has("reset-retained-receipt"))
	assert_eq(profile.get_profile_snapshot()["preferences"], preferences_before_nonpreference_resets)
	assert_true(profile.set_preferences({
		&"preferences.audio.music_muted": true,
		&"preferences.reading.reveal_speed": "fast",
	}).get("ok", false))
	assert_true(profile.reset_entire_profile().get("ok", false))
	assert_eq(localization.get_locale(), "en", "Reset Entire Profile also resets language")
	assert_false(port.bus_states[&"Music"]["muted"])
	assert_almost_eq(accessibility.get_text_delay(), 0.03, 0.001)
	assert_almost_eq(float(dialogic.Settings.settings[&"text_speed"]), 1.0, 0.001)
	assert_eq(input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F5))
	assert_true(profile.get_profile_snapshot()["gallery_transaction_receipts"].has("reset-retained-receipt"))

func _profile_language(profile: Node) -> Dictionary:
	return profile.get_profile_snapshot()["preferences"]["language"]
