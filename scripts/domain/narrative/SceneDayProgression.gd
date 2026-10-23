class_name SceneDayProgression
extends RefCounted
## Stateless, nonwired routing over caller-supplied trusted registration.
## Shape/matching is not issuer authority, native-position proof or durable idempotency.

const EVENT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const DOCUMENT_KEYS := ["schema_version", "days", "endings"]
const DAY_KEYS := ["day", "entry_id", "content_version", "content_sha256", "terminal"]
const MARKER_KEYS := ["event_id", "ordinal", "predecessor", "label", "after_line_id", "successor_id"]
const ENDING_KEYS := ["ending_id", "entry_id", "content_version", "content_sha256"]
const POSITION_KEYS := ["content_sha256", "label", "after_line_id"]

static func plan_new_run(document: Variant) -> Dictionary:
	if not _valid_document(document): return _fail(&"registration_invalid")
	return _plan("enter_day", 1, document.days[0])

static func plan_completion(document: Variant, current_day: Variant, envelope: Variant,
		position: Variant, eligible_ending_id: Variant = null) -> Dictionary:
	if not _valid_document(document): return _fail(&"registration_invalid")
	if typeof(current_day) != TYPE_INT or current_day < 1 or current_day > 7:
		return _fail(&"day_invalid")
	if not EVENT.inspect(envelope).ok or envelope.kind != "day.complete":
		return _fail(&"event_invalid")
	var row: Dictionary = document.days[current_day - 1]
	if envelope.payload.source_day != current_day or envelope.source.entry_id != row.entry_id \
			or envelope.source.content_version != row.content_version:
		return _fail(&"source_mismatch")
	var marker: Dictionary = row.terminal
	if envelope.event_id != marker.event_id or envelope.ordinal != marker.ordinal \
			or envelope.predecessor != marker.predecessor or envelope.payload.successor_id != marker.successor_id:
		return _fail(&"marker_mismatch")
	if not _keys(position, POSITION_KEYS): return _fail(&"marker_mismatch")
	for key: String in POSITION_KEYS:
		if typeof(position[key]) != TYPE_STRING: return _fail(&"marker_mismatch")
	if position.content_sha256 != row.content_sha256 or position.label != marker.label \
			or position.after_line_id != marker.after_line_id:
		return _fail(&"marker_mismatch")
	if current_day < 7:
		if eligible_ending_id != null: return _fail(&"ending_invalid")
		return _plan("enter_day", current_day + 1, document.days[current_day])
	if not EVENT._id(eligible_ending_id): return _fail(&"ending_invalid")
	for ending: Dictionary in document.endings:
		if ending.ending_id == eligible_ending_id: return _plan("enter_ending", 7, ending)
	return _fail(&"ending_invalid")

static func _valid_document(document: Variant) -> bool:
	if not _keys(document, DOCUMENT_KEYS): return false
	if typeof(document.schema_version) != TYPE_INT or document.schema_version != 1: return false
	if not document.days is Array or document.days.size() != 7 or not document.endings is Array: return false
	var entries := {}
	var events := {}
	var labels := {}
	var endings := {}
	for index in range(7):
		var row: Variant = document.days[index]
		if not _keys(row, DAY_KEYS) or not _descriptor(row): return false
		if typeof(row.day) != TYPE_INT or row.day != index + 1: return false
		if entries.has(row.entry_id): return false
		entries[row.entry_id] = true
		var marker: Variant = row.terminal
		if not _keys(marker, MARKER_KEYS): return false
		for key: String in ["event_id", "label", "after_line_id", "successor_id"]:
			if not EVENT._id(marker[key]): return false
		if typeof(marker.ordinal) != TYPE_INT or marker.ordinal < 0: return false
		if typeof(marker.predecessor) != TYPE_STRING: return false
		if marker.ordinal == 0:
			if marker.predecessor != "": return false
		elif not EVENT._id(marker.predecessor) or marker.predecessor == marker.event_id: return false
		if marker.label != "scene.marker." + marker.event_id: return false
		if events.has(marker.event_id) or labels.has(marker.label): return false
		events[marker.event_id] = true
		labels[marker.label] = true
	# Check successors only after all destination rows have passed their shape checks.
	for index in range(7):
		var successor: String = document.days[index + 1].entry_id if index < 6 else "eligible_ending"
		if document.days[index].terminal.successor_id != successor: return false
	for row: Variant in document.endings:
		if not _keys(row, ENDING_KEYS) or not _descriptor(row) or not EVENT._id(row.ending_id): return false
		if entries.has(row.entry_id) or endings.has(row.ending_id): return false
		entries[row.entry_id] = true
		endings[row.ending_id] = true
	return true

static func _descriptor(row: Dictionary) -> bool:
	return EVENT._id(row.entry_id) and typeof(row.content_version) == TYPE_INT \
		and row.content_version > 0 and _hash(row.content_sha256)

static func _hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for index in range(64):
		var code: int = value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)): return false
	return true

static func _keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

static func _plan(kind: String, day: int, descriptor: Dictionary) -> Dictionary:
	var value := {"kind": kind, "target_day": day, "entry_id": descriptor.entry_id,
		"content_version": descriptor.content_version, "content_sha256": descriptor.content_sha256}
	value.make_read_only()
	var result := {"ok": true, "value": value}
	result.make_read_only()
	return result

static func _fail(code: StringName) -> Dictionary:
	var result := {"ok": false, "code": code}
	result.make_read_only()
	return result
