class_name NarrativeCaptionLedger
extends RefCounted
## Live internal prerequisite for semantic History, not a durable save or visited
## receipt. Semantic identity comes from registrations; opaque publication IDs
## distinguish occurrences. Repeated delivery of one publication is idempotent.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const REGISTRY := preload("res://scripts/narrative/NarrativeCaptionRegistry.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

var _scene := false

var _session_token := ""
var _frozen_context: Dictionary = {}
var _entry_contexts_required := false
var _entry_contexts: Dictionary = {}
var _registered: Dictionary = {}
var _by_line: Dictionary = {}
var _published: Dictionary = {}
var _sequence: Array[Dictionary] = []
var _publication_serial := 0

func initialize(session_token: String, frozen_context: Dictionary,
		entry_manifest: Dictionary, registry: Dictionary, entry_contexts_required: bool = false,
		scene: bool = false) -> Dictionary:
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
	_scene = scene
	_entry_contexts_required = entry_contexts_required or scene
	for beat: Dictionary in checked.value.beats:
		FROZEN._freeze(beat)
		_registered[beat.beat_id] = beat
		_by_line[beat.line_id] = beat
	return {"ok": true}

## Opt-in frames arrive at their causal entry boundary, not at session creation.
## Legacy families retain one immutable frame per entry. Scene frames are keyed
## by the admitted occurrence and entry, so re-entry does not overwrite History.
## The caller owns canonical admission; representation checks here do not
## authenticate a receipt or authorize a traversal.
func admit_entry_context(session_token: String, entry_id: String, context: Dictionary,
		occurrence_id: String = "") -> Dictionary:
	if _session_token.is_empty(): return _fail(&"caption_session_uninitialized")
	if session_token != _session_token: return _fail(&"caption_foreign_session")
	if not _entry_contexts_required: return _fail(&"caption_entry_contexts_disabled")
	if not _has_registered_entry(entry_id): return _fail(&"caption_entry_unregistered")
	if context.is_empty() or not FROZEN._primitive(context): return _fail(&"caption_entry_context_invalid")
	var key := entry_id
	if _scene:
		if not valid_scene_frame(context, occurrence_id, entry_id):
			return _fail(&"caption_entry_context_invalid")
		key = scene_frame_key(occurrence_id, entry_id)
	elif not occurrence_id.is_empty():
		return _fail(&"caption_entry_context_invalid")
	if _entry_contexts.has(key):
		if _entry_contexts[key] != context: return _fail(&"caption_entry_context_conflict")
		return {"ok": true}
	var detached := context.duplicate(true)
	FROZEN._freeze(detached)
	_entry_contexts[key] = detached
	return {"ok": true}

## Rebuild only this internal sequence. The canonical owner must independently
## admit the context/catalog; this does not read or migrate a Run save. Validate
## the complete candidate before installing any state, including a valid prefix.
func restore_snapshot(session_token: String, frozen_context: Dictionary,
		entry_manifest: Dictionary, registry: Dictionary, saved: Dictionary,
		entry_contexts: Dictionary = {}, entry_contexts_required: bool = false,
		scene: bool = false) -> Dictionary:
	if not _session_token.is_empty(): return _fail(&"caption_session_already_initialized")
	if scene or saved.has("schema_version"):
		return _restore_scene_snapshot(session_token, frozen_context, entry_manifest, registry,
			saved, entry_contexts)
	# The caller pins the mode even before the first entry is admitted. Saved
	# field removal must not turn an empty framed session into an unguarded one.
	var framed := entry_contexts_required
	if saved.has("entry_contexts") != framed: return _fail(&"caption_entry_context_mismatch")
	var fields := ["session_token", "frozen_context", "captions"]
	if framed: fields.append("entry_contexts")
	if not _has_exact_fields(saved, fields) \
			or not saved.session_token is String \
			or not saved.frozen_context is Dictionary or not saved.captions is Array:
		return _fail(&"caption_snapshot_invalid")
	# Preserve the existing component-root depth contract. Snapshot wrappers do
	# not consume context/signature depth admitted by initialize/valid_beat.
	if not FROZEN._primitive(saved.frozen_context): return _fail(&"caption_snapshot_invalid")
	if saved.session_token != session_token: return _fail(&"caption_foreign_session")
	if saved.frozen_context != frozen_context: return _fail(&"caption_context_mismatch")
	if framed:
		if not saved.entry_contexts is Dictionary: return _fail(&"caption_snapshot_invalid")
		for entry_id: Variant in saved.entry_contexts:
			if not entry_id is String or not saved.entry_contexts[entry_id] is Dictionary \
					or not FROZEN._primitive(saved.entry_contexts[entry_id]):
				return _fail(&"caption_entry_context_invalid")
		if saved.entry_contexts != entry_contexts: return _fail(&"caption_entry_context_mismatch")
	elif not entry_contexts.is_empty():
		return _fail(&"caption_entry_context_mismatch")
	var candidate := NarrativeCaptionLedger.new()
	var initialized := candidate.initialize(session_token, frozen_context, entry_manifest, registry, framed)
	if not initialized.ok: return initialized
	for entry_id: Variant in entry_contexts:
		if not entry_id is String or not entry_contexts[entry_id] is Dictionary:
			return _fail(&"caption_entry_context_invalid")
		var admitted := candidate.admit_entry_context(session_token, entry_id, entry_contexts[entry_id])
		if not admitted.ok: return admitted
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
	_entry_contexts_required = candidate._entry_contexts_required
	_entry_contexts = candidate._entry_contexts
	_registered = candidate._registered
	_by_line = candidate._by_line
	_published = candidate._published
	_sequence = candidate._sequence
	_publication_serial = _sequence.size()
	return {"ok": true}

## Occurrences belong to the retained session, not a reusable Godot instance ID.
## Unpublished allocations are transient; reconstruction skips every retained ID.
func allocate_publication(session_token: String, entry_id: String, occurrence_id: String = "") -> Dictionary:
	var checked := check_session(session_token, entry_id, occurrence_id)
	if not checked.ok: return checked
	_publication_serial += 1
	var publication_id := "caption:%d" % _publication_serial
	while _published.has(publication_id):
		_publication_serial += 1
		publication_id = "caption:%d" % _publication_serial
	return {"ok": true, "value": publication_id}

func check_session(session_token: String, entry_id: String, occurrence_id: String = "") -> Dictionary:
	if _session_token.is_empty(): return _fail(&"caption_session_uninitialized")
	if session_token != _session_token: return _fail(&"caption_foreign_session")
	if not _has_registered_entry(entry_id): return _fail(&"caption_entry_unregistered")
	if _scene:
		return resolve_scene_frame(_entry_contexts, occurrence_id, entry_id)
	if not occurrence_id.is_empty(): return _fail(&"caption_entry_context_invalid")
	if _entry_contexts_required and not _entry_contexts.has(entry_id):
		return _fail(&"caption_entry_context_missing")
	return {"ok": true}

func _has_registered_entry(entry_id: String) -> bool:
	for beat: Dictionary in _registered.values():
		if beat.owning_entry_id == entry_id: return true
	return false

func publish_line(session_token: String, publication_id: String, entry_id: String, line_id: String,
		occurrence_id: String = "") -> Dictionary:
	var session := check_session(session_token, entry_id, occurrence_id)
	if not session.ok: return session
	if not _by_line.has(line_id): return _fail(&"caption_line_unregistered")
	var beat: Dictionary = _by_line[line_id]
	if beat.owning_entry_id != entry_id: return _fail(&"caption_line_foreign_entry")
	return publish_caption(session_token, publication_id, beat, occurrence_id)

func publish_caption(session_token: String, publication_id: String, beat: Dictionary,
		occurrence_id: String = "") -> Dictionary:
	if _session_token.is_empty(): return _fail(&"caption_session_uninitialized")
	if session_token != _session_token: return _fail(&"caption_foreign_session")
	if publication_id.strip_edges().is_empty(): return _fail(&"caption_publication_invalid")
	if not REGISTRY.valid_beat(beat): return _fail(&"caption_registration_invalid")
	if _published.has(publication_id):
		var previous: Dictionary = _published[publication_id]
		if previous.beat != beat: return _fail(&"caption_publication_conflict")
		if str(previous.get("occurrence_id", "")) != occurrence_id:
			return _fail(&"caption_publication_conflict")
		return {"ok": true, "value": {"duplicate": true, "ordinal": previous.ordinal}}
	if not _registered.has(beat.beat_id): return _fail(&"caption_beat_unregistered")
	if _registered[beat.beat_id] != beat: return _fail(&"caption_registration_mismatch")
	var session := check_session(session_token, beat.owning_entry_id, occurrence_id)
	if not session.ok: return session
	var admitted: Dictionary = _registered[beat.beat_id]
	var row := {"publication_id": publication_id, "beat": admitted}
	var publication := {"beat": admitted, "ordinal": _sequence.size()}
	if _scene:
		row["occurrence_id"] = occurrence_id
		publication["occurrence_id"] = occurrence_id
	_sequence.append(row)
	_published[publication_id] = publication
	return {"ok": true, "value": {"duplicate": false, "ordinal": _sequence.size() - 1}}

## A hot presentation admission check must not copy the retained History or
## scan the catalogue. The published tail already proves registration ownership.
func is_current_occurrence(session_token: String, entry_id: String, frontier: Dictionary,
		occurrence_id: String = "") -> bool:
	if _session_token.is_empty() or session_token != _session_token or _sequence.is_empty() \
			or not _has_exact_fields(frontier, ["line_id", "publication_id"]) \
			or not frontier.line_id is String or frontier.line_id.is_empty() \
			or not frontier.publication_id is String or frontier.publication_id.is_empty() \
			or (_entry_contexts_required and not _entry_contexts.has(
				scene_frame_key(occurrence_id, entry_id) if _scene else entry_id)):
		return false
	if not _scene and not occurrence_id.is_empty(): return false
	var last: Dictionary = _sequence.back()
	return last.publication_id == frontier.publication_id and last.beat.line_id == frontier.line_id \
		and last.beat.owning_entry_id == entry_id and str(last.get("occurrence_id", "")) == occurrence_id

func snapshot() -> Dictionary:
	var result := {"session_token": _session_token, "frozen_context": _frozen_context.duplicate(true),
		"captions": _sequence.duplicate(true)}
	# Keep the original opt-in format for callers without per-entry frames. The
	# beat's owning_entry_id binds each occurrence to its one admitted frame.
	if _entry_contexts_required: result["entry_contexts"] = _entry_contexts.duplicate(true)
	if _scene: result["schema_version"] = 2
	return result

## These helpers validate representation, not issuer authority. The reading/save
## owner supplies independently authenticated frames before ledger admission.
static func scene_frame_key(occurrence_id: String, entry_id: String) -> String:
	if occurrence_id.strip_edges().is_empty() or entry_id.strip_edges().is_empty(): return ""
	var encoded := CANONICAL_JSON.stringify([occurrence_id, entry_id])
	return str(encoded.value) if encoded.get("ok", false) else ""

static func decode_scene_frame_key(key: String) -> Dictionary:
	var decoded := STRICT_JSON._parse_value_document(key)
	if not decoded.get("ok", false) or not decoded.value is Array or decoded.value.size() != 2:
		return {"ok": false, "code": &"caption_entry_context_invalid"}
	var pair: Array = decoded.value
	if not pair[0] is String or not pair[1] is String \
			or scene_frame_key(pair[0], pair[1]) != key or key.is_empty():
		return {"ok": false, "code": &"caption_entry_context_invalid"}
	return {"ok": true, "value": {"occurrence_id": pair[0], "entry_id": pair[1]}}

static func valid_scene_frame(frame: Dictionary, occurrence_id: String, entry_id: String) -> bool:
	if scene_frame_key(occurrence_id, entry_id).is_empty() \
			or not _has_exact_fields(frame, ["expected_stage", "playback_id", "role", "transaction_id", "presentation"]) \
			or frame.expected_stage != "scene" or frame.role != "scene" \
			or frame.playback_id != occurrence_id or not frame.transaction_id is String \
			or frame.transaction_id.strip_edges().is_empty() or not frame.presentation is Dictionary:
		return false
	var presentation: Dictionary = frame.presentation
	if not _has_exact_fields(presentation, ["schema_id", "schema_version", "fields"]) \
			or not presentation.schema_id is String or presentation.schema_id != "context.scene.%s.v1" % entry_id \
			or not presentation.schema_version is int or presentation.schema_version != 1 \
			or not presentation.fields is Dictionary:
		return false
	var fields: Dictionary = presentation.fields
	return _has_exact_fields(fields, ["entry_id", "entry_role", "occurrence_id", "admission_receipt_id"]) \
		and fields.entry_id == entry_id and fields.entry_role == "scene" \
		and fields.occurrence_id == occurrence_id and fields.admission_receipt_id is String \
		and not fields.admission_receipt_id.strip_edges().is_empty() and FROZEN._primitive(frame)

static func resolve_scene_frame(frames: Dictionary, occurrence_id: String, entry_id: String) -> Dictionary:
	var key := scene_frame_key(occurrence_id, entry_id)
	if key.is_empty() or not frames.has(key):
		return {"ok": false, "code": &"caption_entry_context_missing"}
	if not frames[key] is Dictionary or not valid_scene_frame(frames[key], occurrence_id, entry_id):
		return {"ok": false, "code": &"caption_entry_context_invalid"}
	return {"ok": true, "value": frames[key].duplicate(true)}

func _restore_scene_snapshot(session_token: String, frozen_context: Dictionary,
		entry_manifest: Dictionary, registry: Dictionary, saved: Dictionary,
		entry_contexts: Dictionary) -> Dictionary:
	if not _has_exact_fields(saved, ["schema_version", "session_token", "frozen_context", "entry_contexts", "captions"]) \
			or not saved.schema_version is int or saved.schema_version != 2 \
			or not saved.session_token is String or not saved.frozen_context is Dictionary \
			or not saved.entry_contexts is Dictionary or not saved.captions is Array:
		return _fail(&"caption_snapshot_invalid")
	if saved.session_token != session_token: return _fail(&"caption_foreign_session")
	if saved.frozen_context != frozen_context: return _fail(&"caption_context_mismatch")
	if saved.entry_contexts != entry_contexts: return _fail(&"caption_entry_context_mismatch")
	var candidate := NarrativeCaptionLedger.new()
	var initialized := candidate.initialize(session_token, frozen_context, entry_manifest, registry, true, true)
	if not initialized.ok: return initialized
	for key: Variant in entry_contexts:
		if not key is String or not entry_contexts[key] is Dictionary:
			return _fail(&"caption_entry_context_invalid")
		var decoded := decode_scene_frame_key(key)
		if not decoded.ok: return decoded
		var admitted := candidate.admit_entry_context(session_token, decoded.value.entry_id,
			entry_contexts[key], decoded.value.occurrence_id)
		if not admitted.ok: return admitted
	for row: Variant in saved.captions:
		if not row is Dictionary or not _has_exact_fields(row, ["publication_id", "occurrence_id", "beat"]) \
				or not row.publication_id is String or not row.occurrence_id is String or not row.beat is Dictionary:
			return _fail(&"caption_snapshot_invalid")
		var published := candidate.publish_caption(session_token, row.publication_id, row.beat, row.occurrence_id)
		if not published.ok: return published
		if published.value["duplicate"]: return _fail(&"caption_snapshot_duplicate")
	_scene = true
	_session_token = candidate._session_token
	_frozen_context = candidate._frozen_context
	_entry_contexts_required = true
	_entry_contexts = candidate._entry_contexts
	_registered = candidate._registered
	_by_line = candidate._by_line
	_published = candidate._published
	_sequence = candidate._sequence
	_publication_serial = _sequence.size()
	return {"ok": true}

static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size(): return false
	for key: Variant in value:
		if not key is String or not fields.has(key): return false
	return true

func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}

