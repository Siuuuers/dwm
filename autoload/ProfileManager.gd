extends Node

signal profile_restored(profile: Dictionary)
signal preference_changed(path: StringName, value: Variant)
signal gallery_changed(ending_id: String, unlocked: bool)
signal visited_history_changed(line_id: String, visited: bool)
signal input_mappings_changed(action_id: StringName)
signal profile_reset(section: StringName)
signal profile_write_failed(result: Dictionary)

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _storage: RefCounted
var _profile: Dictionary = {}
var _initialized := false
var _mutation_blocked := false
var _mutation_gate: Object
var _deferred_publications: Dictionary = {}
var _publication_counter := 0
var _pending_gallery_publications: Dictionary = {}
var _restore_backup: Dictionary = {}
var _profile_existed_at_initialize := false

func _ready() -> void:
	pass

func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _command_failure(&"invalid_mutation_gate")
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return _command_failure(&"invalid_mutation_gate")
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id():
		return _command_failure(&"mutation_gate_already_configured")
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}

func initialize(storage: RefCounted = null) -> Dictionary:
	if _initialized: return _failure(&"already_initialized", "ProfileManager initializes exactly once")
	if storage == null: return _failure(&"invalid_storage", "A storage adapter is required")
	_storage = storage
	var reconciled: Dictionary = _storage.call(&"reconcile", "profile.json", _profile_text_validator)
	if not reconciled.get("ok", false):
		if reconciled.get("code") == &"indeterminate_commit" or reconciled.get("fatal", false): _mutation_blocked = true
		return reconciled
	if not reconciled.get("exists", false):
		var defaults := SCHEMA.make_defaults()
		var persisted := _persist_candidate(defaults)
		if not persisted.get("ok", false): return persisted
		_profile = defaults.duplicate(true)
	else:
		_profile_existed_at_initialize = true
		var text_result: Dictionary = _storage.call(&"read_text", "profile.json")
		if not text_result.get("ok", false): return text_result
		var parsed: Dictionary = STRICT_JSON.parse_object(text_result["value"])
		if not parsed.get("ok", false): return parsed
		var prepared: Dictionary = MIGRATION.prepare_document(parsed["value"])
		if not prepared.get("ok", false): return prepared
		_profile = (prepared["value"] as Dictionary).duplicate(true)
		if prepared.get("migrated", false):
			var migrated_write := _persist_candidate(_profile)
			if not migrated_write.get("ok", false): return migrated_write
	var legacy_input_import := _import_legacy_input_mappings()
	if not legacy_input_import.get("ok", false): return legacy_input_import
	_initialized = true
	profile_restored.emit(_profile.duplicate(true))
	return {"ok": true, "value": _profile.duplicate(true)}

func prepare_profile_document(raw: Dictionary) -> Dictionary:
	return MIGRATION.prepare_document(raw.duplicate(true))

func prepare_preferences(changes: Dictionary) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "ProfileManager is not initialized")
	var candidate := _profile.duplicate(true)
	if changes.is_empty(): return {"ok": true, "value": candidate, "changed_paths": []}
	var normalized: Dictionary = {}
	for path_value in changes:
		if typeof(path_value) != TYPE_STRING_NAME:
			return _failure(&"invalid_preference_path", "Preference batch keys must be StringName")
		var path: StringName = path_value
		if path == &"preferences.language": return _failure(&"managed_preference", "Language is managed by locale preparation")
		var validated := SCHEMA.validate_preference(path, changes[path_value])
		if not validated.get("ok", false): return validated
		normalized[path] = validated["value"]
	var paths: Array = normalized.keys()
	paths.sort_custom(_utf8_name_less)
	for path: StringName in paths:
		_set_profile_path(candidate, path, normalized[path])
	var document_validation := SCHEMA.validate(candidate)
	if not document_validation.get("ok", false): return document_validation
	return {"ok": true, "value": document_validation["value"], "changed_paths": paths.duplicate()}

func prepare_locale_preference(locale_id: String) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "ProfileManager is not initialized")
	var validated := SCHEMA.validate_preference(&"preferences.language", locale_id)
	if not validated.get("ok", false): return validated
	var candidate := _profile.duplicate(true)
	_set_profile_path(candidate, &"preferences.language", locale_id)
	return {"ok": true, "value": candidate, "changed_paths": [&"preferences.language"]}

func commit_prepared_profile(candidate: Dictionary, defer_signals: bool = false) -> Dictionary:
	var guarded := _guard(&"profile_commit")
	if not guarded.get("ok", false): return guarded
	if not _initialized: return _failure(&"not_initialized", "ProfileManager is not initialized")
	if _mutation_blocked: return _failure(&"indeterminate_commit", "Profile mutation is blocked", true)
	var validation := SCHEMA.validate(candidate.duplicate(true))
	if not validation.get("ok", false): return validation
	var detached: Dictionary = validation["value"]
	var old := _profile.duplicate(true)
	var persisted := _persist_candidate(detached)
	if not persisted.get("ok", false):
		if persisted.get("fatal", false) or persisted.get("code") == &"indeterminate_commit": _mutation_blocked = true
		profile_write_failed.emit(persisted.duplicate(true))
		return persisted
	_profile = detached.duplicate(true)
	var publication := _build_publication(old, _profile)
	if defer_signals:
		_publication_counter += 1
		var publication_id := "profile-publication-%d" % _publication_counter
		_deferred_publications[publication_id] = publication.duplicate(true)
		for transaction_id in _profile["gallery_transaction_receipts"]:
			if not old["gallery_transaction_receipts"].has(transaction_id):
				_pending_gallery_publications[transaction_id] = publication_id
		return {"ok": true, "value": {"publication_id": publication_id}}
	_publish(publication)
	return {"ok": true, "value": _profile.duplicate(true)}

func publish_deferred_profile_signals(publication_id: String) -> Dictionary:
	if publication_id.is_empty() or not _deferred_publications.has(publication_id):
		return _failure(&"unknown_publication", "Publication ID is unknown or already consumed")
	var publication: Dictionary = _deferred_publications[publication_id]
	_deferred_publications.erase(publication_id)
	_publish(publication.duplicate(true))
	for transaction_id in _pending_gallery_publications.keys():
		if _pending_gallery_publications[transaction_id] == publication_id: _pending_gallery_publications.erase(transaction_id)
	return {"ok": true, "value": {"publication_id": publication_id}}

func get_profile_snapshot() -> Dictionary:
	return _profile.duplicate(true)

func get_preference(path: StringName, default_value: Variant = null) -> Variant:
	if not SCHEMA.PREFERENCE_DEFAULTS.has(String(path)): return default_value
	return _get_profile_path(_profile, path, default_value)

func set_preference(path: StringName, value: Variant) -> Dictionary:
	if path == &"preferences.language": return _failure(&"managed_preference", "Language is managed by LocalizationManager")
	return set_preferences({path: value})

func set_preferences(changes: Dictionary) -> Dictionary:
	var prepared := prepare_preferences(changes)
	if not prepared.get("ok", false): return prepared
	if prepared["changed_paths"].is_empty(): return {"ok": true, "value": _profile.duplicate(true), "unchanged": true}
	return commit_prepared_profile(prepared["value"])

func is_line_visited(line_id: String) -> bool:
	return line_id in _profile.get("visited_line_ids", [])

func mark_line_visited(line_id: String) -> Dictionary:
	if line_id.is_empty(): return _failure(&"invalid_line_id", "Line ID must be nonempty")
	if is_line_visited(line_id): return {"ok": true, "value": {"visited": true}, "unchanged": true}
	var candidate := _profile.duplicate(true)
	candidate["visited_line_ids"].append(line_id)
	return commit_prepared_profile(candidate)

func has_gallery_unlock(ending_id: String) -> bool:
	return ending_id in _profile.get("gallery_unlocks", [])

func prepare_ending_unlock(ending_id: String, transaction_id: String) -> Dictionary:
	if ending_id not in SCHEMA.ENDING_IDS or transaction_id.is_empty(): return _failure(&"invalid_gallery_transaction", "Ending and transaction IDs must be valid")
	var ledger: Dictionary = _profile["gallery_transaction_receipts"]
	if ledger.has(transaction_id):
		var prior: Dictionary = ledger[transaction_id]
		if prior["ending_id"] != ending_id: return _failure(&"gallery_transaction_conflict", "Transaction ID belongs to another ending")
		return {"ok": true, "value": {"candidate": _profile.duplicate(true), "transaction_id": transaction_id, "gallery_receipt": prior.duplicate(true), "requires_commit": false, "pending_publication_id": _pending_gallery_publications.get(transaction_id, "")}}
	var candidate := _profile.duplicate(true)
	var unlocked := not has_gallery_unlock(ending_id)
	var receipt := {"ending_id": ending_id, "unlocked": unlocked}
	candidate["gallery_transaction_receipts"][transaction_id] = receipt.duplicate(true)
	if unlocked: candidate["gallery_unlocks"].append(ending_id)
	return {"ok": true, "value": {"candidate": candidate, "transaction_id": transaction_id, "gallery_receipt": receipt, "requires_commit": true, "pending_publication_id": ""}}

func unlock_ending(ending_id: String, transaction_id: String) -> Dictionary:
	var prepared := prepare_ending_unlock(ending_id, transaction_id)
	if not prepared.get("ok", false): return prepared
	var value: Dictionary = prepared["value"]
	if value["requires_commit"]:
		var committed := commit_prepared_profile(value["candidate"])
		if not committed.get("ok", false): return committed
	return {"ok": true, "value": (value["gallery_receipt"] as Dictionary).duplicate(true)}

func get_input_mappings() -> Dictionary:
	return (_profile.get("input_mappings", {}) as Dictionary).duplicate(true)

func set_input_mapping(action_id: StringName, events: Array[Dictionary]) -> Dictionary:
	if String(action_id).is_empty(): return _failure(&"invalid_action_id", "Action ID must be nonempty")
	var candidate := _profile.duplicate(true)
	candidate["input_mappings"][String(action_id)] = events.duplicate(true)
	return commit_prepared_profile(candidate)

func prepare_legacy_profile_patch(legacy_run_state: Dictionary, legacy_input_mappings: Dictionary = {}) -> Dictionary:
	if not _initialized: return _failure(&"not_initialized", "ProfileManager is not initialized")
	if _profile["migration_receipts"]["legacy_game_state_profile_v1"]:
		return {"ok": true, "value": _profile.duplicate(true), "unchanged": true}
	var prepared := MIGRATION.prepare_legacy_patch(legacy_run_state.duplicate(true), legacy_input_mappings.duplicate(true))
	if not prepared.get("ok", false): return prepared
	var patch: Dictionary = prepared["value"]
	var candidate := _profile.duplicate(true)
	if not _profile_existed_at_initialize:
		candidate["preferences"] = patch["preferences"].duplicate(true)
	for action_id in patch["input_mappings"]:
		if not candidate["input_mappings"].has(action_id): candidate["input_mappings"][action_id] = patch["input_mappings"][action_id].duplicate(true)
	for ending_id in patch["gallery_unlocks"]:
		if ending_id not in candidate["gallery_unlocks"]: candidate["gallery_unlocks"].append(ending_id)
	candidate["gallery_unlocks"].sort()
	candidate["migration_receipts"]["legacy_game_state_profile_v1"] = true
	if patch["migration_receipts"]["legacy_input_bindings_v1"]: candidate["migration_receipts"]["legacy_input_bindings_v1"] = true
	return SCHEMA.validate(candidate)

func reset_preferences() -> Dictionary:
	var candidate := _profile.duplicate(true)
	candidate["preferences"] = SCHEMA.make_defaults()["preferences"]
	return _commit_reset(candidate, &"preferences")

func reset_visited_history() -> Dictionary:
	var candidate := _profile.duplicate(true)
	candidate["visited_line_ids"] = []
	return _commit_reset(candidate, &"visited_history")

func reset_gallery() -> Dictionary:
	var candidate := _profile.duplicate(true)
	candidate["gallery_unlocks"] = []
	return _commit_reset(candidate, &"gallery")

func reset_entire_profile() -> Dictionary:
	var candidate := SCHEMA.make_defaults()
	candidate["gallery_transaction_receipts"] = _profile["gallery_transaction_receipts"].duplicate(true)
	candidate["migration_receipts"] = _profile["migration_receipts"].duplicate(true)
	return _commit_reset(candidate, &"entire_profile")

func capture_restore_state() -> Dictionary:
	return {"ok": true, "value": {"profile": _profile.duplicate(true)}}

func apply_restore_silent(plan: Dictionary) -> Dictionary:
	var candidate: Variant = plan.get("profile", plan.get("candidate"))
	if typeof(candidate) != TYPE_DICTIONARY: return _failure(&"invalid_restore_plan", "Restore plan requires a profile")
	var validation := SCHEMA.validate(candidate)
	if not validation.get("ok", false): return validation
	_restore_backup = _profile.duplicate(true)
	_profile = (validation["value"] as Dictionary).duplicate(true)
	return {"ok": true}

func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("profile", _restore_backup)
	if typeof(source) != TYPE_DICTIONARY: return _failure(&"invalid_restore_backup", "Restore backup requires a profile")
	var validation := SCHEMA.validate(source)
	if not validation.get("ok", false): return validation
	_profile = (validation["value"] as Dictionary).duplicate(true)
	_restore_backup = {}
	return {"ok": true}

func finalize_restore() -> Dictionary:
	_restore_backup = {}
	profile_restored.emit(_profile.duplicate(true))
	return {"ok": true}

func _commit_reset(candidate: Dictionary, section: StringName) -> Dictionary:
	var result := commit_prepared_profile(candidate, true)
	if not result.get("ok", false): return result
	var publication_id: String = result["value"]["publication_id"]
	var record: Dictionary = _deferred_publications[publication_id]
	record["reset_section"] = section
	_deferred_publications[publication_id] = record
	return publish_deferred_profile_signals(publication_id)

func _persist_candidate(candidate: Dictionary) -> Dictionary:
	var emitted: Dictionary = WRITER.stringify(candidate)
	if not emitted.get("ok", false): return emitted
	return _storage.call(&"write_atomic", "profile.json", emitted["value"], _profile_text_validator)

func _profile_text_validator(text: String) -> Dictionary:
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false): return parsed
	return MIGRATION.prepare_document(parsed["value"])

func _import_legacy_input_mappings() -> Dictionary:
	if _profile["migration_receipts"]["legacy_input_bindings_v1"]: return {"ok": true, "unchanged": true}
	var reconciled: Dictionary = _storage.call(&"reconcile", "input_bindings.json", _legacy_input_text_validator)
	if not reconciled.get("ok", false):
		if reconciled.get("code") == &"indeterminate_transaction": return reconciled
		return reconciled
	if not reconciled.get("exists", false): return {"ok": true, "unchanged": true}
	var read_result: Dictionary = _storage.call(&"read_text", "input_bindings.json")
	if not read_result.get("ok", false): return read_result
	var parsed := STRICT_JSON.parse_object(read_result["value"])
	if not parsed.get("ok", false): return parsed
	var patch_result := MIGRATION.prepare_legacy_patch({}, parsed["value"])
	if not patch_result.get("ok", false): return patch_result
	var patch: Dictionary = patch_result["value"]
	var candidate := _profile.duplicate(true)
	for action_id in patch["input_mappings"]:
		if not candidate["input_mappings"].has(action_id): candidate["input_mappings"][action_id] = patch["input_mappings"][action_id].duplicate(true)
	candidate["migration_receipts"]["legacy_input_bindings_v1"] = true
	var persisted := _persist_candidate(candidate)
	if not persisted.get("ok", false): return persisted
	_profile = candidate.duplicate(true)
	return {"ok": true, "imported": true}

func _legacy_input_text_validator(text: String) -> Dictionary:
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false): return parsed
	var prepared := MIGRATION.prepare_legacy_patch({}, parsed["value"])
	if not prepared.get("ok", false): return prepared
	return {"ok": true, "value": (parsed["value"] as Dictionary).duplicate(true)}

func _build_publication(old: Dictionary, current: Dictionary) -> Dictionary:
	var changes: Array[Dictionary] = []
	for path_value in SCHEMA.PREFERENCE_DEFAULTS:
		var path := StringName(path_value)
		var before: Variant = _get_profile_path(old, path)
		var after: Variant = _get_profile_path(current, path)
		if before != after: changes.append({"kind": &"preference", "id": path, "value": after})
	var old_actions: Dictionary = old["input_mappings"]
	var new_actions: Dictionary = current["input_mappings"]
	for action_id in _union_sorted(old_actions.keys(), new_actions.keys()):
		if old_actions.get(action_id) != new_actions.get(action_id): changes.append({"kind": &"input", "id": StringName(action_id)})
	for ending_id in SCHEMA.ENDING_IDS:
		var before: bool = ending_id in old["gallery_unlocks"]
		var after: bool = ending_id in current["gallery_unlocks"]
		if before != after: changes.append({"kind": &"gallery", "id": ending_id, "value": after})
	for line_id in _union_sorted(old["visited_line_ids"], current["visited_line_ids"]):
		var before: bool = line_id in old["visited_line_ids"]
		var after: bool = line_id in current["visited_line_ids"]
		if before != after: changes.append({"kind": &"visited", "id": line_id, "value": after})
	return {"changes": changes}

func _publish(publication: Dictionary) -> void:
	for change: Dictionary in publication.get("changes", []):
		match change["kind"]:
			&"preference": preference_changed.emit(change["id"], _duplicate_variant(change["value"]))
			&"input": input_mappings_changed.emit(change["id"])
			&"gallery": gallery_changed.emit(change["id"], change["value"])
			&"visited": visited_history_changed.emit(change["id"], change["value"])
	if publication.has("reset_section"): profile_reset.emit(publication["reset_section"])

func _guard(operation_id: StringName) -> Dictionary:
	if _mutation_gate == null: return {"ok": true}
	return _mutation_gate.call(&"guard_external", operation_id)

func _get_profile_path(profile: Dictionary, path: StringName, default_value: Variant = null) -> Variant:
	var segments := String(path).split(".")
	if segments.size() == 2 and segments[0] == "preferences":
		return profile.get("preferences", {}).get(segments[1], default_value)
	if segments.size() != 3: return default_value
	return profile.get("preferences", {}).get(segments[1], {}).get(segments[2], default_value)

func _set_profile_path(profile: Dictionary, path: StringName, value: Variant) -> void:
	var segments := String(path).split(".")
	if segments.size() == 2 and segments[0] == "preferences":
		profile["preferences"][segments[1]] = _duplicate_variant(value)
		return
	profile["preferences"][segments[1]][segments[2]] = _duplicate_variant(value)

func _union_sorted(left: Array, right: Array) -> Array:
	var union := {}
	for value in left + right: union[str(value)] = true
	var output: Array = union.keys()
	output.sort_custom(func(a: String, b: String) -> bool: return _utf8_less(a, b))
	return output

func _utf8_name_less(left: StringName, right: StringName) -> bool:
	return _utf8_less(String(left), String(right))

func _utf8_less(left: String, right: String) -> bool:
	var left_bytes := left.to_utf8_buffer()
	var right_bytes := right.to_utf8_buffer()
	for index in range(mini(left_bytes.size(), right_bytes.size())):
		if left_bytes[index] != right_bytes[index]: return left_bytes[index] < right_bytes[index]
	return left_bytes.size() < right_bytes.size()

func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary or value is Array: return value.duplicate(true)
	return value

func _failure(code: StringName, message: String, fatal: bool = false) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "fatal": fatal}

func _command_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
