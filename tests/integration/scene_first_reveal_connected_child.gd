extends "res://addons/gut/test.gd"
## Cloud child: selected Load preserves Run identity and exact saved board state.
const FIXTURE := preload("res://tests/support/SceneFirstRevealConnectedFixture.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SAVE_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var checked: Dictionary = await fixture.setup_connected(get_tree())
	assert_true(checked.get("ok", false), str(checked))
	fixture_ready = checked.get("ok", false)

func after_all() -> void:
	if fixture != null: await fixture.close_restart()

func create_connected(mode: String) -> void:
	if not fixture_ready: return
	assert_false(fixture.storage.exists("autosave.json"))
	var started: Dictionary = await fixture.begin_playable_source()
	if not _ok(started): return
	if not _ok(fixture.dispatch()): return
	var original: Dictionary = fixture.storage.read_text("autosave.json")
	if not _ok(original): return
	if not _ok(fixture.admit_challenge()): return
	assert_eq(fixture.panel().value.phase, "never_started")
	assert_eq(fixture.challenge_record(), {})
	var writes: int = fixture.files.autosave_writes
	var forged: Dictionary = fixture.challenge_command.duplicate(true)
	forged.command_sha256 = "0".repeat(64)
	var bundle: Dictionary = fixture.game.capture_scene_challenge_command().value.bundle
	assert_false(fixture.game.validate_scene_challenge_command(forged, bundle).ok)
	assert_false(fixture.game.commit_scene_challenge_checkpoint({}, {}, "").ok)
	var checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var unauthorized: Dictionary = fixture.checkpoint_port.commit_scene_challenge(
		fixture.game.capture_run_snapshot_input(), checkpoint.value)
	assert_false(unauthorized.ok, "a held control dictionary alone is not save authority")
	assert_eq(fixture.files.autosave_writes, writes)
	assert_eq(fixture.challenge_record(), {})
	fixture.files.refuse_on = writes + 1
	var refused: Dictionary = fixture.reveal()
	assert_false(refused.get("ok", false), str(refused))
	assert_true(refused.get("rolled_back", false), str(refused))
	assert_false(refused.get("committed", false), str(refused))
	assert_eq(fixture.files.refused, 1)
	if refused.get("ok", false) or not refused.get("rolled_back", false) or fixture.files.refused != 1: return
	assert_eq(fixture.storage.read_text("autosave.json").value, original.value)
	var pending: Dictionary = fixture.physical.capture_reconciliation_state()
	if not _ok(pending): return
	var attempt: Dictionary = {"record": pending.value.pending_checkpoint.duplicate(true)}
	assert_eq(attempt.record.phase, "active")
	assert_true(attempt.record.board.revealed_indices.has(323))
	assert_eq(fixture.challenge_attempt().value, {}, "Run failure creates no global Challenge progress")
	assert_eq(fixture.panel().value.phase, "checkpoint_retry")
	if mode == "normal":
		var retried: Dictionary = fixture.physical.dispatch_scene_panel_action(fixture.challenge_token,
			"retry", -1, int(fixture.panel().value.revision))
		if not _ok(retried): return
		assert_eq(fixture.challenge_attempt().value, {})
		assert_eq(fixture.challenge_record(), attempt.record)
		var durable_before: String = fixture.storage.read_text("autosave.json").value
		var profile_before: Dictionary = fixture.profile_bytes()
		writes = fixture.files.autosave_writes
		if not _ok(fixture.reveal()): return
		assert_eq(fixture.files.autosave_writes, writes, "duplicate first Reveal is write-free")
		assert_eq(fixture.profile_bytes(), profile_before)
		assert_eq(fixture.storage.read_text("autosave.json").value, durable_before)
		assert_eq(fixture.challenge_attempt().value, {})
	elif mode != "profile_ahead":
		fail_test("unknown connected mode")
		return
	var document: Dictionary = fixture.read_autosave()
	if not _ok(document): return
	if not _ok(SAVE_SCHEMA.validate(document.value)): return
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	var saved_record: Dictionary = snapshot.gameplay.route_context.get("active_dating_challenge", {})
	assert_eq(saved_record, attempt.record if mode == "normal" else {})
	var proof := {"phase": "create", "mode": mode, "process_id": OS.get_process_id(),
		"storage_root": fixture.storage.describe_root(), "autosave_sha256": str(fixture.storage.read_text("autosave.json").value).sha256_text(),
		"attempt": attempt, "saved_record": saved_record, "checkpoint": snapshot.narrative_checkpoint,
		"profile_files": fixture.profile_bytes(), "source_branch": snapshot.lifecycle.branch_id,
		"scope": "real_Profile_Run_native_owners_selected_Load_in_TEST_host_no_rendered_panel"}
	write_proof(proof, true)

func load_connected() -> void:
	if not fixture_ready: return
	var path: String = fixture.storage.describe_root().path_join("first-reveal-connected-witness.json")
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var read: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(path))
	if not _ok(read): return
	var witness: Dictionary = read.value
	assert_ne(OS.get_process_id(), int(witness.process_id), "fresh OS process")
	assert_eq(fixture.storage.describe_root(), witness.storage_root)
	if not _ok(fixture.storage.reconcile("autosave.json", Callable(fixture.manager, "_document_text_validator"))): return
	var bytes: Dictionary = fixture.storage.read_text("autosave.json")
	if not _ok(bytes): return
	assert_eq(str(bytes.value).sha256_text(), witness.autosave_sha256)
	assert_eq(fixture.profile_bytes(), witness.profile_files)
	var prepared: Dictionary = fixture.manager.prepare_restore_autosave()
	if not _ok(prepared): return
	var started: Dictionary = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	var activated: Dictionary = await fixture.await_activation()
	if not _ok(activated): return
	assert_eq(fixture.ready_count, 1)
	var current: Dictionary = fixture.game.capture_run_snapshot_input()
	assert_eq(current.lifecycle.branch_id, witness.source_branch, "selected Load preserves the saved branch")
	assert_eq(fixture.bridge._reading_session.boundary, "control")
	var native: Dictionary = fixture.adapter.capture_scene_control_position(fixture.bridge._reading_session)
	if not _ok(native): return
	assert_eq(native.value, witness.checkpoint.reading_session)
	var admitted: Dictionary = fixture.admit_challenge()
	if not _ok(admitted): return
	if witness.mode == "profile_ahead": assert_eq(fixture.panel().value.phase, "never_started")
	assert_eq(fixture.challenge_record(), witness.saved_record, "selected snapshot imports no future progress")
	assert_eq(fixture.challenge_attempt().value, {})
	if witness.mode != "profile_ahead": assert_eq(fixture.panel().value.phase, "active")
	assert_eq(fixture.profile_bytes(), witness.profile_files, "readmission is read-only")
	assert_eq(fixture.files.autosave_writes, 0)
	assert_eq(fixture.storage.read_text("autosave.json").value, bytes.value)
	assert_eq(fixture.native_markers, [])
	var proof: Dictionary = witness.duplicate(true)
	proof.phase = "load"
	proof["creator_process_id"] = witness.process_id
	proof.process_id = OS.get_process_id()
	write_proof(proof, false)

func create_selected_recovery() -> void:
	if not fixture_ready: return
	if not _ok(await fixture.begin_playable_source()): return
	if not _ok(fixture.dispatch()): return
	if not _ok(fixture.manager.save_latest_to_slot(1)): return
	var selected_bytes: Dictionary = fixture.storage.read_text("slot_1.json")
	if not _ok(selected_bytes): return
	if not _ok(fixture.admit_challenge()): return
	if not _ok(fixture.reveal()): return
	var first: Dictionary = fixture.challenge_record().duplicate(true)
	var flag_cell := -1
	for cell: int in 324:
		if not first.board.revealed_indices.has(cell):
			flag_cell = cell
			break
	assert_gte(flag_cell, 0)
	if flag_cell < 0: return
	if not _ok(fixture.physical.dispatch_scene_panel_action(fixture.challenge_token,
		"flag", flag_cell, int(fixture.panel().value.revision))): return
	var source: Dictionary = fixture.challenge_record().duplicate(true)
	var source_branch: String = fixture.game.capture_run_snapshot_input().lifecycle.branch_id
	assert_gt(source.board.revision, first.board.revision)
	assert_true(source.board.flagged_indices.has(flag_cell))
	var prepared: Dictionary = fixture.manager.prepare_restore_slot(1)
	if not _ok(prepared): return
	# Selection retains the old document. Replace its slot through the real save
	# owner with the later source board before completing that selected restore.
	if not _ok(fixture.manager.save_latest_to_slot(1)): return
	assert_ne(fixture.storage.read_text("slot_1.json").value, selected_bytes.value)
	# This persistence fixture cancels its source via the public Bridge API.
	# It does not pretend to exercise the shipped Pause/Load UI handoff.
	var source_input: Dictionary = fixture.game.capture_run_snapshot_input().duplicate(true)
	var source_profile: Dictionary = fixture.profile_bytes()
	if not _ok(fixture.bridge.abort_current_entry(&"TEST.selected_load")): return
	for frame: int in 180:
		if not fixture.bridge.has_active_playback(): break
		await get_tree().process_frame
	assert_false(fixture.bridge.has_active_playback())
	assert_eq(fixture.game.capture_run_snapshot_input(), source_input)
	assert_eq(fixture.profile_bytes(), source_profile)
	fixture.ready_count = 0
	var started: Dictionary = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	if not _ok(await fixture.await_activation()): return
	var identity: Dictionary = fixture.game.capture_run_snapshot_input().lifecycle
	assert_eq(identity.branch_id, source_branch)
	assert_eq(fixture.challenge_record(), {})
	var profile_before: Dictionary = fixture.profile_bytes()
	if not _ok(fixture.admit_challenge()): return
	assert_eq(fixture.panel().value.phase, "never_started")
	assert_eq(fixture.profile_bytes(), profile_before)
	# Profile writes are unavailable throughout this new Run-owned action.
	fixture.files.refuse_profile = true
	fixture.files.refuse_on = fixture.files.autosave_writes + 1
	var refused: Dictionary = fixture.reveal()
	assert_false(refused.get("ok", false), str(refused))
	assert_true(refused.get("rolled_back", false), str(refused))
	assert_eq(fixture.files.refused, 1)
	assert_eq(fixture.files.profile_refusals, 0)
	if refused.get("ok", false) or not refused.get("rolled_back", false): return
	assert_eq(fixture.profile_bytes(), profile_before)
	assert_eq(fixture.panel().value.phase, "checkpoint_retry")
	var pending: Dictionary = fixture.physical.capture_reconciliation_state()
	if not _ok(pending): return
	var destination: Dictionary = pending.value.pending_checkpoint.duplicate(true)
	assert_ne(destination.spec.board_token, source.spec.board_token, "saved absence creates a new board")
	assert_false(destination.board.flagged_indices.has(flag_cell))
	if not _ok(fixture.physical.dispatch_scene_panel_action(fixture.challenge_token,
		"retry", -1, int(fixture.panel().value.revision))): return
	assert_eq(fixture.challenge_record(), destination)
	assert_eq(fixture.challenge_attempt().value, {})
	assert_eq(fixture.profile_bytes(), profile_before)
	assert_eq(fixture.game.capture_run_snapshot_input().lifecycle.branch_id, identity.branch_id)
	var document: Dictionary = fixture.read_autosave()
	if not _ok(document): return
	if not _ok(SAVE_SCHEMA.validate(document.value)): return
	var saved: Dictionary = document.value.current_snapshot.snapshot
	assert_eq(saved.gameplay.route_context.active_dating_challenge, destination)
	var proof := {"phase": "create", "mode": "selected_absence", "process_id": OS.get_process_id(),
		"storage_root": fixture.storage.describe_root(),
		"autosave_sha256": str(fixture.storage.read_text("autosave.json").value).sha256_text(),
		"attempt": destination, "saved_record": destination, "checkpoint": saved.narrative_checkpoint,
		"profile_files": fixture.profile_bytes(), "source_branch": identity.branch_id,

		"scope": "retained_selected_absence_after_slot_overwrite_Run_refusal_retry_without_Profile_write_then_fresh_Load"}
	write_proof(proof, true)

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result))
	return result.get("ok", false)

func write_proof(proof: Dictionary, witness: bool) -> void:
	var encoded: Dictionary = WRITER.stringify(proof)
	if not _ok(encoded): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	var paths: Array[String] = ["res://.godot/ci/first-reveal-connected-" + str(proof.mode) + "-" + str(proof.phase) + ".json"]
	if witness: paths.append(fixture.storage.describe_root().path_join("first-reveal-connected-witness.json"))
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert_not_null(file)
		if file == null: return
		file.store_string(str(encoded.value) + "\n")
		file.flush()
		file.close()
