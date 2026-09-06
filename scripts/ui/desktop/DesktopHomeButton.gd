extends Button
## Operational Home pictogram, independent of locale font coverage.
var return_arrow := false
var current_on_launcher := true:
	set(value):
		current_on_launcher = value
		queue_redraw()

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)

func _draw() -> void:
	if not has_theme_color("face", "Desktop"):
		return
	var ink := get_theme_color("face" if current_on_launcher else "ink", "Desktop")
	draw_rect(Rect2(0, 0, 64, 64), get_theme_color("current" if current_on_launcher else "face", "Desktop"))
	# Pixel steps preserve the frame's native 2:1 grid.
	if return_arrow:
		draw_rect(Rect2(20, 30, 26, 4), ink)
		for step in 6:
			draw_rect(Rect2(20 + step * 2, 28 - step * 2, 2, 2), ink)
			draw_rect(Rect2(20 + step * 2, 34 + step * 2, 2, 2), ink)
	else:
		for step in 6:
			draw_rect(Rect2(18 + step * 2, 28 - step * 2, 2, 2), ink)
			draw_rect(Rect2(42 - step * 2, 28 - step * 2, 2, 2), ink)
		draw_rect(Rect2(22, 28, 2, 16), ink)
		draw_rect(Rect2(40, 28, 2, 16), ink)
		draw_rect(Rect2(22, 42, 20, 2), ink)
	if disabled:
		draw_rect(Rect2(18, 50, 28, 2), ink)
	elif is_pressed():
		draw_rect(Rect2(8, 8, 48, 2), ink)
		draw_rect(Rect2(8, 8, 2, 48), ink)
	elif is_hovered():
		draw_rect(Rect2(12, 56, 40, 2), get_theme_color("structure", "Desktop"))
	if has_focus():
		draw_rect(Rect2(1, 1, 62, 62), ink, false, 2)
		draw_rect(Rect2(5, 5, 54, 54), get_theme_color("focus", "Desktop"), false, 2)
