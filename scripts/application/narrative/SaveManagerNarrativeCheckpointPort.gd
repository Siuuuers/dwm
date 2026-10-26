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
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

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
	if not _scene_challenge.is_empty(): return _fail(&"transaction_in_progress", "Challenge owns checkpoint publication")
	if not _scene_mutation.is_empty() and _scene_mutation.kind in ["shop", "round"]: return _fail(&"transaction_in_progress", "Scene app mutation owns checkpoint publication")
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
	if _next_commit_in_progress or _scene_callback_busy or not _scene_control.is_empty():
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
	if _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy or not _scene_control.is_empty():
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
				or not _player_checkpoint_same(current.get("narrative_checkpoint"), _next_source.checkpoint) or header != source_header:
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
	if _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy or not _scene_control.is_empty():
		return _fail(&"transaction_in_progress", "another checkpoint command owns publication")
	# Public dictionaries must be detached before marker/authority/provider callbacks.
	snapshot_input = snapshot_input.duplicate(true)
	checkpoint = checkpoint.duplicate(true)
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
	var result := _commit_scene_event_autosave(snapshot_input, checkpoint)
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


# Same held-control persistence has a separate live GameState authority. It never
# authorizes a line-to-control transition or changes the native reading position.
var _scene_challenge_authority: Object
var _scene_challenge_validator: Callable
var _scene_challenge: Dictionary = {}

func configure_scene_challenge_authority(authority: Object, validator: Callable) -> Dictionary:
	if not is_instance_valid(authority) or not validator.is_valid() \
			or validator.get_object() != authority or validator.get_argument_count() != 3:
		return _fail(&"scene_challenge_authority_invalid", "valid Run owner required")
	if _scene_challenge_authority != null:
		# Exact replay changes no authority or custody. A failed control write
		# deliberately retains its operation; retry must not require clearing it.
		if _scene_challenge_authority == authority and _scene_challenge_validator == validator: return {"ok": true}
		return _fail(&"scene_challenge_authority_invalid", "authority replacement refused")
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or not _scene_control.is_empty():
		return _fail(&"scene_challenge_authority_invalid", "configure the Run owner while idle")
	_scene_challenge_authority = authority
	_scene_challenge_validator = validator
	return {"ok": true}

func commit_scene_challenge(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or not _scene_control.is_empty() or not _scene_challenge.is_empty() or not _scene_mutation.is_empty():
		return {"ok": false, "code": &"scene_challenge_checkpoint_busy", "committed": false}
	snapshot_input = snapshot_input.duplicate(true)
	checkpoint = checkpoint.duplicate(true)
	if checkpoint.get("stage") != "scene" or not checkpoint.get("reading_session") is Dictionary \
			or typeof(checkpoint.reading_session.get("schema_version")) != TYPE_INT \
			or checkpoint.reading_session.schema_version != 5 or checkpoint.reading_session.get("boundary") not in ["control", "line"]:
		return {"ok": false, "code": &"scene_challenge_checkpoint_invalid", "committed": false}
	_next_commit_in_progress = true
	_scene_challenge = {"input": snapshot_input, "checkpoint": checkpoint,
		"input_hash": _fingerprint(snapshot_input), "checkpoint_hash": _fingerprint(checkpoint)}
	var result: Dictionary
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false) or not captured.get("value", {}).get("backup") is Dictionary:
		result = _fail(&"scene_challenge_source_unavailable", "real journal capture required")
	elif not _scene_reference_valid(_scene_snapshot_reference(_scene_bundle_snapshot(captured.value.backup.get("current")))):
		result = _fail(&"scene_challenge_source_unavailable", "stable journal source required")
	else:
		_scene_challenge["source_hash"] = _fingerprint(captured.value.backup)
		if _scene_challenge.source_hash.is_empty() or not _scene_challenge_validate("before_prepare"):
			result = _fail(&"scene_challenge_custody_invalid", "Run owner refused preparation")
		else:
			result = _commit_scene_event_autosave(snapshot_input, checkpoint)
			if result.get("ok", false) and not _scene_challenge_validate("after_commit"):
				result = {"ok": false, "code": &"scene_challenge_commit_uncertain", "committed": true}
	_scene_challenge = {}
	_next_commit_in_progress = false
	if not result.get("ok", false) and not result.has("committed") and not result.get("rolled_back", false):
		result["committed"] = false
	return result

func _scene_challenge_validate(phase: String) -> bool:
	if _scene_callback_busy or _scene_challenge.is_empty() or not _next_commit_in_progress \
			or not is_instance_valid(_scene_challenge_authority) or not _scene_challenge_validator.is_valid(): return false
	_scene_callback_busy = true
	var checked: Variant = _scene_challenge_validator.call(_scene_challenge.input.duplicate(true),
		_scene_challenge.checkpoint.duplicate(true), phase)
	_scene_callback_busy = false
	return typeof(checked) == TYPE_BOOL and checked == true \
		and not _scene_challenge.input_hash.is_empty() and not _scene_challenge.checkpoint_hash.is_empty() \
		and _fingerprint(_scene_challenge.input) == _scene_challenge.input_hash \
		and _fingerprint(_scene_challenge.checkpoint) == _scene_challenge.checkpoint_hash

func _scene_challenge_source_matches(captured: Dictionary) -> bool:
	return captured.get("ok", false) and captured.get("value", {}).get("backup") is Dictionary \
		and _fingerprint(captured.value.backup) == _scene_challenge.get("source_hash", "")


var _scene_contact_authority: Object
var _scene_contact_validator: Callable
var _scene_shop_authority: Object
var _scene_shop_validator: Callable
var _scene_round_authority: Object
var _scene_round_validator: Callable
# Contacts and Shop share one publication transaction, never two simultaneous owners.
var _scene_mutation: Dictionary = {}

func configure_scene_contact_authority(authority: Object, validator: Callable) -> Dictionary:
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or not _scene_control.is_empty() \
			or not is_instance_valid(authority) or not validator.is_valid() \
			or validator.get_object() != authority or validator.get_argument_count() != 3:
		return _fail(&"scene_contact_authority_invalid", "configure the Run owner while idle")
	if _scene_contact_authority != null:
		if _scene_contact_authority == authority and _scene_contact_validator == validator: return {"ok": true}
		return _fail(&"scene_contact_authority_invalid", "authority replacement refused")
	_scene_contact_authority = authority
	_scene_contact_validator = validator
	return {"ok": true}

func configure_scene_shop_authority(authority: Object, validator: Callable) -> Dictionary:
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or not _scene_control.is_empty() \
			or not is_instance_valid(authority) or not validator.is_valid() \
			or validator.get_object() != authority or validator.get_argument_count() != 3:
		return _fail(&"scene_shop_authority_invalid", "configure the Run owner while idle")
	if _scene_shop_authority != null:
		if _scene_shop_authority == authority and _scene_shop_validator == validator: return {"ok": true}
		return _fail(&"scene_shop_authority_invalid", "authority replacement refused")
	_scene_shop_authority = authority
	_scene_shop_validator = validator
	return {"ok": true}

func configure_scene_round_authority(authority: Object, validator: Callable) -> Dictionary:
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or not _scene_control.is_empty() \
			or not is_instance_valid(authority) or not validator.is_valid() \
			or validator.get_object() != authority or validator.get_argument_count() != 3:
		return _fail(&"scene_round_authority_invalid", "configure the Run owner while idle")
	if _scene_round_authority != null:
		if _scene_round_authority == authority and _scene_round_validator == validator: return {"ok": true}
		return _fail(&"scene_round_authority_invalid", "authority replacement refused")
	_scene_round_authority = authority
	_scene_round_validator = validator
	return {"ok": true}

func commit_scene_contact(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	return _commit_scene_mutation(snapshot_input, checkpoint, "contact", _scene_contact_authority, _scene_contact_validator)

func commit_scene_shop(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	return _commit_scene_mutation(snapshot_input, checkpoint, "shop", _scene_shop_authority, _scene_shop_validator)

func commit_scene_round(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	return _commit_scene_mutation(snapshot_input, checkpoint, "round", _scene_round_authority, _scene_round_validator)

func _commit_scene_mutation(snapshot_input: Dictionary, checkpoint: Dictionary, kind: String,
		authority: Object, validator: Callable) -> Dictionary:
	var prefix := "scene_" + kind
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or not _scene_control.is_empty() or not _scene_mutation.is_empty() or not _scene_challenge.is_empty():
		return {"ok": false, "code": StringName(prefix + "_checkpoint_busy"), "committed": false}

	snapshot_input = snapshot_input.duplicate(true)
	checkpoint = checkpoint.duplicate(true)
	if checkpoint.get("stage") != "scene" or not checkpoint.get("reading_session") is Dictionary \
			or typeof(checkpoint.reading_session.get("schema_version")) != TYPE_INT \
			or checkpoint.reading_session.schema_version != 5 or checkpoint.reading_session.get("boundary") not in ["control", "line"]:
		return {"ok": false, "code": StringName(prefix + "_checkpoint_invalid"), "committed": false}
	_next_commit_in_progress = true
	_scene_mutation = {"input": snapshot_input, "checkpoint": checkpoint,
		"input_hash": _fingerprint(snapshot_input), "checkpoint_hash": _fingerprint(checkpoint), "kind": kind, "authority": authority, "validator": validator}
	var result: Dictionary
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false) or not captured.get("value", {}).get("backup") is Dictionary:
		result = _fail(StringName(prefix + "_source_unavailable"), "real journal capture required")
	elif not _scene_reference_valid(_scene_snapshot_reference(_scene_bundle_snapshot(captured.value.backup.get("current")))):
		result = _fail(StringName(prefix + "_source_unavailable"), "stable journal source required")
	elif kind in ["shop", "round"] and not _player_checkpoint_same(_scene_bundle_snapshot(captured.value.backup.get("current")).get("narrative_checkpoint"), _scene_mutation.checkpoint):
		result = _fail(StringName(prefix + "_source_changed"), "mutation must retain the exact stable reading checkpoint")
	else:
		_scene_mutation["source_hash"] = _fingerprint(captured.value.backup)
		if _scene_mutation.source_hash.is_empty() or not _scene_mutation_validate("before_prepare"):
			result = _fail(StringName(prefix + "_custody_invalid"), "Run owner refused preparation")
		else:
			result = _commit_scene_event_autosave(snapshot_input, checkpoint)
			if result.get("ok", false) and not _scene_mutation_validate("after_commit"):
				result = {"ok": false, "code": StringName(prefix + "_commit_uncertain"), "committed": true}
			if result.get("ok", false) and kind in ["shop", "round"]:
				# A post-write owner callback cannot displace the acknowledged journal.
				var confirmed: Dictionary = _real_port.capture()
				var reference := _scene_snapshot_reference(_scene_bundle_snapshot(confirmed.get("value", {}).get("backup", {}).get("current")))
				if not confirmed.get("ok", false) or reference.is_empty() \
						or reference != result.get("value", {}).get("checkpoint_reference") \
						or _fingerprint(snapshot_input) != _scene_mutation.input_hash \
						or _fingerprint(checkpoint) != _scene_mutation.checkpoint_hash:
					result = {"ok": false, "code": StringName(prefix + "_commit_uncertain"), "committed": true}
	_scene_mutation = {}
	_next_commit_in_progress = false
	if not result.get("ok", false) and not result.has("committed") and not result.get("rolled_back", false):
		result["committed"] = false
	return result

func _scene_mutation_validate(phase: String) -> bool:
	if _scene_callback_busy or _scene_mutation.is_empty() or not _next_commit_in_progress \
			or not is_instance_valid(_scene_mutation.authority) or not _scene_mutation.validator.is_valid(): return false
	_scene_callback_busy = true
	var checked: Variant = _scene_mutation.validator.call(_scene_mutation.input.duplicate(true),
		_scene_mutation.checkpoint.duplicate(true), phase)
	_scene_callback_busy = false
	return typeof(checked) == TYPE_BOOL and checked == true \
		and not _scene_mutation.input_hash.is_empty() and not _scene_mutation.checkpoint_hash.is_empty() \
		and _fingerprint(_scene_mutation.input) == _scene_mutation.input_hash \
		and _fingerprint(_scene_mutation.checkpoint) == _scene_mutation.checkpoint_hash

func _scene_mutation_source_matches(captured: Dictionary) -> bool:
	return captured.get("ok", false) and captured.get("value", {}).get("backup") is Dictionary \
		and _fingerprint(captured.value.backup) == _scene_mutation.get("source_hash", "")


func _commit_scene_event_autosave(snapshot_input: Dictionary, checkpoint: Dictionary) -> Dictionary:
	if not _scene_control.is_empty() and not _scene_control_validate("commit"):
		return _fail(&"scene_control_custody_invalid", "source changed before preparation")
	var route := _call_provider("route_id", [])
	if not route.ok: return route
	if route.value not in ["dating", "scene"]: return _fail(&"scene_event_route_mismatch", "unsupported narrative host")
	var scene_route: bool = route.value == "scene"
	if scene_route and not _scene_route_input_valid(snapshot_input, checkpoint):
		return _fail(&"scene_event_input_invalid", "scene input requires installed authority and exact family binding")
	if not scene_route and snapshot_input.has("scene"):
		return _fail(&"scene_event_route_mismatch", "scene input cannot use a legacy host")
	var active := _call_provider("active_app_id", [])
	if not active.ok: return active
	# Desktop host state can retain its last app while the dating route owns
	# physical presentation. Preserve it; the bridge admits the actual Solo host.
	var audio := _call_provider("audio_context", [])
	if not audio.ok: return audio
	if scene_route and not _scene_entry.is_empty() and _scene_audio_source.is_valid():
		if not _scene_validate(_scene_entry, "commit"):
			return _fail(&"scene_entry_custody_invalid", "audio capture requires retained entry")
		_scene_callback_busy = true
		var captured_audio: Variant = _scene_audio_source.call(_scene_entry.binding.duplicate(true))
		_scene_callback_busy = false
		if not captured_audio is Dictionary or not captured_audio.get("ok", false):
			return _fail(&"scene_entry_audio_unavailable", "Run owner refused target audio capture")
		if not _scene_validate(_scene_entry, "commit"):
			return _fail(&"scene_entry_custody_invalid", "source changed during audio capture")
		if captured_audio.get("value") != null:
			if not captured_audio.value is Dictionary:
				return _fail(&"scene_entry_audio_invalid", "target context must be an object")
			audio = {"ok": true, "value": captured_audio.value.duplicate(true)}
	var content := _call_provider("content_version", [])
	if not content.ok: return content
	var inputs := _checkpoint_inputs(active.value, audio.value, content.value, checkpoint, route.value, snapshot_input)
	var captured: Dictionary = _real_port.capture()
	if not captured.get("ok", false): return captured
	if not _scene_mutation.is_empty() and not _scene_mutation_source_matches(captured):
		return _fail(StringName("scene_" + str(_scene_mutation.kind) + "_source_changed"), "journal changed before preparation")
	if not _scene_challenge.is_empty() and not _scene_challenge_source_matches(captured):
		return _fail(&"scene_challenge_source_changed", "journal changed before preparation")
	if not _scene_control_source_matches(captured):
		return _fail(&"scene_control_source_changed", "the saved source was replaced")
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
	var guarded_candidate := scene_route or not _scene_entry.is_empty()
	var candidate_hash := _fingerprint(candidate) if guarded_candidate else ""
	if scene_route and not _scene_route_candidate_valid(candidate, snapshot_input, checkpoint):
		return _fail(&"scene_entry_candidate_invalid", "prepared scene family differs from admitted input")
	if not scene_route and not _scene_entry.is_empty() and _scene_candidate_reference(candidate, checkpoint).is_empty():
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
		# Keep the lower port's exact prepared object, but reject mutations made by
		# the final authority/source callbacks before crossing its write boundary.
		if _fingerprint(candidate) != candidate_hash or (not scene_route and _scene_candidate_reference(candidate, checkpoint).is_empty()):
			return _fail(&"scene_entry_candidate_invalid", "prepared candidate changed before commit")
	if scene_route and (_fingerprint(candidate) != candidate_hash or not _scene_route_candidate_valid(candidate, snapshot_input, checkpoint)):
		return _fail(&"scene_entry_candidate_invalid", "scene candidate changed before commit")
	if not _scene_control.is_empty():
		if not _scene_control_validate("commit"):
			return _fail(&"scene_control_custody_invalid", "source changed during preparation")
		var control_source: Dictionary = _real_port.capture()
		if not _scene_control_source_matches(control_source):
			return _fail(&"scene_control_source_changed", "source changed during preparation")
		if not _scene_control_validate("commit") or _fingerprint(candidate) != candidate_hash \
				or not _scene_route_candidate_valid(candidate, snapshot_input, checkpoint):
			return _fail(&"scene_control_custody_invalid", "candidate changed before commit")
	if not _scene_challenge.is_empty():
		if not _scene_challenge_validate("before_commit"):
			return _fail(&"scene_challenge_custody_invalid", "Run owner refused commit")
		var challenge_source: Dictionary = _real_port.capture()
		if not _scene_challenge_source_matches(challenge_source):
			return _fail(&"scene_challenge_source_changed", "journal changed before commit")
		# Final callbacks may not change either the admitted bytes or lower candidate.
		if _fingerprint(snapshot_input) != _scene_challenge.input_hash \
				or _fingerprint(checkpoint) != _scene_challenge.checkpoint_hash \
				or _fingerprint(candidate) != candidate_hash \
				or not _scene_route_candidate_valid(candidate, snapshot_input, checkpoint):
			return _fail(&"scene_challenge_candidate_changed", "candidate changed before commit")
	if not _scene_mutation.is_empty():
		if not _scene_mutation_validate("before_commit"):
			return _fail(StringName("scene_" + str(_scene_mutation.kind) + "_custody_invalid"), "Run owner refused commit")
		var challenge_source: Dictionary = _real_port.capture()
		if not _scene_mutation_source_matches(challenge_source):
			return _fail(StringName("scene_" + str(_scene_mutation.kind) + "_source_changed"), "journal changed before commit")
		# Final callbacks may not change either the admitted bytes or lower candidate.
		if _fingerprint(snapshot_input) != _scene_mutation.input_hash \
				or _fingerprint(checkpoint) != _scene_mutation.checkpoint_hash \
				or _fingerprint(candidate) != candidate_hash \
				or not _scene_route_candidate_valid(candidate, snapshot_input, checkpoint):
			return _fail(StringName("scene_" + str(_scene_mutation.kind) + "_candidate_changed"), "candidate changed before commit")
	var committed: Dictionary = _real_port.commit(candidate)
	if guarded_candidate and _fingerprint(candidate) != candidate_hash:
		return {"ok": false, "code": &"scene_entry_commit_uncertain", "committed": true}

	var value: Variant = committed.get("value")
	var confirmed: bool = committed.get("ok", false) == true and value is Dictionary \
		and typeof(value.get("checkpoint_id")) == TYPE_STRING and not str(value.get("checkpoint_id", "")).is_empty() \
		and value.get("checkpoint_id") == candidate.get("checkpoint_id")
	if committed.get("ok", false) and not confirmed:
		return {"ok": false, "code": &"event_commit_ack_invalid", "committed": true}
	if not committed.get("ok", false):
		if not _scene_mutation.is_empty() and _scene_mutation.kind in ["shop", "round"] \
				and (committed.get("committed", false) or str(committed.get("code", "")) == "APPLICATION_FATAL"):
			var committed_failure := committed.duplicate(true)
			committed_failure["committed"] = true
			return committed_failure
		var rolled: Dictionary = _real_port.rollback({"journal_backup": captured.value.backup,
			"storage_backup": candidate.storage_backup})
		if not rolled.get("ok", false):
			if _scene_entry.is_empty() and _scene_control.is_empty() and _scene_challenge.is_empty() and _scene_mutation.is_empty(): return rolled
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
	if scene_route and not result.value.has("checkpoint_reference"):
		return {"ok": false, "code": &"scene_entry_commit_uncertain", "committed": true}
	return result


# These adapter checks bind an admitted input to the real lower candidate. Complete
# Run9/Save9 content, issuer and registration validation remains the lower owner’s job.
# Ordinary scene checkpoints also require the caller's live source/lease custody.
# The entry validator authenticates retained entry operations only; configuring it
# does not authenticate an ordinary checkpoint's source by itself.
const SCENE_INPUT_KEYS := ["lifecycle", "gameplay", "contacts", "desktop", "scene",
	"applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts"]

func _scene_route_input_valid(input: Dictionary, checkpoint: Dictionary) -> bool:
	if not is_instance_valid(_scene_authority) or not _scene_validator.is_valid() \
			or not _exact_keys(input, SCENE_INPUT_KEYS) or checkpoint.get("stage") != "scene": return false
	for key: String in ["lifecycle", "gameplay", "contacts", "desktop", "scene", "command_receipts"]:
		if not input.get(key) is Dictionary: return false
	if not _exact_keys(input.scene, ["registration_sha256", "active_occurrence_id", "entry_id", "notification", "active_challenge", "return_to"]): return false
	if input.scene.registration_sha256 != checkpoint.get("manifest_fingerprint") or not _scene_hash(input.scene.registration_sha256): return false
	var frame: Variant = checkpoint.get("frozen_context")
	if not frame is Dictionary or not frame.get("presentation") is Dictionary \
			or not frame.presentation.get("fields") is Dictionary: return false
	return input.scene.active_occurrence_id == frame.get("playback_id") \
		and input.scene.active_occurrence_id == frame.presentation.fields.get("admission_receipt_id") \
		and input.scene.active_occurrence_id is String and not input.scene.active_occurrence_id.is_empty() \
		and input.scene.entry_id == checkpoint.get("entry_id")

func _scene_route_candidate_valid(candidate: Dictionary, input: Dictionary, checkpoint: Dictionary) -> bool:
	if not _scene_route_input_valid(input, checkpoint) or not candidate.get("autosave_document") is Dictionary \
			or not candidate.get("journal_candidate") is Dictionary: return false
	var snapshot := _scene_bundle_snapshot(candidate.get("journal_candidate", {}).get("current"))
	if typeof(snapshot.get("schema_version")) != TYPE_INT or snapshot.schema_version != 9 \
			or snapshot.get("route_id") != "scene" or typeof(candidate.autosave_document.get("schema_version")) != TYPE_INT \
			or candidate.autosave_document.schema_version != 9: return false
	if not input.desktop.get("board") is Dictionary: return false
	var player_board: Dictionary = BOARD_STATE.project_player_state(input.desktop.board)
	if not player_board.ok: return false
	var expected_desktop: Dictionary = input.desktop.duplicate(true)
	expected_desktop.board = player_board.value.snapshot
	for key: String in ["lifecycle", "gameplay", "contacts", "desktop", "scene"]:
		# Compare the exact persisted projection, while admission/custody above keeps
		# the full live input (including retry records) unchanged.
		var expected: Variant = expected_desktop if key == "desktop" else input[key]
		if not snapshot.has(key) or _fingerprint(snapshot[key]) != _fingerprint(expected): return false
	for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		if snapshot.has(key): return false
	return not _scene_candidate_reference(candidate, checkpoint).is_empty()


# Scene acknowledgements are in-process capabilities, not saved proof. The configured
# Bridge validator authenticates its private candidate and exclusive invocation custody.
# This does not replace full Run/Save validation in the real checkpoint owner.
var _scene_authority: Object
var _scene_validator: Callable
var _scene_entry: Dictionary = {}
var _scene_used: Dictionary = {}
var _scene_callback_busy := false
var _scene_audio_source: Callable

func configure_scene_audio_source(source: Callable) -> Dictionary:
	if not _configured or _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy \
			or not _scene_entry.is_empty() or not source.is_valid() or source.get_argument_count() != 1:
		return _fail(&"scene_audio_source_invalid", "configure retained Run source while idle")
	if _scene_audio_source.is_valid() and _scene_audio_source != source:
		return _fail(&"scene_audio_source_conflict", "source replacement refused")
	_scene_audio_source = source
	return {"ok": true}

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
	if _next_commit_in_progress or _active_owner != &"" or _scene_callback_busy or not _scene_control.is_empty():
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

# One retained, process-local playable handoff. Source and destination still use
# the existing complete Run/Save transaction; neither token nor ack is persisted.
var _scene_control_validator: Callable
var _scene_control: Dictionary = {}

func configure_scene_control_authority(authority: Object, validator: Callable) -> Dictionary:
	if authority != _scene_authority or not is_instance_valid(authority) \
			or not validator.is_valid() or validator.get_object() != authority \
			or validator.get_argument_count() != 3 or _next_commit_in_progress \
			or _scene_callback_busy or not _scene_control.is_empty():
		return _fail(&"scene_control_authority_invalid", "")
	if _scene_control_validator.is_valid() and _scene_control_validator != validator:
		return _fail(&"scene_control_authority_invalid", "authority replacement refused")
	_scene_control_validator = validator
	return {"ok": true}

func retain_scene_control(authority: Object, token: RefCounted, material: Dictionary) -> Dictionary:
	if authority != _scene_authority or token == null or not _scene_control_validator.is_valid() \
			or _next_commit_in_progress or _scene_callback_busy or _active_owner != &"" \
			or not _scene_entry.is_empty() or not _scene_control.is_empty():
		return _fail(&"scene_control_custody_invalid", "")
	material = material.duplicate(true)
	if not _exact_keys(material, ["source_input", "source_checkpoint", "snapshot_input", "checkpoint", "event", "plan"]):
		return _fail(&"scene_control_material_invalid", "")
	for key: String in material:
		if not material[key] is Dictionary: return _fail(&"scene_control_material_invalid", key)
	var source: Dictionary = material.source_checkpoint
	var target: Dictionary = material.checkpoint
	var plan: Dictionary = material.plan
	if source.get("stage") != "scene" or not source.get("reading_session") is Dictionary \
			or not target.get("reading_session") is Dictionary \
			or [source.reading_session.get("boundary"), target.reading_session.get("boundary")] not in [["line", "control"], ["control", "line"]]:
		return _fail(&"scene_control_material_invalid", "exact scene endpoints required")
	var source_header := source.duplicate(true)
	var target_header := target.duplicate(true)
	source_header.erase("reading_session")
	target_header.erase("reading_session")
	if not READING_NEXT._same(source_header, target_header): return _fail(&"scene_control_material_invalid", "header changed")
	for phase: String in ["source", "destination"]:
		var projected := READING_NEXT.project(plan, phase)
		var endpoint: Dictionary = source if phase == "source" else target
		if not projected.ok or not READING_NEXT._same(projected.value, endpoint.reading_session):
			return _fail(&"scene_control_material_invalid", "projection changed")
	if plan.path.size() != 1 or not plan.traversed_captions.is_empty() \
			or plan.destination.kind != target.reading_session.boundary:
		return _fail(&"scene_control_material_invalid", "immediate control required")
	_scene_control = {"token": token, "material": material, "state": "prepared"}
	if not _scene_control_validate("retain"):
		_scene_control = {}
		return _fail(&"scene_control_custody_invalid", "Bridge refused retention")
	return {"ok": true}

## The source acknowledgement is generated here, not supplied by the caller.
## A definite destination refusal retains this same source for an exact retry.
func commit_scene_control(token: RefCounted) -> Dictionary:
	if _next_commit_in_progress or _scene_callback_busy or _active_owner != &"" \
			or _scene_control.is_empty() or token != _scene_control.token \
			or _scene_control.state not in ["prepared", "source_committed"]:
		return _fail(&"scene_control_custody_invalid", "")
	_next_commit_in_progress = true
	var result := _commit_scene_control_owned()
	_next_commit_in_progress = false
	if not result.get("ok", false) and (result.get("committed", false) or str(result.get("code", "")) == "APPLICATION_FATAL"):
		_scene_control.state = "uncertain"
		result["committed"] = true
	return result

func _commit_scene_control_owned() -> Dictionary:
	var material: Dictionary = _scene_control.material
	if _scene_control.state == "prepared":
		var source := _commit_scene_event_autosave(material.source_input, material.source_checkpoint)
		if not source.get("ok", false): return source
		var source_reference: Variant = source.get("value", {}).get("checkpoint_reference")
		if not _scene_reference_valid(source_reference):
			return {"ok": false, "code": &"scene_control_source_ack_invalid", "committed": true}
		_scene_control["source_reference"] = source_reference.duplicate(true)
		_scene_control.state = "source_committed"
	var destination := _commit_scene_event_autosave(material.snapshot_input, material.checkpoint)
	if not destination.get("ok", false): return destination
	var reference: Variant = destination.get("value", {}).get("checkpoint_reference")
	if not _scene_reference_valid(reference):
		return {"ok": false, "code": &"scene_control_ack_invalid", "committed": true}
	_scene_control.state = "committed"
	_scene_control["ack"] = {"source_checkpoint": _scene_control.source_reference.duplicate(true),
		"target_checkpoint": reference.duplicate(true), "material_sha256": _fingerprint(material)}
	return destination

func consume_scene_control_ack(token: RefCounted) -> Dictionary:
	if _next_commit_in_progress or _scene_callback_busy or _scene_control.is_empty() \
			or token == null or token != _scene_control.token:
		return _fail(&"scene_control_ack_unavailable", "")
	if _scene_control.state != "committed":
		return {"ok": false, "code": &"scene_control_ack_unavailable", "committed": _scene_control.state == "uncertain"}
	if not _scene_control_validate("consume"):
		return {"ok": false, "code": &"scene_control_custody_invalid", "committed": true}
	_scene_callback_busy = true
	var captured: Dictionary = _real_port.capture()
	_scene_callback_busy = false
	var current := _scene_bundle_snapshot(captured.get("value", {}).get("backup", {}).get("current"))
	if not captured.get("ok", false) \
			or not READING_NEXT._same(_scene_snapshot_reference(current), _scene_control.ack.target_checkpoint) \
			or not _scene_control_validate("consume"):
		_scene_control.state = "uncertain"
		return {"ok": false, "code": &"scene_control_ack_invalid", "committed": true}
	var ack: Dictionary = _scene_control.ack.duplicate(true)
	_scene_control = {}
	return {"ok": true, "value": ack}

func _scene_control_validate(phase: String) -> bool:
	if _scene_control.is_empty() or _scene_callback_busy or not _scene_control_validator.is_valid(): return false
	_scene_callback_busy = true
	var checked: Variant = _scene_control_validator.call(_scene_control.token,
		_scene_control.material.duplicate(true), phase)
	_scene_callback_busy = false
	return checked is Dictionary and checked.get("ok", false) == true

func _scene_control_source_matches(captured: Dictionary) -> bool:
	if not captured.get("ok", false): return false
	if _scene_control.is_empty() or _scene_control.state == "prepared": return true
	var current := _scene_bundle_snapshot(captured.get("value", {}).get("backup", {}).get("current"))
	return captured.get("ok", false) \
		and READING_NEXT._same(_scene_snapshot_reference(current), _scene_control.source_reference) \
		and _player_checkpoint_same(current.get("narrative_checkpoint"), _scene_control.material.source_checkpoint)


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
	# Entry acknowledgement names the privately retained target, never a caller's
	# potentially callback-mutated copy. Ordinary source checkpoints use their input.
	if not _scene_entry.is_empty() and (not _player_checkpoint_same(snapshot.get("narrative_checkpoint"), _scene_entry.checkpoint) \
			or _fingerprint(_scene_entry.checkpoint) != _scene_entry.narrative_checkpoint_sha256):
		return {}
	if reference.is_empty() or reference.checkpoint_id != candidate.get("checkpoint_id") \
			or not _player_checkpoint_same(snapshot.get("narrative_checkpoint"), checkpoint) \
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
	if _next_commit_in_progress or _scene_callback_busy or not _scene_control.is_empty():
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
	if not _scene_challenge.is_empty(): return _fail(&"transaction_in_progress", "Challenge owns checkpoint publication")
	if not _scene_mutation.is_empty() and _scene_mutation.kind in ["shop", "round"]: return _fail(&"transaction_in_progress", "Scene app mutation owns checkpoint publication")
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
	if not _scene_challenge.is_empty(): return _fail(&"transaction_in_progress", "Challenge owns checkpoint publication")
	if not _scene_mutation.is_empty() and _scene_mutation.kind in ["shop", "round"]: return _fail(&"transaction_in_progress", "Scene app mutation owns checkpoint publication")
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
	if not _scene_challenge.is_empty(): return _fail(&"transaction_in_progress", "Challenge owns checkpoint publication")
	if not _scene_mutation.is_empty() and _scene_mutation.kind in ["shop", "round"]: return _fail(&"transaction_in_progress", "Scene app mutation owns checkpoint publication")
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
			or not _player_checkpoint_same(current.get("narrative_checkpoint"), _next_source.checkpoint):
		return _fail(&"reading_next_source_changed", "")
	var before_header: Dictionary = _next_source.checkpoint.duplicate(true)
	var after_header := checkpoint.duplicate(true)
	before_header.erase("reading_session")
	after_header.erase("reading_session")
	if before_header != after_header: return _fail(&"reading_next_source_changed", "")
	return _marker_validator.call(snapshot.duplicate(true), checkpoint.duplicate(true), _next_source.duplicate(true))


## Compare a persisted reading position with its full live transaction source.
## Other custody hashes still cover complete live owner data.
func _player_checkpoint_same(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary: return false
	var owner := preload("res://scripts/narrative/SoloReadingSession.gd")
	var a: Dictionary = owner.project_player_checkpoint(left)
	var b: Dictionary = owner.project_player_checkpoint(right)
	return a.ok and b.ok and READING_NEXT._same(a.value, b.value)
