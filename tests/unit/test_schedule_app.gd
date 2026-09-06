extends "res://addons/gut/test.gd"
const APP := preload("res://scenes/apps/ScheduleApp.tscn")
const PORT := preload("res://scripts/application/schedule/SchedulePresentationPort.gd")
const VIEW := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const WARNING_PORT := preload("res://scripts/application/schedule/ScheduleWarningPresentationPort.gd")

class Owner extends RefCounted:
	var contacts := CONTACTS.make_defaults()
	var day := 3

var _view: Object
var _app: Control
var _port: Object
var _home: Button
var _viewport: SubViewport
var _issuer: Object
var _warning_context: Dictionary

func before_each() -> void:
	var loaded := REGISTRY.load_current()
	_view = VIEW.new()
	assert_true(_view.configure(loaded.value.registry,RULES,loaded.value.registry_fingerprint).ok)
	assert_true(_view.open_day(3,"mounted-schedule-day").ok)
	var issuer := ISSUER.new()
	_issuer = issuer
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

func test_refused_edit_status_survives_refresh_and_clears_on_success_or_departure() -> void:
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	var id: String = _app.panel.selected_id
	var before: Dictionary = _view.snapshot().value.view
	watch_signals(_app.panel)
	_app._move(id,99)
	assert_eq(_view.snapshot().value.view,before)
	assert_signal_emit_count(_app.panel,"status_announced",1)
	_app._refused({"code":"invalid_target_index"})
	assert_signal_emit_count(_app.panel,"status_announced",1,"Duplicate delivery retains one admitted refusal")
	assert_true(_app.refresh_view().ok)
	await get_tree().process_frame
	assert_signal_emit_count(_app.panel,"status_announced",1)
	_app._move(id,99)
	assert_signal_emit_count(_app.panel,"status_announced",2,"A distinct admitted edit announces anew")
	_app.panel.source_buttons.rest.pressed.emit()
	assert_true(_app.panel.get_node_or_null("DockStatus") == null,"Successful append clears status")
	_app._remove("missing-entry")
	assert_not_null(_app.panel.get_node_or_null("DockStatus"))
	_app.hide_window()
	assert_null(_app.panel.get_node_or_null("DockStatus"),"Safe departure clears transient status")
	_app.show_window()
	await get_tree().process_frame
	assert_null(_app.panel.get_node_or_null("DockStatus"))

func test_stale_refusal_publishes_status_and_new_done_clears_it_before_await() -> void:
	assert_true(_app.configure_presentation(_port,"en",100,false,_delayed_done).ok)
	_app._projection.fingerprint = "stale"
	_app.panel.source_buttons.training.pressed.emit()
	assert_not_null(_app.panel.get_node_or_null("DockStatus"))
	assert_eq(_view.snapshot().value.view.entries.size(),0)
	_app.panel.done_button.pressed.emit()
	assert_null(_app.panel.get_node_or_null("DockStatus"))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func test_pending_done_awaits_its_owner_and_refuses_edits_or_home() -> void:
	assert_true(_app.configure_presentation(_port,"en",100,false,_delayed_done).ok)
	_app.panel.done_button.grab_focus()
	_app.panel.done_button.pressed.emit()
	assert_true(_app._busy)
	assert_false(_app.can_return_home())
	_app.hide_window()
	assert_true(_app.visible,"Direct hide also respects the accepted Done custody")
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

func _key_press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	_viewport.push_input(event,true)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	_viewport.push_input(event,true)

func test_page_keys_scroll_only_the_focused_paper_without_changing_the_draft() -> void:
	assert_true(_app.configure_presentation(_port,"en",150,true).ok)
	for index in 6:
		_app.panel.source_buttons.training.pressed.emit()
		await get_tree().process_frame
	var before: Dictionary = _view.snapshot().value.view
	var selected: String = _app.panel.selected_id
	var first: String = before.entries[0].draft_entry_id
	_app.panel.entry_buttons[first].grab_focus()
	await get_tree().process_frame
	assert_eq(_app.panel.docket_scroll.scroll_vertical,0)
	_key_press(KEY_PAGEDOWN)
	await get_tree().process_frame
	assert_gt(_app.panel.docket_scroll.scroll_vertical,0,"Page Down addresses the focused Docket owner")
	assert_eq(_app.panel.available_scroll.scroll_vertical,0)
	assert_true(_app.panel.entry_buttons[first].has_focus())
	assert_eq(_app.panel.selected_id,selected)
	var bar: VScrollBar = _app.panel.docket_scroll.get_v_scroll_bar()
	for index in 8: _key_press(KEY_PAGEDOWN)
	assert_eq(float(_app.panel.docket_scroll.scroll_vertical),bar.max_value-bar.page)
	for index in 8: _key_press(KEY_PAGEUP)
	assert_eq(_app.panel.docket_scroll.scroll_vertical,0)
	_app.panel.source_buttons.rest.grab_focus()
	_key_press(KEY_PAGEDOWN)
	assert_eq(_app.panel.docket_scroll.scroll_vertical,0,"Fitting Available paper does not redirect to the Docket")
	assert_eq(_view.snapshot().value.view,before)

func test_cached_return_restores_semantic_focus_without_changing_the_draft() -> void:
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	_app.panel.commands.remove.grab_focus()
	var before: Dictionary = _view.snapshot().value.view
	var selected: String = _app.panel.selected_id
	_app.hide_window()
	_app.show_window()
	await get_tree().process_frame
	assert_true(_app.panel.commands.remove.has_focus(),"Safe return restores the same semantic command")
	assert_eq(_app.panel.selected_id,selected)
	assert_eq(_view.snapshot().value.view,before)
	assert_true(_app.panel.source_buttons.training.is_visible_in_tree())

func test_cached_return_reprojects_and_clears_inspection_for_external_view_replacement() -> void:
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	_app.panel.commands.remove.grab_focus()
	_app.hide_window()
	assert_true(_view.open_day(3,"replacement-schedule-day").ok)
	_app.show_window()
	await get_tree().process_frame
	assert_eq(_app.panel.entry_buttons.size(),0)
	assert_eq(_app.panel.selected_id,"")
	assert_true(_app.panel.source_buttons.training.has_focus())
	assert_eq(_app.panel.docket_scroll.scroll_vertical,0)

func test_host_cache_clear_supports_load_even_when_view_fingerprint_is_unchanged() -> void:
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	_app.panel.commands.remove.grab_focus()
	var before: Dictionary = _view.snapshot().value.view
	_app.hide_window()
	_app.clear_presentation_cache()
	_app.show_window()
	await get_tree().process_frame
	assert_eq(_app.panel.selected_id,"")
	assert_eq(_app.panel.commands.size(),0)
	assert_true(_app.panel.source_buttons.training.has_focus())
	assert_eq(_view.snapshot().value.view,before,"Cache reset is presentation-only")

func test_cached_return_cancels_a_held_pointer_contact() -> void:
	var point: Vector2 = _app.panel.source_buttons.rest.get_global_rect().get_center()
	_pointer(point,true)
	assert_true(_app.panel.source_buttons.rest.is_pressed())
	_app.hide_window()
	_app.show_window()
	await get_tree().process_frame
	_pointer(point,false)
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries.size(),0)

func test_keyboard_scroll_is_inert_while_done_owns_custody() -> void:
	assert_true(_app.configure_presentation(_port,"en",150,true,_delayed_done).ok)
	for index in 6:
		_app.panel.source_buttons.training.pressed.emit()
		await get_tree().process_frame
	_app.panel.entry_buttons.values()[0].grab_focus()
	await get_tree().process_frame
	var offset: int = _app.panel.docket_scroll.scroll_vertical
	_app.panel.done_button.pressed.emit()
	_key_press(KEY_PAGEDOWN)
	assert_eq(_app.panel.docket_scroll.scroll_vertical,offset)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func test_failed_configuration_retains_valid_locale_for_recovery_refresh() -> void:
	assert_false(_app.configure_presentation(_port,"unsupported").ok)
	assert_true(_app.refresh_view().ok)
	assert_true(_app.panel.visible)
	assert_eq(_app.panel.source_buttons.training.accessibility_name,"Training")

func test_cached_return_keeps_a_manually_scrolled_position_with_focus_elsewhere() -> void:
	assert_true(_app.configure_presentation(_port,"en",150,true).ok)
	for index in 6:
		_app.panel.source_buttons.training.pressed.emit()
		await get_tree().process_frame
	_app.panel.entry_buttons.values()[0].grab_focus()
	await get_tree().process_frame
	_key_press(KEY_PAGEDOWN)
	var offset: int = _app.panel.docket_scroll.scroll_vertical
	assert_gt(offset,0)
	_app.hide_window()
	_app.show_window()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_app.panel.docket_scroll.scroll_vertical,offset,"Restoring cached focus must not undo manual paper scrolling")

func test_locale_reflow_retains_semantic_docket_top_even_with_focus_elsewhere() -> void:
	assert_true(_app.configure_presentation(_port,"zh-HK",150,true).ok)
	for index in 6:
		_app.panel.source_buttons.training.pressed.emit()
		await get_tree().process_frame
	var entries: Array = _view.snapshot().value.view.entries
	var second_id: String = entries[1].draft_entry_id
	_app.panel.entry_buttons[entries[0].draft_entry_id].grab_focus()
	await get_tree().process_frame
	var before_top: int = int(_app.panel.entry_buttons[second_id].position.y) + 2
	_app.panel.docket_scroll.scroll_vertical = before_top
	assert_eq(_app.panel.docket_scroll.scroll_vertical,before_top)
	assert_true(_app.configure_presentation(_port,"en",150,true).ok)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_app.panel.entry_buttons[entries[0].draft_entry_id].has_focus())
	assert_eq(_app.panel.docket_scroll.scroll_vertical,int(_app.panel.entry_buttons[second_id].position.y)+2)
	assert_ne(_app.panel.docket_scroll.scroll_vertical,before_top,"Reflow follows occurrence identity instead of the old pixel offset")
	assert_eq(_view.snapshot().value.view.entries,entries)

class WarningCommands extends RefCounted:
	var view: Object
	var issuer: Object
	var calls: Array = []
	var tree: SceneTree
	var delay := false
	var refuse := false
	func resolve_warning(activation: String, intent: StringName) -> Dictionary:
		calls.append([activation,intent])
		if delay: await tree.process_frame
		if refuse: return {"ok":false,"code":&"fixture_warning_command_failed"}
		var issued: Dictionary = issuer.issue(&"transaction_id")
		if not issued.ok: return issued
		var resolution := {"outcome":"dismissed"}
		if intent != &"dismiss": resolution = {"outcome":"navigation_failed","intent":str(intent),"failure_code":"fixture_route_unavailable"}
		return view.resolve_warning(issued.value.token,issued.value.issuer_receipt,resolution)

func _mount_warning(kind: String = "unread_invitation", activate: bool = true) -> Object:
	assert_true(_view.configure_warning_identity(_issuer).ok)
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	var context := {"run_id":"run-fixture","branch_id":"branch-fixture","desktop_timeline_generation":0,
		"causal_day_instance":"mounted-schedule-day","eligible_unread_date_message_ids":["fixture-message"],
		"accepted_unscheduled_date_ids":[],"board_identity":null,"board_phase":"NONE","base_round_ordinal":1,
		"base_opportunity_remaining":false,"unfinished_base_board":false,"motivation":1}
	if kind != "unread_invitation": context.eligible_unread_date_message_ids = []
	if kind == "accepted_date":
		context.accepted_unscheduled_date_ids = ["fixture-date"]
		context.motivation = 0
	elif kind == "base_minesweeper": context.base_opportunity_remaining = true
	_warning_context = context
	if activate: assert_true(_view.request_warning_activation(issued.value.token,issued.value.issuer_receipt,context).ok)
	var copy := {}
	for copy_kind: String in ["unread_invitation","accepted_date","base_minesweeper"]:
		copy[copy_kind] = {}
		for locale: String in ["en","zh-CN","zh-HK"]:
			copy[copy_kind][locale] = {"title":"Fixture notice","body":"Fixture body. ".repeat(35),"close":"Close","go":"Go","failed_go":"Fixture route could not open."}
	var warning_port := WARNING_PORT.new()
	assert_true(warning_port.configure(_view,copy).ok)
	var commands := WarningCommands.new()
	commands.view = _view
	commands.issuer = _issuer
	commands.tree = get_tree()
	assert_true(_app.configure_warning(warning_port,commands).ok)
	return commands

func test_pending_warning_mounts_real_retained_desk_and_blocks_background_input() -> void:
	assert_true(_app.configure_presentation(_port,"en",150,true).ok)
	for index in 6:
		_app.panel.source_buttons.training.pressed.emit()
		await get_tree().process_frame
	var selected: String = _app.panel.selected_id
	var commands := _mount_warning()
	await get_tree().process_frame
	assert_true(_app.warning_sheet.close_button.has_focus())
	assert_false(_app.can_return_home())
	assert_true(_app.panel.visible,"The desk remains undimmed beneath the sheet")
	assert_eq(_app.panel.process_mode,Node.PROCESS_MODE_DISABLED)
	assert_eq(_app.panel.selected_id,selected)
	var before: Dictionary = _view.snapshot().value.view
	_app.panel.source_buttons.rest.pressed.emit()
	_pointer(Vector2(5,5),true)
	_pointer(Vector2(5,5),false)
	assert_eq(commands.calls.size(),0,"Outside click does not dismiss")
	assert_eq(_view.snapshot().value.view,before)
	var docket_offset: int = _app.panel.docket_scroll.scroll_vertical
	_key_press(KEY_TAB)
	assert_true(_app.warning_sheet.go_button.has_focus())
	_key_press(KEY_TAB)
	assert_true(_app.warning_sheet.close_button.has_focus())
	_key_press(KEY_PAGEDOWN)
	assert_gt(_app.warning_sheet.body_scroll.scroll_vertical,0)
	assert_eq(_app.panel.docket_scroll.scroll_vertical,docket_offset,"Modal Page affects only its body")
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(740,300)
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_viewport.push_input(wheel,true)
	assert_eq(_app.panel.docket_scroll.scroll_vertical,docket_offset,"Covered paper rejects wheel outside the opaque sheet too")
	assert_false(_port.project("en").ok,"Ordinary editing projection still refuses modal access")
	assert_true(_port.project_modal_background("en").ok)
	_key_press(KEY_ESCAPE)
	await get_tree().process_frame
	assert_eq(commands.calls.size(),1)
	assert_eq(commands.calls[0][1],&"dismiss")
	assert_null(_app.warning_sheet)
	assert_null(_view.snapshot().value.view.pending_warning)
	assert_eq(_view.snapshot().value.view.entries,before.entries)
	assert_eq(_app.panel.selected_id,selected)
	assert_true(_app.can_return_home())

func test_failed_warning_go_keeps_activation_and_projects_only_the_operational_error() -> void:
	var commands := _mount_warning()
	await get_tree().process_frame
	var activation: String = _app.warning_sheet.activation_id
	_app.warning_sheet.go_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(commands.calls[0][1],&"open_contacts_list")
	assert_eq(_app.warning_sheet.activation_id,activation)
	assert_true(_app.warning_sheet.close_button.has_focus())
	var view: Dictionary = _view.snapshot().value.view
	assert_eq(view.pending_warning.attempt_receipts.size(),1)
	assert_eq(view.consumed_warning_receipts.size(),0)
	assert_eq(_app._warning_data.error,"Fixture route could not open.")
	assert_false(str(_app._warning_data).contains("fixture_route_unavailable"),"Technical failure code stays private")
	assert_false(str(_app._warning_data).contains("receipt_provenance"))
	_app.warning_sheet.go_button.grab_focus()
	var same_button: Button = _app.warning_sheet.go_button
	assert_true(_app.refresh_view().ok)
	await get_tree().process_frame
	assert_same(_app.warning_sheet.go_button,same_button)
	assert_true(same_button.has_focus(),"Duplicate projection does not steal modal focus")

func test_warning_command_failure_requests_recovery_without_fabricating_a_navigation_attempt() -> void:
	var commands := _mount_warning()
	commands.refuse = true
	await get_tree().process_frame
	var before: Dictionary = _view.snapshot().value.view
	watch_signals(_app)
	_app.warning_sheet.go_button.pressed.emit()
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(_app,"recovery_requested",[&"fixture_warning_command_failed"])
	assert_false(_app.last_result.ok)
	assert_false(_app.panel.visible)
	assert_null(_app.warning_sheet)
	assert_eq(_view.snapshot().value.view,before,"Recovery preserves the pending activation and all receipt facts")
	assert_eq(commands.calls.size(),1)
	assert_true(_app.refresh_view().ok,"A later refresh can restore the retained warning")
	await get_tree().process_frame
	assert_eq(_app.warning_sheet.activation_id,before.pending_warning.activation_id)
	assert_eq(_app._warning_data.error,"","Technical command refusal is not a failed navigation receipt")

func test_accepted_date_warning_go_is_dismissal_without_navigation() -> void:
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	var commands := _mount_warning("accepted_date")
	await get_tree().process_frame
	_app.warning_sheet.go_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(commands.calls[0][1],&"dismiss")
	assert_null(_app.warning_sheet)
	assert_eq(_view.snapshot().value.view.entries.size(),1)
	assert_eq(_view.snapshot().value.view.consumed_warning_receipts.size(),1)

func test_base_warning_emits_only_minesweeper_intent_and_projection_is_detached() -> void:
	var commands := _mount_warning("base_minesweeper")
	await get_tree().process_frame
	var projected: Dictionary = _app._warning_port.project("en")
	projected.value.warning.copy.title = "Caller mutation"
	assert_eq(_app._warning_port.project("en").value.warning.copy.title,"Fixture notice")
	_app.warning_sheet.go_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(commands.calls[0][1],&"open_minesweeper")
	assert_eq(_view.snapshot().value.view.pending_warning.attempt_receipts.size(),1)

func _done_creates_warning() -> Dictionary:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	return _view.request_warning_activation(issued.value.token,issued.value.issuer_receipt,_warning_context)

func test_done_activation_opens_warning_once_without_replacing_the_draft() -> void:
	_mount_warning("unread_invitation",false)
	assert_true(_app.configure_presentation(_port,"en",100,false,_done_creates_warning).ok)
	_app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	var entries: Array = _view.snapshot().value.view.entries
	_app.panel.done_button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(_app.warning_sheet)
	assert_true(_app.warning_sheet.close_button.has_focus())
	var view: Dictionary = _view.snapshot().value.view
	assert_eq(view.entries,entries)
	_app.panel.done_button.pressed.emit()
	assert_eq(_view.snapshot().value.view,view,"Duplicate Done cannot create or skip another warning")

func test_native_back_and_page_cannot_queue_another_warning_command_during_await() -> void:
	var commands := _mount_warning()
	commands.delay = true
	await get_tree().process_frame
	_app.warning_sheet.go_button.pressed.emit()
	assert_true(_app._busy)
	var offset: int = _app.warning_sheet.body_scroll.scroll_vertical
	_key_press(KEY_ESCAPE)
	_key_press(KEY_PAGEDOWN)
	assert_eq(commands.calls.size(),1)
	assert_eq(_app.warning_sheet.body_scroll.scroll_vertical,offset)
	assert_false(_app.can_return_home())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_app._busy)
	assert_true(_app.warning_sheet.close_button.has_focus())
	assert_eq(commands.calls.size(),1)
