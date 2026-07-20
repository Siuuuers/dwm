class_name SaveDocumentSchema
extends RefCounted

## Discriminated save-document union
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 4).

const DOCUMENT_VERSION := 2

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

const DOCUMENT_KEYS: Array[String] = [
	"current_snapshot", "kind", "recovery_journal", "save_reason", "schema_version", "slot_id",
]
const CHECKPOINT_KINDS: Array[String] = ["day_start", "day_resolution_stage"]
const AUTOSAVE_REASONS: Array[String] = ["automatic", "day_start", "ending", "pre_board", "logout"]
const MIN_SLOT := 1
const MAX_SLOT := 7

static func build(
		kind: StringName,
		slot_id: Variant,
		save_reason: StringName,
		current_bundle: Dictionary,
		journal: Array
) -> Dictionary:
	var discriminator_error := _validate_discriminators(String(kind), slot_id, String(save_reason))
	if discriminator_error != "":
		return _fail(&"invalid_discriminator", discriminator_error)
	var bundle_error := _validate_bundle(current_bundle)
	if not bundle_error.get("ok", false):
		return bundle_error
	var journal_error := _validate_journal(journal)
	if journal_error != "":
		return _fail(&"invalid_recovery_journal", journal_error)
	var document := {
		"schema_version": DOCUMENT_VERSION,
		"kind": String(kind),
		"slot_id": slot_id,
		"save_reason": String(save_reason),
		"current_snapshot": {
			"checkpoint_kind": str(current_bundle["checkpoint_kind"]),
			"snapshot": bundle_error["value"]["candidate"],
		},
		"recovery_journal": journal.duplicate(true),
	}
	var validated := validate(document)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

static func validate(document: Dictionary) -> Dictionary:
	var candidate := RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(document.duplicate(true)) as Dictionary
	var keys: Array = candidate.keys()
	keys.sort()
	var expected := DOCUMENT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return _fail(&"invalid_document_shape", "unexpected document keys: " + str(keys))
	if typeof(candidate["schema_version"]) != TYPE_INT:
		return _fail(&"invalid_document_shape", "schema_version must be an integer")
	if int(candidate["schema_version"]) > DOCUMENT_VERSION:
		return _fail(&"unsupported_schema_version", str(candidate["schema_version"]))
	if int(candidate["schema_version"]) != DOCUMENT_VERSION:
		return _fail(&"invalid_document_shape", "schema_version must be %d" % DOCUMENT_VERSION)
	var discriminator_error := _validate_discriminators(
		str(candidate["kind"]), candidate["slot_id"], str(candidate["save_reason"]))
	if discriminator_error != "":
		return _fail(&"invalid_discriminator", discriminator_error)
	if typeof(candidate["current_snapshot"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_document_shape", "current_snapshot must be an object")
	var bundle_result := _validate_bundle(candidate["current_snapshot"])
	if not bundle_result.get("ok", false):
		return bundle_result
	(candidate["current_snapshot"] as Dictionary)["snapshot"] = bundle_result["value"]["candidate"]
	if typeof(candidate["recovery_journal"]) != TYPE_ARRAY:
		return _fail(&"invalid_document_shape", "recovery_journal must be an array")
	var journal_error := _validate_journal(candidate["recovery_journal"])
	if journal_error != "":
		return _fail(&"invalid_recovery_journal", journal_error)
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

static func prepare_candidate(document: Dictionary) -> Dictionary:
	return validate(document)

static func _validate_discriminators(kind: String, slot_id: Variant, save_reason: String) -> String:
	match kind:
		"slot":
			if typeof(slot_id) != TYPE_INT or int(slot_id) < MIN_SLOT or int(slot_id) > MAX_SLOT:
				return "slot documents require an integer slot_id 1..7"
			if save_reason != "manual":
				return "slot documents require save_reason=manual"
		"quick":
			if slot_id != null:
				return "quick documents require a JSON null slot_id"
			if save_reason != "quick":
				return "quick documents require save_reason=quick"
		"autosave":
			if slot_id != null:
				return "autosave documents require a JSON null slot_id"
			if save_reason not in AUTOSAVE_REASONS:
				return "unknown autosave reason: " + save_reason
		_:
			return "unknown document kind: " + kind
	return ""

static func _validate_bundle(bundle: Dictionary) -> Dictionary:
	var keys: Array = bundle.keys()
	keys.sort()
	if keys != ["checkpoint_kind", "snapshot"]:
		return _fail(&"invalid_bundle_shape", "bundle must have exactly checkpoint_kind and snapshot")
	if str(bundle["checkpoint_kind"]) not in CHECKPOINT_KINDS:
		return _fail(&"invalid_bundle_shape", "unknown checkpoint_kind: " + str(bundle["checkpoint_kind"]))
	if typeof(bundle["snapshot"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_bundle_shape", "snapshot must be an object")
	var snapshot := RUN_SNAPSHOT_SCHEMA.validate(bundle["snapshot"])
	if not snapshot.get("ok", false):
		return snapshot
	return {"ok": true, "code": &"ok", "value": {"candidate": snapshot["value"]["candidate"]}}

static func _validate_journal(journal: Array) -> String:
	for index: int in range(journal.size()):
		if typeof(journal[index]) != TYPE_DICTIONARY:
			return "journal entry %d must be an object" % index
		var primitive := RUN_SNAPSHOT_SCHEMA.validate_primitive_tree(
			journal[index], "$.recovery_journal[%d]" % index)
		if not primitive.get("ok", false):
			return str(primitive.get("message", "journal entry %d must be primitive" % index))
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
