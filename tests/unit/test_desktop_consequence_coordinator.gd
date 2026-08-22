extends "res://addons/gut/test.gd"
## RED/GREEN coverage for DesktopConsequenceCoordinator (Plan 02 Task 8, dwm-p2r.32). Representative
## coverage of the core admission/forward-recovery/publication contract for one real action source
## (MinesweeperShopPurchaseParticipant, fully built by Task 7) plus a minimal hand-built fake standing
## in for the minesweeper_round source (Phase 3's own MinesweeperRoundCoordinator recovery-method
## additions are proven separately in their own suite) -- not an exhaustive permutation of every crash
## point named in the brief's Step 8.2 enumeration. See the Task-8 report for an explicit, honest note
## on what is representative rather than exhaustive here.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const COORDINATOR_PATH := "res://scripts/application/desktop/DesktopConsequenceCoordinator.gd"
const COORDINATOR := preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const CAUSAL_SEQUENCE_PORT := preload("res://scripts/application/desktop/DesktopCausalSequencePort.gd")
const BOARD_FATE_PORT := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const ROUND_COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const SHOP_PARTICIPANT := preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd")
const SHOP_STATE_PORT := preload("res://tests/support/FakeDesktopBoardStatePort.gd")
const SHOP_FAKE_STATE_PORT := preload("res://tests/support/FakeMinesweeperShopStatePort.gd")
const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const CHECKPOINT_PORT := preload("res://tests/support/FakeDesktopConsequenceCheckpointPort.gd")
const CONDITION_POLICY_PORT := preload("res://tests/support/FakeDesktopConditionPolicyPort.gd")
const SCHEDULE_VIEW_PORT := preload("res://tests/support/FakeScheduleDepartureViewPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const CHECKPOINT_GENERATION_PORT := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")

## Review-fix pass (dwm-p2r.32.8, CRITICAL 1): the frozen accept_prepared_action() success shapes,
## mirrored here (not read from production) so an accidental production regression back toward the
## old fabricated shape is caught by an independent expectation, not a shared constant.
const _FROZEN_VALUE_KEYS: Array = [
	"causal_sequence", "condition_receipt", "board_fate_receipt", "schedule_view_commit_receipt",
	"destination_intent", "notification_intent",
]
const _FROZEN_RECEIPT_KEYS: Array = [
	"receipt_id", "receipt_provenance", "action_commit_receipt_id", "action_commit_receipt_provenance",
	"causal_sequence", "disposition",
]

## Minimal in-memory spy double for DesktopPublicationLedger's own record_before_emit() contract.
class FakePublicationLedger:
	var records: Dictionary = {}

	func record_before_emit(request: Dictionary) -> Dictionary:
		# The action_source semantic receipt is a DesktopActionReceipt, which has no receipt_id field
		# of its own -- commit_receipt_id (Ruling B) is its identity for this key, mirroring
		# test_minesweeper_shop_purchase_participant.gd's own established fake ledger precedent.
		var semantic_receipt: Dictionary = request["semantic_receipt"]
		var identity := str(semantic_receipt.get("commit_receipt_id", semantic_receipt.get("receipt_id", "")))
		var key := str(request["kind"]) + ":" + identity
		if records.has(key):
			if records[key] == request:
				return {"ok": true, "code": &"ok", "value": {"record": request, "first_delivery": false}, "receipt": {}}
			return {"ok": false, "code": &"publication_record_conflict", "message": key}
		records[key] = request.duplicate(true)
		return {"ok": true, "code": &"ok", "value": {"record": request, "first_delivery": true}, "receipt": {}}

## Hand-built stand-in for the minesweeper_round source, satisfying only the frozen three-method
## recovery surface -- Phase 3's own MinesweeperRoundCoordinator additions are proven in their own
## suite; this coordinator suite only needs a second, DISTINCT object claiming the other role.
class FakeRoundSource:
	var committed: Array = []
	var published: Array = []
	## Review-fix pass (dwm-p2r.32.8, CRITICAL 2): a one-shot injected publish failure, used to prove
	## destination_intent/notification_intent already landed in the durable pending record BEFORE the
	## publication loop (and this injected failure) ever ran, and that a subsequent forward-recovery
	## replay on a reconstructed coordinator publishes exactly once, not twice.
	var fail_publish_once := false

	func validate_recovery_action(action_candidate: Dictionary, action_receipt: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"publication": {
			"action_candidate_sha256": _sha(action_candidate), "action_receipt": action_receipt,
		}}, "receipt": {}}

	func commit_recovery_action(action_candidate: Dictionary, action_receipt: Dictionary) -> Dictionary:
		committed.append({"action_candidate": action_candidate, "action_receipt": action_receipt})
		return {"ok": true, "code": &"ok", "value": {"action_receipt": action_receipt}, "receipt": action_receipt}

	func publish_recovery_action(publication: Dictionary) -> Dictionary:
		if fail_publish_once:
			fail_publish_once = false
			return {"ok": false, "code": &"fake_injected_publish_failure", "message": "", "details": {}}
		published.append(publication)
		return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": publication["action_receipt"]}

	static func _sha(value: Variant) -> String:
		var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
		return str(emitted["value"]).sha256_text()


var _consequence_state: RefCounted
var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER
var _gate: ApplicationMutationGate
var _checkpoint_port: CHECKPOINT_PORT
var _publication_ledger: FakePublicationLedger
var _causal_sequence_port: RefCounted
var _board_state: RefCounted
var _board_fate_port: RefCounted
var _round_coordinator: ROUND_COORDINATOR
var _shop_participant: RefCounted
var _shop_state_port: SHOP_FAKE_STATE_PORT
var _round_source: FakeRoundSource
var _condition_policy_port: CONDITION_POLICY_PORT
var _schedule_view_port: SCHEDULE_VIEW_PORT
var _coordinator: RefCounted


func before_each() -> void:
	_root_store = FAKE_ROOT_STORE.new("44".repeat(32), 1)
	_issuer = ISSUER.new()
	_issuer.configure(_root_store)
	_gate = ApplicationMutationGate.new()
	_checkpoint_port = CHECKPOINT_PORT.new()
	_publication_ledger = FakePublicationLedger.new()

	_bootstrap_consequence_state("causal-day-1")

	_causal_sequence_port = CAUSAL_SEQUENCE_PORT.new()
	_causal_sequence_port.configure_publication_ledger(_publication_ledger)
	_causal_sequence_port.configure(_consequence_state, _gate, _checkpoint_port)

	# Board owned by a real MinesweeperRoundCoordinator; the fate port reconnects to the SAME
	# privately owned instance (established test precedent -- see DesktopBoardFatePort's own suite).
	var round_state_port := SHOP_STATE_PORT.new()
	round_state_port.identity_issuer = _issuer
	var round_checkpoint_port := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd").new()
	var round_generation_port := CHECKPOINT_GENERATION_PORT.new()
	round_generation_port.arm_materialize({"schema_version": 1, "width": 3, "height": 3, "mine_indices": [1], "mine_count": 1})
	_round_coordinator = ROUND_COORDINATOR.new()
	_round_coordinator.configure(round_state_port, round_checkpoint_port, round_generation_port, _issuer)
	_board_state = _round_coordinator._board_state
	_board_fate_port = BOARD_FATE_PORT.new()
	_board_fate_port.configure_publication_ledger(_publication_ledger)
	_board_fate_port.configure(_board_state, _issuer)

	assert_true(SHOP_REGISTRY.initialize().get("ok", false), "shop registry must load")
	_shop_state_port = SHOP_FAKE_STATE_PORT.new()
	_shop_state_port.causal_day_instance = "causal-day-1"
	_shop_participant = SHOP_PARTICIPANT.new()
	_shop_participant.configure_publication_ledger(_publication_ledger)
	_shop_participant.configure(_shop_state_port, _consequence_state, _checkpoint_port, SHOP_REGISTRY, _issuer, _gate)

	_round_source = FakeRoundSource.new()
	_condition_policy_port = CONDITION_POLICY_PORT.new()
	_condition_policy_port.configure(RefCounted.new())
	_schedule_view_port = SCHEDULE_VIEW_PORT.new()

	_coordinator = COORDINATOR.new()
	var configured: Dictionary = _coordinator.configure(_consequence_state, _causal_sequence_port,
		_board_fate_port, _checkpoint_port, _gate)
	assert_true(configured.get("ok", false), JSON.stringify(configured))
	var sources_configured: Dictionary = _coordinator.configure_action_source_ports(_round_source, _shop_participant)
	assert_true(sources_configured.get("ok", false), JSON.stringify(sources_configured))
	# Review-fix pass (dwm-p2r.32.8, CRITICAL 1): accept_prepared_action()'s own outer receipt now
	# requires an injected issuer -- wired here so every pre-existing test keeps passing unchanged.
	var issuer_configured: Dictionary = _coordinator.configure_identity_issuer(_issuer)
	assert_true(issuer_configured.get("ok", false), JSON.stringify(issuer_configured))


func _bootstrap_consequence_state(causal_day_instance: String) -> void:
	_consequence_state = CONSEQUENCE_STATE.new()
	var receipt: Dictionary = _root_store.mint(&"causal_day_instance").duplicate(true)
	receipt["token"] = causal_day_instance
	var made: Dictionary = CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": causal_day_instance, "causal_day_instance_issuer_receipt": receipt,
	})
	assert_true(made.get("ok", false), JSON.stringify(made))
	var prepared: Dictionary = _consequence_state.prepare_restore((made["value"] as Dictionary)["state"])
	_consequence_state.commit((prepared["value"] as Dictionary)["candidate"])


func _mint_transaction() -> Dictionary:
	var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]), "transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _live_consequence() -> Dictionary:
	return (_consequence_state.capture()["value"] as Dictionary)["state"]


## Drives a real Shop purchase through prepare_purchase() to the pending action_prepared/
## source_checkpoint state, returning the resulting {action_receipt, candidate} plus the ordinal-0
## checkpoint receipt this coordinator's accept_prepared_action() requires.
func _shop_prepared(item_id: String) -> Dictionary:
	var txn := _mint_transaction()
	var quoted: Dictionary = _shop_participant.quote(item_id, txn["transaction_id"], txn["transaction_issuer_receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live := _live_consequence()
	var request := {
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"item_id": item_id, "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	}
	var prepared: Dictionary = _shop_participant.prepare_purchase(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(prepared.get("code"), &"shop_purchase_action_checkpointed")
	# The ordinal-0 checkpoint receipt: recovered from the fake checkpoint port's own commit log --
	# the most recently committed record for this transaction (the participant's own internal write).
	var checkpoint_receipt: Dictionary = {}
	for record: Dictionary in _checkpoint_port.commit_log:
		if str((record["receipt"] as Dictionary)["checkpoint_id"]).find(txn["transaction_id"]) >= 0:
			checkpoint_receipt = record["receipt"]
	assert_false(checkpoint_receipt.is_empty(), "the source's own ordinal-0 checkpoint must be recorded")
	return {
		"action_receipt": (prepared["value"] as Dictionary)["action_receipt"], "prepared_checkpoint_receipt": checkpoint_receipt,
	}


func _accept_request(prepared: Dictionary, expected_run_revision: int) -> Dictionary:
	var action_receipt: Dictionary = prepared["action_receipt"]
	var transaction_id := str(action_receipt["transaction_id"])
	# The self-sufficient economy candidate GameStateMinesweeperShopPort.prepare_purchase() already
	# built, retrieved directly from the participant's own retained entry -- mirroring this
	# codebase's established "reach into private state for test wiring" precedent (see
	# DesktopBoardFatePort's own suite reconnecting MinesweeperRoundCoordinator._board_state).
	var economy_candidate: Dictionary = (_shop_participant._transactions[transaction_id] as Dictionary)["economy_candidate"]
	return {
		"action_receipt": action_receipt, "action_candidate": economy_candidate,
		"prepared_checkpoint_receipt": prepared["prepared_checkpoint_receipt"],
		"expected_run_revision": expected_run_revision, "expected_board_identity": _board_state.capture()["identity"],
		"expected_board_revision": int(_board_state.capture()["revision"]),
	}


## A hand-built minesweeper_round action receipt/candidate pair, standing in for what
## MinesweeperRoundCoordinator.complete_round() itself produces (proven separately in that file's own
## suite): `board_projection` is already phase NONE with a distinct, inspectable terminal_receipts
## marker, so a test can prove the coordinator threads THIS projection (not a live board capture)
## into the departure -- DesktopBoardFatePort's own suite already proves the port-level "projection,
## never live" law in depth; this is the coordinator's own "did it actually forward the right value"
## proof.
func _round_prepared(marker: String) -> Dictionary:
	if not _gate.is_internal_owner_active(&"causal_transaction"):
		var acquired: Dictionary = _gate.acquire(&"causal_transaction")
		assert_true(acquired.get("ok", false), JSON.stringify(acquired))
	var txn := _mint_transaction()
	var quote_derived: Dictionary = _issuer.derive_child({
		"child_kind": "board_start", "ordinal": 0, "parent_receipt_id": str(txn["transaction_issuer_receipt"]["receipt_id"]),
		"source_ids": ["board-start-source"],
	})
	var action_id_derived: Dictionary = _issuer.derive_child({
		"child_kind": "desktop_action", "ordinal": 0, "parent_receipt_id": str(txn["transaction_issuer_receipt"]["receipt_id"]),
		"source_ids": ["action-source"],
	})
	var action_id := str(action_id_derived["value"]["child_id"])
	var action_id_provenance: Dictionary = action_id_derived["value"]["provenance"]
	var action_receipt := {
		"schema_version": 1, "action_kind": "minesweeper_round", "run_id": "run-fake", "branch_id": "branch-fake",
		"desktop_timeline_generation": 0, "causal_day_instance": "causal-day-1", "day": 1,
		"transaction_id": txn["transaction_id"], "transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"source_commit_receipt_id": str(quote_derived["value"]["child_id"]),
		"source_commit_receipt_provenance": quote_derived["value"]["provenance"],
		"condition_before": {"health": 10, "pressure": 0, "carried_sequela": false},
		"condition_after": {"health": 10, "pressure": 0, "carried_sequela": false}, "unlock_receipt_ids": [],
		"action_id": action_id, "action_id_provenance": action_id_provenance,
		"commit_receipt_id": action_id, "commit_receipt_provenance": (action_id_provenance as Dictionary).duplicate(true),
	}
	var validated := ACTION_RECEIPT.validate(action_receipt)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	action_receipt = (validated["value"] as Dictionary)["receipt"]
	var board_projection := {
		"schema_version": 1, "phase": "NONE", "revision": 0, "identity": null, "candidate": null,
		"board": null, "settlement": null, "command_receipts": {},
		"terminal_receipts": {"round_complete.marker": {"kind": "complete", "outcome": marker}},
	}
	var action_candidate := {
		"transaction_id": str(action_receipt["transaction_id"]), "outcome": marker,
		"identity": {"run_id": "run-fake", "branch_id": "branch-fake", "desktop_timeline_generation": 0,
			"causal_day_instance": "causal-day-1", "app_round_ordinal": 3},
		"board_projection": board_projection,
	}
	var live := _live_consequence()
	var recovery_payload := {
		"source_kind": "minesweeper_round", "action_receipt": action_receipt.duplicate(true),
		"run_revision_before": int(live["run_revision"]), "participant_snapshot_ids": {"outcome": marker},
	}
	var handoff_receipt := action_receipt.duplicate(true)
	handoff_receipt["source_kind"] = "minesweeper_round"
	var handoff: Dictionary = _consequence_state.prepare_action_handoff(handoff_receipt, int(live["run_revision"]), recovery_payload)
	assert_true(handoff.get("ok", false), JSON.stringify(handoff))
	var committed: Dictionary = _consequence_state.commit((handoff["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var checkpoint_header := {
		"kind": &"minesweeper_round_action_checkpoint", "operation_ordinal": 0, "run_id": "run-fake",
		"source_ids": [str(action_receipt["transaction_id"])], "stage": "action_prepared",
		"transaction_id": str(action_receipt["transaction_id"]),
	}
	var checkpoint: Dictionary = _checkpoint_port.prepare_consequence_checkpoint(checkpoint_header, (handoff["value"] as Dictionary)["candidate"]["state_after"])
	assert_true(checkpoint.get("ok", false), JSON.stringify(checkpoint))
	var checkpoint_committed: Dictionary = _checkpoint_port.commit_consequence_checkpoint(
		(checkpoint["value"] as Dictionary)["candidate"], (checkpoint["value"] as Dictionary)["checkpoint_receipt"])
	assert_true(checkpoint_committed.get("ok", false), JSON.stringify(checkpoint_committed))
	return {"action_receipt": action_receipt, "action_candidate": action_candidate,
		"prepared_checkpoint_receipt": (checkpoint["value"] as Dictionary)["checkpoint_receipt"]}


func _configure_departure_ports() -> void:
	var configured: Dictionary = _coordinator.configure_condition_departure_ports(_condition_policy_port, _schedule_view_port)
	assert_true(configured.get("ok", false), JSON.stringify(configured))


## Review-fix pass (dwm-p2r.32.8, CRITICAL 1): asserts accept_prepared_action()'s success carries
## EXACTLY the frozen value/receipt key sets (not a spot check of a few fields), plus the receipt's
## own internal consistency (disposition, causal_sequence echo, a nonblank derived receipt_id).
func _assert_frozen_accept_shape(result: Dictionary, expected_disposition: String) -> void:
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	var value_keys: Array = value.keys()
	value_keys.sort()
	var expected_value_keys: Array = _FROZEN_VALUE_KEYS.duplicate(true)
	expected_value_keys.sort()
	assert_eq(value_keys, expected_value_keys, "value must carry exactly the frozen key set")

	var receipt: Dictionary = result["receipt"]
	var receipt_keys: Array = receipt.keys()
	receipt_keys.sort()
	var expected_receipt_keys: Array = _FROZEN_RECEIPT_KEYS.duplicate(true)
	expected_receipt_keys.sort()
	assert_eq(receipt_keys, expected_receipt_keys, "receipt must carry exactly the frozen key set")
	assert_eq(str(receipt["disposition"]), expected_disposition)
	assert_eq(int(receipt["causal_sequence"]), int(value["causal_sequence"]))
	assert_false(str(receipt["receipt_id"]).is_empty())


## CRITICAL 2 (Review-fix pass): minimal, already-valid fixtures for the frozen intent shapes -- built
## through the SAME issuer/derive_child convention every other receipt in this suite uses, since
## Plan 03 alone owns the real derivation and this coordinator's own validation is scoped to key-set
## and enumerated `kind`/`action_kind`, not every field's deeper type.
func _armed_destination_intent(action_receipt: Dictionary, transaction_id: String) -> Dictionary:
	var derived: Dictionary = _issuer.derive_child({
		"child_kind": "destination_intent", "ordinal": 0,
		"parent_receipt_id": str((action_receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": [transaction_id],
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	return {
		"intent_id": str((derived["value"] as Dictionary)["child_id"]),
		"intent_id_provenance": (derived["value"] as Dictionary)["provenance"],
		"kind": "hospital_day", "day": 3, "causal_day_instance": "causal-day-1",
		"source_condition_receipt_id": "condition.fake.placeholder",
		"source_condition_receipt_provenance": {"schema_version": 1, "parent_receipt_id": "",
			"child_kind": "condition", "ordinal": 0, "source_ids": [transaction_id], "child_id": ""},
		"accepted_unfulfilled_sources": [], "terminal_cause": null, "terminal_provenance": null,
		"prerequisite_receipt_ids": [],
	}


func _armed_notification_intent(action_receipt: Dictionary, transaction_id: String) -> Dictionary:
	var derived: Dictionary = _issuer.derive_child({
		"child_kind": "notification_intent", "ordinal": 0,
		"parent_receipt_id": str((action_receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": [transaction_id],
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	return {
		"intent_id": str((derived["value"] as Dictionary)["child_id"]),
		"intent_id_provenance": (derived["value"] as Dictionary)["provenance"],
		"action_kind": str(action_receipt["action_kind"]),
		"action_commit_receipt_id": str(action_receipt["commit_receipt_id"]),
		"action_commit_receipt_provenance": action_receipt["commit_receipt_provenance"],
		"source_condition_receipt_id": "condition.fake.placeholder",
		"source_condition_receipt_provenance": {"schema_version": 1, "parent_receipt_id": "",
			"child_kind": "condition", "ordinal": 0, "source_ids": [transaction_id], "child_id": ""},
	}


# ---- Step 8.1 parse proof ----

func test_coordinator_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(COORDINATOR_PATH)
	assert_true(loaded.get("ok", false), "DesktopConsequenceCoordinator.gd must load")


func test_coordinator_instantiates() -> void:
	var instantiated: Dictionary = PROBE.instantiate(COORDINATOR_PATH)
	assert_true(instantiated.get("ok", false), "DesktopConsequenceCoordinator.gd must instantiate")


# ---- configuration ----

func test_configure_action_source_ports_rejects_the_same_object_for_both_roles() -> void:
	var fresh := COORDINATOR.new()
	fresh.configure(_consequence_state, _causal_sequence_port, _board_fate_port, _checkpoint_port, _gate)
	var result: Dictionary = fresh.configure_action_source_ports(_shop_participant, _shop_participant)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"action_source_ports_must_be_distinct")


func test_configure_condition_departure_ports_requires_action_source_ports_first() -> void:
	var fresh := COORDINATOR.new()
	fresh.configure(_consequence_state, _causal_sequence_port, _board_fate_port, _checkpoint_port, _gate)
	var result: Dictionary = fresh.configure_condition_departure_ports(_condition_policy_port, _schedule_view_port)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"action_source_ports_unconfigured")


func test_accept_prepared_action_rejects_before_condition_departure_ports_configured() -> void:
	var prepared := _shop_prepared("lucky_charm")
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"condition_departure_ports_unconfigured")


# ---- accept_prepared_action(): no-departure path ----

func test_accept_prepared_action_no_departure_commits_and_publishes() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("lucky_charm")
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result.get("code"), &"action_consequence_accepted")
	# Review-fix pass (dwm-p2r.32.8, CRITICAL 1): the frozen shape has no "departure" key -- read the
	# disposition off the receipt instead.
	assert_eq(str(result["receipt"]["disposition"]), "no_departure")

	# The shop economy actually committed (capability granted).
	assert_true(bool(_shop_state_port.inventory.get("lucky_charm", false)))
	assert_eq(_round_source.committed.size(), 0)
	assert_eq(_shop_participant._recovery_committed.size(), 1)

	# Live consequence state returned to a clean slate: pending cleared, sequence advanced.
	var live := _live_consequence()
	assert_null(live["pending"])
	assert_eq(int(live["causal_sequence"]), 1)
	assert_eq(int(live["run_revision"]), 1)

	# Publication ledger recorded exactly causal_sequence (keyed by its own source_kind) + action_source
	# (no board_fate for no-departure).
	var kinds: Array = []
	for record: Dictionary in _publication_ledger.records.values():
		kinds.append(str(record["kind"]))
	kinds.sort()
	assert_eq(kinds, ["action_source", "shop_purchase"])


func test_accept_prepared_action_duplicate_replay_returns_identical_result() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("lucky_charm")
	var request := _accept_request(prepared, 0)
	var first: Dictionary = _coordinator.accept_prepared_action(request)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var replay: Dictionary = _coordinator.accept_prepared_action(request)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay, first)


func test_accept_prepared_action_changed_bytes_at_same_identity_conflicts() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("lucky_charm")
	var request := _accept_request(prepared, 0)
	_coordinator.accept_prepared_action(request)
	var changed := request.duplicate(true)
	changed["expected_run_revision"] = 5
	var result: Dictionary = _coordinator.accept_prepared_action(changed)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"action_receipt_conflict")


# ---- accept_prepared_action(): departure path ----

func test_accept_prepared_action_departure_discards_the_preparing_board_and_commits_the_view() -> void:
	_configure_departure_ports()
	# Put the board into PREPARING via the real round coordinator (independent of the Shop purchase).
	var board_identity: Dictionary = _round_coordinator.get_entry_context("beginner")["value"]["identity"]
	var begin_txn := _mint_transaction()
	var begun: Dictionary = _round_coordinator.begin_debug_preparation({
		"transaction_id": begin_txn["transaction_id"], "transaction_issuer_receipt": begin_txn["transaction_issuer_receipt"],
		"expected_identity": board_identity, "expected_revision": 0, "difficulty_id": "beginner",
	})
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	assert_eq(_board_state.capture()["phase"], "PREPARING")

	var prepared := _shop_prepared("debug_key")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	# Review-fix pass (dwm-p2r.32.8, CRITICAL 2): the brief requires a departure to enqueue exactly
	# one destination intent -- arm one so this pre-existing departure fixture stays valid under the
	# coordinator's own new pairing law.
	var destination_intent := _armed_destination_intent(prepared["action_receipt"], action_txn)
	_condition_policy_port.arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(str(result["receipt"]["disposition"]), "departure_committed")

	assert_eq(_board_state.capture()["phase"], "NONE", "the departure discards the unstarted candidate")
	assert_eq(_schedule_view_port.commit_calls, 1)
	assert_eq(_live_consequence()["pending"], null)

	var kinds: Array = []
	for record: Dictionary in _publication_ledger.records.values():
		kinds.append(str(record["kind"]))
	kinds.sort()
	assert_eq(kinds, ["action_source", "board_fate", "shop_purchase"])


func test_accept_prepared_action_minesweeper_round_departure_uses_the_action_candidate_projection_not_the_live_board() -> void:
	_configure_departure_ports()
	# Deliberately diverge the shared live board from the completed round's own projection (not
	# domain-realistic on its own, but the sharpest proof available that board fate acts on
	# action_candidate.board_projection specifically -- a mutation reading the LIVE board instead
	# would see PREPARING and yield discarded_unstarted, not the projection's own "none".
	var identity: Dictionary = _round_coordinator.get_entry_context("beginner")["value"]["identity"]
	var begin_txn := _mint_transaction()
	var begun: Dictionary = _round_coordinator.begin_debug_preparation({
		"transaction_id": begin_txn["transaction_id"], "transaction_issuer_receipt": begin_txn["transaction_issuer_receipt"],
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner",
	})
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var live: Dictionary = _board_state.capture()
	assert_eq(live["phase"], "PREPARING")

	var prepared := _round_prepared("cleared")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	var destination_intent := _armed_destination_intent(prepared["action_receipt"], action_txn)
	_condition_policy_port.arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)
	var request := {
		"action_receipt": prepared["action_receipt"], "action_candidate": prepared["action_candidate"],
		"prepared_checkpoint_receipt": prepared["prepared_checkpoint_receipt"], "expected_run_revision": 0,
		"expected_board_identity": live["identity"], "expected_board_revision": int(live["revision"]),
	}
	var result: Dictionary = _coordinator.accept_prepared_action(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(str(result["receipt"]["disposition"]), "departure_committed")
	# fate=none: the projected candidate (already NONE) is what board fate acted on, retaining the
	# completed result rather than forfeiting the unrelated live PREPARING board -- proven by the
	# ledger record's own board_fate kind.
	var board_fate_records := 0
	for record: Dictionary in _publication_ledger.records.values():
		if str(record["kind"]) == "board_fate":
			board_fate_records += 1
			assert_eq(str((record["semantic_receipt"] as Dictionary)["fate"]), "none")
	assert_eq(board_fate_records, 1)


# ---- resume_pending(): admitted but not yet published, resumed by a reconstructed coordinator ----

func test_resume_pending_completes_forward_recovery_after_a_reconstructed_coordinator() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("lucky_charm")
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_null(_live_consequence()["pending"], "the happy path above already reaches a clean slate")

	# Simulate an interrupted second transaction: crash BEFORE the coordinator's own publication loop
	# starts, by preparing a second purchase, admitting it manually via a fresh coordinator, then
	# reconstructing a THIRD coordinator instance (empty in-memory ledger) to resume.
	var prepared2 := _shop_prepared("debug_key")
	var accept_req := _accept_request(prepared2, 1)
	var admitted: Dictionary = _coordinator.accept_prepared_action(accept_req)
	assert_true(admitted.get("ok", false), JSON.stringify(admitted))
	assert_null(_live_consequence()["pending"], "a single accept_prepared_action call already carries the transaction through")

	# Full resume_pending() coverage (no pending transaction remaining) is exercised by asserting the
	# no-op success shape on a fresh coordinator instance over the same, now-clean live state.
	var fresh := COORDINATOR.new()
	fresh.configure(_consequence_state, _causal_sequence_port, _board_fate_port, _checkpoint_port, _gate)
	fresh.configure_action_source_ports(_round_source, _shop_participant)
	fresh.configure_condition_departure_ports(_condition_policy_port, _schedule_view_port)
	var resumed: Dictionary = fresh.resume_pending()
	assert_true(resumed.get("ok", false), JSON.stringify(resumed))
	assert_false(bool(resumed["value"]["resumed"]))


# ---- Review-fix pass (dwm-p2r.32.8): CRITICAL 1 -- exact frozen value/receipt key sets ----

func test_accept_prepared_action_shop_purchase_no_departure_returns_the_frozen_value_and_receipt_key_sets() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("lucky_charm")
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	_assert_frozen_accept_shape(result, "no_departure")
	assert_null(result["value"]["board_fate_receipt"])
	assert_null(result["value"]["schedule_view_commit_receipt"])
	assert_null(result["value"]["destination_intent"])
	assert_null(result["value"]["notification_intent"])


func test_accept_prepared_action_shop_purchase_departure_returns_the_frozen_value_and_receipt_key_sets() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("debug_key")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	var destination_intent := _armed_destination_intent(prepared["action_receipt"], action_txn)
	_condition_policy_port.arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	_assert_frozen_accept_shape(result, "departure_committed")
	assert_eq(typeof(result["value"]["board_fate_receipt"]), TYPE_DICTIONARY)
	assert_eq(typeof(result["value"]["schedule_view_commit_receipt"]), TYPE_DICTIONARY)


func test_accept_prepared_action_minesweeper_round_no_departure_returns_the_frozen_value_and_receipt_key_sets() -> void:
	_configure_departure_ports()
	var prepared := _round_prepared("exploded")
	var request := {
		"action_receipt": prepared["action_receipt"], "action_candidate": prepared["action_candidate"],
		"prepared_checkpoint_receipt": prepared["prepared_checkpoint_receipt"], "expected_run_revision": 0,
		"expected_board_identity": _board_state.capture()["identity"], "expected_board_revision": int(_board_state.capture()["revision"]),
	}
	var result: Dictionary = _coordinator.accept_prepared_action(request)
	_assert_frozen_accept_shape(result, "no_departure")
	assert_null(result["value"]["board_fate_receipt"])
	assert_null(result["value"]["schedule_view_commit_receipt"])


func test_accept_prepared_action_minesweeper_round_departure_returns_the_frozen_value_and_receipt_key_sets() -> void:
	_configure_departure_ports()
	var prepared := _round_prepared("cleared")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	var destination_intent := _armed_destination_intent(prepared["action_receipt"], action_txn)
	_condition_policy_port.arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)
	var request := {
		"action_receipt": prepared["action_receipt"], "action_candidate": prepared["action_candidate"],
		"prepared_checkpoint_receipt": prepared["prepared_checkpoint_receipt"], "expected_run_revision": 0,
		"expected_board_identity": _board_state.capture()["identity"], "expected_board_revision": int(_board_state.capture()["revision"]),
	}
	var result: Dictionary = _coordinator.accept_prepared_action(request)
	_assert_frozen_accept_shape(result, "departure_committed")
	assert_eq(typeof(result["value"]["board_fate_receipt"]), TYPE_DICTIONARY)
	assert_eq(typeof(result["value"]["schedule_view_commit_receipt"]), TYPE_DICTIONARY)


# ---- Review-fix pass (dwm-p2r.32.8): CRITICAL 2 -- destination_intent/notification_intent ----

func test_accept_prepared_action_departure_with_destination_intent_lands_it_in_the_final_value() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("debug_key")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	var destination_intent := _armed_destination_intent(prepared["action_receipt"], action_txn)
	_condition_policy_port.arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["destination_intent"], destination_intent)
	assert_null(result["value"]["notification_intent"])


func test_accept_prepared_action_no_departure_with_notification_intent_lands_it_in_the_final_value() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("lucky_charm")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	var notification_intent := _armed_notification_intent(prepared["action_receipt"], action_txn)
	_condition_policy_port.arm(action_txn, "no_departure", false, false, {}, [], null, null, notification_intent)
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["notification_intent"], notification_intent)
	assert_null(result["value"]["destination_intent"])
	assert_null(_live_consequence()["pending"], "the no-departure transaction still reaches a clean slate")


func test_accept_prepared_action_no_departure_with_neither_intent_leaves_both_null() -> void:
	_configure_departure_ports()
	var prepared := _shop_prepared("lucky_charm")
	var result: Dictionary = _coordinator.accept_prepared_action(_accept_request(prepared, 0))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_null(result["value"]["destination_intent"])
	assert_null(result["value"]["notification_intent"])


## Proves both halves of CRITICAL 2's "outbox" wording at once: destination_intent lands in the
## DURABLE pending record at the sequence_committed->publication_pending edge (inspected here BEFORE
## the injected publish failure below even runs), and a forward-recovery replay on a reconstructed
## coordinator publishes every participant exactly once -- never re-publishing the causal_sequence
## callback that already succeeded before the crash.
func test_accept_prepared_action_departure_intent_lands_in_the_persisted_pending_record_exactly_once_across_a_forward_recovery_replay() -> void:
	_configure_departure_ports()
	var prepared := _round_prepared("cleared")
	var action_txn: String = str(prepared["action_receipt"]["transaction_id"])
	var destination_intent := _armed_destination_intent(prepared["action_receipt"], action_txn)
	_condition_policy_port.arm(action_txn, "hospital_day", false, true, {}, [], null, destination_intent, null)
	_round_source.fail_publish_once = true

	var request := {
		"action_receipt": prepared["action_receipt"], "action_candidate": prepared["action_candidate"],
		"prepared_checkpoint_receipt": prepared["prepared_checkpoint_receipt"], "expected_run_revision": 0,
		"expected_board_identity": _board_state.capture()["identity"], "expected_board_revision": int(_board_state.capture()["revision"]),
	}
	var first: Dictionary = _coordinator.accept_prepared_action(request)
	assert_false(first.get("ok", false), "the injected action_source publish failure must surface")

	var live_pending: Dictionary = _live_consequence()["pending"]
	assert_eq(live_pending["destination_intent"], destination_intent)
	assert_null(live_pending["notification_intent"])
	assert_eq(str(live_pending["stage"]), "publication_pending")

	var fresh := COORDINATOR.new()
	fresh.configure(_consequence_state, _causal_sequence_port, _board_fate_port, _checkpoint_port, _gate)
	fresh.configure_action_source_ports(_round_source, _shop_participant)
	fresh.configure_condition_departure_ports(_condition_policy_port, _schedule_view_port)
	fresh.configure_identity_issuer(_issuer)
	var resumed: Dictionary = fresh.resume_pending()
	assert_true(resumed.get("ok", false), JSON.stringify(resumed))
	assert_true(bool(resumed["value"]["resumed"]))
	assert_null(_live_consequence()["pending"])
	assert_eq(_round_source.published.size(), 1, "exactly one publish despite the first attempt's injected failure")

	# FakeRoundSource (this suite's own hand-built minesweeper_round stand-in, unlike the real
	# MinesweeperRoundCoordinator) never writes to the publication ledger itself -- only its own
	# `published` array, already asserted above -- so the ledger sees causal_sequence (kind=
	# minesweeper_round) and board_fate, never action_source.
	var kinds: Array = []
	for record: Dictionary in _publication_ledger.records.values():
		kinds.append(str(record["kind"]))
	kinds.sort()
	assert_eq(kinds, ["board_fate", "minesweeper_round"])


# ---- Review-fix pass (dwm-p2r.32.8): IMPORTANT 3 -- checkpoint ordinal/stage cross-validation ----

func test_validate_ordinal_stage_pairing_accepts_the_documented_pairing() -> void:
	assert_true(_coordinator._validate_ordinal_stage_pairing(
		{"operation_ordinal": 1, "stage": "action_prepared"}).get("ok", false))
	assert_true(_coordinator._validate_ordinal_stage_pairing(
		{"operation_ordinal": 2, "stage": "sequence_committed"}).get("ok", false))


func test_validate_ordinal_stage_pairing_rejects_a_mismatched_pairing() -> void:
	var result: Dictionary = _coordinator._validate_ordinal_stage_pairing(
		{"operation_ordinal": 1, "stage": "sequence_committed"})
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"consequence_checkpoint_ordinal_stage_invalid")
