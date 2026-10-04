extends "res://addons/gut/test.gd"

const LAYOUT := preload("res://scripts/ui/minesweeper/MinesweeperWorksheetLayout.gd")
const BANDS := [Vector2i(400, 246), Vector2i(480, 232), Vector2i(320, 180), Vector2i(120, 80)]


func test_all_manual_cell_sizes_preserve_scaled_grid_and_bounded_pan() -> void:
	for band: Vector2i in BANDS:
		for large: bool in [false, true]:
			var source_target := 32 if large else 24
			var gutter := 24 if large else 12
			for logical_size in range(10, 61, 2):
				var result: Dictionary = LAYOUT.measure_view(22, 22, band, large, logical_size, false, Vector2i(9999, -9999))
				assert_true(result.ok, str([band, large, logical_size]))
				var view: Dictionary = result.value
				var expected_scale := float(logical_size) / (source_target * 2.0)
				var expected_mount := Vector2(22 * source_target + 2, 22 * source_target + 2) * expected_scale
				assert_true(view.mount.size.distance_to(expected_mount) < 0.001, str([band, large, logical_size]))
				assert_true(absf(view.scale - expected_scale) < 0.0001)
				assert_true(absf(view.target * 2.0 - logical_size) < 0.0001)
				assert_eq(view.well.size, band - Vector2i.ONE * gutter)
				assert_eq(view.scroll.x, view.maximum_scroll.x)
				assert_eq(view.scroll.y, 0)
				assert_eq(view.horizontal != null, view.maximum_scroll.x > 0)
				assert_eq(view.vertical != null, view.maximum_scroll.y > 0)
				assert_eq(view.corner, Rect2i(view.well.end, Vector2i.ONE * gutter))
				var reset: Dictionary = LAYOUT.measure_view(22, 22, band, large, logical_size, false, Vector2i(-9999, 9999)).value
				assert_eq(reset.scroll.x, 0)
				assert_eq(reset.scroll.y, reset.maximum_scroll.y)
				for axis in 2:
					if view.maximum_scroll[axis] == 0:
						assert_true(absf(view.mount.position[axis] - (view.well.size[axis] - view.mount.size[axis]) / 2.0) < 0.001)
					else:
						assert_true(absf(view.mount.position[axis] + view.scroll[axis]) < 0.001)


func test_manual_focus_reveals_entire_cell_at_pan_extremes() -> void:
	for band: Vector2i in BANDS:
		for large: bool in [false, true]:
			var source_target := 32 if large else 24
			for logical_size in range(10, 61, 2):
				var last_result: Dictionary = LAYOUT.reveal_view(22, 22, 483, band, large, logical_size, false, Vector2i.ZERO)
				assert_true(last_result.ok, str([band, large, logical_size]))
				var last: Dictionary = last_result.value
				assert_true(_well_contains_cell(last, 21, 21, source_target), str([band, large, logical_size, "last"]))
				var first: Dictionary = LAYOUT.reveal_view(22, 22, 0, band, large, logical_size, false, last.scroll).value
				assert_true(_well_contains_cell(first, 0, 0, source_target), str([band, large, logical_size, "first"]))
				assert_eq(LAYOUT.reveal_view(22, 22, 0, band, large, logical_size, false, first.scroll).value, first)


func test_fit_shows_whole_board_without_rails_and_caps_cell_at_sixty_logical() -> void:
	for band: Vector2i in BANDS:
		for large: bool in [false, true]:
			for board_size in [8, 16, 18, 22]:
				var result: Dictionary = LAYOUT.measure_view(board_size, board_size, band, large, 36, true, Vector2i(9999, 9999))
				assert_true(result.ok, str([band, large, board_size]))
				var view: Dictionary = result.value
				assert_true(_well_rect(view).encloses(view.mount), str([band, large, board_size]))
				assert_true(view.target * 2.0 <= 60.001)
				assert_eq(view.scroll, Vector2i.ZERO)
				assert_eq(view.maximum_scroll, Vector2i.ZERO)
				assert_null(view.horizontal)
				assert_null(view.vertical)
				assert_true(absf(view.mount.get_center().x - band.x / 2.0) < 0.001)
				assert_true(absf(view.mount.get_center().y - band.y / 2.0) < 0.001)
	var large_board: Dictionary = LAYOUT.measure_view(22, 22, Vector2i(120, 80), false, 36, true).value
	assert_lt(large_board.target * 2.0, 10.0, "Fit may go below the manual minimum.")
	var small_board: Dictionary = LAYOUT.measure_view(8, 8, Vector2i(400, 246), false, 36, true).value
	assert_true(absf(small_board.target * 2.0 - 60.0) < 0.001)


func test_zoom_anchor_preserves_board_point_except_where_clamped() -> void:
	var band := Vector2i(400, 246)
	var before: Dictionary = LAYOUT.measure_view(22, 22, band, false, 50, false, Vector2i(80, 100)).value
	var after_zero: Dictionary = LAYOUT.measure_view(22, 22, band, false, 52, false).value
	var anchor := Vector2(150, 100)
	var board_point: Vector2 = (anchor - before.mount.position) / before.scale
	var next_scroll: Vector2i = LAYOUT.anchored_scroll(before, after_zero, anchor)
	var after: Dictionary = LAYOUT.measure_view(22, 22, band, false, 52, false, next_scroll).value
	assert_true(next_scroll.x > 0 and next_scroll.x < after.maximum_scroll.x)
	assert_true(next_scroll.y > 0 and next_scroll.y < after.maximum_scroll.y)
	assert_true((after.mount.position + board_point * after.scale).distance_to(anchor) <= 0.71)
	var clamped: Vector2i = LAYOUT.anchored_scroll(before, after_zero, Vector2(9999, 9999))
	assert_true(clamped.x >= 0 and clamped.x <= after.maximum_scroll.x)
	assert_true(clamped.y >= 0 and clamped.y <= after.maximum_scroll.y)


func test_invalid_manual_sizes_and_cells_do_not_create_view() -> void:
	for invalid in [9, 11, 61]:
		assert_false(LAYOUT.measure_view(8, 8, Vector2i(400, 246), false, invalid, false).ok)
	assert_false(LAYOUT.measure_view(0, 8, Vector2i(400, 246), false, 36, false).ok)
	assert_false(LAYOUT.measure_view(8, 8, Vector2i(32, 32), true, 36, false).ok)
	assert_false(LAYOUT.measure_view(8, 8, Vector2i(40, 40), true, 10, false).ok,
		"A manual well must leave room for a complete rail thumb.")
	assert_false(LAYOUT.measure_view(8, 8, Vector2i(48, 48), true, 10, false).ok,
		"A thumb needs positive travel when the board overflows.")
	assert_false(LAYOUT.reveal_view(8, 8, 64, Vector2i(400, 246), false, 36, false, Vector2i.ZERO).ok)


func _well_rect(view: Dictionary) -> Rect2:
	return Rect2(Vector2(view.well.position), Vector2(view.well.size))


func _well_contains_cell(view: Dictionary, column: int, row: int, source_target: int) -> bool:
	var source_position := Vector2(1 + column * source_target, 1 + row * source_target)
	var position: Vector2 = view.mount.position + source_position * view.scale
	var extent: Vector2 = Vector2.ONE * source_target * view.scale
	return _well_rect(view).encloses(Rect2(position, extent))
