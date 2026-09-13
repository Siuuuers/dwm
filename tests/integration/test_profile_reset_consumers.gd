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

signal boundary_progress

class CompletionRecorder extends RefCounted:
	# Observe the real runtime's completion intent without advancing application state.
	signal completed
	var intents: Array[Dictionary] = []
	func complete_entry(intent: Dictionary) -> Dictionary:
		intents.append(intent.duplicate(true))
		completed.emit()
		return {"ok": true}


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
	assert_eq(profile.get_preference(&"preferences.accessibility.text_size"), 100)
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


func test_real_dialogic_new_game_restore_and_different_slot_boundaries_reapply_once_before_first_event() -> void:
	var file_ops: RefCounted = FAKE_OPS.new()
	var profile: Node = PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("dialogic-boundary", file_ops)).get("ok", false))
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	assert_true(bridge.bind_profile_preferences(profile).get("ok", false))
	# Semantic starts resolve the real manifest and retain the real runtime adapter. The shipped
	# label is comments + return, so its physical completion is observed without advancing a run.
	assert_true(bridge.initialize().get("ok", false), "bridge initialize for semantic starts")
	var completion := CompletionRecorder.new()
	assert_true(bridge.configure_playback_completion_port(completion).get("ok", false))
	completion.completed.connect(func() -> void: boundary_progress.emit())
	var start_failures: Array[Dictionary] = []
	bridge.entry_playback_failed.connect(func(_token: String, _entry_id: String, failure: Dictionary) -> void:
		start_failures.append(failure.duplicate(true))
		boundary_progress.emit())
	if not bridge.has_method("start_entry"):
		assert_true(false, "DialogicBridge must declare start_entry (Task 5, Ruling Y)")
		return
	var dialogic := get_node("/root/Dialogic")
	var state := {"waiting": false, "order": [], "first_values": {}}
	bridge.preference_boundary_step.connect(func(step_id: StringName) -> void:
		if state["waiting"]:
			state["order"].append(step_id)
	)
	var on_event_handled: Callable = func(event: Resource) -> void:
		if state["waiting"]:
			state["order"].append(&"first_event")
			state["first_values"] = {
				"text": float(dialogic.Settings.settings[&"text_speed"]),
				"auto": float(dialogic.Inputs.auto_advance.delay_modifier),
				"enabled": bool(dialogic.Inputs.auto_advance.enabled_until_user_input),
				"event_kind": str(event.get("event_name")),
				"event_label": str(event.get("name")),
			}
			state["waiting"] = false
			boundary_progress.emit()
	dialogic.event_handled.connect(on_event_handled)
	var cases: Array[Dictionary] = [
		{"boundary": "new_game", "reveal_speed": "fast", "auto_delay": "short", "text_multiplier": 0.5, "auto_multiplier": 0.5, "enabled": true},
		{"boundary": "stable_checkpoint_restore", "reveal_speed": "slow", "auto_delay": "long", "text_multiplier": 2.0, "auto_multiplier": 1.5, "enabled": false},
		{"boundary": "different_slot_restore", "reveal_speed": "instant", "auto_delay": "normal", "text_multiplier": 0.0, "auto_multiplier": 1.0, "enabled": true},
	]
	for boundary: Dictionary in cases:
		assert_true(profile.set_preferences({
			&"preferences.reading.reveal_speed": boundary["reveal_speed"],
			&"preferences.reading.auto_delay": boundary["auto_delay"],
			&"preferences.reading.auto_enabled": boundary["enabled"],
		}).get("ok", false), boundary["boundary"])
		dialogic.Settings.settings[&"text_speed"] = 99.0
		dialogic.Inputs.auto_advance.delay_modifier = 99.0
		dialogic.Inputs.auto_advance.enabled_until_user_input = not boundary["enabled"]
		state["order"] = []
		state["first_values"] = {}
		state["waiting"] = true
		var operations_before: int = file_ops.operation_count()
		var completions_before: int = completion.intents.size()
		# Ruling Y (DEVIATION-8) executed per R-II: the retired external path start becomes a
		# label-aware semantic start of the SAME conversation, and the receipt must prove the
		# resolved master path and label - not merely that an event fired (DEVIATION-9 item 3).
		var started: Variant = bridge.call(&"start_entry", "contact.ordinary.lavinia.day1", {
			"expected_stage": "current_entry",
			"playback_id": "profile-reset-%s" % str(boundary["boundary"]),
			"role": "primary",
			"transaction_id": "tx-profile-reset-%s" % str(boundary["boundary"]),
		}, &"canonical")
		assert_true(typeof(started) == TYPE_DICTIONARY and (started as Dictionary).get("ok", false),
			"%s: %s" % [boundary["boundary"], str(started)])
		var start_receipt: Dictionary = (started as Dictionary).get("receipt", {}) if typeof(started) == TYPE_DICTIONARY else {}
		assert_eq(str(start_receipt.get("path", "")), "res://dialogic/timelines/en/contacts/lavinia_day1.dtl",
			"%s: the semantic start resolves the exact master path" % boundary["boundary"])
		assert_eq(str(start_receipt.get("label", "")), "contact.ordinary.lavinia.day1",
			"%s: the semantic start resolves the exact label" % boundary["boundary"])
		var art_view: Node = bridge.get_art_hold_view()
		if art_view != null:
			# The installed return-only entry now has an art card. A successful semantic
			# admission deliberately waits for its real Continue before native events.
			assert_true(state["waiting"], "%s executed text before the art Continue" % boundary["boundary"])
			assert_eq(completion.intents.size(), completions_before,
				"%s completed text before the art Continue" % boundary["boundary"])
			var art_deadline := get_tree().create_timer(3.0)
			while is_instance_valid(art_view) and (not art_view.has_drawn_art() or art_view.next_button.disabled) \
					and start_failures.is_empty() and art_deadline.time_left > 0.0:
				await get_tree().process_frame
			var art_ready: bool = is_instance_valid(art_view) and art_view.has_drawn_art() \
				and not art_view.next_button.disabled and start_failures.is_empty()
			assert_true(art_ready,
				"%s art Continue never became ready" % boundary["boundary"])
			if not art_ready:
				dialogic.event_handled.disconnect(on_event_handled)
				bridge.abort_current_entry(&"art_hold_timeout_cleanup")
				dialogic.clear(1)
				return
			assert_eq(file_ops.operation_count(), operations_before,
				"%s wrote profile storage during art hold" % boundary["boundary"])
			art_view.next_button.pressed.emit()
			assert_null(bridge.get_art_hold_view(), "%s real Continue retires the art hold" % boundary["boundary"])
		# Dialogic.start admits a layout before its ready callback physically starts the
		# timeline. Wait for the observed first event AND natural completion, with a
		# finite deadline and an early exit on a real playback failure.
		var deadline := get_tree().create_timer(3.0)
		var wake_on_timeout := func() -> void: boundary_progress.emit()
		deadline.timeout.connect(wake_on_timeout)
		while (bool(state["waiting"]) or completion.intents.size() <= completions_before) \
				and start_failures.is_empty() and deadline.time_left > 0.0:
			await boundary_progress
		if deadline.timeout.is_connected(wake_on_timeout): deadline.timeout.disconnect(wake_on_timeout)
		# The completion signal fires inside Dialogic's clear/end stack. Let that stack
		# unwind before this test clears the runtime or Gut frees its bridge fixture.
		await get_tree().process_frame
		assert_true(start_failures.is_empty(), "%s playback failed: %s" % [boundary["boundary"], str(start_failures)])
		assert_false(state["waiting"], "%s did not handle a first event" % boundary["boundary"])
		assert_eq(completion.intents.size(), completions_before + 1,
			"%s did not naturally complete exactly once" % boundary["boundary"])
		if not start_failures.is_empty() or bool(state["waiting"]) or completion.intents.size() != completions_before + 1:
			assert_eq(file_ops.operation_count(), operations_before, "%s wrote profile storage" % boundary["boundary"])
			dialogic.event_handled.disconnect(on_event_handled)
			bridge.abort_current_entry(&"boundary_timeout_cleanup")
			dialogic.clear(1)
			return
		assert_eq(state["order"].slice(0, 3), [&"clear", &"profile_preferences_reapplied", &"first_event"], boundary["boundary"])
		assert_eq(state["order"].count(&"profile_preferences_reapplied"), 1, boundary["boundary"])
		assert_almost_eq(state["first_values"]["text"], boundary["text_multiplier"], 0.001, boundary["boundary"])
		assert_almost_eq(state["first_values"]["auto"], boundary["auto_multiplier"], 0.001, boundary["boundary"])
		assert_eq(state["first_values"]["enabled"], boundary["enabled"], boundary["boundary"])
		# Campaign surprise P03: an event merely firing does not prove the LABEL was reached -
		# the first handled event of a labelled start is the DialogicLabelEvent itself.
		assert_eq(str(state["first_values"].get("event_kind", "")), "Label",
			"%s: the first handled event is the label jump itself" % boundary["boundary"])
		assert_eq(str(state["first_values"].get("event_label", "")), "contact.ordinary.lavinia.day1",
			"%s: playback physically starts AT the semantic label" % boundary["boundary"])
		assert_eq(file_ops.operation_count(), operations_before, "%s wrote profile storage" % boundary["boundary"])
		# The short shipped label ends naturally during the wait. Prove the actual completion
		# releases playback before the next boundary; a late abort cannot fabricate another end.
		assert_eq(completion.intents.size(), completions_before + 1, boundary["boundary"])
		if completion.intents.size() == completions_before + 1:
			var intent: Dictionary = completion.intents.back()
			assert_eq(intent["completion_kind"], &"natural_end")
			assert_eq(intent["entry_id"], "contact.ordinary.lavinia.day1")
			assert_eq(intent["playback_token"], start_receipt.get("playback_token"))
			assert_eq(intent["transaction_id"], "tx-profile-reset-%s" % str(boundary["boundary"]))
		assert_false(bridge.has_active_playback(), boundary["boundary"])
		var cleanup: Variant = bridge.call(&"abort_current_entry", &"boundary_iteration_done")
		assert_true(typeof(cleanup) == TYPE_DICTIONARY and not (cleanup as Dictionary).get("ok", true),
			"%s late abort: %s" % [boundary["boundary"], str(cleanup)])
		assert_eq(cleanup.get("code"), &"no_active_entry")
		assert_eq(completion.intents.size(), completions_before + 1)
		dialogic.clear(1)
	dialogic.event_handled.disconnect(on_event_handled)
	for path in ["res://autoload/DialogicBridge.gd", "res://scripts/narrative/DialogicPreferenceAdapter.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["Dialogic.Settings._set", "Dialogic.Save.set_global_info", "ProjectSettings.set_setting", ".set_preference(", ".set_preferences("]:
			assert_false(source.contains(forbidden), "%s contains persistence call %s" % [path, forbidden])
