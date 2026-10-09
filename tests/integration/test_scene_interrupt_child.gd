extends "res://addons/gut/test.gd"
## Shared source for two explicit process suites; this base is never selected.
const FIXTURE := preload("res://tests/support/SceneInterruptionFixture.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var setup: Dictionary = await fixture.setup_restart(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	fixture_ready = setup.get("ok", false)

func after_all() -> void:
	if fixture != null: await fixture.close_restart()

func interrupt_selected_load() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var point := OS.get_environment("DWM_SCENE_INTERRUPT_POINT")
	assert_true(point in ["prefix", "completed"])
	if point not in ["prefix", "completed"]: return
	assert_false(fixture.storage.exists("autosave.json"))
	if fixture.storage.exists("autosave.json"): return
	var created: Dictionary = fixture.start()
	assert_eq(created.get("code"), &"scene_activation_pending", str(created))
	if created.get("code") != &"scene_activation_pending": return
	var activated: Dictionary = await fixture.await_activation()
	assert_true(activated.ok, str(activated))
	if not activated.ok: return
	assert_eq(fixture.ready_count, 1)
	var document: Dictionary = fixture.read_autosave()
	assert_true(document.ok, str(document))
	if not document.ok: return
	var bytes: Dictionary = fixture.storage.inspect_revision("autosave.json")
	assert_true(bytes.ok, str(bytes))
	if not bytes.ok: return
	var prepared: Dictionary = fixture.manager.prepare_restore_autosave()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	assert_eq(prepared.value.prepared.bundle.snapshot, snapshot)
	var context := {"creator_operation_id": str(created.transaction_id), "autosave_sha256": str(bytes.value.revision),
		"run_id": snapshot.run_id, "checkpoint_id": snapshot.checkpoint_id,
		"profile": fixture.profile.get_profile_snapshot().duplicate(true), "snapshot": snapshot.duplicate(true),
		"scope": "test_selected_two_process_interruption_mount_native_integration"}
	fixture.ready_count = 0
	fixture.route_confirmations.clear()
	fixture.narrative_confirmations.clear()
	fixture.native_publications.clear()
	fixture.native_markers.clear()
	var armed: Dictionary = fixture.arm_interruption(point, context)
	assert_true(armed.ok, str(armed))
	if not armed.ok or get_fail_count() > 0: return
	var unexpected: Dictionary = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	fail_test("exact durable interruption must terminate child before commit returns: " + str(unexpected) + str(fixture.stop_failure))

func resume_interrupted_load() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	assert_true(FileAccess.file_exists(fixture.witness_path()))
	if not FileAccess.file_exists(fixture.witness_path()): return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(fixture.witness_path()))
	assert_true(parsed.ok, str(parsed))
	if not parsed.ok: return
	var witness: Dictionary = parsed.value
	var point := OS.get_environment("DWM_SCENE_INTERRUPT_POINT")
	assert_eq(witness.point, point)
	assert_ne(OS.get_process_id(), int(witness.process_id), "recovery uses a distinct OS process")
	assert_eq(fixture.storage.describe_root(), witness.storage_root)
	assert_eq(witness.ready_count, 0, "interrupted Load had no readiness publication")
	assert_eq(witness.route_confirmations, [])
	assert_eq(witness.narrative_confirmations, [])
	var operation_id: String = witness.operation_id
	var before: Dictionary = fixture.manager._continuation_journal.get_operation(operation_id)
	assert_true(before.ok, str(before))
	if not before.ok: return
	assert_true(WRITER._deep_same(before.value, witness.operation), "fresh journal sees the exact physical interrupted operation")
	assert_eq(before.value.kind, "scene_restore")
	assert_eq(before.value.activation_state, null if point == "prefix" else "pending")
	assert_eq(before.value.stage, "participants_applying" if point == "prefix" else "completed")
	assert_eq(before.value.next_participant_index, 7 if point == "prefix" else 8)
	assert_true(before.value.participant_receipts.route is Dictionary)
	var recorded_count := 0
	for receipt: Variant in before.value.participant_receipts.values():
		if receipt != null: recorded_count += 1
	assert_eq(recorded_count, 7 if point == "prefix" else 8)
	assert_eq(fixture.ready_count, 0)
	var profile_before: Dictionary = fixture.profile.get_profile_snapshot().duplicate(true)
	assert_true(WRITER._deep_same(profile_before, witness.profile))
	var resumed: Dictionary = fixture.manager.reconcile_incomplete_continuations()
	# Public recovery propagates the exact pending scene activation envelope.
	assert_eq(resumed.get("code"), &"scene_activation_pending", str(resumed))
	if resumed.get("code") != &"scene_activation_pending": return
	assert_eq(resumed.get("transaction_id"), operation_id)
	assert_eq(fixture.ready_count, 0, "journal recovery alone is not mount/native readiness")
	var activated: Dictionary = await fixture.await_activation()
	assert_true(activated.ok, str(activated))
	if not activated.ok: return
	var after: Dictionary = fixture.manager._continuation_journal.get_operation(operation_id)
	assert_true(after.ok, str(after))
	if not after.ok: return
	assert_eq(after.value.stage, "completed")
	assert_eq(after.value.activation_state, "acknowledged")
	for key: String in ["transaction_id", "transaction_issuer_receipt", "allocation_receipt", "allocation_candidate_fingerprint",
			"source_locator", "selected_document", "request_fingerprint"]:
		assert_true(WRITER._deep_same(after.value[key], before.value[key]), "retained " + key)
	for key: String in before.value.participant_receipts:
		if before.value.participant_receipts[key] == null: continue
		assert_true(WRITER._deep_same(after.value.participant_receipts[key], before.value.participant_receipts[key]),
			"historical receipt prefix preserved: " + key)
	assert_eq(int(witness.live_route_generation), 2, "stopped process performed NewRun then Load")
	assert_ne(fixture.router._route_generation, int(witness.live_route_generation), "fresh route generation differs without rewriting historical receipt")
	assert_eq(fixture.ready_count, 1)
	assert_eq(fixture.route_confirmations, [operation_id])
	assert_eq(fixture.narrative_confirmations, [operation_id])
	assert_true(fixture.participants.route.validate_scene_activation(operation_id).ok)
	assert_true(fixture.participants.narrative.validate_scene_activation(operation_id).ok)
	assert_not_null(get_tree().current_scene)
	if get_tree().current_scene == null: return
	assert_eq(get_tree().current_scene.scene_file_path, FIXTURE.HOST)
	assert_true(get_tree().current_scene.is_node_ready())
	assert_true(fixture.game.capture_live_session().value.active)
	assert_false(fixture.gate.is_active())
	assert_true(WRITER._deep_same(fixture.profile.get_profile_snapshot(), profile_before), "recovery consumes no new form assignment")
	var source: Dictionary = fixture.storage.inspect_revision("autosave.json")
	assert_true(source.ok, str(source))
	if not source.ok: return
	assert_eq(source.value.revision, witness.autosave_sha256)
	var identity: Dictionary = fixture.storage.inspect_revision("desktop-issuer-root.json")
	assert_true(identity.ok, str(identity))
	if not identity.ok: return
	assert_true(identity.value.get("exists", false))
	assert_true(FIXTURE._valid_sha256(identity.value.get("revision")))
	assert_eq(identity.value.revision, witness.issuer_root_sha256, "recovery mints no second transaction or allocation")
	var checkpoint: Dictionary = witness.snapshot.narrative_checkpoint
	assert_true(WRITER._deep_same(fixture.adapter.capture_reading_frontier().value, checkpoint.reading_session.frontier))
	assert_eq(fixture.adapter.current_line_id(), str(checkpoint.reading_session.frontier.line_id))
	assert_true(WRITER._deep_same(fixture.bridge._reading_session.ledger.snapshot(), checkpoint.reading_session.ledger))
	assert_false(fixture.native_publications.is_empty())
	for publication: Dictionary in fixture.native_publications:
		assert_true(publication.ok, str(publication))
		assert_true(publication.get("value", {}).get("duplicate", false))
	assert_eq(fixture.native_markers, [])
	assert_true(fixture.manager.retry_scene_activation(operation_id).ok)
	var repeated: Dictionary = fixture.manager.reconcile_incomplete_continuations()
	assert_true(repeated.ok, str(repeated))
	if repeated.ok: assert_eq(repeated.value.reconciled, [])
	await get_tree().process_frame
	assert_eq(fixture.ready_count, 1, "retry and repeated recovery cannot publish a second readiness")
	assert_eq(fixture.route_confirmations, [operation_id])
	assert_eq(fixture.narrative_confirmations, [operation_id])
	var proof := {"phase": "resume", "point": point, "process_id": OS.get_process_id(),
		"stopped_process_id": int(witness.process_id), "storage_root": fixture.storage.describe_root(),
		"operation_id": operation_id, "creator_operation_id": witness.creator_operation_id,
		"autosave_sha256": source.value.revision, "issuer_root_sha256": identity.value.revision, "run_id": witness.run_id, "checkpoint_id": witness.checkpoint_id,
		"before_operation": before.value, "after_operation": after.value, "ready_count": fixture.ready_count,
		"mounted_host": get_tree().current_scene.scene_file_path, "native_frontier": fixture.adapter.capture_reading_frontier().value,
		"scope": witness.scope}
	var written: Dictionary = fixture.write_proof(proof, "resume")
	assert_true(written.ok, str(written))
	var encoded: Dictionary = WRITER.stringify(proof)
	assert_true(encoded.ok, str(encoded))
	if encoded.ok: print("SCENE_INTERRUPT_RESUME=" + str(encoded.value))
