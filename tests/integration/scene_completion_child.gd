extends "res://tests/integration/scene_computer_child.gd"
## Actual viewport reveals and Auto; layout inspection is TEST solver knowledge only.
const ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
var _second_publications: Dictionary = {}
var _second_visible := false
var _terminal_record: Dictionary = {}

func _observe_second() -> void:
	if bridge == null or not bridge.has_reading_session(): return
	var frontier: Dictionary = bridge._reading_session.ledger.latest_frontier()
	if frontier.get("line_id") == "line.scene.test.b.two":
		_second_publications[frontier.publication_id] = true
	var caption: Node = _caption()
	if caption != null and bridge._runtime_adapter.current_line_id() == "line.scene.test.b.two" \
			and caption.caption_text.is_visible_in_tree() and "B second." in caption.caption_text.text:
		_second_visible = true

func _closure() -> Dictionary:
	var closures: Array = []
	var receipts: Dictionary = game.capture_run_snapshot_input().command_receipts
	for receipt: Dictionary in receipts.values():
		if receipt.get("scene_event", {}).get("result", {}).get("kind") == "challenge_closed":
			closures.append(receipt.scene_event.result.duplicate(true))
	assert_eq(closures.size(), 1, "Exactly one End closure is retained.")
	if closures.size() != 1: return {}
	var result: Dictionary = closures[0]
	assert_true(receipts.has(result.playable_command_id))
	if not receipts.has(result.playable_command_id): return {}
	assert_eq(receipts[result.playable_command_id].scene_event.result.kind, "challenge_playable")
	assert_eq(result.outcome, _expected_outcome())
	assert_eq(result.target_id, "target_a")
	assert_true(result.attempt_proof is Dictionary)
	if not result.attempt_proof is Dictionary: return {}
	return result

func _check_completed_run(closure: Dictionary, observed_board: Dictionary) -> Dictionary:
	var snapshot: Dictionary = game.capture_run_snapshot_input()
	var record: Dictionary = snapshot.gameplay.route_context.active_dating_challenge
	var reference: Dictionary = snapshot.gameplay.route_context.dating_active_attempt_ref
	var proof: Dictionary = closure.attempt_proof
	var hashed: Dictionary = preload("res://scripts/domain/schedule/ScheduleStateSchema.gd").canonical_sha256(record)
	if not _ok(hashed): return {}
	assert_true(ATTEMPTS.validate_record(record))
	assert_eq(hashed.value.sha256, proof.record_sha256)
	assert_eq(snapshot.lifecycle.run_id, proof.run_id)
	assert_eq(record.board.revision + 1, proof.revision)
	assert_eq(proof.publication.kind, "live")
	assert_eq(proof.publication.state_sha256.length(), 64)
	assert_true(proof.publication.state_sha256.is_valid_hex_number(false))
	assert_eq(record.board, observed_board)
	assert_true(record.board.terminal)
	assert_eq(record.state, _expected_outcome())
	assert_eq(ATTEMPTS.semantic_slot(record.context), proof.slot_id)
	assert_eq(record.spec.board_token, proof.attempt_id)
	assert_eq(reference, {"attempt_id": proof.attempt_id, "branch_id": proof.branch_id, "generation": proof.generation})
	assert_eq(snapshot.gameplay.scene_challenge_outcomes, {closure.challenge_occurrence: {
		"outcome": _expected_outcome(), "challenge_id": record.context.challenge_id, "physical_slot": proof.slot_id}})
	return record

func create_completed_scene() -> void:
	if not await _start_playable(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_delay", "short")): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", true)): return
	var host: Control = get_tree().current_scene
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
	var held_checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(held_checkpoint): return
	assert_true(bridge.is_computer_caption_held())
	await get_tree().create_timer(2.5).timeout
	assert_eq(bridge.capture_reading_checkpoint(false), held_checkpoint,
		"Enabled Auto cannot leave playable while the computer is open.")
	assert_true(host.is_computer_open())
	assert_true(profile.get_preference(&"preferences.reading.auto_enabled", false))
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	for receipt: Dictionary in game.capture_run_snapshot_input().command_receipts.values():
		assert_ne(receipt.get("scene_event", {}).get("result", {}).get("kind", ""), "challenge_closed")
	panel.presentation_failed.connect(func(code: StringName): fail_test("completion reveal refused: " + String(code)))
	# Observe the terminal publication before Bootstrap's deferred close/admission.
	panel.presentation_changed.connect(func():
		if panel.public_view.get("phase") == "terminal":
			_terminal_record = game.capture_dating_challenge_state().value.duplicate(true))
	assert_true(panel.worksheet.grid.focus_cell(323))
	await get_tree().process_frame
	await _click(panel.worksheet.grid.cell_nodes[323])
	for step: int in 324:
		_observe_second()
		if not _terminal_record.is_empty(): break
		var captured: Dictionary = game.capture_dating_challenge_state()
		assert_true(captured.get("ok", false), str(captured.get("code", "")))
		if not captured.get("ok", false): return
		var record: Dictionary = captured.value
		assert_false(record.is_empty())
		if record.is_empty(): return
		var safe: int = _next_terminal_cell(record, panel)
		assert_gte(safe, 0, "Active board has a reveal for the expected terminal outcome.")
		if safe < 0: return
		assert_true(panel.worksheet.grid.focus_cell(safe))
		await get_tree().process_frame
		await _click(panel.worksheet.grid.cell_nodes[safe])
	assert_false(_terminal_record.is_empty(), "Native cell inputs reach terminal.")
	if _terminal_record.is_empty(): return
	assert_eq(_terminal_record.state, _expected_outcome())
	var arrived := false
	var caption_captured := false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		_observe_second()
		if _second_visible and not caption_captured:
			await _screenshot(_capture_label("completion-caption"))
			caption_captured = true
		var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
		if checkpoint.get("ok", false) and checkpoint.value.entry_id == "scene.test.a":
			arrived = true
			break
		await get_tree().process_frame
	assert_true(arrived, "Terminal continuation and Auto reach authored End then target A.")
	assert_true(_second_visible, "B second is rendered before End.")
	assert_eq(_second_publications.size(), 1, "B second has one publication.")
	if not arrived: return
	assert_false(get_tree().current_scene.is_computer_open())
	assert_false(bridge.is_computer_caption_held())
	assert_true(profile.get_preference(&"preferences.reading.auto_enabled", false))
	var closure: Dictionary = _closure()
	if closure.is_empty(): return
	var completed := _check_completed_run(closure, _terminal_record.board)
	if completed.is_empty(): return
	await _screenshot(_capture_label("completed-target"))
	# Use the ordinary direct Save surface; its API is the existing backup owner.
	await _click(_controls(get_tree().current_scene, "Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup(), str(sheet.last_result))
	if not sheet.can_save_backup(): return
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(prepared): return
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return
	sheet.surface.leave_host()
	for frame: int in 5: await get_tree().process_frame
	var proof := {"process_id": OS.get_process_id(), "closure": closure,
		"terminal_record": completed, "second_publications": _second_publications.size(),
		"second_visible": _second_visible, "slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"auto": profile.get_preference(&"preferences.reading.auto_enabled", false)}
	assert_eq(str(proof.slot_sha256).length(), 64)
	if not _write_json("user://" + _proof_prefix() + "-proof.json", proof): return
	_write_json("res://.godot/ci/" + _proof_prefix() + "-create-proof.json", proof)

func load_completed_scene() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://" + _proof_prefix() + "-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	assert_eq(checkpoint.value.entry_id, "scene.test.a")
	var slot := PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(slot): return
	var saved_caption: Dictionary = slot.value.current_snapshot.snapshot.narrative_checkpoint.reading_session.captions.back()
	assert_eq(checkpoint.value.reading_session.frontier, saved_caption)
	assert_eq(bridge._runtime_adapter.current_line_id(), saved_caption.line_id)
	assert_true(bridge._runtime_adapter.is_current_line_complete())
	var closure: Dictionary = proof.closure
	var retained := _check_completed_run(closure, proof.terminal_record.board)
	assert_eq(retained, proof.terminal_record, "Load restores the complete terminal record.")
	assert_true(game.capture_run_snapshot_input().command_receipts.is_empty(), "Load begins a fresh command session.")
	assert_eq(profile.get_preference(&"preferences.reading.auto_enabled", false), proof.auto)
	assert_true(proof.auto)
	assert_false(get_tree().paused)
	await _screenshot(_capture_label("completed-restored"))
	# A restored completed scene can be saved again through the normal host.
	var before_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	await _click(_controls(get_tree().current_scene, "Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup(), str(sheet.last_result))
	if not sheet.can_save_backup(): return
	var second_save: Dictionary = sheet._backup_port.prepare_action("save", "slot:2")
	if not _ok(second_save): return
	if not _ok(await sheet._backup_port.commit_action(second_save.value.token)): return
	sheet.surface.leave_host()
	for frame: int in 5: await get_tree().process_frame
	assert_eq(_check_completed_run(closure, proof.terminal_record.board), retained)
	assert_true(game.capture_run_snapshot_input().command_receipts.is_empty(), "Saving creates no second closure.")
	assert_eq(profile.get_profile_snapshot(), before_profile, "Saving cannot create another attempt.")
	var second_hash := FileAccess.get_sha256("user://saves/slot_2.json")
	assert_eq(second_hash.length(), 64)
	proof["second_save_sha256"] = second_hash
	proof["loader_process_id"] = OS.get_process_id()
	proof["loaded_outcomes"] = game.scene_challenge_outcomes
	_write_json("res://.godot/ci/" + _proof_prefix() + "-load-proof.json", proof)

# The loss journey shares completion/Save assertions and changes only its board input.
func _expected_outcome() -> String:
	return "won"

func _proof_prefix() -> String:
	return "scene-completion"

func _capture_label(label: String) -> String:
	return label

func _next_terminal_cell(record: Dictionary, panel: Control) -> int:
	var safe := -1
	for index: int in panel.public_view.board.cells.size():
		if not record.board.mine_indices.has(index) and "reveal" in panel.public_view.board.cells[index].actions:
			if safe < 0: safe = index
			if record.board.adjacency_counts[index] == 0:
				return index
	return safe
