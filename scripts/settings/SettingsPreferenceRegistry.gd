class_name SettingsPreferenceRegistry
extends RefCounted

const WINDOW_SIZES := ["1280x720", "1600x900", "1920x1080"]

const _LOCALE_IDS := ["en", "zh_CN", "zh_HK", "ja", "ko"]
const _MINESWEEPER_CELL_SIZES := [10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60]

const _RECORDS := [
	{"path": &"preferences.language.primary_locale_id", "type": &"locale_id", "default_value": "en", "section_id": &"language", "renderer": &"locale_option", "player_writable": true, "visible": true, "allowed_values": _LOCALE_IDS, "step": 0.0, "label": "Primary language"},
	{"path": &"preferences.language.secondary_locale_id", "type": &"locale_id", "default_value": "zh_CN", "section_id": &"language", "renderer": &"locale_option", "player_writable": true, "visible": true, "allowed_values": _LOCALE_IDS, "step": 0.0, "label": "Secondary language"},
	{"path": &"preferences.language.dual_enabled", "type": &"bool", "default_value": false, "section_id": &"language", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Dual language"},
	{"path": &"preferences.reading.reveal_speed", "type": &"enum_string", "default_value": "normal", "section_id": &"reading", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["instant", "fast", "normal", "slow"], "step": 0.0, "label": "Reveal speed"},
	{"path": &"preferences.reading.auto_enabled", "type": &"bool", "default_value": false, "section_id": &"reading", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Auto advance"},
	{"path": &"preferences.reading.auto_delay", "type": &"enum_string", "default_value": "normal", "section_id": &"reading", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["short", "normal", "long"], "step": 0.0, "label": "Auto delay"},
	{"path": &"preferences.reading.skip_mode", "type": &"enum_string", "default_value": "read_only", "section_id": &"reading", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["read_only", "all_text"], "step": 0.0, "label": "Skip mode"},
	{"path": &"preferences.reading.read_aloud_enabled", "type": &"bool", "default_value": false, "section_id": &"reading", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Read aloud"},
	{"path": &"preferences.reading.read_aloud_rate", "type": &"enum_string", "default_value": "normal", "section_id": &"reading", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["slow", "normal", "fast"], "step": 0.0, "label": "Read aloud rate"},
	{"path": &"preferences.reading.lower_background_during_narration", "type": &"bool", "default_value": true, "section_id": &"reading", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Lower background during narration"},
	{"path": &"preferences.audio.master_volume", "type": &"float_range", "default_value": 1.0, "section_id": &"audio", "renderer": &"percent_slider", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.05, "label": "Master volume"},
	{"path": &"preferences.audio.master_muted", "type": &"bool", "default_value": false, "section_id": &"audio", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Mute all audio"},
	{"path": &"preferences.audio.music_volume", "type": &"float_range", "default_value": 0.8, "section_id": &"audio", "renderer": &"percent_slider", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.05, "label": "Music volume"},
	{"path": &"preferences.audio.music_muted", "type": &"bool", "default_value": false, "section_id": &"audio", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Mute music"},
	{"path": &"preferences.audio.ambience_volume", "type": &"float_range", "default_value": 0.65, "section_id": &"audio", "renderer": &"percent_slider", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.05, "label": "Ambience volume"},
	{"path": &"preferences.audio.ambience_muted", "type": &"bool", "default_value": false, "section_id": &"audio", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Mute ambience"},
	{"path": &"preferences.audio.sfx_volume", "type": &"float_range", "default_value": 0.8, "section_id": &"audio", "renderer": &"percent_slider", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.05, "label": "SFX volume"},
	{"path": &"preferences.audio.sfx_muted", "type": &"bool", "default_value": false, "section_id": &"audio", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Mute SFX"},
	{"path": &"preferences.audio.mute_when_inactive", "type": &"bool", "default_value": true, "section_id": &"audio", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Mute when inactive"},
	{"path": &"preferences.audio.output_mode", "type": &"enum_string", "default_value": "stereo", "section_id": &"audio", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["stereo", "mono"], "step": 0.0, "label": "Output mode"},
	{"path": &"preferences.display.window_mode", "type": &"enum_string", "default_value": "windowed", "section_id": &"display", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["windowed", "borderless"], "step": 0.0, "label": "Window mode"},
	{"path": &"preferences.display.window_size", "type": &"enum_string", "default_value": "1280x720", "section_id": &"display", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": WINDOW_SIZES, "step": 0.0, "label": "Window size"},
	{"path": &"preferences.display.minesweeper_app_beginner_cell_size", "type": &"enum_int", "default_value": 36, "section_id": &"display", "renderer": &"enum_option", "player_writable": true, "visible": false, "allowed_values": _MINESWEEPER_CELL_SIZES, "step": 2.0, "label": "Beginner cell size"},
	{"path": &"preferences.display.minesweeper_app_beginner_always_fit", "type": &"bool", "default_value": false, "section_id": &"display", "renderer": &"toggle", "player_writable": true, "visible": false, "allowed_values": [], "step": 0.0, "label": "Fit beginner board"},
	{"path": &"preferences.display.minesweeper_app_intermediate_cell_size", "type": &"enum_int", "default_value": 36, "section_id": &"display", "renderer": &"enum_option", "player_writable": true, "visible": false, "allowed_values": _MINESWEEPER_CELL_SIZES, "step": 2.0, "label": "Intermediate cell size"},
	{"path": &"preferences.display.minesweeper_app_intermediate_always_fit", "type": &"bool", "default_value": false, "section_id": &"display", "renderer": &"toggle", "player_writable": true, "visible": false, "allowed_values": [], "step": 0.0, "label": "Fit intermediate board"},
	{"path": &"preferences.display.minesweeper_app_expert_cell_size", "type": &"enum_int", "default_value": 36, "section_id": &"display", "renderer": &"enum_option", "player_writable": true, "visible": false, "allowed_values": _MINESWEEPER_CELL_SIZES, "step": 2.0, "label": "Expert cell size"},
	{"path": &"preferences.display.minesweeper_app_expert_always_fit", "type": &"bool", "default_value": false, "section_id": &"display", "renderer": &"toggle", "player_writable": true, "visible": false, "allowed_values": [], "step": 0.0, "label": "Fit expert board"},
	{"path": &"preferences.display.minesweeper_challenge_cell_size", "type": &"enum_int", "default_value": 36, "section_id": &"display", "renderer": &"enum_option", "player_writable": true, "visible": false, "allowed_values": _MINESWEEPER_CELL_SIZES, "step": 2.0, "label": "Challenge cell size"},
	{"path": &"preferences.display.minesweeper_challenge_always_fit", "type": &"bool", "default_value": false, "section_id": &"display", "renderer": &"toggle", "player_writable": true, "visible": false, "allowed_values": [], "step": 0.0, "label": "Fit challenge board"},
	{"path": &"preferences.accessibility.text_size", "type": &"enum_int", "default_value": 100, "section_id": &"accessibility", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": [100, 125, 150], "step": 0.0, "label": "Text size"},
	{"path": &"preferences.accessibility.large_targets", "type": &"bool", "default_value": false, "section_id": &"accessibility", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Large targets"},
	{"path": &"preferences.accessibility.high_contrast", "type": &"bool", "default_value": false, "section_id": &"accessibility", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "High contrast"},
	{"path": &"preferences.accessibility.reduced_motion", "type": &"bool", "default_value": false, "section_id": &"accessibility", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Reduced motion"},
	{"path": &"preferences.accessibility.steady_interface", "type": &"bool", "default_value": false, "section_id": &"accessibility", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Steady interface"},
	{"path": &"preferences.accessibility.screen_shake", "type": &"enum_string", "default_value": "low", "section_id": &"accessibility", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["off", "low", "normal"], "step": 0.0, "label": "Screen shake"},
	{"path": &"preferences.accessibility.colour_differentiation", "type": &"enum_string", "default_value": "standard", "section_id": &"accessibility", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["standard", "protan", "deutan", "tritan"], "step": 0.0, "label": "Colour differentiation"},
	{"path": &"preferences.accessibility.sound_detail_text", "type": &"enum_string", "default_value": "story_relevant", "section_id": &"accessibility", "renderer": &"enum_option", "player_writable": true, "visible": true, "allowed_values": ["story_relevant", "off"], "step": 0.0, "label": "Sound detail text"},
	{"path": &"preferences.exceptional_replay.available", "type": &"bool", "default_value": false, "section_id": &"records", "renderer": &"readonly_bool", "player_writable": false, "visible": true, "allowed_values": [], "step": 0.0, "label": "Exceptional replay available"},
	{"path": &"preferences.exceptional_replay.replay_full", "type": &"bool", "default_value": false, "section_id": &"records", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Replay full route"},
	{"path": &"preferences.dark_mode.available", "type": &"bool", "default_value": false, "section_id": &"dark_mode", "renderer": &"readonly_bool", "player_writable": false, "visible": true, "allowed_values": [], "step": 0.0, "label": "Dark mode available"},
	{"path": &"preferences.dark_mode.next_run_enabled", "type": &"bool", "default_value": false, "section_id": &"dark_mode", "renderer": &"toggle", "player_writable": true, "visible": true, "allowed_values": [], "step": 0.0, "label": "Enable dark mode next run"},
]


static func records() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for record in _RECORDS:
		output.append(record.duplicate(true))
	return output


static func validate(path: StringName, value: Variant) -> Dictionary:
	var record := _record_for(path)
	if record.is_empty():
		return {"ok": false, "code": &"invalid_preference_path", "path": String(path), "message": "unknown preference path"}
	var key := String(path)
	match String(record["type"]):
		"bool":
			if typeof(value) != TYPE_BOOL:
				return _invalid(key, "value must be a bool")
		"locale_id":
			if typeof(value) != TYPE_STRING or value != value.strip_edges() or value not in record["allowed_values"]:
				return _invalid(key, "value must be a registered locale id")
		"enum_string":
			if typeof(value) != TYPE_STRING or value != value.strip_edges() or value not in record["allowed_values"]:
				return _invalid(key, "value is outside the allowed values")
		"enum_int":
			if typeof(value) != TYPE_INT or value not in record["allowed_values"]:
				return _invalid(key, "value is outside the allowed values")
		"float_range":
			if typeof(value) != TYPE_FLOAT or not is_finite(value) or value < 0.0 or value > 1.0:
				return _invalid(key, "value must be a finite float from 0.0 through 1.0")
		_:
			return _invalid(key, "registry record type is invalid")
	return {"ok": true, "code": &"ok", "value": _duplicate_value(value)}


static func default_value(path: StringName) -> Variant:
	var record := _record_for(path)
	if record.is_empty():
		return null
	return _duplicate_value(record["default_value"])


static func visible_records(section_id: StringName) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for record in _RECORDS:
		if bool(record.get("visible", false)) and record.get("section_id") == section_id:
			output.append(record.duplicate(true))
	return output


static func is_player_writable(path: StringName) -> bool:
	var record := _record_for(path)
	return bool(record.get("player_writable", false)) if not record.is_empty() else false


static func _record_for(path: StringName) -> Dictionary:
	for record in _RECORDS:
		if record["path"] == path:
			return record
	return {}


static func _duplicate_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


static func _invalid(path: String, message: String) -> Dictionary:
	return {"ok": false, "code": &"invalid_profile", "path": path, "message": message}
