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
	if _next_commit_in_progress or _scene_callback_busy:
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
	if _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy:
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
	if _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy:
		return _fail(&"transaction_in_progress", "another checkpoint command owns publication")
	if not checkpoint.get("reading_session") is Dictionary:
		return _fail(&"scene_event_checkpoint_invalid", "a reading checkpoint is required")
	if checkpoint.reading_session.get("schema_version") == 4:
		var marker := _validate_marker_commit(snapshot_input, checkpoint)
		if not marker.ok: return marker
	elif checkpoint.reading_session.get("boundary") != "line":
		return _fail(&"scene_event_checkpoint_invalid", "a reading line checkpoint is required")
	var scene_entry := not _scene_entry.is_empty()
	if scene_entry:
		if _scene_entry.state != "prepared" \
				or _fingerprint(checkpoint) != _scene_entry.narrative_checkpoint_sha256 \
				or not _scene_validate(_scene_entry, "commit"):
			return _fail(&"scene_entry_custody_invalid", "no retained Bridge candidate")
	_next_commit_in_progress = true
	var result := _commit_scene_event_autosave(snapshot_input.duplicate(true), checkpoint.duplicate(true))
	if scene_entry:
		if result.get("ok", false):
			var reference: Variant = result.get("value", {}).get("checkpoint_reference")
			if not _scene_reference_valid(reference):
				_scene_entry.state = "uncertain"
				result = {"ok": false, "code": &"scene_entry_commit_uncertain", "committed": true}
			else:
				_scene_entry.state = "committed"
				_scene_entry.ack = {"capability_id": _scene_entry.capability_id, "operation_id": _scene_entry.binding.operation_id,
					"source_checkpoint": _scene_entry.binding.source_checkpoint.duplicate(true), "target_checkpoint": reference.duplicate(true),
					"binding_sha256": _scene_entry.binding_sha256, "narrative_checkpoint_sha256": _scene_entry.narrative_checkpoint_sha256}
		elif result.get("committed", false) or str(result.get("code", "")) == "APPLICATION_FATAL":
			_scene_entry.state = "uncertain"
	_next_commit_in_progress = false
	return result


func _commit_scene_event_autosave(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	var route := _call_provider("route_id", [])
	if not route.ok: return route
	if route.value != "dating": return _fail(&"scene_event_route_mismatch", "only the admitted Solo owner is supported")
	var active := _call_provider("active_app_id", [])
	if not active.ok: return active
	# Desktop host state can retain its last app while the dating route owns
	# physical presentation. Preserve it; the bridge admits the actual Solo host.
	var audio := _call_provider("audio_context", [])
	if not audio.ok: return audio
	var content := _call_provider("content_version", [])
	if not content.ok: return content
	var inputs := _checkpoint_inputs(active.value, audio.value, content.value, checkpoint, route.value, snapshot_input)
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false): return captured
	if not _scene_entry.is_empty():
		var source: Dictionary = _scene_bundle_snapshot(captured.get("value", {}).get("backup", {}).get("current"))
		if _fingerprint(_scene_snapshot_reference(source)) != _fingerprint(_scene_entry.binding.source_checkpoint):
			return _fail(&"scene_entry_source_changed", "journal source differs from retained binding")

	var prepared: Dictionary = _real_port.prepare(inputs, &"safe_marker",
		{"kind": &"autosave", "reason": &"automatic"})
	if not prepared.get("ok", false): return prepared
	var candidate: Dictionary = prepared.value.candidate
	if not candidate.get("storage_backup") is Dictionary:
		return _fail(&"scene_event_storage_backup_missing", "the real autosave preimage is required")
	var candidate_hash := _fingerprint(candidate) if not _scene_entry.is_empty() else ""
	if not _scene_entry.is_empty() and _scene_candidate_reference(candidate, checkpoint).is_empty():
		return _fail(&"scene_entry_candidate_invalid", "real prepared snapshot differs from retained target")

	if not _scene_entry.is_empty():
		# Providers/prepare may invoke synchronous owners. Recheck custody and the
		# actual source after those callbacks, immediately before the one commit.
		if not _scene_validate(_scene_entry, "commit"):
			return _fail(&"scene_entry_custody_invalid", "Bridge custody changed during preparation")
		var source_check: Dictionary = _real_port.capture()
		var current_source := _scene_bundle_snapshot(source_check.get("value", {}).get("backup", {}).get("current"))
		if not source_check.get("ok", false) or _fingerprint(_scene_snapshot_reference(current_source)) != _fingerprint(_scene_entry.binding.source_checkpoint):
			return _fail(&"scene_entry_source_changed", "journal changed during preparation")
	var committed: Dictionary = _real_port.commit(candidate)
	if not _scene_entry.is_empty() and _fingerprint(candidate) != candidate_hash:
		return {"ok": false, "code": &"scene_entry_commit_uncertain", "committed": true}

	var value: Variant = committed.get("value")
	var confirmed: bool = committed.get("ok", false) == true and value is Dictionary \
		and typeof(value.get("checkpoint_id")) == TYPE_STRING and not str(value.get("checkpoint_id", "")).is_empty() \
		and value.get("checkpoint_id") == candidate.get("checkpoint_id")
	if committed.get("ok", false) and not confirmed:
		return {"ok": false, "code": &"event_commit_ack_invalid", "committed": true}
	if not committed.get("ok", false):
		var rolled: Dictionary = _real_port.rollback({"journal_backup": captured.value.backup,
			"storage_backup": candidate.storage_backup})
		if not rolled.get("ok", false):
			if _scene_entry.is_empty(): return rolled
			var uncertain := rolled.duplicate(true)
			uncertain["committed"] = true
			return uncertain
		var failure := committed.duplicate(true)
		failure["rolled_back"] = true
		return failure
	var result := {"ok": true, "code": &"ok", "value": {"checkpoint_id": value.checkpoint_id, "committed": true}}
	# Real commit already proved exact autosave reread and journal installation. Derive
	# metadata from that prepared/retained snapshot, never from caller supplied hashes.
	if checkpoint.get("stage") == "scene" and candidate.get("autosave_document") is Dictionary:
		var reference := _scene_committed_reference(candidate, checkpoint)
		if not reference.is_empty(): result.value["checkpoint_reference"] = reference
	return result


# Scene acknowledgements are in-process capabilities, not saved proof. The configured
# Bridge validator authenticates its private candidate and exclusive invocation custody.
# This does not replace full Run/Save validation in the real checkpoint owner.
var _scene_authority: Object
var _scene_validator: Callable
var _scene_entry: Dictionary = {}
var _scene_used: Dictionary = {}
var _scene_callback_busy := false

func configure_scene_entry_authority(authority: Object, validator: Callable) -> Dictionary:
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or authority == null or not validator.is_valid() \
			or validator.get_object() != authority or validator.get_argument_count() != 4:
		return _fail(&"scene_entry_authority_invalid", "configure the Bridge once while idle")
	if _scene_authority != null:
		if _scene_authority == authority and _scene_validator == validator: return {"ok": true}
		return _fail(&"scene_entry_authority_invalid", "authority replacement refused")
	_scene_authority = authority
	_scene_validator = validator
	return {"ok": true}

func retain_scene_entry(authority: Object, capability_id: String, binding: Dictionary, checkpoint: Dictionary) -> Dictionary:
	if _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or authority != _scene_authority or not is_instance_valid(authority) \
			or not _scene_entry.is_empty() or _scene_used.has(capability_id) or capability_id.strip_edges().is_empty():
		return _fail(&"scene_entry_custody_invalid", "")
	if not _exact_keys(binding, ["operation_id", "source_checkpoint", "source_occurrence_id", "trigger_command_id",
			"target_id", "target_occurrence_id", "admission_receipt_id", "registration_sha256"]) \
			or not _scene_reference_valid(binding.get("source_checkpoint")):
		return _fail(&"scene_entry_binding_invalid", "")
	for field: String in ["operation_id", "target_id", "target_occurrence_id", "admission_receipt_id"]:
		if not binding[field] is String or binding[field].strip_edges().is_empty():
			return _fail(&"scene_entry_binding_invalid", field)
	if not _scene_hash(binding.registration_sha256): return _fail(&"scene_entry_binding_invalid", "registration")
	for field: String in ["source_occurrence_id", "trigger_command_id"]:
		if binding[field] != null and (not binding[field] is String or binding[field].strip_edges().is_empty()):
			return _fail(&"scene_entry_binding_invalid", field)
	if (binding.source_occurrence_id == null) != (binding.trigger_command_id == null):
		return _fail(&"scene_entry_binding_invalid", "initial admission pair")
	var frame: Variant = checkpoint.get("frozen_context")
	if not frame is Dictionary or not frame.get("presentation") is Dictionary \
			or not frame.presentation.get("fields") is Dictionary:
		return _fail(&"scene_entry_binding_invalid", "target frame shape")
	var binding_hash := _fingerprint(binding)
	var checkpoint_hash := _fingerprint(checkpoint)
	if binding_hash.is_empty() or checkpoint_hash.is_empty() or checkpoint.get("stage") != "scene" \
			or checkpoint.get("manifest_fingerprint") != binding.registration_sha256 \
			or frame.get("playback_id") != binding.target_occurrence_id \
			or frame.presentation.fields.get("admission_receipt_id") != binding.admission_receipt_id:
		return _fail(&"scene_entry_binding_invalid", "target checkpoint differs")
	var entry := {"capability_id": capability_id, "binding": binding.duplicate(true),
		"checkpoint": checkpoint.duplicate(true), "binding_sha256": binding_hash,
		"narrative_checkpoint_sha256": checkpoint_hash, "state": "prepared"}
	if not _scene_validate(entry, "retain"): return _fail(&"scene_entry_custody_invalid", "Bridge refused retention")
	_scene_entry = entry
	return {"ok": true}

func consume_scene_entry_ack(capability_id: String) -> Dictionary:
	if _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy:
		return _fail(&"scene_entry_busy", "")
	if _scene_entry.is_empty() or _scene_entry.capability_id != capability_id or _scene_used.has(capability_id):
		return _fail(&"scene_entry_ack_unavailable", "")
	if not _scene_validate(_scene_entry, "consume"): return _fail(&"scene_entry_custody_invalid", "Bridge refused consumption")
	if _scene_entry.state != "committed":
		return {"ok": false, "code": &"scene_entry_ack_unavailable", "committed": _scene_entry.state != "prepared"}
	# A later journal replacement cannot transfer this capability to another target.
	_scene_callback_busy = true
	var captured: Dictionary = _real_port.capture()
	_scene_callback_busy = false
	var current: Dictionary = _scene_bundle_snapshot(captured.get("value", {}).get("backup", {}).get("current"))
	if not captured.get("ok", false) or _fingerprint(_scene_snapshot_reference(current)) != _fingerprint(_scene_entry.ack.target_checkpoint):
		_scene_entry.state = "uncertain"
		return {"ok": false, "code": &"scene_entry_commit_uncertain", "committed": true}
	var result: Dictionary = _scene_entry.ack.duplicate(true)
	_scene_used[capability_id] = true
	_scene_entry = {}
	return {"ok": true, "value": result}

func _scene_validate(entry: Dictionary, phase: String) -> bool:
	if _scene_callback_busy or not is_instance_valid(_scene_authority) or not _scene_validator.is_valid(): return false
	_scene_callback_busy = true
	var result: Variant = _scene_validator.call(entry.capability_id, entry.binding.duplicate(true), entry.checkpoint.duplicate(true), phase)
	_scene_callback_busy = false
	return result is Dictionary and result.get("ok", false) == true

func _scene_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

func _scene_reference_valid(value: Variant) -> bool:
	return value is Dictionary and _exact_keys(value, ["checkpoint_id", "checkpoint_sequence", "snapshot_sha256"]) \
		and value.checkpoint_id is String and not value.checkpoint_id.is_empty() \
		and typeof(value.checkpoint_sequence) == TYPE_INT and value.checkpoint_sequence >= 0 and _scene_hash(value.snapshot_sha256)

func _scene_bundle_snapshot(bundle: Variant) -> Dictionary:
	if not bundle is Dictionary or not bundle.get("snapshot") is Dictionary: return {}
	return bundle.snapshot

func _scene_snapshot_reference(snapshot: Dictionary) -> Dictionary:
	var reference := {"checkpoint_id": snapshot.get("checkpoint_id"), "checkpoint_sequence": snapshot.get("checkpoint_sequence"),
		"snapshot_sha256": _fingerprint(snapshot)}
	return reference if _scene_reference_valid(reference) else {}

func _scene_candidate_reference(candidate: Dictionary, checkpoint: Dictionary) -> Dictionary:
	if not candidate.get("journal_candidate") is Dictionary or not candidate.get("autosave_document") is Dictionary: return {}
	var snapshot: Dictionary = _scene_bundle_snapshot(candidate.get("journal_candidate", {}).get("current"))
	var reference := _scene_snapshot_reference(snapshot)
	if reference.is_empty() or reference.checkpoint_id != candidate.get("checkpoint_id") \
			or _fingerprint(snapshot.get("narrative_checkpoint")) != _fingerprint(checkpoint) \
			or _fingerprint(_scene_bundle_snapshot(candidate.get("autosave_document", {}).get("current_snapshot"))) != reference.snapshot_sha256:
		return {}
	return reference

func _scene_committed_reference(candidate: Dictionary, checkpoint: Dictionary) -> Dictionary:
	var reference := _scene_candidate_reference(candidate, checkpoint)
	if reference.is_empty(): return {}
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false): return {}
	var current: Dictionary = _scene_bundle_snapshot(captured.get("value", {}).get("backup", {}).get("current"))
	return reference if _fingerprint(current) == reference.snapshot_sha256 else {}


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
	if _next_commit_in_progress or _scene_callback_busy:
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


var _marker_authority: Object
var _marker_validator: Callable

func configure_marker_handoff(authority: Object, validator: Callable) -> Dictionary:
	if authority == null or not validator.is_valid() or validator.get_object() != authority \
			or (_marker_authority != null and (_marker_authority != authority or _marker_validator != validator)):
		return _fail(&"event_handoff_authority_invalid", "")
	_marker_authority = authority
	_marker_validator = validator
	return {"ok": true}

func _validate_marker_commit(snapshot: Dictionary, checkpoint: Dictionary) -> Dictionary:
	if not is_instance_valid(_marker_authority) or not _marker_validator.is_valid():
		return _fail(&"event_handoff_authority_invalid", "")
	var operation := READING_NEXT.validate(checkpoint.reading_session, str(checkpoint.get("entry_id", "")))
	if not operation.ok: return operation
	if operation.value.phase != "destination" or operation.value.plan.destination.kind != "notification" \
			or _next_source.get("operation_id") != operation.value.operation_id:
		return _fail(&"reading_next_source_not_committed", "")
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false): return captured
	var current: Dictionary = captured.value.backup.get("current", {}).get("snapshot", {})
	if current.get("checkpoint_id") != _next_source.checkpoint_id \
			or current.get("narrative_checkpoint") != _next_source.checkpoint:
		return _fail(&"reading_next_source_changed", "")
	var before_header: Dictionary = _next_source.checkpoint.duplicate(true)
	var after_header := checkpoint.duplicate(true)
	before_header.erase("reading_session")
	after_header.erase("reading_session")
	if before_header != after_header: return _fail(&"reading_next_source_changed", "")
	return _marker_validator.call(snapshot.duplicate(true), checkpoint.duplicate(true), _next_source.duplicate(true))
