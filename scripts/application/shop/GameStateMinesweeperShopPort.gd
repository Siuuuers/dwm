class_name GameStateMinesweeperShopPort
extends RefCounted

## Production GameState-facing Shop purchase state port (Plan 02 Task 7, dwm-p2r.32.7,
## req.shop.capabilities). Mirrors GameStateDesktopBoardPort's established shape: injected GameState
## reference, prepare/commit/rollback/publish over detached candidates, no direct SaveManager,
## storage, or EffectResolver dependency. Untested directly (no dedicated unit-test suite is in
## Task 7's Create set), matching GameStateDesktopBoardPort's own precedent: proven exclusively
## through the participant's contract fake in unit tests, and through this real port in the
## integration suite.
##
## Interprets exactly the closed 3-item MinesweeperShopRegistry union itself rather than a generic
## effect-string execution path -- the frozen contract's own words: "no generic effect-string
## execution path". `lucky_charm`/`debug_key` grant their capability by permanent inventory
## ownership (their registry cap is "once per saved branch" with no per-causal-day component, so
## ownership IS the branch-scoped cap, checked here before any candidate is built). `supportz`
## spends money and decrements `minesweeper_round_floor` by exactly one via the SAME
## `change_minesweeper_round_floor(-1)` method the retained EffectResolver already uses for this
## effect id -- this port neither computes nor persists the per-branch Supportz purchase count
## itself (that ledger is `DesktopConsequenceState.shop_ledger`, per the Task-7 controller ruling);
## the participant cross-validates the two stay in lockstep (floor sequence 0,-1,-2,-3) before ever
## reaching this port.
##
## `desktop_identity_context` (run_id/branch_id/desktop_timeline_generation/causal_day_instance) is
## supplied at configure() time exactly like GameStateDesktopBoardPort, for the identical documented
## reason: neither is a GameState field yet, and this port may not edit GameState.gd to add one.

const _STAT_HEALTH := "health"
const _STAT_PRESSURE := "pressure"
const _CONDITION_SEQUELA := "sequela"

## The closed item-id union this port interprets. Kept separate from MinesweeperShopRegistry's own
## CAPABILITY_UNION: this list is about WHICH items grant a capability via inventory ownership, not
## which board capabilities exist.
const _CAPABILITY_ITEM_IDS: Array[String] = ["lucky_charm", "debug_key"]
const _SUPPORTZ_ITEM_ID := "supportz"

var _game_state: Object = null
var _desktop_identity_context: Dictionary = {}


## Idempotent on identical replay; a changed owner or context is refused before any mutation,
## mirroring every other configure seam in this codebase.
func configure(game_state: Object, desktop_identity_context: Dictionary) -> Dictionary:
	if game_state == null or not game_state.has_method("get_stat"):
		return _fail(&"invalid_game_state", "game_state must expose get_stat", {})
	var context_shape := _exact_keys(desktop_identity_context,
		["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"],
		&"invalid_desktop_identity_context")
	if not context_shape.get("ok", false):
		return context_shape
	if _game_state != null:
		if _game_state != game_state or _desktop_identity_context != desktop_identity_context:
			return _fail(&"port_already_configured", "a configured port never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_game_state = game_state
	_desktop_identity_context = desktop_identity_context.duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


func guard_external(_operation_id: StringName) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func capture() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var money: int = int(_game_state.money)
	var coins: int = int(_game_state.coins)
	var inventory: Dictionary = (_game_state.inventory as Dictionary).duplicate(true)
	var round_floor: int = int(_game_state.minesweeper_round_floor)
	var owned_item_ids: Dictionary = {}
	for item_id: String in _CAPABILITY_ITEM_IDS:
		owned_item_ids[item_id] = _owns(inventory, item_id)
	return {"ok": true, "code": &"ok", "value": {
		"run_id": str(_desktop_identity_context["run_id"]),
		"branch_id": str(_desktop_identity_context["branch_id"]),
		"desktop_timeline_generation": int(_desktop_identity_context["desktop_timeline_generation"]),
		"causal_day_instance": str(_desktop_identity_context["causal_day_instance"]),
		"day": int(_game_state.day),
		"money": money, "coins": coins,
		"health": _game_state.get_stat(_STAT_HEALTH), "pressure": _game_state.get_stat(_STAT_PRESSURE),
		"carried_sequela": (_game_state.condition_effects_today as Array).has(_CONDITION_SEQUELA),
		"owned_item_ids": owned_item_ids, "minesweeper_round_floor": round_floor,
		"backup": {
			"money": money, "coins": coins, "inventory": inventory.duplicate(true),
			"minesweeper_round_floor": round_floor,
		},
	}, "receipt": {}}


## Validates affordability and the Lucky/Debug once-per-branch ownership cap against LIVE GameState
## facts, then returns a detached candidate carrying only the item id / currency / price / capability
## grant (never precomputed absolute balances): `commit()` re-derives the actual mutation through
## GameState's own signal-emitting economy methods, so a race between prepare and commit fails
## closed there rather than silently overwriting a balance that moved in between.
func prepare_purchase(item: Dictionary, quote: Dictionary, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if typeof(transaction_issuer_receipt) != TYPE_DICTIONARY or transaction_issuer_receipt.is_empty():
		return _fail(&"invalid_transaction_issuer_receipt", "the transaction issuer receipt is required", {})
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "transaction_id must be nonblank", {})
	var item_id := str(item.get("item_id", ""))
	if item_id not in _CAPABILITY_ITEM_IDS and item_id != _SUPPORTZ_ITEM_ID:
		return _fail(&"unregistered_shop_item", "the item is not a known shop item", {"item_id": item_id})
	if str(quote.get("item_id", "")) != item_id:
		return _fail(&"quote_item_mismatch", "quote.item_id must match item.item_id", {})
	var currency := str(item.get("currency", ""))
	var price := int(item.get("price", -1))
	if str(quote.get("currency", "")) != currency or int(quote.get("price", -2)) != price:
		return _fail(&"quote_price_mismatch", "quote no longer matches the item's current price/currency", {})
	if currency != "money" and currency != "minesweeper_coin":
		return _fail(&"invalid_currency", currency, {})

	var captured := capture()
	if not captured.get("ok", false):
		return captured
	var facts: Dictionary = captured["value"]

	var is_capability_item := item_id in _CAPABILITY_ITEM_IDS
	if is_capability_item and bool((facts["owned_item_ids"] as Dictionary).get(item_id, false)):
		return _fail(&"shop_item_already_owned", "%s is already owned on this branch" % item_id, {})
	if not _can_afford(currency, price):
		return _fail(&"insufficient_funds", "not enough %s for %s" % [currency, item_id], {})

	var candidate := {
		"transaction_id": transaction_id, "item_id": item_id, "currency": currency, "price": price,
		"grant_inventory_item_id": item_id if is_capability_item else "",
	}
	return {"ok": true, "code": &"ok", "value": {
		"candidate": candidate, "backup": facts["backup"],
	}, "receipt": {}}


## The Task-7 boundary forward commit: this is called only once the participant's own commit() has
## confirmed the matching pending action transaction is already `sequence_committed`, so every call
## here is the audience-visible economy application. Re-validates affordability at commit time
## through GameState's own try_spend_*() (rather than trusting prepare_purchase()'s earlier check)
## so a balance that moved between prepare and commit fails closed instead of going negative.
func commit(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var currency := str(candidate.get("currency", ""))
	var price := int(candidate.get("price", 0))
	match currency:
		"money":
			if not _game_state.try_spend_money(price):
				return _fail(&"shop_purchase_commit_funds_unavailable", "money is no longer sufficient", {})
		"minesweeper_coin":
			if not _game_state.try_spend_coins(price):
				return _fail(&"shop_purchase_commit_funds_unavailable", "coins are no longer sufficient", {})
		_:
			return _fail(&"invalid_currency", currency, {})
	var grant_item_id := str(candidate.get("grant_inventory_item_id", ""))
	if not grant_item_id.is_empty():
		_game_state.add_inventory(grant_item_id, 1)
	if str(candidate.get("item_id", "")) == _SUPPORTZ_ITEM_ID:
		_game_state.change_minesweeper_round_floor(-1)
	return {"ok": true, "code": &"ok", "value": {"committed": true}, "receipt": {}}


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	_game_state.money = int(backup["money"])
	_game_state.coins = int(backup["coins"])
	_game_state.inventory = (backup["inventory"] as Dictionary).duplicate(true)
	_game_state.minesweeper_round_floor = int(backup["minesweeper_round_floor"])
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func publish(_publication: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": {}}


func _can_afford(currency: String, price: int) -> bool:
	match currency:
		"money":
			return _game_state.can_spend_money(price)
		"minesweeper_coin":
			return _game_state.can_spend_coins(price)
		_:
			return false


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


func _require_configured() -> Dictionary:
	if _game_state == null:
		return _fail(&"port_not_configured", "GameStateMinesweeperShopPort.configure() was never called", {})
	return {"ok": true}


func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
