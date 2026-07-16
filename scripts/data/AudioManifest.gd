class_name AudioManifest
extends RefCounted
# AudioManifest (CONTENT §13 / CONTRACTS §9): descriptive audio catalog. Always check
# ResourceLoader.exists() before loading; missing audio must not crash and is reported.
# No audio metadata is ever executed.

const BGM_DIR := "res://audio/bgm/"
const AMBIENCE_DIR := "res://audio/ambience/"
const UI_DIR := "res://audio/ui/"
const EXT := ".ogg"

const BGM_IDS := [
	"menu_theme", "opening_forget_me_not", "tutorial_soft_screen",
	"desktop_alone_day", "desktop_alone_pressure", "desktop_alone_low_health",
	"desktop_night_uncertain", "minesweeper_focus", "contacts_soft", "shop_idle",
	"schedule_planning", "backup_safe", "settings_calm",
	"priscilla_warm", "priscilla_playful", "priscilla_mad", "priscilla_dark", "priscilla_true",
	"lavinia_quiet", "lavinia_walk", "lavinia_mad", "lavinia_dark", "lavinia_true",
	"sylvia_mystery", "sylvia_soft", "sylvia_mad", "sylvia_dark", "sylvia_true",
	"group_priscilla_lavinia", "group_tension", "twofriends_absent",
	"date_challenge_normal", "date_challenge_dark", "date_challenge_true",
	"hospital_room",
	"ending_alone",
	"ending_priscilla_sweet", "ending_priscilla_dark", "ending_priscilla_true",
	"ending_lavinia_sweet", "ending_lavinia_dark", "ending_lavinia_true",
	"ending_sylvia_sweet", "ending_sylvia_dark", "ending_sylvia_true",
	"ending_priscilla_lavinia",
	"ending_sweet", "ending_dark", "ending_true",
]

const AMBIENCE_IDS := ["room_tone", "computer_hum", "hospital_air", "rain_window"]

# UI sfx + the two mine stingers (AudioCueData, stinger category).
const CUE_IDS := {
	"button_accept": "ui", "button_cancel": "ui", "window_open": "ui", "window_close": "ui",
	"notification": "ui", "save_success": "ui", "save_error": "ui",
	"jealous_mine_stinger": "stinger", "desire_mine_stinger": "stinger",
}


func _bgm_path(id: String) -> String:
	return "%s%s%s" % [BGM_DIR, id, EXT]


func get_bgm_tracks() -> Dictionary:
	var out: Dictionary = {}
	for id in BGM_IDS:
		out[id] = {"id": id, "path": _bgm_path(id), "category": "bgm"}
	return out


func get_audio_cues() -> Dictionary:
	var out: Dictionary = {}
	for id in AMBIENCE_IDS:
		out[id] = {"id": id, "path": "%s%s%s" % [AMBIENCE_DIR, id, EXT], "bus": "Ambience", "category": "ambience"}
	for id in CUE_IDS.keys():
		var cat: String = CUE_IDS[id]
		var bus := "UI" if cat == "ui" else "SFX"
		out[id] = {"id": id, "path": "%s%s%s" % [UI_DIR, id, EXT], "bus": bus, "category": cat}
	return out


func get_expected_audio_paths() -> Dictionary:
	var bgm: Dictionary = {}
	for id in BGM_IDS:
		bgm[id] = _bgm_path(id)
	var ambience: Dictionary = {}
	for id in AMBIENCE_IDS:
		ambience[id] = "%s%s%s" % [AMBIENCE_DIR, id, EXT]
	var ui: Dictionary = {}
	for id in CUE_IDS.keys():
		ui[id] = "%s%s%s" % [UI_DIR, id, EXT]
	return {"bgm": bgm, "ambience": ambience, "ui": ui}


func get_path(category: String, id: String) -> String:
	match category:
		"bgm":
			if id in BGM_IDS:
				return _bgm_path(id)
		"ambience":
			if id in AMBIENCE_IDS:
				return "%s%s%s" % [AMBIENCE_DIR, id, EXT]
		"ui", "sfx", "stinger":
			if CUE_IDS.has(id):
				return "%s%s%s" % [UI_DIR, id, EXT]
	return ""


func has_track(track_id: String) -> bool:
	return track_id in BGM_IDS


func get_track_data(track_id: String) -> Dictionary:
	if track_id in BGM_IDS:
		return {"id": track_id, "path": _bgm_path(track_id), "category": "bgm"}
	return {}


func get_missing_audio_paths() -> Array:
	var missing: Array = []
	var expected := get_expected_audio_paths()
	for group in expected.keys():
		for id in (expected[group] as Dictionary).keys():
			var path: String = expected[group][id]
			if not ResourceLoader.exists(path):
				missing.append(path)
	return missing
