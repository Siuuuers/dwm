extends "res://addons/gut/test.gd"

const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")

func _dock() -> Control:
	var dock: Control = DOCK.new()
	add_child_autofree(dock)
	assert_true(dock.configure())
	return dock

func test_exact_desktop_allocations_leave_vacancy_without_control() -> void:
	var dock := _dock()
	assert_eq(dock.size,Vector2(800,72))
	assert_eq(dock.buttons.keys(),["reveal","flag","drag","new_board","assignments","rules"])
	var x: Array = [8,112,200,392,528,696]
	var width: Array = [96,80,80,128,160,96]
	for index in 6:
		var button: Button = dock.buttons.values()[index]
		assert_eq(button.position,Vector2(x[index],12))
		assert_eq(button.size,Vector2(width[index],48))
		assert_true(button.disabled)

func test_mode_selection_waits_for_owner_and_disabled_new_board_is_inert() -> void:
	var dock := _dock()
	watch_signals(dock)
	assert_true(dock.present(&"reveal",["reveal","flag","drag","assignments","rules"]))
	dock.buttons.flag.pressed.emit()
	assert_signal_emitted_with_parameters(dock,"action_requested",[&"flag"])
	assert_eq(dock.mode,&"reveal")
	assert_true(dock.buttons.reveal.selected)
	dock.buttons.new_board.pressed.emit()
	assert_signal_emit_count(dock,"action_requested",1)
	assert_eq(dock.buttons.new_board.focus_mode,Control.FOCUS_NONE)
	assert_true(dock.present(&"flag",["reveal","flag","drag"]))
	assert_true(dock.buttons.flag.selected)
	assert_false(dock.buttons.reveal.selected)

func test_host_locale_scale_targets_keep_fixed_widths_and_grow_only_height() -> void:
	var dock := _dock()
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				assert_true(dock.configure("canonical_solo",locale,percent,large,&"midnight"))
				assert_eq(dock.buttons.keys(),["reveal","flag","drag","rules","pause"])
				assert_eq(dock.size.x,960.0)
				assert_eq(dock.buttons.rules.position.x,752.0)
				assert_eq(dock.buttons.pause.position.x,856.0)
				for button: Button in dock.buttons.values():
					assert_eq(button.theme.default_font_size,20*percent/100)
					assert_gte(button.size.y,64.0 if large else 48.0)
					assert_eq(button.size.y,dock.buttons.reveal.size.y)

func test_custody_and_invalid_updates_preserve_selection_without_command() -> void:
	var dock := _dock()
	assert_true(dock.present(&"drag",["reveal","flag","drag"],true))
	assert_true(dock.buttons.drag.selected)
	for button: Button in dock.buttons.values(): assert_true(button.disabled)
	assert_false(dock.present(&"reveal",["leave"]))
	assert_false(dock.present(&"reveal",["rules","rules"]))
	assert_false(dock.present(&"guess",[]))
	assert_eq(dock.mode,&"drag")
