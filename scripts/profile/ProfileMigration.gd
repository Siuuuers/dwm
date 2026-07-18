class_name ProfileMigration
extends RefCounted

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")

static func prepare_document(raw: Dictionary) -> Dictionary:
	var detached := raw.duplicate(true)
	var direct := SCHEMA.validate(detached)
	if direct.get("ok", false):
		return direct
	if detached.get("schema_version") != 1:
		return direct
	var preferences: Variant = detached.get("preferences")
	if typeof(preferences) != TYPE_DICTIONARY or typeof(preferences.get("dialogue")) != TYPE_DICTIONARY or not preferences["dialogue"].has("skip_mode"):
		return direct
	preferences["dialogue"]["skip_mode"] = "read_only"
	if typeof(detached.get("migration_receipts")) != TYPE_DICTIONARY:
		return direct
	detached["migration_receipts"]["invalid_persisted_skip_mode_v1"] = true
	var repaired := SCHEMA.validate(detached)
	if not repaired.get("ok", false):
		return direct
	return {"ok": true, "value": repaired["value"], "migrated": true, "migration_id": &"invalid_persisted_skip_mode_v1"}

static func prepare_legacy_patch(legacy_run_state: Dictionary, legacy_input_mappings: Dictionary = {}) -> Dictionary:
	var patch := {"preferences": {}, "input_mappings": {}, "migration_receipts": {}}
	if legacy_run_state.has("skip_unseen_text_allowed"):
		if typeof(legacy_run_state["skip_unseen_text_allowed"]) != TYPE_BOOL:
			return {"ok": false, "code": &"invalid_legacy_profile", "message": "skip_unseen_text_allowed must be boolean"}
		patch["preferences"][&"preferences.dialogue.skip_mode"] = "all_text" if legacy_run_state["skip_unseen_text_allowed"] else "read_only"
	patch["migration_receipts"]["legacy_game_state_profile_v1"] = true
	if not legacy_input_mappings.is_empty():
		var candidate := SCHEMA.make_defaults()
		candidate["input_mappings"] = legacy_input_mappings.duplicate(true)
		var validation := SCHEMA.validate(candidate)
		if not validation.get("ok", false): return validation
		patch["input_mappings"] = legacy_input_mappings.duplicate(true)
		patch["migration_receipts"]["legacy_input_bindings_v1"] = true
	return {"ok": true, "value": patch.duplicate(true)}
