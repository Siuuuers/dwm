class_name MinesweeperCapabilityRules
extends RefCounted

## Lucky Charm / Debug Key / Supportz capability composition and eligibility rules
## (Plan 02 Task 2, dwm-p2r.32.1), per amendment SS7.1-7.2, 8.
##
## Pure domain rules: no board, save, currency, or shop-purchase mutation happens here. Every
## function is a deterministic projection of its explicit inputs onto the frozen board-capability
## vocabulary and Supportz signed round floor; callers apply the produced effects/spec inputs.
## Item facts (capability_ids, price, cap, effect_ids) are read live from MinesweeperShopRegistry
## on every call -- never cached or copied into a local table here.

const _SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")

const _OWNED_KEYS := ["capability_ids"]
const _SUPPORTZ_STATE_KEYS := [
	"causal_day_instance", "completion_receipts", "branch_purchase_count", "daily_purchase_done",
]
const _COMPLETION_RECEIPT_KEYS := ["kind", "app_round_ordinal", "causal_day_instance"]

const _COMPLETE_KIND := "complete"
const _BASE_ORDINALS := [1, 2]
const _MAX_BRANCH_PURCHASES := 3


# ---- capability composition ----

static func resolve_owned(inventory: Dictionary) -> Dictionary:
	var owned_ids: Dictionary = {"first_cell_safe": true}
	for item_id: String in _SHOP_REGISTRY.get_ids():
		if not _owns(inventory, item_id):
			continue
		var fetched: Dictionary = _SHOP_REGISTRY.get_record(item_id)
		if not fetched.get("ok", false):
			return _fail(&"capability_registry_unavailable",
				"the shop registry could not resolve %s" % item_id,
				{"item_id": item_id, "cause": fetched.get("code", &"")})
		var record: Dictionary = (fetched.get("value", {}) as Dictionary).get("record", {}) as Dictionary
		for cap_id: Variant in (record.get("capability_ids", []) as Array):
			owned_ids[str(cap_id)] = true
	var capability_ids: Array[String] = []
	for cap_id: String in _SHOP_REGISTRY.CAPABILITY_UNION:
		if owned_ids.has(cap_id):
			capability_ids.append(cap_id)
	return _ok({"capability_ids": capability_ids})


# ---- BoardSpec extras projection: raw_extra = floor(pressure / 3) + penalty_points_today ----

static func build_spec_inputs(owned: Dictionary, pressure: int, penalty_points_today: int) -> Dictionary:
	var shape := _exact_keys(owned, _OWNED_KEYS, &"owned_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	var capability_ids_value: Variant = owned["capability_ids"]
	if typeof(capability_ids_value) != TYPE_ARRAY:
		return _fail(&"invalid_capability_ids", "capability_ids must be an array", {})
	var capability_ids: Array[String] = []
	for entry: Variant in (capability_ids_value as Array):
		if typeof(entry) != TYPE_STRING:
			return _fail(&"invalid_capability_ids", "capability_ids must contain only strings", {})
		capability_ids.append(str(entry))

	var raw_extra_mines: int = floori(float(pressure) / 3.0) + penalty_points_today
	var has_zero := capability_ids.has("first_cell_zero")
	var forced_no_guess := capability_ids.has("forced_no_guess")
	var effective_extra_mines := (floori(float(raw_extra_mines) / 2.0) if has_zero else raw_extra_mines)

	return _ok({
		"capability_ids": capability_ids,
		"pressure": pressure,
		"penalty_points_today": penalty_points_today,
		"raw_extra_mines": raw_extra_mines,
		"effective_extra_mines": effective_extra_mines,
		"forced_no_guess": forced_no_guess,
	})


# ---- Supportz: two-completion eligibility (SS8.3-8.4) ----

static func supportz_eligible(state: Dictionary) -> Dictionary:
	var counted := _count_qualifying_base_completions(state)
	if not counted.get("ok", false):
		return counted
	var branch_purchase_count: int = int(state["branch_purchase_count"])
	var daily_purchase_done: bool = bool(state["daily_purchase_done"])
	var eligible: bool = bool(counted["value"]) \
		and branch_purchase_count < _MAX_BRANCH_PURCHASES \
		and not daily_purchase_done
	return _ok({"eligible": eligible})


# ---- Supportz: prospective signed round-floor effect (SS8.4) ----

static func prepare_supportz_effect(state: Dictionary, causal_day_instance: String,
		transaction_id: String) -> Dictionary:
	var eligibility := supportz_eligible(state)
	if not eligibility.get("ok", false):
		return eligibility
	if not bool((eligibility["value"] as Dictionary)["eligible"]):
		return _fail(&"supportz_not_eligible",
			"supportz purchase eligibility requirements are not met", {})
	if causal_day_instance.strip_edges().is_empty():
		return _fail(&"invalid_causal_day_instance", "causal_day_instance must be nonblank", {})
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "transaction_id must be nonblank", {})

	var fetched: Dictionary = _SHOP_REGISTRY.get_record("supportz")
	if not fetched.get("ok", false):
		return _fail(&"capability_registry_unavailable",
			"the shop registry could not resolve supportz", {"cause": fetched.get("code", &"")})
	var record: Dictionary = (fetched.get("value", {}) as Dictionary).get("record", {}) as Dictionary
	var effect_ids: Array = record.get("effect_ids", [])
	if effect_ids.size() != 1:
		return _fail(&"invalid_supportz_effect_registration",
			"the supportz registry record must declare exactly one effect id",
			{"effect_ids": effect_ids})
	var effect_id: String = str(effect_ids[0])

	var branch_purchase_count: int = int(state["branch_purchase_count"])
	var previous_round_floor: int = -branch_purchase_count
	var new_round_floor: int = -(branch_purchase_count + 1)

	return _ok({
		"effect_id": effect_id,
		"previous_round_floor": previous_round_floor,
		"new_round_floor": new_round_floor,
		"causal_day_instance": causal_day_instance,
		"transaction_id": transaction_id,
	})


# ---- helpers ----

static func _owns(inventory: Dictionary, item_id: String) -> bool:
	if not inventory.has(item_id):
		return false
	var value: Variant = inventory[item_id]
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value > 0
		_:
			return false


## Counts the set of qualifying (kind=complete, matching causal_day_instance, ordinal in {1,2})
## receipts and requires BOTH base ordinals present -- not merely two receipts.
static func _count_qualifying_base_completions(state: Dictionary) -> Dictionary:
	var shape := _exact_keys(state, _SUPPORTZ_STATE_KEYS, &"supportz_state_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	var causal_day_instance: Variant = state["causal_day_instance"]
	if typeof(causal_day_instance) != TYPE_STRING or str(causal_day_instance).strip_edges().is_empty():
		return _fail(&"invalid_causal_day_instance", "causal_day_instance must be a nonblank string", {})
	var receipts: Variant = state["completion_receipts"]
	if typeof(receipts) != TYPE_ARRAY:
		return _fail(&"invalid_completion_receipts", "completion_receipts must be an array", {})
	var branch_purchase_count: Variant = state["branch_purchase_count"]
	if typeof(branch_purchase_count) != TYPE_INT or int(branch_purchase_count) < 0:
		return _fail(&"invalid_branch_purchase_count",
			"branch_purchase_count must be a nonnegative integer", {})
	var daily_purchase_done: Variant = state["daily_purchase_done"]
	if typeof(daily_purchase_done) != TYPE_BOOL:
		return _fail(&"invalid_daily_purchase_done", "daily_purchase_done must be a boolean", {})

	var qualifying_ordinals: Dictionary = {}
	for entry: Variant in (receipts as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"malformed_completion_receipt", "every completion receipt must be a dictionary", {})
		var receipt_shape := _exact_keys(entry, _COMPLETION_RECEIPT_KEYS, &"malformed_completion_receipt")
		if not receipt_shape.get("ok", false):
			return receipt_shape
		var receipt: Dictionary = entry
		if str(receipt["kind"]) != _COMPLETE_KIND:
			continue
		if str(receipt["causal_day_instance"]) != str(causal_day_instance):
			continue
		var ordinal: Variant = receipt["app_round_ordinal"]
		if typeof(ordinal) != TYPE_INT or not _BASE_ORDINALS.has(int(ordinal)):
			continue
		qualifying_ordinals[int(ordinal)] = true

	return {"ok": true, "value": qualifying_ordinals.size() == _BASE_ORDINALS.size()}


static func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()],
			{"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
