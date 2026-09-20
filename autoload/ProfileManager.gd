extends Node

signal profile_restored(profile: Dictionary)
signal preference_changed(path: StringName, value: Variant)
signal gallery_changed(ending_id: String, unlocked: bool)
signal visited_history_changed(line_id: String, visited: bool)
signal input_mappings_changed(action_id: StringName)
signal controls_bindings_changed()
signal profile_reset(section: StringName)
signal profile_write_failed(result: Dictionary)

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const DATING_ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
const OBSERVER_EVIDENCE := preload("res://scripts/profile/ObserverEvidence.gd")
const PAIR_DECK := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const PRESENTATION_SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const PREFERENCE_REGISTRY := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONTROLS_RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const CONTROLS_IMPORT := preload("res://scripts/settings/ControlsBindingImport.gd")

const NEW_RUN_MATERIAL_KEYS := ["before", "candidate", "captured_dark", "profile_revision",
	"source_revision", "outgoing_text", "outgoing_hash"]

const PRIMARY_LOCALE_PATH := &"preferences.language.primary_locale_id"
const FONT_STYLE_PATH := &"preferences.accessibility.font_style"
const _AUDIO_MEMORY_SURFACES := [&"META_POST_ENDING_TITLE", &"META_BACKUP_LOAD", &"META_GALLERY_REPLAY"]

var _new_run_storage_bound := false
var _new_run_persisting := false
var _storage: RefCounted
var _profile: Dictionary = {}
var _profile_revision := 0
var _initialized := false
var _fresh_profile_pending := false
var _profile_existed_at_initialize := false
var _mutation_blocked := false
var _mutation_gate: Object
var _deferred_publications: Dictionary = {}
var _publication_counter := 0
var _pending_gallery_publications: Dictionary = {}
var _restore_backup: Dictionary = {}


func _ready() -> void:
	pass


func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _command_failure(&"invalid_mutation_gate")
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method):
			return _command_failure(&"invalid_mutation_gate")
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id():
		return _command_failure(&"mutation_gate_already_configured")
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}


func initialize(storage: RefCounted = null) -> Dictionary:
	if _initialized:
		return _failure(&"already_initialized", "ProfileManager initializes exactly once")
	if storage == null:
		return _failure(&"invalid_storage", "A storage adapter is required")
	if _new_run_storage_bound and _storage != storage:
		return _failure(&"profile_storage_already_bound", "New Run storage cannot be replaced")
	_storage = storage
	var reconciled: Dictionary = _storage.call(&"reconcile", "profile.json", _profile_migration_text_validator)
	if not reconciled.get("ok", false):
		if reconciled.get("code") == &"indeterminate_transaction" or reconciled.get("code") == &"indeterminate_commit" or reconciled.get("fatal", false):
			_mutation_blocked = true
		return reconciled
	if not reconciled.get("exists", false):
		_profile_existed_at_initialize = false
		var defaults := SCHEMA.make_defaults()
		var persisted := _persist_candidate(defaults)
		if not persisted.get("ok", false):
			return persisted
		_profile = defaults.duplicate(true)
		_profile_revision += 1
		_fresh_profile_pending = true
	else:
		_profile_existed_at_initialize = true
		var text_result: Dictionary = _storage.call(&"read_text", "profile.json")
		if not text_result.get("ok", false):
			return text_result
		var parsed: Dictionary = STRICT_JSON.parse_object(text_result["value"])
		if not parsed.get("ok", false):
			return parsed
		var validation: Dictionary = MIGRATION.prepare_document(parsed["value"])
		if not validation.get("ok", false):
			return validation
		var adoption: Dictionary = (validation["value"] as Dictionary).duplicate(true)
		var discovery_repaired := _grant_discovered_dark_mode(adoption)
		if validation.get("migrated", false) or discovery_repaired:
			var persisted := _persist_candidate(adoption, true)
			if not persisted.get("ok", false):
				if persisted.get("fatal", false) or persisted.get("code") == &"indeterminate_commit":
					_mutation_blocked = true
				return persisted
		_profile = adoption.duplicate(true)
		_profile_revision += 1
	var imported := _import_legacy_input_mappings()
	if not imported.get("ok", false):
		return imported
	_initialized = true
	profile_restored.emit(_profile.duplicate(true))
	return {"ok": true, "code": &"ok", "value": _profile.duplicate(true)}


## Startup may bind storage before Profile adoption. This never reads or writes files.
func configure_new_run_storage(storage: RefCounted) -> Dictionary:
	if not _supports_new_run_storage(storage):
		return _failure(&"invalid_storage", "New Run requires revision-aware Profile storage")
	if _storage != null and _storage != storage:
		return _failure(&"profile_storage_already_bound", "New Run must retain the same Profile storage")
	var already: bool = _new_run_storage_bound
	_storage = storage
	_new_run_storage_bound = true
	return {"ok": true, "code": &"ok", "value": {"already_configured": already}}


## Freeze current Profile facts, not a legacy-import candidate. Preparation has no
## reconciliation side effects: unfinished storage artifacts must be recovered first.
func prepare_new_run_consumption(expected_revision: Variant) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "Profile must be initialized before New Run preparation")
	if _mutation_blocked:
		return _failure(&"indeterminate_commit", "Profile mutation is blocked", true)
	if typeof(expected_revision) != TYPE_INT or expected_revision < 1:
		return _failure(&"invalid_profile_revision", "New Run requires an exact Profile revision")
	if expected_revision != _profile_revision:
		return _failure(&"profile_revision_changed", "New Run preparation no longer matches Profile")
	if not _supports_new_run_storage(_storage):
		return _failure(&"invalid_storage", "New Run requires revision-aware Profile storage")
	var checked: Dictionary = _validate_new_run_profile(_profile)
	if not checked.get("ok", false): return checked
	var before: Dictionary = checked["value"]
	var inspected: Dictionary = _storage.inspect_revision("profile.json")
	if not inspected.get("ok", false): return inspected
	var disk: Dictionary = inspected["value"]
	if not _new_run_hash(disk.get("revision")) or typeof(disk.get("text")) != TYPE_STRING:
		return _failure(&"profile_source_changed", "Current Profile bytes are unavailable")
	var decoded: Dictionary = _profile_text_validator(disk["text"])
	if not decoded.get("ok", false) or decoded.get("value") != before \
			or _profile_revision != expected_revision or _profile != before:
		return _failure(&"profile_source_changed", "Live and stored Profile disagree")
	var candidate: Dictionary = before.duplicate(true)
	candidate["preferences"]["dark_mode"]["next_run_enabled"] = false
	var emitted: Dictionary = WRITER.stringify(candidate)
	if not emitted.get("ok", false): return emitted
	var text: String = emitted["value"]
	return {"ok": true, "code": &"ok", "value": {
		"before": before.duplicate(true), "candidate": candidate,
		"captured_dark": before["preferences"]["dark_mode"]["next_run_enabled"],
		"profile_revision": expected_revision, "source_revision": disk["revision"],
		"outgoing_text": text, "outgoing_hash": text.sha256_text()}}


## The caller owns the joint Autosave/Profile decision. This writes only Profile,
## under that caller's New Run custody, and never adopts or publishes its candidate.
func persist_new_run_consumption(material: Dictionary) -> Dictionary:
	if _new_run_persisting:
		return _failure(&"profile_new_run_busy", "Profile persistence is already active")
	var checked: Dictionary = _validate_new_run_material(material)
	if not checked.get("ok", false): return checked
	var detached: Dictionary = material.duplicate(true)
	var admitted: Dictionary = _admit_new_run_persistence(detached)
	if not admitted.get("ok", false): return admitted
	_new_run_persisting = true
	var result: Dictionary = _persist_new_run_material(detached)
	_new_run_persisting = false
	return result


## Read-only proof is also usable after startup or live adoption has advanced the
## in-memory Profile revision. It never reconciles or publishes Profile state.
func prove_new_run_consumption(material: Dictionary) -> Dictionary:
	var checked: Dictionary = _validate_new_run_material(material)
	if not checked.get("ok", false): return checked
	if not _supports_new_run_storage(_storage):
		return _failure(&"invalid_storage", "New Run requires revision-aware Profile storage")
	var inspected: Dictionary = _storage.inspect_revision("profile.json")
	if not inspected.get("ok", false): return inspected
	if inspected["value"].get("revision") != material["outgoing_hash"] \
			or inspected["value"].get("text") != material["outgoing_text"]:
		return _failure(&"profile_output_unproven", "Stored Profile differs from the retained consumption")
	return {"ok": true, "code": &"ok", "value": {
		"outgoing_hash": material["outgoing_hash"], "already_persisted": true}}


func _persist_new_run_material(material: Dictionary) -> Dictionary:
	var inspected: Dictionary = _storage.inspect_revision("profile.json")
	if not inspected.get("ok", false) and inspected.get("code") == &"reconcile_required":
		# Only our conditional-write marker may be reconciled. An unrelated pending
		# Profile deletion/write must not be completed before discovering the conflict.
		var marker_read: Dictionary = _storage.inspect_revision("profile.json.txn.json")
		if not marker_read.get("ok", false): return marker_read
		var marker_text: Variant = marker_read["value"].get("text")
		if typeof(marker_text) != TYPE_STRING:
			return _failure(&"profile_source_changed", "No bound Profile write marker is available")
		var parsed: Dictionary = STRICT_JSON.parse_object(marker_text)
		if not parsed.get("ok", false): return parsed
		var marker: Dictionary = parsed["value"]
		if typeof(marker.get("schema_version")) != TYPE_INT or marker["schema_version"] != 2 \
				or marker.get("relative_path") != "profile.json" or marker.get("operation") != "write_revision" \
				or marker.get("previous_hash") != material["source_revision"] \
				or marker.get("outgoing_hash") != material["outgoing_hash"]:
			return _failure(&"profile_source_changed", "Pending Profile write belongs to other material")
		var admitted: Dictionary = _admit_new_run_persistence(material)
		if not admitted.get("ok", false): return admitted
		var recovered: Dictionary = _storage.reconcile("profile.json", _profile_text_validator)
		if not recovered.get("ok", false) and recovered.get("code") != &"write_not_committed":
			return recovered
		inspected = _storage.inspect_revision("profile.json")
	if not inspected.get("ok", false): return inspected
	var current: Dictionary = inspected["value"]
	var admitted: Dictionary = _admit_new_run_persistence(material)
	if not admitted.get("ok", false): return admitted
	if current.get("revision") == material["outgoing_hash"] and current.get("text") == material["outgoing_text"]:
		return {"ok": true, "code": &"ok", "value": {"outgoing_hash": material["outgoing_hash"], "already_persisted": true}}
	if current.get("revision") != material["source_revision"] or typeof(current.get("text")) != TYPE_STRING:
		return _failure(&"profile_source_changed", "Profile bytes no longer match the prepared source")
	var decoded: Dictionary = _profile_text_validator(current["text"])
	if not decoded.get("ok", false) or decoded.get("value") != material["before"]:
		return _failure(&"profile_source_changed", "Stored Profile does not match the prepared source")
	var written: Dictionary = _storage.write_atomic_if_revision("profile.json", material["outgoing_text"],
		_profile_text_validator, material["source_revision"])
	if not written.get("ok", false): return written
	var proved: Dictionary = _storage.inspect_revision("profile.json")
	if not proved.get("ok", false): return proved
	if proved["value"].get("revision") != material["outgoing_hash"] \
			or proved["value"].get("text") != material["outgoing_text"]:
		return _failure(&"profile_output_unproven", "Profile persistence could not be proved", true)
	admitted = _admit_new_run_persistence(material)
	if not admitted.get("ok", false): return admitted
	return {"ok": true, "code": &"ok", "value": {"outgoing_hash": material["outgoing_hash"], "already_persisted": false}}


func _admit_new_run_persistence(material: Dictionary) -> Dictionary:
	if not _supports_new_run_storage(_storage):
		return _failure(&"invalid_storage", "New Run requires revision-aware Profile storage")
	if not is_instance_valid(_mutation_gate) or _mutation_gate.is_fatal_latched() \
			or not _mutation_gate.is_internal_owner_active(&"new_run"):
		return _failure(&"new_run_custody_required", "Profile persistence requires active nonfatal New Run custody")
	if _mutation_blocked:
		return _failure(&"indeterminate_commit", "Profile mutation is blocked", true)
	if _initialized and (_profile_revision != material["profile_revision"] or _profile != material["before"]):
		return _failure(&"profile_revision_changed", "Live Profile no longer matches frozen material")
	return {"ok": true}


func _validate_new_run_material(material: Dictionary) -> Dictionary:
	if material.size() != NEW_RUN_MATERIAL_KEYS.size():
		return _failure(&"invalid_new_run_profile_material", "Unexpected material members")
	for key: Variant in material:
		if typeof(key) != TYPE_STRING or key not in NEW_RUN_MATERIAL_KEYS:
			return _failure(&"invalid_new_run_profile_material", "Unexpected material member")
	if typeof(material["before"]) != TYPE_DICTIONARY or typeof(material["candidate"]) != TYPE_DICTIONARY \
			or typeof(material["captured_dark"]) != TYPE_BOOL or typeof(material["profile_revision"]) != TYPE_INT \
			or material["profile_revision"] < 1 or not _new_run_hash(material["source_revision"]) \
			or not _new_run_hash(material["outgoing_hash"]) or typeof(material["outgoing_text"]) != TYPE_STRING:
		return _failure(&"invalid_new_run_profile_material", "Malformed material facts")
	var checked: Dictionary = _validate_new_run_profile(material["before"])
	if not checked.get("ok", false): return checked
	var candidate: Dictionary = material["before"].duplicate(true)
	if material["captured_dark"] != candidate["preferences"]["dark_mode"]["next_run_enabled"]:
		return _failure(&"invalid_new_run_profile_material", "Captured Dark differs from the source")
	candidate["preferences"]["dark_mode"]["next_run_enabled"] = false
	var candidate_checked: Dictionary = _validate_new_run_profile(material["candidate"])
	if not candidate_checked.get("ok", false): return candidate_checked
	var expected: Dictionary = WRITER.stringify(candidate)
	var supplied: Dictionary = WRITER.stringify(material["candidate"])
	if not expected.get("ok", false) or not supplied.get("ok", false) \
			or expected.get("value") != supplied.get("value") or material["outgoing_text"] != expected.get("value") \
			or material["outgoing_text"].sha256_text() != material["outgoing_hash"]:
		return _failure(&"invalid_new_run_profile_material", "Only canonical Dark selector consumption is allowed")
	return {"ok": true}


func _validate_new_run_profile(profile: Dictionary) -> Dictionary:
	var checked: Dictionary = SCHEMA.validate(profile)
	if not checked.get("ok", false): return checked
	var dark: Dictionary = profile["preferences"]["dark_mode"]
	if dark["next_run_enabled"] and not dark["available"]:
		return _failure(&"invalid_new_run_profile_material", "Unavailable Dark cannot be enabled")
	return checked


func _supports_new_run_storage(storage: RefCounted) -> bool:
	if not is_instance_valid(storage): return false
	for method: StringName in [&"inspect_revision", &"write_atomic_if_revision", &"reconcile"]:
		if not storage.has_method(method): return false
	return true


func _new_run_hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for codepoint: int in value.to_ascii_buffer():
		if not (codepoint >= 0x30 and codepoint <= 0x39) and not (codepoint >= 0x61 and codepoint <= 0x66): return false
	return true


func _has_first_run_accessibility_setup() -> bool:
	return _initialized and _fresh_profile_pending


func _take_first_run_accessibility_setup() -> bool:
	var pending := _has_first_run_accessibility_setup()
	_fresh_profile_pending = false
	return pending


func prepare_profile_document(raw: Dictionary) -> Dictionary:
	return MIGRATION.prepare_document(raw.duplicate(true))


func prepare_preferences(changes: Dictionary) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var candidate := _profile.duplicate(true)
	if changes.is_empty():
		return {"ok": true, "code": &"ok", "value": candidate, "changed_paths": []}
	var normalized: Dictionary = {}
	for path_value in changes:
		if typeof(path_value) != TYPE_STRING_NAME:
			return _failure(&"invalid_preference_path", "Preference batch keys must be StringName")
		var path: StringName = path_value
		var validated := SCHEMA.validate_preference(path, changes[path_value])
		if not validated.get("ok", false):
			return validated
		if path in [PRIMARY_LOCALE_PATH, FONT_STYLE_PATH]:
			return _failure(&"managed_preference", "Language and font style are managed by presentation preparation")
		if not PREFERENCE_REGISTRY.is_player_writable(path):
			return _failure(&"managed_preference", "Preference is capability-owned")
		normalized[path] = validated["value"]
	var paths: Array = normalized.keys()
	paths.sort_custom(_utf8_name_less)
	for path: StringName in paths:
		_set_profile_path(candidate, path, normalized[path])
	var document_validation := SCHEMA.validate(candidate)
	if not document_validation.get("ok", false):
		return document_validation
	return {"ok": true, "code": &"ok", "value": document_validation["value"], "changed_paths": paths.duplicate()}


func prepare_locale_preference(locale_id: String) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var canonical_locale := _canonical_locale_id(locale_id)
	var validated := SCHEMA.validate_preference(PRIMARY_LOCALE_PATH, canonical_locale)
	if not validated.get("ok", false):
		return validated
	var candidate := _profile.duplicate(true)
	var language: Dictionary = candidate["preferences"]["language"]
	var previous_primary := str(language["primary_locale_id"])
	_set_profile_path(candidate, PRIMARY_LOCALE_PATH, canonical_locale)
	if str(language["secondary_locale_id"]) == canonical_locale:
		language["secondary_locale_id"] = _fallback_secondary_locale(canonical_locale, previous_primary)
	var document_validation := SCHEMA.validate(candidate)
	if not document_validation.get("ok", false):
		return document_validation
	return {"ok": true, "code": &"ok", "value": document_validation["value"], "changed_paths": [PRIMARY_LOCALE_PATH]}


func prepare_font_style_preference(font_style: String) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var validated := SCHEMA.validate_preference(FONT_STYLE_PATH, font_style)
	if not validated.get("ok", false): return validated
	var candidate := _profile.duplicate(true)
	_set_profile_path(candidate, FONT_STYLE_PATH, font_style)
	return SCHEMA.validate(candidate)


func commit_prepared_profile(candidate: Dictionary, defer_signals: bool = false, expected_revision: int = -1) -> Dictionary:
	var guarded := _guard(&"profile_commit")
	if not guarded.get("ok", false):
		return guarded
	return _commit_profile_candidate(candidate, defer_signals, expected_revision)


func _commit_profile_candidate(candidate: Dictionary, defer_signals: bool = false, expected_revision: int = -1, allow_dating_reset: bool = false, allow_gallery_reset: bool = false) -> Dictionary:
	var revision_check := _check_profile_revision(expected_revision)
	if not revision_check.get("ok", false):
		return revision_check
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	if _mutation_blocked:
		return _failure(&"indeterminate_commit", "Profile mutation is blocked", true)
	var validation := SCHEMA.validate(candidate.duplicate(true))
	if not validation.get("ok", false):
		return validation
	var detached: Dictionary = validation["value"]
	if not allow_dating_reset and not DATING_ATTEMPTS.preserves(_profile.dating_attempts, detached.dating_attempts):
		return _failure(&"dating_history_rewind", "Only full Profile reset may remove Dating commitments")
	if not allow_dating_reset:
		for key: String in ["observer_evidence", "pair_deck_draws"]:
			if not _preserves_receipts(_profile[key], detached[key]):
				return _failure(&"profile_evidence_rewind", "Only full Profile reset may remove durable evidence")
		if not allow_gallery_reset and not _preserves_receipts(_profile.reached_presentations, detached.reached_presentations):
			return _failure(&"presentation_history_rewind", "Only Clear Gallery or full reset may remove reached presentations")
	var old := _profile.duplicate(true)
	var persisted := _persist_candidate(detached)
	if not persisted.get("ok", false):
		if persisted.get("fatal", false) or persisted.get("code") == &"indeterminate_commit":
			_mutation_blocked = true
		profile_write_failed.emit(persisted.duplicate(true))
		return persisted
	_profile = detached.duplicate(true)
	_profile_revision += 1
	var publication := _build_publication(old, _profile)
	if defer_signals:
		_publication_counter += 1
		var publication_id := "profile-publication-%d" % _publication_counter
		_deferred_publications[publication_id] = publication.duplicate(true)
		for transaction_id in _profile["gallery_transaction_receipts"]:
			if not old["gallery_transaction_receipts"].has(transaction_id):
				_pending_gallery_publications[transaction_id] = publication_id
		return {"ok": true, "code": &"ok", "value": {"publication_id": publication_id}}
	_publish(publication)
	return {"ok": true, "code": &"ok", "value": _profile.duplicate(true)}


func publish_deferred_profile_signals(publication_id: String) -> Dictionary:
	if publication_id.is_empty() or not _deferred_publications.has(publication_id):
		return _failure(&"unknown_publication", "Publication ID is unknown or already consumed")
	var publication: Dictionary = _deferred_publications[publication_id]
	_deferred_publications.erase(publication_id)
	_publish(publication.duplicate(true))
	for transaction_id in _pending_gallery_publications.keys():
		if _pending_gallery_publications[transaction_id] == publication_id:
			_pending_gallery_publications.erase(transaction_id)
	return {"ok": true, "code": &"ok", "value": {"publication_id": publication_id}}


func get_profile_snapshot() -> Dictionary:
	return _profile.duplicate(true)


func get_profile_revision() -> int:
	return _profile_revision


func _check_profile_revision(expected_revision: int) -> Dictionary:
	if expected_revision != -1 and expected_revision != _profile_revision:
		return _failure(&"profile_revision_changed", "Reset confirmation no longer matches the profile")
	return {"ok": true, "code": &"ok"}


func get_preference(path: StringName, default_value: Variant = null) -> Variant:
	if not _is_registered_preference_path(path):
		return default_value
	return _get_profile_path(_profile, path, default_value)


func set_preference(path: StringName, value: Variant) -> Dictionary:
	return set_preferences({path: value})


func set_preferences(changes: Dictionary) -> Dictionary:
	var prepared := prepare_preferences(changes)
	if not prepared.get("ok", false):
		return prepared
	if prepared["changed_paths"].is_empty():
		return {"ok": true, "code": &"ok", "value": _profile.duplicate(true), "unchanged": true}
	return commit_prepared_profile(prepared["value"])


func is_line_visited(line_id: String) -> bool:
	return line_id in _profile.get("visited_line_ids", [])


func mark_line_visited(line_id: String) -> Dictionary:
	if line_id.is_empty():
		return _failure(&"invalid_line_id", "Line ID must be nonempty")
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	if _line_registry_fingerprint.is_empty():
		return _failure(&"line_registry_not_configured", "Visited-line registry is not configured")
	if not _line_registry_admits(line_id):
		return _failure(&"unregistered_line_id", "Line ID is absent from the configured registry")
	if is_line_visited(line_id):
		return {"ok": true, "code": &"ok", "value": {"visited": true}, "unchanged": true}
	var candidate := _profile.duplicate(true)
	candidate["visited_line_ids"].append(line_id)
	return commit_prepared_profile(candidate)


## Only physical presentation owners call this after a counted event or ending.
## A hidden New Run selection never writes a witness receipt.
func record_pair_form_witness(form: String, transaction_id: String) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	if form not in SCHEMA.PAIR_FORMS or transaction_id.strip_edges().is_empty():
		return _failure(&"invalid_pair_form_witness", "a registered form and presentation receipt are required")
	var ledger: Dictionary = _profile["pair_form_witness_receipts"]
	if ledger.has(transaction_id):
		if ledger[transaction_id] != form:
			return _failure(&"pair_form_witness_conflict", "the presentation already witnessed another form")
		return {"ok": true, "value": {"form": form, "already_recorded": true}}
	var candidate := _profile.duplicate(true)
	candidate.pair_form_witness_receipts[transaction_id] = form
	return commit_prepared_profile(candidate)


## Detached first-attempt history; it survives older run saves and Clear Gallery.
func get_dating_attempt(run_id: String, slot_id: String, attempt_id: String = "", branch_id: String = "") -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	return DATING_ATTEMPTS.read(_profile.dating_attempts, run_id, slot_id, attempt_id, branch_id)


## Pure preview: Load does not persist anything. Use its selection on the first action.
func prepare_dating_continuation(run_id: String, slot_id: String, attempt_id: String,
		source_branch_id: String, branch_id: String, saved_record: Dictionary) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	if not has_completed_ending(): return _failure(&"dating_replacement_locked", "A completed ending is required")
	return DATING_ATTEMPTS.prepare_continuation(_profile.dating_attempts, run_id, slot_id,
		attempt_id, source_branch_id, branch_id, saved_record)


func prepare_dating_attempt(run_id: String, slot_id: String, branch_id: String, record: Dictionary,
		expected_revision: int, first_cell_index: int = -1, frozen_effect: Dictionary = {},
		selection: Dictionary = {}) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	if not selection.is_empty() and not has_completed_ending():
		return _failure(&"dating_replacement_locked", "Branch continuations require a completed ending")
	var prepared: Dictionary = DATING_ATTEMPTS.prepare_update(_profile.dating_attempts,
		run_id, slot_id, branch_id, record, expected_revision, first_cell_index, frozen_effect, selection)
	if not prepared.get("ok", false): return prepared
	return {"ok": true, "code": &"ok", "value": {
		"profile_revision": _profile_revision, "attempt": prepared.value.attempt.duplicate(true),
		"changed": prepared.value.changed, "request": {"run_id": run_id, "slot_id": slot_id,
			"branch_id": branch_id, "record": record.duplicate(true), "expected_revision": expected_revision,
			"first_cell_index": first_cell_index, "frozen_effect": frozen_effect.duplicate(true),
			"selection": selection.duplicate(true)}}}


## The Profile commit is durable before the caller writes Autosave. An Autosave failure
## must retry/reconcile this committed attempt, never roll the Profile commitment back.
func commit_dating_attempt(material: Dictionary) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	if _mutation_gate != null and not _mutation_gate.is_internal_owner_active(&"causal_transaction"):
		return _failure(&"dating_attempt_custody_required", "Dating persistence requires its causal lease")
	var keys: Array = material.keys()
	keys.sort()
	if keys != ["attempt", "changed", "profile_revision", "request"] \
			or typeof(material.profile_revision) != TYPE_INT or typeof(material.changed) != TYPE_BOOL \
			or not material.request is Dictionary or not material.attempt is Dictionary:
		return _failure(&"invalid_dating_preparation", "A detached Dating preparation is required")
	var request: Dictionary = material.request
	keys = request.keys()
	keys.sort()
	if keys != ["branch_id", "expected_revision", "first_cell_index", "frozen_effect", "record", "run_id", "selection", "slot_id"]:
		return _failure(&"invalid_dating_preparation", "Unexpected Dating request fields")
	for key: String in ["run_id", "slot_id", "branch_id"]:
		if not request[key] is String: return _failure(&"invalid_dating_preparation", "Expected identity String")
	if typeof(request.expected_revision) != TYPE_INT or typeof(request.first_cell_index) != TYPE_INT \
			or not request.record is Dictionary or not request.frozen_effect is Dictionary or not request.selection is Dictionary:
		return _failure(&"invalid_dating_preparation", "Unexpected Dating request types")
	if not request.selection.is_empty() and not has_completed_ending():
		return _failure(&"dating_replacement_locked", "Branch continuations require a completed ending")
	var prepared: Dictionary = DATING_ATTEMPTS.prepare_update(_profile.dating_attempts,
		request.run_id, request.slot_id, request.branch_id, request.record, request.expected_revision,
		request.first_cell_index, request.frozen_effect, request.selection)
	if not prepared.get("ok", false): return prepared
	if prepared.value.attempt != material.attempt:
		return _failure(&"dating_preparation_conflict", "The prepared commitment changed")
	var attempt: Dictionary = prepared.value.attempt
	var witness_id := ""
	var requires_witness := false
	if attempt.record.host == "canonical_pair" and attempt.completion_receipt != null \
			and attempt.record.outcome in ["perfect", "cleared"]:
		witness_id = str(attempt.attempt_id) + ":complete"
		var witnesses: Dictionary = _profile.pair_form_witness_receipts
		if witnesses.has(witness_id) and witnesses[witness_id] != attempt.record.pair_form:
			return _failure(&"pair_form_witness_conflict", "The completed attempt already witnessed another form")
		requires_witness = not witnesses.has(witness_id)
	if not prepared.value.changed and not requires_witness:
		return {"ok": true, "code": &"ok", "value": {"attempt": attempt.duplicate(true), "already_recorded": true}}
	var candidate := _profile.duplicate(true)
	candidate["dating_attempts"] = prepared.value.ledger.duplicate(true)
	# Physical completion and the presented pair form share one durable Profile write.
	# The ordinary witness API intentionally remains closed while this causal lease is held.
	if requires_witness:
		candidate["pair_form_witness_receipts"][witness_id] = attempt.record.pair_form
	var committed := _commit_profile_candidate(candidate, false, material.profile_revision)
	if not committed.get("ok", false): return committed
	return {"ok": true, "code": &"ok", "value": {"attempt": prepared.value.attempt.duplicate(true), "already_recorded": false}}


## Finite Observer presentation evidence is Profile-wide and independent of board mastery.
func get_observer_evidence() -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	return {"ok": true, "value": {"by_scope": OBSERVER_EVIDENCE.evidence(_profile.observer_evidence),
		"receipts": _profile.observer_evidence.duplicate(true)}}

func record_observer_evidence(receipt: Dictionary) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	var custody := _evidence_custody()
	if not custody.ok: return custody
	var prepared := OBSERVER_EVIDENCE.prepare(_profile.observer_evidence, receipt)
	if not prepared.ok: return prepared
	if prepared.already_recorded: return {"ok": true, "value": {"already_recorded": true}}
	var candidate := _profile.duplicate(true)
	candidate["observer_evidence"] = prepared.value
	var committed := _commit_profile_candidate(candidate)
	return {"ok": true, "value": {"already_recorded": false}} if committed.ok else committed

func get_pair_deck_draw(run_id: String) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	if run_id.strip_edges().is_empty(): return _failure(&"invalid_pair_draw", "A run identity is required")
	var receipt: Variant = _profile.pair_deck_draws.get(run_id)
	return {"ok": true, "value": receipt.duplicate(true) if receipt is Dictionary else null}

func prepare_pair_deck_draw(run_id: String, receipt: Dictionary) -> Dictionary:
	var existing := get_pair_deck_draw(run_id)
	if not existing.ok: return existing
	var checked := PAIR_DECK.validate(receipt)
	if not checked.ok: return checked
	if existing.value != null and existing.value != receipt:
		return _failure(&"pair_deck_draw_conflict", "The run already committed another draw")
	return {"ok": true, "value": {"run_id": run_id, "receipt": receipt.duplicate(true),
		"profile_revision": _profile_revision}}

func commit_pair_deck_draw(material: Dictionary) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	var custody := _evidence_custody()
	if not custody.ok: return custody
	var keys: Array = material.keys()
	keys.sort()
	if keys != ["profile_revision", "receipt", "run_id"] or not material.run_id is String \
			or not material.receipt is Dictionary or typeof(material.profile_revision) != TYPE_INT:
		return _failure(&"invalid_pair_draw_preparation", "An exact draw preparation is required")
	var prepared := prepare_pair_deck_draw(material.run_id, material.receipt)
	if not prepared.ok: return prepared
	if _profile.pair_deck_draws.has(material.run_id):
		return {"ok": true, "value": material.receipt.duplicate(true), "already_recorded": true}
	var revision := _check_profile_revision(material.profile_revision)
	if not revision.ok: return revision
	var candidate := _profile.duplicate(true)
	candidate["pair_deck_draws"][material.run_id] = material.receipt.duplicate(true)
	var committed := _commit_profile_candidate(candidate)
	return {"ok": true, "value": material.receipt.duplicate(true), "already_recorded": false} if committed.ok else committed

func record_reached_presentation(signature: Dictionary) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	var checked := PRESENTATION_SIGNATURE.validate(signature)
	if not checked.ok: return checked
	var id: String = checked.value.signature_id
	if _profile.reached_presentations.has(id):
		if _profile.reached_presentations[id] != signature:
			return _failure(&"presentation_signature_conflict", "A signature digest has conflicting fields")
		return {"ok": true, "value": {"signature_id": id, "already_reached": true}}
	var candidate := _profile.duplicate(true)
	candidate["reached_presentations"][id] = signature.duplicate(true)
	# Canonical physical completion may retain its causal lease; standalone canonical owners
	# use the ordinary Profile admission gate. Rehearsal owns neither path.
	var committed: Dictionary
	if _mutation_gate != null and _mutation_gate.is_internal_owner_active(&"causal_transaction"):
		committed = _commit_profile_candidate(candidate)
	else:
		committed = commit_prepared_profile(candidate)
	return {"ok": true, "value": {"signature_id": id, "already_reached": false}} if committed.ok else committed

func get_reached_presentations(entry_id: String = "") -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	var ids: Array = _profile.reached_presentations.keys()
	ids.sort()
	var records: Array = []
	for id: String in ids:
		var signature: Dictionary = _profile.reached_presentations[id]
		if entry_id.is_empty() or signature.entry_id == entry_id:
			records.append({"signature_id": id, "signature": signature.duplicate(true)})
	return {"ok": true, "value": {"records": records}}

func _evidence_custody() -> Dictionary:
	if _mutation_gate != null and not _mutation_gate.is_internal_owner_active(&"causal_transaction"):
		return _failure(&"evidence_custody_required", "Canonical evidence requires its causal lease")
	return {"ok": true}

static func _preserves_receipts(before: Dictionary, after: Dictionary) -> bool:
	for key: Variant in before:
		if not after.has(key) or after[key] != before[key]: return false
	return true

func get_pair_form_witnesses() -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	var forms: Array[String] = []
	for form: String in _profile.pair_form_witness_receipts.values():
		if form not in forms: forms.append(form)
	forms.sort()
	return {"ok": true, "value": forms}


func has_gallery_unlock(ending_id: String) -> bool:
	return ending_id in _profile.get("gallery_unlocks", [])


func get_gallery_discovery_snapshot() -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "Profile is not ready")
	# This owner's append-only discovery list is persisted without sorting. A
	# rediscovery never appends; Clear Gallery starts a fresh discovery list.
	return {"ok": true, "code": &"ok", "value": {"revision": get_profile_revision(),
		"ending_ids": _profile["gallery_unlocks"].duplicate()}}


func prepare_ending_unlock(ending_id: String, transaction_id: String) -> Dictionary:
	if ending_id not in SCHEMA.ENDING_IDS or transaction_id.is_empty():
		return _failure(&"invalid_gallery_transaction", "Ending and transaction IDs must be valid")
	var ledger: Dictionary = _profile["gallery_transaction_receipts"]
	if ledger.has(transaction_id):
		var prior: Dictionary = ledger[transaction_id]
		if prior["ending_id"] != ending_id:
			return _failure(&"gallery_transaction_conflict", "Transaction ID belongs to another ending")
		return {"ok": true, "code": &"ok", "value": {"candidate": _profile.duplicate(true), "transaction_id": transaction_id, "gallery_receipt": prior.duplicate(true), "requires_commit": false, "pending_publication_id": _pending_gallery_publications.get(transaction_id, "")}}
	var candidate := _profile.duplicate(true)
	var unlocked := not has_gallery_unlock(ending_id)
	var receipt := {"ending_id": ending_id, "unlocked": unlocked}
	candidate["gallery_transaction_receipts"][transaction_id] = receipt.duplicate(true)
	if unlocked:
		candidate["gallery_unlocks"].append(ending_id)
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate, "transaction_id": transaction_id, "gallery_receipt": receipt, "requires_commit": true, "pending_publication_id": ""}}


func unlock_ending(ending_id: String, transaction_id: String) -> Dictionary:
	var prepared := prepare_ending_unlock(ending_id, transaction_id)
	if not prepared.get("ok", false):
		return prepared
	var value: Dictionary = prepared["value"]
	if value["requires_commit"]:
		var committed := commit_prepared_profile(value["candidate"])
		if not committed.get("ok", false):
			return committed
	return {"ok": true, "code": &"ok", "value": (value["gallery_receipt"] as Dictionary).duplicate(true)}


## Called by the ending owner after its exact physical completion, under the shared causal
## lease. The ordinary Profile mutation guard remains closed to UI and preference callers.
func record_ending_completion(ending_id: String, transaction_id: String, pair_form: String = "") -> Dictionary:
	if _mutation_gate != null and not _mutation_gate.is_internal_owner_active(&"causal_transaction"):
		return _failure(&"ending_completion_custody_required", "Ending completion requires its causal lease")
	if not transaction_id.begins_with("ending:") or not transaction_id.ends_with(":gallery:" + ending_id) \
			or transaction_id.trim_prefix("ending:").trim_suffix(":gallery:" + ending_id).is_empty():
		return _failure(&"invalid_ending_completion_transaction", "A run-scoped ending completion is required")
	if ending_id in ["ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.dark"] and pair_form.is_empty():
		return _failure(&"invalid_pair_form_witness", "A pair ending requires its witnessed frozen form")
	if not pair_form.is_empty() and (pair_form not in SCHEMA.PAIR_FORMS \
			or ending_id != "ending.priscilla_lavinia." + ("dark" if pair_form.ends_with("_dark") else "sweet")):
		return _failure(&"invalid_pair_form_witness", "The completed pair ending must match its frozen form")
	var prepared := prepare_ending_unlock(ending_id, transaction_id)
	if not prepared.get("ok", false): return prepared
	var candidate: Dictionary = prepared.value.candidate
	var requires_commit: bool = prepared.value.requires_commit
	if not pair_form.is_empty():
		var witness_id := transaction_id.trim_suffix(":gallery:" + ending_id) + ":pair-form:" + pair_form
		var ledger: Dictionary = candidate.pair_form_witness_receipts
		var witness_prefix := transaction_id.trim_suffix(":gallery:" + ending_id) + ":pair-form:"
		for previous_id: String in ledger:
			if previous_id.begins_with(witness_prefix) and str(ledger[previous_id]) != pair_form:
				return _failure(&"pair_form_witness_conflict", "The run already completed another pair form")
		if ledger.has(witness_id) and str(ledger[witness_id]) != pair_form:
			return _failure(&"pair_form_witness_conflict", "The completion already recorded another form")
		if not ledger.has(witness_id):
			ledger[witness_id] = pair_form
			requires_commit = true
	if _grant_discovered_dark_mode(candidate):
		requires_commit = true
	if requires_commit:
		var committed := _commit_profile_candidate(candidate)
		if not committed.get("ok", false): return committed
	return {"ok": true, "code": &"ok", "value": prepared.value.gallery_receipt.duplicate(true)}


## Pure candidate update shared by real completion and compatibility adoption.
## Receipt history survives Clear Gallery; neither a getter nor Gallery replay writes it.
static func _grant_discovered_dark_mode(candidate: Dictionary) -> bool:
	if candidate.preferences.dark_mode.available: return false
	var required: Array = ["ending.priscilla.dark", "ending.lavinia.dark", "ending.sylvia.dark", "ending.sylvia.special"]
	for discovered: String in candidate.gallery_unlocks:
		required.erase(discovered)
	for receipt: Dictionary in candidate.gallery_transaction_receipts.values():
		required.erase(str(receipt.ending_id))
	if not required.is_empty(): return false
	candidate.preferences.dark_mode.available = true
	return true


## The receipt ledger survives Clear Gallery and ordinary run restoration. A preview or
## Gallery replay adds no receipt here, so neither can manufacture the first-ending milestone.
func has_completed_ending() -> bool:
	if not _initialized: return false
	return _has_ending_completion_evidence(_profile) or not (_profile.gallery_unlocks as Array).is_empty()


static func _has_ending_completion_evidence(profile: Dictionary) -> bool:
	for transaction_id: String in profile.gallery_transaction_receipts:
		var receipt: Dictionary = profile.gallery_transaction_receipts[transaction_id]
		if transaction_id == "profile:legacy-ending-milestone": return true
		if transaction_id.begins_with("ending:") and transaction_id.ends_with(":gallery:" + str(receipt.ending_id)):
			return true
	return false


func _preserve_legacy_ending_milestone(candidate: Dictionary) -> void:
	if _has_ending_completion_evidence(_profile) or (_profile.gallery_unlocks as Array).is_empty(): return
	# A migrated Gallery-only profile already proves an ending was achieved. Retain that
	# historical evidence before a reset removes its visible discovery list.
	candidate.gallery_transaction_receipts["profile:legacy-ending-milestone"] = {
		"ending_id": str(_profile.gallery_unlocks[0]), "unlocked": false}


func get_eligible_audio_memory_ids(surface_id: StringName) -> Array:
	if surface_id not in _AUDIO_MEMORY_SURFACES:
		return []
	var unlock_count := (_profile.get("gallery_unlocks", []) as Array).size()
	if unlock_count <= 0:
		return []
	var ids := ["memory.completion_present"]
	if unlock_count >= 2:
		ids.append("memory.completion_plural")
	return ids


func get_input_mappings() -> Dictionary:
	if _profile.get("controls_import_pending", false): return {}
	var result := {}
	for action: String in _profile.get("controls_bindings", {}):
		var slots: Dictionary = _profile.controls_bindings[action]
		result[action] = [slots.keyboard.duplicate(true), slots.controller.duplicate(true)]
	return result


func set_input_mapping(action_id: StringName, events: Array[Dictionary]) -> Dictionary:
	# Compatibility entry point for one device at a time. Never write provenance,
	# erase the other slot, or silently accept a conflict without Swap consent.
	if events.size() != 1:
		return _failure(&"invalid_binding_change", "Exactly one input slot is required")
	var kind: Variant = events[0].get("kind")
	var slot := "keyboard" if kind == "key" else ("controller" if kind == "joypad_button" else "")
	var proposed := prepare_controls_change(String(action_id), slot, events[0])
	if not proposed.get("ok", false): return proposed
	if proposed.value.operation != &"rebind":
		return _failure(&"binding_conflict", "A conflict requires explicit Swap consent")
	return commit_controls_change(proposed.value)


func get_controls_binding_snapshot() -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "ProfileManager is not initialized")
	var pending: bool = _profile.controls_import_pending
	return {"ok": true, "code": &"ok", "value": {
		"bindings": _profile.controls_bindings.duplicate(true),
		"revision": _profile_revision, "import_pending": pending,
		"import_issues": CONTROLS_IMPORT.prepare(_profile.input_mappings).issues if pending else [],
	}}


func get_controls_import_review() -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	if not _profile.controls_import_pending:
		return _failure(&"controls_import_not_pending", "There is no pending controls import")
	return {"ok": true, "code": &"ok", "value": {
		"revision": _profile_revision,
		"bindings": _profile.controls_bindings.duplicate(true),
		"legacy_bindings": _profile.input_mappings.duplicate(true),
		"issues": CONTROLS_IMPORT.prepare(_profile.input_mappings).issues,
	}}


func prepare_controls_import(bindings: Variant, expected_revision: Variant) -> Dictionary:
	var review := get_controls_import_review()
	if not review.get("ok", false): return review
	if typeof(expected_revision) != TYPE_INT or expected_revision < 0:
		return _failure(&"invalid_profile_revision", "Import review requires an exact profile revision")
	if expected_revision != _profile_revision:
		return _failure(&"profile_revision_changed", "Import review no longer matches the profile")
	var validation := CONTROLS_RULES.validate(bindings)
	if not validation.get("ok", false): return validation
	return {"ok": true, "code": &"ok", "value": {
		"revision": _profile_revision,
		"before": review.value.bindings,
		"legacy_bindings": review.value.legacy_bindings,
		"after": bindings.duplicate(true),
	}}


func commit_controls_import(proposal: Dictionary) -> Dictionary:
	var review := get_controls_import_review()
	if not review.get("ok", false): return review
	if proposal.size() != 4:
		return _failure(&"invalid_binding_proposal", "Import proposal is malformed")
	for field: String in ["revision", "before", "legacy_bindings", "after"]:
		if not proposal.has(field):
			return _failure(&"invalid_binding_proposal", "Import proposal is malformed")
	# Dictionary equality alone allows numerically equal integer/float metadata.
	# Validate the supplied source with the same strict types as its durable owner.
	var source := _profile.duplicate(true)
	source.controls_bindings = proposal.before
	source.input_mappings = proposal.legacy_bindings
	if not SCHEMA.validate(source).get("ok", false):
		return _failure(&"invalid_binding_proposal", "Import source metadata is malformed")
	var recomputed := prepare_controls_import(proposal.after, proposal.revision)
	if not recomputed.get("ok", false): return recomputed
	if proposal != recomputed.value:
		return _failure(&"invalid_binding_proposal", "Import proposal no longer matches the complete source")
	var candidate := _profile.duplicate(true)
	candidate.controls_bindings = recomputed.value.after.duplicate(true)
	candidate.controls_import_pending = false
	return commit_prepared_profile(candidate, false, proposal.revision)


func prepare_controls_change(action: String, slot: String, binding: Variant) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "ProfileManager is not initialized")
	if _profile.controls_import_pending:
		return _failure(&"controls_import_required", "Imported bindings require complete review or Restore Controls")
	return CONTROLS_RULES.propose(_profile.controls_bindings, action, slot, binding, _profile_revision)


func commit_controls_change(proposal: Dictionary) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "ProfileManager is not initialized")
	if _profile.controls_import_pending:
		return _failure(&"controls_import_required", "Imported bindings require complete review or Restore Controls")
	if typeof(proposal.get("revision")) != TYPE_INT or proposal.revision != _profile_revision:
		return _failure(&"profile_revision_changed", "Binding proposal no longer matches the profile")
	if proposal.get("before") != _profile.controls_bindings:
		return _failure(&"binding_source_changed", "Binding proposal no longer matches the input map")
	if typeof(proposal.get("action")) != TYPE_STRING or typeof(proposal.get("slot")) != TYPE_STRING:
		return _failure(&"invalid_binding_proposal", "Binding proposal is malformed")
	var after: Variant = proposal.get("after")
	if not after is Dictionary or not after.get(proposal.action) is Dictionary or not after[proposal.action].has(proposal.slot):
		return _failure(&"invalid_binding_proposal", "Binding proposal is malformed")
	var recomputed := prepare_controls_change(proposal.action, proposal.slot, after[proposal.action][proposal.slot])
	if not recomputed.get("ok", false): return recomputed
	if recomputed.value != proposal or not recomputed.value.can_commit:
		return _failure(&"invalid_binding_proposal", "The complete binding proposal is not valid")
	if proposal.before == proposal.after:
		return {"ok": true, "code": &"ok", "unchanged": true}
	var candidate := _profile.duplicate(true)
	candidate.controls_bindings = proposal.after.duplicate(true)
	return commit_prepared_profile(candidate, false, proposal.revision)


func prepare_legacy_profile_patch(legacy_run_state: Dictionary,
		legacy_input_mappings: Dictionary = {}) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	if _profile["migration_receipts"]["legacy_game_state_profile_v1"]:
		return {"ok": true, "code": &"ok", "value": _profile.duplicate(true), "unchanged": true}
	var prepared := MIGRATION.prepare_legacy_patch(legacy_run_state.duplicate(true),
		legacy_input_mappings.duplicate(true))
	if not prepared.get("ok", false):
		return prepared
	var patch: Dictionary = prepared["value"]
	var candidate := _profile.duplicate(true)
	if not _profile_existed_at_initialize:
		candidate["preferences"] = patch["preferences"].duplicate(true)
		candidate["legacy_preferences_v1"] = patch["legacy_preferences_v1"].duplicate(true)
	for action_id: String in patch["input_mappings"]:
		if not candidate["input_mappings"].has(action_id):
			candidate["input_mappings"][action_id] = patch["input_mappings"][action_id].duplicate(true)
	for ending_id: String in patch["gallery_unlocks"]:
		if ending_id not in candidate["gallery_unlocks"]:
			candidate["gallery_unlocks"].append(ending_id)
	candidate["gallery_unlocks"].sort()
	candidate["migration_receipts"]["legacy_game_state_profile_v1"] = true
	if patch["migration_receipts"]["legacy_input_bindings_v1"]:
		candidate["migration_receipts"]["legacy_input_bindings_v1"] = true
	if not patch["input_mappings"].is_empty():
		var imported := CONTROLS_IMPORT.prepare(candidate["input_mappings"])
		candidate["controls_bindings"] = imported["bindings"]
		candidate["controls_import_pending"] = imported["pending"]
	return SCHEMA.validate(candidate)


func reset_preferences(expected_revision: int = -1) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var checked := _check_profile_revision(expected_revision)
	if not checked.get("ok", false): return checked
	var prepared := _prepare_preferences_reset()
	return _commit_reset(prepared["value"], &"preferences", expected_revision) if prepared.get("ok", false) else prepared


func _prepare_preferences_reset() -> Dictionary:
	var candidate := _profile.duplicate(true)
	var defaults: Dictionary = SCHEMA.make_defaults()["preferences"]
	var retained_language: Dictionary = candidate["preferences"]["language"].duplicate(true)
	var retained_exceptional_available: bool = bool(candidate["preferences"]["exceptional_replay"]["available"])
	var retained_dark_available: bool = bool(candidate["preferences"]["dark_mode"]["available"])
	var retained_pending_dark: bool = bool(candidate["preferences"]["dark_mode"]["next_run_enabled"])
	candidate["preferences"] = defaults.duplicate(true)
	candidate["preferences"]["language"] = retained_language
	candidate["preferences"]["exceptional_replay"]["available"] = retained_exceptional_available
	candidate["preferences"]["dark_mode"]["available"] = retained_dark_available
	candidate["preferences"]["dark_mode"]["next_run_enabled"] = retained_pending_dark
	candidate["legacy_preferences_v1"] = {}
	return SCHEMA.validate(candidate)


func reset_controls(expected_revision: int = -1) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var checked := _check_profile_revision(expected_revision)
	if not checked.get("ok", false): return checked
	var prepared := _prepare_controls_reset()
	return _commit_reset(prepared["value"], &"controls", expected_revision) if prepared.get("ok", false) else prepared


func _prepare_controls_reset() -> Dictionary:
	var candidate := _profile.duplicate(true)
	candidate.controls_bindings = CONTROLS_RULES.defaults()
	candidate.controls_import_pending = false
	return SCHEMA.validate(candidate)


func reset_visited_history(expected_revision: int = -1) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var checked := _check_profile_revision(expected_revision)
	if not checked.get("ok", false): return checked
	var candidate := _profile.duplicate(true)
	candidate["visited_line_ids"] = []
	return _commit_reset(candidate, &"visited_history", expected_revision)


func reset_gallery(expected_revision: int = -1) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var checked := _check_profile_revision(expected_revision)
	if not checked.get("ok", false): return checked
	var candidate := _profile.duplicate(true)
	_preserve_legacy_ending_milestone(candidate)
	candidate["gallery_unlocks"] = []
	candidate["reached_presentations"] = {}
	candidate["preferences"]["exceptional_replay"]["available"] = false
	candidate["preferences"]["exceptional_replay"]["replay_full"] = false
	return _commit_reset(candidate, &"gallery", expected_revision)


func reset_entire_profile(expected_revision: int = -1) -> Dictionary:
	if not _initialized:
		return _failure(&"not_initialized", "ProfileManager is not initialized")
	var checked := _check_profile_revision(expected_revision)
	if not checked.get("ok", false): return checked
	var prepared := _prepare_entire_profile_reset()
	return _commit_reset(prepared["value"], &"entire_profile", expected_revision) if prepared.get("ok", false) else prepared


func _prepare_entire_profile_reset() -> Dictionary:
	var candidate := SCHEMA.make_defaults()
	candidate["gallery_transaction_receipts"] = _profile["gallery_transaction_receipts"].duplicate(true)
	candidate["migration_receipts"] = _profile["migration_receipts"].duplicate(true)
	# The accepted full-reset exception removes completion/milestone evidence, while unrelated
	# transaction receipts retain the existing reset contract. Clear Gallery keeps these IDs.
	for transaction_id: String in candidate.gallery_transaction_receipts.keys():
		var receipt: Dictionary = candidate.gallery_transaction_receipts[transaction_id]
		if transaction_id == "profile:legacy-ending-milestone" or (transaction_id.begins_with("ending:")
				and transaction_id.ends_with(":gallery:" + str(receipt.ending_id))):
			candidate.gallery_transaction_receipts.erase(transaction_id)
	return SCHEMA.validate(candidate)


func capture_restore_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"profile": _profile.duplicate(true)}}


func apply_restore_silent(plan: Dictionary) -> Dictionary:
	var candidate: Variant = plan.get("profile", plan.get("candidate"))
	if typeof(candidate) != TYPE_DICTIONARY:
		return _failure(&"invalid_restore_plan", "Restore plan requires a profile")
	var validation := SCHEMA.validate(candidate)
	if not validation.get("ok", false):
		return validation
	if not DATING_ATTEMPTS.preserves(_profile.dating_attempts, validation.value.dating_attempts):
		return _failure(&"dating_history_rewind", "Run restoration cannot rewind Profile Dating commitments")
	for key: String in ["observer_evidence", "pair_deck_draws", "reached_presentations"]:
		if not _preserves_receipts(_profile[key], validation.value[key]):
			return _failure(&"profile_evidence_rewind", "Run restoration cannot rewind durable Profile evidence")
	_restore_backup = _profile.duplicate(true)
	_profile = (validation["value"] as Dictionary).duplicate(true)
	_profile_revision += 1
	return {"ok": true, "code": &"ok"}


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("profile", _restore_backup)
	if typeof(source) != TYPE_DICTIONARY:
		return _failure(&"invalid_restore_backup", "Restore backup requires a profile")
	var validation := SCHEMA.validate(source)
	if not validation.get("ok", false):
		return validation
	_profile = (validation["value"] as Dictionary).duplicate(true)
	_profile_revision += 1
	_restore_backup = {}
	return {"ok": true, "code": &"ok"}


func validate_restore_ready() -> Dictionary:
	return SCHEMA.validate(_profile)

func publish_restore() -> void:
	_restore_backup = {}
	profile_restored.emit(_profile.duplicate(true))

func finalize_restore() -> Dictionary:
	var ready := validate_restore_ready()
	if not ready.get("ok", false): return ready
	publish_restore()
	return {"ok": true, "code": &"ok"}


func _commit_reset(candidate: Dictionary, section: StringName, expected_revision: int = -1) -> Dictionary:
	var result := _commit_prepared_reset(candidate, section, expected_revision)
	if not result.get("ok", false): return result
	return publish_deferred_profile_signals(result["value"]["publication_id"])


func _commit_prepared_reset(candidate: Dictionary, section: StringName, expected_revision: int = -1) -> Dictionary:
	var guarded := _guard(&"profile_commit")
	if not guarded.get("ok", false): return guarded
	var result := _commit_profile_candidate(candidate, true, expected_revision, section == &"entire_profile", section == &"gallery")
	if not result.get("ok", false):
		return result
	var publication_id: String = result["value"]["publication_id"]
	var record: Dictionary = _deferred_publications[publication_id]
	record["reset_section"] = section
	_deferred_publications[publication_id] = record
	return result


func _persist_candidate(candidate: Dictionary, migrating := false) -> Dictionary:
	if migrating:
		var checked := SCHEMA.validate(candidate)
		if not checked.get("ok", false): return checked
	var emitted: Dictionary = WRITER.stringify(candidate)
	if not emitted.get("ok", false):
		return emitted
	return _storage.call(&"write_atomic", "profile.json", emitted["value"], _profile_migration_text_validator if migrating else _profile_text_validator)


func _profile_migration_text_validator(text: String) -> Dictionary:
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false): return parsed
	return MIGRATION.prepare_document(parsed.value)


func _profile_text_validator(text: String) -> Dictionary:
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return parsed
	return SCHEMA.validate(parsed["value"])


func _import_legacy_input_mappings() -> Dictionary:
	if _profile["migration_receipts"]["legacy_input_bindings_v1"]:
		return {"ok": true, "code": &"ok", "unchanged": true}
	var reconciled: Dictionary = _storage.call(&"reconcile", "input_bindings.json",
		_legacy_input_text_validator)
	if not reconciled.get("ok", false):
		return reconciled
	if not reconciled.get("exists", false):
		return {"ok": true, "code": &"ok", "unchanged": true}
	var read_result: Dictionary = _storage.call(&"read_text", "input_bindings.json")
	if not read_result.get("ok", false):
		return read_result
	var parsed := STRICT_JSON.parse_object(read_result["value"])
	if not parsed.get("ok", false):
		return parsed
	var patch_result := MIGRATION.prepare_legacy_patch({}, parsed["value"])
	if not patch_result.get("ok", false):
		return patch_result
	var patch: Dictionary = patch_result["value"]
	var candidate := _profile.duplicate(true)
	for action_id: String in patch["input_mappings"]:
		if not candidate["input_mappings"].has(action_id):
			candidate["input_mappings"][action_id] = patch["input_mappings"][action_id].duplicate(true)
	var imported := CONTROLS_IMPORT.prepare(candidate["input_mappings"])
	candidate["controls_bindings"] = imported["bindings"]
	candidate["controls_import_pending"] = imported["pending"]
	candidate["migration_receipts"]["legacy_input_bindings_v1"] = true
	var validation := SCHEMA.validate(candidate)
	if not validation.get("ok", false):
		return validation
	var persisted := _persist_candidate(validation["value"])
	if not persisted.get("ok", false):
		return persisted
	_profile = (validation["value"] as Dictionary).duplicate(true)
	_profile_revision += 1
	return {"ok": true, "code": &"ok", "imported": true}


func _legacy_input_text_validator(text: String) -> Dictionary:
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return parsed
	var prepared := MIGRATION.prepare_legacy_patch({}, parsed["value"])
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "code": &"ok", "value": (parsed["value"] as Dictionary).duplicate(true)}


func _build_publication(old: Dictionary, current: Dictionary) -> Dictionary:
	var changes: Array[Dictionary] = []
	var preference_changes: Array[Dictionary] = []
	for record in PREFERENCE_REGISTRY.records():
		var path: StringName = record["path"]
		var before: Variant = _get_profile_path(old, path)
		var after: Variant = _get_profile_path(current, path)
		if before != after:
			preference_changes.append({"kind": &"preference", "id": path, "value": after})
	preference_changes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _utf8_less(String(a["id"]), String(b["id"])))
	changes.append_array(preference_changes)
	var old_actions: Dictionary = old["input_mappings"]
	var new_actions: Dictionary = current["input_mappings"]
	for action_id in _union_sorted(old_actions.keys(), new_actions.keys()):
		if old_actions.get(action_id) != new_actions.get(action_id):
			changes.append({"kind": &"input", "id": StringName(action_id)})
	if old.controls_bindings != current.controls_bindings or old.controls_import_pending != current.controls_import_pending:
		changes.append({"kind": &"controls"})
	for ending_id in SCHEMA.ENDING_IDS:
		var before: bool = ending_id in old["gallery_unlocks"]
		var after: bool = ending_id in current["gallery_unlocks"]
		if before != after:
			changes.append({"kind": &"gallery", "id": ending_id, "value": after})
	for line_id in _union_sorted(old["visited_line_ids"], current["visited_line_ids"]):
		var before: bool = line_id in old["visited_line_ids"]
		var after: bool = line_id in current["visited_line_ids"]
		if before != after:
			changes.append({"kind": &"visited", "id": line_id, "value": after})
	return {"changes": changes}


func _publish(publication: Dictionary) -> void:
	for change: Dictionary in publication.get("changes", []):
		match change["kind"]:
			&"preference":
				preference_changed.emit(change["id"], _duplicate_variant(change["value"]))
			&"input":
				input_mappings_changed.emit(change["id"])
			&"controls":
				controls_bindings_changed.emit()
			&"gallery":
				gallery_changed.emit(change["id"], change["value"])
			&"visited":
				visited_history_changed.emit(change["id"], change["value"])
	if publication.has("reset_section"):
		profile_reset.emit(publication["reset_section"])


func _guard(operation_id: StringName) -> Dictionary:
	if _mutation_gate == null:
		return {"ok": true, "code": &"ok"}
	return _mutation_gate.call(&"guard_external", operation_id)


func _get_profile_path(profile: Dictionary, path: StringName, default_value: Variant = null) -> Variant:
	var segments := String(path).split(".")
	if segments.size() != 3 or segments[0] != "preferences":
		return default_value
	return profile.get("preferences", {}).get(segments[1], {}).get(segments[2], default_value)


func _set_profile_path(profile: Dictionary, path: StringName, value: Variant) -> void:
	var segments := String(path).split(".")
	profile["preferences"][segments[1]][segments[2]] = _duplicate_variant(value)


func _is_registered_preference_path(path: StringName) -> bool:
	for record in PREFERENCE_REGISTRY.records():
		if record["path"] == path:
			return true
	return false


func _canonical_locale_id(locale_id: String) -> String:
	match locale_id:
		"zh_cn":
			return "zh_CN"
		"zh_hk":
			return "zh_HK"
		_:
			return locale_id


func _fallback_secondary_locale(primary_locale_id: String, previous_primary_locale_id: String) -> String:
	var locale_ids := _registered_locale_ids()
	if previous_primary_locale_id != primary_locale_id and previous_primary_locale_id in locale_ids:
		return previous_primary_locale_id
	for locale_id in locale_ids:
		if locale_id != primary_locale_id:
			return locale_id
	return primary_locale_id


func _registered_locale_ids() -> Array:
	for record in PREFERENCE_REGISTRY.records():
		if record["path"] == PRIMARY_LOCALE_PATH:
			return (record["allowed_values"] as Array).duplicate()
	return []


func _union_sorted(left: Array, right: Array) -> Array:
	var union := {}
	for value in left + right:
		union[str(value)] = true
	var output: Array = union.keys()
	output.sort_custom(func(a: String, b: String) -> bool: return _utf8_less(a, b))
	return output


func _utf8_name_less(left: StringName, right: StringName) -> bool:
	return _utf8_less(String(left), String(right))


func _utf8_less(left: String, right: String) -> bool:
	var left_bytes := left.to_utf8_buffer()
	var right_bytes := right.to_utf8_buffer()
	for index in range(mini(left_bytes.size(), right_bytes.size())):
		if left_bytes[index] != right_bytes[index]:
			return left_bytes[index] < right_bytes[index]
	return left_bytes.size() < right_bytes.size()


func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _failure(code: StringName, message: String, fatal: bool = false) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "fatal": fatal}


func _command_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}


# The fingerprint, rather than an empty index, distinguishes an explicitly configured empty
# registry from the unconfigured state.
var _line_registry_index: Dictionary = {}
var _line_registry_fingerprint := ""


func configure_line_registry(registry: Dictionary) -> Dictionary:
	var block: Variant = registry.get("reply_lines")
	if not (block is Array):
		return _command_failure(&"invalid_line_registry")
	var index: Dictionary = {}
	for record: Variant in (block as Array):
		if not (record is Dictionary):
			return _command_failure(&"invalid_line_record")
		var line_id: Variant = (record as Dictionary).get("line_id")
		if typeof(line_id) != TYPE_STRING or (line_id as String).is_empty():
			return _command_failure(&"invalid_line_record_id")
		index[line_id] = true
	var atoms: Variant = registry.get("atoms", [])
	if not (atoms is Array):
		return _command_failure(&"invalid_line_registry")
	for atom: Variant in (atoms as Array):
		if not (atom is Dictionary):
			return _command_failure(&"invalid_line_registry")
		if (atom as Dictionary).get("kind") != "observer_presentation":
			continue
		var observer_line: Variant = (atom as Dictionary).get("associated_line_id")
		if typeof(observer_line) != TYPE_STRING or (observer_line as String).is_empty():
			return _command_failure(&"invalid_observer_line_id")
		index[observer_line] = true
	var emitted: Dictionary = WRITER.stringify(index)
	if not emitted.get("ok", false):
		return _command_failure(&"unfingerprintable_line_registry")
	var fingerprint: String = str(emitted["value"]).sha256_text()
	if not _line_registry_fingerprint.is_empty() and _line_registry_fingerprint != fingerprint:
		return _command_failure(&"line_registry_already_configured")
	var already := not _line_registry_fingerprint.is_empty()
	_line_registry_index = index
	_line_registry_fingerprint = fingerprint
	return {"ok": true, "code": &"ok", "value": {"line_count": index.size(),
		"registry_fingerprint": fingerprint, "already_configured": already}, "receipt": {}}


func _line_registry_admits(line_id: String) -> bool:
	if _line_registry_fingerprint.is_empty():
		return false
	return _line_registry_index.has(line_id)
