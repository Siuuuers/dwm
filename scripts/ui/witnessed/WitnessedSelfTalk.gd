extends Control
## Three shaped text rows over artwork. Canonical reading History owns all text.
signal review_changed
signal return_to_live_requested
signal input_started

var _rows: Array = []
var _live_start := 0
var _paragraphs: Array[TextParagraph] = []
var _lines: Array[Dictionary] = []
var _review_start := -1
var _live_line_start := 0
var _font: Font
var _font_size := 20
var _ink := Color.WHITE
var _pane_name := ""
var _admission: Callable
var _drag_y := 0.0
var _touch_index := -1
var _drag_rows := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func configure(next_theme: Theme, width: float, admission: Callable, pane_name: String = "") -> void:
	_admission = admission
	_pane_name = pane_name
	var next_font := next_theme.get_font(&"normal_font", &"RichTextLabel")
	var next_size := next_theme.get_font_size(&"normal_font_size", &"RichTextLabel")
	var changed := _font != next_font or _font_size != next_size or size.x != width
	_font = next_font
	_font_size = next_size
	_ink = next_theme.get_color(&"default_color", &"RichTextLabel")
	size.x = width
	if changed: _shape()
	else: _update_window()
	queue_redraw()

func project(rows: Array, live_start: int) -> void:
	if rows == _rows and live_start == _live_start: return
	var was_reviewing := is_reviewing()
	var new_publication := rows.size() != _rows.size() or live_start != _live_start
	if not new_publication:
		for index: int in rows.size():
			if rows[index].id != _rows[index].id: new_publication = true
	_rows = rows.duplicate(true)
	_live_start = live_start
	if new_publication: _review_start = -1
	_shape()
	if new_publication and was_reviewing: review_changed.emit()

func has_history() -> bool:
	return not _rows.is_empty()

func is_reviewing() -> bool:
	return _review_start >= 0

func return_to_live() -> void:
	if not is_reviewing(): return
	_review_start = -1
	_update_window()
	review_changed.emit()

func review_rows(delta: int) -> void:
	if _lines.is_empty(): return
	var current := _review_start if is_reviewing() else _live_line_start
	var next := clampi(current - delta, 0, _lines.size())
	if delta < 0 and next >= _live_line_start:
		return_to_live()
		return
	if next == current and is_reviewing(): return
	if next == current and not is_reviewing() and _live_start < _rows.size(): return
	_review_start = next
	_update_window()
	review_changed.emit()

func _shape() -> void:
	if _font == null: return
	var anchor: Dictionary = _lines[_review_start].duplicate() if is_reviewing() and _review_start < _lines.size() else {}
	_paragraphs.clear()
	_lines.clear()
	var first_live_line := 0
	for index: int in _rows.size():
		if index == _live_start: first_live_line = _lines.size()
		var paragraph := TextParagraph.new()
		paragraph.width = maxf(1.0, size.x)
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(str(_rows[index].text), _font, _font_size)
		_paragraphs.append(paragraph)
		for line: int in paragraph.get_line_count():
			var span := paragraph.get_line_range(line)
			_lines.append({"id":_rows[index].id, "start":span.x, "end":span.y,
				"entry":index, "line":line, "height":ceilf(paragraph.get_line_ascent(line) + paragraph.get_line_descent(line))})
	if _live_start >= _rows.size(): first_live_line = _lines.size()
	_live_line_start = maxi(first_live_line, _lines.size() - 3)
	if not anchor.is_empty():
		_review_start = -1
		for index: int in _lines.size():
			if _lines[index].id == anchor.id and int(_lines[index].start) <= int(anchor.start):
				_review_start = index
	_update_window()

func _update_window() -> void:
	var line_height := ceilf(_font.get_height(_font_size)) if _font != null else 24.0
	for row: Dictionary in _visible_rows(): line_height = maxf(line_height, float(row.height))
	size.y = line_height * 3
	visible = not _rows.is_empty()
	var copy := PackedStringArray()
	for row: Dictionary in _visible_rows():
		copy.append(str(_rows[row.entry].text).substr(row.start, row.end - row.start))
	accessibility_name = _pane_name if copy.is_empty() else "\n".join(copy)
	queue_redraw()

func _visible_rows() -> Array[Dictionary]:
	var start := _review_start if is_reviewing() else _live_line_start
	var result: Array[Dictionary] = []
	for index: int in range(start, mini(start + 3, _lines.size())): result.append(_lines[index])
	return result

func get_projection() -> Dictionary:
	return {"visible_rows":_visible_rows().duplicate(true), "reviewing":is_reviewing(),
		"history_count":_rows.size(), "live_start":_live_start, "row_count":_lines.size()}

func _draw() -> void:
	var top := 0.0
	for row: Dictionary in _visible_rows():
		var paragraph: TextParagraph = _paragraphs[row.entry]
		paragraph.draw_line_outline(get_canvas_item(), Vector2(0, top), row.line, 2, Color(0.05, 0.05, 0.05, 0.9))
		paragraph.draw_line(get_canvas_item(), Vector2(0, top), row.line, _ink)
		top += row.height
	if has_focus(): draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), _ink, false)

func _gui_input(event: InputEvent) -> void:
	if _admission.is_valid() and not _admission.call():
		accept_event()
		return
	if event is InputEventMouseButton:
		input_started.emit()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			review_rows(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_y = event.position.y
				_drag_rows = 0
				grab_focus()
			elif is_reviewing() and absf(event.position.y - _drag_y) < 4:
				return_to_live_requested.emit()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		input_started.emit()
		_drag_rows += event.relative.y
		_scroll_drag()
	elif event is InputEventScreenTouch:
		input_started.emit()
		if event.pressed:
			_touch_index = event.index
			_drag_y = event.position.y
			_drag_rows = 0
		elif event.index == _touch_index:
			_touch_index = -1
			if is_reviewing() and absf(event.position.y - _drag_y) < 4: return_to_live_requested.emit()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		input_started.emit()
		_drag_rows += event.relative.y
		_scroll_drag()
	elif event is InputEventPanGesture:
		input_started.emit()
		_drag_rows -= event.delta.y * 20
		_scroll_drag()
	elif event is InputEventKey and event.pressed:
		input_started.emit()
		if event.keycode in [KEY_UP, KEY_PAGEUP]: review_rows(1)
		elif event.keycode in [KEY_DOWN, KEY_PAGEDOWN]: review_rows(-1)
		elif event.keycode in [KEY_END, KEY_ENTER, KEY_SPACE]: return_to_live_requested.emit()
	accept_event()

func _scroll_drag() -> void:
	var height := maxf(1, size.y / 3)
	var count := int(_drag_rows / height)
	if count == 0: return
	_drag_rows -= count * height
	review_rows(count)
