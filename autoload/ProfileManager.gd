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
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const PREFERENCE_REGISTRY := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONTROLS_RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const CONTROLS_IMPORT := preload("res://scripts/settings/ControlsBindingImport.gd")

const PRIMARY_LOCALE_PATH := &"preferences.language.primary_locale_id"
const _AUDIO_MEMORY_SURFACES := [&"META_POST_ENDING_TITLE", &"META_BACKUP_LOAD", &"META_GALLERY_REPLAY"]

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
		if validation.get("migrated", false):
			var persisted := _persist_candidate(validation["value"], true)
			if not persisted.get("ok", false):
				if persisted.get("fatal", false) or persisted.get("code") == &"indeterminate_commit":
					_mutation_blocked = true
				return persisted
		_profile = (validation["value"] as Dictionary).duplicate(true)
		_profile_revision += 1
	var imported := _import_legacy_input_mappings()
	if not imported.get("ok", false):
		return imported
	_initialized = true
	profile_restored.emit(_profile.duplicate(true))
	return {"ok": true, "code": &"ok", "value": _profile.duplicate(true)}


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
		if path == PRIMARY_LOCALE_PATH:
			return _failure(&"managed_preference", "Primary language is managed by locale preparation")
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


func commit_prepared_profile(candidate: Dictionary, defer_signals: bool = false, expected_revision: int = -1) -> Dictionary:
	var guarded := _guard(&"profile_commit")
	if not guarded.get("ok", false):
		return guarded
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
	if not _line_registry_admits(line_id):
		return _failure(&"unregistered_line_id", "Line ID is absent from the configured registry")
	if is_line_visited(line_id):
		return {"ok": true, "code": &"ok", "value": {"visited": true}, "unchanged": true}
	var candidate := _profile.duplicate(true)
	candidate["visited_line_ids"].append(line_id)
	return commit_prepared_profile(candidate)


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
	candidate["gallery_unlocks"] = []
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
	var result := commit_prepared_profile(candidate, true, expected_revision)
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
# registry from the legacy unconfigured state.
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
		return true
	return _line_registry_index.has(line_id)
