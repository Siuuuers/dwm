extends "res://addons/gut/test.gd"
## Shared assertions for two explicit child suites. Never selected as a suite itself.
## Exact same files cross an actual OS-process exit, not object reconstruction.
const FIXTURE := preload("res://tests/support/SceneRestartFixture.gd")
const SAVE_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var setup: Dictionary = await fixture.setup_restart(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	fixture_ready = setup.get("ok", false)

func after_all() -> void:
	if fixture != null: await fixture.close_restart()

func exercise_phase(phase: String) -> void:
	assert_true(fixture_ready, "restart fixture initializes real owners")
	if not fixture_ready: return
	assert_true(phase in ["create", "load"])
	var witness_path: String = fixture.storage.describe_root().path_join("restart-witness.json")
	var snapshot := {}
	var original_hash := ""
	var first_pid := OS.get_process_id()
	var previous_profile := {}
	var started := {}
	if phase == "create":
		assert_false(fixture.storage.exists("autosave.json"), "creator starts with a fresh shared root")
		if fixture.storage.exists("autosave.json"): return
		started = fixture.start()
	else:
		assert_true(FileAccess.file_exists(witness_path), "creator's durable witness must exist")
		if not FileAccess.file_exists(witness_path): return
		var witness: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(witness_path))
		assert_true(witness.ok, str(witness))
		if not witness.ok: return
		first_pid = int(witness.value.process_id)
		assert_ne(OS.get_process_id(), first_pid, "selected Load runs in a different OS process")
		assert_eq(fixture.storage.describe_root(), witness.value.storage_root)
		original_hash = witness.value.autosave_sha256
		# Observe the selected bytes without claiming a storage read lease before
		# SaveManager's real prepare path has reconciled this fresh process.
		var bytes: Dictionary = fixture.storage.inspect_revision("autosave.json")
		assert_true(bytes.ok, str(bytes))
		if not bytes.ok: return
		assert_eq(bytes.value.revision, original_hash, "load opens the creator's exact physical autosave")
		assert_true(bytes.value.text is String)
		if not bytes.value.text is String: return
		var document: Dictionary = PARSER.parse_object(bytes.value.text)
		assert_true(document.ok, str(document))
		if not document.ok: return
		snapshot = document.value.current_snapshot.snapshot
		assert_eq(snapshot.run_id, witness.value.run_id)
		assert_eq(snapshot.checkpoint_id, witness.value.checkpoint_id)
		assert_true(SAVE_SCHEMA.validate(document.value).ok, "fresh process proves saved creation authority")
		previous_profile = fixture.profile.get_profile_snapshot().duplicate(true)
		var prepared: Dictionary = fixture.manager.prepare_restore_autosave()
		assert_true(prepared.ok, str(prepared))
		if not prepared.ok: return
		assert_eq(prepared.value.prepared.bundle.snapshot, snapshot, "selected Load chooses the entire saved bundle")
		started = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	var operation_id: String = started.transaction_id
	assert_eq(fixture.ready_count, 0, "durable commit and queued scene replacement are not readiness")
	var activated: Dictionary = await fixture.await_activation()
	assert_true(activated.ok, str(activated))
	if not activated.ok: return
	var operation: Dictionary = fixture.manager._continuation_journal.get_operation(operation_id)
	assert_true(operation.ok, str(operation))
	if not operation.ok: return
	assert_eq(operation.value.activation_state, "acknowledged")
	assert_eq(operation.value.kind, "scene_new_run" if phase == "create" else "scene_restore")
	assert_eq(fixture.ready_count, 1)
	assert_eq(fixture.route_confirmations, [operation_id])
	assert_eq(fixture.narrative_confirmations, [operation_id])
	assert_true(fixture.participants.route.validate_scene_activation(operation_id).ok)
	assert_true(fixture.participants.narrative.validate_scene_activation(operation_id).ok)
	assert_not_null(get_tree().current_scene)
	assert_eq(get_tree().current_scene.scene_file_path, FIXTURE.HOST)
	assert_true(get_tree().current_scene.is_node_ready())
	assert_true(fixture.game.capture_live_session().value.active)
	assert_false(fixture.gate.is_active(), "input custody releases only after actual mount and native proof")
	if phase == "create":
		var document: Dictionary = fixture.read_autosave()
		assert_true(document.ok, str(document))
		if not document.ok: return
		snapshot = document.value.current_snapshot.snapshot
		assert_true(SAVE_SCHEMA.validate(document.value).ok)
		var bytes: Dictionary = fixture.storage.read_text("autosave.json")
		assert_true(bytes.ok, str(bytes))
		if not bytes.ok: return
		original_hash = str(bytes.value).sha256_text()
	else:
		assert_true(fixture.manager.capture_committed_scene_restore(operation_id).ok)
		var restored: Dictionary = fixture.game.capture_run_snapshot_input()
		assert_eq(restored.lifecycle.run_id, snapshot.run_id)
		assert_ne(restored.lifecycle.branch_id, snapshot.lifecycle.branch_id, "selected Load allocates a new branch")
		assert_gt(restored.lifecycle.desktop_timeline_generation, snapshot.lifecycle.desktop_timeline_generation)
		assert_eq(restored.lifecycle.scene_assignment, snapshot.lifecycle.scene_assignment)
		assert_eq(restored.scene, snapshot.scene)
		assert_eq(fixture.profile.get_profile_snapshot(), previous_profile, "Load does not consume another form assignment")
		var after_bytes: Dictionary = fixture.storage.read_text("autosave.json")
		assert_true(after_bytes.ok, str(after_bytes))
		if not after_bytes.ok: return
		assert_eq(str(after_bytes.value).sha256_text(), original_hash, "selected source file remains unchanged")
	var checkpoint: Dictionary = snapshot.narrative_checkpoint
	assert_eq(fixture.adapter.capture_reading_frontier().value, checkpoint.reading_session.frontier)
	assert_eq(fixture.adapter.current_line_id(), checkpoint.reading_session.frontier.line_id)
	assert_eq(fixture.bridge._reading_session.ledger.snapshot(), checkpoint.reading_session.ledger,
		"native restoration cannot add a second caption or history consequence")
	assert_false(fixture.native_publications.is_empty(), "installed native text_started was observed")
	for publication: Dictionary in fixture.native_publications:
		assert_true(publication.ok, str(publication))
		assert_true(publication.get("value", {}).get("duplicate", false), "native restoration reuses the saved publication")
	assert_eq(fixture.native_markers, [], "restoring first caption executes no later authored marker")
	assert_true(fixture.manager.retry_scene_activation(operation_id).ok)
	assert_eq(fixture.ready_count, 1, "duplicate activation cannot republish readiness")
	var proof := {"phase": phase, "process_id": OS.get_process_id(), "creator_process_id": first_pid,
		"storage_root": fixture.storage.describe_root(), "autosave_sha256": original_hash,
		"run_id": snapshot.run_id, "checkpoint_id": snapshot.checkpoint_id,
		"operation_id": operation_id, "mounted_host": get_tree().current_scene.scene_file_path,
		"native_frontier": fixture.adapter.capture_reading_frontier().value,
		"scope": "test_selected_same_files_mount_and_native_integration"}
	var encoded: Dictionary = WRITER.stringify(proof)
	assert_true(encoded.ok, str(encoded))
	if not encoded.ok: return
	if phase == "create":
		var file := FileAccess.open(witness_path, FileAccess.WRITE)
		assert_not_null(file)
		if file == null: return
		file.store_string(str(encoded.value) + "\n")
		file.flush()
		file.close()
	var output := "res://.godot/ci/scene-restart-" + phase + ".json"
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	assert_eq(mkdir_error, OK)
	var evidence := FileAccess.open(output, FileAccess.WRITE)
	assert_not_null(evidence)
	if evidence == null: return
	evidence.store_string(str(encoded.value) + "\n")
	evidence.close()
	print("SCENE_RESTART_PROOF=" + str(encoded.value))
