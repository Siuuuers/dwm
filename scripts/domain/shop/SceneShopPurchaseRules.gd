extends RefCounted
## Detached preparation. GameState supplies canonical catalogue data and owns the
## lease, Supportz eligibility/consequence candidate, receipt and durable commit.
## This helper never accepts a UI-supplied quote as transaction authority.
const MAX_INTEGER: int = 9223372036854775807
const SPECIAL_IDS: Array[String] = ["supportz", "lucky_charm", "debug_key"]


static func prepare(gameplay: Dictionary, item_record: Dictionary, quantity: Variant,
		supportz_effect: Dictionary = {}) -> Dictionary:
	if typeof(quantity) != TYPE_INT or quantity < 1:
		return _fail(&"invalid_quantity")
	for key: String in ["id", "currency"]:
		if typeof(item_record.get(key)) != TYPE_STRING or item_record[key].is_empty():
			return _fail(&"invalid_shop_item")
	if typeof(item_record.get("price")) != TYPE_INT or item_record.price <= 0 \
			or typeof(item_record.get("max_purchases")) != TYPE_INT or item_record.max_purchases < 0 \
			or not item_record.get("effect_ids") is Array or item_record.effect_ids.is_empty():
		return _fail(&"invalid_shop_item")
	var item_id: String = item_record.id
	if (item_id in SPECIAL_IDS and quantity != 1) \
			or (item_record.max_purchases == 0 and quantity != 1) \
			or (item_record.max_purchases > 0 and quantity > item_record.max_purchases):
		return _fail(&"invalid_quantity")
	@warning_ignore("integer_division")
	var maximum_price: int = MAX_INTEGER / quantity
	if item_record.price > maximum_price:
		return _fail(&"invalid_shop_price")
	var total: int = item_record.price * quantity
	for key: String in ["money", "coins", "minesweeper_round_floor"]:
		if typeof(gameplay.get(key)) != TYPE_INT:
			return _fail(&"invalid_shop_gameplay")
	if gameplay.money < -30 or gameplay.coins < 0 \
			or gameplay.minesweeper_round_floor < -3 or gameplay.minesweeper_round_floor > 0 \
			or not gameplay.get("stats") is Dictionary or not gameplay.get("inventory") is Dictionary:
		return _fail(&"invalid_shop_gameplay")
	if typeof(gameplay.stats.get("pressure")) != TYPE_INT \
			or gameplay.stats.pressure < 0 or gameplay.stats.pressure > 12:
		return _fail(&"invalid_shop_gameplay")
	for key: Variant in gameplay.inventory:
		if typeof(key) != TYPE_STRING or typeof(gameplay.inventory[key]) != TYPE_INT or gameplay.inventory[key] < 0:
			return _fail(&"invalid_shop_gameplay")
	var candidate: Dictionary = gameplay.duplicate(true)
	match item_record.currency:
		"money":
			# Compare without adding 30 to a possibly maximal balance.
			if gameplay.money < 0 or (total > gameplay.money and total - gameplay.money > 30):
				return _fail(&"insufficient_funds")
			candidate.money -= total
		"minesweeper_coin":
			if gameplay.coins < total: return _fail(&"insufficient_funds")
			candidate.coins -= total
		_:
			return _fail(&"invalid_shop_currency")
	var seen: Dictionary = {}
	for raw: Variant in item_record.effect_ids:
		if typeof(raw) != TYPE_STRING or seen.has(raw): return _fail(&"invalid_shop_effect")
		seen[raw] = true
		var effect_id: String = raw
		if effect_id in ["pressure:-1", "pressure:-2", "pressure:-3", "pressure:-4"]:
			# Reduce by bounded steps without multiplying an unbounded quantity.
			var reduction: int = int(effect_id.get_slice(":", 1))
			candidate.stats.pressure = maxi(0, candidate.stats.pressure + reduction * mini(quantity, 12))
		elif effect_id == "inventory:add:" + item_id:
			var owned: int = candidate.inventory.get(item_id, 0)
			if item_record.max_purchases == 1 and owned > 0: return _fail(&"item_already_owned")
			if owned > MAX_INTEGER - quantity: return _fail(&"inventory_overflow")
			candidate.inventory[item_id] = owned + quantity
		elif effect_id == "minesweeper:round_floor:-1" and item_id == "supportz":
			if not _supportz_effect_valid(supportz_effect, gameplay.minesweeper_round_floor):
				return _fail(&"invalid_supportz_effect")
			candidate.minesweeper_round_floor = supportz_effect.new_round_floor
		else:
			return _fail(&"invalid_shop_effect")
	if item_id == "supportz" and item_record.effect_ids != ["minesweeper:round_floor:-1"]:
		return _fail(&"invalid_supportz_effect")
	if item_id != "supportz" and not supportz_effect.is_empty(): return _fail(&"invalid_supportz_effect")
	return {"ok": true, "code": &"ok", "value": {"gameplay": candidate,
		"purchase": {"item_id": item_id, "quantity": quantity, "currency": item_record.currency,
			"unit_price": item_record.price, "effect_ids": item_record.effect_ids.duplicate(true)}}}


static func _supportz_effect_valid(effect: Dictionary, current_floor: int) -> bool:
	if effect.size() != 5: return false
	for key: String in ["effect_id", "previous_round_floor", "new_round_floor", "causal_day_instance", "transaction_id"]:
		if not effect.has(key): return false
	return effect.effect_id == "minesweeper:round_floor:-1" \
		and typeof(effect.previous_round_floor) == TYPE_INT and effect.previous_round_floor == current_floor \
		and typeof(effect.new_round_floor) == TYPE_INT and effect.new_round_floor == current_floor - 1 \
		and effect.new_round_floor >= -3 \
		and typeof(effect.causal_day_instance) == TYPE_STRING and not effect.causal_day_instance.strip_edges().is_empty() \
		and typeof(effect.transaction_id) == TYPE_STRING and not effect.transaction_id.strip_edges().is_empty()


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": {}}
