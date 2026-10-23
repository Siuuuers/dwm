extends GutTest

const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const SHELL := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACTS := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const BOARD := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

class PublicPort extends RefCounted:
	var view: Dictionary
	var commands: Array[String] = []
	func pull() -> Dictionary: return {"ok": true, "value": view.duplicate(true)}
	func set_foreground(_foreground: bool, _revision: int) -> Dictionary: return pull()
	func dispatch(action: String, _index: int, _revision: int) -> Dictionary:
		commands.append(action)
		return pull()

var _viewport: SubViewport
var _desktop: Control
var _app: Control
var _port: PublicPort
var _profile: RefCounted


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1100, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_desktop = DESKTOP.instantiate()
	_desktop.set_script(SHELL.IsolatedDesktop)
	_desktop.size = Vector2(800, 720)
	assert_true(_desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new()).ok)
	_viewport.add_child(_desktop)
	_port = PublicPort.new()
	_port.view = _active_view()
	_profile = CONTACTS.FakeProfile.new()
	var host := CONTACTS.FakeHost.new()
	host.reject_next = false
	assert_true(_desktop.configure_minesweeper(_port, null, _profile, host).ok)
	var opened: Dictionary = _desktop.open_app(&"minesweeper")
	assert_true(opened.ok)
	_app = opened.value.app
	await _settle()


func _settle() -> void:
	for _frame: int in range(3): await get_tree().process_frame


func _active_view(revision: int = 1) -> Dictionary:
	var board: Dictionary = BOARD.desktop(STATE.new().capture(), "beginner", true).value
	board.revision = revision
	return {"board": board, "register": {"difficulty": "beginner", "rounds": 1,
		"mine_estimate": board.mine_estimate, "foresight": null, "no_flag": "intact",
		"custody": false, "difficulty_enabled": []}, "assignments": [false, false, false,
		false, false, false, false, false, false],
		"actions": ["reveal", "flag", "drag", "assignments", "rules"], "settled": false}


func _publish_terminal(settled: bool = false) -> void:
	_port.view.board.terminal = true
	_port.view.board.custody = true
	for cell: Dictionary in _port.view.board.cells:
		cell.actions = []
		cell.pressable = false
		cell.inspectable = false
	_port.view.register.custody = true
	_port.view.settled = settled
	_port.view.actions = ["new_board", "assignments", "rules"] if settled else []
	assert_true(_app.refresh_view().ok)
	_desktop.set_process(false)


func _notice(id: String, friend: String = "lavinia") -> void:
	_desktop._on_contact_message_unlocked({"notification_id": id, "friend_id": friend})
	_desktop.set_process(false)


func _new_round() -> void:
	_port.view = _active_view(_port.view.board.revision + 1)
	assert_true(_app.refresh_view().ok)
	_publish_terminal()


func test_terminal_publication_starts_loop_without_restarting_on_refresh() -> void:
	assert_false(_desktop.delivery_notice.visible)
	_publish_terminal()
	assert_true(_desktop.delivery_notice.visible)
	assert_eq(_desktop.delivery_caption.text, "delivering.")
	_desktop._process(0.4)
	assert_eq(_desktop.delivery_caption.text, "delivering..")
	_publish_terminal()
	assert_eq(_desktop.delivery_caption.text, "delivering..", "repeat publication keeps animation progress")
	_desktop._process(0.41)
	assert_eq(_desktop.delivery_caption.text, "delivering...")
	_desktop._process(0.4)
	assert_eq(_desktop.delivery_caption.text, "delivering.")


func test_delivered_waits_for_matching_corner_notice_and_fades_only_with_time() -> void:
	_notice("older")
	_publish_terminal()
	_notice("this-round")
	_publish_terminal(true)
	assert_eq(_desktop.delivery_caption.text, "delivering.", "queued message is not visible yet")
	_desktop._process(5.0)
	assert_true(_desktop.delivery_notice.visible, "pending notice is not timed out")
	_desktop._dismiss_message_notification()
	_desktop.set_process(false)
	assert_eq(_desktop.message_notification.get_meta("notification_id"), "this-round")
	assert_eq(_desktop.delivery_caption.text, "delivered :)")
	_desktop._dismiss_message_notification()
	assert_true(_desktop.delivery_notice.visible, "closing the corner message cannot cancel delivery feedback")
	_desktop._process(1.99)
	assert_eq(_desktop.delivery_notice.modulate.a, 1.0)
	_desktop._process(0.26)
	assert_almost_eq(_desktop.delivery_notice.modulate.a, 0.5, 0.001)
	_desktop._process(0.25)
	assert_false(_desktop.delivery_notice.visible)


func test_new_round_replaces_fade_and_old_queued_notices_cannot_finish_it() -> void:
	_publish_terminal()
	_notice("first")
	_publish_terminal(true)
	_desktop._process(2.25)
	assert_lt(_desktop.delivery_notice.modulate.a, 1.0)
	_new_round()
	assert_eq(_desktop.delivery_caption.text, "delivering.")
	assert_eq(_desktop.delivery_notice.modulate.a, 1.0)
	_notice("second")
	_publish_terminal(true)
	_new_round()
	_notice("third")
	_publish_terminal(true)
	_desktop._dismiss_message_notification()
	assert_eq(_desktop.message_notification.get_meta("notification_id"), "second")
	assert_eq(_desktop.delivery_caption.text, "delivering.", "older queued round cannot finish newest delivery")
	_desktop._dismiss_message_notification()
	_desktop.set_process(false)
	assert_eq(_desktop.delivery_caption.text, "delivered :)")
	_desktop._process(0.4)
	assert_eq(_desktop.delivery_notice.modulate.a, 1.0, "old fade deadline cannot hide the replacement")


func test_no_message_settlement_clears_without_false_success() -> void:
	_publish_terminal()
	_publish_terminal(true)
	assert_false(_desktop.delivery_notice.visible)
	assert_ne(_desktop.delivery_caption.text, "delivered :)")
	_notice("unrelated")
	assert_false(_desktop.delivery_notice.visible, "later unrelated contact notification cannot revive the round")


func test_cold_settled_inspection_and_duplicate_notifications_do_not_replay() -> void:
	_publish_terminal(true)
	assert_false(_desktop.delivery_notice.visible)
	_new_round()
	_notice("once")
	_publish_terminal(true)
	_desktop._process(2.5)
	_notice("once")
	_publish_terminal(true)
	assert_false(_desktop.delivery_notice.visible)
	assert_true(_desktop._message_notification_queue.is_empty())


func test_failure_clears_spinner_and_successful_retry_can_deliver() -> void:
	_publish_terminal()
	_app.recovery_requested.emit(&"minesweeper_settlement_refused")
	assert_false(_desktop.delivery_notice.visible)
	assert_true(_desktop.status_label.visible, "existing recovery presentation remains authoritative")
	_notice("retry-success")
	_publish_terminal(true)
	assert_eq(_desktop.delivery_caption.text, "delivered :)")
	assert_true(_desktop.delivery_notice.visible)
	_app.recovery_requested.emit(&"another_action_refused")
	assert_true(_desktop.delivery_notice.visible, "an unrelated failure cannot dismiss delivered feedback")


func test_home_keeps_feedback_but_desktop_retirement_invalidates_queued_completion() -> void:
	_notice("older")
	_publish_terminal()
	_notice("queued")
	_publish_terminal(true)
	assert_true(_desktop.return_home().ok)
	assert_true(_desktop.delivery_notice.visible, "app navigation does not cancel desktop feedback")
	_desktop.hide()
	assert_false(_desktop.delivery_notice.visible)
	_desktop.show()
	_desktop._dismiss_message_notification()
	assert_false(_desktop.delivery_notice.visible, "retired generation cannot revive from a queued notice")


func test_day_reset_invalidates_pending_feedback() -> void:
	_publish_terminal()
	_desktop._on_daily_state_reset()
	assert_false(_desktop.delivery_notice.visible)
	_notice("previous-day")
	assert_false(_desktop.delivery_notice.visible)


func test_notice_inherits_scale_and_stays_centered_at_large_text() -> void:
	_publish_terminal()
	for width: float in [800.0, 960.0]:
		_desktop.size.x = width
		_profile.change_scale(1.5)
		await _settle()
		assert_eq(_desktop.delivery_notice.get_global_rect().get_center(), _desktop.get_global_rect().get_center())
		assert_eq(_desktop.delivery_notice.get_global_transform().get_scale(), Vector2.ONE * width / 800.0)
		assert_eq(_desktop.delivery_caption.get_theme_font_size("font_size"), 36)
		assert_true(_desktop.delivery_notice.get_global_rect().encloses(_desktop.delivery_caption.get_global_rect()))


func test_notice_has_no_modal_or_focus_and_mouse_reaches_control_beneath() -> void:
	var button := Button.new()
	button.position = Vector2(224, 316)
	button.size = Vector2(352, 88)
	button.text = "Underlying action"
	_desktop.desktop_canvas.add_child(button)
	_desktop.desktop_canvas.move_child(button, _desktop.delivery_notice.get_index())
	button.grab_focus()
	watch_signals(button)
	_publish_terminal()
	await _settle()
	assert_same(_viewport.gui_get_focus_owner(), button)
	assert_null(_desktop._confirmation)
	for control: Control in [_desktop.delivery_notice, _desktop.delivery_caption]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(control.focus_mode, Control.FOCUS_NONE)
	var mouse := InputEventMouseButton.new()
	mouse.position = _desktop.delivery_notice.get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	_viewport.push_input(mouse, true)
	mouse = mouse.duplicate()
	mouse.pressed = false
	_viewport.push_input(mouse, true)
	assert_signal_emit_count(button, "pressed", 1)
	_notice("done")
	_publish_terminal(true)
	_port.view = _active_view(2)
	_app.panel.dock.buttons.new_board.pressed.emit()
	assert_eq(_port.commands, ["new_board"], "delivery feedback never disables a permitted new board")
	assert_true(_desktop.delivery_notice.visible)
	button.queue_free()
	await _settle()
	var cell: Control = _app.panel.worksheet.grid.cell_nodes[0]
	mouse = InputEventMouseButton.new()
	mouse.position = cell.get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	_viewport.push_input(mouse, true)
	mouse = mouse.duplicate()
	mouse.pressed = false
	_viewport.push_input(mouse, true)
	assert_eq(_port.commands, ["new_board", "reveal"], "cells still accept physical clicks while delivered remains visible")
	assert_true(_desktop.delivery_notice.visible)
