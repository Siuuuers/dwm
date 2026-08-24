class_name GameStateDesktopConditionContextPort
extends RefCounted

## Read-only condition-context adapter over the retained GameState facade (Plan 03 Task 7 line 854,
## created ahead of the full task under the dwm-oyo.3 slice authority recorded 2026-08-24 on
## dwm-p2r.21 / dwm-oyo.3).
##
## THE SEAM. `DesktopConditionPolicyPort` owns the faint predicate but no state: everything it reads
## arrives through `snapshot_for()`, and every child it persists derives through `derive_child()` /
## `validate_child()` below -- so the one `.16` issuer stays the sole identity root and the policy
## never touches GameState directly.
##
## SLICE SCOPE, stated honestly. This port validates the two frozen Plan-02 receipts against each
## other and against the live lifecycle identity, and captures the exact 11-key context. The full
## Task-7 depth -- action-outbox ownership proof and the Contacts accepted/read-state refinement of
## "unfulfilled" -- remains owned by Plan 03 Task 7; today's capture takes the current day's issued
## Schedule source receipts as the consumable set, which is the whole set Plan 01 can have issued.

const ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")

const _ISSUER_METHODS: Array[String] = ["derive_child", "validate_child", "verify_issued"]
const _GAME_STATE_METHODS: Array[String] = ["get_stat", "capture_run_snapshot_input"]
const _REQUEST_KEYS: Array[String] = ["action_receipt", "causal_sequence_receipt"]
## The exact Plan-02 causal-sequence receipt member set (Plan 03 line 99), sorted.
const _SEQUENCE_RECEIPT_KEYS: Array[String] = [
	"branch_id", "causal_day_instance", "causal_sequence", "desktop_timeline_generation",
	"receipt_id", "receipt_provenance", "run_id", "run_revision", "source_commit_receipt_id",
	"source_commit_receipt_provenance", "source_kind", "transaction_id",
	"transaction_issuer_receipt",
]

var _game_state: Object = null
var _identity_issuer: Object = null


func configure(game_state: Object, identity_issuer: Object) -> Dictionary:
	if game_state == null or not _has_methods(game_state, _GAME_STATE_METHODS) \
			or identity_issuer == null or not _has_methods(identity_issuer, _ISSUER_METHODS):
		return {"ok": false, "code": &"invalid_context_configuration",
			"message": "the exact GameState facade and Plan-02 issuer are required", "details": {}}
	if _game_state != null or _identity_issuer != null:
		if _game_state != game_state or _identity_issuer != identity_issuer:
			return {"ok": false, "code": &"context_port_conflict",
				"message": "a configured context port never adopts a replacement owner", "details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_game_state = game_state
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


## Captures the exact 11-key condition context for ONE validated action/sequence receipt pair.
## Read-only: nothing on the facade is mutated and every returned member is detached.
func snapshot_for(request: Dictionary) -> Dictionary:
	if _game_state == null or _identity_issuer == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	var keys: Array = request.keys()
	keys.sort()
	if keys != _REQUEST_KEYS:
		return {"ok": false, "code": &"context_request_invalid",
			"message": "the request is exactly {action_receipt, causal_sequence_receipt}", "details": {}}
	var receipt_valid: Dictionary = ACTION_RECEIPT.validate(request["action_receipt"])
	if not receipt_valid.get("ok", false):
		return receipt_valid
	var action_receipt: Dictionary = (receipt_valid["value"] as Dictionary)["receipt"]
	if typeof(request["causal_sequence_receipt"]) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"context_request_invalid",
			"message": "causal_sequence_receipt must be an object", "details": {}}
	var sequence_receipt: Dictionary = request["causal_sequence_receipt"]
	var sequence_keys: Array = sequence_receipt.keys()
	sequence_keys.sort()
	if sequence_keys != _SEQUENCE_RECEIPT_KEYS:
		return {"ok": false, "code": &"context_request_invalid",
			"message": "causal_sequence_receipt must carry the exact Plan-02 member set", "details": {}}
	var mismatch := _receipts_mismatch(action_receipt, sequence_receipt)
	if mismatch != "":
		return {"ok": false, "code": &"context_receipts_mismatch", "message": mismatch, "details": {}}
	var unlock_ids: Array = action_receipt.get("unlock_receipt_ids", [])
	var sources := _current_day_sources(int(action_receipt["day"]), unlock_ids)
	return {"ok": true, "code": &"ok", "value": {"context": {
		"run_id": str(action_receipt["run_id"]),
		"branch_id": str(action_receipt["branch_id"]),
		"desktop_timeline_generation": int(action_receipt["desktop_timeline_generation"]),
		"causal_day_instance": str(action_receipt["causal_day_instance"]),
		"day": int(action_receipt["day"]),
		"run_revision": int(sequence_receipt["run_revision"]),
		"dark_mode": _dark_mode_active(),
		"schedule_done_state": _schedule_done_state(),
		"condition_after": {
			"health": int(_game_state.call(&"get_stat", "health")),
			"pressure": int(_game_state.call(&"get_stat", "pressure")),
			"carried_sequela": (_game_state.get("condition_effects_today") as Array).has("sequela"),
		},
		"accepted_unfulfilled_sources": sources,
		"sylvia_read_source_receipt": _sylvia_source(sources),
	}}, "receipt": {}}


## Delegates child derivation to the one retained issuer; the policy port never holds the issuer.
func derive_child(request: Dictionary) -> Dictionary:
	if _identity_issuer == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	var derived: Variant = _identity_issuer.call(&"derive_child", request)
	return derived if typeof(derived) == TYPE_DICTIONARY else {
		"ok": false, "code": &"context_child_unavailable", "message": "", "details": {}}


func validate_child(provenance: Dictionary, expected_kind: StringName) -> Dictionary:
	if _identity_issuer == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	var validated: Variant = _identity_issuer.call(&"validate_child", provenance, expected_kind)
	return validated if typeof(validated) == TYPE_DICTIONARY else {
		"ok": false, "code": &"context_child_unavailable", "message": "", "details": {}}


## The receipts must describe ONE transaction inside the CURRENT live identity. The lifecycle is the
## authority for run/branch/generation/causal-day/day, exactly as `GameStateDayResolutionPort` reads
## it; `run_revision` stays receipt-supplied because the consequence state, not GameState, owns it.
func _receipts_mismatch(action_receipt: Dictionary, sequence_receipt: Dictionary) -> String:
	if str(sequence_receipt["transaction_id"]) != str(action_receipt["transaction_id"]):
		return "the sequence receipt settles another transaction"
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if str(sequence_receipt[key]) != str(action_receipt[key]):
			return "the two receipts disagree on " + key
	if int(sequence_receipt["desktop_timeline_generation"]) \
			!= int(action_receipt["desktop_timeline_generation"]):
		return "the two receipts disagree on desktop_timeline_generation"
	var live_identity: Dictionary = _game_state._run_lifecycle.get_desktop_identity_context()
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if str(action_receipt[key]) != str(live_identity[key]):
			return "the receipts name another live " + key
	if int(action_receipt["desktop_timeline_generation"]) \
			!= int(live_identity["desktop_timeline_generation"]):
		return "the receipts name another live desktop_timeline_generation"
	if int(action_receipt["day"]) != int(_game_state._run_lifecycle.get_day()):
		return "the receipts name a day the live lifecycle is not in"
	return ""


## The current day's issued Schedule source receipts, sorted by (action_id, receipt_id), minus any
## receipt the CURRENT action itself unlocked -- an unlock emitted by the current action is not a
## read receipt (Plan 03 line 872).
func _current_day_sources(day: int, unlock_receipt_ids: Array) -> Array:
	var index: Variant = (_game_state.get("contacts") as Dictionary).get("schedule_source_receipts")
	if typeof(index) != TYPE_DICTIONARY:
		return []
	var sources: Array = []
	for receipt_id: Variant in (index as Dictionary):
		var source: Variant = (index as Dictionary)[receipt_id]
		if typeof(source) != TYPE_DICTIONARY:
			continue
		if int((source as Dictionary).get("day", -1)) != day:
			continue
		if unlock_receipt_ids.has(str(receipt_id)):
			continue
		sources.append((source as Dictionary).duplicate(true))
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["action_id"]) != str(b["action_id"]):
			return str(a["action_id"]) < str(b["action_id"])
		return str(a["receipt_id"]) < str(b["receipt_id"]))
	return sources


## The first (already-sorted) consumable source naming Sylvia, or null. Detached: the same capture
## the sources array carries, duplicated again so the two projections never alias.
func _sylvia_source(sources: Array) -> Variant:
	for source: Variant in sources:
		if ((source as Dictionary).get("participants", []) as Array).has("sylvia"):
			return (source as Dictionary).duplicate(true)
	return null


func _dark_mode_active() -> bool:
	var routes: Variant = _game_state.get("dating_route_state")
	if typeof(routes) != TYPE_DICTIONARY:
		return false
	for friend_id: Variant in (routes as Dictionary):
		var route: Variant = (routes as Dictionary)[friend_id]
		if typeof(route) == TYPE_DICTIONARY and int((route as Dictionary).get("dark_points", 0)) >= 2:
			return true
	return false


## `open | committed | resolving` (Plan 03 line 854). Resolving means an ACTIVE, incomplete
## resolution plan; a completed plan is deliberately never cleared (RunLifecycle's own succession
## law), so completeness -- not presence -- is the discriminator. Committed means the current day's
## canonical committed aggregate carries its commit receipt.
func _schedule_done_state() -> String:
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(plan) == TYPE_DICTIONARY:
		var complete := true
		for stage_value: Variant in ((plan as Dictionary).get("stages", []) as Array):
			if str((stage_value as Dictionary).get("state", "")) != "completed":
				complete = false
				break
		if not complete:
			return "resolving"
	var aggregate: Dictionary = _game_state._canonical_committed_schedule()
	if typeof(aggregate.get("commit_receipt")) == TYPE_DICTIONARY:
		return "committed"
	return "open"


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true
