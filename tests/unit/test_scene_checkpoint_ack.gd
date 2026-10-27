extends "res://addons/gut/test.gd"

# Live-publication custody and explicit absence of lower storage operations.
# Real native adoption and physical save bytes are covered by integration suites.
const PORT := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")

class CheckpointSeam extends "res://tests/support/FakeNarrativeCheckpointContext.gd":
	var current := {"checkpoint_id": "run:1", "checkpoint_sequence": 1, "narrative_checkpoint": {"source": true}}

class BridgeSeam extends RefCounted:
	var allow := true
	var expected_binding: Dictionary = {}
	var expected_checkpoint: Dictionary = {}
	var phases: Array = []
	var callback := Callable()
	func validate(capability: String, binding: Dictionary, checkpoint: Dictionary, phase: String) -> Dictionary:
		phases.append(phase)
		if callback.is_valid(): callback.call()
		return {"ok": allow and capability == "cap:1" and binding.recursive_equal(expected_binding, 32)
			and checkpoint.recursive_equal(expected_checkpoint, 32)}

func _hash(value: Variant) -> String:
	return str(JSON_WRITER.stringify(value).value).sha256_text()

func _fixture(retain: bool = true) -> Dictionary:
	var real := CheckpointSeam.new()
	real.route_id_value = "dating"
	var authority := BridgeSeam.new()
	var port := PORT.new()
	assert_true(port.configure(real, real.provider_callables()).ok)
	assert_true(port.configure_scene_entry_authority(authority, authority.validate).ok)
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	assert_true(session.begin_scene("TEST.checkpoint-ack").ok)
	var occurrence := "occurrence:target"
	var presentation := FROZEN.build("Day1", {"entry_id": "Day1", "entry_role": "scene",
		"occurrence_id": occurrence, "admission_receipt_id": occurrence})
	assert_true(presentation.ok, str(presentation))
	var frame := {"expected_stage": "scene", "playback_id": occurrence, "role": "scene",
		"transaction_id": occurrence, "presentation": presentation.value}
	assert_true(session.admit_scene("Day1", frame).ok)
	var programme: Dictionary = session.entry_program("Day1", frame)
	var allocated: Dictionary = session.ledger.allocate_publication(session.command_id, "Day1", occurrence)
	var line_id: String = programme.value.lines[0].line_id
	assert_true(session.ledger.publish_line(session.command_id, allocated.value, "Day1", line_id, occurrence).ok)
	var captured: Dictionary = session.capture({"line_id": line_id, "publication_id": allocated.value})
	assert_true(captured.ok, str(captured))
	var binding := {"operation_id": "operation:1", "source_checkpoint": {"checkpoint_id": "run:1", "checkpoint_sequence": 1,
		"snapshot_sha256": _hash(real.current)}, "source_occurrence_id": "occurrence:source", "trigger_command_id": "event:1",
		"target_id": "target:1", "target_occurrence_id": occurrence, "admission_receipt_id": occurrence,
		"registration_sha256": session.fingerprint}
	var checkpoint := {"stage": "scene", "manifest_fingerprint": binding.registration_sha256,
		"entry_id": "Day1", "content_version": 1, "transaction_id": occurrence,
		"reading_session": captured.value, "frozen_context": frame}
	authority.expected_binding = binding.duplicate(true)
	authority.expected_checkpoint = checkpoint.duplicate(true)
	if retain: assert_true(port.retain_scene_entry(authority, "cap:1", binding, checkpoint).ok)
	return {"port": port, "real": real, "authority": authority, "binding": binding, "checkpoint": checkpoint}

func _scene_input(f: Dictionary) -> Dictionary:
	var board: Dictionary = BOARD_STATE.new().capture()
	board.erase("terminal_receipts")
	board["settled_inspection"] = false
	board["round_paid"] = false
	return {"lifecycle": {}, "gameplay": {}, "contacts": {}, "desktop": {"board": board, "consequence": {}},
		"scene": {"registration_sha256": f.binding.registration_sha256,
			"active_occurrence_id": f.binding.target_occurrence_id,
			"entry_id": f.checkpoint.entry_id, "notification": null, "active_challenge": null, "return_to": null},
		"applied_effect_transaction_ids": {}, "applied_variable_transaction_ids": {}, "command_receipts": {}}

func test_live_publication_binds_target_and_consumes_once_without_storage() -> void:
	var f := _fixture()
	var old_disk: Dictionary = f.real.current.duplicate(true)
	var published: Dictionary = f.port.commit_scene_event(_scene_input(f), f.checkpoint)
	assert_true(published.ok, str(published))
	assert_false(published.get("durable", true))
	assert_eq(published.value, {"publication": {"kind": "live", "state_sha256": _hash(f.checkpoint)}})
	var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_true(ack.ok, str(ack))
	assert_eq(ack.value.keys().size(), 6)
	assert_eq(ack.value.source_checkpoint, f.binding.source_checkpoint)
	assert_eq(ack.value.target_publication, published.value.publication)
	assert_eq(ack.value.binding_sha256, _hash(f.binding))
	assert_eq(ack.value.narrative_checkpoint_sha256, _hash(f.checkpoint))
	assert_false(f.port.consume_scene_entry_ack("cap:1").ok)
	assert_false(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, f.checkpoint).ok)
	assert_eq(f.real.current, old_disk)
	assert_true(f.real.calls.is_empty(), "no capture, preparation, write, rollback or readback")

func test_foreign_authority_and_reconfiguration_refuse() -> void:
	var f := _fixture(false)
	var other := BridgeSeam.new()
	assert_false(f.port.configure_scene_entry_authority(other, other.validate).ok)
	assert_false(f.port.configure_scene_entry_authority(f.authority, other.validate).ok)
	assert_false(f.port.retain_scene_entry(other, "cap:1", f.binding, f.checkpoint).ok)
	assert_false(PORT.new().consume_scene_entry_ack("cap:1").ok)
	assert_true(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, f.checkpoint).ok)

func test_unpublished_candidate_cannot_be_confirmed_with_hash_knowledge() -> void:
	var f := _fixture()
	var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_false(ack.ok)
	assert_false(ack.committed)
	assert_false(f.port.consume_scene_entry_ack(_hash(f.checkpoint)).ok)
	assert_false(f.port.consume_scene_entry_ack("foreign").ok)
	assert_true(f.real.calls.is_empty())

func test_owner_refusal_preserves_capability_for_retry_and_consumption() -> void:
	var f := _fixture()
	f.authority.allow = false
	assert_false(f.port.commit_scene_event(_scene_input(f), f.checkpoint).ok)
	f.authority.allow = true
	assert_true(f.port.commit_scene_event(_scene_input(f), f.checkpoint).ok)
	f.authority.allow = false
	assert_false(f.port.consume_scene_entry_ack("cap:1").ok)
	f.authority.allow = true
	assert_true(f.port.consume_scene_entry_ack("cap:1").ok)
	assert_true(f.real.calls.is_empty())

func test_changed_target_refuses_but_older_disk_never_governs_live_publication() -> void:
	var f := _fixture()
	var altered: Dictionary = f.checkpoint.duplicate(true)
	altered["altered"] = true
	assert_false(f.port.commit_scene_event(_scene_input(f), altered).ok)
	f.real.current = {}
	f.real.prepare_ok = false
	f.real.commit_ok = false
	f.real.rollback_ok = false
	assert_true(f.port.commit_scene_event(_scene_input(f), f.checkpoint).ok)
	f.real.current = {"unrelated_disk_snapshot": true}
	assert_true(f.port.consume_scene_entry_ack("cap:1").ok)
	assert_true(f.real.calls.is_empty(), "unavailable storage cannot block ordinary reading")

func test_reentrant_authority_callbacks_cannot_publish_or_consume() -> void:
	var f := _fixture(false)
	var results: Array = []
	f.authority.callback = func() -> void:
		results.append(f.port.consume_scene_entry_ack("cap:1"))
		results.append(f.port.commit_scene_event(_scene_input(f), f.checkpoint))
	assert_true(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, f.checkpoint).ok)
	assert_true(f.port.commit_scene_event(_scene_input(f), f.checkpoint).ok)
	assert_true(f.port.consume_scene_entry_ack("cap:1").ok)
	assert_gt(results.size(), 0)
	for result: Dictionary in results: assert_false(result.ok)
	f.authority.callback = Callable()
	assert_true(f.real.calls.is_empty())

func test_invalid_binding_and_target_fields_refuse_before_retention() -> void:
	for field: String in ["registration_sha256", "source_checkpoint", "target_occurrence_id", "admission_receipt_id"]:
		var f := _fixture(false)
		var changed: Dictionary = f.binding.duplicate(true)
		if field == "source_checkpoint": changed[field] = {"checkpoint_id": "run:1"}
		else: changed[field] = "wrong"
		assert_false(f.port.retain_scene_entry(f.authority, "cap:1", changed, f.checkpoint).ok, field)
		assert_true(f.real.calls.is_empty())

func test_ordinary_publication_does_not_create_entry_capability() -> void:
	var f := _fixture(false)
	var result: Dictionary = f.port.commit_scene_event(_scene_input(f), f.checkpoint)
	assert_true(result.ok, str(result))
	assert_false(result.get("durable", true))
	assert_false(f.port.consume_scene_entry_ack("cap:1").ok)
	assert_true(f.real.calls.is_empty())

func test_malformed_nested_checkpoint_refuses_before_callback_or_write() -> void:
	for frame: Variant in [null, 7, {"playback_id": "occurrence:target", "presentation": null}, {"playback_id": "occurrence:target", "presentation": {"fields": "wrong"}}]:
		var f := _fixture(false)
		var checkpoint: Dictionary = f.checkpoint.duplicate(true)
		checkpoint.frozen_context = frame
		assert_false(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, checkpoint).ok)
		assert_true(f.authority.phases.is_empty())
		assert_true(f.real.calls.is_empty())

func test_authority_callback_cannot_change_detached_publication() -> void:
	var f := _fixture()
	var original: Dictionary = f.checkpoint.duplicate(true)
	var input := _scene_input(f)
	var before: Dictionary = input.duplicate(true)
	f.authority.callback = func() -> void:
		f.checkpoint["altered"] = true
		input.gameplay["altered"] = true
	var published: Dictionary = f.port.commit_scene_event(input, f.checkpoint)
	assert_true(published.ok, str(published))
	assert_true(f.checkpoint.has("altered"))
	assert_ne(input, before)
	assert_eq(published.value.publication.state_sha256, _hash(original))
	var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_true(ack.ok, str(ack))
	assert_eq(ack.value.narrative_checkpoint_sha256, _hash(original))
	f.authority.callback = Callable()
	assert_true(f.real.calls.is_empty())

func test_scene_publication_refuses_unbound_input_before_storage() -> void:
	for mode: String in ["input", "registration", "occurrence", "admission", "authority"]:
		var f := _fixture()
		var input := _scene_input(f)
		match mode:
			"input": input["committed_schedule"] = {}
			"registration": input.scene.registration_sha256 = "b".repeat(64)
			"occurrence": input.scene.active_occurrence_id = "wrong"
			"admission": input.scene["active_admission_receipt_id"] = "wrong"
			"authority":
				f.port = PORT.new()
				assert_true(f.port.configure(f.real, f.real.provider_callables()).ok)
		assert_false(f.port.commit_scene_event(input, f.checkpoint).ok, mode)
		assert_true(f.real.calls.is_empty(), mode)

func test_candidate_reference_compact_persisted_matches_full_targets_without_mutation() -> void:
	for retained: bool in [false, true]:
		var f := _fixture(retained)
		var projected: Dictionary = SESSION.project_player_checkpoint(f.checkpoint)
		assert_true(projected.ok, str(projected))
		if not projected.ok: return
		assert_eq(projected.value.reading_session.schema_version, 7)
		assert_eq(f.checkpoint.reading_session.schema_version, 5)
		var snapshot := {"checkpoint_id": "run:2", "checkpoint_sequence": 2,
			"narrative_checkpoint": projected.value}
		var candidate := {"checkpoint_id": "run:2", "journal_candidate": {"current": {"snapshot": snapshot}},
			"autosave_document": {"current_snapshot": {"snapshot": snapshot.duplicate(true)}}}
		var candidate_before := candidate.duplicate(true)
		var supplied_before: Dictionary = f.checkpoint.duplicate(true)
		var retained_before: Dictionary = f.port._scene_entry.duplicate(true)
		var reference: Dictionary = f.port._scene_candidate_reference(candidate, f.checkpoint)
		assert_eq(reference, {"checkpoint_id": "run:2", "checkpoint_sequence": 2, "snapshot_sha256": _hash(snapshot)})
		assert_eq(candidate, candidate_before)
		assert_eq(f.checkpoint, supplied_before)
		assert_eq(f.port._scene_entry, retained_before)
		assert_false(f.real.calls.has("commit"), "reference lookup grants no write")

func test_candidate_reference_refuses_independent_target_mismatch_and_malformed_persisted_checkpoint() -> void:
	for mode: String in ["retained_rehashed", "supplied", "persisted", "null", "scalar", "incomplete"]:
		var f := _fixture()
		var projected: Dictionary = SESSION.project_player_checkpoint(f.checkpoint)
		assert_true(projected.ok, str(projected))
		if not projected.ok: return
		var supplied: Dictionary = f.checkpoint.duplicate(true)
		var persisted: Variant = projected.value.duplicate(true)
		match mode:
			"retained_rehashed":
				f.port._scene_entry.checkpoint.content_version += 1
				f.port._scene_entry.narrative_checkpoint_sha256 = _hash(f.port._scene_entry.checkpoint)
			"supplied": supplied.content_version += 1
			"persisted": persisted.content_version += 1
			"null": persisted = null
			"scalar": persisted = 7
			"incomplete": persisted = {"stage": "scene", "reading_session": {"schema_version": 7}}
		var snapshot := {"checkpoint_id": "run:2", "checkpoint_sequence": 2, "narrative_checkpoint": persisted}
		var candidate := {"checkpoint_id": "run:2", "journal_candidate": {"current": {"snapshot": snapshot}},
			"autosave_document": {"current_snapshot": {"snapshot": snapshot.duplicate(true)}}}
		var candidate_before := candidate.duplicate(true)
		var supplied_before := supplied.duplicate(true)
		var retained_before: Dictionary = f.port._scene_entry.duplicate(true)
		assert_true(f.port._scene_candidate_reference(candidate, supplied).is_empty(), mode)
		assert_eq(candidate, candidate_before, mode)
		assert_eq(supplied, supplied_before, mode)
		assert_eq(f.port._scene_entry, retained_before, mode)
		assert_false(f.real.calls.has("commit"), "refusal cannot write: " + mode)
