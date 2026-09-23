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

func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
