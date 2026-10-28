extends "res://tests/integration/scene_seven_day_connected_child.gd"
## Separate rendered processes, real FINAL owners, native input and physical slots.
const PARTNER := preload("res://tests/support/ScenePartnerForkFixture.gd")
const WRITE_REFUSAL := preload("res://tests/support/ScenePlayableFixture.gd")
const OFFER := "line.scene.test.partner.shared.offer"

func _install_content_registration() -> Dictionary:
	return PARTNER.install()

func _open_partner_backup(command: String) -> Node:
	var caption: Node = _caption()
	var button: Button = _controls(get_tree().current_scene, command)
	var deadline := Time.get_ticks_msec() + 5000
	var admission := "_save_admitted" if command == "Save" else "_load_admitted"
	# Native text DONE precedes the rail's next presentation/admission update.
	while Time.get_ticks_msec() < deadline:
		if button.is_visible_in_tree() and not button.disabled and caption.call(admission): break
		await get_tree().process_frame
	assert_true(button.is_visible_in_tree() and not button.disabled and caption.call(admission), command + " is ready for real input")
	if not button.is_visible_in_tree() or button.disabled or not caption.call(admission): return null
	await _click(button)
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	deadline = Time.get_ticks_msec() + 5000
	while sheet._backup_port == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_not_null(sheet._backup_port, command + " mounts the real Backup port")
	if sheet._backup_port == null:
		await _screenshot("partner-backup-open-failed")
		return null
	return sheet

func _save_partner(slot: int) -> bool:
	var sheet: Node = await _open_partner_backup("Save")
	if sheet == null: return false
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:" + str(slot))
	if not _ok(prepared): return false
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return false
	sheet.surface.leave_host()
	for frame: int in 4: await get_tree().process_frame
	return true

func _load_partner(slot: int, initial: bool = false) -> bool:
	var backup: RefCounted
	if initial:
		backup = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
		if not _ok(backup.configure(saves, "title")): return false
	else:
		var sheet: Node = await _open_partner_backup("Load")
		if sheet == null: return false
		backup = sheet._backup_port
	var prepared: Dictionary = backup.prepare_action("load", "slot:" + str(slot))
	if not _ok(prepared): return false
	var count := ready_count
	var loaded: Dictionary = await backup.commit_action(prepared.value.token)
	assert_true(loaded.get("ok", false) or loaded.get("code") == &"scene_activation_pending", str(loaded))
	if not loaded.get("ok", false) and loaded.get("code") != &"scene_activation_pending": return false
	var deadline := Time.get_ticks_msec() + 20000
	while ready_count == count and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	assert_eq(ready_count, count + 1)
	return ready_count == count + 1

func create_partner() -> void:
	if not _start_services(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var started: Dictionary = saves.start_scene_new_run("partner.shared", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if not await _await_ready(): return
	if not await _wait_line("line.scene.test.partner.shared.before"): return
	assert_true(game.scene_choices.is_empty(), "NewRun has no partner")
	assert_false(game.accept_scene_thought(bridge.capture_current_line_presentation_frontier()).ok)
	await _accept()
	if not await _wait_line(OFFER): return
	if not await _save_partner(1): return
	var stale: Dictionary = bridge.capture_current_line_presentation_frontier()
	var caption: Node = _caption()
	await caption._on_history_requested()
	assert_true(caption._history_open)
	assert_false(game.accept_scene_thought(stale).ok, "History cannot resolve the live offer")
	assert_true(game.scene_choices.is_empty())
	await caption._on_history_close_requested()
	for frame: int in 4: await get_tree().process_frame
	var host: Control = get_tree().current_scene
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	assert_false(game.accept_scene_thought(stale).ok)
	assert_false(bridge.request_auto_step(stale).ok)
	assert_true(game.scene_choices.is_empty())
	await _click(_controls(host, "CheckComputer"))
	for frame: int in 12: await get_tree().process_frame
	var yes: Button = host.get_node("SceneControlsLayer/Surface/ThoughtYes")
	assert_true(yes.is_visible_in_tree())
	await _screenshot("partner-offer")
	# Refuse the actual first autosave write: no choice or continuation may appear.
	var original_files: RefCounted = saves._storage._file_ops
	var refused = WRITE_REFUSAL.WriteRefusal.new()
	refused.refuse_on = 1
	saves._storage._file_ops = refused
	await _click(yes)
	assert_eq(refused.refused, 1)
	assert_true(game.scene_choices.is_empty())
	assert_eq(bridge._runtime_adapter.current_line_id(), OFFER)
	saves._storage._file_ops = original_files
	for frame: int in 12: await get_tree().process_frame
	yes.grab_focus()
	await get_tree().process_frame
	assert_true(yes.has_focus())
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		get_viewport().push_input(key, true)
		await get_tree().process_frame
	if not await _wait_line("line.scene.test.partner.sylvia.after"): return
	assert_eq(game.scene_choices.size(), 1)
	assert_eq(game.scene_choices["TEST.partner"], "yes")
	assert_eq(game.capture_run_snapshot_input().scene.entry_id, "scene.test.partner.sylvia")
	assert_false(game.accept_scene_thought(stale).ok)
	assert_false(game.accept_scene_thought({}).ok)
	assert_eq(game.scene_choices.size(), 1)
	if not await _save_partner(2): return
	await _screenshot("partner-sylvia")
	_write_json("user://partner-proof.json", {"pid": OS.get_process_id(), "unresolved": FileAccess.get_sha256("user://saves/slot_1.json"),
		"resolved": FileAccess.get_sha256("user://saves/slot_2.json"), "choices": game.scene_choices.duplicate(true)})

func load_partner_manual() -> void:
	var proof: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://partner-proof.json"))
	if not _ok(proof): return
	assert_ne(OS.get_process_id(), proof.value.pid)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.value.unresolved)
	if not _start_services() or not await _load_partner(1, true): return
	if not await _wait_line(OFFER): return
	assert_true(game.scene_choices.is_empty(), "earlier save remains unresolved after later Yes")
	await _accept()
	if not await _wait_line("line.scene.test.partner.lavinia.after"): return
	assert_eq(game.scene_choices.size(), 1)
	assert_eq(game.scene_choices["TEST.partner"], "pass")
	assert_eq(game.capture_run_snapshot_input().scene.entry_id, "scene.test.partner.lavinia")
	await _screenshot("partner-manual-lavinia")

func load_partner_auto() -> void:
	var proof: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://partner-proof.json"))
	if not _ok(proof): return
	assert_ne(OS.get_process_id(), proof.value.pid)
	if not _start_services() or not await _load_partner(2, true): return
	if not await _wait_line("line.scene.test.partner.sylvia.after"): return
	assert_eq(game.scene_choices.size(), 1)
	assert_eq(game.scene_choices, proof.value.choices, "resolved choice survives fresh Load exactly")
	var stale: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not await _load_partner(1): return
	if not await _wait_line(OFFER): return
	assert_true(game.scene_choices.is_empty())
	assert_false(game.accept_scene_thought(stale).ok, "pre-Load presentation cannot choose")
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", true)): return
	if not await _wait_line("line.scene.test.partner.lavinia.after"): return
	assert_eq(game.scene_choices.size(), 1)
	assert_eq(game.scene_choices["TEST.partner"], "pass")
	assert_true(profile.get_preference(&"preferences.reading.auto_enabled", false), "Auto continues normally")
	await _screenshot("partner-auto-lavinia")
