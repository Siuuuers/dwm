extends "res://addons/gut/test.gd"
## Actual Settings hosts and Profile/Localization/Input owners. Storage and audio
## playback are in-memory; no player file, external window or runtime route is used.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const PLAYBACK := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const PAUSE := preload("res://scenes/overlay/PauseSurface.tscn")
const TITLE := preload("res://scenes/menu/MenuScene.tscn")

var _surface: SubViewport
var _profile: Node
var _localization: Node
var _input: Node
var _audio: Node
var _files: RefCounted
var _input_backup: Dictionary = {}

func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_files = FILES.new()
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	_input = INPUT.new()
	_audio = AUDIO.new(PLAYBACK.new())
	for owner: Node in [_profile, _localization, _input, _audio]: add_child(owner)
	assert_true(_profile.initialize(STORAGE.new("settings-shared-hosts.memory", _files)).get("ok", false))
	assert_true(_localization.initialize(_profile).get("ok", false))
	assert_true(_input.initialize(_profile).get("ok", false))
	assert_true(_audio.initialize(_profile).get("ok", false))
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.gui_embed_subwindows = true
	add_child(_surface)

func after_each() -> void:
	if is_instance_valid(_surface): _surface.free()
	for owner: Node in [_audio, _input, _localization, _profile]:
		if is_instance_valid(owner): owner.free()
	for action: StringName in InputMap.get_actions():
		if not _input_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _input_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_backup[action].events: InputMap.action_add_event(action, event)
	_input_backup.clear()

func _services() -> Dictionary:
	return {"profile": _profile, "localization": _localization, "input": _input,
		"audio": _audio, "volume": _audio, "tts": null,
		"profile_reset_admission": func() -> bool: return true}

func _settings() -> Control:
	var app: Control = SETTINGS.instantiate()
	app.get_node("SettingsContent").configure_services(_services())
	app.get_node("LocalePresentationRoot").set("_localization", _localization)
	return app

func _pause() -> Dictionary:
	var pause: Control = PAUSE.instantiate()
	var app := _settings()
	assert_true(pause.set_host(&"settings", app))
	_surface.add_child(pause)
	pause.open_surface()
	return {"pause": pause, "app": app, "content": app.settings_content}

func _settle() -> void:
	for frame: int in range(4): await get_tree().process_frame

func _key(keycode: int, pressed: bool, viewport: Viewport = null) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	var destination: Viewport = viewport if viewport != null else _surface
	destination.push_input(event, true)

func _tap(keycode: int, viewport: Viewport = null) -> void:
	_key(keycode, true, viewport)
	await _settle()
	_key(keycode, false, viewport)
	await _settle()

func _mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_surface.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_surface.push_input(event, true)

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	_mouse(point, true)
	await _settle()
	_mouse(point, false)
	await _settle()

func _enter_settings(fixture: Dictionary) -> void:
	fixture.pause.rows[&"settings"].grab_focus()
	await _settle()
	await _tap(KEY_RIGHT)
	assert_eq(fixture.pause.entered_action, &"settings")
	assert_true(fixture.content.find_child("LanguageCategory", true, false).has_focus())
	assert_true(fixture.app.is_processing_unhandled_input(), "entered host regains its script input")
	assert_true(fixture.content.is_processing_unhandled_input(), "entered shared content regains paging and Back input")

func test_pause_preview_is_inert_and_native_back_retreats_one_level_each() -> void:
	var fixture := _pause()
	var pause: Control = fixture.pause
	var content: Control = fixture.content
	watch_signals(pause)
	watch_signals(fixture.app)
	pause.rows[&"settings"].grab_focus()
	await _settle()
	assert_true(fixture.app.visible)
	assert_false(content.is_interaction_enabled())
	assert_true(pause.rows[&"settings"].has_focus())
	var before: Dictionary = _profile.get_profile_snapshot()
	var operations: int = _files.operation_count()
	await _click(content.control_for(&"preferences.language.primary_locale_id"))
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.operation_count(), operations)
	assert_eq(pause.entered_action, &"")
	await _enter_settings(fixture)
	assert_true(content.is_interaction_enabled())
	assert_eq(content.host_context, "pause")
	assert_eq(content.get_global_rect(), Rect2(480, 64, 800, 656))
	await _tap(KEY_RIGHT)
	assert_true(content.sheet_has_focus())
	await _tap(KEY_ESCAPE)
	assert_true(content.find_child("LanguageCategory", true, false).has_focus())
	assert_eq(pause.entered_action, &"settings")
	assert_signal_emit_count(pause, "continue_requested", 0)
	await _tap(KEY_ESCAPE)
	assert_eq(pause.entered_action, &"")
	assert_true(pause.rows[&"settings"].has_focus())
	assert_signal_emit_count(fixture.app, "window_hidden", 1)
	assert_signal_emit_count(pause, "continue_requested", 0)
	await _tap(KEY_ESCAPE)
	assert_signal_emit_count(pause, "continue_requested", 1)
	assert_signal_emit_count(pause, "enter_requested", 1)

func test_desktop_canonical_commit_updates_fonts_without_resetting_controls() -> void:
	var binding := {"kind": "key", "physical_keycode": KEY_F6, "keycode": 0,
		"shift": false, "alt": false, "ctrl": false, "meta": false}
	var proposal: Dictionary = _profile.prepare_controls_change("game_quick_save", "keyboard", binding)
	assert_true(proposal.get("ok", false))
	assert_true(_profile.commit_controls_change(proposal.value).get("ok", false))
	var bindings: Dictionary = _profile.get_controls_binding_snapshot().value.bindings
	var app := _settings()
	app.position = Vector2(480, 64)
	app.size = Vector2(800, 656)
	_surface.add_child(app)
	assert_true(app.get_desktop_ready_result().get("ok", false))
	app.show_window()
	await _settle()
	var content: Control = app.settings_content
	content.select_category("accessibility")
	var size_control: OptionButton = content.control_for(&"preferences.accessibility.text_size")
	var index := -1
	for item: int in range(size_control.item_count):
		if size_control.get_item_metadata(item) == 125: index = item
	assert_gte(index, 0)
	if index < 0: return
	size_control.select(index)
	size_control.item_selected.emit(index)
	await _settle()
	assert_eq(_profile.get_preference(&"preferences.accessibility.text_size"), 125)
	assert_eq(content.theme.default_font_size, 30)
	assert_eq(_profile.get_controls_binding_snapshot().value.bindings, bindings)
	assert_eq(_input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))
	assert_eq(app.get_global_rect(), Rect2(480, 64, 800, 656))
	assert_true(_localization.set_locale("zh_CN").get("ok", false))
	assert_eq(content.current_locale(), "zh_CN")
	assert_eq(content.theme.default_font_size, 30)

func test_pause_enter_restores_native_paging_on_overflowing_settings_sheet() -> void:
	var fixture := _pause()
	await _enter_settings(fixture)
	var content: Control = fixture.content
	content.select_category("accessibility")
	content.focus_rail()
	await _settle()
	var scroll: ScrollContainer = content.sheet_scroll
	var bar := scroll.get_v_scroll_bar()
	assert_gt(bar.max_value, bar.page, "fixture must genuinely overflow")
	scroll.scroll_vertical = 0
	await _tap(KEY_PAGEDOWN)
	assert_gt(scroll.scroll_vertical, 0, "native Page Down reaches the restored shared-content handler")
	assert_eq(fixture.pause.entered_action, &"settings")
	await _tap(KEY_PAGEUP)
	assert_eq(scroll.scroll_vertical, 0, "native Page Up returns to the sheet's start")
	assert_true(content.find_child("AccessibilityCategory", true, false).has_focus())

func test_pause_controls_capture_blocks_parent_leave_and_back_only_cancels_capture() -> void:
	var fixture := _pause()
	await _enter_settings(fixture)
	var content: Control = fixture.content
	content.select_category("controls")
	var sheet: Control = content.get("_controls_sheet")
	var source: Button = sheet.button_for("game_quick_save", "keyboard")
	source.grab_focus()
	await _settle()
	var before: Dictionary = _profile.get_profile_snapshot()
	await _tap(KEY_ENTER)
	assert_true(sheet.capture_dialog.visible)
	assert_true(content.is_departure_blocked())
	assert_false(fixture.app.can_return_home())
	fixture.pause.leave_host()
	assert_eq(fixture.pause.entered_action, &"settings")
	assert_true(sheet.capture_dialog.visible)
	await _tap(KEY_ESCAPE, sheet.capture_dialog)
	assert_false(sheet.capture_dialog.visible)
	assert_eq(fixture.pause.entered_action, &"settings")
	assert_true(source.has_focus())
	assert_eq(_profile.get_profile_snapshot(), before)

func test_paused_settings_mouse_release_after_custody_cycle_cannot_commit() -> void:
	var fixture := _pause()
	await _enter_settings(fixture)
	var content: Control = fixture.content
	content.select_category("accessibility")
	var toggle: CheckBox = content.control_for(&"preferences.accessibility.high_contrast")
	toggle.grab_focus()
	await _settle()
	var point := toggle.get_global_rect().get_center()
	var before: Dictionary = _profile.get_profile_snapshot()
	_mouse(point, true)
	fixture.pause.set_interactive(false)
	assert_false(content.is_interaction_enabled())
	fixture.pause.set_interactive(true)
	_mouse(point, false)
	await _settle()
	assert_eq(_profile.get_profile_snapshot(), before, "a pre-custody press cannot consent after restoration")
	await _click(toggle)
	assert_true(_profile.get_preference(&"preferences.accessibility.high_contrast"), "a fresh contact still works")

func test_actual_audio_output_capability_does_not_invent_sample_assets() -> void:
	assert_true(_audio.has_method("preview_settings_volume"))
	assert_false(_audio.has_method("start_settings_preview"))
	var app := _settings()
	app.size = Vector2(800, 656)
	_surface.add_child(app)
	app.show_window()
	await _settle()
	var content: Control = app.settings_content
	content.select_category("audio")
	var before: Dictionary = _profile.get_profile_snapshot()
	for channel: String in ["master", "music", "ambience", "sfx"]:
		var slider: HSlider = content.control_for(StringName("preferences.audio." + channel + "_volume"))
		assert_true(slider.editable, channel)
	for kind: String in ["Music", "Ambience", "SFX"]:
		assert_true(content.test_buttons[kind].disabled, kind)
		content.test_buttons[kind].pressed.emit()
	await _settle()
	assert_eq(_profile.get_profile_snapshot(), before)

func test_title_caches_settings_and_shared_return_preserves_capture_then_restores_row() -> void:
	var menu: Control = TITLE.instantiate()
	menu.configure_settings_services(_services())
	for child: Node in menu.get_children():
		if child.get_script() != null and child.get_script().resource_path in ["res://scripts/ui/LocalePresentationRoot.gd", "res://scripts/ui/LocalizedBinding.gd"]:
			child.set("_localization", _localization)
	_surface.add_child(menu)
	await _settle()
	var row: Button = menu.get_node("%SettingButton")
	await _click(row)
	var app: Control = menu.get("_setting_instance")
	assert_not_null(app)
	if app == null: return
	var identity := app.get_instance_id()
	var content: Control = app.settings_content
	assert_eq(content.host_context, "title")
	content.select_category("controls")
	var sheet: Control = content.get("_controls_sheet")
	var source: Button = sheet.button_for("game_quick_save", "keyboard")
	source.grab_focus()
	await _settle()
	await _tap(KEY_ENTER)
	assert_true(sheet.capture_dialog.visible)
	# The shared shell Return must independently refuse while its child owns a modal.
	menu._return_from_title_host()
	assert_true(sheet.capture_dialog.visible)
	assert_true(app.is_visible_in_tree())
	await _tap(KEY_ESCAPE, sheet.capture_dialog)
	assert_true(source.has_focus())
	await _click(menu.get("_title_home"))
	assert_false(app.is_visible_in_tree())
	assert_true(row.has_focus())
	await _click(row)
	assert_eq(menu.get("_setting_instance").get_instance_id(), identity)
	assert_true(app.is_visible_in_tree())
