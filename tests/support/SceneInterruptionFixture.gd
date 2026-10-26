extends "res://tests/support/SceneRestartFixture.gd"
## Stop within direct Load's synchronous participant pass, before readiness.
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class InterruptingNarrative:
	extends "res://scripts/application/restore/NarrativeRestoreParticipant.gd"
	var stop_point := ""
	var after_memory_stop: Callable
	func apply_silent(plan: Dictionary) -> Dictionary:
		if stop_point == "prefix":
			stop_point = ""
			after_memory_stop.call(str(plan.scene_restore_operation_id))
			return {"ok": false, "code": &"test_interruption_did_not_terminate"}
		var result: Dictionary = super.apply_silent(plan)
		if result.get("ok", false) and stop_point == "completed":
			stop_point = ""
			after_memory_stop.call(str(plan.scene_restore_operation_id))
			return {"ok": false, "code": &"test_interruption_did_not_terminate"}
		return result

func setup_restart(scene_tree: SceneTree) -> Dictionary:
	var checked: Dictionary = await super.setup_restart(scene_tree)
	if not checked.ok: return checked
	participants.narrative = InterruptingNarrative.new(bridge)
	participants.narrative.scene_activation_confirmed.connect(func(id: String) -> void: narrative_confirmations.append(id))
	return manager.configure_scene_restore_participants(participants)

var interrupt_context: Dictionary = {}
var stop_failure: Dictionary = {}

func arm_interruption(point: String, context: Dictionary) -> Dictionary:
	if point not in ["prefix", "completed"]: return {"ok": false, "code": &"test_stop_point_invalid"}
	interrupt_context = context.duplicate(true)
	interrupt_context["point"] = point
	participants.narrative.stop_point = point
	participants.narrative.after_memory_stop = _stop_after_memory_apply
	return {"ok": true}

func witness_path() -> String:
	return storage.describe_root().path_join("interruption-witness.json")

func persistent_files() -> Dictionary:
	var hashes := {}
	var directory: String = storage.describe_root()
	for name: String in DirAccess.get_files_at(directory):
		if name == "interruption-witness.json": continue
		hashes[name] = FileAccess.get_sha256(directory.path_join(name))
	return hashes

func _stop_after_memory_apply(operation_id: String) -> void:
	var reread: Dictionary = manager._continuation_journal.get_operation(operation_id)
	if reread.ok:
		stop_failure = {"ok": false, "code": &"test_load_wrote_operation"}
		return
	if persistent_files() != interrupt_context.persistent_files:
		stop_failure = {"ok": false, "code": &"test_load_changed_persistent_files"}
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
		"operation_id": operation_id, "operation_absent": true, "ready_count": ready_count,
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
