extends Node

## SaveManager — isolated, atomic save-document and checkpoint persistence
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).
## Owns slot/quick/autosave I/O through one injected StorageAdapter and the
## in-memory CheckpointJournal. Never interprets gameplay rules.

signal save_completed(result: Dictionary)
signal load_completed(result: Dictionary)
signal save_failed(result: Dictionary)
signal load_failed(result: Dictionary)
signal slot_metadata_changed()
signal run_restored(checkpoint_id: String, route_id: String)
signal save_capability_changed(capability: Dictionary)

const MIN_SLOT := 1
const MAX_SLOT := 7

const CHECKPOINT_JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _GATE_CONTRACT_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const _LOCK_OWNERS: Array[StringName] = [&"minesweeper_board", &"scene_transition", &"restore"]
const _CHECKPOINT_INPUT_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint",
	"route_id", "snapshot_input",
]

var _storage: RefCounted = null
var _journal: RefCounted = CHECKPOINT_JOURNAL.new()
var _mutation_gate: Object = null
var _lock_owner: StringName = &""
var _pending_deferred_save := false

func initialize(storage: StorageAdapter = null) -> Dictionary:
	if storage == null:
		return _fail(&"invalid_storage", "SaveManager requires an injected StorageAdapter")
	_storage = storage
	return {"ok": true, "code": &"ok", "value": {"root": storage.describe_root()}}

func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _fail(&"invalid_mutation_gate", "gate contract incomplete")
	for method in _GATE_CONTRACT_METHODS:
		if not gate.has_method(method):
			return _fail(&"invalid_mutation_gate", "missing method: " + method)
	if _mutation_gate != null:
		if gate == _mutation_gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return _fail(&"mutation_gate_already_configured", "")
	_mutation_gate = gate
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": false},
		"receipt": {}}

func record_stable_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName) -> Dictionary:
	if _storage == null:
		return _fail(&"not_initialized", "")
	var input_error := _validate_checkpoint_inputs(checkpoint_inputs)
	if input_error != "":
		return _fail(&"invalid_checkpoint_inputs", input_error)
	var run_id := str((checkpoint_inputs["snapshot_input"]["lifecycle"] as Dictionary).get("run_id", ""))
	var peeked: Dictionary = _journal.peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		checkpoint_inputs["snapshot_input"], checkpoint_inputs["dialogic_checkpoint"],
		str(checkpoint_inputs["route_id"]), checkpoint_inputs["active_app_id"],
		checkpoint_inputs["audio_context"], int(checkpoint_inputs["content_version"]),
		int(peeked["value"]["checkpoint_sequence"]))
	if not built.get("ok", false):
		return built
	var prepared: Dictionary = _journal.prepare_record(built["value"]["snapshot"], checkpoint_kind)
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = _journal.commit_prepared(prepared["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	if _pending_deferred_save and _lock_owner == &"":
		_pending_deferred_save = false
		autosave_latest()
	return committed

func get_latest_stable_checkpoint() -> Dictionary:
	return _journal.get_current_bundle()

func start_new_run(_run_id: String, _initial_context: Dictionary) -> Dictionary:
	return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED",
		"start_new_run requires the Task 7 production transaction participants")

func save_latest_to_slot(slot_id: int) -> Dictionary:
	return _write_latest(_resolve_locator(&"slot", slot_id), "manual")

func quick_save_latest() -> Dictionary:
	return _write_latest(_resolve_locator(&"quick", -1), "quick")

func autosave_latest() -> Dictionary:
	return _write_latest(_resolve_locator(&"autosave", -1), "automatic")

func save_for_logout() -> Dictionary:
	if not _journal.get_current_bundle().get("ok", false):
		return {"ok": true, "code": &"ok", "value": {"written": false, "save_reason": "logout"}}
	return _write_latest(_resolve_locator(&"autosave", -1), "logout")

func prepare_restore_slot(slot_id: int) -> Dictionary:
	return _prepare_restore(_resolve_locator(&"slot", slot_id))

func prepare_restore_quick() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"quick", -1))

func prepare_restore_autosave() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"autosave", -1))

func commit_prepared_restore(_prepared: Dictionary) -> Dictionary:
	return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED",
		"commit_prepared_restore requires the Task 7 restore participants")

func delete_slot(slot_id: int) -> Dictionary:
	return _delete(_resolve_locator(&"slot", slot_id))

func delete_quick_save() -> Dictionary:
	return _delete(_resolve_locator(&"quick", -1))

func delete_autosave() -> Dictionary:
	return _delete(_resolve_locator(&"autosave", -1))

func save_exists(kind: StringName, slot_id: int = -1) -> bool:
	var locator := _resolve_locator(kind, slot_id)
	if locator.is_empty() or _storage == null:
		return false
	return _storage.exists(str(locator["relative_path"]))

func get_save_metadata(kind: StringName, slot_id: int = -1) -> Dictionary:
	var locator := _resolve_locator(kind, slot_id)
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "%s/%d" % [kind, slot_id])
	if _storage == null:
		return _fail(&"not_initialized", "")
	var relative_path := str(locator["relative_path"])
	if not _storage.exists(relative_path):
		return {"ok": true, "code": &"ok", "value": {
			"exists": false, "kind": str(locator["kind"]), "slot_id": locator["slot_id"],
			"save_reason": null, "run_id": null, "day": null, "state": null, "checkpoint_id": null,
		}}
	var read: Dictionary = _storage.read_text(relative_path)
	if not read.get("ok", false):
		return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var document: Dictionary = validated["value"]["candidate"]
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	return {"ok": true, "code": &"ok", "value": {
		"exists": true,
		"kind": str(document["kind"]),
		"slot_id": document["slot_id"],
		"save_reason": str(document["save_reason"]),
		"run_id": str(snapshot["run_id"]),
		"day": int(snapshot["lifecycle"]["day"]),
		"state": str(snapshot["lifecycle"]["state"]),
		"checkpoint_id": str(snapshot["checkpoint_id"]),
	}}

func get_all_save_metadata() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for slot_id: int in range(MIN_SLOT, MAX_SLOT + 1):
		records.append(get_save_metadata(&"slot", slot_id))
	records.append(get_save_metadata(&"quick", -1))
	records.append(get_save_metadata(&"autosave", -1))
	return records

func acquire_save_lock(owner_id: StringName) -> Dictionary:
	if owner_id not in _LOCK_OWNERS:
		return _fail(&"invalid_lock_owner", String(owner_id))
	if _lock_owner != &"" and _lock_owner != owner_id:
		return _fail(&"save_lock_held", String(_lock_owner))
	var was_locked := _lock_owner == owner_id
	_lock_owner = owner_id
	if not was_locked:
		save_capability_changed.emit(get_save_capability())
	return {"ok": true, "code": &"ok", "value": {"owner_id": owner_id, "already_locked": was_locked}}

func release_save_lock(owner_id: StringName) -> Dictionary:
	if _lock_owner == &"" or owner_id != _lock_owner:
		return _fail(&"save_lock_mismatch", String(owner_id))
	_lock_owner = &""
	save_capability_changed.emit(get_save_capability())
	if _pending_deferred_save:
		_pending_deferred_save = false
		autosave_latest()
	return {"ok": true, "code": &"ok", "value": {"owner_id": owner_id}}

func is_save_locked() -> bool:
	return _lock_owner != &""

func get_save_capability() -> Dictionary:
	match _lock_owner:
		&"minesweeper_board":
			return {"enabled": false, "silent": true, "deferred": false}
		&"scene_transition":
			return {"enabled": false, "silent": true, "deferred": true}
		&"restore":
			return {"enabled": false, "silent": true, "deferred": false}
	return {"enabled": true, "silent": false, "deferred": false}

func configure_restore_participants(_participants: Dictionary) -> Dictionary:
	return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED",
		"configure_restore_participants arrives with Task 7")

# ---- Deprecated wrappers (one issue only; delegate to the new facade) ----

func save_slot(slot_id: int) -> Dictionary:
	return save_latest_to_slot(slot_id)

func load_slot(slot_id: int) -> Dictionary:
	var prepared := prepare_restore_slot(slot_id)
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func quick_save() -> Dictionary:
	return quick_save_latest()

func quick_load() -> Dictionary:
	var prepared := prepare_restore_quick()
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func autosave() -> Dictionary:
	return autosave_latest()

func load_autosave() -> Dictionary:
	var prepared := prepare_restore_autosave()
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func has_slot(slot_id: int) -> bool:
	return save_exists(&"slot", slot_id)

func get_slot_metadata(slot_id: int) -> Dictionary:
	return get_save_metadata(&"slot", slot_id)

func get_all_slot_metadata() -> Array:
	return get_all_save_metadata()

# ---- Internals ----

func _resolve_locator(kind: StringName, public_slot_id: int) -> Dictionary:
	match kind:
		&"slot":
			if public_slot_id < MIN_SLOT or public_slot_id > MAX_SLOT:
				return {}
			return {"kind": "slot", "slot_id": public_slot_id,
				"relative_path": "slot_%d.json" % public_slot_id}
		&"quick":
			if public_slot_id != -1:
				return {}
			return {"kind": "quick", "slot_id": null, "relative_path": "quicksave.json"}
		&"autosave":
			if public_slot_id != -1:
				return {}
			return {"kind": "autosave", "slot_id": null, "relative_path": "autosave.json"}
	return {}

func _write_latest(locator: Dictionary, save_reason: String) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	match _lock_owner:
		&"minesweeper_board", &"restore":
			return {"ok": false, "code": &"save_locked", "message": "",
				"details": {"silent": true, "deferred": false}}
		&"scene_transition":
			_pending_deferred_save = true
			return {"ok": false, "code": &"save_locked", "message": "",
				"details": {"silent": true, "deferred": true}}
	var bundle: Dictionary = _journal.get_current_bundle()
	if not bundle.get("ok", false):
		return _fail(&"no_stable_checkpoint", "")
	var built: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
		StringName(str(locator["kind"])), locator["slot_id"], StringName(save_reason),
		bundle["value"]["bundle"], _journal.get_bundles_for_disk())
	if not built.get("ok", false):
		save_failed.emit(built)
		return built
	var canonical: Dictionary = CANONICAL_JSON.stringify(built["value"])
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "")
	var relative_path := str(locator["relative_path"])
	var written: Dictionary = _storage.write_atomic(
		relative_path, str(canonical["value"]) + "\n", _document_text_validator)
	if not written.get("ok", false):
		save_failed.emit(written)
		return written
	var re_read: Dictionary = _storage.read_text(relative_path)
	if not re_read.get("ok", false):
		return re_read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(re_read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"reread_mismatch", relative_path)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return _fail(&"reread_mismatch", relative_path)
	var document: Dictionary = validated["value"]["candidate"]
	if str(document["kind"]) != str(locator["kind"]) or str(document["save_reason"]) != save_reason:
		return _fail(&"reread_mismatch", "locator or reason drift")
	var result := {"ok": true, "code": &"ok", "value": {
		"kind": str(locator["kind"]),
		"slot_id": locator["slot_id"],
		"save_reason": save_reason,
		"checkpoint_id": str(document["current_snapshot"]["snapshot"]["checkpoint_id"]),
		"written": true,
	}}
	save_completed.emit(result)
	slot_metadata_changed.emit()
	return result

func _prepare_restore(locator: Dictionary) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	var relative_path := str(locator["relative_path"])
	if not _storage.exists(relative_path):
		return _fail(&"save_absent", relative_path)
	var read: Dictionary = _storage.read_text(relative_path)
	if not read.get("ok", false):
		return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	var document: Dictionary = validated["value"]["candidate"]
	if str(document["kind"]) != str(locator["kind"]) or document["slot_id"] != locator["slot_id"]:
		return _fail(&"corrupt_save_document", "document discriminators do not match the locator")
	return {"ok": true, "code": &"ok", "value": {"prepared": {
		"locator": locator.duplicate(true),
		"document": document,
	}}}

func _delete(locator: Dictionary) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	var relative_path := str(locator["relative_path"])
	var removed: Dictionary = _storage.remove(relative_path)
	if not removed.get("ok", false):
		return removed
	var reconciled: Dictionary = _storage.reconcile(relative_path, _document_text_validator)
	if not reconciled.get("ok", false):
		return reconciled
	if _storage.exists(relative_path):
		return _fail(&"delete_incomplete", relative_path)
	slot_metadata_changed.emit()
	return {"ok": true, "code": &"ok", "value": {"deleted": true, "relative_path": relative_path}}

func _document_text_validator(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

func _validate_checkpoint_inputs(checkpoint_inputs: Dictionary) -> String:
	var keys: Array = checkpoint_inputs.keys()
	keys.sort()
	var expected := _CHECKPOINT_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected checkpoint input keys: " + str(keys)
	if typeof(checkpoint_inputs["snapshot_input"]) != TYPE_DICTIONARY \
			or typeof(checkpoint_inputs["snapshot_input"].get("lifecycle")) != TYPE_DICTIONARY:
		return "snapshot_input.lifecycle is required"
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
