extends "res://addons/gut/test.gd"

const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")

func _dock() -> Control:
	var dock: Control = DOCK.new()
	add_child_autofree(dock)
	assert_true(dock.configure())
	return dock

func test_desktop_actions_fit_without_a_separate_reveal_button() -> void:
	var dock := _dock()
	assert_eq(dock.size.x,800.0)
	assert_false(dock.buttons.has("reveal"))
	for action: String in ["flag","drag","board","new_board","assignments","rules"]:
		assert_true(dock.buttons.has(action))
	for button: Button in dock.buttons.values():
		assert_true(Rect2(Vector2.ZERO,dock.size).encloses(Rect2(button.position,button.size)))
		assert_true(button.disabled)

func test_mode_selection_waits_for_owner_and_disabled_new_board_is_inert() -> void:
	var dock := _dock()
	watch_signals(dock)
	assert_true(dock.present(&"reveal",["reveal","flag","drag","assignments","rules"]))
	assert_false(dock.buttons.flag.button_pressed)
	assert_string_contains(dock.buttons.flag.accessibility_name,"Reveal")
	dock.buttons.flag.pressed.emit()
	assert_signal_emitted_with_parameters(dock,"action_requested",[&"flag"])
	assert_eq(dock.mode,&"reveal")
	assert_false(dock.buttons.flag.selected)
	dock.buttons.new_board.pressed.emit()
	assert_signal_emit_count(dock,"action_requested",1)
	assert_eq(dock.buttons.new_board.focus_mode,Control.FOCUS_NONE)
	assert_true(dock.present(&"flag",["reveal","flag","drag"]))
	assert_true(dock.buttons.flag.selected)
	assert_true(dock.buttons.flag.button_pressed)
	assert_string_contains(dock.buttons.flag.accessibility_name,"Flag")
	dock.buttons.flag.pressed.emit()
	assert_signal_emitted_with_parameters(dock,"action_requested",[&"reveal"])
	assert_eq(dock.mode,&"flag","The UI requests a toggle; the owning panel commits its mode.")
	assert_true(dock.present(&"drag",["reveal","flag","drag"]))
	dock.buttons.flag.pressed.emit()
	assert_signal_emitted_with_parameters(dock,"action_requested",[&"flag"])

func test_host_locale_scale_targets_keep_accessible_actions_inside_dock() -> void:
	var dock := _dock()
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				assert_true(dock.configure("canonical_solo",locale,percent,large,&"midnight"))
				assert_false(dock.buttons.has("reveal"))
				for action: String in ["flag","drag","board","rules","pause"]:
					assert_true(dock.buttons.has(action))
				assert_eq(dock.size.x,960.0)
				for button: Button in dock.buttons.values():
					assert_eq(button.theme.default_font_size,20*percent/100)
					assert_gte(button.size.y,64.0 if large else 48.0)
					assert_true(Rect2(Vector2.ZERO,dock.size).encloses(Rect2(button.position,button.size)))

func test_custody_and_invalid_updates_preserve_selection_without_command() -> void:
	var dock := _dock()
	assert_true(dock.present(&"drag",["reveal","flag","drag"],true))
	assert_true(dock.buttons.drag.selected)
	for button: Button in dock.buttons.values(): assert_true(button.disabled)
	assert_false(dock.present(&"reveal",["leave"]))
	assert_false(dock.present(&"reveal",["rules","rules"]))
	assert_false(dock.present(&"guess",[]))
	assert_eq(dock.mode,&"drag")
