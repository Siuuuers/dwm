class_name ProfileMigration
extends RefCounted

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const CONTROLS_RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const CONTROLS_IMPORT := preload("res://scripts/settings/ControlsBindingImport.gd")

const _RETIRED_ENDING_MAP := {
	"ending.priscilla.true": "ending.priscilla.observation",
	"ending.lavinia.true": "ending.lavinia.observation",
	"ending.sylvia.true": "ending.sylvia.special",
}
const _LEGACY_ENDING_MAP := {
	"alone": "ending.alone",
	"lavinia_priscilla": "ending.priscilla_lavinia",
	"ending.priscilla.true": "ending.priscilla.observation",
	"ending.lavinia.true": "ending.lavinia.observation",
	"ending.sylvia.true": "ending.sylvia.special",
}
const _REGISTERED_LEGACY_ACTIONS := [
	"game_quick_save", "game_quick_load", "game_open_log", "game_skip_text",
	"game_toggle_auto", "game_hint", "game_new_board", "game_close_window",
	"game_next_tab", "game_prev_tab", "game_page_next", "game_page_prev",
	"game_open_settings", "game_open_schedule", "game_open_contacts",
]


static func prepare_document(raw: Dictionary) -> Dictionary:
	var detached := raw.duplicate(true)
	_remap_retired_gallery_unlocks(detached)
	var version: Variant = detached.get("schema_version")
	if version == SCHEMA.SCHEMA_VERSION:
		return SCHEMA.validate(detached)
	if version == 9:
		return _migration_result(SCHEMA.prepare_v9_upgrade(detached), &"profile_v9_to_v10")
	if version == 8:
		return _migration_result(SCHEMA.prepare_v8_upgrade(detached), &"profile_v8_to_v10")
	if version == 7:
		return _migration_result(SCHEMA.prepare_v7_upgrade(detached), &"profile_v7_to_v10")
	if version == 6:
		return _migration_result(SCHEMA.prepare_v6_upgrade(detached), &"profile_v6_to_v10")
	if version == 5:
		return _migration_result(SCHEMA.prepare_v5_upgrade(detached), &"profile_v5_to_v10")
	if version == 4:
		return _migration_result(SCHEMA.prepare_v4_upgrade(detached), &"profile_v4_to_v10")
	if version == 3:
		return _migration_result(SCHEMA.prepare_v3_upgrade(detached), &"profile_v3_to_v10")
	if version == 2:
		return _migration_result(SCHEMA.prepare_v2_upgrade(detached), &"profile_v2_to_v10")
	if version == 1:
		return _prepare_v1_upgrade(detached)
	return {"ok": false, "code": &"unsupported_profile_schema", "path": "schema_version",
		"message": "profile schema version is unsupported"}


static func prepare_legacy_patch(legacy_run_state: Dictionary,
		legacy_input_mappings: Dictionary = {}) -> Dictionary:
	var legacy_preferences := _legacy_preference_defaults()
	var settings: Variant = legacy_run_state.get("settings", {})
	if typeof(settings) != TYPE_DICTIONARY:
		return _legacy_failure("settings must be an object")
	var setting_map := {
		"language": ["language"],
		"music_volume": ["audio", "music_volume"],
		"voice_volume": ["audio", "voice_volume"],
		"sfx_volume": ["audio", "sfx_volume"],
		"ambience_volume": ["audio", "ambience_volume"],
		"mute_audio_on_focus_loss": ["audio", "mute_audio_on_focus_loss"],
		"text_speed": ["dialogue", "text_speed"],
		"auto_text_speed": ["dialogue", "auto_text_speed"],
		"auto_advance_dialogue": ["dialogue", "auto_advance_dialogue"],
		"fullscreen": ["display", "fullscreen"],
	}
	for key: String in ["font_scale", "high_contrast", "reduced_motion",
			"screen_shake_strength", "large_click_targets", "hold_to_confirm",
			"colorblind_mode", "show_focus_ring", "controller_cursor_enabled",
			"subtitles_enabled", "captions_enabled", "subtitle_speaker_names",
			"subtitle_background_opacity", "text_box_opacity", "visual_audio_cues",
			"flashing_effects_enabled", "pause_on_focus_loss"]:
		setting_map[key] = ["accessibility", key]
	for key_value: Variant in settings:
		if typeof(key_value) != TYPE_STRING:
			return _legacy_failure("setting names must be Strings")
		var key: String = key_value
		if key == "skip_unseen_text_allowed":
			if typeof(settings[key]) != TYPE_BOOL:
				return _legacy_failure("skip_unseen_text_allowed must be boolean")
			legacy_preferences["dialogue"]["skip_mode"] = "all_text" if settings[key] else "read_only"
			continue
		if not setting_map.has(key):
			return {"ok": false, "code": &"unknown_legacy_profile_key", "message": key}
		var destination: Array = setting_map[key]
		if destination.size() == 1:
			legacy_preferences[destination[0]] = settings[key]
		else:
			legacy_preferences[destination[0]][destination[1]] = settings[key]
	var audio_state: Variant = legacy_run_state.get("audio_state", {})
	if typeof(audio_state) != TYPE_DICTIONARY:
		return _legacy_failure("audio_state must be an object")
	for key_value: Variant in audio_state:
		if typeof(key_value) != TYPE_STRING:
			return _legacy_failure("audio state names must be Strings")
		var key: String = key_value
		if key == "music_muted":
			if typeof(audio_state[key]) != TYPE_BOOL:
				return _legacy_failure("music_muted must be boolean")
			legacy_preferences["audio"]["music_muted"] = audio_state[key]
		elif key in ["current_bgm_id", "current_ambience_id", "current_context_id"]:
			if typeof(audio_state[key]) != TYPE_STRING:
				return _legacy_failure(key + " must be a String")
		elif key == "current_context":
			if typeof(audio_state[key]) != TYPE_DICTIONARY:
				return _legacy_failure("current_context must be an object")
		else:
			return {"ok": false, "code": &"unknown_legacy_profile_key",
					"message": "audio_state." + key}
	var checked_preferences := SCHEMA.validate_v1_preferences(legacy_preferences)
	if not checked_preferences.get("ok", false):
		return checked_preferences
	var endings := _import_legacy_endings(legacy_run_state.get("seen_endings", {}))
	if not endings.get("ok", false):
		return endings
	var input_records := _legacy_input_records(legacy_input_mappings)
	if not input_records.get("ok", false):
		return input_records
	var patch := SCHEMA.make_defaults()
	patch["gallery_unlocks"] = endings["value"]
	patch["input_mappings"] = input_records["value"]
	patch["migration_receipts"]["legacy_game_state_profile_v1"] = true
	patch["migration_receipts"]["legacy_input_bindings_v1"] = not legacy_input_mappings.is_empty()
	patch["legacy_preferences_v1"] = legacy_preferences.duplicate(true)
	_apply_v1_preferences(patch, legacy_preferences)
	_apply_controls_import(patch)
	var validation := SCHEMA.validate(patch)
	if not validation.get("ok", false):
		return validation
	return {"ok": true, "code": &"ok", "value": validation["value"]}


static func _prepare_v1_upgrade(detached: Dictionary) -> Dictionary:
	var checked := SCHEMA.validate_v1_source(detached)
	if not checked.get("ok", false):
		var preferences: Variant = detached.get("preferences")
		if typeof(preferences) != TYPE_DICTIONARY \
				or typeof(preferences.get("dialogue")) != TYPE_DICTIONARY \
				or not preferences["dialogue"].has("skip_mode") \
				or typeof(detached.get("migration_receipts")) != TYPE_DICTIONARY:
			return checked
		preferences["dialogue"]["skip_mode"] = "read_only"
		detached["migration_receipts"]["invalid_persisted_skip_mode_v1"] = true
		checked = SCHEMA.validate_v1_source(detached)
		if not checked.get("ok", false):
			return checked
	var source: Dictionary = checked["value"]
	var candidate := SCHEMA.make_defaults()
	for key: String in ["gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids",
			"input_mappings", "migration_receipts"]:
		candidate[key] = source[key].duplicate(true)
	candidate["legacy_preferences_v1"] = source["preferences"].duplicate(true)
	_apply_v1_preferences(candidate, source["preferences"])
	_apply_controls_import(candidate)
	var validation := SCHEMA.validate(candidate)
	return _migration_result(validation, &"profile_v1_to_v10")


static func _apply_v1_preferences(candidate: Dictionary, legacy: Dictionary) -> void:
	var primary := _canonical_locale(str(legacy["language"]))
	candidate["preferences"]["language"]["primary_locale_id"] = primary
	candidate["preferences"]["language"]["secondary_locale_id"] = "en" if primary == "zh_CN" else "zh_CN"
	var audio: Dictionary = legacy["audio"]
	for key: String in ["music_volume", "music_muted", "ambience_volume", "ambience_muted",
			"sfx_volume", "sfx_muted"]:
		candidate["preferences"]["audio"][key] = audio[key]
	candidate["preferences"]["audio"]["mute_when_inactive"] = audio["mute_audio_on_focus_loss"]
	var dialogue: Dictionary = legacy["dialogue"]
	candidate["preferences"]["reading"]["reveal_speed"] = _nearest_speed(
		1.0 / float(dialogue["text_speed"]), [["normal", 1.0], ["fast", 0.5], ["slow", 2.0]])
	candidate["preferences"]["reading"]["auto_delay"] = _nearest_speed(
		1.0 / float(dialogue["auto_text_speed"]), [["normal", 1.0], ["short", 0.5], ["long", 1.5]])
	candidate["preferences"]["reading"]["skip_mode"] = dialogue["skip_mode"]
	candidate["preferences"]["reading"]["auto_enabled"] = dialogue["auto_advance_dialogue"]
	candidate["preferences"]["display"]["window_mode"] = "borderless" if legacy["display"]["fullscreen"] else "windowed"
	var accessibility: Dictionary = legacy["accessibility"]
	var font_scale := float(accessibility["font_scale"])
	candidate["preferences"]["accessibility"]["text_size"] = 150 if font_scale >= 1.5 else (125 if font_scale >= 1.25 else 100)
	for mapping: Array in [["large_click_targets", "large_targets"], ["high_contrast", "high_contrast"],
			["reduced_motion", "reduced_motion"]]:
		candidate["preferences"]["accessibility"][mapping[1]] = accessibility[mapping[0]]
	var shake := float(accessibility["screen_shake_strength"])
	candidate["preferences"]["accessibility"]["screen_shake"] = "off" if shake == 0.0 else ("low" if shake <= 0.5 else "normal")
	var colour_map := {"none": "standard", "protanopia": "protan", "deuteranopia": "deutan", "tritanopia": "tritan"}
	candidate["preferences"]["accessibility"]["colour_differentiation"] = colour_map[accessibility["colorblind_mode"]]
	candidate["preferences"]["accessibility"]["sound_detail_text"] = "story_relevant" if accessibility["visual_audio_cues"] else "off"


static func _apply_controls_import(candidate: Dictionary) -> void:
	if candidate["input_mappings"].is_empty():
		candidate["controls_bindings"] = CONTROLS_RULES.defaults()
		candidate["controls_import_pending"] = false
		return
	var imported := CONTROLS_IMPORT.prepare(candidate["input_mappings"])
	candidate["controls_bindings"] = imported["bindings"]
	candidate["controls_import_pending"] = imported["pending"]


static func _nearest_speed(value: float, ordered: Array) -> String:
	var selected: String = ordered[0][0]
	var distance := absf(value - float(ordered[0][1]))
	for index in range(1, ordered.size()):
		var next_distance := absf(value - float(ordered[index][1]))
		if next_distance < distance:
			selected = ordered[index][0]
			distance = next_distance
	return selected


static func _canonical_locale(value: String) -> String:
	var normalized := value.replace("-", "_").to_lower()
	if normalized in ["zh_cn", "zh_hans", "zh"]:
		return "zh_CN"
	if normalized in ["zh_hk", "zh_tw", "zh_hant"]:
		return "zh_HK"
	return "en"


static func _legacy_preference_defaults() -> Dictionary:
	return {
		"language": "en",
		"audio": {"music_volume": 0.8, "music_muted": false, "ambience_volume": 0.65,
			"ambience_muted": false, "sfx_volume": 0.8, "sfx_muted": false,
			"voice_volume": 0.8, "voice_muted": false, "mute_audio_on_focus_loss": false},
		"dialogue": {"text_speed": 1.0, "auto_text_speed": 1.0,
			"skip_mode": "read_only", "auto_advance_dialogue": false},
		"display": {"fullscreen": false},
		"accessibility": {"font_scale": 1.0, "high_contrast": false,
			"reduced_motion": false, "screen_shake_strength": 0.5,
			"large_click_targets": false, "hold_to_confirm": false,
			"colorblind_mode": "none", "show_focus_ring": true,
			"controller_cursor_enabled": false, "subtitles_enabled": true,
			"captions_enabled": true, "subtitle_speaker_names": true,
			"subtitle_background_opacity": 0.85, "text_box_opacity": 0.9,
			"visual_audio_cues": true, "flashing_effects_enabled": false,
			"pause_on_focus_loss": true},
	}.duplicate(true)


static func _import_legacy_endings(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _legacy_failure("seen_endings must be an object")
	var unlocks: Array = []
	for ending_value: Variant in value:
		if typeof(ending_value) != TYPE_STRING or typeof(value[ending_value]) != TYPE_BOOL:
			return _legacy_failure("seen ending names and values are invalid")
		if not value[ending_value]:
			continue
		var canonical: String = _LEGACY_ENDING_MAP.get(ending_value, ending_value)
		if canonical not in SCHEMA.ENDING_IDS:
			return _legacy_failure("unknown legacy ending: " + ending_value)
		if canonical not in unlocks:
			unlocks.append(canonical)
	unlocks.sort()
	return {"ok": true, "code": &"ok", "value": unlocks}


static func _legacy_input_records(value: Dictionary) -> Dictionary:
	var mappings := {}
	for action_value: Variant in value:
		if typeof(action_value) != TYPE_STRING:
			return _legacy_failure("input action names must be Strings")
		var action_id: String = action_value
		if action_id not in _REGISTERED_LEGACY_ACTIONS:
			continue
		if typeof(value[action_id]) != TYPE_ARRAY:
			return _legacy_failure("registered input mapping must be an array")
		var records: Array = []
		for code: Variant in value[action_id]:
			if typeof(code) != TYPE_INT:
				return _legacy_failure("legacy physical keycode must be an integer")
			records.append(_key_record(code))
		mappings[action_id] = records
	return {"ok": true, "code": &"ok", "value": mappings}


static func _key_record(code: int) -> Dictionary:
	return {"kind": "key", "physical_keycode": code, "keycode": 0,
		"shift": false, "alt": false, "ctrl": false, "meta": false}


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


static func _migration_result(result: Dictionary, migration_id: StringName) -> Dictionary:
	if not result.get("ok", false):
		return result
	return {"ok": true, "code": &"ok", "value": result["value"], "migrated": true,
		"migration_id": migration_id}


static func _legacy_failure(message: String) -> Dictionary:
	return {"ok": false, "code": &"invalid_legacy_profile", "message": message}
