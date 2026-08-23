extends "res://addons/gut/test.gd"

## Production Shop condition-driven contract departure (Plan 02 Task 8, dwm-p2r.32,
## req.shop.capabilities, req.minesweeper.causal_departure, req.desktop.cross_app_actions).
## Configures the same real domain/application ports as test_desktop_completion_transaction.gd (see
## that file's own doc comment for the FakeDesktopConsequenceCheckpointPort scope note) -- a real
## GameState-backed MinesweeperShopPurchaseParticipant, real DesktopBoardFatePort/
## DesktopCausalSequencePort/DesktopConsequenceCoordinator, and a real MinesweeperRoundCoordinator
## whose board a Shop purchase's condition-driven departure discards or forfeits. The fake condition
## policy port and ScheduleView port are Plan 02's own Task-8 contract fakes throughout -- Plan 03
## alone owns their real production law.
##
## Representative coverage of the shop-purchase departure path (discard an unstarted candidate;
## forfeit a started round; leave a no-departure purchase's board untouched), not an exhaustive
## permutation of every crash point named in the brief's Step 8.2 enumeration -- see the Task-8
## report for an explicit, honest note on what is representative rather than exhaustive here.

const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PORT_PATH := "res://tests/support/FakeDesktopConsequenceCheckpointPort.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GS_PATH := "res://autoload/GameState.gd"
const SHOP_STATE_PORT_PATH := "res://scripts/application/shop/GameStateMinesweeperShopPort.gd"
const BOARD_STATE_PORT_PATH := "res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd"
const SHOP_PARTICIPANT_PATH := "res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd"
const ROUND_COORDINATOR_PATH := "res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd"
const CONSEQUENCE_COORDINATOR_PATH := "res://scripts/application/desktop/DesktopConsequenceCoordinator.gd"
const CAUSAL_SEQUENCE_PORT_PATH := "res://scripts/application/desktop/DesktopCausalSequencePort.gd"
const BOARD_FATE_PORT_PATH := "res://scripts/application/minesweeper/DesktopBoardFatePort.gd"
const CONSEQUENCE_STATE_PATH := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const REGISTRY_PATH := "res://scripts/domain/shop/MinesweeperShopRegistry.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"
const FAKE_FILE_OPS_PATH := "res://tests/support/FakeFileOps.gd"
const FAKE_MINESWEEPER_CHECKPOINT_PATH := "res://tests/support/FakeMinesweeperCheckpointPort.gd"
const FAKE_MINESWEEPER_GENERATION_PATH := "res://tests/support/FakeMinesweeperGenerationPort.gd"
const CONDITION_POLICY_PORT_PATH := "res://tests/support/FakeDesktopConditionPolicyPort.gd"
const SCHEDULE_VIEW_PORT_PATH := "res://tests/support/FakeScheduleDepartureViewPort.gd"
const PUBLICATION_LEDGER_PATH := "res://scripts/infrastructure/save/DesktopPublicationLedger.gd"

const IDENTITY_CONTEXT := {
	"run_id": "run-shop-departure", "branch_id": "branch-shop-departure", "desktop_timeline_generation": 0,
	"causal_day_instance": "causal-day-shop-departure-1",
}


func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: RefCounted = load(FAKE_FILE_OPS_PATH).new()
	var storage: Object = load(STORAGE_PATH).new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new("8".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("shop_departure").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root)

	var checkpoint_port: Object = load(CHECKPOINT_PORT_PATH).new()
	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	gs.money = 100
	gs.coins = 10

	var issuer := _fresh_issuer(root)
	var consequence_state: RefCounted = load(CONSEQUENCE_STATE_PATH).new()
	var day_receipt := {
		"receipt_id": "issuer_receipt.fixture-causal-day-shop-departure-1", "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-shop-departure-1", "numeric_value": null,
	}
	var made: Dictionary = load(CONSEQUENCE_STATE_PATH).make_empty({
		"causal_day_instance": str(day_receipt["token"]), "causal_day_instance_issuer_receipt": day_receipt,
	})
	assert_true(made.get("ok", false), JSON.stringify(made))
	var prepared_state: Dictionary = consequence_state.prepare_restore((made["value"] as Dictionary)["state"])
	consequence_state.commit((prepared_state["value"] as Dictionary)["candidate"])

	var identity_context := IDENTITY_CONTEXT.duplicate(true)
	identity_context["causal_day_instance"] = str(day_receipt["token"])

	var gate := ApplicationMutationGate.new()
	# FIX (dwm-p2r.13 remediation, finding W1): the REAL DesktopPublicationLedger, not a hand-rolled
	# fake -- see test_desktop_completion_transaction.gd's identical fix for the full rationale.
	var publication_storage: Object = load(STORAGE_PATH).new(root.path_join("_publications"))
	var publication_ledger: Object = load(PUBLICATION_LEDGER_PATH).new()
	assert_true(publication_ledger.configure(publication_storage).get("ok", false))
	assert_true(publication_ledger.load().get("ok", false))

	var board_state_port: Object = load(BOARD_STATE_PORT_PATH).new()
	assert_true(board_state_port.configure(gs, issuer, identity_context).get("ok", false))
	var round_coordinator: Object = load(ROUND_COORDINATOR_PATH).new()
	assert_true(round_coordinator.configure(board_state_port, load(FAKE_MINESWEEPER_CHECKPOINT_PATH).new(),
		load(FAKE_MINESWEEPER_GENERATION_PATH).new(), issuer).get("ok", false))
	assert_true(round_coordinator.configure_publication_ledger(publication_ledger).get("ok", false))
	var mine_indices: Array[int] = [1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
	(round_coordinator._generation_port as Object).arm_materialize(
		{"schema_version": 1, "width": 9, "height": 9, "mine_indices": mine_indices, "mine_count": mine_indices.size()})

	var shop_state_port: Object = load(SHOP_STATE_PORT_PATH).new()
	assert_true(shop_state_port.configure(gs, identity_context).get("ok", false))
	var shop_participant: Object = load(SHOP_PARTICIPANT_PATH).new()
	assert_true(shop_participant.configure_publication_ledger(publication_ledger).get("ok", false))
	assert_true(shop_participant.configure(shop_state_port, consequence_state, checkpoint_port,
		load(REGISTRY_PATH), issuer, gate).get("ok", false))

	var board_fate_port: Object = load(BOARD_FATE_PORT_PATH).new()
	assert_true(board_fate_port.configure_publication_ledger(publication_ledger).get("ok", false))
	assert_true(board_fate_port.configure(round_coordinator._board_state, issuer).get("ok", false))

	var causal_sequence_port: Object = load(CAUSAL_SEQUENCE_PORT_PATH).new()
	assert_true(causal_sequence_port.configure_publication_ledger(publication_ledger).get("ok", false))
	assert_true(causal_sequence_port.configure(consequence_state, gate, checkpoint_port).get("ok", false))

	var coordinator: Object = load(CONSEQUENCE_COORDINATOR_PATH).new()
	assert_true(coordinator.configure(consequence_state, causal_sequence_port, board_fate_port, checkpoint_port, gate).get("ok", false))
	assert_true(coordinator.configure_action_source_ports(round_coordinator, shop_participant).get("ok", false))
	var condition_policy_port: Object = load(CONDITION_POLICY_PORT_PATH).new()
	assert_true(condition_policy_port.configure(RefCounted.new()).get("ok", false))
	var schedule_view_port: Object = load(SCHEDULE_VIEW_PORT_PATH).new()
	assert_true(coordinator.configure_condition_departure_ports(condition_policy_port, schedule_view_port).get("ok", false))
	# Review-fix pass (dwm-p2r.32.8, CRITICAL 1): accept_prepared_action()'s own outer receipt now
	# requires an injected issuer -- the same production issuer already retained above.
	assert_true(coordinator.configure_identity_issuer(issuer).get("ok", false))

	return {
		"gs": gs, "issuer": issuer, "consequence_state": consequence_state, "gate": gate,
		"round_coordinator": round_coordinator, "shop_participant": shop_participant, "coordinator": coordinator,
		"board_fate_port": board_fate_port, "publication_ledger": publication_ledger,
		"condition_policy_port": condition_policy_port, "schedule_view_port": schedule_view_port,
		"shop_state_port": shop_state_port,
	}


func before_each() -> void:
	assert_true(load(REGISTRY_PATH).initialize().get("ok", false), "shop registry must load")


func _mint_transaction(issuer: Object) -> Dictionary:
	var issued: Dictionary = issuer.call(&"issue", &"transaction_id")
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]),
		"transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _shop_prepared(wired: Dictionary, item_id: String) -> Dictionary:
	var shop_participant: Object = wired["shop_participant"]
	var issuer: Object = wired["issuer"]
	var txn := _mint_transaction(issuer)
	var quoted: Dictionary = shop_participant.quote(item_id, txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	var prepared: Dictionary = shop_participant.prepare_purchase({
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": item_id, "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(prepared.get("code"), &"shop_purchase_action_checkpointed")
	return {"action_receipt": (prepared["value"] as Dictionary)["action_receipt"]}


## A Shop purchase during a PREPARING (unstarted) candidate, condition-armed for a departure: the
## real GameState economy commits (capability granted) AND the real board discards the unstarted
## candidate -- both through the same admitted causal transaction.
func test_shop_purchase_departure_discards_an_unstarted_candidate() -> void:
	var wired := _wired()
	var round_coordinator: Object = wired["round_coordinator"]
	var issuer: Object = wired["issuer"]
	var identity: Dictionary = round_coordinator.get_entry_context("beginner")["value"]["identity"]
	var begin_txn := _mint_transaction(issuer)
	var begun: Dictionary = round_coordinator.begin_debug_preparation({
		"transaction_id": begin_txn["transaction_id"], "transaction_issuer_receipt": begin_txn["transaction_issuer_receipt"],
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner",
	})
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	assert_eq(round_coordinator.get_state()["value"]["phase"], "PREPARING")

	var prepared := _shop_prepared(wired, "debug_key")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	# Review-fix pass (dwm-p2r.32.8, CRITICAL 2): the brief requires a departure to enqueue exactly
	# one destination intent -- arm one so this pre-existing departure fixture stays valid under the
	# coordinator's own new pairing law.
	var action_receipt_for_intent: Dictionary = prepared["action_receipt"]
	var destination_derived: Dictionary = issuer.derive_child({
		"child_kind": "destination_intent", "ordinal": 0,
		"parent_receipt_id": str((action_receipt_for_intent["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": [action_txn],
	})
	assert_true(destination_derived.get("ok", false), JSON.stringify(destination_derived))
	var destination_intent := {
		"intent_id": str((destination_derived["value"] as Dictionary)["child_id"]),
		"intent_id_provenance": (destination_derived["value"] as Dictionary)["provenance"],
		"kind": "hospital_day", "day": 3, "causal_day_instance": "causal-day-1",
		"source_condition_receipt_id": "condition.fake.placeholder",
		"source_condition_receipt_provenance": {"schema_version": 1, "parent_receipt_id": "",
			"child_kind": "condition", "ordinal": 0, "source_ids": [action_txn], "child_id": ""},
		"accepted_unfulfilled_sources": [], "terminal_cause": null, "terminal_provenance": null,
		"prerequisite_receipt_ids": [],
	}
	(wired["condition_policy_port"] as Object).arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)

	var coordinator: Object = wired["coordinator"]
	# Recover the ordinal-0 checkpoint receipt directly from the shared checkpoint port instance
	# (the participant and the coordinator share the SAME configured checkpoint_port object).
	var shop_participant: Object = wired["shop_participant"]
	var raw_checkpoint_port: Object = shop_participant._checkpoint_port
	var prepared_checkpoint: Dictionary = {}
	for record: Dictionary in (raw_checkpoint_port as Object).commit_log:
		if str((record["receipt"] as Dictionary)["checkpoint_id"]).find(action_txn) >= 0:
			prepared_checkpoint = record["receipt"]
	assert_false(prepared_checkpoint.is_empty())

	var economy_candidate: Dictionary = (shop_participant._transactions[action_txn] as Dictionary)["economy_candidate"]
	var live_board: Dictionary = round_coordinator._board_state.capture()
	var result: Dictionary = coordinator.accept_prepared_action({
		"action_receipt": prepared["action_receipt"], "action_candidate": economy_candidate,
		"prepared_checkpoint_receipt": prepared_checkpoint, "expected_run_revision": 0,
		"expected_board_identity": live_board["identity"], "expected_board_revision": int(live_board["revision"]),
	})
	assert_true(result.get("ok", false), JSON.stringify(result))
	# Review-fix pass (dwm-p2r.32.8, CRITICAL 1): the frozen shape has no "departure" key -- read the
	# disposition off the receipt instead.
	assert_eq(str(result["receipt"]["disposition"]), "departure_committed")

	assert_eq(round_coordinator.get_state()["value"]["phase"], "NONE", "the unstarted candidate was discarded")
	assert_eq(int((wired["gs"] as Node).inventory.get("debug_key", 0)), 1, "the real economy still committed")
	assert_true((wired["schedule_view_port"] as Object).commit_calls >= 1)


## A no-departure Shop purchase leaves an in-flight PREPARING candidate completely untouched.
func test_shop_purchase_without_a_departure_leaves_the_board_untouched() -> void:
	var wired := _wired()
	var round_coordinator: Object = wired["round_coordinator"]
	var issuer: Object = wired["issuer"]
	var identity: Dictionary = round_coordinator.get_entry_context("beginner")["value"]["identity"]
	var begin_txn := _mint_transaction(issuer)
	round_coordinator.begin_debug_preparation({
		"transaction_id": begin_txn["transaction_id"], "transaction_issuer_receipt": begin_txn["transaction_issuer_receipt"],
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner",
	})
	var before_board: Dictionary = round_coordinator.get_state()["value"]

	var prepared := _shop_prepared(wired, "lucky_charm")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	# No arm() call: the fake condition policy defaults to no_departure.

	var shop_participant: Object = wired["shop_participant"]
	var raw_checkpoint_port: Object = shop_participant._checkpoint_port
	var prepared_checkpoint: Dictionary = {}
	for record: Dictionary in (raw_checkpoint_port as Object).commit_log:
		if str((record["receipt"] as Dictionary)["checkpoint_id"]).find(action_txn) >= 0:
			prepared_checkpoint = record["receipt"]

	var economy_candidate: Dictionary = (shop_participant._transactions[action_txn] as Dictionary)["economy_candidate"]
	var live_board: Dictionary = round_coordinator._board_state.capture()
	var coordinator: Object = wired["coordinator"]
	var result: Dictionary = coordinator.accept_prepared_action({
		"action_receipt": prepared["action_receipt"], "action_candidate": economy_candidate,
		"prepared_checkpoint_receipt": prepared_checkpoint, "expected_run_revision": 0,
		"expected_board_identity": live_board["identity"], "expected_board_revision": int(live_board["revision"]),
	})
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(str(result["receipt"]["disposition"]), "no_departure")
	assert_eq(round_coordinator.get_state()["value"], before_board, "the unrelated in-flight candidate is byte-identical")
	assert_eq(int((wired["gs"] as Node).inventory.get("lucky_charm", 0)), 1)
	assert_eq((wired["schedule_view_port"] as Object).commit_calls, 0, "no-departure never calls the view port")
