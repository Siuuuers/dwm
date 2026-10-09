extends "res://tests/support/SceneRestartFixture.gd"
## Exact stop seam only: all journal admission, persistence and participants are real.
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")

class InterruptingJournal:
	extends "res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd"
	var stop_point := ""
	var after_durable_stop: Callable
	func advance(request: Dictionary) -> Dictionary:
		var result: Dictionary = super.advance(request)
		if not result.get("ok", false) or stop_point.is_empty(): return result
		var operation: Dictionary = result.value
		if operation.get("kind") != "scene_restore": return result
		var prefix := stop_point == "prefix" and operation.stage == STAGE_APPLYING \
			and operation.next_participant_index == 7 and operation.participant_receipts.get("route") is Dictionary
		var completed := stop_point == "completed" and operation.stage == STAGE_COMPLETED \
			and operation.activation_state == "pending"
		if prefix or completed:
			stop_point = ""
			after_durable_stop.call(operation.duplicate(true))
			return {"ok": false, "code": &"test_interruption_did_not_terminate"}
		return result

var interrupt_context: Dictionary = {}
var stop_failure: Dictionary = {}

func arm_interruption(point: String, context: Dictionary) -> Dictionary:
	if point not in ["prefix", "completed"]: return {"ok": false, "code": &"test_stop_point_invalid"}
	interrupt_context = context.duplicate(true)
	interrupt_context["point"] = point
	var journal := InterruptingJournal.new()
	var checked: Dictionary = journal.configure(storage, manager)
	if checked.ok: checked = journal.configure_scene_new_run_validation(ENTRY_MANIFEST.scene_registration().value, issuer)
	if not checked.ok: return checked
	journal.stop_point = point
	journal.after_durable_stop = _stop_after_durable_journal_write
	manager._continuation_journal = journal
	return {"ok": true}

func witness_path() -> String:
	return storage.describe_root().path_join("interruption-witness.json")

func _stop_after_durable_journal_write(operation: Dictionary) -> void:
	# A separately configured real journal must read the disk, not the writer cache.
	var reopened: Dictionary = reopen_journal()
	if not reopened.ok:
		stop_failure = reopened
		return
	var reread: Dictionary = reopened.value.get_operation(operation.transaction_id)
	if not reread.ok or not JSON_WRITER._deep_same(reread.get("value"), operation):
		stop_failure = {"ok": false, "code": &"test_durable_stop_readback_failed", "result": reread}
		return
	var identity: Dictionary = storage.inspect_revision("desktop-issuer-root.json")
	if not identity.ok:
		stop_failure = identity
		return
	if not identity.value.get("exists", false) or not _valid_sha256(identity.value.get("revision")):
		stop_failure = {"ok": false, "code": &"test_identity_file_missing"}
		return
	var proof := interrupt_context.duplicate(true)
	proof.merge({"phase": "stop", "process_id": OS.get_process_id(), "storage_root": storage.describe_root(),
		"operation_id": operation.transaction_id, "operation": operation, "ready_count": ready_count,
		"issuer_root_sha256": identity.value.revision,
		"route_confirmations": route_confirmations.duplicate(), "narrative_confirmations": narrative_confirmations.duplicate(),
		"live_route_generation": router._route_generation}, true)
	var written := write_proof(proof, "stop")
	if not written.ok:
		stop_failure = written
		return
	var encoded: Dictionary = JSON_WRITER.stringify(proof)
	var witness := FileAccess.open(witness_path(), FileAccess.WRITE)
	if witness == null:
		stop_failure = {"ok": false, "code": &"test_witness_open_failed"}
		return
	witness.store_string(str(encoded.value) + "\n")
	witness.flush()
	witness.close()
	print("SCENE_INTERRUPT_STOP=" + str(encoded.value))
	# SceneTree.quit is deferred and would let the synchronous transaction proceed.
	# Kill this actual child immediately after flushed physical proof, before returning.
	var killed: Error = OS.kill(OS.get_process_id())
	stop_failure = {"ok": false, "code": &"test_self_kill_returned", "error": killed}

func write_proof(proof: Dictionary, phase: String) -> Dictionary:
	var encoded: Dictionary = JSON_WRITER.stringify(proof)
	if not encoded.ok: return encoded
	var directory := ProjectSettings.globalize_path("res://.godot/ci")
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return {"ok": false, "code": &"test_proof_directory_failed"}
	var file := FileAccess.open(directory.path_join("scene-interrupt-" + phase + ".json"), FileAccess.WRITE)
	if file == null: return {"ok": false, "code": &"test_proof_open_failed"}
	file.store_string(str(encoded.value) + "\n")
	file.flush()
	file.close()
	return {"ok": true}

static func _valid_sha256(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true
