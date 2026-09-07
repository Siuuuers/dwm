extends GutTest
## Real Schedule projection/edit owners hosted by the production Desktop scene. Persistence is
## isolated through JsonFileStorage over FakeFileOps; no successful completion is fabricated.

const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const PORT := preload("res://scripts/application/schedule/SchedulePresentationPort.gd")
const VIEW := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const WARNING_PORT := preload("res://scripts/application/schedule/ScheduleWarningPresentationPort.gd")


class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	func _configure_from_bootstrap() -> void:
		pass


class ContactsPort extends RefCounted:
	func get_projection(_day: int = 1) -> Dictionary:
		return {"ok":true,"value":{"friends":[],"group":{}}}
	func open_friend(_friend_id: String) -> Dictionary:
		return {"ok":false,"code":&"fixture_command_unavailable"}
	func reply_to_group(_choice_id: String) -> Dictionary:
		return {"ok":false,"code":&"fixture_command_unavailable"}


class ScheduleOwner extends RefCounted:
	var contacts: Dictionary = CONTACTS.make_defaults()
	var day := 3


class WarningCommands extends RefCounted:
	var calls: Array = []
	func resolve_warning(activation_id: String, intent: StringName) -> Dictionary:
		calls.append([activation_id,intent])
		return {"ok":false,"code":&"fixture_warning_command_unavailable"}


var _viewport: SubViewport
var _profile: Node
var _localization: Node
var _host: RefCounted
var _owner: ScheduleOwner
var _view: RefCounted
var _issuer: RefCounted
var _port: RefCounted
var _contacts_port: RefCounted
var _done_released := false


func before_each() -> void:
	_done_released = false
	var files := FILES.new()
	_profile = PROFILE.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new("memory/schedule-desktop/profile",files)).ok)
	_localization = LOCALIZATION.new()
	add_child_autofree(_localization)
	assert_true(_localization.initialize(_profile).ok)
	_host = HOST.new()
	_host.reset(3)
	_contacts_port = ContactsPort.new()
	_owner = ScheduleOwner.new()
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.ok)
	_view = VIEW.new()
	assert_true(_view.configure(loaded.value.registry,RULES,loaded.value.registry_fingerprint).ok)
	assert_true(_view.open_day(3,"mounted-schedule-day").ok)
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(ROOT_STORE.new("75".repeat(32),23)).ok)
	assert_true(_view.configure_warning_identity(_issuer).ok)
	_port = PORT.new()
	assert_true(_port.configure(_owner,_view,loaded.value.registry,
		loaded.value.registry_fingerprint,_issuer,_names()).ok)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024,720)
	_viewport.handle_input_locally = true
	_viewport.gui_disable_input = false
	add_child_autofree(_viewport)


func _names() -> Dictionary:
	return {
		"training":{"en":"Training","zh-CN":"训练","zh-HK":"訓練"},
		"working":{"en":"Working","zh-CN":"工作","zh-HK":"工作"},
		"rest":{"en":"Rest","zh-CN":"休息","zh-HK":"休息"},
	}


func _desktop_on_tree() -> Control:
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	_viewport.add_child(desktop)
	assert_true(desktop.configure_contacts(_contacts_port,_localization,_profile,_host,3).ok)
	return desktop


func _configure_schedule(desktop: Control, done: Callable = Callable(), warning: Dictionary = {}) -> Dictionary:
	return desktop.configure_schedule(_port,_localization,_profile,_host,3,done,
		warning.get("presentation"),warning.get("commands"))


func _open_schedule(desktop: Control) -> Control:
	desktop.launcher_buttons[&"schedule"].pressed.emit()
	var app: Control = desktop._cached_app_windows.get(&"schedule") as Control
	assert_not_null(app)
	if app != null:
		assert_true(app.is_visible_in_tree())
		assert_eq(desktop._active_id,&"schedule")
		assert_eq(_host.get_state().active_app_id,&"schedule")
		assert_false(desktop.icon_grid.visible)
	return app


func _warning_fixture() -> Dictionary:
	var copy := {}
	for kind: String in ["unread_invitation","accepted_date","base_minesweeper"]:
		copy[kind] = {}
		for locale: String in ["en","zh-CN","zh-HK"]:
			copy[kind][locale] = {"title":"Fixture notice","body":"Fixture body. ".repeat(35),
				"close":"Close","go":"Go","failed_go":"Fixture route could not open."}
	var presentation := WARNING_PORT.new()
	assert_true(presentation.configure(_view,copy).ok)
	return {"presentation":presentation,"commands":WarningCommands.new()}


func _activate_warning() -> void:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.ok)
	assert_true(_view.request_warning_activation(issued.value.token,issued.value.issuer_receipt,{
		"run_id":"run-fixture","branch_id":"branch-fixture","desktop_timeline_generation":0,
		"causal_day_instance":"mounted-schedule-day",
		"eligible_unread_date_message_ids":["fixture-message"],
		"accepted_unscheduled_date_ids":[],"board_identity":null,"board_phase":"NONE",
		"base_round_ordinal":1,"base_opportunity_remaining":false,
		"unfinished_base_board":false,"motivation":1,
	}).ok)


func _pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	_viewport.push_input(event,true)


func _motion(point: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_viewport.push_input(event,true)


func _delayed_refused_done() -> Dictionary:
	while not _done_released:
		await get_tree().process_frame
	return {"ok":false,"code":&"fixture_done_unavailable"}


func _done_with_argument(_value: Variant) -> Dictionary:
	return {"ok":false,"code":&"not_called"}


func test_absent_schedule_port_keeps_the_registered_launcher_unavailable_without_host_mutation() -> void:
	var desktop := _desktop_on_tree()
	await get_tree().process_frame
	var before: Dictionary = _host.get_state()
	assert_eq(desktop.open_app(&"schedule"),{"ok":false,"code":&"schedule_unavailable"})
	assert_eq(desktop.app_window_host.get_child_count(),0)
	assert_eq(desktop._cached_app_windows,{})
	assert_eq(_host.get_state(),before)
	assert_true(desktop.icon_grid.visible)
	assert_true(desktop.status_label.visible)


func test_real_owner_edits_and_cached_home_reopen_preserve_draft_selection_focus_and_preferences() -> void:
	var contacts_before: Dictionary = _owner.contacts.duplicate(true)
	var desktop := _desktop_on_tree()
	assert_true(_configure_schedule(desktop).ok)
	await get_tree().process_frame
	var app := _open_schedule(desktop)
	if app == null: return
	for source: String in ["training","rest"]:
		app.panel.source_buttons[source].pressed.emit()
		await get_tree().process_frame
	var first: String = _view.snapshot().value.view.entries[0].draft_entry_id
	var second: String = _view.snapshot().value.view.entries[1].draft_entry_id
	assert_eq(app.panel.selected_id,second)
	app.panel.commands.earlier.pressed.emit()
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries[0].draft_entry_id,second)
	app.panel.commands.remove.pressed.emit()
	await get_tree().process_frame
	assert_eq(_view.snapshot().value.view.entries.size(),1)
	assert_eq(_view.snapshot().value.view.entries[0].draft_entry_id,first)
	app.panel.commands.remove.grab_focus()
	var draft_before: Dictionary = _view.snapshot().value.view
	var selected_before: String = app.panel.selected_id
	assert_true(desktop.return_home().ok)
	assert_false(app.visible)
	assert_null(_host.get_state().active_app_id)
	assert_true(_host.get_state().cached_app_ids.has(&"schedule"))
	assert_true(desktop.launcher_buttons[&"schedule"].has_focus())
	assert_true(_localization.set_locale("zh_HK").ok)
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size",125).ok)
	var reopened: Dictionary = desktop.open_app(&"schedule")
	assert_true(reopened.ok)
	if not reopened.ok: return
	await get_tree().process_frame
	await get_tree().process_frame
	assert_same(reopened.value.app,app)
	assert_eq(_view.snapshot().value.view,draft_before)
	assert_eq(app.panel.selected_id,selected_before)
	assert_true(app.panel.commands.remove.has_focus(),"The same semantic command regains focus after cached reflow.")
	assert_eq(app._locale,"zh-HK")
	assert_eq(app._percent,125)
	assert_eq(app.panel.source_buttons.training.accessibility_name,"訓練")
	assert_eq(_owner.contacts,contacts_before,"Docket edits never rewrite the gameplay Contacts resource.")
	assert_eq(_owner.day,3)


func test_pre_ready_configuration_reconciles_a_restored_active_schedule_route() -> void:
	assert_true(_host.open_app(&"schedule",3).ok)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	assert_true(desktop.configure_contacts(_contacts_port,_localization,_profile,_host,3).ok)
	assert_true(_configure_schedule(desktop).ok)
	_viewport.add_child(desktop)
	await get_tree().process_frame
	await get_tree().process_frame
	var app: Control = desktop._cached_app_windows.get(&"schedule") as Control
	assert_not_null(app)
	if app == null: return
	assert_true(app.is_visible_in_tree())
	assert_eq(desktop._active_id,&"schedule")
	assert_false(desktop.icon_grid.visible)
	assert_false(desktop._restoration_failed)
	assert_eq(_host.get_state().active_app_id,&"schedule")


func test_failed_pre_ready_restored_projection_stays_masked_as_the_saved_route() -> void:
	assert_true(_host.open_app(&"schedule",3).ok)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	assert_true(desktop.configure_contacts(_contacts_port,_localization,_profile,_host,3).ok)
	assert_true(_configure_schedule(desktop).ok)
	_owner.day = 4
	_viewport.add_child(desktop)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(desktop._restoration_failed)
	assert_eq(desktop._active_id,&"schedule")
	assert_eq(_host.get_state().active_app_id,&"schedule")
	assert_false(desktop.icon_grid.visible,"A failed restored route is never presented as the launcher.")
	assert_true(desktop.home_button.disabled)
	assert_eq(desktop.home_button.focus_mode,Control.FOCUS_NONE)
	assert_false(desktop._cached_app_windows.has(&"schedule"))


func test_schedule_configuration_is_immutable_and_rejects_mismatched_or_partial_owners() -> void:
	var desktop := _desktop_on_tree()
	assert_true(_configure_schedule(desktop).ok)
	assert_true(_configure_schedule(desktop).ok,"An exact owner replay is idempotent.")
	var replacement := PORT.new()
	assert_eq(desktop.configure_schedule(replacement,_localization,_profile,_host,3).code,
		&"schedule_already_configured")
	var other_host := HOST.new()
	other_host.reset(3)
	assert_eq(desktop.configure_schedule(_port,_localization,_profile,other_host,3).code,
		&"desktop_owner_mismatch")
	assert_eq(desktop.configure_contacts(_contacts_port,null,null,null,3).code,
		&"desktop_owner_mismatch","Contacts cannot clear Schedule's retained shared owners.")
	assert_eq(desktop.configure_contacts(_contacts_port,_localization,_profile,other_host,3).code,
		&"desktop_owner_mismatch","Contacts cannot replace Schedule's retained host.")
	assert_eq(desktop.configure_contacts(_contacts_port,_localization,_profile,_host,4).code,
		&"desktop_owner_mismatch","Contacts cannot change Schedule's retained day.")
	assert_eq(desktop.configure_schedule(_port,_localization,_profile,_host,3,_done_with_argument).code,
		&"invalid_schedule_done")
	var warning: Dictionary = _warning_fixture()
	assert_eq(desktop.configure_schedule(_port,_localization,_profile,_host,3,Callable(),
		warning.presentation,null).code,&"invalid_schedule_warning")
	assert_eq(desktop.configure_schedule(_port,_localization,_profile,_host,3,Callable(),
		warning.presentation,_view).code,&"invalid_schedule_warning",
		"The real view's three-argument resolve_warning is not the UI's two-argument command port.")
	var app := _open_schedule(desktop)
	if app == null: return
	assert_same(desktop._schedule_port,_port)
	assert_same(desktop._presentation_port,_contacts_port)
	assert_same(desktop._host_state,_host)
	assert_same(desktop._localization,_localization)
	assert_same(desktop._profile,_profile)
	assert_eq(desktop._day,3)
	assert_null(desktop._schedule_warning_port)
	assert_null(desktop._schedule_warning_commands)
	assert_true(desktop._schedule_done.is_null())
	assert_null(other_host.get_state().active_app_id)
	assert_true(app.last_result.ok,"Rejected replacements leave the admitted owner usable.")


func test_native_drag_custody_blocks_home_and_other_apps_without_editing_the_draft() -> void:
	var desktop := _desktop_on_tree()
	assert_true(_configure_schedule(desktop).ok)
	var app := _open_schedule(desktop)
	if app == null: return
	for source: String in ["training","rest"]:
		app.panel.source_buttons[source].pressed.emit()
		await get_tree().process_frame
	var before: Dictionary = _view.snapshot().value.view
	var id: String = before.entries[1].draft_entry_id
	var button: Button = app.panel.entry_buttons[id]
	var origin: Vector2 = button.global_position+button.drag_grip.get_center()
	_pointer(origin,true)
	_motion(origin+Vector2(0,16),Vector2(0,16),true)
	await get_tree().process_frame
	assert_true(_viewport.gui_is_dragging())
	assert_true(app.panel.is_dragging())
	assert_eq(desktop.return_home().code,&"desktop_modal_active")
	assert_eq(desktop.open_app(&"contacts").code,&"desktop_modal_active")
	assert_eq(_host.get_state().active_app_id,&"schedule")
	assert_eq(_view.snapshot().value.view,before)
	_pointer(origin+Vector2(0,16),false)
	await get_tree().process_frame
	assert_false(app.panel.is_dragging())
	assert_eq(_view.snapshot().value.view,before)


func test_delayed_refused_done_holds_host_custody_without_fabricating_completion() -> void:
	var desktop := _desktop_on_tree()
	var done: Callable = _delayed_refused_done
	assert_true(_configure_schedule(desktop,done).ok)
	var app := _open_schedule(desktop)
	if app == null: return
	app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	var before: Dictionary = _view.snapshot().value.view
	app.panel.done_button.pressed.emit()
	assert_true(app._busy)
	assert_eq(app.panel.process_mode,Node.PROCESS_MODE_DISABLED)
	assert_eq(desktop.return_home().code,&"desktop_modal_active")
	assert_eq(desktop.open_app(&"contacts").code,&"desktop_modal_active")
	assert_eq(_host.get_state().active_app_id,&"schedule")
	assert_eq(_view.snapshot().value.view,before)
	_done_released = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(app._busy)
	assert_false(app.last_result.ok)
	assert_eq(app.last_result.code,&"fixture_done_unavailable")
	assert_true(desktop.status_label.visible)
	assert_eq(_host.get_state().active_app_id,&"schedule")
	assert_eq(_view.snapshot().value.view,before,"A refused Done cannot consume or replace the draft.")


func test_real_pending_warning_owns_modal_custody_without_background_commands() -> void:
	var desktop := _desktop_on_tree()
	var warning: Dictionary = _warning_fixture()
	assert_true(_configure_schedule(desktop,Callable(),warning).ok)
	var app := _open_schedule(desktop)
	if app == null: return
	app.panel.source_buttons.training.pressed.emit()
	await get_tree().process_frame
	_activate_warning()
	assert_true(app.refresh_view().ok)
	await get_tree().process_frame
	assert_not_null(app.warning_sheet)
	if app.warning_sheet == null: return
	var before: Dictionary = _view.snapshot().value.view
	assert_true(app.warning_sheet.close_button.has_focus())
	assert_false(app.can_return_home())
	assert_eq(app.panel.process_mode,Node.PROCESS_MODE_DISABLED)
	assert_eq(desktop.home_button.focus_mode,Control.FOCUS_NONE)
	assert_eq(desktop.return_home().code,&"desktop_modal_active")
	assert_eq(desktop.open_app(&"contacts").code,&"desktop_modal_active")
	app.panel.source_buttons.rest.pressed.emit()
	app.hide_window()
	assert_true(app.visible)
	assert_eq(_host.get_state().active_app_id,&"schedule")
	assert_eq(_view.snapshot().value.view,before)
	assert_eq((warning.commands as WarningCommands).calls.size(),0)
