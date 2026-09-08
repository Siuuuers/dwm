extends RefCounted

## Read-only title-host playback. Endings require discovery; other reached scenes require the ending milestone.
signal playback_finished(result: Dictionary)
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
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
		var checked := SIGNATURE.validate(record.signature)
		if not checked.ok or checked.value.signature_id != record.signature_id: continue
		var entry: Dictionary = SIGNATURE.entry_record(record.signature.entry_id).value
		if entry.ending_id != canonical_id or str(record.signature.entry_id).ends_with(".residue"): continue
		variants.append(record.duplicate(true))
	return {"ok":true, "value":{"records":variants}}

## No new Gallery discovery identities: these are exact already-reached callable scenes.
func get_reached_entry_variants(entry_id: String = "") -> Dictionary:
	if _profile == null: return _fail(&"gallery_replay_unavailable")
	if not _profile.has_method("has_completed_ending") or not _profile.has_completed_ending():
		return {"ok": true, "value": {"records": []}}
	var reached: Dictionary = _profile.get_reached_presentations()
	if not reached.get("ok", false): return reached
	var variants: Array[Dictionary] = []
	for record: Dictionary in reached.value.records:
		var checked := SIGNATURE.validate(record.signature)
		if not checked.ok or checked.value.signature_id != record.signature_id: continue
		var entry: Dictionary = SIGNATURE.entry_record(record.signature.entry_id).value
		if entry.ending_id != null or (not entry_id.is_empty() and record.signature.entry_id != entry_id): continue
		variants.append(record.duplicate(true))
	variants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: String = str(a.signature.entry_id) + ":" + str(a.signature_id)
		var right: String = str(b.signature.entry_id) + ":" + str(b.signature_id)
		return left < right)
	return {"ok": true, "value": {"records": variants}}

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
