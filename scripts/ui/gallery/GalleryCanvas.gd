extends Control
## Paint-only material, unavailable leaf, and inert overflow witness.

var unavailable_record := false
var replay_start_failed := false
var replay_unavailable := false
var unavailable_height := 0.0
var unavailable_top := 32.0
var index_extent := 0.0
var index_offset := 0.0
var paper_extent := 0.0
var paper_offset := 0.0
var paper_focus := false

func _draw() -> void:
	if not has_theme_color("habitat", "Gallery"): return
	draw_rect(Rect2(0, 0, 960, 656), get_theme_color("habitat", "Gallery"))
	draw_rect(Rect2(16, 16, 344, 624), get_theme_color("face", "Gallery"))
	draw_rect(Rect2(376, 16, 568, 544), get_theme_color("paper", "Gallery"))
	draw_rect(Rect2(376, 560, 568, 80), get_theme_color("face", "Gallery"))
	if replay_start_failed:
		draw_rect(Rect2(392, 576, 2, 48), get_theme_color("error_rule", "Gallery"))
	elif replay_unavailable:
		draw_rect(Rect2(392, 576, 2, 48), get_theme_color("information_rule", "Gallery"))
	if unavailable_record:
		var ink := get_theme_color("paper_ink", "Gallery")
		for x: int in range(0, 520, 8):
			draw_rect(Rect2(392 + x, unavailable_top, mini(4, 520 - x), 2), ink)
			draw_rect(Rect2(392 + x, unavailable_top + unavailable_height - 2, mini(4, 520 - x), 2), ink)
		for y: int in range(0, int(unavailable_height), 8):
			draw_rect(Rect2(392, unavailable_top + y, 2, minf(4, unavailable_height - y)), ink)
			draw_rect(Rect2(910, unavailable_top + y, 2, minf(4, unavailable_height - y)), ink)
		for y: int in range(0, int(unavailable_height) - 4, 8):
			draw_rect(Rect2(894, unavailable_top + 2 + y, 16, 2), ink)
	if index_extent > 592:
		# Compute on the native master, then display every value at exact 2:1.
		var extent := index_extent / 2
		var thumb := maxf(8, floorf(296 * 296 / extent))
		var offset := floorf((296 - thumb) * (index_offset / 2) / (extent - 296))
		var ink := get_theme_color("ink", "Gallery")
		draw_rect(Rect2(352, 32, 2, 592), ink)
		draw_rect(Rect2(350, 32 + offset * 2, 6, thumb * 2), ink)
	if paper_extent > 512:
		var extent := paper_extent / 2
		var thumb := maxf(8, floorf(256 * 256 / extent))
		var offset := floorf((256 - thumb) * (paper_offset / 2) / (extent - 256))
		var ink := get_theme_color("paper_ink", "Gallery")
		draw_rect(Rect2(936, 32, 2, 512), ink)
		draw_rect(Rect2(934, 32 + offset * 2, 6, thumb * 2), ink)
		if paper_focus:
			draw_rect(Rect2(385, 25, 534, 526), ink, false, 2)
			draw_rect(Rect2(389, 29, 526, 518), get_theme_color("paper_focus", "Gallery"), false, 2)
