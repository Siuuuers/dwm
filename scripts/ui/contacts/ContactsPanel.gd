extends Control
## Presentation only. The caller owns read/open transactions and supplies committed text.
## Baseline is the 800x656 plate; extra host width expands the reading pane.

signal open_requested(friend_id: String)
signal back_requested
signal pending_reply_drawn(rendered_line: Dictionary)

const Row = preload("res://scripts/ui/contacts/ContactsRow.gd")
const ART_MANIFEST := preload("res://scripts/data/ArtManifest.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const CONTACTS_THEME := preload("res://scripts/ui/contacts/ContactsTheme.gd")
const FRIENDS := ["priscilla", "lavinia", "sylvia"]
const NAMES := ["Priscilla", "Lavinia", "Sylvia"]
const LOCALES := ["en", "zh-CN", "zh-HK", "ja", "ko"]

var selected_friend := ""
var rows: Array[Button] = []
var transcript: ScrollContainer
var messages: VBoxContainer
var font_size := 24
var _fonts: Dictionary = {}
var _entries: Array = []
var _unread: Dictionary = {}
var _primary := "en"
var _secondary := ""
var _header: Label
var _continuation: Control
var _revision := 0
var _pending_reply: Dictionary = {}
var _pending_label: Label
var _pending_emitted := false
var _presentation: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(800, 656)
	clip_contents = true
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for i in range(3):
		var row := Row.new()
		row.position = Vector2(0, 8 + 96 * i)
		row.size = Vector2(248, 96)
		row.identity_index = i
		row.portrait_texture = ART_MANIFEST.get_texture("contact.%s.row" % FRIENDS[i], Vector2i(32, 64))
		row.display_name = NAMES[i]
		row.accessibility_name = NAMES[i]
		row.pressed.connect(func(): open_requested.emit(FRIENDS[i]))
		row.gui_input.connect(_row_input)
		add_child(row)
		rows.append(row)
	for i in range(3):
		rows[i].focus_neighbor_top = rows[i].get_path_to(rows[maxi(0, i - 1)])
		rows[i].focus_neighbor_bottom = rows[i].get_path_to(rows[mini(2, i + 1)])
	rows[0].grab_focus()
	resized.connect(_on_resized)

func _on_resized() -> void:
	# Anchors widen the same transcript; retain the current reading position.
	var anchor := _scroll_anchor()
	_revision += 1
	_restore_scroll.call_deferred(anchor, _revision)
	queue_redraw()

func configure(english: Font, simplified: Font, traditional: Font, text_percent: int = 100,
		midnight: bool = false, day: int = 1, high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	if english == null or simplified == null or traditional == null or text_percent not in [100, 125, 150]:
		return false
	var palette: StringName = &"midnight" if midnight else &"after_hours"
	var candidate := CONTACTS_THEME.build(english, 24 * text_percent / 100, palette, day, high_contrast, colour_preset)
	if candidate == null: return false
	var anchor := _scroll_anchor()
	_fonts = {"en": english, "zh-CN": simplified, "zh-HK": traditional,
		"ja": TYPOGRAPHY.font("ja", text_percent), "ko": TYPOGRAPHY.font("ko", text_percent)}
	font_size = 24 * text_percent / 100
	theme = candidate
	_presentation = [palette, day, high_contrast, colour_preset]
	for label in find_children("*", "Label", true, false):
		_style_label(label, label.get_meta("locale", "en"), label.get_meta("outgoing", false))
	_apply_materials()
	_revision += 1
	_restore_scroll.call_deferred(anchor, _revision)
	return true

func apply_presentation(palette: StringName, day: int, high_contrast: bool, colour_preset: String) -> bool:
	if _fonts.is_empty(): return false
	if _presentation == [palette, day, high_contrast, colour_preset]: return true
	var candidate := CONTACTS_THEME.build(_fonts.en, font_size, palette, day, high_contrast, colour_preset)
	if candidate == null: return false
	theme = candidate
	_presentation = [palette, day, high_contrast, colour_preset]
	# Retain geometry and the exact pending draw receipt; only materials change.
	_apply_materials()
	return true

func _apply_materials() -> void:
	for label: Label in find_children("*", "Label", true, false):
		var role: String = label.get_meta("contacts_color_role", "ink")
		label.add_theme_color_override("font_color", theme.get_color(role, "Contacts"))
	for surface: PanelContainer in find_children("*", "PanelContainer", true, false):
		if not surface.has_meta("contacts_background_role"): continue
		var style := surface.get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = theme.get_color(surface.get_meta("contacts_background_role"), "Contacts")
		style.border_color = theme.get_color("ink", "Contacts")
		surface.queue_redraw()
	for row: Button in rows: row.queue_redraw()
	_queue_continuation()
	queue_redraw()

func set_projection(friend_id: String, entries: Array, unread: Dictionary, primary_locale: String = "en", secondary_locale: String = "") -> bool:
	if _fonts.is_empty() or not _valid_projection(friend_id, entries, unread, primary_locale, secondary_locale):
		return false
	var same_friend := selected_friend == friend_id
	var anchor := _scroll_anchor() if same_friend else {}
	var had_transcript_focus := transcript != null and transcript.has_focus()
	selected_friend = friend_id
	_entries = entries.duplicate(true)
	_unread = unread.duplicate(true)
	_primary = primary_locale
	_secondary = secondary_locale
	_clear_thread()
	_update_rows()
	if not friend_id.is_empty():
		_build_thread()
		if not same_friend or had_transcript_focus:
			transcript.grab_focus()
	elif not rows.is_empty() and (not same_friend or get_viewport().gui_get_focus_owner() == null):
		rows[0].grab_focus()
	_revision += 1
	_restore_scroll.call_deferred(anchor, _revision)
	queue_redraw()
	return true

func _valid_projection(friend_id: String, entries: Array, unread: Dictionary, primary: String, secondary: String) -> bool:
	if friend_id not in FRIENDS and friend_id != "":
		return false
	if friend_id == "" and not entries.is_empty():
		return false
	if primary not in LOCALES or (secondary != "" and (secondary not in LOCALES or secondary == primary)):
		return false
	for key in unread:
		if key not in FRIENDS or not unread[key] is bool:
			return false
	var ids: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id):
			return false
		if not entry.get("outgoing") is bool or not entry.get("texts") is Dictionary:
			return false
		ids[entry.id] = true
		for locale in [primary, secondary]:
			if locale != "" and (not entry.texts.get(locale) is String or entry.texts[locale].is_empty()):
				return false
		if entry.has("timestamp"):
			var stamp = entry.timestamp
			if not stamp is String or stamp.length() != 5 or stamp[2] != ":":
				return false
			for index in [0, 1, 3, 4]:
				if stamp.unicode_at(index) < 48 or stamp.unicode_at(index) > 57:
					return false
			if not stamp.substr(0, 2).is_valid_int() or not stamp.substr(3, 2).is_valid_int():
				return false
			if int(stamp.substr(0, 2)) not in range(24) or int(stamp.substr(3, 2)) not in range(60):
				return false
	return true

func _update_rows() -> void:
	for i in range(rows.size()):
		rows[i].selected = selected_friend == FRIENDS[i]
		rows[i].unread = _unread.get(FRIENDS[i], false)
		var words := {"en": ["Open thread", "Unread"], "zh-CN": ["已打开的会话", "未读"], "zh-HK": ["已開啟的對話", "未讀"], "ja": ["開いている会話", "未読"], "ko": ["열린 대화", "읽지 않음"]}
		var facts: Array[String] = []
		if rows[i].selected:
			facts.append(words[_primary][0])
		if rows[i].unread:
			facts.append(words[_primary][1])
		rows[i].accessibility_description = ", ".join(facts)
		rows[i].queue_redraw()

func _clear_thread() -> void:
	_pending_reply = {}
	_pending_label = null
	_pending_emitted = false
	for node in [_header, transcript, _continuation]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_header = null
	transcript = null
	messages = null
	_continuation = null

func _build_thread() -> void:
	_header = Label.new()
	_header.text = NAMES[FRIENDS.find(selected_friend)]
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header.offset_left = 304
	_header.offset_right = -16
	_header.offset_top = 16
	_header.offset_bottom = 80
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.set_meta("contacts_color_role", "bone")
	_header.add_theme_color_override("font_color", theme.get_color("bone", "Contacts"))
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	transcript = ScrollContainer.new()
	transcript.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transcript.offset_left = 248
	transcript.offset_top = 96
	transcript.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	transcript.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	transcript.focus_mode = Control.FOCUS_ALL
	transcript.draw_focus_border = true
	transcript.accessibility_name = _header.text
	transcript.gui_input.connect(_transcript_input)
	transcript.get_v_scroll_bar().value_changed.connect(func(_value): _queue_continuation())
	transcript.get_v_scroll_bar().changed.connect(_queue_continuation)
	add_child(transcript)
	messages = VBoxContainer.new()
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages.add_theme_constant_override("separation", 0)
	transcript.add_child(messages)
	for entry in _entries:
		_append_entry(entry, [_primary, _secondary])
	_continuation = Control.new()
	_continuation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_continuation.offset_left = 248
	_continuation.offset_top = 96
	_continuation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continuation.z_index = 1
	_continuation.draw.connect(_draw_continuation)
	add_child(_continuation)

func _append_entry(entry: Dictionary, locales: Array) -> Label:
	var first_label: Label
	var margin := MarginContainer.new()
	margin.set_meta("entry_id", entry.id)
	margin.add_theme_constant_override("margin_left", 56 if entry.outgoing else 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 4)
	messages.add_child(margin)
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 8)
	margin.add_child(block)
	var surface := PanelContainer.new()
	surface.set_meta("contacts_background_role", "plum" if entry.outgoing else "paper")
	var style := StyleBoxFlat.new()
	style.bg_color = theme.get_color("plum" if entry.outgoing else "paper", "Contacts")
	style.border_color = theme.get_color("ink", "Contacts")
	style.border_width_left = 0 if entry.outgoing else 2
	style.content_margin_left = 16
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	surface.add_theme_stylebox_override("panel", style)
	block.add_child(surface)
	var text_stack := VBoxContainer.new()
	text_stack.add_theme_constant_override("separation", 12)
	surface.add_child(text_stack)
	for locale in locales:
		if locale == "":
			continue
		var label := Label.new()
		label.text = entry.texts[locale]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_meta("locale", locale)
		label.set_meta("outgoing", entry.outgoing)
		_style_label(label, locale, entry.outgoing)
		text_stack.add_child(label)
		if first_label == null: first_label = label
	if entry.has("timestamp"):
		var time := Label.new()
		time.text = entry.timestamp
		_style_label(time, "en", false)
		block.add_child(time)
	if entry.outgoing:
		# Decoration draws on the panel itself; internal Controls are still container children.
		surface.draw.connect(_draw_outgoing_notch.bind(surface))
	return first_label

func _draw_outgoing_notch(surface: Control) -> void:
	surface.draw_rect(Rect2(surface.size.x - 8, 12, 8, 8), theme.get_color("paper_mark", "Contacts"))

func present_pending_reply(rendered_line: Dictionary, locale: String) -> bool:
	if messages == null or transcript == null or locale not in LOCALES or rendered_line.size() != 3:
		return false
	for key: String in ["view_token", "line_id", "text"]:
		if not rendered_line.get(key) is String or rendered_line[key].is_empty(): return false
	if not _pending_reply.is_empty(): return _pending_reply == rendered_line
	_pending_reply = rendered_line.duplicate(true)
	_pending_emitted = false
	_pending_label = _append_entry({"id": "ui:ordinary:" + rendered_line.view_token,
		"outgoing": true, "texts": {locale: rendered_line.text}}, [locale])
	_pending_label.name = "PendingOrdinaryReply"
	_pending_label.draw.connect(_on_pending_reply_drawn.bind(_pending_label, rendered_line.duplicate(true)))
	_reveal_pending_reply.call_deferred(str(rendered_line.view_token))
	return true

func _reveal_pending_reply(token: String) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _pending_reply.get("view_token") != token \
		or not is_instance_valid(transcript) or not is_instance_valid(_pending_label): return
	transcript.ensure_control_visible(_pending_label)

func _on_pending_reply_drawn(label: Label, rendered_line: Dictionary) -> void:
	if _pending_emitted or label != _pending_label or rendered_line != _pending_reply \
		or not is_instance_valid(label) or not label.is_visible_in_tree() or is_queued_for_deletion(): return
	_pending_emitted = true
	pending_reply_drawn.emit(rendered_line.duplicate(true))

func _style_label(label: Label, locale: String, outgoing: bool) -> void:
	label.add_theme_font_override("font", _fonts[locale])
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", maxi(0, int(font_size * 1.55 - _fonts[locale].get_height(font_size))))
	var role: String = label.get_meta("contacts_color_role", "bone" if outgoing or label == _header else "ink")
	label.set_meta("contacts_color_role", role)
	label.add_theme_color_override("font_color", theme.get_color(role, "Contacts"))
	label.language = locale

func _scroll_anchor() -> Dictionary:
	if transcript == null or messages == null:
		return {}
	for block in messages.get_children():
		if block.position.y + block.size.y > transcript.scroll_vertical:
			return {"id": block.get_meta("entry_id"), "offset": transcript.scroll_vertical - block.position.y}
	return {}

func _restore_scroll(anchor: Dictionary, revision: int, frames_left: int = 3) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or revision != _revision: return
	if frames_left > 0:
		# A Node-bound one-shot disconnects on destruction; an awaiting instance cannot.
		var next := _restore_scroll.bind(anchor.duplicate(true), revision, frames_left - 1)
		if not get_tree().process_frame.is_connected(next):
			get_tree().process_frame.connect(next, CONNECT_ONE_SHOT)
		return
	if not is_instance_valid(transcript) or not is_instance_valid(messages): return
	for block in messages.get_children():
		if block.get_meta("entry_id") == anchor.get("id", ""):
			transcript.scroll_vertical = int(block.position.y + anchor.offset)
			break
	_queue_continuation()

func _queue_continuation() -> void:
	if is_instance_valid(_continuation):
		_continuation.queue_redraw()

func _draw_continuation() -> void:
	var ink := theme.get_color("ink", "Contacts")
	var bounds := get_scroll_state()
	var center_x := (_continuation.size.x - 12) / 2
	if not bounds.top:
		_continuation.draw_rect(Rect2(center_x, 0, 12, 4), ink)
	if not bounds.bottom:
		_continuation.draw_rect(Rect2(center_x, _continuation.size.y - 4, 12, 4), ink)

func get_scroll_state() -> Dictionary:
	if transcript == null:
		return {"top": true, "bottom": true}
	var bar := transcript.get_v_scroll_bar()
	return {"top": bar.value <= 1, "bottom": bar.value + bar.page >= bar.max_value - 1}

func _row_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

func _transcript_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_left"):
		rows[FRIENDS.find(selected_friend)].grab_focus()
	elif event.is_action_pressed("ui_down"):
		var bar := transcript.get_v_scroll_bar()
		if transcript.scroll_vertical >= bar.max_value - bar.page and not transcript.focus_neighbor_bottom.is_empty():
			var target := transcript.get_node_or_null(transcript.focus_neighbor_bottom) as Control
			if target != null:
				target.grab_focus()
		else:
			transcript.scroll_vertical += 48
	elif event.is_action_pressed("ui_up"):
		transcript.scroll_vertical -= 48
	elif event is InputEventKey and event.keycode in [KEY_HOME, KEY_END, KEY_PAGEDOWN, KEY_PAGEUP]:
		match event.keycode:
			KEY_HOME: transcript.scroll_vertical = 0
			KEY_END: transcript.scroll_vertical = int(transcript.get_v_scroll_bar().max_value)
			KEY_PAGEDOWN: transcript.scroll_vertical += 480
			KEY_PAGEUP: transcript.scroll_vertical -= 480
	else:
		return
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Synthetic accessibility action events do not travel through gui_input.
	if event is InputEventAction and transcript != null and transcript.has_focus():
		_transcript_input(event)

func _draw() -> void:
	if theme == null:
		return
	draw_rect(Rect2(0, 0, 248, size.y), theme.get_color("instrument", "Contacts"))
	draw_rect(Rect2(248, 0, size.x - 248, size.y), theme.get_color("paper", "Contacts"))
	if selected_friend == "":
		return
	draw_rect(Rect2(248, 0, size.x - 248, 96), theme.get_color("instrument", "Contacts"))
	draw_rect(Rect2(256, 16, 32, 64), theme.get_color("void", "Contacts"))
	var header_art := ART_MANIFEST.get_texture("contact.%s.header" % selected_friend, Vector2i(32, 64))
	var identity := theme.get_color("identity_%d" % FRIENDS.find(selected_friend), "Contacts")
	if header_art != null:
		draw_texture_rect(header_art, Rect2(256, 16, 32, 64), false)
	elif selected_friend == "sylvia":
		draw_rect(Rect2(264, 16, 6, 64), identity)
		draw_rect(Rect2(274, 16, 6, 64), identity)
	else:
		draw_rect(Rect2(264, 16, 16, 64), identity)
		if selected_friend == "lavinia":
			draw_rect(Rect2(272, 44, 8, 8), theme.get_color("void", "Contacts"))
