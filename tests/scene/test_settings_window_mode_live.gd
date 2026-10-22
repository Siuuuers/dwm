extends "res://addons/gut/test.gd"
## Real Settings presentation and owners; only persistence and physical output are modeled.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const WINDOW := preload("res://autoload/WindowModeManager.gd")
const PLAYBACK := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const WINDOW_PATH := &"preferences.display.window_mode"

class PhysicalWindow extends RefCounted:
	var available := true
	var fail_apply := false
	var operations: Array = []
	var state := {"mode": "windowed", "position": Vector2i(41, 73), "size": Vector2i(1110, 670)}
	func capture_output() -> Dictionary:
		if not available: return {"ok": false, "code": &"window_output_unavailable"}
		return {"ok": true, "value": state.duplicate(true)}
	func apply_mode(mode: String, _window_size: String = "1280x720") -> Dictionary:
		operations.append(["apply", mode])
		state = {"mode": mode, "position": Vector2i.ZERO,
			"size": Vector2i(1600, 900) if mode == "borderless" else preload("res://scripts/display/WindowModePort.gd").WINDOW_SIZES[_window_size]}
		if fail_apply:
			fail_apply = false
			return {"ok": false, "code": &"injected_window_apply"}
		return {"ok": true}
	func output_matches(mode: String, _window_size: String = "1280x720") -> bool:
		return available and state.mode == mode and (mode == "borderless" or state.size == preload("res://scripts/display/WindowModePort.gd").WINDOW_SIZES[_window_size])
	func get_available_window_sizes() -> Array[String]:
		return ["1280x720", "1600x900"]
	func restore_output(snapshot: Dictionary) -> Dictionary:
		operations.append(["restore", snapshot.duplicate(true)])
		state = snapshot.duplicate(true)
		return {"ok": true}

var _surface: SubViewport
var _profile: Node
var _localization: Node
var _input: Node
var _audio: Node
var _window: Node
var _playback: RefCounted
var _physical: RefCounted
var _files: RefCounted
var _app: Control
var _content: Control
var _input_backup: Dictionary = {}

func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true)}
	_files = FILES.new()
	_profile = PROFILE.new()
	_localization = LOCALIZATION.new()
	_input = INPUT.new()
	_playback = PLAYBACK.new()
	_audio = AUDIO.new(_playback)
	for owner: Node in [_profile, _localization, _input, _audio]: add_child(owner)
	assert_true(_profile.initialize(STORAGE.new("settings-window-live.memory", _files)).ok)
	assert_true(_localization.initialize(_profile).ok)
	assert_true(_input.initialize(_profile).ok)
	assert_true(_audio.initialize(_profile).ok)

func _mount(window_kind: String = "available") -> void:
	_window = null
	_physical = PhysicalWindow.new()
	if window_kind != "absent":
		_physical.available = window_kind == "available"
		_window = WINDOW.new(_physical)
		add_child(_window)
		assert_true(_window.initialize(_profile, _audio.get_settings_output_transactions()).ok)
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child(_surface)
	_app = SETTINGS.instantiate()
	_app.get_node("SettingsContent").configure_services({
		"profile": _profile, "localization": _localization, "input": _input,
		"audio": _audio, "volume": _audio, "window": _window, "tts": null,
		"profile_reset_admission": func() -> bool: return true,
	})
	_app.get_node("LocalePresentationRoot").set("_localization", _localization)
	_surface.add_child(_app)
	_app.show_window()
	_content = _app.settings_content

func after_each() -> void:
	if is_instance_valid(_surface): _surface.free()
	for owner: Node in [_window, _audio, _input, _localization, _profile]:
		if is_instance_valid(owner): owner.free()
	_window = null
	_surface = null
	for action: StringName in InputMap.get_actions():
		if not _input_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _input_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_backup[action].events: InputMap.action_add_event(action, event)
	_input_backup.clear()

func _settle() -> void:
	for _frame: int in range(4): await get_tree().process_frame

func _tap(keycode: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		_surface.push_input(event, true)
		await _settle()

func _select_option(option: OptionButton, value: String) -> void:
	for index: int in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			option.item_selected.emit(index)
			return
	assert_true(false, "Missing option metadata: " + value)

func _selected(option: OptionButton) -> Variant:
	return option.get_item_metadata(option.selected)

func test_actual_window_option_commits_one_profile_revision_and_proven_output() -> void:
	_mount()
	_content.select_category("display")
	await _settle()
	var option: OptionButton = _content.control_for(WINDOW_PATH)
	assert_false(option.disabled)
	assert_eq(_selected(option), "windowed")
	option.grab_focus()
	var revision: int = _profile.get_profile_revision()
	var operations: int = _physical.operations.size()
	var publications: Array = []
	_profile.preference_changed.connect(func(path, value):
		if path == WINDOW_PATH: publications.append([value, _physical.state.mode]))
	_select_option(option, "borderless")
	await _settle()
	assert_eq(_profile.get_profile_revision(), revision + 1)
	assert_eq(publications, [["borderless", "borderless"]])
	assert_eq(_physical.operations.size(), operations + 1)
	assert_eq(_profile.get_preference(WINDOW_PATH), "borderless")
	assert_eq(_window.get_applied_mode(), "borderless")
	assert_eq(_selected(option), "borderless")
	assert_eq(_content._general_status.text, "")

func test_failed_physical_selection_restores_option_geometry_focus_and_factual_error() -> void:
	_mount()
	_content.select_category("display")
	await _settle()
	var option: OptionButton = _content.control_for(WINDOW_PATH)
	option.grab_focus()
	await _settle()
	_physical.state.position = Vector2i(81, 113)
	_physical.state.size = Vector2i(1100, 680)
	var geometry: Dictionary = _physical.state.duplicate(true)
	var snapshot: Dictionary = _profile.get_profile_snapshot()
	var revision: int = _profile.get_profile_revision()
	_physical.fail_apply = true
	_select_option(option, "borderless")
	await _settle()
	assert_eq(_profile.get_profile_snapshot(), snapshot)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_eq(_physical.state, geometry)
	assert_eq(_selected(option), "windowed")
	assert_false(option.disabled)
	assert_eq(_surface.gui_get_focus_owner(), option)
	assert_eq(_content._general_status.text, _content.text("settings.status.failed"))
	assert_false(_content._general_status.text.is_empty())
	assert_false(_audio._fatal)
	assert_false(_window._fatal)

func _assert_unavailable(window_kind: String) -> void:
	_mount(window_kind)
	_content.select_category("display")
	await _settle()
	var option: OptionButton = _content.control_for(WINDOW_PATH)
	assert_true(option.disabled)
	assert_eq(_content.statuses[WINDOW_PATH].text, _content.text("settings.status.unavailable"))
	var snapshot: Dictionary = _profile.get_profile_snapshot()
	var revision: int = _profile.get_profile_revision()
	var result: Dictionary = await _content.get_controller().commit_preference(WINDOW_PATH, "borderless")
	assert_false(result.ok)
	_select_option(option, "borderless")
	await _settle()
	assert_eq(_selected(option), "windowed")
	assert_eq(_profile.get_profile_snapshot(), snapshot)
	assert_eq(_profile.get_profile_revision(), revision)
	assert_true(_physical.operations.is_empty())

func test_absent_window_service_disables_row_and_refuses_programmatic_commit() -> void:
	await _assert_unavailable("absent")

func test_unavailable_window_owner_disables_row_and_refuses_programmatic_commit() -> void:
	await _assert_unavailable("unavailable")

func test_actual_preferences_confirmation_resets_both_outputs_once_and_preserves_language_controls() -> void:
	_mount()
	assert_true(_localization.set_locale("zh_CN").ok)
	var binding := {"kind": "key", "physical_keycode": KEY_F6, "keycode": 0,
		"shift": false, "alt": false, "ctrl": false, "meta": false}
	var proposed: Dictionary = _profile.prepare_controls_change("game_quick_save", "keyboard", binding)
	assert_true(proposed.ok)
	assert_true(_profile.commit_controls_change(proposed.value).ok)
	var controls: Dictionary = _profile.get_controls_binding_snapshot().value.bindings.duplicate(true)
	for change: Array in [[WINDOW_PATH, "borderless"], [&"preferences.audio.master_volume", 0.35],
		[&"preferences.audio.music_muted", true], [&"preferences.audio.output_mode", "mono"]]:
		assert_true((await _content.get_controller().commit_preference(change[0], change[1])).ok)
	_content.select_category("records")
	await _settle()
	var revision: int = _profile.get_profile_revision()
	var resets: Array = []
	_profile.profile_reset.connect(func(section): resets.append([section, _physical.state.mode, _playback.output_mode]))
	var reset: Button = _content.find_child("PreferencesResetButton", true, false)
	reset.grab_focus()
	await _tap(KEY_SPACE)
	var dialog: ConfirmationDialog = _content.confirmations.preferences
	assert_true(dialog.visible)
	assert_eq(_profile.get_profile_revision(), revision, "opening confirmation cannot reset preferences")
	dialog.get_ok_button().grab_focus()
	await _tap(KEY_ENTER)
	assert_false(dialog.visible)
	assert_eq(_profile.get_profile_revision(), revision + 1)
	assert_eq(resets, [[&"preferences", "windowed", "stereo"]])
	assert_eq(_profile.get_preference(WINDOW_PATH), "windowed")
	assert_eq(_physical.state.mode, "windowed")
	assert_eq(_window.get_applied_mode(), "windowed")
	assert_eq(_profile.get_preference(&"preferences.language.primary_locale_id"), "zh_CN")
	assert_eq(_localization.get_locale(), "zh_CN")
	assert_eq(_profile.get_controls_binding_snapshot().value.bindings, controls)
	assert_almost_eq(db_to_linear(float(_playback.bus_states[&"Master"].db)), 1.0, 0.0001)
	assert_false(_playback.bus_states[&"Music"].muted)
	assert_eq(_playback.output_mode, "stereo")
	assert_eq(_surface.gui_get_focus_owner(), reset)

func test_window_size_picker_disables_oversized_choices_and_retains_size_in_borderless() -> void:
	_mount()
	_content.select_category("display")
	await _settle()
	var option: OptionButton = _content.control_for(&"preferences.display.window_size")
	assert_false(option.disabled)
	assert_eq(option.item_count, 3)
	assert_eq(option.get_item_text(1), "1600 × 900")
	assert_true(option.is_item_disabled(2), "1920×1080 must fit the current monitor before selection")
	await _select_option(option, "1600x900")
	assert_eq(_profile.get_preference(&"preferences.display.window_size"), "1600x900")
	assert_eq(_physical.state.size, Vector2i(1600, 900))
	await _select_option(_content.control_for(WINDOW_PATH), "borderless")
	assert_true(option.disabled)
	assert_eq(option.get_item_metadata(option.selected), "1600x900")
	assert_false(_content.statuses[&"preferences.display.window_size"].text.is_empty())
	await _select_option(_content.control_for(WINDOW_PATH), "windowed")
	assert_false(option.disabled)
	assert_eq(_physical.state.size, Vector2i(1600, 900))
