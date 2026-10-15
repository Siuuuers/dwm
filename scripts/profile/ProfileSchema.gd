class_name ProfileSchema
extends RefCounted

const PREFERENCE_REGISTRY := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
const CONTROLS_RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const CONTROLS_IMPORT := preload("res://scripts/settings/ControlsBindingImport.gd")

const DATING_ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")

const OBSERVER_EVIDENCE := preload("res://scripts/profile/ObserverEvidence.gd")
const PAIR_DECK := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const PRESENTATION_SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const CAPTION_WITNESSES := preload("res://scripts/profile/CaptionWitnessLedger.gd")

const SCHEMA_VERSION := 10
const V1_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "migration_receipts"]
const V2_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings"]
const V3_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "controls_bindings", "controls_import_pending"]
const V4_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "controls_bindings", "controls_import_pending", "migration_receipts", "legacy_preferences_v1"]
const V5_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "controls_bindings", "controls_import_pending", "migration_receipts", "legacy_preferences_v1", "pair_form_witness_receipts"]
const V7_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "controls_bindings", "controls_import_pending", "migration_receipts", "legacy_preferences_v1", "pair_form_witness_receipts", "dating_attempts"]
const V8_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "controls_bindings", "controls_import_pending", "migration_receipts", "legacy_preferences_v1", "pair_form_witness_receipts", "dating_attempts", "observer_evidence", "pair_deck_draws", "reached_presentations"]
const V9_ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "controls_bindings", "controls_import_pending", "migration_receipts", "legacy_preferences_v1", "pair_form_witness_receipts", "dating_attempts", "observer_evidence", "pair_deck_draws", "reached_presentations", "reached_presentation_chronology"]
const ROOT_KEYS := ["schema_version", "gallery_unlocks", "gallery_transaction_receipts", "visited_line_ids", "preferences", "input_mappings", "controls_bindings", "controls_import_pending", "migration_receipts", "legacy_preferences_v1", "pair_form_witness_receipts", "dating_attempts", "observer_evidence", "pair_deck_draws", "reached_presentations", "reached_presentation_chronology", "witnessed_caption_variants"]
const PAIR_FORMS := ["ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"]
const MIGRATION_RECEIPT_KEYS := ["legacy_game_state_profile_v1", "legacy_input_bindings_v1", "invalid_persisted_skip_mode_v1"]
const PREFERENCE_GROUPS := ["language", "reading", "audio", "display", "accessibility", "exceptional_replay", "dark_mode"]
const _PANEL_WIDTH_LEAVES := ["angela_panel_width", "dating_solo_portrait_width", "dating_group_portrait_width"]
const _MINESWEEPER_VIEW_LEAVES := [
	"minesweeper_app_beginner_cell_size", "minesweeper_app_beginner_always_fit",
	"minesweeper_app_intermediate_cell_size", "minesweeper_app_intermediate_always_fit",
	"minesweeper_app_expert_cell_size", "minesweeper_app_expert_always_fit",
	"minesweeper_challenge_cell_size", "minesweeper_challenge_always_fit",
]

const ENDING_IDS := [
	"ending.alone", "ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.observation",
	"ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.observation",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.special",
	"ending.priscilla_lavinia", "ending.priscilla_lavinia.sweet",
	"ending.priscilla_lavinia.dark", "ending.priscilla_lavinia.observer",
]

const LEGACY_PREFERENCE_DEFAULTS := {
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
	"preferences.accessibility.pause_on_focus_loss": true,
}

const _DEFAULT_INPUT_KEYCODES := {
	"game_quick_save": KEY_F5,
	"game_quick_load": KEY_F9,
	"game_open_log": KEY_L,
	"game_skip_text": KEY_CTRL,
	"game_toggle_auto": KEY_A,
	"game_hint": KEY_H,
	"game_new_board": KEY_N,
	"game_close_window": KEY_ESCAPE,
	"game_next_tab": KEY_E,
	"game_prev_tab": KEY_Q,
	"game_page_next": KEY_BRACKETRIGHT,
	"game_page_prev": KEY_BRACKETLEFT,
	"game_open_settings": KEY_F1,
	"game_open_schedule": KEY_F2,
	"game_open_contacts": KEY_F3,
}


static func make_defaults() -> Dictionary:
	var preferences := {}
	for group in PREFERENCE_GROUPS:
		preferences[group] = {}
	for record in PREFERENCE_REGISTRY.records():
		var parts := String(record["path"]).split(".")
		preferences[parts[1]][parts[2]] = _duplicate_value(record["default_value"])
	return {
		"schema_version": SCHEMA_VERSION,
		"gallery_unlocks": [],
		"gallery_transaction_receipts": {},
		"pair_form_witness_receipts": {},
		"dating_attempts": {},
		"observer_evidence": {}, "pair_deck_draws": {}, "reached_presentations": {},
		"reached_presentation_chronology": {"first_witnessed": [], "legacy_unordered": []},
		"visited_line_ids": [],
		"witnessed_caption_variants": {},
		"preferences": preferences,
		"input_mappings": {},
		"controls_bindings": CONTROLS_RULES.defaults(),
		"controls_import_pending": false,
		"migration_receipts": {
			"legacy_game_state_profile_v1": false,
			"legacy_input_bindings_v1": false,
			"invalid_persisted_skip_mode_v1": false,
		},
		"legacy_preferences_v1": {},
	}.duplicate(true)


static func validate(profile: Dictionary) -> Dictionary:
	return _validate_modern_document(profile, SCHEMA_VERSION, ROOT_KEYS, true)

static func validate_v2_source(profile: Dictionary) -> Dictionary:
	return _validate_modern_document(profile, 2, V2_ROOT_KEYS, false)

static func validate_v4_source(profile: Dictionary) -> Dictionary:
	return _validate_modern_document(profile, 4, V4_ROOT_KEYS, true)

static func validate_v3_source(profile: Dictionary) -> Dictionary:
	return _validate_modern_document(profile, 3, V3_ROOT_KEYS, true)

static func validate_v1_source(profile: Dictionary) -> Dictionary:
	if typeof(profile.get("schema_version")) != TYPE_INT or profile.get("schema_version") != 1:
		return _failure(&"unsupported_profile_schema", "schema_version", "profile schema version is unsupported")
	var exact := _require_keys(profile, V1_ROOT_KEYS, "profile")
	if not exact.get("ok", false): return exact
	var gallery := _validate_unique_strings(profile["gallery_unlocks"], "gallery_unlocks", ENDING_IDS)
	if not gallery.get("ok", false): return gallery
	var receipts := _validate_gallery_receipts(profile["gallery_transaction_receipts"])
	if not receipts.get("ok", false): return receipts
	var visited := _validate_unique_strings(profile["visited_line_ids"], "visited_line_ids")
	if not visited.get("ok", false): return visited
	var preferences := _validate_v1_preferences(profile["preferences"])
	if not preferences.get("ok", false): return preferences
	var mappings := _validate_input_mappings(profile["input_mappings"])
	if not mappings.get("ok", false): return mappings
	var migrations := _validate_migration_receipts(profile["migration_receipts"])
	if not migrations.get("ok", false): return migrations
	return {"ok": true, "code": &"ok", "value": profile.duplicate(true)}

static func validate_v1_preferences(preferences: Dictionary) -> Dictionary:
	return _validate_v1_preferences(preferences)


static func prepare_v2_upgrade(raw: Dictionary) -> Dictionary:
	var checked := validate_v2_source(raw)
	if not checked.get("ok", false):
		return checked
	var candidate: Dictionary = checked["value"]
	var imported := CONTROLS_IMPORT.prepare(candidate["input_mappings"])
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["controls_bindings"] = imported["bindings"]
	candidate["controls_import_pending"] = imported["pending"]
	_add_closed_legacy_fields(candidate)
	candidate["pair_form_witness_receipts"] = {}
	candidate["dating_attempts"] = {}
	_add_v8_fields(candidate)
	_add_presentation_chronology(candidate)
	return validate(candidate)

static func prepare_v3_upgrade(raw: Dictionary) -> Dictionary:
	var checked := validate_v3_source(raw)
	if not checked.get("ok", false): return checked
	var candidate: Dictionary = checked["value"]
	candidate["schema_version"] = SCHEMA_VERSION
	_add_closed_legacy_fields(candidate)
	candidate["pair_form_witness_receipts"] = {}
	candidate["dating_attempts"] = {}
	_add_v8_fields(candidate)
	_add_presentation_chronology(candidate)
	return validate(candidate)


static func prepare_v9_upgrade(raw: Dictionary) -> Dictionary:
	var checked := _validate_modern_document(raw, 9, V9_ROOT_KEYS, true)
	if not checked.ok: return checked
	var candidate: Dictionary = checked.value
	candidate.schema_version = SCHEMA_VERSION
	# Base-line visits and reached scene signatures never prove an exact caption.
	candidate["witnessed_caption_variants"] = {}
	return validate(candidate)


static func prepare_v8_upgrade(raw: Dictionary) -> Dictionary:
	var checked := _validate_modern_document(raw, 8, V8_ROOT_KEYS, true)
	if not checked.get("ok", false): return checked
	var candidate: Dictionary = checked.value
	candidate["schema_version"] = SCHEMA_VERSION
	_add_presentation_chronology(candidate)
	return validate(candidate)

## Older documents prove membership, never the order in which signatures were reached.
static func _add_presentation_chronology(candidate: Dictionary) -> void:
	var legacy: Array = candidate.reached_presentations.keys()
	legacy.sort()
	candidate["reached_presentation_chronology"] = {
		"first_witnessed": [], "legacy_unordered": legacy}
	candidate["witnessed_caption_variants"] = {}

static func prepare_v7_upgrade(raw: Dictionary) -> Dictionary:
	var checked := _validate_modern_document(raw, 7, V7_ROOT_KEYS, true)
	if not checked.ok: return checked
	var candidate: Dictionary = checked.value
	candidate["schema_version"] = SCHEMA_VERSION
	_add_v8_fields(candidate)
	_add_presentation_chronology(candidate)
	return validate(candidate)

static func _add_v8_fields(candidate: Dictionary) -> void:
	for key: String in ["observer_evidence", "pair_deck_draws", "reached_presentations"]:
		candidate[key] = {}

static func prepare_v6_upgrade(raw: Dictionary) -> Dictionary:
	var checked := _validate_modern_document(raw, 6, V7_ROOT_KEYS, true)
	if not checked.get("ok", false): return checked
	var upgraded := DATING_ATTEMPTS.upgrade_v6(checked.value.dating_attempts)
	if not upgraded.ok: return upgraded
	var candidate: Dictionary = checked.value
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["dating_attempts"] = upgraded.value
	_add_v8_fields(candidate)
	_add_presentation_chronology(candidate)
	return validate(candidate)


static func prepare_v5_upgrade(raw: Dictionary) -> Dictionary:
	var checked := _validate_modern_document(raw, 5, V5_ROOT_KEYS, true)
	if not checked.get("ok", false): return checked
	var candidate: Dictionary = checked.value
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["dating_attempts"] = {}
	_add_v8_fields(candidate)
	_add_presentation_chronology(candidate)
	return validate(candidate)


static func prepare_v4_upgrade(raw: Dictionary) -> Dictionary:
	var checked := validate_v4_source(raw)
	if not checked.get("ok", false): return checked
	var candidate: Dictionary = checked.value
	candidate.schema_version = SCHEMA_VERSION
	candidate["pair_form_witness_receipts"] = {}
	candidate["dating_attempts"] = {}
	_add_v8_fields(candidate)
	_add_presentation_chronology(candidate)
	return validate(candidate)


static func _add_closed_legacy_fields(candidate: Dictionary) -> void:
	candidate["migration_receipts"] = {
		"legacy_game_state_profile_v1": true,
		"legacy_input_bindings_v1": true,
		"invalid_persisted_skip_mode_v1": false,
	}
	candidate["legacy_preferences_v1"] = {}


static func _validate_modern_document(source: Dictionary, version: int, root_keys: Array,
		has_controls: bool) -> Dictionary:
	var profile := source.duplicate(true)
	if not profile.has("schema_version") or typeof(profile["schema_version"]) != TYPE_INT:
		return _invalid("schema_version", "schema_version must be an integer")
	if profile["schema_version"] != version:
		return _failure(&"unsupported_profile_schema", "schema_version", "profile schema version is unsupported")
	var exact := _require_keys(profile, root_keys, "profile")
	if not exact.get("ok", false): return exact
	var gallery := _validate_unique_strings(profile["gallery_unlocks"], "gallery_unlocks", ENDING_IDS)
	if not gallery.get("ok", false): return gallery
	var receipts := _validate_gallery_receipts(profile["gallery_transaction_receipts"])
	if not receipts.get("ok", false): return receipts
	var visited := _validate_unique_strings(profile["visited_line_ids"], "visited_line_ids")
	if not visited.get("ok", false): return visited
	var admitted_view_defaults := _admit_legacy_minesweeper_view_defaults(profile)
	var admitted_steady_default := _admit_legacy_steady_interface_default(profile)
	var admitted_window_default := _admit_legacy_window_size_default(profile)
	var admitted_font_default := _admit_legacy_font_style_default(profile)
	var admitted_panel_widths := _admit_legacy_panel_width_defaults(profile)
	var preferences := _validate_preferences(profile["preferences"])
	if not preferences.get("ok", false): return preferences
	var mappings := _validate_input_mappings(profile["input_mappings"], version == 2)
	if not mappings.get("ok", false): return mappings
	if has_controls:
		if typeof(profile["controls_import_pending"]) != TYPE_BOOL:
			return _invalid("controls_import_pending", "import status must be a boolean")
		var bindings := CONTROLS_RULES.validate(profile["controls_bindings"])
		if not bindings.get("ok", false):
			return _invalid("controls_bindings", "invalid Controls map: " + str(bindings.get("code")))
	if version >= 4:
		var migrations := _validate_migration_receipts(profile["migration_receipts"])
		if not migrations.get("ok", false): return migrations
		var archive: Variant = profile["legacy_preferences_v1"]
		if typeof(archive) != TYPE_DICTIONARY:
			return _invalid("legacy_preferences_v1", "legacy preferences archive must be an object")
		if not archive.is_empty():
			var archived := _validate_v1_preferences(archive)
			if not archived.get("ok", false):
				return _invalid("legacy_preferences_v1", "legacy preferences archive is invalid")
	if version >= 5:
		var witnessed: Variant = profile["pair_form_witness_receipts"]
		if not witnessed is Dictionary:
			return _invalid("pair_form_witness_receipts", "witness receipts must be an object")
		for receipt_id: Variant in witnessed:
			if not receipt_id is String or receipt_id.strip_edges().is_empty() \
					or not witnessed[receipt_id] is String or witnessed[receipt_id] not in PAIR_FORMS:
				return _invalid("pair_form_witness_receipts", "each presentation receipt names a registered form")
	if version >= 6:
		var attempts: Dictionary = DATING_ATTEMPTS.validate_v6(profile["dating_attempts"]) if version == 6 else DATING_ATTEMPTS.validate(profile["dating_attempts"])
		if not attempts.get("ok", false): return attempts
	if version >= 8:
		var observer := OBSERVER_EVIDENCE.validate(profile["observer_evidence"])
		if not observer.ok: return observer
		if not profile["reached_presentations"] is Dictionary: return _invalid("reached_presentations", "Reached presentations must be an object")
		var reached := PRESENTATION_SIGNATURE.validate_ledger(profile["reached_presentations"])
		if not reached.ok: return reached
		var draws: Dictionary = PAIR_DECK.validate_ledger(profile["pair_deck_draws"])
		if not draws.ok: return draws
	if version >= 9:
		var chronology := _validate_presentation_chronology(profile)
		if not chronology.ok: return chronology
	if version >= 10:
		var captions := CAPTION_WITNESSES.validate(profile["witnessed_caption_variants"])
		if not captions.ok: return captions
		for beat: Dictionary in profile.witnessed_caption_variants.values():
			if beat.line_id not in profile.visited_line_ids:
				return _invalid("witnessed_caption_variants", "An exact caption witness also retains its base-line visit")
	var result := {"ok": true, "code": &"ok", "value": profile}
	if admitted_view_defaults or admitted_steady_default or admitted_window_default or admitted_font_default or admitted_panel_widths:
		result["migrated"] = true
	return result


## Each reached signature has exactly one provenance: first-witness sequence or unknown legacy order.
static func _validate_presentation_chronology(profile: Dictionary) -> Dictionary:
	var path := "reached_presentation_chronology"
	var chronology: Variant = profile[path]
	if not chronology is Dictionary:
		return _invalid(path, "Presentation chronology must be an object")
	var exact := _require_keys(chronology, ["first_witnessed", "legacy_unordered"], path)
	if not exact.ok: return exact
	var seen := {}
	for partition: String in ["first_witnessed", "legacy_unordered"]:
		var checked := _validate_unique_strings(chronology[partition], path + "." + partition)
		if not checked.ok: return checked
		for identity: String in chronology[partition]:
			if not profile.reached_presentations.has(identity) or seen.has(identity):
				return _invalid(path, "Every chronology identity must name one distinct reached signature")
			seen[identity] = true
	if seen.size() != profile.reached_presentations.size():
		return _invalid(path, "Every reached signature requires chronology provenance")
	var sorted_legacy: Array = chronology.legacy_unordered.duplicate()
	sorted_legacy.sort()
	if sorted_legacy != chronology.legacy_unordered:
		return _invalid(path, "Legacy membership must use canonical identity order, not witness order")
	return {"ok": true}


static func _admit_legacy_minesweeper_view_defaults(profile: Dictionary) -> bool:
	var preferences: Variant = profile.get("preferences")
	if typeof(preferences) != TYPE_DICTIONARY:
		return false
	var display: Variant = preferences.get("display")
	if typeof(display) != TYPE_DICTIONARY:
		return false
	for leaf: String in _MINESWEEPER_VIEW_LEAVES:
		if display.has(leaf):
			return false
	for leaf: String in _MINESWEEPER_VIEW_LEAVES:
		display[leaf] = PREFERENCE_REGISTRY.default_value(StringName("preferences.display." + leaf))
	return true


static func _admit_legacy_panel_width_defaults(profile: Dictionary) -> bool:
	var preferences: Variant = profile.get("preferences")
	if typeof(preferences) != TYPE_DICTIONARY: return false
	var display: Variant = preferences.get("display")
	if typeof(display) != TYPE_DICTIONARY: return false
	for leaf: String in _PANEL_WIDTH_LEAVES:
		if display.has(leaf): return false
	for leaf: String in _PANEL_WIDTH_LEAVES:
		display[leaf] = PREFERENCE_REGISTRY.default_value(StringName("preferences.display." + leaf))
	return true


static func _admit_legacy_window_size_default(profile: Dictionary) -> bool:
	var preferences: Variant = profile.get("preferences")
	if typeof(preferences) != TYPE_DICTIONARY: return false
	var display: Variant = preferences.get("display")
	if typeof(display) != TYPE_DICTIONARY or display.has("window_size"): return false
	display["window_size"] = PREFERENCE_REGISTRY.default_value(&"preferences.display.window_size")
	return true


static func _admit_legacy_steady_interface_default(profile: Dictionary) -> bool:
	var preferences: Variant = profile.get("preferences")
	if typeof(preferences) != TYPE_DICTIONARY:
		return false
	var accessibility: Variant = preferences.get("accessibility")
	if typeof(accessibility) != TYPE_DICTIONARY or accessibility.has("steady_interface"):
		return false
	accessibility["steady_interface"] = false
	return true


static func _admit_legacy_font_style_default(profile: Dictionary) -> bool:
	var preferences: Variant = profile.get("preferences")
	if typeof(preferences) != TYPE_DICTIONARY: return false
	var accessibility: Variant = preferences.get("accessibility")
	if typeof(accessibility) != TYPE_DICTIONARY or accessibility.has("font_style"): return false
	accessibility["font_style"] = PREFERENCE_REGISTRY.default_value(&"preferences.accessibility.font_style")
	return true


static func validate_preference(path: StringName, value: Variant) -> Dictionary:
	return PREFERENCE_REGISTRY.validate(path, value)


static func _validate_preferences(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _invalid("preferences", "preferences must be an object")
	var preferences: Dictionary = value
	var exact := _require_keys(preferences, PREFERENCE_GROUPS, "preferences")
	if not exact.get("ok", false): return exact
	for group_name in PREFERENCE_GROUPS:
		if typeof(preferences[group_name]) != TYPE_DICTIONARY:
			return _invalid("preferences." + group_name, "preference group must be an object")
		var leaves := _expected_preference_leaves(group_name)
		exact = _require_keys(preferences[group_name], leaves, "preferences." + group_name)
		if not exact.get("ok", false): return exact
	for record in PREFERENCE_REGISTRY.records():
		var qualified_path := String(record["path"])
		var parts := qualified_path.split(".")
		var leaf_result := PREFERENCE_REGISTRY.validate(record["path"], preferences[parts[1]][parts[2]])
		if not leaf_result.get("ok", false): return leaf_result
	var language: Dictionary = preferences["language"]
	if language["primary_locale_id"] == language["secondary_locale_id"] and _registered_locale_count() > 1:
		return _invalid("preferences.language.secondary_locale_id", "secondary locale must differ from primary when possible")
	return {"ok": true}


static func _validate_v1_preferences(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _invalid("preferences", "preferences must be an object")
	var preferences: Dictionary = value
	var exact := _require_keys(preferences, ["language", "audio", "dialogue", "display", "accessibility"], "preferences")
	if not exact.get("ok", false): return exact
	var groups := {
		"audio": ["music_volume", "music_muted", "ambience_volume", "ambience_muted", "sfx_volume", "sfx_muted", "voice_volume", "voice_muted", "mute_audio_on_focus_loss"],
		"dialogue": ["text_speed", "auto_text_speed", "skip_mode", "auto_advance_dialogue"],
		"display": ["fullscreen"],
		"accessibility": ["font_scale", "high_contrast", "reduced_motion", "screen_shake_strength", "large_click_targets", "hold_to_confirm", "colorblind_mode", "show_focus_ring", "controller_cursor_enabled", "subtitles_enabled", "captions_enabled", "subtitle_speaker_names", "subtitle_background_opacity", "text_box_opacity", "visual_audio_cues", "flashing_effects_enabled", "pause_on_focus_loss"],
	}
	for group: String in groups:
		if typeof(preferences[group]) != TYPE_DICTIONARY: return _invalid("preferences." + group, "preference group must be an object")
		# Older v1 writers persisted this retired capability. Keep it only in the archive.
		if group == "accessibility" and preferences[group].has("tutorial_replay_available"):
			if typeof(preferences[group]["tutorial_replay_available"]) != TYPE_BOOL:
				return _invalid("preferences.accessibility.tutorial_replay_available", "legacy tutorial capability must be a Boolean")
			groups[group].append("tutorial_replay_available")
		exact = _require_keys(preferences[group], groups[group], "preferences." + group)
		if not exact.get("ok", false): return exact
	for path_value: String in LEGACY_PREFERENCE_DEFAULTS:
		var path := StringName(path_value)
		var parts := path_value.split(".")
		var leaf: Variant = preferences[parts[1]] if parts.size() == 2 else preferences[parts[1]][parts[2]]
		var checked := _validate_v1_preference(path, leaf)
		if not checked.get("ok", false): return checked
	return {"ok": true, "code": &"ok"}


static func _validate_v1_preference(path: StringName, value: Variant) -> Dictionary:
	var key := String(path)
	var default_value: Variant = LEGACY_PREFERENCE_DEFAULTS[key]
	if key == "preferences.language":
		if typeof(value) != TYPE_STRING or value.strip_edges().is_empty() or value != value.strip_edges():
			return _invalid(key, "language must be a trimmed nonempty String")
		return {"ok": true}
	if key.ends_with("_volume") or key.ends_with("_opacity") or key.ends_with("screen_shake_strength"):
		return _finite_float_range(key, value, 0.0, 1.0, false)
	if key.ends_with("text_speed") or key.ends_with("font_scale"):
		return _finite_float_range(key, value, 0.0, INF, true)
	if key.ends_with("skip_mode"):
		return {"ok": true} if typeof(value) == TYPE_STRING and value in ["read_only", "all_text"] else _invalid(key, "skip_mode is invalid")
	if key.ends_with("colorblind_mode"):
		return {"ok": true} if typeof(value) == TYPE_STRING and value in ["none", "protanopia", "deuteranopia", "tritanopia"] else _invalid(key, "colorblind mode is invalid")
	return {"ok": true} if typeof(value) == typeof(default_value) else _invalid(key, "preference type does not match schema")


static func _expected_preference_leaves(group_name: String) -> Array:
	var leaves := []
	for record in PREFERENCE_REGISTRY.records():
		var parts := String(record["path"]).split(".")
		if parts[1] == group_name:
			leaves.append(parts[2])
	return leaves


static func _registered_locale_count() -> int:
	for record in PREFERENCE_REGISTRY.records():
		if record["path"] == &"preferences.language.primary_locale_id":
			return (record["allowed_values"] as Array).size()
	return 0


static func _validate_gallery_receipts(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _invalid("gallery_transaction_receipts", "receipt ledger must be an object")
	for transaction_id in value:
		if typeof(transaction_id) != TYPE_STRING or transaction_id.is_empty():
			return _invalid("gallery_transaction_receipts", "transaction IDs must be nonempty Strings")
		var receipt: Variant = value[transaction_id]
		if typeof(receipt) != TYPE_DICTIONARY:
			return _invalid("gallery_transaction_receipts", "receipt must be an object")
		var exact := _require_keys(receipt, ["ending_id", "unlocked"], "gallery receipt")
		if not exact.get("ok", false): return exact
		if typeof(receipt["ending_id"]) != TYPE_STRING or receipt["ending_id"] not in ENDING_IDS or typeof(receipt["unlocked"]) != TYPE_BOOL:
			return _invalid("gallery_transaction_receipts", "receipt values are invalid")
	return {"ok": true}


static func _validate_input_mappings(value: Variant, require_inventory: bool = false) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _invalid("input_mappings", "input_mappings must be an object")
	if require_inventory:
		var exact := _require_keys(value, _DEFAULT_INPUT_KEYCODES.keys(), "input_mappings")
		if not exact.get("ok", false): return exact
	for action_id in value:
		if typeof(action_id) != TYPE_STRING or action_id.is_empty():
			return _invalid("input_mappings", "action IDs must be nonempty Strings")
		if typeof(value[action_id]) != TYPE_ARRAY:
			return _invalid("input_mappings", "action events must be arrays")
		for event in value[action_id]:
			if typeof(event) != TYPE_DICTIONARY:
				return _invalid("input_mappings", "event must be an object")
			var kind: Variant = event.get("kind")
			if kind == "key":
				var key_exact := _require_keys(event, ["kind", "physical_keycode", "keycode", "shift", "alt", "ctrl", "meta"], "key event")
				if not key_exact.get("ok", false): return key_exact
				if typeof(event["physical_keycode"]) != TYPE_INT or typeof(event["keycode"]) != TYPE_INT:
					return _invalid("input_mappings", "key codes must be integers")
				for modifier in ["shift", "alt", "ctrl", "meta"]:
					if typeof(event[modifier]) != TYPE_BOOL:
						return _invalid("input_mappings", "key modifiers must be booleans")
			elif kind == "joypad_button":
				var joy_exact := _require_keys(event, ["kind", "button_index", "device"], "joypad event")
				if not joy_exact.get("ok", false): return joy_exact
				if typeof(event["button_index"]) != TYPE_INT or typeof(event["device"]) != TYPE_INT:
					return _invalid("input_mappings", "joypad fields must be integers")
			else:
				return _invalid("input_mappings", "input event kind is invalid")
	return {"ok": true}


static func _validate_migration_receipts(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _invalid("migration_receipts", "migration receipts must be an object")
	var exact := _require_keys(value, MIGRATION_RECEIPT_KEYS, "migration_receipts")
	if not exact.get("ok", false): return exact
	for key: String in MIGRATION_RECEIPT_KEYS:
		if typeof(value[key]) != TYPE_BOOL:
			return _invalid("migration_receipts", "migration receipt values must be booleans")
	return {"ok": true, "code": &"ok"}


static func _finite_float_range(path: String, value: Variant, minimum: float,
		maximum: float, exclusive_minimum: bool) -> Dictionary:
	if typeof(value) != TYPE_FLOAT or not is_finite(value):
		return _invalid(path, "value must be a finite float")
	if (exclusive_minimum and value <= minimum) or (not exclusive_minimum and value < minimum) or value > maximum:
		return _invalid(path, "value is outside its allowed range")
	return {"ok": true, "code": &"ok"}


static func _validate_unique_strings(value: Variant, path: String, allowlist: Array = []) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _invalid(path, path + " must be an array")
	var seen := {}
	for item in value:
		if typeof(item) != TYPE_STRING or item.is_empty():
			return _invalid(path, path + " entries must be nonempty Strings")
		if seen.has(item):
			return _invalid(path, path + " entries must be unique")
		if not allowlist.is_empty() and item not in allowlist:
			return _invalid(path, "unknown ending ID")
		seen[item] = true
	return {"ok": true}


static func _default_input_mappings() -> Dictionary:
	var mappings := {}
	for action_id in _DEFAULT_INPUT_KEYCODES:
		mappings[action_id] = [_key_record(_DEFAULT_INPUT_KEYCODES[action_id])]
	return mappings


static func _key_record(physical_keycode: int) -> Dictionary:
	return {
		"kind": "key",
		"physical_keycode": physical_keycode,
		"keycode": 0,
		"shift": false,
		"alt": false,
		"ctrl": false,
		"meta": false,
	}


static func _require_keys(value: Dictionary, expected: Array, path: String) -> Dictionary:
	if value.size() != expected.size():
		return _invalid(path, "object has unknown or missing fields")
	for key in expected:
		if not value.has(key):
			return _invalid(path, "object has unknown or missing fields")
	return {"ok": true}


static func _duplicate_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


static func _invalid(path: String, message: String) -> Dictionary:
	return _failure(&"invalid_profile", path, message)


static func _failure(code: StringName, path: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "path": path, "message": message}
