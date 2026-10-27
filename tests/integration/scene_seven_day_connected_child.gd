extends "res://tests/integration/scene_later_caption_child.gd"
## Normal shipped selection; real Title, viewport Accept, Save and ending owners.
## Two GUT children run in separate rendered processes sharing one isolated root.
const WEEK_PROOF := "user://scene-seven-day-proof.json"
const MENU := "res://scenes/menu/MenuScene.tscn"
const SAVED_LINE := "line.Day4.two"
const PASSAGE_ID := "passage.test.seven_day"
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
	return {"ok": OS.get_environment("DWM_SCENE_READING_FIXTURE") != "1"
		and not OS.get_cmdline_user_args().has("--scene-reading-fixture")
		and not OS.get_cmdline_args().has("--scene-reading-fixture")}

func _wait_route(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready(): return true
		await get_tree().process_frame
	print("SCENE_ROUTE_TIMEOUT " + JSON.stringify({"lifecycle": game._run_lifecycle.to_dict(),
		"gate": game._mutation_gate.guard_external(&"scene_entry"), "live": game._live_session_active,
		"reading": bridge.has_reading_session(), "playback": bridge.has_active_playback()}))
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
			_ending_phase("walk.Day%d.%d.begin" % [day, half])
			await _accept()
			var line_id := "line.Day%d.%s" % [day, "one" if half == 1 else "two"]
			if not await _wait_line(line_id): return false
			_ending_phase("walk.Day%d.%d.ready" % [day, half])
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
	var projected: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(checkpoint.value)
	if not _ok(projected): return
	assert_eq(snapshot.narrative_checkpoint, projected.value, "real Save retains exact Day4.two position")
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "first four days require no board")
	var proof := {"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"checkpoint": snapshot.narrative_checkpoint, "snapshot": snapshot, "observed_lines": observed_lines,
		"source_run": initial.lifecycle.run_id, "source_branch": snapshot.lifecycle.branch_id,
		"profile": profile.get_profile_snapshot(),
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"autosave_sha256": _autosave_sha256(),
		"profile_sha256": FileAccess.get_sha256("user://profile.json")}
	for key: String in ["slot_sha256", "profile_sha256"]: assert_eq(str(proof[key]).length(), 64)
	assert_eq(proof.autosave_sha256, "", "ordinary seven-day reading never creates Autosave")
	assert_eq(observed_lines.size(), 8, "first eight captions observed in order")
	if not _write_json(WEEK_PROOF, proof): return
	_write_json("res://.godot/ci/scene-seven-day-create-proof.json", proof)

func load_and_complete_week(stop_after_load: bool = false, witness_save: bool = false) -> void:
	_ending_phase_timing = witness_save
	_ending_phase("loader.begin")
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
	var expanded: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(proof.checkpoint)
	if not _ok(expanded): return
	assert_eq(_ready_observation.ledger, expanded.value.reading_session.ledger, "Load adds no publication")
	var restored_native: Dictionary = _ready_observation.duplicate(true)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_eq(reading.value, expanded.value, "Load neither replays nor advances the saved caption")
	var current: Dictionary = game.capture_run_snapshot_input()
	assert_eq(current.lifecycle.run_id, proof.source_run)
	assert_eq(current.lifecycle.branch_id, proof.source_branch)
	for key: String in ["gameplay", "scene"]:
		assert_eq(current[key], proof.snapshot[key], "Load preserves " + key)
	assert_eq(profile.get_profile_snapshot(), proof.profile, "Load writes no history")
	_assert_source_files(proof)
	# Session publication uses a deferred display refresh. Native Ready stays full-line.
	for frame: int in 4: await get_tree().process_frame
	var layer: Node = _caption()
	assert_eq(layer.get_caption_projection().retained_captions, ["TEST Day3 closing.", "TEST Day4 opening."])
	assert_eq(layer.get_caption_projection().caption_window, ["TEST Day3 closing.", "TEST Day4 opening.", "TEST Day4 closing."])
	assert_eq(layer._scrollback, ["TEST Day2 opening.", "TEST Day2 closing.", "TEST Day3 opening.",
		"TEST Day3 closing.", "TEST Day4 opening."], "History keeps the two preceding encountered checkpoint sections")
	assert_eq(layer._review_offset, 0)
	assert_eq(bridge._reading_session.ledger.snapshot().captions.size(), 1, "Load retains only the current live publication")
	var history: Dictionary = bridge.get_reading_history()
	if not _ok(history): return
	assert_eq(history.value.captions.map(func(row: Dictionary) -> String: return row.text),
		["TEST Day2 opening.", "TEST Day2 closing.", "TEST Day3 opening.", "TEST Day3 closing.",
			"TEST Day4 opening.", "TEST Day4 closing."], "History retains exactly the last three encountered sections")
	assert_eq(reading.value.reading_session.player_progress.history_sections.size(), 3)
	var stale: Dictionary = layer._presented_line.duplicate(true)
	stale.value.token = "stale-playback"
	assert_false(bridge.get_scene_caption_memory(stale).ok)
	var native_index: int = bridge._runtime_adapter._dialogic.current_event_idx
	layer._refresh_reading_session()
	layer._refresh_reading_session()
	assert_eq(bridge._runtime_adapter._dialogic.current_event_idx, native_index)
	assert_eq(preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(bridge.capture_reading_checkpoint(false).value).value, proof.checkpoint)
	assert_eq(layer.get_caption_projection().caption_window, ["TEST Day3 closing.", "TEST Day4 opening.", "TEST Day4 closing."])
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	await _screenshot("seven-day-day4-restored-full")
	if stop_after_load: return
	_ending_phase("witness_save.begin")
	if witness_save and not await _save_restored_witness(proof): return
	_ending_phase("witness_save.return")
	_ending_phase("remaining_walk.begin")
	if not await _walk(5, 1, 7, 2): return
	_ending_phase("remaining_walk.return")
	assert_eq(observed_lines.size(), 6, "remaining six captions observed in order")
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "seven-day reading does not require Minesweeper")
	var prior_layout: Node = bridge._runtime_adapter._dialogic.Styles.get_layout_node()
	var prior_layout_ref: WeakRef = weakref(prior_layout)
	var prior_layout_id: int = prior_layout.get_instance_id()
	_ending_phase("ending_entry.begin")
	await _accept()
	_ending_phase("ending_entry.accept_return")
	var ending_ready: bool = await _wait_line("line.ending.alone.normal.one")
	_ending_phase("ending_readiness.return")
	if witness_save:
		_ending_phase("ending_evidence.begin")
		await _record_witness_ending(prior_layout_ref, prior_layout_id, ending_ready)
		_ending_phase("ending_evidence.return")
	if not ending_ready: return
	assert_eq(get_tree().current_scene.scene_file_path, HOST, "passage remains ordinary Scene dialogue")
	var ending_state: Dictionary = game.capture_run_snapshot_input().lifecycle
	assert_eq(ending_state.state, "PLAYING", "last caption precedes Finish")
	assert_false(ending_state.has("ending_plan"))
	assert_false(PASSAGE_ID in profile.get_profile_snapshot().gallery_unlocks)
	await _screenshot("seven-day-ending")
	# This opt-in journey keeps slot 2 as the restored Day4 witness, like export.
	# The original ending-save/terminal-load journey remains unchanged by default.
	if not witness_save and not await _save_ending_caption(): return
	var autosave_before := _autosave_sha256()
	var completed_capture := {}
	var finish_results: Array[Dictionary] = []
	bridge.next_request_finished.connect(func(_frontier: Dictionary, result: Dictionary) -> void:
		finish_results.append(result.duplicate(true))
		if witness_save and result.get("ok", false):
			completed_capture.merge(get_node("/root/ApplicationBootstrap")._capture_paused_checkpoint_inputs(), true), CONNECT_ONE_SHOT)
	_ending_phase("ending_completion.begin")
	await _accept()
	_ending_phase("ending_completion.accept_return")
	if not await _wait_route(MENU):
		assert_false(finish_results.is_empty(), "Finish delivered its completion result")
		for result: Dictionary in finish_results: assert_true(result.get("ok", false), "Finish failed: " + str(result))
		return
	_ending_phase("title.ready")
	var finished: Dictionary = game._run_lifecycle.to_dict()
	assert_eq(finished.state, "COMPLETED")
	assert_false(finished.has("ending_plan"), "completion is ordinary lifecycle state")
	assert_false(game.capture_live_session().value.active, "completion retires live authority")
	assert_eq(_autosave_sha256(), autosave_before, "ordinary Finish does not write a game save")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256, "ending preserves source save")
	await _screenshot("seven-day-completed-title")
	var completed_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var gallery_id := "passage:%s:gallery:%s" % [str(proof.source_run), PASSAGE_ID]
	assert_eq(completed_profile.gallery_transaction_receipts.get(gallery_id), {"ending_id": PASSAGE_ID, "unlocked": true})
	assert_eq(completed_profile.gallery_transaction_receipts.size(), proof.profile.gallery_transaction_receipts.size() + 1)
	assert_true(PASSAGE_ID in completed_profile.gallery_unlocks)
	if witness_save:
		var witness: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("res://.godot/ci/scene-seven-day-witness-proof.json"))
		if not _ok(witness): return
		assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), witness.value.slot_sha256, "ending preserves restored Day4 witness")
		# Explicit fixture Save preserves the actual completed capture for review.
		if not _ok(completed_capture): return
		if not _ok(saves.record_stable_checkpoint(completed_capture.value, &"manual_save")): return
		if not _ok(saves.save_latest_to_slot(3)): return
		var terminal_files := {}
		for name: String in ["saves/slot_3.json", "profile.json"]:
			var source := "user://" + name
			var destination := "res://.godot/ci/scene-seven-day-completed-" + name.get_file()
			var copied: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))
			assert_eq(copied, OK)
			if copied != OK: return
			assert_eq(FileAccess.get_sha256(destination), FileAccess.get_sha256(source))
			terminal_files[name] = {"file": destination, "sha256": FileAccess.get_sha256(destination)}
		if not _write_json("res://.godot/ci/scene-seven-day-completed-files.json", terminal_files): return
	_ending_phase("completion_checks.return")
	if not await _new_from_title(2): return
	_ending_phase("fresh_day1.ready")
	var fresh: Dictionary = game.capture_run_snapshot_input()
	assert_ne(fresh.lifecycle.run_id, proof.source_run)
	assert_ne(fresh.lifecycle.branch_id, current.lifecycle.branch_id)
	assert_eq(fresh.lifecycle.state, "PLAYING")
	assert_false(fresh.lifecycle.has("ending_plan"), "fresh run has no terminal plan")
	assert_eq(bridge._reading_session.ledger.snapshot().captions.size(), 1, "fresh Day1 has one new publication")
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, completed_profile.gallery_transaction_receipts, "New Game preserves completion history")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if witness_save:
		var witness: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("res://.godot/ci/scene-seven-day-witness-proof.json"))
		if not _ok(witness): return
		assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), witness.value.slot_sha256, "completion and New Acc preserve witness slot")
	await _screenshot("seven-day-fresh-day1")
	_write_json("res://.godot/ci/scene-seven-day-load-proof.json", {"loader_process_id": OS.get_process_id(),
		"creator_process_id": proof.process_id, "ready_native": restored_native,
		"creator_lines": proof.observed_lines, "loader_lines": observed_lines,
		"completed_lifecycle": finished, "completed_profile": completed_profile,
		"fresh_lifecycle": fresh.lifecycle, "ready_count": ready_count,
		"preserved_slot_sha256": proof.slot_sha256})


func _press_witness(button: Button, label: String) -> bool:
	# Existing pointer-save fixture semantics: real visible button, one fresh click.
	assert_true(is_instance_valid(button), label)
	if not is_instance_valid(button): return false
	assert_true(button.is_visible_in_tree(), label + " visible")
	assert_false(button.disabled, label + " enabled")
	if not button.is_visible_in_tree() or button.disabled: return false
	var bounds := Rect2(button.get_global_transform_with_canvas() * Vector2.ZERO,
		button.get_global_transform_with_canvas().get_scale() * button.size)
	assert_true(get_viewport().get_visible_rect().encloses(bounds), label + " on screen")
	var observed := [0]
	if button is WitnessedTransportButton:
		button.activated.connect(func(): observed[0] += 1, CONNECT_ONE_SHOT)
	else:
		button.pressed.connect(func(): observed[0] += 1, CONNECT_ONE_SHOT)
	await _click(button)
	assert_eq(observed[0], 1, label + " receives pointer activation")
	return observed[0] == 1

func _save_restored_witness(proof: Dictionary) -> bool:
	const PATH := "user://saves/slot_2.json"
	assert_false(FileAccess.file_exists(PATH), "restored witness slot is initially empty")
	if FileAccess.file_exists(PATH): return false
	var caption: Node = _caption()
	if not await _press_witness(caption.transport_rail.get_node("Save"), "reading rail Save"): return false
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	var backup: Control = sheet.surface._hosts[&"backup"]
	assert_true(backup.is_visible_in_tree())
	assert_eq(backup.active_mode, "save")
	if not backup.is_visible_in_tree() or backup.active_mode != "save": return false
	if not await _press_witness(backup.drawer_buttons["slot:2"], "select witness slot 2"): return false
	assert_eq(backup.selected_locator, "slot:2")
	if not await _press_witness(backup.action_buttons.save, "save empty witness slot"): return false
	# Same 15000 ms Saved+disk guard as scene_pointer_save_load_child.
	var deadline := Time.get_ticks_msec() + 15000
	print("ENDING_LOAD_WITNESS_SAVE_WAIT deadline_msec=", deadline)
	while Time.get_ticks_msec() < deadline:
		if not backup._in_operation and backup._status_key == "saved" and FileAccess.file_exists(PATH): break
		await get_tree().process_frame
	assert_true(not backup._in_operation and backup._status_key == "saved" and FileAccess.file_exists(PATH),
		"ENDING_LOAD_WITNESS_SAVE_TIMEOUT: Saved and durable bytes within the existing 15000ms bound")
	if backup._in_operation or backup._status_key != "saved" or not FileAccess.file_exists(PATH): return false
	if not _ok(backup.last_result): return false
	assert_true(backup.status_label.is_visible_in_tree())
	assert_eq(backup.status_label.text, "Saved")
	assert_false(is_instance_valid(backup.confirmation), "empty slot needs no confirmation")
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(PATH))
	if not _ok(parsed): return false
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	for key: String in ["narrative_checkpoint", "gameplay", "scene"]:
		assert_eq(snapshot[key], proof.snapshot[key], "witness preserves " + key)
	assert_eq(snapshot.lifecycle.run_id, proof.source_run)
	assert_eq(snapshot.lifecycle.branch_id, proof.source_branch)
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	var witness_hash := FileAccess.get_sha256(PATH)
	# Exercise the actual Back owner; no direct leave_host/request_continue shortcut.
	_ending_phase("witness_back.begin")
	if not await _press_witness(sheet.surface._sheet_back, "witness Backup Back"): return false
	_ending_phase("witness_back.return")
	assert_false(sheet.surface.visible)
	assert_false(get_tree().paused)
	if sheet.surface.visible or get_tree().paused: return false
	if not await _wait_line(SAVED_LINE): return false
	# _wait_line records observations; this is the restored line, not one of six later captions.
	observed_lines.pop_back()
	assert_eq(preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(bridge.capture_reading_checkpoint(false).value).value, proof.checkpoint)
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	return _write_json("res://.godot/ci/scene-seven-day-witness-proof.json", {
		"process_id": OS.get_process_id(), "checkpoint": snapshot.narrative_checkpoint,
		"snapshot": snapshot, "slot_sha256": witness_hash, "source_slot_sha256": proof.slot_sha256,
		"native_after_back": _native_observation(), "profile": profile.get_profile_snapshot()})

func _record_witness_ending(prior_ref: WeakRef, prior_id: int, ending_ready: bool) -> void:
	var prior: Node = prior_ref.get_ref()
	var active: Node = bridge._runtime_adapter._dialogic.Styles.get_layout_node()
	var style: Resource = active.get_meta("style", null) if is_instance_valid(active) else null
	var caption: Node = _caption()
	var observation := {"process_id": OS.get_process_id(),
		"window_handle": DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, get_tree().root.get_window_id()),
		"ending_ready": ending_ready, "prior_layout_id": prior_id,
		"prior_layout_in_tree": is_instance_valid(prior) and prior.is_inside_tree(),
		"layout_id": active.get_instance_id() if is_instance_valid(active) else 0,
		"style": style.resource_path if style != null else "",
		"caption_script": caption.get_script().resource_path if is_instance_valid(caption) else "",
		"ending_layout": caption.transport_rail.ending_layout if is_instance_valid(caption) else false,
		"clock_present": caption.transport_rail.has_node("AudienceClock") if is_instance_valid(caption) else true,
		"lifecycle": game._run_lifecycle.to_dict().duplicate(true),
		"reading_checkpoint": bridge.capture_reading_checkpoint(false).duplicate(true)}
	await _screenshot("seven-day-witness-ending")
	var path := "res://.godot/ci/computer-seven-day-witness-ending.png"
	observation["capture"] = {"source": "Godot viewport, not desktop", "file": path,
		"sha256": FileAccess.get_sha256(path)}
	_write_json("res://.godot/ci/scene-seven-day-witness-ending.json", observation)
	if not ending_ready: return
	assert_eq(observation.style, "res://dialogic/styles/witnessed_caption_style.tres")
	assert_eq(observation.caption_script, "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
	assert_true(observation.layout_id != 0)
	assert_false(observation.ending_layout)
	assert_false(observation.clock_present, "Scene rail has no clock")

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
	# Ordinary Scene Save is a direct host: leaving it already requests Continue.
	sheet.surface.leave_host()
	for frame: int in 4: await get_tree().process_frame
	if not _ok(sheet.last_result): return false
	assert_false(sheet.surface.visible, "Save Back closes the direct host")
	assert_false(get_tree().paused, "Save Back resumes the ordinary passage")
	if sheet.surface.visible or get_tree().paused: return false
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_2.json"))
	if not _ok(parsed): return false
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	var projected := preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(checkpoint.value)
	if not _ok(projected): return false
	assert_eq(snapshot.narrative_checkpoint, projected.value, "passage Save keeps exact visible reading frontier")
	assert_eq(snapshot.lifecycle.state, "PLAYING")
	assert_false(snapshot.lifecycle.has("ending_plan"))
	for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_false(snapshot.has(key), "player passage omits historical ledger " + key)
	var proof := {"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"checkpoint": snapshot.narrative_checkpoint, "snapshot": snapshot, "saved_native": native,
		"profile": profile.get_profile_snapshot(), "slot_sha256": FileAccess.get_sha256("user://saves/slot_2.json")}
	assert_eq(str(proof.slot_sha256).length(), 64)
	await _screenshot("seven-day-ending-saved")
	if not _write_json("user://scene-seven-day-ending-proof.json", proof): return false
	return _write_json("res://.godot/ci/scene-seven-day-ending-save-proof.json", proof)




