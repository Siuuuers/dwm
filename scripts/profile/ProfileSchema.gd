class_name ProfileSchema
extends RefCounted

const ENDING_IDS := [
	"ending.alone", "ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.true",
	"ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.true",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.true", "ending.sylvia.special",
	"ending.priscilla_lavinia",
]

const PREFERENCE_DEFAULTS := {
	"preferences.language": "en",
	"preferences.audio.music_volume": 0.8,
	"preferences.audio.music_muted": false,
	"preferences.audio.ambience_volume": 0.65,
	"preferences.audio.ambience_muted": false,
	"preferences.audio.sfx_volume": 0.8,
	"preferences.audio.sfx_muted": false,
	"preferences.audio.voice_volume": 0.8,
	"preferences.audio.voice_muted": false,
	"preferences.audio.mute_audio_on_focus_loss": false,
	"preferences.dialogue.text_speed": 1.0,
	"preferences.dialogue.auto_text_speed": 1.0,
	"preferences.dialogue.skip_mode": "read_only",
	"preferences.dialogue.auto_advance_dialogue": false,
	"preferences.display.fullscreen": false,
	"preferences.accessibility.font_scale": 1.0,
	"preferences.accessibility.high_contrast": false,
	"preferences.accessibility.reduced_motion": false,
	"preferences.accessibility.screen_shake_strength": 0.5,
	"preferences.accessibility.large_click_targets": false,
	"preferences.accessibility.hold_to_confirm": false,
	"preferences.accessibility.colorblind_mode": "none",
	"preferences.accessibility.show_focus_ring": true,
	"preferences.accessibility.controller_cursor_enabled": false,
	"preferences.accessibility.subtitles_enabled": true,
	"preferences.accessibility.captions_enabled": true,
	"preferences.accessibility.subtitle_speaker_names": true,
	"preferences.accessibility.subtitle_background_opacity": 0.85,
	"preferences.accessibility.text_box_opacity": 0.9,
	"preferences.accessibility.visual_audio_cues": true,
	"preferences.accessibility.flashing_effects_enabled": false,
	"preferences.accessibility.tutorial_replay_available": true,
	"preferences.accessibility.pause_on_focus_loss": true,
}

static func make_defaults() -> Dictionary:
	return {
		"schema_version": 1,
		"gallery_unlocks": [],
		"gallery_transaction_receipts": {},
		"visited_line_ids": [],
		"preferences": {
			"language": "en",
			"audio": {
				"music_volume": 0.8, "music_muted": false,
				"ambience_volume": 0.65, "ambience_muted": false,
				"sfx_volume": 0.8, "sfx_muted": false,
				"voice_volume": 0.8, "voice_muted": false,
				"mute_audio_on_focus_loss": false,
			},
			"dialogue": {
				"text_speed": 1.0, "auto_text_speed": 1.0,
				"skip_mode": "read_only", "auto_advance_dialogue": false,
			},
			"display": {"fullscreen": false},
			"accessibility": {
				"font_scale": 1.0, "high_contrast": false, "reduced_motion": false,
				"screen_shake_strength": 0.5, "large_click_targets": false,
				"hold_to_confirm": false, "colorblind_mode": "none", "show_focus_ring": true,
				"controller_cursor_enabled": false, "subtitles_enabled": true,
				"captions_enabled": true, "subtitle_speaker_names": true,
				"subtitle_background_opacity": 0.85, "text_box_opacity": 0.9,
				"visual_audio_cues": true, "flashing_effects_enabled": false,
				"tutorial_replay_available": true, "pause_on_focus_loss": true,
			},
		},
		"input_mappings": {},
		"migration_receipts": {
			"legacy_game_state_profile_v1": false,
			"legacy_input_bindings_v1": false,
			"invalid_persisted_skip_mode_v1": false,
		},
	}.duplicate(true)

static func validate(profile: Dictionary) -> Dictionary:
	var exact := _require_keys(profile, ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "migration_receipts"], "profile")
	if not exact.get("ok", false): return exact
	if typeof(profile["schema_version"]) != TYPE_INT or profile["schema_version"] != 1:
		return _invalid("schema_version", "schema_version must be integer 1")
	var gallery := _validate_unique_strings(profile["gallery_unlocks"], "gallery_unlocks", ENDING_IDS)
	if not gallery.get("ok", false): return gallery
	var receipts := _validate_gallery_receipts(profile["gallery_transaction_receipts"])
	if not receipts.get("ok", false): return receipts
	var visited := _validate_unique_strings(profile["visited_line_ids"], "visited_line_ids")
	if not visited.get("ok", false): return visited
	var preferences := _validate_preferences(profile["preferences"])
	if not preferences.get("ok", false): return preferences
	var mappings := _validate_input_mappings(profile["input_mappings"])
	if not mappings.get("ok", false): return mappings
	var migrations := _validate_migration_receipts(profile["migration_receipts"])
	if not migrations.get("ok", false): return migrations
	return {"ok": true, "value": profile.duplicate(true)}

static func validate_preference(path: StringName, value: Variant) -> Dictionary:
	var key := String(path)
	if not PREFERENCE_DEFAULTS.has(key):
		return {"ok": false, "code": &"invalid_preference_path", "message": key}
	var default_value: Variant = PREFERENCE_DEFAULTS[key]
	if key == "preferences.language":
		if typeof(value) != TYPE_STRING or value.strip_edges().is_empty() or value != value.strip_edges():
			return _invalid(key, "language must be a trimmed nonempty String")
		return {"ok": true, "value": value}
	if key.ends_with("_volume") or key.ends_with("_opacity") or key.ends_with("screen_shake_strength"):
		return _finite_float_range(key, value, 0.0, 1.0, false)
	if key.ends_with("text_speed") or key.ends_with("font_scale"):
		return _finite_float_range(key, value, 0.0, INF, true)
	if key.ends_with("skip_mode"):
		if typeof(value) != TYPE_STRING or value not in ["read_only", "all_text"]:
			return _invalid(key, "skip_mode must be read_only or all_text")
		return {"ok": true, "value": value}
	if key.ends_with("colorblind_mode"):
		if typeof(value) != TYPE_STRING or value not in ["none", "protanopia", "deuteranopia", "tritanopia"]:
			return _invalid(key, "colorblind_mode is invalid")
		return {"ok": true, "value": value}
	if typeof(value) != typeof(default_value):
		return _invalid(key, "preference type does not match schema")
	return {"ok": true, "value": value}

static func _validate_preferences(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _invalid("preferences", "preferences must be an object")
	var preferences: Dictionary = value
	var exact := _require_keys(preferences, ["language", "audio", "dialogue", "display", "accessibility"], "preferences")
	if not exact.get("ok", false): return exact
	for group_name in ["audio", "dialogue", "display", "accessibility"]:
		if typeof(preferences[group_name]) != TYPE_DICTIONARY:
			return _invalid("preferences." + group_name, "preference group must be an object")
	var expected_groups := {
		"audio": ["music_volume", "music_muted", "ambience_volume", "ambience_muted", "sfx_volume", "sfx_muted", "voice_volume", "voice_muted", "mute_audio_on_focus_loss"],
		"dialogue": ["text_speed", "auto_text_speed", "skip_mode", "auto_advance_dialogue"],
		"display": ["fullscreen"],
		"accessibility": ["font_scale", "high_contrast", "reduced_motion", "screen_shake_strength", "large_click_targets", "hold_to_confirm", "colorblind_mode", "show_focus_ring", "controller_cursor_enabled", "subtitles_enabled", "captions_enabled", "subtitle_speaker_names", "subtitle_background_opacity", "text_box_opacity", "visual_audio_cues", "flashing_effects_enabled", "tutorial_replay_available", "pause_on_focus_loss"],
	}
	for group_name in expected_groups:
		exact = _require_keys(preferences[group_name], expected_groups[group_name], "preferences." + group_name)
		if not exact.get("ok", false): return exact
	var language_result := validate_preference(&"preferences.language", preferences["language"])
	if not language_result.get("ok", false): return language_result
	for qualified_path_value in PREFERENCE_DEFAULTS:
		var qualified_path: String = qualified_path_value
		if qualified_path == "preferences.language": continue
		var segments: PackedStringArray = qualified_path.split(".")
		var leaf: Variant = preferences[segments[1]][segments[2]]
		var leaf_result := validate_preference(StringName(qualified_path), leaf)
		if not leaf_result.get("ok", false): return leaf_result
	return {"ok": true}

static func _validate_gallery_receipts(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _invalid("gallery_transaction_receipts", "receipt ledger must be an object")
	for transaction_id in value:
		if typeof(transaction_id) != TYPE_STRING or transaction_id.is_empty(): return _invalid("gallery_transaction_receipts", "transaction IDs must be nonempty Strings")
		var receipt: Variant = value[transaction_id]
		if typeof(receipt) != TYPE_DICTIONARY: return _invalid("gallery_transaction_receipts", "receipt must be an object")
		var exact := _require_keys(receipt, ["ending_id", "unlocked"], "gallery receipt")
		if not exact.get("ok", false): return exact
		if typeof(receipt["ending_id"]) != TYPE_STRING or receipt["ending_id"] not in ENDING_IDS or typeof(receipt["unlocked"]) != TYPE_BOOL:
			return _invalid("gallery_transaction_receipts", "receipt values are invalid")
	return {"ok": true}

static func _validate_input_mappings(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _invalid("input_mappings", "input_mappings must be an object")
	for action_id in value:
		if typeof(action_id) != TYPE_STRING or action_id.is_empty(): return _invalid("input_mappings", "action IDs must be nonempty Strings")
		if typeof(value[action_id]) != TYPE_ARRAY: return _invalid("input_mappings", "action events must be arrays")
		for event in value[action_id]:
			if typeof(event) != TYPE_DICTIONARY: return _invalid("input_mappings", "event must be an object")
			var kind: Variant = event.get("kind")
			if kind == "key":
				var exact := _require_keys(event, ["kind", "physical_keycode", "keycode", "shift", "alt", "ctrl", "meta"], "key event")
				if not exact.get("ok", false): return exact
				if typeof(event["physical_keycode"]) != TYPE_INT or typeof(event["keycode"]) != TYPE_INT: return _invalid("input_mappings", "key codes must be integers")
				for modifier in ["shift", "alt", "ctrl", "meta"]:
					if typeof(event[modifier]) != TYPE_BOOL: return _invalid("input_mappings", "key modifiers must be booleans")
			elif kind == "joypad_button":
				var exact := _require_keys(event, ["kind", "button_index", "device"], "joypad event")
				if not exact.get("ok", false): return exact
				if typeof(event["button_index"]) != TYPE_INT or typeof(event["device"]) != TYPE_INT: return _invalid("input_mappings", "joypad fields must be integers")
			else:
				return _invalid("input_mappings", "input event kind is invalid")
	return {"ok": true}

static func _validate_migration_receipts(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _invalid("migration_receipts", "migration receipts must be an object")
	var exact := _require_keys(value, ["legacy_game_state_profile_v1", "legacy_input_bindings_v1", "invalid_persisted_skip_mode_v1"], "migration_receipts")
	if not exact.get("ok", false): return exact
	for key in value:
		if typeof(value[key]) != TYPE_BOOL: return _invalid("migration_receipts", "migration receipt values must be booleans")
	return {"ok": true}

static func _validate_unique_strings(value: Variant, path: String, allowlist: Array = []) -> Dictionary:
	if typeof(value) != TYPE_ARRAY: return _invalid(path, path + " must be an array")
	var seen := {}
	for item in value:
		if typeof(item) != TYPE_STRING or item.is_empty(): return _invalid(path, path + " entries must be nonempty Strings")
		if seen.has(item): return _invalid(path, path + " entries must be unique")
		if not allowlist.is_empty() and item not in allowlist: return _invalid(path, "unknown ending ID")
		seen[item] = true
	return {"ok": true}

static func _finite_float_range(path: String, value: Variant, minimum: float, maximum: float, exclusive_minimum: bool) -> Dictionary:
	if typeof(value) != TYPE_FLOAT or not is_finite(value): return _invalid(path, "value must be a finite float")
	if (exclusive_minimum and value <= minimum) or (not exclusive_minimum and value < minimum) or value > maximum:
		return _invalid(path, "value is outside its allowed range")
	return {"ok": true, "value": value}

static func _require_keys(value: Dictionary, expected: Array, path: String) -> Dictionary:
	if value.size() != expected.size(): return _invalid(path, "object has unknown or missing fields")
	for key in expected:
		if not value.has(key): return _invalid(path, "object has unknown or missing fields")
	return {"ok": true}

static func _invalid(path: String, message: String) -> Dictionary:
	return {"ok": false, "code": &"invalid_profile", "path": path, "message": message}
