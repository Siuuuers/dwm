extends "res://addons/gut/test.gd"

const OWNERS := preload("res://tests/unit/test_settings_controls_reset.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const LEGACY := preload("res://scripts/settings/ControlsLegacyPresentation.gd")
var _surface: SubViewport
var _input_backup: Dictionary = {}


func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)


func after_each() -> void:
	for action: StringName in InputMap.get_actions():
		if not _input_backup.has(action):
			InputMap.erase_action(action)
	for action: StringName in _input_backup:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_backup[action].events:
			InputMap.action_add_event(action, event)
	_input_backup.clear()


func _fixture(locale: String = "en", percent: int = 100, nondefault_pending: bool = false) -> Dictionary:
	var ops := OWNERS.FILES.new()
	var profile := OWNERS.PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(OWNERS.STORAGE.new("import-review.memory", ops)).ok)
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).ok)
	assert_true(localization.set_locale(locale).ok)
	assert_true(profile.set_preferences({
		&"preferences.accessibility.text_size": percent,
		&"preferences.accessibility.large_targets": true,
	}).ok)
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.input_mappings = OWNERS.SCHEMA._default_input_mappings()
	candidate.input_mappings.game_quick_save.append(candidate.input_mappings.game_quick_save[0].duplicate(true))
	candidate.input_mappings.game_quick_save.append({"kind": "joypad_button", "button_index": 7, "device": 3})
	candidate.controls_import_pending = true
	if nondefault_pending:
		candidate.controls_bindings.game_quick_save.keyboard.physical_keycode = KEY_F8
	assert_true(profile.commit_prepared_profile(candidate).ok)
	var input := OWNERS.INPUT.new()
	add_child_autofree(input)
	assert_true(input.initialize(profile).ok)
	var content: Control = CONTENT.instantiate()
	content.configure_services({"profile": profile, "localization": localization, "input": input, "audio": null, "tts": null, "volume": null, "profile_reset_admission": func() -> bool: return false, "controller_mapped": func(_device: int) -> bool: return true})
	_surface.add_child(content)
	content.select_category("controls")
	return {"profile": profile, "input": input, "content": content, "sheet": content._controls_sheet, "ops": ops}


func _settle() -> void:
	for frame: int in range(4):
		await get_tree().process_frame


func _key(viewport: Viewport, code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	viewport.push_input(event)
	await _settle()


func _press(viewport: Viewport, code: int) -> void:
	await _key(viewport, code, true)
	await _key(viewport, code, false)


func _start(f: Dictionary) -> void:
	f.sheet.review_button.pressed.emit()
	await _settle()
	assert_true(f.sheet.is_reviewing_import())
	assert_eq(f.sheet.get_review_draft(), RULES.defaults())


func _capture(f: Dictionary, code: int, action: String = "game_quick_save") -> void:
	f.sheet.button_for(action, "keyboard").pressed.emit()
	await _settle()
	assert_true(f.sheet.capture_dialog.visible)
	await _key(f.sheet.capture_dialog, code, true)
	assert_true(f.sheet.capture_dialog.visible)
	await _key(f.sheet.capture_dialog, code, false)


func _confirm(f: Dictionary) -> void:
	f.sheet.apply_review_button.pressed.emit()
	await _settle()
	assert_true(f.sheet.import_dialog.visible)
	assert_eq(f.sheet.import_dialog.gui_get_focus_owner(), f.sheet.import_dialog.get_cancel_button())


func test_custom_draft_is_local_until_whole_map_confirmation_and_publishes_once() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var disk: Dictionary = f.ops.snapshot_persisted()
	var revision: int = f.profile.get_profile_revision()
	await _start(f)
	await _capture(f, KEY_F6)
	assert_true(f.sheet.is_reviewing_import(), "Closing capture preserves the review")
	assert_eq(f.sheet.get_review_draft().game_quick_save.keyboard.physical_keycode, KEY_F6)
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.ops.snapshot_persisted(), disk)
	assert_eq(_surface.gui_get_focus_owner(), f.sheet.button_for("game_quick_save", "keyboard"))
	var copy: Dictionary = f.sheet.get_review_draft()
	copy.game_quick_save.keyboard.physical_keycode = KEY_F7
	assert_eq(f.sheet.get_review_draft().game_quick_save.keyboard.physical_keycode, KEY_F6)
	await _confirm(f)
	await _press(f.sheet.import_dialog, KEY_ENTER)
	assert_true(f.sheet.is_reviewing_import(), "Initial Cancel declines activation but keeps the draft")
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(_surface.gui_get_focus_owner(), f.sheet.apply_review_button)
	await _confirm(f)
	var publications: Array = []
	f.input.input_bindings_changed.connect(func() -> void:
		assert_false(f.profile.get_profile_snapshot().controls_import_pending)
		assert_eq(f.input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))
		publications.append(true))
	f.sheet.import_dialog.get_ok_button().grab_focus()
	await _press(f.sheet.import_dialog, KEY_ENTER)
	assert_eq(publications.size(), 1)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_false(f.sheet.is_reviewing_import())
	assert_eq(f.profile.get_profile_snapshot().input_mappings, before.input_mappings)
	assert_eq(f.profile.get_profile_snapshot().controls_bindings.game_quick_save.controller, before.controls_bindings.game_quick_save.controller)
	f.sheet.import_dialog.confirmed.emit()
	assert_eq(publications.size(), 1, "Consumed confirmation cannot publish twice")


func test_local_swap_and_capture_cancel_preserve_draft_without_publishing() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var disk: Dictionary = f.ops.snapshot_persisted()
	await _start(f)
	await _capture(f, KEY_ESCAPE)
	assert_true(f.sheet.is_reviewing_import())
	await _capture(f, KEY_F9)
	assert_true(f.sheet.conflict_dialog.visible)
	await _press(f.sheet.conflict_dialog, KEY_ENTER)
	assert_eq(f.sheet.get_review_draft(), RULES.defaults())
	assert_true(f.sheet.is_reviewing_import())
	await _capture(f, KEY_F9)
	f.sheet.conflict_dialog.get_ok_button().grab_focus()
	await _press(f.sheet.conflict_dialog, KEY_ENTER)
	var draft: Dictionary = f.sheet.get_review_draft()
	assert_eq(draft.game_quick_save.keyboard.physical_keycode, KEY_F9)
	assert_eq(draft.game_quick_load.keyboard.physical_keycode, KEY_F5)
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.ops.snapshot_persisted(), disk)
	f.sheet.cancel_review_button.pressed.emit()
	await _settle()
	assert_false(f.sheet.is_reviewing_import())
	assert_eq(f.sheet.get_review_draft(), {})
	assert_eq(_surface.gui_get_focus_owner(), f.sheet.review_button)


func test_pending_nondefault_source_gets_explicit_default_draft_and_requires_apply() -> void:
	var f := _fixture("en", 100, true)
	await _settle()
	assert_eq(f.profile.get_profile_snapshot().controls_bindings.game_quick_save.keyboard.physical_keycode, KEY_F8)
	var revision: int = f.profile.get_profile_revision()
	await _start(f)
	assert_eq(f.sheet.button_for("game_quick_save", "keyboard").text, OS.get_keycode_string(KEY_F5))
	assert_true(f.profile.get_profile_snapshot().controls_import_pending)
	assert_eq(f.profile.get_profile_revision(), revision)
	await _confirm(f)
	assert_eq(f.sheet.import_dialog.get_ok_button().text, f.content.text("settings.controls.review_apply"))
	assert_eq(f.profile.get_profile_revision(), revision)
	f.sheet.import_dialog.get_ok_button().grab_focus()
	await _press(f.sheet.import_dialog, KEY_ENTER)
	assert_false(f.profile.get_profile_snapshot().controls_import_pending)
	assert_eq(f.profile.get_profile_snapshot().controls_bindings, RULES.defaults())
	assert_eq(f.profile.get_profile_revision(), revision + 1)


func test_external_departures_discard_custom_review_without_any_write() -> void:
	for departure: String in ["cancel", "depart", "category", "focus"]:
		var f := _fixture()
		await _settle()
		var before: Dictionary = f.profile.get_profile_snapshot()
		var disk: Dictionary = f.ops.snapshot_persisted()
		await _start(f)
		await _capture(f, KEY_F6)
		match departure:
			"cancel": f.sheet.cancel_review_button.pressed.emit()
			"depart": f.content.get_controller().depart()
			"category": f.content.select_category("audio")
			"focus": f.sheet.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _settle()
		assert_false(f.sheet.is_reviewing_import(), departure)
		assert_eq(f.sheet.get_review_draft(), {}, departure)
		assert_eq(f.profile.get_profile_snapshot(), before, departure)
		assert_eq(f.ops.snapshot_persisted(), disk, departure)
		assert_false(f.sheet.capture_dialog.visible)
		assert_false(f.sheet.conflict_dialog.visible)
		assert_false(f.sheet.import_dialog.visible)
		f.content.free()


func test_stale_or_failed_apply_never_activates_the_review() -> void:
	for failure: String in ["before_confirmation", "after_confirmation", "storage"]:
		var f := _fixture()
		await _settle()
		await _start(f)
		await _capture(f, KEY_F6)
		if failure != "before_confirmation":
			await _confirm(f)
		if failure == "storage":
			f.ops.fail_after(f.ops.operation_count() + 1)
		else:
			assert_true(f.profile.mark_line_visited("newer.review.revision").ok)
		var before: Dictionary = f.profile.get_profile_snapshot()
		var disk: Dictionary = f.ops.snapshot_persisted()
		if failure == "before_confirmation":
			f.sheet.apply_review_button.pressed.emit()
		else:
			f.sheet.import_dialog.get_ok_button().grab_focus()
			await _press(f.sheet.import_dialog, KEY_ENTER)
		await _settle()
		assert_false(f.sheet.import_dialog.visible)
		assert_eq(f.sheet.is_reviewing_import(), failure == "storage")
		assert_eq(f.profile.get_profile_snapshot(), before, failure)
		assert_eq(f.ops.snapshot_persisted(), disk, failure)
		assert_true(f.profile.get_profile_snapshot().controls_import_pending)
		var expected: String = f.content.text("settings.controls.failed" if failure == "storage" else "settings.controls.stale")
		assert_true(f.sheet.get_node("ControlsStatus").text.contains(expected), failure)
		if failure == "storage":
			assert_eq(f.sheet.get_review_draft().game_quick_save.keyboard.physical_keycode, KEY_F6)
			assert_eq(_surface.gui_get_focus_owner(), f.sheet.apply_review_button)
			await _settle()
			assert_eq(f.ops.snapshot_persisted(), disk, "Keeping the draft cannot automatically retry")
			await _confirm(f)
			assert_eq(f.ops.snapshot_persisted(), disk, "A fresh Apply confirmation is required for any retry")
			await _press(f.sheet.import_dialog, KEY_ESCAPE)
		f.content.free()


func test_original_records_and_complete_apply_table_fit_nine_presentations() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		for percent: int in [100, 125, 150]:
			var f := _fixture(locale, percent)
			await _settle()
			var before: Dictionary = f.profile.get_profile_snapshot()
			f.sheet.original_button.pressed.emit()
			await _settle()
			var original: ConfirmationDialog = f.sheet.original_dialog
			assert_true(original.visible)
			_assert_dialog_fit(original)
			var labels := _tagged_labels(original, "controls_legacy_action")
			assert_eq(labels.size(), 15, "Every retained legacy action is inspectable")
			var expected: Array[Dictionary] = LEGACY.rows(before.input_mappings, locale, f.content.text)
			for row: Dictionary in expected:
				assert_true(labels.has(row.action_id))
				var label: Label = labels[row.action_id]
				assert_true(label.text.contains(row.label))
				for binding: String in row.bindings:
					assert_true(label.text.contains(binding), locale + ": complete stored record")
				assert_false(label.text.contains("format_error"))
				assert_false(label.text.contains("physical_keycode"))
				assert_ne(label.autowrap_mode, TextServer.AUTOWRAP_OFF)
			assert_true(labels.game_quick_save.text.count(OS.get_keycode_string(KEY_F5)) >= 2, "Duplicate original records remain visible")
			await _press(original, KEY_ESCAPE)
			assert_false(f.sheet.is_reviewing_import(), "Inspecting evidence alone cannot start an activation draft")
			await _start(f)
			await _confirm(f)
			_assert_dialog_fit(f.sheet.import_dialog)
			var assigned := _tagged_labels(f.sheet.import_dialog, "controls_review_action")
			assert_eq(assigned.size(), 4)
			for record: Dictionary in RULES.REGISTRY.records():
				var label: Label = assigned[String(record.id)]
				assert_true(label.text.contains(f.content.text("settings.controls.keyboard")))
				assert_true(label.text.contains(f.content.text("settings.controls.controller")))
			await _press(f.sheet.import_dialog, KEY_ESCAPE)
			for button: Button in [f.sheet.original_button, f.sheet.apply_review_button, f.sheet.cancel_review_button]:
				button.grab_focus()
				await _settle()
				var caption: Label = button.get_node("BindingCaption")
				assert_eq(caption.text, button.text)
				assert_gte(button.size.y, 64.0)
				assert_gte(caption.size.y + 1, caption.get_minimum_size().y)
				assert_lte(button.get_global_rect().end.x, f.content.sheet_scroll.get_global_rect().end.x + 1)
			assert_eq(f.profile.get_profile_snapshot(), before)
			f.content.free()


func test_old_capture_cleanup_cannot_clear_a_newer_opening_guard() -> void:
	var f := _fixture()
	await _settle()
	await _start(f)
	var controller: RefCounted = f.content.get_controller()
	# These are issued-operation tokens in the real controller's settlement set;
	# physical audio behavior is covered by the Menu lifecycle suites.
	var first: RefCounted = controller._begin_preview_operation()
	f.sheet.begin_capture("game_quick_save", "keyboard")
	f.content.select_category("audio")
	f.content.select_category("controls")
	await _start(f)
	var second: RefCounted = controller._begin_preview_operation()
	f.sheet.begin_capture("game_quick_load", "keyboard")
	controller._finish_preview_operation(first)
	await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	f.sheet.begin_capture("game_new_board", "keyboard")
	controller._finish_preview_operation(second)
	await _settle()
	assert_true(f.sheet.capture_dialog.visible)
	assert_true(f.sheet.capture_dialog.dialog_text.contains("Quick Load"), "The newer opening retains custody; a third request is refused")
	await _press(f.sheet.capture_dialog, KEY_ESCAPE)
	assert_true(f.sheet.is_reviewing_import())
	assert_true(f.profile.get_profile_snapshot().controls_import_pending)


func test_original_records_scroll_by_native_keyboard_and_controller_without_losing_cancel_focus() -> void:
	var f := _fixture("en", 150)
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	f.sheet.original_button.pressed.emit()
	await _settle()
	var dialog: ConfirmationDialog = f.sheet.original_dialog
	var scroll: ScrollContainer = dialog.get_node("ReviewScroll")
	assert_eq(scroll.scroll_vertical, 0)
	await _press(dialog, KEY_DOWN)
	var after_line := scroll.scroll_vertical
	assert_gt(after_line, 0)
	await _press(dialog, KEY_PAGEDOWN)
	var after_page := scroll.scroll_vertical
	assert_gt(after_page, after_line)
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 3
		event.button_index = JOY_BUTTON_DPAD_DOWN
		event.pressed = pressed
		dialog.push_input(event)
		await _settle()
	assert_gt(scroll.scroll_vertical, after_page)
	assert_eq(dialog.gui_get_focus_owner(), dialog.get_cancel_button())
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _press(dialog, KEY_ESCAPE)
	assert_false(dialog.visible)
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(_surface.gui_get_focus_owner(), f.sheet.original_button)


func _tagged_labels(parent: Node, key: String) -> Dictionary:
	var found := {}
	for child: Node in parent.get_children():
		if child is Label and child.has_meta(key):
			found[child.get_meta(key)] = child
		found.merge(_tagged_labels(child, key))
	return found


func test_open_original_records_relocalize_without_changing_their_source() -> void:
	var f := _fixture()
	await _settle()
	var legacy: Dictionary = f.profile.get_profile_snapshot().input_mappings
	f.sheet.original_button.pressed.emit()
	await _settle()
	var before: String = _tagged_labels(f.sheet.original_dialog, "controls_legacy_action").game_quick_save.text
	assert_true(f.content._services.localization.set_locale("zh_HK").ok)
	await _settle()
	assert_true(f.sheet.original_dialog.visible)
	var labels := _tagged_labels(f.sheet.original_dialog, "controls_legacy_action")
	assert_ne(labels.game_quick_save.text, before)
	for row in LEGACY.rows(legacy, "zh_HK", f.content.text):
		assert_true(labels[row.action_id].text.contains(row.label))
		for binding in row.bindings: assert_true(labels[row.action_id].text.contains(binding))
	assert_eq(f.profile.get_profile_snapshot().input_mappings, legacy)
	assert_true(f.profile.get_profile_snapshot().controls_import_pending)
	await _press(f.sheet.original_dialog, KEY_ESCAPE)


func test_keyboard_and_controller_draft_edits_activate_together_after_final_apply() -> void:
	var f := _fixture()
	await _settle()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var disk: Dictionary = f.ops.snapshot_persisted()
	await _start(f)
	await _capture(f, KEY_F6)
	f.sheet.button_for("game_quick_load", "controller").pressed.emit()
	await _settle()
	assert_true(f.sheet.capture_dialog.visible)
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 4
		event.button_index = JOY_BUTTON_PADDLE1
		event.pressed = pressed
		f.sheet.capture_dialog.push_input(event)
		await _settle()
	assert_false(f.sheet.capture_dialog.visible)
	assert_eq(f.sheet.get_review_draft().game_quick_load.controller, {"kind": "joypad_button", "button_index": JOY_BUTTON_PADDLE1, "device": -1})
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.ops.snapshot_persisted(), disk)
	await _confirm(f)
	f.sheet.import_dialog.get_ok_button().grab_focus()
	await _press(f.sheet.import_dialog, KEY_ENTER)
	assert_false(f.profile.get_profile_snapshot().controls_import_pending)
	assert_eq(f.profile.get_profile_snapshot().controls_bindings.game_quick_save.keyboard.physical_keycode, KEY_F6)
	assert_eq(f.profile.get_profile_snapshot().controls_bindings.game_quick_load.controller, {"kind": "joypad_button", "button_index": JOY_BUTTON_PADDLE1, "device": -1})
	assert_eq(f.profile.get_profile_snapshot().input_mappings, before.input_mappings)


func _assert_dialog_fit(dialog: ConfirmationDialog) -> void:
	var border: StyleBox = dialog.get_theme_stylebox("embedded_border", "Window")
	var top: float = border.expand_margin_top if border is StyleBoxFlat else 0.0
	assert_gte(dialog.position.x - 2, 0)
	assert_gte(dialog.position.y - top, 0.0)
	assert_lte(dialog.position.x + dialog.size.x + 2, 800)
	assert_lte(dialog.position.y + dialog.size.y + 2, 656)
	assert_eq(dialog.gui_get_focus_owner(), dialog.get_cancel_button())
	assert_true(Rect2(Vector2.ZERO, Vector2(dialog.size)).encloses(dialog.get_cancel_button().get_global_rect()))
