extends Button
## One target; marks are drawn, never extra controls or unread counts.

var identity_index := 0
var selected := false
var unread := false
var display_name := ""
var portrait_texture: Texture2D

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)

func _outline(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), color)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2)), color)
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 2, 0), Vector2(2, rect.size.y)), color)

func _draw() -> void:
	var ink := get_theme_color("ink", "Contacts")
	var dark := get_theme_color("instrument", "Contacts")
	var bone := get_theme_color("bone", "Contacts")
	var filed := get_theme_color("filed", "Contacts")
	var void_color := get_theme_color("void", "Contacts")
	draw_rect(Rect2(0, 0, 248, 96), dark)
	draw_rect(Rect2(8, 8, 32, 80), void_color)
	draw_rect(Rect2(216, 8, 24, 80), void_color)
	if selected:
		draw_rect(Rect2(40, 8, 176, 80), filed)
		draw_rect(Rect2(40, 8, 2, 80), ink)
	var identity := get_theme_color("identity_%d" % identity_index, "Contacts")
	if portrait_texture != null:
		draw_texture_rect(portrait_texture, Rect2(8, 16, 32, 64), false)
	elif identity_index == 2:
		draw_rect(Rect2(16, 16, 6, 64), identity)
		draw_rect(Rect2(26, 16, 6, 64), identity)
	else:
		draw_rect(Rect2(16, 16, 16, 64), identity)
		if identity_index == 1:
			draw_rect(Rect2(24, 44, 8, 8), void_color)
	if unread:
		draw_rect(Rect2(224, 44, 8, 8), get_theme_color("paper", "Contacts"))
	if is_pressed():
		draw_rect(Rect2(44, 14, 166, 2), ink if selected else bone)
		draw_rect(Rect2(44, 14, 2, 68), ink if selected else bone)
	elif is_hovered():
		draw_rect(Rect2(46, 82, 164, 2), ink if selected else get_theme_color("gold", "Contacts"))
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size", "Label")
	var baseline := (96 - font.get_height(font_size)) / 2 + font.get_ascent(font_size)
	draw_string(font, Vector2(48, baseline), display_name, HORIZONTAL_ALIGNMENT_LEFT, 160, font_size, ink if selected else bone)
	if has_focus():
		_outline(Rect2(0, 0, 248, 96), ink if selected else bone)
		_outline(Rect2(2, 2, 244, 92), filed if selected else dark)
		_outline(Rect2(4, 4, 240, 88), ink if selected else get_theme_color("gold", "Contacts"))
