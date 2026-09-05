extends SceneTree

const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var missing: Control = SETTINGS.instantiate()
	root.add_child(missing)
	_check(not missing.get_desktop_ready_result().get("ok", false), "missing owners reported")
	missing.free()
	var gate := GATE.new()
	var profile: Node = PROFILE.new()
	profile.name = "ProfileManager"
	root.add_child(profile)
	var localization: Node = LOCALIZATION.new()
	localization.name = "LocalizationManager"
	root.add_child(localization)
	var unready: Control = SETTINGS.instantiate()
	root.add_child(unready)
	_check(unready.get_desktop_ready_result().get("code") == &"settings_dependencies_not_ready",
		"present but uninitialized owner rejected")
	unready.free()
	_check(profile.configure_mutation_gate(gate)["ok"], "profile gate")
	_check(profile.initialize(STORAGE.new("settings-host-test", FILES.new()))["ok"], "real profile with fake disk")
	_check(localization.configure_mutation_gate(gate)["ok"], "locale gate")
	_check(localization.initialize(profile)["ok"], "real locale owner")
	var home := Button.new()
	home.text = "Home test"
	root.add_child(home)
	var app: Control = SETTINGS.instantiate()
	app.size = Vector2(800, 656)
	root.add_child(app)
	app.configure_desktop_home(home)
	_check(app.get_desktop_ready_result()["ok"], "real controller bind readiness")
	_check(not app.get_node("VBoxContainer/TopBar").visible, "one shell strip only")
	app.show_window()
	await _frames()
	var language: OptionButton = app.language_option
	_check(language.has_focus(), "initial root focus")
	_check(language.get_node(language.focus_neighbor_top) == home, "up from root reaches shell Home")
	_check(home.get_node(home.focus_next) == language and home.get_node(home.focus_neighbor_bottom) == language,
		"shell Home next/down enters current Settings root")
	_check(app.size == Vector2(800, 656), "bounded app content geometry")
	var controller: RefCounted = app.get("_controller")
	var controls: Dictionary = controller.get("_controls")
	var slider: HSlider = controls[&"preferences.audio.music_volume"]
	slider.value = 0.25
	_check(profile.get_preference(&"preferences.audio.music_volume") == 0.25, "existing owner command preserved")
	slider.grab_focus()
	await _frames()
	_check(app.settings_scroll.scroll_vertical > 0, "deep control focus scrolls into view")
	app.hide()
	home.grab_focus()
	app.show_window()
	_check(slider.has_focus(), "cached reopen retains valid focus")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	app._unhandled_input(cancel)
	_check(language.has_focus() and app.visible, "local Back returns root without Home mutation")
	_check(app.can_return_home(), "Home allowed without modal")
	app._unhandled_input(cancel)
	_check(not app.visible, "second Back returns Home")
	app.show_window()
	var confirmation: ConfirmationDialog = app.get_node("PreferencesResetConfirmation")
	confirmation.popup_centered()
	await _frames()
	app._unhandled_input(cancel)
	_check(confirmation.visible and app.visible, "Settings does not consume confirmation Back")
	_check(not app.can_return_home(), "open confirmation blocks shell Home")
	confirmation.hide()
	for font_size in [24, 30, 36]:
		var resized_theme: Theme = app.theme.duplicate() if app.theme != null else Theme.new()
		resized_theme.default_font_size = font_size
		app.theme = resized_theme
		await _frames()
		_check(app.size == Vector2(800, 656), "text size preserves app bounds %d" % font_size)
		_check(app.settings_scroll.get_h_scroll_bar().max_value <= app.settings_scroll.size.x + 1.0,
			"no horizontal overflow %d" % font_size)
		_check(app.accessibility_container.get_global_rect().end.y <= app.audio_container.global_position.y,
			"preference sections do not overlap %d" % font_size)
		app.settings_scroll.scroll_vertical = int(app.settings_scroll.get_v_scroll_bar().max_value)
		await _frames()
		_check(app.audio_container.get_global_rect().end.y <= app.settings_scroll.get_global_rect().end.y + 1.0,
			"last settings section reachable %d" % font_size)
	app.free()
	home.free()
	localization.free()
	profile.free()
	if failures == 0:
		print("SETTINGS_DESKTOP_HOST_PASS")
	quit(0 if failures == 0 else 1)

func _frames() -> void:
	for _frame in range(4):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
