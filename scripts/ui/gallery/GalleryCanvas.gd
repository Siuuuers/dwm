extends Control
## Paint-only material, unavailable leaf, and inert overflow witness.

var unavailable_record := false
var unavailable_height := 0.0
var index_extent := 0.0
var index_offset := 0.0

func _draw() -> void:
	if not has_theme_color("habitat", "Gallery"): return
	draw_rect(Rect2(0, 0, 960, 656), get_theme_color("habitat", "Gallery"))
	draw_rect(Rect2(16, 16, 344, 624), get_theme_color("face", "Gallery"))
	draw_rect(Rect2(376, 16, 568, 544), get_theme_color("paper", "Gallery"))
	draw_rect(Rect2(376, 560, 568, 80), get_theme_color("face", "Gallery"))
	if unavailable_record:
		var ink := get_theme_color("paper_ink", "Gallery")
		for x: int in range(0, 520, 8):
			draw_rect(Rect2(392 + x, 32, mini(4, 520 - x), 2), ink)
			draw_rect(Rect2(392 + x, 32 + unavailable_height - 2, mini(4, 520 - x), 2), ink)
		for y: int in range(0, int(unavailable_height), 8):
			draw_rect(Rect2(392, 32 + y, 2, minf(4, unavailable_height - y)), ink)
			draw_rect(Rect2(910, 32 + y, 2, minf(4, unavailable_height - y)), ink)
		for y: int in range(0, int(unavailable_height) - 4, 8):
			draw_rect(Rect2(894, 34 + y, 16, 2), ink)
	if index_extent > 592:
		# Compute on the native master, then display every value at exact 2:1.
		var extent := index_extent / 2
		var thumb := maxf(8, floorf(296 * 296 / extent))
		var offset := floorf((296 - thumb) * (index_offset / 2) / (extent - 296))
		var ink := get_theme_color("ink", "Gallery")
		draw_rect(Rect2(352, 32, 2, 592), ink)
		draw_rect(Rect2(350, 32 + offset * 2, 6, thumb * 2), ink)
