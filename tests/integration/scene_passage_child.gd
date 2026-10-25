extends "res://tests/integration/scene_contacts_connected_child.gd"
## Three fresh processes share physical files; every advance uses Viewport input.
const PASSAGE_CONTENT := preload("res://tests/support/ScenePassageRegistrationFixture.gd")
const PASSAGE_ID := PASSAGE_CONTENT.PASSAGE_ID
const MENU := "res://scenes/menu/MenuScene.tscn"

class ProfileWriteRefusal extends "res://scripts/infrastructure/storage/FileOps.gd":
	var refused := 0
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if path.replace("\\", "/").ends_with("/profile.json.next"):
			refused += 1
			return {"ok": false, "code": &"TEST.profile_write_refused", "message": path}
		return super.write_bytes(path, bytes)

func _install_content_registration() -> Dictionary:
	return PASSAGE_CONTENT.new()._install_registration()

func _load_passage(locator: String) -> Dictionary:
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return {"ok": false}
	var prepared: Dictionary = backup.prepare_action("load", locator)
	if not _ok(prepared): return prepared
	return backup.commit_action(prepared.value.token)

func _wait_menu() -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == MENU: return true
		await get_tree().process_frame
	return _ok({"ok": false, "code": "TEST.passage_title_timeout"})

func create_passage_scene() -> void:
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	assert_false(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks)
	await _click(_caption().caption_text)
	if not await _wait_line("scene.test.a", "line.scene.test.a.two"): return
	assert_false(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks, "start marker never unlocks")
	if not await _save_slot(1): return
	await _screenshot("passage-first")
	await _click(_caption().caption_text)
	if not await _wait_line("scene.test.a", "line.scene.test.a.three"): return
	if not await _save_slot(2): return
	assert_false(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks, "last caption is still before finish")
	await _screenshot("passage-last-before-save")
	var proof := {"process_id": OS.get_process_id(), "slot_1_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"slot_2_sha256": FileAccess.get_sha256("user://saves/slot_2.json"),
		"reading": bridge.capture_reading_checkpoint(false).value.reading_session}
	if not _write_json("user://passage-proof.json", proof): return
	_write_json("res://.godot/ci/passage-connected-create-proof.json", proof)

func load_and_finish_passage_scene() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://passage-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.slot_2_sha256)
	if not _start_services(): return
	var loaded := _load_passage("slot:2")
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.three"): return
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	assert_eq(bridge.capture_reading_checkpoint(false).value.reading_session, proof.reading)
	assert_false(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks)
	await _screenshot("passage-last-fresh-load")
	var profile_files: RefCounted = profile._storage._file_ops
	var profile_fault := ProfileWriteRefusal.new()
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var profile_bytes := FileAccess.get_sha256("user://profile.json")
	var run_bytes := FileAccess.get_sha256("user://saves/autosave.json")
	profile._storage._file_ops = profile_fault
	await _click(_caption().transport_rail._next_button)
	profile._storage._file_ops = profile_files
	assert_eq(profile_fault.refused, 1)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(FileAccess.get_sha256("user://profile.json"), profile_bytes)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), run_bytes)
	assert_eq(game.capture_run_snapshot_input().lifecycle.state, "PLAYING")
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	assert_false(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks)
	assert_true(_caption().is_reading_recovery_active())
	await _screenshot("passage-profile-write-refused")
	var files: RefCounted = saves._storage._file_ops
	var fault := CONTENT.WriteRefusal.new()
	fault.refuse_on = 1
	saves._storage._file_ops = fault
	var before := FileAccess.get_sha256("user://saves/autosave.json")
	await _click(_caption().recovery_overlay.retry_button)
	saves._storage._file_ops = files
	assert_eq(fault.refused, 1)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), before)
	assert_true(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks, "global finish discovery survives failed Run write")
	assert_eq(game.capture_run_snapshot_input().lifecycle.state, "PLAYING")
	assert_eq(get_tree().current_scene.scene_file_path, HOST, "write refusal cannot retire the caption")
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.three")
	assert_true(_caption().is_reading_recovery_active())
	await _screenshot("passage-finish-retry")
	await _click(_caption().recovery_overlay.retry_button)
	if not await _wait_menu(): return
	assert_true(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks)
	var latest: Dictionary = saves.get_latest_stable_checkpoint()
	if not _ok(latest): return
	assert_eq(latest.value.bundle.snapshot.lifecycle.state, "COMPLETED")
	assert_false(latest.value.bundle.snapshot.lifecycle.has("ending_plan"))
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_1_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.slot_2_sha256)
	proof["finisher_process_id"] = OS.get_process_id()
	proof["completed_sha256"] = FileAccess.get_sha256("user://saves/autosave.json")
	if not _write_json("user://passage-proof.json", proof): return
	await _screenshot("passage-title-after-finish")
	_write_json("res://.godot/ci/passage-connected-load-proof.json", proof)

func replay_completed_passage_scene() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://passage-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_ne(OS.get_process_id(), proof.finisher_process_id)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), proof.completed_sha256)
	if not _start_services(): return
	var loaded := _load_passage("autosave")
	assert_true(loaded.get("ok", false) or loaded.get("code") == &"scene_activation_pending", str(loaded))
	if not await _wait_menu(): return
	assert_true(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks)
	var menu: Node = get_tree().current_scene
	await _click(menu._gallery_button)
	var gallery: Node = menu._gallery_instance
	assert_not_null(gallery)
	if gallery == null: return
	assert_true(gallery.is_visible_in_tree())
	var tile: Button = null
	for row: Button in gallery._ending_tile_grid.get_children():
		if row.get_meta(&"gallery_record_id") == PASSAGE_ID: tile = row
	assert_not_null(tile)
	if tile == null: return
	assert_eq(tile.text, "Ending 1")
	await _click(tile)
	assert_eq(gallery._selected_id, PASSAGE_ID)
	assert_false(gallery._replay_button.disabled)
	await _screenshot("passage-gallery-record")
	var owner: RefCounted = gallery._replay_owner
	var run_before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var autosave_before := FileAccess.get_sha256("user://saves/autosave.json")
	var profile_bytes := FileAccess.get_sha256("user://profile.json")
	if not _ok(owner.get_variants(PASSAGE_ID)): return
	var finishes: Array = []
	owner.playback_finished.connect(func(result: Dictionary): finishes.append(result))
	await _click(gallery._replay_button)
	assert_true(owner.is_playing())
	if not owner.is_playing(): return
	for expected: String in ["line.scene.test.a.two", "line.scene.test.a.three"]:
		for frame: int in 5: await get_tree().process_frame
		assert_eq(bridge._reached_replay.card.receipt.line_id, expected)
		var surface: Node = bridge._reached_replay.surface
		assert_true(surface._current_body.is_visible_in_tree())
		assert_eq(surface._current_body.text, "TEST passage first." if expected.ends_with("two") else "TEST passage last.")
		await _screenshot("passage-replay-" + expected.get_slice(".", 4))
		await _click(surface._next)
	assert_eq(finishes.size(), 1)
	assert_true(bridge._reached_replay.is_empty())
	assert_eq(game.capture_run_snapshot_input(), run_before)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), autosave_before)
	assert_eq(FileAccess.get_sha256("user://profile.json"), profile_bytes)
	_write_json("res://.godot/ci/passage-connected-replay-proof.json", {"process_id": OS.get_process_id(),
		"completed_creator": proof.finisher_process_id, "replayed_line_ids": ["line.scene.test.a.two", "line.scene.test.a.three"],
		"profile_unchanged": true, "run_unchanged": true, "finish_count": finishes.size()})
