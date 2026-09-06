extends "res://addons/gut/test.gd"
const APP := preload("res://scenes/apps/ScheduleApp.tscn")
const PORT := preload("res://scripts/application/schedule/SchedulePresentationPort.gd")
const VIEW := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

class Owner extends RefCounted:
	var contacts := CONTACTS.make_defaults()
	var day := 3

var _view: Object
var _app: Control
var _port: Object
var _home: Button
var _viewport: SubViewport

func before_each() -> void:
	var loaded := REGISTRY.load_current()
	_view = VIEW.new()
	assert_true(_view.configure(loaded.value.registry,RULES,loaded.value.registry_fingerprint).ok)
	assert_true(_view.open_day(3,"mounted-schedule-day").ok)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(ROOT.new("55".repeat(32),17)).ok)
	var names := {}
	for id: String in ["training","working","rest"]:
		names[id] = {"en":id.capitalize(),"zh-CN":"训练","zh-HK":"訓練"}
	_port = PORT.new()
	assert_true(_port.configure(Owner.new(),_view,loaded.value.registry,loaded.value.registry_fingerprint,issuer,names).ok)
	_home = Button.new()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800,656)
	_viewport.handle_input_locally = true
	_viewport.gui_disable_input = false
	add_child_autofree(_viewport)
	_viewport.add_child(_home)
	_app = APP.instantiate()
	_viewport.add_child(_app)
	_app.configure_desktop_home(_home)
	assert_true(_app.configure_presentation(_port).ok)
	await get_tree().process_frame

func test_real_mounted_source_append_inspect_reorder_remove_and_focus_repair() -> void:
	assert_false(_app.get_node("VBoxContainer/TopBar").visible)
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries.size(),1)
	assert_true(_app.panel.source_buttons.training.has_focus())
	_app.panel.source_buttons.rest.pressed.emit()
	await get_tree().process_frame
	var entries: Array = _view.snapshot().value.view.entries
	var first: String = entries[0].draft_entry_id
	var second: String = entries[1].draft_entry_id
	assert_eq(_app.panel.selected_id,second)
	_app.panel.commands.earlier.pressed.emit()
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries[0].draft_entry_id,second)
	assert_true(_app.panel.entry_buttons[second].has_focus())
	_app.panel.commands.remove.pressed.emit()
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries[0].draft_entry_id,first)
	assert_true(_app.panel.entry_buttons[first].has_focus())
	assert_eq(_app.panel.selected_id,first)

func test_expected_stale_refusal_preserves_visible_inspection_without_mutation() -> void:
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	var selected: String = _app.panel.selected_id
	var before: Dictionary = _view.snapshot().value.view
	_app._projection.fingerprint = "stale"
	_app.panel.commands.remove.pressed.emit()
	assert_eq(_view.snapshot().value.view,before)
	assert_eq(_app.panel.selected_id,selected)
	assert_true(_app.panel.visible)
	assert_ne(_app._projection.fingerprint,"stale","Refusal refreshes the fingerprint instead of trapping every later edit")
	_app.panel.commands.remove.pressed.emit()
	assert_eq(_view.snapshot().value.view.entries.size(),0)

func test_done_needs_a_real_handler_and_home_preserves_draft() -> void:
	assert_true(_app.panel.done_button.disabled)
	_app.panel.source_buttons.rest.pressed.emit()
	await get_tree().process_frame
	var before: Dictionary = _view.snapshot().value.view
	assert_true(_app.can_return_home())
	_app.hide_window()
	assert_eq(_view.snapshot().value.view,before)
	assert_false(_app.visible)

func test_pending_done_awaits_its_owner_and_refuses_edits_or_home() -> void:
	assert_true(_app.configure_presentation(_port,"en",100,false,_delayed_done).ok)
	_app.panel.done_button.grab_focus()
	_app.panel.done_button.pressed.emit()
	assert_true(_app._busy)
	assert_false(_app.can_return_home())
	assert_false(_home.disabled,"The app refuses Home through its admission gate without writing shared host state")
	assert_eq(_app.panel.process_mode,Node.PROCESS_MODE_DISABLED)
	_app.panel.source_buttons.rest.pressed.emit()
	assert_eq(_view.snapshot().value.view.entries.size(),0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_app._busy)
	assert_true(_home.disabled,"A newer owner decision during Done must survive its return")
	assert_true(_app.can_return_home())

func _delayed_done() -> Dictionary:
	await get_tree().process_frame
	_home.disabled = true
	await get_tree().process_frame
	return {"ok":true}

func test_pointer_release_after_projection_replacement_cannot_activate_new_source() -> void:
	var button: Button = _app.panel.source_buttons.rest
	var point := button.get_global_rect().get_center()
	_pointer(point,true)
	await get_tree().process_frame
	assert_true(button.is_pressed(),"Native BaseButton contact is actually held")
	assert_true(_app.refresh_view().ok)
	await get_tree().process_frame
	_pointer(point,false)
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries.size(),0)
	_pointer(point,true)
	await get_tree().process_frame
	_pointer(point,false)
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries.size(),1,"A new complete contact still works")

func _pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	_viewport.push_input(event,true)

func test_native_grip_drag_reorders_once_and_home_is_inert_during_drag() -> void:
	for source: String in ["training","working","rest"]:
		_app.panel.source_buttons[source].pressed.emit()
		await get_tree().process_frame
	var entries: Array = _view.snapshot().value.view.entries
	var last: String = entries[2].draft_entry_id
	var button: Button = _app.panel.entry_buttons[last]
	var origin: Vector2 = button.global_position + button.drag_grip.get_center()
	_pointer(origin,true)
	_motion(origin+Vector2(0,16),Vector2(0,16),true)
	await get_tree().process_frame
	assert_true(_viewport.gui_is_dragging(),"Native viewport drag started from the grip")
	assert_true(_app.panel.is_dragging())
	assert_false(_app.can_return_home())
	var target: Vector2 = _app.panel.docket_scroll.global_position+Vector2(26,0)
	_app.panel.source_buttons.training.pressed.emit()
	assert_eq(_view.snapshot().value.view.entries.size(),3,"Drag custody refuses a competing append")
	_motion(target,target-origin,true)
	await get_tree().process_frame
	assert_eq(_app.panel._docket_body.witness,0)
	_pointer(target,false)
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries[0].draft_entry_id,last)
	assert_false(_app.panel.is_dragging())
	assert_eq(_view.snapshot().value.view.entries.size(),3)

func _motion(point: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_viewport.push_input(event,true)

func test_native_drag_cancels_on_refresh_and_outside_release_without_edit() -> void:
	for source: String in ["training","rest"]:
		_app.panel.source_buttons[source].pressed.emit()
		await get_tree().process_frame
	var before: Dictionary = _view.snapshot().value.view
	var id: String = before.entries[1].draft_entry_id
	for cancellation: String in ["refresh","outside","back"]:
		var button: Button = _app.panel.entry_buttons[id]
		var origin: Vector2 = button.global_position+button.drag_grip.get_center()
		_pointer(origin,true)
		_motion(origin+Vector2(0,16),Vector2(0,16),true)
		await get_tree().process_frame
		assert_true(_viewport.gui_is_dragging(),cancellation)
		if cancellation == "refresh":
			assert_true(_app.refresh_view().ok)
		elif cancellation == "back":
			var back := InputEventAction.new()
			back.action = "ui_cancel"
			back.pressed = true
			_app._unhandled_input(back)
			assert_true(_app.visible,"Back cancels drag without returning Home")
		else:
			var boundary: Vector2 = _app.panel.docket_scroll.global_position+Vector2(26,0)
			_motion(boundary,boundary-origin,true)
			await get_tree().process_frame
			assert_eq(_app.panel._docket_body.witness,0)
			_motion(Vector2(790,650),Vector2(100,100),true)
			await get_tree().process_frame
			assert_eq(_app.panel._docket_body.witness,-1,"Outside motion removes the insertion witness before release")
		_pointer(Vector2(790,650),false)
		await get_tree().process_frame
		assert_false(_viewport.gui_is_dragging())
		assert_false(_app.panel.is_dragging())
		assert_eq(_view.snapshot().value.view,before)

func test_non_grip_pointer_drag_cannot_reorder_and_arrow_stays_in_its_region() -> void:
	_app.panel.source_buttons.training.grab_focus()
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	_viewport.push_input(down,true)
	await get_tree().process_frame
	assert_true(_app.panel.source_buttons.working.has_focus())
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	var id: String = _view.snapshot().value.view.entries[0].draft_entry_id
	var button: Button = _app.panel.entry_buttons[id]
	var point := button.global_position+Vector2(40,24)
	_pointer(point,true)
	_motion(point+Vector2(0,16),Vector2(0,16),true)
	await get_tree().process_frame
	assert_false(_viewport.gui_is_dragging())
	_pointer(point,false)
