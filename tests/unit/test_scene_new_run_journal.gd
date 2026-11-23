extends GutTest

const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const MATERIALS := preload("res://scripts/infrastructure/save/NewRunMaterials.gd")
var fixture: RefCounted
var scope := preload("res://tests/support/SceneValidationScope.gd").new()

func before_each() -> void:
	scope.install(true)
	fixture = FIXTURE.new()

func after_each() -> void:
	fixture.close()
	scope.restore()

func test_completed_creation_proof_reads_only_the_referenced_record() -> void:
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.ok, str(setup))
	if not setup.ok: return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	var tx: String = started.transaction_id
	var allocation: Dictionary = fixture.issuer.capture_root().value.allocation_receipts[tx]
	var profile := FIXTURE.profile_material(fixture.profile.get_profile_snapshot(), allocation, 0)
	var snapshot: Dictionary = fixture.manager.get_latest_stable_checkpoint().value.bundle.snapshot
	snapshot.lifecycle["scene_assignment"] = profile.scene_assignment.receipt
	var bundle: Dictionary = fixture.manager._scene_new_run_bundle
	var reading: Dictionary = fixture.bridge._build_current_scene_initial_checkpoint(snapshot.scene, bundle)
	assert_true(reading.ok, str(reading))
	if not reading.ok: return
	var projected := MATERIALS._project_acknowledged_initial_checkpoint(reading.value, 7)
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	snapshot.narrative_checkpoint = projected.value
	var context := {"route_id": "scene", "active_app_id": null, "audio_context": {},
		"content_version": snapshot.content_version, "dialogic_checkpoint": reading.value}
	var autosave := {"schema_version": 9, "kind": "autosave", "slot_id": null,
		"current_snapshot": {"checkpoint_kind": "day_start", "snapshot": snapshot}, "recovery_journal": []}
	var text: String = WRITER.stringify(autosave).value + "\n"
	var material := {"allocation_candidate": allocation, "profile": profile,
		"autosave": {"source_revision": "absent", "outgoing_text": text, "outgoing_hash": text.sha256_text()}}
	var receipts := {}
	for name: String in JOURNAL.SCENE_PARTICIPANT_ORDER: receipts[name] = {}
	var fingerprint: String = WRITER.stringify(allocation).value.sha256_text()
	var operation := {"kind": "scene_new_run", "transaction_id": tx, "stage": "completed", "activation_state": "acknowledged",
		"initial_context": context, "initial_context_sha256": WRITER.stringify(context).value.sha256_text(),
		"new_run_materials": material, "new_run_targets": {"identity": fingerprint, "profile": profile.outgoing_hash, "autosave": text.sha256_text()},
		"request_fingerprint": WRITER.stringify({"kind": "scene_new_run", "transaction_id": tx,
			"initial_context": context, "new_run_materials": material}).value.sha256_text(),
		"allocation_candidate_fingerprint": fingerprint, "allocation_receipt": allocation,
		"transaction_issuer_receipt": allocation.request.transaction_issuer_receipt, "failure": null,
		"source_locator": null, "next_participant_index": receipts.size(), "participant_receipts": receipts}
	var journal_text: String = WRITER.stringify({"schema_version": 5, "operations": {
		tx: operation, "old": {"kind": "scene_new_run", "stage": "intent_committed"}}}).value
	assert_true(fixture.storage.write_atomic("profile.json", profile.outgoing_text, STRICT.parse_object).ok)
	assert_true(fixture.storage.write_atomic(JOURNAL.JOURNAL_PATH, journal_text, STRICT.parse_object).ok)
	var captured: Dictionary = fixture.manager.capture_committed_scene_creation(tx)
	assert_true(captured.ok, str(captured.get("message", captured.get("code"))))
	if captured.ok:
		assert_eq(captured.value.allocation_candidate, allocation)
		assert_eq(captured.value.profile_material, profile)
		assert_eq(captured.value.initial_scene, snapshot.scene)
	assert_eq(fixture.storage.read_text(JOURNAL.JOURNAL_PATH).value, journal_text)
