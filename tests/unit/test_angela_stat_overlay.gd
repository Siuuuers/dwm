extends GutTest

const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")

var _viewport: SubViewport
var _main: Control
var _desktop: Control
var _panel: Control
var _art: Control
var _split: Container

func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_main = MAIN.instantiate()
	assert_true(_main.bind_view_preferences(null))
	# Preserve the existing plain-Control injection seam. This suite owns only
	# host/art/divider behavior; connected rendering mounts the real Desktop.
	_desktop = Control.new()
	_desktop.theme = DESKTOP_THEME.build("en", 100)
	_main._computer_desktop_instance = _desktop
	_main.get_node("%ComputerPanel").add_child(_desktop)
	_viewport.add_child(_main)
	_panel = _main.get_node("%AngelaPanel")
	_art = _main.get_node("%AngelaImage")
	_split = _main.get_node("RootHBox")
	await _settle()

func _settle() -> void:
	for _frame: int in range(6): await get_tree().process_frame

func _assert_handle_theme(expected: Theme) -> void:
	var handle: Control = _split.get_node("SplitDragHandle")
	assert_same(_split.theme, expected)
	assert_eq(handle.separator_color, expected.get_color("font_color", "Label"))
	assert_eq(handle.grip_color, expected.get_color("face", "Desktop"))
	assert_eq(handle.focus_color, expected.get_color("focus", "Desktop"))
	assert_false(handle.accessibility_name.is_empty())
	assert_false(handle.accessibility_description.is_empty())

func test_portrait_fills_panel_with_no_stat_hud_at_both_widths() -> void:
	for width: int in [480, 320]:
		_split.set_angela_width(width)
		await _settle()
		assert_null(_main.find_child("StatHud", true, false), "HUD is absent, not hidden")
		assert_eq(_art.get_global_rect(), _panel.get_global_rect())
		assert_gt(_art.get_child_count(), 0, "actual shipped artwork is mounted")
		for layer: Control in _art.get_children():
			assert_eq(layer.get_global_rect(), _art.get_global_rect())
			assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_initial_mounted_desktop_theme_supplies_actual_handle_colors() -> void:
	_assert_handle_theme(_desktop.theme)

func test_live_theme_changes_refresh_handle_without_resize_or_recursive_reassignment() -> void:
	var initial_width: float = _split.get_angela_width()
	var changes: Array[float] = []
	_split.width_committed.connect(func(width: float): changes.append(width))
	var variants: Array[Theme] = [
		DESKTOP_THEME.build("zh-HK", 150),
		DESKTOP_THEME.build("en", 100, &"after_hours", WEEK_TINT.tint_for_day(7)),
		DESKTOP_THEME.build("en", 100, &"midnight", 0.0, true),
		DESKTOP_THEME.build("en", 125, &"after_hours", 0.0, false, "standard", "readable"),
	]
	for variant: Theme in variants:
		_desktop.theme = variant
		await _settle()
		_assert_handle_theme(variant)
		assert_eq(_split.get_angela_width(), initial_width)
		assert_true(changes.is_empty(), "theme propagation cannot save panel width")
		# Refreshing an unchanged theme must settle on the same resource even
		# when ancestor assignment triggers inherited theme notifications.
		_main._refresh_split_presentation()
		await _settle()
		assert_same(_desktop.theme, variant)
		_assert_handle_theme(variant)

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_viewport.push_input(event, true)


func _touch(point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	_viewport.push_input(event, true)


func test_mouse_and_touch_divider_keep_focus_and_commit_once_after_release() -> void:
	var focus := Button.new()
	focus.size = Vector2(100, 50)
	_main.get_node("%ComputerPanel").add_child(focus)
	focus.grab_focus()
	var changes: Array[float] = []
	_split.split_changed.connect(func(width: float): changes.append(width))
	var initial_art := _art.get_global_rect()
	_mouse(Vector2(472, 360), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(312, 360)
	motion.global_position = motion.position
	motion.relative = Vector2(-160, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(motion, true)
	await _settle()
	assert_eq(_art.get_global_rect(), initial_art)
	assert_true(changes.is_empty())
	_mouse(motion.position, false)
	await _settle()
	assert_eq(changes, [320.0])
	assert_eq(_art.size.x, 320.0)
	assert_same(_viewport.gui_get_focus_owner(), focus)
	_touch(Vector2(312, 360), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(472, 360)
	drag.relative = Vector2(160, 0)
	_viewport.push_input(drag, true)
	await _settle()
	assert_eq(_art.size.x, 320.0, "portrait remains stable during touch preview")
	_touch(drag.position, false, true)
	await _settle()
	assert_eq(changes, [320.0], "cancelled touch cannot commit")
	_touch(Vector2(312, 360), true)
	_viewport.push_input(drag, true)
	_touch(drag.position, false)
	await _settle()
	assert_eq(changes, [320.0, 480.0])
	assert_eq(_art.get_global_rect(), initial_art)
	assert_same(_viewport.gui_get_focus_owner(), focus)
