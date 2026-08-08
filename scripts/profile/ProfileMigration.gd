class_name ProfileMigration
extends RefCounted

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")

## The retired true-path ending ids and their true-observation replacements (story/05 sec 1).
## Sylvia has no Observer end, so a legacy sylvia.true unlock folds into her Special.
const _RETIRED_ENDING_MAP := {
	"ending.priscilla.true": "ending.priscilla.observation",
	"ending.lavinia.true": "ending.lavinia.observation",
	"ending.sylvia.true": "ending.sylvia.special",
}

static func _remap_retired_gallery_unlocks(document: Dictionary) -> void:
	var unlocks: Variant = document.get("gallery_unlocks")
	if typeof(unlocks) != TYPE_ARRAY:
		return
	var remapped: Array = []
	for entry: Variant in unlocks:
		var id := str(_RETIRED_ENDING_MAP.get(entry, entry))
		if id not in remapped:
			remapped.append(id)
	remapped.sort()
	document["gallery_unlocks"] = remapped

static func prepare_document(raw: Dictionary) -> Dictionary:
	var detached := raw.duplicate(true)
	_remap_retired_gallery_unlocks(detached)
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
	var patch := SCHEMA.make_defaults()
	patch["gallery_unlocks"] = []
	patch["gallery_transaction_receipts"] = {}
	patch["visited_line_ids"] = []
	patch["migration_receipts"]["legacy_game_state_profile_v1"] = true
	var settings: Variant = legacy_run_state.get("settings", {})
	if typeof(settings) != TYPE_DICTIONARY: return _legacy_failure("settings must be an object")
	var setting_map := {
		"language": ["language"],
		"music_volume": ["audio", "music_volume"], "voice_volume": ["audio", "voice_volume"],
		"sfx_volume": ["audio", "sfx_volume"], "ambience_volume": ["audio", "ambience_volume"],
		"mute_audio_on_focus_loss": ["audio", "mute_audio_on_focus_loss"],
		"text_speed": ["dialogue", "text_speed"], "auto_text_speed": ["dialogue", "auto_text_speed"],
		"auto_advance_dialogue": ["dialogue", "auto_advance_dialogue"],
		"fullscreen": ["display", "fullscreen"],
	}
	for key in ["font_scale", "high_contrast", "reduced_motion", "screen_shake_strength", "large_click_targets", "hold_to_confirm", "colorblind_mode", "show_focus_ring", "controller_cursor_enabled", "subtitles_enabled", "captions_enabled", "subtitle_speaker_names", "subtitle_background_opacity", "text_box_opacity", "visual_audio_cues", "flashing_effects_enabled", "tutorial_replay_available", "pause_on_focus_loss"]:
		setting_map[key] = ["accessibility", key]
	for key_value in settings:
		var key: String = key_value
		if key == "skip_unseen_text_allowed":
			if typeof(settings[key]) != TYPE_BOOL: return _legacy_failure("skip_unseen_text_allowed must be boolean")
			patch["preferences"]["dialogue"]["skip_mode"] = "all_text" if settings[key] else "read_only"
			continue
		if not setting_map.has(key): return {"ok": false, "code": &"unknown_legacy_profile_key", "message": key}
		var destination: Array = setting_map[key]
		if destination.size() == 1: patch["preferences"][destination[0]] = settings[key]
		else: patch["preferences"][destination[0]][destination[1]] = settings[key]
	var audio_state: Variant = legacy_run_state.get("audio_state", {})
	if typeof(audio_state) != TYPE_DICTIONARY: return _legacy_failure("audio_state must be an object")
	for key_value in audio_state:
		var key: String = key_value
		if key == "music_muted":
			if typeof(audio_state[key]) != TYPE_BOOL: return _legacy_failure("music_muted must be boolean")
			patch["preferences"]["audio"]["music_muted"] = audio_state[key]
		elif key in ["current_bgm_id", "current_ambience_id", "current_context_id"]:
			if typeof(audio_state[key]) != TYPE_STRING: return _legacy_failure(key + " must be a String")
		elif key == "current_context":
			if typeof(audio_state[key]) != TYPE_DICTIONARY: return _legacy_failure("current_context must be an object")
		else:
			return {"ok": false, "code": &"unknown_legacy_profile_key", "message": "audio_state." + key}
	var ending_map := {
		"alone": "ending.alone", "lavinia_priscilla": "ending.priscilla_lavinia",
		"ending.priscilla.true": "ending.priscilla.observation",
		"ending.lavinia.true": "ending.lavinia.observation",
		"ending.sylvia.true": "ending.sylvia.special",
	}
	var seen: Variant = legacy_run_state.get("seen_endings", {})
	if typeof(seen) != TYPE_DICTIONARY: return _legacy_failure("seen_endings must be an object")
	for ending_value in seen:
		var legacy_id: String = ending_value
		if typeof(seen[legacy_id]) != TYPE_BOOL: return _legacy_failure("seen ending values must be booleans")
		if not seen[legacy_id]: continue
		var canonical: String = ending_map.get(legacy_id, legacy_id)
		if canonical not in SCHEMA.ENDING_IDS: return _legacy_failure("unknown legacy ending: " + legacy_id)
		if canonical not in patch["gallery_unlocks"]: patch["gallery_unlocks"].append(canonical)
	patch["gallery_unlocks"].sort()
	var registered_actions := ["game_quick_save", "game_quick_load", "game_open_log", "game_skip_text", "game_toggle_auto", "game_hint", "game_new_board", "game_close_window", "game_next_tab", "game_prev_tab", "game_page_next", "game_page_prev", "game_open_settings", "game_open_schedule", "game_open_contacts"]
	for action_value in legacy_input_mappings:
		var action_id: String = action_value
		if action_id not in registered_actions: continue
		if typeof(legacy_input_mappings[action_id]) != TYPE_ARRAY: return _legacy_failure("registered input mapping must be an array")
		var records: Array = []
		for code in legacy_input_mappings[action_id]:
			if typeof(code) != TYPE_INT: return _legacy_failure("legacy physical keycode must be an integer")
			records.append({"kind": "key", "physical_keycode": code, "keycode": 0, "shift": false, "alt": false, "ctrl": false, "meta": false})
		patch["input_mappings"][action_id] = records
	if not legacy_input_mappings.is_empty(): patch["migration_receipts"]["legacy_input_bindings_v1"] = true
	var validation := SCHEMA.validate(patch)
	if not validation.get("ok", false): return validation
	return {"ok": true, "value": (validation["value"] as Dictionary).duplicate(true)}

static func _legacy_failure(message: String) -> Dictionary:
	return {"ok": false, "code": &"invalid_legacy_profile", "message": message}
