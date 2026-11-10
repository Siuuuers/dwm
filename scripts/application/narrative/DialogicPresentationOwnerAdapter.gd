extends RefCounted


const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const _FROZEN_CONTEXT := preload("res://scripts/narrative/HospitalFrozenContext.gd")

const OWNER_KIND := "narrative"
const TOKEN_PREFIX := "narrative_presentation."
const STATUS_COMPLETED := "completed"

const COMMAND_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "completion_transaction_provenance", "context",
	"resolution_id", "resolution_issuer_receipt", "route_id", "stage_id", "substage_id",
	"timeline_id",
]
const RECEIPT_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "owner_kind", "physical_token", "result",
	"status",
]
const VALIDATE_KEYS: Array[String] = ["physical_completion_receipt", "presentation_command"]
const CANONICAL_COMMAND_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "completion_transaction_provenance", "context",
	"physical_token", "resolution_id", "resolution_issuer_receipt", "route_id", "stage_id",
	"substage_id", "timeline_id",
]

const _BRIDGE_METHODS: Array[String] = ["start_timeline_id", "is_dialogic_available"]

signal physical_completion_ready(receipt: Dictionary)
signal physical_completion_failed(failure: Dictionary)

var _bridge: Object = null
var _in_flight: Dictionary = {}
var _completed: Dictionary = {}
var _presentation_revision := 0
var _frozen_contexts_required := false

func configure_frozen_hospital_contexts() -> Dictionary:
	_frozen_contexts_required = true
	return _ok({})


func configure(bridge: Object) -> Dictionary:
	if bridge == null or not _has_methods(bridge, _BRIDGE_METHODS) \
			or not bridge.has_signal("timeline_finished"):
		return _fail(&"invalid_narrative_bridge", "the bridge contract is incomplete", {})
	if _bridge != null:
		if _bridge != bridge:
			return _fail(&"narrative_owner_already_configured",
				"a configured owner never adopts a replacement bridge", {})
		return _ok({"configured": true, "already_configured": true,
			"bridge_instance_id": bridge.get_instance_id()})
	_bridge = bridge
	if bridge.has_signal("hospital_reading_finished"):
		bridge.connect("hospital_reading_finished", _on_hospital_reading_finished)
	if not bridge.is_connected("timeline_finished", _on_timeline_finished):
		bridge.connect("timeline_finished", _on_timeline_finished)
	if bridge.has_signal("ordinary_playback_failed") and not bridge.is_connected("ordinary_playback_failed", _on_playback_failed):
		bridge.connect("ordinary_playback_failed", _on_playback_failed)
	if bridge.has_signal("ordinary_playback_retired"):
		bridge.connect("ordinary_playback_retired", _on_playback_retired)
	return _ok({"configured": true, "already_configured": false,
		"bridge_instance_id": bridge.get_instance_id()})


func owner_kind() -> String:
	return OWNER_KIND


func adopt_reading_restore(command: Dictionary) -> Dictionary:
	if _bridge == null or not _bridge.has_method("is_hospital_reading_restore_for") \
			or not _bridge.is_hospital_reading_restore_for(command):
		return _ok({"restored": false})
	var shaped := _exact_keys(command, CANONICAL_COMMAND_KEYS, &"invalid_presentation_command")
	if not shaped.is_empty(): return shaped
	var completion_id := str(command.completion_transaction_id)
	var prior_completed: Dictionary = _completed.get(completion_id, {}).duplicate(true)
	var prior_pending: Dictionary = _in_flight.get(completion_id, {}).duplicate(true)
	for prior: Dictionary in [prior_completed, prior_pending]:
		if not prior.is_empty() and (prior.get("command_sha256") != command.command_sha256 \
				or prior.get("physical_token") != command.physical_token):
			return _fail(&"presentation_command_conflict", "restored command binding changed", {})
	_completed.erase(completion_id)
	_in_flight.erase(completion_id)
	var physical := command.duplicate(true)
	physical.erase("physical_token")
	var resumed := begin_physical(physical)
	if not resumed.get("ok", false):
		if not prior_completed.is_empty(): _completed[completion_id] = prior_completed
		if not prior_pending.is_empty(): _in_flight[completion_id] = prior_pending
		return resumed
	resumed.value["restored"] = true
	return resumed


func begin_physical(command: Dictionary) -> Dictionary:
	if _bridge == null:
		return _fail(&"narrative_owner_unconfigured", "configure() has not run", {})
	var shaped := _exact_keys(command, COMMAND_KEYS, &"invalid_presentation_command")
	if not shaped.is_empty():
		return shaped
	var completion_id := str(command["completion_transaction_id"])
	var command_sha256 := str(command["command_sha256"])
	if completion_id.strip_edges().is_empty() or command_sha256.strip_edges().is_empty():
		return _fail(&"invalid_presentation_command",
			"completion_transaction_id and command_sha256 must be nonblank", {})
	var timeline_id := str(command["timeline_id"])
	var context: Variant = command.get("context")
	if timeline_id == "hospital.faint" and (_frozen_contexts_required or (context is Dictionary and context.has("presentation"))):
		var frozen := _FROZEN_CONTEXT.validate(context)
		if not frozen.get("ok", false): return frozen
	var token := derive_token(completion_id, command_sha256)

	if _completed.has(completion_id):
		var settled: Dictionary = _completed[completion_id]
		if str(settled["command_sha256"]) != command_sha256:
			return _fail(&"presentation_command_conflict",
				"a settled completion id cannot be reused with different bytes", {})
		return _ok({"physical_token": token, "command_sha256": command_sha256})
	if _in_flight.has(completion_id):
		var pending: Dictionary = _in_flight[completion_id]
		if str(pending["command_sha256"]) != command_sha256:
			return _fail(&"presentation_command_conflict",
				"an in-flight completion id cannot be reused with different bytes", {})
		return _ok({"physical_token": token, "command_sha256": command_sha256})

	_presentation_revision += 1
	_in_flight[completion_id] = {
		"command_sha256": command_sha256,
		"physical_token": token,
		"timeline_id": timeline_id,
		"route_id": str(command["route_id"]),
		"revision": _presentation_revision,
	}
	if timeline_id == "hospital.faint" and _bridge.has_method("begin_hospital_reading"):
		var canonical := command.duplicate(true)
		canonical["physical_token"] = token
		_in_flight[completion_id]["semantic_command"] = canonical.duplicate(true)
		var reading: Dictionary = _bridge.begin_hospital_reading(canonical)
		if not reading.get("ok", false):
			_in_flight.erase(completion_id)
			return reading
		if reading.get("value", {}).get("enabled", false):
			return _ok({"physical_token": token, "command_sha256": command_sha256})
		_in_flight[completion_id].erase("semantic_command")
	var started: Variant = _bridge.call(&"start_timeline_id", timeline_id,
		(command["context"] as Dictionary).duplicate(true))
	if typeof(started) != TYPE_DICTIONARY or not (started as Dictionary).get("ok", false):
		_in_flight.erase(completion_id)
		return _fail(&"narrative_presentation_unavailable",
			"the bridge refused to start the timeline",
			{"timeline_id": timeline_id, "cause": started})
	return _ok({"physical_token": token, "command_sha256": command_sha256})


func capture_pause_source() -> Dictionary:
	if _bridge == null or not _bridge.has_method("capture_pause_frontier") or _in_flight.size() != 1:
		return _fail(&"pause_source_unavailable", "no unique owned presentation", {})
	var completion_id: String = str(_in_flight.keys()[0])
	var pending: Dictionary = _in_flight[completion_id]
	if pending.route_id != "hospital":
		return _fail(&"pause_source_unavailable", "this owner has no canonical Pause source", {})
	var frontier: Dictionary = _bridge.capture_pause_frontier(str(pending.timeline_id))
	if not frontier.get("ok", false): return frontier
	var source := pending.duplicate(true)
	source["completion_transaction_id"] = completion_id
	source["frontier"] = frontier.value.duplicate(true)
	return _ok(source)


func _on_playback_retired(timeline_id: String) -> void:
	for completion_id: Variant in _in_flight.keys():
		var pending: Dictionary = _in_flight[completion_id]
		if str(pending.timeline_id) == timeline_id:
			_in_flight.erase(completion_id)


func _on_playback_failed(timeline_id: String, result: Dictionary) -> void:
	for completion_id: Variant in _in_flight.keys():
		var pending: Dictionary = _in_flight[completion_id]
		if str(pending.timeline_id) == timeline_id:
			_in_flight.erase(completion_id)
			physical_completion_failed.emit(_fail(&"narrative_presentation_unavailable",
				"admitted playback failed", {"completion_transaction_id": completion_id, "cause": result.duplicate(true)}))


func validate_physical_completion(request: Dictionary) -> Dictionary:
	if _bridge == null:
		return _fail(&"narrative_owner_unconfigured", "configure() has not run", {})
	var shaped := _exact_keys(request, VALIDATE_KEYS, &"invalid_completion_request")
	if not shaped.is_empty():
		return shaped
	if typeof(request["presentation_command"]) != TYPE_DICTIONARY \
			or typeof(request["physical_completion_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_completion_request", "both members must be dictionaries", {})
	var command: Dictionary = request["presentation_command"]
	var receipt: Dictionary = request["physical_completion_receipt"]
	var command_shape := _exact_keys(command, CANONICAL_COMMAND_KEYS,
		&"invalid_presentation_command")
	if not command_shape.is_empty():
		return command_shape
	if str(command["physical_token"]) != derive_token(str(command["completion_transaction_id"]),
			str(command["command_sha256"])):
		return _fail(&"physical_completion_untrusted",
			"the canonical command carries a token this owner did not derive", {})
	var receipt_shape := _exact_keys(receipt, RECEIPT_KEYS, &"physical_completion_untrusted")
	if not receipt_shape.is_empty():
		return receipt_shape

	var completion_id := str(command["completion_transaction_id"])
	if not _completed.has(completion_id):
		return _fail(&"physical_completion_untrusted",
			"this owner never emitted a completion for that command", {})
	if receipt != (_completed[completion_id] as Dictionary):
		return _fail(&"physical_completion_untrusted",
			"the receipt is not byte-identical to the emitted completion", {})
	if str(receipt["command_sha256"]) != str(command["command_sha256"]):
		return _fail(&"physical_completion_untrusted",
			"the receipt does not belong to this command", {})
	return _ok({"validated": true, "owner_kind": OWNER_KIND})


static func derive_token(completion_transaction_id: String, command_sha256: String) -> String:
	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(
		completion_transaction_id + "|" + command_sha256)
	if not hashed.get("ok", false):
		return ""
	return TOKEN_PREFIX + str((hashed["value"] as Dictionary)["sha256"])


func _on_timeline_finished(timeline_id: String, result: Dictionary) -> void:
	var completion_id := ""
	for candidate: Variant in _in_flight:
		var candidate_pending: Dictionary = _in_flight[candidate]
		if candidate_pending.has("semantic_command"): continue
		if str(candidate_pending["timeline_id"]) == timeline_id:
			completion_id = str(candidate)
			break
	if completion_id.is_empty():
		return
	_complete_owned(completion_id, result)


func _on_hospital_reading_finished(command: Dictionary, result: Dictionary) -> void:
	var completion_id := str(command.get("completion_transaction_id", ""))
	if not _in_flight.has(completion_id) \
			or _in_flight[completion_id].get("semantic_command") != command:
		return
	_complete_owned(completion_id, result)


func _complete_owned(completion_id: String, result: Dictionary) -> void:
	var pending: Dictionary = _in_flight[completion_id]
	_in_flight.erase(completion_id)
	var receipt := {
		"owner_kind": OWNER_KIND,
		"physical_token": str(pending["physical_token"]),
		"command_sha256": str(pending["command_sha256"]),
		"completion_transaction_id": completion_id,
		"status": STATUS_COMPLETED,
		"result": result.duplicate(true) if typeof(result) == TYPE_DICTIONARY else {},
	}
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != RECEIPT_KEYS:
		physical_completion_failed.emit(_fail(&"physical_completion_malformed",
			"the emitted receipt member set is not exact", {}))
		return
	_completed[completion_id] = receipt.duplicate(true)
	physical_completion_ready.emit(receipt.duplicate(true))



func _exact_keys(value: Dictionary, expected: Array[String], code: StringName) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(code, "the member set is not exact", {"expected": expected, "actual": keys})
	return {}


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
