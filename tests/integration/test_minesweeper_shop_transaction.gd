extends "res://addons/gut/test.gd"

## Production Shop purchase transaction (Plan 02 Task 7, dwm-p2r.32.7, req.shop.capabilities).
## Configures the REAL GameStateMinesweeperShopPort over the real GameState autoload, the real
## DesktopConsequenceState, the real ApplicationMutationGate, a real DesktopIdentityNonceIssuer over
## an isolated root store, and the real SaveManagerCheckpointPort's consequence-checkpoint seam
## (SaveManager over isolated storage) -- mirroring test_minesweeper_first_reveal_transaction.gd's
## own established combined wiring for exactly this kind of durable, cross-port transaction.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PORT_PATH := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const GS_PATH := "res://autoload/GameState.gd"
const STATE_PORT_PATH := "res://scripts/application/shop/GameStateMinesweeperShopPort.gd"
const PARTICIPANT_PATH := "res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd"
const CONSEQUENCE_STATE_PATH := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const REGISTRY_PATH := "res://scripts/domain/shop/MinesweeperShopRegistry.gd"
const ACTION_RECEIPT_PATH := "res://scripts/domain/desktop/DesktopActionReceipt.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"
const FAKE_FILE_OPS_PATH := "res://tests/support/FakeFileOps.gd"
const PUBLICATION_LEDGER_PATH := "res://scripts/infrastructure/save/DesktopPublicationLedger.gd"

const IDENTITY_CONTEXT := {
	"run_id": "run-shop", "branch_id": "branch-shop", "desktop_timeline_generation": 0,
	"causal_day_instance": "causal-day-shop-1",
}


func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: RefCounted = load(FAKE_FILE_OPS_PATH).new()
	var storage: Object = load(STORAGE_PATH).new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new("6".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("shop_transaction").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root.path_join("saves"))

	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(save_manager)
	save_manager.initialize(load(STORAGE_PATH).new(root.path_join("saves")))

	var checkpoint_port: Object = load(CHECKPOINT_PORT_PATH).new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(load(GATE_PATH).new()).get("ok", false))

	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	gs.money = 100
	gs.coins = 10

	var issuer := _fresh_issuer(root)
	var consequence_state: RefCounted = load(CONSEQUENCE_STATE_PATH).new()
	# `causal_day_instance` is one of the two purposes DesktopIdentityNonceIssuer.issue() refuses to
	# mint directly (reachable only through the causal-day-advance allocator, which this test does
	# not otherwise exercise); DesktopConsequenceState's own provenance check is purely structural
	# (purpose + token self-consistency, no root/issuer cross-check), so a hand-built fixture receipt
	# is a legitimate way to bootstrap this test's starting causal day.
	var day_receipt := {
		"receipt_id": "issuer_receipt.fixture-causal-day-shop-1", "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-shop-1", "numeric_value": null,
	}
	var made: Dictionary = load(CONSEQUENCE_STATE_PATH).make_empty({
		"causal_day_instance": str(day_receipt["token"]), "causal_day_instance_issuer_receipt": day_receipt,
	})
	assert_true(made.get("ok", false), JSON.stringify(made))
	var prepared_state: Dictionary = consequence_state.prepare_restore((made["value"] as Dictionary)["state"])
	consequence_state.commit((prepared_state["value"] as Dictionary)["candidate"])

	var identity_context := IDENTITY_CONTEXT.duplicate(true)
	identity_context["causal_day_instance"] = str(day_receipt["token"])
	var state_port: Object = load(STATE_PORT_PATH).new()
	assert_true(state_port.configure(gs, identity_context).get("ok", false))

	var gate := ApplicationMutationGate.new()
	# FIX (dwm-p2r.35.6 remediation, finding 5): the REAL DesktopPublicationLedger, not a hand-rolled
	# fake that accepted any kind/shape the real ledger rejects -- see
	# test_desktop_completion_transaction.gd's identical W1 fix for the full rationale.
	var publication_storage: Object = load(STORAGE_PATH).new(root.path_join("_publications"))
	var publication_ledger: Object = load(PUBLICATION_LEDGER_PATH).new()
	assert_true(publication_ledger.configure(publication_storage).get("ok", false))
	assert_true(publication_ledger.load().get("ok", false))
	var participant: Object = load(PARTICIPANT_PATH).new()
	assert_true(participant.configure_publication_ledger(publication_ledger).get("ok", false))
	assert_true(participant.configure(state_port, consequence_state, checkpoint_port,
		load(REGISTRY_PATH), issuer, gate).get("ok", false))

	return {
		"participant": participant, "gs": gs, "consequence_state": consequence_state, "gate": gate,
		"issuer": issuer, "checkpoint_port": checkpoint_port, "state_port": state_port,
		"publication_ledger": publication_ledger, "root": root, "day_token": str(day_receipt["token"]),
	}


func _mint_transaction(issuer: Object) -> Dictionary:
	var issued: Dictionary = issuer.call(&"issue", &"transaction_id")
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]),
		"transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func before_each() -> void:
	assert_true(load(REGISTRY_PATH).initialize().get("ok", false), "shop registry must load")


## Full end-to-end drive against every REAL production port this task builds: quote, prepare
## (durable action_checkpointed handoff), Task-8-substitute admission to sequence_committed, forward
## commit (real currency spend via GameState.try_spend_coins, real inventory grant), and publish.
func test_lucky_charm_purchase_transacts_exactly_once_against_real_ports() -> void:
	var wired := _wired()
	var participant: Object = wired["participant"]
	var gs: Node = wired["gs"]
	var issuer: Object = wired["issuer"]

	var txn := _mint_transaction(issuer)
	var quoted: Dictionary = participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))

	var live: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var before_coins: int = gs.coins
	var prepared: Dictionary = participant.prepare_purchase(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(prepared.get("code"), &"shop_purchase_action_checkpointed")
	assert_eq(gs.coins, before_coins, "prepare never spends currency")
	assert_eq(gs.inventory.get("lucky_charm", 0), 0, "prepare never grants the capability")

	var receipt: Dictionary = (prepared["value"] as Dictionary)["action_receipt"]
	var validated: Dictionary = load(ACTION_RECEIPT_PATH).validate(receipt)
	assert_true(validated.get("ok", false), JSON.stringify(validated))

	_force_sequence_committed(wired, txn["transaction_id"])
	var candidate: Dictionary = (prepared["value"] as Dictionary)["candidate"]
	var committed: Dictionary = participant.commit(candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(gs.coins, before_coins - 1, "the real GameState.try_spend_coins() spent exactly 1 coin")
	assert_eq(int(gs.inventory.get("lucky_charm", 0)), 1, "the real GameState.add_inventory() granted the capability")

	var published: Dictionary = participant.publish({"action_receipt": (committed["value"] as Dictionary)["action_receipt"]})
	assert_true(published.get("ok", false), JSON.stringify(published))
	var ledger: Object = wired["publication_ledger"]
	var ledger_loaded: Dictionary = ledger.load()
	assert_true(ledger_loaded.get("ok", false), JSON.stringify(ledger_loaded))
	var records: Dictionary = ((ledger_loaded["value"] as Dictionary)["document"] as Dictionary)["records"]
	assert_true(records.has("action_source:" + str(receipt["commit_receipt_id"])),
		"the REAL ledger accepted and durably recorded the real action_source publication")
	assert_false((wired["gate"] as ApplicationMutationGate).is_active(), "publish released the lease")


func test_a_second_purchase_within_the_same_prepared_purchase_conflicts() -> void:
	var wired := _wired()
	var participant: Object = wired["participant"]
	var issuer: Object = wired["issuer"]

	var txn := _mint_transaction(issuer)
	var quoted: Dictionary = participant.quote("lucky_charm", txn["transaction_id"], txn["transaction_issuer_receipt"])
	var live: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var prepared: Dictionary = participant.prepare_purchase(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))

	var second_txn := _mint_transaction(issuer)
	var second_quoted: Dictionary = participant.quote("debug_key", second_txn["transaction_id"], second_txn["transaction_issuer_receipt"])
	assert_true(second_quoted.get("ok", false), JSON.stringify(second_quoted))
	var second_request := {
		"transaction_id": second_txn["transaction_id"], "transaction_issuer_receipt": second_txn["transaction_issuer_receipt"],
		"item_id": "debug_key", "quote_id": str((second_quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var second: Dictionary = participant.prepare_purchase(second_request)
	assert_false(second.get("ok", true))
	assert_eq(second.get("code"), &"shop_purchase_requires_no_other_pending_transaction")


func test_commit_rejects_before_causal_admission_leaving_currency_and_inventory_untouched() -> void:
	var wired := _wired()
	var participant: Object = wired["participant"]
	var gs: Node = wired["gs"]
	var issuer: Object = wired["issuer"]

	var txn := _mint_transaction(issuer)
	var quoted: Dictionary = participant.quote("debug_key", txn["transaction_id"], txn["transaction_issuer_receipt"])
	var live: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "debug_key", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var prepared: Dictionary = participant.prepare_purchase(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var before_coins: int = gs.coins

	var candidate: Dictionary = (prepared["value"] as Dictionary)["candidate"]
	var rejected: Dictionary = participant.commit(candidate)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected.get("code"), &"shop_purchase_commit_requires_sequence_committed")
	assert_eq(gs.coins, before_coins)
	assert_eq(int(gs.inventory.get("debug_key", 0)), 0)


func test_supportz_purchase_decrements_the_real_round_floor_and_spends_real_money() -> void:
	var wired := _wired()
	var participant: Object = wired["participant"]
	var gs: Node = wired["gs"]
	var issuer: Object = wired["issuer"]
	var consequence_state: Object = wired["consequence_state"]

	for ordinal: int in [1, 2]:
		var recorded: Dictionary = consequence_state.prepare_record_base_completion(
			{"kind": "complete", "app_round_ordinal": ordinal, "causal_day_instance": str(wired["day_token"])})
		assert_true(recorded.get("ok", false), JSON.stringify(recorded))
		consequence_state.commit((recorded["value"] as Dictionary)["candidate"])

	var txn := _mint_transaction(issuer)
	var quoted: Dictionary = participant.quote("supportz", txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live: Dictionary = (consequence_state.capture()["value"] as Dictionary)["state"]
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": "supportz", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var before_money: int = gs.money
	var before_floor: int = gs.minesweeper_round_floor
	var prepared: Dictionary = participant.prepare_purchase(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))

	_force_sequence_committed(wired, txn["transaction_id"])
	var committed: Dictionary = participant.commit((prepared["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(gs.money, before_money - 45, "the real GameState.try_spend_money() spent exactly 45 money")
	assert_eq(gs.minesweeper_round_floor, before_floor - 1, "the real GameState.change_minesweeper_round_floor(-1) fired")


## Test-only substitute for Task 8's real DesktopCausalSequencePort admission dance, driving
## DesktopConsequenceState straight to sequence_committed -- exactly the same substitution the unit
## suite uses, since Task 8 does not exist yet.
func _force_sequence_committed(wired: Dictionary, transaction_id: String) -> void:
	var gate: ApplicationMutationGate = wired["gate"]
	var consequence_state: Object = wired["consequence_state"]
	if not gate.is_internal_owner_active(&"causal_transaction"):
		assert_true(gate.acquire(&"causal_transaction").get("ok", false))
	var live: Dictionary = (consequence_state.capture()["value"] as Dictionary)["state"]
	var pending: Dictionary = (live["pending"] as Dictionary).duplicate(true)
	assert_eq(str(pending["transaction_id"]), transaction_id)
	pending["stage"] = "sequence_committed"
	var fake_receipt := {"forced": "sequence_committed"}
	pending["admission_checkpoint_receipt"] = fake_receipt
	pending["checkpoint_receipt"] = fake_receipt
	live["pending"] = pending
	live["run_revision"] = int(live["run_revision"]) + 1
	live["causal_sequence"] = int(live["causal_sequence"]) + 1
	var prepared: Dictionary = consequence_state.prepare_restore(live)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	consequence_state.commit((prepared["value"] as Dictionary)["candidate"])
