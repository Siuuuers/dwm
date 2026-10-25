extends "res://tests/integration/scene_seven_day_connected_child.gd"
## Third rendered process: restore the ordinary final passage saved by the week loader.
const TERMINAL_PROOF := "user://scene-seven-day-ending-proof.json"
const TERMINAL_SLOT := "user://saves/slot_2.json"
const TERMINAL_LINE := "line.ending.alone.normal.one"

func load_saved_terminal_line() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(TERMINAL_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id, "passage Load uses a fresh OS process")
	assert_eq(ProjectSettings.globalize_path("user://"), proof.user_dir)
	assert_eq(FileAccess.get_sha256(TERMINAL_SLOT), proof.slot_sha256)
	assert_eq(proof.snapshot.lifecycle.state, "PLAYING")
	assert_false(proof.snapshot.lifecycle.has("ending_plan"))
	var expanded: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(proof.checkpoint)
	if not _ok(expanded): return
	assert_eq(expanded.value.stage, "scene")
	assert_eq(expanded.value.reading_session.schema_version, 5)
	assert_eq(expanded.value.reading_session.ledger.frozen_context.family, "scene")
	assert_eq(expanded.value.reading_session.boundary, "line")
	assert_eq(expanded.value.reading_session.frontier.line_id, TERMINAL_LINE)
	for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_false(proof.snapshot.has(key), "current player save omits " + key)
	if not _start_services(): return
	# The preceding process completed this Run and started another. Load must not
	# rewind global discovery or replay the passage's Finish.
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var profile_hash := FileAccess.get_sha256("user://profile.json")
	var slot1_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	var gallery_id := "passage:%s:gallery:%s" % [str(proof.snapshot.lifecycle.run_id), PASSAGE_ID]
	assert_true(profile_before.gallery_transaction_receipts.has(gallery_id))
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return
	saves.live_session_ready.connect(func() -> void: _ready_observation = _native_observation())
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:2")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	assert_eq(ready_count, 1, "passage activation publishes exactly one Ready")
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	assert_eq(_ready_observation.line_id, TERMINAL_LINE)
	assert_true(_ready_observation.visible)
	assert_false(_ready_observation.revealing)
	assert_eq(float(_ready_observation.visible_ratio), 1.0)
	assert_true(_ready_observation.event_done)
	assert_eq(_ready_observation.text.strip_edges(), "TEST Seven-day ending.")
	assert_eq(_ready_observation.ledger, expanded.value.reading_session.ledger, "Load creates no publication")
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_eq(reading.value, expanded.value, "Load restores the current frame and native frontier")
	var restored: Dictionary = game.capture_run_snapshot_input()
	assert_eq(restored.lifecycle.run_id, proof.snapshot.lifecycle.run_id)
	assert_ne(restored.lifecycle.branch_id, proof.snapshot.lifecycle.branch_id)
	assert_eq(restored.lifecycle.state, "PLAYING", "restoring the final caption does not execute Finish")
	for key: String in ["gameplay", "scene"]:
		assert_eq(restored[key], proof.snapshot[key], "Load preserves " + key)
	assert_true(restored.command_receipts.is_empty(), "Load starts a fresh command session")
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(FileAccess.get_sha256("user://profile.json"), profile_hash)
	assert_eq(FileAccess.get_sha256(TERMINAL_SLOT), proof.slot_sha256)
	await _screenshot("seven-day-terminal-restored-full")
	await _accept()
	if not await _wait_route(MENU): return
	var finished: Dictionary = game._run_lifecycle.to_dict()
	assert_eq(finished.state, "COMPLETED")
	assert_false(finished.has("ending_plan"))
	assert_false(game.capture_live_session().value.active)
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts,
		profile_before.gallery_transaction_receipts, "Finish reuses the existing global passage discovery")
	var durable: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(durable): return
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.state, "COMPLETED")
	assert_false(durable.value.current_snapshot.snapshot.lifecycle.has("ending_plan"))
	assert_eq(FileAccess.get_sha256(TERMINAL_SLOT), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot1_hash)
	await _screenshot("seven-day-terminal-restored-completed-title")
	# Gallery replays this same ordinary passage without dispatching gameplay.
	var menu: Node = get_tree().current_scene
	await _click(menu._gallery_button)
	var gallery: Node = menu._gallery_instance
	assert_not_null(gallery)
	if gallery == null: return
	var tile: Button = null
	for row: Button in gallery._ending_tile_grid.get_children():
		if row.get_meta(&"gallery_record_id") == PASSAGE_ID: tile = row
	assert_not_null(tile)
	if tile == null: return
	await _click(tile)
	assert_eq(gallery._selected_id, PASSAGE_ID)
	assert_false(gallery._replay_button.disabled)
	var run_before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var global_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var autosave_hash := FileAccess.get_sha256("user://saves/autosave.json")
	profile_hash = FileAccess.get_sha256("user://profile.json")
	var owner: RefCounted = gallery._replay_owner
	var finishes: Array = []
	owner.playback_finished.connect(func(result: Dictionary): finishes.append(result))
	await _click(gallery._replay_button)
	assert_true(owner.is_playing())
	if not owner.is_playing(): return
	for frame: int in 5: await get_tree().process_frame
	assert_eq(bridge._reached_replay.card.receipt.line_id, TERMINAL_LINE)
	var surface: Node = bridge._reached_replay.surface
	assert_true(surface._current_body.is_visible_in_tree())
	assert_eq(surface._current_body.text, "TEST Seven-day ending.")
	await _screenshot("seven-day-passage-gallery-replay")
	await _click(surface._next)
	assert_eq(finishes.size(), 1)
	assert_true(bridge._reached_replay.is_empty())
	assert_eq(game.capture_run_snapshot_input(), run_before)
	assert_eq(profile.get_profile_snapshot(), global_before)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), autosave_hash)
	assert_eq(FileAccess.get_sha256("user://profile.json"), profile_hash)
	_write_json("res://.godot/ci/scene-seven-day-terminal-load-proof.json", {
		"loader_process_id": OS.get_process_id(), "creator_process_id": proof.process_id,
		"ready_native": _ready_observation, "restored_checkpoint": reading.value,
		"restored_lifecycle": restored.lifecycle, "completed_lifecycle": finished,
		"gallery_receipts": profile.get_profile_snapshot().gallery_transaction_receipts,
		"gallery_replay_unchanged": true, "ready_count": ready_count,
		"preserved_slot_sha256": proof.slot_sha256})
