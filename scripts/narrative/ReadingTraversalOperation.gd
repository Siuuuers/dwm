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
	if plan.get("schema_version") == 2: return _create_marker_operation(plan, phase)
	if phase not in PHASES: return _fail(&"reading_next_phase_invalid")
	var checked := _validate_plan(plan)
	if not checked.ok: return checked
	var encoded := JSON_WRITER.stringify(plan)
	if not encoded.ok: return _fail(&"reading_next_plan_invalid")
	return {"ok": true, "value": {"schema_version": 1,
		"operation_id": str(encoded.value).sha256_text(), "phase": phase, "plan": plan.duplicate(true)}}

## The complete source/destination projection, useful to the one semantic owner.
static func project(plan: Dictionary, phase: String) -> Dictionary:
	if plan.get("schema_version") == 2: return _project_marker_operation(plan, phase)
	var made := create(plan, phase)
	if not made.ok: return made
	var reading := _projection(plan, phase)
	reading["schema_version"] = 2
	reading["next_operation"] = made.value
	return {"ok": true, "value": reading}

static func validate(reading: Dictionary, entry_id: String) -> Dictionary:
	if reading.get("schema_version") == 4: return _validate_marker_operation(reading, entry_id)
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
	if typeof(result.get("schema_version")) == TYPE_INT and result.schema_version == 4:
		result["next_operation"] = null
		return result
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


## Version 4 is a genuine marker-aware reading cursor, never a caption alias.
## These structural checks are complemented by the session's trusted programme
## checks and the Run owner's converse receipt check before mutation.
const MARKER_READING_KEYS := ["schema_version", "catalogue_fingerprint", "marker_program_fingerprint",
	"boundary", "ledger", "frontier", "next_operation"]
const MARKER_PLAN_KEYS := ["schema_version", "entry_id", "source_reading", "traversed_captions", "destination"]
const EVENT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

static func valid_marker_reading_shape(reading: Dictionary) -> bool:
	if not FROZEN._exact(reading, MARKER_READING_KEYS) or not FROZEN._primitive(reading) \
			or typeof(reading.get("schema_version")) != TYPE_INT or reading.schema_version != 4 \
			or not _hash(reading.get("catalogue_fingerprint")) or not _hash(reading.get("marker_program_fingerprint")) \
			or reading.get("boundary") not in ["line", "notification", "between_entries"] \
			or not reading.get("ledger") is Dictionary or not reading.get("frontier") is Dictionary \
			or (reading.next_operation != null and not reading.next_operation is Dictionary): return false
	var ledger: Dictionary = reading.ledger
	if not FROZEN._exact(ledger, ["session_token", "frozen_context", "entry_contexts", "captions"]) \
			or not _id(ledger.session_token) or not ledger.frozen_context is Dictionary \
			or not ledger.entry_contexts is Dictionary or not ledger.captions is Array or ledger.captions.is_empty(): return false
	var publications := {}
	var lines := {}
	for row: Variant in ledger.captions:
		if not _admit_row(row, publications, lines): return false
	var tail: Dictionary = ledger.captions.back()
	var frontier: Dictionary = reading.frontier
	if reading.boundary == "line":
		return frontier == {"line_id": tail.beat.line_id, "publication_id": tail.publication_id} \
			and FROZEN._exact(frontier, ["line_id", "publication_id"])
	if reading.boundary == "between_entries": return frontier.is_empty()
	if not FROZEN._exact(frontier, ["event_id", "command_id", "event_digest", "anchor"]) \
			or not EVENT._id(frontier.event_id) or not EVENT._id(frontier.command_id) \
			or not _hash(frontier.event_digest) or not frontier.anchor is Dictionary \
			or not FROZEN._exact(frontier.anchor, EVENT.ANCHOR_KEYS): return false
	var anchor: Dictionary = frontier.anchor
	return anchor.get("session_id") == ledger.session_token and anchor.get("entry_id") == tail.beat.owning_entry_id \
		and anchor.get("line_id") == tail.beat.line_id and anchor.get("publication_id") == tail.publication_id \
		and anchor.get("catalogue_fingerprint") == reading.catalogue_fingerprint \
		and typeof(anchor.get("content_version")) == TYPE_INT and anchor.content_version > 0

static func _create_marker_operation(plan: Dictionary, phase: String) -> Dictionary:
	if phase not in PHASES: return _fail(&"reading_next_phase_invalid")
	var checked := _validate_marker_plan(plan)
	if not checked.ok: return checked
	var encoded := JSON_WRITER.stringify(plan)
	if not encoded.ok: return _fail(&"reading_next_plan_invalid")
	return {"ok": true, "value": {"schema_version": 2, "operation_id": str(encoded.value).sha256_text(),
		"phase": phase, "plan": plan.duplicate(true)}}

static func _validate_marker_plan(plan: Dictionary) -> Dictionary:
	if not FROZEN._exact(plan, MARKER_PLAN_KEYS) or not FROZEN._primitive(plan) \
			or typeof(plan.get("schema_version")) != TYPE_INT or plan.schema_version != 2 \
			or not _id(plan.get("entry_id")) or not plan.get("source_reading") is Dictionary \
			or not plan.get("traversed_captions") is Array or not plan.get("destination") is Dictionary:
		return _fail(&"reading_next_plan_invalid")
	var source: Dictionary = plan.source_reading
	if not valid_marker_reading_shape(source) or source.next_operation != null \
			or source.boundary == "between_entries" or source.ledger.captions.back().beat.owning_entry_id != plan.entry_id:
		return _fail(&"reading_next_source_invalid")
	var publications := {}
	var lines := {}
	for row: Variant in source.ledger.captions:
		if not _admit_row(row, publications, lines): return _fail(&"reading_next_sequence_invalid")
	for row: Variant in plan.traversed_captions:
		if not _admit_row(row, publications, lines) or row.beat.owning_entry_id != plan.entry_id:
			return _fail(&"reading_next_sequence_invalid")
	var target: Dictionary = plan.destination
	match target.get("kind"):
		"line":
			if not FROZEN._exact(target, ["kind", "caption"]) or not _admit_row(target.caption, publications, lines) \
					or target.caption.beat.owning_entry_id != plan.entry_id: return _fail(&"reading_next_destination_invalid")
		"completion":
			if not FROZEN._exact(target, ["kind"]): return _fail(&"reading_next_destination_invalid")
		"notification":
			if source.boundary == "notification" or not FROZEN._exact(target, ["kind", "semantic", "anchor"]) \
					or not target.semantic is Dictionary or target.semantic.has("playback_token") \
					or not target.anchor is Dictionary: return _fail(&"reading_next_destination_invalid")
			var envelope: Dictionary = target.semantic.duplicate(true)
			envelope["playback_token"] = "marker.validation"
			var receipt := EVENT.make_receipt(envelope, target.anchor)
			if not receipt.ok or envelope.kind != "notification.set" or envelope.ordinal != 0 \
					or envelope.predecessor != "" or envelope.source.scene_occurrence != source.ledger.session_token \
					or envelope.source.entry_id != plan.entry_id: return _fail(&"reading_next_destination_invalid")
		_:
			return _fail(&"reading_next_destination_invalid")
	var projected := _marker_projection(plan, "destination")
	if not valid_marker_reading_shape(projected): return _fail(&"reading_next_projection_mismatch")
	return {"ok": true}

static func _marker_projection(plan: Dictionary, phase: String) -> Dictionary:
	var result: Dictionary = plan.source_reading.duplicate(true)
	if phase == "source": return result
	for row: Dictionary in plan.traversed_captions: result.ledger.captions.append(row.duplicate(true))
	var target: Dictionary = plan.destination
	match target.kind:
		"line":
			result.ledger.captions.append(target.caption.duplicate(true))
			result.boundary = "line"
			result.frontier = {"line_id": target.caption.beat.line_id, "publication_id": target.caption.publication_id}
		"completion":
			result.boundary = "between_entries"
			result.frontier = {}
		"notification":
			result.boundary = "notification"
			result.frontier = {"event_id": target.semantic.event_id, "command_id": target.semantic.command_id,
				"event_digest": str(JSON_WRITER.stringify(target.semantic).value).sha256_text(), "anchor": target.anchor.duplicate(true)}
	return result

static func _project_marker_operation(plan: Dictionary, phase: String) -> Dictionary:
	var made := _create_marker_operation(plan, phase)
	if not made.ok: return made
	var result := _marker_projection(plan, phase)
	result.next_operation = made.value
	return {"ok": true, "value": result}

static func _validate_marker_operation(reading: Dictionary, entry_id: String) -> Dictionary:
	if not valid_marker_reading_shape(reading) or not reading.next_operation is Dictionary:
		return _fail(&"reading_next_operation_invalid")
	var operation: Dictionary = reading.next_operation
	if not FROZEN._exact(operation, ["schema_version", "operation_id", "phase", "plan"]) \
			or typeof(operation.schema_version) != TYPE_INT or operation.schema_version != 2 \
			or not operation.plan is Dictionary or not operation.phase is String:
		return _fail(&"reading_next_operation_invalid")
	var made := _create_marker_operation(operation.plan, operation.phase)
	if not made.ok: return made
	if not EVENT._same_types(operation, made.value) or operation != made.value or operation.plan.entry_id != entry_id:
		return _fail(&"reading_next_operation_mismatch")
	var expected := _marker_projection(operation.plan, operation.phase)
	var actual := without_operation(reading)
	if not EVENT._same_types(actual, expected) or actual != expected: return _fail(&"reading_next_projection_mismatch")
	return {"ok": true, "value": operation.duplicate(true)}

static func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true
