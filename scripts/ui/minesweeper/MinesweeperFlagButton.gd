extends "res://scripts/ui/minesweeper/MinesweeperActionButton.gd"
## Vector flag avoids missing symbol glyphs; pressed state belongs to the published mode.

func _init() -> void:
	super._init()
	toggle_mode = true

func configure(copy: String, next_theme: Theme, large: bool, width_logical: int = 80) -> bool:
	if not super.configure(copy, next_theme, large, width_logical): return false
	# Only the vector is drawn; the accessible label must not reserve wrapped text height.
	custom_minimum_size.y = 64 if large else 48
	update_minimum_size()
	size = custom_minimum_size
	return true

func present_state(enabled: bool, next_selected: bool) -> void:
	super.present_state(enabled, next_selected)
	set_pressed_no_signal(next_selected)

func _draw_copy(ink: Color) -> void:
	var origin := Vector2(floorf(size.x / 2.0) - 10, floorf(size.y / 2.0) - 12)
	var flag := PackedVector2Array([origin, origin + Vector2(22, 0), origin + Vector2(16, 8), origin + Vector2(22, 16), origin + Vector2(0, 16)])
	if selected:
		draw_colored_polygon(flag, ink)
	else:
		flag.append(origin)
		draw_polyline(flag, ink, 2.0, true)
	draw_line(origin, origin + Vector2(0, 27), ink, 2.0, true)
	draw_line(origin + Vector2(-5, 27), origin + Vector2(6, 27), ink, 2.0, true)
