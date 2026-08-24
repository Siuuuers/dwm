extends "res://addons/gut/test.gd"
## RED/GREEN coverage for DesktopBoardFatePort (Plan 02 Task 8, dwm-p2r.32,
## req.minesweeper.causal_departure). Representative, mutation-tested coverage of the core
## capture/prepare/commit/rollback/publish contract and its three fates (none/discarded_unstarted/
## forfeited_started), not an exhaustive permutation of every phase x stage x corruption named in
## the brief's Step 8.1 enumeration -- see the Task-8 report for an honest note on what is
## representative rather than exhaustive here, matching this repo's own established precedent.
##
## Board phases are driven through a REAL `MinesweeperRoundCoordinator` (application, Task-5 file,
## preloaded by path, no class_name) via its existing fake ports, then its privately owned
## `_board_state` is reconnected directly to `DesktopBoardFatePort.configure()` -- the SAME
## direct-property-access pattern Task 6's own restore tests already established for this exact
## coordinator (see its report's C2/D handoff), rather than hand-building MinesweeperBoardSchema
## board dictionaries from scratch.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/minesweeper/DesktopBoardFatePort.gd"
const PORT := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const STATE_PORT := preload("res://tests/support/FakeDesktopBoardStatePort.gd")
const CHECKPOINT_PORT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION_PORT := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")

## A pass-through call COUNTER wrapped around the REAL DesktopPublicationLedger. It decides
## nothing: every request is forwarded verbatim and the real ledger's verbatim result comes back,
## so every acceptance and every rejection in this file is production's own. The counter exists
## only because the real ledger keeps no call count of its own, and one test below has to prove
## `record_before_emit` is still CALLED on a republish (where it correctly becomes a no-op) rather
## than skipped.
##
## FIX (dwm-p2r.35.6, the W6 truthfulness wave): what stood here was a hand-rolled double that
## keyed every record off `semantic_receipt["receipt_id"]` whatever the kind, compared whole
## requests with raw `==`, and accepted ANY `kind` with ANY publication shape. The real ledger has
## a CLOSED three-kind union (`causal_sequence`/`action_source`/`board_fate`), an exact per-kind
## publication member set, a per-kind receipt-id path, a canonical `publication_sha256` check and a
## write-then-re-read durability confirmation -- none of which the double could ever refuse. Same
## root cause as the whole dwm-p2r.35 remediation: a double accepting what production rejects.
class CountingPublicationLedger extends RefCounted:
	var real: Object = null
	var record_calls := 0

	func _init(real_ledger: Object) -> void:
		real = real_ledger

	func record_before_emit(request: Dictionary) -> Dictionary:
		record_calls += 1
		return real.call(&"record_before_emit", request)

var _coordinator: COORDINATOR
var _publication_root_counter := 0
var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER


func before_each() -> void:
	_root_store = FAKE_ROOT_STORE.new("33".repeat(32), 1)
	_issuer = ISSUER.new()
	_issuer.configure(_root_store)
	var state_port := STATE_PORT.new()
	state_port.identity_issuer = _issuer
	var checkpoint_port := CHECKPOINT_PORT.new()
	var generation_port := GENERATION_PORT.new()
	generation_port.arm_materialize(_layout())
	_coordinator = COORDINATOR.new()
	_coordinator.configure(state_port, checkpoint_port, generation_port, _issuer)


## The REAL DesktopPublicationLedger needs a real storage root. Mirrors
## test_desktop_publication_ledger.gd's own isolation discipline exactly -- the wrapper-provided
## DWM_TEST_ROOT, never the production user:// directory -- with a FRESH root per ledger so each
## test starts against an empty durable ledger, the way the deleted in-memory double did.
func _isolated_publication_root() -> String:
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_publication_root_counter += 1
	var root: String = wrapper.path_join("board-fate-publications-%d" % _publication_root_counter)
	var production := ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


func _real_publication_ledger() -> CountingPublicationLedger:
	var ledger: Object = PUBLICATION_LEDGER.new()
	var configured: Dictionary = ledger.configure(JsonFileStorage.new(_isolated_publication_root()))
	assert_true(configured.get("ok", false), JSON.stringify(configured))
	var loaded: Dictionary = ledger.load()
	assert_true(loaded.get("ok", false), JSON.stringify(loaded))
	return CountingPublicationLedger.new(ledger)


## The real ledger's DURABLE records, re-read from disk -- the deleted double exposed a plain
## in-memory `records` Dictionary instead.
func _ledger_records(ledger: CountingPublicationLedger) -> Dictionary:
	var loaded: Dictionary = ledger.real.call(&"load")
	assert_true(loaded.get("ok", false), JSON.stringify(loaded))
	return ((loaded["value"] as Dictionary)["document"] as Dictionary)["records"]


func _layout() -> Dictionary:
	return {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [1], "mine_count": 1}


func _next_tx() -> String:
	var issued := _issuer.issue(&"transaction_id")
	return str(issued["value"]["token"])


func _issue_transaction_receipt_for(transaction_id: String) -> Dictionary:
	for receipt: Dictionary in _root_store.receipts.values():
		if String(receipt["purpose"]) == "transaction_id" and str(receipt["token"]) == transaction_id:
			return receipt
	fail_test("no minted transaction_id receipt found for %s" % transaction_id)
	return {}


func _reveal_first(transaction_id: String, difficulty_id: String, cell_index: int) -> Dictionary:
	var identity: Dictionary = _coordinator.get_entry_context(difficulty_id)["value"]["identity"]
	var request := {
		"transaction_id": transaction_id, "transaction_issuer_receipt": _issue_transaction_receipt_for(transaction_id),
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": difficulty_id, "cell_index": cell_index,
	}
	return _coordinator.reveal(request)


func _begin_debug(transaction_id: String, difficulty_id: String) -> Dictionary:
	var identity: Dictionary = _coordinator.get_entry_context(difficulty_id)["value"]["identity"]
	return _coordinator.begin_debug_preparation({
		"transaction_id": transaction_id, "transaction_issuer_receipt": _issue_transaction_receipt_for(transaction_id),
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": difficulty_id,
	})


## Reconnects the port to the coordinator's own privately owned board-state instance, mirroring the
## established test precedent for this exact wiring gap (see the class doc's OWNERSHIP WIRING note).
func _wired(ledger: CountingPublicationLedger = null) -> Dictionary:
	var live_ledger: CountingPublicationLedger = ledger if ledger != null else _real_publication_ledger()
	var port := PORT.new()
	var configured_ledger: Dictionary = port.configure_publication_ledger(live_ledger)
	assert_true(configured_ledger.get("ok", false), JSON.stringify(configured_ledger))
	var configured: Dictionary = port.configure(_coordinator._board_state, _issuer)
	assert_true(configured.get("ok", false), JSON.stringify(configured))
	return {"port": port, "ledger": live_ledger}


func _schedule_request(command_id: String, live: Dictionary) -> Dictionary:
	return {
		"command_id": command_id, "command_issuer_receipt": _issue_transaction_receipt_for(command_id),
		"run_id": "run-fake", "branch_id": "branch-fake", "causal_day_instance": "day-fake",
		"reason": "schedule_done", "expected_board_identity": live["identity"], "expected_board_revision": live["revision"],
	}


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	return str(emitted["value"]).sha256_text()


## Builds a minimal, ACTION_RECEIPT.validate()-passing action receipt whose transaction_id equals
## `command_id`, for the condition_departure seam.
func _source_action_receipt(command_id: String, action_kind: String) -> Dictionary:
	var transaction_receipt := _issue_transaction_receipt_for(command_id)
	var quote_derived: Dictionary = _issuer.derive_child({
		"child_kind": "shop_quote", "ordinal": 0, "parent_receipt_id": str(transaction_receipt["receipt_id"]),
		"source_ids": ["quote-source"],
	})
	var quote_id := str(quote_derived["value"]["child_id"])
	var quote_provenance: Dictionary = quote_derived["value"]["provenance"]
	var action_candidate := {
		"schema_version": 1, "action_kind": action_kind, "run_id": "run-fake", "branch_id": "branch-fake",
		"desktop_timeline_generation": 0, "causal_day_instance": "day-fake", "day": 1,
		"transaction_id": command_id, "transaction_issuer_receipt": transaction_receipt,
		"source_commit_receipt_id": quote_id, "source_commit_receipt_provenance": quote_provenance,
		"condition_before": {"health": 10, "pressure": 0, "carried_sequela": false},
		"condition_after": {"health": 10, "pressure": 0, "carried_sequela": false},
		"unlock_receipt_ids": [],
	}
	var action_id_derived: Dictionary = _issuer.derive_child({
		"child_kind": "desktop_action", "ordinal": 0, "parent_receipt_id": str(transaction_receipt["receipt_id"]),
		"source_ids": ["action-source"],
	})
	var receipt := action_candidate.duplicate(true)
	receipt["action_id"] = str(action_id_derived["value"]["child_id"])
	receipt["action_id_provenance"] = action_id_derived["value"]["provenance"]
	receipt["commit_receipt_id"] = receipt["action_id"]
	receipt["commit_receipt_provenance"] = (receipt["action_id_provenance"] as Dictionary).duplicate(true)
	var validated := ACTION_RECEIPT.validate(receipt)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	return (validated["value"] as Dictionary)["receipt"]


func _projected_request(command_id: String, action_receipt: Dictionary, projected: Dictionary,
		live: Dictionary) -> Dictionary:
	return {
		"command_id": command_id, "command_issuer_receipt": action_receipt["transaction_issuer_receipt"],
		"run_id": "run-fake", "branch_id": "branch-fake", "causal_day_instance": "day-fake",
		"reason": "condition_departure", "expected_board_identity": live["identity"],
		"expected_board_revision": live["revision"], "source_action_receipt": action_receipt,
		"projected_board_candidate": projected, "projected_board_candidate_sha256": _canonical_sha256(projected),
	}


# ---- Step 8.1 parse proof ----

func test_port_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	assert_true(loaded.get("ok", false), "DesktopBoardFatePort.gd must load")


func test_port_instantiates() -> void:
	var instantiated: Dictionary = PROBE.instantiate(PORT_PATH)
	assert_true(instantiated.get("ok", false), "DesktopBoardFatePort.gd must instantiate")


# ---- configuration ----

func test_configure_publication_ledger_is_idempotent_on_identical_replay() -> void:
	var port := PORT.new()
	var ledger: Object = PUBLICATION_LEDGER.new()
	port.configure_publication_ledger(ledger)
	var replay := port.configure_publication_ledger(ledger)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(replay["value"]["already_configured"])


func test_configure_publication_ledger_rejects_replacement() -> void:
	var port := PORT.new()
	port.configure_publication_ledger(PUBLICATION_LEDGER.new())
	var result := port.configure_publication_ledger(PUBLICATION_LEDGER.new())
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"publication_ledger_already_configured")


func test_configure_rejects_before_publication_ledger_configured() -> void:
	var port := PORT.new()
	var result := port.configure(BOARD_STATE.new(), _issuer)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"publication_ledger_not_configured")


func test_configure_is_idempotent_on_identical_replay() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var replay: Dictionary = port.configure(_coordinator._board_state, _issuer)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(replay["value"]["already_configured"])


func test_configure_rejects_a_replacement_board_state() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var result: Dictionary = port.configure(BOARD_STATE.new(), _issuer)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_port_already_configured")


func test_configure_rejects_an_invalid_board_state() -> void:
	var port := PORT.new()
	port.configure_publication_ledger(PUBLICATION_LEDGER.new())
	var result: Dictionary = port.configure(RefCounted.new(), _issuer)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"invalid_board_state")


# ---- prepare_causal_departure(): reason=schedule_done, derives fate from the live board ----

func test_prepare_causal_departure_from_none_yields_fate_none() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var live: Dictionary = _coordinator._board_state.capture()
	assert_eq(live["phase"], "NONE")
	var result: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	assert_true(result.get("ok", false), JSON.stringify(result))
	var receipt: Dictionary = result["value"]["board_fate_receipt"]
	assert_eq(receipt["fate"], "none")
	assert_null(receipt["board_identity"])
	assert_eq(receipt["board_revision"], -1)
	assert_null(receipt["source_action_commit_receipt_id"])
	assert_eq(result["value"]["board_candidate"], live)


func test_prepare_causal_departure_from_preparing_yields_discarded_unstarted() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	assert_eq(live["phase"], "PREPARING")
	var result: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	assert_true(result.get("ok", false), JSON.stringify(result))
	var receipt: Dictionary = result["value"]["board_fate_receipt"]
	assert_eq(receipt["fate"], "discarded_unstarted")
	assert_eq(receipt["board_identity"], live["identity"])
	assert_eq(receipt["board_revision"], live["revision"])
	var candidate: Dictionary = result["value"]["board_candidate"]
	assert_eq(candidate["phase"], "NONE")
	assert_null(candidate["identity"])
	assert_eq(candidate["terminal_receipts"].size(), 1)


func test_prepare_causal_departure_from_active_visible_yields_forfeited_started() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	_reveal_first(_next_tx(), "beginner", 0)
	var live: Dictionary = _coordinator._board_state.capture()
	assert_eq(live["phase"], "ACTIVE_VISIBLE")
	var result: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	assert_true(result.get("ok", false), JSON.stringify(result))
	var receipt: Dictionary = result["value"]["board_fate_receipt"]
	assert_eq(receipt["fate"], "forfeited_started")
	var candidate: Dictionary = result["value"]["board_candidate"]
	assert_eq(candidate["phase"], "NONE")
	assert_null(candidate["board"])


func test_prepare_causal_departure_rejects_a_non_schedule_reason() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var live: Dictionary = _coordinator._board_state.capture()
	var request := _schedule_request(_next_tx(), live)
	request["reason"] = "bogus_reason"
	var result: Dictionary = port.prepare_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_reason_invalid")


func test_prepare_causal_departure_rejects_stale_revision() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var live: Dictionary = _coordinator._board_state.capture()
	var request := _schedule_request(_next_tx(), live)
	request["expected_board_revision"] = int(live["revision"]) + 5
	var result: Dictionary = port.prepare_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_stale_revision")


func test_prepare_causal_departure_rejects_identity_mismatch() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	var request := _schedule_request(_next_tx(), live)
	request["expected_board_identity"] = {"run_id": "someone-else", "branch_id": "b", "desktop_timeline_generation": 0,
		"causal_day_instance": "d", "app_round_ordinal": 1}
	var result: Dictionary = port.prepare_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_identity_mismatch")


func test_prepare_causal_departure_duplicate_replay_returns_identical_result() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var live: Dictionary = _coordinator._board_state.capture()
	var request := _schedule_request(_next_tx(), live)
	var first: Dictionary = port.prepare_causal_departure(request)
	var replay: Dictionary = port.prepare_causal_departure(request)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay, first)


func test_prepare_causal_departure_changed_request_at_same_command_id_conflicts() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var live: Dictionary = _coordinator._board_state.capture()
	var command_id := _next_tx()
	var request := _schedule_request(command_id, live)
	port.prepare_causal_departure(request)
	var changed := request.duplicate(true)
	changed["causal_day_instance"] = "a-different-day"
	var result: Dictionary = port.prepare_causal_departure(changed)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_conflict")


func test_prepare_causal_departure_from_settling_is_rejected() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	_reveal_first(_next_tx(), "beginner", 0)
	# Force the forced-safe cell layout's only mine (index 1) to explode via a routine reveal, making
	# the live board terminal, then settle it directly through DesktopBoardState's own seam.
	var board_state = _coordinator._board_state
	var settle_tx := _next_tx()
	var reduced := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd").reveal(
		((board_state.capture()["board"] as Dictionary)["board"] as Dictionary), 1, settle_tx)
	assert_true(reduced.get("ok", false), JSON.stringify(reduced))
	var live_before: Dictionary = board_state.capture()
	var prepared := board_state.prepare_board_command({
		"transaction_id": settle_tx, "identity": live_before["identity"], "expected_revision": live_before["revision"],
		"kind": &"reveal", "cell_index": 1, "request_fingerprint": "fp-settle",
	}, reduced["value"]["board"])
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	board_state.commit(prepared["value"]["candidate"])
	var terminal_live: Dictionary = board_state.capture()
	assert_true((terminal_live["board"] as Dictionary)["board"]["terminal"])

	var settlement_tx := _next_tx()
	var settlement_prepared := board_state.prepare_settlement({
		"transaction_id": settlement_tx, "identity": terminal_live["identity"], "expected_revision": terminal_live["revision"],
		"request_fingerprint": "fp-settlement",
	}, {"outcome": "exploded"})
	assert_true(settlement_prepared.get("ok", false), JSON.stringify(settlement_prepared))
	board_state.commit(settlement_prepared["value"]["candidate"])
	assert_eq(board_state.capture()["phase"], "SETTLING")

	var settling_live: Dictionary = board_state.capture()
	var result: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), settling_live))
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_settling_not_resumable")


# ---- prepare_projected_causal_departure(): reason=condition_departure ----

func test_prepare_projected_departure_minesweeper_round_none_projection_yields_fate_none() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var command_id := _next_tx()
	var action_receipt := _source_action_receipt(command_id, "minesweeper_round")
	var live: Dictionary = _coordinator._board_state.capture()
	assert_eq(live["phase"], "NONE")
	# A minesweeper_round projection is exactly the source's own already-NONE post-completion board.
	var request := _projected_request(command_id, action_receipt, live, live)
	var result: Dictionary = port.prepare_projected_causal_departure(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var receipt: Dictionary = result["value"]["board_fate_receipt"]
	assert_eq(receipt["fate"], "none")
	assert_eq(receipt["source_action_commit_receipt_id"], action_receipt["commit_receipt_id"])


func test_prepare_projected_departure_rejects_a_nonterminal_minesweeper_round_projection() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var command_id := _next_tx()
	var action_receipt := _source_action_receipt(command_id, "minesweeper_round")
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	assert_eq(live["phase"], "PREPARING")
	var request := _projected_request(command_id, action_receipt, live, live)
	var result: Dictionary = port.prepare_projected_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_projection_invalid")


func test_prepare_projected_departure_shop_purchase_applies_ordinary_current_board_fate() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var command_id := _next_tx()
	var action_receipt := _source_action_receipt(command_id, "shop_purchase")
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	assert_eq(live["phase"], "PREPARING")
	# Shop never touches the board: the projection is byte-equal to the current board.
	var request := _projected_request(command_id, action_receipt, live, live)
	var result: Dictionary = port.prepare_projected_causal_departure(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var receipt: Dictionary = result["value"]["board_fate_receipt"]
	assert_eq(receipt["fate"], "discarded_unstarted")
	assert_eq(receipt["source_action_commit_receipt_id"], action_receipt["commit_receipt_id"])


func test_prepare_projected_departure_rejects_a_shop_projection_that_diverges_from_current_board() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var command_id := _next_tx()
	var action_receipt := _source_action_receipt(command_id, "shop_purchase")
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	var stale_projection: Dictionary = live.duplicate(true)
	stale_projection["revision"] = int(live["revision"]) + 1
	var request := _projected_request(command_id, action_receipt, stale_projection, live)
	var result: Dictionary = port.prepare_projected_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_projection_invalid")


func test_prepare_projected_departure_rejects_a_changed_projection_hash() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var command_id := _next_tx()
	var action_receipt := _source_action_receipt(command_id, "minesweeper_round")
	var live: Dictionary = _coordinator._board_state.capture()
	var request := _projected_request(command_id, action_receipt, live, live)
	request["projected_board_candidate_sha256"] = "0".repeat(64)
	var result: Dictionary = port.prepare_projected_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_projection_hash_mismatch")


func test_prepare_projected_departure_rejects_an_action_receipt_transaction_mismatch() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var command_id := _next_tx()
	var other_command_id := _next_tx()
	var action_receipt := _source_action_receipt(other_command_id, "minesweeper_round")
	var live: Dictionary = _coordinator._board_state.capture()
	var request := _projected_request(command_id, action_receipt, live, live)
	# command_issuer_receipt must be re-pinned to the (mismatched) action's own root for this probe;
	# the transaction_id mismatch itself is the property under test.
	request["command_issuer_receipt"] = action_receipt["transaction_issuer_receipt"]
	var result: Dictionary = port.prepare_projected_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_action_mismatch")


func test_prepare_projected_departure_rejects_stale_pre_state() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var command_id := _next_tx()
	var action_receipt := _source_action_receipt(command_id, "minesweeper_round")
	var live: Dictionary = _coordinator._board_state.capture()
	var request := _projected_request(command_id, action_receipt, live, live)
	request["expected_board_revision"] = int(live["revision"]) + 9
	var result: Dictionary = port.prepare_projected_causal_departure(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_stale_revision")


# ---- capture / commit / rollback / publish round trips ----

func test_commit_adopts_the_fate_none_candidate_and_publish_records_once() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var ledger: CountingPublicationLedger = wired["ledger"]
	var live: Dictionary = _coordinator._board_state.capture()
	var prepared: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	var board_candidate: Dictionary = prepared["value"]["board_candidate"]
	var board_fate_receipt: Dictionary = prepared["value"]["board_fate_receipt"]

	var backup: Dictionary = port.capture()["value"]["backup"]
	var committed: Dictionary = port.commit(board_candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["board_candidate"], board_candidate)
	assert_eq(committed["receipt"], board_fate_receipt)
	assert_eq(_coordinator._board_state.capture()["phase"], "NONE")

	var replay: Dictionary = port.commit(board_candidate)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay, committed)

	var published: Dictionary = port.publish({"board_candidate": board_candidate, "board_fate_receipt": board_fate_receipt})
	assert_true(published.get("ok", false), JSON.stringify(published))
	assert_eq(published["value"]["published"], true)
	assert_eq(published["receipt"], board_fate_receipt)
	assert_eq(ledger.record_calls, 1)

	var republish: Dictionary = port.publish({"board_candidate": board_candidate, "board_fate_receipt": board_fate_receipt})
	assert_true(republish.get("ok", false), JSON.stringify(republish))
	assert_eq(ledger.record_calls, 2, "record_before_emit is still called, but its own replay stays a no-op")
	assert_eq(_ledger_records(ledger).size(), 1, "no second distinct ledger record is created")

	# Rollback is forbidden once admitted.
	var rollback_result: Dictionary = port.rollback(backup)
	assert_false(rollback_result.get("ok", false))
	assert_eq(rollback_result.get("code"), &"board_fate_rollback_forbidden")


func test_commit_adopts_a_discard_and_rollback_restores_pre_commit() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	var prepared: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	var board_candidate: Dictionary = prepared["value"]["board_candidate"]

	var backup: Dictionary = port.capture()["value"]["backup"]
	assert_eq(backup, live)
	var rolled_back: Dictionary = port.rollback(backup)
	assert_true(rolled_back.get("ok", false), JSON.stringify(rolled_back))
	assert_eq(_coordinator._board_state.capture(), live, "rollback before commit is a genuine no-op restore")

	var committed: Dictionary = port.commit(board_candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(_coordinator._board_state.capture()["phase"], "NONE")
	assert_eq(_coordinator._board_state.capture()["terminal_receipts"].size(), 1)


func test_commit_rejects_a_wrapped_candidate() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	var prepared: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	var board_candidate: Dictionary = prepared["value"]["board_candidate"]
	var wrapped := {"board_candidate": board_candidate}
	var result: Dictionary = port.commit(wrapped)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"invalid_candidate")


func test_rollback_rejects_an_unknown_backup() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var result: Dictionary = port.rollback({"schema_version": 1, "phase": "NONE", "revision": 999,
		"identity": null, "candidate": null, "board": null, "settlement": null,
		"command_receipts": {}, "terminal_receipts": {}})
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_backup_unknown")


func test_publish_rejects_changed_receipt_bytes() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var live: Dictionary = _coordinator._board_state.capture()
	var prepared: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	var board_candidate: Dictionary = prepared["value"]["board_candidate"]
	var board_fate_receipt: Dictionary = prepared["value"]["board_fate_receipt"]
	port.commit(board_candidate)
	var tampered: Dictionary = board_fate_receipt.duplicate(true)
	tampered["fate"] = "forfeited_started"
	var result: Dictionary = port.publish({"board_candidate": board_candidate, "board_fate_receipt": tampered})
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_conflict")


func test_publish_rejects_a_candidate_not_yet_committed() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var live: Dictionary = _coordinator._board_state.capture()
	var prepared: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	var result: Dictionary = port.publish({
		"board_candidate": prepared["value"]["board_candidate"], "board_fate_receipt": prepared["value"]["board_fate_receipt"],
	})
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"board_fate_conflict")


func test_board_fate_receipt_provenance_validates_against_the_issuer() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	_begin_debug(_next_tx(), "beginner")
	var live: Dictionary = _coordinator._board_state.capture()
	var result: Dictionary = port.prepare_causal_departure(_schedule_request(_next_tx(), live))
	var receipt: Dictionary = result["value"]["board_fate_receipt"]
	var validated := _issuer.validate_child(receipt["receipt_provenance"], &"board_fate")
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	assert_eq(receipt["receipt_id"], receipt["receipt_provenance"]["child_id"])
