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
	root.size = Vector2i(1280,720)
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
	app.get_node("SettingsContent").configure_services({"profile": profile,
		"localization": localization, "audio": null, "tts": null, "volume": null,
		"input": null, "window": null})
	app.get_node("LocalePresentationRoot").set("_localization", localization)
	var app_host := Control.new()
	app_host.size = Vector2(800, 656)
	root.add_child(app_host)
	app_host.add_child(app)
	app.configure_desktop_home(home)
	_check(app.get_desktop_ready_result()["ok"], "real controller bind readiness")
	_check(app.get_node_or_null("VBoxContainer/TopBar") == null, "one shell strip only")
	app.show_window()
	await _frames()
	var content: Control = app.settings_content
	var language: Button = content.find_child("LanguageCategory",true,false)
	_check(language.has_focus(), "initial category rail focus")
	_check(language.get_node(language.focus_previous) == home, "Shift Tab from root reaches shell Home")
	_check(home.get_node(home.focus_next) == language and home.get_node(home.focus_neighbor_bottom) == language,
		"shell Home next/down enters current Settings category root")
	_check(app.size == Vector2(800,656), "bounded app content geometry")
	_check(content.get_category_ids() == ["language","reading","audio","display","controls","accessibility","records"],
		"canonical categories replace the obsolete flat preferences list")
	content.select_category("audio")
	var slider: HSlider = content.control_for(&"preferences.audio.music_volume")
	var before_volume: float = profile.get_preference(&"preferences.audio.music_volume")
	_check(not slider.editable, "volume is unavailable without a real preview/commit audio sink")
	slider.value = 0.25
	await _frames()
	_check(profile.get_preference(&"preferences.audio.music_volume") == before_volume,
		"an unavailable audio control cannot mutate committed settings")
	for kind in ["Music","Ambience","SFX"]:
		_check(content.test_buttons[kind].disabled, "missing real audio sample capability is explicit: "+kind)
	content.select_category("accessibility")
	var motion: CheckBox = content.control_for(&"preferences.accessibility.reduced_motion")
	motion.grab_focus()
	await _key(KEY_SPACE)
	_check(profile.get_preference(&"preferences.accessibility.reduced_motion") == true,
		"native released checkbox still reaches the real profile owner")
	var last_control: Control = content.control_for(&"preferences.accessibility.sound_detail_text")
	last_control.grab_focus()
	await _frames()
	_check(content.sheet_scroll.scroll_vertical > 0, "deep control focus scrolls into view")
	await app.hide_window()
	home.grab_focus()
	app.show_window()
	await _frames()
	_check(last_control.has_focus(), "cached reopen retains valid focus")
	await _key(KEY_ESCAPE)
	var accessibility: Button = content.find_child("AccessibilityCategory",true,false)
	_check(accessibility.has_focus() and app.visible, "one Back returns from sheet to its category")
	_check(app.can_return_home(), "Home allowed without modal")
	await _key(KEY_ESCAPE)
	_check(not app.visible, "second Back returns Home")
	app.show_window()
	await _frames()
	content.select_category("records")
	content._open_reset_confirmation("preferences")
	await _frames()
	var confirmation: ConfirmationDialog = content.confirmations["preferences"]
	_check(confirmation.visible and not app.can_return_home(), "actual reset confirmation blocks shell Home")
	_check(confirmation.get_cancel_button().has_focus(), "reset confirmation starts on Cancel")
	await _key(KEY_ESCAPE)
	_check(not confirmation.visible and app.visible, "native confirmation Back cancels only the modal")
	for percent in [100,125,150]:
		_check(profile.set_preference(&"preferences.accessibility.text_size",percent).get("ok",false), "owner applies text size")
		content.select_category("accessibility")
		await _frames()
		_check(app.size == Vector2(800,656), "text size preserves app bounds %d" % percent)
		_check(content.theme.default_font_size == roundi(24.0*percent/100.0), "full action-tier font %d" % percent)
		_check(content.sheet_scroll.get_h_scroll_bar().max_value <= content.sheet_scroll.size.x+1.0,
			"no horizontal overflow %d" % percent)
		var previous_bottom := -INF
		for row: Control in content._sheets["accessibility"].get_children():
			if not row.visible: continue
			_check(row.position.y >= previous_bottom, "canonical preference rows do not overlap %d" % percent)
			previous_bottom = row.position.y+row.size.y
		content.sheet_scroll.scroll_vertical = int(content.sheet_scroll.get_v_scroll_bar().max_value)
		await _frames()
		_check(last_control.get_global_rect().end.y <= content.sheet_scroll.get_global_rect().end.y+1.0,
			"last accessibility control remains reachable %d" % percent)
	app.free()
	app_host.free()
	home.free()
	localization.free()
	profile.free()
	if failures == 0:
		print("SETTINGS_DESKTOP_HOST_PASS")
	quit(0 if failures == 0 else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await _frames()

func _frames() -> void:
	for _frame in range(4):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
