extends RefCounted

## Read-only title-host playback. Endings require discovery; other reached scenes require the ending milestone.
signal playback_finished(result: Dictionary)
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
var _entry_catalog: Script = preload("res://scripts/data/DialogicTimelineCatalog.gd")
var _profile: Object
var _bridge: Object
var _active_signature := ""
var _active_token := ""
var _starting := false
var _early: Array[Dictionary] = []

func configure(profile: Object, bridge: Object) -> Dictionary:
	if profile == null or bridge == null or not profile.has_method("get_reached_presentations") \
			or not bridge.has_method("configure_reached_replay") or not bridge.has_signal("reached_replay_finished"):
		return _fail(&"gallery_replay_unavailable")
	if _profile != null and (_profile != profile or _bridge != bridge): return _fail(&"gallery_replay_already_configured")
	var bound: Dictionary = bridge.configure_reached_replay(profile)
	if not bound.get("ok", false): return bound
	_profile = profile
	_bridge = bridge
	if not bridge.is_connected("reached_replay_finished", _on_finished):
		bridge.connect("reached_replay_finished", _on_finished)
	return {"ok":true}

func get_variants(ending_id: String) -> Dictionary:
	if _profile == null: return _fail(&"gallery_replay_unavailable")
	var discovery: Dictionary = _profile.get_gallery_discovery_snapshot()
	if not discovery.get("ok", false): return discovery
	var canonical_id := SIGNATURE.semantic_ending_id(ending_id)
	var discovered := false
	for identity: String in discovery.value.ending_ids:
		if SIGNATURE.semantic_ending_id(identity) == canonical_id: discovered = true
	if not discovered: return _fail(&"ending_not_discovered")
	var reached: Dictionary = _profile.get_reached_presentations()
	if not reached.get("ok", false): return reached
	var variants: Array[Dictionary] = []
	for record: Dictionary in reached.value.records:
		var entry_id := str(record.signature.get("entry_id", ""))
		var located := SIGNATURE.entry_record(entry_id)
		if not located.ok or located.value.ending_id != canonical_id or entry_id.ends_with(".residue"): continue
		var checked := SIGNATURE.validate(record.signature)
		if not checked.ok or checked.value.signature_id != record.signature_id:
			return _fail(&"gallery_record_unavailable")
		if not _entry_available(located.value): return _fail(&"gallery_record_unavailable")
		variants.append(record.duplicate(true))
	return {"ok":true, "value":{"records":variants, "chronology": _variant_chronology(reached.value, variants)}}

## No new Gallery discovery identities: these are exact already-reached callable scenes.
func get_reached_entry_variants(entry_id: String = "") -> Dictionary:
	if _profile == null: return _fail(&"gallery_replay_unavailable")
	if not _profile.has_method("has_completed_ending") or not _profile.has_completed_ending():
		return {"ok": true, "value": {"records": [], "entry_ids": [],
			"chronology": {"first_witnessed": [], "legacy_unordered": []}}}
	var reached: Dictionary = _profile.get_reached_presentations()
	if not reached.get("ok", false): return reached
	var variants: Array[Dictionary] = []
	var entry_ids: Array[String] = []
	for record: Dictionary in reached.value.records:
		var candidate_id := str(record.signature.get("entry_id", ""))
		if not entry_id.is_empty() and candidate_id != entry_id: continue
		var located := SIGNATURE.entry_record(candidate_id)
		if not located.ok or not _is_date_record(located.value): continue
		if candidate_id not in entry_ids: entry_ids.append(candidate_id)
		var checked := SIGNATURE.validate(record.signature)
		if not checked.ok or checked.value.signature_id != record.signature_id:
			# Enumeration retains the known record; its exact query owns failure.
			if not entry_id.is_empty(): return _fail(&"gallery_record_unavailable")
			continue
		variants.append(record.duplicate(true))
	entry_ids.sort()
	return {"ok": true, "value": {"records": variants, "entry_ids": entry_ids,
		"chronology": _variant_chronology(reached.value, variants)}}

## Filters owner-provided provenance without interpreting a signature digest as chronology.
func _variant_chronology(source: Dictionary, variants: Array[Dictionary]) -> Dictionary:
	var result := {"first_witnessed": [], "legacy_unordered": []}
	var selected := {}
	for record: Dictionary in variants: selected[record.signature_id] = true
	var chronology: Dictionary = source.get("chronology", {})
	for partition: String in result:
		for identity: String in chronology.get(partition, []):
			if selected.has(identity): result[partition].append(identity)
	return result

func _is_date_record(entry: Dictionary) -> bool:
	var parts := str(entry.entry_id).split(".")
	return parts.size() == 5 and parts[0] == "dating" and entry.ending_id == null \
		and entry.role in ["solo_pre_challenge", "solo_post_challenge", "pair_pre_challenge_scene", "pair_post_challenge_scene"]

func _entry_available(entry: Dictionary) -> bool:
	# Reached dates use native cards; only DTL playback requires a physical master.
	if _is_date_record(entry): return true
	var resolved: Dictionary = _entry_catalog.get_entry(str(entry.entry_id), "en")
	if not resolved.get("ok", false): return false
	var path := str(resolved.value.path)
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)

func begin(signature_id: String) -> Dictionary:
	if _bridge == null or not _active_signature.is_empty(): return _fail(&"gallery_replay_busy")
	_active_signature = signature_id
	_active_token = ""
	_starting = true
	_early.clear()
	var started: Dictionary = _bridge.replay_reached_signature(signature_id)
	_starting = false
	if not started.get("ok", false):
		_active_signature = ""
		_early.clear()
		return started
	_active_token = str(started.get("receipt", {}).get("playback_token", ""))
	for result: Dictionary in _early: _on_finished(result)
	_early.clear()
	return started

func close() -> Dictionary:
	if _active_signature.is_empty(): return {"ok":true}
	var cancelled: Dictionary = _bridge.cancel_reached_replay(_active_signature)
	if cancelled.get("ok", false):
		_active_signature = ""
		_active_token = ""
	return cancelled

func is_playing() -> bool:
	return not _active_signature.is_empty()

func _on_finished(result: Dictionary) -> void:
	if _starting:
		_early.append(result.duplicate(true))
		return
	if str(result.get("signature_id", "")) != _active_signature \
			or str(result.get("playback_token", "")) != _active_token: return
	_active_signature = ""
	_active_token = ""
	playback_finished.emit(result.duplicate(true))

static func _fail(code: StringName) -> Dictionary:
	return {"ok":false, "code":code, "value":null}
