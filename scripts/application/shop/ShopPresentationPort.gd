class_name ShopPresentationPort
extends RefCounted

## Production Shop query/command boundary. The UI receives only presentation rows and item/quantity
## commands. Every purchase uses the retained durable participant: one debit and its authored
## effects, followed by condition evaluation and a complete result Autosave.

signal catalog_changed

const _COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const _CAPABILITY_RULES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")

const _SPECIAL_IDS: Array[String] = ["supportz", "lucky_charm", "debug_key"]
const _PUBLIC_ORDER: Array[String] = [
	"coffee", "wine", "pineapple_bun", "bandage_pack", "quiet_tea",
	"soft_blanket", "weighted_plush", "spa_coupon", "healthy_meal", "protein_box",
	"pep_note", "premium_care", "lucky_charm", "debug_key", "bookend_keepsake",
	"metronome_keepsake", "pocket_calculator_keepsake",
]
const _SOURCE_TO_PUBLIC := {
	"priscilla_gift": "bookend_keepsake",
	"lavinia_gift": "metronome_keepsake",
	"sylvia_gift": "pocket_calculator_keepsake",
}
const _PUBLIC_TO_SOURCE := {
	"bookend_keepsake": "priscilla_gift",
	"metronome_keepsake": "lavinia_gift",
	"pocket_calculator_keepsake": "sylvia_gift",
}
const _BATCHABLE_IDS: Array[String] = [
	"coffee", "wine", "pineapple_bun", "bandage_pack", "quiet_tea",
	"soft_blanket", "weighted_plush", "healthy_meal", "protein_box",
	"pep_note", "premium_care",
]

const _GAME_STATE_METHODS: Array[String] = [
	"get_mutation_gate_instance_id", "capture_live_session", "validate_live_session",
	"can_spend_money", "can_spend_coins",
]
const _CATALOG_METHODS: Array[String] = ["get_shop_items", "get_shop_item"]
const _PARTICIPANT_METHODS: Array[String] = [
	"capture", "quote", "prepare_purchase", "release_recovery_lease",
]

var _game_state: Object
var _data_catalog: Object
var _purchase_participant: Object
var _consequence_coordinator: Object
var _round_coordinator: Object
var _identity_issuer: Object
var _mutation_gate: Object
var _art: Dictionary = {}
var _pending_purchase: Dictionary = {}
var _session_handle: Dictionary = {}


func configure(game_state: Object, data_catalog: Object, purchase_participant: Object,
		consequence_coordinator: Object, round_coordinator: Object, identity_issuer: Object,
		mutation_gate: Object) -> Dictionary:
	if not _has_methods(game_state, _GAME_STATE_METHODS):
		return _fail(&"invalid_shop_game_state")
	if not _has_methods(data_catalog, _CATALOG_METHODS):
		return _fail(&"invalid_shop_data_catalog")
	if not _has_methods(purchase_participant, _PARTICIPANT_METHODS):
		return _fail(&"invalid_shop_purchase_participant")
	if not is_instance_valid(consequence_coordinator) \
			or not consequence_coordinator.has_method("accept_prepared_action"):
		return _fail(&"invalid_shop_consequence_coordinator")
	if not is_instance_valid(round_coordinator) or not round_coordinator.has_method("get_state"):
		return _fail(&"invalid_shop_round_coordinator")
	if not _has_methods(identity_issuer, ["issue", "verify_issued"]):
		return _fail(&"invalid_shop_identity_issuer")
	if not is_instance_valid(mutation_gate) or not mutation_gate.has_method("guard_external"):
		return _fail(&"invalid_shop_mutation_gate")
	if int(game_state.call(&"get_mutation_gate_instance_id")) != mutation_gate.get_instance_id():
		return _fail(&"shop_mutation_gate_mismatch")
	if _game_state != null:
		if _game_state != game_state or _data_catalog != data_catalog \
				or _purchase_participant != purchase_participant \
				or _consequence_coordinator != consequence_coordinator \
				or _round_coordinator != round_coordinator or _identity_issuer != identity_issuer \
				or _mutation_gate != mutation_gate:
			return _fail(&"shop_presentation_port_already_configured")
		return _ok({"already_configured": true})
	var captured: Dictionary = game_state.call(&"capture_live_session")
	if not captured.get("ok", false) or not captured.get("value") is Dictionary:
		return _fail(&"shop_session_capture_malformed")
	var admitted: Dictionary = game_state.call(&"validate_live_session", captured.value)
	if not admitted.get("ok", false): return admitted
	_session_handle = captured.value.duplicate(true)
	_game_state = game_state
	_data_catalog = data_catalog
	_purchase_participant = purchase_participant
	_consequence_coordinator = consequence_coordinator
	_round_coordinator = round_coordinator
	_identity_issuer = identity_issuer
	_mutation_gate = mutation_gate
	return _ok({"already_configured": false})


func get_catalog(locale: String) -> Dictionary:
	var admitted := _admit_session()
	if not admitted.get("ok", false):
		return admitted
	var locale_id := locale.replace("-", "_")
	if locale_id not in ["en", "zh_CN", "zh_HK"]:
		return _fail(&"invalid_shop_locale")
	var source_items: Variant = _data_catalog.call(&"get_shop_items")
	if typeof(source_items) != TYPE_ARRAY or (source_items as Array).size() != 18:
		return _fail(&"shop_catalog_unavailable")
	var rows_by_id: Dictionary = {}
	for item: Variant in source_items:
		if not item is ShopItemData:
			return _fail(&"shop_catalog_unavailable")
		var source_id := str(item.get("id"))
		if source_id == "supportz":
			continue
		var public_id := str(_SOURCE_TO_PUBLIC.get(source_id, source_id))
		var name := _COPY.item_name(locale_id, public_id)
		if name.is_empty():
			return _fail(&"shop_catalog_copy_unavailable")
		var maximum := int(item.get("max_purchases"))
		# DataCatalog's zero means no branch cap. It remains repeatedly purchasable; one command
		# carries one item because the finite selector cannot represent infinity.
		var command_cap := 1 if maximum == 0 else maximum
		var owned := _is_owned_nonrepeatable(item)
		var row := {
			"id": public_id,
			"name": name,
			"unit_price": int(item.get("price")),
			"currency": str(item.get("currency")),
			"available": not owned,
			"batchable": public_id in _BATCHABLE_IDS,
			"legal_max": 0 if owned else command_cap,
			"card_art": _texture(public_id, 28),
			"inspector_art": _texture(public_id, 56),
		}
		var description := str(item.get("description"))
		if not description.is_empty():
			row["description"] = description
		rows_by_id[public_id] = row
	if rows_by_id.size() != _PUBLIC_ORDER.size():
		return _fail(&"shop_catalog_unavailable")
	var rows: Array = []
	for public_id: String in _PUBLIC_ORDER:
		if not rows_by_id.has(public_id):
			return _fail(&"shop_catalog_unavailable")
		rows.append((rows_by_id[public_id] as Dictionary).duplicate(true))
	return _ok(rows)


func can_purchase(item_id: String, quantity: int = 1) -> Dictionary:
	var admitted := _admit_session()
	if not admitted.get("ok", false):
		return admitted
	var resolved := _resolve_item(item_id)
	if not resolved.get("ok", false):
		return resolved
	var item: ShopItemData = resolved["value"]
	var checked := _validate_quantity(item_id, item, quantity)
	if not checked.get("ok", false):
		return checked
	if _is_owned_nonrepeatable(item):
		return _fail(&"shop_item_already_owned")
	if item_id == "supportz":
		var supportz := _supportz_eligibility()
		if not supportz.get("ok", false):
			return supportz
		if not bool((supportz["value"] as Dictionary)["eligible"]):
			return _fail(&"supportz_not_eligible")
	var total := int(item.get("price")) * quantity
	if not _can_afford(str(item.get("currency")), total):
		return _fail(&"insufficient_funds")
	return _ok({"eligible": true, "total": total})


func purchase(item_id: String, quantity: int) -> Dictionary:
	if not _pending_purchase.is_empty():
		if item_id != str(_pending_purchase.get("item_id", "")) or quantity != int(_pending_purchase.get("quantity", 1)):
			return _fail(&"shop_purchase_pending")
		return _retry_purchase()
	var eligible := can_purchase(item_id, quantity)
	if not eligible.get("ok", false):
		return eligible
	var issued := _issue_transaction()
	if not issued.get("ok", false):
		return issued
	var issue_value: Dictionary = issued["value"]
	return _prepare_purchase(item_id, quantity, issue_value)


func _prepare_purchase(item_id: String, quantity: int, issue_value: Dictionary) -> Dictionary:
	var participant_capture: Variant = _purchase_participant.call(&"capture")
	if typeof(participant_capture) != TYPE_DICTIONARY \
			or not (participant_capture as Dictionary).get("ok", false):
		return participant_capture if typeof(participant_capture) == TYPE_DICTIONARY \
			else _fail(&"shop_participant_capture_malformed")
	var consequence: Variant = (participant_capture as Dictionary).get("value", {}).get("backup", {}) \
		.get("consequence_state")
	if typeof(consequence) != TYPE_DICTIONARY:
		return _fail(&"shop_participant_capture_malformed")
	var board_result: Variant = _round_coordinator.call(&"get_state")
	if typeof(board_result) != TYPE_DICTIONARY or not (board_result as Dictionary).get("ok", false) \
			or typeof((board_result as Dictionary).get("value")) != TYPE_DICTIONARY:
		return board_result if typeof(board_result) == TYPE_DICTIONARY \
			else _fail(&"shop_board_capture_malformed")
	var board: Dictionary = (board_result as Dictionary)["value"]
	var transaction_id := str(issue_value["transaction_id"])
	var issuer_receipt: Dictionary = issue_value["issuer_receipt"]
	var source_id := str(_PUBLIC_TO_SOURCE.get(item_id, item_id))
	var quoted: Variant = _purchase_participant.call(&"quote", source_id, transaction_id,
		issuer_receipt.duplicate(true), quantity)
	if typeof(quoted) != TYPE_DICTIONARY or not (quoted as Dictionary).get("ok", false):
		return quoted if typeof(quoted) == TYPE_DICTIONARY else _fail(&"shop_quote_result_malformed")
	var quote_value: Variant = (quoted as Dictionary).get("value")
	if typeof(quote_value) != TYPE_DICTIONARY or str((quote_value as Dictionary).get("quote_id", "")).is_empty():
		return _fail(&"shop_quote_result_malformed")
	var prepared: Variant = _purchase_participant.call(&"prepare_purchase", {
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": issuer_receipt.duplicate(true),
		"item_id": source_id,
		"quote_id": str((quote_value as Dictionary)["quote_id"]),
		"expected_run_revision": int((consequence as Dictionary).get("run_revision", -1)),
		"expected_causal_day_instance": str((consequence as Dictionary).get("causal_day_instance", "")),
	})
	if typeof(prepared) != TYPE_DICTIONARY or not (prepared as Dictionary).get("ok", false):
		return prepared if typeof(prepared) == TYPE_DICTIONARY else _fail(&"shop_prepare_result_malformed")
	var value: Variant = (prepared as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY or typeof((value as Dictionary).get("action_receipt")) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("action_candidate")) != TYPE_DICTIONARY \
			or typeof((value as Dictionary).get("prepared_checkpoint_receipt")) != TYPE_DICTIONARY:
		return _fail(&"shop_prepare_result_malformed")
	var accept_request := {
		"action_receipt": ((value as Dictionary)["action_receipt"] as Dictionary).duplicate(true),
		"action_candidate": ((value as Dictionary)["action_candidate"] as Dictionary).duplicate(true),
		"prepared_checkpoint_receipt": ((value as Dictionary)["prepared_checkpoint_receipt"] as Dictionary).duplicate(true),
		"expected_run_revision": int((consequence as Dictionary)["run_revision"]),
		"expected_board_identity": _detached(board.get("identity")),
		"expected_board_revision": int(board.get("revision", -1)),
	}
	_pending_purchase = {"item_id": item_id, "quantity": quantity, "accept_request": accept_request.duplicate(true)}
	return _retry_purchase()


func _retry_purchase() -> Dictionary:
	var result: Variant = _consequence_coordinator.call(&"accept_prepared_action",
		(_pending_purchase["accept_request"] as Dictionary).duplicate(true))
	if typeof(result) != TYPE_DICTIONARY:
		return _fail(&"shop_consequence_result_malformed")
	if bool((result as Dictionary).get("ok", false)):
		_pending_purchase.clear()
		catalog_changed.emit()
	elif str((result as Dictionary).get("code", "")) == "condition_departure_ports_unconfigured":
		_purchase_participant.call(&"release_recovery_lease")
		_pending_purchase.clear()
	return (result as Dictionary).duplicate(true)


func _issue_transaction() -> Dictionary:
	var issued: Variant = _identity_issuer.call(&"issue", &"transaction_id")
	if typeof(issued) != TYPE_DICTIONARY or not (issued as Dictionary).get("ok", false):
		return issued if typeof(issued) == TYPE_DICTIONARY else _fail(&"shop_transaction_issue_malformed")
	var value: Variant = (issued as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY or typeof((value as Dictionary).get("issuer_receipt")) != TYPE_DICTIONARY:
		return _fail(&"shop_transaction_issue_malformed")
	var transaction_id := str((value as Dictionary).get("token", ""))
	var receipt: Dictionary = (value as Dictionary)["issuer_receipt"]
	if transaction_id.is_empty() or receipt.get("token") != transaction_id \
			or (issued as Dictionary).get("receipt") != receipt:
		return _fail(&"shop_transaction_issue_malformed")
	var verified: Variant = _identity_issuer.call(&"verify_issued", receipt, &"transaction_id")
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"shop_transaction_issue_unverified")
	return _ok({"transaction_id": transaction_id, "issuer_receipt": receipt.duplicate(true)})


func _supportz_eligibility() -> Dictionary:
	var captured: Variant = _purchase_participant.call(&"capture")
	if typeof(captured) != TYPE_DICTIONARY or not (captured as Dictionary).get("ok", false):
		return captured if typeof(captured) == TYPE_DICTIONARY else _fail(&"shop_participant_capture_malformed")
	var state: Variant = (captured as Dictionary).get("value", {}).get("backup", {}).get("consequence_state")
	if typeof(state) != TYPE_DICTIONARY or typeof((state as Dictionary).get("shop_ledger")) != TYPE_DICTIONARY:
		return _fail(&"shop_participant_capture_malformed")
	var ledger: Dictionary = (state as Dictionary)["shop_ledger"]
	return _CAPABILITY_RULES.supportz_eligible({
		"causal_day_instance": str((state as Dictionary).get("causal_day_instance", "")),
		"completion_receipts": (ledger.get("base_completion_receipts", []) as Array).duplicate(true),
		"branch_purchase_count": int(ledger.get("supportz_branch_purchase_count", -1)),
		"daily_purchase_done": str(ledger.get("supportz_last_purchase_causal_day_instance", "")) \
			== str((state as Dictionary).get("causal_day_instance", "")),
	})


func _resolve_item(public_id: String) -> Dictionary:
	var source_id := str(_PUBLIC_TO_SOURCE.get(public_id, public_id))
	var raw: Variant = _data_catalog.call(&"get_shop_item", source_id)
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return _fail(&"unregistered_shop_item")
	var item := ShopItemData.new()
	item.id = source_id
	item.price = int((raw as Dictionary).get("price", 0))
	item.currency = str((raw as Dictionary).get("currency", ""))
	item.max_purchases = int((raw as Dictionary).get("max_purchases", -1))
	var effects: Array[String] = []
	for effect: Variant in ((raw as Dictionary).get("effect_ids", []) as Array):
		effects.append(str(effect))
	item.effect_ids = effects
	return _ok(item)


func _validate_quantity(public_id: String, item: ShopItemData, quantity: int) -> Dictionary:
	if quantity < 1:
		return _fail(&"invalid_shop_quantity")
	if public_id in _SPECIAL_IDS and quantity != 1:
		return _fail(&"shop_quantity_exceeds_batch_cap")
	var maximum := int(item.max_purchases)
	if maximum > 0 and quantity > maximum:
		return _fail(&"shop_quantity_exceeds_batch_cap")
	if maximum == 0 and quantity != 1:
		return _fail(&"shop_quantity_exceeds_batch_cap")
	return _ok({})


func _is_owned_nonrepeatable(item: ShopItemData) -> bool:
	if int(item.max_purchases) != 1:
		return false
	for effect: String in item.effect_ids:
		if effect.begins_with("inventory:add:"):
			var inventory_id := effect.trim_prefix("inventory:add:")
			return _owns(_game_state.get("inventory"), inventory_id)
	return false


func _can_afford(currency: String, total: int) -> bool:
	if currency == "money":
		return bool(_game_state.call(&"can_spend_money", total))
	if currency == "minesweeper_coin":
		return bool(_game_state.call(&"can_spend_coins", total))
	return false


func _admit_session() -> Dictionary:
	if _game_state == null:
		return _fail(&"shop_presentation_port_unconfigured")
	var admitted: Variant = _game_state.call(&"validate_live_session", _session_handle.duplicate(true))
	return (admitted as Dictionary).duplicate(true) if typeof(admitted) == TYPE_DICTIONARY \
		else _fail(&"shop_session_admission_malformed")


func _texture(item_id: String, size: int) -> Texture2D:
	var key := "%s:%d" % [item_id, size]
	if _art.has(key):
		return _art[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var hue := float(abs(item_id.hash()) % 360) / 360.0
	image.fill(Color.from_hsv(hue, 0.28, 0.78, 1.0))
	var edge := Color.from_hsv(hue, 0.5, 0.34, 1.0)
	for coordinate: int in size:
		image.set_pixel(coordinate, 0, edge)
		image.set_pixel(coordinate, size - 1, edge)
		image.set_pixel(0, coordinate, edge)
		image.set_pixel(size - 1, coordinate, edge)
	var texture := ImageTexture.create_from_image(image)
	_art[key] = texture
	return texture


static func _owns(inventory_value: Variant, item_id: String) -> bool:
	if typeof(inventory_value) != TYPE_DICTIONARY or not (inventory_value as Dictionary).has(item_id):
		return false
	var value: Variant = (inventory_value as Dictionary)[item_id]
	return bool(value) if typeof(value) == TYPE_BOOL else float(value) > 0.0 \
		if typeof(value) in [TYPE_INT, TYPE_FLOAT] else false


static func _detached(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


static func _has_methods(target: Object, methods: Array) -> bool:
	if not is_instance_valid(target):
		return false
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true


static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "", "details": {}}
