extends GutTest

const MENU := preload("res://scenes/menu/MenuScene.tscn")
const SAFE_MENU := preload("res://tests/title_shell/SafeMenu.gd")

class Locale extends Node:
	signal locale_changed(locale: String)
	func get_locale() -> String: return "en"
	func has_key(_key: String) -> bool: return true
	func t(key: String, _parameters: Dictionary = {}) -> String: return key

class Profile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	func get_preference(_path: StringName, fallback: Variant = null) -> Variant: return fallback

class StartupOwner extends Node:
	signal startup_recovery_changed()
	var available := true
	var transaction := "startup-operation"
	var retries: Array[String] = []
	var retry_ok := false
	var fatal_result: Dictionary = {}
	var on_retry: Callable
	func get_startup_state() -> Dictionary:
		return {"ready": false, "fatal_result": fatal_result.duplicate(true)}
	func get_new_run_startup_recovery() -> Dictionary:
		return {"ok": true, "value": {"available": available, "transaction_id": transaction if available else ""}}
	func retry_new_run_startup(token: String) -> Dictionary:
		retries.append(token)
		if on_retry.is_valid(): on_retry.call()
		return {"ok": retry_ok, "code": "ok" if retry_ok else "NEW_RUN_RECOVERY_PENDING"}

class SaveCounter extends RefCounted:
	var prepares := 0
	var retries := 0
	func prepare_new_run_action(_context: Dictionary) -> Dictionary:
		prepares += 1
		return {"ok": false, "code": "fixture_unavailable"}
	func retry_new_run(_token: String) -> Dictionary:
		retries += 1
		return {"ok": false}

var original_scene: Node
var source: Node
var destination: Control
var destination_button: Button
var viewport: SubViewport
var menu: Control
var startup: StartupOwner
var save_counter: SaveCounter

func before_each() -> void:
	original_scene = get_tree().current_scene
	source = Node.new()
	get_tree().root.add_child(source)
	get_tree().current_scene = source
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.handle_input_locally = true
	source.add_child(viewport)
	startup = StartupOwner.new()
	add_child(startup)
	save_counter = SaveCounter.new()

func after_each() -> void:
	get_tree().current_scene = original_scene if is_instance_valid(original_scene) else null
	if is_instance_valid(source): source.free()
	if is_instance_valid(destination): destination.free()
	if is_instance_valid(startup): startup.free()
	await get_tree().process_frame

func _mount() -> void:
	var locale := Locale.new()
	var profile := Profile.new()
	viewport.add_child(locale)
	viewport.add_child(profile)
	menu = MENU.instantiate()
	menu.set_script(SAFE_MENU)
	menu.configure_settings_services({"profile": profile, "localization": locale})
	menu.configure_new_acc_owner(save_counter)
	menu.configure_startup_recovery_owner(startup)
	viewport.add_child(menu)
	await _settle()

func _settle() -> void:
	for frame in 3: await get_tree().process_frame

func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		viewport.push_input(event, true)
	await _settle()

func _assert_single_action(copy: String) -> void:
	assert_true(is_instance_valid(menu._confirmation), "Startup state has a visible owned sheet")
	if not is_instance_valid(menu._confirmation): return
	var sheet: Control = menu._confirmation
	assert_false(sheet.cancel_button.visible)
	assert_eq(sheet.cancel_button.focus_mode, Control.FOCUS_NONE)
	assert_eq(sheet.confirm_button.get_node("Caption").text, copy)
	assert_eq(sheet.confirm_button.risk, "neutral")
	assert_true(sheet.confirm_button.has_focus())
	assert_eq(save_counter.prepares, 0, "Recovery never starts a fresh account")
	assert_eq(save_counter.retries, 0, "Bootstrap owns startup Retry, not SaveManager UI dispatch")

func test_retained_startup_autoopens_once_and_back_cannot_release_ledger() -> void:
	await _mount()
	_assert_single_action("Retry")
	var sheet: Control = menu._confirmation
	startup.startup_recovery_changed.emit()
	startup.startup_recovery_changed.emit()
	await _settle()
	assert_eq(menu._confirmation, sheet, "Repeated publication keeps the same sheet and focus")
	await _key(KEY_ESCAPE)
	assert_eq(menu._confirmation, sheet)
	assert_true(startup.retries.is_empty())
	for button: Button in [menu._new_acc_button, menu._log_in_button, menu._gallery_button,
		menu._setting_button, menu._shut_down_button]:
		button.pressed.emit()
	assert_eq(menu._confirmation, sheet, "Every ledger command remains under recovery custody")
	assert_false(menu._backup_app_host.visible)
	assert_false(menu._setting_host.visible)
	assert_false(menu._gallery_host.visible)
	assert_eq(menu.quit_requests, 0)
	_assert_single_action("Retry")

func test_repeated_failure_retries_the_same_bootstrap_operation_then_success_releases_custody() -> void:
	await _mount()
	await _key(KEY_ENTER)
	_assert_single_action("Retry")
	await _key(KEY_ENTER)
	assert_eq(startup.retries, ["startup-operation", "startup-operation"])
	_assert_single_action("Retry")
	startup.retry_ok = true
	startup.on_retry = func(): startup.available = false
	await _key(KEY_ENTER)
	assert_eq(startup.retries, ["startup-operation", "startup-operation", "startup-operation"])
	assert_false(is_instance_valid(menu._confirmation))
	assert_true(menu._can_leave_login(), "Successful retained operation releases title custody in this fixture")
	assert_eq(save_counter.prepares, 0)

func test_failed_retry_without_recovery_capability_offers_only_safe_shutdown() -> void:
	await _mount()
	startup.on_retry = func(): startup.available = false
	await _key(KEY_ENTER)
	_assert_single_action("Shut down")
	await _key(KEY_ESCAPE)
	_assert_single_action("Shut down")
	assert_eq(menu.quit_requests, 0)
	await _key(KEY_ENTER)
	assert_eq(menu.quit_requests, 1, "Only the intercepted process-exit seam is invoked")
	assert_eq(startup.retries, ["startup-operation"])

func test_foreign_recovery_after_failed_retry_cannot_replace_the_bound_operation() -> void:
	await _mount()
	startup.on_retry = func(): startup.transaction = "foreign-operation"
	await _key(KEY_ENTER)
	assert_eq(startup.retries, ["startup-operation"])
	_assert_single_action("Shut down")
	startup.startup_recovery_changed.emit()
	await _settle()
	_assert_single_action("Shut down")
	assert_eq(startup.retries, ["startup-operation"])

func test_lost_bound_owner_never_falls_back_to_other_services() -> void:
	await _mount()
	startup.free()
	await _key(KEY_ENTER)
	_assert_single_action("Shut down")
	await _key(KEY_ESCAPE)
	_assert_single_action("Shut down")

func test_no_retained_operation_keeps_normal_title_and_initial_focus() -> void:
	startup.available = false
	await _mount()
	assert_false(is_instance_valid(menu._confirmation))
	assert_true(menu._new_acc_button.has_focus())
	assert_true(startup.retries.is_empty())

func test_retry_retiring_source_never_creates_outgoing_sheet_or_steals_destination_focus() -> void:
	await _mount()
	startup.on_retry = func():
		destination = Control.new()
		get_tree().root.add_child(destination)
		destination_button = Button.new()
		destination_button.text = "Destination action"
		destination_button.size = Vector2(240, 64)
		destination.add_child(destination_button)
		get_tree().current_scene = destination
		destination_button.grab_focus()
		source.queue_free()
	# Emit the real shared action to keep assertions before queued source deletion.
	menu._confirmation.confirm_button.pressed.emit()
	assert_eq(startup.retries, ["startup-operation"])
	assert_false(is_instance_valid(menu._confirmation))
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button)
	await _settle()
	assert_false(is_instance_valid(source))
	assert_eq(get_tree().root.gui_get_focus_owner(), destination_button)

func test_initial_generic_startup_failure_offers_only_shutdown_without_a_new_run_identity() -> void:
	startup.available = false
	startup.fatal_result = {"ok": false, "code": "fixture_configuration_failed", "stage": "configure_participants"}
	await _mount()
	_assert_single_action("Shut down")
	assert_true(startup.retries.is_empty())
	assert_eq(startup.get_new_run_startup_recovery().value.transaction_id, "")
	var sheet: Control = menu._confirmation
	await _key(KEY_ESCAPE)
	assert_eq(menu._confirmation, sheet, "Generic fatal startup cannot be dismissed into a fresh account")
	for button: Button in [menu._new_acc_button, menu._log_in_button, menu._gallery_button,
		menu._setting_button, menu._shut_down_button]:
		button.pressed.emit()
	assert_eq(menu._confirmation, sheet)
	assert_false(menu._backup_app_host.visible)
	assert_false(menu._setting_host.visible)
	assert_false(menu._gallery_host.visible)
	assert_eq(menu.quit_requests, 0)
	_assert_single_action("Shut down")
	await _key(KEY_ENTER)
	assert_eq(menu.quit_requests, 1)
	assert_true(startup.retries.is_empty(), "No Retry exists without a retained startup operation")
	assert_eq(save_counter.prepares, 0)

func test_generic_failure_publication_replaces_normal_title_custody_with_shutdown_only() -> void:
	startup.available = false
	await _mount()
	assert_false(is_instance_valid(menu._confirmation))
	assert_true(menu._new_acc_button.has_focus())
	startup.fatal_result = {"ok": false, "code": "fixture_late_configuration_failed", "stage": "publish_startup_route"}
	startup.startup_recovery_changed.emit()
	await _settle()
	_assert_single_action("Shut down")
	var sheet: Control = menu._confirmation
	startup.startup_recovery_changed.emit()
	await _settle()
	assert_eq(menu._confirmation, sheet, "Repeated fatal publication does not recreate the sheet")
	await _key(KEY_ESCAPE)
	assert_eq(menu._confirmation, sheet)
	menu._new_acc_button.pressed.emit()
	assert_eq(save_counter.prepares, 0)
	assert_true(startup.retries.is_empty())
	_assert_single_action("Shut down")
