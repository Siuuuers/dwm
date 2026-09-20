extends GutTest

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const REGISTRY_PATH := "res://scripts/settings/SettingsPreferenceRegistry.gd"

const EXPECTED_RECORDS := {
	"preferences.language.primary_locale_id": {"type": "locale_id", "default_value": "en", "section_id": "language", "renderer": "locale_option", "player_writable": true, "allowed_values": ["en", "zh_CN", "zh_HK", "ja", "ko"], "step": 0.0},
	"preferences.language.secondary_locale_id": {"type": "locale_id", "default_value": "zh_CN", "section_id": "language", "renderer": "locale_option", "player_writable": true, "allowed_values": ["en", "zh_CN", "zh_HK", "ja", "ko"], "step": 0.0},
	"preferences.language.dual_enabled": {"type": "bool", "default_value": false, "section_id": "language", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.reading.reveal_speed": {"type": "enum_string", "default_value": "normal", "section_id": "reading", "renderer": "enum_option", "player_writable": true, "allowed_values": ["instant", "fast", "normal", "slow"], "step": 0.0},
	"preferences.reading.auto_enabled": {"type": "bool", "default_value": false, "section_id": "reading", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.reading.auto_delay": {"type": "enum_string", "default_value": "normal", "section_id": "reading", "renderer": "enum_option", "player_writable": true, "allowed_values": ["short", "normal", "long"], "step": 0.0},
	"preferences.reading.skip_mode": {"type": "enum_string", "default_value": "read_only", "section_id": "reading", "renderer": "enum_option", "player_writable": true, "allowed_values": ["read_only", "all_text"], "step": 0.0},
	"preferences.reading.read_aloud_enabled": {"type": "bool", "default_value": false, "section_id": "reading", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.reading.read_aloud_rate": {"type": "enum_string", "default_value": "normal", "section_id": "reading", "renderer": "enum_option", "player_writable": true, "allowed_values": ["slow", "normal", "fast"], "step": 0.0},
	"preferences.reading.lower_background_during_narration": {"type": "bool", "default_value": true, "section_id": "reading", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.audio.master_volume": {"type": "float_range", "default_value": 1.0, "section_id": "audio", "renderer": "percent_slider", "player_writable": true, "allowed_values": [], "step": 0.05},
	"preferences.audio.master_muted": {"type": "bool", "default_value": false, "section_id": "audio", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.audio.music_volume": {"type": "float_range", "default_value": 0.8, "section_id": "audio", "renderer": "percent_slider", "player_writable": true, "allowed_values": [], "step": 0.05},
	"preferences.audio.music_muted": {"type": "bool", "default_value": false, "section_id": "audio", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.audio.ambience_volume": {"type": "float_range", "default_value": 0.65, "section_id": "audio", "renderer": "percent_slider", "player_writable": true, "allowed_values": [], "step": 0.05},
	"preferences.audio.ambience_muted": {"type": "bool", "default_value": false, "section_id": "audio", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.audio.sfx_volume": {"type": "float_range", "default_value": 0.8, "section_id": "audio", "renderer": "percent_slider", "player_writable": true, "allowed_values": [], "step": 0.05},
	"preferences.audio.sfx_muted": {"type": "bool", "default_value": false, "section_id": "audio", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.audio.mute_when_inactive": {"type": "bool", "default_value": true, "section_id": "audio", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.audio.output_mode": {"type": "enum_string", "default_value": "stereo", "section_id": "audio", "renderer": "enum_option", "player_writable": true, "allowed_values": ["stereo", "mono"], "step": 0.0},
	"preferences.display.window_mode": {"type": "enum_string", "default_value": "windowed", "section_id": "display", "renderer": "enum_option", "player_writable": true, "allowed_values": ["windowed", "borderless"], "step": 0.0},
	"preferences.display.window_size": {"type": "enum_string", "default_value": "1280x720", "section_id": "display", "renderer": "enum_option", "player_writable": true, "allowed_values": ["1280x720", "1600x900", "1920x1080"], "step": 0.0},
	"preferences.display.minesweeper_app_beginner_cell_size": {"type": "enum_int", "default_value": 36, "section_id": "display", "renderer": "enum_option", "player_writable": true, "allowed_values": [10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60], "step": 2.0},
	"preferences.display.minesweeper_app_beginner_always_fit": {"type": "bool", "default_value": false, "section_id": "display", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.display.minesweeper_app_intermediate_cell_size": {"type": "enum_int", "default_value": 36, "section_id": "display", "renderer": "enum_option", "player_writable": true, "allowed_values": [10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60], "step": 2.0},
	"preferences.display.minesweeper_app_intermediate_always_fit": {"type": "bool", "default_value": false, "section_id": "display", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.display.minesweeper_app_expert_cell_size": {"type": "enum_int", "default_value": 36, "section_id": "display", "renderer": "enum_option", "player_writable": true, "allowed_values": [10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60], "step": 2.0},
	"preferences.display.minesweeper_app_expert_always_fit": {"type": "bool", "default_value": false, "section_id": "display", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.display.minesweeper_challenge_cell_size": {"type": "enum_int", "default_value": 36, "section_id": "display", "renderer": "enum_option", "player_writable": true, "allowed_values": [10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60], "step": 2.0},
	"preferences.display.minesweeper_challenge_always_fit": {"type": "bool", "default_value": false, "section_id": "display", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.accessibility.font_style": {"type": "enum_string", "default_value": "pixel", "section_id": "accessibility", "renderer": "enum_option", "player_writable": true, "allowed_values": ["pixel", "readable"], "step": 0.0},
	"preferences.accessibility.text_size": {"type": "enum_int", "default_value": 100, "section_id": "accessibility", "renderer": "enum_option", "player_writable": true, "allowed_values": [100, 125, 150], "step": 0.0},
	"preferences.accessibility.large_targets": {"type": "bool", "default_value": false, "section_id": "accessibility", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.accessibility.high_contrast": {"type": "bool", "default_value": false, "section_id": "accessibility", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.accessibility.reduced_motion": {"type": "bool", "default_value": false, "section_id": "accessibility", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.accessibility.steady_interface": {"type": "bool", "default_value": false, "section_id": "accessibility", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.accessibility.screen_shake": {"type": "enum_string", "default_value": "low", "section_id": "accessibility", "renderer": "enum_option", "player_writable": true, "allowed_values": ["off", "low", "normal"], "step": 0.0},
	"preferences.accessibility.colour_differentiation": {"type": "enum_string", "default_value": "standard", "section_id": "accessibility", "renderer": "enum_option", "player_writable": true, "allowed_values": ["standard", "protan", "deutan", "tritan"], "step": 0.0},
	"preferences.accessibility.sound_detail_text": {"type": "enum_string", "default_value": "story_relevant", "section_id": "accessibility", "renderer": "enum_option", "player_writable": true, "allowed_values": ["story_relevant", "off"], "step": 0.0},
	"preferences.exceptional_replay.available": {"type": "bool", "default_value": false, "section_id": "records", "renderer": "readonly_bool", "player_writable": false, "allowed_values": [], "step": 0.0},
	"preferences.exceptional_replay.replay_full": {"type": "bool", "default_value": false, "section_id": "records", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
	"preferences.dark_mode.available": {"type": "bool", "default_value": false, "section_id": "dark_mode", "renderer": "readonly_bool", "player_writable": false, "allowed_values": [], "step": 0.0},
	"preferences.dark_mode.next_run_enabled": {"type": "bool", "default_value": false, "section_id": "dark_mode", "renderer": "toggle", "player_writable": true, "allowed_values": [], "step": 0.0},
}


func test_registry_records_are_the_complete_accepted_vocabulary() -> void:
	var records_by_path := _records_by_path(_records())
	assert_eq(_sorted_strings(records_by_path.keys()), _sorted_strings(EXPECTED_RECORDS.keys()),
			"registry must expose exactly the accepted v2 preference paths and no retired aliases")
	if records_by_path.size() != EXPECTED_RECORDS.size():
		return
	for path in EXPECTED_RECORDS.keys():
		var record: Dictionary = records_by_path[path]
		var expected: Dictionary = EXPECTED_RECORDS[path]
		assert_eq(str(record.get("path")), path)
		assert_eq(str(record.get("type")), expected["type"], path)
		assert_eq(record.get("default_value"), expected["default_value"], path)
		assert_eq(str(record.get("section_id")), expected["section_id"], path)
		assert_eq(str(record.get("renderer")), expected["renderer"], path)
		assert_eq(record.get("player_writable"), expected["player_writable"], path)
		assert_eq(record.get("allowed_values", []), expected["allowed_values"], path)
		assert_eq(float(record.get("step", -1.0)), float(expected["step"]), path)


func test_registry_validates_manual_extensions_and_rejects_retired_names() -> void:
	assert_true(_validate(&"preferences.reading.lower_background_during_narration", true).get("ok", false),
			"manual extension 1 must be accepted")
	assert_true(_validate(&"preferences.audio.output_mode", "mono").get("ok", false),
			"manual extension 2 must be accepted")
	assert_true(_validate(&"preferences.accessibility.sound_detail_text", "off").get("ok", false),
			"manual extension 3 must be accepted")

	for path in [
		&"preferences.language",
		&"preferences.dialogue.text_speed",
		&"preferences.dialogue.auto_text_speed",
		&"preferences.audio.voice_volume",
		&"preferences.audio.voice_muted",
		&"preferences.audio.mute_audio_on_focus_loss",
		&"preferences.display.fullscreen",
		&"preferences.accessibility.font_scale",
		&"preferences.accessibility.large_click_targets",
		&"preferences.accessibility.colorblind_mode",
		&"preferences.accessibility.screen_shake_strength",
	]:
		var result := _validate(path, true)
		assert_false(result.get("ok", true), "%s must not be accepted" % path)
		assert_eq(result.get("code"), &"invalid_preference_path", "%s must fail as an unknown path" % path)


func test_registry_rejects_non_finite_audio_and_wrong_numeric_shapes() -> void:
	assert_eq(_validate(&"preferences.audio.music_volume", 2.0).get("code"), &"invalid_profile")
	assert_eq(_validate(&"preferences.audio.music_volume", -0.1).get("code"), &"invalid_profile")
	assert_eq(_validate(&"preferences.audio.music_volume", INF).get("code"), &"invalid_profile")
	assert_eq(_validate(&"preferences.audio.music_volume", 1).get("code"), &"invalid_profile")
	assert_eq(_validate(&"preferences.accessibility.text_size", 125.0).get("code"), &"invalid_profile")


func test_visible_records_are_section_authority_and_audio_uses_five_percent_steps() -> void:
	var audio_paths := []
	for record in _visible_records(&"audio"):
		audio_paths.append(str(record.get("path")))
		if str(record.get("renderer")) == "percent_slider":
			assert_eq(float(record.get("step")), 0.05, str(record.get("path")))
	audio_paths.sort()
	assert_eq(audio_paths, [
		"preferences.audio.ambience_muted",
		"preferences.audio.ambience_volume",
		"preferences.audio.master_muted",
		"preferences.audio.master_volume",
		"preferences.audio.music_muted",
		"preferences.audio.music_volume",
		"preferences.audio.mute_when_inactive",
		"preferences.audio.output_mode",
		"preferences.audio.sfx_muted",
		"preferences.audio.sfx_volume",
	])
	assert_false(audio_paths.has("preferences.audio.voice_volume"))


func test_capability_owned_fields_are_the_only_non_player_writable_records() -> void:
	for path in EXPECTED_RECORDS.keys():
		var expected_writable: bool = EXPECTED_RECORDS[path]["player_writable"]
		assert_eq(_is_player_writable(StringName(path)), expected_writable, path)
	assert_false(_is_player_writable(&"preferences.exceptional_replay.available"))
	assert_false(_is_player_writable(&"preferences.dark_mode.available"))
	assert_true(_is_player_writable(&"preferences.exceptional_replay.replay_full"))
	assert_true(_is_player_writable(&"preferences.dark_mode.next_run_enabled"))


func _registry_script() -> Variant:
	var loaded: Dictionary = PROBE.load_script(REGISTRY_PATH)
	if not loaded.get("ok", false):
		return null
	return loaded["value"]


func _records() -> Array:
	var registry = _registry_script()
	if registry == null:
		return []
	return registry.call(&"records")


func _visible_records(section_id: StringName) -> Array:
	var registry = _registry_script()
	if registry == null:
		return []
	return registry.call(&"visible_records", section_id)


func _validate(path: StringName, value: Variant) -> Dictionary:
	var registry = _registry_script()
	if registry == null:
		return {"ok": false, "code": &"invalid_preference_path", "message": "registry missing"}
	return registry.call(&"validate", path, value)


func _is_player_writable(path: StringName) -> bool:
	var registry = _registry_script()
	if registry == null:
		return false
	return bool(registry.call(&"is_player_writable", path))


func _records_by_path(records: Array) -> Dictionary:
	var by_path := {}
	for record in records:
		by_path[str(record.get("path"))] = record
	return by_path


func _sorted_strings(values: Array) -> Array:
	var strings := []
	for value in values:
		strings.append(str(value))
	strings.sort()
	return strings
