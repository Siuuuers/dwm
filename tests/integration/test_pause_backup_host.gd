extends GutTest
## Actual Pause/Backup/confirmation controls and SaveManager/BackupPresentationPort.
## Storage is memory-only; seeded desktop records do not claim a paused narrative save.

const PAUSE := preload("res://scenes/overlay/PauseSurface.tscn")
const BACKUP := preload("res://scenes/apps/BackupApp.tscn")
const MANAGER := preload("res://autoload/SaveManager.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

var _viewport: SubViewport
var _surface: Control
var _backup: Control
var _manager: Node
var _port: RefCounted
var _files: RefCounted
var _storage: RefCounted
var _before: Dictionary
var _old_process_mode: int
var _source_admitted := true

func before_each() -> void:
	_old_process_mode = process_mode
	_source_admitted = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_files = FILES.new()
	_storage = STORAGE.new("memory/pause-backup",_files)
	_manager = MANAGER.new()
	add_child(_manager)
	assert_true(_manager.initialize(_storage).ok)
	assert_true(_manager.configure_mutation_gate(GATE.new()).ok)
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v4_desktop_prepared.json"))
	snapshot["gameplay"]["money"] = 0
	_manager._journal.reset(snapshot.run_id)
	var prepared: Dictionary = _manager._journal.prepare_record(snapshot,&"day_start")
	assert_true(prepared.ok,str(prepared))
	assert_true(_manager._journal.commit_prepared(prepared.value.candidate).ok)
	_port = PORT.new()
	assert_true(_port.configure(_manager,"in_run",_source_admission).ok)
	for locator: String in ["slot:1","quick"]:
		var seed: Dictionary = _port.prepare_action("save",locator)
		assert_true(seed.ok)
		assert_true(_port.commit_action(seed.value.token).ok)
	# Production has no qualified paused-source capture yet. Keep that real refusal.
	assert_true(_manager.configure_backup_capture_provider(_unavailable_capture).ok)
	_before = _files.snapshot_persisted()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280,720)
	_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_viewport)
	_surface = PAUSE.instantiate()
	_viewport.add_child(_surface)
	_backup = BACKUP.instantiate()
	assert_true(_backup.configure_backup(_port).ok)
	assert_true(_surface.set_host(&"backup",_backup))
	_surface.open_surface()
	watch_signals(_surface)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(_surface): _surface.close_surface()
	_viewport.free()
	_manager.free()
	await get_tree().process_frame
	process_mode = _old_process_mode

func _unavailable_capture() -> Dictionary:
	return {"ok":false,"code":&"backup_capture_unavailable"}

func _source_admission() -> Dictionary:
	return {"ok":true} if _source_admitted else {"ok":false,"code":&"pause_source_changed"}

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	_viewport.push_input(event,true)

func _tap(code: Key) -> void:
	_key(code,true)
	_key(code,false)

func _enter_backup() -> void:
	_surface.rows[&"backup"].grab_focus()
	_tap(KEY_RIGHT)
	assert_eq(_surface.entered_action,&"backup")
	assert_true(_backup.drawer_buttons["slot:1"].has_focus())
	_backup.mode_buttons.load.grab_focus()
	_tap(KEY_ENTER)
	assert_eq(_backup.active_mode,"load")

func _request_delete() -> Control:
	_backup.drawer_buttons["slot:1"].grab_focus()
	_backup.action_buttons.delete.grab_focus()
	_tap(KEY_ENTER)
	var sheet: Control = _backup.confirmation
	assert_not_null(sheet)
	return sheet

func test_preview_retains_real_nine_records_and_source_save_refusal_without_mutation() -> void:
	_surface.rows[&"backup"].grab_focus()
	assert_true(_backup.visible)
	assert_eq(_backup.drawer_buttons.keys(),PORT.LOCATORS)
	assert_eq(_backup.size,Vector2(800,656))
	assert_eq(_backup.position,Vector2.ZERO)
	assert_true(_backup.action_buttons.save.disabled)
	assert_false(_backup.is_processing_unhandled_input())
	assert_true(_surface.rows[&"backup"].has_focus())
	assert_eq(_files.snapshot_persisted(),_before,"preview never writes or creates a checkpoint")
	_tap(KEY_ESCAPE)
	assert_signal_emit_count(_surface,"continue_requested",1)
	assert_eq(_surface.entered_action,&"")
	assert_eq(_files.snapshot_persisted(),_before)

func test_confirmation_cancel_then_backup_retreat_then_continue_each_need_their_own_back() -> void:
	get_tree().paused = true
	_enter_backup()
	var sheet := _request_delete()
	assert_same(sheet.get_parent(),_surface.workfield)
	assert_true(sheet.cancel_button.has_focus())
	assert_false(_backup.is_visible_in_tree(),"the covered Backup is not an active modal subtree")
	assert_false(_backup.is_processing_unhandled_input())
	assert_eq(_files.snapshot_persisted(),_before)
	_tap(KEY_ESCAPE)
	assert_null(_backup.confirmation)
	assert_eq(_surface.entered_action,&"backup")
	assert_true(_backup.action_buttons.delete.has_focus())
	assert_signal_emit_count(_surface,"continue_requested",0)
	assert_eq(_files.snapshot_persisted(),_before)
	_tap(KEY_ESCAPE)
	assert_eq(_surface.entered_action,&"")
	assert_true(_surface.rows[&"backup"].has_focus())
	assert_signal_emit_count(_surface,"continue_requested",0)
	_tap(KEY_ESCAPE)
	assert_signal_emit_count(_surface,"continue_requested",1)
	assert_true(get_tree().paused,"only the lifecycle owner can release source custody")

func test_confirmed_delete_uses_real_record_revision_without_resuming_or_changing_quick() -> void:
	_enter_backup()
	var journal: Dictionary = _manager._journal.capture_state().duplicate(true)
	var quick: Dictionary = _storage.inspect_revision("quick.json").duplicate(true)
	var sheet := _request_delete()
	sheet.confirm_button.grab_focus()
	_key(KEY_ENTER,true)
	assert_true(_storage.exists("slot_1.json"),"press alone is not destructive consent")
	_key(KEY_ENTER,false)
	assert_false(_storage.exists("slot_1.json"))
	assert_eq(_storage.inspect_revision("quick.json"),quick)
	assert_eq(_manager._journal.capture_state(),journal)
	assert_true(_backup.last_result.ok)
	assert_eq(_surface.entered_action,&"backup")
	assert_signal_emit_count(_surface,"continue_requested",0)

func test_changed_record_enters_recovery_and_back_does_not_escape_backup() -> void:
	_enter_backup()
	var sheet := _request_delete()
	var changed: String = _storage.read_text("slot_1.json").value + " "
	assert_true(_files.write_bytes("memory/pause-backup/slot_1.json",changed.to_utf8_buffer()).ok)
	assert_true(_files.flush_path("memory/pause-backup/slot_1.json").ok)
	sheet.confirm_button.grab_focus()
	_tap(KEY_ENTER)
	assert_false(_backup.last_result.ok)
	assert_eq(_backup.last_result.code,&"stale_backup_target")
	assert_true(_backup._recovering)
	assert_true(_backup.action_buttons.cancel.has_focus())
	assert_eq(_files.read_bytes("memory/pause-backup/slot_1.json").value,changed.to_utf8_buffer())
	_surface.leave_host()
	assert_eq(_surface.entered_action,&"backup","owner recovery blocks parent departure")
	_tap(KEY_ESCAPE)
	assert_false(_backup._recovering)
	assert_eq(_surface.entered_action,&"backup")
	assert_signal_emit_count(_surface,"continue_requested",0)

func test_confirmation_is_inert_during_parent_custody_and_close_cancels_its_token() -> void:
	_enter_backup()
	var sheet := _request_delete()
	var token: String = _backup._pending_token
	_surface.set_interactive(false)
	_tap(KEY_ESCAPE)
	_tap(KEY_ENTER)
	assert_same(_backup.confirmation,sheet)
	assert_eq(_files.snapshot_persisted(),_before)
	_surface.set_interactive(true)
	assert_true(sheet.cancel_button.has_focus(),"restoring parent custody restores the exact modal focus")
	_surface.close_surface()
	assert_false(_port.commit_action(token).ok,"closing cancels its uncommitted consent")
	assert_eq(_files.snapshot_persisted(),_before)
	assert_false(_surface.visible)

func test_source_change_after_confirmation_prevents_delete_and_consumes_consent() -> void:
	_enter_backup()
	var sheet := _request_delete()
	var token: String = _backup._pending_token
	_source_admitted = false
	sheet.confirm_button.grab_focus()
	_tap(KEY_ENTER)
	assert_eq(_backup.last_result.code,&"pause_source_changed")
	assert_true(_backup._recovering)
	assert_true(_backup.action_buttons.cancel.has_focus())
	assert_eq(_files.snapshot_persisted(),_before)
	_source_admitted = true
	assert_false(_port.commit_action(token).ok,"repaired source cannot replay old consent")
	assert_signal_emit_count(_surface,"continue_requested",0)

func test_removing_backup_cancels_prepared_owner_token() -> void:
	_enter_backup()
	_request_delete()
	var token: String = _backup._pending_token
	_backup.get_parent().remove_child(_backup)
	assert_false(_port.commit_action(token).ok)
	assert_eq(_files.snapshot_persisted(),_before)
	_surface.close_surface()
	_backup.free()

func test_parent_interaction_restores_exact_backup_focus_without_resetting_mode_or_record() -> void:
	_enter_backup()
	_backup.action_buttons.delete.grab_focus()
	_surface.set_interactive(false)
	assert_null(_viewport.gui_get_focus_owner())
	_surface.set_interactive(false)
	_surface.set_interactive(true)
	assert_true(_backup.action_buttons.delete.has_focus())
	assert_eq(_backup.active_mode,"load")
	assert_eq(_backup.selected_locator,"slot:1")
	assert_eq(_files.snapshot_persisted(),_before)

func test_parent_custody_change_retires_held_touch_consent_before_reactivation() -> void:
	_enter_backup()
	var sheet := _request_delete()
	await get_tree().process_frame
	await get_tree().process_frame
	var point: Vector2 = sheet.confirm_button.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.position = point
	press.pressed = true
	_viewport.push_input(press,true)
	assert_true(sheet.confirm_button.has_focus())
	_surface.set_interactive(false)
	_surface.set_interactive(true)
	var release := press.duplicate() as InputEventScreenTouch
	release.pressed = false
	_viewport.push_input(release,true)
	assert_same(_backup.confirmation,sheet,"old contact cannot consent after custody interruption")
	assert_eq(_files.snapshot_persisted(),_before)
	_viewport.push_input(press,true)
	_viewport.push_input(release,true)
	assert_false(_storage.exists("slot_1.json"),"a fresh contact still confirms normally")
