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
	var authority: Callable
	var authority_bridge: Object
	var on_configure: Callable
	var refuse_configuration := false
	var accepted_phases: Array[String] = []
	var probe_wrong_phases := false
	var wrong_phase_results: Array[Dictionary] = []

	func configure_scene_entry_authority(bridge: Object, callback: Callable) -> Dictionary:
		if authority.is_valid() or bridge == null or not callback.is_valid(): return {"ok": false}
		if on_configure.is_valid(): on_configure.call()
		if refuse_configuration: return {"ok": false}
		authority_bridge = bridge
		authority = callback
		return {"ok": true}

	func simulate_checkpoint_commit() -> Dictionary:
		# This is callback-order evidence only, never disk durability evidence.
		var checked: Dictionary = authority.call(capability, binding, checkpoint, "commit")
		if not checked.ok: return checked
		accepted_phases.append("commit")
		confirmed = true
		return {"ok": true}

	func retain_scene_entry(bridge: Object, capability_id: String, owner_binding: Dictionary,
			narrative_checkpoint: Dictionary) -> Dictionary:
		if bridge != authority_bridge or not authority.is_valid(): return {"ok": false}
		var checked: Dictionary = authority.call(capability_id, owner_binding, narrative_checkpoint, "retain")
		if not checked.ok: return checked
		accepted_phases.append("retain")
		if probe_wrong_phases:
			for phase: String in ["commit", "consume"]:
				wrong_phase_results.append(authority.call(capability_id, owner_binding, narrative_checkpoint, phase))
		capability = capability_id
		binding = owner_binding.duplicate(true)
		checkpoint = narrative_checkpoint.duplicate(true)
		return {"ok": true}

	func consume_scene_entry_ack(capability_id: String) -> Dictionary:
		if not authority.is_valid(): return {"ok": false}
		var checked: Dictionary = authority.call(capability_id, binding, checkpoint, "consume")
		if not checked.ok: return checked
		accepted_phases.append("consume")
		if probe_wrong_phases:
			for phase: String in ["retain", "commit"]:
				wrong_phase_results.append(authority.call(capability_id, binding, checkpoint, phase))
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
	signal reading_frontier_restored(result: Dictionary)
	signal playback_start_failed(failure: Dictionary)
	var installations := 0
	var fail_install := false
	var restore_inside_install := false
	var fail_signal_inside_install := false

	func install_scene_target(_session: RefCounted, _checkpoint: Dictionary, _target: Dictionary) -> Dictionary:
		installations += 1
		if restore_inside_install: reading_frontier_restored.emit({"ok": true})
		if fail_signal_inside_install:
			playback_start_failed.emit({"ok": false, "code": &"test_simulated_native_failure"})
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

func test_simulated_configuration_reentrancy_refuses_nested_owners_and_releases_refusal_guard() -> void:
	var bridge := BRIDGE.new()
	autofree(bridge)
	var outer := SimulatedCheckpointPort.new()
	var other := SimulatedCheckpointPort.new()
	var source := func(_binding: Dictionary) -> Dictionary: return {"ok": true}
	var context := func(_entry: String, _frame: Dictionary) -> Dictionary: return {"ok": false}
	var nested: Array[Dictionary] = []
	outer.on_configure = func() -> void:
		nested.append(bridge.configure_scene_staging(other, source, context))
		nested.append(bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:1")))
	outer.refuse_configuration = true
	assert_false(bridge.configure_scene_staging(outer, source, context).ok)
	assert_eq(nested.size(), 2)
	for result: Dictionary in nested: assert_false(result.ok)
	assert_null(bridge._scene_stage_port, "refusal installs neither outer nor reentrant owner")
	assert_false(other.authority.is_valid())
	assert_false(bridge._scene_stage_busy, "refused configuration releases its temporary guard")
	nested.clear()
	outer.refuse_configuration = false
	assert_true(bridge.configure_scene_staging(outer, source, context).ok)
	assert_eq(nested.size(), 2)
	for result: Dictionary in nested: assert_false(result.ok)
	assert_eq(bridge._scene_stage_port, outer)
	assert_eq(outer.authority_bridge, bridge)
	assert_true(outer.authority.is_valid())
	assert_false(other.authority.is_valid(), "nested port never receives authority")
	assert_false(bridge.configure_scene_staging(other, source, context).ok)
	assert_false(bridge.configure_scene_staging(outer, source, context).ok)
	assert_eq(bridge._scene_stage_port, outer, "configured owner cannot be replaced or rebound")
	assert_true(bridge._scene_stage.is_empty(), "nested preparation cannot retain a candidate")

func test_simulated_checkpoint_authority_binds_private_candidate_and_call_phase() -> void:
	var fixture := _staged_fixture()
	fixture.port.probe_wrong_phases = true
	assert_eq(fixture.port.authority_bridge, fixture.bridge)
	var prepared: Dictionary = fixture.bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:1"))
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(fixture.port.accepted_phases, ["retain"])
	var cap: String = fixture.port.capability
	var binding: Dictionary = fixture.port.binding.duplicate(true)
	var checkpoint: Dictionary = fixture.port.checkpoint.duplicate(true)
	for phase: String in ["retain", "consume", "unknown"]:
		var wrong_phase: Dictionary = fixture.port.authority.call(cap, binding, checkpoint, phase)
		assert_false(wrong_phase.ok, "idle retained candidate cannot authorize " + phase)
	var foreign: Dictionary = fixture.port.authority.call("foreign:capability", binding, checkpoint, "commit")
	assert_false(foreign.ok)
	var changed_binding: Dictionary = binding.duplicate(true)
	changed_binding.operation_id = "foreign:operation"
	var changed: Dictionary = fixture.port.authority.call(cap, changed_binding, checkpoint, "commit")
	assert_false(changed.ok)
	var changed_checkpoint: Dictionary = checkpoint.duplicate(true)
	changed_checkpoint.content_version += 1
	changed = fixture.port.authority.call(cap, binding, changed_checkpoint, "commit")
	assert_false(changed.ok)
	assert_eq(fixture.port.binding, binding, "authority refusals preserve retained binding")
	assert_eq(fixture.port.checkpoint, checkpoint, "authority refusals preserve detached target")
	assert_false(fixture.bridge.has_reading_session())
	assert_eq(fixture.native.installations, 0)
	var confirmed: Dictionary = fixture.port.simulate_checkpoint_commit()
	assert_true(confirmed.ok, str(confirmed))
	if not confirmed.ok: return
	var installed: Dictionary = fixture.bridge.commit_day_entry(prepared.value)
	assert_true(installed.ok, str(installed))
	assert_eq(fixture.port.accepted_phases, ["retain", "commit", "consume"])
	assert_eq(fixture.port.wrong_phase_results.size(), 4)
	for refused: Dictionary in fixture.port.wrong_phase_results: assert_false(refused.ok)
	assert_true(fixture.port.consumed)
	assert_eq(fixture.port.consumes, 1)
	assert_eq(fixture.native.installations, 1)
	for phase: String in ["retain", "commit", "consume"]:
		var spent: Dictionary = fixture.port.authority.call(cap, binding, checkpoint, phase)
		assert_false(spent.ok, "adopted candidate cannot authorize " + phase)

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

func test_synchronous_restore_then_native_failure_retains_committed_target_without_adoption() -> void:
	for failure: String in ["return_failure", "failure_signal"]:
		var fixture := _staged_fixture()
		watch_signals(fixture.bridge)
		var prepared: Dictionary = fixture.bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:1"))
		assert_true(prepared.ok, str(prepared))
		if not prepared.ok: continue
		fixture.port.confirmed = true
		fixture.native.restore_inside_install = true
		fixture.native.fail_install = failure == "return_failure"
		fixture.native.fail_signal_inside_install = failure == "failure_signal"
		var committed: Dictionary = fixture.bridge.commit_day_entry(prepared.value)
		assert_false(committed.ok, failure)
		assert_eq(committed.get("code"), &"test_simulated_native_failure", failure)
		assert_true(fixture.port.consumed, failure)
		assert_eq(fixture.port.consumes, 1, failure)
		assert_true(fixture.bridge._scene_stage_fatal, failure)
		assert_false(fixture.bridge.has_reading_session(), failure)
		assert_true(fixture.bridge._active_entry.is_empty(), failure)
		assert_signal_not_emitted(fixture.bridge, "reading_session_changed",
			"a synchronous success callback cannot briefly publish before install returns")
		assert_eq(fixture.bridge._scene_stage.get("committed_checkpoint"),
			{"checkpoint_id": "test:target-checkpoint", "checkpoint_sequence": 1,
				"snapshot_sha256": "1".repeat(64)}, failure)
		assert_eq(fixture.bridge._scene_stage.transport, prepared.value, failure)
		assert_true(fixture.bridge._scene_stage.has("native_failure"), failure)
		assert_eq(fixture.native.installations, 1, failure)
		fixture.native.fail_install = false
		fixture.native.fail_signal_inside_install = false
		# Late duplicate restoration must not clear failure custody either.
		fixture.native.reading_frontier_restored.emit({"ok": true})
		assert_false(fixture.bridge.has_reading_session(), failure)
		assert_true(fixture.bridge._scene_stage_fatal, failure)
		assert_false(fixture.bridge.commit_day_entry(prepared.value).ok, failure)
		assert_false(fixture.bridge.prepare_day_entry(FIXTURE.A, FIXTURE.frame(FIXTURE.A, "a:2")).ok, failure)
		assert_eq(fixture.port.consumes, 1, "fatal retries cannot consume another acknowledgement")
		assert_eq(fixture.native.installations, 1, "fatal retries cannot install again")
		assert_signal_not_emitted(fixture.bridge, "reading_session_changed")

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


func test_fully_witnessed_next_stops_at_revisited_backward_caption() -> void:
	var created := FIXTURE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return
	var session: RefCounted = created.value
	var entered := FIXTURE.enter(session, FIXTURE.A, "a:1")
	assert_true(entered.ok, str(entered))
	if not entered.ok: return
	var before: Dictionary = session.capture(FIXTURE.frontier(session)).value
	var planned: Dictionary = session.prepare_next(FIXTURE.frontier(session),
		func(_beat: Dictionary) -> bool: return true)
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	var plan: Dictionary = planned.value
	assert_eq(plan.path, [{"from": 0, "to": 1}, {"from": 1, "to": 2}, {"from": 2, "to": 1}])
	assert_eq(plan.traversed_captions.size(), 1)
	assert_eq(plan.destination.kind, "line")
	assert_eq(plan.destination.program_index, 1)
	assert_eq(plan.traversed_captions[0].beat.line_id, plan.destination.caption.beat.line_id)
	assert_ne(plan.traversed_captions[0].publication_id, plan.destination.caption.publication_id)
	assert_eq(session.capture(FIXTURE.frontier(session)).value, before,
		"planning allocates only on the detached ledger and retains the live cursor")
	var projected := OP.project(plan, "destination")
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	var admitted: Dictionary = restored.restore(projected.value, FIXTURE.A)
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	assert_eq(restored.ledger.snapshot().captions.size(), 3)
	assert_eq(restored.capture(projected.value.frontier).value, projected.value)
	assert_eq(session.capture(FIXTURE.frontier(session)).value, before)
	# Keep the forged operation structurally valid and programme-adjacent:
	# continue around the same loop after its first mandatory stopping point.
	var extended: Dictionary = plan.duplicate(true)
	extended.path.append({"from": 1, "to": 2})
	extended.path.append({"from": 2, "to": 1})
	var invalid_projection := OP.project(extended, "destination")
	assert_true(invalid_projection.ok, "shape alone does not authorize programme traversal")
	if invalid_projection.ok:
		var retained: Dictionary = restored.ledger.snapshot()
		assert_false(restored.restore(invalid_projection.value, FIXTURE.A).ok,
			"no edge may follow the first backward-caption stop")
		assert_eq(restored.ledger.snapshot(), retained)

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
