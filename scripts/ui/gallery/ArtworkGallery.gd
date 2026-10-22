extends Control
signal viewer_visibility_changed(active: bool)
## Read-only projection of durable, visibly witnessed lines. Opening art writes nothing.
const ART := preload("res://scripts/data/ArtManifest.gd")
const UNLOCK_LINES := {"picture1": "line.Day1.one", "picture2": "line.Day1.one",
	"picture3": "line.Day4.one", "picture4": "line.Day2.one", "picture5": "line.Day3.one"}

var _profile: Object
var _rows: Array[Button] = []
var _preview: TextureButton
var _caption: Label
var _selected := ""
var _viewer: CanvasLayer
var _hints: Label
var _return_focus: Control

static func unlocked(profile: Object, picture_id: String) -> bool:
	return is_instance_valid(profile) and profile.has_method("is_line_visited") \
		and UNLOCK_LINES.has(picture_id) and profile.is_line_visited(UNLOCK_LINES[picture_id])

func configure(profile: Object) -> void:
	_profile = profile
	if is_instance_valid(profile):
		if profile.has_signal("visited_history_changed"):
			profile.visited_history_changed.connect(_on_history_changed)
		if profile.has_signal("profile_restored"):
			profile.profile_restored.connect(_on_profile_restored)

func _ready() -> void:
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 24)
	add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 272
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for id: String in UNLOCK_LINES:
		var row := Button.new()
		row.name = id
		row.custom_minimum_size = Vector2(248, 92)
		row.expand_icon = true
		row.add_theme_constant_override("icon_max_width", 104)
		row.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(select_picture.bind(id))
		list.add_child(row)
		_rows.append(row)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(right)
	_preview = TextureButton.new()
	_preview.name = "ArtworkPreview"
	_preview.ignore_texture_size = true
	_preview.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.pressed.connect(open_viewer)
	right.add_child(_preview)
	_caption = Label.new()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size.y = 64
	right.add_child(_caption)
	refresh()

func refresh() -> void:
	if not is_node_ready(): return
	for row: Button in _rows:
		var id := str(row.name)
		var reached := unlocked(_profile, id)
		row.disabled = not reached
		row.text = id.capitalize() if reached else "Locked"
		row.icon = ART.get_texture(id) if reached else null
		row.accessibility_name = id.capitalize() if reached else "Locked artwork"
	if not _selected.is_empty() and not unlocked(_profile, _selected):
		close_viewer()
		_selected = ""
	if _selected.is_empty():
		for id: String in UNLOCK_LINES:
			if unlocked(_profile, id):
				_selected = id
				break
	_update_preview()

func select_picture(id: String) -> void:
	if not unlocked(_profile, id): return
	_selected = id
	_update_preview()

func _update_preview() -> void:
	var texture: Texture2D = ART.get_texture(_selected) if not _selected.is_empty() else null
	_preview.texture_normal = texture
	_preview.disabled = texture == null
	_preview.accessibility_name = "View " + _selected.capitalize()
	_caption.text = "Artwork appears here after you encounter it in the story." if _selected.is_empty() \
		else (_selected.capitalize() + " · Click to view" if texture != null else "Artwork unavailable")

func focus_first() -> void:
	for row: Button in _rows:
		if not row.disabled:
			row.grab_focus()
			return

func viewer_is_open() -> bool:
	return is_instance_valid(_viewer)

func open_viewer() -> void:
	if viewer_is_open() or not unlocked(_profile, _selected): return
	var texture := ART.get_texture(_selected)
	if texture == null: return
	_return_focus = get_viewport().gui_get_focus_owner()
	if is_instance_valid(_return_focus): _return_focus.release_focus()
	_viewer = CanvasLayer.new()
	_viewer.name = "ArtworkViewer"
	_viewer.layer = 100
	add_child(_viewer)
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewer.add_child(backdrop)
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(picture)
	_hints = Label.new()
	_hints.text = "H — Hide · Esc — Exit"
	_hints.add_theme_color_override("font_color", Color.WHITE)
	_hints.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hints.add_theme_constant_override("shadow_offset_x", 2)
	_hints.add_theme_constant_override("shadow_offset_y", 2)
	_hints.position = Vector2(24, 24)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(_hints)
	viewer_visibility_changed.emit(true)

func close_viewer() -> void:
	if not viewer_is_open(): return
	_viewer.queue_free()
	_viewer = null
	_hints = null
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	viewer_visibility_changed.emit(false)

func _input(event: InputEvent) -> void:
	if not viewer_is_open(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_viewer()
		elif event.keycode == KEY_H:
			_hints.visible = not _hints.visible
	# Modal ownership includes releases and mouse input: nothing reaches the title shell.
	get_viewport().set_input_as_handled()

func _on_history_changed(_line_id: String, _visited: bool) -> void:
	refresh()

func _on_profile_restored(_snapshot: Dictionary) -> void:
	refresh()

func _exit_tree() -> void:
	close_viewer()
