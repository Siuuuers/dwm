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
## CONDITION TRUTH IS NEVER FABRICATED. `resolve_condition_receipt` returns only the day's latest
## policy-produced condition receipt retained by the one shared `DesktopConsequenceCoordinator`
## after a fully committed action transaction; when no action committed one, it fails closed as
## `condition_receipt_unavailable` and the Hospital site stays honestly unreachable -- exactly the
## DEVIATION-5 fail-closed law, now scoped to the one record that genuinely has no producer yet.
##
## `identity_context` is the bootstrap-retained issuer-backed run/branch context -- the same
## recorded placeholder posture the desktop board and shop ports already run under (dwm-p2r.32.8's
## honest-gap note); a resolved per-run identity arrives with the full New-Run allocation work.

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
var _identity_context: Dictionary = {}
## causal_day_instance -> the settled board-fate receipt, so one causal day departs exactly once.
var _board_fates: Dictionary = {}


func configure(consequence_coordinator: Object, board_fate_port: Object,
		identity_issuer: Object, identity_context: Dictionary) -> Dictionary:
	if consequence_coordinator == null \
			or not _has_methods(consequence_coordinator, _COORDINATOR_METHODS) \
			or board_fate_port == null or not _has_methods(board_fate_port, _BOARD_FATE_METHODS) \
			or identity_issuer == null or not _has_methods(identity_issuer, _ISSUER_METHODS):
		return {"ok": false, "code": &"invalid_consequence_source_configuration",
			"message": "the coordinator, board-fate port, and issuer capabilities are required",
			"details": {}}
	var context_keys: Array = identity_context.keys()
	context_keys.sort()
	if context_keys != _CONTEXT_KEYS \
			or str(identity_context["run_id"]).strip_edges().is_empty() \
			or str(identity_context["branch_id"]).strip_edges().is_empty():
		return {"ok": false, "code": &"invalid_consequence_source_configuration",
			"message": "identity_context must be the exact 4-key issuer-backed context", "details": {}}
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
	_identity_context = identity_context.duplicate(true)
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


func resolve_board_fate_receipt(request: Dictionary) -> Dictionary:
	var shaped := _validate_request(request)
	if not shaped.get("ok", false):
		return shaped
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
		"run_id": str(_identity_context["run_id"]),
		"branch_id": str(_identity_context["branch_id"]),
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
	var causal_day_instance := str(request["causal_day_instance"])
	var retained: Variant = _consequence_coordinator.call(
		&"committed_condition_receipt", causal_day_instance)
	if typeof(retained) != TYPE_DICTIONARY or (retained as Dictionary).is_empty() \
			or int((retained as Dictionary).get("day", -1)) != int(request["source_day"]):
		return {"ok": false, "code": &"condition_receipt_unavailable",
			"message": "no committed action has produced this day's condition receipt",
			"details": {}}
	return {"ok": true, "code": &"ok", "value": {
		"condition_receipt": (retained as Dictionary).duplicate(true),
	}, "receipt": {}}


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
