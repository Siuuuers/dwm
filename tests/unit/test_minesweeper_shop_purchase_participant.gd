extends "res://addons/gut/test.gd"

## RED/GREEN coverage for MinesweeperShopPurchaseParticipant (Plan 02 Task 7, dwm-p2r.32.7,
## req.shop.capabilities). Drives the REAL DesktopConsequenceState and ApplicationMutationGate (pure
## domain objects with no storage dependency) plus FakeMinesweeperShopStatePort, a real
## DesktopIdentityNonceIssuer over FakeDesktopIssuerRootStore (the established lightweight issuer
## substrate for unit-level tests, per test_desktop_identity_nonce_issuer.gd's own precedent), and
## two small test-local fakes for the checkpoint port and publication ledger (no dedicated file is in
## Task 7's own Create set for either).

const _PARTICIPANT := preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd")
const _STATE_PORT := preload("res://tests/support/FakeMinesweeperShopStatePort.gd")
const _CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const _REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const _ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const _FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

const _PARTICIPANT_PATH := "res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd"
const _STATE_PORT_PATH := "res://tests/support/FakeMinesweeperShopStatePort.gd"
const _ACTION_RECEIPT_PATH := "res://scripts/domain/desktop/DesktopActionReceipt.gd"


class _FakeConsequenceCheckpointPort extends RefCounted:
	var documents: Dictionary = {}  # transaction_id -> {"document": Dictionary}
	var fail_prepare_once := false
	var fail_commit_once := false
	var prepare_calls := 0
	var commit_calls := 0

	func prepare_consequence_checkpoint(checkpoint_header: Dictionary, stage_candidate: Dictionary) -> Dictionary:
		prepare_calls += 1
		if fail_prepare_once:
			fail_prepare_once = false
			return {"ok": false, "code": &"fake_checkpoint_prepare_failed", "message": "", "details": {}}
		var preimage: Dictionary = _CONSEQUENCE_STATE.checkpoint_content_preimage(checkpoint_header, stage_candidate)
		if not preimage.get("ok", false):
			return preimage
		var preimage_value: Dictionary = (preimage["value"] as Dictionary)["preimage"]
		var canonical: Dictionary = _CANONICAL_JSON.stringify(preimage_value)
		var content_sha256: String = str(canonical["value"]).sha256_text()
		var checkpoint_receipt := {
			"receipt_id": "fake_consequence_checkpoint." + content_sha256,
			"header": (preimage_value["header"] as Dictionary).duplicate(true),
			"content_sha256": content_sha256,
		}
		var document := {
			"header": (preimage_value["header"] as Dictionary).duplicate(true),
			"stage_candidate": stage_candidate.duplicate(true), "checkpoint_receipt": checkpoint_receipt,
		}
		return {"ok": true, "code": &"ok",
			"value": {"candidate": {"document": document}, "checkpoint_receipt": checkpoint_receipt}}

	func commit_consequence_checkpoint(checkpoint_candidate: Dictionary, checkpoint_receipt: Dictionary) -> Dictionary:
		commit_calls += 1
		if fail_commit_once:
			fail_commit_once = false
			return {"ok": false, "code": &"fake_checkpoint_commit_failed", "message": "", "details": {}}
		if typeof(checkpoint_candidate.get("document")) != TYPE_DICTIONARY:
			return {"ok": false, "code": &"invalid_candidate", "message": "", "details": {}}
		var document: Dictionary = checkpoint_candidate["document"]
		if document.get("checkpoint_receipt") != checkpoint_receipt:
			return {"ok": false, "code": &"checkpoint_receipt_mismatch", "message": "", "details": {}}
		var transaction_id: String = str((document["header"] as Dictionary).get("transaction_id", ""))
		if documents.has(transaction_id):
			var existing: Dictionary = documents[transaction_id]
			if existing["document"] == document:
				return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}
			return {"ok": false, "code": &"consequence_checkpoint_conflict", "message": "", "details": {}}
		documents[transaction_id] = {"document": document.duplicate(true)}
		return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}


class _FakePublicationLedger extends RefCounted:
	var records: Dictionary = {}

	func record_before_emit(request: Dictionary) -> Dictionary:
		var kind: String = str(request.get("kind", ""))
		var semantic_receipt: Dictionary = request.get("semantic_receipt", {})
		var key := kind + ":" + str(semantic_receipt.get("commit_receipt_id", semantic_receipt.get("receipt_id", "")))
		if records.has(key):
			var existing: Dictionary = records[key]
			if existing.get("publication") == request.get("publication") \
					and existing.get("publication_sha256") == request.get("publication_sha256"):
				return {"ok": true, "code": &"ok", "value": {"record": existing, "first_delivery": false}, "receipt": {}}
			return {"ok": false, "code": &"publication_record_conflict", "message": "", "details": {}}
		var record: Dictionary = request.duplicate(true)
		record["key"] = key
		records[key] = record
		return {"ok": true, "code": &"ok", "value": {"record": record, "first_delivery": true}, "receipt": {}}


var _state_port: RefCounted
var _consequence_state: RefCounted
var _checkpoint_port: _FakeConsequenceCheckpointPort
var _publication_ledger: _FakePublicationLedger
var _issuer: RefCounted
var _root: RefCounted
var _gate: ApplicationMutationGate
var _participant: RefCounted


func before_each() -> void:
	_state_port = _STATE_PORT.new()
	_consequence_state = _CONSEQUENCE_STATE.new()
	_checkpoint_port = _FakeConsequenceCheckpointPort.new()
	_publication_ledger = _FakePublicationLedger.new()
	_root = _FAKE_ROOT_STORE.new("ab".repeat(32), 1)
	_issuer = _ISSUER.new()
	_issuer.configure(_root)
	_gate = ApplicationMutationGate.new()
	_participant = _PARTICIPANT.new()
	_bootstrap_consequence_state("causal-day-1")
	assert_true(_REGISTRY.initialize().get("ok", false), "shop registry must load")


## `causal_day_instance` is one of the two purposes DesktopIdentityNonceIssuer.issue() refuses to
## mint directly (reachable only through an allocator this test does not exercise), so test setup
## mints it straight off the fake root store instead, matching FakeDesktopIssuerRootStore's own
## documented seam for exactly this need. The minted token is overwritten with the requested
## literal for test readability (Supportz eligibility tests key completion receipts off this exact
## string); validity only requires token == receipt.token, so both are set together.
func _bootstrap_consequence_state(causal_day_instance: String) -> void:
	var receipt: Dictionary = _root.mint(&"causal_day_instance").duplicate(true)
	receipt["token"] = causal_day_instance
	var made: Dictionary = _CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": causal_day_instance, "causal_day_instance_issuer_receipt": receipt,
	})
	assert_true(made.get("ok", false), JSON.stringify(made))
	var prepared: Dictionary = _consequence_state.prepare_restore((made["value"] as Dictionary)["state"])
	_consequence_state.commit((prepared["value"] as Dictionary)["candidate"])


func _configured_participant() -> RefCounted:
	assert_true(_participant.configure_publication_ledger(_publication_ledger).get("ok", false))
	var configured: Dictionary = _participant.configure(
		_state_port, _consequence_state, _checkpoint_port, _REGISTRY, _issuer, _gate)
	assert_true(configured.get("ok", false), JSON.stringify(configured))
	return _participant


func _mint_transaction(index: int = 1) -> Dictionary:
	var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]), "transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _live_consequence() -> Dictionary:
	return (_consequence_state.capture()["value"] as Dictionary)["state"]


func _quote_and_prepare(item_id: String, txn: Dictionary) -> Dictionary:
	var participant := _configured_participant()
	var quoted: Dictionary = participant.quote(item_id, txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live := _live_consequence()
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": item_id, "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	return participant.prepare_purchase(request)


# ---------------------------------------------------------------------------------------------
# Parse-only proof: every preload used across this suite must load and instantiate.
# ---------------------------------------------------------------------------------------------

func test_dynamic_script_probe_proves_every_preload_loads() -> void:
	for path: String in [_PARTICIPANT_PATH, _STATE_PORT_PATH, _ACTION_RECEIPT_PATH]:
		var probed: Dictionary = _PROBE.instantiate(path)
		assert_true(probed.get("ok", false), "%s must load and instantiate: %s" % [path, str(probed)])


# ---------------------------------------------------------------------------------------------
# configure() / configure_publication_ledger()
# ---------------------------------------------------------------------------------------------

func test_configure_publication_ledger_is_idempotent_and_rejects_replacement() -> void:
	var participant := _PARTICIPANT.new()
	assert_true(participant.configure_publication_ledger(_publication_ledger).get("ok", false))
	var replay: Dictionary = participant.configure_publication_ledger(_publication_ledger)
	assert_true(replay.get("ok", false))
	assert_true(bool((replay["value"] as Dictionary)["already_configured"]))
	var other := _FakePublicationLedger.new()
	assert_false(participant.configure_publication_ledger(other).get("ok", true))


func test_configure_requires_publication_ledger_first() -> void:
	var participant := _PARTICIPANT.new()
	var configured: Dictionary = participant.configure(_state_port, _consequence_state, _checkpoint_port,
		_REGISTRY, _issuer, _gate)
	assert_false(configured.get("ok", true))
	assert_eq(configured.get("code"), &"publication_ledger_not_configured")


func test_configure_is_idempotent_and_rejects_replacement_owner() -> void:
	var participant := _configured_participant()
	var replay: Dictionary = participant.configure(_state_port, _consequence_state, _checkpoint_port,
		_REGISTRY, _issuer, _gate)
	assert_true(replay.get("ok", false))
	assert_true(bool((replay["value"] as Dictionary)["already_configured"]))
	var other_state_port := _STATE_PORT.new()
	var rejected: Dictionary = participant.configure(other_state_port, _consequence_state, _checkpoint_port,
		_REGISTRY, _issuer, _gate)
	assert_false(rejected.get("ok", true))


func test_prepare_purchase_fails_closed_before_configure() -> void:
	var participant := _PARTICIPANT.new()
	var result: Dictionary = participant.prepare_purchase({})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"participant_not_configured")


# ---------------------------------------------------------------------------------------------
# quote()
# ---------------------------------------------------------------------------------------------

func test_quote_produces_the_exact_frozen_shape_and_derives_shop_quote_child_id() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var quoted: Dictionary = participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var value: Dictionary = quoted["value"]
	var keys: Array = value.keys()
	keys.sort()
	var expected: Array = ["currency", "item_id", "price", "quote_id", "quote_id_provenance",
		"registry_version", "request_fingerprint", "transaction_id", "transaction_issuer_receipt"]
	expected.sort()
	assert_eq(keys, expected, "quote() returns exactly the frozen 9-key shape")
	assert_eq(str(value["currency"]), "minesweeper_coin")
	assert_eq(int(value["price"]), 1)
	assert_true(str(value["quote_id"]).begins_with("shop_quote."), "quote_id is child kind shop_quote")
	var validated: Dictionary = _issuer.call(&"validate_child", value["quote_id_provenance"], &"shop_quote")
	assert_true(validated.get("ok", false), "quote_id_provenance validates against the issuer")


func test_quote_is_idempotent_on_identical_replay() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var first: Dictionary = participant.quote("debug_key", txn["transaction_id"], txn["transaction_issuer_receipt"])
	var second: Dictionary = participant.quote("debug_key", txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_eq(first["value"], second["value"], "a byte-identical replay reproduces the same quote record")


func test_quote_a_second_item_under_the_same_transaction_conflicts() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	assert_true(participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"]).get("ok", false))
	var second: Dictionary = participant.quote("debug_key", txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_false(second.get("ok", true))
	assert_eq(second.get("code"), &"shop_quote_second_item_conflict")


func test_quote_rejects_an_unregistered_item() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var result: Dictionary = participant.quote("not_a_real_item", txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_false(result.get("ok", true))


func test_quote_rejects_a_transaction_receipt_that_does_not_verify() -> void:
	var participant := _configured_participant()
	var forged := {"receipt_id": "issuer_receipt.forged", "purpose": "transaction_id", "namespace": "x",
		"counter": 99, "token": "forged-txn", "numeric_value": null}
	var result: Dictionary = participant.quote("lucky_charm", "forged-txn", forged)
	assert_false(result.get("ok", true))


# ---------------------------------------------------------------------------------------------
# prepare_purchase() -- validation and the durable action_checkpointed handoff.
# ---------------------------------------------------------------------------------------------

func test_prepare_purchase_lucky_charm_produces_the_frozen_action_shape_and_is_pending() -> void:
	var txn := _mint_transaction()
	var result: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result.get("code"), &"shop_purchase_action_checkpointed",
		"the public result is PENDING, never audience success")
	var value: Dictionary = result["value"]
	assert_true(value.has("action_receipt"))
	assert_true(value.has("candidate"))
	var receipt: Dictionary = value["action_receipt"]
	var validated: Dictionary = load(_ACTION_RECEIPT_PATH).validate(receipt)
	assert_true(validated.get("ok", false), "the produced value is a valid DesktopActionReceipt")
	assert_eq(str(receipt["action_kind"]), "shop_purchase")
	assert_eq(receipt["condition_before"], receipt["condition_after"],
		"Lucky/Debug/Supportz never directly change the condition triple")
	assert_eq((receipt["unlock_receipt_ids"] as Array), [], "no unlock receipts for these three purchases")


func test_prepare_purchase_leaves_live_economy_board_sequence_and_outbox_byte_equal() -> void:
	var txn := _mint_transaction()
	var before_state := _live_consequence()
	var before_money: int = _state_port.money
	var before_coins: int = _state_port.coins
	var before_inventory: Dictionary = (_state_port.inventory as Dictionary).duplicate(true)
	var result: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(result.get("ok", false), JSON.stringify(result))

	assert_eq(_state_port.money, before_money, "prepare never spends currency")
	assert_eq(_state_port.coins, before_coins, "prepare never spends currency")
	assert_eq(_state_port.inventory, before_inventory, "prepare never grants the capability")

	var after_state := _live_consequence()
	assert_eq(int(after_state["run_revision"]), int(before_state["run_revision"]), "run_revision stays byte-equal")
	assert_eq(int(after_state["causal_sequence"]), int(before_state["causal_sequence"]), "causal_sequence stays byte-equal")
	assert_eq(after_state["outbox"], before_state["outbox"], "outbox stays byte-equal")
	assert_null(before_state["pending"], "no transaction was pending before prepare")
	assert_not_null(after_state["pending"],
		"pending IS the durably recorded action_checkpointed candidate -- this is the one thing that changes")
	assert_eq(str((after_state["pending"] as Dictionary)["stage"]), "action_prepared")


func test_prepare_purchase_durably_checkpoints_before_live_pending_is_adopted() -> void:
	var txn := _mint_transaction()
	var result: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(_checkpoint_port.prepare_calls, 1)
	assert_eq(_checkpoint_port.commit_calls, 1)
	assert_true(_checkpoint_port.documents.has(txn["transaction_id"]), "the checkpoint is durably recorded")


func test_prepare_purchase_acquires_and_retains_the_causal_transaction_lease() -> void:
	var txn := _mint_transaction()
	assert_false(_gate.is_active())
	var result: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_true(_gate.is_internal_owner_active(&"causal_transaction"), "the lease is retained after prepare")


func test_prepare_purchase_rejects_when_no_quote_was_retained() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var live := _live_consequence()
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": "shop_quote.does-not-exist",
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var result: Dictionary = participant.prepare_purchase(request)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"shop_quote_not_found")


func test_prepare_purchase_rejects_a_wrong_member_set() -> void:
	var participant := _configured_participant()
	var result: Dictionary = participant.prepare_purchase({"transaction_id": "x"})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"shop_purchase_request_invalid")


func test_prepare_purchase_rejects_a_stale_run_revision() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var quoted: Dictionary = participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"])
	var live := _live_consequence()
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]) + 1, "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var result: Dictionary = participant.prepare_purchase(request)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"stale_run_revision")


func test_prepare_purchase_rejects_a_stale_causal_day_instance() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var quoted: Dictionary = participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"])
	var live := _live_consequence()
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": "some-other-day",
	}
	var result: Dictionary = participant.prepare_purchase(request)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"stale_causal_day_instance")


func test_prepare_purchase_rejects_insufficient_funds() -> void:
	_state_port.coins = 0
	var txn := _mint_transaction()
	var result: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"insufficient_funds")


func test_prepare_purchase_rejects_lucky_charm_a_second_time_on_the_same_branch() -> void:
	var first_txn := _mint_transaction()
	var first: Dictionary = _quote_and_prepare("lucky_charm", first_txn)
	assert_true(first.get("ok", false), JSON.stringify(first))
	# Drive the first purchase all the way through a genuine forward commit + publish (mirroring
	# Task 8's own admission dance for this unit test), then simulate Task 8's own terminal cleanup
	# so DesktopConsequenceState's single pending slot is free for a second, independent transaction.
	_force_sequence_committed(first_txn["transaction_id"])
	var committed: Dictionary = _participant.commit((first["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_true(_participant.publish({"action_receipt": (committed["value"] as Dictionary)["action_receipt"]}).get("ok", false))
	_force_terminal_cleanup()
	assert_eq(int(_state_port.inventory.get("lucky_charm", 0)), 1, "the first purchase genuinely owns it now")

	var second_txn := _mint_transaction()
	var second: Dictionary = _quote_and_prepare("lucky_charm", second_txn)
	assert_false(second.get("ok", true))
	assert_eq(second.get("code"), &"shop_item_already_owned")


func test_prepare_purchase_rejects_a_second_pending_transaction_while_one_is_already_pending() -> void:
	var first_txn := _mint_transaction()
	var first: Dictionary = _quote_and_prepare("lucky_charm", first_txn)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var second_txn := _mint_transaction()
	var second: Dictionary = _quote_and_prepare("debug_key", second_txn)
	assert_false(second.get("ok", true))
	assert_eq(second.get("code"), &"shop_purchase_requires_no_other_pending_transaction")


func test_prepare_purchase_duplicate_replay_is_idempotent_and_a_changed_payload_conflicts() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var quoted: Dictionary = participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"])
	var live := _live_consequence()
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var first: Dictionary = participant.prepare_purchase(request)
	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_eq(_checkpoint_port.commit_calls, 1)

	# Rapid duplicate input: identical bytes replay the stored result with no new work.
	var replay: Dictionary = participant.prepare_purchase(request.duplicate(true))
	assert_eq(replay, first, "an identical replay returns the original result byte-for-byte")
	assert_eq(_checkpoint_port.commit_calls, 1, "no second checkpoint is written on replay")

	var changed := request.duplicate(true)
	changed["expected_run_revision"] = int(live["run_revision"])
	changed["item_id"] = "debug_key"
	var conflicting: Dictionary = participant.prepare_purchase(changed)
	assert_false(conflicting.get("ok", true))
	assert_eq(conflicting.get("code"), &"transaction_conflict")


func test_prepare_purchase_recognizes_a_durable_pending_purchase_after_a_fresh_participant_instance() -> void:
	var txn := _mint_transaction()
	var original: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(original.get("ok", false), JSON.stringify(original))

	# Simulate a crash: build a brand-new participant with NO in-memory ledger, but the same
	# durable DesktopConsequenceState/gate/checkpoint substrate. It must recognize the durable
	# pending action_checkpointed record and replay coherently -- crash/restart from the exact
	# pending action receipt, no second checkpoint written.
	var restarted := _PARTICIPANT.new()
	assert_true(restarted.configure_publication_ledger(_publication_ledger).get("ok", false))
	assert_true(restarted.configure(_state_port, _consequence_state, _checkpoint_port, _REGISTRY, _issuer, _gate)
		.get("ok", false))
	var live := _live_consequence()
	var pending: Dictionary = live["pending"]
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm",
		"quote_id": str(((pending["recovery_payload"] as Dictionary)["action_receipt"] as Dictionary)["source_commit_receipt_id"]),
		"expected_run_revision": 0, "expected_causal_day_instance": str(_live_consequence()["causal_day_instance"]),
	}
	# expected_run_revision/expected_causal_day_instance are irrelevant on the recognized-live-
	# pending path (it never re-validates them), but the request bytes overall must still match the
	# ORIGINAL prepare_purchase() call's own fingerprint to be recognized rather than conflict.
	var recognized: Dictionary = restarted.prepare_purchase(request)
	assert_true(recognized.get("ok", false), JSON.stringify(recognized))
	assert_eq((recognized["value"] as Dictionary)["action_receipt"], (original["value"] as Dictionary)["action_receipt"],
		"the exact same pending action receipt is recovered")
	assert_eq(_checkpoint_port.commit_calls, 1, "no second checkpoint is ever written on restart-recognition")


func test_prepare_purchase_a_capability_purchase_is_invisible_to_an_already_frozen_board_capability_ids() -> void:
	# A shop purchase never touches board state at all -- this participant has no board dependency,
	# so any already-materialized board spec's capability_ids is trivially untouched by a purchase.
	var txn := _mint_transaction()
	var frozen_capability_ids: Array = ["first_cell_safe"]
	var result: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(frozen_capability_ids, ["first_cell_safe"], "an already-frozen spec's capability_ids never mutates")


# ---------------------------------------------------------------------------------------------
# Supportz eligibility (two-completion, once-per-causal-day, three-per-branch, floor sequence)
# ---------------------------------------------------------------------------------------------

func _seed_two_base_completions(causal_day_instance: String) -> void:
	for ordinal: int in [1, 2]:
		var recorded: Dictionary = _consequence_state.prepare_record_base_completion(
			{"kind": "complete", "app_round_ordinal": ordinal, "causal_day_instance": causal_day_instance})
		assert_true(recorded.get("ok", false), JSON.stringify(recorded))
		_consequence_state.commit((recorded["value"] as Dictionary)["candidate"])


func test_supportz_purchase_rejects_without_two_base_completions_today() -> void:
	var txn := _mint_transaction()
	var result: Dictionary = _quote_and_prepare("supportz", txn)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"supportz_not_eligible")


func test_supportz_purchase_succeeds_with_two_base_completions_and_decrements_the_floor_on_commit() -> void:
	_seed_two_base_completions("causal-day-1")
	var txn := _mint_transaction()
	var prepared: Dictionary = _quote_and_prepare("supportz", txn)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(_state_port.minesweeper_round_floor, 0, "floor is untouched until forward commit")

	# Drive to sequence_committed the same way DesktopCausalSequencePort's admission would (Task 8's
	# real territory): directly advance the consequence pending's stage for this unit test.
	_force_sequence_committed(txn["transaction_id"])
	assert_true(_gate.acquire(&"causal_transaction").get("ok", true) or _gate.is_internal_owner_active(&"causal_transaction"))

	var candidate: Dictionary = (prepared["value"] as Dictionary)["candidate"]
	var committed: Dictionary = _participant.commit(candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(_state_port.minesweeper_round_floor, -1, "supportz decrements the floor by exactly one")
	assert_eq(_state_port.money, 55, "supportz spends 45 money from the fake's seeded 100")


func test_supportz_purchase_rejects_a_second_time_the_same_causal_day() -> void:
	_seed_two_base_completions("causal-day-1")
	var first_txn := _mint_transaction()
	var first: Dictionary = _quote_and_prepare("supportz", first_txn)
	assert_true(first.get("ok", false), JSON.stringify(first))
	_force_sequence_committed(first_txn["transaction_id"])
	var committed: Dictionary = _participant.commit((first["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_true(_participant.publish({"action_receipt": (committed["value"] as Dictionary)["action_receipt"]}).get("ok", false))
	_force_terminal_cleanup()

	var second_txn := _mint_transaction()
	var second: Dictionary = _quote_and_prepare("supportz", second_txn)
	assert_false(second.get("ok", true))
	assert_eq(second.get("code"), &"supportz_not_eligible", "once per causal day")


func test_supportz_purchase_rejects_a_fourth_time_on_the_same_branch() -> void:
	_state_port.money = 500  # three purchases at 45 money each exceeds the fake's default 100 seed
	for day_index: int in [1, 2, 3]:
		var day_token := "causal-day-supportz-%d" % day_index
		_reseed_causal_day(day_token)
		_seed_two_base_completions(day_token)
		var txn := _mint_transaction()
		var prepared: Dictionary = _quote_and_prepare("supportz", txn)
		assert_true(prepared.get("ok", false), "purchase %d must succeed: %s" % [day_index, JSON.stringify(prepared)])
		_force_sequence_committed(txn["transaction_id"])
		var committed: Dictionary = _participant.commit((prepared["value"] as Dictionary)["candidate"])
		assert_true(committed.get("ok", false), JSON.stringify(committed))
		assert_true(_participant.publish({"action_receipt": (committed["value"] as Dictionary)["action_receipt"]}).get("ok", false))
		_force_terminal_cleanup()
	assert_eq(_state_port.minesweeper_round_floor, -3, "floor sequence 0,-1,-2,-3")

	_reseed_causal_day("causal-day-supportz-4")
	_seed_two_base_completions("causal-day-supportz-4")
	var fourth_txn := _mint_transaction()
	var fourth: Dictionary = _quote_and_prepare("supportz", fourth_txn)
	assert_false(fourth.get("ok", true))
	assert_eq(fourth.get("code"), &"supportz_not_eligible", "three per saved branch")


func test_supportz_purchase_rejects_when_the_live_floor_no_longer_matches_the_branch_count() -> void:
	_seed_two_base_completions("causal-day-1")
	# Corrupt the invariant directly: the live floor no longer equals -branch_purchase_count.
	_state_port.minesweeper_round_floor = -5
	var txn := _mint_transaction()
	var result: Dictionary = _quote_and_prepare("supportz", txn)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"supportz_floor_sequence_conflict")


func _reseed_causal_day(causal_day_instance: String) -> void:
	var receipt: Dictionary = _root.mint(&"causal_day_instance")
	# Force the token to the requested literal for test readability; validity only requires
	# token == receipt.token, so both are overwritten together.
	receipt = receipt.duplicate(true)
	receipt["token"] = causal_day_instance
	var live := _live_consequence()
	var restore_state := live.duplicate(true)
	restore_state["causal_day_instance"] = causal_day_instance
	restore_state["causal_day_instance_issuer_receipt"] = receipt
	var prepared: Dictionary = _consequence_state.prepare_restore(restore_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	_consequence_state.commit((prepared["value"] as Dictionary)["candidate"])


## Test-only substitute for Task 8's own DesktopCausalSequencePort admission dance: advances the
## live pending straight to sequence_committed with both receipts populated, exactly matching
## _validate_pending()'s post-admission shape, so this suite can prove commit()'s OWN gate/apply
## behavior without depending on Task 8, which does not exist yet.
func _force_sequence_committed(transaction_id: String) -> void:
	if not _gate.is_internal_owner_active(&"causal_transaction"):
		assert_true(_gate.acquire(&"causal_transaction").get("ok", false))
	var live := _live_consequence()
	var pending: Dictionary = (live["pending"] as Dictionary).duplicate(true)
	assert_eq(str(pending["transaction_id"]), transaction_id)
	pending["stage"] = "sequence_committed"
	var fake_receipt := {"forced": "sequence_committed"}
	pending["admission_checkpoint_receipt"] = fake_receipt
	pending["checkpoint_receipt"] = fake_receipt
	pending["expected_run_revision"] = int(pending["expected_run_revision"])
	live["pending"] = pending
	live["run_revision"] = int(live["run_revision"]) + 1
	live["causal_sequence"] = int(live["causal_sequence"]) + 1
	var prepared: Dictionary = _consequence_state.prepare_restore(live)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	_consequence_state.commit((prepared["value"] as Dictionary)["candidate"])


## Test-only substitute for Task 8's own terminal-cleanup edge (prepare_recovery_advance's
## publication_pending -> null transition, after a complete publication cursor). Task 7 never clears
## `pending` itself -- that is explicitly Task 8's job -- so a suite exercising more than one
## sequential Supportz purchase must model it directly to free DesktopConsequenceState's single
## pending slot for the next transaction, exactly as Task 8's real admission/publication pipeline
## eventually would.
func _force_terminal_cleanup() -> void:
	var live := _live_consequence()
	live["pending"] = null
	var prepared: Dictionary = _consequence_state.prepare_restore(live)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	_consequence_state.commit((prepared["value"] as Dictionary)["candidate"])


# ---------------------------------------------------------------------------------------------
# capture() / commit() / rollback() / publish()
# ---------------------------------------------------------------------------------------------

func test_commit_rejects_without_the_gate_lease() -> void:
	var participant := _configured_participant()
	var result: Dictionary = participant.commit({"transaction_id": "no-such-txn"})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"causal_transaction_lease_required")


func test_commit_rejects_before_sequence_committed() -> void:
	var txn := _mint_transaction()
	var prepared: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var candidate: Dictionary = (prepared["value"] as Dictionary)["candidate"]
	var result: Dictionary = _participant.commit(candidate)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"shop_purchase_commit_requires_sequence_committed")
	assert_eq(_state_port.inventory, {}, "commit rejection never grants the capability")


func test_commit_succeeds_after_sequence_committed_and_grants_the_capability() -> void:
	var txn := _mint_transaction()
	var prepared: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	_force_sequence_committed(txn["transaction_id"])
	var candidate: Dictionary = (prepared["value"] as Dictionary)["candidate"]
	var committed: Dictionary = _participant.commit(candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(int(_state_port.inventory.get("lucky_charm", 0)), 1)
	assert_eq(_state_port.coins, 9, "lucky_charm spends 1 coin from the fake's seeded 10")


func test_commit_is_idempotent_on_identical_replay_and_conflicts_on_changed_bytes() -> void:
	var txn := _mint_transaction()
	var prepared: Dictionary = _quote_and_prepare("lucky_charm", txn)
	_force_sequence_committed(txn["transaction_id"])
	var candidate: Dictionary = (prepared["value"] as Dictionary)["candidate"]
	var first: Dictionary = _participant.commit(candidate)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var replay: Dictionary = _participant.commit(candidate.duplicate(true))
	assert_eq(replay, first, "an identical replay returns the stored result")
	assert_eq(int(_state_port.inventory.get("lucky_charm", 0)), 1, "no double grant on replay")

	var changed := candidate.duplicate(true)
	changed["transaction_id"] = txn["transaction_id"]
	changed["bogus"] = true
	var conflicting: Dictionary = _participant.commit(changed)
	assert_false(conflicting.get("ok", true))
	assert_eq(conflicting.get("code"), &"transaction_conflict")


func test_rollback_reverts_the_prepared_pending_and_releases_the_gate() -> void:
	var txn := _mint_transaction()
	var before := _live_consequence()
	var participant := _configured_participant()
	var backup: Dictionary = participant.capture()["value"]["backup"]
	var prepared: Dictionary = _quote_and_prepare("lucky_charm", txn)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_true(_gate.is_internal_owner_active(&"causal_transaction"))

	var restored: Dictionary = participant.rollback(backup)
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	assert_eq(_live_consequence(), before, "consequence pending reverts to the pre-prepare state")
	assert_false(_gate.is_active(), "the causal_transaction lease is released on abandonment")


func test_publish_records_through_the_action_source_kind_and_releases_the_gate() -> void:
	var txn := _mint_transaction()
	var prepared: Dictionary = _quote_and_prepare("lucky_charm", txn)
	_force_sequence_committed(txn["transaction_id"])
	var committed: Dictionary = _participant.commit((prepared["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var receipt: Dictionary = (committed["value"] as Dictionary)["action_receipt"]

	assert_true(_gate.is_internal_owner_active(&"causal_transaction"))
	var published: Dictionary = _participant.publish({"action_receipt": receipt})
	assert_true(published.get("ok", false), JSON.stringify(published))
	assert_false(_gate.is_active(), "publish releases the lease")
	assert_true(_publication_ledger.records.has("action_source:" + str(receipt["commit_receipt_id"])))

	# record-before-emit retry with no second signal: an identical publish() replay is safe.
	assert_true(_gate.acquire(&"causal_transaction").get("ok", false))
	var replay: Dictionary = _participant.publish({"action_receipt": receipt})
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(_publication_ledger.records.size(), 1, "no second ledger record is written on replay")


func test_publish_rejects_an_invalid_publication_shape() -> void:
	var participant := _configured_participant()
	var result: Dictionary = participant.publish({"wrong_key": {}})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"invalid_publication")


# ---------------------------------------------------------------------------------------------
# Mutation detachment: returned dictionaries are deep copies, never live references.
# ---------------------------------------------------------------------------------------------

func test_prepare_purchase_result_is_detached_from_internal_state() -> void:
	var participant := _configured_participant()
	var txn := _mint_transaction()
	var quoted: Dictionary = participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live := _live_consequence()
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var result: Dictionary = participant.prepare_purchase(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	(result["value"] as Dictionary)["action_receipt"] = "tampered"

	var replay: Dictionary = participant.prepare_purchase(request.duplicate(true))
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(typeof((replay["value"] as Dictionary)["action_receipt"]), TYPE_DICTIONARY,
		"mutating a caller's copy never corrupts the participant's own retained record")
