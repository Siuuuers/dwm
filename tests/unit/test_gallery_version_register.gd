extends GutTest

const REGISTER := preload("res://scripts/ui/gallery/GalleryVersionRegister.gd")
const ROW := preload("res://scripts/ui/gallery/GalleryRecordButton.gd")
const THEME := preload("res://scripts/ui/gallery/GalleryTheme.gd")
const PAPER := preload("res://scripts/ui/gallery/GalleryRecordPaper.gd")
var _surface: SubViewport
var _register: Control

func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 960)
	_surface.handle_input_locally = true
	add_child(_surface)
	_register = REGISTER.new()
	_register.theme = THEME.build("en", 100, &"after_hours")
	_surface.add_child(_register)

func after_each() -> void:
	_surface.free()

func _entries() -> Array[Dictionary]:
	# TEST-only noncanonical cues and identifiers; no production metadata is registered.
	return [{"signature_id": "fixture-first", "cue": "TEST first cue"},
		{"signature_id": "fixture-second", "cue": "TEST second cue"}]

func _settle() -> void:
	for frame: int in range(3): await get_tree().process_frame

func _key(code: int) -> void:
	for held: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = held
		_surface.push_input(event, true)
		await _settle()

func test_plural_geometry_and_single_version_absence() -> void:
	_register.set_versions(_entries(), "fixture-first", "en")
	await _settle()
	var rows: Array[Control] = _register.get_rows()
	var heading: Label = _register.get_node("VersionHeading")
	assert_true(_register.visible)
	assert_eq(_register.size.x, 520.0)
	assert_eq(heading.position, Vector2(24, 0))
	assert_eq(heading.size.x, 464.0)
	assert_eq(rows[0].position, Vector2(8, heading.size.y + 8))
	assert_eq(rows[0].size.x, 504.0)
	assert_eq(rows[0].caption.position, Vector2(16, 8))
	assert_eq(rows[0].caption.size.x, 464.0)
	assert_eq(rows[0].size.y, 16.0 + maxf(64.0, rows[0].caption.size.y))
	assert_eq(rows[1].position.y, rows[0].position.y + rows[0].size.y + 8)
	assert_eq(_register.size.y, rows[1].position.y + rows[1].size.y + 8)
	assert_true(rows[0].selected)
	assert_false(rows[1].selected)
	var one: Array[Dictionary] = [_entries()[0]]
	_register.set_versions(one, "fixture-first", "en")
	assert_false(_register.visible)
	assert_eq(_register.size, Vector2.ZERO)
	assert_eq(_register.custom_minimum_size, Vector2.ZERO)
	assert_eq(_register.get_rows().size(), 0)
	assert_null(_register.get_node_or_null("VersionHeading"))
	_register.set_versions([], "", "en")
	assert_eq(_register.size, Vector2.ZERO)
	assert_null(_register.row_for_signature("fixture-first"))

func test_exact_rows_and_focus_survive_reorder_locale_and_selection_reprojection() -> void:
	_register.set_versions(_entries(), "fixture-first", "en")
	await _settle()
	var second: Control = _register.row_for_signature("fixture-second")
	second.grab_focus()
	var reordered := _entries()
	reordered.reverse()
	reordered[0].cue = "TEST 第二提示"
	_register.set_versions(reordered, "fixture-second", "zh_HK")
	await _settle()
	assert_same(_register.get_rows()[0], second)
	assert_true(second.has_focus())
	assert_eq(_register.focused_signature_id(), "fixture-second")
	assert_eq(second.text, "TEST 第二提示")
	assert_eq(second.language, "zh-HK")
	assert_eq(_register.get_node("VersionHeading").text, "其他見證版本")
	assert_true(second.selected)
	var detached: Array[Control] = _register.get_rows()
	detached.clear()
	assert_eq(_register.get_rows().size(), 2)

func test_navigation_clamps_and_emits_selection_before_focus_without_owning_replay() -> void:
	_register.set_versions(_entries(), "fixture-first", "en")
	await _settle()
	var events: Array = []
	_register.item_selected.connect(func(index: int): events.append(index))
	_register.row_focused.connect(func(row: Control): events.append(row))
	var rows: Array[Control] = _register.get_rows()
	rows[0].grab_focus()
	assert_eq(events, [0, rows[0]])
	await _key(KEY_UP)
	assert_true(rows[0].has_focus())
	await _key(KEY_DOWN)
	assert_true(rows[1].has_focus())
	assert_eq(events, [0, rows[0], 1, rows[1]])
	await _key(KEY_DOWN)
	assert_true(rows[1].has_focus())
	await _key(KEY_ENTER)
	assert_eq(events, [0, rows[0], 1, rows[1], 1])
	_register.set_interactive(false)
	for row: Control in rows:
		assert_true(row.disabled)
		assert_eq(row.focus_mode, Control.FOCUS_NONE)
	rows[0].pressed.emit()
	assert_eq(events.size(), 5)
	_register.set_interactive(true)
	assert_false(rows[0].disabled)
	assert_eq(rows[0].focus_mode, Control.FOCUS_ALL)

func test_removed_focused_row_notifies_owner_once_and_does_not_choose_another() -> void:
	_register.set_versions(_entries(), "fixture-second", "en")
	await _settle()
	_register.row_for_signature("fixture-second").grab_focus(true)
	var removed: Array = []
	_register.focused_row_removed.connect(func(hidden: bool): removed.append(hidden))
	_register.set_versions([], "", "en")
	assert_eq(removed, [true])
	assert_eq(_register.focused_signature_id(), "")
	_register.set_versions([], "", "en")
	assert_eq(removed.size(), 1)

func test_wrapped_theme_relayout_preserves_rows_and_guards_reentrant_layout() -> void:
	var entries := _entries()
	entries[0].cue = "TEST noncanonical long cue ".repeat(18)
	_register.set_versions(entries, "fixture-first", "en")
	await _settle()
	var first: Control = _register.get_rows()[0]
	var height: float = _register.size.y
	var layouts: Array = []
	_register.layout_changed.connect(func():
		layouts.append(true)
		_register.refresh_layout())
	_register.theme = THEME.build("en", 150, &"after_hours")
	await _settle()
	assert_same(_register.get_rows()[0], first)
	assert_gt(_register.size.y, height)
	assert_gt(first.size.y, 80.0)
	assert_gt(layouts.size(), 0)
	assert_lt(layouts.size(), 5, "Theme refresh must settle instead of scheduling an endless layout loop")
	assert_eq(first.caption.get_theme_color("font_color"), _register.get_theme_color("paper_ink", "Gallery"))
	var index = ROW.new()
	_surface.add_child(index)
	index.text = "TEST index"
	index.refresh_caption()
	assert_false(index.paper_context)
	assert_eq(index.caption.size.x, 264.0)
	assert_eq(index.custom_minimum_size.x, 296.0)

func test_oversized_cue_reveal_and_relayout_keep_visible_interior_and_focus_stable() -> void:
	var paper := PAPER.new()
	paper.theme = THEME.build("en", 100, &"after_hours")
	_surface.add_child(paper)
	paper.set_copy("TEST record", "TEST noncanonical sentence", "en")
	paper.set_actions(null, null, _register)
	var entries := _entries()
	entries[0].cue = "TEST noncanonical oversized cue ".repeat(100)
	_register.set_versions(entries, "fixture-first", "en")
	await _settle()
	var first: Control = _register.row_for_signature("fixture-first")
	assert_gt(first.size.y, PAPER.VIEW_SIZE.y * 2.0,
		"Fixture must exceed the viewport; a full-perimeter fit is impossible")
	first.grab_focus()
	paper.scroll_to(0)
	paper.reveal_control(first)
	var revealed_offset: float = paper.scroll_offset
	assert_gt(revealed_offset, 0.0)
	paper.reveal_control(first)
	assert_eq(paper.scroll_offset, revealed_offset, "Repeated reveal must not alternate row edges")
	var row_top: float = _register.position.y + first.position.y
	var interior: float = row_top + (first.size.y - PAPER.VIEW_SIZE.y) / 2.0
	paper.scroll_to(interior)
	var interior_offset: float = paper.scroll_offset
	assert_gt(interior_offset, revealed_offset)
	paper.refresh_layout()
	assert_eq(paper.scroll_offset, interior_offset, "Relayout preserves an already visible interior")
	paper.refresh_layout()
	assert_eq(paper.scroll_offset, interior_offset)
	assert_true(first.has_focus())
	assert_eq(_register.focused_signature_id(), "fixture-first")
