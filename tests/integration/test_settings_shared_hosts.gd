extends "res://addons/gut/test.gd"
## Actual Settings hosts and Profile/Localization/Input owners. Storage and audio
## playback are in-memory; no player file, external window or runtime route is used.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const PLAYBACK := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const PAUSE := preload("res://scenes/overlay/PauseSurface.tscn")
const TITLE := preload("res://scenes/menu/MenuScene.tscn")
const SETTINGS_THEME := preload("res://scripts/ui/SettingsTheme.gd")
const PAUSE_THEME := preload("res://scripts/ui/pause/PauseTheme.gd")

## Refuse real storage operations, not the Profile result. Persistent marker
## cleanup failure proves why live rollback cannot be advertised as durable.
class SettingsFaultFiles extends "res://tests/support/FakeFileOps.gd":
	var refuse_writes := false
	var refuse_marker_cleanup := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if refuse_writes and "/profile.json" in path:
			_record(&"write_bytes", path)
			return _injected_failure()
		return super.write_bytes(path, bytes)
	func remove_path(path: String) -> Dictionary:
		if refuse_marker_cleanup and path.ends_with("/profile.json.txn.json"):
			_record(&"remove_path", path)
			return _injected_failure()
		return super.remove_path(path)

var _surface: SubViewport
var _profile: Node
var _localization: Node
var _input: Node
var _audio: Node
var _playback: RefCounted
var _files: RefCounted
var _input_backup: Dictionary = {}

func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_files = SettingsFaultFiles.new()
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	_input = INPUT.new()
	_playback = PLAYBACK.new()
	_audio = AUDIO.new(_playback)
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


func test_actual_pause_host_recolours_for_captured_day_and_keeps_focus_through_accessibility_refresh() -> void:
	var fixture := _pause()
	var pause: Control = fixture.pause
	var content: Control = fixture.content
	assert_true(pause.configure_presentation("en", 100, "Midnight", false, "standard", false, 6))
	await _settle()
	var expected: Theme = SETTINGS_THEME.build("en", 100, &"midnight", false, "standard", 6)
	assert_eq(content.get_palette_id(), &"midnight")
	assert_eq(content.theme.get_color("paper", "Settings"), expected.get_color("paper", "Settings"))
	assert_eq(pause.theme.get_color("paper", "Pause"), expected.get_color("paper", "Settings"))
	await _enter_settings(fixture)
	content.select_category("accessibility")
	content.focus_rail()
	await _settle()
	var focused: Control = content.find_child("AccessibilityCategory", true, false)
	assert_true(focused.has_focus())
	assert_true(_profile.set_preference(&"preferences.dark_mode.next_run_enabled", true).get("ok", false))
	assert_true(_profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
	assert_true(_profile.set_preference(&"preferences.accessibility.colour_differentiation", "protan").get("ok", false))
	var revision: int = _profile.get_profile_revision()
	assert_true(pause.configure_presentation("en", 100, "Midnight", true, "protan", false, 7))
	await _settle()
	expected = SETTINGS_THEME.build("en", 100, &"midnight", true, "protan", 7)
	var expected_pause: Theme = PAUSE_THEME.build("en", 100, "Midnight", true, "protan", 7)
	assert_eq(content.get_palette_id(), &"midnight", "pending title Dark cannot replace captured run context")
	assert_eq(content.theme.get_color("paper", "Settings"), expected.get_color("paper", "Settings"))
	assert_eq(pause.theme.get_color("paper", "Pause"), expected_pause.get_color("paper", "Pause"))
	assert_true(focused.has_focus(), "appearance refresh preserves entered Settings focus")
	assert_eq(pause.entered_action, &"settings")
	assert_eq(_profile.get_profile_revision(), revision, "presentation has no profile publication")
	pause.close_surface()
	assert_true(pause.configure_presentation("en", 100, "Midnight", true, "protan", false, 4))
	pause.open_surface()
	await _settle()
	assert_eq(fixture.app, pause.get("_hosts")[&"settings"], "reopen uses the cached host")
	assert_eq(content.get("_run_day"), 4)
	assert_eq(pause.get("_day"), 4)
	assert_true(pause.rows[&"continue"].has_focus())

func test_desktop_canonical_commit_updates_fonts_without_resetting_controls() -> void:
	var binding := {"kind": "key", "physical_keycode": KEY_F6, "keycode": 0,
		"shift": false, "alt": false, "ctrl": false, "meta": false}
	var proposal: Dictionary = _profile.prepare_controls_change("game_quick_save", "keyboard", binding)
	assert_true(proposal.get("ok", false))
	assert_true(_profile.commit_controls_change(proposal.value).get("ok", false))
	var bindings: Dictionary = _profile.get_controls_binding_snapshot().value.bindings
	var app := _settings()
	var app_host := Control.new()
	app_host.position = Vector2(480, 0)
	app_host.size = Vector2(800, 656)
	_surface.add_child(app_host)
	app_host.add_child(app)
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
	assert_eq(app.get_global_rect(), Rect2(480, 0, 800, 656))
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
	var app_host := Control.new()
	app_host.size = Vector2(800, 656)
	_surface.add_child(app_host)
	app_host.add_child(app)
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


func test_settings_determinate_storage_failure_restores_control_and_allows_fresh_change() -> void:
	var fixture := _pause()
	await _enter_settings(fixture)
	var content: Control = fixture.content
	content.select_category("accessibility")
	await _settle()
	var toggle: CheckBox = content.control_for(&"preferences.accessibility.high_contrast")
	var before: Dictionary = _profile.get_profile_snapshot()
	var persisted: Dictionary = _files.snapshot_persisted()
	var revision: int = _profile.get_profile_revision()
	_files.refuse_writes = true
	await _click_settings_toggle(content, toggle)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_files.snapshot_persisted(), persisted, "the previous durable profile remains exact")
	assert_false(toggle.button_pressed, "the failed user toggle restores the canonical value")
	assert_false(content.is_profile_write_uncertain())
	assert_true(content.is_interaction_enabled())
	assert_true(fixture.app.can_return_home())
	var status: Label = content.find_child("SettingsStatus", true, false)
	assert_true(status.visible)
	assert_eq(status.text, _localization.t("settings.status.failed"))
	_files.refuse_writes = false
	await _click_settings_toggle(content, toggle)
	assert_true(_profile.get_preference(&"preferences.accessibility.high_contrast"))
	assert_eq(_profile.get_profile_revision(), revision + 1)
	assert_true(toggle.button_pressed)
	assert_false(status.visible, "a proven successful fresh action clears the error")
	var durable: Dictionary = _durable_profile()
	assert_true(durable.preferences.accessibility.high_contrast)
	assert_false(content.is_profile_write_uncertain())


func test_paused_settings_uncertain_storage_keeps_custody_and_blocks_repeated_input() -> void:
	var fixture := _pause()
	await _enter_settings(fixture)
	var content: Control = fixture.content
	content.select_category("accessibility")
	await _settle()
	var toggle: CheckBox = content.control_for(&"preferences.accessibility.high_contrast")
	var before: Dictionary = _profile.get_profile_snapshot()
	var revision: int = _profile.get_profile_revision()
	watch_signals(fixture.pause)
	watch_signals(fixture.app)
	_files.refuse_marker_cleanup = true
	await _click_settings_toggle(content, toggle)
	_assert_uncertain_profile(content, before, revision)
	var persisted: Dictionary = _files.snapshot_persisted()
	var operations: int = _files.operation_count()
	assert_false(fixture.app.can_return_home())
	assert_false(fixture.pause.quick_input_admitted("save"), "F5 admission respects Settings custody")
	assert_false(fixture.pause.quick_input_admitted("load"), "F9 admission respects Settings custody")
	fixture.pause.set_interactive(false)
	fixture.pause.set_interactive(true)
	assert_false(content.is_interaction_enabled(), "parent custody restoration cannot clear uncertainty")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_F5)
	await _tap(KEY_F9)
	await _click(toggle)
	fixture.pause.leave_host()
	await fixture.app.hide_window()
	var repeated: Dictionary = await content.get_controller().commit_preference(&"preferences.accessibility.high_contrast", true)
	assert_false(repeated.get("ok", false))
	var fenced: Dictionary = _profile.set_preference(&"preferences.accessibility.high_contrast", true)
	assert_false(fenced.get("ok", false), "the canonical owner independently refuses further mutation")
	assert_eq(fenced.get("code"), &"indeterminate_commit")
	assert_eq(fixture.pause.entered_action, &"settings")
	assert_true(fixture.app.is_visible_in_tree())
	assert_signal_emit_count(fixture.pause, "continue_requested", 0)
	assert_signal_emit_count(fixture.app, "window_hidden", 0)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_files.operation_count(), operations, "no retry, Back, or fresh input performs another file operation")
	assert_eq(_files.snapshot_persisted(), persisted, "uncertain artifacts remain available to canonical recovery")
	_assert_uncertainty_presentation(content)


func test_title_settings_uncertain_storage_refuses_home_and_cached_host_reactivation() -> void:
	var menu: Control = TITLE.instantiate()
	menu.configure_settings_services(_services())
	for child: Node in menu.get_children():
		if child.get_script() != null and child.get_script().resource_path in ["res://scripts/ui/LocalePresentationRoot.gd", "res://scripts/ui/LocalizedBinding.gd"]:
			child.set("_localization", _localization)
	_surface.add_child(menu)
	await _settle()
	await _click(menu.get_node("%SettingButton"))
	var app: Control = menu.get("_setting_instance")
	assert_not_null(app)
	if app == null: return
	var content: Control = app.settings_content
	content.select_category("accessibility")
	await _settle()
	var before: Dictionary = _profile.get_profile_snapshot()
	var revision: int = _profile.get_profile_revision()
	_files.refuse_marker_cleanup = true
	await _click_settings_toggle(content, content.control_for(&"preferences.accessibility.high_contrast"))
	_assert_uncertain_profile(content, before, revision)
	var operations: int = _files.operation_count()
	var persisted: Dictionary = _files.snapshot_persisted()
	menu._return_from_title_host()
	assert_false(menu._source_departure_admitted())
	await _click(menu.get("_title_home"))
	await _tap(KEY_ESCAPE)
	await app.hide_window()
	content.set_interaction_enabled(false)
	content.set_interaction_enabled(true)
	app.show_window()
	await _settle()
	assert_true(app.is_visible_in_tree())
	assert_false(content.is_interaction_enabled())
	assert_true(content.is_departure_blocked())
	assert_eq(menu.get("_setting_instance"), app)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.operation_count(), operations)
	assert_eq(_files.snapshot_persisted(), persisted)
	_assert_uncertainty_presentation(content)


func test_settings_audio_uncertainty_preserves_physical_compensation_before_deferred_custody_cleanup() -> void:
	var fixture := _pause()
	await _enter_settings(fixture)
	var content: Control = fixture.content
	content.select_category("audio")
	await _settle()
	var before: Dictionary = _profile.get_profile_snapshot()
	var revision: int = _profile.get_profile_revision()
	var output_before: Dictionary = _playback.capture_runtime().value
	var settings_before: Dictionary = _audio.get("_settings").duplicate(true)
	_files.refuse_marker_cleanup = true
	var result: Dictionary = await content.get_controller().commit_preference(&"preferences.audio.music_volume", 0.35)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"indeterminate_commit")
	assert_true(content.is_profile_write_uncertain(), "the write signal fences input before the controller returns")
	assert_false(content.is_interaction_enabled())
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_playback.capture_runtime().value, output_before, "the existing transaction compensates physical output")
	assert_eq(_audio.get("_settings"), settings_before)
	assert_false(_audio.get("_fatal"), "presentation must not interrupt compensation and spuriously poison output")
	assert_false(_audio.get("_settings_transactions").is_busy())
	var durable: Dictionary = _durable_profile()
	assert_almost_eq(durable.preferences.audio.music_volume, 0.35, 0.0001,
		"physical rollback cannot prove that the previous Profile bytes remain durable")
	var persisted: Dictionary = _files.snapshot_persisted()
	assert_true(persisted.has("settings-shared-hosts.memory/profile.json.txn.json"))
	var operations: int = _files.operation_count()
	await _settle()
	_assert_uncertainty_presentation(content)
	assert_eq(_playback.capture_runtime().value, output_before, "deferred presentation cleanup leaves the compensated output intact")
	assert_false(fixture.app.can_return_home())
	result = await content.get_controller().commit_preference(&"preferences.audio.music_volume", 0.6)
	assert_false(result.get("ok", false))
	await _settle()
	assert_eq(_files.operation_count(), operations)
	assert_eq(_files.snapshot_persisted(), persisted)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_playback.capture_runtime().value, output_before)


func _durable_profile() -> Dictionary:
	var persisted: Dictionary = _files.snapshot_persisted()
	var bytes: PackedByteArray = persisted["settings-shared-hosts.memory/profile.json"]
	return JSON.parse_string(bytes.get_string_from_utf8())


func _assert_uncertain_profile(content: Control, before: Dictionary, revision: int) -> void:
	assert_true(content.is_profile_write_uncertain())
	assert_false(content.is_interaction_enabled())
	assert_true(content.is_departure_blocked())
	assert_eq(_profile.get_profile_snapshot(), before, "the live prior value is retained, not published as a successful commit")
	assert_eq(_profile.get_profile_revision(), revision)
	var durable: Dictionary = _durable_profile()
	assert_true(durable.preferences.accessibility.high_contrast, "candidate bytes actually won despite the unsuccessful result")
	assert_true(_files.snapshot_persisted().has("settings-shared-hosts.memory/profile.json.txn.json"), "unresolved transaction evidence is preserved")
	_assert_uncertainty_presentation(content)


func _assert_uncertainty_presentation(content: Control) -> void:
	var recovery: Control = content.get_node_or_null("SettingsWriteRecovery")
	assert_not_null(recovery, "uncertainty is visible rather than only a retained internal fence")
	if recovery == null: return
	assert_true(recovery.is_visible_in_tree())
	assert_true(recovery.is_presented())
	assert_eq(recovery.message_label.text, _localization.t("settings.status.uncertain"))
	assert_false(recovery.retry_button.visible, "no unproven live retry is offered")
	assert_false(recovery.cancel_button.visible, "Back cannot claim a proven rollback")


func _click_settings_toggle(content: Control, toggle: CheckBox) -> void:
	# Accessibility overflows: real focus invokes the existing scroll owner before
	# native pointer coordinates are captured. A hidden row cannot receive a click.
	toggle.grab_focus()
	await _settle()
	assert_true(toggle.has_focus(), "the intended setting owns native focus")
	assert_true(content.sheet_scroll.get_global_rect().encloses(toggle.get_global_rect()),
		"the intended setting is inside the scrolling viewport before native input")
	assert_false(toggle.disabled)
	await _click(toggle)
