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
	assert_true(profile.set_input_mapping(&"game_quick_save", custom_mapping).get("ok", false))
	assert_eq(input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))
	var changed: Dictionary = profile.set_preferences({
		&"preferences.audio.music_volume": 0.2,
		&"preferences.audio.music_muted": true,
		&"preferences.dialogue.text_speed": 2.0,
		&"preferences.dialogue.auto_text_speed": 4.0,
		&"preferences.dialogue.auto_advance_dialogue": true,
		&"preferences.accessibility.font_scale": 1.5,
	})
	assert_true(changed.get("ok", false), str(changed))
	assert_true(profile.reset_preferences().get("ok", false))
	assert_eq(localization.get_locale(), "en")
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
		&"preferences.dialogue.text_speed": 2.0,
	}).get("ok", false))
	assert_true(profile.reset_entire_profile().get("ok", false))
	assert_false(port.bus_states[&"Music"]["muted"])
	assert_almost_eq(accessibility.get_text_delay(), 0.03, 0.001)
	assert_almost_eq(float(dialogic.Settings.settings[&"text_speed"]), 1.0, 0.001)
	assert_eq(input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F5))
	assert_true(profile.get_profile_snapshot()["gallery_transaction_receipts"].has("reset-retained-receipt"))


func test_real_dialogic_new_game_restore_and_different_slot_boundaries_reapply_once_before_first_event() -> void:
	var file_ops: RefCounted = FAKE_OPS.new()
	var profile: Node = PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("dialogic-boundary", file_ops)).get("ok", false))
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	assert_true(bridge.bind_profile_preferences(profile).get("ok", false))
	var dialogic := get_node("/root/Dialogic")
	var state := {"waiting": false, "order": [], "first_values": {}}
	bridge.preference_boundary_step.connect(func(step_id: StringName) -> void:
		if state["waiting"]:
			state["order"].append(step_id)
	)
	dialogic.event_handled.connect(func(_event: Resource) -> void:
		if state["waiting"]:
			state["order"].append(&"first_event")
			state["first_values"] = {
				"text": float(dialogic.Settings.settings[&"text_speed"]),
				"auto": float(dialogic.Inputs.auto_advance.delay_modifier),
				"enabled": bool(dialogic.Inputs.auto_advance.enabled_until_user_input),
			}
			state["waiting"] = false
	)
	var cases: Array[Dictionary] = [
		{"boundary": "new_game", "text_speed": 2.0, "auto_speed": 4.0, "enabled": true},
		{"boundary": "stable_checkpoint_restore", "text_speed": 1.25, "auto_speed": 2.5, "enabled": false},
		{"boundary": "different_slot_restore", "text_speed": 3.0, "auto_speed": 5.0, "enabled": true},
	]
	for boundary: Dictionary in cases:
		assert_true(profile.set_preferences({
			&"preferences.dialogue.text_speed": boundary["text_speed"],
			&"preferences.dialogue.auto_text_speed": boundary["auto_speed"],
			&"preferences.dialogue.auto_advance_dialogue": boundary["enabled"],
		}).get("ok", false), boundary["boundary"])
		dialogic.Settings.settings[&"text_speed"] = 99.0
		dialogic.Inputs.auto_advance.delay_modifier = 99.0
		dialogic.Inputs.auto_advance.enabled_until_user_input = not boundary["enabled"]
		state["order"] = []
		state["first_values"] = {}
		state["waiting"] = true
		var operations_before: int = file_ops.operation_count()
		var started: Dictionary = bridge.start_timeline_path("res://dialogic/timelines/en/contacts/lavinia_day1.dtl")
		assert_true(started.get("ok", false), "%s: %s" % [boundary["boundary"], started])
		await wait_process_frames(5)
		assert_false(state["waiting"], "%s did not handle a first event" % boundary["boundary"])
		assert_eq(state["order"].slice(0, 3), [&"clear", &"profile_preferences_reapplied", &"first_event"], boundary["boundary"])
		assert_eq(state["order"].count(&"profile_preferences_reapplied"), 1, boundary["boundary"])
		assert_almost_eq(state["first_values"]["text"], 1.0 / float(boundary["text_speed"]), 0.001, boundary["boundary"])
		assert_almost_eq(state["first_values"]["auto"], 1.0 / float(boundary["auto_speed"]), 0.001, boundary["boundary"])
		assert_eq(state["first_values"]["enabled"], boundary["enabled"], boundary["boundary"])
		assert_eq(file_ops.operation_count(), operations_before, "%s wrote profile storage" % boundary["boundary"])
		dialogic.clear(1)
	for path in ["res://autoload/DialogicBridge.gd", "res://scripts/narrative/DialogicPreferenceAdapter.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["Dialogic.Settings._set", "Dialogic.Save.set_global_info", "ProjectSettings.set_setting", ".set_preference(", ".set_preferences("]:
			assert_false(source.contains(forbidden), "%s contains persistence call %s" % [path, forbidden])
