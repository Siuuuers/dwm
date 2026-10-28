extends Control
## A read-only projection. Only accepted story reading changes discovery membership.
signal navigation_changed
signal empty_focus_requested
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const CATALOGUE := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")
const DEFAULT_COPY := {"empty": "Dialogue appears here after you reach a passage in the story.",
	"unread": "Unread dialogue", "thought": "Self-talk", "passage": "Passage dialogue"}
var _profile: Object
var _copy: Dictionary = DEFAULT_COPY.duplicate()
var _locale := "en"
var _passages: Array = []
var _selected := ""
var _rows: Array[Button] = []
var _index: VBoxContainer
var _paper: VBoxContainer
var _scroll: ScrollContainer
var _empty: Label

func configure(profile: Object) -> void:
	_profile = profile
	if is_instance_valid(profile):
		if profile.has_signal("dialogue_library_changed"):
			profile.dialogue_library_changed.connect(refresh)
		if profile.has_signal("profile_restored"):
			profile.profile_restored.connect(_on_profile_restored)
		if profile.has_signal("preference_changed"):
			profile.preference_changed.connect(_on_preference_changed)

func configure_copy(copy: Dictionary, locale: String) -> void:
	_copy = copy.duplicate()
	_locale = locale
	if is_node_ready(): refresh()

func _ready() -> void:
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 24)
	add_child(layout)
	var index_scroll := ScrollContainer.new()
	index_scroll.custom_minimum_size.x = 256
	index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	index_scroll.follow_focus = true
	layout.add_child(index_scroll)
	_index = VBoxContainer.new()
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.add_theme_constant_override("separation", 8)
	index_scroll.add_child(_index)
	_scroll = ScrollContainer.new()
	_scroll.name = "Passage"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.gui_input.connect(_on_passage_input)
	layout.add_child(_scroll)
	_paper = VBoxContainer.new()
	_paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paper.add_theme_constant_override("separation", 16)
	_scroll.add_child(_paper)
	_empty = Label.new()
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)
	refresh()

func refresh() -> void:
	if not is_node_ready() or not is_visible_in_tree(): return
	var paper_had_focus := _scroll.has_focus()
	var had_focus := paper_had_focus
	for row: Button in _rows: had_focus = had_focus or row.has_focus()
	var secondary := ""
	if is_instance_valid(_profile) and _profile.has_method("get_preference") and _profile.get_preference(&"preferences.language.dual_enabled", false):
		secondary = str(_profile.get_preference(&"preferences.language.secondary_locale_id", ""))
	_passages = CATALOGUE.reached_passages(_profile.get_dialogue_library(), _locale, secondary) if is_instance_valid(_profile) and _profile.has_method("get_dialogue_library") else []
	for row: Button in _rows:
		_index.remove_child(row)
		row.queue_free()
	_rows.clear()
	var retained := false
	for passage: Dictionary in _passages:
		var row := Button.new()
		row.text = str(passage.title)
		row.accessibility_name = row.text
		row.language = _locale.replace("_", "-")
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(240, 48)
		row.theme_type_variation = &"GalleryDarkAction"
		row.toggle_mode = true
		row.pressed.connect(select_passage.bind(str(passage.id)))
		_index.add_child(row)
		_rows.append(row)
		retained = retained or str(passage.id) == _selected
	if not retained: _selected = str(_passages[0].id) if not _passages.is_empty() else ""
	_empty.text = str(_copy.empty)
	_empty.accessibility_name = _empty.text
	_empty.add_theme_color_override("font_color", get_theme_color("ink", "Gallery"))
	_empty.visible = _passages.is_empty()
	_scroll.visible = not _passages.is_empty()
	_scroll.accessibility_name = str(_copy.passage)
	_show_passage(retained)
	if had_focus:
		if paper_had_focus and not _passages.is_empty(): _scroll.grab_focus()
		elif not focus_first(): empty_focus_requested.emit()
	navigation_changed.emit()

func select_passage(id: String) -> void:
	if _selected == id:
		for index: int in _rows.size(): _rows[index].set_pressed_no_signal(str(_passages[index].id) == id)
		return
	_selected = id
	_show_passage(false)

func _show_passage(retain_scroll: bool) -> void:
	var offset := _scroll.scroll_vertical if retain_scroll else 0
	for child: Node in _paper.get_children():
		_paper.remove_child(child)
		child.queue_free()
	for passage: Dictionary in _passages:
		if str(passage.id) != _selected: continue
		_add_text(str(passage.title))
		for entry: Dictionary in passage.entries:
			# Unread prose never enters a Label, tooltip, metadata or accessibility name.
			if entry.read:
				if str(entry.kind) == "thought": _add_text(str(_copy.thought))
				_add_text(str(entry.text), str(entry.content_locale))
				if not str(entry.secondary_text).is_empty():
					_add_text(str(entry.secondary_text), str(entry.secondary_locale))
			else:
				var wording := str(_copy.unread)
				if str(entry.kind) == "thought": wording = str(_copy.thought) + "\n" + wording
				_add_text(wording)
			if not str(entry.requirements).is_empty(): _add_text(str(entry.requirements))
		break
	_scroll.set_deferred("scroll_vertical", offset)
	for index: int in _rows.size():
		var row := _rows[index]
		row.set_pressed_no_signal(str(_passages[index].id) == _selected)
		row.focus_neighbor_top = _rows[maxi(index - 1, 0)].get_path()
		row.focus_neighbor_bottom = _rows[mini(index + 1, _rows.size() - 1)].get_path()
		row.focus_neighbor_left = row.get_path()
		row.focus_neighbor_right = _scroll.get_path()
		if str(_passages[index].id) == _selected: _scroll.focus_neighbor_left = row.get_path()
	_scroll.focus_neighbor_right = _scroll.get_path()
	navigation_changed.emit()

func _add_text(text: String, content_locale: String = "") -> void:
	var label := Label.new()
	label.text = text
	label.accessibility_name = text
	label.language = (_locale if content_locale.is_empty() else content_locale).replace("_", "-")
	if not content_locale.is_empty():
		var percent := 100
		var style := "pixel"
		if _profile.has_method("get_preference"):
			percent = int(_profile.get_preference(&"preferences.accessibility.text_size", 100))
			style = str(_profile.get_preference(&"preferences.accessibility.font_style", "pixel"))
		label.add_theme_font_override("font", TYPOGRAPHY.story_font(content_locale, percent, style))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", get_theme_color("ink", "Gallery"))
	_paper.add_child(label)

func focus_first() -> bool:
	for index: int in _rows.size():
		if str(_passages[index].id) == _selected:
			_rows[index].grab_focus()
			return true
	return false

func focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for row: Button in _rows: controls.append(row)
	if _scroll.visible: controls.append(_scroll)
	return controls

func _on_passage_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down", true): _scroll.scroll_vertical += 48
	elif event.is_action_pressed("ui_up", true): _scroll.scroll_vertical -= 48
	elif event.is_action_pressed("ui_page_down", true): _scroll.scroll_vertical += int(_scroll.size.y)
	elif event.is_action_pressed("ui_page_up", true): _scroll.scroll_vertical -= int(_scroll.size.y)
	elif event.is_action_pressed("ui_home"): _scroll.scroll_vertical = 0
	elif event.is_action_pressed("ui_end"): _scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	else: return
	accept_event()

func _on_profile_restored(_snapshot: Dictionary) -> void:
	refresh()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path in [&"preferences.language.secondary_locale_id", &"preferences.language.dual_enabled"]:
		refresh()
