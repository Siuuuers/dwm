extends RefCounted


const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const _NARRATIVE_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const _FROZEN_CONTEXT := preload("res://scripts/narrative/HospitalFrozenContext.gd")

const ROUTE_ID := "hospital"
const CONTEXT_KIND := "hospital"
const OWNER_KIND := "narrative"
const COMPLETION_CHILD_KIND := &"day_resolution_stage"
const ROOT_PURPOSE := &"transaction_id"
const COMPLETION_ROLE := "presentation.completion"
const STATUS_COMPLETED := "completed"

const REQUEST_KEYS: Array[String] = [
	"completion_transaction_id", "completion_transaction_provenance", "context", "resolution_id",
	"resolution_issuer_receipt", "route_id", "stage_id", "substage_id", "timeline_id",
]
const CONTEXT_KEYS: Array[String] = [
	"day", "kind", "miss_receipt_ids", "source_entry_ids",
]
const COMPLETE_KEYS: Array[String] = [
	"physical_completion_receipt", "presentation_command",
]
const OWNER_RECEIPT_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "owner_kind", "physical_token", "result",
	"status",
]
const COMPLETION_RECEIPT_KEYS: Array[String] = [
	"command_sha256", "physical_completion_receipt", "physical_owner_kind", "physical_token",
	"receipt_id", "receipt_provenance", "resolution_id", "route_id", "stage_id", "substage_id",
	"timeline_id",
]

const _ISSUER_METHODS: Array[String] = ["verify_issued", "derive_child", "validate_child"]
const _OWNER_METHODS: Array[String] = ["begin_physical", "validate_physical_completion"]

signal completion_ready(completion_result: Dictionary)
signal completion_failed(failure: Dictionary)

var _identity_issuer: Object = null
var _physical_owner: Object = null
var _commands: Dictionary = {}
var _settled: Dictionary = {}
var _frozen_contexts_required := false

func configure_frozen_hospital_contexts() -> Dictionary:
	_frozen_contexts_required = true
	return _ok({})


func configure(identity_issuer: Object, physical_owner: Object) -> Dictionary:
	if identity_issuer == null or not _has_methods(identity_issuer, _ISSUER_METHODS):
		return _fail(&"invalid_identity_issuer", "the issuer contract is incomplete", {})
	var owner_error := _owner_error(physical_owner)
	if owner_error != "":
		return _fail(&"invalid_physical_owner", owner_error, {})
	if _identity_issuer != null or _physical_owner != null:
		if _identity_issuer == identity_issuer and _physical_owner == physical_owner:
			return _ok({"configured": true, "already_configured": true,
				"owner_instance_id": physical_owner.get_instance_id()})
		return _fail(&"presentation_port_already_configured",
			"a configured port never adopts a replacement dependency", {})
	_identity_issuer = identity_issuer
	_physical_owner = physical_owner
	if not physical_owner.is_connected("physical_completion_ready", _on_physical_completion_ready):
		physical_owner.connect("physical_completion_ready", _on_physical_completion_ready)
	if not physical_owner.is_connected("physical_completion_failed", _on_physical_completion_failed):
		physical_owner.connect("physical_completion_failed", _on_physical_completion_failed)
	return _ok({"configured": true, "already_configured": false,
		"owner_instance_id": physical_owner.get_instance_id()})


func begin(request: Dictionary) -> Dictionary:
	if _identity_issuer == null or _physical_owner == null:
		return _fail(&"presentation_port_unconfigured", "configure() has not run", {})
	var validated := _validate_request(request)
	if not validated.get("ok", false):
		return validated

	var completion_id := str(request["completion_transaction_id"])
	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(request)
	if not hashed.get("ok", false):
		return _fail(&"invalid_presentation_intent",
			"the request is not canonically representable", {})
	var command_sha256 := str((hashed["value"] as Dictionary)["sha256"])

	if _commands.has(completion_id):
		var existing: Dictionary = _commands[completion_id]
		if str(existing["command_sha256"]) != command_sha256:
			return _fail(&"presentation_command_conflict",
				"this completion transaction already carries different command bytes", {})
		if _physical_owner.has_method("adopt_reading_restore"):
			var resumed: Variant = _physical_owner.adopt_reading_restore(existing.duplicate(true))
			if not resumed is Dictionary or not resumed.get("ok", false):
				return resumed if resumed is Dictionary else _fail(
					&"physical_presentation_unavailable", "the owner returned no restore result", {})
			if resumed.get("value", {}).get("restored", false):
				if resumed.value.get("physical_token") != existing.physical_token \
						or resumed.value.get("command_sha256") != command_sha256:
					return _fail(&"physical_presentation_unavailable", "restored command binding changed", {})
				_settled.erase(completion_id)
		return _ok({"presentation_command": existing.duplicate(true)})

	var command := request.duplicate(true)
	command["command_sha256"] = command_sha256
	var started: Variant = _physical_owner.call(&"begin_physical", command.duplicate(true))
	if typeof(started) != TYPE_DICTIONARY or not (started as Dictionary).get("ok", false):
		return started if typeof(started) == TYPE_DICTIONARY else _fail(
			&"physical_presentation_unavailable", "the owner returned no result", {})
	var value: Dictionary = (started as Dictionary)["value"]
	var physical_token := str(value.get("physical_token", ""))
	if physical_token.strip_edges().is_empty() \
			or str(value.get("command_sha256", "")) != command_sha256:
		return _fail(&"physical_presentation_unavailable",
			"the owner returned no nonblank token bound to these command bytes", {})
	command["physical_token"] = physical_token
	_commands[completion_id] = command.duplicate(true)
	return _ok({"presentation_command": command.duplicate(true)})


func complete(request: Dictionary) -> Dictionary:
	if _identity_issuer == null or _physical_owner == null:
		return _fail(&"presentation_port_unconfigured", "configure() has not run", {})
	var shaped := _exact_keys(request, COMPLETE_KEYS, &"invalid_presentation_completion")
	if not shaped.is_empty():
		return shaped
	if typeof(request["presentation_command"]) != TYPE_DICTIONARY \
			or typeof(request["physical_completion_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_presentation_completion", "both members must be dictionaries", {})
	var command: Dictionary = request["presentation_command"]
	var owner_receipt: Dictionary = request["physical_completion_receipt"]
	var completion_id := str(command.get("completion_transaction_id", ""))
	if not _commands.has(completion_id):
		return _fail(&"physical_completion_untrusted",
			"this port issued no command for that completion transaction", {})
	if command != (_commands[completion_id] as Dictionary):
		return _fail(&"presentation_command_conflict",
			"the supplied command is not the one this port issued", {})
	var owner_shape := _exact_keys(owner_receipt, OWNER_RECEIPT_KEYS,
		&"physical_completion_untrusted")
	if not owner_shape.is_empty():
		return owner_shape
	if str(owner_receipt["owner_kind"]) != OWNER_KIND \
			or str(owner_receipt["status"]) != STATUS_COMPLETED \
			or str(owner_receipt["physical_token"]) != str(command["physical_token"]) \
			or str(owner_receipt["command_sha256"]) != str(command["command_sha256"]) \
			or str(owner_receipt["completion_transaction_id"]) != completion_id:
		return _fail(&"physical_completion_untrusted",
			"the physical receipt does not bind this exact command", {})

	var proven: Variant = _physical_owner.call(&"validate_physical_completion", {
		"presentation_command": command.duplicate(true),
		"physical_completion_receipt": owner_receipt.duplicate(true),
	})
	if typeof(proven) != TYPE_DICTIONARY or not (proven as Dictionary).get("ok", false):
		return _fail(&"physical_completion_untrusted",
			"the configured owner refused the physical receipt",
			{"cause": (proven as Dictionary).get("code", &"") if typeof(proven) == TYPE_DICTIONARY else &"invalid_result"})

	var receipt := {
		"receipt_id": completion_id,
		"receipt_provenance": (command["completion_transaction_provenance"] as Dictionary).duplicate(true),
		"resolution_id": str(command["resolution_id"]),
		"stage_id": str(command["stage_id"]),
		"substage_id": str(command["substage_id"]),
		"route_id": ROUTE_ID,
		"timeline_id": str(command["timeline_id"]),
		"command_sha256": str(command["command_sha256"]),
		"physical_owner_kind": OWNER_KIND,
		"physical_token": str(command["physical_token"]),
		"physical_completion_receipt": owner_receipt.duplicate(true),
	}
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != COMPLETION_RECEIPT_KEYS:
		return _fail(&"invalid_presentation_completion",
			"the completion receipt member set is not exact", {})
	if _settled.has(completion_id):
		if receipt != (_settled[completion_id] as Dictionary):
			return _fail(&"physical_completion_conflict",
				"this completion transaction already settled with different bytes", {})
		return _completion_result(receipt)
	_settled[completion_id] = receipt.duplicate(true)
	return _completion_result(receipt)


func is_ready() -> bool:
	return _identity_issuer != null and _physical_owner != null



func _validate_request(request: Dictionary) -> Dictionary:
	if typeof(request) != TYPE_DICTIONARY:
		return _fail(&"invalid_presentation_intent", "the request must be a dictionary", {})
	var shaped := _exact_keys(request, REQUEST_KEYS, &"invalid_presentation_intent")
	if not shaped.is_empty():
		return shaped
	for field: String in ["resolution_id", "stage_id", "substage_id", "timeline_id",
			"completion_transaction_id"]:
		if not _is_nonblank_string(request[field]):
			return _fail(&"invalid_presentation_intent", field + " must be a nonblank String", {})
	if str(request["route_id"]) != ROUTE_ID:
		return _fail(&"presentation_route_mismatch",
			"this port routes only " + ROUTE_ID, {"route_id": request["route_id"]})
	if not DialogicTimelineCatalog.has_timeline_id(str(request["timeline_id"])):
		return _fail(&"unregistered_presentation_timeline",
			"the locator is not registered in DialogicTimelineCatalog",
			{"timeline_id": request["timeline_id"]})
	var context_error := _context_error(request["context"])
	if context_error != "":
		return _fail(&"invalid_presentation_context", context_error, {})
	if typeof(request["resolution_issuer_receipt"]) != TYPE_DICTIONARY \
			or typeof(request["completion_transaction_provenance"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_presentation_intent",
			"the root receipt and child provenance must be dictionaries", {})

	var root: Dictionary = request["resolution_issuer_receipt"]
	var verified: Variant = _identity_issuer.call(&"verify_issued", root.duplicate(true),
		ROOT_PURPOSE)
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"presentation_root_unverified",
			"the resolution issuer receipt did not verify", {})
	return _validate_completion_child(request, root)


func _validate_completion_child(request: Dictionary, root: Dictionary) -> Dictionary:
	var provenance: Dictionary = request["completion_transaction_provenance"]
	var revalidated: Variant = _identity_issuer.call(&"validate_child", provenance.duplicate(true),
		COMPLETION_CHILD_KIND)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return _fail(&"presentation_completion_unverified",
			"the completion provenance did not revalidate through the issuer", {})
	if str(provenance.get("child_id", "")) != str(request["completion_transaction_id"]):
		return _fail(&"presentation_completion_unverified",
			"the completion id disagrees with its own provenance", {})
	if str(provenance.get("parent_receipt_id", "")) != str(root.get("receipt_id", "")):
		return _fail(&"presentation_completion_unverified",
			"the completion child is not parented to this resolution root", {})

	var expected := _completion_sources(request)
	if expected.is_empty():
		return _fail(&"invalid_presentation_intent",
			"the completion projection is not canonically representable", {})
	var actual: Variant = provenance.get("source_ids")
	if typeof(actual) != TYPE_ARRAY or (actual as Array) != expected:
		return _fail(&"presentation_completion_unverified",
			"the completion provenance does not project these exact bytes",
			{"expected": expected, "actual": actual})
	return _ok({"validated": true})


func _completion_sources(request: Dictionary) -> Array:
	var context_hash: Dictionary = _STATE_SCHEMA.canonical_sha256(request["context"])
	if not context_hash.get("ok", false):
		return []
	var tokens: Array = [
		_project("role", COMPLETION_ROLE),
		_project("resolution_id", str(request["resolution_id"])),
		_project("stage_id", str(request["stage_id"])),
		_project("substage_id", str(request["substage_id"])),
		_project("route_id", ROUTE_ID),
		_project("timeline_id", str(request["timeline_id"])),
		_project("context_sha256", str((context_hash["value"] as Dictionary)["sha256"])),
	]
	for token: String in tokens:
		if token.is_empty():
			return []
	tokens.sort()
	return tokens


func _context_error(context: Variant) -> String:
	if typeof(context) != TYPE_DICTIONARY:
		return "context must be a dictionary"
	if _frozen_contexts_required or context.has("presentation"):
		var checked := _FROZEN_CONTEXT.validate(context)
		return "" if checked.get("ok", false) else str(checked.get("code", &"hospital_frozen_context_invalid"))
	var keys: Array = (context as Dictionary).keys()
	keys.sort()
	if keys != CONTEXT_KEYS:
		return "the context member set is not exact: " + str(keys)
	var detached: Dictionary = context as Dictionary
	if str(detached["kind"]) != CONTEXT_KIND:
		return "the Hospital context kind is exactly " + CONTEXT_KIND
	if typeof(detached["day"]) != TYPE_INT or int(detached["day"]) < 1 or int(detached["day"]) > 7:
		return "day must be an int in 1..7"
	for field: String in ["source_entry_ids", "miss_receipt_ids"]:
		var value: Variant = detached[field]
		if typeof(value) != TYPE_ARRAY:
			return field + " must be an Array of String"
		var seen := {}
		var previous := ""
		for element: Variant in (value as Array):
			if typeof(element) != TYPE_STRING or str(element).strip_edges().is_empty():
				return field + " must be an Array of nonblank String"
			if seen.has(str(element)):
				return field + " must be unique"
			if previous != "" and str(element) < previous:
				return field + " must be sorted"
			seen[str(element)] = true
			previous = str(element)
	return ""



func _on_physical_completion_ready(receipt: Dictionary) -> void:
	if typeof(receipt) != TYPE_DICTIONARY:
		completion_failed.emit(_fail(&"physical_completion_untrusted",
			"the owner emitted a non-dictionary receipt", {}))
		return
	var completion_id := str(receipt.get("completion_transaction_id", ""))
	if not _commands.has(completion_id):
		completion_failed.emit(_fail(&"physical_completion_untrusted",
			"no in-flight command matches the emitted completion",
			{"completion_transaction_id": completion_id}))
		return
	var already_settled := _settled.has(completion_id)
	var result := complete({
		"presentation_command": (_commands[completion_id] as Dictionary).duplicate(true),
		"physical_completion_receipt": receipt.duplicate(true),
	})
	if not result.get("ok", false):
		completion_failed.emit(result)
		return
	if already_settled: return
	completion_ready.emit(result)


func _on_physical_completion_failed(failure: Dictionary) -> void:
	completion_failed.emit(failure.duplicate(true) if typeof(failure) == TYPE_DICTIONARY
		else _fail(&"physical_presentation_failed", "the owner failed without a result", {}))



func _owner_error(physical_owner: Object) -> String:
	if physical_owner == null or not _has_methods(physical_owner, _OWNER_METHODS):
		return "the physical owner contract is incomplete"
	if not physical_owner.has_signal("physical_completion_ready") \
			or not physical_owner.has_signal("physical_completion_failed"):
		return "the physical owner declares no completion signals"
	if physical_owner.get_script() != _NARRATIVE_OWNER:
		return "the Hospital port accepts only DialogicPresentationOwnerAdapter"
	if not physical_owner.has_method("owner_kind") \
			or str(physical_owner.call(&"owner_kind")) != OWNER_KIND:
		return "the physical owner does not declare owner_kind=" + OWNER_KIND
	return ""


static func _completion_result(receipt: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok",
		"value": {"completion_receipt": receipt.duplicate(true)},
		"receipt": receipt.duplicate(true)}


static func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = _STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


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


static func _is_nonblank_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty()


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
