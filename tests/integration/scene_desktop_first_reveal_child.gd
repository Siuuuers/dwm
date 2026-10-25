extends "res://tests/integration/scene_bootstrap_restart_child.gd"
## FINAL scene owners, actual filesystem refusal, and separate-process selected Load.
## Production presentation commands exercise the retained desktop coordinator; this
## is connected owner coverage, not a claim of desktop UI availability on SceneHost.
const PRESENTATION := preload("res://scripts/application/minesweeper/MinesweeperPresentationPort.gd")
const DESKTOP_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const PROOF := "user://scene-desktop-first-reveal-proof.json"

class ObservedFiles extends "res://scripts/infrastructure/storage/FileOps.gd":
	var refused_writes := 0
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		var result: Dictionary = super.write_bytes(path, bytes)
		if path.replace("\\", "/").ends_with("/autosave.json.next") and result.get("code") == &"write_failed":
			refused_writes += 1
		return result

func _desktop_port() -> RefCounted:
	var port: RefCounted = PRESENTATION.new()
	if not _ok(port.configure(bootstrap.get("_retained_minesweeper_round_coordinator_app"),
			bootstrap.get("_desktop_identity_nonce_issuer"))): return null
	return port

func _settlement_request() -> Dictionary:
	var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	if not _ok(issued): return {}
	var board: Dictionary = bootstrap._desktop_board_state.capture()
	return {"transaction_id": issued.value.token, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"expected_identity": board.identity.duplicate(true), "expected_revision": int(board.revision)}

func _line_ready() -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if bridge._runtime_adapter.current_line_id() == "line.scene.test.a.one" \
				and bridge._runtime_adapter.is_current_line_complete():
			var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
			if not _ok(frontier): return false
			return _ok(bridge.acknowledge_current_line_presentation(frontier))
		await get_tree().process_frame
	fail_test("Native target_a first caption did not finish")
	return false

func _file_hashes() -> Dictionary:
	return {"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"autosave_sha256": FileAccess.get_sha256("user://saves/autosave.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json")}

func _same_files(hashes: Dictionary) -> void:
	assert_eq(_file_hashes(), hashes, "selected source, autosave and persistent Profile bytes unchanged")

func _assert_scene_context_admission(source: Dictionary, reading: Dictionary) -> bool:
	var captured: Dictionary = bootstrap._capture_desktop_board_scene_context(source)
	if not _ok(captured): return false
	assert_eq(captured.value.route_id, "scene")
	assert_eq(captured.value.dialogic_checkpoint, reading)
	var forged: Dictionary = source.duplicate(true)
	forged.scene.active_occurrence_id += ":not-current"
	var refused: Dictionary = bootstrap._capture_desktop_board_scene_context(forged)
	assert_false(refused.get("ok", false))
	assert_eq(refused.get("code"), &"stale_scene_checkpoint_source")
	var gate: RefCounted = bootstrap.get("_application_gate")
	var acquired: Dictionary = gate.acquire(&"causal_transaction")
	if not _ok(acquired): return false
	# safe_marker is an internal checkpoint within this existing lease, not an
	# external command attempting to bypass transaction custody.
	var internal: Dictionary = bootstrap._capture_desktop_board_scene_context(source)
	var released: Dictionary = gate.release(&"causal_transaction", acquired.value.token)
	if not _ok(released): return false
	if not _ok(internal): return false
	assert_eq(internal.value, captured.value)
	for owner: StringName in [&"restore", &"new_run", &"session_abandonment"]:
		acquired = gate.acquire(owner)
		if not _ok(acquired): return false
		refused = bootstrap._capture_desktop_board_scene_context(source)
		released = gate.release(owner, acquired.value.token)
		if not _ok(released): return false
		assert_false(refused.get("ok", false), "foreign lease refuses scene checkpoint context: " + String(owner))
		assert_eq(refused.get("code"), &"TRANSACTION_ACTIVE")
	assert_eq(game.capture_run_snapshot_input(), source, "context capture and refusals never change Run provenance")
	return true

func _assert_scene_snapshot(snapshot: Dictionary, reading: Dictionary, run: Dictionary) -> void:
	assert_eq(snapshot.schema_version, 9)
	assert_eq(snapshot.route_id, "scene")
	assert_eq(snapshot.narrative_checkpoint.reading_session.entry_id, reading.entry_id)
	assert_eq(snapshot.narrative_checkpoint.reading_session.program_index, reading.program_index)
	assert_eq(snapshot.narrative_checkpoint.reading_session.boundary, "line")
	var normalized: Dictionary = DESKTOP_STATE._inspection_normalize(run)
	for key: String in normalized:
		assert_eq(snapshot[key], normalized[key], "durable candidate matches complete live owner input: " + key)
	assert_eq(typeof(snapshot.desktop.board.board.board.outcome), TYPE_STRING, "saved reducer outcome is JSON primitive text")
	assert_eq(typeof(run.desktop.board.board.board.outcome), TYPE_STRING_NAME, "serialization never mutates the live reducer outcome")

func create_scene_desktop_first_reveal() -> void:
	if not _start_services(): return
	var audio: Node = get_node("/root/AudioManager")
	var started: Dictionary = saves.start_scene_new_run("target_a", {
		"route_id": "scene", "content_version": 1, "audio_context": audio.get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	if not await _await_ready(): return
	if not await _line_ready(): return
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	assert_eq(ready_count, 1)
	if not _ok(saves.save_latest_to_slot(1)): return
	var port: RefCounted = _desktop_port()
	if port == null: return
	var projected: Dictionary = port.pull("beginner")
	if not _ok(projected): return
	var before: Dictionary = game.capture_run_snapshot_input()
	assert_eq(before.desktop.board.phase, "NONE")
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	var stable: Dictionary = saves.get_latest_stable_checkpoint()
	if not _ok(stable): return
	var hashes := _file_hashes()
	var history: Dictionary = profile.get_profile_snapshot()
	if not _assert_scene_context_admission(before, reading.value): return
	assert_eq(saves.get_latest_stable_checkpoint(), stable)
	assert_eq(profile.get_profile_snapshot(), history)
	_same_files(hashes)
	# A real directory at the destination refuses FileAccess.WRITE on Windows.
	# The observer calls production FileOps unchanged and records that exact failure.
	var blocked := ProjectSettings.globalize_path("user://saves/autosave.json.next")
	assert_eq(DirAccess.make_dir_absolute(blocked), OK)
	if not DirAccess.dir_exists_absolute(blocked): return
	var original_files: RefCounted = saves._storage._file_ops
	var observed := ObservedFiles.new()
	saves._storage._file_ops = observed
	var refused: Dictionary = port.dispatch("reveal", 0, int(projected.value.revision))
	if observed.refused_writes == 0:
		# Diagnostic-only failure path: presentation intentionally hides owner errors.
		# Keep the filesystem obstruction in place and mint a genuine production
		# transaction to expose the first failing owner boundary without fake success.
		var issued: Dictionary = port._mint_transaction()
		var diagnostic: Dictionary = issued
		if issued.get("ok", false):
			var identity: Variant = port.get("_identity")
			diagnostic = bootstrap.get("_retained_minesweeper_round_coordinator_app").reveal({
				"transaction_id": str(issued.value.token),
				"transaction_issuer_receipt": issued.value.issuer_receipt.duplicate(true),
				"expected_identity": identity.duplicate(true) if identity is Dictionary else null,
				"expected_revision": int(port.get("_revision")), "cell_index": 0,
				"difficulty_id": str(port.get("_difficulty"))})
		print("SCENE_DESKTOP_FIRST_REVEAL_OWNER_DIAGNOSTIC ", JSON.stringify({
			"ok": diagnostic.get("ok", false), "code": str(diagnostic.get("code", "")),
			"message": str(diagnostic.get("message", "")).left(1000),
			"details": str(diagnostic.get("details", {})).left(2400)}))
		saves._storage._file_ops = original_files
		assert_eq(DirAccess.remove_absolute(blocked), OK)
		fail_test("First Reveal did not reach the obstructed autosave; see owner diagnostic")
		return
	saves._storage._file_ops = original_files
	assert_eq(DirAccess.remove_absolute(blocked), OK)
	assert_false(refused.get("ok", false), str(refused))
	assert_eq(observed.refused_writes, 1, "real autosave write was attempted and refused")
	assert_eq(game.capture_run_snapshot_input(), before, "no debit, board installation or Run receipt on refusal")
	assert_eq(saves.get_latest_stable_checkpoint(), stable)
	assert_eq(profile.get_profile_snapshot(), history)
	_same_files(hashes)
	# A fresh presentation request retries the same observable action after storage repair.
	projected = port.pull("beginner")
	if not _ok(projected): return
	var revealed: Dictionary = port.dispatch("reveal", 0, int(projected.value.revision))
	if not _ok(revealed): return
	var after: Dictionary = game.capture_run_snapshot_input()
	assert_eq(typeof(after.desktop.board.board.board.outcome), TYPE_STRING_NAME)
	assert_eq(after.gameplay.minesweeper_rounds_left, before.gameplay.minesweeper_rounds_left - 1)
	assert_eq(after.desktop.board.phase, "ACTIVE_VISIBLE")
	assert_false(after.desktop.board.board.board.terminal, "beginner first Reveal stays playable")
	assert_true((after.desktop.board.board.board.revealed_indices as Array).has(0))
	assert_eq(after.desktop.board.command_receipts.size(), 1)
	assert_false(after.desktop.board.board.paid_start_receipt.is_empty())
	assert_eq(after.command_receipts, before.command_receipts, "ordinary scene frontier has no extra story consequences")
	assert_eq(profile.get_profile_snapshot(), history)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), hashes.slot_sha256)
	assert_ne(FileAccess.get_sha256("user://saves/autosave.json"), hashes.autosave_sha256)
	var committed: Dictionary = saves.get_latest_stable_checkpoint()
	if not _ok(committed): return
	var snapshot: Dictionary = committed.value.bundle.snapshot
	_assert_scene_snapshot(snapshot, reading.value.reading_session, after)
	var disk: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(disk): return
	assert_eq(disk.value.schema_version, 9)
	assert_eq(disk.value.current_snapshot.snapshot, snapshot, "physical Save9 carries the complete committed Run9")
	if not _ok(saves.save_latest_to_slot(1)): return
	assert_eq(game.capture_run_snapshot_input(), after, "serializing autosave and selected slot leaves live state untouched")
	assert_eq(typeof(game.capture_run_snapshot_input().desktop.board.board.board.outcome), TYPE_STRING_NAME)
	var proof := {"phase": "create", "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "file_hashes": _file_hashes(),
		"run": DESKTOP_STATE._inspection_normalize(after), "profile": history, "reading_session": snapshot.narrative_checkpoint.reading_session,
		"ready_count": ready_count, "refused_writes": observed.refused_writes}
	if not _write_json(PROOF, proof): return
	_write_json("res://.godot/ci/scene-desktop-first-reveal-create-proof.json", proof)

func load_scene_desktop_first_reveal() -> void:
	assert_true(FileAccess.file_exists(PROOF))
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(PROOF))
	if not _ok(parsed): return
	var witness: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), witness.process_id)
	assert_eq(ProjectSettings.globalize_path("user://"), witness.user_dir)
	_same_files(witness.file_hashes)
	if not _start_services(): return
	_same_files(witness.file_hashes)
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not prepared.get("ok", false):
		# Diagnostic-only: mirror Backup's detached document admission, avoiding
		# the unrelated storage read lease required by public prepare_restore_slot.
		# No plan returned here is committed or substituted for the failed action.
		var phase := "parse"
		var raw: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
		if raw.get("ok", false):
			phase = "migrate"
			raw = preload("res://scripts/infrastructure/save/SaveMigrations.gd").migrate_document(
				raw.value, {"kind": "slot", "slot_id": 1})
			if raw.get("ok", false):
				phase = "participants"
				raw = saves._prepare_restore_document(saves._resolve_locator(&"slot", 1),
					raw.value.document, raw.value)
		print("SCENE_DESKTOP_FIRST_REVEAL_LOAD_DIAGNOSTIC ", JSON.stringify({
			"phase": phase, "ok": raw.get("ok", false), "code": str(raw.get("code", "")),
			"message": str(raw.get("message", "")).left(1000),
			"details": raw.get("details", {})}))
	if not _ok(prepared): return
	assert_false(prepared.value.confirmation_required)
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending": return
	if not await _await_ready(): return
	if not await _line_ready(): return
	assert_eq(ready_count, 1)
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	var current_raw: Dictionary = game.capture_run_snapshot_input()
	var current: Dictionary = DESKTOP_STATE._inspection_normalize(current_raw)
	assert_eq(current.lifecycle.run_id, witness.run.lifecycle.run_id)
	assert_ne(current.lifecycle.branch_id, witness.run.lifecycle.branch_id)
	assert_eq(current.gameplay, witness.run.gameplay, "Load never charges another round")
	assert_eq(current.command_receipts, witness.run.command_receipts, "scene receipt history is not replayed")
	assert_eq(current.scene, witness.run.scene)
	assert_eq(current.desktop.board.phase, witness.run.desktop.board.phase)
	assert_eq(current.desktop.board.revision, witness.run.desktop.board.revision)
	assert_eq(current.desktop.board.board, witness.run.desktop.board.board, "layout, reveal state and historical paid receipt survive Load")
	assert_ne(current.desktop.board.identity.branch_id, witness.run.desktop.board.identity.branch_id)
	assert_eq(current.desktop.board.command_receipts.size(), witness.run.desktop.board.command_receipts.size())
	# Live command identities are remapped; their committed results and revisions remain history.
	var restored_receipts: Array = current.desktop.board.command_receipts.values()
	var source_receipts: Array = witness.run.desktop.board.command_receipts.values()
	assert_eq(restored_receipts.size(), 1)
	if restored_receipts.size() != 1 or source_receipts.size() != 1: return
	for key: String in ["result", "pre_revision", "post_revision", "command_kind"]:
		assert_eq(restored_receipts[0][key], source_receipts[0][key], key)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_eq(reading.value.reading_session.entry_id, witness.reading_session.entry_id)
	assert_eq(reading.value.reading_session.program_index, witness.reading_session.program_index)
	assert_true(bridge.is_current_line_presentation_acknowledged())
	assert_eq(profile.get_profile_snapshot(), witness.profile)
	var port: RefCounted = _desktop_port()
	if port == null: return
	var projected: Dictionary = port.pull("beginner")
	if not _ok(projected): return
	assert_eq(projected.value.revision, current.desktop.board.revision)
	for frame: int in 4: await get_tree().process_frame
	assert_eq(game.capture_run_snapshot_input(), current_raw, "opening restored presentation has no accounting or receipt side effects")
	assert_eq(profile.get_profile_snapshot(), witness.profile)
	_same_files(witness.file_hashes)
	var proof: Dictionary = witness.duplicate(true)
	proof.phase = "load"
	proof["creator_process_id"] = witness.process_id
	proof.process_id = OS.get_process_id()
	proof["destination_branch"] = current.lifecycle.branch_id
	proof.ready_count = ready_count
	# Finish the board restored by this fresh process, then save its paid result for a third process.
	var owner: Object = bootstrap._retained_minesweeper_round_coordinator_app
	var terminal_request := _settlement_request()
	if terminal_request.is_empty(): return
	terminal_request.cell_index = int(current_raw.desktop.board.board.board.mine_indices[0])
	if not _ok(owner.reveal(terminal_request)): return
	assert_false(bootstrap._desktop_board_state.capture().settled_inspection)
	var completion := _settlement_request()
	if completion.is_empty() or not _ok(owner.complete_round(completion)): return
	var settled: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_true(settled.desktop.board.settled_inspection)
	assert_true(settled.desktop.board.board.board.terminal)
	assert_false(settled.desktop.board.has("terminal_receipts"))
	assert_eq(settled.gameplay.money, current_raw.gameplay.money + 1)
	assert_eq(settled.gameplay.minesweeper_app_rounds_finished_today, 1)
	if not _ok(saves.save_latest_to_slot(2)): return
	proof["settled"] = DESKTOP_STATE._inspection_normalize(settled)
	proof["settled_slot_sha256"] = FileAccess.get_sha256("user://saves/slot_2.json")
	proof.file_hashes = _file_hashes()
	if not _write_json(PROOF, proof): return
	_write_json("res://.godot/ci/scene-desktop-first-reveal-load-proof.json", proof)

func load_scene_desktop_settled_result() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(PROOF))
	if not _ok(parsed): return
	var witness: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), witness.process_id, "settled Load uses a third OS process")
	assert_ne(OS.get_process_id(), witness.creator_process_id)
	_same_files(witness.file_hashes)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), witness.settled_slot_sha256)
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:2")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending": return
	if not await _await_ready() or not await _line_ready(): return
	var settled_raw: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var settled: Dictionary = DESKTOP_STATE._inspection_normalize(settled_raw)
	assert_true(settled.desktop.board.settled_inspection)
	assert_true(bootstrap._desktop_board_state.has_settled_inspection())
	assert_eq(settled.gameplay, witness.settled.gameplay, "settled Load preserves exact economy without another payment")
	assert_eq(settled.desktop.board.board, witness.settled.desktop.board.board, "terminal layout and inspection restore exactly")
	assert_false(settled.desktop.board.has("terminal_receipts"))
	assert_ne(settled.desktop.board.identity.branch_id, witness.settled.desktop.board.identity.branch_id)
	var request := _settlement_request()
	if request.is_empty(): return
	var owner: Object = bootstrap._retained_minesweeper_round_coordinator_app
	for retry: int in 2:
		var completed: Dictionary = owner.complete_round(request)
		if not _ok(completed): return
		assert_true(completed.get("already_applied", false))
		assert_eq(game.capture_run_snapshot_input(), settled_raw, "cold completion retry does not repeat rewards")
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), witness.settled_slot_sha256)
	_same_files(witness.file_hashes)
	var proof := witness.duplicate(true)
	proof["settled_destination_branch"] = settled.lifecycle.branch_id
	proof["settled_loader_process_id"] = OS.get_process_id()
	proof.ready_count = ready_count
	_write_json("res://.godot/ci/scene-desktop-settled-load-proof.json", proof)
