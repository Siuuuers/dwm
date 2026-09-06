extends "res://addons/gut/test.gd"
const OWNERS := preload("res://tests/unit/test_settings_controls_reset.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
var _surface: SubViewport
var _input_backup: Dictionary = {}

func before_each() -> void:
	for action in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)

func after_each() -> void:
	for action in InputMap.get_actions():
		if not _input_backup.has(action): InputMap.erase_action(action)
	for action in _input_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event in _input_backup[action].events: InputMap.action_add_event(action, event)
	_input_backup.clear()

func _fixture(locale: String = "en", percent: int = 100, pending := false, mapped := true) -> Dictionary:
	var ops := OWNERS.FILES.new()
	var profile := OWNERS.PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(OWNERS.STORAGE.new("capture-scene.memory", ops)).ok)
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).ok)
	assert_true(localization.set_locale(locale).ok)
	assert_true(profile.set_preference(&"preferences.accessibility.text_size", percent).ok)
	assert_true(profile.set_preference(&"preferences.accessibility.large_targets", true).ok)
	if pending:
		var candidate: Dictionary = profile.get_profile_snapshot()
		candidate.input_mappings = OWNERS.SCHEMA._default_input_mappings()
		candidate.input_mappings.game_quick_save[0].physical_keycode = KEY_F
		candidate.controls_import_pending = true
		assert_true(profile.commit_prepared_profile(candidate).ok)
	var input := OWNERS.INPUT.new()
	add_child_autofree(input)
	assert_true(input.initialize(profile).ok)
	var content: Control = CONTENT.instantiate()
	content.configure_services({"profile": profile, "localization": localization, "input": input, "audio": null, "tts": null, "volume": null, "profile_reset_admission": func() -> bool: return false, "controller_mapped": func(_device: int) -> bool: return mapped})
	_surface.add_child(content)
	content.select_category("controls")
	return {"profile": profile, "input": input, "content": content, "sheet": content._controls_sheet, "ops": ops}

func _settle() -> void:
	for frame in range(4): await get_tree().process_frame

func _key(viewport: Viewport, code: int, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	viewport.push_input(event)
	await _settle()

func _press(viewport: Viewport, code: int) -> void:
	await _key(viewport, code, true)
	await _key(viewport, code, false)

func _open(f: Dictionary, action: String = "game_quick_save", slot: String = "keyboard") -> void:
	var button: Button = f.sheet.button_for(action, slot)
	button.grab_focus()
	button.pressed.emit()
	await _settle()
	assert_true(f.sheet.capture_dialog.visible)

func _capture(f: Dictionary, code: int) -> void:
	await _key(f.sheet.capture_dialog, code, true)
	assert_true(f.sheet.capture_dialog.visible, "Triggering contact stays in capture until its release")
	await _key(f.sheet.capture_dialog, code, false)

func test_native_capture_persists_one_slot_and_releases_before_destination() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	await _open(f)
	await _capture(f, KEY_F6)
	assert_false(f.sheet.capture_dialog.visible)
	assert_false(f.sheet.conflict_dialog.visible)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))
	assert_eq(f.profile.get_profile_snapshot().controls_bindings.game_quick_save.controller, before.controls_bindings.game_quick_save.controller)
	assert_eq(f.profile.get_profile_snapshot().input_mappings, before.input_mappings)
	assert_eq(_surface.gui_get_focus_owner(), f.sheet.button_for("game_quick_save", "keyboard"))

func test_native_back_and_departure_cancel_without_mutation() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var disk: Dictionary = f.ops.snapshot_persisted()
	await _open(f)
	await _press(f.sheet.capture_dialog, KEY_ESCAPE)
	assert_false(f.sheet.capture_dialog.visible)
	await _open(f)
	f.content.select_category("audio")
	await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.ops.snapshot_persisted(), disk)

func test_native_enter_activation_is_not_captured_and_echo_cannot_choose() -> void:
	var f := _fixture()
	await _settle()
	f.sheet.button_for("game_quick_save", "keyboard").grab_focus()
	await _key(_surface, KEY_ENTER, true)
	await _key(_surface, KEY_ENTER, false)
	assert_true(f.sheet.capture_dialog.visible)
	await _key(f.sheet.capture_dialog, KEY_ENTER, true, true)
	await _key(f.sheet.capture_dialog, KEY_ENTER, false)
	await _key(f.sheet.capture_dialog, KEY_F6, true, true)
	assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F5))
	assert_true(f.sheet.capture_dialog.visible)
	await _capture(f, KEY_F6)
	assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))

func test_back_retires_captured_candidate_even_before_its_release() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f)
	await _key(f.sheet.capture_dialog, KEY_F6, true)
	await _press(f.sheet.capture_dialog, KEY_ESCAPE)
	await _key(f.sheet.capture_dialog, KEY_F6, false)
	assert_false(f.sheet.capture_dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)

func test_back_retires_swap_consent_even_before_accept_release() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f)
	await _capture(f, KEY_F9)
	var dialog: ConfirmationDialog = f.sheet.conflict_dialog
	dialog.get_ok_button().grab_focus()
	await _key(dialog, KEY_ENTER, true)
	await _press(dialog, KEY_ESCAPE)
	await _key(dialog, KEY_ENTER, false)
	assert_false(dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)

func test_focus_loss_cancels_lost_release_and_allows_fresh_same_key() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f)
	await _key(f.sheet.capture_dialog, KEY_F6, true)
	f.content.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)
	# No F6 release arrived while the application was inactive.
	f.content.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _settle()
	assert_eq(_surface.gui_get_focus_owner(), f.sheet.button_for("game_quick_save", "keyboard"))
	await _open(f)
	await _capture(f, KEY_F6)
	assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))

func test_departure_consumes_both_held_candidate_and_back_until_release() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f)
	await _key(f.sheet.capture_dialog, KEY_F6, true)
	await _key(f.sheet.capture_dialog, KEY_ESCAPE, true)
	f.content.select_category("audio")
	await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	for code in [KEY_ESCAPE, KEY_F6]:
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.pressed = pressed
			_surface.push_input(event)
			assert_true(_surface.is_input_handled(), "Held capture contact remains consumed after departure: %s/%s" % [code, pressed])
			await _settle()
	assert_eq(f.profile.get_profile_snapshot(), before)

func test_second_capture_request_cannot_replace_an_open_capture() -> void:
	var f := _fixture()
	await _settle()
	await _open(f)
	f.sheet.begin_capture("game_quick_load", "keyboard")
	await _settle()
	await _capture(f, KEY_F6)
	assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))
	assert_eq(f.input.get_action_label("game_quick_load"), OS.get_keycode_string(KEY_F9))

func test_conflict_cancel_then_swap_publishes_complete_map_once() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f)
	await _capture(f, KEY_F9)
	var dialog: ConfirmationDialog = f.sheet.conflict_dialog
	assert_true(dialog.visible)
	assert_eq(dialog.gui_get_focus_owner(), dialog.get_cancel_button())
	await _press(dialog, KEY_ENTER)
	assert_false(dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)
	await _open(f)
	await _capture(f, KEY_F9)
	var publications: Array = []
	f.input.input_bindings_changed.connect(func() -> void:
		assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F9))
		assert_eq(f.input.get_action_label("game_quick_load"), OS.get_keycode_string(KEY_F5))
		publications.append(true))
	dialog.get_ok_button().grab_focus()
	await _press(dialog, KEY_ENTER)
	assert_false(dialog.visible)
	assert_eq(publications.size(), 1)

func test_stale_and_failed_swap_preserve_committed_bindings() -> void:
	for fail_storage in [false, true]:
		var f := _fixture()
		await _settle()
		await _open(f)
		await _capture(f, KEY_F9)
		if fail_storage:
			f.ops.fail_after(f.ops.operation_count() + 1)
		else:
			assert_true(f.profile.mark_line_visited("newer.confirmation").ok)
		var before: Dictionary = f.profile.get_profile_snapshot()
		var revision: int = f.profile.get_profile_revision()
		var disk: Dictionary = f.ops.snapshot_persisted()
		f.sheet.conflict_dialog.get_ok_button().grab_focus()
		await _press(f.sheet.conflict_dialog, KEY_ENTER)
		assert_eq(f.profile.get_profile_snapshot(), before)
		assert_eq(f.profile.get_profile_revision(), revision)
		assert_eq(f.ops.snapshot_persisted(), disk)
		assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F5))
		f.content.free()

func test_illegal_displacement_keeps_swap_separately_disabled() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f, "game_new_board")
	await _capture(f, KEY_F5)
	assert_true(f.sheet.conflict_dialog.visible)
	assert_true(f.sheet.conflict_dialog.get_ok_button().disabled, "Global Quick Save cannot receive displaced Space")
	assert_false(f.sheet.conflict_dialog.get_cancel_button().disabled)
	await _press(f.sheet.conflict_dialog, KEY_ESCAPE)
	assert_eq(f.profile.get_profile_snapshot(), before)

func test_controller_capture_persists_semantic_position_for_any_device() -> void:
	var f := _fixture()
	await _settle()
	await _open(f, "game_quick_save", "controller")
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_PADDLE1
		event.device = 3
		event.pressed = pressed
		f.sheet.capture_dialog.push_input(event)
		await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	assert_eq(f.profile.get_profile_snapshot().controls_bindings.game_quick_save.controller, {"kind": "joypad_button", "button_index": JOY_BUTTON_PADDLE1, "device": -1})
	assert_eq(f.sheet.button_for("game_quick_save", "controller").text, f.content.text("settings.controls.position.paddle_1"))

func test_controller_disconnect_retires_contact_and_reused_device_index_can_capture() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f, "game_quick_save", "controller")
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_PADDLE1
	event.device = 3
	event.pressed = true
	f.sheet.capture_dialog.push_input(event)
	await _settle()
	Input.joy_connection_changed.emit(3, false)
	await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)
	Input.joy_connection_changed.emit(3, true)
	await _open(f, "game_quick_save", "controller")
	for pressed in [true, false]:
		event = event.duplicate()
		event.pressed = pressed
		f.sheet.capture_dialog.push_input(event)
		await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	assert_eq(f.profile.get_profile_snapshot().controls_bindings.game_quick_save.controller, {"kind": "joypad_button", "button_index": JOY_BUTTON_PADDLE1, "device": -1})

func test_pending_import_keeps_cells_disabled_until_confirmed_restore() -> void:
	var f := _fixture("en", 100, true)
	await _settle()
	for action in OWNERS.SCHEMA.make_defaults().controls_bindings:
		for slot in ["keyboard", "controller"]: assert_true(f.sheet.button_for(action, slot).disabled)
	var before: Dictionary = f.profile.get_profile_snapshot().input_mappings
	f.content.find_child("ControlsResetButton", true, false).pressed.emit()
	await _settle()
	var dialog: ConfirmationDialog = f.content.confirmations.controls
	assert_true(dialog.visible)
	dialog.get_ok_button().grab_focus()
	await _press(dialog, KEY_ENTER)
	assert_false(f.profile.get_controls_binding_snapshot().value.import_pending)
	assert_false(f.sheet.button_for("game_quick_save", "keyboard").disabled)
	assert_eq(f.profile.get_profile_snapshot().input_mappings, before)

func test_unmapped_controller_contact_is_not_saved_as_semantic_position() -> void:
	var f := _fixture("en", 100, false, false)
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	await _open(f, "game_quick_save", "controller")
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_PADDLE1
		event.device = 3
		event.pressed = pressed
		f.sheet.capture_dialog.push_input(event)
		await _settle()
	assert_true(f.sheet.capture_dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)
	await _press(f.sheet.capture_dialog, KEY_ESCAPE)

func test_binding_cells_and_conflict_fit_nine_presentations() -> void:
	for locale in ["en", "zh_CN", "zh_HK"]:
		for percent in [100, 125, 150]:
			var f := _fixture(locale, percent)
			await _settle()
			var context := "%s %s%%" % [locale, percent]
			for action in OWNERS.SCHEMA.make_defaults().controls_bindings:
				var keyboard: Button = f.sheet.button_for(action, "keyboard")
				var controller: Button = f.sheet.button_for(action, "controller")
				assert_false(keyboard.get_global_rect().intersects(controller.get_global_rect()), context)
				for button: Button in [keyboard, controller]:
					assert_false(button.text.begins_with("settings."), context)
					var caption: Label = button.get_node("BindingCaption")
					assert_eq(caption.text, button.text, context)
					assert_ne(caption.autowrap_mode, TextServer.AUTOWRAP_OFF, context)
					assert_gte(caption.size.y + 1.0, caption.get_minimum_size().y, context)
					assert_gte(button.size.y, 64.0, context)
					assert_gte(button.size.y + 1.0, button.get_combined_minimum_size().y, context)
					assert_lte(button.get_global_rect().end.x, f.content.sheet_scroll.get_global_rect().end.x + 1, context)
			await _open(f)
			await _capture(f, KEY_F9)
			var dialog: ConfirmationDialog = f.sheet.conflict_dialog
			assert_true(dialog.visible, context)
			assert_gte(dialog.position.x, 0, context)
			assert_gte(dialog.position.y, 0, context)
			assert_lte(dialog.position.x + dialog.size.x, 800, context)
			assert_lte(dialog.position.y + dialog.size.y, 656, context)
			assert_eq(dialog.gui_get_focus_owner(), dialog.get_cancel_button(), context)
			await _press(dialog, KEY_ESCAPE)
			f.content.free()
