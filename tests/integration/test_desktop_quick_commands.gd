extends GutTest
## Actual Desktop input, shared confirmation/status, Backup port and SaveManager transactions.
## The confirmed-load row composes all eight production restore participants over real owners;
## only storage, native audio/window-independent playback, and the live capture adapter are bounded.

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const MANAGER := preload("res://autoload/SaveManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const ROUTER := preload("res://autoload/SceneRouter.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const AUDIO_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const BACKUP_PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const RUN_RESTORE := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const PROFILE_RESTORE := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const LOCALIZATION_RESTORE := preload("res://scripts/application/restore/LocalizationRestoreParticipant.gd")
const AUDIO_RESTORE := preload("res://scripts/application/restore/AudioRestoreParticipant.gd")
const ROUTE_RESTORE := preload("res://scripts/application/restore/RouteRestoreParticipant.gd")
const NARRATIVE_RESTORE := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const CONSEQUENCE_RESTORE := preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd")
const BOARD_RESTORE := preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd")
const IDENTITY_RESTORE := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const FIXTURE := "res://tests/fixtures/saves/v6_desktop_prepared.json"


class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	func _configure_from_bootstrap() -> void:
		pass


class ContactsPort extends RefCounted:
	func get_projection(_friend_id: String, _primary: String = "en", _secondary: String = "") -> Dictionary:
		return {"ok": true, "value": {"friend_id": "", "entries": [], "unread": {}}}
	func open_friend(_friend_id: String) -> Dictionary: return {"ok": false, "code": &"not_used"}
	func reply_to_group(_choice_id: String) -> Dictionary: return {"ok": false, "code": &"not_used"}


class CaptureSource extends Node:
	var inputs: Dictionary = {}
	var available := true
	var after_capture := Callable()
	func capture() -> Dictionary:
		var result := {"ok": true, "value": inputs.duplicate(true)} if available else {"ok": false, "code": &"backup_capture_unavailable"}
		if after_capture.is_valid(): after_capture.call()
		return result


class AppCustody extends Control:
	# Isolate each host's existing can_return_home seam, including native Settings
	# capture. Actual Contacts and Minesweeper mounts are exercised separately.
	var departure_allowed := true
	var gui_packets := 0
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(800, 656)
	func can_return_home() -> bool: return departure_allowed
	func _gui_input(_event: InputEvent) -> void:
		gui_packets += 1
		accept_event()


var _viewport: SubViewport
var _files: RefCounted
var _storage: RefCounted
var _manager: Node
var _profile: Node
var _input: Node
var _game_state: Node
var _localization: Node
var _host: RefCounted
var _source: CaptureSource
var _port: RefCounted
var _desktop: Control
var _desktop_admitted := true
var _input_map_backup: Dictionary = {}


func before_each() -> void:
	_capture_input_map()
	_desktop_admitted = true
	_files = FILES.new()
	_storage = STORAGE.new("memory/desktop-quick", _files)
	_manager = MANAGER.new()
	add_child_autofree(_manager)
	assert_true(_manager.initialize(_storage).ok)
	var gate: RefCounted = GATE.new()
	assert_true(_manager.configure_mutation_gate(gate).ok)

	_profile = PROFILE.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new("memory/desktop-quick/profile", _files)).ok)
	_input = INPUT.new()
	add_child_autofree(_input)
	assert_true(_input.initialize(_profile).ok)
	_game_state = GAME_STATE.new()
	assert_true(_game_state.configure_mutation_gate(gate).get("ok", false))
	add_child_autofree(_game_state)
	_game_state.reset_game()
	_host = HOST.new()
	_host.reset(1)

	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert_true(_seed_stable(snapshot).ok)
	_source = CaptureSource.new()
	add_child_autofree(_source)
	_source.inputs = _capture_inputs(snapshot)
	assert_true(_manager.configure_backup_capture_provider(_source.capture).ok)
	assert_true(_configure_real_restore_graph().ok)

	_port = BACKUP_PORT.new()
	assert_true(_port.configure(_manager, "in_run", _port_admission).ok)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_desktop = DESKTOP.instantiate()
	_desktop.set_script(IsolatedDesktop)
	_viewport.add_child(_desktop)
	assert_true(_desktop.configure_backup_port(_port).ok)
	assert_true(_desktop.configure_contacts(ContactsPort.new(), _localization, _profile, _host, 1).ok)
	assert_true(_desktop.open_app(&"backup").ok)
	assert_true(_desktop.configure_quick_commands(_port, _input, _desktop_admission).ok)
	_desktop._foreground_eligible = true
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_restore_input_map()


func _capture_input_map() -> void:
	_input_map_backup.clear()
	for action: StringName in InputMap.get_actions():
		_input_map_backup[action] = {"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true)}


func _restore_input_map() -> void:
	for action: StringName in InputMap.get_actions():
		if not _input_map_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _input_map_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_map_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_map_backup[action].events:
			InputMap.action_add_event(action, event)


func _capture_inputs(snapshot: Dictionary) -> Dictionary:
	var raw := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "desktop", "dating", "schedule_view",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts"]:
		var value: Variant = snapshot[key]
		raw[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"snapshot_input": raw, "route_id": "main", "active_app_id": &"backup",
		"dialogic_checkpoint": {}, "audio_context": {
			"music_context_id": "", "music_context": {},
			"ambience_context_id": "", "ambience_context": {},
		}, "content_version": 1}


func _seed_stable(snapshot: Dictionary) -> Dictionary:
	_manager._journal.reset(snapshot.run_id)
	var prepared: Dictionary = _manager._journal.prepare_record(snapshot, &"day_start")
	if not prepared.get("ok", false): return prepared
	return _manager._journal.commit_prepared(prepared.value.candidate)


func _configure_real_restore_graph() -> Dictionary:
	var root_store := ROOT_STORE.new()
	var identity_storage := STORAGE.new("memory/desktop-quick/identity", _files)
	var configured: Dictionary = root_store.configure(identity_storage, NAMESPACE.new("3".repeat(64)))
	if not configured.get("ok", false): return configured
	var loaded: Dictionary = root_store.load_or_create()
	if not loaded.get("ok", false): return loaded
	var issuer := ISSUER.new()
	configured = issuer.configure(root_store)
	if not configured.get("ok", false): return configured
	configured = _manager.configure_identity_issuer(issuer)
	if not configured.get("ok", false): return configured
	configured = _manager.configure_identity_allocation_participant(IDENTITY_RESTORE.new(issuer, _manager))
	if not configured.get("ok", false): return configured

	_localization = LOCALIZATION.new()
	add_child_autofree(_localization)
	configured = _localization.initialize(_profile)
	if not configured.get("ok", false): return configured
	var audio := AUDIO.new()
	audio.set("_playback_port", AUDIO_PORT.new())
	add_child_autofree(audio)
	configured = audio.initialize(_profile)
	if not configured.get("ok", false): return configured
	var router := ROUTER.new()
	add_child_autofree(router)
	var bridge := BRIDGE.new()
	add_child_autofree(bridge)
	configured = bridge.initialize()
	if not configured.get("ok", false): return configured
	var route := ROUTE_RESTORE.new(router)
	configured = route.configure_desktop_host(_host)
	if not configured.get("ok", false): return configured
	return _manager.configure_restore_participants({
		"run": RUN_RESTORE.new(_game_state),
		"desktop_consequence": CONSEQUENCE_RESTORE.new(CONSEQUENCE_STATE.new()),
		"desktop_board": BOARD_RESTORE.new(BOARD_STATE.new()),
		"schedule_view": preload("res://tests/support/ScheduleRestoreFixture.gd").create(issuer).value.participant,
		"profile": PROFILE_RESTORE.new(_profile),
		"localization": LOCALIZATION_RESTORE.new(_localization),
		"audio": AUDIO_RESTORE.new(audio),
		"route": route,
		"narrative": NARRATIVE_RESTORE.new(bridge),
	})


func _port_admission() -> Dictionary:
	return {"ok": true}


func _desktop_admission() -> bool:
	return _desktop_admitted


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _tap(code: Key) -> void:
	_viewport.push_input(_key(code, true), true)
	_viewport.push_input(_key(code, false), true)


func _joy(button: JoyButton, pressed: bool, device: int = 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	event.pressed = pressed
	return event


func _tap_joy(button: JoyButton) -> void:
	_viewport.push_input(_joy(button, true), true)
	_viewport.push_input(_joy(button, false), true)


func _rebind(action: String, slot: String, binding: Dictionary) -> void:
	var proposed: Dictionary = _profile.prepare_controls_change(action, slot, binding)
	assert_true(proposed.get("ok", false), JSON.stringify(proposed))
	if proposed.get("ok", false): assert_true(_profile.commit_controls_change(proposed.value).ok)


func _backup_presentation() -> Dictionary:
	var backup: Control = _desktop._cached_app_windows[&"backup"]
	return {"selected_locator": backup.selected_locator, "active_mode": backup.active_mode,
		"status_text": backup.status_label.text, "status_visible": backup.status_label.visible}


func _seed_quick() -> void:
	var prepared: Dictionary = _port.prepare_quick_action("save")
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if prepared.get("ok", false):
		assert_true(_port.commit_action(prepared.value.token).ok)


func test_f5_commits_current_quick_through_real_owner_without_displacing_backup_state() -> void:
	var before := _backup_presentation()
	assert_false(_storage.exists("quicksave.json"))
	_tap(KEY_F5)
	assert_true(_storage.exists("quicksave.json"))
	assert_true(_desktop._quick_commands.last_result.get("ok", false),
		JSON.stringify(_desktop._quick_commands.last_result))
	assert_eq(_desktop._quick_commands.edge.key, &"saved")
	assert_eq(_backup_presentation(), before,
		"the shell voice does not change Backup's selected record, mode, or local status")
	var inspected: Dictionary = _manager.inspect_backup("quick")
	assert_true(inspected.ok)
	assert_eq(inspected.value.state, "occupied")
	var edge: Label = _desktop._quick_commands.edge
	edge.set_process(false)
	watch_signals(edge)
	var binding: Dictionary = edge.current_binding
	var remaining: float = edge.remaining_seconds
	for font_style: String in ["readable", "pixel"]:
		var changed: Dictionary = _profile.prepare_font_style_preference(font_style)
		assert_true(changed.ok,JSON.stringify(changed))
		assert_true(_profile.commit_prepared_profile(changed.value).ok)
		await get_tree().process_frame
		assert_same(edge.theme.default_font,TYPOGRAPHY.font("en",100,font_style))
		assert_eq(edge.current_binding,binding,"font preference does not replace the published saved fact")
		assert_eq(edge.remaining_seconds,remaining,"font preference does not restart status lifetime")
	assert_signal_not_emitted(edge,"status_announced")


func test_f9_uses_shared_confirmation_and_escape_consumes_the_real_token() -> void:
	_seed_quick()
	var journal: Dictionary = _manager._journal.capture_state().duplicate(true)
	var backup: Control = _desktop._cached_app_windows[&"backup"]
	backup.action_buttons["save"].grab_focus()
	var before := _backup_presentation()
	var changed: Dictionary = _profile.prepare_font_style_preference("readable")
	assert_true(changed.ok,JSON.stringify(changed))
	assert_true(_profile.commit_prepared_profile(changed.value).ok)
	_tap(KEY_F9)
	assert_not_null(_desktop._confirmation)
	assert_same(_desktop._confirmation.theme.default_font,TYPOGRAPHY.font("en",100,"readable"))
	assert_eq(_desktop._quick_commands.edge.key, &"")
	var token: String = _desktop._quick_commands._pending_token
	assert_false(token.is_empty())
	assert_true(_localization.set_locale("zh_HK").ok)
	var resized: Dictionary = _profile.prepare_preferences({&"preferences.accessibility.text_size": 125})
	assert_true(resized.ok)
	assert_true(_profile.commit_prepared_profile(resized.value).ok)
	_viewport.size = Vector2i(800, 720)
	_tap(KEY_ESCAPE)
	assert_null(_desktop._confirmation)
	assert_eq(_desktop._quick_commands._pending_token, "")
	assert_true(backup.action_buttons["save"].has_focus(),
		"Cancel restores the semantic dock focus after real locale/text-size reflow and resize")
	assert_false(_port.commit_action(token).get("ok", false), "cancelled consent cannot replay")
	assert_eq(_manager._journal.capture_state(), journal)
	assert_eq(_backup_presentation(), before)


func test_confirmed_f9_load_runs_the_real_eight_participant_restore_graph() -> void:
	_seed_quick()
	assert_ne(str(_game_state.capture_restore_state().value.backup.lifecycle.run_id), "fixture-run-1")
	_tap(KEY_F9)
	var sheet: Control = _desktop._confirmation
	assert_not_null(sheet)
	if sheet == null: return
	sheet.confirm_button.grab_focus()
	_tap(KEY_ENTER)
	assert_true(_desktop._quick_commands.last_result.get("ok", false),
		JSON.stringify(_desktop._quick_commands.last_result))
	assert_eq(str(_game_state.capture_restore_state().value.backup.lifecycle.run_id), "fixture-run-1",
		"the production RunRestoreParticipant applied the selected Quick snapshot")
	assert_eq(_manager.get_latest_stable_checkpoint().value.bundle.snapshot.active_app_id, "backup")


func test_changed_capture_after_f9_prepare_cancels_without_restore_or_replay() -> void:
	_seed_quick()
	var run_before: Dictionary = _game_state.capture_restore_state().duplicate(true)
	_tap(KEY_F9)
	assert_not_null(_desktop._confirmation)
	var token: String = _desktop._quick_commands._pending_token
	_source.inputs.content_version = 2
	_desktop._confirmation.confirm_button.grab_focus()
	_tap(KEY_ENTER)
	assert_null(_desktop._confirmation)
	assert_eq(_desktop._quick_commands._pending_token, "")
	assert_eq(_game_state.capture_restore_state(), run_before)
	assert_false(_port.commit_action(token).get("ok", false), "changed-source consent is consumed")


func test_source_admission_lost_inside_prepare_cancels_the_real_owner_token() -> void:
	assert_false(_storage.exists("quicksave.json"))
	_source.after_capture = func() -> void:
		_source.after_capture = Callable()
		_desktop_admitted = false
	_tap(KEY_F5)
	assert_false(_storage.exists("quicksave.json"), "a prepared save never commits after source custody changes")
	assert_eq(_desktop._quick_commands._pending_token, "")
	assert_null(_desktop._confirmation)
	assert_true(_manager._backup_actions.is_empty(), "the prepared owner token was cancelled")


func test_profile_rebound_keyboard_and_controller_drive_the_same_real_commands() -> void:
	_rebind("game_quick_save", "keyboard", {"kind": "key", "physical_keycode": KEY_F6,
		"keycode": 0, "shift": false, "alt": false, "ctrl": false, "meta": false})
	_tap(KEY_F5)
	assert_false(_storage.exists("quicksave.json"), "the replaced physical key is inert")
	_tap(KEY_F6)
	assert_true(_storage.exists("quicksave.json"))
	_rebind("game_quick_load", "controller", {"kind": "joypad_button",
		"button_index": JOY_BUTTON_PADDLE1, "device": -1})
	_tap_joy(JOY_BUTTON_RIGHT_STICK)
	assert_null(_desktop._confirmation, "the replaced controller button is inert")
	_tap_joy(JOY_BUTTON_PADDLE1)
	assert_not_null(_desktop._confirmation)
	_tap(KEY_ESCAPE)


func test_duplicate_echo_and_pause_held_contact_do_not_repeat_quick_save() -> void:
	_viewport.push_input(_key(KEY_F5, true), true)
	var first: Dictionary = _storage.inspect_revision("quicksave.json")
	assert_true(first.ok)
	_viewport.push_input(_key(KEY_F5, true), true)
	var echo := _key(KEY_F5, true)
	echo.echo = true
	_viewport.push_input(echo, true)
	assert_eq(_storage.inspect_revision("quicksave.json"), first,
		"duplicate and echo packets cannot create a second edge")
	_viewport.push_input(_key(KEY_F5, false), true)
	var handle := {"generation": 1, "handle_id": "quick-input-pause", "holder": &"pause",
		"reason": &"universal_pause"}
	assert_true(_input.begin_suspend(handle).ok)
	_viewport.push_input(_key(KEY_F5, true), true)
	assert_true(_input.resume(handle).ok)
	_viewport.push_input(_key(KEY_F5, true), true)
	assert_eq(_storage.inspect_revision("quicksave.json"), first,
		"a held source remains quarantined when custody returns")
	_viewport.push_input(_key(KEY_F5, false), true)
	await get_tree().process_frame
	_tap(KEY_F5)
	assert_ne(_storage.inspect_revision("quicksave.json"), first,
		"a later neutral, fresh contact is admitted")


func test_existing_backup_confirmation_and_token_are_not_displaced_by_f5() -> void:
	_seed_quick()
	var backup: Control = _desktop._cached_app_windows[&"backup"]
	backup._set_mode("load")
	backup._select_drawer("quick")
	backup._action_pressed("load")
	var sheet: Control = _desktop._confirmation
	var token: String = str(backup._pending_token)
	assert_not_null(sheet)
	assert_false(token.is_empty())
	_tap(KEY_F5)
	assert_same(_desktop._confirmation, sheet)
	assert_eq(str(backup._pending_token), token)
	assert_eq(_desktop._quick_commands._pending_token, "")
	_tap(KEY_ESCAPE)
	assert_null(_desktop._confirmation)


func test_f5_status_survives_same_frame_entry_when_bound_to_the_new_backup_source() -> void:
	assert_true(_desktop.return_home().ok)
	await get_tree().process_frame
	assert_eq(_desktop._quick_commands._observed_source.app, "")
	assert_true(_desktop.open_app(&"backup").ok)
	_tap(KEY_F5)
	assert_eq(_desktop._quick_commands.edge.key, &"saved")
	await get_tree().process_frame
	assert_eq(_desktop._quick_commands.edge.key, &"saved",
		"source observation does not clear a status already bound to the entered Backup source")


func test_backup_recovery_entered_inside_prepare_cancels_the_new_quick_token() -> void:
	var backup: Control = _desktop._cached_app_windows[&"backup"]
	_source.after_capture = func() -> void:
		_source.after_capture = Callable()
		backup._recovering = true
	_tap(KEY_F5)
	assert_false(_storage.exists("quicksave.json"))
	assert_eq(_desktop._quick_commands._pending_token, "")
	assert_true(_manager._backup_actions.is_empty())
	backup._recovering = false
func test_inherited_focus_custody_blocks_quick_input_and_explicit_desktop_override_admits_it() -> void:
	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(wrapper)
	_desktop.reparent(wrapper)
	wrapper.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_desktop.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_tap(KEY_F5)
	assert_false(_storage.exists("quicksave.json"),
		"an injected source callback cannot override the inherited higher focus custody")
	_desktop.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	_tap(KEY_F5)
	assert_true(_storage.exists("quicksave.json"),
		"the closest explicit desktop override restores its admitted focus subtree")


func test_contacts_refusal_and_real_load_consent_preserve_live_app_and_focus() -> void:
	_seed_quick()
	var revision: Dictionary = _storage.inspect_revision("quicksave.json")
	_source.available = false # The production capture boundary only accepts Backup.
	assert_true(_desktop.return_home().ok)
	assert_true(_desktop.open_app(&"contacts").ok)
	await get_tree().process_frame
	var app: Control = _desktop._cached_app_windows[&"contacts"]
	var focused: Control = app.contacts_panel.rows[0]
	focused.grab_focus()
	_tap(KEY_F5)
	assert_eq(_desktop._quick_commands.edge.key, &"unavailable")
	assert_true(_desktop._quick_commands.edge.visible)
	assert_same(_viewport.gui_get_focus_owner(), focused)
	assert_eq(_storage.inspect_revision("quicksave.json"), revision)
	_tap(KEY_F9)
	var sheet: Control = _desktop._confirmation
	assert_not_null(sheet, "Load remains available through the real owner despite capture refusal")
	if sheet == null: return
	assert_true(sheet.cancel_button.has_focus(), "Replacement consent starts on Cancel")
	var token: String = _desktop._quick_commands._pending_token
	_tap(KEY_ESCAPE)
	assert_null(_desktop._confirmation)
	assert_false(_port.commit_action(token).get("ok", false))
	assert_eq(_host.get_state().active_app_id, &"contacts")
	assert_true(app.is_visible_in_tree())
	assert_same(_viewport.gui_get_focus_owner(), focused)
	assert_eq(_storage.inspect_revision("quicksave.json"), revision)


func test_live_app_custody_precedes_quick_and_reserved_status_stays_outside_content() -> void:
	assert_true(_desktop.return_home().ok)
	_source.available = false
	for app_id: StringName in [&"settings", &"schedule", &"shop"]:
		var app := AppCustody.new()
		_desktop.app_window_host.add_child(app)
		_desktop._cached_app_windows[app_id] = app
		assert_true(_host.open_app(app_id, 1).ok)
		_desktop._active_id = app_id
		_desktop.icon_grid.hide()
		_desktop._refresh_app_scroll()
		await get_tree().process_frame
		app.grab_focus()
		app.departure_allowed = false
		_desktop._quick_commands.last_result = {}
		_viewport.push_input(_key(KEY_F5, true), true)
		assert_true(_desktop._quick_commands.last_result.is_empty(), str(app_id))
		assert_gt(app.gui_packets, 0, "A denied Quick packet reaches its capture/modal owner")
		app.departure_allowed = true
		_viewport.push_input(_key(KEY_F5, true), true)
		assert_true(_desktop._quick_commands.last_result.is_empty(), "A held packet cannot replay after custody returns")
		_viewport.push_input(_key(KEY_F5, false), true)
		_tap(KEY_F5)
		assert_eq(_desktop._quick_commands.edge.key, &"unavailable", str(app_id))
		assert_true(_desktop._quick_commands.edge.visible)
		var rect: Rect2 = _desktop.quick_status_safe_rect()
		assert_true(rect.has_area())
		assert_lte(_desktop.app_scroll.get_rect().end.y, rect.position.y)
		assert_lte(_desktop.app_scroll_rail.get_rect().end.y, rect.position.y)
		assert_lte(rect.end.y, _desktop.desktop_canvas.size.y - 64)
		var viewport_rect: Rect2 = _desktop.app_scroll.get_rect()
		_desktop._quick_commands.edge.clear_status()
		assert_eq(_desktop.app_scroll.get_rect(), viewport_rect, "Expiry never rearranges the app's focused controls")
		app.hide()
		assert_true(_host.close_app().ok)
		_desktop._active_id = &""
		_desktop._cached_app_windows.erase(app_id)
		app.queue_free()


func test_contacts_notification_suppresses_status_until_eligible_without_repeating_it() -> void:
	_source.available = false
	assert_true(_desktop.return_home().ok)
	assert_true(_desktop.open_app(&"contacts").ok)
	await get_tree().process_frame
	var edge: Label = _desktop._quick_commands.edge
	edge.set_process(false)
	watch_signals(edge)
	_desktop.message_notification.show()
	_tap(KEY_F5)
	assert_eq(edge.key, &"unavailable")
	assert_false(edge.visible)
	var remaining: float = edge.remaining_seconds
	edge.advance_eligible_time(10.0)
	assert_eq(edge.remaining_seconds, remaining)
	assert_signal_not_emitted(edge, "status_announced")
	_desktop.message_notification.hide()
	_desktop._quick_commands._process(0.0)
	assert_true(edge.visible)
	assert_signal_emit_count(edge, "status_announced", 1)
	_tap(KEY_F5)
	assert_signal_emit_count(edge, "status_announced", 1)
	assert_eq(edge.remaining_seconds, remaining)
	_desktop.delivery_notice.show()
	_desktop._quick_commands._process(0.0)
	assert_false(edge.visible, "Delivery copy has the same protected-text priority")


func test_quick_saved_modifier_binding_rejects_unrelated_held_keys() -> void:
	_rebind("game_quick_save", "keyboard", {"kind": "key", "physical_keycode": KEY_F6,
		"keycode": 0, "shift": true, "alt": false, "ctrl": false, "meta": false})
	var modified := _key(KEY_F6, true)
	modified.shift_pressed = true
	_viewport.push_input(_key(KEY_F7, true), true)
	_viewport.push_input(_key(KEY_SHIFT, true), true)
	_viewport.push_input(modified, true)
	assert_false(_storage.exists("quicksave.json"))
	_viewport.push_input(_key(KEY_F6, false), true)
	_viewport.push_input(_key(KEY_SHIFT, false), true)
	_viewport.push_input(_key(KEY_F7, false), true)
	_viewport.push_input(_key(KEY_SHIFT, true), true)
	_viewport.push_input(modified, true)
	assert_true(_storage.exists("quicksave.json"), JSON.stringify(_desktop._quick_commands.last_result))
	_viewport.push_input(_key(KEY_F6, false), true)
	_viewport.push_input(_key(KEY_SHIFT, false), true)


func test_focus_out_and_in_before_a_frame_consumes_quick_load_consent() -> void:
	_seed_quick()
	var focused := _viewport.gui_get_focus_owner()
	_tap(KEY_F9)
	assert_not_null(_desktop._confirmation)
	var token: String = _desktop._quick_commands._pending_token
	_desktop._quick_commands.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_desktop._quick_commands.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_null(_desktop._confirmation)
	assert_eq(_desktop._quick_commands._pending_token, "")
	assert_false(_port.commit_action(token).get("ok", false))
	await get_tree().process_frame
	assert_same(_viewport.gui_get_focus_owner(), focused)


func test_focused_live_minesweeper_gets_owner_refusal_and_load_consent_without_board_actions() -> void:
	_seed_quick()
	assert_true(_desktop.return_home().ok)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(preload("res://tests/support/FakeDesktopIssuerRootStore.gd").new("42".repeat(32), 1)).ok)
	var state_port := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd").new()
	assert_true(state_port.configure(_game_state, issuer, {"run_id": "private-run", "branch_id": "private-branch",
		"desktop_timeline_generation": 0, "causal_day_instance": "private-day"}).ok)
	var generation := preload("res://tests/support/FakeMinesweeperGenerationPort.gd").new()
	generation.arm_materialize({"schema_version": 1, "width": 8, "height": 8,
		"mine_indices": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "mine_count": 10})
	var coordinator := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd").new()
	assert_true(coordinator.configure(state_port, preload("res://tests/support/FakeMinesweeperCheckpointPort.gd").new(), generation, issuer).ok)
	var port := preload("res://scripts/application/minesweeper/MinesweeperPanelPort.gd").new()
	assert_true(port.configure(coordinator, issuer, _game_state, preload("res://scripts/data/DataCatalog.gd").new()).ok)
	assert_true(_desktop.configure_minesweeper(port, _localization, _profile, _host, 1, _input).ok)
	assert_true(_desktop.open_app(&"minesweeper").ok)
	await get_tree().process_frame
	var app: Control = _desktop._cached_app_windows[&"minesweeper"]
	var grid: Control = app.panel.worksheet.grid
	assert_true(grid.focus_cell(0))
	watch_signals(grid)
	var board: Dictionary = coordinator.get_state().duplicate(true)
	_source.available = false
	_tap(KEY_F5)
	assert_eq(_desktop._quick_commands.edge.key, &"unavailable")
	assert_true(_desktop._quick_commands.edge.visible)
	assert_true(grid.has_focus())
	_tap(KEY_F9)
	assert_not_null(_desktop._confirmation)
	if _desktop._confirmation == null: return
	assert_true(_desktop._confirmation.cancel_button.has_focus())
	_tap(KEY_ESCAPE)
	assert_true(grid.has_focus())
	assert_eq(grid.focused_index, 0)
	assert_eq(coordinator.get_state(), board)
	assert_signal_not_emitted(grid, "cell_action_requested")
	assert_signal_not_emitted(grid, "new_board_requested")
	assert_signal_not_emitted(grid, "mode_changed")
	var rect: Rect2 = _desktop.quick_status_safe_rect()
	assert_lte(_desktop.app_scroll.get_rect().end.y, rect.position.y)
