extends "res://tests/ui/render_self_talk_base.gd"
## Separate OS process: reopen the same physical slot through FINAL owners.

func test_fresh_process_load_restores_current_thought_and_empty_frame() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://self-talk-pair-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), int(proof.creator_process_id), "fresh OS process")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	for frame: int in 6: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.five")
	assert_eq(_history_ids(), proof.history_ids)
	var restored: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(restored): return
	var compact: Dictionary = COMPACT_READING.project_player_checkpoint(restored.value)
	if not _ok(compact): return
	assert_eq(compact.value, proof.checkpoint, "fresh process restores the same paired player position")
	assert_eq(bridge.capture_self_talk_presentation().value, proof.thoughts)
	var caption: Node = _caption()
	assert_false(caption.caption_text.revealing)
	assert_true(caption.self_talk.is_visible_in_tree())
	assert_eq(caption.self_talk.get_projection().visible_rows.size(), 1)
	assert_eq(caption.self_talk.get_projection().history_count, 1)
	assert_eq(profile.get_profile_snapshot(), proof.profile, "Load does not repeat Global read marks")
	assert_eq(game.capture_run_snapshot_input().gameplay, proof.gameplay, "Load replays no gameplay consequence")
	assert_eq(game.capture_run_snapshot_input().scene, proof.scene)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	await _capture_self_talk("fresh-process-restored-pair")
	await _click(caption.transport_rail.get_node("Load"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	prepared = sheet._backup_port.prepare_action("load", "slot:2")
	if not _ok(prepared): return
	ready_count = 0
	loaded = await sheet._backup_port.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	for frame: int in 6: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.six")
	assert_eq(_history_ids(), proof.empty_history_ids, "empty caption Load retains earlier thoughts in History")
	caption = _caption()
	assert_true(caption.self_talk.is_visible_in_tree())
	assert_eq(caption.self_talk.get_projection().visible_rows, [])
	assert_eq(bridge.capture_self_talk_presentation().value.rows, [])
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.empty_slot_sha256)
	await _capture_self_talk("fresh-process-empty-frame")
	_write_json("res://.godot/ci/self-talk-fresh-load.json", {"creator_process_id": proof.creator_process_id,
		"loader_process_id": OS.get_process_id(), "history_ids": proof.history_ids, "slot_sha256": proof.slot_sha256})
	print("SELF_TALK_FRESH_LOAD_COMPLETED creator=", proof.creator_process_id, " loader=", OS.get_process_id())
