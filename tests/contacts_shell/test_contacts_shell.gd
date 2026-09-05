extends SceneTree
## Real scene integration. Only the external application ports are test doubles.

class FakePort extends RefCounted:
	var opens: Array[String] = []
	var reads := 0
	var reject_next := false
	var reply_count := 0
	var reply_pending := true
	var reject_reply := false
	var unread := {"priscilla": true, "lavinia": true, "sylvia": false}
	func get_projection(friend_id: String, _primary: String, _secondary: String = "") -> Dictionary:
		reads += 1
		var entries: Array = []
		if not friend_id.is_empty():
			for index in range(12):
				entries.append({"id": "%s-%d" % [friend_id, index], "outgoing": index % 2 == 1,
					"texts": {"en": "Neutral integration fixture. Complete text remains visible. ".repeat(5),
						"zh-CN": "中性测试文本。文字放大以后，每一行仍然应当完整显示。".repeat(5),
						"zh-HK": "中性測試文本。文字放大以後，每一行仍然應當完整顯示。".repeat(5)}})
		return {"ok": true, "code": &"ok", "value": {"friend_id": friend_id,
			"entries": entries, "unread": unread.duplicate(true), "reply_required": friend_id == "lavinia" and reply_pending}, "receipt": {}}
	func open_friend(friend_id: String, primary: String, secondary: String = "") -> Dictionary:
		opens.append(friend_id)
		if reject_next:
			reject_next = false
			return {"ok": false, "code": &"fixture_transaction_rejected", "details": {}}
		unread[friend_id] = false
		return get_projection(friend_id, primary, secondary)
	func reply_to_group(friend_id: String, primary: String, secondary: String = "") -> Dictionary:
		reply_count += 1
		if reject_reply:
			reject_reply = false
			return {"ok": false, "code": &"fixture_reply_rejected", "details": {}}
		reply_pending = false
		return get_projection(friend_id, primary, secondary)

class FakeLocale extends Node:
	signal locale_changed(locale_id: String)
	var locale := "en"
	func get_locale() -> String:
		return locale
	func change(value: String) -> void:
		locale = value
		locale_changed.emit(value)

class FakeProfile extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var font_scale := 1.0
	func get_preference(path: StringName, default: Variant = null) -> Variant:
		return font_scale if path == &"preferences.accessibility.font_scale" else default
	func change_scale(value: float) -> void:
		font_scale = value
		preference_changed.emit(&"preferences.accessibility.font_scale", value)

class FakeHost extends RefCounted:
	var reject_next := true
	var active: Variant = null
	var close_count := 0
	func get_state() -> Dictionary:
		return {"active_app_id": active}
	func open_app(app_id: StringName, _day: int) -> Dictionary:
		if reject_next:
			reject_next = false
			return {"ok": false, "code": &"fixture_host_rejected"}
		active = app_id
		return {"ok": true, "value": {}}
	func close_app() -> Dictionary:
		close_count += 1
		active = null
		return {"ok": true, "value": {}}

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func settle() -> void:
	for frame in range(6):
		await process_frame

func check_caption_font(button: Button, description: String) -> void:
	var caption := button.get_node_or_null("Caption") as Label
	var font: Font = caption.get_theme_font("font") if caption != null else button.get_theme_font("font")
	var text: String = caption.text if caption != null else button.text
	check(not text.is_empty(), description + " exposes visible nonempty text")
	for character in text:
		check(font.has_char(character.unicode_at(0)), description + " has glyph for " + character)

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func verify_main_scene() -> void:
	var main: Control = load("res://scenes/main/MainGameScene.tscn").instantiate()
	root.add_child(main)
	await settle()
	var desktop = main.find_child("ComputerDesktop", true, false)
	check(desktop != null, "Actual MainGameScene creates its production desktop")
	if desktop == null:
		main.queue_free()
		await settle()
		return
	var port := FakePort.new()
	var owner := FakeHost.new()
	owner.active = &"contacts"
	owner.reject_next = false
	var profile := FakeProfile.new()
	profile.font_scale = 1.5
	check(desktop.configure_contacts(port, null, profile, owner).get("ok", false), "Already-active owner configures the restored desktop")
	await settle()
	var host: Control = desktop.get_node("%AppWindowHost")
	check(host.get_child_count() == 1, "Restored active Contacts mounts automatically without launcher activation")
	if host.get_child_count() == 1:
		var app: Control = host.get_child(0)
		var panel = app.get_node("%ContactsPanel")
		check(app.is_visible_in_tree(), "Restored active Contacts is visible")
		check(panel.selected_friend == "" and panel.transcript == null and port.opens.is_empty(), "Restoring active app does not restore a thread or mark any contact read")
		check(main.size.is_equal_approx(Vector2(1280, 720)), "Actual main scene fills the 1280 by 720 viewport")
		check(app.size.is_equal_approx(Vector2(800, 656)), "Actual mounted app content remains 800 by 656 at 150%")
		check(panel.size.is_equal_approx(Vector2(800, 656)), "Actual mounted Contacts plate remains 800 by 656 at 150%")
		check(not app.get_node("VBoxContainer/TopBar").visible, "App-local toolbar stays hidden under shared shell")
		check(is_equal_approx(desktop.get_node("AppStrip").size.y, 64.0), "Desktop-owned toolbar remains 64 pixels high at 150%")
		check(is_equal_approx(app.global_position.y - desktop.global_position.y, 64.0), "App content starts below the desktop-owned toolbar")
		var bounds := app.get_global_rect()
		print("MAIN_GEOMETRY ", {"viewport": root.size, "main": main.get_global_rect(), "app": bounds, "panel": panel.size})
		check(main.get_global_rect().encloses(bounds), "Actual Contacts app fits completely inside MainGameScene")
		check(panel.font_size == 36, "MainGameScene mount honors 150% profile text setting")
	main.queue_free()
	await settle()

func _run() -> void:
	# Headless Windows starts with a 64x64 window despite project display hints.
	# Establish the real game's logical viewport before measuring scene layout.
	root.size = Vector2i(1280, 720)
	var desktop = load("res://scenes/desktop/ComputerDesktop.tscn").instantiate()
	root.add_child(desktop)
	await settle()
	for method in ["configure_contacts", "open_contacts"]:
		check(desktop.has_method(method), "Desktop exposes " + method + " (expected initial red before shell wiring)")
	if not failures.is_empty():
		desktop.queue_free()
		await settle()
		quit(1)
		return
	var port := FakePort.new()
	var locale := FakeLocale.new()
	root.add_child(locale)
	var profile := FakeProfile.new()
	var host_owner := FakeHost.new()
	check(desktop.configure_contacts(port, locale, profile, host_owner).get("ok", false), "Desktop accepts presentation dependencies")
	check(not desktop.open_contacts().get("ok", false), "Owner rejection propagates from desktop open")
	await settle()
	for child in desktop.get_node("%AppWindowHost").get_children():
		check(not child.is_visible_in_tree(), "Rejected host open does not expose a window outside owner state")
	check(desktop.open_contacts().get("ok", false), "Contacts opens through desktop")
	await settle()
	var host: Control = desktop.get_node("%AppWindowHost")
	check(host.get_child_count() == 1, "Exactly one Contacts window is mounted")
	if host.get_child_count() != 1:
		desktop.queue_free()
		locale.queue_free()
		await settle()
		quit(1)
		return
	var app = host.get_child(0)
	var panel = app.get_node("%ContactsPanel")
	var icon: Button = desktop.get_node("%ContactsButton")
	check(app.scene_file_path == "res://scenes/apps/ContactListApp.tscn", "Host mounts the real ContactListApp scene")
	check(panel.selected_friend == "" and panel.transcript == null, "Fresh Contacts is blank and unselected")
	check(port.opens.is_empty(), "Opening app does not open or mark a friend read")
	var reads_before: int = port.reads
	panel.rows[1].grab_focus()
	await settle()
	check(port.opens.is_empty() and port.reads == reads_before, "Focus alone performs no contact transaction or query")
	check(panel.rows[1].unread and not panel.rows[1].selected, "Focused unread row remains unselected")
	panel.rows[0].pressed.emit()
	await settle()
	check(port.opens == ["priscilla"], "Row activation delegates one open to application owner")
	check(panel.selected_friend == "priscilla" and panel.rows[0].selected, "Successful committed projection selects the opened friend")
	check(not panel.rows[0].unread and panel.rows[1].unread, "Only committed owner unread state is displayed")
	var old_transcript = panel.transcript
	port.reject_next = true
	panel.rows[1].pressed.emit()
	await settle()
	check(panel.selected_friend == "priscilla" and panel.transcript == old_transcript, "Failed open preserves prior selection and transcript")
	check(panel.rows[1].unread and not panel.rows[1].selected, "Failed open does not clear unread or fabricate selection")
	var status: Label = app.find_child("ContactStatus", true, false)
	check(status != null and status.is_visible_in_tree() and not status.text.is_empty(), "Failed action shows a visible technical status while preserving the conversation")
	check(desktop.home_button.is_visible_in_tree() and not desktop.home_button.disabled and not panel.rows[1].disabled, "Failed action leaves shared Home and retry controls available")
	check(panel.transcript.get_v_scroll_bar().max_value > panel.transcript.size.y, "Long owner content scrolls")
	panel.transcript.grab_focus()
	await press_key(KEY_END)
	await settle()
	check(panel.get_scroll_state().bottom and not panel.get_scroll_state().top, "End reaches transcript bottom through keyboard routing")
	await press_key(KEY_HOME)
	await settle()
	check(panel.get_scroll_state().top, "Home reaches transcript start")
	profile.change_scale(1.5)
	locale.change("zh-CN")
	await settle()
	check(icon.get_node("Caption").text == "联系人", "Simplified Chinese launcher uses real localized text")
	check_caption_font(icon, "Simplified Chinese launcher font")
	check(panel.font_size == 36, "Profile 150% uses 36 logical pixel font")
	check(panel.selected_friend == "priscilla", "Locale and text reflow preserve selection")
	var localized_count := 0
	for label in panel.find_children("*", "Label", true, false):
		if label.get_meta("locale", "") == "zh-CN":
			localized_count += 1
			check(label.text.begins_with("中性测试文本"), "Locale refresh uses supplied translation")
			check(label.size.x <= panel.transcript.size.x, "150% Chinese labels remain within transcript width")
			check(label.max_lines_visible == -1, "150% Chinese labels are not line capped")
	check(localized_count == 12, "All 12 owner entries remain rendered after locale reflow")
	check(port.opens.size() == 2, "Preference and locale updates do not repeat open transactions")
	locale.change("zh-HK")
	await settle()
	check(icon.get_node("Caption").text == "聯絡人", "Traditional Chinese launcher uses real localized text")
	check_caption_font(icon, "Traditional Chinese launcher font")
	var traditional_count := 0
	for label in panel.find_children("*", "Label", true, false):
		if label.get_meta("locale", "") == "zh-HK":
			traditional_count += 1
			check(label.text.begins_with("中性測試文本"), "Traditional Chinese refresh uses supplied regional translation")
	check(traditional_count == 12, "All entries remain present in Traditional Chinese")
	panel.transcript.grab_focus()
	await press_key(KEY_ESCAPE)
	await settle()
	check(app.visible and panel.rows[0].has_focus(), "Back from transcript returns to selected row without hiding app")
	await press_key(KEY_ESCAPE)
	await settle()
	check(not app.visible and is_instance_valid(app), "Back from row hides cached Contacts")
	check(host_owner.active == null and host_owner.close_count == 1, "Back delegates closing to existing host owner")
	check(icon.has_focus(), "Closing app restores focus to Contacts desktop button")
	check(desktop.open_contacts().get("ok", false), "Cached Contacts reopens")
	await settle()
	check(host.get_child_count() == 1 and host.get_child(0) == app, "Reopen reuses the same scene instance")
	check(panel.selected_friend == "priscilla", "Reopening preserves selected thread")
	panel.rows[1].pressed.emit()
	await settle()
	var reply: Button = app.find_child("ReplyButton", true, false)
	check(reply != null and reply.is_visible_in_tree(), "Owner's pending operational reply is reachable in actual app")
	if reply != null:
		check_caption_font(reply, "Traditional Chinese reply font")
		panel.transcript.scroll_vertical = int(panel.transcript.get_v_scroll_bar().max_value)
		await settle()
		panel.transcript.grab_focus()
		await press_key(KEY_DOWN)
		await settle()
		check(reply.has_focus(), "Down from transcript bottom reaches operational reply")
		profile.change_scale(1.25)
		await settle()
		reply = app.find_child("ReplyButton", true, false)
		check(reply != null, "Reply remains available after reflow at end of transcript")
		check(reply.has_focus(), "Font refresh preserves focus on replacement reply control")
		locale.change("zh-CN")
		await settle()
		reply = app.find_child("ReplyButton", true, false)
		check(reply.has_focus(), "Locale refresh preserves focus on replacement reply control")
		port.reject_reply = true
		reply.pressed.emit()
		await settle()
		check(port.reply_count == 1 and port.reply_pending, "Failed reply preserves owner pending state")
		check(is_instance_valid(reply) and reply.is_visible_in_tree(), "Failed reply preserves actionable control")
		reply.pressed.emit()
		await settle()
		check(port.reply_count == 2 and not port.reply_pending, "Reply delegates to owner once per activation")
		check(app.find_child("ReplyButton", true, false) == null, "Successful committed reply projection removes resolved action")
		check(panel.transcript.has_focus(), "Successful reply returns focus to transcript after removing action")
		check(not status.visible, "Successful retry clears technical failure status")
	desktop.home_button.pressed.emit()
	await settle()
	check(not app.visible and icon.has_focus(), "Shared shell hide action returns icon focus")
	desktop.open_contacts()
	await settle()
	var old_id: int = app.get_instance_id()
	desktop._on_daily_state_reset()
	await settle()
	check(host.get_child_count() == 0, "Day reset evicts cached view")
	check(desktop.open_contacts().get("ok", false), "Contacts can open after day reset")
	await settle()
	check(host.get_child_count() == 1 and host.get_child(0).get_instance_id() != old_id, "New day creates a fresh Contacts scene")
	check(host.get_child(0).get_node("%ContactsPanel").selected_friend == "", "New day begins unselected")
	desktop.queue_free()
	locale.queue_free()
	await settle()
	await verify_main_scene()
	if failures.is_empty():
		print("CONTACTS_SHELL_PASS")
	quit(0 if failures.is_empty() else 1)
