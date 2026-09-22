extends GutTest
## Actual Dating scene, InputManager, confirmation and BackupPresentationPort.
## The Backup owner below isolates token/restore outcomes; production capture proof
## is in test_active_dating_backup_capture, and durable restore has its existing suites.

const DATING := preload("res://scenes/dating/DatingScene.tscn")
const FIXTURE := preload("res://tests/unit/test_dating_physical_owner.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const BACKUP := preload("res://scripts/application/backup/BackupPresentationPort.gd")

class Session extends FIXTURE.State:
	var handle := {"active": true, "generation": 1, "run_id": "quick-dating-fixture", "owner_id": 42}
	func capture_live_session() -> Dictionary:
		return {"ok": true, "value": handle.duplicate(true)}

class Bridge extends RefCounted:
	var active := false
	func has_active_playback() -> bool: return active

class Physical extends FIXTURE.PORT:
	var calls: Array[String] = []
	func dispatch_physical(command: Dictionary, action: String, index: int, revision: int) -> Dictionary:
		calls.append(action)
		return super.dispatch_physical(command, action, index, revision)

class Saves extends RefCounted:
	var saved := 0
	var loaded := 0
	var revision := 1
	var sequence := 0
	var pending := {}
	var fail_load := false
	var on_load := Callable()
	func get_backup_save_capability() -> Dictionary: return {"enabled": true, "reason": ""}
	func inspect_backup(locator: String) -> Dictionary:
		return {"ok": true, "value": {"locator": locator, "revision": str(revision), "state": "occupied",
			"day": 3, "saved_time": "12:30", "fallback": false, "load_day": 3, "load_saved_time": "12:30",
			"reason": "", "loadable": true, "operation_allowed": true}}
	func get_backup_quick_capability(action: String) -> Dictionary:
		return {"ok": true, "value": {"enabled": true, "status_key": "",
			"condition": {"action": action, "revision": revision}}}
	func is_quick_condition_current(condition: Dictionary) -> bool:
		return condition.get("revision") == revision
	func prepare_quick_backup_action(action: String) -> Dictionary:
		var result := prepare_backup_action(action, "quick")
		result.value.condition = {"action": action, "revision": revision}
		return result
	func prepare_backup_action(action: String, locator: String) -> Dictionary:
		sequence += 1
		var token := "quick-fixture-%d" % sequence
		pending[token] = action
		return {"ok": true, "value": {"token": token, "record": inspect_backup(locator).value}}
	func commit_backup_action(token: String) -> Dictionary:
		if not pending.has(token): return {"ok": false, "code": &"stale_backup_action"}
		var action: String = pending[token]
		pending.erase(token)
		if action == "save":
			saved += 1
			return {"ok": true}
		loaded += 1
		if on_load.is_valid(): on_load.call()
		return {"ok": not fail_load, "code": &"fixture_compensated_load" if fail_load else &"ok"}
	func cancel_backup_action(token: String) -> void: pending.erase(token)

var _viewport: SubViewport
var _scene: Control
var _old_scene: Node
var _input: Node
var _profile: Node
var _session: Session
var _bridge: Bridge
var _saves: Saves
var _backup: RefCounted
var _physical: RefCounted
var _port: Physical
var _issuer: RefCounted
var _generation: RefCounted
var _dating_profile: RefCounted
var _maps := {}
var _destination: Control

func before_each() -> void:
	_old_scene = get_tree().current_scene
	_destination = null
	_maps.clear()
	for action: StringName in InputMap.get_actions():
		_maps[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_profile = PROFILE.new()
	add_child(_profile)
	assert_true(_profile.initialize(STORAGE.new("memory/dating-quick", FILES.new())).ok)
	_input = INPUT.new()
	add_child(_input)
	assert_true(_input.initialize(_profile).ok)
	_session = Session.new()
	_bridge = Bridge.new()
	_saves = Saves.new()
	_backup = BACKUP.new()
	assert_true(_backup.configure(_saves, "in_run", _admission).ok)
	_issuer = FIXTURE.ISSUER.new()
	assert_true(_issuer.configure(FIXTURE.STORE.new("84".repeat(32), 1)).ok)
	_generation = FIXTURE.GENERATION.new()
	var mines: Array = []
	for index in 36: mines.append(index)
	_generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18,
		"mine_indices": mines, "mine_count": 36})
	_dating_profile = FIXTURE.Profile.new()
	_physical = FIXTURE.OWNER.new()
	assert_true(_physical.configure(_issuer, _session, _dating_profile, _generation).ok)
	_port = Physical.new()
	assert_true(_port.configure(_issuer, _physical).ok)
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	var command: Dictionary = begun.value.presentation_command
	assert_true(_port.dispatch_physical(command, "continue", -1, 0).ok)
	_port.calls.clear()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child(_viewport)
	_scene = DATING.instantiate()
	assert_true(_scene.configure_presentation(_port, command).ok)
	assert_true(_scene.configure_presentation_services(_input).ok)
	assert_true(_scene.configure_quick_commands(_backup, _bridge, _session).ok)
	_viewport.add_child(_scene)
	get_tree().current_scene = _scene
	await get_tree().process_frame
	await get_tree().process_frame
	_scene.worksheet.grid.grab_focus()

func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _old_scene
	if is_instance_valid(_viewport): _viewport.free()
	if is_instance_valid(_destination): _destination.free()
	if is_instance_valid(_input): _input.free()
	if is_instance_valid(_profile): _profile.free()
	for action: StringName in InputMap.get_actions():
		if not _maps.has(action): InputMap.erase_action(action)
	for action: StringName in _maps:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _maps[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _maps[action].events: InputMap.action_add_event(action, event)

func _request() -> Dictionary:
	var context := {"kind": "solo", "day": 3, "schedule_entry_id": "quick-fixture",
		"participants": ["sylvia"]}
	var root: Dictionary = _issuer.issue(&"transaction_id").value.issuer_receipt
	var request := {"resolution_id": "quick-fixture", "resolution_issuer_receipt": root,
		"stage_id": "execute_dates", "substage_id": "quick-date", "route_id": "dating",
		"timeline_id": "dating.solo.sylvia.day3.pre_challenge", "context": context,
		"completion_transaction_id": "", "completion_transaction_provenance": {}}
	var sources: Array = []
	for key: String in ["resolution_id", "stage_id", "substage_id", "route_id", "timeline_id"]:
		sources.append(key + "=" + str(FIXTURE.CANONICAL.canonical_json(request[key]).value.text))
	sources.append("role=" + str(FIXTURE.CANONICAL.canonical_json("presentation.completion").value.text))
	sources.append("context_sha256=" + str(FIXTURE.CANONICAL.canonical_json(FIXTURE.CANONICAL.canonical_sha256(context).value.sha256).value.text))
	sources.sort()
	var child: Dictionary = _issuer.derive_child({"parent_receipt_id": root.receipt_id,
		"child_kind": FIXTURE.PORT.COMPLETION_CHILD_KIND, "ordinal": 0, "source_ids": sources})
	assert_true(child.ok)
	request.completion_transaction_id = child.value.child_id
	request.completion_transaction_provenance = child.value.provenance
	return request

func _admission() -> Dictionary:
	return {"ok": not _bridge.active and _session.handle.active}

func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	_viewport.push_input(event, true)

func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)

func _quick() -> Node: return _scene._quick_commands

func _paint_terminal() -> void:
	_scene._dispatch_action("reveal", 323)
	assert_true(_scene._physical_view.board.terminal)
	assert_eq(_session.saved.phase, "challenge")
	_port.calls.clear()

func test_save_uses_shared_owner_without_pause_or_focus_move_and_quarantines_repeat() -> void:
	var focus := _viewport.gui_get_focus_owner()
	_key(KEY_F5, true)
	assert_eq(_saves.saved, 1)
	assert_false(get_tree().paused)
	assert_null(_scene._confirmation)
	assert_same(_viewport.gui_get_focus_owner(), focus)
	assert_eq(_quick().edge.key, &"saved")
	assert_eq(_quick().edge.focus_mode, Control.FOCUS_NONE)
	_key(KEY_F5, true, true)
	_key(KEY_F5, true)
	assert_eq(_saves.saved, 1)
	_key(KEY_F5, false)
	_tap(KEY_F5)
	assert_eq(_saves.saved, 2)

func test_load_consent_freezes_real_terminal_settlement_and_cancel_keeps_source() -> void:
	_paint_terminal()
	var before := _session.saved.duplicate(true)
	var focus := _viewport.gui_get_focus_owner()
	_tap(KEY_F9)
	assert_not_null(_scene._confirmation)
	assert_false(get_tree().paused)
	_scene._process(1.0)
	_scene._dispatch_action("settle", -1)
	assert_eq(_port.calls, [])
	assert_eq(_session.saved, before)
	assert_eq(_session.applications, 0)
	assert_eq(_saves.loaded, 0)
	_tap(KEY_ESCAPE)
	assert_null(_scene._confirmation)
	assert_true(_saves.pending.is_empty())
	assert_eq(_session.saved, before)
	assert_same(_viewport.gui_get_focus_owner(), focus)
	_scene._process(0.0)
	assert_eq(_session.applications, 1, "automatic settlement resumes after consent is cancelled")

func test_confirmation_held_close_contact_cannot_become_quick_or_story_input() -> void:
	_tap(KEY_F9)
	_key(KEY_ESCAPE, true)
	assert_null(_scene._confirmation)
	assert_false(_scene._phase_input_released(), "the consumed Cancel press remains in the physical ledger")
	_key(KEY_F5, true)
	assert_eq(_saves.saved, 0)
	_key(KEY_ESCAPE, false)
	_key(KEY_F5, true)
	assert_eq(_saves.saved, 0, "a blocked held Quick contact cannot revive after Cancel release")
	_key(KEY_F5, false)
	_tap(KEY_F5)
	assert_eq(_saves.saved, 1)

func test_target_or_live_session_change_cancels_existing_load_consent() -> void:
	_tap(KEY_F9)
	_saves.revision += 1
	_quick()._process(0.25)
	assert_null(_scene._confirmation)
	assert_true(_saves.pending.is_empty())
	assert_eq(_saves.loaded, 0)
	_tap(KEY_F9)
	_session.handle.generation += 1
	_quick()._process(0.0)
	assert_null(_scene._confirmation)
	assert_true(_saves.pending.is_empty())
	assert_eq(_saves.loaded, 0)

func test_focus_loss_cancels_consent_even_if_focus_returns_before_next_frame() -> void:
	var focus := _viewport.gui_get_focus_owner()
	_tap(KEY_F9)
	_quick()._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_quick()._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_quick()._process(0.0)
	assert_null(_scene._confirmation)
	assert_true(_saves.pending.is_empty())
	assert_eq(_saves.loaded, 0)
	assert_same(_viewport.gui_get_focus_owner(), focus)

func test_compensated_load_failure_keeps_source_focus_and_freezes_commit_callbacks() -> void:
	_paint_terminal()
	var before := _session.saved.duplicate(true)
	var focus := _viewport.gui_get_focus_owner()
	_saves.fail_load = true
	_saves.on_load = func() -> void: _scene._process(0.0)
	_tap(KEY_F9)
	var sheet: Control = _scene._confirmation
	assert_not_null(sheet)
	if sheet == null: return
	sheet._finish(true)
	assert_eq(_saves.loaded, 1)
	assert_eq(_session.saved, before)
	assert_eq(_port.calls, [])
	assert_true(_saves.pending.is_empty())
	assert_eq(_quick().edge.key, &"unavailable")
	assert_same(_viewport.gui_get_focus_owner(), focus)
	assert_false(get_tree().paused)

func test_successful_load_never_reclaims_destination_focus() -> void:
	_saves.on_load = func() -> void:
		_destination = Button.new()
		_destination.size = Vector2(100, 50)
		_viewport.add_child(_destination)
		get_tree().current_scene = _destination
		_destination.grab_focus()
	_tap(KEY_F9)
	var sheet: Control = _scene._confirmation
	assert_not_null(sheet)
	if sheet == null: return
	sheet._finish(true)
	assert_eq(_saves.loaded, 1)
	assert_true(_saves.pending.is_empty())
	assert_same(_viewport.gui_get_focus_owner(), _destination)
	assert_same(get_tree().current_scene, _destination)

func test_active_narrative_refuses_both_commands_without_empty_checkpoint_or_pause() -> void:
	_bridge.active = true
	_tap(KEY_F5)
	_tap(KEY_F9)
	assert_eq(_saves.saved, 0)
	assert_eq(_saves.loaded, 0)
	assert_true(_saves.pending.is_empty())
	assert_null(_scene._confirmation)
	assert_false(get_tree().paused)
	assert_eq(_quick().last_result.get("code"), &"backup_action_unavailable")

func test_rules_focus_and_reserved_status_band_do_not_overlap_the_gameplay_host() -> void:
	_scene.worksheet.open_rules(_scene._rules_button)
	_scene._refresh_mode_controls()
	var row: Control = _scene.worksheet.information_sheet.rows[0]
	row.grab_focus()
	_tap(KEY_F5)
	assert_same(_viewport.gui_get_focus_owner(), row)
	var status: Rect2 = _scene.quick_status_safe_rect()
	assert_true(status.has_area())
	assert_gte(status.position.y, _scene._challenge_content.position.y + _scene._challenge_content.size.y)
	assert_eq(_quick().edge.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_missing_physical_board_has_no_revision_without_a_nil_method_call() -> void:
	var before: Dictionary = _scene._physical_view.duplicate(true)
	for board: Variant in [null, {}]:
		_scene._physical_view["board"] = board
		assert_eq(_quick()._source_snapshot().revision, -1)
	_scene._physical_view = before
