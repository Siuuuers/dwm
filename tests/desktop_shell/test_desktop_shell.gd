extends SceneTree
## Uses production scenes. External owner doubles are shared with Contacts tests.
const Fixtures := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const SettingsFixtures := preload("res://tests/desktop_shell/test_settings_host.gd")
const APP_IDS := [&"minesweeper", &"contacts", &"schedule", &"shop", &"backup", &"settings", &"logout"]
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		printerr("FAIL: " + description)

func settle() -> void:
	for frame in range(6):
		await process_frame

func press_key(key: Key, shifted: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.shift_pressed = shifted
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = key
	event.shift_pressed = shifted
	Input.parse_input_event(event)
	await process_frame

func check_font(control: Control, caption: String, label: String) -> void:
	var font: Font = control.get_theme_font("font")
	for character in caption:
		check(font.has_char(character.unicode_at(0)), label + " has configured glyph: " + character)

func check_grid(desktop: Control) -> void:
	check(desktop.launcher_buttons.keys() == APP_IDS, "Seven launchers keep the exact registry order")
	check(desktop.launcher_buttons.size() == 7, "Eighth grid position has no selectable app")
	for index in range(APP_IDS.size()):
		var button: Button = desktop.launcher_buttons[APP_IDS[index]]
		var expected := Vector2(24 + (index % 4) * 192, 88 + (index / 4) * 192)
		check(button.size.is_equal_approx(Vector2(176, 176)), "Launcher cell is 176 square: " + str(APP_IDS[index]))
		check((button.global_position - desktop.global_position).is_equal_approx(expected), "Launcher uses inset24 and gutter16: " + str(APP_IDS[index]))
		check(button.focus_mode == Control.FOCUS_ALL, "Launcher remains keyboard reachable: " + str(APP_IDS[index]))
		check(not button.disabled, "Unavailable app remains inspectable by focus: " + str(APP_IDS[index]))
		check(not button.accessibility_name.is_empty(), "Launcher has accessible app identity")

func check_shell_geometry(main: Control, desktop: Control) -> void:
	check(main.size.is_equal_approx(Vector2(1280, 720)), "Actual main scene fills 1280 by720")
	check(desktop.size.is_equal_approx(Vector2(800, 720)), "Shared desktop remains800 by720")
	check(main.get_global_rect().encloses(desktop.get_global_rect()), "Desktop fits main scene")
	for control in [desktop.home_button, desktop.title_label, desktop.clock_label]:
		var relative: Vector2 = control.global_position - desktop.global_position
		check(relative.y >= 0 and relative.y + control.size.y <= 64.1, "Shared chrome remains inside 64px strip")
		check(relative.x >= 0 and relative.x + control.size.x <= 800.1, "Shared chrome fits available width")

func verify_cross_app_home() -> void:
	var gate := SettingsFixtures.GATE.new()
	var profile: Node = SettingsFixtures.PROFILE.new()
	profile.name = "ProfileManager"
	root.add_child(profile)
	check(profile.configure_mutation_gate(gate).get("ok", false), "Cross-app profile uses a real mutation gate")
	check(profile.initialize(SettingsFixtures.STORAGE.new("desktop-shell-fixture", SettingsFixtures.FILES.new())).get("ok", false), "Cross-app real profile uses memory-only storage")
	var locale: Node = SettingsFixtures.LOCALIZATION.new()
	locale.name = "LocalizationManager"
	root.add_child(locale)
	check(locale.configure_mutation_gate(gate).get("ok", false), "Cross-app locale uses the shared mutation gate")
	check(locale.initialize(profile).get("ok", false), "Cross-app localization initializes real catalog")
	var main: Control = load("res://scenes/main/MainGameScene.tscn").instantiate()
	root.add_child(main)
	await settle()
	var desktop = main.find_child("ComputerDesktop", true, false)
	var owner := Fixtures.FakeHost.new()
	owner.reject_next = false
	check(desktop.configure_contacts(Fixtures.FakePort.new(), locale, profile, owner).get("ok", false), "Cross-app desktop configures real Settings dependencies")
	check(desktop.open_contacts().get("ok", false), "Cross-app first Contacts opening succeeds")
	await settle()
	var contacts = desktop.app_window_host.get_child(0)
	desktop.return_home()
	await settle()
	var opened: Dictionary = desktop.open_app(&"settings")
	check(opened.get("ok", false), "Shared route opens real Settings with initialized production dependencies")
	await settle()
	if opened.get("ok", false):
		var settings = desktop.app_window_host.find_child("SettingsApp", false, false)
		check(settings != null and settings.is_visible_in_tree(), "Actual Settings scene is mounted")
		if settings != null:
			check(settings.size.is_equal_approx(Vector2(800, 656)), "Settings uses the same content bounds")
			desktop.home_button.grab_focus()
			await press_key(KEY_DOWN)
			check(settings.is_ancestor_of(root.gui_get_focus_owner()), "Home Down enters the currently active Settings controls")
			desktop.return_home()
			await settle()
			check(desktop.open_contacts().get("ok", false), "Contacts reopens after visiting Settings")
			await settle()
			check(contacts.is_visible_in_tree(), "The original Contacts instance is reused across app visits")
			desktop.home_button.grab_focus()
			await press_key(KEY_DOWN)
			check(contacts.is_ancestor_of(root.gui_get_focus_owner()), "Home Down is rebound to active cached Contacts after Settings")
	main.queue_free()
	await settle()
	locale.queue_free()
	profile.queue_free()
	await settle()

func verify_foundation(main: Control, desktop: Control) -> void:
	var port := Fixtures.FakePort.new()
	var locale := Fixtures.FakeLocale.new()
	root.add_child(locale)
	var profile := Fixtures.FakeProfile.new()
	var owner := Fixtures.FakeHost.new()
	owner.reject_next = false
	check(desktop.configure_contacts(port, locale, profile, owner).get("ok", false), "Existing Contacts dependency injection remains supported")
	check(desktop.has_method("configure_clock") and desktop.has_method("refresh_clock"), "Clock accepts explicit read-only source")
	if desktop.has_method("configure_clock"):
		var initial_reads := [0]
		desktop.configure_clock(func():
			initial_reads[0] += 1
			return {"hour": 9, "minute": 7, "second": 3})
		if not desktop.get_window().has_focus():
			check(initial_reads[0] == 0, "New desktop created without application focus never reads clock")
			for timer in desktop.find_children("*", "Timer", true, false):
				check(timer.is_stopped(), "New background desktop starts with no clock timer")
		desktop.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		desktop.configure_clock(func(): return {"hour": 9, "minute": 7, "second": 3})
		desktop.refresh_clock()
		check(desktop.clock_label.text == "09:07", "Clock displays supplied hour and minute with leading zeros")
		desktop.configure_clock(func(): return {})
		desktop.refresh_clock()
		check(desktop.clock_label.text == "--:--", "Unavailable clock does not retain a misleading stale time")
		desktop.configure_clock(func(): return {"hour": 9, "minute": 7, "second": {}})
		desktop.refresh_clock()
		check(desktop.clock_label.text == "--:--", "Malformed clock seconds fail without coercion")
		locale.change("zh-CN")
		check(desktop.clock_label.accessibility_description == "时间不可用", "Unavailable clock description follows locale")
		locale.change("en")
		desktop.configure_clock(func(): return {"hour": 9, "minute": 7, "second": 3})
		desktop.refresh_clock()
		check(desktop.clock_label.text == "09:07", "Clock recovers when valid source returns")
		check(desktop.clock_label.focus_mode == Control.FOCUS_NONE, "Audience clock never becomes an input target")
		check(port.opens.is_empty() and owner.active == null, "Clock refresh does not mutate gameplay state")
		var clock_reads := [0]
		desktop.configure_clock(func():
			clock_reads[0] += 1
			return {"hour": 9, "minute": 7, "second": 3})
		desktop.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var reads_at_blur: int = clock_reads[0]
		desktop.refresh_clock()
		check(clock_reads[0] == reads_at_blur, "Background clock does not call its reader")
		for timer in desktop.find_children("*", "Timer", true, false):
			check(timer.is_stopped(), "Background clock has no running timer")
		desktop.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		check(clock_reads[0] == reads_at_blur + 1, "Focus return refreshes clock once")
	await settle()
	check_grid(desktop)
	check_shell_geometry(main, desktop)
	check(desktop.home_button.disabled and desktop.home_button.current_on_launcher, "Launcher Home is both Current and disabled")
	var clock_geometry: Rect2 = desktop.clock_label.get_rect()
	var first: Button = desktop.launcher_buttons[&"minesweeper"]
	check(first.has_focus(), "Launcher initially focuses first Minesweeper entry")
	await press_key(KEY_TAB, true)
	check(first.has_focus(), "Shift Tab at first launcher never wraps to last")
	var reads_before: int = port.reads
	var last_top: Button = desktop.launcher_buttons[&"shop"]
	last_top.grab_focus()
	await press_key(KEY_UP)
	check(last_top.has_focus(), "First row Up does not leave the launcher grid")
	await press_key(KEY_RIGHT)
	check(last_top.has_focus(), "Right edge does not wrap to next launcher row")
	var first_bottom: Button = desktop.launcher_buttons[&"backup"]
	first_bottom.grab_focus()
	await press_key(KEY_LEFT)
	check(first_bottom.has_focus(), "Left edge does not wrap to preceding launcher row")
	var last_bottom: Button = desktop.launcher_buttons[&"logout"]
	last_bottom.grab_focus()
	await press_key(KEY_RIGHT)
	check(last_bottom.has_focus(), "Empty eighth cell does not receive keyboard focus")
	await press_key(KEY_DOWN)
	check(last_bottom.has_focus(), "Bottom edge does not wrap to first launcher row")
	await press_key(KEY_TAB)
	check(last_bottom.has_focus(), "Tab at last launcher never wraps to first")
	check(port.opens.is_empty() and port.reads == reads_before and owner.active == null, "Launcher focus navigation never opens or reads app content")
	for language in ["en", "zh-CN", "zh-HK"]:
		locale.change(language)
		for scale_value in [1.0, 1.25, 1.5]:
			profile.change_scale(scale_value)
			await settle()
			check_grid(desktop)
			check_shell_geometry(main, desktop)
			var current_clock: Rect2 = desktop.clock_label.get_rect()
			check(is_equal_approx(current_clock.position.x, clock_geometry.position.x) and is_equal_approx(current_clock.size.x, clock_geometry.size.x) and is_equal_approx(current_clock.get_center().y, clock_geometry.get_center().y), "Clock retains its reserved width and center as font height grows")
			for button in desktop.launcher_buttons.values():
				check(button.get_node_or_null("Caption") is Label, "Launcher supplies actual visible caption label")
				for label in button.find_children("*", "Label", true, false):
					check_font(label, label.text, "Launcher text " + language)
					check(label.get_theme_font_size("font_size") == int(24 * scale_value), "Launcher label honors chosen font scale")
					check(label.max_lines_visible == -1, "Launcher captions are not line capped")
					check(button.get_global_rect().encloses(label.get_global_rect()), "Launcher caption fits its cell: %s %s %.2f label=%s cell=%s" % [button.accessibility_name, language, scale_value, label.get_global_rect(), button.get_global_rect()])
			check_font(desktop.title_label, desktop.title_label.text, "Shared title " + language)
			check_font(desktop.clock_label, desktop.clock_label.text, "Clock " + language)
			var clock_font: Font = desktop.clock_label.get_theme_font("font")
			var font_size: int = desktop.clock_label.get_theme_font_size("font_size")
			var digit_width: float = clock_font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			for digit in range(1, 10):
				check(is_equal_approx(clock_font.get_string_size(str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, digit_width), "Clock digits use equal advances at each text size")
	check(not desktop.open_app(&"unknown_fixture_app").get("ok", false), "Unknown app fails without resolving a scene")
	check(owner.active == null and desktop.icon_grid.visible, "Rejected route preserves launcher and owner")
	owner.reject_next = true
	check(not desktop.open_contacts().get("ok", false), "Contacts propagates owner rejection")
	for child in desktop.app_window_host.get_children():
		check(not child.is_visible_in_tree(), "Rejected app stays hidden")
	check(desktop.open_app(&"contacts").get("ok", false), "Generic launcher route opens Contacts")
	await settle()
	var app: Control = desktop.app_window_host.get_child(0)
	var panel = app.get_node("%ContactsPanel")
	check(app.size.is_equal_approx(Vector2(800, 656)), "Contacts content uses800 by656 beneath shared strip")
	check(not desktop.home_button.disabled and not desktop.home_button.current_on_launcher, "Active Contacts Home is available without claiming Current")
	check((app.global_position - desktop.global_position).is_equal_approx(Vector2(0, 64)), "Contacts starts immediately below shared strip")
	check(panel.size.is_equal_approx(Vector2(800, 656)), "Contacts plate retains full content area")
	check(not app.get_node("VBoxContainer/TopBar").is_visible_in_tree(), "Contacts has no duplicate visible toolbar")
	check(panel.selected_friend == "" and port.opens.is_empty(), "App activation begins blank without opening any friend")
	panel.rows[0].grab_focus()
	await press_key(KEY_UP)
	check(desktop.home_button.has_focus(), "Up from first Contacts row reaches shared Home")
	await press_key(KEY_DOWN)
	check(panel.rows[0].has_focus(), "Down from Home returns to first Contacts row")
	await press_key(KEY_TAB, true)
	check(desktop.home_button.has_focus(), "Shift Tab from first Contacts row reaches Home")
	await press_key(KEY_TAB)
	check(panel.rows[0].has_focus(), "Tab from Home returns to first Contacts row")
	panel.rows[0].pressed.emit()
	await settle()
	check(panel.selected_friend == "priscilla", "Contacts commits ordinary application open")
	var transcript = panel.transcript
	port.reject_next = true
	panel.rows[1].pressed.emit()
	await settle()
	check(panel.transcript == transcript and panel.selected_friend == "priscilla", "Failed friend open preserves current content")
	check(not desktop.open_app(&"unknown_fixture_app").get("ok", false), "Unknown route rejects while Contacts active")
	check(app.visible and panel.selected_friend == "priscilla" and owner.active == &"contacts", "Failed route preserves active app and owner")
	check(not desktop.open_app(&"settings").get("ok", false), "Settings fails honestly when production dependencies are not injected")
	check(app.visible and panel.selected_friend == "priscilla" and owner.active == &"contacts", "Unavailable known route preserves active view")
	panel.transcript.grab_focus()
	await settle()
	desktop.home_button.grab_focus()
	desktop.home_button.pressed.emit()
	await settle()
	check(not app.visible and desktop.icon_grid.visible and owner.active == null, "Shared Home hides app and closes existing owner")
	check(desktop.launcher_buttons[&"contacts"].has_focus(), "Home returns focus to invoking launcher")
	check(desktop.open_contacts().get("ok", false), "Existing Contacts opening API still reopens cache")
	await settle()
	check(desktop.app_window_host.get_child(0) == app and panel.selected_friend == "priscilla", "Cache preserves Contacts instance and thread")
	check(panel.transcript.has_focus(), "Reopen restores transcript focus remembered before Home took focus")
	panel.rows[1].pressed.emit()
	await settle()
	var reply: Button = app.find_child("ReplyButton", true, false)
	check(reply != null, "Operational reply fixture remains available")
	if reply != null:
		reply.grab_focus()
		await settle()
		desktop.home_button.grab_focus()
		desktop.home_button.pressed.emit()
		await settle()
		desktop.open_contacts()
		await settle()
		reply = app.find_child("ReplyButton", true, false)
		check(reply != null and reply.has_focus(), "Reopen restores reply focus remembered before Home took focus")
	panel.rows[0].grab_focus()
	await press_key(KEY_ESCAPE)
	await settle()
	check(not app.visible and desktop.launcher_buttons[&"contacts"].has_focus(), "Back follows shared Home focus behavior")
	desktop.open_contacts()
	await settle()
	var old_id := app.get_instance_id()
	check(desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 2}).get("ok", false), "Day eviction uses existing host dispatch contract")
	await settle()
	check(desktop.app_window_host.get_child_count() == 0 and desktop.icon_grid.visible, "Day eviction drops cached content and shows launcher")
	check(first.has_focus(), "Day rebuild starts focus at first launcher")
	owner.active = null
	desktop.open_contacts()
	await settle()
	app = desktop.app_window_host.get_child(0)
	check(app.get_instance_id() != old_id and app.get_node("%ContactsPanel").selected_friend == "", "New day creates a fresh Contacts pane")
	main.queue_free()
	locale.queue_free()
	await settle()
	var restored: Control = load("res://scenes/main/MainGameScene.tscn").instantiate()
	root.add_child(restored)
	await settle()
	var restored_desktop = restored.find_child("ComputerDesktop", true, false)
	var restored_port := Fixtures.FakePort.new()
	owner.active = &"contacts"
	check(restored_desktop.configure_contacts(restored_port, null, profile, owner, 2).get("ok", false), "Restored active owner configures rebuilt shared desktop")
	await settle()
	check(restored_desktop.app_window_host.get_child_count() == 1, "Restore automatically mounts active Contacts")
	if restored_desktop.app_window_host.get_child_count() == 1:
		var pane = restored_desktop.app_window_host.get_child(0).get_node("%ContactsPanel")
		check(pane.selected_friend == "" and restored_port.opens.is_empty(), "Restore does not fabricate thread selection or read")
	restored.queue_free()
	await settle()
	var unavailable_main: Control = load("res://scenes/main/MainGameScene.tscn").instantiate()
	root.add_child(unavailable_main)
	await settle()
	var unavailable_desktop = unavailable_main.find_child("ComputerDesktop", true, false)
	owner.active = &"minesweeper"
	check(not unavailable_desktop.configure_contacts(Fixtures.FakePort.new(), null, profile, owner, 2).get("ok", false), "Unsupported restored app reports its unavailable projection")
	await settle()
	check(owner.active == &"minesweeper", "Unsupported restored view preserves the actual owner app ID")
	check(unavailable_desktop.title_label.text == "Minesweeper", "Unsupported restored view names the actual app instead of Home")
	check(not unavailable_desktop.icon_grid.visible and unavailable_desktop.home_button.disabled, "Unsupported restored view does not fabricate a Home launcher or available exit")
	check(not unavailable_desktop.home_button.current_on_launcher, "Disabled Home on failed restored app does not impersonate Current")
	check(unavailable_desktop.status_label.is_visible_in_tree() and not unavailable_desktop.status_label.text.is_empty(), "Unsupported restored view provides factual status")
	owner.active = null
	check(unavailable_desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 3}).get("ok", false), "Existing day eviction clears failed restored projection")
	await settle()
	check(unavailable_desktop.icon_grid.visible and not unavailable_desktop.status_label.visible and unavailable_desktop.title_label.text == "Home", "Eviction rebuilds an honest launcher after failed restored view")
	unavailable_main.queue_free()
	await settle()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main/MainGameScene.tscn").instantiate()
	root.add_child(main)
	await settle()
	var desktop = main.find_child("ComputerDesktop", true, false)
	for method in ["open_app", "return_home"]:
		check(desktop.has_method(method), "Shared desktop exposes " + method + " (expected initial red before foundation wiring)")
	var properties: Array[String] = []
	for property in desktop.get_property_list():
		properties.append(property.name)
	for property in ["launcher_buttons", "home_button", "title_label", "clock_label"]:
		check(property in properties, "Shared desktop exposes " + property + " (expected initial red before foundation wiring)")
	if failures.is_empty():
		await verify_foundation(main, desktop)
		await verify_cross_app_home()
	else:
		main.queue_free()
		await settle()
	if failures.is_empty():
		print("DESKTOP_SHELL_PASS")
	quit(0 if failures.is_empty() else 1)
