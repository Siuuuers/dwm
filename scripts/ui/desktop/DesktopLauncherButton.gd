extends Button
## Fixed launcher target. Its literal label supplies identity; the inert aperture
## is the same fallback silhouette for every missing decorative icon.

var caption: Label
var _icon_texture: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(176, 176)
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	caption = Label.new()
	caption.name = "Caption"
	caption.position = Vector2(12, 72)
	caption.size = Vector2(152, 96)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)

func set_caption(value: String) -> void:
	caption.text = value
	accessibility_name = value

func set_icon_texture(value: Texture2D) -> void:
	_icon_texture = value
	queue_redraw()

func _outline(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, false, 2)

func _draw() -> void:
	if theme == null:
		return
	var face := get_theme_color("face", "Desktop")
	var ink := get_theme_color("ink", "Desktop")
	var structure := get_theme_color("structure", "Desktop")
	draw_rect(Rect2(0, 0, 176, 176), face)
	if _icon_texture != null:
		draw_texture_rect(_icon_texture, Rect2(64, 16, 48, 48), false)
	else:
		# A single generic document silhouette within the fixed 48x48 aperture.
		_outline(Rect2(69, 21, 38, 44), structure)
		draw_rect(Rect2(77, 33, 22, 2), structure)
		draw_rect(Rect2(77, 41, 22, 2), structure)
	if is_pressed():
		draw_rect(Rect2(8, 8, 160, 2), ink)
		draw_rect(Rect2(8, 8, 2, 160), ink)
	elif is_hovered():
		draw_rect(Rect2(12, 168, 152, 2), structure)
	if has_focus():
		_outline(Rect2(1, 1, 174, 174), ink)
		_outline(Rect2(5, 5, 166, 166), get_theme_color("focus", "Desktop"))
