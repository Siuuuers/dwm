class_name AudioManifest
extends RefCounted

const BGM_DIR := "res://audio/bgm/"
const AMBIENCE_DIR := "res://audio/ambience/"
const UI_DIR := "res://audio/ui/"
const EXT := ".ogg"

const BGM_IDS := [
	"menu_theme",
	"desktop_alone_day", "desktop_alone_pressure", "desktop_alone_low_health",
	"desktop_night_uncertain", "minesweeper_focus", "contacts_soft", "shop_idle",
	"schedule_planning", "backup_safe", "settings_calm",
	"priscilla_warm", "priscilla_playful", "priscilla_mad", "priscilla_dark", "priscilla_true",
	"lavinia_quiet", "lavinia_walk", "lavinia_mad", "lavinia_dark", "lavinia_true",
	"sylvia_mystery", "sylvia_soft", "sylvia_mad", "sylvia_dark", "sylvia_true",
	"group_priscilla_lavinia", "group_tension", "twofriends_absent",
	"date_challenge_normal", "date_challenge_dark", "date_challenge_true",
	"hospital_room", "ending_alone",
	"ending_priscilla_sweet", "ending_priscilla_dark", "ending_priscilla_observation",
	"ending_lavinia_sweet", "ending_lavinia_dark", "ending_lavinia_observation",
	"ending_sylvia_sweet", "ending_sylvia_dark", "ending_sylvia_special",
	"ending_priscilla_lavinia", "ending_sweet", "ending_dark",
]

## Exact ending-id -> track map (dwm-p2r.8 handoff contract sec 4). Keys equal
## DatingEndingRules.CANONICAL_ENDING_IDS; there is no suffix inference and no ending_alone
## fallback. The retired .true ids resolve to nothing and fail before AudioManager mutation.
const ENDING_TRACKS := {
	"ending.alone": "ending_alone",
	"ending.priscilla.sweet": "ending_priscilla_sweet",
	"ending.priscilla.dark": "ending_priscilla_dark",
	"ending.priscilla.observation": "ending_priscilla_observation",
	"ending.lavinia.sweet": "ending_lavinia_sweet",
	"ending.lavinia.dark": "ending_lavinia_dark",
	"ending.lavinia.observation": "ending_lavinia_observation",
	"ending.sylvia.sweet": "ending_sylvia_sweet",
	"ending.sylvia.dark": "ending_sylvia_dark",
	"ending.sylvia.special": "ending_sylvia_special",
	"ending.priscilla_lavinia": "ending_priscilla_lavinia",
}
const AMBIENCE_IDS := ["room_tone", "computer_hum", "hospital_air", "rain_window"]
const CUE_IDS := {
	"button_accept": "ui", "button_cancel": "ui", "window_open": "ui", "window_close": "ui",
	"notification": "ui", "save_success": "ui", "save_error": "ui",
	"jealous_mine_stinger": "stinger", "desire_mine_stinger": "stinger",
}
const SIMPLE_CONTEXTS := {
	"menu": "menu_theme",
	"minesweeper": "minesweeper_focus", "contacts": "contacts_soft", "shop": "shop_idle",
	"schedule": "schedule_planning", "backup": "backup_safe", "settings": "settings_calm",
	"dating_challenge": "date_challenge_normal", "dating_dark_path": "date_challenge_dark",
	"dating_true_path": "date_challenge_true", "hospital": "hospital_room",
}
const AMBIENCE_CONTEXTS := {
	"room": "room_tone", "desktop": "computer_hum", "hospital": "hospital_air", "rain": "rain_window",
}


func resolve_music_context(context_id: String, context: Dictionary = {}) -> Dictionary:
	if not _primitive_dictionary(context):
		return _failure(&"invalid_audio_context")
	var allowed: Array = {
		"main_desktop": ["pressure", "health"], "dating": ["route_type", "friend_id", "mood", "attitude"],
		"ending": ["ending_id"],
	}.get(context_id, [])
	if not _only_fields(context, allowed):
		return _failure(&"invalid_audio_context")
	if context_id == "main_desktop":
		for key in context:
			if typeof(context[key]) != TYPE_INT:
				return _failure(&"invalid_audio_context")
	elif context_id in ["dating", "ending"]:
		for key in context:
			if typeof(context[key]) != TYPE_STRING:
				return _failure(&"invalid_audio_context")
	var track_id := str(SIMPLE_CONTEXTS.get(context_id, ""))
	match context_id:
		"main_desktop":
			track_id = "desktop_alone_pressure" if int(context.get("pressure", 0)) >= 10 else ("desktop_alone_low_health" if int(context.get("health", 6)) <= 0 else "desktop_alone_day")
		"dating":
			track_id = _dating_track(context)
		"ending":
			track_id = _ending_track(str(context.get("ending_id", "")))
	if track_id.is_empty() or track_id not in BGM_IDS:
		return _failure(&"unknown_audio_context")
	return {"ok": true, "value": _record(track_id, _bgm_path(track_id), &"Music", true, 0.25, 0.25)}


func resolve_ambience_context(context_id: String, context: Dictionary = {}) -> Dictionary:
	if not _primitive_dictionary(context) or not context.is_empty():
		return _failure(&"invalid_audio_context")
	var track_id := str(AMBIENCE_CONTEXTS.get(context_id, ""))
	if track_id.is_empty():
		return _failure(&"unknown_audio_context")
	return {"ok": true, "value": _record(track_id, "%s%s%s" % [AMBIENCE_DIR, track_id, EXT], &"Ambience", true, 0.2, 0.2)}


func get_cue(cue_id: String) -> Dictionary:
	if not CUE_IDS.has(cue_id):
		return _failure(&"unknown_audio_cue")
	var category: String = CUE_IDS[cue_id]
	var bus := &"UI" if category == "ui" else &"SFX"
	return {"ok": true, "value": _record(cue_id, "%s%s%s" % [UI_DIR, cue_id, EXT], bus, false, 0.0, 0.0)}


func get_expected_audio_paths() -> Dictionary:
	var bgm := {}
	for id in BGM_IDS:
		bgm[id] = _bgm_path(id)
	var ambience := {}
	for id in AMBIENCE_IDS:
		ambience[id] = "%s%s%s" % [AMBIENCE_DIR, id, EXT]
	var ui := {}
	for id in CUE_IDS:
		ui[id] = "%s%s%s" % [UI_DIR, id, EXT]
	return {"bgm": bgm, "ambience": ambience, "ui": ui}


func get_missing_audio_paths() -> Array:
	var missing: Array = []
	for group: Dictionary in get_expected_audio_paths().values():
		for path: String in group.values():
			if not ResourceLoader.exists(path):
				missing.append(path)
	return missing


func _dating_track(context: Dictionary) -> String:
	var route := str(context.get("route_type", "solo"))
	if route == "twofriends":
		return "twofriends_absent"
	if route == "group":
		return "group_tension" if str(context.get("mood", "")) in ["mad", "upset"] or str(context.get("attitude", "")) in ["mad", "upset"] else "group_priscilla_lavinia"
	var friend := str(context.get("friend_id", ""))
	if str(context.get("mood", "")) == "mad" and friend in ["priscilla", "lavinia", "sylvia"]:
		return "%s_mad" % friend
	return {"priscilla": "priscilla_warm", "lavinia": "lavinia_quiet", "sylvia": "sylvia_mystery"}.get(friend, "desktop_alone_day")


func _ending_track(ending_id: String) -> String:
	# Exact map only: empty, unknown, and retired .true ids resolve to "" and the caller fails
	# with unknown_audio_context before any AudioManager mutation.
	return str(ENDING_TRACKS.get(ending_id, ""))


func _record(id: String, path: String, bus: StringName, looped: bool, fade_in: float, fade_out: float) -> Dictionary:
	return {"id": id, "path": path, "bus": bus, "loop": looped, "fade_in_seconds": fade_in, "fade_out_seconds": fade_out}


func _bgm_path(id: String) -> String:
	return "%s%s%s" % [BGM_DIR, id, EXT]


func _only_fields(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if str(key) not in allowed:
			return false
	return true


func _primitive_dictionary(value: Dictionary) -> bool:
	for key in value:
		if typeof(key) != TYPE_STRING:
			return false
		var item: Variant = value[key]
		if typeof(item) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			return false
	return true


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
