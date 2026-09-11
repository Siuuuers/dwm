extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/shop/ShopPresentationPort.gd")
const DATA_CATALOG := preload("res://scripts/data/DataCatalog.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

const PUBLIC_ORDER := [
	"coffee", "wine", "pineapple_bun", "bandage_pack", "quiet_tea",
	"soft_blanket", "weighted_plush", "spa_coupon", "healthy_meal",
	"protein_box", "pep_note", "premium_care", "lucky_charm", "debug_key",
	"bookend_keepsake", "metronome_keepsake", "pocket_calculator_keepsake",
]


class GameStatePort extends RefCounted:
	var money := 200
	var coins := 8
	var inventory: Dictionary = {}
	var effect_requests: Array[Dictionary] = []
	var gate: RefCounted
	var session := {"active": true, "generation": 4, "run_id": "run-shop", "owner_id": 7}

	func _init(configured_gate: RefCounted) -> void:
		gate = configured_gate

	func get_mutation_gate_instance_id() -> int:
		return gate.get_instance_id()

	func capture_live_session() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": session.duplicate(true)}

	func validate_live_session(handle: Variant) -> Dictionary:
		var guarded: Dictionary = gate.guard_external(&"live_session")
		if not guarded.get("ok", false):
			return guarded
		return {"ok": handle == session, "code": &"ok" if handle == session else &"stale_live_session"}

	func can_spend_money(amount: int) -> bool:
		return amount > 0 and money >= 0 and money - amount >= -30

	func can_spend_coins(amount: int) -> bool:
		return amount > 0 and coins >= amount

	func commit_effect_transaction(transaction_id: String, effect_ids: Array[String], source_id: String) -> Dictionary:
		var guarded: Dictionary = gate.guard_external(&"commit_effect_transaction")
		if not guarded.get("ok", false):
			return guarded
		effect_requests.append({
			"transaction_id": transaction_id,
			"effect_ids": effect_ids.duplicate(),
			"source_id": source_id,
		})
		return {"ok": true, "code": &"ok", "value": {"duplicate": false}, "receipt": {"transaction_id": transaction_id}}


class Issuer extends RefCounted:
	var next := 0

	func issue(purpose: StringName) -> Dictionary:
		next += 1
		var token := "shop-transaction-%d" % next
		var receipt := {"receipt_id": "receipt-%d" % next, "purpose": purpose, "token": token}
		return {"ok": true, "code": &"ok", "value": {"token": token, "issuer_receipt": receipt}, "receipt": receipt}

	func verify_issued(receipt: Dictionary, purpose: StringName) -> Dictionary:
		if receipt.get("purpose") != purpose:
			return {"ok": false, "code": &"wrong_purpose"}
		return {"ok": true, "code": &"ok", "value": {"receipt": receipt.duplicate(true)}}


class PurchaseParticipant extends RefCounted:
	var shop_ledger := {
		"supportz_branch_purchase_count": 0,
		"supportz_last_purchase_causal_day_instance": "",
		"base_completion_receipts": [],
	}
	var quote_requests: Array[Dictionary] = []
	var prepare_requests: Array[Dictionary] = []

	func capture() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"backup": {"state_backup": {}, "consequence_state": {
			"run_revision": 9,
			"causal_day_instance": "causal-day-3",
			"shop_ledger": shop_ledger.duplicate(true),
		}}}}

	func quote(item_id: String, transaction_id: String, receipt: Dictionary, quantity: int = 1) -> Dictionary:
		quote_requests.append({"item_id": item_id, "quantity": quantity, "transaction_id": transaction_id, "receipt": receipt.duplicate(true)})
		return {"ok": true, "code": &"ok", "value": {"quote_id": "quote-" + transaction_id}}

	func prepare_purchase(request: Dictionary) -> Dictionary:
		prepare_requests.append(request.duplicate(true))
		return {"ok": true, "code": &"shop_purchase_action_checkpointed", "value": {
			"action_receipt": {"transaction_id": request.transaction_id},
			"action_candidate": {"transaction_id": request.transaction_id, "item_id": request.item_id},
			"prepared_checkpoint_receipt": {"receipt_id": "checkpoint-" + request.transaction_id},
		}}

	func release_recovery_lease() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"released": true}, "receipt": {}}


class ConsequenceCoordinator extends RefCounted:
	var requests: Array[Dictionary] = []
	var fail_next := false

	func accept_prepared_action(request: Dictionary) -> Dictionary:
		requests.append(request.duplicate(true))
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"save_write_failed"}
		return {"ok": true, "code": &"action_consequence_accepted", "value": {}, "receipt": {}}


class RoundCoordinator extends RefCounted:
	func get_state() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {
			"identity": null, "revision": 0, "phase": "NONE",
		}, "receipt": {}}


var _gate: RefCounted
var _game_state: GameStatePort
var _participant: PurchaseParticipant
var _consequence: ConsequenceCoordinator
var _issuer: Issuer
var _port: RefCounted


func before_each() -> void:
	_gate = GATE.new()
	_game_state = GameStatePort.new(_gate)
	_participant = PurchaseParticipant.new()
	_consequence = ConsequenceCoordinator.new()
	_issuer = Issuer.new()
	_port = PORT.new()
	var configured: Dictionary = _port.configure(
		_game_state, DATA_CATALOG.new(), _participant, _consequence,
		RoundCoordinator.new(), _issuer, _gate)
	assert_true(configured.get("ok", false), JSON.stringify(configured))


func test_catalog_projects_all_current_items_from_the_authoritative_eighteen_templates() -> void:
	var result: Dictionary = _port.get_catalog("zh_CN")
	assert_true(result.get("ok", false), JSON.stringify(result))
	var rows: Array = result["value"]
	assert_eq(rows.size(), 17, "Supportz remains the secret structural eighteenth position")
	var ids: Array = []
	for row: Dictionary in rows:
		ids.append(row["id"])
		assert_eq((row["card_art"] as Texture2D).get_size(), Vector2(28, 28))
		assert_eq((row["inspector_art"] as Texture2D).get_size(), Vector2(56, 56))
	assert_eq(ids, PUBLIC_ORDER)
	assert_eq(rows[0]["name"], "咖啡")
	assert_eq(rows[0]["unit_price"], 20)
	assert_eq(rows[0]["legal_max"], 9)
	assert_eq(rows[3]["legal_max"], 1, "DataCatalog max=0 means repeatable without a branch cap, one per command")
	assert_eq(rows[14]["id"], "bookend_keepsake")
	assert_eq(rows[14]["unit_price"], 3)


func test_ordinary_quantity_uses_the_same_durable_consequence_flow() -> void:
	var result: Dictionary = _port.purchase("coffee", 3)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_true(_game_state.effect_requests.is_empty(), "presentation cannot apply effects outside the durable flow")
	assert_eq(_participant.quote_requests.size(), 1)
	assert_eq(_participant.quote_requests[0].quantity, 3)
	assert_eq(_participant.prepare_requests.size(), 1)
	assert_eq(_participant.prepare_requests[0].item_id, "coffee")
	assert_eq(_consequence.requests.size(), 1)


func test_special_item_uses_one_participant_and_completes_the_existing_consequence_pipeline() -> void:
	var result: Dictionary = _port.purchase("lucky_charm", 1)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(_game_state.effect_requests.size(), 0, "the ordinary stack must never spend a special item")
	assert_eq(_participant.quote_requests.size(), 1)
	assert_eq(_participant.prepare_requests.size(), 1)
	var prepared: Dictionary = _participant.prepare_requests[0]
	assert_eq(prepared["item_id"], "lucky_charm")
	assert_eq(prepared["expected_run_revision"], 9)
	assert_eq(prepared["expected_causal_day_instance"], "causal-day-3")
	assert_eq(_consequence.requests.size(), 1)
	var accepted: Dictionary = _consequence.requests[0]
	assert_eq(accepted["action_candidate"]["item_id"], "lucky_charm")
	assert_eq(accepted["prepared_checkpoint_receipt"]["receipt_id"], "checkpoint-shop-transaction-1")
	assert_null(accepted["expected_board_identity"])
	assert_eq(accepted["expected_board_revision"], 0)


func test_quantity_caps_owned_items_funds_and_shared_gate_fail_closed_before_issuance() -> void:
	assert_eq(_port.purchase("wine", 4).get("code"), &"shop_quantity_exceeds_batch_cap")
	assert_eq(_issuer.next, 0)
	_game_state.inventory["lucky_charm"] = 1
	assert_eq(_port.purchase("lucky_charm", 1).get("code"), &"shop_item_already_owned")
	assert_eq(_issuer.next, 0)
	_game_state.money = -30
	assert_eq(_port.purchase("coffee", 1).get("code"), &"insufficient_funds")
	assert_eq(_issuer.next, 0)
	var lease: Dictionary = _gate.acquire(&"causal_transaction")
	assert_true(lease.get("ok", false))
	assert_eq(_port.purchase("coffee", 1).get("code"), &"TRANSACTION_ACTIVE")
	assert_eq(_issuer.next, 0)


func test_configuration_requires_the_same_mutation_gate_as_game_state() -> void:
	var other_gate := GATE.new()
	var result: Dictionary = PORT.new().configure(
		_game_state, DATA_CATALOG.new(), _participant, _consequence,
		RoundCoordinator.new(), _issuer, other_gate)
	assert_eq(result.get("code"), &"shop_mutation_gate_mismatch")


func test_retained_shop_from_previous_session_cannot_spend_in_a_loaded_run() -> void:
	_game_state.session.generation += 1
	assert_false(_port.purchase("coffee", 1).ok)
	assert_eq(_game_state.effect_requests.size(), 0)


func test_supportz_real_admission_requires_both_current_day_ordinals_and_honors_all_caps() -> void:
	assert_eq(_port.can_purchase("supportz").code, &"supportz_not_eligible")
	var first := {"kind": "complete", "app_round_ordinal": 1, "causal_day_instance": "causal-day-3"}
	var second := {"kind": "complete", "app_round_ordinal": 2, "causal_day_instance": "causal-day-3"}
	_participant.shop_ledger.base_completion_receipts = [first]
	assert_eq(_port.can_purchase("supportz").code, &"supportz_not_eligible")
	_participant.shop_ledger.base_completion_receipts = [first, first.duplicate(true)]
	assert_eq(_port.can_purchase("supportz").code, &"supportz_not_eligible", "two copies of ordinal one do not qualify")
	_participant.shop_ledger.base_completion_receipts = [first, second]
	var admitted: Dictionary = _port.can_purchase("supportz")
	assert_true(admitted.ok)
	assert_eq(admitted.value.total, 45)
	_participant.shop_ledger.supportz_last_purchase_causal_day_instance = "causal-day-3"
	assert_eq(_port.can_purchase("supportz").code, &"supportz_not_eligible")
	_participant.shop_ledger.supportz_last_purchase_causal_day_instance = "causal-day-2"
	_participant.shop_ledger.supportz_branch_purchase_count = 2
	assert_true(_port.can_purchase("supportz").ok)
	_participant.shop_ledger.supportz_branch_purchase_count = 3
	assert_eq(_port.can_purchase("supportz").code, &"supportz_not_eligible")
	_participant.shop_ledger.supportz_branch_purchase_count = 0
	_game_state.money = 0
	assert_eq(_port.can_purchase("supportz").code, &"insufficient_funds")
	_game_state.money = 200
	second.causal_day_instance = "causal-day-2"
	assert_eq(_port.can_purchase("supportz").code, &"supportz_not_eligible", "yesterday's second round does not qualify")
	assert_eq(_issuer.next, 0, "eligibility queries never issue purchase identities")


func test_pending_purchase_reports_real_retained_recovery_until_retry_finishes() -> void:
	assert_false(_port.has_pending_purchase())
	_consequence.fail_next = true
	assert_false(_port.purchase("coffee", 1).ok)
	assert_true(_port.has_pending_purchase())
	assert_true(_port.purchase("coffee", 1).ok)
	assert_false(_port.has_pending_purchase())
	assert_eq(_participant.prepare_requests.size(), 1, "retry resumes the original purchase")
