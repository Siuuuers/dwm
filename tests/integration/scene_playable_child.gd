extends "res://addons/gut/test.gd"
## Shared assertions only; selected children below each declare one GUT test.
const FIXTURE := preload("res://tests/support/ScenePlayableFixture.gd")
const SAVE_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var checked: Dictionary = await fixture.setup_playable(get_tree())
	assert_true(checked.get("ok", false), str(checked))
	fixture_ready = checked.get("ok", false)

func after_all() -> void:
	if fixture != null: await fixture.close_restart()

func create_playable(mode: String) -> void:
	if not fixture_ready: return
	assert_false(fixture.storage.exists("autosave.json"), "fresh isolated physical root")
	var started: Dictionary = await fixture.begin_playable_source()
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	var original: Dictionary = fixture.storage.read_text("autosave.json")
	var profile_hashes: Dictionary = fixture.profile_bytes()
	assert_true(original.ok, str(original))
	if not original.ok: return
	assert_eq(fixture.before_reading.reading_session.boundary, "line")
	assert_eq(fixture.adapter.current_line_id(), "line.scene.test.b.one")
	var stale: Dictionary = fixture.issued_event.duplicate(true)
	stale.playback_token += ".stale"
	assert_false(fixture.dispatch(stale).get("ok", false), "stale authority is refused before any write")
	var wrong: Dictionary = fixture.issued_event.duplicate(true)
	wrong.event_id = "scene.test.b.end"
	assert_false(fixture.dispatch(wrong).get("ok", false), "registered wrong marker cannot borrow this caption")
	assert_eq(fixture.files.autosave_writes, 0)
	if mode == "normal":
		fixture.files.refuse_on = 1
		var refused: Dictionary = fixture.dispatch()
		assert_false(refused.get("ok", false), str(refused))
		assert_false(refused.get("committed", false), "definite source-write failure permits retry")
		assert_eq(refused.get("code"), &"write_not_committed")
		assert_true(refused.get("rolled_back", false))
		assert_eq(fixture.files.refused, 1, "fault actually reached physical autosave.next write")
		assert_eq(fixture.lower.last_prepare_phase, "source", "source fault belongs to the source checkpoint")
		assert_eq(fixture.files.autosave_writes, 2, "refused source plus physical rollback write")
		if refused.get("ok", false) or refused.get("committed", false) or fixture.files.refused != 1 \
				or fixture.files.autosave_writes != 2 or fixture.lower.last_prepare_phase != "source": return
		assert_eq(fixture.storage.read_text("autosave.json").value, original.value)
		assert_eq(fixture.game.capture_run_snapshot_input(), fixture.before_input)
		assert_eq(fixture.bridge.capture_reading_checkpoint(false).value, fixture.before_reading)
		# Source retry writes once, then the destination's real write is refused.
		fixture.files.refuse_on = fixture.files.autosave_writes + 2
		refused = fixture.dispatch()
		assert_false(refused.get("ok", false), str(refused))
		assert_false(refused.get("committed", false), "definite destination rollback permits same-command retry")
		assert_eq(refused.get("code"), &"write_not_committed")
		assert_true(refused.get("rolled_back", false))
		assert_eq(fixture.files.refused, 2)
		assert_eq(fixture.lower.last_prepare_phase, "destination", "destination fault follows the saved source")
		assert_eq(fixture.files.autosave_writes, 5, "source retry, refused destination and physical rollback write")
		if refused.get("ok", false) or refused.get("committed", false) or fixture.files.refused != 2 \
				or fixture.files.autosave_writes != 5 or fixture.lower.last_prepare_phase != "destination": return
		var source: Dictionary = fixture.read_autosave()
		assert_true(source.ok, str(source))
		if not source.ok: return
		var saved_source: Dictionary = source.value.current_snapshot.snapshot
		assert_true(SAVE_SCHEMA.validate(source.value).ok)
		assert_eq(saved_source.narrative_checkpoint.reading_session.boundary, "line")
		if not assert_operation_phase(saved_source.narrative_checkpoint, "source"): return
		assert_false(saved_source.command_receipts.has(fixture.issued_event.command_id))
		assert_eq(fixture.game.capture_run_snapshot_input(), fixture.before_input)
		assert_eq(fixture.bridge.capture_reading_checkpoint(false).value, fixture.before_reading)
	elif mode == "dropped_ack":
		fixture.checkpoint_port.drop_ack = true
	elif mode == "native_refusal":
		# Negative-only fault: discard real native source custody after the real
		# destination commit/ack. No positive native proof is assigned.
		fixture.checkpoint_port.after_ack = func() -> void: fixture.adapter._scene_source_token = null
	else:
		fail_test("unknown child mode")
		return
	var result: Dictionary = fixture.dispatch()
	if mode == "normal":
		assert_true(result.get("ok", false), str(result))
		if not result.get("ok", false): return
		assert_false(result.get("duplicate", true))
		assert_eq(result.value.kind, "challenge_playable")
		assert_eq(fixture.bridge._reading_session.boundary, "control")
		var native: Dictionary = fixture.adapter.capture_scene_control_position(fixture.bridge._reading_session)
		assert_true(native.ok, str(native))
		if not native.ok: return
	else:
		assert_false(result.get("ok", false), str(result))
		# The shared gate returns its retained fatal diagnostic on lease release.
		# Inspect that public envelope, not the owner's internal committed result.
		var expected_code := "scene_playable_ack_unavailable" if mode == "dropped_ack" else "scene_playable_ack_invalid"
		var expected_failure := {"source": "scene_event", "phase": "committed_adoption",
			"code": expected_code, "details": {"committed": true}}
		assert_eq(result.get("code"), &"APPLICATION_FATAL")
		assert_eq(result.get("details", {}).get("failure"), expected_failure, "the injected postcommit fault retains its exact cause")
		assert_true(fixture.gate.is_fatal_latched(), "the shared gate retains fatal custody")
		assert_eq(fixture.game.capture_run_snapshot_input(), fixture.before_input, "unacknowledged receipt is not adopted live")
		assert_true(fixture.bridge._scene_stage_fatal, "failed adoption retains fatal custody")
		if result.get("ok", false) or result.get("code") != &"APPLICATION_FATAL" \
				or result.get("details", {}).get("failure") != expected_failure \
				or not fixture.gate.is_fatal_latched() or not fixture.bridge._scene_stage_fatal: return
	assert_eq(fixture.checkpoint_port.consumed, 1, "the actual durable acknowledgement was consumed exactly once")
	if fixture.checkpoint_port.consumed != 1: return
	var document: Dictionary = fixture.read_autosave()
	assert_true(document.ok, str(document))
	if not document.ok: return
	assert_true(SAVE_SCHEMA.validate(document.value).ok, "entire committed Run/Save validates")
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	assert_eq(snapshot.narrative_checkpoint.reading_session.boundary, "control")
	if not assert_operation_phase(snapshot.narrative_checkpoint, "destination"): return
	assert_true(snapshot.command_receipts.has(fixture.issued_event.command_id))
	if not snapshot.command_receipts.has(fixture.issued_event.command_id): return
	assert_eq(snapshot.command_receipts[fixture.issued_event.command_id].scene_event.result.kind, "challenge_playable")
	assert_eq(snapshot.command_receipts.size(), fixture.before_input.command_receipts.size() + 1)
	assert_eq(snapshot.scene, fixture.before_input.scene, "availability does not create physical Challenge progress")
	assert_eq(snapshot.gameplay, fixture.before_input.gameplay, "availability does not construct a board")
	assert_eq(snapshot.narrative_checkpoint.reading_session.ledger, fixture.before_reading.reading_session.ledger)
	assert_eq(fixture.profile.get_profile_snapshot(), fixture.before_profile)
	assert_eq(fixture.profile_bytes(), profile_hashes, "physical Profile files remain unchanged")
	assert_eq(fixture.native_publications.size(), fixture.before_publications, "no duplicate caption publication")
	assert_eq(fixture.native_markers, [], "native held caption does not run the next authored event")
	var writes: int = fixture.files.autosave_writes
	var durable: String = fixture.storage.read_text("autosave.json").value
	var retry: Dictionary = fixture.dispatch()
	if mode == "normal":
		assert_true(retry.get("ok", false), str(retry))
		assert_true(retry.get("duplicate", false), "duplicate uses current command authority without another save")
		assert_eq(retry.get("value"), result.get("value"))
	else:
		assert_false(retry.get("ok", false), "fatal custody refuses retry rather than minting progress")
	assert_eq(fixture.files.autosave_writes, writes)
	assert_eq(fixture.storage.read_text("autosave.json").value, durable)
	var proof := {"phase": "create", "mode": mode, "process_id": OS.get_process_id(),
		"storage_root": fixture.storage.describe_root(), "autosave_sha256": durable.sha256_text(),
		"run_id": snapshot.run_id, "checkpoint_id": snapshot.checkpoint_id,
		"event": fixture.issued_event, "profile_files": profile_hashes,
		"receipt": snapshot.command_receipts[fixture.issued_event.command_id],
		"checkpoint": snapshot.narrative_checkpoint, "refused_writes": fixture.files.refused,
		"scope": "real_save_native_and_fresh_process_test_host_integration"}
	write_proof(proof, true)

func load_playable() -> void:
	if not fixture_ready: return
	var witness_path: String = fixture.storage.describe_root().path_join("playable-witness.json")
	assert_true(FileAccess.file_exists(witness_path))
	if not FileAccess.file_exists(witness_path): return
	var read: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(witness_path))
	assert_true(read.ok, str(read))
	if not read.ok: return
	var witness: Dictionary = read.value
	assert_ne(OS.get_process_id(), int(witness.process_id), "Load is a fresh OS process")
	assert_eq(fixture.storage.describe_root(), witness.storage_root)
	var reconciled: Dictionary = fixture.storage.reconcile("autosave.json", Callable(fixture.manager, "_document_text_validator"))
	assert_true(reconciled.ok, str(reconciled))
	if not reconciled.ok: return
	var bytes: Dictionary = fixture.storage.read_text("autosave.json")
	assert_true(bytes.ok, str(bytes))
	if not bytes.ok: return
	assert_eq(str(bytes.value).sha256_text(), witness.autosave_sha256)
	var document: Dictionary = PARSER.parse_object(bytes.value)
	assert_true(document.ok, str(document))
	if not document.ok: return
	assert_true(SAVE_SCHEMA.validate(document.value).ok)
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	assert_eq(snapshot.narrative_checkpoint, witness.checkpoint)
	assert_eq(snapshot.command_receipts[witness.event.command_id], witness.receipt)
	assert_eq(fixture.profile_bytes(), witness.profile_files)
	var before_profile: Dictionary = fixture.profile.get_profile_snapshot().duplicate(true)
	var prepared: Dictionary = fixture.manager.prepare_restore_autosave()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(prepared.value.prepared.bundle.snapshot, snapshot)
	var started: Dictionary = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	var activated: Dictionary = await fixture.await_activation()
	assert_true(activated.ok, str(activated))
	if not activated.ok: return
	assert_eq(fixture.ready_count, 1)
	assert_eq(get_tree().current_scene.scene_file_path, FIXTURE.HOST)
	assert_true(fixture.participants.route.validate_scene_activation(started.transaction_id).ok)
	assert_true(fixture.participants.narrative.validate_scene_activation(started.transaction_id).ok)
	var current: Dictionary = fixture.game.capture_run_snapshot_input()
	assert_eq(current.lifecycle.branch_id, snapshot.lifecycle.branch_id)
	assert_eq(current.scene, snapshot.scene)
	assert_eq(current.gameplay, snapshot.gameplay, "route activation preserves the restored gameplay context")
	assert_eq(current.command_receipts, snapshot.command_receipts)
	assert_eq(fixture.bridge._reading_session.boundary, "control")
	var control: Dictionary = fixture.adapter.capture_scene_control_position(fixture.bridge._reading_session)
	assert_true(control.ok, str(control))
	if not control.ok: return
	assert_eq(control.value, snapshot.narrative_checkpoint.reading_session)
	assert_eq(fixture.adapter.current_line_id(), "line.scene.test.b.one")
	assert_eq(fixture.bridge._reading_session.ledger.snapshot(), witness.checkpoint.reading_session.ledger)
	assert_eq(fixture.profile.get_profile_snapshot(), before_profile)
	assert_eq(fixture.profile_bytes(), witness.profile_files)
	assert_eq(fixture.native_markers, [])
	assert_false(fixture.native_publications.is_empty())
	for publication: Dictionary in fixture.native_publications:
		assert_true(publication.get("ok", false), str(publication))
		assert_true(publication.get("value", {}).get("duplicate", false))
	# Old presentation authority is stale even for a genuine already-saved command.
	assert_false(fixture.dispatch(witness.event).get("ok", false))
	var context: Dictionary = fixture.game.scene_event_context()
	assert_true(context.ok, str(context))
	if not context.ok: return
	var refreshed: Dictionary = witness.event.duplicate(true)
	refreshed.playback_token = context.value.playback_token
	var duplicate: Dictionary = fixture.dispatch(refreshed)
	assert_true(duplicate.get("ok", false), str(duplicate))
	assert_true(duplicate.get("duplicate", false))
	assert_eq(duplicate.get("value"), witness.receipt.scene_event.result)
	assert_eq(fixture.game.capture_run_snapshot_input(), current)
	assert_eq(fixture.storage.read_text("autosave.json").value, bytes.value)
	assert_eq(fixture.files.autosave_writes, 0, "Load and duplicate issue no replacement autosave")
	assert_true(fixture.manager.retry_scene_activation(started.transaction_id).ok)
	assert_eq(fixture.ready_count, 1)
	var proof: Dictionary = witness.duplicate(true)
	proof.phase = "load"
	proof["creator_process_id"] = witness.process_id
	proof.process_id = OS.get_process_id()
	write_proof(proof, false)

func assert_operation_phase(checkpoint: Dictionary, expected: String) -> bool:
	var operation: Variant = checkpoint.get("reading_session", {}).get("next_operation")
	assert_true(operation is Dictionary, "saved " + expected + " checkpoint retains its traversal operation")
	if not operation is Dictionary: return false
	assert_eq(operation.get("phase"), expected)
	return operation.get("phase") == expected

func write_proof(proof: Dictionary, witness: bool) -> void:
	var encoded: Dictionary = WRITER.stringify(proof)
	assert_true(encoded.ok, str(encoded))
	if not encoded.ok: return
	var output := "res://.godot/ci/playable-" + str(proof.mode) + "-" + str(proof.phase) + ".json"
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	var paths: Array[String] = [output]
	if witness: paths.append(fixture.storage.describe_root().path_join("playable-witness.json"))
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert_not_null(file)
		if file == null: return
		file.store_string(str(encoded.value) + "\n")
		file.flush()
		file.close()
	print("SCENE_PLAYABLE_PROOF=" + str(encoded.value))
