extends "res://addons/gut/test.gd"
## Domain-only: real issuer allocation/derivation, synthetic registered programme.
## Full checkpoint persistence and physical playback are separate integration gates.
const FIXTURE := preload("res://tests/support/SceneTransitionIdentityFixture.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
var fixture: RefCounted
var identity: Dictionary
var bundle: Dictionary
var receipts: Dictionary
var admission: Dictionary
var plan: Dictionary
var lifecycle: RefCounted

func _ok(result: Dictionary, message: String) -> bool:
	assert_true(result.get("ok", false), message + ": " + str(result))
	return result.get("ok", false)

func _setup() -> bool:
	fixture = FIXTURE.new()
	if not _ok(fixture.setup(), "real issuer fixture"): return false
	identity = FIXTURE.identity(fixture.lifecycle)
	bundle = fixture.bundle.duplicate(true)
	bundle.scene_programme.entries.append({"entry_id": "ending.alone.normal", "content_version": 1,
		"content_sha256": "c".repeat(64), "program_sha256": "d".repeat(64), "markers": []})
	bundle.targets.append({"target_id": "terminal.alone", "target": {"kind": "ending",
		"entry_id": "ending.alone.normal", "label": "ending.alone.normal", "content_version": 1,
		"program_sha256": "d".repeat(64)}})
	bundle.scene_programme.entries[0].markers[0].payload.target_id = "terminal.alone"
	var root: Dictionary = fixture.issuer.issue(&"transaction_id")
	if not _ok(root, "source admission root"): return false
	var checkpoint := {"checkpoint_id": identity.run_id + ":1", "checkpoint_sequence": 1,
		"snapshot_sha256": "e".repeat(64)}
	var source: Dictionary = CONTRACT.make_scene_admission(identity, root.value.issuer_receipt,
		"TEST.target", checkpoint, null, null, bundle, fixture.issuer)
	if not _ok(source, "ordinary source admission"): return false
	receipts = {source.value.transaction_id: source.value}
	var event: Dictionary = fixture.event.duplicate(true)
	root = fixture.issuer.issue(&"transaction_id")
	if not _ok(root, "final event root"): return false
	event.command_id = root.value.token
	event.issuer_receipt = root.value.issuer_receipt
	event.source.scene_occurrence = source.value.transaction_id
	event.payload.target_id = "terminal.alone"
	var anchor: Dictionary = fixture.anchor.duplicate(true)
	anchor.session_id = source.value.transaction_id
	var request: Dictionary = CONTRACT.scene_completion_request(event, anchor, bundle)
	if not _ok(request, "terminal completion request"): return false
	var child: Dictionary = fixture.issuer.derive_child(request.value)
	if not _ok(child, "terminal completion child"): return false
	var trigger: Dictionary = CONTRACT.make_scene_receipt(event, anchor, {
		"kind": "scene_transition_accepted", "source_scene_occurrence": source.value.transaction_id,
		"target_id": "terminal.alone", "target": bundle.targets[1].target,
		"resolution_receipt": {"receipt_id": child.value.child_id, "provenance": child.value.provenance}}, bundle)
	if not _ok(trigger, "durable final event receipt"): return false
	receipts[event.command_id] = trigger.value
	root = fixture.issuer.issue(&"transaction_id")
	if not _ok(root, "terminal admission root"): return false
	var admitted: Dictionary = CONTRACT.make_scene_terminal_admission(identity, root.value.issuer_receipt,
		source.value.transaction_id, source.value.transaction_id, trigger.value, checkpoint,
		"terminal.alone", bundle, fixture.issuer)
	if not _ok(admitted, "authenticated terminal admission"): return false
	admission = admitted.value
	if not _ok(CONTRACT.validate_scene_terminal_admission(admission, bundle, fixture.issuer, receipts), "full ledger admission"): return false
	plan = {"schema_version": 1, "source_kind": "scene", "admission": admission.duplicate(true),
		"ending_id": "ending.alone", "epilogue_ending_id": "", "steps": [{"ending_id": "ending.alone", "role": "core"}],
		"next_step_index": 0, "playback_stage": "PRIMARY_PENDING", "playback_receipts": {},
		"source_reading_checkpoint": {"stage": "scene", "reading_session": {"occurrence_id": source.value.transaction_id}}}
	var state := identity.duplicate(true)
	state.merge({"state": "PLAYING", "restore_provenance": null, "scene_assignment": {
		"creation_transaction_id": "TEST.creation", "form": "sweet", "predecessor_assignment_sha256": null,
		"predecessor_run_id": null, "rng_nonce": 0, "ruleset_id": "scene.new_run.alternating.v1", "selection_kind": "initial_random"}})
	lifecycle = LIFECYCLE.new()
	if not _ok(lifecycle.configure_scene_issuer(fixture.issuer), "lifecycle issuer"): return false
	return _ok(lifecycle.commit_restore(state), "PLAYING scene restore")

func test_authenticated_terminal_roundtrip_retains_source_without_legacy_day() -> void:
	if not _setup(): return
	assert_false(lifecycle.to_dict().has("ending_plan"))
	assert_true(lifecycle.enter_scene_ending(plan).ok)
	var saved: Dictionary = lifecycle.to_dict()
	assert_eq(saved.state, "ENDING")
	assert_eq(saved.ending_plan.admission, admission)
	assert_false(saved.has("day"))
	assert_false(saved.ending_plan.has("source_day"))
	var restored := LIFECYCLE.new()
	assert_true(restored.configure_scene_issuer(fixture.issuer).ok)
	assert_true(restored.commit_restore(saved).ok)
	assert_eq(restored.to_dict(), saved)
	saved.ending_plan.admission.target_id = "forged"
	assert_ne(restored.to_dict().ending_plan.admission.target_id, "forged")
	assert_false(lifecycle.enter_scene_ending(plan).ok, "duplicate does not replace admitted state")

func test_terminal_tampering_stale_source_and_ordinary_admission_are_refused() -> void:
	if not _setup(): return
	for key: String in ["trigger_sha256", "target_id", "source_occurrence_id"]:
		var bad := admission.duplicate(true)
		bad[key] = "f".repeat(64)
		assert_false(CONTRACT.validate_scene_terminal_admission(bad, bundle, fixture.issuer, receipts).ok, key)
	var missing := receipts.duplicate(true)
	missing.erase(admission.trigger_command_id)
	assert_false(CONTRACT.validate_scene_terminal_admission(admission, bundle, fixture.issuer, missing).ok)
	var root: Dictionary = fixture.issuer.issue(&"transaction_id")
	assert_false(CONTRACT.make_scene_admission(identity, root.value.issuer_receipt, "terminal.alone",
		admission.source_checkpoint, admission.trigger_command_id, null, bundle, fixture.issuer).ok)
	var changed := plan.duplicate(true)
	changed.source_day = 7
	assert_false(lifecycle.enter_scene_ending(changed).ok)
	changed = plan.duplicate(true)
	changed.source_reading_checkpoint.reading_session.occurrence_id = "stale"
	assert_false(lifecycle.enter_scene_ending(changed).ok)
	assert_eq(lifecycle.to_dict().state, "PLAYING")

func test_physical_completion_and_gallery_are_ordered_and_persisted() -> void:
	if not _setup(): return
	assert_true(lifecycle.enter_scene_ending(plan).ok)
	assert_false(lifecycle.complete_ending().ok)
	assert_false(lifecycle.complete_ending_playback_stage("ending:step:0", &"PRIMARY_PENDING", {"value": {}}).ok)
	var physical := {"value": {"outcome": "completed", "timeline_completion_receipt_id": "TEST.physical"}}
	assert_true(lifecycle.complete_ending_playback_stage("ending:step:0", &"PRIMARY_PENDING", physical).ok)
	assert_false(lifecycle.complete_ending_playback_stage("ending:step:0", &"PRIMARY_PENDING", physical).ok)
	assert_false(lifecycle.complete_ending().ok)
	assert_true(lifecycle.complete_ending_playback_stage("ending:EPILOGUE_PLAYED", &"EPILOGUE_PLAYED",
		{"value": {"step:0": {"ending_id": "ending.alone"}}}).ok)
	assert_true(lifecycle.complete_ending().ok)
	var saved: Dictionary = lifecycle.to_dict()
	assert_eq(saved.state, "COMPLETED")
	assert_true(LIFECYCLE.validate_scene(saved, fixture.issuer).ok)
	var restored := LIFECYCLE.new()
	assert_true(restored.configure_scene_issuer(fixture.issuer).ok)
	assert_true(restored.commit_restore(saved).ok)
	assert_eq(restored.to_dict(), saved)
	saved.state = "PLAYING"
	assert_false(LIFECYCLE.validate_scene(saved, fixture.issuer).ok, "PLAYING cannot carry terminal plan")

class TerminalReaderSpy extends RefCounted:
	var retire_calls := 0
	func retire_scene_for_ending(_admission_id: String) -> Dictionary:
		retire_calls += 1
		return {"ok": true}

func test_delayed_duplicate_admission_preserves_ending_reader_and_completed_run() -> void:
	if not _setup(): return
	assert_true(lifecycle.enter_scene_ending(plan).ok)
	var game := preload("res://autoload/GameState.gd").new()
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	var reader := TerminalReaderSpy.new()
	var save_owner := RefCounted.new()
	game._run_lifecycle = lifecycle
	game._identity_issuer = fixture.issuer
	game._scene_event_bridge = reader
	game._scene_save_owner = save_owner
	game._scene_snapshot_references = {"active_occurrence_id": admission.source_occurrence_id,
		"active_admission_receipt_id": admission.source_admission_receipt_id}
	game._command_receipts = receipts.duplicate(true)
	assert_true(game.configure_mutation_gate(gate).ok)
	var issuer_before: Dictionary = fixture.issuer.capture_root()
	var ending_before: Dictionary = lifecycle.to_dict()
	var duplicate: Dictionary = game.admit_scene_target(admission.target_id, admission.trigger_command_id)
	assert_true(duplicate.get("ok", false), str(duplicate))
	assert_true(duplicate.get("duplicate", false))
	assert_eq(duplicate.get("value", {}).get("admission_id"), admission.admission_id)
	assert_eq(lifecycle.to_dict(), ending_before)
	assert_eq(reader.retire_calls, 0, "current ending reader is never retired by old final Accept")
	assert_eq(fixture.issuer.capture_root(), issuer_before, "no second root allocated")
	assert_false(game.admit_scene_target("wrong.target", admission.trigger_command_id).ok)
	assert_false(game.admit_scene_target(admission.target_id, "wrong.trigger").ok)
	assert_true(lifecycle.complete_ending_playback_stage("ending:step:0", &"PRIMARY_PENDING",
		{"value": {"outcome": "completed", "timeline_completion_receipt_id": "TEST.physical"}}).ok)
	assert_true(lifecycle.complete_ending_playback_stage("ending:EPILOGUE_PLAYED", &"EPILOGUE_PLAYED",
		{"value": {"step:0": {"ending_id": "ending.alone"}}}).ok)
	assert_true(lifecycle.complete_ending().ok)
	var completed_before: Dictionary = lifecycle.to_dict()
	duplicate = game.admit_scene_target(admission.target_id, admission.trigger_command_id)
	assert_true(duplicate.get("ok", false), str(duplicate))
	assert_true(duplicate.get("duplicate", false))
	assert_eq(lifecycle.to_dict(), completed_before, "completed state is not resurrected")
	assert_eq(reader.retire_calls, 0)
	assert_eq(fixture.issuer.capture_root(), issuer_before)
	assert_true(game._scene_terminal_operation.is_empty())
	game.free()

func test_terminal_route_waits_for_transaction_then_rejects_replaced_session() -> void:
	if not _setup(): return
	assert_true(lifecycle.enter_scene_ending(plan).ok)
	var game := preload("res://autoload/GameState.gd").new()
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	game._run_lifecycle = lifecycle
	game._live_session_active = true
	game._live_session_generation = 1
	game._live_session_run_id = lifecycle.to_dict().run_id
	assert_true(game.configure_mutation_gate(gate).ok)
	var held: Dictionary = gate.acquire(&"restore")
	assert_true(held.ok)
	var session: Dictionary = game._live_session_fact()
	game._on_scene_terminal_retired(admission.admission_id, session)
	game._on_scene_terminal_retired(admission.admission_id, session)
	assert_eq(gate.get_signal_connection_list("transaction_released").size(), 1,
		"one pending route survives a temporary gate owner")
	# A replacement during the awaited transaction makes the old route obsolete.
	game._live_session_generation += 1
	assert_true(gate.release(&"restore", held.value.token).ok)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(gate.get_signal_connection_list("transaction_released").size(), 0)
	assert_false(gate.is_fatal_latched(), "stale callback does not route or fault the replacement")
	assert_eq(lifecycle.to_dict().state, "ENDING")
	game.free()
