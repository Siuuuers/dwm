extends "res://tests/integration/scene_later_caption_child.gd"
## Normal shipped selection; real Title, viewport Accept, Save and ending owners.
## Two GUT children run in separate rendered processes sharing one isolated root.
const WEEK_PROOF := "user://scene-seven-day-proof.json"
const MENU := "res://scenes/menu/MenuScene.tscn"
const SAVED_LINE := "line.Day4.two"
var observed_lines: Array[String] = []

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result))
	return result.get("ok", false)

func _install_content_registration() -> Dictionary:
	# Override the inherited diagnostic fixture installer with no installation.
	assert_ne(OS.get_environment("DWM_SCENE_READING_FIXTURE"), "1")
	assert_false(OS.get_cmdline_user_args().has("--scene-reading-fixture"))
	assert_false(OS.get_cmdline_args().has("--scene-reading-fixture"))
	assert_true(FileAccess.file_exists("res://data/manifests/scene_story_registration.json"))
	assert_true(FileAccess.file_exists("res://data/manifests/scene_ending_reading_catalogue.json"))
	return {"ok": OS.get_environment("DWM_SCENE_READING_FIXTURE") != "1"
		and not OS.get_cmdline_user_args().has("--scene-reading-fixture")
		and not OS.get_cmdline_args().has("--scene-reading-fixture")}

func _wait_route(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready(): return true
		await get_tree().process_frame
	fail_test("Route timeout: " + path)
	return false

func _wait_line(line_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if bridge._runtime_adapter.current_line_id() == line_id \
				and bridge._runtime_adapter.is_current_line_complete() \
				and bridge.is_current_line_presentation_acknowledged():
			var native := _native_observation()
			assert_true(native.visible, line_id + " is rendered")
			assert_false(native.revealing, line_id + " fully revealed")
			assert_eq(float(native.visible_ratio), 1.0)
			assert_true(native.event_done, line_id + " native event DONE")
			observed_lines.append(line_id)
			return true
		await get_tree().process_frame
	await _screenshot("seven-day-line-timeout")
	if get_tree().current_scene is EndingScene:
		print("ENDING_HANDOFF_FAILURE ", get_tree().current_scene._last_playback_failure,
			" adapter_phase=", bridge._runtime_adapter._activity_phase)
	fail_test("Caption timeout: " + line_id + "; actual=" + bridge._runtime_adapter.current_line_id()
		+ "; activation=" + str(saves._scene_restore_activation))
	return false

func _new_from_title(expected_ready: int) -> bool:
	if not await _wait_route(MENU): return false
	var menu: Node = get_tree().current_scene
	assert_true(menu._new_acc_button.is_visible_in_tree())
	assert_false(menu._new_acc_button.disabled)
	await _click(menu._new_acc_button)
	# A retained completed autosave may require explicit replacement consent.
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if ready_count == expected_ready: break
		if is_instance_valid(menu) and is_instance_valid(menu._confirmation) and not menu._title_transition:
			assert_true(menu._confirmation.confirm_button.is_visible_in_tree())
			await _click(menu._confirmation.confirm_button)
		await get_tree().process_frame
	assert_eq(ready_count, expected_ready, "New Acc publishes exactly one Ready")
	if ready_count != expected_ready or not await _wait_route(HOST): return false
	return await _wait_line("line.Day1.one")

func _walk(first_day: int, first_half: int, last_day: int, last_half: int) -> bool:
	for day: int in range(first_day, last_day + 1):
		for half: int in range(1, 3):
			if day == first_day and half < first_half: continue
			if day == last_day and half > last_half: continue
			await _accept()
			var line_id := "line.Day%d.%s" % [day, "one" if half == 1 else "two"]
			if not await _wait_line(line_id): return false
			var expected_text := "TEST Day%d %s." % [day, "opening" if half == 1 else "closing"]
			assert_eq(_native_observation().text.strip_edges(), expected_text)
	return true

func create_week() -> void:
	if not _start_services(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	assert_false(FileAccess.file_exists("user://saves/slot_1.json"), "fresh isolated files")
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	# The GUT harness has no main scene. Mount the actual normal Title through its router.
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1): return
	var initial: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_eq(initial.lifecycle.state, "PLAYING")
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "New Game creates no board")
	await _screenshot("seven-day-title-opening")
	if not await _walk(1, 2, 4, 2): return
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	assert_eq(checkpoint.value.reading_session.frontier.line_id, SAVED_LINE)
	await _screenshot("seven-day-day4-save-source")
	await _click(_controls(get_tree().current_scene, "Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup(), str(sheet.last_result))
	if not sheet.can_save_backup(): return
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(prepared): return
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return
	sheet.surface.leave_host()
	for frame: int in 4: await get_tree().process_frame
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(parsed): return
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	assert_eq(snapshot.narrative_checkpoint, checkpoint.value, "real Save retains exact Day4.two frontier")
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "first four days require no board")
	var proof := {"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"checkpoint": snapshot.narrative_checkpoint, "snapshot": snapshot, "observed_lines": observed_lines,
		"source_run": initial.lifecycle.run_id, "source_branch": snapshot.lifecycle.branch_id,
		"profile": profile.get_profile_snapshot(),
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"autosave_sha256": FileAccess.get_sha256("user://saves/autosave.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json")}
	for key: String in ["slot_sha256", "autosave_sha256", "profile_sha256"]: assert_eq(str(proof[key]).length(), 64)
	assert_eq(observed_lines.size(), 8, "first eight captions observed in order")
	if not _write_json(WEEK_PROOF, proof): return
	_write_json("res://.godot/ci/scene-seven-day-create-proof.json", proof)

func load_and_complete_week(stop_after_load: bool = false) -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(WEEK_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id, "Load runs in a fresh OS process")
	assert_eq(ProjectSettings.globalize_path("user://"), proof.user_dir)
	_assert_source_files(proof)
	if not _start_services(): return
	_assert_source_files(proof)
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return
	saves.live_session_ready.connect(func() -> void: _ready_observation = _native_observation())
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var restored: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(restored.get("code"), &"scene_activation_pending")
	if restored.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	assert_eq(_ready_observation.line_id, SAVED_LINE)
	assert_true(_ready_observation.visible)
	assert_false(_ready_observation.revealing)
	assert_eq(float(_ready_observation.visible_ratio), 1.0)
	assert_true(_ready_observation.event_done)
	assert_eq(_ready_observation.text.strip_edges(), "TEST Day4 closing.")
	assert_eq(_ready_observation.ledger, proof.checkpoint.reading_session.ledger, "Load adds no publication")
	var restored_native: Dictionary = _ready_observation.duplicate(true)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_eq(reading.value, proof.checkpoint, "Load neither replays nor advances the saved caption")
	var current: Dictionary = game.capture_run_snapshot_input()
	assert_eq(current.lifecycle.run_id, proof.source_run)
	assert_ne(current.lifecycle.branch_id, proof.source_branch)
	for key: String in ["gameplay", "scene", "command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_eq(current[key], proof.snapshot[key], "Load preserves " + key)
	assert_eq(profile.get_profile_snapshot(), proof.profile, "Load writes no history")
	_assert_source_files(proof)
	# Session publication uses a deferred display refresh. Native Ready stays full-line.
	for frame: int in 4: await get_tree().process_frame
	var layer: Node = _caption()
	assert_eq(layer.get_caption_projection().retained_captions, ["TEST Day4 opening."])
	assert_eq(layer.get_caption_projection().caption_window, ["TEST Day4 opening.", "TEST Day4 closing."])
	assert_eq(layer._scrollback, ["TEST Day4 opening."], "earlier days cannot leak into this occurrence")
	assert_eq(layer._review_offset, 0)
	assert_eq(bridge.get_reading_history().value.captions.size(), 8)
	var stale: Dictionary = layer._presented_line.duplicate(true)
	stale.value.token = "stale-playback"
	assert_false(bridge.get_scene_caption_memory(stale).ok)
	var native_index: int = bridge._runtime_adapter._dialogic.current_event_idx
	layer._refresh_reading_session()
	layer._refresh_reading_session()
	assert_eq(bridge._runtime_adapter._dialogic.current_event_idx, native_index)
	assert_eq(bridge.capture_reading_checkpoint(false).value, proof.checkpoint)
	assert_eq(layer.get_caption_projection().caption_window, ["TEST Day4 opening.", "TEST Day4 closing."])
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	await _screenshot("seven-day-day4-restored-full")
	if stop_after_load: return
	if not await _walk(5, 1, 7, 2): return
	assert_eq(observed_lines.size(), 6, "remaining six captions observed in order")
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "seven-day reading does not require Minesweeper")
	await _accept()
	if not await _wait_line("line.ending.alone.normal.one"): return
	var terminal_scene: Node = get_tree().current_scene
	assert_true(terminal_scene is EndingScene, "terminal registration mounts real EndingScene")
	var ending_state: Dictionary = game.capture_run_snapshot_input().lifecycle
	assert_eq(ending_state.state, "ENDING")
	assert_eq(ending_state.ending_plan.source_kind, "scene")
	assert_eq(ending_state.ending_plan.ending_id, "ending.alone")
	assert_eq(ending_state.ending_plan.next_step_index, 0, "starting physical playback cannot complete ending")
	assert_eq(ending_state.ending_plan.source_reading_checkpoint.reading_session.frontier.line_id, "line.Day7.two")
	assert_eq(terminal_scene.get_presentation_projection().kind, "play_ending")
	await _screenshot("seven-day-ending")
	if not await _save_ending_caption(): return
	await _accept()
	if not await _wait_route(MENU): return
	var finished: Dictionary = game._run_lifecycle.to_dict()
	assert_eq(finished.state, "COMPLETED")
	assert_eq(finished.ending_plan.next_step_index, 1, "physical ending completed once")
	assert_eq(finished.ending_plan.playback_stage, "GALLERY_RECORDED")
	assert_false(game.capture_live_session().value.active, "completion retires live authority")
	var durable: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(durable): return
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.state, "COMPLETED", "completion durable before Title")
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.ending_plan, finished.ending_plan)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256, "ending preserves source save")
	await _screenshot("seven-day-completed-title")
	var completed_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var gallery_id := "ending:%s:gallery:ending.alone" % str(proof.source_run)
	assert_eq(completed_profile.gallery_transaction_receipts.get(gallery_id), {"ending_id": "ending.alone", "unlocked": true})
	assert_eq(completed_profile.gallery_transaction_receipts.size(), proof.profile.gallery_transaction_receipts.size() + 1)
	assert_true("ending.alone" in completed_profile.gallery_unlocks)
	if not await _new_from_title(2): return
	var fresh: Dictionary = game.capture_run_snapshot_input()
	assert_ne(fresh.lifecycle.run_id, proof.source_run)
	assert_ne(fresh.lifecycle.branch_id, current.lifecycle.branch_id)
	assert_eq(fresh.lifecycle.state, "PLAYING")
	assert_false(fresh.lifecycle.has("ending_plan"), "fresh run has no terminal plan")
	assert_eq(bridge._reading_session.ledger.snapshot().captions.size(), 1, "fresh Day1 has one new publication")
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, completed_profile.gallery_transaction_receipts, "New Game preserves completion history")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	await _screenshot("seven-day-fresh-day1")
	_write_json("res://.godot/ci/scene-seven-day-load-proof.json", {"loader_process_id": OS.get_process_id(),
		"creator_process_id": proof.process_id, "ready_native": restored_native,
		"creator_lines": proof.observed_lines, "loader_lines": observed_lines,
		"completed_lifecycle": finished, "completed_profile": completed_profile,
		"fresh_lifecycle": fresh.lifecycle, "ready_count": ready_count,
		"preserved_slot_sha256": proof.slot_sha256})

func _save_ending_caption() -> bool:
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return false
	var native := _native_observation()
	assert_eq(native.line_id, "line.ending.alone.normal.one")
	assert_true(native.visible)
	var caption: Node = _caption()
	var save_button: Control = caption.transport_rail.get_node("Save")
	assert_true(save_button.is_visible_in_tree(), "ending exposes normal Save")
	assert_true(caption._save_admitted(), "ending caption admits physical Save")
	if not caption._save_admitted(): return false
	await _click(save_button)
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup(), str(sheet.last_result))
	if not sheet.can_save_backup(): return false
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:2")
	if not _ok(prepared): return false
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return false
	sheet.surface.leave_host()
	if not _ok(await sheet.request_continue()): return false
	for frame: int in 4: await get_tree().process_frame
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_2.json"))
	if not _ok(parsed): return false
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	assert_eq(snapshot.narrative_checkpoint, checkpoint.value, "ending Save keeps exact visible reading frontier")
	assert_eq(snapshot.lifecycle.state, "ENDING")
	assert_eq(snapshot.lifecycle.ending_plan.next_step_index, 0)
	var proof := {"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"checkpoint": snapshot.narrative_checkpoint, "snapshot": snapshot, "saved_native": native,
		"profile": profile.get_profile_snapshot(), "slot_sha256": FileAccess.get_sha256("user://saves/slot_2.json")}
	assert_eq(str(proof.slot_sha256).length(), 64)
	await _screenshot("seven-day-ending-saved")
	if not _write_json("user://scene-seven-day-ending-proof.json", proof): return false
	return _write_json("res://.godot/ci/scene-seven-day-ending-save-proof.json", proof)
