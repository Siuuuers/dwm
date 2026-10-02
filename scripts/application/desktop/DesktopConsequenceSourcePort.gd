class_name DesktopConsequenceSourcePort
extends RefCounted

## The ONE production desktop-consequence source for a Schedule-Done resolution -- the object
## `GameStateDayResolutionPort.configure_desktop_consequence_source()` retains, finishing
## DEVIATION-5's truthful remainder (dwm-oyo.3 slice authorized 2026-08-24 on dwm-p2r.21 /
## dwm-oyo.3). The seam demands `resolve_board_fate_receipt` and `resolve_condition_receipt` on one
## object (dwm-p2r.32.8); this adapter composes the two real owners behind that one surface.
##
## BOARD FATE IS A REAL DEPARTURE. `resolve_board_fate_receipt` settles the live board's
## Schedule-Done fate through the retained `DesktopBoardFatePort` -- mint one command root through
## the one `.16` issuer, `prepare_causal_departure(reason="schedule_done")` against the board's own
## current identity/revision, `commit()`, then `publish()` into the desktop publication ledger --
## and retains the receipt per `causal_day_instance`, so a replayed resolution binds the SAME board
## fate rather than departing a second time (the law `FakeDesktopConsequenceSource` documented as
## "what the real ports will do"). ONCE THE PLAN IS PERSISTED a replayed Done command never reaches
## this seam at all: `GameStateDayResolutionPort._resolution_start` answers it from the persisted
## active plan. Before that checkpoint a narrow window remains -- the board fate publishes ahead of
## `begin_day_resolution` -- in which a crash-replay mints a second departure under a fresh command
## root, which the `command_id`-keyed idempotency cannot dedupe. It is the same window the
## resolution root already carries, and Plan-03 Tasks 1-5 own closing it.
##
## Schedule Done consumes the condition outcome already committed by its current run. Its child
## receipt derives under the persisted day-resolution root, so a new process reconstructs the same
## ancestry without depending on earlier board/Shop actions or applying condition penalties again.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _COORDINATOR_METHODS: Array[String] = ["committed_condition_receipt"]
const _BOARD_FATE_METHODS: Array[String] = [
	"prepare_causal_departure", "commit", "publish", "capture",
]
const _ISSUER_METHODS: Array[String] = ["issue"]
const _CONTEXT_KEYS: Array[String] = [
	"branch_id", "causal_day_instance", "desktop_timeline_generation", "run_id",
]
const _REQUEST_KEYS: Array[String] = ["causal_day_instance", "source_day"]

var _consequence_coordinator: Object = null
var _board_fate_port: Object = null
var _identity_issuer: Object = null
var _identity_context: Variant = {}
var _current_condition_owner: Object = null
## causal_day_instance -> the settled board-fate receipt, so one causal day departs exactly once.
var _board_fates: Dictionary = {}


func configure(consequence_coordinator: Object, board_fate_port: Object,
		identity_issuer: Object, identity_context: Variant) -> Dictionary:
	if consequence_coordinator == null \
			or not _has_methods(consequence_coordinator, _COORDINATOR_METHODS) \
			or board_fate_port == null or not _has_methods(board_fate_port, _BOARD_FATE_METHODS) \
			or identity_issuer == null or not _has_methods(identity_issuer, _ISSUER_METHODS):
		return {"ok": false, "code": &"invalid_consequence_source_configuration",
			"message": "the coordinator, board-fate port, and issuer capabilities are required",
			"details": {}}
	if identity_context is Callable:
		if not identity_context.is_valid() or identity_context.get_argument_count() != 0:
			return {"ok": false, "code": &"invalid_consequence_source_configuration"}
	elif not _valid_identity_context(identity_context):
		return {"ok": false, "code": &"invalid_consequence_source_configuration"}
	if _consequence_coordinator != null:
		if _consequence_coordinator != consequence_coordinator \
				or _board_fate_port != board_fate_port or _identity_issuer != identity_issuer \
				or _identity_context != identity_context:
			return {"ok": false, "code": &"consequence_source_conflict",
				"message": "a configured source never adopts a replacement owner", "details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_consequence_coordinator = consequence_coordinator
	_board_fate_port = board_fate_port
	_identity_issuer = identity_issuer
	_identity_context = identity_context.duplicate(true) if identity_context is Dictionary else identity_context
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


func configure_current_condition_owner(game_state: Object) -> Dictionary:
	if game_state == null or not _has_methods(game_state, ["capture_run_snapshot_input", "should_route_hospital"]) \
			or _identity_issuer == null or not _has_methods(_identity_issuer, ["derive_child", "validate_child", "verify_issued"]):
		return {"ok": false, "code": &"invalid_current_condition_owner"}
	if _current_condition_owner != null and _current_condition_owner != game_state:
		return {"ok": false, "code": &"current_condition_owner_conflict"}
	_current_condition_owner = game_state
	return {"ok": true, "code": &"ok"}


func resolve_board_fate_receipt(request: Dictionary) -> Dictionary:
	var shaped := _validate_request(request)
	if not shaped.get("ok", false):
		return shaped
	var current: Variant = _identity_context.call() if _identity_context is Callable \
		else {"ok": true, "value": _identity_context}
	if not current is Dictionary or not current.get("ok", false):
		return current if current is Dictionary else {"ok": false, "code": &"invalid_desktop_identity_context"}
	if not _valid_identity_context(current.get("value")):
		return {"ok": false, "code": &"invalid_desktop_identity_context"}
	var identity: Dictionary = current.value
	if _identity_context is Callable and identity.causal_day_instance != request.causal_day_instance:
		return {"ok": false, "code": &"stale_desktop_identity"}
	var causal_day_instance := str(request["causal_day_instance"])
	if _board_fates.has(causal_day_instance):
		return {"ok": true, "code": &"ok", "value": {
			"board_fate_receipt": (_board_fates[causal_day_instance] as Dictionary).duplicate(true),
		}, "receipt": {}}

	var issued: Variant = _identity_issuer.call(&"issue", &"transaction_id")
	if typeof(issued) != TYPE_DICTIONARY or not (issued as Dictionary).get("ok", false):
		return issued if typeof(issued) == TYPE_DICTIONARY else {
			"ok": false, "code": &"board_fate_root_unavailable",
			"message": "the issuer refused to mint a departure command root", "details": {}}
	var issued_value: Dictionary = (issued as Dictionary)["value"]

	var captured: Variant = _board_fate_port.call(&"capture")
	if typeof(captured) != TYPE_DICTIONARY or not (captured as Dictionary).get("ok", false):
		return captured if typeof(captured) == TYPE_DICTIONARY else {
			"ok": false, "code": &"board_fate_receipt_unavailable",
			"message": "the board-fate port returned no CommandResult", "details": {}}
	var live_board: Dictionary = ((captured as Dictionary)["value"] as Dictionary)["backup"]

	var prepared: Variant = _board_fate_port.call(&"prepare_causal_departure", {
		"command_id": str(issued_value["token"]),
		"command_issuer_receipt": (issued_value["issuer_receipt"] as Dictionary).duplicate(true),
		"run_id": str(identity["run_id"]),
		"branch_id": str(identity["branch_id"]),
		"causal_day_instance": causal_day_instance,
		"reason": "schedule_done",
		"expected_board_identity": _detached_or_null(live_board.get("identity")),
		"expected_board_revision": int(live_board.get("revision", 0)),
	})
	if typeof(prepared) != TYPE_DICTIONARY or not (prepared as Dictionary).get("ok", false):
		return prepared if typeof(prepared) == TYPE_DICTIONARY else {
			"ok": false, "code": &"board_fate_receipt_unavailable",
			"message": "the board-fate port returned no CommandResult", "details": {}}
	var prepared_value: Dictionary = (prepared as Dictionary)["value"]
	var board_candidate: Dictionary = prepared_value["board_candidate"]
	var board_fate_receipt: Dictionary = prepared_value["board_fate_receipt"]

	var committed: Variant = _board_fate_port.call(&"commit", board_candidate)
	if typeof(committed) != TYPE_DICTIONARY or not (committed as Dictionary).get("ok", false):
		return committed if typeof(committed) == TYPE_DICTIONARY else {
			"ok": false, "code": &"board_fate_receipt_unavailable",
			"message": "the board-fate port returned no CommandResult", "details": {}}
	var published: Variant = _board_fate_port.call(&"publish", {
		"board_candidate": board_candidate, "board_fate_receipt": board_fate_receipt,
	})
	if typeof(published) != TYPE_DICTIONARY or not (published as Dictionary).get("ok", false):
		return published if typeof(published) == TYPE_DICTIONARY else {
			"ok": false, "code": &"board_fate_receipt_unavailable",
			"message": "the board-fate port returned no CommandResult", "details": {}}

	_board_fates[causal_day_instance] = (board_fate_receipt as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {
		"board_fate_receipt": (board_fate_receipt as Dictionary).duplicate(true),
	}, "receipt": {}}


func resolve_condition_receipt(request: Dictionary) -> Dictionary:
	var shaped := _validate_request(request)
	if not shaped.get("ok", false):
		return shaped
	if _current_condition_owner == null:
		return _condition_unavailable("the current run condition owner is not configured")
	var snapshot: Dictionary = _current_condition_owner.call(&"capture_run_snapshot_input")
	var lifecycle: Dictionary = snapshot.get("lifecycle", {})
	var gameplay: Dictionary = snapshot.get("gameplay", {})
	var day := int(request["source_day"])
	var causal_day := str(request["causal_day_instance"])
	# A fresh Load may remap the live desktop continuation while retaining an unfinished
	# resolution from this same source day. The active plan below remains the authority for
	# that in-flight request: its persisted start must name this exact causal day and its
	# verified root. The live lifecycle still has to be on the same numeric day, so neither a
	# request from another day nor a foreign plan can borrow the restored gameplay outcome.
	if int(lifecycle.get("day", -1)) != day:
		return _condition_unavailable("the request names another live day")
	var plan: Dictionary = lifecycle.get("active_resolution_plan", {}) \
		if lifecycle.get("active_resolution_plan") is Dictionary else {}
	var root: Dictionary = plan.get("resolution_issuer_receipt", {}) \
		if plan.get("resolution_issuer_receipt") is Dictionary else {}
	var start: Dictionary = plan.get("day_resolution_start_receipt", {}) \
		if plan.get("day_resolution_start_receipt") is Dictionary else {}
	if int(plan.get("source_day", -1)) != day or int(start.get("source_day", -1)) != day \
			or str(start.get("causal_day_instance", "")) != causal_day \
			or str(plan.get("resolution_id", "")).is_empty() \
			or str(root.get("token", "")) != str(plan.get("resolution_id", "")) \
			or str(start.get("resolution_id", "")) != str(plan.get("resolution_id", "")):
		return _condition_unavailable("the current day has no matching persisted resolution root")
	var root_valid: Dictionary = _identity_issuer.call(&"verify_issued", root, &"transaction_id")
	if not root_valid.get("ok", false):
		return root_valid
	var provenance: Dictionary = start.get("receipt_provenance", {})
	var start_valid: Dictionary = _identity_issuer.call(&"validate_child", provenance, &"day_resolution_stage")
	if not start_valid.get("ok", false) or str(provenance.get("parent_receipt_id", "")) != str(root["receipt_id"]) \
			or str(provenance.get("child_id", "")) != str(start.get("receipt_id", "")):
		return _condition_unavailable("the resolution start is not a child of its persisted root")
	var outcome: Dictionary = gameplay.get("route_context", {}).get("provisional_hospital_resolution", {})
	if int(gameplay.get("condition_resolved_day", -1)) != day \
			or not bool(gameplay.get("pending_hospital", false)) \
			or not bool(_current_condition_owner.call(&"should_route_hospital")) \
			or outcome.get("required") != true:
		return _condition_unavailable("the current resolution has no committed Hospital condition outcome")
	var stats: Dictionary = gameplay.get("stats", {})
	if typeof(stats.get("health")) != TYPE_INT or typeof(stats.get("pressure")) != TYPE_INT \
			or not gameplay.get("condition_effects_today") is Array:
		return _condition_unavailable("the committed condition facts are incomplete")
	var condition := {
		"day": day, "causal_day_instance": causal_day, "resolution_id": str(plan["resolution_id"]),
		"day_resolution_start_receipt_id": str(start["receipt_id"]), "required": true,
		"condition_after": {"health": stats["health"], "pressure": stats["pressure"],
			"effects": gameplay["condition_effects_today"].duplicate(true)},
		"hospital_resolution": outcome.duplicate(true),
	}
	var serialized: Dictionary = _CANONICAL_JSON.stringify(condition)
	if not serialized.get("ok", false):
		return serialized
	var source_ids: Array = [
		"P(role,schedule_done.condition)", "P(resolution_id,%s)" % str(plan["resolution_id"]),
		"P(day_resolution_start_receipt_id,%s)" % str(start["receipt_id"]),
		"P(condition_result_sha256,%s)" % str(serialized["value"]).sha256_text(),
	]
	source_ids.sort()
	var derived: Dictionary = _identity_issuer.call(&"derive_child", {"child_kind": "condition", "ordinal": 0,
		"parent_receipt_id": str(root["receipt_id"]), "source_ids": source_ids})
	if not derived.get("ok", false):
		return derived
	var child: Dictionary = derived["value"]
	var verified: Dictionary = _identity_issuer.call(&"validate_child", child["provenance"], &"condition")
	if not verified.get("ok", false):
		return verified
	condition["receipt_id"] = str(child["child_id"])
	condition["receipt_provenance"] = child["provenance"].duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"condition_receipt": condition}, "receipt": {}}


static func _condition_unavailable(message: String) -> Dictionary:
	return {"ok": false, "code": &"condition_receipt_unavailable", "message": message, "details": {}}


func _validate_request(request: Dictionary) -> Dictionary:
	if _consequence_coordinator == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	var keys: Array = request.keys()
	keys.sort()
	if keys != _REQUEST_KEYS \
			or str(request["causal_day_instance"]).strip_edges().is_empty() \
			or typeof(request["source_day"]) != TYPE_INT:
		return {"ok": false, "code": &"consequence_source_request_invalid",
			"message": "the request is exactly {causal_day_instance, source_day}", "details": {}}
	return {"ok": true}


static func _detached_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	return (value as Dictionary).duplicate(true)


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


static func _valid_identity_context(context: Variant) -> bool:
	if not context is Dictionary: return false
	var keys: Array = context.keys()
	keys.sort()
	return keys == _CONTEXT_KEYS and typeof(context.run_id) == TYPE_STRING \
		and not context.run_id.is_empty() and typeof(context.branch_id) == TYPE_STRING \
		and not context.branch_id.is_empty()
