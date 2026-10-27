extends "res://tests/integration/scene_partner_fork_child.gd"
## FINAL owners, physical saves and rendered native input in distinct processes.
## Only TEST content/version and physical write refusal are substituted.
const UPDATE := preload("res://tests/support/SceneContentUpdateFixture.gd")
const ATTEMPT := preload("res://scripts/profile/DatingAttemptLedger.gd")
const PROOF := "user://content-update-proof.json"
var updated_content := false
var case_id := ""
var binding_retry := {}
var last_next_result := {}

func _install_content_registration() -> Dictionary:
	case_id = UPDATE.selected_case()
	return UPDATE.install(updated_content, case_id)

func _walk_to(line_id: String) -> bool:
	if not bridge.next_request_finished.is_connected(_observe_next_result):
		bridge.next_request_finished.connect(_observe_next_result)
	for step: int in 60:
		var current: String = bridge._runtime_adapter.current_line_id()
		if current == line_id:
			return await _wait_line(line_id)
		if not current.is_empty() and not await _wait_line(current): return false
		await _accept()
		var caption: Node = _caption()
		if caption != null and caption.is_reading_recovery_active():
			fail_test("content update traversal refused at " + current + ": " + str(last_next_result))
			return false
	fail_test("content update target not reached: " + line_id + "; actual=" + bridge._runtime_adapter.current_line_id()
		+ "; can_next=" + str(bridge.can_next_current_line()) + "; pending=" + str(bridge.capture_scene_pending_marker())
		+ "; next_result=" + str(last_next_result))
	return false

func _observe_next_result(_frontier: Dictionary, result: Dictionary) -> void:
	last_next_result = result.duplicate(true)
	if not result.get("ok", false): print("CONTENT_UPDATE_NEXT_REFUSED ", result)

func _assert_gameplay_preserved(before: Dictionary) -> void:
	var after: Dictionary = game.capture_run_snapshot_input().gameplay
	for key: String in before:
		if key == "scene_challenge_outcomes":
			assert_eq(after[key].keys(), before[key].keys(), "migration adds no story result")
			for id: String in before[key]:
				for field: String in before[key][id]: assert_eq(after[key][id].get(field), before[key][id][field])
		else:
			assert_eq(after[key], before[key], "preserved saved gameplay: " + key)

func _click_open_computer(host: Control) -> Array:
	var action: Callable = host._actions.computer_open
	var observed: Array = []
	# Observe the real callback result; the native click and actual Bootstrap
	# owner still perform the entire action and return their own acknowledgement.
	host._actions.computer_open = func() -> Dictionary:
		var result: Dictionary = await action.call()
		observed.append(result.duplicate(true))
		return result
	await _click(_controls(host, "CheckComputer"))
	host._actions.computer_open = action
	return observed

func _open_board() -> Control:
	var host: Control = get_tree().current_scene
	var observed: Array = await _click_open_computer(host)
	assert_true(host.is_computer_open(), "native CheckComputer opens restored board; action=" + str(observed)
		+ "; busy=" + str(host._busy) + "; command=" + str(game.capture_scene_challenge_command()))
	if not host.is_computer_open():
		await _screenshot("content-update-board-open-refused")
		return null
	return host.get_challenge_mount().get_node_or_null("SceneChallengePanel")

func _make_active_board() -> Control:
	if not await _walk_to(UPDATE.line("update.a", "cue")): return null
	await _accept()
	assert_eq(game.capture_run_snapshot_input().scene.active_challenge.challenge_id, UPDATE.A)
	var panel: Control = await _open_board()
	if panel == null: return null
	assert_true(panel.worksheet.grid.focus_cell(323))
	await _click(panel.worksheet.grid.cell_nodes[323])
	assert_eq(game.capture_dating_challenge_state().value.state, "in_progress")
	var hidden := -1
	for index: int in panel.public_view.board.cells.size():
		if "flag" in panel.public_view.board.cells[index].get("actions", []):
			hidden = index
			break
	assert_gte(hidden, 0)
	if hidden < 0: return null
	panel.worksheet.set_mode(&"flag")
	assert_true(panel.worksheet.grid.focus_cell(hidden))
	await _click(panel.worksheet.grid.cell_nodes[hidden])
	panel.worksheet.set_mode(&"reveal")
	return panel

func create_content_update() -> void:
	updated_content = false
	if not _start_services(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var initial := "update.end" if UPDATE.completed_case(case_id) else "Day1"
	var started: Dictionary = saves.start_scene_new_run("target." + initial, {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if not await _await_ready() or not await _wait_line(UPDATE.line(initial, "anchor")): return
	# Non-default values exercise preservation, through existing gameplay setters.
	assert_true(game.change_money(37))
	assert_true(game.change_coins(5))
	if UPDATE.completed_case(case_id):
		await _create_completed_update()
		return
	var locator := "slot:1"
	var terminal_capture := {}
	var public_board := {}
	if UPDATE.board_case(case_id):
		var panel: Control = await _make_active_board()
		if panel == null: return
		public_board = panel.public_view.board.duplicate(true)
		if case_id == "transfer_terminal":
			var files: RefCounted = saves._storage._file_ops
			var fault := WRITE_REFUSAL.WriteRefusal.new()
			fault.refuse_on = 1
			var autosave_before := _autosave_sha256()
			saves._storage._file_ops = fault
			panel.presentation_changed.connect(func():
				if panel.public_view.get("phase") == "terminal" and terminal_capture.is_empty():
					terminal_capture.merge(bootstrap._capture_paused_checkpoint_inputs(), true))
			var record: Dictionary = game.capture_dating_challenge_state().value
			var mine: int = record.board.mine_indices[0]
			# Remove a flag if the selected mine owns it before revealing.
			if "unflag" in panel.public_view.board.cells[mine].get("actions", []):
				assert_true(panel.worksheet.grid.focus_cell(mine))
				panel.worksheet.set_mode(&"flag")
				await _click(panel.worksheet.grid.cell_nodes[mine])
				panel.worksheet.set_mode(&"reveal")
			assert_true(panel.worksheet.grid.focus_cell(mine))
			await _click(panel.worksheet.grid.cell_nodes[mine])
			for frame: int in 8: await get_tree().process_frame
			saves._storage._file_ops = files
			assert_eq(fault.refused, 0, "terminal board and ordinary continuation do not save")
			assert_eq(_autosave_sha256(), autosave_before)
			if not _ok(terminal_capture): return
			assert_true(terminal_capture.value.snapshot_input.gameplay.scene_challenge_outcomes.is_empty(), "captured terminal board precedes its story result")
			assert_eq(terminal_capture.value.snapshot_input.gameplay.route_context.active_dating_challenge.state, "lost")
			# Deliberately save the exact terminal capture before story continuation;
			# no injected storage failure is needed to stop normal live progression.
			if not _ok(saves.record_stable_checkpoint(terminal_capture.value, &"manual_save")): return
			if not _ok(saves.save_latest_to_slot(1)): return
		else:
			await _click(_controls(get_tree().current_scene, "CheckComputer"))
			if case_id == "resolved_unfinished":
				await _accept()
				if not await _wait_line(UPDATE.line("update.a", "following")): return
				await _accept()
				if not await _wait_line(UPDATE.line("update.after_a", "anchor")): return
				assert_eq(game.scene_challenge_outcomes.size(), 1)
				assert_eq(game.scene_challenge_outcomes.values()[0].outcome, "unfinished")
				assert_eq(game.capture_dating_challenge_state().value.state, "in_progress")
	else:
		var target := UPDATE.line("update.four" if case_id == "history" else "update.one",
			"last" if case_id in ["invalid_choice", "invalid_choice_missing_default"] else "middle")
		if not await _walk_to(target): return
	if terminal_capture.is_empty() and not await _save_partner(1): return
	var path := "user://saves/autosave.json" if locator == "autosave" else "user://saves/slot_1.json"
	var document: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(path))
	if not _ok(document): return
	if case_id in ["invalid_choice", "invalid_choice_missing_default"]:
		# Deliberate saved-input fixture: a formerly authored option is absent.
		# Retain the real Run, reading position and all gameplay consequences.
		document.value.current_snapshot.snapshot.gameplay.scene_choices["TEST.choice.update.one"] = "retired"
		if not _write_json(path, document.value): return
	var saved: Dictionary = document.value.current_snapshot.snapshot
	var reading: Dictionary = saved.narrative_checkpoint.reading_session
	assert_eq(reading.schema_version, 7)
	assert_lte(reading.history_sections.size(), 3)
	if case_id == "deleted_checkpoint":
		assert_eq(reading.story_day, 1)
		assert_eq(reading.recovery_anchor, {"entry_id": "update.one", "line_id": UPDATE.line("update.one", "anchor")},
			"native Save retains the authored checkpoint that the next content revision deletes")
		assert_eq(reading.captions.back().line_id, UPDATE.line("update.one", "middle"))
	var proof := {"creator_pid": OS.get_process_id(), "case": case_id, "locator": locator, "path": path,
		"source_sha256": FileAccess.get_sha256(path), "snapshot": saved,
		"reading": reading, "public_board": public_board, "record": saved.gameplay.route_context.get("active_dating_challenge", {}).duplicate(true),
		"profile": profile.get_profile_snapshot().duplicate(true)}
	if not _write_json(PROOF, proof): return
	_write_json("res://.godot/ci/content-update-create-proof.json", proof)
	await _screenshot("content-update-" + case_id + "-old")

func _history_assertions(proof: Dictionary) -> void:
	var before_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var before_bytes := FileAccess.get_sha256("user://profile.json")
	var current: Dictionary = bridge.get_reading_history()
	if not _ok(current): return
	var ids: Array = current.value.captions.map(func(row: Dictionary) -> String: return row.line_id)
	var unique := {}
	for id: String in ids: unique[id] = true
	assert_eq(ids.size(), unique.size(), "History never duplicates checkpoint boundaries")
	for id: String in ids: assert_false("inserted_" in id, "unseen inserted lines are not backfilled")
	if case_id == "history":
		var expected: Array = []
		for section: Array in proof.reading.history_sections:
			for id: String in section:
				if id != UPDATE.line("update.two", "middle"): expected.append(id)
		assert_eq(ids, expected, "History preserves exactly the last three encountered sections")
		assert_false(UPDATE.line("Day1", "anchor") in ids)
		assert_false(UPDATE.line("update.one", "anchor") in ids)
		assert_false(UPDATE.line("update.two", "middle") in ids, "deleted encountered line is omitted")
		assert_true(UPDATE.line("update.three", "middle") in ids)
		for row: Dictionary in current.value.captions:
			if row.line_id == UPDATE.line("update.three", "middle"):
				assert_eq(row.text, "TEST update.three middle revised.")
		var beat: Dictionary = bridge._reading_session._caption_variants_by_line[UPDATE.line("update.three", "middle")]
		assert_false(profile.is_caption_variant_witnessed(beat), "History's revised prior text is still unread")
	var layer: Node = _caption()
	await _click(layer.transport_rail._history_button)
	assert_true(layer._history_open)
	await _screenshot("content-update-" + case_id + "-history")
	await _click(layer._history_overlay.close_button)
	assert_false(layer._history_open)
	assert_eq(profile.get_profile_snapshot(), before_profile)
	assert_eq(FileAccess.get_sha256("user://profile.json"), before_bytes, "History writes no global marks")
	assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256)

func load_content_update() -> void:
	updated_content = true
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.creator_pid)
	assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256)
	if not _start_services(): return
	assert_eq(case_id, proof.case)
	if case_id in ["invalid_choice", "invalid_choice_missing_default"]:
		assert_eq(preload("res://scripts/narrative/DialogicEntryManifest.gd").scene_registration_fingerprint(),
			proof.snapshot.scene.registration_sha256, "file-only edit does not rebuild the shipped registry")
	if case_id in ["deleted_line", "deleted_checkpoint", "completed_deleted", "invalid_choice_missing_default"]:
		await _load_missing_content(proof, false)
		return
	if UPDATE.completed_case(case_id):
		await _load_completed_update(proof, false)
		return
	var backup := preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", proof.locator)
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if not await _await_ready(): return
	_assert_gameplay_preserved(proof.snapshot.gameplay)
	assert_eq(game.capture_run_snapshot_input().lifecycle.run_id, proof.snapshot.lifecycle.run_id)
	assert_eq(game.capture_run_snapshot_input().lifecycle.branch_id, proof.snapshot.lifecycle.branch_id)
	assert_eq(game.capture_dating_challenge_state().value, proof.record, "exact selected physical prefix survives migration")
	assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256)
	if not UPDATE.board_case(case_id):
		var expected := UPDATE.line("update.four" if case_id == "history" else "update.one",
			"last" if case_id == "invalid_choice" else "middle")
		if not await _wait_line(expected): return
		if case_id == "wording": assert_eq(_native_observation().text, "TEST update.one middle revised.")
		await _history_assertions(proof)
		if case_id == "invalid_choice":
			await _accept()
			if not await _wait_line(UPDATE.line("update.two", "anchor")): return
			_assert_gameplay_preserved(proof.snapshot.gameplay)
			assert_eq(game.scene_choices["TEST.choice.update.one"], "retired", "fallback does not replay or rewrite old consequences")
			assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256)
		if case_id == "wording":
			await _accept()
			if not await _wait_line(UPDATE.line("update.one", "inserted_after")): return
			assert_eq(game.capture_run_snapshot_input().gameplay, proof.snapshot.gameplay, "new prose changes no gameplay")
	else:
		if case_id in ["transfer_active", "transfer_terminal"]:
			assert_eq(bridge._runtime_adapter.current_line_id(), proof.reading.captions.back().line_id,
				"board transfer starts at the retained saved cue, without a recovery rewind")
		if not await _verify_board_continuation(proof): return
	await _screenshot("content-update-" + case_id + "-loaded")
	if not await _save_partner(3): return
	var persisted: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_3.json"))
	if not _ok(persisted): return
	var reloaded_proof := {"loader_pid": OS.get_process_id(), "case": case_id,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_3.json"),
		"snapshot": persisted.value.current_snapshot.snapshot, "old_source": proof,
		"binding_retry": binding_retry}
	if not _write_json("user://content-update-current-proof.json", reloaded_proof): return
	_write_json("res://.godot/ci/content-update-load-proof.json", {"creator_pid": proof.creator_pid,
		"loader_pid": OS.get_process_id(), "case": case_id, "source_sha256": proof.source_sha256,
		"preserved_run_id": proof.snapshot.lifecycle.run_id, "ready_count": ready_count})

func _verify_board_continuation(proof: Dictionary) -> bool:
	if case_id == "active_board":
		var panel: Control = await _open_board()
		if panel == null: return false
		assert_eq(game.capture_dating_challenge_state().value, proof.record)
		assert_eq(panel.public_view.board, proof.public_board, "restored board is rendered from saved cells")
		await _screenshot("content-update-active-board")
		return true
	var outcomes_before: Dictionary = game.scene_challenge_outcomes.duplicate(true)
	if not await _walk_to(UPDATE.line("update.b", "cue")): return false
	if case_id == "transfer_active":
		# Manual Save retains suspended A. Admitting B is a live-only operation.
		if not await _save_partner(2): return false
		var source: Dictionary = game.capture_run_snapshot_input().duplicate(true)
		var attempts: Dictionary = profile.get_profile_snapshot().dating_attempts.duplicate(true)
		var files: RefCounted = saves._storage._file_ops
		var fault := WRITE_REFUSAL.WriteRefusal.new()
		fault.refuse_on = 1
		var autosave_before := _autosave_sha256()
		saves._storage._file_ops = fault
		await _accept()
		saves._storage._file_ops = files
		assert_eq(fault.refused, 0, "binding B never attempts a game-save write")
		assert_eq(_autosave_sha256(), autosave_before)
		assert_false(_caption().is_reading_recovery_active(), "live binding requires no storage retry")
		assert_eq(game.capture_dating_challenge_state().value, proof.record)
		assert_eq(profile.get_profile_snapshot().dating_attempts, attempts)
		assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256)
		await _screenshot("content-update-binding-live")
		binding_retry = {"refused_writes": fault.refused, "retry_activations": 0,
			"autosave_unchanged": _autosave_sha256() == autosave_before,
			"suspended_slot_sha256": FileAccess.get_sha256("user://saves/slot_2.json"),
			"suspended_gameplay": source.gameplay}
	else:
		await _accept()
	assert_eq(game.capture_run_snapshot_input().scene.active_challenge.challenge_id, UPDATE.B)
	if case_id == "resolved_unfinished":
		assert_eq(game.scene_challenge_outcomes, outcomes_before)
		var panel: Control = await _open_board()
		if panel == null: return false
		assert_eq(panel.public_view.phase, "never_started", "resolved A is not transferred into B")
		return true
	assert_eq(game.capture_dating_challenge_state().value, proof.record, "binding B does not rewrite physical A")
	var before: Dictionary = game.capture_run_snapshot_input().gameplay.duplicate(true)
	if case_id == "transfer_terminal":
		var host: Control = get_tree().current_scene
		var failures: Array = []
		host.get_challenge_mount().child_entered_tree.connect(func(child: Node):
			if child.has_signal("presentation_failed"):
				child.presentation_failed.connect(func(code: StringName): failures.append(String(code))))
		var opened: Array = await _click_open_computer(host)
		if not await _wait_line(UPDATE.line("update.b", "following")):
			var panel: Node = host.get_challenge_mount().get_node_or_null("SceneChallengePanel")
			var diagnostic := {"open_result": opened, "presentation_failures": failures, "computer_open": host.is_computer_open(),
				"caption_held": bridge.is_computer_caption_held(), "current_command": game.capture_scene_challenge_command(),
				"panel_phase": panel.public_view.get("phase") if panel != null else null,
				"panel_command": panel._command if panel != null else {},
				"record_context": game.capture_dating_challenge_state().value.get("context", {}),
				"physical_reference": game.route_context.get("dating_active_attempt_ref", {}),
				"live_branch": game.capture_run_snapshot_input().lifecycle.branch_id}
			print("CONTENT_UPDATE_TERMINAL_REFUSED ", diagnostic)
			_write_json("res://.godot/ci/content-update-terminal-refusal.json", diagnostic)
			return false
		await _accept()
		if not await _wait_line(UPDATE.line("update.end", "anchor")): return false
		assert_eq(game.scene_challenge_outcomes.size(), 1)
		var result: Dictionary = game.scene_challenge_outcomes.values()[0]
		assert_eq(result.challenge_id, UPDATE.B)
		assert_eq(result.outcome, "lost")
		assert_eq(result.physical_slot, ATTEMPT.semantic_slot(proof.record.context))
		for key: String in before:
			if key not in ["scene_challenge_outcomes", "route_context"]:
				assert_eq(game.capture_run_snapshot_input().gameplay[key], before[key], "terminal transfer does not repeat " + key)
	else:
		var panel: Control = await _open_board()
		if panel == null: return false
		assert_eq(game.capture_dating_challenge_state().value, proof.record)
		assert_eq(panel.public_view.board, proof.public_board)
		await _screenshot("content-update-transferred-active-board")

	return true

func reload_current_content() -> void:
	updated_content = true
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://content-update-current-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.loader_pid)
	assert_ne(OS.get_process_id(), proof.old_source.creator_pid)
	if str(proof.case) not in ["deleted_line", "deleted_checkpoint", "completed_deleted", "invalid_choice_missing_default"] and not UPDATE.completed_case(str(proof.case)):
		assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), proof.slot_sha256)
	if not _start_services(): return
	if case_id in ["deleted_line", "deleted_checkpoint", "completed_deleted", "invalid_choice_missing_default"]:
		await _load_missing_content(proof.old_source, true, int(proof.loader_pid))
		return
	if UPDATE.completed_case(case_id):
		await _load_completed_update(proof.old_source, true, int(proof.loader_pid))
		return
	if case_id == "transfer_active":
		assert_eq(proof.binding_retry.refused_writes, 0)
		assert_eq(proof.binding_retry.retry_activations, 0)
		assert_true(proof.binding_retry.autosave_unchanged)
		assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.binding_retry.suspended_slot_sha256)
		if not await _load_partner(2, true): return
		if not await _wait_line(UPDATE.line("update.b", "cue")): return
		assert_eq(game.capture_run_snapshot_input().gameplay, proof.binding_retry.suspended_gameplay)
		assert_eq(game.capture_dating_challenge_state().value, proof.old_source.record)
		assert_false(game.capture_scene_challenge_command().get("ok", false), "suspended physical A has no playable native B authority")
		await _screenshot("content-update-suspended-reloaded")
	if not await _load_partner(3, case_id != "transfer_active"): return
	if case_id == "invalid_choice":
		if not await _wait_line(UPDATE.line("update.two", "anchor")): return
		assert_eq(game.scene_choices["TEST.choice.update.one"], "retired")
	_assert_gameplay_preserved(proof.snapshot.gameplay)
	assert_eq(game.capture_dating_challenge_state().value, proof.snapshot.gameplay.route_context.get("active_dating_challenge", {}))
	assert_eq(game.capture_run_snapshot_input().scene.active_challenge, proof.snapshot.scene.active_challenge)
	assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), proof.slot_sha256)
	if case_id in ["active_board", "transfer_active"]:
		var panel: Control = await _open_board()
		if panel == null: return
		assert_eq(panel.public_view.board, proof.old_source.public_board)
		assert_eq(game.scene_challenge_outcomes, proof.snapshot.gameplay.scene_challenge_outcomes)
	await _screenshot("content-update-" + case_id + "-reloaded")
	_write_json("res://.godot/ci/content-update-reload-proof.json", {"case": case_id,
		"creator_pid": proof.old_source.creator_pid, "loader_pid": proof.loader_pid,
		"reload_pid": OS.get_process_id(), "binding_live": case_id == "transfer_active" and proof.binding_retry.refused_writes == 0 and proof.binding_retry.retry_activations == 0 and proof.binding_retry.autosave_unchanged,
		"binding_retry_detail": proof.binding_retry,
		"slot_sha256": proof.slot_sha256})

func _create_completed_update() -> void:
	if not await _walk_to(UPDATE.line("update.end", "last")): return
	var gameplay: Dictionary = game.capture_run_snapshot_input().gameplay.duplicate(true)
	assert_eq(game.capture_run_snapshot_input().lifecycle.state, "PLAYING")
	assert_false(UPDATE.FINISH in profile.get_profile_snapshot().gallery_unlocks)
	await _screenshot("content-update-completed-old-final-caption")
	var autosave_before := _autosave_sha256()
	var completed_capture := {}
	bridge.next_request_finished.connect(func(_frontier: Dictionary, result: Dictionary) -> void:
		if result.get("ok", false):
			completed_capture.merge(get_node("/root/ApplicationBootstrap")._capture_paused_checkpoint_inputs(), true), CONNECT_ONE_SHOT)
	await _accept()
	if not await _wait_route(MENU): return
	assert_eq(game._run_lifecycle.to_dict().state, "COMPLETED")
	assert_eq(game.capture_run_snapshot_input().gameplay, gameplay, "Finish grants no repeated gameplay reward")
	assert_false(game.capture_live_session().value.active)
	assert_eq(_autosave_sha256(), autosave_before, "Finish does not create an Autosave")
	if not _ok(completed_capture): return
	assert_eq(completed_capture.value.snapshot_input.lifecycle.state, "COMPLETED")
	# Deliberately save the captured completed Run through the real save owner;
	# the production Finish itself has no automatic game-save side effect.
	if not _ok(saves.record_stable_checkpoint(completed_capture.value, &"manual_save")): return
	if not _ok(saves.save_latest_to_slot(4)): return
	var path := "user://saves/slot_4.json"
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(path))
	if not _ok(parsed): return
	if case_id == "completed_deleted" and not _write_without_completion_provenance(path, parsed.value): return
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	assert_eq(snapshot.lifecycle.state, "COMPLETED")
	assert_eq(snapshot.lifecycle.has("completed_registration_sha256"), case_id != "completed_deleted")
	assert_eq(snapshot.narrative_checkpoint.reading_session.captions.back().line_id, UPDATE.line("update.end", "last"))
	assert_true(UPDATE.FINISH in profile.get_profile_snapshot().gallery_unlocks)
	var proof := {"creator_pid": OS.get_process_id(), "case": case_id, "locator": "slot:4", "path": path,
		"source_sha256": FileAccess.get_sha256(path), "snapshot": snapshot,
		"profile": profile.get_profile_snapshot().duplicate(true), "profile_sha256": FileAccess.get_sha256("user://profile.json")}
	if not _write_json(PROOF, proof): return
	_write_json("res://.godot/ci/content-update-create-proof.json", proof)
	await _screenshot("content-update-" + case_id + "-completed-title")

func _load_completed_update(proof: Dictionary, third: bool, prior_loader_pid: int = 0) -> void:
	assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256)
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	var backup := preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", proof.locator)
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_true(loaded.get("ok", false) or loaded.get("code") == &"scene_activation_pending", str(loaded))
	if not await _wait_route(MENU): return
	assert_eq(game._run_lifecycle.to_dict().state, "COMPLETED", "current prose cannot reopen a completed Run")
	assert_eq(game._run_lifecycle.to_dict().run_id, proof.snapshot.lifecycle.run_id)
	assert_eq(game._run_lifecycle.to_dict().completed_registration_sha256, proof.snapshot.scene.registration_sha256,
		"completion retains original registration provenance, including legacy field derivation")
	assert_ne(game.capture_run_snapshot_input().scene.registration_sha256, proof.snapshot.scene.registration_sha256)
	_assert_gameplay_preserved(proof.snapshot.gameplay)
	assert_false(game.capture_live_session().value.active)
	assert_eq(profile.get_profile_snapshot(), proof.profile, "Load executes no Finish, discovery or unseen appended caption")
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256, "completed source bytes are preserved")
	await _screenshot("content-update-" + case_id + ("-reloaded-title" if third else "-loaded-title"))
	var evidence := {"case": case_id, "creator_pid": proof.creator_pid,
		"loader_pid": prior_loader_pid if third else OS.get_process_id(), "old_source": proof,
		"reload_pid": OS.get_process_id() if third else 0,
		"state": game._run_lifecycle.to_dict().state, "source_sha256": proof.source_sha256}
	if not third and not _write_json("user://content-update-current-proof.json", evidence): return
	_write_json("res://.godot/ci/content-update-" + ("reload" if third else "load") + "-proof.json", evidence)

func _write_without_completion_provenance(path: String, document: Dictionary) -> bool:
	# TEST optional-lifecycle-field conversion follows an actual native Finish.
	# Reading remains schema7; gameplay, Profile and saved receipts stay real.
	var bundles: Array = [document.current_snapshot]
	bundles.append_array(document.recovery_journal)
	for bundle: Dictionary in bundles:
		assert_eq(bundle.snapshot.narrative_checkpoint.reading_session.schema_version, 7)
		bundle.snapshot.lifecycle.erase("completed_registration_sha256")
	# The old registration is still installed: prove this prior-format document
	# is admissible before the next process introduces any content change.
	if not _ok(preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(document)): return false
	return _write_json(path, document)

## The final child deliberately exits through the production Quit button. Its
## external runner verifies exit status and source bytes after the process ends.
func _load_missing_content(proof: Dictionary, quit_process: bool, prior_loader_pid: int = 0) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var autosave_before := _autosave_sha256()
	var backup := preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var result: Dictionary = backup.prepare_action("load", proof.locator)
	if result.get("ok", false): result = backup.commit_action(result.value.token)
	if case_id == "invalid_choice_missing_default":
		assert_eq(result.get("code"), &"scene_activation_pending", str(result))
		if not await _await_ready() or not await _wait_line(UPDATE.line("update.one", "last")): return
		_assert_gameplay_preserved(proof.snapshot.gameplay)
		if not bridge.next_request_finished.is_connected(_observe_next_result):
			bridge.next_request_finished.connect(_observe_next_result)
		await _accept()
		result = last_next_result
		_assert_gameplay_preserved(proof.snapshot.gameplay)
	assert_false(result.get("ok", false), str(result))
	assert_eq(result.get("code"), &"reading_content_error", str(result))
	var error_layer: Node = bootstrap.get_node_or_null("ContentError")
	assert_not_null(error_layer)
	if error_layer == null: return
	var confirmation: Control = error_layer.get_node("ContentErrorConfirmation")
	var missing_id := "update.two" if case_id == "invalid_choice_missing_default" else (
		UPDATE.line("update.end", "last") if case_id == "completed_deleted" else UPDATE.line("update.one", "middle"))
	assert_true(str(confirmation.request.body).contains(missing_id), "the visible diagnosis identifies the saved dialogue ID")
	assert_false(confirmation.cancel_button.visible)
	for pressed: bool in [true, false]:
		var cancel := InputEventAction.new()
		cancel.action = &"ui_cancel"
		cancel.pressed = pressed
		get_viewport().push_input(cancel, true)
		await get_tree().process_frame
	for frame: int in 5: await get_tree().process_frame
	assert_true(is_instance_valid(confirmation) and confirmation.is_visible_in_tree(), "Escape cannot dismiss the content error")
	assert_eq(get_viewport().gui_get_focus_owner(), confirmation.confirm_button, "Quit retains keyboard focus after Escape and background frames")
	assert_true(get_tree().paused)
	assert_true(bootstrap._application_gate.is_fatal_latched())
	assert_false(saves.save_latest_to_slot(3).get("ok", false), "failed continuation cannot save")
	assert_false(saves.autosave_latest().get("ok", false), "failed continuation cannot autosave")
	assert_eq(FileAccess.get_sha256(proof.path), proof.source_sha256)
	assert_eq(_autosave_sha256(), autosave_before)
	assert_false(FileAccess.file_exists("user://saves/slot_3.json"))
	await _screenshot("content-update-" + case_id + ("-quit" if quit_process else "-error"))
	var evidence := {"case": case_id, "creator_pid": proof.creator_pid,
		"loader_pid": prior_loader_pid if quit_process else OS.get_process_id(),
		"reload_pid": OS.get_process_id() if quit_process else 0,
		"source_sha256": proof.source_sha256, "source_filename": "slot_4.json" if case_id == "completed_deleted" else "slot_1.json",
		"autosave_sha256": autosave_before, "missing_id": missing_id,
		"old_source": proof, "assertions": get_assert_count(), "failures": get_fail_count(), "quit_activated": false}
	if not quit_process:
		if not _write_json("user://content-update-current-proof.json", evidence): return
		_write_json("res://.godot/ci/content-update-load-proof.json", evidence)
		# End this assertion child normally so GUT writes its complete JUnit.
		get_tree().paused = false
		return
	if get_fail_count() != 0: return
	confirmation.finished.connect(func(accepted: bool):
		evidence.quit_activated = accepted
		evidence.assertions = get_assert_count()
		evidence.failures = get_fail_count()
		_write_json("res://.godot/ci/content-update-reload-proof.json", evidence))
	if case_id == "invalid_choice_missing_default":
		# Use the modal's existing focus: grabbing it here would hide background
		# controls stealing focus while the failed reading scene remains mounted.
		for pressed: bool in [true, false]:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.physical_keycode = KEY_ENTER
			enter.pressed = pressed
			get_viewport().push_input(enter, true)
			await get_tree().process_frame
		for frame: int in 4: await get_tree().process_frame
	else:
		await _click(confirmation.confirm_button)
	fail_test("Production Quit did not terminate the process")
