extends Button
## Fixed launcher target with an inert pixel icon and a literal accessible name.

var caption: Label
var icon_id: StringName
var unread := false
var _icon_texture: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(176, 176)
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	caption = Label.new()
	caption.name = "Caption"
	caption.position = Vector2(12, 60)
	caption.size = Vector2(152, 108)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)

func set_caption(value: String) -> void:
	caption.text = value
	if value == "Minesweeper" and caption.get_theme_font("font").get_string_size(value,
			HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x > caption.size.x:
		caption.text = "Mine\nsweeper"
	accessibility_name = value

func set_unread(value: bool) -> void:
	unread = value
	queue_redraw()

func set_icon_texture(value: Texture2D) -> void:
	_icon_texture = value
	queue_redraw()

func _outline(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, false, 2)

func _icon_rect(x: int, y: int, width: int, height: int, color: Color) -> void:
	draw_rect(Rect2(64 + x * 2, 8 + y * 2, width * 2, height * 2), color)

func _draw_app_icon(face: Color, ink: Color, structure: Color) -> void:
	# Original 24x24 pixel silhouettes, drawn on the same two-pixel grid.
	match icon_id:
		&"minesweeper":
			_icon_rect(2, 2, 20, 20, ink)
			_icon_rect(3, 3, 18, 18, face)
			_icon_rect(3, 3, 8, 8, structure)
			_icon_rect(12, 3, 1, 18, ink)
			_icon_rect(3, 12, 18, 1, ink)
			_icon_rect(15, 14, 1, 5, ink)
			_icon_rect(16, 14, 4, 2, ink)
			_icon_rect(14, 19, 4, 1, ink)
		&"contacts":
			_icon_rect(2, 6, 20, 14, ink)
			_icon_rect(3, 7, 18, 12, face)
			for step: int in range(8):
				_icon_rect(3 + step, 7 + step, 1, 1, ink)
				_icon_rect(20 - step, 7 + step, 1, 1, ink)
			for step: int in range(5):
				_icon_rect(3 + step, 18 - step, 1, 1, structure)
				_icon_rect(20 - step, 18 - step, 1, 1, structure)
			_icon_rect(11, 14, 2, 1, ink)
		&"schedule":
			_icon_rect(3, 5, 18, 17, ink)
			_icon_rect(4, 6, 16, 15, face)
			_icon_rect(4, 6, 16, 4, structure)
			_icon_rect(7, 2, 2, 6, ink)
			_icon_rect(15, 2, 2, 6, ink)
			for x: int in [6, 11, 16]:
				for y: int in [12, 17]: _icon_rect(x, y, 2, 2, ink)
		&"shop":
			_icon_rect(4, 10, 16, 12, structure)
			_icon_rect(5, 11, 14, 10, face)
			_icon_rect(6, 13, 6, 5, ink)
			_icon_rect(15, 13, 3, 8, ink)
			_icon_rect(4, 4, 16, 2, ink)
			_icon_rect(3, 6, 18, 5, structure)
			for x: int in [3, 9, 15]: _icon_rect(x, 6, 3, 5, ink)
			_icon_rect(3, 21, 18, 1, ink)
		&"backup":
			_icon_rect(6, 3, 12, 7, ink)
			_icon_rect(8, 5, 8, 1, structure)
			_icon_rect(8, 7, 6, 1, structure)
			_icon_rect(3, 10, 18, 12, structure)
			_icon_rect(4, 12, 16, 9, face)
			_icon_rect(2, 9, 20, 3, ink)
			_icon_rect(9, 15, 6, 3, ink)
			_icon_rect(10, 16, 4, 1, face)
		&"settings":
			for x: int in [5, 11, 17]: _icon_rect(x, 3, 2, 18, structure)
			for point: Vector2i in [Vector2i(3, 6), Vector2i(9, 15), Vector2i(15, 9)]:
				_icon_rect(point.x, point.y, 6, 4, ink)
				_icon_rect(point.x + 2, point.y + 1, 2, 2, face)
		&"logout":
			_icon_rect(3, 3, 11, 19, structure)
			_icon_rect(5, 5, 7, 15, face)
			_icon_rect(3, 3, 2, 19, ink)
			_icon_rect(3, 20, 11, 2, ink)
			_icon_rect(10, 11, 11, 2, ink)
			for step: int in range(4):
				_icon_rect(16 + step, 7 + step, 2, 2, ink)
				_icon_rect(16 + step, 15 - step, 2, 2, ink)
		_:
			_icon_rect(4, 2, 16, 20, structure)
			_icon_rect(5, 3, 14, 18, face)
			_icon_rect(8, 8, 8, 1, structure)
			_icon_rect(8, 12, 8, 1, structure)

func _draw() -> void:
	if theme == null:
		return
	var face := get_theme_color("face", "Desktop")
	var ink := get_theme_color("ink", "Desktop")
	var structure := get_theme_color("structure", "Desktop")
	draw_rect(Rect2(0, 0, 176, 176), face)
	if _icon_texture != null:
		draw_texture_rect(_icon_texture, Rect2(64, 8, 48, 48), false)
	else:
		_draw_app_icon(face, ink, structure)
	if unread:
		draw_rect(Rect2(106, 8, 4, 8), ink)
		draw_rect(Rect2(104, 10, 8, 4), ink)
	if is_pressed():
		draw_rect(Rect2(8, 8, 160, 2), ink)
		draw_rect(Rect2(8, 8, 2, 160), ink)
	elif is_hovered():
		draw_rect(Rect2(12, 168, 152, 2), structure)
	if has_focus():
		_outline(Rect2(1, 1, 174, 174), ink)
		_outline(Rect2(5, 5, 166, 166), get_theme_color("focus", "Desktop"))
