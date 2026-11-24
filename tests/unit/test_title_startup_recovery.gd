extends GutTest

const MENU := preload("res://scenes/menu/MenuScene.tscn")
const SAFE_MENU := preload("res://tests/title_shell/SafeMenu.gd")

class Locale extends Node:
	signal locale_changed(locale: String)
	func get_locale() -> String: return "en"
	func has_key(_key: String) -> bool: return true
	func t(key: String, _parameters: Dictionary = {}) -> String: return key

class Profile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var text_size := 100
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return text_size if path == &"preferences.accessibility.text_size" else fallback

class StartupOwner extends Node:
	signal startup_failed()
	var fatal_result: Dictionary = {}
	func get_startup_state() -> Dictionary:
		return {"ready": false, "fatal_result": fatal_result}


class SaveCounter extends RefCounted:
	var prepares := 0
	var retries := 0
	func prepare_new_run_action() -> Dictionary:
		prepares += 1
		return {"ok": false, "code": "fixture_unavailable"}
	func retry_new_run(_token: String) -> Dictionary:
		retries += 1
		return {"ok": false}

var original_scene: Node
var source: Node
var viewport: SubViewport
var menu: Control
var startup: StartupOwner
var save_counter: SaveCounter

func before_each() -> void:
	original_scene = get_tree().current_scene
	source = Node.new()
	get_tree().root.add_child(source)
	get_tree().current_scene = source
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.handle_input_locally = true
	source.add_child(viewport)
	startup = StartupOwner.new()
	add_child(startup)
	save_counter = SaveCounter.new()

func after_each() -> void:
	get_tree().current_scene = original_scene if is_instance_valid(original_scene) else null
	if is_instance_valid(source): source.free()
	if is_instance_valid(startup): startup.free()
	await get_tree().process_frame

func _mount() -> void:
	var locale := Locale.new()
	var profile := Profile.new()
	viewport.add_child(locale)
	viewport.add_child(profile)
	menu = MENU.instantiate()
	menu.set_script(SAFE_MENU)
	menu.configure_settings_services({"profile": profile, "localization": locale})
	menu.configure_new_acc_owner(save_counter)
	menu.startup_owner = startup
	viewport.add_child(menu)
	await _settle()

func _settle() -> void:
	for frame in 3: await get_tree().process_frame

func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		viewport.push_input(event, true)
	await _settle()

func _assert_single_action(copy: String) -> void:
	assert_true(is_instance_valid(menu._confirmation), "Startup state has a visible owned sheet")
	if not is_instance_valid(menu._confirmation): return
	var sheet: Control = menu._confirmation
	assert_false(sheet.cancel_button.visible)
	assert_eq(sheet.cancel_button.focus_mode, Control.FOCUS_NONE)
	assert_eq(sheet.confirm_button.get_node("Caption").text, copy)
	assert_eq(sheet.confirm_button.risk, "neutral")
	assert_true(sheet.confirm_button.has_focus())
	assert_eq(save_counter.prepares, 0, "Recovery never starts a fresh account")
	assert_eq(save_counter.retries, 0, "A startup failure cannot dispatch a live retry")

func test_no_retained_operation_keeps_normal_title_and_initial_focus() -> void:
	await _mount()
	assert_false(is_instance_valid(menu._confirmation))
	assert_true(menu._new_acc_button.has_focus())

func test_title_refreshes_its_theme_for_text_size_and_preserves_focus() -> void:
	await _mount()
	var profile: Profile = menu._menu_profile()
	var original_theme: Theme = menu.theme
	profile.preference_changed.emit(&"preferences.audio.master_volume", 0.25)
	assert_same(menu.theme, original_theme)
	profile.text_size = 150
	profile.preference_changed.emit(&"preferences.accessibility.text_size", 150)
	assert_eq(menu._clock_label.get_theme_font_size("font_size"), 36)
	assert_true(menu._new_acc_button.has_focus())

func test_initial_generic_startup_failure_offers_only_shutdown_without_a_new_run_identity() -> void:
	startup.fatal_result = {"ok": false, "code": "fixture_configuration_failed", "stage": "configure_participants"}
	await _mount()
	_assert_single_action("Shut down")
	var sheet: Control = menu._confirmation
	await _key(KEY_ESCAPE)
	assert_eq(menu._confirmation, sheet, "Generic fatal startup cannot be dismissed into a fresh account")
	for button: Button in [menu._new_acc_button, menu._log_in_button, menu._gallery_button,
		menu._setting_button, menu._shut_down_button]:
		button.pressed.emit()
	assert_eq(menu._confirmation, sheet)
	assert_false(menu._backup_app_host.visible)
	assert_false(menu._setting_host.visible)
	assert_false(menu._gallery_host.visible)
	assert_eq(menu.quit_requests, 0)
	_assert_single_action("Shut down")
	await _key(KEY_ENTER)
	assert_eq(menu.quit_requests, 1)
	assert_eq(save_counter.prepares, 0)

func test_generic_failure_publication_replaces_normal_title_custody_with_shutdown_only() -> void:
	await _mount()
	assert_false(is_instance_valid(menu._confirmation))
	assert_true(menu._new_acc_button.has_focus())
	startup.fatal_result = {"ok": false, "code": "fixture_late_configuration_failed", "stage": "publish_startup_route"}
	startup.startup_failed.emit()
	await _settle()
	_assert_single_action("Shut down")
	var sheet: Control = menu._confirmation
	startup.startup_failed.emit()
	await _settle()
	assert_eq(menu._confirmation, sheet, "Repeated fatal publication does not recreate the sheet")
	await _key(KEY_ESCAPE)
	assert_eq(menu._confirmation, sheet)
	menu._new_acc_button.pressed.emit()
	assert_eq(save_counter.prepares, 0)
	_assert_single_action("Shut down")
