extends "res://addons/gut/test.gd"

const LAYOUT := preload("res://scripts/ui/minesweeper/MinesweeperWorksheetLayout.gd")

func test_accepted_baseline_mounts_origins_and_conditional_axes() -> void:
	for sample: Array in [
		[8,false,Vector2i(400,246),Vector2i(194,194),Vector2i(91,14),false,false],
		[16,false,Vector2i(400,246),Vector2i(386,386),Vector2i.ZERO,true,true],
		[22,false,Vector2i(400,246),Vector2i(530,530),Vector2i.ZERO,true,true],
		[18,false,Vector2i(480,246),Vector2i(434,434),Vector2i(11,0),false,true],
		[8,true,Vector2i(400,232),Vector2i(258,258),Vector2i(55,0),false,true],
		[16,true,Vector2i(400,232),Vector2i(514,514),Vector2i.ZERO,true,true],
		[22,true,Vector2i(400,232),Vector2i(706,706),Vector2i.ZERO,true,true],
		[18,true,Vector2i(480,232),Vector2i(578,578),Vector2i.ZERO,true,true],
	]:
		var result := LAYOUT.measure(sample[0],sample[0],sample[2],sample[1])
		assert_true(result.ok)
		assert_eq(result.value.mount.size,sample[3])
		assert_eq(result.value.mount.position,sample[4])
		assert_eq(result.value.horizontal != null,sample[5])
		assert_eq(result.value.vertical != null,sample[6])

func test_scroll_clamps_before_thumb_derivation_and_corner_is_separate() -> void:
	var result: Dictionary = LAYOUT.measure(22,22,Vector2i(400,246),false,Vector2i(9999,-20)).value
	assert_eq(result.scroll,Vector2i(154,0))
	assert_eq(result.mount.position,Vector2i(-154,0))
	assert_eq(result.horizontal.thumb.end.x,result.well.end.x)
	assert_eq(result.vertical.thumb.position.y,0)
	assert_false(result.horizontal.rect.intersects(result.corner))
	assert_false(result.vertical.rect.intersects(result.corner))
	assert_eq(result.horizontal.thumb.size.x,maxi(24,floori(376.0*376/530)))

func test_focus_correction_reveals_full_cell_without_fractional_motion() -> void:
	var last: Dictionary = LAYOUT.reveal_cell(22,22,483,Vector2i(400,246),false,Vector2i.ZERO).value
	var cell := Rect2i(last.mount.position+Vector2i(21,21)*24+Vector2i.ONE,Vector2i(24,24))
	assert_true(last.well.encloses(cell))
	var first: Dictionary = LAYOUT.reveal_cell(22,22,0,Vector2i(400,246),false,last.scroll).value
	assert_true(first.well.encloses(Rect2i(first.mount.position+Vector2i.ONE,Vector2i(24,24))))
	var retained: Dictionary = LAYOUT.reveal_cell(22,22,0,Vector2i(400,246),false,first.scroll).value
	assert_eq(first,retained,"Repeated correction does not drift.")

func test_invalid_geometry_never_creates_a_partial_layout() -> void:
	assert_false(LAYOUT.measure(0,8,Vector2i(400,246)).ok)
	assert_false(LAYOUT.measure(8,8,Vector2i(24,246)).ok)
	assert_false(LAYOUT.measure(8,8,Vector2i(25,246)).ok,"A viewport must fit one full cell target.")
	assert_false(LAYOUT.reveal_cell(8,8,64,Vector2i(400,246),false,Vector2i.ZERO).ok)
