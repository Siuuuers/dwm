extends SceneTree

const SAFE_MENU := preload("res://tests/title_shell/SafeMenu.gd")

class FakeLocale extends Node:
	signal locale_changed(locale: String)
	var locale := "en"
	const TEXT := {
		"en": {"menu.new_account": "New Acc", "menu.login": "Log in", "menu.gallery": "Gallery", "menu.setting": "Setting", "menu.shutdown": "Shut down"},
		"zh-CN": {"menu.new_account": "新建账号", "menu.login": "登录", "menu.gallery": "画廊", "menu.setting": "设置", "menu.shutdown": "关闭游戏"},
		"zh-HK": {"menu.new_account": "建立帳號", "menu.login": "登入", "menu.gallery": "畫廊", "menu.setting": "設定", "menu.shutdown": "關閉遊戲"}}
	func get_locale() -> String:
		return locale
	func has_key(key: String) -> bool:
		return TEXT[locale].has(key)
	func t(key: String, _parameters: Dictionary = {}) -> String:
		return TEXT[locale].get(key, key)
	func change(value: String) -> void:
		locale = value
		locale_changed.emit(value)

class FakeProfile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var scale := 1.0
	func get_preference(path: StringName, default: Variant = null) -> Variant:
		return scale if path == &"preferences.accessibility.font_scale" else default
	func change(value: float) -> void:
		scale = value
		preference_changed.emit(&"preferences.accessibility.font_scale", value)

class SaveCounter extends Node:
	var calls := 0
	func start_new_run(_context: Dictionary) -> Dictionary:
		calls += 1
		return {"ok": false, "code": &"fixture_unavailable"}

class RouteCounter extends Node:
	var calls := 0
	func goto_scene_id(_route: String) -> void:
		calls += 1

var failures: Array[String] = []
var checks := 0
var clock_reads := 0
var clock_value: Dictionary = {"hour": 9, "minute": 7, "second": 13}

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in 5:
		await process_frame

func key(code: Key, shifted: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shifted
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shifted
	Input.parse_input_event(event)
	await settle()

func read_clock() -> Dictionary:
	clock_reads += 1
	return clock_value.duplicate(true)

func check_caption(button: Button) -> void:
	var caption: Label = button.get_node("Caption")
	check(not caption.text.is_empty() and caption.text == button.accessibility_name, "Confirmation exposes complete visible and accessible action copy")
	check(button.get_global_rect().encloses(caption.get_global_rect()), "Confirmation action text fits its fixed target")
	check(caption.max_lines_visible == -1, "Confirmation copy has no line truncation")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var locale := FakeLocale.new()
	locale.name = "LocalizationManager"
	root.add_child(locale)
	var profile := FakeProfile.new()
	profile.name = "ProfileManager"
	root.add_child(profile)
	var saves := SaveCounter.new()
	saves.name = "SaveManager"
	root.add_child(saves)
	var routes := RouteCounter.new()
	routes.name = "SceneRouter"
	root.add_child(routes)
	var menu: Control = load("res://scenes/menu/MenuScene.tscn").instantiate()
	menu.set_script(SAFE_MENU)
	root.add_child(menu)
	await settle()
	var ledger: Array[Button] = []
	for name in ["NewAccButton", "LogInButton", "GalleryButton", "SettingButton", "ShutDownButton"]:
		ledger.append(menu.get_node("%" + name))
	var clock: Label = menu._clock_label
	clock.configure_clock(read_clock)
	clock.set_foreground_eligible(true)
	clock.refresh_clock()
	await settle()
	check(clock.text == "09:07" and clock.focus_mode == Control.FOCUS_NONE, "Title clock is a nonfocusable HH:MM readout")
	check(is_equal_approx(clock._timer.wait_time, 47.0), "Clock schedules the next minute boundary from injected seconds")
	var reads_before := clock_reads
	clock_value = {"hour": 9, "minute": 8, "second": 0}
	clock._timer.timeout.emit()
	check(clock.text == "09:08" and clock_reads == reads_before + 1, "Minute timer refreshes only the routine time projection")
	clock._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	reads_before = clock_reads
	clock.refresh_clock()
	check(clock_reads == reads_before and clock._timer.is_stopped(), "Background title stops clock polling and its timer")
	clock._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(clock_reads == reads_before + 1 and clock.text == "09:08", "Foreground return refreshes the routine clock immediately")
	for invalid in [{}, {"hour": 24, "minute": 1, "second": 0}, {"hour": 9, "minute": 60, "second": 0}, {"hour": 9, "minute": 7, "second": {}}, {"hour": 9, "minute": 7, "second": 60}]:
		clock_value = invalid
		clock.refresh_clock()
		check(clock.text == "--:--", "Invalid clock data yields factual unavailability")
	clock_value = {"hour": 9, "minute": 7, "second": 13}
	clock.refresh_clock()
	var clock_rect: Rect2 = clock.get_global_rect()
	ledger[0].grab_focus()
	await key(KEY_UP)
	check(ledger[0].has_focus(), "Up at the first ledger row does not wrap")
	for index in range(1, ledger.size()):
		await key(KEY_DOWN)
		check(ledger[index].has_focus(), "Down moves to the next ledger row")
	await key(KEY_DOWN)
	check(ledger[-1].has_focus(), "Down at Shut down does not wrap")
	await key(KEY_RIGHT)
	check(ledger[-1].has_focus(), "Right cannot enter a hidden title host")
	await key(KEY_TAB)
	check(ledger[0].has_focus(), "Unhosted ledger Tab follows its declared cycle")
	check(saves.calls == 0 and routes.calls == 0 and menu._backup_app_instance == null and menu._setting_instance == null, "Focus navigation does not activate apps, save or route commands")
	for language in ["en", "zh-CN", "zh-HK"]:
		locale.change(language)
		for index in range(3):
			profile.change([1.0, 1.25, 1.5][index])
			await settle()
			check(clock.is_visible_in_tree() and clock.get_global_rect() == clock_rect, "Routine clock geometry remains fixed across locale and scale")
			check(menu.get_global_rect().encloses(clock.get_global_rect()), "Routine clock remains inside the title canvas")
			check(clock.get_theme_font_size("font_size") == [24, 30, 36][index], "Clock follows the font preset")
			var font: Font = clock.get_theme_font("font")
			var advance: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, [24, 30, 36][index]).x
			for digit in "123456789":
				check(is_equal_approx(font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, [24, 30, 36][index]).x, advance), "Routine clock uses tabular digit advances")
			for button in ledger:
				check(button.size.y >= 64 and not button.text.is_empty(), "Ledger targets retain full localized copy and accessible height")
				check(button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x <= button.size.x, "Ledger copy fits its target without truncation")
			ledger[-1].grab_focus()
			ledger[-1].pressed.emit()
			await settle()
			var sheet: Control = menu._confirmation
			check(is_instance_valid(sheet), "Shut down opens the shared confirmation sheet")
			if not is_instance_valid(sheet):
				continue
			check(sheet.cancel_button.has_focus(), "Shutdown confirmation begins on Cancel")
			check(not sheet.request.get("warning", true), "Trusted routine shutdown requests neutral presentation")
			var warning: Control = sheet.find_child("WarningGlyph", true, false)
			check(warning == null or not warning.visible, "Neutral shutdown reserves no visible Warning glyph")
			check_caption(sheet.cancel_button)
			check_caption(sheet.confirm_button)
			await key(KEY_ESCAPE)
			check(not is_instance_valid(menu._confirmation) and ledger[-1].has_focus(), "Escape closes only shutdown confirmation and restores Shut down focus")
			check(menu.quit_requests == 0 and saves.calls == 0 and routes.calls == 0, "Cancelling shutdown performs no quit, save or route mutation")
	ledger[-1].pressed.emit()
	await settle()
	menu._confirmation.confirm_button.pressed.emit()
	await settle()
	check(menu.quit_requests == 1, "Explicit shutdown confirmation reaches the intercepted production quit seam once")
	menu.queue_free()
	await settle()
	locale.queue_free()
	profile.queue_free()
	saves.queue_free()
	routes.queue_free()
	await settle()
	if failures.is_empty():
		print(JSON.stringify({"checks": checks, "suite": "TitleShell"}))
		print("TITLE_SHELL_PASS")
	quit(0 if failures.is_empty() else 1)
