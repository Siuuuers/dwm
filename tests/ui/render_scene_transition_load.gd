extends "res://tests/ui/render_scene_transition_base.gd"

func test_fresh_process_load_restores_destination_without_transition() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(TRANSITION_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), int(proof.creator_process_id))
	if not _start_services(): return
	bridge.scene_transition_changed.connect(_on_transition_changed)
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending")
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	for frame: int in 6: await get_tree().process_frame
	assert_true(transition_events.is_empty(), "Load is a direct restoration, never an authored transition")
	assert_false(bridge.is_scene_transition_active())
	assert_null(get_tree().current_scene.transition_surface.texture)
	assert_eq(bridge._runtime_adapter.current_line_id(), TARGET_LINE)
	assert_false(_caption().caption_text.revealing)
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var compact: Dictionary = COMPACT_READING.project_player_checkpoint(checkpoint.value)
	if not _ok(compact): return
	assert_eq(compact.value, proof.checkpoint)
	assert_eq(game.capture_run_snapshot_input().gameplay, proof.gameplay)
	assert_eq(game.capture_run_snapshot_input().scene, proof.scene)
	assert_eq(profile.get_profile_snapshot(), proof.profile, "restoration repeats no read mark")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	await _screenshot("scene-transition-fresh-load")
	_write_json("res://.godot/ci/scene-transition-load.json", {"process_id": OS.get_process_id(),
		"creator_process_id": proof.creator_process_id, "slot_sha256": proof.slot_sha256})
	print("SCENE_TRANSITION_LOAD_COMPLETED")
