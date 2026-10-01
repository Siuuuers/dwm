extends RefCounted
## Versioned, nonrecursive Next plan inside the existing reading checkpoint.
## The source ledger is immutable; only the exact declared ordered suffix can
## become the destination. Authored catalogue and Profile admission stay with
## the bridge. This pure schema never grants witnessing or performs traversal.

const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const REGISTRY := preload("res://scripts/narrative/NarrativeCaptionRegistry.gd")
const READING_KEYS := ["schema_version", "catalogue_fingerprint", "boundary", "ledger", "frontier"]
const PLAN_KEYS := ["entry_id", "catalogue_fingerprint", "source_ledger", "source_frontier", "traversed_captions", "destination"]
const PHASES := ["source", "destination"]

static func create(plan: Dictionary, phase: String) -> Dictionary:
	if phase not in PHASES: return _fail(&"reading_next_phase_invalid")
	var checked := _validate_plan(plan)
	if not checked.ok: return checked
	var encoded := JSON_WRITER.stringify(plan)
	if not encoded.ok: return _fail(&"reading_next_plan_invalid")
	return {"ok": true, "value": {"schema_version": 1,
		"operation_id": str(encoded.value).sha256_text(), "phase": phase, "plan": plan.duplicate(true)}}

## The complete source/destination projection, useful to the one semantic owner.
static func project(plan: Dictionary, phase: String) -> Dictionary:
	var made := create(plan, phase)
	if not made.ok: return made
	var reading := _projection(plan, phase)
	reading["schema_version"] = 2
	reading["next_operation"] = made.value
	return {"ok": true, "value": reading}

static func validate(reading: Dictionary, entry_id: String) -> Dictionary:
	var keys := READING_KEYS.duplicate()
	keys.append("next_operation")
	if not FROZEN._exact(reading, keys) or typeof(reading.get("schema_version")) != TYPE_INT \
			or reading.schema_version != 2 or not reading.get("next_operation") is Dictionary:
		return _fail(&"reading_next_operation_invalid")
	var operation: Dictionary = reading.next_operation
	if not FROZEN._exact(operation, ["schema_version", "operation_id", "phase", "plan"]) \
			or typeof(operation.get("schema_version")) != TYPE_INT or operation.schema_version != 1 \
			or not operation.get("operation_id") is String or not operation.get("phase") is String \
			or not operation.get("plan") is Dictionary:
		return _fail(&"reading_next_operation_invalid")
	var made := create(operation.plan, operation.phase)
	if not made.ok: return made
	if operation != made.value or operation.plan.entry_id != entry_id:
		return _fail(&"reading_next_operation_mismatch")
	if without_operation(reading) != _projection(operation.plan, operation.phase):
		return _fail(&"reading_next_projection_mismatch")
	return {"ok": true, "value": operation.duplicate(true)}

static func without_operation(reading: Dictionary) -> Dictionary:
	var result := reading.duplicate(true)
	if typeof(result.get("schema_version")) == TYPE_INT and result.schema_version == 2:
		result["schema_version"] = 1
		result.erase("next_operation")
	return result

static func _projection(plan: Dictionary, phase: String) -> Dictionary:
	var ledger: Dictionary = plan.source_ledger.duplicate(true)
	var frontier: Dictionary = plan.source_frontier.duplicate(true)
	var boundary := "line"
	if phase == "destination":
		for row: Dictionary in plan.traversed_captions:
			ledger.captions.append(row.duplicate(true))
		if plan.destination.kind == "line":
			var row: Dictionary = plan.destination.caption
			ledger.captions.append(row.duplicate(true))
			frontier = {"line_id": row.beat.line_id, "publication_id": row.publication_id}
		else:
			boundary = "between_entries"
			frontier = {}
	return {"schema_version": 1, "catalogue_fingerprint": plan.catalogue_fingerprint,
		"boundary": boundary, "ledger": ledger, "frontier": frontier}

static func _validate_plan(plan: Dictionary) -> Dictionary:
	if not FROZEN._exact(plan, PLAN_KEYS) or not FROZEN._primitive(plan) \
			or not _id(plan.get("entry_id")) or not _id(plan.get("catalogue_fingerprint")) \
			or not plan.get("source_ledger") is Dictionary or not plan.get("source_frontier") is Dictionary \
			or not plan.get("traversed_captions") is Array or not plan.get("destination") is Dictionary:
		return _fail(&"reading_next_plan_invalid")
	var ledger: Dictionary = plan.source_ledger
	if not FROZEN._exact(ledger, ["session_token", "frozen_context", "entry_contexts", "captions"]) \
			or not _id(ledger.get("session_token")) or not ledger.get("frozen_context") is Dictionary \
			or not ledger.get("entry_contexts") is Dictionary or not ledger.get("captions") is Array \
			or ledger.captions.is_empty() or not ledger.entry_contexts.get(plan.entry_id) is Dictionary \
			or not FROZEN._exact(ledger.frozen_context, ["completion_transaction_id", "pre_entry_id"]) \
			or ledger.frozen_context.get("completion_transaction_id") != ledger.session_token \
			or not _id(ledger.frozen_context.get("pre_entry_id")):
		return _fail(&"reading_next_plan_invalid")
	var publications := {}
	var lines := {}
	for row: Variant in ledger.captions:
		if not _admit_row(row, publications, lines): return _fail(&"reading_next_sequence_invalid")
		if not ledger.entry_contexts.get(row.beat.owning_entry_id) is Dictionary:
			return _fail(&"reading_next_sequence_invalid")
	var tail: Dictionary = ledger.captions.back()
	if tail.beat.owning_entry_id != plan.entry_id \
			or plan.source_frontier != {"line_id": tail.beat.line_id, "publication_id": tail.publication_id}:
		return _fail(&"reading_next_source_invalid")
	for row: Variant in plan.traversed_captions:
		if not _admit_row(row, publications, lines) or row.beat.owning_entry_id != plan.entry_id:
			return _fail(&"reading_next_sequence_invalid")
	var destination: Dictionary = plan.destination
	if not FROZEN._exact(destination, ["kind", "caption"]) or destination.get("kind") not in ["line", "completion"]:
		return _fail(&"reading_next_destination_invalid")
	if destination.kind == "line":
		if not _admit_row(destination.caption, publications, lines) or destination.caption.beat.owning_entry_id != plan.entry_id:
			return _fail(&"reading_next_destination_invalid")
	elif destination.caption != null:
		return _fail(&"reading_next_destination_invalid")
	return {"ok": true}

static func _admit_row(row: Variant, publications: Dictionary, lines: Dictionary) -> bool:
	if not row is Dictionary or not FROZEN._exact(row, ["publication_id", "beat"]) \
			or not _id(row.get("publication_id")) or not row.get("beat") is Dictionary \
			or not REGISTRY.valid_beat(row.beat) or publications.has(row.publication_id) \
			or lines.has(row.beat.line_id):
		return false
	publications[row.publication_id] = true
	lines[row.beat.line_id] = true
	return true

static func _id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
