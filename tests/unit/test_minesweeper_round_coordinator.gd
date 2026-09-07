extends "res://addons/gut/test.gd"
# Behavioral RED/GREEN contract tests for the Task-5 application-level MinesweeperRoundCoordinator
# (Plan 02 Task 5, dwm-p2r.32). Preloaded by path throughout: this file has NO class_name (the
# global name is owned by the frozen, retained scripts/domain/minesweeper/
# MinesweeperRoundCoordinator.gd), and its own dependencies were never through an editor import
# pass either -- this repo's established answer (see test_desktop_identity_nonce_issuer.gd).
#
# The coordinator is proven here entirely against contract fakes: FakeDesktopBoardStatePort,
# FakeMinesweeperCheckpointPort, FakeMinesweeperGenerationPort, and a REAL DesktopIdentityNonceIssuer
# configured over FakeDesktopIssuerRootStore (this repo's own established issuer test double,
# reused per the task's instruction rather than inventing a fake issuer).

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const COORDINATOR_PATH := "res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd"
const STATE_PORT := preload("res://tests/support/FakeDesktopBoardStatePort.gd")
const CHECKPOINT_PORT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION_PORT := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const CONSEQUENCE_CHECKPOINT_PORT := preload("res://tests/support/FakeDesktopConsequenceCheckpointPort.gd")
const ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const FIRST_REVEAL_COMPOSER := preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd")


class DurableCheckpointWithoutSeal:
	func capture() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"backup": {}}, "receipt": {}}

	func preview_checkpoint_id(_run_id: String) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"checkpoint_id": "unused"}, "receipt": {}}

	func prepare_checkpoint(_snapshot: Dictionary, _kind: StringName, _disk_write: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"unused", "message": "", "details": {}}

	func commit_checkpoint(_candidate: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"unused", "message": "", "details": {}}

	func rollback(_backup: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

## Task 8 (dwm-p2r.32) contract fake for DesktopConsequenceCoordinator's own
## accept_prepared_action() -- this file proves complete_round()'s OWN contract (request shape,
## board-fate-neutral checkpointing, delegation), not the full causal admission pipeline, which is
## test_desktop_consequence_coordinator.gd's and the Task-8 integration suite's own territory.
class FakeConsequencePort:
	var calls: Array[Dictionary] = []
	var armed_result: Dictionary = {}

	func accept_prepared_action(request: Dictionary) -> Dictionary:
		calls.append(request.duplicate(true))
		if not armed_result.is_empty():
			return (armed_result as Dictionary).duplicate(true)
		return {"ok": true, "code": &"action_consequence_accepted",
			"value": {"action_receipt": request["action_receipt"], "source_kind": "minesweeper_round", "departure": false},
			"receipt": {}}

## dwm-p2r.35.7 remediation (finding 3): minimal fake for publish_recovery_action()'s own
## record_before_emit() call, mirroring test_minesweeper_shop_purchase_participant.gd's own
## established _FakePublicationLedger exactly.
class FakePublicationLedger:
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


const RECEIPT_KEYS: Array[String] = [
	"receipt_id", "receipt_provenance", "transaction_id", "transaction_issuer_receipt",
	"identity", "difficulty_id", "first_cell", "board_revision", "rounds_before", "rounds_after",
	"motivation_before", "motivation_after", "layout_sha256", "proof_sha256", "checkpoint_id",
]

var _coordinator: COORDINATOR
var _state_port: STATE_PORT
var _checkpoint_port: CHECKPOINT_PORT
var _generation_port: GENERATION_PORT
var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER
var _consequence_state: RefCounted
var _consequence_checkpoint_port: CONSEQUENCE_CHECKPOINT_PORT
var _consequence_gate: ApplicationMutationGate
var _consequence_port: FakeConsequencePort


func before_each() -> void:
	_coordinator = COORDINATOR.new()
	_state_port = STATE_PORT.new()
	_checkpoint_port = CHECKPOINT_PORT.new()
	_generation_port = GENERATION_PORT.new()
	_root_store = FAKE_ROOT_STORE.new("22".repeat(32), 1)
	_issuer = ISSUER.new()
	_issuer.configure(_root_store)
	_state_port.identity_issuer = _issuer
	_generation_port.arm_materialize(_layout())
	var configured := _coordinator.configure(_state_port, _checkpoint_port, _generation_port, _issuer)
	assert_true(configured.get("ok", false), "configure() must succeed in before_each: %s" % configured)

	_consequence_state = _bootstrap_consequence_state("causal-day-1")
	_consequence_checkpoint_port = CONSEQUENCE_CHECKPOINT_PORT.new()
	_consequence_gate = ApplicationMutationGate.new()
	_consequence_port = FakeConsequencePort.new()
	var consequence_configured := _coordinator.configure_consequence_port(_consequence_port, _consequence_gate)
	assert_true(consequence_configured.get("ok", false), JSON.stringify(consequence_configured))
	var checkpoint_configured := _coordinator.configure_consequence_checkpoint(_consequence_state, _consequence_checkpoint_port)
	assert_true(checkpoint_configured.get("ok", false), JSON.stringify(checkpoint_configured))


func test_base_configure_accepts_the_same_durable_port_without_legacy_seal() -> void:
	var fresh := COORDINATOR.new()
	var durable := DurableCheckpointWithoutSeal.new()
	var consequence := CONSEQUENCE_STATE.new()
	var durable_configured: Dictionary = fresh.configure_durable_checkpoint(
		durable, FIRST_REVEAL_COMPOSER, consequence)
	assert_true(durable_configured.get("ok", false), JSON.stringify(durable_configured))
	var configured: Dictionary = fresh.configure(_state_port, durable, _generation_port, _issuer)
	assert_true(configured.get("ok", false), JSON.stringify(configured))

func _bootstrap_consequence_state(causal_day_instance: String) -> RefCounted:
	var state := CONSEQUENCE_STATE.new()
	var receipt: Dictionary = _root_store.mint(&"causal_day_instance").duplicate(true)
	receipt["token"] = causal_day_instance
	var made: Dictionary = CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": causal_day_instance, "causal_day_instance_issuer_receipt": receipt,
	})
	assert_true(made.get("ok", false), JSON.stringify(made))
	var prepared: Dictionary = state.prepare_restore((made["value"] as Dictionary)["state"])
	state.commit((prepared["value"] as Dictionary)["candidate"])
	return state


## Drives a fresh round to a terminal EXPLODED board: reveal safely at cell 0, then reveal the known
## mine at cell 1 (the fixed _layout() below always places its one mine there).
func _explode_a_fresh_round() -> Dictionary:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	var reveal_result := _reveal_first(_next_tx(), "beginner", 0)
	assert_true(reveal_result.get("ok", false), JSON.stringify(reveal_result))
	var live: Dictionary = _coordinator.get_state()["value"]
	var explode_request := _cell_request_with_real_transaction(live["identity"], live["revision"], 1)
	var exploded := _coordinator.reveal(explode_request)
	assert_true(exploded.get("ok", false), JSON.stringify(exploded))
	assert_true(_coordinator.get_state()["value"]["board"]["board"]["terminal"])
	return identity


func _complete_round_request(transaction_id: String) -> Dictionary:
	return {
		"transaction_id": transaction_id, "transaction_issuer_receipt": _issue_transaction_receipt_for(transaction_id),
		"expected_identity": _coordinator.get_state()["value"]["identity"],
		"expected_revision": int(_coordinator.get_state()["value"]["revision"]),
	}


# ---- complete_round() (Plan 02 Task 8, dwm-p2r.32) ----

func test_configure_consequence_port_rejects_before_it_is_configured() -> void:
	var fresh := COORDINATOR.new()
	fresh.configure(STATE_PORT.new(), CHECKPOINT_PORT.new(), GENERATION_PORT.new(), _issuer)
	var result: Dictionary = fresh.complete_round(_complete_round_request(_next_tx()))
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"consequence_port_not_configured")


func test_configure_consequence_checkpoint_rejects_an_invalid_state_port() -> void:
	var fresh := COORDINATOR.new()
	fresh.configure(STATE_PORT.new(), CHECKPOINT_PORT.new(), GENERATION_PORT.new(), _issuer)
	fresh.configure_consequence_port(FakeConsequencePort.new(), ApplicationMutationGate.new())
	var result: Dictionary = fresh.configure_consequence_checkpoint(RefCounted.new(), CONSEQUENCE_CHECKPOINT_PORT.new())
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"invalid_consequence_state_port")


func test_complete_round_requires_a_terminal_board() -> void:
	_reveal_first(_next_tx(), "beginner", 0)
	assert_false(bool(_coordinator.get_state()["value"]["board"]["board"]["terminal"]))
	var result: Dictionary = _coordinator.complete_round(_complete_round_request(_next_tx()))
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"complete_round_requires_terminal_board")


func test_complete_round_delegates_to_accept_prepared_action_with_a_valid_receipt() -> void:
	_explode_a_fresh_round()
	var tx := _next_tx()
	var result: Dictionary = _coordinator.complete_round(_complete_round_request(tx))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(_consequence_port.calls.size(), 1)
	var call: Dictionary = _consequence_port.calls[0]
	var validated := ACTION_RECEIPT.validate(call["action_receipt"])
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	assert_eq(str(call["action_receipt"]["action_kind"]), "minesweeper_round")
	assert_eq(str(call["action_receipt"]["commit_receipt_id"]), str(call["action_receipt"]["action_id"]),
		"Ruling B: commit_receipt_id reuses action_id byte-for-byte")
	assert_eq(str((call["action_candidate"] as Dictionary)["outcome"]), "exploded")
	assert_eq(str(((call["action_candidate"] as Dictionary)["board_projection"] as Dictionary)["phase"]), "NONE")
	assert_true((call["prepared_checkpoint_receipt"] as Dictionary).size() > 0)


func test_complete_round_never_changes_live_board_truth_even_when_delegation_fails() -> void:
	_explode_a_fresh_round()
	# complete_round() itself never adopts the board_projection -- that is commit_recovery_action()'s
	# own, later job. Proven here by forcing accept_prepared_action() to fail: the board must stay
	# exactly the terminal ACTIVE_VISIBLE state complete_round() found it in.
	_consequence_port.armed_result = {"ok": false, "code": &"forced_test_failure", "message": "", "details": {}}
	var before: Dictionary = _coordinator.get_state()["value"]
	var result: Dictionary = _coordinator.complete_round(_complete_round_request(_next_tx()))
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"forced_test_failure")
	var after: Dictionary = _coordinator.get_state()["value"]
	assert_eq(after["phase"], "ACTIVE_VISIBLE")
	assert_eq(after, before, "the board must be byte-identical to its pre-delegation state")


func test_complete_round_duplicate_replay_returns_identical_result() -> void:
	_explode_a_fresh_round()
	var tx := _next_tx()
	var request := _complete_round_request(tx)
	var first: Dictionary = _coordinator.complete_round(request)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var replay: Dictionary = _coordinator.complete_round(request)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay, first)
	assert_eq(_consequence_port.calls.size(), 1, "a duplicate replay never calls accept_prepared_action again")


## dwm-p2r.35.7 remediation (finding 2): complete_round() used to cache EVERY accept_prepared_action()
## result in _round_completions unconditionally, including failures -- freezing a transient failure
## forever even though the ordinal-0 checkpoint and pending record were already durable, with no
## forward path and no retry path. Proves a retry with the SAME request after a transient failure
## genuinely re-drives accept_prepared_action() (via the new _recognize_live_round_pending() -- see
## finding 1) and succeeds, rather than replaying the cached failure.
func test_complete_round_retries_after_a_transient_accept_prepared_action_failure() -> void:
	_explode_a_fresh_round()
	var tx := _next_tx()
	var request := _complete_round_request(tx)

	_consequence_port.armed_result = {"ok": false, "code": &"forced_test_failure", "message": "", "details": {}}
	var first: Dictionary = _coordinator.complete_round(request)
	assert_false(first.get("ok", false))
	assert_eq(first.get("code"), &"forced_test_failure")
	# The failure must NOT be cached: a byte-identical retry must not replay it.
	assert_eq(_consequence_port.calls.size(), 1)

	_consequence_port.armed_result = {}
	var retried: Dictionary = _coordinator.complete_round(request)
	assert_true(retried.get("ok", false), JSON.stringify(retried))
	assert_eq(retried.get("code"), &"action_consequence_accepted")
	assert_eq(_consequence_port.calls.size(), 2, "the retry genuinely re-drove accept_prepared_action, not a cached replay")

	# The success IS now cached: a further identical call replays it without a third call.
	var third: Dictionary = _coordinator.complete_round(request)
	assert_eq(third, retried)
	assert_eq(_consequence_port.calls.size(), 2, "a successful result replays from cache, not a third live call")


## dwm-p2r.35.7 remediation (finding 1): plan02-frozen-contracts.md line 2271 -- when
## accept_prepared_action() abandons a pre-admission pending because the condition-departure ports
## are unconfigured, complete_round() -- the actual causal_transaction token holder, since
## DesktopConsequenceCoordinator never acquires the lease itself -- releases it, completing the
## frozen law's "releases causal_transaction". Also proves the abandoned pending is cleared so a
## fresh complete_round() call for a NEW transaction can proceed (the deadlock this finding fixes).
func test_complete_round_releases_the_gate_when_accept_prepared_action_abandons_a_pre_admission_pending() -> void:
	_explode_a_fresh_round()
	_consequence_port.armed_result = {"ok": false, "code": &"condition_departure_ports_unconfigured", "message": "", "details": {}}
	var tx := _next_tx()
	var blocked: Dictionary = _coordinator.complete_round(_complete_round_request(tx))
	assert_false(blocked.get("ok", false))
	assert_eq(blocked.get("code"), &"condition_departure_ports_unconfigured")
	assert_false(_consequence_gate.is_active(), "the lease must be released, not left stranded, on abandonment")

	# A later retry of the SAME transaction is not stuck forever either -- the failure was not cached.
	_consequence_port.armed_result = {}
	var retried: Dictionary = _coordinator.complete_round(_complete_round_request(tx))
	assert_true(retried.get("ok", false), JSON.stringify(retried))


func test_commit_recovery_action_adopts_the_board_projection_and_rejects_without_the_gate() -> void:
	var identity := _explode_a_fresh_round()
	var tx := _next_tx()
	var board_projection := {
		"schema_version": 1, "phase": "NONE", "revision": int(_coordinator.get_state()["value"]["revision"]) + 1,
		"identity": null, "candidate": null, "board": null, "settlement": null,
		"command_receipts": (_coordinator.get_state()["value"]["command_receipts"] as Dictionary).duplicate(true),
		"terminal_receipts": {},
	}
	var action_candidate := {"transaction_id": tx, "outcome": "exploded", "identity": identity, "board_projection": board_projection}
	var action_receipt := _minimal_round_action_receipt(tx, identity)

	var without_gate: Dictionary = _coordinator.commit_recovery_action(action_candidate, action_receipt)
	assert_false(without_gate.get("ok", false))
	assert_eq(without_gate.get("code"), &"causal_transaction_lease_required")

	var acquired: Dictionary = _consequence_gate.acquire(&"causal_transaction")
	assert_true(acquired.get("ok", false))
	var committed: Dictionary = _coordinator.commit_recovery_action(action_candidate, action_receipt)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE")


## dwm-p2r.35.7 remediation (finding 3): publish_recovery_action() used to release the causal_
## transaction lease itself, immediately after recording -- callback index 1 of up to 3 in
## DesktopConsequenceCoordinator's own departure publication plan -- leaving board-fate publish and
## terminal cleanup running unleased. Proves the lease survives publish_recovery_action() and is
## released only by the new release_recovery_lease() (which DesktopConsequenceCoordinator now calls
## after terminal cleanup). complete_round() is the real production path that populates this
## coordinator's own _consequence_gate_token (never reached into directly here) -- armed to succeed
## trivially so the gate is genuinely acquired the same way production acquires it.
func test_publish_recovery_action_retains_the_gate_until_release_recovery_lease() -> void:
	_explode_a_fresh_round()
	var tx := _next_tx()
	var completed: Dictionary = _coordinator.complete_round(_complete_round_request(tx))
	assert_true(completed.get("ok", false), JSON.stringify(completed))
	assert_true(_consequence_gate.is_internal_owner_active(&"causal_transaction"))

	var identity: Dictionary = {"run_id": "run-fake", "branch_id": "branch-fake",
		"desktop_timeline_generation": 0, "causal_day_instance": "causal-day-1"}
	var action_receipt := _minimal_round_action_receipt(tx, identity)
	var publication_ledger := FakePublicationLedger.new()
	assert_true(_coordinator.configure_publication_ledger(publication_ledger).get("ok", false))

	var validated := _coordinator.validate_recovery_action({"transaction_id": tx}, action_receipt)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	var published: Dictionary = _coordinator.publish_recovery_action((validated["value"] as Dictionary)["publication"])
	assert_true(published.get("ok", false), JSON.stringify(published))
	assert_true(_consequence_gate.is_internal_owner_active(&"causal_transaction"),
		"publish_recovery_action retains the lease -- release_recovery_lease() is the sole release point")

	var released: Dictionary = _coordinator.release_recovery_lease()
	assert_true(released.get("ok", false), JSON.stringify(released))
	assert_false(_consequence_gate.is_active(), "release_recovery_lease() releases the lease")
	var idempotent_release: Dictionary = _coordinator.release_recovery_lease()
	assert_true(idempotent_release.get("ok", false), JSON.stringify(idempotent_release))


func _minimal_round_action_receipt(transaction_id: String, identity: Dictionary) -> Dictionary:
	var receipt_txn := _issue_transaction_receipt_for(transaction_id)
	var derived: Dictionary = _issuer.derive_child({
		"child_kind": "desktop_action", "ordinal": 0, "parent_receipt_id": str(receipt_txn["receipt_id"]),
		"source_ids": ["round-source"],
	})
	var action_id := str(derived["value"]["child_id"])
	var provenance: Dictionary = derived["value"]["provenance"]
	return {
		"schema_version": 1, "action_kind": "minesweeper_round", "run_id": str(identity["run_id"]),
		"branch_id": str(identity["branch_id"]), "desktop_timeline_generation": int(identity["desktop_timeline_generation"]),
		"causal_day_instance": str(identity["causal_day_instance"]), "day": 1,
		"transaction_id": transaction_id, "transaction_issuer_receipt": receipt_txn,
		"source_commit_receipt_id": "board_start.fake", "source_commit_receipt_provenance": {},
		"condition_before": {"health": 0, "pressure": 0, "carried_sequela": false},
		"condition_after": {"health": 0, "pressure": 0, "carried_sequela": false}, "unlock_receipt_ids": [],
		"action_id": action_id, "action_id_provenance": provenance,
		"commit_receipt_id": action_id, "commit_receipt_provenance": provenance.duplicate(true),
	}


# ---- Step 5.1 parse proof ----

func test_coordinator_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(COORDINATOR_PATH)
	assert_true(loaded.get("ok", false), "MinesweeperRoundCoordinator.gd must load")


func test_coordinator_instantiates() -> void:
	var instantiated: Dictionary = PROBE.instantiate(COORDINATOR_PATH)
	assert_true(instantiated.get("ok", false), "MinesweeperRoundCoordinator.gd must instantiate")


# ---- configure() ----

func test_configure_is_idempotent_on_identical_replay() -> void:
	var replay := _coordinator.configure(_state_port, _checkpoint_port, _generation_port, _issuer)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(replay["value"]["already_configured"])


func test_configure_rejects_a_replacement_port() -> void:
	var other := STATE_PORT.new()
	var result := _coordinator.configure(other, _checkpoint_port, _generation_port, _issuer)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"minesweeper_round_coordinator_already_configured")


func test_configure_rejects_a_port_missing_required_methods() -> void:
	var fresh := COORDINATOR.new()
	var result := fresh.configure(RefCounted.new(), _checkpoint_port, _generation_port, _issuer)
	assert_false(result.get("ok", false))
	assert_ne(result.get("code"), &"not_implemented")


# ---- get_entry_context() ----

func test_get_entry_context_is_eligible_from_fresh_none_phase() -> void:
	var context := _coordinator.get_entry_context("beginner")
	assert_true(context.get("ok", false), JSON.stringify(context))
	var value: Dictionary = context["value"]
	assert_true(value["eligible"])
	assert_eq(value["identity"]["app_round_ordinal"], 1)
	assert_eq(value["revision"], 0)
	assert_eq(value["difficulty_id"], "beginner")


func test_get_entry_context_is_not_eligible_when_motivation_exhausted() -> void:
	_state_port.motivation = 0
	var context := _coordinator.get_entry_context("beginner")
	assert_true(context.get("ok", false))
	assert_false(context["value"]["eligible"])


func test_get_entry_context_is_not_eligible_once_phase_leaves_none() -> void:
	_reveal_first(_next_tx(), "beginner", 0)
	var context := _coordinator.get_entry_context("beginner")
	assert_true(context.get("ok", false))
	assert_false(context["value"]["eligible"])
	assert_null(context["value"]["identity"])


# ---- Debug preparation: begin -> slice(progress) -> slice(certified) ----

func test_debug_preparation_reaches_prepared_unstarted() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	var tx1 := _next_tx()
	var begin_request := _debug_request(tx1, identity, 0, "beginner")
	var begun := _coordinator.begin_debug_preparation(begin_request)
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	assert_eq(begun["value"]["phase"], "PREPARING")

	_generation_port.arm_search_slices([
		{"done": false, "frontier": {"cursor": 1}},
		{"done": true, "layout": _layout(), "forced_cell": 0, "proof_sha256": "proof-abc"},
	])
	var tx2 := _next_tx()
	var progress := _coordinator.run_debug_preparation_slice(_generic_request(tx2, identity, 1))
	assert_true(progress.get("ok", false), JSON.stringify(progress))
	assert_eq(progress["value"]["phase"], "PREPARING")

	var tx3 := _next_tx()
	var certified := _coordinator.run_debug_preparation_slice(_generic_request(tx3, identity, 2))
	assert_true(certified.get("ok", false), JSON.stringify(certified))
	assert_eq(certified["value"]["phase"], "PREPARED_UNSTARTED")


# ---- first Reveal: Default/Lucky path from NONE ----

func test_first_reveal_from_none_produces_the_exact_frozen_receipt_shape() -> void:
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result.get("code"), &"first_reveal_committed")
	var receipt: Dictionary = result["value"]["receipt"]
	var keys: Array = receipt.keys()
	keys.sort()
	var expected := RECEIPT_KEYS.duplicate()
	expected.sort()
	assert_eq(keys, expected)
	assert_eq(receipt["first_cell"], 0)
	assert_eq(receipt["rounds_before"], 2)
	assert_eq(receipt["rounds_after"], 1)
	assert_eq(receipt["motivation_before"], 7)
	assert_eq(receipt["motivation_after"], 6)
	assert_null(receipt["proof_sha256"])


func test_first_reveal_charges_exactly_once_and_advances_ordinal() -> void:
	_reveal_first(_next_tx(), "beginner", 0)
	assert_eq(_state_port.motivation, 6)
	assert_eq(_state_port.rounds_left, 1)
	assert_eq(_state_port.next_ordinal, 2)
	assert_eq(_checkpoint_port.is_committed("run-fake:1"), true)
	assert_eq(_checkpoint_port.is_sealed("run-fake:1"), true)
	assert_eq(_state_port.published.size(), 1)


func test_first_reveal_receipt_provenance_validates_against_the_issuer() -> void:
	var result := _reveal_first(_next_tx(), "beginner", 0)
	var receipt: Dictionary = result["value"]["receipt"]
	var provenance: Dictionary = receipt["receipt_provenance"]
	var validated := _issuer.validate_child(provenance, &"board_start")
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	assert_eq(receipt["receipt_id"], provenance["child_id"],
		"receipt_id must be exactly the issuer-derived child_id")
	assert_eq(provenance["child_kind"], "board_start")
	assert_eq(provenance["ordinal"], 0)
	assert_eq(provenance["source_ids"], [receipt["transaction_id"]])


func test_first_reveal_receipt_provenance_rejects_a_tampered_member() -> void:
	var result := _reveal_first(_next_tx(), "beginner", 0)
	var receipt: Dictionary = result["value"]["receipt"]
	var tampered: Dictionary = (receipt["receipt_provenance"] as Dictionary).duplicate(true)
	tampered["ordinal"] = 1
	var validated := _issuer.validate_child(tampered, &"board_start")
	assert_false(validated.get("ok", false), "a mutated provenance member must fail issuer validation")
	assert_ne(validated.get("code"), &"not_implemented")


func test_default_and_lucky_remain_none_until_reveal() -> void:
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE")
	_reveal_first(_next_tx(), "beginner", 0)
	assert_eq(_coordinator.get_state()["value"]["phase"], "ACTIVE_VISIBLE")


# ---- first Reveal: Debug-adopted path from PREPARED_UNSTARTED ----

func test_first_reveal_adopts_a_certified_debug_candidate() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	_coordinator.begin_debug_preparation(_debug_request(_next_tx(), identity, 0, "beginner"))
	_generation_port.arm_search_slices([
		{"done": true, "layout": _layout(), "forced_cell": 0, "proof_sha256": "proof-xyz"},
	])
	_coordinator.run_debug_preparation_slice(_generic_request(_next_tx(), identity, 1))
	assert_eq(_coordinator.get_state()["value"]["phase"], "PREPARED_UNSTARTED")

	var request := _first_reveal_request(_next_tx(), identity, 2, "beginner", 0)
	var result := _coordinator.reveal(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["receipt"]["proof_sha256"], "proof-xyz")
	assert_eq(_coordinator.get_state()["value"]["phase"], "ACTIVE_VISIBLE")


func test_first_reveal_rejects_a_difficulty_id_that_does_not_match_the_certified_candidate() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	_coordinator.begin_debug_preparation(_debug_request(_next_tx(), identity, 0, "beginner"))
	_generation_port.arm_search_slices([
		{"done": true, "layout": _layout(), "forced_cell": 0, "proof_sha256": "proof-xyz"},
	])
	_coordinator.run_debug_preparation_slice(_generic_request(_next_tx(), identity, 1))
	assert_eq(_coordinator.get_state()["value"]["phase"], "PREPARED_UNSTARTED")

	# The candidate was certified for "beginner"; requesting first Reveal with a different
	# difficulty_id must be rejected before any mutation, and the board must stay unstarted.
	var mismatched := _first_reveal_request(_next_tx(), identity, 2, "expert", 0)
	var result := _coordinator.reveal(mismatched)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"difficulty_mismatch")
	assert_eq(_coordinator.get_state()["value"]["phase"], "PREPARED_UNSTARTED",
		"a rejected mismatch must not consume the certified candidate")
	assert_eq(_state_port.motivation, 7, "a rejected mismatch must charge nothing")


# ---- duplicate request equality / changed-payload conflict / stale / identity ----

func test_duplicate_first_reveal_replays_the_original_receipt_without_recharging() -> void:
	var tx := _next_tx()
	var first := _reveal_first(tx, "beginner", 0)
	var identity: Dictionary = first["value"]["receipt"]["identity"]
	var request := _first_reveal_request(tx, identity, 0, "beginner", 0)
	var replay := _coordinator.reveal(request)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay["value"]["receipt"], first["value"]["receipt"])
	assert_eq(_state_port.motivation, 6, "a duplicate retry must never charge again")
	assert_eq(_state_port.published.size(), 2, "the exact retry re-publishes idempotently")


func test_changed_payload_on_the_same_transaction_id_conflicts() -> void:
	var tx := _next_tx()
	_reveal_first(tx, "beginner", 0)
	var identity := _entry_identity_after_first_reveal()
	# Same transaction_id, different cell_index -- a changed request payload.
	var request := _first_reveal_request(tx, identity, 0, "beginner", 1)
	var result := _coordinator.reveal(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"transaction_conflict")


func test_stale_revision_is_rejected() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	var request := _first_reveal_request(_next_tx(), identity, 99, "beginner", 0)
	var result := _coordinator.reveal(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"stale_revision")


func test_identity_mismatch_is_rejected() -> void:
	var bad_identity := {
		"run_id": "someone-else", "branch_id": "branch-x", "desktop_timeline_generation": 0,
		"causal_day_instance": "day-x", "app_round_ordinal": 1,
	}
	var request := _first_reveal_request(_next_tx(), bad_identity, 0, "beginner", 0)
	var result := _coordinator.reveal(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"identity_mismatch")


func test_a_forged_transaction_receipt_is_rejected() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	var forged_receipt := {
		"receipt_id": "forged", "purpose": "transaction_id", "namespace": _root_store.namespace_hex,
		"counter": 0, "token": "tx-forged", "numeric_value": null,
	}
	var request := {
		"transaction_id": "tx-forged", "transaction_issuer_receipt": forged_receipt,
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner", "cell_index": 0,
	}
	var result := _coordinator.reveal(request)
	assert_false(result.get("ok", false))
	assert_ne(result.get("code"), &"not_implemented")


func test_a_receipt_whose_token_does_not_match_the_transaction_id_is_rejected() -> void:
	var identity: Dictionary = _coordinator.get_entry_context("beginner")["value"]["identity"]
	var issued := _issuer.issue(&"transaction_id")
	var real_receipt: Dictionary = issued["value"]["issuer_receipt"]
	var request := {
		"transaction_id": "not-the-real-token", "transaction_issuer_receipt": real_receipt,
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner", "cell_index": 0,
	}
	var result := _coordinator.reveal(request)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"transaction_id_receipt_mismatch")


# ---- Step 5.2: injected failures before/through seal roll back in reverse ----

func test_materialize_failure_charges_nothing() -> void:
	_generation_port.fail_next_materialize({"ok": false, "code": &"fake_materialize_failed", "message": "", "details": {}})
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_false(result.get("ok", false))
	assert_eq(_state_port.motivation, 7)
	assert_eq(_state_port.rounds_left, 2)
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE")


func test_checkpoint_prepare_failure_charges_nothing() -> void:
	_checkpoint_port.fail_next("prepare_checkpoint",
		{"ok": false, "code": &"fake_prepare_failed", "message": "", "details": {}})
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_false(result.get("ok", false))
	assert_eq(_state_port.motivation, 7)
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE")


func test_checkpoint_commit_failure_charges_nothing_and_needs_no_rollback() -> void:
	_checkpoint_port.fail_next("commit_checkpoint",
		{"ok": false, "code": &"fake_commit_failed", "message": "", "details": {}})
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_false(result.get("ok", false))
	assert_eq(_state_port.motivation, 7)
	assert_eq(_state_port.rounds_left, 2)
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE")


func test_state_commit_failure_rolls_back_the_already_committed_checkpoint() -> void:
	_state_port.fail_next("commit", {"ok": false, "code": &"fake_state_commit_failed", "message": "", "details": {}})
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_false(result.get("ok", false))
	assert_eq(_state_port.motivation, 7)
	assert_eq(_state_port.rounds_left, 2)
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE")
	assert_false(_checkpoint_port.is_committed("run-fake:1"), "the provisional checkpoint must be rolled back")


func test_seal_failure_rolls_back_board_state_and_state_port_and_checkpoint() -> void:
	_checkpoint_port.fail_next("seal_checkpoint",
		{"ok": false, "code": &"fake_seal_failed", "message": "", "details": {}})
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_false(result.get("ok", false))
	assert_eq(_state_port.motivation, 7, "motivation must be restored")
	assert_eq(_state_port.rounds_left, 2, "rounds must be restored")
	assert_eq(_coordinator.get_state()["value"]["phase"], "NONE", "the board must be restored to NONE")
	assert_false(_checkpoint_port.is_committed("run-fake:1"), "the checkpoint must be rolled back")


func test_seal_failure_leaves_the_ledger_without_a_recorded_transaction() -> void:
	_checkpoint_port.fail_next("seal_checkpoint",
		{"ok": false, "code": &"fake_seal_failed", "message": "", "details": {}})
	var tx := _next_tx()
	_reveal_first(tx, "beginner", 0)
	assert_false(_coordinator.get_state()["value"]["command_receipts"].has(tx),
		"a fully rolled-back attempt must not leave a replayable ledger entry")


func test_publish_failure_after_seal_returns_committed_unpublished_and_keeps_the_commit() -> void:
	_state_port.fail_next("publish", {"ok": false, "code": &"fake_publish_failed", "message": "", "details": {}})
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"FIRST_REVEAL_COMMITTED_UNPUBLISHED")
	assert_true((result["details"] as Dictionary).has("receipt"))
	assert_eq(_state_port.motivation, 6, "the commit already happened and is never rolled back after seal")
	assert_eq(_coordinator.get_state()["value"]["phase"], "ACTIVE_VISIBLE")
	assert_true(_checkpoint_port.is_sealed("run-fake:1"))


func test_retry_after_committed_unpublished_publishes_the_existing_receipt_and_never_recharges() -> void:
	_state_port.fail_next("publish", {"ok": false, "code": &"fake_publish_failed", "message": "", "details": {}})
	var tx := _next_tx()
	var failed := _reveal_first(tx, "beginner", 0)
	assert_eq(failed.get("code"), &"FIRST_REVEAL_COMMITTED_UNPUBLISHED")
	var receipt_before: Dictionary = failed["details"]["receipt"]
	var identity: Dictionary = receipt_before["identity"]

	var retry_request := _first_reveal_request(tx, identity, 0, "beginner", 0)
	var retried := _coordinator.reveal(retry_request)
	assert_true(retried.get("ok", false), JSON.stringify(retried))
	assert_eq(retried.get("code"), &"first_reveal_committed")
	assert_eq(retried["value"]["receipt"], receipt_before)
	assert_eq(_state_port.motivation, 6, "the retry must never charge a second time")
	assert_eq(_state_port.published.size(), 1)


func test_double_rollback_failure_latches_fatal_and_refuses_subsequent_calls() -> void:
	_state_port.fail_next("commit", {"ok": false, "code": &"fake_state_commit_failed", "message": "", "details": {}})
	_checkpoint_port.fail_next("rollback", {"ok": false, "code": &"fake_rollback_failed", "message": "", "details": {}})
	var result := _reveal_first(_next_tx(), "beginner", 0)
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"APPLICATION_FATAL")
	var next := _coordinator.get_entry_context("beginner")
	assert_false(next.get("ok", false))
	assert_eq(next.get("code"), &"APPLICATION_FATAL")


func test_checkpoint_port_reports_never_production() -> void:
	assert_false(_checkpoint_port.is_production())


# ---- routine commands: reveal/flag/chord/suspend/resume touch only DesktopBoardState ----

func test_routine_reveal_commits_a_new_board_revision_without_touching_the_other_ports() -> void:
	_reveal_first(_next_tx(), "beginner", 0)
	# The one call every public coordinator operation makes to the state port is the shared
	# guard_external() mutation-gate check (req.desktop.cross_app_actions' fatal-latch fence
	# applies uniformly); routine commands never reach any OTHER state-port or checkpoint-port
	# method beyond that.
	var before_state_calls := _state_port.call_log.size()
	var before_checkpoint_calls := _checkpoint_port.call_log.size()
	var identity: Dictionary = _entry_identity_after_first_reveal()
	var result := _coordinator.reveal(_cell_request_with_real_transaction(identity, 1, 2))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["revision"], 2)
	assert_eq(_state_port.call_log.size(), before_state_calls + 1,
		"a routine command calls only guard_external() on the state port")
	assert_eq(_state_port.call_log[_state_port.call_log.size() - 1]["method"], &"guard_external")
	assert_eq(_checkpoint_port.call_log.size(), before_checkpoint_calls, "routine commands never call the checkpoint port")


func test_suspend_then_resume_round_trips_through_the_coordinator() -> void:
	_reveal_first(_next_tx(), "beginner", 0)
	var identity: Dictionary = _entry_identity_after_first_reveal()
	var suspended := _coordinator.suspend(_generic_request(_next_tx(), identity, 1))
	assert_true(suspended.get("ok", false), JSON.stringify(suspended))
	assert_eq(suspended["value"]["phase"], "ACTIVE_SUSPENDED")
	var resumed := _coordinator.resume(_generic_request(_next_tx(), identity, 2))
	assert_true(resumed.get("ok", false), JSON.stringify(resumed))
	assert_eq(resumed["value"]["phase"], "ACTIVE_VISIBLE")


func test_set_flag_flags_a_hidden_cell() -> void:
	_reveal_first(_next_tx(), "beginner", 0)
	var identity: Dictionary = _entry_identity_after_first_reveal()
	var request := {
		"transaction_id": _next_tx(), "transaction_issuer_receipt": {},
		"expected_identity": identity, "expected_revision": 1, "cell_index": 1, "flagged": true,
	}
	request["transaction_issuer_receipt"] = _issue_transaction_receipt_for(str(request["transaction_id"]))
	var result := _coordinator.set_flag(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var board: Dictionary = (result["value"]["board"] as Dictionary)["board"]
	assert_true((board["flagged_indices"] as Array).has(1))


# ---- KNOWN UPSTREAM EDGE: duplicate terminal-causing reveal must not reach the reducer ----

func test_duplicate_terminal_causing_reveal_replays_without_reaching_the_reducer() -> void:
	# _layout() places the single mine at index 1, adjacent to the forced cell 0, so first Reveal
	# only reveals cell 0 (adjacency 1 blocks the flood). One routine reveal at cell 6 (adjacency 0,
	# floods the entire mine-free row-2 region and every cell it borders) then leaves exactly ONE
	# safe cell (2) still hidden -- so revealing it is the exact command that makes the board
	# terminal.
	var tx1 := _next_tx()
	_reveal_first(tx1, "beginner", 0)
	var identity: Dictionary = _entry_identity_after_first_reveal()
	var routine := _coordinator.reveal(_cell_request_with_real_transaction(identity, 1, 6))
	assert_true(routine.get("ok", false), JSON.stringify(routine))
	assert_false(((_coordinator.get_state()["value"]["board"] as Dictionary)["board"] as Dictionary)["terminal"])

	var terminal_request := _cell_request_with_real_transaction(identity, 2, 2)
	var terminal_result := _coordinator.reveal(terminal_request)
	assert_true(terminal_result.get("ok", false), JSON.stringify(terminal_result))
	assert_true(((_coordinator.get_state()["value"]["board"] as Dictionary)["board"] as Dictionary)["terminal"])

	# Replaying the EXACT transaction_id that just made the board terminal would hit
	# MinesweeperBoardReducer's own board_terminal short-circuit (which fires BEFORE its
	# duplicate-transaction ledger scan) if it ever reached the reducer a second time. The
	# coordinator's own ledger lookup must intercept this first.
	var replay := _coordinator.reveal(terminal_request)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay, terminal_result, "the duplicate retry must replay the original result exactly")


# ---- get_state() ----

func test_get_state_returns_the_board_state_capture() -> void:
	var state := _coordinator.get_state()
	assert_true(state.get("ok", false))
	assert_eq(state["value"]["phase"], "NONE")


# ---- helpers ----

var _tx_counter := 0

func _next_tx() -> String:
	_tx_counter += 1
	var issued := _issuer.issue(&"transaction_id")
	return str(issued["value"]["token"])


## The issuer mints transaction_id and its receipt TOGETHER (issue() takes no value), so a caller
## that already has a specific transaction_id string (from a prior _next_tx()) cannot mint a NEW
## receipt for it after the fact. Tests that need a receipt for an already-known transaction_id
## mint a fresh (transaction_id, receipt) pair via _next_tx()-style minting instead and use ITS
## token as the transaction_id, keeping the two always in lockstep.
func _issue_transaction_receipt_for(transaction_id: String) -> Dictionary:
	for receipt: Dictionary in _root_store.receipts.values():
		if String(receipt["purpose"]) == "transaction_id" and str(receipt["token"]) == transaction_id:
			return receipt
	fail_test("no minted transaction_id receipt found for %s" % transaction_id)
	return {}


func _debug_request(transaction_id: String, identity: Dictionary, expected_revision: int,
		difficulty_id: String) -> Dictionary:
	return {
		"transaction_id": transaction_id, "transaction_issuer_receipt": _issue_transaction_receipt_for(transaction_id),
		"expected_identity": identity, "expected_revision": expected_revision, "difficulty_id": difficulty_id,
	}


func _generic_request(transaction_id: String, identity: Dictionary, expected_revision: int) -> Dictionary:
	return {
		"transaction_id": transaction_id, "transaction_issuer_receipt": _issue_transaction_receipt_for(transaction_id),
		"expected_identity": identity, "expected_revision": expected_revision,
	}


func _first_reveal_request(transaction_id: String, identity: Dictionary, expected_revision: int,
		difficulty_id: String, cell_index: int) -> Dictionary:
	return {
		"transaction_id": transaction_id, "transaction_issuer_receipt": _issue_transaction_receipt_for(transaction_id),
		"expected_identity": identity, "expected_revision": expected_revision,
		"difficulty_id": difficulty_id, "cell_index": cell_index,
	}


func _cell_request_with_real_transaction(identity: Dictionary, expected_revision: int, cell_index: int) -> Dictionary:
	var tx := _next_tx()
	return {
		"transaction_id": tx, "transaction_issuer_receipt": _issue_transaction_receipt_for(tx),
		"expected_identity": identity, "expected_revision": expected_revision, "cell_index": cell_index,
	}


func _reveal_first(transaction_id: String, difficulty_id: String, cell_index: int) -> Dictionary:
	var identity: Dictionary = _coordinator.get_entry_context(difficulty_id)["value"]["identity"]
	var request := _first_reveal_request(transaction_id, identity, 0, difficulty_id, cell_index)
	return _coordinator.reveal(request)


func _entry_identity_after_first_reveal() -> Dictionary:
	return _coordinator.get_state()["value"]["identity"]


func _layout() -> Dictionary:
	return {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [1], "mine_count": 1}
