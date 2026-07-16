extends Node
# AudioManager (CONTRACTS §9 / FLOWS §8): owns music/ambience/sfx contexts. Never applies
# gameplay effects or changes scenes. No hard audio dependency: the prototype runs with no
# audio files. Missing tracks return a safe error and never crash. No audio metadata is executed.

signal bgm_changed(track_id: String, previous_track_id: String)
signal bgm_stopped(previous_track_id: String)
signal ambience_changed(track_id: String, previous_track_id: String)
signal audio_context_changed(context_id: String, context: Dictionary)
signal audio_settings_applied(settings: Dictionary)
signal audio_warning(result: Dictionary)

var _current_bgm_id: String = ""
var _current_ambience_id: String = ""
var _current_context_id: String = ""
var _current_context: Dictionary = {}

var _bgm_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer

# AudioManifest is a RefCounted instance (not called statically) so its get_path(category,id)
# does not collide with the built-in Resource.get_path() on the class object.
var _manifest := AudioManifest.new()


func _ready() -> void:
	ensure_audio_players()


func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func ensure_audio_players() -> void:
	if _bgm_player == null:
		_bgm_player = _make_player("BgmPlayer")
	if _ambience_player == null:
		_ambience_player = _make_player("AmbiencePlayer")
	if _sfx_player == null:
		_sfx_player = _make_player("SfxPlayer")
	if _ui_player == null:
		_ui_player = _make_player("UiPlayer")
	if _voice_player == null:
		_voice_player = _make_player("VoicePlayer")


func _make_player(pname: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = pname
	add_child(p)
	return p


func ensure_audio_buses() -> void:
	# Buses are optional; creating them is safe but not required for the prototype.
	pass


func _setting(key: String, default_value: Variant) -> Variant:
	var gs := _gs()
	if gs != null and gs.get("settings") is Dictionary and (gs.settings as Dictionary).has(key):
		return gs.settings[key]
	return default_value


func apply_volume_settings() -> void:
	ensure_audio_players()
	var music_vol := float(_setting("music_volume", 0.8))
	var sfx_vol := float(_setting("sfx_volume", 0.8))
	var amb_vol := float(_setting("ambience_volume", 0.65))
	if _bgm_player != null:
		_bgm_player.volume_db = linear_to_db(maxf(0.0001, music_vol))
	if _ambience_player != null:
		_ambience_player.volume_db = linear_to_db(maxf(0.0001, amb_vol))
	if _sfx_player != null:
		_sfx_player.volume_db = linear_to_db(maxf(0.0001, sfx_vol))
	if _ui_player != null:
		_ui_player.volume_db = linear_to_db(maxf(0.0001, sfx_vol))
	emit_signal("audio_settings_applied", {"music": music_vol, "sfx": sfx_vol, "ambience": amb_vol})


func _missing_result(track_id: String) -> Dictionary:
	var path := _manifest.get_path("bgm", track_id)
	var result := {"ok": false, "reason": "missing_audio", "track_id": track_id, "path": path}
	emit_signal("audio_warning", result)
	return result


func is_track_available(track_id: String) -> bool:
	if not _manifest.has_track(track_id):
		return false
	return ResourceLoader.exists(_manifest.get_path("bgm", track_id))


func get_track_path(track_id: String) -> String:
	return _manifest.get_path("bgm", track_id)


func play_bgm(track_id: String, fade_seconds: float = -1.0, force_restart: bool = false) -> Dictionary:
	if track_id == "":
		return {"ok": false, "reason": "empty_track_id"}
	if not force_restart and track_id == _current_bgm_id:
		return {"ok": true, "reason": "already_playing", "track_id": track_id}
	if not is_track_available(track_id):
		return _missing_result(track_id)
	ensure_audio_players()
	var stream = ResourceLoader.load(get_track_path(track_id))
	if stream == null or not (stream is AudioStream):
		return _missing_result(track_id)
	var previous := _current_bgm_id
	_bgm_player.stream = stream
	_bgm_player.play()
	_current_bgm_id = track_id
	_set_audio_state("current_bgm_id", track_id)
	emit_signal("bgm_changed", track_id, previous)
	return {"ok": true, "track_id": track_id}


func stop_bgm(fade_seconds: float = -1.0) -> Dictionary:
	var previous := _current_bgm_id
	if _bgm_player != null:
		_bgm_player.stop()
	_current_bgm_id = ""
	_set_audio_state("current_bgm_id", "")
	emit_signal("bgm_stopped", previous)
	return {"ok": true, "previous_track_id": previous}


func get_current_bgm_id() -> String:
	return _current_bgm_id


func is_bgm_playing(track_id: String = "") -> bool:
	if _bgm_player == null:
		return false
	if track_id == "":
		return _bgm_player.playing
	return _bgm_player.playing and _current_bgm_id == track_id


func play_ambience(track_id: String, fade_seconds: float = -1.0, force_restart: bool = false) -> Dictionary:
	if track_id == "":
		return {"ok": false, "reason": "empty_track_id"}
	if not force_restart and track_id == _current_ambience_id:
		return {"ok": true, "reason": "already_playing", "track_id": track_id}
	var path := _manifest.get_path("ambience", track_id)
	if path == "" or not ResourceLoader.exists(path):
		var result := {"ok": false, "reason": "missing_audio", "track_id": track_id, "path": path}
		emit_signal("audio_warning", result)
		return result
	ensure_audio_players()
	var stream = ResourceLoader.load(path)
	if stream == null or not (stream is AudioStream):
		return {"ok": false, "reason": "missing_audio", "track_id": track_id, "path": path}
	var previous := _current_ambience_id
	_ambience_player.stream = stream
	_ambience_player.play()
	_current_ambience_id = track_id
	_set_audio_state("current_ambience_id", track_id)
	emit_signal("ambience_changed", track_id, previous)
	return {"ok": true, "track_id": track_id}


func stop_ambience(fade_seconds: float = -1.0) -> Dictionary:
	var previous := _current_ambience_id
	if _ambience_player != null:
		_ambience_player.stop()
	_current_ambience_id = ""
	_set_audio_state("current_ambience_id", "")
	return {"ok": true, "previous_track_id": previous}


func get_current_ambience_id() -> String:
	return _current_ambience_id


func _play_cue(player: AudioStreamPlayer, cue_id: String) -> Dictionary:
	var cues := _manifest.get_audio_cues()
	if not cues.has(cue_id):
		return {"ok": false, "reason": "unknown_cue", "cue_id": cue_id}
	var path: String = cues[cue_id]["path"]
	if not ResourceLoader.exists(path):
		return {"ok": false, "reason": "missing_audio", "cue_id": cue_id, "path": path}
	var stream = ResourceLoader.load(path)
	if stream == null or not (stream is AudioStream):
		return {"ok": false, "reason": "missing_audio", "cue_id": cue_id, "path": path}
	ensure_audio_players()
	player.stream = stream
	player.play()
	return {"ok": true, "cue_id": cue_id}


func play_sfx(cue_id: String) -> Dictionary:
	return _play_cue(_sfx_player, cue_id)


func play_ui_sfx(cue_id: String) -> Dictionary:
	return _play_cue(_ui_player, cue_id)


func play_voice(cue_id: String) -> Dictionary:
	return _play_cue(_voice_player, cue_id)


# ---- Context resolution (FLOWS §8) ----
func set_music_context(context_id: String, context: Dictionary = {}) -> Dictionary:
	_current_context_id = context_id
	_current_context = context.duplicate(true)
	_set_audio_state("current_context_id", context_id)
	_set_audio_state("current_context", _current_context)
	emit_signal("audio_context_changed", context_id, _current_context)
	var track := resolve_bgm_for_context(context_id, context)
	if track == "":
		return {"ok": false, "reason": "no_track_for_context", "context_id": context_id}
	return play_bgm(track)


func refresh_current_context() -> Dictionary:
	return set_music_context(_current_context_id, _current_context)


func resolve_bgm_for_context(context_id: String, context: Dictionary = {}) -> String:
	match context_id:
		"menu":
			return "menu_theme"
		"opening":
			return "opening_forget_me_not"
		"tutorial":
			return "tutorial_soft_screen"
		"main_desktop":
			return _resolve_main_desktop(context)
		"minesweeper":
			return "minesweeper_focus"
		"contacts":
			return "contacts_soft"
		"shop":
			return "shop_idle"
		"schedule":
			return "schedule_planning"
		"backup":
			return "backup_safe"
		"settings":
			return "settings_calm"
		"dating":
			return _resolve_dating(context)
		"dating_challenge":
			return "date_challenge_normal"
		"dating_dark_path":
			return "date_challenge_dark"
		"dating_true_path":
			return "date_challenge_true"
		"hospital":
			return "hospital_room"
		"ending":
			return _resolve_ending(context)
	return ""


func _resolve_main_desktop(context: Dictionary) -> String:
	var pressure := int(context.get("pressure", _gs_stat("pressure", 0)))
	var health := int(context.get("health", _gs_stat("health", 6)))
	if pressure >= 10:
		return "desktop_alone_pressure"
	if health <= 0:
		return "desktop_alone_low_health"
	return "desktop_alone_day"


func _gs_stat(stat_id: String, default_value: int) -> int:
	var gs := _gs()
	if gs != null and gs.has_method("get_stat"):
		return int(gs.get_stat(stat_id))
	return default_value


func _resolve_dating(context: Dictionary) -> String:
	var route_type := str(context.get("route_type", "solo"))
	if route_type == "twofriends":
		return "twofriends_absent"
	if route_type == "group":
		var mood := str(context.get("mood", ""))
		var attitude := str(context.get("attitude", ""))
		if mood == "mad" or mood == "upset" or attitude == "mad" or attitude == "upset":
			return "group_tension"
		return "group_priscilla_lavinia"
	# solo (or unset)
	var friend_id := str(context.get("friend_id", ""))
	var mood2 := str(context.get("mood", ""))
	if mood2 == "mad":
		match friend_id:
			"priscilla": return "priscilla_mad"
			"lavinia": return "lavinia_mad"
			"sylvia": return "sylvia_mad"
	match friend_id:
		"priscilla": return "priscilla_warm"
		"lavinia": return "lavinia_quiet"
		"sylvia": return "sylvia_mystery"
	return "desktop_alone_day"


func _resolve_ending(context: Dictionary) -> String:
	var ending_id := str(context.get("ending_id", ""))
	if ending_id == "":
		var gs := _gs()
		if gs != null and gs.get("route_context") is Dictionary:
			ending_id = str((gs.route_context as Dictionary).get("ending_id", ""))
	if ending_id == "":
		return "ending_alone"
	# "ending.priscilla.true" -> "ending_priscilla_true"; "ending.alone" -> "ending_alone".
	var track := ending_id.replace(".", "_")
	if _manifest.has_track(track):
		return track
	# Fallback by suffix.
	if ending_id.ends_with("sweet"):
		return "ending_sweet"
	if ending_id.ends_with("dark"):
		return "ending_dark"
	if ending_id.ends_with("true"):
		return "ending_true"
	return "ending_alone"


# ---- Music mute / pause ----
func pause_music() -> void:
	if _bgm_player != null:
		_bgm_player.stream_paused = true


func resume_music() -> void:
	if _bgm_player != null:
		_bgm_player.stream_paused = false


func set_music_muted(muted: bool) -> void:
	if _bgm_player != null:
		_bgm_player.stream_paused = muted
	_set_audio_state("music_muted", muted)


func get_missing_audio_report() -> Array:
	return _manifest.get_missing_audio_paths()


func _set_audio_state(key: String, value: Variant) -> void:
	var gs := _gs()
	if gs != null and gs.has_method("set_audio_state_value"):
		gs.set_audio_state_value(key, value)
