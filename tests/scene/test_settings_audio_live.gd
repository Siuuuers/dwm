extends "res://addons/gut/test.gd"
## Actual shared Settings app with the real Profile, Localization, Input, and Audio owners.
## Storage and physical audio are bounded in-memory adapters.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const PLAYBACK := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const ROOT := "settings-audio-live.memory"

var _surface: SubViewport
var _profile: Node
var _localization: Node
var _input: Node
var _audio: Node
var _playback: RefCounted
var _files: RefCounted
var _app: Control
var _content: Control
var _input_backup: Dictionary = {}


func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {
			"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true),
		}
	_files = FILES.new()
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	_input = INPUT.new()
	_playback = PLAYBACK.new()
	_audio = AUDIO.new(_playback)
	for owner: Node in [_profile, _localization, _input, _audio]:
		add_child(owner)
	assert_true(_profile.initialize(STORAGE.new(ROOT, _files)).get("ok", false))
	assert_true(_localization.initialize(_profile).get("ok", false))
	assert_true(_input.initialize(_profile).get("ok", false))
	assert_true(_audio.initialize(_profile).get("ok", false))
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child(_surface)
	_app = SETTINGS.instantiate()
	_app.get_node("SettingsContent").configure_services({
		"profile": _profile, "localization": _localization, "input": _input,
		"audio": _audio, "volume": _audio, "tts": null,
		"profile_reset_admission": func() -> bool: return true,
	})
	_app.get_node("LocalePresentationRoot").set("_localization", _localization)
	_surface.add_child(_app)
	_app.show_window()
	_content = _app.settings_content


func after_each() -> void:
	if is_instance_valid(_surface):
		_surface.free()
	for owner: Node in [_audio, _input, _localization, _profile]:
		if is_instance_valid(owner):
			owner.free()
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


func _settle() -> void:
	for _frame: int in range(4):
		await get_tree().process_frame


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	_surface.push_input(event, true)


func _tap(keycode: int) -> void:
	_key(keycode, true)
	await _settle()
	_key(keycode, false)
	await _settle()


func _mouse_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	_surface.push_input(event, true)
	await _settle()


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_surface.push_input(event, true)
	await _settle()


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	await _mouse_motion(point)
	await _mouse_button(point, true)
	await _mouse_button(point, false)


func _slider_point(slider: HSlider, ratio: float) -> Vector2:
	var rect: Rect2 = slider.get_global_rect()
	return Vector2(rect.position.x + rect.size.x * ratio, rect.get_center().y)


func _begin_native_drag(slider: HSlider, ratio: float) -> void:
	var start: Vector2 = _slider_point(slider, float(slider.value))
	await _mouse_motion(start)
	await _mouse_button(start, true)
	await _mouse_motion(_slider_point(slider, ratio))


func _release_native_drag(slider: HSlider) -> void:
	await _mouse_button(_slider_point(slider, float(slider.value)), false)


func _music_output_linear() -> float:
	return db_to_linear(float(_playback.bus_states[&"Music"].db))


func _select_option(option: OptionButton, value: Variant) -> void:
	for index: int in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			option.item_selected.emit(index)
			return
	assert_true(false, "Missing option metadata: " + str(value))


func test_registered_output_controls_are_live_but_unregistered_samples_are_unavailable() -> void:
	_content.select_category("audio")
	await _settle()
	assert_eq(_audio.get_settings_audio_capability(), {
		"ok": true, "value": {"volume": true, "samples": false},
	})
	for channel: String in ["master", "music", "ambience", "sfx"]:
		var slider: HSlider = _content.control_for(StringName("preferences.audio." + channel + "_volume"))
		assert_true(slider.editable, channel + " output is physically supported")
	for kind: String in ["Music", "Ambience", "SFX"]:
		assert_true(_content.test_buttons[kind].disabled, kind)
		assert_eq(_content.test_status(kind), _content.text("settings.status.unavailable"), kind)


func test_native_pointer_drag_previews_physical_output_without_a_profile_write_then_commits_once() -> void:
	_content.select_category("audio")
	await _settle()
	var slider: HSlider = _content.control_for(&"preferences.audio.music_volume")
	var revision: int = _profile.get_profile_revision()
	var operations: int = _files.operation_count()
	var persisted: Dictionary = _files.snapshot_persisted()
	var changes: Array[StringName] = []
	_profile.preference_changed.connect(func(path: StringName, _value: Variant) -> void: changes.append(path))
	await _begin_native_drag(slider, 0.42)
	var preview_value: float = float(slider.value)
	assert_lt(preview_value, 0.65, "the native pointer moved the slider")
	assert_almost_eq(_music_output_linear(), preview_value, 0.0001,
		"preview changes the physical Music bus")
	assert_almost_eq(_profile.get_preference(&"preferences.audio.music_volume"), 0.8, 0.0001)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_files.operation_count(), operations)
	assert_eq(_files.snapshot_persisted(), persisted)
	await _release_native_drag(slider)
	assert_almost_eq(_profile.get_preference(&"preferences.audio.music_volume"), preview_value, 0.0001)
	assert_eq(_profile.get_profile_revision(), revision + 1, "release performs one Profile commit")
	assert_eq(changes, [&"preferences.audio.music_volume"], "the commit publishes exactly once")
	assert_almost_eq(_music_output_linear(), preview_value, 0.0001)


func test_escape_and_departure_cancel_to_latest_output_and_ignore_stale_pointer_release() -> void:
	_content.select_category("audio")
	await _settle()
	var slider: HSlider = _content.control_for(&"preferences.audio.music_volume")
	assert_true((await _content.get_controller().commit_preference(
		&"preferences.audio.music_volume", 0.6)).get("ok", false))
	var revision: int = _profile.get_profile_revision()
	var operations: int = _files.operation_count()
	await _begin_native_drag(slider, 0.3)
	assert_lt(_music_output_linear(), 0.5)
	await _tap(KEY_ESCAPE)
	assert_almost_eq(_profile.get_preference(&"preferences.audio.music_volume"), 0.6, 0.0001)
	assert_almost_eq(_music_output_linear(), 0.6, 0.0001)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_files.operation_count(), operations)
	await _release_native_drag(slider)
	assert_eq(_profile.get_profile_revision(), revision,
		"the release from the cancelled native contact cannot commit")

	await _begin_native_drag(slider, 0.25)
	assert_lt(_music_output_linear(), 0.5)
	await _app.hide_window()
	assert_false(_app.is_visible_in_tree())
	assert_almost_eq(_music_output_linear(), 0.6, 0.0001,
		"departure settles the latest committed output")
	await _release_native_drag(slider)
	assert_eq(_profile.get_profile_revision(), revision,
		"a release after departure remains stale")
	assert_eq(_files.operation_count(), operations)


func test_native_keyboard_step_and_mute_output_mode_commit_through_the_audio_owner() -> void:
	_content.select_category("audio")
	await _settle()
	var music: HSlider = _content.control_for(&"preferences.audio.music_volume")
	music.grab_focus()
	await _tap(KEY_RIGHT)
	assert_almost_eq(_profile.get_preference(&"preferences.audio.music_volume"), 0.85, 0.0001)
	assert_almost_eq(_music_output_linear(), 0.85, 0.0001)
	var muted: CheckBox = _content.control_for(&"preferences.audio.music_muted")
	muted.grab_focus()
	await _settle()
	await _tap(KEY_SPACE)
	assert_true(_profile.get_preference(&"preferences.audio.music_muted"))
	assert_true(_playback.bus_states[&"Music"].muted)
	var output: OptionButton = _content.control_for(&"preferences.audio.output_mode")
	_select_option(output, "mono")
	await _settle()
	assert_eq(_profile.get_preference(&"preferences.audio.output_mode"), "mono")
	assert_eq(_playback.output_mode, "mono")


func test_confirmed_preferences_restore_settles_output_and_retains_language_and_controls() -> void:
	assert_true(_localization.set_locale("zh_CN").get("ok", false))
	var binding: Dictionary = {"kind": "key", "physical_keycode": KEY_F6, "keycode": 0,
		"shift": false, "alt": false, "ctrl": false, "meta": false}
	var proposed: Dictionary = _profile.prepare_controls_change("game_quick_save", "keyboard", binding)
	assert_true(proposed.get("ok", false))
	assert_true(_profile.commit_controls_change(proposed.value).get("ok", false))
	var controls: Dictionary = _profile.get_controls_binding_snapshot().value.bindings.duplicate(true)
	assert_true((await _content.get_controller().commit_preference(
		&"preferences.audio.master_volume", 0.35)).get("ok", false))
	assert_true((await _content.get_controller().commit_preference(
		&"preferences.audio.music_muted", true)).get("ok", false))
	assert_true((await _content.get_controller().commit_preference(
		&"preferences.audio.output_mode", "mono")).get("ok", false))
	_content.select_category("records")
	await _settle()
	var reset: Button = _content.find_child("PreferencesResetButton", true, false)
	reset.pressed.emit()
	await _settle()
	var dialog: ConfirmationDialog = _content.confirmations.preferences
	assert_true(dialog.visible)
	dialog.get_ok_button().grab_focus()
	await _tap(KEY_ENTER)
	assert_false(dialog.visible)
	assert_eq(_profile.get_preference(&"preferences.language.primary_locale_id"), "zh_CN")
	assert_eq(_localization.get_locale(), "zh_CN")
	assert_eq(_profile.get_controls_binding_snapshot().value.bindings, controls)
	assert_almost_eq(_profile.get_preference(&"preferences.audio.master_volume"), 1.0, 0.0001)
	assert_false(_profile.get_preference(&"preferences.audio.music_muted"))
	assert_eq(_profile.get_preference(&"preferences.audio.output_mode"), "stereo")
	assert_almost_eq(db_to_linear(float(_playback.bus_states[&"Master"].db)), 1.0, 0.0001)
	assert_false(_playback.bus_states[&"Music"].muted)
	assert_eq(_playback.output_mode, "stereo")
