extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
const GUARD := preload("res://scripts/application/schedule/ScheduleDownstreamContractGuard.gd")
const GS := preload("res://autoload/GameState.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const CAUSAL_SEQUENCE_PORT := preload("res://scripts/application/desktop/DesktopCausalSequencePort.gd")
const CONSEQUENCE_COORDINATOR := preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd")
const BOARD_FATE_PORT := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const BOARD_STATE_PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const ROUND_COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const SHOP_STATE_PORT := preload("res://scripts/application/shop/GameStateMinesweeperShopPort.gd")
const SHOP_PARTICIPANT := preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd")
const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const FAKE_NAMESPACE_SOURCE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const FAKE_FILE_OPS := preload("res://tests/support/FakeFileOps.gd")
const FAKE_CONSEQUENCE_CHECKPOINT := preload("res://tests/support/FakeDesktopConsequenceCheckpointPort.gd")
const FAKE_MINESWEEPER_CHECKPOINT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const FAKE_MINESWEEPER_GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const FAKE_CONDITION_POLICY := preload("res://tests/support/FakeDesktopConditionPolicyPort.gd")
const FAKE_SCHEDULE_VIEW := preload("res://tests/support/FakeScheduleDepartureViewPort.gd")
const DAY := 3
const RUN_ID := "run-p2r13-contracts"
const BRANCH_ID := "branch-p2r13-contracts"
const CAUSAL_DAY := "causal-day-p2r13-contracts-1"

# ---- consumed-interface-lock key sets (sorted; the lock's prose order differs, the SET is law) ----
const SUCCESS_ENVELOPE_KEYS: Array = ["code", "ok", "receipt", "value"]
const FAILURE_ENVELOPE_KEYS: Array = ["code", "details", "message", "ok"]
const ADMISSION_CANDIDATE_KEYS: Array = [
	"admission_checkpoint_candidate", "recovery_payload_sha256", "sequence_candidate",
	"transaction_id",
]
const CAUSAL_COMMIT_KEYS: Array = ["admission_checkpoint_receipt", "causal_sequence_receipt"]
const BOARD_FATE_VALUE_KEYS: Array = ["board_candidate", "board_fate_receipt"]
const BOARD_FATE_RECEIPT_KEYS: Array = [
	"board_identity", "board_revision", "causal_day_instance", "command_id",
	"command_issuer_receipt", "fate", "receipt_id", "receipt_provenance",
	"source_action_commit_receipt_id", "source_action_commit_receipt_provenance",
]
const CONSEQUENCE_VALUE_KEYS: Array = [
	"board_fate_receipt", "causal_sequence", "condition_receipt", "destination_intent",
	"notification_intent", "schedule_view_commit_receipt",
]
const CONSEQUENCE_RECEIPT_KEYS: Array = [
	"action_commit_receipt_id", "action_commit_receipt_provenance", "causal_sequence",
	"disposition", "receipt_id", "receipt_provenance",
]


func before_each() -> void:
	assert_true(SHOP_REGISTRY.initialize().get("ok", false), "shop registry must load")


# -------------------------------------------------------------------------------------------------
# Wiring -- the production graph, seam for seam from the three established integration suites.
# -------------------------------------------------------------------------------------------------

func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: RefCounted = FAKE_FILE_OPS.new()
	var storage: Object = STORAGE.new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = FAKE_NAMESPACE_SOURCE.new("9".repeat(64))
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


func _wired(day: int = DAY) -> Dictionary:
	var created: Dictionary = TEMPORARY_STORAGE.create("p2r13-downstream-contracts")
	assert_true(created.get("ok", false), created.get("message", ""))
	if not created.get("ok", false):
		return {}
	var root := str(created["value"])

	var gs: Node = GS.new()
	add_child_autofree(gs)
	gs.reset_game()
	gs.money = 100
	gs.coins = 10
	gs._lifecycle_set_playing_day(day)

	var issuer := _fresh_issuer(root)
	var checkpoint_port: Object = FAKE_CONSEQUENCE_CHECKPOINT.new()
	var consequence_state: RefCounted = CONSEQUENCE_STATE.new()
	var day_receipt := {
		"receipt_id": "issuer_receipt.fixture-" + CAUSAL_DAY, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": CAUSAL_DAY, "numeric_value": null,
	}
	var made: Dictionary = CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": CAUSAL_DAY, "causal_day_instance_issuer_receipt": day_receipt,
	})
	assert_true(made.get("ok", false), JSON.stringify(made))
	var prepared_state: Dictionary = consequence_state.prepare_restore(
		(made["value"] as Dictionary)["state"])
	consequence_state.commit((prepared_state["value"] as Dictionary)["candidate"])

	var identity_context := {
		"run_id": RUN_ID, "branch_id": BRANCH_ID, "desktop_timeline_generation": 0,
		"causal_day_instance": CAUSAL_DAY,
	}

	var gate := ApplicationMutationGate.new()
	var desktop_ledger: Object = DESKTOP_PUBLICATION_LEDGER.new()
	assert_true(desktop_ledger.configure(STORAGE.new(root.path_join("_publications"))).get("ok", false))
	assert_true(desktop_ledger.load().get("ok", false))

	var board_state_port: Object = BOARD_STATE_PORT.new()
	assert_true(board_state_port.configure(gs, issuer, identity_context).get("ok", false))
	var round_coordinator: Object = ROUND_COORDINATOR.new()
	assert_true(round_coordinator.configure(board_state_port, FAKE_MINESWEEPER_CHECKPOINT.new(),
		FAKE_MINESWEEPER_GENERATION.new(), issuer).get("ok", false))
	assert_true(round_coordinator.configure_publication_ledger(desktop_ledger).get("ok", false))

	var shop_state_port: Object = SHOP_STATE_PORT.new()
	assert_true(shop_state_port.configure(gs, identity_context).get("ok", false))
	var shop_participant: Object = SHOP_PARTICIPANT.new()
	assert_true(shop_participant.configure_publication_ledger(desktop_ledger).get("ok", false))
	assert_true(shop_participant.configure(shop_state_port, consequence_state, checkpoint_port,
		SHOP_REGISTRY, issuer, gate).get("ok", false))

	var board_fate_port: Object = BOARD_FATE_PORT.new()
	assert_true(board_fate_port.configure_publication_ledger(desktop_ledger).get("ok", false))
	assert_true(board_fate_port.configure(round_coordinator._board_state, issuer).get("ok", false))

	var causal_sequence_port: Object = CAUSAL_SEQUENCE_PORT.new()
	assert_true(causal_sequence_port.configure_publication_ledger(desktop_ledger).get("ok", false))
	assert_true(causal_sequence_port.configure(consequence_state, gate, checkpoint_port).get("ok", false))

	var coordinator: Object = CONSEQUENCE_COORDINATOR.new()
	assert_true(coordinator.configure(consequence_state, causal_sequence_port, board_fate_port,
		checkpoint_port, gate).get("ok", false))
	assert_true(coordinator.configure_action_source_ports(round_coordinator, shop_participant).get("ok", false))
	var condition_policy_port: Object = FAKE_CONDITION_POLICY.new()
	assert_true(condition_policy_port.configure(RefCounted.new()).get("ok", false))
	var schedule_view_port: Object = FAKE_SCHEDULE_VIEW.new()
	assert_true(coordinator.configure_condition_departure_ports(condition_policy_port,
		schedule_view_port).get("ok", false))
	assert_true(coordinator.configure_identity_issuer(issuer).get("ok", false))
	assert_true(round_coordinator.configure_consequence_port(coordinator, gate).get("ok", false))
	assert_true(round_coordinator.configure_consequence_checkpoint(consequence_state,
		checkpoint_port).get("ok", false))

	return {
		"gs": gs, "issuer": issuer,
		"gate": gate,
		"consequence_state": consequence_state, "checkpoint_port": checkpoint_port,
		"board_state": round_coordinator._board_state, "round_coordinator": round_coordinator,
		"shop_participant": shop_participant, "coordinator": coordinator,
		"board_fate_port": board_fate_port, "causal_sequence_port": causal_sequence_port,
		"schedule_view_port": schedule_view_port,
		"condition_policy_port": condition_policy_port,
	}


# -------------------------------------------------------------------------------------------------
# Fixture helpers -- every identity below is issuer-minted; nothing invents one.
# -------------------------------------------------------------------------------------------------

func _mint_transaction(issuer: Object) -> Dictionary:
	var issued: Dictionary = issuer.call(&"issue", &"transaction_id")
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]),
		"transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _schedule_fate_request(wired: Dictionary, command: Dictionary) -> Dictionary:
	var live: Dictionary = (wired["board_state"] as Object).capture()
	return {
		"command_id": command["transaction_id"],
		"command_issuer_receipt": command["transaction_issuer_receipt"],
		"run_id": RUN_ID, "branch_id": BRANCH_ID,
		"causal_day_instance": CAUSAL_DAY, "reason": "schedule_done",
		"expected_board_identity": live["identity"],
		"expected_board_revision": int(live["revision"]),
	}


func _projected_fate_request(wired: Dictionary, action_receipt: Dictionary) -> Dictionary:
	var live: Dictionary = (wired["board_state"] as Object).capture()
	var projected: Dictionary = live.duplicate(true)
	return {
		"command_id": str(action_receipt["transaction_id"]),
		"command_issuer_receipt": (action_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"run_id": str(action_receipt["run_id"]), "branch_id": str(action_receipt["branch_id"]),
		"causal_day_instance": str(action_receipt["causal_day_instance"]),
		"reason": "condition_departure",
		"expected_board_identity": live["identity"],
		"expected_board_revision": int(live["revision"]),
		"source_action_receipt": action_receipt.duplicate(true),
		"projected_board_candidate": projected,
		"projected_board_candidate_sha256": _sha256(projected),
	}


## Quotes and prepares a real Shop purchase through the production participant; on return the
## pending record is durably action_prepared and the participant holds the one shared
## causal_transaction lease, exactly as in test_shop_condition_contract_departure.gd.
func _shop_prepared(wired: Dictionary, item_id: String) -> Dictionary:
	var shop_participant: Object = wired["shop_participant"]
	var issuer: Object = wired["issuer"]
	var txn := _mint_transaction(issuer)
	var quoted: Dictionary = shop_participant.quote(item_id, txn["transaction_id"],
		txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	var prepared: Dictionary = shop_participant.prepare_purchase({
		"transaction_id": txn["transaction_id"],
		"transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": item_id, "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]),
		"expected_causal_day_instance": str(live["causal_day_instance"]),
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(prepared.get("code"), &"shop_purchase_action_checkpointed")
	return {"action_receipt": (prepared["value"] as Dictionary)["action_receipt"]}


## The production admission flow for the real shop pending record, mirroring
## test_desktop_causal_sequence_port.gd's proven _admit() drive: reservation over the live pending,
## an admission checkpoint candidate from the shared (observing) checkpoint double at the first
## coordinator ordinal, then prepare_admission over the pending's own recovery payload hash.
func _shop_admission(wired: Dictionary) -> Dictionary:
	var prepared := _shop_prepared(wired, "lucky_charm")
	var action_receipt: Dictionary = prepared["action_receipt"]
	var transaction_id := str(action_receipt["transaction_id"])
	var request := {
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": (action_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"run_id": str(action_receipt["run_id"]), "branch_id": str(action_receipt["branch_id"]),
		"desktop_timeline_generation": int(action_receipt["desktop_timeline_generation"]),
		"causal_day_instance": str(action_receipt["causal_day_instance"]),
		"source_kind": "shop_purchase",
		"source_commit_receipt_id": str(action_receipt["commit_receipt_id"]),
		"source_commit_receipt_provenance": (action_receipt["commit_receipt_provenance"] as Dictionary).duplicate(true),
		"expected_last_sequence": 0, "expected_run_revision": 0,
	}
	var port: Object = wired["causal_sequence_port"]
	var reserved: Dictionary = port.prepare_reservation(request)
	assert_true(reserved.get("ok", false), JSON.stringify(reserved))
	var sequence_candidate: Dictionary = (reserved["value"] as Dictionary)["sequence_candidate"]

	var state: Object = wired["consequence_state"]
	var candidate_state: Dictionary = (state.capture()["value"] as Dictionary)["state"]
	var live_pending: Dictionary = candidate_state["pending"]
	var header := {"kind": &"consequence_admission", "operation_ordinal": 1,
		"run_id": str(action_receipt["run_id"]), "source_ids": [],
		"stage": String(live_pending["stage"]), "transaction_id": transaction_id}
	var checkpoint_prepared: Dictionary = (wired["checkpoint_port"] as Object) \
		.prepare_consequence_checkpoint(header, candidate_state)
	assert_true(checkpoint_prepared.get("ok", false), JSON.stringify(checkpoint_prepared))

	var admitted: Dictionary = port.prepare_admission(sequence_candidate,
		checkpoint_prepared["value"], str(live_pending["recovery_payload_sha256"]))
	return {"reserved": reserved, "admitted": admitted, "action_receipt": action_receipt,
		"request": request}


# -------------------------------------------------------------------------------------------------
# Assertion helpers
# -------------------------------------------------------------------------------------------------

func _keys_of(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func _sha256(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	assert_true(emitted.get("ok", false), JSON.stringify(emitted))
	return str(emitted["value"]).sha256_text()


func _require_ok(result: Dictionary, context: String) -> bool:
	assert_true(result.get("ok", false),
		"%s must succeed before the law under test is reachable: %s" % [context, JSON.stringify(result)])
	return bool(result.get("ok", false))


## The RED anchor: at RED the guard skeleton answers every call with &"not_implemented", so this
## message names not_implemented behavior; at GREEN it names the exact schema difference instead.
func _assert_guard_accepts(verdict: Dictionary, context: String) -> void:
	assert_true(verdict.get("ok", false), "guard refused %s (code=%s): %s" % [
		context, str(verdict.get("code", &"")), JSON.stringify(verdict)])


func _assert_success_shape(result: Dictionary, context: String) -> void:
	assert_true(result.get("ok", false), "%s must succeed: %s" % [context, JSON.stringify(result)])
	assert_eq(_keys_of(result), SUCCESS_ENVELOPE_KEYS,
		"%s success envelope is exactly {ok, code, value, receipt}" % context)


func _assert_rejects(result: Dictionary, code: StringName, context: String) -> void:
	assert_false(result.get("ok", true), "%s must be refused: %s" % [context, JSON.stringify(result)])
	assert_ne(result.get("code", &"not_implemented"), &"not_implemented",
		"%s must be refused by real validation, never satisfied by an unimplemented stub" % context)
	assert_eq(result.get("code"), code, "%s exact refusal code: %s" % [context, JSON.stringify(result)])
	assert_eq(_keys_of(result), FAILURE_ENVELOPE_KEYS,
		"%s failure envelope is exactly {ok, code, message, details}" % context)


func _assert_guarded_refusal(verdict: Dictionary, result: Dictionary, code: StringName,
		context: String) -> void:
	_assert_guard_accepts(verdict, context + " (refusal envelope)")
	_assert_rejects(result, code, context)


## Byte-level fingerprint of every downstream owner a refused request must leave untouched.
func _graph_snapshot(wired: Dictionary) -> Dictionary:
	var gs: Node = wired["gs"]
	return {
		"board": ((wired["board_state"] as Object).capture() as Dictionary).duplicate(true),
		"consequence": (((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"] as Dictionary),
		"contacts": (gs.contacts as Dictionary).duplicate(true),
		"economy": {"money": gs.money, "coins": gs.coins,
			"inventory": (gs.inventory as Dictionary).duplicate(true)},
	}


func test_a05_causal_admission_binds_reservation_checkpoint_and_payload_hash() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var admission := _shop_admission(wired)
	var admitted: Dictionary = admission["admitted"]
	_assert_guard_accepts(GUARD.validate_causal_admission_result(admitted),
		"validate_causal_admission_result over a real admission binding")

	_assert_success_shape(admitted, "prepare_admission")
	assert_eq(_keys_of(admitted["value"]), ["candidate"], "success value is exactly {candidate}")
	var candidate: Dictionary = (admitted["value"] as Dictionary)["candidate"]
	assert_eq(_keys_of(candidate), ADMISSION_CANDIDATE_KEYS,
		"the combined candidate binds exactly the sequence candidate, checkpoint candidate, and payload hash")
	assert_eq(admitted["receipt"], {}, "prepare_admission allocates nothing and issues no receipt")
	assert_eq(candidate["sequence_candidate"],
		((admission["reserved"] as Dictionary)["value"] as Dictionary)["sequence_candidate"],
		"the bound sequence candidate is exactly the live reservation")


func test_a06_causal_commit_returns_the_combined_admission_receipt() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var admission := _shop_admission(wired)
	var admitted: Dictionary = admission["admitted"]
	if not _require_ok(admitted, "prepare_admission before the admission commit"):
		return
	assert_true((wired["gate"] as ApplicationMutationGate).is_internal_owner_active(&"causal_transaction"),
		"the source participant already holds the one shared causal_transaction lease")
	var committed: Dictionary = (wired["causal_sequence_port"] as Object).commit(
		(admitted["value"] as Dictionary)["candidate"])
	_assert_guard_accepts(GUARD.validate_causal_commit_result(committed),
		"validate_causal_commit_result over a real admission commit")

	_assert_success_shape(committed, "causal commit")
	assert_eq(_keys_of(committed["value"]), CAUSAL_COMMIT_KEYS,
		"commit success value is exactly {causal_sequence_receipt, admission_checkpoint_receipt}")
	assert_eq(_keys_of(committed["receipt"]), CAUSAL_COMMIT_KEYS,
		"the outer receipt is exactly the combined causal/admission-checkpoint receipt")
	assert_eq((committed["receipt"] as Dictionary)["causal_sequence_receipt"],
		(committed["value"] as Dictionary)["causal_sequence_receipt"],
		"receipt and value carry the same causal sequence receipt bytes")
	assert_eq((committed["value"] as Dictionary)["causal_sequence_receipt"],
		((admission["reserved"] as Dictionary)["value"] as Dictionary)["causal_sequence_receipt"],
		"commit forward-applies the same reserved sequence receipt, never a reissued one")
	var live: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	assert_eq(int(live["causal_sequence"]), 1, "the live sequence advanced exactly once")
	assert_eq(str((live["pending"] as Dictionary)["stage"]), "sequence_committed",
		"the admission checkpoint stage is promoted atomically with the live receipt")


func test_a07_board_fate_schedule_done_uses_the_live_board_with_null_source_action_members() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var command := _mint_transaction(wired["issuer"])
	var result: Dictionary = (wired["board_fate_port"] as Object).prepare_causal_departure(
		_schedule_fate_request(wired, command))
	_assert_guard_accepts(GUARD.validate_board_fate_result(result),
		"validate_board_fate_result over a real schedule_done departure")

	_assert_success_shape(result, "prepare_causal_departure")
	assert_eq(_keys_of(result["value"]), BOARD_FATE_VALUE_KEYS,
		"success value carries exactly board_candidate and board_fate_receipt")
	var receipt: Dictionary = (result["value"] as Dictionary)["board_fate_receipt"]
	assert_eq(result["receipt"], receipt,
		"the outer receipt is an exact detached copy of board_fate_receipt")
	assert_eq(_keys_of(receipt), BOARD_FATE_RECEIPT_KEYS, "the fate receipt member set is exact")
	assert_null(receipt["source_action_commit_receipt_id"],
		"Schedule Done carries a null source-action commit receipt id")
	assert_null(receipt["source_action_commit_receipt_provenance"],
		"Schedule Done carries a null source-action commit receipt provenance")
	assert_eq(str(receipt["fate"]), "none", "an already-NONE live board departs with fate none")
	assert_null(receipt["board_identity"], "a fate-none departure names no board identity")
	assert_eq(int(receipt["board_revision"]), -1, "board_revision is -1 exactly when identity is null")
	assert_true(((wired["issuer"] as Object).validate_child(receipt["receipt_provenance"], &"board_fate") as Dictionary).get("ok", false),
		"the receipt validates as the issuer-anchored board_fate child")


func test_a08_board_fate_condition_departure_binds_the_exact_source_action() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var prepared := _shop_prepared(wired, "lucky_charm")
	var action_receipt: Dictionary = prepared["action_receipt"]
	var result: Dictionary = (wired["board_fate_port"] as Object).prepare_projected_causal_departure(
		_projected_fate_request(wired, action_receipt))
	_assert_guard_accepts(GUARD.validate_board_fate_result(result),
		"validate_board_fate_result over a real projected condition departure")

	_assert_success_shape(result, "prepare_projected_causal_departure")
	var receipt: Dictionary = (result["value"] as Dictionary)["board_fate_receipt"]
	assert_eq(_keys_of(receipt), BOARD_FATE_RECEIPT_KEYS, "the fate receipt member set is exact")
	assert_eq(str(receipt["source_action_commit_receipt_id"]), str(action_receipt["commit_receipt_id"]),
		"a projected departure returns the exact nonnull commit id of its source action")
	assert_eq(receipt["source_action_commit_receipt_provenance"], action_receipt["commit_receipt_provenance"],
		"...and the byte-equal source-action commit provenance")
	assert_eq(str(receipt["command_id"]), str(action_receipt["transaction_id"]),
		"the departure command is the source action's own transaction root")


func test_a09_consequence_accept_returns_the_frozen_value_and_receipt() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	wired["gs"].set_stat(GS.STAT_HEALTH, 4)
	var prepared := _shop_prepared(wired, "lucky_charm")
	var action_receipt: Dictionary = prepared["action_receipt"]
	assert_eq(action_receipt["condition_before"]["health"], 4)
	assert_eq(action_receipt["condition_after"]["health"], 4)
	var action_txn := str(action_receipt["transaction_id"])
	# Recover the ordinal-0 checkpoint receipt and the real economy candidate exactly as
	# test_shop_condition_contract_departure.gd does: participant and coordinator share the same
	# configured checkpoint port instance, and the production participant built the candidate.
	var shop_participant: Object = wired["shop_participant"]
	var raw_checkpoint_port: Object = shop_participant._checkpoint_port
	var prepared_checkpoint: Dictionary = {}
	for record: Dictionary in (raw_checkpoint_port as Object).commit_log:
		if str((record["receipt"] as Dictionary)["checkpoint_id"]).find(action_txn) >= 0:
			prepared_checkpoint = record["receipt"]
	assert_false(prepared_checkpoint.is_empty(), "the source's own ordinal-0 checkpoint is recoverable")
	var economy_candidate: Dictionary = (shop_participant._transactions[action_txn] as Dictionary)["economy_candidate"]
	var live_board: Dictionary = (wired["board_state"] as Object).capture()
	var result: Dictionary = (wired["coordinator"] as Object).accept_prepared_action({
		"action_receipt": action_receipt, "action_candidate": economy_candidate,
		"prepared_checkpoint_receipt": prepared_checkpoint, "expected_run_revision": 0,
		"expected_board_identity": live_board["identity"],
		"expected_board_revision": int(live_board["revision"]),
	})
	_assert_guard_accepts(GUARD.validate_consequence_result(result),
		"validate_consequence_result over a real accepted shop action")

	_assert_success_shape(result, "accept_prepared_action")
	assert_eq(_keys_of(result["value"]), CONSEQUENCE_VALUE_KEYS,
		"success value carries exactly the six frozen consequence members")
	var receipt: Dictionary = result["receipt"]
	assert_eq(_keys_of(receipt), CONSEQUENCE_RECEIPT_KEYS, "the consequence receipt member set is exact")
	assert_eq(str(receipt["disposition"]), "no_departure",
		"an unarmed condition policy yields the no_departure disposition")
	assert_eq(str(receipt["action_commit_receipt_id"]), str(action_receipt["commit_receipt_id"]),
		"the receipt pins the exact source-action commit identity")
	assert_eq(receipt["action_commit_receipt_provenance"], action_receipt["commit_receipt_provenance"],
		"...and its byte-equal provenance")
	assert_eq(int((result["value"] as Dictionary)["causal_sequence"]), 1,
		"the admitted transaction holds causal sequence 1")
	assert_null((result["value"] as Dictionary)["board_fate_receipt"],
		"no_departure never touches board fate")
	assert_null((result["value"] as Dictionary)["schedule_view_commit_receipt"],
		"schedule_view_commit_receipt stays null for an action no_departure")
	assert_eq(int((wired["gs"] as Node).inventory.get("lucky_charm", 0)), 1,
		"the real GameState economy candidate committed -- no fake manufactured this success")
	assert_eq(wired["gs"].get_stat(GS.STAT_HEALTH), 4)


## Review-fix (Minor 3): the nonnull direction of the board-fate -1-iff-null identity law needs a
## real green driver -- a materialized, STARTED board (the completion suite's own arm/reveal
## pattern, test_desktop_completion_transaction.gd lines 110-183) whose schedule_done departure
## returns the live nonnull identity and nonnegative revision through the guard.
func test_a11_board_fate_forfeits_a_started_board_with_nonnull_identity() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var round_coordinator: Object = wired["round_coordinator"]
	var reveal_txn := _mint_transaction(wired["issuer"])
	var prepared: Dictionary = round_coordinator._state_port.prepare_spec("beginner",
		reveal_txn.transaction_id, reveal_txn.transaction_issuer_receipt)
	if not _require_ok(prepared, "canonical beginner spec"):
		return
	var spec: Dictionary = prepared.value.spec
	var mine_indices: Array[int] = []
	for index: int in range(1, int(spec.requested_mine_count) + 1):
		mine_indices.append(index)
	(round_coordinator._generation_port as Object).arm_materialize({"schema_version": 1,
		"width": spec.width, "height": spec.height, "mine_indices": mine_indices,
		"mine_count": mine_indices.size()})
	var identity: Dictionary = round_coordinator.get_entry_context("beginner")["value"]["identity"]
	var revealed: Dictionary = round_coordinator.reveal({
		"transaction_id": reveal_txn["transaction_id"],
		"transaction_issuer_receipt": reveal_txn["transaction_issuer_receipt"],
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner",
		"cell_index": 0,
	})
	if not _require_ok(revealed, "the real board start/reveal"):
		return
	var live: Dictionary = (wired["board_state"] as Object).capture()
	assert_true(live["identity"] != null, "a started board carries a nonnull identity")
	var result: Dictionary = (wired["board_fate_port"] as Object).prepare_causal_departure(
		_schedule_fate_request(wired, _mint_transaction(wired["issuer"])))
	_assert_guard_accepts(GUARD.validate_board_fate_result(result),
		"validate_board_fate_result over a real started-board forfeiture")
	_assert_success_shape(result, "prepare_causal_departure (started board)")
	var receipt: Dictionary = (result["value"] as Dictionary)["board_fate_receipt"]
	assert_eq(str(receipt["fate"]), "forfeited_started", "a started board departs by silent forfeit")
	assert_eq(receipt["board_identity"], live["identity"],
		"the fate receipt names the live board's own nonnull identity")
	assert_true(int(receipt["board_revision"]) >= 0,
		"a nonnull-identity departure carries the real nonnegative revision, never -1")
	assert_null(receipt["source_action_commit_receipt_id"],
		"Schedule Done keeps both source-action members null even for a forfeit")
	assert_null(receipt["source_action_commit_receipt_provenance"],
		"...both of them, exactly as the lock's null law says")


func test_b05_board_fate_accepts_only_its_own_request_shape_and_reason() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var prepared := _shop_prepared(wired, "lucky_charm")
	var action_receipt: Dictionary = prepared["action_receipt"]
	var port: Object = wired["board_fate_port"]
	var schedule_request := _schedule_fate_request(wired, _mint_transaction(wired["issuer"]))
	var projected_request := _projected_fate_request(wired, action_receipt)
	var before := _graph_snapshot(wired)

	var wrong_reason: Dictionary = schedule_request.duplicate(true)
	wrong_reason["reason"] = "condition_departure"
	var refused_reason: Dictionary = port.prepare_causal_departure(wrong_reason)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(refused_reason), refused_reason,
		&"board_fate_reason_invalid", "prepare_causal_departure with reason=condition_departure")

	var cross_shape: Dictionary = port.prepare_causal_departure(projected_request)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(cross_shape), cross_shape,
		&"board_fate_request_invalid", "prepare_causal_departure fed the projected request shape")

	var cross_shape_projected: Dictionary = port.prepare_projected_causal_departure(schedule_request)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(cross_shape_projected), cross_shape_projected,
		&"board_fate_request_invalid", "prepare_projected_causal_departure fed the current-board shape")

	var wrong_projected_reason: Dictionary = projected_request.duplicate(true)
	wrong_projected_reason["reason"] = "schedule_done"
	var refused_projected: Dictionary = port.prepare_projected_causal_departure(wrong_projected_reason)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(refused_projected), refused_projected,
		&"board_fate_reason_invalid", "prepare_projected_causal_departure with reason=schedule_done")

	assert_eq(_graph_snapshot(wired), before, "every cross-shape refusal mutates nothing")


func test_b06_board_fate_refuses_a_stale_board_revision_without_mutation() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var request := _schedule_fate_request(wired, _mint_transaction(wired["issuer"]))
	request["expected_board_revision"] = int(request["expected_board_revision"]) + 7
	var before := _graph_snapshot(wired)
	var refused: Dictionary = (wired["board_fate_port"] as Object).prepare_causal_departure(request)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(refused), refused,
		&"board_fate_stale_revision", "prepare_causal_departure with a stale expected_board_revision")
	assert_eq(_graph_snapshot(wired), before, "a stale-revision refusal mutates nothing")


func test_b07_board_fate_refuses_a_wrong_causal_day_without_mutation() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var prepared := _shop_prepared(wired, "lucky_charm")
	var request := _projected_fate_request(wired, prepared["action_receipt"])
	request["causal_day_instance"] = "causal-day-OTHER"
	var before := _graph_snapshot(wired)
	var refused: Dictionary = (wired["board_fate_port"] as Object).prepare_projected_causal_departure(request)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(refused), refused,
		&"board_fate_action_mismatch", "a causal day different from the bound source action's own")
	assert_eq(_graph_snapshot(wired), before, "a wrong-causal-day refusal mutates nothing")


func test_b08_board_fate_refuses_a_bad_projection_hash_and_a_foreign_action_identity() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var prepared := _shop_prepared(wired, "lucky_charm")
	var action_receipt: Dictionary = prepared["action_receipt"]
	var port: Object = wired["board_fate_port"]
	var before := _graph_snapshot(wired)

	var bad_hash := _projected_fate_request(wired, action_receipt)
	bad_hash["projected_board_candidate_sha256"] = _sha256({"not": "the projection"})
	var refused_hash: Dictionary = port.prepare_projected_causal_departure(bad_hash)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(refused_hash), refused_hash,
		&"board_fate_projection_hash_mismatch",
		"a projected hash that does not match the canonical candidate")

	var foreign := _projected_fate_request(wired, action_receipt)
	foreign["command_id"] = str(_mint_transaction(wired["issuer"])["transaction_id"])
	var refused_identity: Dictionary = port.prepare_projected_causal_departure(foreign)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(refused_identity), refused_identity,
		&"board_fate_action_mismatch", "a command identity foreign to the bound source action")

	assert_eq(_graph_snapshot(wired), before, "hash and identity refusals mutate nothing")
