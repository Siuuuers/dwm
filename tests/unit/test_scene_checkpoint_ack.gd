extends "res://addons/gut/test.gd"

# Injected real-port/Bridge seams: these prove adapter authentication and transaction
# ordering, NOT disk persistence, native adoption, or acceptance by the held Run/Save format.
const PORT := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class CheckpointSeam extends "res://tests/support/FakeNarrativeCheckpointContext.gd":
	var current := {"checkpoint_id": "run:1", "checkpoint_sequence": 1, "narrative_checkpoint": {"source": true}}
	var bad_ack := false
	var bad_target := false
	var readback_mismatch := false
	var before_commit := Callable()
	var after_prepare := Callable()
	var before_capture := Callable()
	var prepared_object: Dictionary = {}
	var committed_same_object := false

	func capture() -> Dictionary:
		calls.append("capture")
		if before_capture.is_valid(): before_capture.call()
		return {"ok": true, "value": {"backup": {"current": {"snapshot": current.duplicate(true)}}}}

	func prepare(inputs: Dictionary, _kind: StringName, _disk: Dictionary) -> Dictionary:
		calls.append("prepare")
		if not prepare_ok: return {"ok": false, "code": &"prepare_failed"}
		var snapshot := {"checkpoint_id": "run:2", "checkpoint_sequence": 2,
			"narrative_checkpoint": inputs.dialogic_checkpoint.duplicate(true), "payload": inputs.snapshot_input.duplicate(true)}
		if bad_target: snapshot.narrative_checkpoint["altered"] = true
		prepared_object = {"checkpoint_id": "run:2", "journal_candidate": {"current": {"snapshot": snapshot}},
			"autosave_document": {"current_snapshot": {"snapshot": snapshot.duplicate(true)}}, "storage_backup": {"original": true}}
		if after_prepare.is_valid(): after_prepare.call()
		return {"ok": true, "value": {"candidate": prepared_object, "checkpoint_id": "run:2"}}

	func commit(candidate: Dictionary) -> Dictionary:
		calls.append("commit")
		committed_same_object = is_same(candidate, prepared_object)
		if before_commit.is_valid(): before_commit.call()
		if not commit_ok: return {"ok": false, "code": &"write_failed"}
		current = candidate.journal_candidate.current.snapshot.duplicate(true)
		if readback_mismatch: current["mismatch"] = true
		return {"ok": true, "value": {"checkpoint_id": "wrong" if bad_ack else candidate.checkpoint_id}}

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
	var binding := {"operation_id": "operation:1", "source_checkpoint": {"checkpoint_id": "run:1", "checkpoint_sequence": 1,
		"snapshot_sha256": _hash(real.current)}, "source_occurrence_id": "occurrence:source", "trigger_command_id": "event:1",
		"target_id": "target:1", "target_occurrence_id": "occurrence:target", "admission_receipt_id": "admission:1",
		"registration_sha256": "a".repeat(64)}
	var checkpoint := {"stage": "scene", "manifest_fingerprint": binding.registration_sha256,
		"reading_session": {"schema_version": 5, "boundary": "line"},
		"frozen_context": {"playback_id": binding.target_occurrence_id,
			"presentation": {"fields": {"admission_receipt_id": binding.admission_receipt_id}}}}
	authority.expected_binding = binding.duplicate(true)
	authority.expected_checkpoint = checkpoint.duplicate(true)
	if retain: assert_true(port.retain_scene_entry(authority, "cap:1", binding, checkpoint).ok)
	return {"port": port, "real": real, "authority": authority, "binding": binding, "checkpoint": checkpoint}

func test_confirmed_commit_ack_binds_actual_snapshot_and_consumes_once() -> void:
	var f := _fixture()
	var saved: Dictionary = f.port.commit_scene_event({"real_payload": "payload"}, f.checkpoint)
	assert_true(saved.ok, str(saved))
	assert_true(f.real.committed_same_object)
	var result: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_true(result.ok, str(result))
	assert_eq(result.value.keys().size(), 6)
	assert_eq(result.value.capability_id, "cap:1")
	assert_eq(result.value.operation_id, f.binding.operation_id)
	assert_eq(result.value.source_checkpoint, f.binding.source_checkpoint)
	assert_eq(result.value.binding_sha256, _hash(f.binding))
	assert_eq(result.value.narrative_checkpoint_sha256, _hash(f.checkpoint))
	assert_eq(result.value.target_checkpoint.snapshot_sha256, _hash(f.real.current))
	assert_eq(result.value.target_checkpoint, saved.value.checkpoint_reference)
	assert_false(f.port.consume_scene_entry_ack("cap:1").ok)
	assert_false(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, f.checkpoint).ok)
	assert_eq(f.authority.phases, ["retain", "commit", "commit", "consume"])

func test_foreign_authority_and_reconfiguration_refuse() -> void:
	var f := _fixture(false)
	var other := BridgeSeam.new()
	assert_false(f.port.configure_scene_entry_authority(other, other.validate).ok)
	assert_false(f.port.configure_scene_entry_authority(f.authority, other.validate).ok)
	assert_false(f.port.retain_scene_entry(other, "cap:1", f.binding, f.checkpoint).ok)
	assert_false(PORT.new().consume_scene_entry_ack("cap:1").ok)
	assert_true(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, f.checkpoint).ok)

func test_uncommitted_candidate_cannot_be_confirmed_with_hash_knowledge() -> void:
	var f := _fixture()
	var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_false(ack.ok)
	assert_false(ack.committed)
	assert_false(f.port.consume_scene_entry_ack(_hash(f.checkpoint)).ok)
	assert_false(f.port.consume_scene_entry_ack("foreign").ok)
	assert_false(f.real.calls.has("commit"))

func test_bridge_custody_required_again_at_commit_and_consumption() -> void:
	var f := _fixture()
	f.authority.allow = false
	assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
	assert_false(f.real.calls.has("commit"))
	f.authority.allow = true
	assert_true(f.port.commit_scene_event({}, f.checkpoint).ok)
	f.authority.allow = false
	assert_false(f.port.consume_scene_entry_ack("cap:1").ok)
	f.authority.allow = true
	assert_true(f.port.consume_scene_entry_ack("cap:1").ok)

func test_retained_copies_refuse_altered_target_and_source() -> void:
	var f := _fixture()
	var altered: Dictionary = f.checkpoint.duplicate(true)
	altered["altered"] = true
	assert_false(f.port.commit_scene_event({}, altered).ok)
	f.real.current["changed_source"] = true
	assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
	assert_false(f.real.calls.has("prepare"))
	assert_false(f.real.calls.has("commit"))

func test_prepared_real_candidate_must_match_before_disk_commit() -> void:
	var f := _fixture()
	f.real.bad_target = true
	assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
	assert_false(f.real.calls.has("commit"))
	assert_false(f.port.consume_scene_entry_ack("cap:1").committed)

func test_prepare_refusal_preserves_same_capability_for_retry() -> void:
	var f := _fixture()
	f.real.prepare_ok = false
	assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
	assert_false(f.port.consume_scene_entry_ack("cap:1").committed)
	f.real.prepare_ok = true
	assert_true(f.port.commit_scene_event({}, f.checkpoint).ok)
	assert_true(f.port.consume_scene_entry_ack("cap:1").ok)

func test_confirmed_rollback_allows_retry_but_failed_rollback_is_uncertain() -> void:
	var f := _fixture()
	f.real.commit_ok = false
	assert_true(f.port.commit_scene_event({}, f.checkpoint).rolled_back)
	assert_false(f.port.consume_scene_entry_ack("cap:1").committed)
	f.real.rollback_ok = false
	assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
	var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_false(ack.ok)
	assert_true(ack.committed)
	f.real.commit_ok = true
	assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)

func test_bad_success_and_changed_committed_snapshot_are_fatal_without_ack() -> void:
	for mode: String in ["bad_ack", "readback_mismatch"]:
		var f := _fixture()
		f.real.set(mode, true)
		assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
		var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
		assert_false(ack.ok)
		assert_true(ack.committed)
		assert_false(f.real.calls.has("rollback"), "confirmed target must not be rolled back")

func test_later_checkpoint_replacement_cannot_consume_stale_ack() -> void:
	var f := _fixture()
	assert_true(f.port.commit_scene_event({}, f.checkpoint).ok)
	f.real.current["later_target"] = true
	var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_false(ack.ok)
	assert_true(ack.committed)

func test_reentrant_callbacks_cannot_publish_or_consume() -> void:
	var f := _fixture(false)
	var results: Array = []
	f.authority.callback = func() -> void:
		results.append(f.port.consume_scene_entry_ack("cap:1"))
		results.append(f.port.commit_scene_event({}, f.checkpoint))
	assert_true(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, f.checkpoint).ok)
	f.real.before_commit = func() -> void:
		results.append(f.port.consume_scene_entry_ack("cap:1"))
		results.append(f.port.commit_scene_event({}, f.checkpoint))
	assert_true(f.port.commit_scene_event({}, f.checkpoint).ok)
	assert_true(f.port.consume_scene_entry_ack("cap:1").ok)
	assert_gt(results.size(), 0)
	for result: Dictionary in results: assert_false(result.ok)
	# Remove test-only closure cycles.
	f.authority.callback = Callable()
	f.real.before_commit = Callable()

func test_invalid_binding_and_target_fields_refuse_before_retention() -> void:
	for field: String in ["registration_sha256", "source_checkpoint", "target_occurrence_id", "admission_receipt_id"]:
		var f := _fixture(false)
		var changed: Dictionary = f.binding.duplicate(true)
		if field == "source_checkpoint": changed[field] = {"checkpoint_id": "run:1"}
		else: changed[field] = "wrong"
		assert_false(f.port.retain_scene_entry(f.authority, "cap:1", changed, f.checkpoint).ok, field)
		assert_false(f.real.calls.has("commit"))

func test_source_commit_reference_does_not_create_entry_ack() -> void:
	var f := _fixture(false)
	var result: Dictionary = f.port.commit_scene_event({}, f.checkpoint)
	assert_true(result.ok)
	assert_eq(result.value.checkpoint_reference.snapshot_sha256, _hash(f.real.current))
	assert_false(f.port.consume_scene_entry_ack("cap:1").ok)

func test_empty_journal_source_refuses_without_runtime_error() -> void:
	var f := _fixture()
	f.real.current = {}
	assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
	assert_false(f.real.calls.has("prepare"))

func test_malformed_nested_checkpoint_refuses_before_callback_or_write() -> void:
	for frame: Variant in [null, 7, {"playback_id": "occurrence:target", "presentation": null}, {"playback_id": "occurrence:target", "presentation": {"fields": "wrong"}}]:
		var f := _fixture(false)
		var checkpoint: Dictionary = f.checkpoint.duplicate(true)
		checkpoint.frozen_context = frame
		assert_false(f.port.retain_scene_entry(f.authority, "cap:1", f.binding, checkpoint).ok)
		assert_true(f.authority.phases.is_empty())
		assert_true(f.real.calls.is_empty())

func test_prepare_callback_cannot_invalidate_custody_or_source_before_write() -> void:
	for change_source: bool in [false, true]:
		var f := _fixture()
		f.real.after_prepare = func() -> void:
			if change_source: f.real.current["changed"] = true
			else: f.authority.allow = false
		assert_false(f.port.commit_scene_event({}, f.checkpoint).ok)
		assert_false(f.real.calls.has("commit"))
		f.real.after_prepare = Callable()

func test_real_save8_prepare_refuses_unintegrated_scene_identity_without_ack() -> void:
	# Real SaveManagerCheckpointPort + Run/Save validators and journal, FakeFileOps.
	# The accepted legacy control is durable through real write/readback APIs in that
	# injected filesystem; this is NOT a physical filesystem/process-restart claim.
	var durable := preload("res://tests/support/DurableSceneEventFixture.gd").new()
	var initialized: Dictionary = durable.initialize()
	assert_true(initialized.ok, str(initialized))
	if not initialized.ok:
		durable.dispose()
		return
	var reading := preload("res://tests/support/ReadingNextFixture.gd")
	var input: Dictionary = reading.snapshot_input(durable.snapshot)
	var baseline: Dictionary = durable.adapter.commit_scene_event(input, durable.snapshot.narrative_checkpoint)
	assert_true(baseline.ok, str(baseline))
	if not baseline.ok:
		durable.dispose()
		return
	var source: Dictionary = durable.real.capture().value.backup.current.snapshot
	var before_disk: Dictionary = durable.storage.read_text("autosave.json")
	assert_true(before_disk.ok)
	var baseline_commits: int = durable.real.commits
	var f := _fixture(false)
	var adapter := PORT.new()
	assert_true(adapter.configure(durable.real, durable.context.provider_callables()).ok)
	assert_true(adapter.configure_scene_entry_authority(f.authority, f.authority.validate).ok)
	f.binding.source_checkpoint = {"checkpoint_id": source.checkpoint_id, "checkpoint_sequence": source.checkpoint_sequence,
		"snapshot_sha256": _hash(source)}
	f.authority.expected_binding = f.binding.duplicate(true)
	assert_true(adapter.retain_scene_entry(f.authority, "cap:1", f.binding, f.checkpoint).ok)
	# The scene identity is the released five-member family; do not fabricate retired
	# day/calendar members or bypass current RunSnapshotSchema to make it saveable.
	var scene_identity := {}
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]:
		scene_identity[key] = input.lifecycle[key]
	input.lifecycle = scene_identity
	var refused: Dictionary = adapter.commit_scene_event(input, f.checkpoint)
	assert_false(refused.ok)
	assert_eq(durable.real.commits, baseline_commits, "real prepare refuses before any commit")
	assert_eq(_hash(durable.real.capture().value.backup.current.snapshot), _hash(source))
	assert_eq(durable.storage.read_text("autosave.json").value, before_disk.value)
	var ack: Dictionary = adapter.consume_scene_entry_ack("cap:1")
	assert_false(ack.ok)
	assert_false(ack.committed)
	durable.dispose()

func test_authority_callback_cannot_change_public_checkpoint_or_snapshot_commit() -> void:
	var f := _fixture()
	var original: Dictionary = f.checkpoint.duplicate(true)
	var input := {"nested": {"original": true}}
	f.authority.callback = func() -> void:
		f.checkpoint["altered"] = true
		input.nested["altered"] = true
	var saved: Dictionary = f.port.commit_scene_event(input, f.checkpoint)
	assert_true(saved.ok, str(saved))
	assert_true(f.checkpoint.has("altered"), "mutation seam ran")
	assert_true(input.nested.has("altered"))
	assert_eq(f.real.current.narrative_checkpoint, original)
	assert_eq(f.real.current.payload, {"nested": {"original": true}})
	assert_true(f.real.committed_same_object)
	var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
	assert_true(ack.ok, str(ack))
	assert_eq(ack.value.narrative_checkpoint_sha256, _hash(f.real.current.narrative_checkpoint))
	assert_eq(ack.value.narrative_checkpoint_sha256, _hash(original))
	assert_eq(ack.value.target_checkpoint.snapshot_sha256, _hash(f.real.current))
	f.authority.callback = Callable()

func test_final_external_callbacks_cannot_mutate_prepared_candidate_before_write() -> void:
	for callback_owner: String in ["authority", "source"]:
		for mutation: String in ["narrative", "payload", "checkpoint_id"]:
			var f := _fixture()
			var original_source: Dictionary = f.real.current.duplicate(true)
			var mutate := func() -> void:
				if f.real.prepared_object.is_empty(): return
				var candidate: Dictionary = f.real.prepared_object
				if mutation == "checkpoint_id":
					candidate.checkpoint_id = "changed:2"
				else:
					var snapshot: Dictionary = candidate.journal_candidate.current.snapshot
					if mutation == "narrative": snapshot.narrative_checkpoint["altered"] = true
					else: snapshot.payload["altered"] = true
					candidate.autosave_document.current_snapshot.snapshot = snapshot.duplicate(true)
			if callback_owner == "authority": f.authority.callback = mutate
			else: f.real.before_capture = mutate
			var refused: Dictionary = f.port.commit_scene_event({}, f.checkpoint)
			assert_false(refused.ok, callback_owner + ":" + mutation)
			assert_eq(str(refused.code), "scene_entry_candidate_invalid")
			assert_false(f.real.calls.has("commit"), "refuse before write")
			assert_false(f.real.calls.has("rollback"), "no write to roll back")
			assert_eq(f.real.current, original_source)
			var ack: Dictionary = f.port.consume_scene_entry_ack("cap:1")
			assert_false(ack.ok)
			assert_false(ack.committed)
			f.authority.callback = Callable()
			f.real.before_capture = Callable()
			assert_true(f.port.commit_scene_event({}, f.checkpoint).ok, "no-write refusal retains retry custody")
			assert_true(f.real.committed_same_object)
			assert_true(f.port.consume_scene_entry_ack("cap:1").ok)
