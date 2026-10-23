extends Control
## Projection only. The containing paper owns scrolling; the scene owns Replay and departure.
signal item_selected(index: int)
signal row_focused(row: Control)
signal layout_changed
signal focused_row_removed(hide_focus: bool)

const ROW := preload("res://scripts/ui/gallery/GalleryRecordButton.gd")
var _rows: Array[Control] = []
var _heading: Label
var _interactive := true
var _laying_out := false
var _layout_queued := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	_ensure_heading()
	refresh_layout()

func _ensure_heading() -> void:
	if is_instance_valid(_heading): return
	_heading = Label.new()
	_heading.name = "VersionHeading"
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.add_theme_constant_override("line_spacing", 0)
	add_child(_heading)

func set_versions(entries: Array[Dictionary], selected_id: String, locale: String, heading_copy: String) -> void:
	_ensure_heading()
	var retained: Dictionary = {}
	for row: Control in _rows: retained[row.get_meta("gallery_signature_id")] = row
	var next: Array[Control] = []
	var removed_focus := false
	var hide_focus := false
	# A singular version has no register, including no hidden focus or assistive rows.
	if entries.size() >= 2:
		for entry: Dictionary in entries:
			var id := str(entry.signature_id)
			var row: Button = retained.get(id)
			if row == null:
				row = ROW.new()
				row.paper_context = true
				row.caption_width = 464.0
				row.body_width = 504.0
				row.set_meta("gallery_signature_id", id)
				row.focus_entered.connect(_on_row_focused.bind(row))
				row.pressed.connect(_on_row_pressed.bind(row))
				add_child(row)
			retained.erase(id)
			row.text = str(entry.cue)
			row.language = locale.replace("_", "-")
			next.append(row)
	for row: Control in retained.values():
		if row.has_focus():
			removed_focus = true
			hide_focus = not row.has_focus(true)
		remove_child(row)
		row.queue_free()
	_rows = next
	for index: int in range(_rows.size()): move_child(_rows[index], index + 1)
	var language_code := locale.replace("_", "-")
	_heading.language = language_code
	_heading.text = heading_copy
	set_selected(selected_id)
	set_interactive(_interactive)
	refresh_layout()
	if removed_focus: focused_row_removed.emit(hide_focus)

func set_selected(signature_id: String) -> void:
	for row: Control in _rows:
		row.selected = str(row.get_meta("gallery_signature_id")) == signature_id

func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	for row: Control in _rows:
		row.disabled = not enabled
		row.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		if not enabled: row.cancel_pointer_press()

func get_rows() -> Array[Control]:
	return _rows.duplicate()

func row_for_signature(id: String) -> Control:
	for row: Control in _rows:
		if str(row.get_meta("gallery_signature_id")) == id: return row
	return null

func focused_signature_id() -> String:
	for row: Control in _rows:
		if row.has_focus(): return str(row.get_meta("gallery_signature_id"))
	return ""

func refresh_layout() -> void:
	if _laying_out: return
	_laying_out = true
	_ensure_heading()
	visible = _rows.size() >= 2
	_heading.visible = visible
	if not visible:
		remove_child(_heading)
		_heading.queue_free()
		_heading = null
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
	else:
		_heading.add_theme_color_override("font_color", get_theme_color("secondary_ink", "Gallery"))
		_heading.position = Vector2(24, 0)
		_heading.size = Vector2(464, 0)
		var heading_height := ceilf(_heading.get_minimum_size().y / 2.0) * 2.0
		_heading.size = Vector2(464, heading_height)
		var y := heading_height + 8.0
		for index: int in range(_rows.size()):
			var row: Control = _rows[index]
			row.refresh_caption()
			row.position = Vector2(8, y)
			row.size = row.custom_minimum_size
			row.focus_neighbor_top = row.get_path_to(_rows[maxi(0, index - 1)])
			row.focus_neighbor_bottom = row.get_path_to(_rows[mini(_rows.size() - 1, index + 1)])
			y += row.size.y + 8.0
		custom_minimum_size = Vector2(520, y)
		size = custom_minimum_size
	layout_changed.emit()
	_laying_out = false

func _on_row_focused(row: Control) -> void:
	if not _interactive: return
	var index := _rows.find(row)
	if index < 0: return
	item_selected.emit(index)
	row_focused.emit(row)

func _on_row_pressed(row: Control) -> void:
	if not _interactive: return
	var index := _rows.find(row)
	if index >= 0: item_selected.emit(index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_inside_tree() and not _layout_queued:
		_layout_queued = true
		_refresh_theme.call_deferred()

func _refresh_theme() -> void:
	_layout_queued = false
	refresh_layout()
