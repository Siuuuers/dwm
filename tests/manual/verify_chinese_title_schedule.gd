extends "res://tests/integration/verify_playable_startup.gd"
## Real localized title and Schedule, with their real catalogs, owners, and UI bindings.
const SCHEDULE_COPY := preload("res://scripts/ui/schedule/ScheduleCopy.gd")
const TITLE_KEYS := {
	"NewAccButton": "menu.new_account", "LogInButton": "menu.login",
	"GalleryButton": "menu.gallery", "SettingButton": "menu.setting", "ShutDownButton": "menu.shutdown",
}
var _evidence := ""

func _initialize() -> void:
	var destination := ProjectSettings.globalize_path("user://").replace("\\", "/")
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/")
	if not _check(not isolated.is_empty() and destination.to_lower().begins_with(
			isolated.get_base_dir().path_join("appdata").to_lower() + "/"), "isolated native localization root"): return
	_evidence = ProjectSettings.globalize_path("res://.godot/phase2r_logs/chinese-title-schedule")
	if not _check(DirAccess.make_dir_recursive_absolute(_evidence) == OK, "localization evidence folder"): return
	_run.call_deferred()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), "native localization pixels"): return
	if not _check(pixels.save_png(_evidence.path_join(name + ".png")) == OK, "save localization pixels"): return
	print("CHINESE_UI_CAPTURE: " + name)

func _run() -> void:
	await _frames()
	if not _check(root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false), "real localization startup"): return
	var localization: Node = root.get_node("LocalizationManager")
	var router: Node = root.get_node("SceneRouter")
	router.goto_menu()
	await _frames()
	for locale: String in ["zh_CN", "zh_HK"]:
		if not _check(localization.set_locale(locale).get("ok", false), "change title locale " + locale): return
		router.goto_menu()
		await _frames()
		var menu: Node = current_scene
		for button_name: String in TITLE_KEYS:
			var text: String = menu.get_node("%" + button_name).text
			if not _check(text == localization.t(TITLE_KEYS[button_name]) and text.unicode_at(0) >= 0x3400,
					"real initial title translation " + locale + " " + button_name): return
		menu._title_welcome.set_busy("starting")
		await _frames()
		if not _check(menu._title_welcome.status.text.begins_with("正在"),
				"real translated startup status " + locale): return
		if not _check(menu._title_welcome.wordmark.text == "DWM"
				and menu._title_welcome.welcome.text == "Welcome! :)", "authored title preserved"): return
		await _capture(locale + "-title")
		menu._title_welcome.set_busy("")
	var menu: Node = current_scene
	menu.get_node("%NewAccButton").pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while is_instance_valid(menu) and menu._title_transition and Time.get_ticks_msec() < deadline:
		await process_frame
	if is_instance_valid(menu) and is_instance_valid(menu._confirmation):
		menu._confirmation.confirm_button.pressed.emit()
	var manager: Node = root.get_node("SaveManager")
	var desktop: Node
	while Time.get_ticks_msec() < deadline:
		desktop = current_scene.find_child("ComputerDesktop", true, false) if current_scene != null else null
		if desktop != null and not manager._new_run_busy: break
		await process_frame
	if not _check(desktop != null and root.get_node("GameState").capture_live_session().value.active,
			"real new account reaches desktop"): return
	if not _check(desktop.open_app(&"schedule").get("ok", false), "real Schedule opens"): return
	await _frames()
	var schedule: Node = desktop._cached_app_windows[&"schedule"]
	for locale: String in ["zh_CN", "zh_HK"]:
		if not _check(localization.set_locale(locale).get("ok", false), "change visible Schedule locale " + locale): return
		await _frames()
		var normalized := locale.replace("_", "-")
		if not _check(schedule._locale == normalized, "Schedule follows language change"): return
		for action: String in ["training", "working", "rest"]:
			var expected: String = SCHEDULE_COPY.LABELS[action][normalized]
			var button: Button = schedule.panel.source_buttons[action]
			if not _check(button.accessibility_name.begins_with(expected) and expected.unicode_at(0) >= 0x3400,
					"real localized Schedule source " + action): return
			var found := false
			for label: Label in button.find_children("*", "Label", true, false):
				found = found or label.text == expected
			if not _check(found, "visible translated Schedule label " + action): return
		if not _check(schedule.panel.done_button.accessibility_name == "完成", "localized Done control"): return
		await _capture(locale + "-schedule")
	print("CHINESE_TITLE_SCHEDULE_PASS")
	quit(0)
