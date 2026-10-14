extends "res://tests/integration/scene_computer_child.gd"
## Actual viewport reveals and Auto; layout inspection is TEST solver knowledge only.
const ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
var _second_publications: Dictionary = {}
var _second_visible := false
var _terminal_record: Dictionary = {}

func _observe_second() -> void:
	if bridge == null or not bridge.has_reading_session(): return
	for row: Dictionary in bridge._reading_session.ledger.snapshot().captions:
		if row.beat.line_id == "line.scene.test.b.two":
			_second_publications[row.publication_id] = true
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
	assert_eq(result.outcome, "won")
	assert_eq(result.target_id, "target_a")
	assert_true(result.attempt_proof is Dictionary)
	if not result.attempt_proof is Dictionary: return {}
	var proof: Dictionary = result.attempt_proof
	var retained: Dictionary = profile.get_dating_attempt(proof.run_id, proof.slot_id, proof.attempt_id, proof.branch_id)
	if not _ok(retained): return {}
	if not _ok(ATTEMPTS.validate_attempt_proof(retained.value, proof)): return {}
	assert_eq(retained.value.record.state, "won")
	assert_true(retained.value.record.board.terminal)
	return result

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
		var safe := -1
		for index: int in panel.public_view.board.cells.size():
			if not record.board.mine_indices.has(index) and "reveal" in panel.public_view.board.cells[index].actions:
				if safe < 0: safe = index
				if record.board.adjacency_counts[index] == 0:
					safe = index
					break
		assert_gte(safe, 0, "Active board has a remaining safe reveal.")
		if safe < 0: return
		assert_true(panel.worksheet.grid.focus_cell(safe))
		await get_tree().process_frame
		await _click(panel.worksheet.grid.cell_nodes[safe])
	assert_false(_terminal_record.is_empty(), "Native cell inputs reach terminal.")
	if _terminal_record.is_empty(): return
	assert_eq(_terminal_record.state, "won")
	var arrived := false
	var caption_captured := false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		_observe_second()
		if _second_visible and not caption_captured:
			await _screenshot("completion-caption")
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
	await _screenshot("completed-target")
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
		"terminal_record": _terminal_record, "second_publications": _second_publications.size(),
		"second_visible": _second_visible, "slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"auto": profile.get_preference(&"preferences.reading.auto_enabled", false)}
	assert_eq(str(proof.slot_sha256).length(), 64)
	if not _write_json("user://scene-completion-proof.json", proof): return
	_write_json("res://.godot/ci/scene-completion-create-proof.json", proof)

func load_completed_scene() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://scene-completion-proof.json"))
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
	var closure: Dictionary = _closure()
	if closure.is_empty(): return
	assert_eq(closure.attempt_proof, proof.closure.attempt_proof, "Terminal board proof survives fresh-process Load.")
	var terminal: Dictionary = closure.attempt_proof
	var retained: Dictionary = profile.get_dating_attempt(terminal.run_id, terminal.slot_id, terminal.attempt_id, terminal.branch_id)
	if not _ok(retained): return
	assert_eq(retained.value.record, proof.terminal_record)
	assert_eq(profile.get_preference(&"preferences.reading.auto_enabled", false), proof.auto)
	assert_true(proof.auto)
	assert_false(get_tree().paused)
	await _screenshot("completed-restored")
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
	assert_eq(_closure(), closure, "Saving completed Load creates no second closure or changed proof.")
	assert_eq(profile.get_profile_snapshot(), before_profile, "Saving cannot create another attempt.")
	var after_attempt: Dictionary = profile.get_dating_attempt(terminal.run_id, terminal.slot_id,
		terminal.attempt_id, terminal.branch_id)
	assert_eq(after_attempt, retained)
	var second_hash := FileAccess.get_sha256("user://saves/slot_2.json")
	assert_eq(second_hash.length(), 64)
	proof["second_save_sha256"] = second_hash
	proof["loader_process_id"] = OS.get_process_id()
	proof["loaded_closure"] = closure
	_write_json("res://.godot/ci/scene-completion-load-proof.json", proof)
