class_name FakeMinesweeperShopStatePort
extends RefCounted

## Contract fake for the Task-7 GameState-facing Shop purchase state port (Plan 02 Task 7,
## dwm-p2r.32.7), mirroring FakeDesktopBoardStatePort's established shape and discipline: tracks a
## small in-memory GameState-shaped slice (currency, inventory, round floor, condition) so
## participant tests can exercise affordability/ownership gating and full prepare/commit/rollback/
## publish transactional round-trips without touching real GameState. Never production wiring.

var run_id := "run-fake"
var branch_id := "branch-fake"
var desktop_timeline_generation := 0
var causal_day_instance := "day-fake"
var day := 2
var money := 100
var coins := 10
var inventory: Dictionary = {}
var minesweeper_round_floor := 0
var health := 8
var pressure := 3
var carried_sequela := false

const _CAPABILITY_ITEM_IDS: Array[String] = ["lucky_charm", "debug_key"]
const _SUPPORTZ_ITEM_ID := "supportz"

var call_log: Array[Dictionary] = []
var published: Array[Dictionary] = []

var _fail_next: Dictionary = {}  # method_name (String) -> failure Dictionary


func fail_next(method_name: String, failure: Dictionary) -> void:
	_fail_next[method_name] = failure.duplicate(true)


func guard_external(operation_id: StringName) -> Dictionary:
	_log(&"guard_external", {"operation_id": operation_id})
	var armed := _consume_failure("guard_external")
	if not armed.is_empty():
		return armed
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func capture() -> Dictionary:
	_log(&"capture", {})
	var armed := _consume_failure("capture")
	if not armed.is_empty():
		return armed
	var owned_item_ids: Dictionary = {}
	for item_id: String in _CAPABILITY_ITEM_IDS:
		owned_item_ids[item_id] = _owns(item_id)
	return {"ok": true, "code": &"ok", "value": {
		"run_id": run_id, "branch_id": branch_id, "desktop_timeline_generation": desktop_timeline_generation,
		"causal_day_instance": causal_day_instance, "day": day, "money": money, "coins": coins,
		"health": health, "pressure": pressure, "carried_sequela": carried_sequela,
		"owned_item_ids": owned_item_ids, "minesweeper_round_floor": minesweeper_round_floor,
		"backup": {
			"money": money, "coins": coins, "inventory": inventory.duplicate(true),
			"minesweeper_round_floor": minesweeper_round_floor,
		},
	}, "receipt": {}}


func prepare_purchase(item: Dictionary, quote: Dictionary, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary:
	_log(&"prepare_purchase", {"item_id": item.get("item_id", ""), "transaction_id": transaction_id})
	var armed := _consume_failure("prepare_purchase")
	if not armed.is_empty():
		return armed
	if typeof(transaction_issuer_receipt) != TYPE_DICTIONARY or transaction_issuer_receipt.is_empty():
		return {"ok": false, "code": &"invalid_transaction_issuer_receipt", "message": "", "details": {}}
	var item_id := str(item.get("item_id", ""))
	if item_id not in _CAPABILITY_ITEM_IDS and item_id != _SUPPORTZ_ITEM_ID:
		return {"ok": false, "code": &"unregistered_shop_item", "message": "", "details": {"item_id": item_id}}
	if str(quote.get("item_id", "")) != item_id:
		return {"ok": false, "code": &"quote_item_mismatch", "message": "", "details": {}}
	var currency := str(item.get("currency", ""))
	var price := int(item.get("price", -1))
	if str(quote.get("currency", "")) != currency or int(quote.get("price", -2)) != price:
		return {"ok": false, "code": &"quote_price_mismatch", "message": "", "details": {}}

	var is_capability_item := item_id in _CAPABILITY_ITEM_IDS
	if is_capability_item and _owns(item_id):
		return {"ok": false, "code": &"shop_item_already_owned", "message": "", "details": {"item_id": item_id}}
	if not _can_afford(currency, price):
		return {"ok": false, "code": &"insufficient_funds", "message": "", "details": {}}

	var candidate := {
		"transaction_id": transaction_id, "item_id": item_id, "currency": currency, "price": price,
		"grant_inventory_item_id": item_id if is_capability_item else "",
	}
	return {"ok": true, "code": &"ok", "value": {
		"candidate": candidate,
		"backup": {"money": money, "coins": coins, "inventory": inventory.duplicate(true),
			"minesweeper_round_floor": minesweeper_round_floor},
	}, "receipt": {}}


func commit(candidate: Dictionary) -> Dictionary:
	_log(&"commit", {})
	var armed := _consume_failure("commit")
	if not armed.is_empty():
		return armed
	var currency := str(candidate.get("currency", ""))
	var price := int(candidate.get("price", 0))
	match currency:
		"money":
			if price > money:
				return {"ok": false, "code": &"shop_purchase_commit_funds_unavailable", "message": "", "details": {}}
			money -= price
		"minesweeper_coin":
			if price > coins:
				return {"ok": false, "code": &"shop_purchase_commit_funds_unavailable", "message": "", "details": {}}
			coins -= price
		_:
			return {"ok": false, "code": &"invalid_currency", "message": currency, "details": {}}
	var grant_item_id := str(candidate.get("grant_inventory_item_id", ""))
	if not grant_item_id.is_empty():
		inventory[grant_item_id] = int(inventory.get(grant_item_id, 0)) + 1
	if str(candidate.get("item_id", "")) == _SUPPORTZ_ITEM_ID:
		minesweeper_round_floor -= 1
	return {"ok": true, "code": &"ok", "value": {"committed": true}, "receipt": {}}


func rollback(backup: Dictionary) -> Dictionary:
	_log(&"rollback", {})
	var armed := _consume_failure("rollback")
	if not armed.is_empty():
		return armed
	money = int(backup["money"])
	coins = int(backup["coins"])
	inventory = (backup["inventory"] as Dictionary).duplicate(true)
	minesweeper_round_floor = int(backup["minesweeper_round_floor"])
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func publish(publication: Dictionary) -> Dictionary:
	_log(&"publish", {})
	var armed := _consume_failure("publish")
	if not armed.is_empty():
		return armed
	published.append(publication.duplicate(true))
	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": {}}


func _owns(item_id: String) -> bool:
	return int(inventory.get(item_id, 0)) > 0


func _can_afford(currency: String, price: int) -> bool:
	match currency:
		"money":
			return price >= 0 and money >= price
		"minesweeper_coin":
			return price >= 0 and coins >= price
		_:
			return false


func _consume_failure(method_name: String) -> Dictionary:
	if not _fail_next.has(method_name):
		return {}
	var failure: Dictionary = _fail_next[method_name]
	_fail_next.erase(method_name)
	return failure


func _log(method: StringName, argument: Dictionary) -> void:
	call_log.append({"method": method, "argument": argument.duplicate(true)})
