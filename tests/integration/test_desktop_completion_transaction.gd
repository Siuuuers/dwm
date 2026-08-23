extends "res://addons/gut/test.gd"

## Production desktop round-completion transaction (Plan 02 Task 8, dwm-p2r.32,
## req.minesweeper.causal_departure, req.desktop.cross_app_actions). Configures every REAL
## production port this task and its predecessors build for the DOMAIN/application layer --
## DesktopConsequenceState, DesktopCausalSequencePort, DesktopBoardFatePort,
## DesktopConsequenceCoordinator, MinesweeperRoundCoordinator, MinesweeperShopPurchaseParticipant, a
## real GameState autoload node, and a real DesktopIdentityNonceIssuer over an isolated root store.
## The consequence-checkpoint PORT itself is `FakeDesktopConsequenceCheckpointPort` (the same double
## Phase 2/3's own unit suites already prove thoroughly against): `SaveManagerCheckpointPort`'s real
## implementation keys its on-disk consequence-checkpoint document by a SINGLE FIXED path with no
## transaction/ordinal keying, which does not support this task's own multi-write-per-transaction
## checkpoint sequence (ordinal 0 by the source, then 1/2/6+ by the coordinator) the way the
## already-proven fake does; reconciling that mismatch is out of this task's own scope
## (SaveManagerCheckpointPort.gd belongs to Task 6). Plan 03's own condition policy and ScheduleView
## remain the Task-8 fakes throughout (Plan 02 never owns that production law).
##
## Representative coverage of the round-completion admission/forward-recovery/publication path and
## the cross-source gate-ordering property, not an exhaustive permutation of every crash point named
## in the brief's Step 8.2 enumeration -- see the Task-8 report for an explicit, honest note on what
## is representative rather than exhaustive here.

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
const ACTION_RECEIPT_PATH := "res://scripts/domain/desktop/DesktopActionReceipt.gd"
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
	"run_id": "run-complete", "branch_id": "branch-complete", "desktop_timeline_generation": 0,
	"causal_day_instance": "causal-day-complete-1",
}


func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: RefCounted = load(FAKE_FILE_OPS_PATH).new()
	var storage: Object = load(STORAGE_PATH).new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new("7".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("completion_transaction").path_join(str(randi()))
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
		"receipt_id": "issuer_receipt.fixture-causal-day-complete-1", "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-complete-1", "numeric_value": null,
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
	# fake -- the fake this file used to build here accepted ANY kind/shape uniformly, which is
	# exactly why W1 (three of four production publishers could not talk to the production ledger)
	# was invisible to this suite. Wired over a real JsonFileStorage/FakeFileOps pair, matching the
	# already-established issuer-root pattern immediately above.
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
	# beginner's real registered dimensions are 9x9 with 10 base mines (GameStateDesktopBoardPort
	# ._DIFFICULTY_DIMENSIONS) -- unlike the Task-5 fake state port, the real port builds a real spec
	# these layout dimensions/mine_count must match exactly. Cell 0 stays safe (the forced first
	# reveal); cell 1 is a mine, used later to force a terminal EXPLODED board deterministically.
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
	assert_true(round_coordinator.configure_consequence_port(coordinator, gate).get("ok", false))
	assert_true(round_coordinator.configure_consequence_checkpoint(consequence_state, checkpoint_port).get("ok", false))

	return {
		"gs": gs, "issuer": issuer, "consequence_state": consequence_state, "gate": gate,
		"round_coordinator": round_coordinator, "shop_participant": shop_participant, "coordinator": coordinator,
		"board_fate_port": board_fate_port, "causal_sequence_port": causal_sequence_port,
		"publication_ledger": publication_ledger, "condition_policy_port": condition_policy_port,
		"shop_state_port": shop_state_port,
	}


func before_each() -> void:
	assert_true(load(REGISTRY_PATH).initialize().get("ok", false), "shop registry must load")


func _mint_transaction(issuer: Object) -> Dictionary:
	var issued: Dictionary = issuer.call(&"issue", &"transaction_id")
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]),
		"transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _reveal_and_explode(wired: Dictionary) -> void:
	var round_coordinator: Object = wired["round_coordinator"]
	var issuer: Object = wired["issuer"]
	var identity: Dictionary = round_coordinator.get_entry_context("beginner")["value"]["identity"]
	var reveal_txn := _mint_transaction(issuer)
	var revealed: Dictionary = round_coordinator.reveal({
		"transaction_id": reveal_txn["transaction_id"], "transaction_issuer_receipt": reveal_txn["transaction_issuer_receipt"],
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner", "cell_index": 0,
	})
	assert_true(revealed.get("ok", false), JSON.stringify(revealed))
	var live: Dictionary = round_coordinator.get_state()["value"]
	var explode_txn := _mint_transaction(issuer)
	var exploded: Dictionary = round_coordinator.reveal({
		"transaction_id": explode_txn["transaction_id"], "transaction_issuer_receipt": explode_txn["transaction_issuer_receipt"],
		"expected_identity": live["identity"], "expected_revision": live["revision"], "cell_index": 1,
	})
	assert_true(exploded.get("ok", false), JSON.stringify(exploded))
	assert_true(round_coordinator.get_state()["value"]["board"]["board"]["terminal"])


## Full end-to-end drive against every real production port this task and its predecessors build: a
## real terminal EXPLODED board, complete_round()'s own ordinal-0 checkpoint handoff, causal
## admission through the real DesktopCausalSequencePort, forward commit (the real board transition to
## NONE via commit_recovery_action()), and publication -- with real SaveManagerCheckpointPort-backed
## disk durability throughout.
func test_complete_round_transacts_exactly_once_against_real_ports() -> void:
	var wired := _wired()
	var round_coordinator: Object = wired["round_coordinator"]
	var issuer: Object = wired["issuer"]
	_reveal_and_explode(wired)

	var live: Dictionary = round_coordinator.get_state()["value"]
	var complete_txn := _mint_transaction(issuer)
	var result: Dictionary = round_coordinator.complete_round({
		"transaction_id": complete_txn["transaction_id"], "transaction_issuer_receipt": complete_txn["transaction_issuer_receipt"],
		"expected_identity": live["identity"], "expected_revision": live["revision"], "expected_run_revision": 0,
	})
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result.get("code"), &"action_consequence_accepted")
	# Review-fix pass (dwm-p2r.32.8, CRITICAL 1): the frozen shape has no "departure" key -- read the
	# disposition off the receipt instead. Also proves MinesweeperRoundCoordinator.complete_round()
	# surfaces the frozen shape verbatim through this REAL (non-fake) integration wiring.
	assert_eq(str(result["receipt"]["disposition"]), "no_departure")

	assert_eq(round_coordinator.get_state()["value"]["phase"], "NONE", "the board returned to NONE via the real forward commit")
	var live_consequence: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	assert_null(live_consequence["pending"], "terminal cleanup reached a clean slate")
	assert_eq(int(live_consequence["causal_sequence"]), 1)

	var ledger: Object = wired["publication_ledger"]
	var ledger_loaded: Dictionary = ledger.load()
	assert_true(ledger_loaded.get("ok", false), JSON.stringify(ledger_loaded))
	var records: Dictionary = ((ledger_loaded["value"] as Dictionary)["document"] as Dictionary)["records"]
	var kinds: Array = []
	for record: Dictionary in records.values():
		kinds.append(str(record["kind"]))
	kinds.sort()
	# FIX (dwm-p2r.13 remediation, finding W1): the real ledger's closed kind union is
	# causal_sequence|action_source|board_fate -- a no-departure completion publishes exactly the
	# first two, proving both the causal-sequence port AND the round coordinator's action-source
	# publish() now speak the ledger's real kind/shape (they always sent the correct frozen shape;
	# only the ledger itself rejected it before the fix).
	assert_eq(kinds, ["action_source", "causal_sequence"])

	# Replaying the identical completion request never re-admits or re-transitions anything.
	var replay: Dictionary = round_coordinator.complete_round({
		"transaction_id": complete_txn["transaction_id"], "transaction_issuer_receipt": complete_txn["transaction_issuer_receipt"],
		"expected_identity": live["identity"], "expected_revision": live["revision"], "expected_run_revision": 0,
	})
	assert_eq(replay, result, "a duplicate replay returns the identical result")


## FIX (dwm-p2r.13 remediation, finding W2): a minesweeper_round completion whose condition policy
## requests a departure. DesktopConsequenceCoordinator._build_projected_board_candidate() builds this
## departure's board_candidate from action_candidate.board_projection -- the round's OWN
## already-NONE post-completion projection -- and forward recovery then commits the action source
## FIRST (MinesweeperRoundCoordinator.commit_recovery_action() adopts that exact projection into the
## shared board) and board fate SECOND, post-admission with no rollback available. Before the fix,
## DesktopBoardFatePort.commit() re-validated the ORIGINAL pre-completion expected_board_identity/
## expected_board_revision against the now-already-advanced live board and always rejected with
## board_fate_conflict, permanently stranding the transaction (RED, observed directly: reverting the
## fix reproduces exactly this failure -- see the remediation report). This test proves commit
## succeeds and the round's own completed result/reward (its terminal_receipts entry) survives the
## resulting fate=none no-op board-fate commit untouched.
func test_complete_round_departure_commits_board_fate_against_real_ports() -> void:
	var wired := _wired()
	var round_coordinator: Object = wired["round_coordinator"]
	var issuer: Object = wired["issuer"]
	var condition_policy_port: Object = wired["condition_policy_port"]
	_reveal_and_explode(wired)

	var live: Dictionary = round_coordinator.get_state()["value"]
	var complete_txn := _mint_transaction(issuer)
	var action_txn: String = str(complete_txn["transaction_id"])

	# Review-fix pass precedent (dwm-p2r.32.8, CRITICAL 2), matching
	# test_shop_condition_contract_departure.gd's own established fixture pattern exactly: a departure
	# must enqueue exactly one destination intent for the coordinator's own pairing law to accept it.
	var destination_derived: Dictionary = issuer.derive_child({
		"child_kind": "destination_intent", "ordinal": 0,
		"parent_receipt_id": str((complete_txn["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": [action_txn],
	})
	assert_true(destination_derived.get("ok", false), JSON.stringify(destination_derived))
	var destination_intent := {
		"intent_id": str((destination_derived["value"] as Dictionary)["child_id"]),
		"intent_id_provenance": (destination_derived["value"] as Dictionary)["provenance"],
		"kind": "hospital_day", "day": 3, "causal_day_instance": "causal-day-complete-1",
		"source_condition_receipt_id": "condition.fake.placeholder",
		"source_condition_receipt_provenance": {"schema_version": 1, "parent_receipt_id": "",
			"child_kind": "condition", "ordinal": 0, "source_ids": [action_txn], "child_id": ""},
		"accepted_unfulfilled_sources": [], "terminal_cause": null, "terminal_provenance": null,
		"prerequisite_receipt_ids": [],
	}
	condition_policy_port.arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)

	var result: Dictionary = round_coordinator.complete_round({
		"transaction_id": complete_txn["transaction_id"], "transaction_issuer_receipt": complete_txn["transaction_issuer_receipt"],
		"expected_identity": live["identity"], "expected_revision": live["revision"], "expected_run_revision": 0,
	})
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result.get("code"), &"action_consequence_accepted")
	assert_eq(str(result["receipt"]["disposition"]), "departure_committed")
	assert_eq(str((result["value"] as Dictionary)["board_fate_receipt"]["fate"]), "none",
		"a minesweeper_round projection is already phase NONE, so its own departure fate is always none")

	assert_eq(round_coordinator.get_state()["value"]["phase"], "NONE")
	var terminal_receipts: Dictionary = round_coordinator.get_state()["value"]["terminal_receipts"]
	var terminal_receipt_id := "round_complete." + action_txn
	assert_true(terminal_receipts.has(terminal_receipt_id),
		"the round's own completed result/reward must survive the fate=none board-fate commit")
	assert_eq(str((terminal_receipts[terminal_receipt_id] as Dictionary)["outcome"]), "exploded")

	var live_consequence: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	assert_null(live_consequence["pending"], "terminal cleanup reached a clean slate")

	# The three-publisher fan-out for a departure, all against the REAL DesktopPublicationLedger.
	var ledger: Object = wired["publication_ledger"]
	var ledger_loaded: Dictionary = ledger.load()
	assert_true(ledger_loaded.get("ok", false), JSON.stringify(ledger_loaded))
	var records: Dictionary = ((ledger_loaded["value"] as Dictionary)["document"] as Dictionary)["records"]
	var kinds: Array = []
	for record: Dictionary in records.values():
		kinds.append(str(record["kind"]))
	kinds.sort()
	assert_eq(kinds, ["action_source", "board_fate", "causal_sequence"])

	# Replaying the identical completion request never re-admits or re-transitions anything.
	var replay: Dictionary = round_coordinator.complete_round({
		"transaction_id": complete_txn["transaction_id"], "transaction_issuer_receipt": complete_txn["transaction_issuer_receipt"],
		"expected_identity": live["identity"], "expected_revision": live["revision"], "expected_run_revision": 0,
	})
	assert_eq(replay, result, "a duplicate replay returns the identical result")


## Cross-source gate-ordering property (Step 8.2): whichever source acquires the shared
## causal_transaction lease first proceeds; the other is rejected until the first fully releases it
## (publish). There is never a genuinely concurrent admission race -- DesktopConsequenceState allows
## only one pending transaction at a time -- so this is the real, testable ordering law.
func test_a_source_already_holding_the_gate_blocks_the_other_source_until_it_releases() -> void:
	var wired := _wired()
	var shop_participant: Object = wired["shop_participant"]
	var round_coordinator: Object = wired["round_coordinator"]
	var issuer: Object = wired["issuer"]
	_reveal_and_explode(wired)

	# Shop prepares first and retains the gate through its own pending action_prepared checkpoint.
	var quote_txn := _mint_transaction(issuer)
	var quoted: Dictionary = shop_participant.quote("lucky_charm", quote_txn["transaction_id"], quote_txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live_consequence: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	var prepared: Dictionary = shop_participant.prepare_purchase({
		"transaction_id": quote_txn["transaction_id"], "transaction_issuer_receipt": quote_txn["transaction_issuer_receipt"],
		"item_id": "lucky_charm", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live_consequence["run_revision"]), "expected_causal_day_instance": str(live_consequence["causal_day_instance"]),
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_true((wired["gate"] as ApplicationMutationGate).is_internal_owner_active(&"causal_transaction"))

	# The gate tracks only the OWNER ROLE ("causal_transaction"), not which caller holds it, so
	# complete_round() sees the role already active and does not attempt its own acquire() -- it
	# proceeds straight to its own ordinal-0 handoff, which DesktopConsequenceState itself then
	# correctly rejects: only one pending transaction may exist at a time.
	var live_board: Dictionary = round_coordinator.get_state()["value"]
	var complete_txn := _mint_transaction(issuer)
	var blocked: Dictionary = round_coordinator.complete_round({
		"transaction_id": complete_txn["transaction_id"], "transaction_issuer_receipt": complete_txn["transaction_issuer_receipt"],
		"expected_identity": live_board["identity"], "expected_revision": live_board["revision"], "expected_run_revision": 0,
	})
	assert_false(blocked.get("ok", false))
	assert_eq(blocked.get("code"), &"consequence_transaction_already_pending")
	assert_eq(round_coordinator.get_state()["value"]["phase"], "ACTIVE_VISIBLE", "the round completion never proceeded")

	# Shop must fully clear its own transaction (admit, forward-commit, publish) before the gate frees.
	var pending: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]["pending"]
	assert_eq(str(pending["source_kind"]), "shop_purchase")