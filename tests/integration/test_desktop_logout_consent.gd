extends GutTest

const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")

class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	func _configure_from_bootstrap() -> void:
		pass

class ExitOwner extends RefCounted:
	var host: RefCounted
	var results: Array[Dictionary] = []
	var captures: Array[Dictionary] = []
	func return_to_title(save_before_exit: bool) -> Dictionary:
		captures.append({"save": save_before_exit, "desktop": host.capture_persistent_state()})
		return results.pop_front() if not results.is_empty() else {"ok": true}

var _viewport: SubViewport
var _desktop: Control
var _host: RefCounted
var _exit: ExitOwner

func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_host = HOST.new()
	_host.reset(1)
	_exit = ExitOwner.new()
	_exit.host = _host
	_desktop = DESKTOP.instantiate()
	_desktop.set_script(IsolatedDesktop)
	_viewport.add_child(_desktop)
	_desktop._host_state = _host
	assert_true(_desktop.configure_session_exit(_exit).ok)
	await get_tree().process_frame
	await get_tree().process_frame

func _click(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size / 2)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		_viewport.push_input(event, true)
		await get_tree().process_frame

func test_launcher_logout_keeps_workspace_and_cache_then_cancel_restores_exact_focus() -> void:
	_host.open_app(&"contacts", 1)
	_host.close_app()
	var before: Dictionary = _host.get_state()
	var launcher: Button = _desktop.launcher_buttons[&"logout"]
	launcher.grab_focus()
	await _click(launcher)
	var consent: Control = _desktop._confirmation
	assert_not_null(consent)
	if consent == null: return
	assert_true(_desktop.icon_grid.visible)
	assert_eq(_desktop._active_id, &"")
	assert_eq(_host.get_state(), before)
	assert_eq(_host.capture_persistent_state(), {"active_app_id": null})
	assert_false(_desktop._cached_app_windows.has(&"logout"))
	assert_eq(_desktop.app_window_host.get_child_count(), 0)
	assert_eq(_viewport.gui_get_focus_owner(), consent.cancel_button)
	assert_eq(consent.cancel_button.accessibility_name, "No")
	assert_eq(consent.accessibility_name, "Log out")
	assert_eq(_desktop.icon_grid.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	assert_eq(_desktop.icon_grid.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)
	assert_false(_desktop.open_app(&"settings").ok)
	assert_false(_desktop.return_home().ok)
	await _click(launcher)
	assert_eq(_desktop._confirmation, consent, "background clicks cannot open or accept consent")
	assert_eq(_exit.captures, [])
	await _click(consent.cancel_button)
	assert_null(_desktop._confirmation)
	assert_eq(_viewport.gui_get_focus_owner(), launcher)
	assert_eq(_desktop.icon_grid.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED)
	assert_eq(_host.get_state(), before)
	assert_eq(_exit.captures, [])

func test_back_cancels_without_saving_and_restores_launcher_focus() -> void:
	_desktop.launcher_buttons[&"logout"].pressed.emit()
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	_viewport.push_input(back, true)
	await get_tree().process_frame
	assert_null(_desktop._confirmation)
	assert_eq(_viewport.gui_get_focus_owner(), _desktop.launcher_buttons[&"logout"])
	assert_eq(_exit.captures, [])

func test_failed_save_keeps_retry_cancel_and_retry_captures_launcher_only() -> void:
	_exit.results = [{"ok": false, "code": &"write_not_committed"}, {"ok": true}]
	_desktop.launcher_buttons[&"logout"].pressed.emit()
	var initial: Control = _desktop._confirmation
	var initial_id := initial.get_instance_id()
	await _click(initial.confirm_button)
	var retry: Control = _desktop._confirmation
	assert_not_null(retry)
	if retry == null: return
	assert_ne(retry.get_instance_id(), initial_id)
	assert_eq(retry.confirm_button.accessibility_name, "Retry")
	assert_false(retry.cancel_button.disabled)
	assert_eq(_viewport.gui_get_focus_owner(), retry.cancel_button)
	assert_eq(_exit.captures, [{"save": true, "desktop": {"active_app_id": null}}])
	await _click(retry.confirm_button)
	assert_eq(_exit.captures.size(), 2)
	assert_eq(_exit.captures[1], _exit.captures[0])
	assert_null(_desktop._confirmation)
	assert_true(_desktop.icon_grid.visible)
	assert_false(_desktop._cached_app_windows.has(&"logout"))

func test_retired_route_failure_only_allows_same_exit_retry() -> void:
	_exit.results = [{"ok": false, "code": &"exit_route_retry_required"}, {"ok": true}]
	_desktop.launcher_buttons[&"logout"].pressed.emit()
	await _click(_desktop._confirmation.confirm_button)
	var retry: Control = _desktop._confirmation
	assert_not_null(retry)
	if retry == null: return
	assert_false(retry.cancel_button.visible)
	assert_true(retry.cancel_button.disabled)
	assert_eq(_viewport.gui_get_focus_owner(), retry.confirm_button)
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	_viewport.push_input(back, true)
	await get_tree().process_frame
	assert_eq(_desktop._confirmation, retry)
	assert_false(_desktop.return_home().ok)
	await _click(retry.confirm_button)
	assert_eq(_exit.captures.size(), 2)
	assert_null(_desktop._confirmation)
