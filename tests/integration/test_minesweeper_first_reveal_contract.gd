extends "res://addons/gut/test.gd"
# Integration RED/GREEN contract tests for the Task-5 first-Reveal transaction (Plan 02 Task 5,
# dwm-p2r.32, req.minesweeper.round_contract). Drives MinesweeperRoundCoordinator, its owned
# DesktopBoardState, and all three Task-5 contract fakes together end-to-end -- proving the whole
# stack composes, that the fake checkpoint's provisional/reversible-until-seal semantics hold, and
# that the production boundary (SaveManagerMinesweeperPort, ApplicationBootstrap, canonical save,
# any storage path) is entirely absent from this transaction. Per-scenario rollback/duplicate/
# conflict coverage lives in test_minesweeper_round_coordinator.gd; this file focuses on the
# end-to-end shape and the production-boundary-absence proof Step 5.7 requires.
#
# GLOBAL CLASS NAMES ARE NOT AVAILABLE for these fresh Task-5 scripts, so every dependency is
# preloaded by path -- this repo's established answer (see test_desktop_identity_nonce_issuer.gd).

const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const STATE_PORT := preload("res://tests/support/FakeDesktopBoardStatePort.gd")
const CHECKPOINT_PORT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION_PORT := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

## Method-name fragments that would signal the fake reached toward production persistence. None of
## these ever appear in either fake's call log across the tests in this file.
const _FORBIDDEN_CALL_FRAGMENTS: Array[String] = ["save", "storage", "disk", "bootstrap"]

var _coordinator: COORDINATOR
var _state_port: STATE_PORT
var _checkpoint_port: CHECKPOINT_PORT
var _generation_port: GENERATION_PORT
var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER


func before_each() -> void:
	_coordinator = COORDINATOR.new()
	_state_port = STATE_PORT.new()
	_checkpoint_port = CHECKPOINT_PORT.new()
	_generation_port = GENERATION_PORT.new()
	_root_store = FAKE_ROOT_STORE.new("33".repeat(32), 1)
	_issuer = ISSUER.new()
	_issuer.configure(_root_store)
	_state_port.identity_issuer = _issuer
	_generation_port.arm_materialize({"schema_version": 1, "width": 3, "height": 3, "mine_indices": [1], "mine_count": 1})
	var configured := _coordinator.configure(_state_port, _checkpoint_port, _generation_port, _issuer)
	assert_true(configured.get("ok", false), "configure() must succeed: %s" % configured)


# ---- end-to-end happy path: entry context -> first Reveal -> routine command -> suspend/resume ----

func test_full_default_round_end_to_end() -> void:
	var context := _coordinator.get_entry_context("beginner")
	assert_true(context.get("ok", false))
	assert_true(context["value"]["eligible"])
	var identity: Dictionary = context["value"]["identity"]

	var reveal_result := _coordinator.reveal(_first_reveal_request(identity, 0, "beginner", 0))
	assert_true(reveal_result.get("ok", false), JSON.stringify(reveal_result))
	assert_eq(reveal_result.get("code"), &"first_reveal_committed")
	var receipt: Dictionary = reveal_result["value"]["receipt"]
	assert_eq(receipt["rounds_after"], 1)
	assert_eq(receipt["motivation_after"], 6)

	var routine := _coordinator.reveal(_cell_request(identity, 1, 2))
	assert_true(routine.get("ok", false), JSON.stringify(routine))
	assert_eq(routine["value"]["phase"], "ACTIVE_VISIBLE")

	var suspended := _coordinator.suspend(_generic_request(identity, 2))
	assert_true(suspended.get("ok", false), JSON.stringify(suspended))
	assert_eq(suspended["value"]["phase"], "ACTIVE_SUSPENDED")
	var resumed := _coordinator.resume(_generic_request(identity, 3))
	assert_true(resumed.get("ok", false), JSON.stringify(resumed))
	assert_eq(resumed["value"]["phase"], "ACTIVE_VISIBLE")


func test_full_debug_round_end_to_end() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	var begun := _coordinator.begin_debug_preparation(_debug_request(identity, 0, "beginner"))
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	_generation_port.arm_search_slices([
		{"done": true, "layout": {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [1], "mine_count": 1},
			"forced_cell": 0, "proof_sha256": "integration-proof"},
	])
	var certified := _coordinator.run_debug_preparation_slice(_generic_request(identity, 1))
	assert_true(certified.get("ok", false), JSON.stringify(certified))
	assert_eq(certified["value"]["phase"], "PREPARED_UNSTARTED")

	var revealed := _coordinator.reveal(_first_reveal_request(identity, 2, "beginner", 0))
	assert_true(revealed.get("ok", false), JSON.stringify(revealed))
	assert_eq(revealed["value"]["receipt"]["proof_sha256"], "integration-proof")


# ---- fake checkpoint provisional/reversible-until-seal semantics ----

func test_checkpoint_commit_is_reversible_until_seal_and_fixed_after() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	# Fail state_port.commit AFTER the checkpoint is provisionally committed: the checkpoint must be
	# rolled back rather than left half-applied.
	_state_port.fail_next("commit", {"ok": false, "code": &"fake_state_commit_failed", "message": "", "details": {}})
	var failed := _coordinator.reveal(_first_reveal_request(identity, 0, "beginner", 0))
	assert_false(failed.get("ok", false))
	assert_false(_checkpoint_port.is_committed("run-fake:1"),
		"a checkpoint provisionally committed before a later failure must roll back")

	# A clean retry with the SAME identity/revision now succeeds and seals durably.
	var succeeded := _coordinator.reveal(_first_reveal_request(identity, 0, "beginner", 0))
	assert_true(succeeded.get("ok", false), JSON.stringify(succeeded))
	assert_true(_checkpoint_port.is_sealed("run-fake:1"))


func test_seal_failure_rolls_back_every_participant_leaving_bytes_unchanged() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	var motivation_before := _state_port.motivation
	var rounds_before := _state_port.rounds_left
	_checkpoint_port.fail_next("seal_checkpoint",
		{"ok": false, "code": &"fake_seal_failed", "message": "", "details": {}})
	var result := _coordinator.reveal(_first_reveal_request(identity, 0, "beginner", 0))
	assert_false(result.get("ok", false))
	assert_eq(_state_port.motivation, motivation_before, "motivation bytes must be unchanged")
	assert_eq(_state_port.rounds_left, rounds_before, "round-counter bytes must be unchanged")
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE", "board bytes must be unchanged")
	assert_false(_checkpoint_port.is_committed("run-fake:1"), "fake-checkpoint bytes must be unchanged")


func test_publish_failure_after_seal_is_committed_unpublished_then_exact_retry_publishes_once() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	_state_port.fail_next("publish", {"ok": false, "code": &"fake_publish_failed", "message": "", "details": {}})
	var request := _first_reveal_request(identity, 0, "beginner", 0)
	var failed := _coordinator.reveal(request)
	assert_false(failed.get("ok", false))
	assert_eq(failed.get("code"), &"FIRST_REVEAL_COMMITTED_UNPUBLISHED")

	var retried := _coordinator.reveal(request)
	assert_true(retried.get("ok", false), JSON.stringify(retried))
	assert_eq(retried.get("code"), &"first_reveal_committed")
	assert_eq(retried["value"]["receipt"], failed["details"]["receipt"])
	assert_eq(_state_port.published.size(), 1, "only the successful retry publishes")
	assert_eq(_state_port.motivation, 6, "the retry never charges a second time")


# ---- production-boundary absence ----

func test_fake_checkpoint_reports_never_production() -> void:
	assert_false(_checkpoint_port.is_production())


func test_no_participant_ever_calls_toward_a_production_persistence_path() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	_coordinator.reveal(_first_reveal_request(identity, 0, "beginner", 0))
	for entry: Dictionary in _checkpoint_port.call_log:
		_assert_method_name_clean(str(entry["method"]))
	for entry: Dictionary in _state_port.call_log:
		_assert_method_name_clean(str(entry["method"]))


func _assert_method_name_clean(method_name: String) -> void:
	var lowered := method_name.to_lower()
	for fragment: String in _FORBIDDEN_CALL_FRAGMENTS:
		assert_false(lowered.contains(fragment),
			"method name '%s' suggests a production persistence path" % method_name)


# ---- helpers ----

var _tx_counter := 0

func _next_tx() -> String:
	_tx_counter += 1
	var issued := _issuer.issue(&"transaction_id")
	return str(issued["value"]["token"])


func _issue_transaction_receipt_for(transaction_id: String) -> Dictionary:
	for receipt: Dictionary in _root_store.receipts.values():
		if String(receipt["purpose"]) == "transaction_id" and str(receipt["token"]) == transaction_id:
			return receipt
	fail_test("no minted transaction_id receipt found for %s" % transaction_id)
	return {}


func _debug_request(identity: Dictionary, expected_revision: int, difficulty_id: String) -> Dictionary:
	var tx := _next_tx()
	return {
		"transaction_id": tx, "transaction_issuer_receipt": _issue_transaction_receipt_for(tx),
		"expected_identity": identity, "expected_revision": expected_revision, "difficulty_id": difficulty_id,
	}


func _generic_request(identity: Dictionary, expected_revision: int) -> Dictionary:
	var tx := _next_tx()
	return {
		"transaction_id": tx, "transaction_issuer_receipt": _issue_transaction_receipt_for(tx),
		"expected_identity": identity, "expected_revision": expected_revision,
	}


func _cell_request(identity: Dictionary, expected_revision: int, cell_index: int) -> Dictionary:
	var tx := _next_tx()
	return {
		"transaction_id": tx, "transaction_issuer_receipt": _issue_transaction_receipt_for(tx),
		"expected_identity": identity, "expected_revision": expected_revision, "cell_index": cell_index,
	}


func _first_reveal_request(identity: Dictionary, expected_revision: int, difficulty_id: String,
		cell_index: int) -> Dictionary:
	var tx := _next_tx()
	return {
		"transaction_id": tx, "transaction_issuer_receipt": _issue_transaction_receipt_for(tx),
		"expected_identity": identity, "expected_revision": expected_revision,
		"difficulty_id": difficulty_id, "cell_index": cell_index,
	}
