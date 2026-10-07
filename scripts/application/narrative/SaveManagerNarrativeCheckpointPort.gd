class_name SaveManagerNarrativeCheckpointPort
extends RefCounted
## The single narrative-checkpoint adapter shared by DialogicBridge and GameState (dwm-p2r.8,
## Plan-05 Task 2). It wraps exactly one real Plan-03 SaveManagerCheckpointPort plus six provider
## Callables. Neither DialogicBridge nor GameState touches SaveManager, the journal, a /root
## singleton, or a second checkpoint port directly.
##
## commit_current_boundary() is the atomic owner for stable boundaries that do not change gameplay
## state; prepare_candidate/commit/rollback are the low-level seam used only while GameState owns an
## effect/variable transaction (Task 3).

const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const READING_NEXT := preload("res://scripts/narrative/ReadingTraversalOperation.gd")

const REAL_PORT_METHODS := ["preview_checkpoint_id", "capture", "prepare", "commit", "rollback"]
const PROVIDER_KEYS := ["active_app_id", "audio_context", "content_version", "narrative_checkpoint", "route_id", "snapshot_input"]
const PROVIDER_ARITY := {
	"snapshot_input": 0, "route_id": 0, "active_app_id": 0, "audio_context": 0, "content_version": 0,
	"narrative_checkpoint": 3,
}
const HIGH_LEVEL_KINDS := ["timeline_start", "line", "choice", "safe_marker", "scene_transition", "timeline_complete"]
const STAGE_DISK_WRITE := {"kind": &"none", "reason": &"stage"}
const LOW_LEVEL_OWNER := &"game_state_narrative_transaction"

var _configured := false
var _real_port: Object = null
var _providers: Dictionary = {}
var _provider_identity: Dictionary = {}
var _committed: Dictionary = {}
var _active_owner: StringName = &""
var _active_candidate: Dictionary = {}
var _next_commit_in_progress := false
var _next_source: Dictionary = {}


func configure(checkpoint_port: Object, providers: Dictionary) -> Dictionary:
	if checkpoint_port == null:
		return _fail(&"invalid_checkpoint_port", "checkpoint port is null")
	for method in REAL_PORT_METHODS:
		if not checkpoint_port.has_method(method):
			return _fail(&"invalid_checkpoint_port", "missing method " + method)
	if typeof(providers) != TYPE_DICTIONARY or not _exact_keys(providers, PROVIDER_KEYS):
		return _fail(&"invalid_providers", "providers must have exactly " + str(PROVIDER_KEYS))
	var identity := {}
	for key in PROVIDER_KEYS:
		var raw: Variant = providers[key]
		if typeof(raw) != TYPE_CALLABLE:
			return _fail(&"invalid_provider", key + " must be a Callable")
		var callable := raw as Callable
		if not callable.is_valid() or callable.get_object_id() == 0:
			return _fail(&"invalid_provider", key + " has no stable object identity")
		if callable.get_argument_count() != int(PROVIDER_ARITY[key]):
			return _fail(&"invalid_provider", key + " has the wrong arity")
		identity[key] = [callable.get_object_id(), String(callable.get_method())]
	if _configured:
		if _real_port.get_instance_id() == checkpoint_port.get_instance_id() and identity == _provider_identity:
			return _configured_result(true)
		return _fail(&"narrative_checkpoint_port_already_configured", "")
	_real_port = checkpoint_port
	_providers = providers.duplicate()
	_provider_identity = identity
	_configured = true
	return _configured_result(false)


func commit_current_boundary(request: Dictionary) -> Dictionary:
	if not _configured:
		return _fail(&"not_configured", "configure first")
	if _next_commit_in_progress:
		return _fail(&"transaction_in_progress", "reading Next owns checkpoint publication")
	if typeof(request) != TYPE_DICTIONARY or not _exact_keys(request, ["boundary_id", "checkpoint_kind", "narrative_checkpoint"]):
		return _fail(&"invalid_request", "request keys must be exactly boundary_id, checkpoint_kind, narrative_checkpoint")
	var boundary_id := str(request["boundary_id"])
	var kind := String(request["checkpoint_kind"])
	if kind not in HIGH_LEVEL_KINDS:
		return _fail(&"invalid_checkpoint_kind", kind)
	var checkpoint: Variant = request["narrative_checkpoint"]
	if typeof(checkpoint) != TYPE_DICTIONARY:
		return _fail(&"invalid_narrative_checkpoint", "must be a dictionary")
	var derived := _derive_boundary_id(kind, checkpoint)
	if not derived.get("ok", false):
		return derived
	if str(derived["value"]) != boundary_id:
		return _fail(&"boundary_id_mismatch", "%s != %s" % [boundary_id, str(derived["value"])])
	var fingerprint := _fingerprint({"boundary_id": boundary_id, "checkpoint_kind": kind, "narrative_checkpoint": checkpoint})
	if fingerprint.is_empty():
		return _fail(&"fingerprint_failed", "")
	if _committed.has(boundary_id):
		var stored: Dictionary = _committed[boundary_id]
		if str(stored["fingerprint"]) == fingerprint:
			return {"ok": true, "code": &"ok",
				"value": {"checkpoint_id": str(stored["checkpoint_id"]), "duplicate": true},
				"receipt": (stored["receipt"] as Dictionary).duplicate(true)}
		return _fail(&"duplicate_transaction_conflict", boundary_id)
	var snapshot := _call_provider("snapshot_input", [])
	if not snapshot.get("ok", false):
		return snapshot
	var route := _call_provider("route_id", [])
	if not route.get("ok", false):
		return route
	var active := _call_provider("active_app_id", [])
	if not active.get("ok", false):
		return active
	var audio := _call_provider("audio_context", [])
	if not audio.get("ok", false):
		return audio
	var content := _call_provider("content_version", [])
	if not content.get("ok", false):
		return content
	var inputs := _checkpoint_inputs(active["value"], audio["value"], content["value"], checkpoint, route["value"], snapshot["value"])
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false):
		return captured
	var prepared: Dictionary = _real_port.prepare(inputs, StringName(kind), STAGE_DISK_WRITE.duplicate(true))
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = _real_port.commit((prepared["value"] as Dictionary)["candidate"])
	if not committed.get("ok", false):
		var rolled: Dictionary = _real_port.rollback((captured["value"] as Dictionary)["backup"])
		if not rolled.get("ok", false):
			return rolled
		return committed
	var checkpoint_id := str((committed["value"] as Dictionary)["checkpoint_id"])
	var receipt := {"boundary_id": boundary_id, "checkpoint_id": checkpoint_id, "checkpoint_kind": StringName(kind), "narrative_fingerprint": fingerprint}
	_committed[boundary_id] = {"fingerprint": fingerprint, "checkpoint_id": checkpoint_id, "receipt": receipt.duplicate(true)}
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": checkpoint_id, "duplicate": false}, "receipt": receipt}


## Unlike ordinary memory-only narrative boundaries, each admitted Next source
## and destination is an automatic autosave. The caller owns exclusive narrative
## custody and the authored plan; this adapter owns disk/journal commitment.
## A cold source restores the pre-command state, never a queued traversal.
func commit_reading_next(checkpoint: Dictionary, operation_id: String, phase: String) -> Dictionary:
	if not _configured: return _fail(&"not_configured", "configure first")
	if _next_commit_in_progress or _active_owner != &"":
		return _fail(&"transaction_in_progress", "another checkpoint command owns publication")
	if not checkpoint.get("reading_session") is Dictionary or not checkpoint.get("entry_id") is String:
		return _fail(&"reading_next_operation_invalid", "an exact semantic reading checkpoint is required")
	var checked := READING_NEXT.validate(checkpoint.reading_session, checkpoint.entry_id)
	if not checked.ok: return checked
	if checked.value.operation_id != operation_id or checked.value.phase != phase:
		return _fail(&"reading_next_operation_mismatch", "the request differs from its frozen operation")
	# Coalescing belongs to the bridge's one live command lease. Never cache a
	# successful source across later Autosaves or Load: every new activation must
	# prove this source durable again, even when its semantic plan bytes repeat.
	if phase == "source": _next_source = {}
	if phase == "destination" and _next_source.get("operation_id") != operation_id:
		return _fail(&"reading_next_source_not_committed", "the exact source must be durable first")
	_next_commit_in_progress = true
	var result := _commit_reading_next_autosave(checkpoint, operation_id, phase)
	_next_commit_in_progress = false
	if result.get("ok", false):
		_next_source = {"operation_id": operation_id, "checkpoint": checkpoint.duplicate(true),
			"checkpoint_id": result.value.checkpoint_id} if phase == "source" else {}
	return result

func _commit_reading_next_autosave(checkpoint: Dictionary, operation_id: String, phase: String) -> Dictionary:
	var snapshot := _call_provider("snapshot_input", [])
	if not snapshot.ok: return snapshot
	var route := _call_provider("route_id", [])
	if not route.ok: return route
	if route.value != "dating": return _fail(&"reading_next_route_mismatch", "only the admitted Solo owner is supported")
	var active := _call_provider("active_app_id", [])
	if not active.ok: return active
	var audio := _call_provider("audio_context", [])
	if not audio.ok: return audio
	var content := _call_provider("content_version", [])
	if not content.ok: return content
	var inputs := _checkpoint_inputs(active.value, audio.value, content.value, checkpoint, route.value, snapshot.value)
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false): return captured
	if phase == "destination":
		var current: Dictionary = captured.value.backup.get("current", {}).get("snapshot", {})
		var header := checkpoint.duplicate(true)
		header.erase("reading_session")
		var source_header: Dictionary = _next_source.checkpoint.duplicate(true)
		source_header.erase("reading_session")
		if current.get("checkpoint_id") != _next_source.checkpoint_id \
				or current.get("narrative_checkpoint") != _next_source.checkpoint or header != source_header:
			_next_source = {}
			return _fail(&"reading_next_source_changed", "the durable source no longer owns the current journal")
	var prepared: Dictionary = _real_port.prepare(inputs, &"safe_marker",
		{"kind": &"autosave", "reason": &"automatic"})
	if not prepared.get("ok", false): return prepared
	var candidate: Dictionary = prepared.value.candidate
	if not candidate.get("storage_backup") is Dictionary:
		return _fail(&"reading_next_storage_backup_missing", "the real autosave preimage is required")
	var committed: Dictionary = _real_port.commit(candidate)
	if not committed.get("ok", false):
		# capture() contains the journal alone. A failed write may already have
		# replaced disk, so rollback must also restore the exact prepared preimage.
		var rolled: Dictionary = _real_port.rollback({"journal_backup": captured.value.backup,
			"storage_backup": candidate.storage_backup})
		if not rolled.get("ok", false): return rolled
		return committed
	var checkpoint_id := str(committed.value.checkpoint_id)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": checkpoint_id, "duplicate": false},
		"receipt": {"operation_id": operation_id, "phase": phase, "checkpoint_id": checkpoint_id,
			"narrative_fingerprint": _fingerprint(checkpoint)}}


## The caller owns receipt admission and live adoption. This seam commits its detached
## complete snapshot through the existing journal/autosave transaction, without a cache.
func commit_scene_event(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	if not _configured: return _fail(&"not_configured", "configure first")
	if _next_commit_in_progress or _active_owner != &"":
		return _fail(&"transaction_in_progress", "another checkpoint command owns publication")
	if not checkpoint.get("reading_session") is Dictionary \
			or checkpoint.reading_session.get("boundary") != "line":
		return _fail(&"scene_event_checkpoint_invalid", "a reading line checkpoint is required")
	_next_commit_in_progress = true
	var result := _commit_scene_event_autosave(snapshot_input.duplicate(true), checkpoint.duplicate(true))
	_next_commit_in_progress = false
	return result


func _commit_scene_event_autosave(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	var route := _call_provider("route_id", [])
	if not route.ok: return route
	if route.value != "dating": return _fail(&"scene_event_route_mismatch", "only the admitted Solo owner is supported")
	var active := _call_provider("active_app_id", [])
	if not active.ok: return active
	if active.value != null: return _fail(&"scene_event_active_app_mismatch", "the reading owner requires no active app")
	var audio := _call_provider("audio_context", [])
	if not audio.ok: return audio
	var content := _call_provider("content_version", [])
	if not content.ok: return content
	var inputs := _checkpoint_inputs(active.value, audio.value, content.value, checkpoint, route.value, snapshot_input)
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false): return captured
	var prepared: Dictionary = _real_port.prepare(inputs, &"safe_marker",
		{"kind": &"autosave", "reason": &"automatic"})
	if not prepared.get("ok", false): return prepared
	var candidate: Dictionary = prepared.value.candidate
	if not candidate.get("storage_backup") is Dictionary:
		return _fail(&"scene_event_storage_backup_missing", "the real autosave preimage is required")
	var committed: Dictionary = _real_port.commit(candidate)
	var value: Variant = committed.get("value")
	var confirmed := committed.get("ok", false) == true and value is Dictionary \
		and typeof(value.get("checkpoint_id")) == TYPE_STRING and not str(value.get("checkpoint_id", "")).is_empty() \
		and value.get("checkpoint_id") == candidate.get("checkpoint_id")
	if committed.get("ok", false) and not confirmed:
		return {"ok": false, "code": &"event_commit_ack_invalid", "committed": true}
	if not committed.get("ok", false):
		var rolled: Dictionary = _real_port.rollback({"journal_backup": captured.value.backup,
			"storage_backup": candidate.storage_backup})
		if not rolled.get("ok", false): return rolled
		var failure := committed.duplicate(true)
		failure["rolled_back"] = true
		return failure
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": value.checkpoint_id, "committed": true}}


func preview_checkpoint_id(run_id: String) -> Dictionary:
	if not _configured:
		return _fail(&"not_configured", "")
	var previewed: Dictionary = _real_port.preview_checkpoint_id(run_id)
	if not previewed.get("ok", false):
		return previewed
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": str((previewed["value"] as Dictionary)["checkpoint_id"])}, "receipt": {}}


func capture() -> Dictionary:
	if not _configured:
		return _fail(&"not_configured", "")
	return _real_port.capture()


func prepare_candidate(owner_id: StringName, snapshot_input: Dictionary, transaction_id: String, source_id: String, checkpoint_kind: StringName, expected_checkpoint_id: String) -> Dictionary:
	if not _configured:
		return _fail(&"not_configured", "")
	if _next_commit_in_progress:
		return _fail(&"transaction_in_progress", "reading Next owns checkpoint publication")
	if owner_id != LOW_LEVEL_OWNER:
		return _fail(&"invalid_owner", str(owner_id))
	if _active_owner != &"":
		return _fail(&"transaction_in_progress", str(_active_owner))
	if typeof(snapshot_input) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot_input", "snapshot_input must be a dictionary")
	var narrative := _call_narrative(transaction_id, source_id, checkpoint_kind)
	if not narrative.get("ok", false):
		return narrative
	var checkpoint: Dictionary = (narrative["value"] as Dictionary)["narrative_checkpoint"]
	var route := _call_provider("route_id", [])
	if not route.get("ok", false):
		return route
	var active := _call_provider("active_app_id", [])
	if not active.get("ok", false):
		return active
	var audio := _call_provider("audio_context", [])
	if not audio.get("ok", false):
		return audio
	var content := _call_provider("content_version", [])
	if not content.get("ok", false):
		return content
	var inputs := _checkpoint_inputs(active["value"], audio["value"], content["value"], checkpoint, route["value"], snapshot_input.duplicate(true))
	var prepared: Dictionary = _real_port.prepare(inputs, checkpoint_kind, STAGE_DISK_WRITE.duplicate(true))
	if not prepared.get("ok", false):
		return prepared
	var checkpoint_id := str((prepared["value"] as Dictionary)["checkpoint_id"])
	if checkpoint_id != expected_checkpoint_id:
		return _fail(&"checkpoint_id_mismatch", "%s != %s" % [checkpoint_id, expected_checkpoint_id])
	var candidate: Variant = (prepared["value"] as Dictionary)["candidate"]
	_active_owner = owner_id
	_active_candidate = {"checkpoint_id": checkpoint_id, "hash": _fingerprint(candidate)}
	return {"ok": true, "code": &"ok", "value": {"candidate": _copy(candidate), "checkpoint_id": checkpoint_id}, "receipt": {}}


func commit(owner_id: StringName, candidate: Dictionary) -> Dictionary:
	if _active_owner == &"" or owner_id != _active_owner:
		return _fail(&"invalid_owner", str(owner_id))
	if _fingerprint(candidate) != str(_active_candidate.get("hash", "")):
		return _fail(&"candidate_altered", "candidate bytes changed since prepare")
	var committed: Dictionary = _real_port.commit(candidate)
	if not committed.get("ok", false):
		return committed
	_active_owner = &""
	_active_candidate = {}
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": str((committed["value"] as Dictionary)["checkpoint_id"])}}


func rollback(owner_id: StringName, backup: Dictionary) -> Dictionary:
	if _active_owner == &"" or owner_id != _active_owner:
		return _fail(&"invalid_owner", str(owner_id))
	var rolled: Dictionary = _real_port.rollback(backup)
	if not rolled.get("ok", false):
		return rolled
	_active_owner = &""
	_active_candidate = {}
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func _checkpoint_inputs(active_app_id: Variant, audio_context: Variant, content_version: Variant, dialogic_checkpoint: Dictionary, route_id: Variant, snapshot_input: Dictionary) -> Dictionary:
	return {
		"active_app_id": active_app_id,
		"audio_context": _copy(audio_context),
		"content_version": content_version,
		"dialogic_checkpoint": dialogic_checkpoint.duplicate(true),
		"route_id": route_id,
		"snapshot_input": snapshot_input.duplicate(true),
	}


func _derive_boundary_id(kind: String, checkpoint: Dictionary) -> Dictionary:
	var timeline_id := str(checkpoint.get("timeline_id", ""))
	match kind:
		"timeline_start":
			return {"ok": true, "value": "timeline:%s:start" % timeline_id}
		"timeline_complete":
			return {"ok": true, "value": "timeline:%s:complete" % timeline_id}
		"line", "choice", "safe_marker":
			var event: Variant = checkpoint.get("event")
			if typeof(event) != TYPE_DICTIONARY or typeof((event as Dictionary).get("event_id")) != TYPE_STRING or str((event as Dictionary)["event_id"]).is_empty():
				return _fail(&"invalid_narrative_checkpoint", kind + " requires event.event_id")
			return {"ok": true, "value": str((event as Dictionary)["event_id"])}
		"scene_transition":
			var boundary: Variant = checkpoint.get("boundary")
			if typeof(boundary) != TYPE_DICTIONARY or String((boundary as Dictionary).get("transaction_id", "")).is_empty():
				return _fail(&"invalid_narrative_checkpoint", "scene_transition requires boundary.transaction_id")
			return {"ok": true, "value": String((boundary as Dictionary)["transaction_id"])}
	return _fail(&"invalid_checkpoint_kind", kind)


func _call_provider(key: String, args: Array) -> Dictionary:
	var callable: Callable = _providers[key]
	var raw: Variant = callable.callv(args)
	match key:
		"snapshot_input", "audio_context":
			if typeof(raw) != TYPE_DICTIONARY:
				return _fail(&"invalid_provider_result", key + " must return a dictionary")
			return {"ok": true, "value": (raw as Dictionary).duplicate(true)}
		"route_id":
			if (typeof(raw) != TYPE_STRING and typeof(raw) != TYPE_STRING_NAME) or String(raw).is_empty():
				return _fail(&"invalid_provider_result", "route_id must be a nonempty string")
			return {"ok": true, "value": String(raw)}
		"active_app_id":
			if raw != null and (typeof(raw) != TYPE_STRING or String(raw).is_empty()):
				return _fail(&"invalid_provider_result", "active_app_id must be null or a nonempty string")
			return {"ok": true, "value": raw}
		"content_version":
			if typeof(raw) != TYPE_INT or int(raw) <= 0:
				return _fail(&"invalid_provider_result", "content_version must be a positive integer")
			return {"ok": true, "value": int(raw)}
	return _fail(&"invalid_provider", key)


func _call_narrative(transaction_id: String, source_id: String, checkpoint_kind: StringName) -> Dictionary:
	var callable: Callable = _providers["narrative_checkpoint"]
	var raw: Variant = callable.call(transaction_id, source_id, checkpoint_kind)
	if typeof(raw) != TYPE_DICTIONARY or not (raw as Dictionary).get("ok", false):
		return _fail(&"narrative_provider_failed", "no validated transaction checkpoint")
	var value: Variant = (raw as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY or typeof((value as Dictionary).get("narrative_checkpoint")) != TYPE_DICTIONARY:
		return _fail(&"narrative_provider_failed", "provider returned no narrative_checkpoint")
	return {"ok": true, "value": {"narrative_checkpoint": ((value as Dictionary)["narrative_checkpoint"] as Dictionary).duplicate(true)}}


func _fingerprint(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


func _configured_result(already: bool) -> Dictionary:
	return {"ok": true, "code": &"ok",
		"value": {"port_instance_id": get_instance_id(), "checkpoint_port_instance_id": _real_port.get_instance_id(), "already_configured": already},
		"receipt": {}}


func _exact_keys(target: Dictionary, keys: Array) -> bool:
	if target.size() != keys.size():
		return false
	for key in keys:
		if not target.has(key):
			return false
	return true


func _copy(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
