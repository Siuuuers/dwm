extends Button

func _draw() -> void:
	if not disabled or not has_theme_color("ink", "Gallery"): return
	var ink := get_theme_color("ink", "Gallery")
	# Open-bottom gate is a disabled action, not a border around the record.
	draw_rect(Rect2(0, 0, size.x, 2), ink)
	draw_rect(Rect2(0, 0, 2, size.y), ink)
	draw_rect(Rect2(size.x - 2, 0, 2, size.y), ink)
