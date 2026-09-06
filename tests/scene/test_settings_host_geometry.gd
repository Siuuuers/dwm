extends "res://addons/gut/test.gd"
## Bare title/desktop wrappers around real shared Settings and isolated owners.

const OWNERS := preload("res://tests/unit/test_settings_controls_reset.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const RESET := preload("res://tests/scene/test_settings_reset_confirmation.gd")
const SCENES := {"title": preload("res://scenes/menu/Setting.tscn"), "desktop": preload("res://scenes/apps/SettingsApp.tscn")}
var _surface: SubViewport
var _fixtures: Array[Dictionary] = []


func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)


func after_each() -> void:
	for fixture: Dictionary in _fixtures:
		for id: String in ["parent", "home", "localization", "profile"]:
			if is_instance_valid(fixture[id]):
				fixture[id].free()
	_fixtures.clear()


func _fixture(kind: String, locale: String = "en", percent: int = 100, audio: RefCounted = null, unavailable: String = "") -> Dictionary:
	var profile := OWNERS.PROFILE.new()
	add_child(profile)
	if unavailable != "profile":
		assert_true(profile.initialize(OWNERS.STORAGE.new("settings-wrapper.memory", OWNERS.FILES.new())).get("ok", false))
	var localization := LOCALIZATION.new()
	add_child(localization)
	if unavailable.is_empty():
		assert_true(localization.initialize(profile).get("ok", false))
		assert_true(localization.set_locale(locale).get("ok", false))
		assert_true(profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false))
		assert_true(profile.set_preference(&"preferences.accessibility.large_targets", true).get("ok", false))
	var parent := Control.new()
	parent.name = "SettingHost" if kind == "title" else "DesktopContent"
	parent.position = Vector2(320, 64) if kind == "title" else Vector2(480, 64)
	parent.size = Vector2(960, 656) if kind == "title" else Vector2(800, 656)
	_surface.add_child(parent)
	var home := Button.new()
	home.name = "ShellHome"
	home.text = "Home"
	home.position = Vector2(24, 24)
	home.size = Vector2(180, 64)
	_surface.add_child(home)
	var wrapper: Control = SCENES[kind].instantiate()
	var content: Control = wrapper.get_node("SettingsContent")
	content.configure_services({"profile": profile, "localization": localization, "audio": audio, "tts": null, "volume": null, "input": null, "profile_reset_admission": func() -> bool: return true})
	wrapper.get_node("LocalePresentationRoot").set("_localization", localization)
	parent.add_child(wrapper)
	if kind == "desktop":
		wrapper.configure_desktop_home(home)
	var hidden: Array = []
	wrapper.window_hidden.connect(func() -> void: hidden.append(true))
	var fixture := {"parent": parent, "wrapper": wrapper, "content": content, "profile": profile, "localization": localization, "home": home, "hidden": hidden}
	_fixtures.append(fixture)
	if unavailable.is_empty():
		wrapper.show_window()
	return fixture


func _settle() -> void:
	for frame: int in range(4):
		await get_tree().process_frame


func _key(keycode: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		_surface.push_input(event)
		await _settle()


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	_surface.push_input(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_surface.push_input(event)
		await _settle()


func test_both_bare_wrappers_fit_canonical_shell_rectangles_in_nine_presentations() -> void:
	for kind: String in SCENES:
		for locale: String in ["en", "zh_CN", "zh_HK"]:
			for percent: int in [100, 125, 150]:
				var fixture := _fixture(kind, locale, percent)
				var wrapper: Control = fixture.wrapper
				var content: Control = fixture.content
				await _settle()
				var context := "%s %s %d%%" % [kind, locale, percent]
				var expected := Rect2(400, 64, 800, 656) if kind == "title" else Rect2(480, 64, 800, 656)
				assert_eq(content.get_global_rect(), expected, context + ": exact shared plate")
				assert_eq(wrapper.get_global_rect(), expected, context + ": bare wrapper")
				assert_true(fixture.parent.get_global_rect().encloses(expected), context + ": inside the actual shell workfield")
				assert_eq(content.host_context, kind, context)
				assert_eq(content.theme.default_font_size, int(24 * percent / 100.0), context)
				assert_eq(content.scene_file_path, "res://scenes/shared/SettingsContent.tscn", context)
				assert_eq(wrapper.get_class(), "Control", context + ": no inherited window panel")
				for node_name: String in ["CloseButton", "HideButton", "TopBar", "ContentMargin"]:
					assert_null(wrapper.find_child(node_name, true, false), context + ": no " + node_name)
				assert_true(content.rail_scroll.is_ancestor_of(_surface.gui_get_focus_owner()), context + ": entry focus")
				if kind == "desktop":
					assert_true(wrapper.get_desktop_ready_result().get("ok", false), context)
					assert_eq(wrapper.get_content_host(), content, context)
				await wrapper.hide_window()
				assert_false(content.is_visible_in_tree(), context + ": shell departure hides the plate")
				fixture.parent.free()
				fixture.home.free()


func test_desktop_readiness_refuses_uninitialized_real_dependencies() -> void:
	for missing: String in ["profile", "localization"]:
		var fixture := _fixture("desktop", "en", 100, null, missing)
		await _settle()
		var result: Dictionary = fixture.wrapper.get_desktop_ready_result()
		assert_false(result.get("ok", true), missing + ": no optimistic readiness")
		assert_eq(result.get("code"), &"settings_dependencies_not_ready", missing)
		fixture.parent.free()


func test_desktop_home_and_back_preserve_native_modal_then_sheet_then_rail_custody() -> void:
	var fixture := _fixture("desktop")
	var wrapper: Control = fixture.wrapper
	var content: Control = fixture.content
	await _settle()
	assert_true(wrapper.can_return_home())
	var language: Control = content.find_child("LanguageCategory", true, false)
	assert_eq(language.get_node(language.focus_previous), fixture.home, "Rail has the configured shell Home neighbor")
	await _key(KEY_RIGHT)
	var option: OptionButton = content.control_for(&"preferences.language.primary_locale_id")
	assert_true(option.has_focus())
	await _key(KEY_SPACE)
	assert_true(option.get_popup().visible)
	assert_false(wrapper.can_return_home(), "Native dropdown owns dismissal")
	await _key(KEY_ESCAPE)
	assert_false(option.get_popup().visible)
	assert_true(wrapper.is_visible_in_tree(), "Dropdown Back cannot also close Settings")
	content.select_category("controls")
	var reset_button: Button = content.find_child("ControlsResetButton", true, false)
	reset_button.pressed.emit()
	await _settle()
	var dialog: ConfirmationDialog = content.confirmations.controls
	assert_true(dialog.visible)
	assert_false(wrapper.can_return_home(), "Confirmation owns dismissal")
	await _key(KEY_ESCAPE)
	assert_false(dialog.visible)
	assert_true(wrapper.is_visible_in_tree())
	assert_true(content.sheet_has_focus(), "Cancel returns to the scoped command")
	await _key(KEY_ESCAPE)
	assert_true(content.rail_scroll.is_ancestor_of(_surface.gui_get_focus_owner()))
	assert_true(wrapper.is_visible_in_tree(), "One Back only returns to the rail")
	await _key(KEY_ESCAPE)
	assert_false(wrapper.is_visible_in_tree())
	assert_eq(fixture.hidden.size(), 1, "Only the final Back exits the app")


func test_departure_blocks_input_and_reopen_until_held_sample_cleanup_finishes() -> void:
	for kind: String in SCENES:
		var audio := RESET.DelayedStopAudio.new()
		audio.available = true
		var fixture := _fixture(kind, "en", 100, audio)
		var wrapper: Control = fixture.wrapper
		var content: Control = fixture.content
		await _settle()
		content.select_category("audio")
		await content.get_controller().toggle_test("Music")
		assert_eq(audio.starts.size(), 1)
		if kind == "desktop":
			assert_false(wrapper.can_return_home(), "An active sample retains Home custody")
		var revision: int = fixture.profile.get_profile_revision()
		wrapper.hide_window()
		await _settle()
		assert_eq(audio.stops.size(), 1)
		assert_true(wrapper.is_visible_in_tree(), "Physical cleanup completes before the wrapper disappears")
		assert_false(content.is_interaction_enabled())
		assert_eq(fixture.hidden.size(), 0)
		var checkbox: CheckBox = content.control_for(&"preferences.audio.master_muted")
		assert_eq(checkbox.get_focus_mode_with_override(), Control.FOCUS_NONE)
		var queued_checkbox: CheckBox = content.control_for(&"preferences.accessibility.reduced_motion")
		queued_checkbox.toggled.emit(true)
		await _click(checkbox.get_global_rect().get_center())
		wrapper.hide_window()
		wrapper.show_window()
		await _key(KEY_ESCAPE)
		assert_false(content.is_interaction_enabled(), "Reopen cannot cancel pending cleanup")
		assert_eq(audio.stops.size(), 1, "One owner shutdown despite repeated commands")
		assert_eq(fixture.profile.get_profile_revision(), revision)
		if kind == "desktop":
			assert_false(wrapper.can_return_home())
		audio.stop_ready.emit()
		await _settle()
		assert_false(wrapper.is_visible_in_tree())
		assert_eq(fixture.hidden.size(), 1)
		queued_checkbox.toggled.emit(true)
		await _key(KEY_PAGEDOWN)
		assert_eq(fixture.profile.get_profile_revision(), revision, "Hidden queued input cannot commit")
		fixture.parent.show()
		wrapper.show_window()
		await _settle()
		assert_true(content.is_interaction_enabled())
		assert_true(content.rail_scroll.is_ancestor_of(_surface.gui_get_focus_owner()), "Reopen starts with valid Settings focus")
		fixture.parent.hide()
		assert_false(content.is_interaction_enabled(), "Raw shell visibility also removes interaction synchronously")
		queued_checkbox.toggled.emit(true)
		await _settle()
		assert_eq(fixture.profile.get_profile_revision(), revision)
		fixture.parent.show()
		await _settle()
		assert_true(content.is_interaction_enabled())
		assert_true(content.rail_scroll.is_ancestor_of(_surface.gui_get_focus_owner()), "Raw shell reopening restores current focus")
		await wrapper.hide_window()
		fixture.parent.free()
		fixture.home.free()


func test_busy_reset_cannot_be_detached_by_either_wrapper() -> void:
	for kind: String in SCENES:
		var audio := RESET.DelayedStopAudio.new()
		audio.available = true
		var fixture := _fixture(kind, "en", 100, audio)
		var wrapper: Control = fixture.wrapper
		var content: Control = fixture.content
		await _settle()
		await content.get_controller().toggle_test("Music")
		var revision: int = fixture.profile.get_profile_revision()
		content.get_controller().reset_profile("reset_preferences", revision)
		await _settle()
		assert_true(content.get_controller().is_commit_pending(), "A real reset is awaiting sample departure")
		if kind == "desktop":
			assert_false(wrapper.can_return_home())
		wrapper.hide_window()
		await _key(KEY_ESCAPE)
		assert_true(wrapper.is_visible_in_tree(), "Busy owner work must retain its wrapper")
		assert_eq(fixture.hidden.size(), 0)
		audio.stop_ready.emit()
		await _settle()
		assert_false(content.get_controller().is_commit_pending())
		assert_eq(fixture.profile.get_profile_revision(), revision, "Missing reset sink fails without a profile commit")
		assert_true(wrapper.is_visible_in_tree())
		await wrapper.hide_window()
		assert_eq(fixture.hidden.size(), 1, "Departure is admitted after owner work settles")
		fixture.parent.free()
		fixture.home.free()
