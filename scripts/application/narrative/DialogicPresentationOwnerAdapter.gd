extends RefCounted

## The ONE narrative physical-presentation owner (Plan 01 Task 8, dwm-p2r.14).
##
## WHAT IT IS. `HospitalPresentationPort` needs a physical owner that can actually run a timeline and
## then say, trustworthily, that it finished. This adapter is that owner and nothing more: it wraps
## the existing `DialogicBridge` and converts exactly one TRUSTED bridge signal into exactly one
## `physical_completion_ready`.
##
## WHY IT IS THE ONLY SOURCE OF PHYSICAL TRUTH. Before Task 8 the bridge exposed a public
## `finish_current_timeline()`, so any caller could announce a completion that never happened. That
## method is gone. The only path to a completion now is the runtime's own `timeline_ended`, which
## this adapter observes through the bridge's `timeline_finished`. A scene cannot author a result, a
## caller cannot forge one, and a second emission for the same command replays the first record
## rather than minting a new one.
##
## WHAT IT DELIBERATELY CANNOT DO. It starts no dating challenge, decides no outcome, mutates no
## gameplay state, and holds no canonical ledger. Its retained map is an EPHEMERAL projection of the
## coordinator-owned pending command; `DayResolutionPlan` owns the durable command and the
## checkpointed completion receipt.
##
## THE TOKEN IS DERIVED, NOT MINTED. `physical_token` is a deterministic function of the completion
## transaction id and the canonical command hash, so an unfinished restore that replays the same
## bytes reconstructs the SAME token instead of stranding the old one.

const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

## The owner kind this adapter declares. `HospitalPresentationPort` accepts only this value; the
## Dating port accepts only `dating_challenge`, so the two owners can never be swapped.
const OWNER_KIND := "narrative"
const TOKEN_PREFIX := "narrative_presentation."
const STATUS_COMPLETED := "completed"

## Exact `begin_physical()` command members (sorted): the port's exact `begin()` request plus the
## canonical hash the port computed over it.
const COMMAND_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "completion_transaction_provenance", "context",
	"resolution_id", "resolution_issuer_receipt", "route_id", "stage_id", "substage_id",
	"timeline_id",
]
## Exact owner completion-receipt members (sorted), frozen by the plan.
const RECEIPT_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "owner_kind", "physical_token", "result",
	"status",
]
## Exact `validate_physical_completion()` request members (sorted).
const VALIDATE_KEYS: Array[String] = ["physical_completion_receipt", "presentation_command"]
## The CANONICAL command members (sorted): `begin_physical()`'s command plus the token this owner
## returned. `complete()` validates against the canonical command, so it carries one member more
## than the command that started the presentation.
const CANONICAL_COMMAND_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "completion_transaction_provenance", "context",
	"physical_token", "resolution_id", "resolution_issuer_receipt", "route_id", "stage_id",
	"substage_id", "timeline_id",
]

const _BRIDGE_METHODS: Array[String] = ["start_timeline_id", "is_dialogic_available"]

signal physical_completion_ready(receipt: Dictionary)
signal physical_completion_failed(failure: Dictionary)

var _bridge: Object = null
## completion_transaction_id -> {command_sha256, physical_token, timeline_id}. Ephemeral.
var _in_flight: Dictionary = {}
## completion_transaction_id -> the exact receipt this adapter emitted. Replay returns these bytes.
var _completed: Dictionary = {}
var _presentation_revision := 0


## Retains the exact existing `DialogicBridge` and connects its trusted completion signal once.
## Idempotent for that same object; a replacement is refused rather than adopted, so a second wiring
## attempt can never re-point a live owner at a different runtime.
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
	if not bridge.is_connected("timeline_finished", _on_timeline_finished):
		bridge.connect("timeline_finished", _on_timeline_finished)
	if bridge.has_signal("ordinary_playback_failed") and not bridge.is_connected("ordinary_playback_failed", _on_playback_failed):
		bridge.connect("ordinary_playback_failed", _on_playback_failed)
	return _ok({"configured": true, "already_configured": false,
		"bridge_instance_id": bridge.get_instance_id()})


func owner_kind() -> String:
	return OWNER_KIND


## Starts the physical timeline for one canonical command and returns its derived token.
##
## Byte-identical replay of the SAME command returns the identical token WITHOUT restarting the
## timeline; the same completion id carrying different bytes is refused, because that would be two
## different presentations wearing one identity.
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
	var token := derive_token(completion_id, command_sha256)

	if _completed.has(completion_id):
		# Already physically finished. Restarting would replay narrative the player already saw.
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
	var started: Variant = _bridge.call(&"start_timeline_id", timeline_id,
		(command["context"] as Dictionary).duplicate(true))
	if typeof(started) != TYPE_DICTIONARY or not (started as Dictionary).get("ok", false):
		_in_flight.erase(completion_id)
		return _fail(&"narrative_presentation_unavailable",
			"the bridge refused to start the timeline",
			{"timeline_id": timeline_id, "cause": started})
	return _ok({"physical_token": token, "command_sha256": command_sha256})


## Pause queries the retained owner, never a scene-authored readiness flag or cached timeline ID.
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


func _on_playback_failed(timeline_id: String, result: Dictionary) -> void:
	for completion_id: Variant in _in_flight.keys():
		if str((_in_flight[completion_id] as Dictionary).timeline_id) == timeline_id:
			_in_flight.erase(completion_id)
			physical_completion_failed.emit(_fail(&"narrative_presentation_unavailable",
				"admitted playback failed", {"completion_transaction_id": completion_id, "cause": result.duplicate(true)}))


## Proves that one owner receipt is byte-identical to the record THIS adapter actually emitted for
## that command. The caller's bytes are never trusted to describe what physically happened.
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
	# ONE comparison, not six: the emitted record is the whole truth, so owner kind, token, hash,
	# completion id, status and result all drift together or not at all.
	if receipt != (_completed[completion_id] as Dictionary):
		return _fail(&"physical_completion_untrusted",
			"the receipt is not byte-identical to the emitted completion", {})
	if str(receipt["command_sha256"]) != str(command["command_sha256"]):
		return _fail(&"physical_completion_untrusted",
			"the receipt does not belong to this command", {})
	return _ok({"validated": true, "owner_kind": OWNER_KIND})


## The deterministic token law, exposed so a restore can reconstruct the same token without this
## adapter's in-flight map surviving the crash.
static func derive_token(completion_transaction_id: String, command_sha256: String) -> String:
	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(
		completion_transaction_id + "|" + command_sha256)
	if not hashed.get("ok", false):
		return ""
	return TOKEN_PREFIX + str((hashed["value"] as Dictionary)["sha256"])


## The ONLY entry point for a physical completion. Reached exclusively from the bridge's trusted
## `timeline_finished`, which since Task 8 only the Dialogic runtime's own `timeline_ended` can
## raise. A timeline this adapter did not start is ignored: other systems legitimately run timelines.
func _on_timeline_finished(timeline_id: String, result: Dictionary) -> void:
	var completion_id := ""
	for candidate: Variant in _in_flight:
		if str((_in_flight[candidate] as Dictionary)["timeline_id"]) == timeline_id:
			completion_id = str(candidate)
			break
	if completion_id.is_empty():
		return
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


# ---- helpers ----

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
