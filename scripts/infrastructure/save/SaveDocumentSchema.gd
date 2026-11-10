class_name SaveDocumentSchema
extends RefCounted

const DOCUMENT_VERSION := 9
const SCENE_DOCUMENT_VERSION := DOCUMENT_VERSION

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

const DOCUMENT_KEYS := SCENE_DOCUMENT_KEYS
const SCENE_DOCUMENT_KEYS: Array[String] = [
	"current_snapshot", "kind", "recovery_journal", "schema_version", "slot_id",
]
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
		saved_time: Dictionary = {},
		proven_journal: Array = [],
		profile: Dictionary = {},
		proven_current_snapshot: Dictionary = {}
) -> Dictionary:
	var tick := Time.get_ticks_usec() if not profile.is_empty() else 0
	var discriminator_error := _validate_discriminators(String(kind), slot_id, String(save_reason))
	tick = _profile_phase(profile, "document_schema_discriminators_us", tick)
	if discriminator_error != "":
		return _fail(&"invalid_discriminator", discriminator_error)
	var proven := _journal_is_proven(journal, proven_journal)
	tick = _profile_phase(profile, "document_schema_proof_selection_us", tick)
	if not profile.is_empty(): profile["document_schema_journal_proven"] = proven
	var current_proven := not proven_current_snapshot.is_empty() \
		and is_same(current_bundle.get("snapshot"), proven_current_snapshot)
	current_bundle = current_bundle.duplicate(true) if current_proven else _normalize_engine_text(current_bundle)
	tick = _profile_phase(profile, "document_schema_normalize_current_us", tick)
	if not proven:
		journal = _normalize_engine_text(journal)
	tick = _profile_phase(profile, "document_schema_normalize_journal_us", tick)
	var bundle_error := _validate_bundle(current_bundle, current_bundle.get("snapshot", {}) if current_proven else {})
	tick = _profile_phase(profile, "document_schema_validate_current_us", tick)
	if not bundle_error.get("ok", false):
		return bundle_error
	if not proven:
		var journal_error := _validate_journal(journal)
		if journal_error != "":
			_profile_phase(profile, "document_schema_validate_journal_us", tick)
			return _fail(&"invalid_recovery_journal", journal_error)
	tick = _profile_phase(profile, "document_schema_validate_journal_us", tick)
	var document := {
		"schema_version": SCENE_DOCUMENT_VERSION,
		"kind": String(kind),
		"slot_id": RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(slot_id),
		"current_snapshot": {
			"checkpoint_kind": str(current_bundle["checkpoint_kind"]),
			"snapshot": bundle_error["value"]["candidate"],
		},
		"recovery_journal": (_profile_compose_build_journal(journal, proven_journal, proven, profile)),
	}
	tick = _profile_phase(profile, "document_schema_compose_us", tick)
	if proven:
		var proof_tick := Time.get_ticks_usec() if not profile.is_empty() else 0
		var proof_error := _scene_proof_error(journal, proven_journal)
		_profile_phase(profile, "document_schema_proof_equality_us", proof_tick)
		if not proof_error.is_empty(): return _fail(&"invalid_recovery_journal", proof_error)
	var scene_error := _profile_scene_journal_error(document.current_snapshot, document.recovery_journal, profile, "document_schema")
	if not scene_error.is_empty(): return _fail(&"invalid_recovery_journal", scene_error)
	var display_time := normalize_optional_saved_time(saved_time)
	if not display_time.is_empty(): document["saved_time"] = display_time
	if document.has("saved_time") and not validate_saved_time(document["saved_time"]):
		_profile_phase(profile, "document_schema_metadata_us", tick)
		return _fail(&"invalid_saved_time", "saved_time must bind a UTC instant, original offset, and frozen HH:MM")
	_profile_phase(profile, "document_schema_metadata_us", tick)
	return {"ok": true, "code": &"ok", "value": document}

static func validate_scene_new_run_candidate(document: Dictionary, allocation_candidate: Dictionary,
		profile_material: Dictionary, bundle: Dictionary, issuer: Object,
		acknowledged_checkpoint: Dictionary = {}) -> Dictionary:
	document = document.duplicate()
	document.erase("save_reason")
	document.erase("ink_marks")
	var display_time := normalize_optional_saved_time(document.get("saved_time"))
	document.erase("saved_time")
	if not display_time.is_empty(): document["saved_time"] = display_time
	var primitive := RUN_SNAPSHOT_SCHEMA.validate_primitive_tree(document)
	if not primitive.ok: return primitive
	var expected := SCENE_DOCUMENT_KEYS.duplicate()
	if document.has("saved_time"): expected.append("saved_time")
	if not RUN_SNAPSHOT_SCHEMA._scene_keys(document, expected) \
			or typeof(document.schema_version) != TYPE_INT or document.schema_version != SCENE_DOCUMENT_VERSION \
			or document.kind != "autosave" or document.slot_id != null \
			or not document.recovery_journal is Array or not document.recovery_journal.is_empty():
		return _fail(&"invalid_document_shape", "initial Save9 requires Autosave and empty recovery")
	var current: Variant = document.current_snapshot
	if not RUN_SNAPSHOT_SCHEMA._scene_keys(current, ["checkpoint_kind", "snapshot"]) \
			or current.checkpoint_kind != "day_start" or not current.snapshot is Dictionary:
		return _fail(&"invalid_bundle_shape", "initial bundle must be day_start")
	var checked := RUN_SNAPSHOT_SCHEMA.validate_scene_new_run_candidate(current.snapshot,
		allocation_candidate, profile_material, bundle, issuer, acknowledged_checkpoint)
	if not checked.ok: return checked
	var candidate := document.duplicate(true)
	candidate.current_snapshot.snapshot = checked.value.candidate
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

static func validate(document: Dictionary, profile: Dictionary = {},
		scene_seed_receiver: Callable = Callable()) -> Dictionary:
	return _validate_document(document, [], false, profile, false, scene_seed_receiver)

static func validate_outgoing(document: Dictionary, proven_journal: Array,
		profile: Dictionary = {}) -> Dictionary:
	return _validate_document(document, proven_journal, true, profile)

static func _validate_outgoing_document_proofs(document: Dictionary, proven_journal: Array,
		proven_documents: Array, profile: Dictionary = {}) -> Dictionary:
	if _journal_is_proven(proven_journal, proven_documents):
		return _validate_document(document, proven_documents, true, profile, true)
	return validate_outgoing(document, proven_journal, profile)

static func _validate_document(document: Dictionary, proven_journal: Array,
		use_proven_journal: bool, profile: Dictionary = {}, normalized_proofs: bool = false,
		scene_seed_receiver: Callable = Callable()) -> Dictionary:
	var type_guard := _validate_initial_types_before_normalization(document)
	if not type_guard.ok: return type_guard
	if use_proven_journal:
		for proof: Variant in proven_journal:
			var proof_guard := _validate_initial_types_before_normalization({
				"schema_version": document.get("schema_version"), "current_snapshot": proof})
			if not proof_guard.ok: return proof_guard
	var tick := Time.get_ticks_usec() if not profile.is_empty() else 0
	var candidate := {}
	for key: Variant in document:
		if key == "ink_marks": continue
		if key == "save_reason": continue
		if key == "saved_time":
			var display_time := normalize_optional_saved_time(document[key])
			if not display_time.is_empty(): candidate[key] = display_time
			continue
		if key == "current_snapshot" or (use_proven_journal and key == "recovery_journal"):
			candidate[key] = document[key]
		else:
			candidate[key] = RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(document[key])
	tick = _profile_phase(profile, "outgoing_schema_envelope_normalize_us", tick)
	var keys: Array = candidate.keys()
	keys.sort()
	var expected := SCENE_DOCUMENT_KEYS.duplicate()
	if candidate.has("saved_time"):
		expected.append("saved_time")
	expected.sort()
	if keys != Array(expected):
		return _fail(&"invalid_document_shape", "unexpected document keys: " + str(keys))
	if candidate.has("saved_time") and not validate_saved_time(candidate["saved_time"]):
		return _fail(&"invalid_saved_time", "saved_time must bind a UTC instant, original offset, and frozen HH:MM")
	if typeof(candidate["schema_version"]) != TYPE_INT:
		return _fail(&"invalid_document_shape", "schema_version must be an integer")
	if int(candidate["schema_version"]) > SCENE_DOCUMENT_VERSION:
		return _fail(&"unsupported_schema_version", str(candidate["schema_version"]))
	if int(candidate["schema_version"]) != SCENE_DOCUMENT_VERSION:
		return _fail(&"invalid_document_shape", "schema_version must be %d" % DOCUMENT_VERSION)
	var discriminator_error := _validate_locator(str(candidate["kind"]), candidate["slot_id"])
	if discriminator_error != "":
		return _fail(&"invalid_discriminator", discriminator_error)
	if typeof(candidate["current_snapshot"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_document_shape", "current_snapshot must be an object")
	tick = _profile_phase(profile, "outgoing_schema_shape_us", tick)
	var current_bundle: Dictionary = candidate["current_snapshot"]
	var bundle_result := _validate_bundle(current_bundle)
	tick = _profile_phase(profile, "outgoing_schema_validate_current_us", tick)
	if not bundle_result.get("ok", false):
		return bundle_result
	if bundle_result.value.candidate.schema_version != candidate.schema_version:
		return _fail(&"invalid_document_shape", "Save and Run versions must agree")
	candidate["current_snapshot"] = {
		"checkpoint_kind": RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(
			current_bundle["checkpoint_kind"]),
		"snapshot": bundle_result["value"]["candidate"],
	}
	if typeof(candidate["recovery_journal"]) != TYPE_ARRAY:
		return _fail(&"invalid_document_shape", "recovery_journal must be an array")
	tick = _profile_phase(profile, "outgoing_schema_compose_current_us", tick)
	if use_proven_journal:
		var proof_tick := Time.get_ticks_usec() if not profile.is_empty() else 0
		var proof_error := _scene_proof_error(candidate.recovery_journal, proven_journal)
		_profile_phase(profile, "outgoing_schema_proof_equality_us", proof_tick)
		if not proof_error.is_empty(): return _fail(&"invalid_recovery_journal", proof_error)
		var composition_tick := Time.get_ticks_usec() if not profile.is_empty() else 0
		var composed: Array = []
		if normalized_proofs:
			composed = _proven_entries(proven_journal)
		else:
			for bundle: Variant in proven_journal:
				composed.append(_normalize_engine_text(bundle))
		candidate["recovery_journal"] = composed
		_profile_phase(profile, "outgoing_schema_journal_composition_us", composition_tick)
		var scene_error := _profile_scene_journal_error(candidate.current_snapshot, composed, profile, "outgoing_schema")
		if not scene_error.is_empty(): return _fail(&"invalid_recovery_journal", scene_error)
		_profile_phase(profile, "outgoing_schema_compose_proven_journal_us", tick)
		return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}
	var journal_error := _validate_journal(candidate["recovery_journal"])
	_profile_phase(profile, "outgoing_schema_validate_journal_us", tick)
	if journal_error != "":
		return _fail(&"invalid_recovery_journal", journal_error)
	var admitted_bundles: Array = [candidate.current_snapshot]
	var scene_error := _scene_journal_error(candidate.current_snapshot, candidate.recovery_journal,
		{}, "", admitted_bundles if scene_seed_receiver.is_valid() else null)
	if not scene_error.is_empty(): return _fail(&"invalid_recovery_journal", scene_error)
	if scene_seed_receiver.is_valid():
		scene_seed_receiver.call(candidate.duplicate(true), admitted_bundles.duplicate(true))
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

static func _validate_initial_types_before_normalization(document: Dictionary) -> Dictionary:
	var bundles: Array = [document.get("current_snapshot")]
	if document.get("recovery_journal") is Array: bundles.append_array(document.recovery_journal)
	for bundle: Variant in bundles:
		if not bundle is Dictionary or not bundle.get("snapshot") is Dictionary: continue
		if not RUN_SNAPSHOT_SCHEMA._scene_has_initial_admission(bundle.snapshot): continue
		if typeof(document.get("schema_version")) != TYPE_INT:
			return _fail(&"scene_initial_types_invalid", "Scene Save header must retain exact types")
		var error := RUN_SNAPSHOT_SCHEMA._scene_initial_types_error(bundle.snapshot)
		if not error.is_empty(): return _fail(&"scene_initial_types_invalid", error)
	return {"ok": true}

static func _scene_journal_error(current: Dictionary, journal: Array,
		profile: Dictionary = {}, phase: String = "", admitted_bundles: Variant = null) -> String:
	var source: Dictionary = current.snapshot
	var seen := {source.checkpoint_id: true}
	for raw: Variant in journal:
		if not raw is Dictionary: return "scene journal bundle must be an object"
		var checked := _profile_validate_scene_journal_bundle(raw, profile, phase)
		if not checked.ok: return str(checked.get("code", "invalid scene journal bundle"))
		var saved: Dictionary = checked.value.candidate
		if saved.schema_version != SCENE_DOCUMENT_VERSION or saved.run_id != source.run_id \
				or saved.content_version != source.content_version:
			return "scene journal family/run/content mismatch"
		if saved.scene.registration_sha256 != source.scene.registration_sha256:
			return "scene journal registration mismatch"
		if seen.has(saved.checkpoint_id): return "duplicate scene checkpoint id"
		if saved.checkpoint_sequence >= source.checkpoint_sequence:
			return "scene recovery must precede the current checkpoint"
		seen[saved.checkpoint_id] = true
		if admitted_bundles != null:
			admitted_bundles.append({"checkpoint_kind": str(raw.checkpoint_kind), "snapshot": saved})
	return ""

static func _scene_proof_error(journal: Array, proofs: Array) -> String:
	if journal.size() != proofs.size(): return "scene journal proof count mismatch"
	for index: int in journal.size():
		var entry: Variant = RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(_normalize_engine_text(journal[index]))
		var proof: Variant = RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(_normalize_engine_text(proofs[index]))
		if not entry is Dictionary or not proof is Dictionary or entry != proof:
			return "scene journal proof does not match its bundle"
	return ""

static func _profile_compose_build_journal(journal: Array, proofs: Array, proven: bool,
		profile: Dictionary) -> Array:
	var started := Time.get_ticks_usec() if not profile.is_empty() else 0
	var composed: Array = (_proven_entries(proofs) if proven
		else RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(journal))
	_profile_phase(profile, "document_schema_journal_composition_us", started)
	return composed

static func _profile_scene_journal_error(current: Dictionary, journal: Array,
		profile: Dictionary, phase: String) -> String:
	if profile.is_empty(): return _scene_journal_error(current, journal)
	profile[phase + "_journal_inclusive_nested"] = true
	profile[phase + "_journal_entries"] = []
	profile[phase + "_journal_bundle_us"] = 0
	profile[phase + "_journal_input_count"] = journal.size()
	profile[phase + "_journal_current"] = _profile_bundle_labels(current)
	var started := Time.get_ticks_usec()
	var error := _scene_journal_error(current, journal, profile, phase)
	var elapsed := Time.get_ticks_usec() - started
	profile[phase + "_scene_journal_us"] = elapsed
	profile[phase + "_journal_checks_and_observation_us"] = elapsed - int(profile[phase + "_journal_bundle_us"])
	profile[phase + "_scene_journal_ok"] = error.is_empty()
	return error

static func _profile_validate_scene_journal_bundle(raw: Dictionary,
		profile: Dictionary, phase: String) -> Dictionary:
	if profile.is_empty(): return _validate_bundle(raw)
	var started := Time.get_ticks_usec()
	var checked := _validate_bundle(raw)
	var elapsed := Time.get_ticks_usec() - started
	var records: Array = profile[phase + "_journal_entries"]
	var record := _profile_bundle_labels(raw)
	record["ordinal"] = records.size()
	record["elapsed_us"] = elapsed
	record["ok"] = bool(checked.get("ok", false))
	records.append(record)
	profile[phase + "_journal_bundle_us"] = int(profile[phase + "_journal_bundle_us"]) + elapsed
	return checked

static func _profile_bundle_labels(raw: Dictionary) -> Dictionary:
	var record := {}
	var snapshot: Variant = raw.get("snapshot")
	if snapshot is Dictionary:
		if typeof(snapshot.get("checkpoint_sequence")) == TYPE_INT:
			record["checkpoint_sequence"] = snapshot.checkpoint_sequence
		var lifecycle: Variant = snapshot.get("lifecycle")
		if lifecycle is Dictionary:
			var state: Variant = lifecycle.get("state")
			if typeof(state) in [TYPE_STRING, TYPE_STRING_NAME] and String(state) in RUN_SNAPSHOT_SCHEMA.LIFECYCLE_STATES:
				record["lifecycle_state"] = String(state)
			var ending_plan: Variant = lifecycle.get("ending_plan")
			if ending_plan is Dictionary:
				var stage: Variant = ending_plan.get("playback_stage")
				if typeof(stage) in [TYPE_STRING, TYPE_STRING_NAME] and String(stage) in RUN_SNAPSHOT_SCHEMA.PLAYBACK_SEQUENCE:
					record["playback_stage"] = String(stage)
	return record

static func _profile_phase(profile: Dictionary, phase: String, started_us: int) -> int:
	if profile.is_empty(): return 0
	var now := Time.get_ticks_usec()
	profile[phase] = now - started_us
	return now

static func prepare_candidate(document: Dictionary) -> Dictionary:
	return validate(document)

static func normalize_optional_saved_time(value: Variant) -> Dictionary:
	var normalized: Variant = RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(value)
	return normalized if validate_saved_time(normalized) else {}

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

static func _validate_locator(kind: String, slot_id: Variant) -> String:
	match kind:
		"slot":
			if typeof(slot_id) != TYPE_INT or int(slot_id) < MIN_SLOT or int(slot_id) > MAX_SLOT:
				return "slot documents require an integer slot_id 1..7"
		"quick", "autosave":
			if slot_id != null:
				return kind + " documents require a JSON null slot_id"
		_:
			return "unknown document kind: " + kind
	return ""

static func _validate_discriminators(kind: String, slot_id: Variant, save_reason: String) -> String:
	var locator_error := _validate_locator(kind, slot_id)
	if not locator_error.is_empty(): return locator_error
	match kind:
		"slot":
			if save_reason != "manual": return "slot documents require save_reason=manual"
		"quick":
			if save_reason != "quick": return "quick documents require save_reason=quick"
		"autosave":
			if save_reason not in AUTOSAVE_REASONS: return "unknown autosave reason: " + save_reason
	return ""

static func _validate_bundle(bundle: Dictionary, proven_snapshot: Dictionary = {}) -> Dictionary:
	var keys: Array = bundle.keys()
	keys.sort()
	if keys != ["checkpoint_kind", "snapshot"]:
		return _fail(&"invalid_bundle_shape", "bundle must have exactly checkpoint_kind and snapshot")
	if str(bundle["checkpoint_kind"]) not in CHECKPOINT_KINDS:
		return _fail(&"invalid_bundle_shape", "unknown checkpoint_kind: " + str(bundle["checkpoint_kind"]))
	if typeof(bundle["snapshot"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_bundle_shape", "snapshot must be an object")
	if not proven_snapshot.is_empty() and is_same(bundle.snapshot, proven_snapshot):
		return {"ok": true, "code": &"ok", "value": {"candidate": proven_snapshot}}
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

static func _journal_is_proven(journal: Array, proven_journal: Array) -> bool:
	if proven_journal.is_empty() or proven_journal.size() != journal.size():
		return false
	for proof: Variant in proven_journal:
		if typeof(proof) != TYPE_DICTIONARY or (proof as Dictionary).is_empty():
			return false
	return true

static func _proven_entries(proven_journal: Array) -> Array:
	var composed: Array = []
	for proof: Variant in proven_journal:
		composed.append((proof as Dictionary).duplicate(true))
	return composed

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


static func _normalize_engine_text(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME: return String(value)
		TYPE_ARRAY:
			var source_array: Array = value
			var array: Variant = null
			for index: int in source_array.size():
				var element: Variant = source_array[index]
				var normalized_element: Variant = _normalize_engine_text(element)
				if array == null and not is_same(normalized_element, element):
					array = []
					for prior: int in index:
						array.append(source_array[prior])
				if array != null: array.append(normalized_element)
			return source_array if array == null else array
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			var dictionary: Variant = null
			var visited := 0
			for raw_key: Variant in source_dictionary:
				var key: Variant = String(raw_key) if typeof(raw_key) == TYPE_STRING_NAME else raw_key
				var member: Variant = source_dictionary[raw_key]
				var normalized_member: Variant = _normalize_engine_text(member)
				if dictionary == null and (not is_same(key, raw_key) or not is_same(normalized_member, member)):
					dictionary = {}
					var copied := 0
					for prior_key: Variant in source_dictionary:
						if copied == visited: break
						dictionary[prior_key] = source_dictionary[prior_key]
						copied += 1
				if dictionary != null: dictionary[key] = normalized_member
				visited += 1
			return source_dictionary if dictionary == null else dictionary
	return value

