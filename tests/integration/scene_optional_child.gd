extends "res://tests/integration/scene_manual_entry_child.gd"
## FINAL owners and physical saves. TEST content; creation/Save/Load use application
## ports, while admission, computer, board, departure, End and Retry use Viewport input.

func _optional_wait(line: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while true:
		if bridge._runtime_adapter.current_line_id() == line and bridge._runtime_adapter.is_current_line_complete(): return true
		if Time.get_ticks_msec() >= deadline:
			await _screenshot("optional-timeout")
			fail_test("Optional path did not reach " + line + ": " + str(bridge.capture_reading_checkpoint(false)))
			return false
		await get_tree().process_frame
	return false

func _optional_closure(outcome: String, mode: String = "") -> Dictionary:
	var found: Array = []
	var playable := 0
	for receipt: Dictionary in game.capture_run_snapshot_input().command_receipts.values():
		var result: Dictionary = receipt.get("scene_event", {}).get("result", {})
		if result.get("kind") == "challenge_playable": playable += 1
		if result.get("kind") == "challenge_closed": found.append(result)
	assert_eq(playable, 1)
	assert_eq(found.size(), 1)
	if found.size() != 1: return {}
	var closure: Dictionary = found[0]
	assert_eq(closure.outcome, outcome)
	assert_eq(closure.target_id, "target_a")
	if outcome == "never_started":
		assert_null(closure.attempt_proof)
		if mode == "selected_absence":
			assert_false(profile.get_profile_snapshot().dating_attempts.is_empty())
		else:
			assert_true(profile.get_profile_snapshot().dating_attempts.is_empty())
	else:
		var proof: Dictionary = closure.attempt_proof
		var attempt: Dictionary = profile.get_dating_attempt(proof.run_id, proof.slot_id, proof.attempt_id, proof.branch_id)
		if not _ok(attempt): return {}
		if not _ok(ATTEMPTS.validate_attempt_proof(attempt.value, proof)): return {}
		assert_eq(attempt.value.record.state, "in_progress")
		assert_false(attempt.value.record.board.terminal)
	return closure

func create_optional(mode: String) -> void:
	if not await _start_playable(): return
	var outcome := "unfinished" if mode == "unfinished" else "never_started"
	var host: Control = get_tree().current_scene
	var command := {}
	var board_before := {}
	var selected_sha := ""
	var future_record := {}
	if mode == "selected_absence":
		if not _ok(saves.save_latest_to_slot(3)): return
		selected_sha = FileAccess.get_sha256("user://saves/slot_3.json")
		assert_eq(selected_sha.length(), 64)
	if mode != "never_opened":
		await _click(_controls(host, "CheckComputer"))
		assert_true(host.is_computer_open())
		if not host.is_computer_open(): return
		var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
		command = panel._command.duplicate(true)
		assert_eq(panel.public_view.phase, "never_started")
		if mode in ["unfinished", "selected_absence"]:
			assert_true(panel.worksheet.grid.focus_cell(323))
			await get_tree().process_frame
			await _click(panel.worksheet.grid.cell_nodes[323])
			assert_eq(panel.public_view.phase, "active")
			if panel.public_view.phase != "active": return
			board_before = game.capture_dating_challenge_state().value.duplicate(true)
		await _click(_controls(host, "CheckComputer"))
		assert_false(host.is_computer_open())
	if mode == "selected_absence":
		future_record = board_before.duplicate(true)
		assert_false(future_record.is_empty())
		var prior_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
		assert_false(prior_profile.dating_attempts.is_empty())
		var source_branch: String = game.capture_run_snapshot_input().lifecycle.branch_id
		var pause: Node = get_node("/root/SceneRouter")._production_pause
		if not _ok(await pause.request_pause()): return
		var prepared: Dictionary = pause._backup_port.prepare_action("load", "slot:3")
		if not _ok(prepared): return
		if not _ok(await pause._backup_port.commit_action(prepared.value.token)): return
		var deadline := Time.get_ticks_msec() + 20000
		while ready_count < 2 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		assert_eq(ready_count, 2)
		if ready_count != 2: return
		for frame: int in 4: await get_tree().process_frame
		# Ready restores ownership; the native caption can still be revealing.
		# Wait for real presentation completion before the one departure input.
		if not await _optional_wait("line.scene.test.b.one"): return
		await get_tree().process_frame
		var departure_admission := {"complete": bridge._runtime_adapter.is_current_line_complete(),
			"next_admitted": _caption()._next_admitted(), "waiting_for_text": _caption()._line_waiting_for_text,
			"frontier_kind": str(bridge.capture_current_line_presentation_frontier().get("value", {}).get("kind", ""))}
		print("OPTIONAL_SELECTED_DEPARTURE_ADMISSION ", departure_admission)
		_write_json("res://.godot/ci/optional-selected-absence-admission.json", departure_admission)
		assert_true(departure_admission.next_admitted, str(departure_admission))
		assert_false(get_tree().paused)
		assert_false(get_tree().current_scene.is_computer_open())
		assert_ne(game.capture_run_snapshot_input().lifecycle.branch_id, source_branch)
		assert_eq(profile.get_profile_snapshot(), prior_profile, "Selected Load preserves the later source-branch attempt.")
		assert_true(game.capture_dating_challenge_state().value.is_empty(), "Selected absence never imports the later source board.")
		assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), selected_sha)
		board_before = {}
	assert_false(bridge.is_computer_caption_held())
	var source: Dictionary = bridge.capture_reading_checkpoint(false)
	assert_eq(source.value.reading_session.boundary, "control", "Closing Computer alone does not advance dialogue.")
	var attempts_before: Dictionary = profile.get_profile_snapshot().dating_attempts.duplicate(true)
	var files: RefCounted = saves._storage._file_ops
	var fault := CONTENT.WriteRefusal.new()
	var source_autosave := FileAccess.get_sha256("user://saves/autosave.json")
	if mode == "unfinished":
		var next_results: Array = []
		var retry_activations := [0]
		var retry_admission := {}
		bridge.next_request_finished.connect(func(frontier: Dictionary, result: Dictionary):
			next_results.append({"code": str(result.get("code", "")), "ok": bool(result.get("ok", false)),
				"fatal": bool(result.get("fatal", false)), "committed": bool(result.get("committed", false)),
				"frontier_kind": str(frontier.get("value", {}).get("kind", "")),
				"frontier_still_current": frontier == bridge.capture_current_line_presentation_frontier()})
			_write_json("res://.godot/ci/optional-unfinished-next-trace.json", {
				"next_results": next_results, "retry_activations": retry_activations[0], "retry_admission": retry_admission})
			print("OPTIONAL_NEXT_RESULT ", next_results.back()))
		_caption().recovery_overlay.retry_button.activated.connect(func(): retry_activations[0] += 1)
		fault.refuse_on = 1
		saves._storage._file_ops = fault
		await _click(_caption().transport_rail._next_button)
		assert_eq(fault.refused, 1, "Physical departure checkpoint write was refused.")
		assert_eq(next_results.size(), 1, "The real Next request reports its write refusal.")
		if not next_results.is_empty(): assert_false(next_results[0].ok, str(next_results[0]))
		assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), source_autosave)
		assert_eq(profile.get_profile_snapshot().dating_attempts, attempts_before)
		assert_eq(bridge.capture_reading_checkpoint(false), source)
		assert_eq(game.capture_dating_challenge_state().value, board_before)
		assert_true(_caption().is_reading_recovery_active())
		await _screenshot("optional-" + mode + "-retry")
		saves._storage._file_ops = files
		var optional_frontier: Dictionary = bridge.capture_scene_optional_frontier()
		retry_admission.merge({"recovery_admitted": _caption()._recovery_action_admitted(),
			"can_next": bridge.can_next_current_line(),
			"frontier_ok": bool(optional_frontier.get("ok", false)),
			"frontier_code": str(optional_frontier.get("code", ""))})
		print("OPTIONAL_RETRY_ADMISSION ", retry_admission)
		await _click(_caption().recovery_overlay.retry_button)
		_write_json("res://.godot/ci/optional-unfinished-next-trace.json", {
			"next_results": next_results, "retry_activations": retry_activations[0], "retry_admission": retry_admission,
			"recovery_active": _caption().is_reading_recovery_active(),
			"retry_visible": _caption().recovery_overlay.retry_button.is_visible_in_tree(),
			"retry_disabled": _caption().recovery_overlay.retry_button.disabled})
		assert_eq(retry_activations[0], 1, "The actual Retry button receives one activation.")
		assert_eq(next_results.size(), 2, "Retry completes one additional real Next request.")
		if next_results.size() == 2: assert_true(next_results[1].ok, str(next_results[1]))
	else:
		await _click(_caption().caption_text)
	if not await _optional_wait("line.scene.test.b.two"): return
	assert_eq(profile.get_profile_snapshot().dating_attempts, attempts_before, "Departure does not create another attempt.")
	assert_eq(game.capture_dating_challenge_state().value, board_before)
	var before_end: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	for receipt: Dictionary in before_end.command_receipts.values():
		assert_ne(receipt.get("scene_event", {}).get("result", {}).get("kind", ""), "challenge_closed")
	if not command.is_empty():
		assert_false(bootstrap._retained_dating_presentation_port.dispatch_scene_panel_action(command, "reveal", 0, 0).ok,
			"Departed board command cannot create another move.")
		assert_eq(game.capture_run_snapshot_input(), before_end)
	await _screenshot("optional-" + mode + "-before-end")
	await _click(_caption().caption_text)
	if not await _optional_wait("line.scene.test.a.one"): return
	var closure := _optional_closure(outcome, mode)
	if closure.is_empty(): return
	assert_eq(ready_count, 2 if mode == "selected_absence" else 1)
	assert_eq(profile.get_profile_snapshot().dating_attempts, attempts_before, "End preserves physical history.")
	if not _ok(saves.save_latest_to_slot(1)): return
	var saved: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(saved): return
	assert_eq(saved.value.current_snapshot.snapshot.command_receipts, game.capture_run_snapshot_input().command_receipts)
	var proof := {"mode": mode, "outcome": outcome, "creator_process_id": OS.get_process_id(),
		"closure": closure, "profile": profile.get_profile_snapshot(), "record": board_before,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"), "refusals": fault.refused,
		"selected_slot_sha256": selected_sha, "future_record": future_record, "creator_ready_count": ready_count}
	assert_eq(str(proof.slot_sha256).length(), 64)
	if mode == "selected_absence":
		assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), selected_sha)
	await _screenshot("optional-" + mode + "-target")
	if not _write_json("user://optional-proof.json", proof): return
	_write_json("res://.godot/ci/optional-" + mode + "-create-proof.json", proof)

func load_optional(mode: String) -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://optional-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.creator_process_id)
	assert_eq(proof.mode, mode)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not _start_services(): return
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _optional_wait("line.scene.test.a.one"): return
	assert_eq(_optional_closure(proof.outcome, mode), proof.closure)
	assert_eq(game.capture_dating_challenge_state().value, proof.record)
	assert_eq(profile.get_profile_snapshot(), proof.profile, "Load does not replay Challenge/history effects.")
	if not _ok(saves.save_latest_to_slot(2)): return
	assert_eq(_optional_closure(proof.outcome, mode), proof.closure)
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if mode == "selected_absence":
		assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), proof.selected_slot_sha256)
		assert_false(proof.future_record.is_empty())
		assert_true(game.capture_dating_challenge_state().value.is_empty())
	proof["loader_process_id"] = OS.get_process_id()
	proof["ready_count"] = ready_count
	assert_eq(ready_count, 1)
	await _screenshot("optional-" + mode + "-restored")
	_write_json("res://.godot/ci/optional-" + mode + "-load-proof.json", proof)
