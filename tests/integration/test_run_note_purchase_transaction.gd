extends "res://addons/gut/test.gd"
## Exclusive real final-bootstrap suite. Controller supplies isolated DWM_TEST_ROOT.
const FIXTURE := preload("res://tests/support/RunNotePurchaseTransactionFixture.gd")
const NOTES := preload("res://tests/support/RunNotePurchaseFixture.gd")
var fixture: RefCounted

func before_each() -> void:
	fixture = FIXTURE.new()
	var result: Dictionary = await fixture.initialize(get_tree())
	assert_true(result.get("ok", false), JSON.stringify(result))

func after_each() -> void:
	fixture.dispose()

func _ready_fixture() -> bool:
	return fixture.presentation != null

func _assert_preserved(before: Dictionary, after: Dictionary) -> void:
	assert_eq(after.profile, before.profile, "purchase leaves complete Profile unchanged")
	assert_eq(after.reading, before.reading, "desktop reading availability/checkpoint unchanged")
	for key: String in before.run:
		if key in ["gameplay", "desktop"]: continue
		assert_eq(after.run[key], before.run[key], "full Run owner unchanged: " + key)
	for key: String in before.run.gameplay:
		if key in ["money", "shop_purchase_counts"]: continue
		assert_eq(after.run.gameplay[key], before.run.gameplay[key], "deep gameplay retained: " + key)

func test_all_three_note_chains_debit_project_save_and_refuse_fourth() -> void:
	if not _ready_fixture(): return
	# Explicit engineering economy seed; every subsequent debit and saved byte is real.
	fixture.game.money = 1000
	var expected_money := 1000
	for item: String in NOTES.ITEMS:
		for ordinal: int in range(1, 4):
			var before: Dictionary = fixture.witness()
			var purchased: Dictionary = fixture.presentation.purchase(item, 1)
			assert_true(purchased.get("ok", false), JSON.stringify(purchased))
			if not purchased.get("ok", false): return
			expected_money -= 45
			assert_eq(fixture.game.money, expected_money)
			assert_eq(fixture.game.shop_purchase_counts[item], ordinal)
			_assert_preserved(before, fixture.witness())
			var saved: Dictionary = fixture.disk_snapshot()
			assert_true(saved.get("ok", false), JSON.stringify(saved))
			if not saved.get("ok", false): return
			assert_eq(saved.value.gameplay.money, expected_money, "actual completed Autosave debit")
			assert_eq(saved.value.gameplay.shop_purchase_counts[item], ordinal, "actual completed Autosave count")
			var projected: Dictionary = fixture.projection()
			assert_true(projected.ok)
			for group: Dictionary in projected.value.groups:
				if group.item_id == item:
					assert_eq(group.notes, NOTES.catalogue()[item].slice(0, ordinal), "exact prefix; no future note")
		var before_cap: Dictionary = fixture.witness()
		var bytes: String = fixture.disk_text()
		assert_false(fixture.presentation.purchase(item, 1).get("ok", false))
		assert_eq(fixture.witness(), before_cap, "cap refusal changes no owner")
		assert_eq(fixture.disk_text(), bytes, "cap refusal changes no primary bytes")

func test_invalid_quantities_catalogue_rows_and_quote_leave_owners_and_disk_unchanged() -> void:
	if not _ready_fixture(): return
	fixture.game.money = 500
	var before: Dictionary = fixture.witness()
	var bytes: String = fixture.disk_text()
	for quantity: int in [-1, 0, 2, 3, 4]:
		assert_false(fixture.presentation.purchase(NOTES.ITEMS[0], quantity).get("ok", false))
		var identity: Dictionary = fixture.issuer.issue(&"transaction_id")
		assert_true(identity.get("ok", false), JSON.stringify(identity))
		if not identity.get("ok", false): return
		assert_false(fixture.participant.quote(NOTES.ITEMS[0], identity.value.token,
			identity.value.issuer_receipt, quantity).get("ok", false), "participant independently refuses quantity")
	var prepared: Dictionary = fixture.request_for(NOTES.ITEMS[0])
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false): return
	var request: Dictionary = prepared.value.duplicate(true)
	request.quote_id = "TEST.wrong.quote"
	assert_false(fixture.participant.prepare_purchase(request).get("ok", false))
	for changed: Dictionary in [{"price": 44}, {"price": 45.0}, {"currency": "minesweeper_coin"},
			{"max_purchases": 4}, {"effect_ids": ["money:+999"]}]:
		var row: Dictionary = fixture.catalog.get_shop_item(NOTES.ITEMS[1])
		row.merge(changed, true)
		fixture.catalog.overrides[NOTES.ITEMS[1]] = row
		assert_false(fixture.presentation.purchase(NOTES.ITEMS[1], 1).get("ok", false), JSON.stringify(changed))
		assert_false(fixture.request_for(NOTES.ITEMS[1]).get("ok", false), "raw participant record also refuses before normalization")
		fixture.catalog.overrides.clear()
	assert_eq(fixture.witness(), before)
	assert_eq(fixture.disk_text(), bytes)

func test_catalogue_registration_and_full_candidate_are_detached_and_refuse_tampering() -> void:
	if not _ready_fixture(): return
	fixture.game.money = 500
	var before: Dictionary = fixture.witness()
	var bytes: String = fixture.disk_text()
	var port := preload("res://scripts/application/shop/GameStateMinesweeperShopPort.gd").new()
	assert_true(port.configure(fixture.game, Callable(fixture.game, "capture_desktop_identity_context")).get("ok", false))
	var identity: Dictionary = fixture.issuer.issue(&"transaction_id")
	assert_true(identity.get("ok", false), JSON.stringify(identity))
	if not identity.get("ok", false): return
	var item := {"item_id": NOTES.ITEMS[0], "currency": "money", "price": 45,
		"max_purchases": 3, "effect_ids": [], "quantity": 1}
	var quote := {"transaction_id": identity.value.token, "item_id": NOTES.ITEMS[0], "currency": "money", "price": 45}
	assert_eq(port.prepare_purchase(item, quote, identity.value.token, identity.value.issuer_receipt).get("code"), &"note_catalogue_unconfigured")
	var catalogue: Dictionary = NOTES.catalogue()
	assert_true(port.configure_note_catalogue(catalogue).get("ok", false))
	catalogue[NOTES.ITEMS[0]][0].text = "TEST caller changed its copy"
	assert_true(port.configure_note_catalogue(NOTES.catalogue()).get("ok", false), "caller mutation did not change retained catalogue")
	assert_false(port.configure_note_catalogue(catalogue).get("ok", false), "replacement is refused")
	var prepared: Dictionary = port.prepare_purchase(item, quote, identity.value.token, identity.value.issuer_receipt)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false): return
	var candidate: Dictionary = prepared.value.candidate
	assert_true(port.validate_note_candidate(candidate).get("ok", false))
	for key: String in ["money", "day"]:
		var forged: Dictionary = candidate.duplicate(true)
		forged.ordinary_gameplay[key] += 1
		assert_false(port.validate_note_candidate(forged).get("ok", false), "changed full-state field: " + key)
	var forged: Dictionary = candidate.duplicate(true)
	forged.ordinary_gameplay.shop_purchase_counts[NOTES.ITEMS[0]] = 2
	assert_false(port.validate_note_candidate(forged).get("ok", false), "cannot skip note")
	prepared.value.backup.gameplay.shop_purchase_counts[NOTES.ITEMS[1]] = 3
	assert_true(port.validate_note_candidate(candidate).get("ok", false), "backup cannot change source/candidate")
	assert_eq(fixture.witness(), before, "all preparation and refusal is mutation-free")
	assert_eq(fixture.disk_text(), bytes)

func test_insufficient_money_and_invalid_counts_refuse_before_checkpoint() -> void:
	if not _ready_fixture(): return
	fixture.game.money = 44
	var bytes: String = fixture.disk_text()
	assert_false(fixture.presentation.purchase(NOTES.ITEMS[0], 1).get("ok", false))
	fixture.game.money = 500
	for count: Variant in [true, 1.0, -1, 4]:
		fixture.game.shop_purchase_counts = {NOTES.ITEMS[0]: count}
		var before: Dictionary = fixture.witness()
		assert_false(fixture.presentation.purchase(NOTES.ITEMS[0], 1).get("ok", false))
		assert_eq(fixture.witness(), before)
	assert_eq(fixture.disk_text(), bytes)
	fixture.game.shop_purchase_counts = {}

func test_completion_capture_failure_retains_pending_and_same_command_retries_once() -> void:
	if not _ready_fixture(): return
	fixture.game.money = 500
	var before: Dictionary = fixture.witness()
	fixture.arm_completion_fault()
	var failed: Dictionary = fixture.presentation.purchase(NOTES.ITEMS[0], 1)
	assert_false(failed.get("ok", false), "injected completion capture failure is not success")
	assert_eq(fixture.fault.failures, 1)
	assert_true(fixture.presentation.has_pending_purchase())
	assert_false(fixture.presentation.purchase(NOTES.ITEMS[1], 1).get("ok", false), "different command cannot steal pending custody")
	var retried: Dictionary = fixture.presentation.purchase(NOTES.ITEMS[0], 1)
	assert_true(retried.get("ok", false), JSON.stringify(retried))
	if not retried.get("ok", false): return
	assert_false(fixture.presentation.has_pending_purchase())
	assert_eq(fixture.game.money, 455, "retry debits once")
	assert_eq(fixture.game.shop_purchase_counts[NOTES.ITEMS[0]], 1, "retry unlocks once")
	_assert_preserved(before, fixture.witness())
	var saved: Dictionary = fixture.disk_snapshot()
	assert_true(saved.get("ok", false), JSON.stringify(saved))
	if saved.get("ok", false):
		assert_eq(saved.value.gameplay.money, 455)
		assert_eq(saved.value.gameplay.shop_purchase_counts[NOTES.ITEMS[0]], 1)

func test_repeated_real_load_then_new_run_retains_profile_and_resets_counts() -> void:
	if not _ready_fixture(): return
	fixture.game.money = 500
	assert_true(fixture.presentation.purchase(NOTES.ITEMS[2], 1).get("ok", false))
	var expected: Dictionary = fixture.witness()
	for repeat_index: int in 2:
		var restored: Dictionary = await fixture.load_from("autosave")
		assert_true(restored.get("ok", false), JSON.stringify(restored))
		if not restored.get("ok", false): return
		assert_eq(fixture.game.money, 455)
		assert_eq(fixture.game.shop_purchase_counts[NOTES.ITEMS[2]], 1)
		assert_eq(fixture.witness().profile, expected.profile)
		assert_eq(fixture.witness().reading, expected.reading)
	var started: Dictionary = await fixture.new_run()
	assert_true(started.get("ok", false), JSON.stringify(started))
	for item: String in NOTES.ITEMS: assert_eq(fixture.game.shop_purchase_counts.get(item, 0), 0)
	assert_eq(fixture.witness().profile, expected.profile)

func test_direct_restore_owners_refuse_bad_maps_before_mutation_or_signals() -> void:
	if not _ready_fixture(): return
	var before: Dictionary = fixture.witness()
	var restore_backup: Dictionary = fixture.game.capture_restore_state().value.backup
	var live_backup: Dictionary = fixture.game.capture_live_run_state().value.backup
	watch_signals(fixture.game)
	for invalid: Variant in [null, [], true, {"crystal_stutters": 1.0}, {"crystal_stutters": true},
			{"crystal_stutters": -1}, {"crystal_stutters": 4}, {"unrelated": -1}]:
		var plan: Dictionary = before.run.duplicate(true)
		plan.gameplay.shop_purchase_counts = invalid
		plan.gameplay.money = 999999
		assert_false(fixture.game.apply_restore_silent({"snapshot": plan}).get("ok", false))
		assert_eq(fixture.witness(), before, "apply refuses before any owner changes")
		var rollback: Dictionary = restore_backup.duplicate(true)
		rollback.gameplay.shop_purchase_counts = invalid
		rollback.gameplay.money = 999999
		assert_false(fixture.game.rollback_restore_silent(rollback).get("ok", false))
		assert_eq(fixture.witness(), before, "rollback refuses before any owner changes")
		var live: Dictionary = live_backup.duplicate(true)
		live.gameplay.shop_purchase_counts = invalid
		live.gameplay.money = 999999
		assert_false(fixture.game.restore_live_run_state(live).get("ok", false))
		assert_eq(fixture.witness(), before, "live restore refuses before any owner changes")
	for signal_name: String in ["money_changed", "coins_changed", "inventory_changed", "friends_changed", "save_relevant_state_changed"]:
		assert_signal_not_emitted(fixture.game, signal_name)

func test_omitted_map_direct_restore_owners_clear_previous_counts() -> void:
	if not _ready_fixture(): return
	var snapshot: Dictionary = fixture.game.capture_run_snapshot_input().duplicate(true)
	var rollback: Dictionary = fixture.game.capture_restore_state().value.backup
	var live: Dictionary = fixture.game.capture_live_run_state().value.backup
	snapshot.gameplay.erase("shop_purchase_counts")
	rollback.gameplay.erase("shop_purchase_counts")
	live.gameplay.erase("shop_purchase_counts")
	fixture.game.shop_purchase_counts = {"crystal_stutters": 2}
	var applied: Dictionary = fixture.game.apply_restore_silent({"snapshot": snapshot})
	assert_true(applied.get("ok", false), JSON.stringify(applied))
	assert_eq(fixture.game.shop_purchase_counts, {}, "omitted apply map explicitly clears")
	fixture.game.shop_purchase_counts = {"crystal_stutters": 2}
	var rolled_back: Dictionary = fixture.game.rollback_restore_silent(rollback)
	assert_true(rolled_back.get("ok", false), JSON.stringify(rolled_back))
	assert_eq(fixture.game.shop_purchase_counts, {}, "omitted rollback map explicitly clears")
	fixture.game.shop_purchase_counts = {"crystal_stutters": 2}
	var restored: Dictionary = fixture.game.restore_live_run_state(live)
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	assert_eq(fixture.game.shop_purchase_counts, {}, "omitted live restore map explicitly clears")
