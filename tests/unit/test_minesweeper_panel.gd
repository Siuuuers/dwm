extends GutTest

const INPUT_FIXTURE := preload("res://tests/support/MinesweeperInputFixture.gd")
var _input_fixture: RefCounted


const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const BOARD_QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

class PublicPort extends RefCounted:
	var view: Dictionary = {}
	var next_view: Dictionary = {}
	var calls: Array[Dictionary] = []
	var pull_count := 0
	func pull() -> Dictionary:
		pull_count += 1
		return {"ok":true,"value":view.duplicate(true)}
	func select_difficulty(difficulty: String, revision: int) -> Dictionary:
		calls.append({"difficulty":difficulty,"revision":revision})
		if not next_view.is_empty():
			view = next_view.duplicate(true)
			next_view = {}
		return {"ok":true,"value":view.duplicate(true)}
	func dispatch(action: String, index: int, revision: int) -> Dictionary:
		calls.append({"action":action,"index":index,"revision":revision})
		if not next_view.is_empty():
			view = next_view.duplicate(true)
			next_view = {}
		return {"ok":true,"value":view.duplicate(true)}

func _view(difficulty: String = "beginner") -> Dictionary:
	var board: Dictionary = BOARD_QUERY.desktop(STATE.new().capture(),difficulty,true).value
	return {"board":board,"register":{"difficulty":difficulty,"rounds":2,"mine_estimate":null,
		"foresight":null,"no_flag":"intact","custody":false,"difficulty_enabled":[]},
		"assignments":[true,false,false,false,false,false,false,false,false],
		"actions":["reveal","flag","drag","assignments","rules"],"settled":false}

func _port(difficulty: String = "beginner") -> PublicPort:
	var port := PublicPort.new()
	port.view = _view(difficulty)
	return port

func _settled_view() -> Dictionary:
	var value := _view()
	value.board.terminal = true
	value.board.custody = true
	for cell: Dictionary in value.board.cells:
		cell.bracketed = false
		cell.inspectable = false
		cell.pressable = false
		cell.actions = []
	value.register.custody = true
	value.actions = ["new_board","assignments","rules"]
	value.settled = true
	return value

func _panel(port: PublicPort) -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child_autofree(viewport)
	var panel: Control = PANEL.new()
	viewport.add_child(panel)
	assert_true(_input_fixture.bind_grid(panel.worksheet.grid,viewport))
	assert_true(panel.configure())
	assert_true(panel.bind(port))
	assert_true(panel.refresh())
	return panel

func _key(panel: Control, code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	panel.get_viewport().push_input(event,true)

func test_dock_mode_and_real_f_shortcut_share_selection_without_board_commands() -> void:
	var port := _port()
	var panel := _panel(port)
	panel.dock.buttons.flag.grab_focus()
	_key(panel,KEY_ENTER)
	_key(panel,KEY_ENTER,false)
	assert_eq(panel.worksheet.grid.mode,&"flag")
	assert_true(panel.dock.buttons.flag.selected)
	assert_false(panel.dock.buttons.reveal.selected)
	panel.worksheet.grid.grab_focus()
	_key(panel,KEY_F)
	_key(panel,KEY_F,false)
	assert_eq(panel.worksheet.grid.mode,&"reveal")
	assert_true(panel.dock.buttons.reveal.selected)
	assert_false(panel.dock.buttons.flag.selected)
	panel.dock.buttons.drag.pressed.emit()
	assert_eq(panel.worksheet.grid.mode,&"drag")
	_key(panel,KEY_F)
	_key(panel,KEY_F,false)
	assert_eq(panel.worksheet.grid.mode,&"flag")
	assert_true(panel.dock.buttons.flag.selected)
	assert_true(port.calls.is_empty())

func test_sheet_restores_source_mode_cell_and_scroll_while_dock_stays_inert() -> void:
	var port := _port("expert")
	var panel := _panel(port)
	panel.dock.buttons.flag.pressed.emit()
	panel.worksheet.grid._set_focused(200)
	panel.worksheet.set_scroll(Vector2i(80,140))
	var before: Dictionary = panel.public_view.duplicate(true)
	for action: String in ["rules","assignments"]:
		var source: Button = panel.dock.buttons[action]
		source.grab_focus()
		source.pressed.emit()
		var sheet: Control = panel.worksheet.information_sheet
		assert_not_null(sheet)
		if sheet == null: return
		assert_true(sheet.rows[0].has_focus())
		assert_true(panel.register.visible)
		assert_true(panel.dock.visible)
		assert_false(panel.worksheet.well.visible)
		for button: Button in panel.dock.buttons.values():
			assert_true(button.disabled)
			assert_eq(button.focus_mode,Control.FOCUS_NONE)
		panel.dock.buttons.drag.pressed.emit()
		_key(panel,KEY_F)
		_key(panel,KEY_F,false)
		assert_eq(panel.worksheet.grid.mode,&"flag")
		assert_true(port.calls.is_empty())
		_key(panel,KEY_ESCAPE)
		_key(panel,KEY_ESCAPE,false)
		assert_null(panel.worksheet.information_sheet)
		assert_true(source.has_focus())
		assert_false(source.disabled)
		assert_eq(panel.worksheet.grid.focused_index,200)
		assert_eq(panel.worksheet.get_scroll(),Vector2i.ZERO)
		assert_eq(panel.public_view,before)

func test_invalid_composite_preserves_facts_blocks_input_and_refresh_recovers() -> void:
	var port := _port()
	var panel := _panel(port)
	panel.worksheet.grid.grab_focus()
	var before: Dictionary = panel.public_view.duplicate(true)
	var cell: Control = panel.worksheet.grid.cell_nodes[0]
	var malformed: Dictionary = before.duplicate(true)
	malformed.board.mine_indices = [1]
	watch_signals(panel)
	assert_false(panel.present(malformed))
	assert_eq(panel.public_view,before)
	assert_eq(panel.worksheet.grid.projection,before.board)
	assert_same(panel.worksheet.grid.cell_nodes[0],cell)
	assert_eq(panel.worksheet.grid.focus_mode,Control.FOCUS_NONE)
	for button: Button in panel.dock.buttons.values(): assert_true(button.disabled)
	panel.dock.buttons.flag.pressed.emit()
	_key(panel,KEY_ENTER)
	_key(panel,KEY_ENTER,false)
	assert_true(port.calls.is_empty())
	assert_signal_emitted(panel,"presentation_failed")
	assert_true(panel.refresh())
	assert_false(panel.dock.buttons.flag.disabled)
	assert_eq(panel.worksheet.grid.focus_mode,Control.FOCUS_ALL)
	panel.worksheet.grid.grab_focus()
	_key(panel,KEY_ENTER)
	_key(panel,KEY_ENTER,false)
	assert_eq(port.calls,[{"action":"reveal","index":0,"revision":0}])

func test_same_size_dispatch_refreshes_public_facts_without_replacing_cells() -> void:
	var port := _port()
	var panel := _panel(port)
	var retained: Array = panel.worksheet.grid.cell_nodes.duplicate()
	port.next_view = port.view.duplicate(true)
	port.next_view.board.revision = 1
	port.next_view.board.cells[0].face = "revealed"
	port.next_view.board.cells[0].number = 1
	port.next_view.board.cells[0].actions = []
	port.next_view.board.cells[0].pressable = false
	panel.worksheet.grid.grab_focus()
	_key(panel,KEY_ENTER)
	_key(panel,KEY_ENTER,false)
	assert_eq(port.calls,[{"action":"reveal","index":0,"revision":0}])
	assert_eq(panel.public_view.board.revision,1)
	assert_eq(panel.worksheet.grid.projection.cells[0].number,1)
	for index in retained.size(): assert_same(panel.worksheet.grid.cell_nodes[index],retained[index])

func test_all_locale_scale_and_target_tuples_close_fixed_body_without_shrinking_fonts() -> void:
	var panel := _panel(_port())
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				assert_true(panel.configure(locale,percent,large,&"midnight"),"%s %d large=%s" % [locale,percent,large])
				assert_eq(panel.size,Vector2(800,656))
				assert_eq(panel.worksheet.position,Vector2(0,panel.register.size.y))
				assert_eq(panel.dock.position.y,panel.worksheet.position.y+panel.worksheet.size.y)
				assert_eq(panel.dock.position.y+panel.dock.size.y,panel.size.y)
				assert_gte(panel.worksheet.size.y,128.0 if large else 96.0)
				assert_eq(fmod(panel.worksheet.size.y,2.0),0.0)
				for button: Button in panel.dock.buttons.values():
					assert_eq(button.theme.default_font_size,20*percent/100)
					assert_gte(button.size.y,64.0 if large else 48.0)

func test_replacement_and_difficulty_remain_disabled_and_unpublished_actions_are_rejected() -> void:
	var port := _port()
	var panel := _panel(port)
	assert_true(panel.dock.buttons.new_board.disabled)
	for button: Button in panel.register.difficulties.values():
		assert_true(button.disabled)
		assert_eq(button.focus_mode,Control.FOCUS_NONE)
		button.pressed.emit()
	panel.dock.buttons.new_board.pressed.emit()
	panel.worksheet.grid.grab_focus()
	_key(panel,KEY_SPACE)
	_key(panel,KEY_SPACE,false)
	assert_true(port.calls.is_empty())
	var bad: Dictionary = panel.public_view.duplicate(true)
	bad.actions.append("new_board")
	assert_false(panel.present(bad))
	bad = port.view.duplicate(true)
	bad.register.difficulty_enabled = ["unknown-tier"]
	assert_false(panel.present(bad))
	bad = port.view.duplicate(true)
	bad.actions = ["reveal","drag","assignments","rules"]
	assert_false(panel.present(bad),"A mode subset cannot leave F able to choose an unpublished action.")
	assert_eq(panel.public_view,port.view)
	assert_true(port.calls.is_empty())

func test_settled_terminal_enables_real_new_board_and_returns_to_unpaid_view() -> void:
	var port := _port()
	var panel := _panel(port)
	assert_true(panel.present(_settled_view()))
	assert_false(panel.dock.buttons.new_board.disabled)
	assert_eq(panel.worksheet.grid.focus_mode,Control.FOCUS_NONE)
	port.next_view = _view()
	panel.dock.buttons.new_board.pressed.emit()
	assert_eq(port.calls,[{"action":"new_board","index":-1,"revision":0}])
	assert_false(panel.public_view.settled)
	assert_false(panel.public_view.board.terminal)
	assert_true(panel.dock.buttons.new_board.disabled)


func test_binding_is_idempotent_and_cannot_redirect_to_a_replacement_port() -> void:
	var first := _port()
	var panel := _panel(first)
	var replacement := _port("expert")
	assert_true(panel.bind(first))
	assert_false(panel.bind(replacement))
	assert_false(panel.bind(RefCounted.new()))
	assert_false(panel.bind(null))
	var reads_before: int = first.pull_count
	assert_true(panel.refresh())
	assert_eq(first.pull_count,reads_before+1)
	assert_eq(replacement.pull_count,0)
	assert_eq(panel.public_view.register.difficulty,"beginner")

func test_real_tab_visits_fitted_grid_then_dock_and_exits_to_the_host() -> void:
	var panel := _panel(_port("expert"))
	var after := Button.new()
	after.text = "Host action after Minesweeper"
	after.position = Vector2(900,650)
	panel.get_viewport().add_child(after)
	var before := Button.new()
	before.text = "Host action before Minesweeper"
	panel.get_viewport().add_child(before)
	assert_true(panel.connect_host_focus(before,after))
	assert_false(panel.connect_host_focus(panel.worksheet.grid,after))
	assert_true(panel.refresh(),"A publication preserves the host boundary connections.")
	assert_null(panel.worksheet.vertical_rail)
	assert_null(panel.worksheet.horizontal_rail)
	panel.worksheet.grid.grab_focus()
	var order: Array[Control] = [panel.dock.buttons.reveal,panel.dock.buttons.flag,panel.dock.buttons.drag,
		panel.dock.buttons.assignments,panel.dock.buttons.rules,after]
	for target: Control in order:
		_key(panel,KEY_TAB)
		_key(panel,KEY_TAB,false)
		assert_same(panel.get_viewport().gui_get_focus_owner(),target,"Tab must follow public reading order and leave the panel after Rules.")
	assert_true(after.has_focus(),"The panel is a composite, not a modal focus trap.")
	panel.worksheet.grid.grab_focus()
	var backwards := InputEventKey.new()
	backwards.keycode = KEY_TAB
	backwards.pressed = true
	backwards.shift_pressed = true
	panel.get_viewport().push_input(backwards,true)
	assert_true(before.has_focus())

func test_synchronous_long_press_publication_retains_touch_gate_and_all_cell_nodes() -> void:
	var port := _port()
	# Active public fixture: all covered cells allow Reveal and Flag; no hidden layout enters the panel.
	port.view.board.mine_estimate = 10
	port.view.register.mine_estimate = 10
	port.view.register.rounds = 1
	for cell: Dictionary in port.view.board.cells: cell.actions = ["reveal","flag"]
	var panel := _panel(port)
	var retained: Array = panel.worksheet.grid.cell_nodes.duplicate()
	port.next_view = port.view.duplicate(true)
	port.next_view.board.revision = 1
	port.next_view.board.cells[2].mark = "flag"
	port.next_view.board.cells[2].actions = ["unflag"]
	port.next_view.board.mine_estimate = 9
	port.next_view.register.mine_estimate = 9
	port.next_view.register.no_flag = "lost"
	panel.worksheet.grid.set_process(false)
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.position = panel.worksheet.position+panel.worksheet.grid.position+Vector2(122,26)*panel.worksheet.grid.scale
	touch.pressed = true
	panel.get_viewport().push_input(touch,true)
	assert_true(panel.worksheet.grid.has_held_touch())
	panel.worksheet.grid._process(0.499)
	assert_true(port.calls.is_empty())
	panel.worksheet.grid._process(0.001)
	assert_eq(port.calls,[{"action":"flag","index":2,"revision":0}])
	assert_eq(panel.public_view.board.cells[2].mark,"flag")
	assert_eq(panel.public_view.register.no_flag,"lost")
	assert_true(panel.worksheet.grid.has_held_touch(),"Whole-panel publication must preserve the same finger's release gate.")
	for index in retained.size(): assert_same(panel.worksheet.grid.cell_nodes[index],retained[index])
	touch.pressed = false
	panel.get_viewport().push_input(touch,true)
	assert_false(panel.worksheet.grid.has_held_touch())
	assert_eq(port.calls.size(),1,"Release cannot Reveal or Unflag after a committed long press.")
	assert_eq(panel.public_view.board.revision,1)

func test_locale_configuration_during_sheet_restores_rebuilt_semantic_source_and_pan() -> void:
	var panel := _panel(_port("expert"))
	panel.dock.buttons.flag.pressed.emit()
	panel.worksheet.grid._set_focused(200)
	panel.worksheet.set_scroll(Vector2i(80,140))
	var old_source: Button = panel.dock.buttons.rules
	old_source.grab_focus()
	old_source.pressed.emit()
	assert_not_null(panel.worksheet.information_sheet)
	assert_true(panel.configure("zh-HK",150,true,&"midnight"))
	assert_true(panel.worksheet.information_sheet.rows[0].has_focus())
	assert_null(old_source.get_parent(),"The configured dock has new localized controls.")
	assert_eq(panel.worksheet.get_scroll(),Vector2i.ZERO)
	panel.worksheet.information_sheet.return_button.pressed.emit()
	assert_null(panel.worksheet.information_sheet)
	assert_true(panel.dock.buttons.rules.has_focus(),"Return resolves the source by semantic action after locale rebuilding.")
	assert_eq(panel.worksheet.grid.mode,&"flag")
	assert_eq(panel.worksheet.grid.focused_index,200)
	assert_eq(panel.worksheet.get_scroll(),Vector2i.ZERO)

func test_unchanged_assignment_refresh_preserves_scrolled_rail_identity_and_focus() -> void:
	var port := _port()
	var panel := _panel(port)
	panel.dock.buttons.assignments.pressed.emit()
	var sheet: Control = panel.worksheet.information_sheet
	assert_not_null(sheet)
	if sheet == null: return
	var retained_rail: Control = sheet.rail
	assert_not_null(retained_rail)
	if retained_rail == null: return
	sheet.set_scroll(37)
	var retained_scroll: int = sheet.get_scroll()
	assert_gt(retained_scroll,0)
	retained_rail.grab_focus()
	assert_true(panel.refresh())
	assert_same(panel.worksheet.information_sheet,sheet)
	assert_same(sheet.rail,retained_rail)
	assert_true(retained_rail.has_focus())
	assert_eq(sheet.get_scroll(),retained_scroll)
	assert_true(port.calls.is_empty())

func before_each() -> void:
	_input_fixture = INPUT_FIXTURE.new()

func after_each() -> void:
	_input_fixture.restore_map()
	_input_fixture = null


func test_real_difficulty_buttons_dispatch_frozen_revision_and_reset_mode_only_on_success() -> void:
	var port := _port()
	port.view.register.difficulty_enabled = ["beginner","intermediate","expert"]
	var panel := _panel(port)
	assert_false(panel.register.difficulties.expert.disabled)
	assert_eq(panel.register.difficulties.expert.focus_mode,Control.FOCUS_ALL)
	panel.dock.buttons.flag.pressed.emit()
	panel.register.difficulties.beginner.pressed.emit()
	assert_true(port.calls.is_empty(),"Same-tier selection is a no-op.")
	assert_eq(panel.worksheet.grid.mode,&"flag")
	port.next_view = _view("expert")
	port.next_view.register.difficulty_enabled = ["beginner","intermediate","expert"]
	panel.register.difficulties.expert.pressed.emit()
	assert_eq(port.calls,[{"difficulty":"expert","revision":0}])
	assert_eq(panel.public_view.register.difficulty,"expert")
	assert_eq(panel.public_view.board.width,22)
	assert_eq(panel.worksheet.grid.mode,&"reveal")
	panel.dock.buttons.rules.pressed.emit()
	assert_true(panel.register.difficulties.beginner.disabled)
	panel.register.difficulties.beginner.pressed.emit()
	assert_eq(port.calls.size(),1,"A sheet cannot dispatch a tier change.")


func test_touched_space_and_new_board_share_dispatch_while_untouched_space_is_inert() -> void:
	var port := _port()
	var panel := _panel(port)
	panel.worksheet.grid.grab_focus()
	_key(panel,KEY_SPACE)
	_key(panel,KEY_SPACE,false)
	assert_true(port.calls.is_empty())
	var active := _view()
	active.board.cells[0].face = "revealed"
	active.board.cells[0].actions = []
	active.board.cells[0].pressable = false
	active.actions.append("new_board")
	assert_true(panel.present(active))
	panel.dock.buttons.flag.pressed.emit()
	assert_false(panel.dock.buttons.new_board.disabled)
	panel.worksheet.grid.grab_focus()
	port.next_view = _view()
	_key(panel,KEY_SPACE)
	_key(panel,KEY_SPACE,false)
	assert_eq(port.calls,[{"action":"new_board","index":-1,"revision":0}])
	assert_true(panel.dock.buttons.new_board.disabled)
	assert_eq(panel.worksheet.grid.mode,&"reveal")

func test_settled_space_uses_new_board_even_when_grid_has_no_focus() -> void:
	var port := _port()
	port.view = _settled_view()
	var panel := _panel(port)
	port.next_view = _view()
	_key(panel,KEY_SPACE)
	_key(panel,KEY_SPACE,false)
	assert_eq(port.calls,[{"action":"new_board","index":-1,"revision":0}])
	assert_false(panel.public_view.settled)

func test_settled_difficulty_uses_only_authoritative_capability() -> void:
	var port := _port()
	port.view = _settled_view()
	port.view.register.difficulty_enabled = ["beginner","intermediate","expert"]
	var panel := _panel(port)
	port.next_view = _view("expert")
	assert_false(panel.register.difficulties.expert.disabled)
	panel.register.difficulties.expert.pressed.emit()
	assert_eq(port.calls,[{"difficulty":"expert","revision":0}])
	assert_eq(panel.public_view.board.width,22)
	assert_false(panel.public_view.settled)
