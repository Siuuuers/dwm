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


const SCENE_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Pure definition checks: media availability is the playback owner's responsibility.
static func validate_scene_catalogue(catalogue: Variant, entry_ids: Array) -> Dictionary:
	if not _scene_keys(catalogue, ["kind", "schema_version", "assets", "plans", "bindings"]):
		return _scene_failure()
	if typeof(catalogue.kind) != TYPE_STRING or catalogue.kind != "scene_audio_catalogue" or typeof(catalogue.schema_version) != TYPE_INT or catalogue.schema_version not in [1, 2]:
		return _scene_failure()
	for field: String in ["assets", "plans", "bindings"]:
		if typeof(catalogue[field]) != TYPE_ARRAY:
			return _scene_failure()
	var entries: Dictionary = {}
	for entry: Variant in entry_ids:
		if not _scene_id(entry) or entries.has(entry):
			return _scene_failure()
		entries[entry] = true
	var assets: Dictionary = {}
	var previous: String = ""
	for asset: Variant in catalogue.assets:
		if not _scene_keys(asset, ["asset_id", "path", "sha256", "duration_ms"]):
			return _scene_failure()
		if not _scene_id(asset.asset_id) or asset.asset_id <= previous or not _scene_hash(asset.sha256):
			return _scene_failure()
		if typeof(asset.duration_ms) != TYPE_INT or asset.duration_ms <= 0 or not _scene_path(asset.path, catalogue.schema_version):
			return _scene_failure()
		previous = asset.asset_id
		assets[asset.asset_id] = asset
	var plans: Dictionary = {}
	previous = ""
	for plan: Variant in catalogue.plans:
		if not _scene_keys(plan, ["plan_id", "revision", "variant_id", "ambience_asset_id", "entrance_ms", "load_anchor_id", "load_anchor_ms", "authorial", "essential", "missing_media", "music", "cues"]):
			return _scene_failure()
		# Version 1 remains ambience-only. Version 2 admits one authored bed on
		# its proper channel; it does not combine independent channel timelines.
		var asset_id: Variant = plan.ambience_asset_id
		if catalogue.schema_version == 2 and plan.music != null:
			if plan.ambience_asset_id != null: return _scene_failure()
			asset_id = plan.music
		if not _scene_id(plan.plan_id) or plan.plan_id <= previous or not _scene_id(asset_id) or not assets.has(asset_id):
			return _scene_failure()
		if typeof(plan.revision) != TYPE_INT or plan.revision <= 0 or typeof(plan.variant_id) != TYPE_STRING or plan.variant_id != "base" or not _scene_id(plan.load_anchor_id):
			return _scene_failure()
		if typeof(plan.authorial) != TYPE_BOOL or not plan.authorial or typeof(plan.essential) != TYPE_BOOL or plan.essential:
			return _scene_failure()
		if typeof(plan.missing_media) != TYPE_STRING or plan.missing_media != "silence" or (catalogue.schema_version == 1 and plan.music != null) or typeof(plan.cues) != TYPE_ARRAY or not plan.cues.is_empty():
			return _scene_failure()
		for field: String in ["entrance_ms", "load_anchor_ms"]:
			if typeof(plan[field]) != TYPE_INT or plan[field] < 0 or plan[field] >= assets[asset_id].duration_ms:
				return _scene_failure()
		previous = plan.plan_id
		plans[plan.plan_id] = plan
	previous = ""
	if catalogue.bindings.size() != entries.size():
		return _scene_failure()
	for binding: Variant in catalogue.bindings:
		if not _scene_keys(binding, ["entry_id", "plan_id"]):
			return _scene_failure()
		if not _scene_id(binding.entry_id) or binding.entry_id <= previous or not entries.has(binding.entry_id):
			return _scene_failure()
		if binding.plan_id != null and (not _scene_id(binding.plan_id) or not plans.has(binding.plan_id)):
			return _scene_failure()
		previous = binding.entry_id
	return {"ok": true, "value": catalogue.duplicate(true)}


static func make_scene_context(registration: Dictionary, entry_id: String, admission_receipt_id: String) -> Dictionary:
	var checked: Dictionary = _scene_registration(registration)
	if not checked.ok:
		return checked
	if not _scene_id(admission_receipt_id):
		return _scene_failure(&"invalid_scene_audio_context")
	var found: bool = false
	var selection: Variant = null
	for binding: Dictionary in checked.value.bindings:
		if binding.entry_id != entry_id:
			continue
		found = true
		if binding.plan_id != null:
			for plan: Dictionary in checked.value.plans:
				if plan.plan_id == binding.plan_id:
					selection = _scene_selection(plan)
	if not found:
		return _scene_failure(&"invalid_scene_audio_context")
	var encoded: Dictionary = SCENE_WRITER.stringify(registration)
	if not encoded.ok:
		return encoded
	return {"ok": true, "value": {"kind": "scene_audio", "schema_version": 1,
		"registration_sha256": str(encoded.value).sha256_text(),
		"admission_receipt_id": admission_receipt_id, "selection": selection}}


## Receipt-to-entry authority belongs to A's validated ledger, not this resolver.
static func resolve_scene_context(context: Dictionary, registration: Dictionary) -> Dictionary:
	var checked: Dictionary = _scene_registration(registration)
	if not checked.ok:
		return checked
	if not _scene_keys(context, ["kind", "schema_version", "registration_sha256", "admission_receipt_id", "selection"]):
		return _scene_failure(&"invalid_scene_audio_context")
	if typeof(context.kind) != TYPE_STRING or context.kind != "scene_audio" or typeof(context.schema_version) != TYPE_INT or context.schema_version != 1 or not _scene_id(context.admission_receipt_id) or not _scene_hash(context.registration_sha256):
		return _scene_failure(&"invalid_scene_audio_context")
	var encoded: Dictionary = SCENE_WRITER.stringify(registration)
	if not encoded.ok:
		return encoded
	if context.registration_sha256 != str(encoded.value).sha256_text():
		return _scene_failure(&"scene_audio_registration_mismatch")
	var result: Dictionary = {"snapshot": context.duplicate(true), "record": null, "entrance_seconds": 0.0, "load_seconds": 0.0}
	if context.selection == null:
		return {"ok": true, "value": result}
	if not _scene_keys(context.selection, ["plan_id", "plan_revision", "variant_id", "anchor_id"]):
		return _scene_failure(&"invalid_scene_audio_selection")
	if not _scene_id(context.selection.plan_id) or typeof(context.selection.plan_revision) != TYPE_INT or typeof(context.selection.variant_id) != TYPE_STRING or not _scene_id(context.selection.anchor_id):
		return _scene_failure(&"invalid_scene_audio_selection")
	for plan: Dictionary in checked.value.plans:
		if context.selection != _scene_selection(plan):
			continue
		var asset_id: String = plan.music if plan.music != null else plan.ambience_asset_id
		for asset: Dictionary in checked.value.assets:
			if asset.asset_id == asset_id:
				result.record = {"asset": asset.duplicate(true), "plan": plan.duplicate(true)}
				if plan.music != null: result["channel"] = &"music"
				result.entrance_seconds = float(plan.entrance_ms) / 1000.0
				result.load_seconds = float(plan.load_anchor_ms) / 1000.0
				return {"ok": true, "value": result}
	return _scene_failure(&"invalid_scene_audio_selection")


static func _scene_registration(registration: Dictionary) -> Dictionary:
	if registration.get("kind") != "scene_reading_registration" or typeof(registration.get("schema_version")) != TYPE_INT or registration.schema_version != 3:
		return _scene_failure(&"invalid_scene_audio_registration")
	var manifest: Variant = registration.get("entry_manifest")
	if typeof(manifest) != TYPE_DICTIONARY or typeof(manifest.get("entries")) != TYPE_ARRAY:
		return _scene_failure(&"invalid_scene_audio_registration")
	var ids: Array = []
	for entry: Variant in manifest.entries:
		if typeof(entry) != TYPE_DICTIONARY or not _scene_id(entry.get("entry_id")):
			return _scene_failure(&"invalid_scene_audio_registration")
		ids.append(entry.entry_id)
	return validate_scene_catalogue(registration.get("audio_catalogue"), ids)


static func _scene_selection(plan: Dictionary) -> Dictionary:
	return {"plan_id": plan.plan_id, "plan_revision": plan.revision, "variant_id": plan.variant_id, "anchor_id": plan.load_anchor_id}


static func _scene_keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size():
		return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or key not in keys:
			return false
	return true


static func _scene_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty()


static func _scene_hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _scene_path(value: Variant, catalogue_version: int = 1) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var prefix := "res://tests/fixtures/audio/"
	if catalogue_version == 2 and value.begins_with(BGM_DIR) and value.ends_with(".ogg"):
		prefix = BGM_DIR
	if not value.begins_with(prefix): return false
	var relative: String = value.trim_prefix(prefix)
	if relative.is_empty() or "\\" in relative or ":" in relative or "%" in relative:
		return false
	for part: String in relative.split("/", true):
		if part in ["", ".", ".."]:
			return false
	return true


static func _scene_failure(code: StringName = &"invalid_scene_audio_catalogue") -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}

