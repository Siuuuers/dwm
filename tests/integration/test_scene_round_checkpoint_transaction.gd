extends "res://tests/integration/scene_desktop_first_reveal_child.gd"
## Actual generated ordinary board, Run9 writer and canonical consequence ledger.
## Run in an isolated test_manual process. Rendered Apps journeys are separate.

class CustodyFault extends RefCounted:
	var port: Object
	var phase := ""
	var hits := 0
	var validator: Callable
	func configure_scene_round_authority(owner: Object, callback: Callable) -> Dictionary:
		validator = callback
		return port.configure_scene_round_authority(owner, callback)
	func commit_scene_round(input: Dictionary, checkpoint: Dictionary) -> Dictionary:
		port.set("_scene_round_validator", _validate)
		var result: Dictionary = port.commit_scene_round(input, checkpoint)
		port.set("_scene_round_validator", validator)
		return result
	func _validate(input: Dictionary, checkpoint: Dictionary, at_phase: String) -> bool:
		if at_phase == phase:
			hits += 1
			input.gameplay.money -= 1
		return validator.call(input, checkpoint, at_phase)

func _request() -> Dictionary:
	var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	if not _ok(issued): return {}
	var board: Dictionary = bootstrap._desktop_board_state.capture()
	return {"transaction_id": issued.value.token, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"expected_identity": board.identity.duplicate(true), "expected_revision": int(board.revision)}

func _terminal_board() -> bool:
	var port: RefCounted = _desktop_port()
	if port == null: return false
	var projected: Dictionary = port.pull("beginner")
	if not _ok(projected): return false
	if not _ok(port.dispatch("reveal", 0, int(projected.value.revision))): return false
	var board: Dictionary = bootstrap._desktop_board_state.capture()
	assert_false(board.board.board.terminal, "known deterministic first reveal remains active")
	if board.board.board.terminal: return false
	var request := _request()
	if request.is_empty(): return false
	request.cell_index = int(board.board.board.mine_indices[0])
	var owner: Object = bootstrap._retained_minesweeper_round_coordinator_app
	if not _ok(owner.reveal(request)): return false
	assert_true(bootstrap._desktop_board_state.capture().board.board.terminal)
	assert_false(bootstrap._desktop_board_state.has_settled_inspection())
	assert_false(bootstrap._desktop_board_state.capture().settled_inspection)
	return true

func test_scene_round_physical_refusal_retry_conflict_and_uncertain_acknowledgment() -> void:
	if not _start_services(): return
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready() or not await _line_ready(): return
	if not await _terminal_board(): return
	var original_spec: Dictionary = bootstrap._desktop_board_state.capture().board.spec.duplicate(true)
	assert_eq(original_spec.difficulty_id, "beginner")
	assert_false(bootstrap._desktop_board_state.capture().board.has("paid_start_receipt"))
	# Later selection and ownership changes do not change the first board's frozen reward tier.
	game.minesweeper_selected_difficulty = "expert"
	game.inventory["debug_key"] = 1
	assert_eq(bootstrap._desktop_board_state.capture().board.spec, original_spec)
	var owner: Object = bootstrap._retained_minesweeper_round_coordinator_app
	var request := _request()
	if request.is_empty(): return
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	var actual_port: Object = game._narrative_checkpoint_port
	var probe := CustodyFault.new()
	probe.port = actual_port
	game._narrative_checkpoint_port = probe
	for phase: String in ["before_prepare", "before_commit"]:
		probe.phase = phase
		var hits: int = probe.hits
		var refused: Dictionary = owner.complete_round(request)
		assert_false(refused.get("ok", false), str(refused))
		assert_false(refused.get("committed", false))
		assert_eq(probe.hits, hits + 1, "validator phase reached")
		assert_eq(game.capture_run_snapshot_input(), before)
		assert_eq(bridge.capture_reading_checkpoint(false), reading)
	game._narrative_checkpoint_port = actual_port
	var blocked := ProjectSettings.globalize_path("user://saves/autosave.json.next")
	assert_eq(DirAccess.make_dir_absolute(blocked), OK)
	if not DirAccess.dir_exists_absolute(blocked): return
	var disk: Dictionary = saves._storage.read_text("autosave.json")
	var refused: Dictionary = owner.complete_round(request)
	assert_eq(DirAccess.remove_absolute(blocked), OK)
	assert_false(refused.get("ok", false), str(refused))
	assert_false(refused.get("committed", false))
	assert_true(refused.get("rolled_back", false), str(refused))
	assert_eq(game.capture_run_snapshot_input(), before)
	assert_eq(saves._storage.read_text("autosave.json"), disk)
	assert_false(bootstrap._desktop_board_state.has_settled_inspection())
	assert_false(bootstrap._desktop_board_state.capture().settled_inspection)
	var accepted: Dictionary = owner.complete_round(request)
	if not _ok(accepted): return
	var after: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_eq(after.gameplay.money, before.gameplay.money + 1, "beginner explosion reward ignores selected expert tier")
	assert_eq(after.desktop.board.board.spec, original_spec)
	assert_eq(after.command_receipts[request.transaction_id].scene_round_completion.completion.difficulty, "beginner")
	assert_eq(after.gameplay.minesweeper_app_rounds_finished_today, 1)
	assert_eq(after.desktop.consequence.shop_ledger.base_completion_receipts.size(), 1)
	assert_true(bootstrap._desktop_board_state.has_settled_inspection())
	assert_true(after.desktop.board.settled_inspection)
	assert_false(after.desktop.board.has("terminal_receipts"),
		"current settlement stores its fact without terminal history")
	assert_eq(after.lifecycle, before.lifecycle)
	assert_eq(after.contacts, before.contacts)
	assert_eq(bridge.capture_reading_checkpoint(false), reading)
	var accepted_disk: Dictionary = saves._storage.read_text("autosave.json")
	var written: Dictionary = JSON.parse_string(str(accepted_disk.value))
	assert_eq(written.schema_version, 9)
	assert_eq(written.recovery_journal, [], "the real round checkpoint emits no fallback snapshots")
	assert_true(written.current_snapshot.snapshot.desktop.board.settled_inspection,
		"settled state and the reward share one durable checkpoint")
	assert_eq(written.current_snapshot.snapshot.gameplay.money, after.gameplay.money)
	assert_false(written.current_snapshot.snapshot.command_receipts.has(request.transaction_id),
		"player save omits the app-round retry receipt while retaining settlement")
	if not _ok(owner.complete_round(request)): return
	assert_eq(game.capture_run_snapshot_input(), after)
	assert_eq(saves._storage.read_text("autosave.json"), accepted_disk)
	var fresh_retry := _request()
	var retried: Dictionary = owner.complete_round(fresh_retry)
	if not _ok(retried): return
	assert_true(retried.get("already_applied", false))
	assert_eq(game.capture_run_snapshot_input(), after, "new command cannot pay a settled board twice")
	assert_eq(saves._storage.read_text("autosave.json"), accepted_disk)
	var changed := request.duplicate(true)
	changed.expected_revision += 1
	assert_false(owner.complete_round(changed).get("ok", false))
	assert_eq(game.capture_run_snapshot_input(), after)
	# Start the second real ordinary board. Discard only the settled inspection.
	game.inventory.erase("debug_key")
	var port: RefCounted = _desktop_port()
	if not _ok(port.pull("beginner")): return
	var configuration: Dictionary = owner.get_configuration_context()
	if not _ok(configuration): return
	var replacement := _request()
	replacement.difficulty_id = "beginner"
	if not _ok(owner.replace_board(replacement)): return
	assert_false(bootstrap._desktop_board_state.capture().settled_inspection, "replacement clears old settlement")
	if not await _terminal_board(): return
	request = _request()
	before = game.capture_run_snapshot_input().duplicate(true)
	probe.phase = "after_commit"
	game._narrative_checkpoint_port = probe
	var uncertain: Dictionary = owner.complete_round(request)
	game._narrative_checkpoint_port = actual_port
	assert_false(uncertain.get("ok", false), str(uncertain))
	assert_true(uncertain.get("committed", false), str(uncertain))
	assert_eq(game.capture_run_snapshot_input(), before, "uncertain acknowledgment must not adopt live effects")
	assert_false(bootstrap._desktop_board_state.has_settled_inspection())
	assert_false(bootstrap._desktop_board_state.capture().settled_inspection)
