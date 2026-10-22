extends "res://addons/gut/test.gd"
## Pure contract tests: real issuer over fake storage, invented scene registration.
## No claim of Shop UI, gameplay debit, durable checkpoint or rendered coverage.
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const RECEIPT_FIXTURE := preload("res://tests/unit/test_scene_receipt_validation.gd")
var fixture
var purchase: Dictionary
var root: Dictionary

func before_each() -> void:
	fixture = RECEIPT_FIXTURE.new()
	fixture.before_each()
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	assert_true(issued.ok)
	root = issued.value.issuer_receipt
	purchase = {"item_id": "TEST.drink", "quantity": 2, "currency": "money",
		"unit_price": 7, "effect_ids": ["pressure:-2"]}

func after_each() -> void:
	fixture.free()

func _make(quote: Variant = null) -> Dictionary:
	if quote == null: quote = purchase
	return CONTRACT.make_scene_shop_purchase(fixture.identity, root,
		fixture.admission.transaction_id, quote, fixture.issuer)

func _bag(receipt: Dictionary) -> Dictionary:
	# Purchase deliberately precedes its admission in dictionary iteration order.
	return {receipt.transaction_id: receipt, fixture.admission.transaction_id: fixture.admission}

func test_purchase_authenticates_quote_detaches_inputs_and_has_no_authored_ordinal() -> void:
	var made := _make()
	assert_true(made.ok, str(made))
	if not made.ok: return
	assert_true(CONTRACT.validate_scene_shop_purchase(made.value, fixture.issuer).ok)
	var event_receipt: Dictionary = fixture._receipt()
	var before: Dictionary = CONTRACT.validate_scene_receipts(fixture._bag(event_receipt), fixture.bundle, fixture.issuer)
	var bag := _bag(made.value)
	bag[event_receipt.transaction_id] = event_receipt
	var after: Dictionary = CONTRACT.validate_scene_receipts(bag, fixture.bundle, fixture.issuer)
	assert_true(before.ok, str(before))
	assert_true(after.ok, str(after))
	if not before.ok or not after.ok: return
	assert_eq(after.value.occurrences, before.value.occurrences)
	assert_eq(after.value.commands, before.value.commands)
	made.value.scene_shop_purchase.purchase.unit_price = 99
	assert_eq(purchase.unit_price, 7)
	assert_false(CONTRACT.validate_scene_shop_purchase(made.value, fixture.issuer).ok)

func test_changed_quote_source_fingerprint_or_provenance_refuses() -> void:
	var made := _make()
	assert_true(made.ok)
	if not made.ok: return
	for field: String in ["item", "price", "quantity", "effects", "source", "fingerprint", "provenance", "identity", "token"]:
		var bad: Dictionary = made.value.duplicate(true)
		match field:
			"item": bad.scene_shop_purchase.purchase.item_id = "TEST.other"
			"price": bad.scene_shop_purchase.purchase.unit_price += 1
			"quantity": bad.scene_shop_purchase.purchase.quantity += 1
			"effects": bad.scene_shop_purchase.purchase.effect_ids = ["pressure:-3"]
			"source": bad.source_id = "TEST.other"
			"fingerprint": bad.request_fingerprint = "0".repeat(64)
			"provenance": bad.scene_shop_purchase.provenance.source_ids[0] = 'role="forged"'
			"identity": bad.scene_shop_purchase.source_identity.branch_id = "TEST.foreign"
			"token": bad.transaction_id = "TEST.foreign"
		assert_false(CONTRACT.validate_scene_shop_purchase(bad, fixture.issuer).ok, field)

func test_missing_source_wrong_map_key_or_purchase_before_admission_refuses() -> void:
	var made := _make()
	assert_true(made.ok)
	if not made.ok: return
	assert_false(CONTRACT.validate_scene_receipts({made.value.transaction_id: made.value}, fixture.bundle, fixture.issuer).ok)
	assert_false(CONTRACT.validate_scene_receipts({"TEST.wrong": made.value}, fixture.bundle, fixture.issuer).ok)
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	var later: Dictionary = CONTRACT.make_scene_admission(fixture.identity, issued.value.issuer_receipt,
		"TEST.target", fixture.admission.scene_admission.result.source_checkpoint, null, null, fixture.bundle, fixture.issuer)
	assert_true(later.ok)
	var earlier: Dictionary = CONTRACT.make_scene_shop_purchase(fixture.identity, root,
		later.value.transaction_id, purchase, fixture.issuer)
	assert_true(earlier.ok)
	assert_false(CONTRACT.validate_scene_receipts({earlier.value.transaction_id: earlier.value,
		later.value.transaction_id: later.value}, fixture.bundle, fixture.issuer).ok)

func test_wrong_issuer_purpose_and_unallocated_identity_refuse() -> void:
	var foreign := RECEIPT_FIXTURE.ISSUER.new()
	assert_true(foreign.configure(RECEIPT_FIXTURE.ROOT.new("cd".repeat(32), 1)).ok)
	var made := _make()
	assert_true(made.ok)
	if not made.ok: return
	assert_false(CONTRACT.validate_scene_shop_purchase(made.value, foreign).ok)
	assert_false(CONTRACT.make_scene_shop_purchase(fixture.identity, root,
		fixture.admission.transaction_id, purchase, null).ok)
	assert_false(CONTRACT.make_scene_shop_purchase(fixture.identity,
		fixture.identity.causal_day_instance_issuer_receipt, fixture.admission.transaction_id, purchase, fixture.issuer).ok)
	var identity: Dictionary = fixture.identity.duplicate(true)
	identity.branch_id = "TEST.unallocated"
	assert_false(CONTRACT.make_scene_shop_purchase(identity, root,
		fixture.admission.transaction_id, purchase, fixture.issuer).ok)

func test_malformed_quotes_overflow_and_retired_effects_refuse() -> void:
	for value: Variant in [0, -1, 1.0, "1", 9223372036854775807]:
		var quote := purchase.duplicate(true)
		quote.quantity = value
		assert_false(_make(quote).ok, str(value))
	for effects: Array in [[], ["health:+1"], ["motivation:+1"], ["pressure:+1"], ["pressure:-02"],
		["pressure:-2", "pressure:-2"], ["inventory:add:other"], ["minesweeper:round_floor:-1"]]:
		var quote := purchase.duplicate(true)
		quote.effect_ids = effects
		assert_false(_make(quote).ok, str(effects))
	var quote := purchase.duplicate(true)
	quote.unit_price = 0
	assert_false(_make(quote).ok)
	quote = purchase.duplicate(true)
	quote.extra = true
	assert_false(_make(quote).ok)

func test_retained_quote_is_not_repriced_and_partition_excludes_purchase() -> void:
	var quote := purchase.duplicate(true)
	quote.unit_price = 12345 # Accepted historic quote; no current catalogue lookup.
	var made := _make(quote)
	assert_true(made.ok, str(made))
	if not made.ok: return
	assert_true(CONTRACT.validate_scene_receipts(_bag(made.value), fixture.bundle, fixture.issuer).ok)
	assert_eq(SCHEMA._validate_receipt_partition(_bag(made.value), [], []), "")
	assert_ne(SCHEMA._validate_receipt_partition(_bag(made.value), [made.value.transaction_id], []), "")
	assert_eq(SCHEMA._validate_scene_history_run(_bag(made.value), fixture.identity.run_id), "")
	assert_ne(SCHEMA._validate_scene_history_run(_bag(made.value), "TEST.foreign"), "")
	var snapshot := {"command_receipts": _bag(made.value), "applied_effect_transaction_ids": [],
		"applied_variable_transaction_ids": [], "scene": {"active_admission_receipt_id": fixture.admission.transaction_id,
		"registration_sha256": fixture.admission.scene_admission.registration_fingerprint}}
	assert_eq(SCHEMA._validate_scene_receipt_shapes(snapshot), "")
	made.value.scene_shop_purchase.schema_version = 1.0
	assert_ne(SCHEMA._validate_scene_receipt_shapes(snapshot), "")

func test_restore_identity_can_buy_from_retained_admission_without_rewriting_history() -> void:
	var original := _make()
	assert_true(original.ok)
	if not original.ok: return
	var original_receipt: Dictionary = original.value.duplicate(true)
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	var prepared: Dictionary = fixture.issuer.prepare_continuation_allocation({
		"transaction_id": issued.value.issuer_receipt.token, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"kind": "restore", "existing_run_id": fixture.identity.run_id,
		"source_desktop_timeline_generation": fixture.identity.desktop_timeline_generation,
		"remap_source_transaction_ids": []})
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var committed: Dictionary = fixture.issuer.commit_continuation_allocation(prepared.value)
	assert_true(committed.ok, str(committed))
	if not committed.ok: return
	var restored_identity := {}
	for key: String in fixture.identity: restored_identity[key] = committed.value[key]
	issued = fixture.issuer.issue(&"transaction_id")
	var restored: Dictionary = CONTRACT.make_scene_shop_purchase(restored_identity, issued.value.issuer_receipt,
		fixture.admission.transaction_id, purchase, fixture.issuer)
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	var bag := _bag(original.value)
	bag[restored.value.transaction_id] = restored.value
	assert_true(CONTRACT.validate_scene_receipts(bag, fixture.bundle, fixture.issuer).ok)
	assert_eq(original.value, original_receipt)
	assert_ne(restored_identity.branch_id, original.value.scene_shop_purchase.source_identity.branch_id)

func test_purchase_cannot_join_an_admission_from_another_allocated_run() -> void:
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	var prepared: Dictionary = fixture.issuer.prepare_continuation_allocation({
		"transaction_id": issued.value.issuer_receipt.token, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"kind": "new_run", "existing_run_id": null, "source_desktop_timeline_generation": null,
		"remap_source_transaction_ids": []})
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var committed: Dictionary = fixture.issuer.commit_continuation_allocation(prepared.value)
	assert_true(committed.ok, str(committed))
	if not committed.ok: return
	var foreign_identity := {}
	for key: String in fixture.identity: foreign_identity[key] = committed.value[key]
	issued = fixture.issuer.issue(&"transaction_id")
	var foreign: Dictionary = CONTRACT.make_scene_shop_purchase(foreign_identity, issued.value.issuer_receipt,
		fixture.admission.transaction_id, purchase, fixture.issuer)
	assert_true(foreign.ok, str(foreign))
	if not foreign.ok: return
	var checked: Dictionary = CONTRACT.validate_scene_receipts(_bag(foreign.value), fixture.bundle, fixture.issuer)
	assert_false(checked.ok)
	assert_eq(checked.code, &"scene_shop_admission_mismatch")
