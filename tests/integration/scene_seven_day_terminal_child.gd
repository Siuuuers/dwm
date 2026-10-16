extends "res://tests/integration/scene_seven_day_connected_child.gd"
## Third rendered process: consume the real ending Save retained by the week loader.
const TERMINAL_PROOF := "user://scene-seven-day-ending-proof.json"
const TERMINAL_SLOT := "user://saves/slot_2.json"
const TERMINAL_LINE := "line.ending.alone.normal.one"

func load_saved_terminal_line() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(TERMINAL_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id, "ending Load uses a fresh OS process")
	assert_eq(ProjectSettings.globalize_path("user://"), proof.user_dir)
	assert_eq(FileAccess.get_sha256(TERMINAL_SLOT), proof.slot_sha256)
	assert_eq(proof.snapshot.lifecycle.state, "ENDING")
	assert_eq(proof.checkpoint.reading_session.family, "ending")
	assert_eq(proof.checkpoint.reading_session.boundary, "line")
	assert_eq(proof.checkpoint.reading_session.frontier.line_id, TERMINAL_LINE)
	if not _start_services(): return
	# The preceding process completed this run and started another. Current Profile
	# history is authoritative; restoring an older ending must not rewind it.
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var profile_hash := FileAccess.get_sha256("user://profile.json")
	var slot1_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	var gallery_id := "ending:%s:gallery:ending.alone" % str(proof.snapshot.lifecycle.run_id)
	assert_true(profile_before.gallery_transaction_receipts.has(gallery_id), "prior process physically completed this ending")
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return
	saves.live_session_ready.connect(func() -> void: _ready_observation = _native_observation())
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:2")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_true(loaded.get("ok", false) or loaded.get("code") == &"scene_activation_pending", str(loaded))
	if not loaded.get("ok", false) and loaded.get("code") != &"scene_activation_pending": return
	if not await _await_ready(): return
	assert_eq(ready_count, 1, "ending activation publishes exactly one Ready")
	assert_true(get_tree().current_scene is EndingScene, "Load mounts actual EndingScene")
	assert_eq(_ready_observation.line_id, TERMINAL_LINE)
	assert_true(_ready_observation.visible, "saved ending caption rendered at Ready")
	assert_false(_ready_observation.revealing, "saved ending line is fully revealed")
	assert_eq(float(_ready_observation.visible_ratio), 1.0)
	assert_true(_ready_observation.event_done, "native ending event is DONE")
	assert_eq(_ready_observation.text.strip_edges(), "TEST Seven-day ending.")
	assert_eq(_ready_observation.ledger, proof.checkpoint.reading_session.ledger, "Load creates no publication")
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_eq(reading.value, proof.checkpoint, "ending Load restores exact frozen frame and native frontier")
	var restored: Dictionary = game.capture_run_snapshot_input()
	assert_eq(restored.lifecycle.run_id, proof.snapshot.lifecycle.run_id)
	assert_ne(restored.lifecycle.branch_id, proof.snapshot.lifecycle.branch_id)
	assert_eq(restored.lifecycle.state, "ENDING")
	assert_eq(restored.lifecycle.ending_plan.next_step_index, 0, "restoring caption does not complete ending")
	for key: String in ["gameplay", "scene", "command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_eq(restored[key], proof.snapshot[key], "ending Load preserves " + key)
	assert_eq(profile.get_profile_snapshot(), profile_before, "ending Load preserves current history")
	assert_eq(FileAccess.get_sha256("user://profile.json"), profile_hash)
	assert_eq(FileAccess.get_sha256(TERMINAL_SLOT), proof.slot_sha256)
	# EndingScene adopts the restored reader only after publication releases custody.
	for frame: int in 8: await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	assert_true(scene is EndingScene)
	if not scene is EndingScene: return
	var command: Dictionary = scene.get_presentation_projection()
	assert_eq(command.get("kind"), "play_ending", "restored ending reader belongs to the real scene")
	assert_eq(command.get("ending_id"), "ending.alone")
	assert_eq(bridge.capture_reading_checkpoint(false).get("value"), proof.checkpoint, "adoption does not replay the caption")
	await _screenshot("seven-day-terminal-restored-full")
	await _accept()
	if not await _wait_route(MENU): return
	var finished: Dictionary = game._run_lifecycle.to_dict()
	assert_eq(finished.state, "COMPLETED")
	assert_eq(finished.ending_plan.next_step_index, 1, "one physical completion advances restored ending")
	assert_eq(finished.ending_plan.playback_stage, "GALLERY_RECORDED")
	assert_false(game.capture_live_session().value.active)
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts,
		profile_before.gallery_transaction_receipts, "replayed run ending reuses existing gallery transaction")
	var durable: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(durable): return
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.state, "COMPLETED")
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.ending_plan, finished.ending_plan)
	assert_eq(FileAccess.get_sha256(TERMINAL_SLOT), proof.slot_sha256, "completion preserves ending Save")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot1_hash)
	await _screenshot("seven-day-terminal-restored-completed-title")
	_write_json("res://.godot/ci/scene-seven-day-terminal-load-proof.json", {
		"loader_process_id": OS.get_process_id(), "creator_process_id": proof.process_id,
		"ready_native": _ready_observation, "restored_checkpoint": reading.value,
		"restored_lifecycle": restored.lifecycle, "completed_lifecycle": finished,
		"gallery_receipts": profile.get_profile_snapshot().gallery_transaction_receipts,
		"ready_count": ready_count, "preserved_slot_sha256": proof.slot_sha256})
