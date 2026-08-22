class_name SaveManagerCheckpointPort
extends RefCounted

## Production checkpoint port bridging DayResolutionCoordinator to
## SaveManager's CheckpointJournal and isolated storage
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

## Plan 02 Task 6 (dwm-p2r.32): the narrow, self-contained durable record backing
## `DesktopCausalSequencePort`'s admission checkpoint -- one small atomic JSON file at a fixed
## relative path through the same injected StorageAdapter the autosave document already uses,
## deliberately NOT routed through CheckpointJournal/SaveDocumentSchema: those own the full
## RunSnapshot lifecycle, while this owns only the narrow consequence-admission compare-and-swap
## point (brief line 249's "final compare-and-swap/admission point shared by every source kind").
const CONSEQUENCE_CHECKPOINT_RELATIVE_PATH := "desktop-consequence-checkpoint.json"
const CONSEQUENCE_CHECKPOINT_DOCUMENT_KEYS: Array[String] = ["checkpoint_receipt", "header", "schema_version", "stage_candidate"]

const GATE_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const CHECKPOINT_INPUT_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint",
	"route_id", "snapshot_input",
]
const DISK_WRITES := [
	{"kind": &"none", "reason": &"stage"},
	{"kind": &"autosave", "reason": &"day_start"},
	{"kind": &"autosave", "reason": &"ending"},
	# The Minesweeper pre-board autosave must be durable BEFORE a round is consumed or the save
	# lock acquired (dwm-p2r.9 Plan 06 Task 2). Both layers beneath this port already carry the
	# vocabulary -- CheckpointJournal.SEMANTIC_KINDS lists "pre_board" and
	# SaveDocumentSchema.AUTOSAVE_REASONS lists "pre_board" -- so only this enumeration was
	# missing the pairing. Reusing "day_start" instead would mislabel the durable document.
	{"kind": &"autosave", "reason": &"pre_board"},
]
const AUTOSAVE_RELATIVE_PATH := "autosave.json"

var _gate: Object = null
var _save_manager: Object = null
var _desktop_context_provider: Object = null


func configure_desktop_context_provider(provider: Object) -> Dictionary:
	# One Bootstrap-owned DesktopAppHostState supplies the persisted active_app_id. A second
	# direct configuration with the same object is idempotent; a different object is rejected.
	if provider == null or not provider.has_method("capture_persistent_state"):
		return _fail(&"invalid_desktop_context_provider", "provider must expose capture_persistent_state")
	if _desktop_context_provider != null:
		if provider == _desktop_context_provider:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"desktop_provider_already_configured", "a desktop context provider is already configured")
	_desktop_context_provider = provider
	return {"ok": true, "code": &"ok",
		"value": {"provider_instance_id": _desktop_context_provider.get_instance_id()}, "receipt": {}}

func _init(save_manager: Object = null) -> void:
	_save_manager = save_manager

func configure_fatal_latch(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed") or not _has_all_methods(gate):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	if _gate != null:
		if gate == _gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return {"ok": false, "code": &"mutation_gate_already_configured", "message": ""}
	_gate = gate
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": false},
		"receipt": {}}

func preview_checkpoint_id(run_id: String) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if run_id.is_empty():
		return _fail(&"invalid_run_id", "run_id must be nonempty")
	var peeked: Dictionary = _journal().peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	return {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": "%s:%d" % [run_id, int(peeked["value"]["checkpoint_sequence"])]},
		"receipt": {}}

func capture() -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var captured: Dictionary = _journal().capture_state()
	return {"ok": true, "code": &"ok", "value": {"backup": captured["value"]["backup"]}}

func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var keys: Array = checkpoint_inputs.keys()
	keys.sort()
	var expected := CHECKPOINT_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return _fail(&"invalid_checkpoint_inputs", "unexpected input keys: " + str(keys))
	if disk_write not in DISK_WRITES:
		return _fail(&"invalid_disk_write", str(disk_write))
	var snapshot_input: Variant = checkpoint_inputs["snapshot_input"]
	if typeof(snapshot_input) != TYPE_DICTIONARY \
			or typeof((snapshot_input as Dictionary).get("lifecycle")) != TYPE_DICTIONARY:
		return _fail(&"invalid_checkpoint_inputs", "snapshot_input.lifecycle is required")
	var run_id := str((snapshot_input["lifecycle"] as Dictionary).get("run_id", ""))
	var peeked: Dictionary = _journal().peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	# When configured, the desktop host is the sole source of the persisted active_app_id;
	# the caller-supplied value is ignored (dwm-p2r.9 Plan 02 Task 1).
	var active_app_id: Variant = checkpoint_inputs["active_app_id"]
	if _desktop_context_provider != null:
		active_app_id = _desktop_context_provider.capture_persistent_state().get("active_app_id", null)
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		snapshot_input, checkpoint_inputs["dialogic_checkpoint"],
		str(checkpoint_inputs["route_id"]), active_app_id,
		checkpoint_inputs["audio_context"], int(checkpoint_inputs["content_version"]),
		int(peeked["value"]["checkpoint_sequence"]))
	if not built.get("ok", false):
		return built
	var prepared_record: Dictionary = _journal().prepare_record(built["value"]["snapshot"], checkpoint_kind)
	if not prepared_record.get("ok", false):
		return prepared_record
	var journal_candidate: Dictionary = prepared_record["value"]["candidate"]
	var checkpoint_id := str(built["value"]["snapshot"]["checkpoint_id"])
	var candidate := {
		"journal_candidate": journal_candidate,
		"checkpoint_id": checkpoint_id,
		"autosave_document": null,
		"storage_backup": null,
	}
	if str(disk_write["kind"]) == "autosave":
		var reason := str(disk_write["reason"])
		var projected_earlier: Array = journal_candidate["earlier"]
		var document: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
			&"autosave", null, StringName(reason), journal_candidate["current"], projected_earlier)
		if not document.get("ok", false):
			return document
		candidate["autosave_document"] = document["value"]
		var backup := _capture_storage_backup(AUTOSAVE_RELATIVE_PATH)
		if not backup.get("ok", false):
			return backup
		candidate["storage_backup"] = backup["value"]["descriptor"]
	return {"ok": true, "code": &"ok",
		"value": {"candidate": candidate, "checkpoint_id": checkpoint_id}}

func commit(candidate: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if typeof(candidate.get("journal_candidate")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by this port")
	if candidate.get("autosave_document") != null:
		var canonical: Dictionary = CANONICAL_JSON.stringify(candidate["autosave_document"])
		if not canonical.get("ok", false):
			return _fail(&"canonical_serialization_failed", "")
		var written: Dictionary = _storage().write_atomic(
			AUTOSAVE_RELATIVE_PATH, str(canonical["value"]) + "\n", _document_text_validator)
		if not written.get("ok", false):
			return written
		var re_read: Dictionary = _storage().read_text(AUTOSAVE_RELATIVE_PATH)
		if not re_read.get("ok", false):
			return re_read
		var parsed: Dictionary = STRICT_JSON.parse_object(str(re_read["value"]))
		if not parsed.get("ok", false) or not SAVE_DOCUMENT_SCHEMA.validate(parsed["value"]).get("ok", false):
			return _fail(&"reread_mismatch", AUTOSAVE_RELATIVE_PATH)
	var committed: Dictionary = _journal().commit_prepared(candidate["journal_candidate"])
	if not committed.get("ok", false):
		return committed
	return {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": str(committed["value"]["checkpoint_id"])}}

func rollback(backup: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var attempts: Array = []
	var journal_backup: Variant = backup.get("journal_backup", backup)
	var journal_restored: Dictionary = _journal().restore_state(journal_backup)
	attempts.append({"owner_id": "checkpoint_journal", "operation": "restore_state", "result": journal_restored})
	var storage_descriptor: Variant = backup.get("storage_backup")
	var storage_ok := true
	if typeof(storage_descriptor) == TYPE_DICTIONARY:
		var descriptor := storage_descriptor as Dictionary
		var relative_path := str(descriptor.get("relative_path", AUTOSAVE_RELATIVE_PATH))
		var storage_result: Dictionary
		if bool(descriptor.get("existed", false)):
			storage_result = _storage().write_atomic(
				relative_path, str(descriptor.get("validated_text", "")), _document_text_validator)
		else:
			storage_result = _storage().remove(relative_path)
		attempts.append({"owner_id": "save_storage", "operation": "rollback", "result": storage_result})
		storage_ok = storage_result.get("ok", false)
	if journal_restored.get("ok", false) and storage_ok:
		return {"ok": true, "code": &"ok"}
	return _fatal_rollback("rollback", str((journal_backup as Dictionary).get("run_id", "")), attempts)

## Task-6 addition (dwm-p2r.32): builds the narrow admission-checkpoint candidate for
## `DesktopCausalSequencePort`. Mutation-free -- it computes the frozen preimage/receipt (the sole
## legal builder is `DesktopConsequenceState.checkpoint_content_preimage()`) and captures the
## current on-disk backup, but writes nothing; only `commit_consequence_checkpoint()` durably writes.
func prepare_consequence_checkpoint(checkpoint_header: Dictionary, stage_candidate: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var preimage: Dictionary = DESKTOP_CONSEQUENCE_STATE.checkpoint_content_preimage(checkpoint_header, stage_candidate)
	if not preimage.get("ok", false):
		return preimage
	var preimage_value: Dictionary = (preimage["value"] as Dictionary)["preimage"]
	var canonical: Dictionary = CANONICAL_JSON.stringify(preimage_value)
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "consequence checkpoint preimage is not canonicalizable")
	var content_sha256 := str(canonical["value"]).sha256_text()
	var checkpoint_receipt := {
		"receipt_id": "consequence_checkpoint." + content_sha256,
		"header": (preimage_value["header"] as Dictionary).duplicate(true),
		"content_sha256": content_sha256,
	}
	var document := {
		"schema_version": 1,
		"header": (preimage_value["header"] as Dictionary).duplicate(true),
		"stage_candidate": stage_candidate.duplicate(true),
		"checkpoint_receipt": checkpoint_receipt,
	}
	var backup := _capture_storage_backup(CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	if not backup.get("ok", false):
		return backup
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"document": document, "storage_backup": backup["value"]["descriptor"]},
		"checkpoint_receipt": checkpoint_receipt,
	}}

## Requires the exact receipt `prepare_consequence_checkpoint()` minted for this candidate (the
## caller never mints its own); writes and re-reads before returning, matching this port's existing
## autosave discipline.
func commit_consequence_checkpoint(checkpoint_candidate: Dictionary, checkpoint_receipt: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if typeof(checkpoint_candidate.get("document")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by prepare_consequence_checkpoint")
	var document: Dictionary = checkpoint_candidate["document"]
	if document.get("checkpoint_receipt") != checkpoint_receipt:
		return _fail(&"checkpoint_receipt_mismatch", "checkpoint_receipt does not match the prepared candidate")
	var canonical: Dictionary = CANONICAL_JSON.stringify(document)
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "consequence checkpoint document is not canonicalizable")
	var text := str(canonical["value"]) + "\n"
	var written: Dictionary = _storage().write_atomic(
		CONSEQUENCE_CHECKPOINT_RELATIVE_PATH, text, _consequence_checkpoint_text_validator)
	if not written.get("ok", false):
		return written
	var re_read: Dictionary = _storage().read_text(CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	if not re_read.get("ok", false):
		return re_read
	if str(re_read["value"]) != text:
		return _fail(&"reread_mismatch", CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}

func _consequence_checkpoint_text_validator(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var document: Variant = parsed["value"]
	if typeof(document) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "document must be an object"}
	var keys: Array = (document as Dictionary).keys()
	keys.sort()
	var expected := CONSEQUENCE_CHECKPOINT_DOCUMENT_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "unexpected document keys"}
	return {"ok": true, "code": &"ok", "value": document}

func _fatal_rollback(phase: String, run_id: String, raw_diagnostics: Array) -> Dictionary:
	var already_retained := false
	for diagnostic: Dictionary in raw_diagnostics:
		if str((diagnostic.get("result", {}) as Dictionary).get("code", "")) == "APPLICATION_FATAL":
			already_retained = true
	if not already_retained and not _gate.is_fatal_latched():
		var projected: Dictionary = PROJECTOR.project_failure(
			"save_checkpoint", phase, "fatal_rollback_failed",
			{"run_id": run_id, "relative_path": AUTOSAVE_RELATIVE_PATH},
			raw_diagnostics)
		var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false):
			var failure: Dictionary = projected["value"]["failure"]
			if PROJECTOR.validate_failure(failure).get("ok", false):
				candidate = failure
		_gate.latch_fatal(candidate)
	return _gate.guard_external(&"save_checkpoint_recovery")

func _capture_storage_backup(relative_path: String) -> Dictionary:
	var existed: bool = _storage().exists(relative_path)
	var descriptor := {
		"relative_path": relative_path,
		"existed": existed,
		"validated_text": null,
		"sha256": null,
	}
	if existed:
		var read: Dictionary = _storage().read_text(relative_path)
		if not read.get("ok", false):
			return read
		var text := str(read["value"])
		var validation := _document_text_validator(text)
		if not validation.get("ok", false):
			return validation
		descriptor["validated_text"] = text
		descriptor["sha256"] = text.sha256_text()
	return {"ok": true, "code": &"ok", "value": {"descriptor": descriptor}}

func _document_text_validator(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

func _readiness() -> Dictionary:
	if _gate == null:
		return _fail(&"fatal_latch_not_configured", "")
	if _gate.is_fatal_latched():
		return _gate.guard_external(&"save_checkpoint_recovery")
	if _save_manager == null or _journal() == null or _storage() == null:
		return _fail(&"not_initialized", "SaveManagerCheckpointPort requires an initialized SaveManager")
	return {}

func _journal() -> RefCounted:
	return _save_manager._journal if _save_manager != null else null

func _storage() -> RefCounted:
	return _save_manager._storage if _save_manager != null else null

static func _has_all_methods(target: Object) -> bool:
	for method: String in GATE_METHODS:
		if not target.has_method(method):
			return false
	return true

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
