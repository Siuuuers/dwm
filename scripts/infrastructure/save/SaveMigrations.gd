class_name SaveMigrations
extends RefCounted
## Current save-document admission. Unshipped older records do not carry captured
## run configuration and are unsupported. Never repair or convert required gameplay.
## Scene admission drops retired optional save_reason metadata.
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")

## Ordinary Load owns the decoded current document. Only content-position
## compatibility is resolved here; gameplay facts are trusted.
static func load_current_document(raw: Dictionary) -> Dictionary:
	var version: Variant = raw.get("schema_version")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != SAVE_DOCUMENT_SCHEMA.SCENE_DOCUMENT_VERSION:
		return _fail(&"unsupported_save_format", "Only current Save9 files can be loaded")
	var normalized := RUN_SNAPSHOT_SCHEMA.normalize_scene_content(raw.current_snapshot.snapshot, true)
	if not normalized.ok: return normalized
	raw.current_snapshot.snapshot = normalized.value
	# Older Save9 files may carry these retired presentation/configuration fields.
	# Discard them without inspecting or repairing gameplay.
	raw.current_snapshot.snapshot.erase("audio_context")
	raw.current_snapshot.snapshot.erase("active_app_id")
	raw.current_snapshot.snapshot.lifecycle.erase("scene_assignment")
	raw.erase("save_reason")
	return {"ok": true, "value": {"document": raw,
		"legacy_profile_patch_input": {}, "migration_receipts": []}}

static func migrate_document(raw: Dictionary, expected_locator: Dictionary,
		scene_seed_receiver: Callable = Callable()) -> Dictionary:
	var locator_error := _validate_expected_locator(expected_locator)
	if locator_error != "": return _fail(&"invalid_expected_locator", locator_error)
	var version: Variant = raw.get("schema_version")
	if typeof(version) == TYPE_FLOAT and is_finite(version) and version == floorf(version): version = int(version)
	if typeof(version) != TYPE_INT: return _fail(&"invalid_schema_version", "Document version must be integral")
	if version < SAVE_DOCUMENT_SCHEMA.DOCUMENT_VERSION:
		return _fail(&"unsupported_run_configuration_schema", "Captured run configuration is required")
	if version > SAVE_DOCUMENT_SCHEMA.SCENE_DOCUMENT_VERSION:
		return _fail(&"unsupported_future_schema", str(version))
	var admitted := raw
	if version == SAVE_DOCUMENT_SCHEMA.SCENE_DOCUMENT_VERSION:
		admitted = raw.duplicate(true)
		if not admitted.get("current_snapshot") is Dictionary or not admitted.get("recovery_journal") is Array:
			return _fail(&"invalid_document_shape", "Save9 requires current snapshot and journal")
		var bundles: Array = [admitted.current_snapshot]
		bundles.append_array(admitted.recovery_journal)
		for bundle: Variant in bundles:
			if not bundle is Dictionary or not bundle.get("snapshot") is Dictionary:
				return _fail(&"invalid_document_shape", "snapshot bundle must contain a snapshot")
			var normalized := RUN_SNAPSHOT_SCHEMA.normalize_scene_content(bundle.snapshot)
			if not normalized.ok: return normalized
			bundle.snapshot = normalized.value
	var validated := SAVE_DOCUMENT_SCHEMA.validate(admitted, {}, scene_seed_receiver)
	if not validated.get("ok", false): return validated
	var document: Dictionary = validated["value"]["candidate"]
	if document.kind != expected_locator.kind or document.slot_id != expected_locator.slot_id:
		return _fail(&"save_locator_mismatch", "Document identity differs from its source locator")
	return {"ok":true,"code":&"ok","value":{
		"document":document,"legacy_profile_patch_input":{},"migration_receipts":[]}}

static func _validate_expected_locator(locator: Dictionary) -> String:
	var keys: Array = locator.keys()
	keys.sort()
	if keys != ["kind", "slot_id"]:
		return "expected_locator must have exactly kind and slot_id"
	match str(locator["kind"]):
		"slot":
			if typeof(locator["slot_id"]) != TYPE_INT or int(locator["slot_id"]) < 1 or int(locator["slot_id"]) > 7:
				return "slot expected_locator needs slot_id 1..7"
		"quick", "autosave":
			if locator["slot_id"] != null:
				return str(locator["kind"]) + " expected_locator needs a null slot_id"
		_:
			return "unknown expected_locator kind: " + str(locator["kind"])
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

