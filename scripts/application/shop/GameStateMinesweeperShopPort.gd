class_name GameStateMinesweeperShopPort
extends RefCounted

## GameState source for durable Shop purchases. The three Minesweeper capability items keep
## their closed registry operations; ordinary items prepare authored effects on a detached state.
## Preparation never changes live balances. The participant owns admission, save/retry, and
## publication; this port only captures, applies, restores, and publishes the source values.

const _NOTE_RULES := preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")

const _STAT_HEALTH := "health"
const _STAT_PRESSURE := "pressure"
const _CONDITION_SEQUELA := "sequela"

## The closed item-id union this port interprets. Kept separate from MinesweeperShopRegistry's own
## CAPABILITY_UNION: this list is about WHICH items grant a capability via inventory ownership, not
## which board capabilities exist.
const _CAPABILITY_ITEM_IDS: Array[String] = ["lucky_charm", "debug_key"]
const _SUPPORTZ_ITEM_ID := "supportz"

var _note_catalogue: Dictionary = {}
var _note_catalogue_configured: bool = false
var _game_state: Object = null
var _desktop_identity_context: Variant = {}


## Idempotent on identical replay; a changed owner or context is refused before any mutation,
## mirroring every other configure seam in this codebase.
func configure(game_state: Object, desktop_identity_context: Variant) -> Dictionary:
	if game_state == null or not game_state.has_method("get_stat"):
		return _fail(&"invalid_game_state", "game_state must expose get_stat", {})
	var context_shape: Dictionary
	if desktop_identity_context is Callable:
		context_shape = {"ok": desktop_identity_context.is_valid() and desktop_identity_context.get_argument_count() == 0}
	elif desktop_identity_context is Dictionary:
		context_shape = _exact_keys(desktop_identity_context,
			["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"],
			&"invalid_desktop_identity_context")
	else:
		context_shape = _fail(&"invalid_desktop_identity_context", "", {})
	if not context_shape.get("ok", false):
		return context_shape
	if _game_state != null:
		if _game_state != game_state or _desktop_identity_context != desktop_identity_context:
			return _fail(&"port_already_configured", "a configured port never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_game_state = game_state
	_desktop_identity_context = desktop_identity_context.duplicate(true) if desktop_identity_context is Dictionary else desktop_identity_context
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


func guard_external(_operation_id: StringName) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if _desktop_identity_context is Callable:
		return _game_state.validate_live_session(_game_state.capture_live_session().value)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func capture() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var captured_identity := _capture_identity()
	if not captured_identity.get("ok", false): return captured_identity
	var identity_context: Dictionary = captured_identity.value
	var money: int = int(_game_state.money)
	var coins: int = int(_game_state.coins)
	var inventory: Dictionary = (_game_state.inventory as Dictionary).duplicate(true)
	var round_floor: int = int(_game_state.minesweeper_round_floor)
	var owned_item_ids: Dictionary = {}
	for item_id: String in _CAPABILITY_ITEM_IDS:
		owned_item_ids[item_id] = _owns(inventory, item_id)
	return {"ok": true, "code": &"ok", "value": {
		"run_id": str(identity_context["run_id"]),
		"branch_id": str(identity_context["branch_id"]),
		"desktop_timeline_generation": int(identity_context["desktop_timeline_generation"]),
		"causal_day_instance": str(identity_context["causal_day_instance"]),
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
	# New admission only: the participant recognizes exact pending recovery before this seam.
	if _game_state.has_method("require_day7_presentations_complete"):
		var presentations: Dictionary = _game_state.require_day7_presentations_complete()
		if not presentations.get("ok", false): return presentations
	if typeof(transaction_issuer_receipt) != TYPE_DICTIONARY or transaction_issuer_receipt.is_empty():
		return _fail(&"invalid_transaction_issuer_receipt", "the transaction issuer receipt is required", {})
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "transaction_id must be nonblank", {})
	var item_id := str(item.get("item_id", ""))
	if item_id in _NOTE_RULES.ITEM_IDS:
		return _prepare_note(item, quote, transaction_id)
	if item_id not in _CAPABILITY_ITEM_IDS and item_id != _SUPPORTZ_ITEM_ID:
		return _prepare_ordinary(item, quote, transaction_id)
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
	if candidate.get("item_id", "") in _NOTE_RULES.ITEM_IDS:
		var checked := validate_note_candidate(candidate)
		if not checked.get("ok", false): return checked
		var live: Dictionary = _game_state.to_save_dict()
		var source_matches: bool = _same_note_state(live, candidate.ordinary_source_gameplay) \
			and _same_note_state(_game_state.contacts, candidate.ordinary_source_contacts)
		var adopted_matches: bool = _same_note_state(live, candidate.ordinary_gameplay) \
			and _same_note_state(_game_state.contacts, candidate.ordinary_contacts)
		if not source_matches and not adopted_matches:
			return _fail(&"stale_note_shop_source", "", {})
	if candidate.get("ordinary_gameplay") is Dictionary:
		var gameplay: Dictionary = candidate.ordinary_gameplay
		if int(gameplay.get("day", -1)) != int(_game_state.day) or not candidate.get("ordinary_contacts") is Dictionary:
			return _fail(&"invalid_ordinary_shop_candidate", "", {})
		_game_state.call(&"_apply_gameplay_silent", gameplay.duplicate(true))
		_game_state.contacts = candidate.ordinary_contacts.duplicate(true)
		return {"ok": true}
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


## Ordinary items use the authored resolver only on a detached GameState. The resulting complete
## gameplay values enter the same durable purchase flow as the three capability items.
func _prepare_ordinary(item: Dictionary, quote: Dictionary, transaction_id: String) -> Dictionary:
	var item_id := str(item.get("item_id", ""))
	var currency := str(item.get("currency", ""))
	var price := int(item.get("price", -1))
	var quantity := int(item.get("quantity", 0))
	if str(quote.get("item_id", "")) != item_id or str(quote.get("currency", "")) != currency \
			or int(quote.get("price", -2)) != price or quantity < 1 or not item.get("effect_ids") is Array:
		return _fail(&"invalid_ordinary_shop_quote", "", {})
	if not _can_afford(currency, price): return _fail(&"insufficient_funds", "", {})
	var effects: Array[String] = []
	for count: int in quantity:
		for effect: Variant in item.effect_ids:
			var effect_id := str(effect)
			if int(item.get("max_purchases", 0)) == 1 and effect_id.begins_with("inventory:add:") \
					and _owns(_game_state.inventory, effect_id.trim_prefix("inventory:add:")):
				return _fail(&"shop_item_already_owned", "", {})
			effects.append(effect_id)
	var resolver: Object = _game_state.get_node_or_null("/root/EffectResolver")
	if resolver == null: return _fail(&"effect_resolver_unavailable", "", {})
	var resolved: Dictionary = resolver.resolve_effects(effects)
	if not resolved.get("ok", false): return resolved
	var clone: Node = _game_state.get_script().new()
	clone.reset_game()
	clone.apply_save_dict(_game_state.to_save_dict())
	clone.contacts = _game_state.contacts.duplicate(true)
	var spent: bool = clone.try_spend_money(price) if currency == "money" else clone.try_spend_coins(price)
	if not spent:
		clone.free()
		return _fail(&"insufficient_funds", "", {})
	var applied: Dictionary = resolver.apply_resolved_descriptors(clone, resolved.value.descriptors)
	if not applied.get("ok", false):
		clone.free()
		return applied
	var candidate := {"transaction_id": transaction_id, "item_id": item_id, "currency": currency,
		"price": price, "ordinary_gameplay": clone.to_save_dict(), "ordinary_contacts": clone.contacts.duplicate(true)}
	var condition := {"health": int(clone.get_stat("health")), "pressure": int(clone.get_stat("pressure")),
		"carried_sequela": (_game_state.condition_effects_today as Array).has("sequela")}
	clone.free()
	return {"ok": true, "value": {"candidate": candidate, "condition_after": condition,
		"backup": {"gameplay": _game_state.to_save_dict(), "contacts": _game_state.contacts.duplicate(true)}}}


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if backup.get("gameplay") is Dictionary:
		_game_state.call(&"_apply_gameplay_silent", backup.gameplay.duplicate(true))
		_game_state.contacts = backup.contacts.duplicate(true)
		return {"ok": true}
	_game_state.money = int(backup["money"])
	_game_state.coins = int(backup["coins"])
	_game_state.inventory = (backup["inventory"] as Dictionary).duplicate(true)
	_game_state.minesweeper_round_floor = int(backup["minesweeper_round_floor"])
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func publish(_publication: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	_game_state.emit_signal("money_changed", int(_game_state.money))
	_game_state.emit_signal("coins_changed", int(_game_state.coins))
	_game_state.emit_signal("inventory_changed")
	for stat_id: String in ["health", "pressure", "motivation"]:
		_game_state.emit_signal("stat_changed", stat_id, int(_game_state.get_stat(stat_id)),
			int(_game_state.call(&"_stat_min", stat_id)), int(_game_state.call(&"_stat_max", stat_id)))
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


func _capture_identity() -> Dictionary:
	var captured: Variant = _desktop_identity_context.call() if _desktop_identity_context is Callable \
		else {"ok": true, "value": _desktop_identity_context.duplicate(true)}
	if not captured is Dictionary or not captured.get("ok", false) or not captured.get("value") is Dictionary:
		return captured if captured is Dictionary else _fail(&"invalid_desktop_identity_context", "", {})
	var shaped := _exact_keys(captured.value,
		["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"], &"invalid_desktop_identity_context")
	return captured if shaped.get("ok", false) else shaped


## Content registration is detached, validated and immutable for this port's lifetime.
func configure_note_catalogue(catalogue: Variant) -> Dictionary:
	var checked: Dictionary = _NOTE_RULES.validate_counts_and_catalogue({}, catalogue)
	if not checked.get("ok", false): return checked
	var value: Dictionary = checked.value.catalogue
	if _note_catalogue_configured and _note_catalogue != value:
		return _fail(&"note_catalogue_already_configured", "", {})
	_note_catalogue = value.duplicate(true)
	_note_catalogue_configured = true
	return {"ok": true}


func _prepare_note(item: Dictionary, quote: Dictionary, transaction_id: String) -> Dictionary:
	if not _note_catalogue_configured:
		return _fail(&"note_catalogue_unconfigured", "", {})
	if typeof(item.get("currency")) != TYPE_STRING or item.currency != "money" \
			or typeof(item.get("price")) != TYPE_INT or item.price != 45 \
			or typeof(item.get("max_purchases")) != TYPE_INT or item.max_purchases != 3 \
			or not item.get("effect_ids") is Array or not item.effect_ids.is_empty() \
			or typeof(item.get("quantity")) != TYPE_INT or item.quantity != 1:
		return _fail(&"invalid_note_shop_record", "", {})
	if quote.get("transaction_id") != transaction_id or quote.get("item_id") != item.item_id or quote.get("currency") != "money" \
			or typeof(quote.get("price")) != TYPE_INT or quote.price != 45 \
			or typeof(quote.get("quantity", 1)) != TYPE_INT or quote.get("quantity", 1) != 1:
		return _fail(&"invalid_ordinary_shop_quote", "", {})
	var source: Dictionary = _game_state.to_save_dict().duplicate(true)
	var prepared: Dictionary = _NOTE_RULES.prepare(item.item_id, item.quantity,
		source.get("money"), source.get("shop_purchase_counts", {}), _note_catalogue)
	if not prepared.get("ok", false): return prepared
	var gameplay: Dictionary = source.duplicate(true)
	gameplay.money = prepared.value.candidate.money
	gameplay.shop_purchase_counts = prepared.value.candidate.shop_purchase_counts.duplicate(true)
	var contacts: Dictionary = _game_state.contacts.duplicate(true)
	var candidate := {"transaction_id": transaction_id, "item_id": item.item_id,
		"currency": "money", "price": 45,
		"ordinary_source_gameplay": source.duplicate(true),
		"ordinary_source_contacts": contacts.duplicate(true),
		"ordinary_gameplay": gameplay, "ordinary_contacts": contacts.duplicate(true)}
	var checked := validate_note_candidate(candidate)
	if not checked.get("ok", false): return checked
	return {"ok": true, "value": {"candidate": candidate,
		"condition_after": {"health": int(_game_state.get_stat("health")),
			"pressure": int(_game_state.get_stat("pressure")),
			"carried_sequela": (_game_state.condition_effects_today as Array).has("sequela")},
		"backup": {"gameplay": source.duplicate(true), "contacts": contacts.duplicate(true)}}}


## Recovery checks the frozen full-state delta without consulting content or today's price.
## The participant binds transaction identity and hash to its durable pending action.
func validate_note_candidate(candidate: Dictionary) -> Dictionary:
	var expected_keys: Array = ["transaction_id", "item_id", "currency", "price",
		"ordinary_source_gameplay", "ordinary_source_contacts", "ordinary_gameplay", "ordinary_contacts"]
	# The participant adds checkpoint custody after this port prepares the detached candidate.
	if candidate.has("source_checkpoint"):
		expected_keys.append("source_checkpoint")
		if not candidate.source_checkpoint is Dictionary:
			return _fail(&"invalid_note_shop_candidate", "", {})
		var checkpoint: Dictionary = candidate.source_checkpoint
		var checkpoint_shape := _exact_keys(checkpoint, ["checkpoint_id", "snapshot_sha256"],
			&"invalid_note_shop_candidate")
		if not checkpoint_shape.get("ok", false): return checkpoint_shape
		if typeof(checkpoint.checkpoint_id) != TYPE_STRING or checkpoint.checkpoint_id.strip_edges().is_empty() \
				or typeof(checkpoint.snapshot_sha256) != TYPE_STRING or checkpoint.snapshot_sha256.length() != 64:
			return _fail(&"invalid_note_shop_candidate", "", {})
		for index: int in 64:
			if checkpoint.snapshot_sha256.substr(index, 1) not in "0123456789abcdef":
				return _fail(&"invalid_note_shop_candidate", "", {})
	var shaped := _exact_keys(candidate, expected_keys, &"invalid_note_shop_candidate")
	if not shaped.get("ok", false): return shaped
	if typeof(candidate.transaction_id) != TYPE_STRING or candidate.transaction_id.strip_edges().is_empty() \
			or typeof(candidate.item_id) != TYPE_STRING or candidate.item_id not in _NOTE_RULES.ITEM_IDS \
			or typeof(candidate.currency) != TYPE_STRING or candidate.currency != "money" \
			or typeof(candidate.price) != TYPE_INT or candidate.price != 45 \
			or not candidate.ordinary_source_gameplay is Dictionary \
			or not candidate.ordinary_gameplay is Dictionary \
			or not candidate.ordinary_source_contacts is Dictionary \
			or not candidate.ordinary_contacts is Dictionary:
		return _fail(&"invalid_note_shop_candidate", "", {})
	var source: Dictionary = candidate.ordinary_source_gameplay
	if typeof(source.get("money")) != TYPE_INT or source.money < 45 \
			or typeof(source.get("day")) != TYPE_INT \
			or not _same_note_state(candidate.ordinary_contacts, candidate.ordinary_source_contacts):
		return _fail(&"invalid_note_shop_candidate", "", {})
	var validated: Dictionary = _NOTE_RULES.validate_counts(source.get("shop_purchase_counts", {}))
	if not validated.get("ok", false): return validated
	var counts: Dictionary = validated.value.shop_purchase_counts
	var count: int = counts.get(candidate.item_id, 0)
	if count >= 3: return _fail(&"invalid_note_shop_candidate", "", {})
	counts[candidate.item_id] = count + 1
	var expected := source.duplicate(true)
	expected.money = source.money - 45
	expected.shop_purchase_counts = counts
	if not _same_note_state(expected, candidate.ordinary_gameplay):
		return _fail(&"invalid_note_shop_candidate", "", {})
	return {"ok": true}


## Variant equality alone permits equal-valued numeric type substitutions.
## Preserve every nested value and key type, independent of dictionary order.
func _same_note_state(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if left is Dictionary:
		if left.size() != right.size(): return false
		var right_keys: Array = right.keys()
		for key: Variant in left:
			var index: int = right_keys.find(key)
			if index < 0 or typeof(key) != typeof(right_keys[index]): return false
			if not _same_note_state(left[key], right[right_keys[index]]): return false
		return true
	if left is Array:
		if left.size() != right.size(): return false
		for index: int in left.size():
			if not _same_note_state(left[index], right[index]): return false
		return true
	return left == right
