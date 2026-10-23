extends SceneTree
## Isolated component contract; run with --headless --script this file.

const PANEL_PATH := "res://scripts/ui/contacts/ContactsPanel.gd"
const FONT_DIR := "res://assets/ui/contacts/fonts/"
var failures: Array[String] = []
var requests: Array[String] = []
var panel
var fonts: Array[Font] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func settle() -> void:
	for frame in range(5):
		await process_frame

func entries_for_test() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in range(14):
		entries.append({
			"id": "sample-%02d" % index,
			"outgoing": index % 2 == 1,
			"texts": {
				"en": "Neutral reading sample %d. " % index + "The next line should remain readable at every text size. ".repeat(4),
				"zh-CN": "中性阅读示例。文字放大以后，每一行仍然应当完整显示。".repeat(4),
				"zh-HK": "中性閱讀示例。文字放大以後，每一行仍然應當完整顯示。".repeat(4)
			},
			"timestamp": "12:00"
		})
	return entries

func label_texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(label_texts(child))
	return result

func check_label_widths(node: Node, width: float) -> void:
	if node is Label:
		check(node.size.x <= width + 1.0, "Label fits transcript width: " + node.text.left(24))
	for child in node.get_children():
		check_label_widths(child, width)

func _run() -> void:
	if not FileAccess.file_exists(PANEL_PATH):
		printerr("FAIL: ContactsPanel component does not exist yet (expected initial red).")
		quit(1)
		return
	var script = load(PANEL_PATH)
	if script == null or not script.can_instantiate():
		printerr("FAIL: ContactsPanel cannot be loaded.")
		quit(1)
		return
	for file in ["source-sans-3-regular.ttf.woff2", "source-han-sans-sc-regular.otf", "source-han-sans-hc-regular.otf"]:
		var font = load(FONT_DIR + file)
		if not font is Font:
			printerr("FAIL: Required font could not be loaded: " + file)
			quit(1)
			return
		fonts.append(font)
	root.size = Vector2i(1280, 720)
	panel = script.new()
	panel.position = Vector2(480, 64)
	panel.size = Vector2(800, 656)
	root.add_child(panel)
	check(panel.configure(fonts[0], fonts[1], fonts[2], 100, false), "Valid font configuration accepted")
	panel.open_requested.connect(func(friend_id: String): requests.append(friend_id))
	await settle()
	check(panel.rows.size() == 3, "Exactly three stable contact rows")
	check(panel.selected_friend == "", "Fresh entry has no selected friend")
	check(panel.transcript == null and panel.messages == null, "Fresh entry has no transcript")
	check(root.gui_get_focus_owner() == panel.rows[0], "Fresh entry focuses first contact")
	panel.rows[1].pressed.emit()
	await settle()
	check(requests == ["lavinia"], "Row emits the correct open request")
	check(panel.selected_friend == "" and panel.transcript == null, "Open request does not commit a projection")
	var entries := entries_for_test()
	var unread := {"priscilla": true, "lavinia": false, "sylvia": true}
	check(panel.set_projection("priscilla", entries, unread, "en", "zh-CN"), "Valid bilingual projection accepted")
	await settle()
	check(panel.selected_friend == "priscilla", "Projection commits selected friend")
	check(panel.transcript != null and panel.messages != null, "Projection builds transcript")
	check(root.gui_get_focus_owner() == panel.transcript, "Committed projection focuses transcript")
	var transcript_before = panel.transcript
	var text_before := label_texts(panel.messages)
	var focus_before := root.gui_get_focus_owner()
	var font_before: int = panel.font_size
	check(not panel.configure(fonts[0], fonts[1], fonts[2], 110, false), "Unsupported text percentage rejected")
	check(panel.font_size == font_before, "Invalid configuration leaves font size unchanged")
	for invalid in [
		["unknown", entries, "en", ""],
		["", entries, "en", ""],
		["priscilla", entries, "fr", ""],
		["priscilla", entries, "en", "en"],
		["priscilla", entries, "en", "fr"]
	]:
		check(not panel.set_projection(invalid[0], invalid[1], unread, invalid[2], invalid[3]), "Invalid projection rejected")
	var missing: Array[Dictionary] = [{"id": "missing", "outgoing": false, "texts": {"en": "Sample"}}]
	check(not panel.set_projection("sylvia", missing, unread, "en", "zh-HK"), "Missing requested translation rejected")
	var duplicate := entries.duplicate(true)
	duplicate[1]["id"] = duplicate[0]["id"]
	check(not panel.set_projection("sylvia", duplicate, unread, "en", "zh-CN"), "Duplicate entry IDs rejected")
	for timestamp in ["24:00", "12:60", "9:00", "yesterday"]:
		var malformed := entries.duplicate(true)
		malformed[0]["timestamp"] = timestamp
		check(not panel.set_projection("sylvia", malformed, unread, "en", "zh-CN"), "Malformed timestamp rejected: " + timestamp)
	check(panel.selected_friend == "priscilla" and panel.transcript == transcript_before, "Rejection leaves selected friend and transcript unchanged")
	check(label_texts(panel.messages) == text_before, "Rejection leaves rendered content unchanged")
	check(root.gui_get_focus_owner() == focus_before, "Rejection leaves focus unchanged")
	entries[0]["texts"]["en"] = "CALLER MUTATION MUST NOT APPEAR"
	unread["priscilla"] = false
	check(panel.configure(fonts[0], fonts[1], fonts[2], 125, true), "Valid relayout accepted")
	await settle()
	check(not "CALLER MUTATION MUST NOT APPEAR" in " ".join(label_texts(panel.messages)), "Component owns a deep copy of caller text")
	check(panel.rows[0].get("unread") == true, "Selected contact retains caller-supplied unread state across relayout")
	check(root.gui_get_focus_owner() == panel.transcript, "Relayout preserves transcript focus")
	var anchor = panel.messages.get_child(5)
	check(anchor.get_meta("entry_id", "") == "sample-05", "Message exposes its stable entry ID")
	panel.transcript.scroll_vertical += int(anchor.get_global_rect().position.y - panel.transcript.get_global_rect().position.y) + 8
	await settle()
	var offset_before: float = anchor.get_global_rect().position.y - panel.transcript.get_global_rect().position.y
	check(panel.configure(fonts[0], fonts[1], fonts[2], 150, false), "Mid-transcript relayout accepted")
	await settle()
	var restored_anchor = panel.messages.get_child(5)
	check(restored_anchor.get_meta("entry_id", "") == "sample-05", "Relayout retains anchor entry ID")
	var offset_after: float = restored_anchor.get_global_rect().position.y - panel.transcript.get_global_rect().position.y
	check(absf(offset_after - offset_before) <= 2.0, "Relayout preserves entry-relative scroll offset")
	var literal := "[b]Plain text[/b] <sample> & a literal ending"
	var plain: Array[Dictionary] = [{"id": "literal", "outgoing": false, "texts": {"en": literal}}]
	check(panel.set_projection("lavinia", plain, unread, "en", ""), "Markup-like plain text accepted")
	await settle()
	check(literal in label_texts(panel.messages), "Markup-like text remains literal Label content")
	entries = entries_for_test()
	for stamp in ["+1:00", "12:+1"]:
		var signed_time: Array[Dictionary] = [{"id": "signed", "outgoing": false, "texts": {"en": "Sample"}, "timestamp": stamp}]
		check(not panel.set_projection("priscilla", signed_time, unread, "en", ""), "Signed timestamp rejected")
	panel.set_projection("priscilla", entries, unread, "en", "zh-HK")
	await settle()
	panel.set_projection("priscilla", entries, unread, "en", "zh-HK")
	panel.configure(fonts[0], fonts[1], fonts[2], 150, true)
	await settle()
	check(root.gui_get_focus_owner() == panel.transcript, "Projection then immediate configure retains transcript focus")
	for surface in panel.messages.find_children("*", "PanelContainer", true, false):
		var style: StyleBoxFlat = surface.get_theme_stylebox("panel")
		if style.border_width_left > 0:
			check(style.border_color == Color("14201d"), "Palette refresh updates existing incoming borders")
	panel.set_projection("lavinia", entries, unread, "en", "zh-HK")
	panel.rows[0].grab_focus()
	await settle()
	check(root.gui_get_focus_owner() == panel.rows[0], "Deferred layout does not steal a newer row focus")
	for percent in [100, 125, 150]:
		for locale_pair in [["en", ""], ["zh-CN", "en"], ["zh-HK", "en"]]:
			check(panel.configure(fonts[0], fonts[1], fonts[2], percent, false), "Text size accepted: %d" % percent)
			check(panel.set_projection("sylvia", entries, unread, locale_pair[0], locale_pair[1]), "Language pair accepted")
			await settle()
			var bar = panel.transcript.get_v_scroll_bar()
			check(bar.max_value > bar.page, "Long transcript requires vertical scrolling")
			var horizontal = panel.transcript.get_h_scroll_bar()
			check(horizontal.max_value <= horizontal.page + 1.0, "No horizontal transcript overflow")
			check_label_widths(panel.messages, panel.transcript.size.x)
			panel.transcript.scroll_vertical = 0
			await settle()
			check(panel.get_scroll_state().top and not panel.get_scroll_state().bottom, "Scroll state reports hidden content below")
			panel.transcript.scroll_vertical = 1000000
			await settle()
			check(panel.get_scroll_state().bottom and not panel.get_scroll_state().top, "Scroll state reports ending reachable")
			var last = panel.messages.get_child(panel.messages.get_child_count() - 1)
			check(last.get_global_rect().end.y <= panel.transcript.get_global_rect().end.y + 2.0, "Final message fully reachable")
	panel.transcript.scroll_vertical = 0
	panel.transcript.grab_focus()
	await settle()
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_DPAD_DOWN
	joy.pressed = true
	Input.parse_input_event(joy)
	await settle()
	joy.pressed = false
	Input.parse_input_event(joy)
	check(panel.transcript.scroll_vertical > 0, "Controller D-pad scrolls focused transcript")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await settle()
	cancel.pressed = false
	Input.parse_input_event(cancel)
	check(panel.selected_friend == "sylvia", "Cancel preserves committed selection")
	check(root.gui_get_focus_owner() == panel.rows[2], "Cancel returns focus to selected contact")
	check(panel.configure(fonts[0], fonts[1], fonts[2], 100, false), "Row-focused relayout accepted")
	await settle()
	check(root.gui_get_focus_owner() == panel.rows[2], "Relayout preserves row focus")
	var empty: Array[Dictionary] = []
	check(panel.set_projection("", empty, unread, "en", ""), "Explicit closed projection accepted")
	await settle()
	check(panel.selected_friend == "" and panel.transcript == null and panel.messages == null, "Closed projection restores blank pane")
	panel.rows[2].grab_focus()
	panel.set_projection("", empty, unread, "en", "")
	await settle()
	check(root.gui_get_focus_owner() == panel.rows[2], "Unread-only blank refresh preserves row focus")
	var immediate = script.new()
	root.add_child(immediate)
	immediate.configure(fonts[0], fonts[1], fonts[2], 100, false)
	immediate.set_projection("lavinia", entries_for_test(), unread, "en", "")
	await settle()
	check(root.gui_get_focus_owner() == immediate.transcript, "Initial same-frame projection is not overridden by startup focus")
	immediate.queue_free()
	panel.queue_free()
	await settle()
	if failures.is_empty():
		print("CONTACTS_COMPONENT_PASS: projection, localization, geometry, focus, and scrolling contracts.")
	else:
		printerr("%d Contacts component checks failed." % failures.size())
	quit(0 if failures.is_empty() else 1)
