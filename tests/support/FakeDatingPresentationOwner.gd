extends RefCounted

## Schema-exact stand-in for the relationship-board / challenge owner `dwm-oyo.4` will write
## (Plan 01 Task 8, dwm-p2r.14).
##
## WHAT IT IS FOR. `DatingPresentationPort` is deliberately production-unconfigured, so without this
## the port's ancestry, command and completion laws could never be exercised at all and would rot
## until dwm-oyo.4 discovered them. This fake exists so those laws are proved NOW, against the exact
## surface the real owner must implement.
##
## WHAT IT IS NOT. It is never a bootstrap dependency. `ApplicationBootstrap` constructs the Dating
## port with NO owner; only contract and scenario tests configure this one. It decides no gameplay
## outcome: `result` is whatever the test hands `finish()`, which is precisely how a real challenge
## owner would report its own physical result and no more.
##
## IT MIRRORS THE NARRATIVE OWNER'S TRUST MODEL ON PURPOSE. The token is derived from the completion
## id plus command hash, a completion can only be produced by calling `finish()` (this fake's stand-in
## for a challenge genuinely ending), and `validate_physical_completion()` compares byte-for-byte
## against the record actually emitted. A fake that blessed any well-shaped receipt would let the
## port's tests pass while the real owner's would not.

const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const OWNER_KIND := "dating_challenge"
const TOKEN_PREFIX := "dating_challenge."
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
## The CANONICAL command: begin_physical()'s command plus the token this owner returned.
const CANONICAL_COMMAND_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "completion_transaction_provenance", "context",
	"physical_token", "resolution_id", "resolution_issuer_receipt", "route_id", "stage_id",
	"substage_id", "timeline_id",
]

signal physical_completion_ready(receipt: Dictionary)
signal physical_completion_failed(failure: Dictionary)

## completion_transaction_id -> {command_sha256, physical_token}
var _in_flight: Dictionary = {}
## completion_transaction_id -> the exact receipt this owner emitted
var _completed: Dictionary = {}
## Every command this owner was asked to start, so a test can assert it started exactly once.
var started_commands: Array = []


func owner_kind() -> String:
	return OWNER_KIND


func begin_physical(command: Dictionary) -> Dictionary:
	var shaped := _exact_keys(command, COMMAND_KEYS, &"invalid_presentation_command")
	if not shaped.is_empty():
		return shaped
	var completion_id := str(command["completion_transaction_id"])
	var command_sha256 := str(command["command_sha256"])
	if completion_id.strip_edges().is_empty() or command_sha256.strip_edges().is_empty():
		return _fail(&"invalid_presentation_command",
			"completion_transaction_id and command_sha256 must be nonblank", {})
	var token := derive_token(completion_id, command_sha256)
	for settled: Dictionary in [_completed.get(completion_id, {}), _in_flight.get(completion_id, {})]:
		if settled.is_empty():
			continue
		if str(settled["command_sha256"]) != command_sha256:
			return _fail(&"presentation_command_conflict",
				"that completion id already carries different bytes", {})
		return _ok({"physical_token": token, "command_sha256": command_sha256})
	_in_flight[completion_id] = {"command_sha256": command_sha256, "physical_token": token}
	started_commands.append(command.duplicate(true))
	return _ok({"physical_token": token, "command_sha256": command_sha256})


func validate_physical_completion(request: Dictionary) -> Dictionary:
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
	var completion_id := str(command.get("completion_transaction_id", ""))
	if not _completed.has(completion_id):
		return _fail(&"physical_completion_untrusted",
			"this owner never emitted a completion for that command", {})
	if receipt != (_completed[completion_id] as Dictionary):
		return _fail(&"physical_completion_untrusted",
			"the receipt is not byte-identical to the emitted completion", {})
	if str(receipt["command_sha256"]) != str(command.get("command_sha256", "")):
		return _fail(&"physical_completion_untrusted",
			"the receipt does not belong to this command", {})
	return _ok({"validated": true, "owner_kind": OWNER_KIND})


## The test-side stand-in for a challenge genuinely ending. A repeat emits nothing new, mirroring the
## narrative owner, so duplicate-delivery tests exercise the same law on both ports.
func finish(completion_transaction_id: String, result: Dictionary = {}) -> void:
	if not _in_flight.has(completion_transaction_id):
		return
	var pending: Dictionary = _in_flight[completion_transaction_id]
	_in_flight.erase(completion_transaction_id)
	var receipt := {
		"owner_kind": OWNER_KIND,
		"physical_token": str(pending["physical_token"]),
		"command_sha256": str(pending["command_sha256"]),
		"completion_transaction_id": completion_transaction_id,
		"status": STATUS_COMPLETED,
		"result": result.duplicate(true),
	}
	_completed[completion_transaction_id] = receipt.duplicate(true)
	physical_completion_ready.emit(receipt.duplicate(true))


## Re-emits the settled record, the way a restored owner would replay an already-finished challenge.
func reemit(completion_transaction_id: String) -> void:
	if _completed.has(completion_transaction_id):
		physical_completion_ready.emit((_completed[completion_transaction_id] as Dictionary).duplicate(true))


func fail(failure: Dictionary) -> void:
	physical_completion_failed.emit(failure.duplicate(true))


static func derive_token(completion_transaction_id: String, command_sha256: String) -> String:
	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(
		completion_transaction_id + "|" + command_sha256)
	if not hashed.get("ok", false):
		return ""
	return TOKEN_PREFIX + str((hashed["value"] as Dictionary)["sha256"])


func _exact_keys(value: Dictionary, expected: Array[String], code: StringName) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(code, "the member set is not exact", {"expected": expected, "actual": keys})
	return {}


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
