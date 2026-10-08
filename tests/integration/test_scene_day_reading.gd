extends "res://addons/gut/test.gd"
## Dedicated-process nonwired tests. Snapshot round trips below use only the
## reading component; they establish no SaveManager, issuer or native UI proof.
const FIXTURE := preload("res://tests/support/SceneDayReadingFixture.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const OP := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const LEDGER := preload("res://scripts/narrative/NarrativeCaptionLedger.gd")
const RUN := preload("res://scripts/narrative/FrozenRunContext.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")

class SimulatedCheckpointPort:
	extends RefCounted
	var binding: Dictionary = {}
	var checkpoint: Dictionary = {}
	var capability := ""
	var confirmed := false
	var consumed := false
	var corrupt_hash := false
	var uncertain := false
	var consumes := 0

	func retain_scene_entry(_bridge: Object, capability_id: String, owner_binding: Dictionary,
			narrative_checkpoint: Dictionary) -> Dictionary:
		capability = capability_id
		binding = owner_binding.duplicate(true)
		checkpoint = narrative_checkpoint.duplicate(true)
		return {"ok": true}

	func consume_scene_entry_ack(capability_id: String) -> Dictionary:
		consumes += 1
		if uncertain: return {"ok": false}
		if not confirmed: return {"ok": false, "committed": false}
		if consumed or capability_id != capability: return {"ok": false}
		consumed = true
		var writer := preload("res://scripts/validation/CanonicalJsonWriter.gd")
		var binding_json: Dictionary = writer.stringify(binding)
		var checkpoint_json: Dictionary = writer.stringify(checkpoint)
		return {"ok": true, "value": {"capability_id": capability, "operation_id": binding.operation_id,
			"source_checkpoint": binding.source_checkpoint.duplicate(true),
			"target_checkpoint": {"checkpoint_id": "test:target-checkpoint", "checkpoint_sequence": 1,
				"snapshot_sha256": "1".repeat(64)},
			"binding_sha256": "0".repeat(64) if corrupt_hash else str(binding_json.value).sha256_text(),
			"narrative_checkpoint_sha256": str(checkpoint_json.value).sha256_text()}}

class SimulatedNativeTarget:
	extends RefCounted
	var installations := 0
	var fail_install := false

	func install_scene_target(_session: RefCounted, _checkpoint: Dictionary, _target: Dictionary) -> Dictionary:
		installations += 1
		if fail_install: return {"ok": false, "code": &"test_simulated_native_failure"}
		return {"ok": true}

func _staged_fixture() -> Dictionary:
	var bridge := BRIDGE.new()
	autofree(bridge) # Deliberately never enters the tree or invokes _ready.
	var port := SimulatedCheckpointPort.new()
	var native := SimulatedNativeTarget.new()
	bridge._runtime_adapter = native
	var binding := {"operation_id": "test:operation:a:1",
		"source_checkpoint": {"checkpoint_id": "test:source-checkpoint", "checkpoint_sequence": 0,
			"snapshot_sha256": "2".repeat(64)},
		"source_occurrence_id": null, "trigger_command_id": null,
		"target_id": "target_a", "target_occurrence_id": "a:1",
		"admission_receipt_id": "test:receipt:a:1",
		"registration_sha256": FIXTURE.MANIFEST.scene_registration_fingerprint()}
	var configured := bridge.configure_scene_staging(port,
		func(_provided: Dictionary) -> Dictionary: return {"ok": true},
		func(_entry: String, _context: Dictionary) -> Dictionary:
			return {"ok": true, "value": binding.duplicate(true)})
	assert_true(configured.ok, str(configured))
	return {"bridge": bridge, "port": port, "native": native}

func test_simulated_staging_requires_exact_candidate_and_confirmation_then_installs_once() -> void:
	var fixture := _staged_fixture()
	var prepared: Dictionary = fixture.bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:1"))
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_false(fixture.bridge.has_reading_session(), "prepare keeps target ledger detached")
	assert_eq(fixture.native.installations, 0)
	var altered: Dictionary = prepared.value.duplicate(true)
	altered.narrative_checkpoint.content_version = 2
	assert_false(fixture.bridge.commit_day_entry(altered).ok)
	assert_eq(fixture.port.consumes, 0, "changed transport cannot consume confirmation")
	assert_false(fixture.bridge.commit_day_entry(prepared.value).ok)
	assert_false(fixture.bridge.has_reading_session())
	assert_eq(fixture.native.installations, 0)
	fixture.port.confirmed = true
	var committed: Dictionary = fixture.bridge.commit_day_entry(prepared.value)
	assert_true(committed.ok, str(committed))
	assert_true(fixture.bridge.has_reading_session())
	assert_eq(fixture.native.installations, 1)
	assert_eq(fixture.bridge._reading_session.ledger.snapshot().captions.size(), 1)
	assert_false(fixture.bridge.commit_day_entry(prepared.value).ok)
	assert_eq(fixture.native.installations, 1, "consumed transport never installs twice")

func test_simulated_wrong_acknowledgement_and_uncertainty_keep_fatal_custody() -> void:
	for failure: String in ["hash", "uncertain"]:
		var fixture := _staged_fixture()
		var prepared: Dictionary = fixture.bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:1"))
		assert_true(prepared.ok, str(prepared))
		if not prepared.ok: continue
		fixture.port.confirmed = true
		fixture.port.corrupt_hash = failure == "hash"
		fixture.port.uncertain = failure == "uncertain"
		assert_false(fixture.bridge.commit_day_entry(prepared.value).ok)
		assert_true(fixture.bridge._scene_stage_fatal, failure)
		assert_eq(fixture.native.installations, 0)
		assert_false(fixture.bridge.has_reading_session())
		fixture.port.corrupt_hash = false
		fixture.port.uncertain = false
		assert_false(fixture.bridge.commit_day_entry(prepared.value).ok)
		assert_false(fixture.bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:2")).ok)
		assert_eq(fixture.native.installations, 0)

func test_simulated_confirmed_save_then_native_failure_never_retries_adoption() -> void:
	var fixture := _staged_fixture()
	var prepared: Dictionary = fixture.bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:1"))
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	fixture.port.confirmed = true
	fixture.native.fail_install = true
	assert_false(fixture.bridge.commit_day_entry(prepared.value).ok)
	assert_true(fixture.port.consumed)
	assert_true(fixture.bridge._scene_stage_fatal)
	assert_false(fixture.bridge.has_reading_session())
	assert_eq(fixture.native.installations, 1)
	fixture.native.fail_install = false
	assert_false(fixture.bridge.commit_day_entry(prepared.value).ok)
	assert_eq(fixture.native.installations, 1)

func test_selected_registration_rejects_late_or_changed_configuration() -> void:
	var created := FIXTURE.create_session()
	assert_true(created.ok, str(created))
	var selected := FIXTURE.MANIFEST.scene_registration()
	assert_true(selected.ok, str(selected))
	if not selected.ok: return
	var fingerprint: String = FIXTURE.MANIFEST.scene_registration_fingerprint()
	assert_false(FIXTURE.MANIFEST.configure_test_scene_registration(selected.value).ok)
	selected.value.caption_registry.entries[0].lines[0].text = "changed after admission"
	assert_false(FIXTURE.MANIFEST.configure_test_scene_registration(selected.value).ok)
	assert_eq(FIXTURE.MANIFEST.scene_registration_fingerprint(), fingerprint)

func before_all() -> void:
	var configured := FIXTURE.configure()
	assert_true(configured.ok, str(configured))

func test_reentry_loop_snapshot_restore_and_history_keep_all_publications() -> void:
	var created := FIXTURE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return
	var session: RefCounted = created.value
	for visit: Array in [[FIXTURE.A, "a:1"], [FIXTURE.B, "b:1"], [FIXTURE.A, "a:2"]]:
		var entered := FIXTURE.enter(session, visit[0], visit[1])
		assert_true(entered.ok, str(entered))
		if not entered.ok: return
	var next := FIXTURE.advance_detached(session)
	assert_true(next.ok, str(next))
	if not next.ok: return
	var loop := FIXTURE.advance_detached(session, true)
	assert_true(loop.ok, str(loop))
	if not loop.ok: return
	assert_eq(loop.value.ledger.captions.size(), 5)
	assert_eq(loop.value.ledger.entry_contexts.size(), 3)
	assert_eq(loop.value.frontier.line_id, "line.scene.test.a.two")
	assert_ne(loop.value.ledger.captions[3].publication_id, loop.value.ledger.captions[4].publication_id)
	var encoded := JSON_WRITER.stringify(loop.value)
	assert_true(encoded.ok, str(encoded))
	if not encoded.ok: return
	var decoded := FIXTURE.JSON_READER.parse_object(encoded.value)
	assert_true(decoded.ok, str(decoded))
	if not decoded.ok: return
	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	assert_true(restored.restore(decoded.value, FIXTURE.A).ok)
	var projected: Dictionary = restored.project(loop.value.frontier)
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	var text_rows: Array = []
	for row: Dictionary in projected.value.captions: text_rows.append(row.text)
	assert_eq(text_rows, ["A first.", "B first.", "A first.", "A loop.", "A loop."])
	assert_eq(restored.ledger.snapshot(), session.ledger.snapshot())
	var after_restore := FIXTURE.advance_detached(restored, true)
	assert_true(after_restore.ok, str(after_restore))
	if after_restore.ok: assert_eq(after_restore.value.ledger.captions.size(), 6)

func test_next_planning_is_detached_and_stops_at_registered_control() -> void:
	var created := FIXTURE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return
	var session: RefCounted = created.value
	assert_true(FIXTURE.enter(session, FIXTURE.B, "b:1").ok)
	var before: Dictionary = session.ledger.snapshot()
	var plan: Dictionary = session.prepare_next(FIXTURE.frontier(session),
		func(_beat: Dictionary) -> bool: return true)
	assert_true(plan.ok, str(plan))
	if not plan.ok: return
	assert_eq(session.ledger.snapshot(), before)
	assert_eq(plan.value.destination.kind, "control")
	assert_eq(plan.value.traversed_captions.size(), 1)
	var destination := OP.project(plan.value, "destination")
	assert_true(destination.ok, str(destination))
	if not destination.ok: return
	assert_true(session.restore(destination.value, FIXTURE.B).ok)
	assert_false(session.prepare_next(destination.value.frontier,
		func(_beat: Dictionary) -> bool: return false).ok,
		"ordinary Next cannot cross a held owner boundary")

func test_forged_path_and_historical_frame_refuse_without_installation() -> void:
	var created := FIXTURE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return
	var session: RefCounted = created.value
	assert_true(FIXTURE.enter(session, FIXTURE.A, "a:1").ok)
	var plan: Dictionary = session.prepare_next(FIXTURE.frontier(session),
		func(_beat: Dictionary) -> bool: return false)
	assert_true(plan.ok, str(plan))
	if not plan.ok: return
	var forged: Dictionary = plan.value.duplicate(true)
	forged.path[0].to = 0
	var projected := OP.project(forged, "destination")
	if projected.ok: assert_false(session.validate_saved(projected.value, FIXTURE.A).ok)
	else: assert_false(projected.ok)
	var saved: Dictionary = session.capture(FIXTURE.frontier(session)).value
	var key := LEDGER.scene_frame_key("a:1", FIXTURE.A)
	saved.ledger.entry_contexts[key].presentation.fields.occurrence_id = "forged"
	var before: Dictionary = session.ledger.snapshot()
	assert_false(session.restore(saved, FIXTURE.A).ok)
	assert_eq(session.ledger.snapshot(), before)

func test_full_run_validation_stays_closed_without_scene_receipt_owner() -> void:
	var created := FIXTURE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return
	var session: RefCounted = created.value
	assert_true(FIXTURE.enter(session, FIXTURE.A, "a:1").ok)
	var checkpoint := FIXTURE.checkpoint(session)
	assert_true(checkpoint.ok, str(checkpoint))
	if not checkpoint.ok: return
	var snapshot := {"narrative_checkpoint": checkpoint.value}
	var before := var_to_bytes(snapshot)
	var checked := RUN.validate(snapshot, true)
	assert_false(checked.ok)
	assert_eq(checked.code, &"scene_owner_validation_unavailable")
	assert_eq(var_to_bytes(snapshot), before)

func test_actual_dialogic_resource_compiles_to_registered_finite_programmes() -> void:
	var selected := FIXTURE.MANIFEST.scene_registration()
	assert_true(selected.ok, str(selected))
	if not selected.ok: return
	var entries: Array = []
	for entry: Dictionary in selected.value.entry_manifest.entries: entries.append(entry.entry_id)
	for programme: Dictionary in selected.value.scene_programme.entries:
		var compiled := ADAPTER.compile_scene_programme("res://tests/fixtures/dialogic/scene_day_terminal.dtl",
			programme.entry_id, entries, programme.markers)
		assert_true(compiled.ok, str(compiled))
		if not compiled.ok: continue
		assert_eq(compiled.value.content_sha256, programme.content_sha256)
		assert_eq(compiled.value.program_sha256, programme.program_sha256)
		assert_eq(compiled.value.native_indices.size(), compiled.value.nodes.size())
		if programme.entry_id == FIXTURE.A:
			assert_eq(compiled.value.nodes[2], {"kind": "jump", "next": 1})
