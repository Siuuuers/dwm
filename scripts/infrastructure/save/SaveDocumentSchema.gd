class_name SaveDocumentSchema
extends RefCounted

## Discriminated save-document union
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 4; v4 desktop durability,
## Plan 02 Task 6, dwm-p2r.32).
##
## `DOCUMENT_VERSION` and `RunSnapshotSchema.SCHEMA_VERSION` are pinned to the same current integer and
## independently enforced -- this document validator and its delegate `_validate_bundle()` ->
## `RunSnapshotSchema.validate()` -- so a document/embedded-snapshot version mismatch can never both
## pass: whichever one carries the wrong integer is rejected by its own owning check.

const DOCUMENT_VERSION := 6

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

const DOCUMENT_KEYS: Array[String] = [
	"current_snapshot", "kind", "recovery_journal", "save_reason", "schema_version", "slot_id",
]
# Every CheckpointJournal-accepted kind may be the persisted current bundle.
const CHECKPOINT_KINDS: Array[String] = [
	"line", "day_start", "timeline_start", "timeline_complete", "choice",
	"variable_transaction", "effect_transaction", "safe_marker", "scene_transition",
	"pre_board", "post_result", "day_resolution_stage", "manual_save",
]
const AUTOSAVE_REASONS: Array[String] = ["automatic", "day_start", "ending", "pre_board", "logout"]
const MIN_SLOT := 1
const MAX_SLOT := 7

static func build(
		kind: StringName,
		slot_id: Variant,
		save_reason: StringName,
		current_bundle: Dictionary,
		journal: Array,
		saved_time: Dictionary = {}
) -> Dictionary:
	var discriminator_error := _validate_discriminators(String(kind), slot_id, String(save_reason))
	if discriminator_error != "":
		return _fail(&"invalid_discriminator", discriminator_error)
	# Only the internal builder converts immutable engine text; external validation stays strict.
	current_bundle = _normalize_engine_text(current_bundle)
	journal = _normalize_engine_text(journal)
	var bundle_error := _validate_bundle(current_bundle)
	if not bundle_error.get("ok", false):
		return bundle_error
	var journal_error := _validate_journal(journal)
	if journal_error != "":
		return _fail(&"invalid_recovery_journal", journal_error)
	# The builder already proved its discriminators, current bundle and journal above. Its fixed
	# envelope cannot gain unknown members; only optional metadata remains to check. So normalize
	# each member AS the document is composed, in the same member order, and pass the current
	# bundle's candidate through UNTOUCHED: it came from `_validate_bundle()` ->
	# `RunSnapshotSchema.validate()`, which already normalized it, and `_normalize_integral_floats()`
	# is idempotent -- so the whole-document walk that used to run here rebuilt the entire saved
	# board a second time to reproduce it exactly. That candidate is a tree `RunSnapshotSchema`
	# freshly allocated and nothing else retains, so the document owns it outright and stays
	# detached from the caller's bundle, exactly as `_validate_document()` composes it.
	# `schema_version`, `kind` and `save_reason` are int/String literals and `checkpoint_kind` is
	# `str()`-ed, so only `slot_id`, the journal and the optional metadata can carry an integral
	# float. `saved_time` is still normalized BEFORE `validate_saved_time()` reads it below, and
	# the journal is still rebuilt untyped and detached by `_normalize_integral_floats()` itself,
	# which allocates a fresh Dictionary/Array at every container node: the `duplicate(true)`
	# that used to precede it copied the whole retained history a second time per save.
	var document := {
		"schema_version": DOCUMENT_VERSION,
		"kind": String(kind),
		"slot_id": RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(slot_id),
		"save_reason": String(save_reason),
		"current_snapshot": {
			"checkpoint_kind": str(current_bundle["checkpoint_kind"]),
			"snapshot": bundle_error["value"]["candidate"],
		},
		"recovery_journal": RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(journal),
	}
	if not saved_time.is_empty():
		document["saved_time"] = RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(
			saved_time.duplicate(true))
	if document.has("saved_time") and not validate_saved_time(document["saved_time"]):
		return _fail(&"invalid_saved_time", "saved_time must bind a UTC instant, original offset, and frozen HH:MM")
	return {"ok": true, "code": &"ok", "value": document}

static func validate(document: Dictionary) -> Dictionary:
	return _validate_document(document, [], false)

## `validate()` for an outgoing document whose `recovery_journal` bytes are NOT being emitted from
## the document itself. The checkpoint port splices each journal entry's bytes from the text its own
## commit proved for that bundle, so the candidate this returns -- the storage lease for those exact
## bytes -- must be composed from the bundles those texts belong to, never from the in-memory journal
## the caller still holds and may have edited since prepare. Every other check runs where it ran in
## `validate()`, in the same order, over the same document.
##
## The caller's obligation, which only it can discharge: `proven_journal[k]` is the bundle whose
## already-proved canonical text becomes `recovery_journal[k]` in the bytes being written.
##
## Equivalence obligations for the composed entries (why no further normalization is needed):
## - `RunSnapshotSchema._normalize_integral_floats()` is the IDENTITY over them. Every retained
##   bundle's `snapshot` is a `RunSnapshotSchema.validate()` candidate, i.e. that normalizer's own
##   output, and it is idempotent; `checkpoint_kind` is a String; `_normalize_engine_text()` below
##   converts StringNames only and can introduce no float.
## - `_normalize_engine_text()` IS applied, because a validate candidate is not StringName-free: the
##   normalizer that produced it converts integral floats only, so engine text (a desktop pending
##   stage, an active_app_id) survives into it, and `build()` is what converted it when those bytes
##   were written. It is identity-preserving, so a bundle with no StringName costs no allocation.
## - The composed Array is deliberately UNTYPED, exactly as `_normalize_integral_floats()` rebuilds
##   every Array: a proven journal handed in as `Array[Dictionary]` must not leak its typedness into
##   a candidate that is supposed to match a strict re-parse of JSON.
static func validate_outgoing(document: Dictionary, proven_journal: Array) -> Dictionary:
	return _validate_document(document, proven_journal, true)

static func _validate_document(document: Dictionary, proven_journal: Array,
		use_proven_journal: bool) -> Dictionary:
	# Normalize each envelope member, and NEVER the current bundle: its `snapshot` is rebuilt by
	# `_validate_bundle()` -> `RunSnapshotSchema.validate()`, which normalizes it itself, and that
	# candidate overwrites whatever a whole-document walk would have produced here. The caller's
	# document is not deep-copied first either: `_normalize_integral_floats()` allocates a FRESH
	# Dictionary/Array at every container node, so a prior `duplicate(true)` rebuilt the same tree
	# twice. The leaves the normalizer passes through by reference rather than copying (Packed
	# arrays, Objects) can never reach a saved document: `RunSnapshotSchema.validate_primitive_tree()`
	# refuses them with `invalid_primitive` and `CanonicalJsonWriter._emit()` with `unsupported_type`.
	# Member order and refusal order are unchanged: this loop preserves the document's own key
	# order, and every check below still runs where it ran before.
	var candidate := {}
	for key: Variant in document:
		if key == "current_snapshot":
			candidate[key] = document[key]
		else:
			candidate[key] = RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(document[key])
	var keys: Array = candidate.keys()
	keys.sort()
	var expected := DOCUMENT_KEYS.duplicate()
	if candidate.has("saved_time"):
		expected.append("saved_time")
	expected.sort()
	if keys != Array(expected):
		return _fail(&"invalid_document_shape", "unexpected document keys: " + str(keys))
	if candidate.has("saved_time") and not validate_saved_time(candidate["saved_time"]):
		return _fail(&"invalid_saved_time", "saved_time must bind a UTC instant, original offset, and frozen HH:MM")
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
	var current_bundle: Dictionary = candidate["current_snapshot"]
	var bundle_result := _validate_bundle(current_bundle)
	if not bundle_result.get("ok", false):
		return bundle_result
	# `_validate_bundle()` proved this bundle holds exactly `checkpoint_kind` and `snapshot`, so
	# compose the candidate's bundle from those two proven parts rather than mutating the caller's
	# container. `checkpoint_kind` is a scalar and still goes through the normalizer, so its value
	# and type are exactly what the whole-document walk produced.
	candidate["current_snapshot"] = {
		"checkpoint_kind": RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(
			current_bundle["checkpoint_kind"]),
		"snapshot": bundle_result["value"]["candidate"],
	}
	if typeof(candidate["recovery_journal"]) != TYPE_ARRAY:
		return _fail(&"invalid_document_shape", "recovery_journal must be an array")
	if use_proven_journal:
		# The document's own entries are not validated here because they are not what is being
		# written: the caller's proven bundles are, one per entry, in this order. See
		# `validate_outgoing()` for the obligation that carries and the equivalence it rests on.
		var composed: Array = []
		for bundle: Variant in proven_journal:
			composed.append(_normalize_engine_text(bundle))
		candidate["recovery_journal"] = composed
		return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}
	var journal_error := _validate_journal(candidate["recovery_journal"])
	if journal_error != "":
		return _fail(&"invalid_recovery_journal", journal_error)
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

static func prepare_candidate(document: Dictionary) -> Dictionary:
	return validate(document)

## Optional outer metadata; absence means legacy time unknown, never current wall time.
static func validate_saved_time(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var keys: Array = value.keys()
	keys.sort()
	if keys != ["hhmm", "unix_seconds", "utc_offset_minutes"]:
		return false
	if typeof(value["unix_seconds"]) != TYPE_INT or int(value["unix_seconds"]) < 0 \
			or int(value["unix_seconds"]) > 253402300799 \
			or typeof(value["utc_offset_minutes"]) != TYPE_INT \
			or absi(int(value["utc_offset_minutes"])) > 14 * 60 \
			or typeof(value["hhmm"]) != TYPE_STRING:
		return false
	var local_seconds := int(value["unix_seconds"]) + int(value["utc_offset_minutes"]) * 60
	var clock := Time.get_datetime_dict_from_unix_time(local_seconds)
	return str(value["hhmm"]) == "%02d:%02d" % [clock["hour"], clock["minute"]]

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


## Identity-preserving: a subtree that holds no StringName is returned AS IS, so the common
## StringName-free build allocates nothing here. Exact mirror of
## `SaveManagerCheckpointPort._normalize_json_string_types()`. Detachment is unaffected --
## `build()` replaces the bundle with `_validate_bundle()`'s own candidate and still detaches
## the journal when it composes the document -- so the persisted document never aliases an input.
static func _normalize_engine_text(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME: return String(value)
		TYPE_ARRAY:
			var source_array: Array = value
			var array: Array = []
			var array_converted := false
			for element: Variant in source_array:
				var normalized_element: Variant = _normalize_engine_text(element)
				if not is_same(normalized_element, element):
					array_converted = true
				array.append(normalized_element)
			return array if array_converted else source_array
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			var dictionary := {}
			var dictionary_converted := false
			for raw_key: Variant in source_dictionary:
				var key: Variant = String(raw_key) if typeof(raw_key) == TYPE_STRING_NAME else raw_key
				if not is_same(key, raw_key):
					dictionary_converted = true
				var member: Variant = source_dictionary[raw_key]
				var normalized_member: Variant = _normalize_engine_text(member)
				if not is_same(normalized_member, member):
					dictionary_converted = true
				dictionary[key] = normalized_member
			return dictionary if dictionary_converted else source_dictionary
	return value
