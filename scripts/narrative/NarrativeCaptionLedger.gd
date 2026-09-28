class_name NarrativeCaptionLedger
extends RefCounted
## Live internal prerequisite for semantic History, not a durable save or visited
## receipt. Semantic identity comes from registrations; opaque publication IDs
## distinguish occurrences. Repeated delivery of one publication is idempotent.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const REGISTRY := preload("res://scripts/narrative/NarrativeCaptionRegistry.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")

var _session_token := ""
var _frozen_context: Dictionary = {}
var _registered: Dictionary = {}
var _by_line: Dictionary = {}
var _published: Dictionary = {}
var _sequence: Array[Dictionary] = []
var _publication_serial := 0

func initialize(session_token: String, frozen_context: Dictionary,
		entry_manifest: Dictionary, registry: Dictionary) -> Dictionary:
	# Primitive-only captured context is immutable here; this does not perform
	# canonical FrozenPresentationContext admission or install Dialogic variables.
	# The first fixture supplies explicitly synthetic context. A later canonical
	# owner must supply its already admitted context and exact authored catalog.
	if not _session_token.is_empty(): return _fail(&"caption_session_already_initialized")
	if session_token.strip_edges().is_empty() or frozen_context.is_empty() \
			or not FROZEN._primitive(frozen_context):
		return _fail(&"caption_session_invalid")
	var checked := MANIFEST.validate_caption_registry(entry_manifest, registry)
	if not checked.ok: return checked
	_session_token = session_token
	_frozen_context = frozen_context.duplicate(true)
	FROZEN._freeze(_frozen_context)
	for beat: Dictionary in checked.value.beats:
		FROZEN._freeze(beat)
		_registered[beat.beat_id] = beat
		_by_line[beat.line_id] = beat
	return {"ok": true}

## Rebuild only this internal sequence. The canonical owner must independently
## admit the context/catalog; this does not read or migrate a Run save. Validate
## the complete candidate before installing any state, including a valid prefix.
func restore_snapshot(session_token: String, frozen_context: Dictionary,
		entry_manifest: Dictionary, registry: Dictionary, saved: Dictionary) -> Dictionary:
	if not _session_token.is_empty(): return _fail(&"caption_session_already_initialized")
	if not _has_exact_fields(saved, ["session_token", "frozen_context", "captions"]) \
			or not saved.session_token is String \
			or not saved.frozen_context is Dictionary or not saved.captions is Array:
		return _fail(&"caption_snapshot_invalid")
	# Preserve the existing component-root depth contract. Snapshot wrappers do
	# not consume context/signature depth admitted by initialize/valid_beat.
	if not FROZEN._primitive(saved.frozen_context): return _fail(&"caption_snapshot_invalid")
	if saved.session_token != session_token: return _fail(&"caption_foreign_session")
	if saved.frozen_context != frozen_context: return _fail(&"caption_context_mismatch")
	var candidate := NarrativeCaptionLedger.new()
	var initialized := candidate.initialize(session_token, frozen_context, entry_manifest, registry)
	if not initialized.ok: return initialized
	for row: Variant in saved.captions:
		if not row is Dictionary or not _has_exact_fields(row, ["publication_id", "beat"]) \
				or not row.publication_id is String or not row.beat is Dictionary:
			return _fail(&"caption_snapshot_invalid")
		if not _has_exact_fields(row.beat, REGISTRY.FIELDS): return _fail(&"caption_registration_invalid")
		var admitted := candidate.publish_caption(session_token, row.publication_id, row.beat)
		if not admitted.ok: return admitted
		if admitted.value["duplicate"]: return _fail(&"caption_snapshot_duplicate")
	_session_token = candidate._session_token
	_frozen_context = candidate._frozen_context
	_registered = candidate._registered
	_by_line = candidate._by_line
	_published = candidate._published
	_sequence = candidate._sequence
	_publication_serial = _sequence.size()
	return {"ok": true}

## Occurrences belong to the retained session, not a reusable Godot instance ID.
## Unpublished allocations are transient; reconstruction skips every retained ID.
func allocate_publication(session_token: String, entry_id: String) -> Dictionary:
	var checked := check_session(session_token, entry_id)
	if not checked.ok: return checked
	_publication_serial += 1
	var publication_id := "caption:%d" % _publication_serial
	while _published.has(publication_id):
		_publication_serial += 1
		publication_id = "caption:%d" % _publication_serial
	return {"ok": true, "value": publication_id}

func check_session(session_token: String, entry_id: String) -> Dictionary:
	if _session_token.is_empty(): return _fail(&"caption_session_uninitialized")
	if session_token != _session_token: return _fail(&"caption_foreign_session")
	for beat: Dictionary in _registered.values():
		if beat.owning_entry_id == entry_id: return {"ok": true}
	return _fail(&"caption_entry_unregistered")

func publish_line(session_token: String, publication_id: String, entry_id: String, line_id: String) -> Dictionary:
	var session := check_session(session_token, entry_id)
	if not session.ok: return session
	if not _by_line.has(line_id): return _fail(&"caption_line_unregistered")
	var beat: Dictionary = _by_line[line_id]
	if beat.owning_entry_id != entry_id: return _fail(&"caption_line_foreign_entry")
	return publish_caption(session_token, publication_id, beat)

func publish_caption(session_token: String, publication_id: String, beat: Dictionary) -> Dictionary:
	if _session_token.is_empty(): return _fail(&"caption_session_uninitialized")
	if session_token != _session_token: return _fail(&"caption_foreign_session")
	if publication_id.strip_edges().is_empty(): return _fail(&"caption_publication_invalid")
	if not REGISTRY.valid_beat(beat): return _fail(&"caption_registration_invalid")
	if _published.has(publication_id):
		var previous: Dictionary = _published[publication_id]
		if previous.beat != beat: return _fail(&"caption_publication_conflict")
		return {"ok": true, "value": {"duplicate": true, "ordinal": previous.ordinal}}
	if not _registered.has(beat.beat_id): return _fail(&"caption_beat_unregistered")
	if _registered[beat.beat_id] != beat: return _fail(&"caption_registration_mismatch")
	var admitted: Dictionary = _registered[beat.beat_id]
	_sequence.append({"publication_id": publication_id, "beat": admitted})
	_published[publication_id] = {"beat": admitted, "ordinal": _sequence.size() - 1}
	return {"ok": true, "value": {"duplicate": false, "ordinal": _sequence.size() - 1}}

func snapshot() -> Dictionary:
	return {"session_token": _session_token, "frozen_context": _frozen_context.duplicate(true),
		"captions": _sequence.duplicate(true)}

func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size(): return false
	for key: Variant in value:
		if not key is String or not fields.has(key): return false
	return true

func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
