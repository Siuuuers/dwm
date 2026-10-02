extends "res://addons/gut/test.gd"
## RED/GREEN coverage for DesktopConsequenceSourcePort -- the ONE production object satisfying
## GameStateDayResolutionPort.configure_desktop_consequence_source (DEVIATION-5's truthful
## remainder, dwm-oyo.3 slice authorized 2026-08-24 on dwm-p2r.21 / dwm-oyo.3).
##
## THE SEAM IT FILLS. `resolve_board_fate_receipt({causal_day_instance, source_day})` settles the
## live board's Schedule-Done departure through the REAL DesktopBoardFatePort (prepare -> commit ->
## publish) under a freshly minted command root, retaining the receipt per causal day so a replayed
## resolution binds the SAME board fate -- the law FakeDesktopConsequenceSource documented as "what
## the real ports will do". `resolve_condition_receipt({causal_day_instance, source_day})` returns
## the current run's already-committed condition outcome under its durable resolution root; no
## process-local board or Shop receipt is required.
##
## SUBSTRATE. Real DesktopBoardFatePort over a real, standalone DesktopBoardState (phase NONE), the
## real issuer over FakeDesktopIssuerRootStore, a spy publication ledger mirroring the coordinator
## suite's own FakePublicationLedger, and a minimal duck-typed coordinator read stub -- the REAL
## retention behind that read is proven in test_desktop_consequence_coordinator.gd.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/desktop/DesktopConsequenceSourcePort.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const BOARD_FATE_PORT := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

const CAUSAL_DAY := "causal-day-source-1"

## Exact Plan-02 board-fate receipt members (sorted), mirrored from the fixture the seam froze.
const BOARD_FATE_KEYS: Array = [
	"board_identity", "board_revision", "causal_day_instance", "command_id",
	"command_issuer_receipt", "fate", "receipt_id", "receipt_provenance",
	"source_action_commit_receipt_id", "source_action_commit_receipt_provenance",
]

## Minimal in-memory ledger spy satisfying record_before_emit(), keyed like the real ledger.
class FakePublicationLedger:
	var records: Dictionary = {}

	func record_before_emit(request: Dictionary) -> Dictionary:
		var semantic_receipt: Dictionary = request["semantic_receipt"]
		var identity := str(semantic_receipt.get("receipt_id", ""))
		var key := str(request["kind"]) + ":" + identity
		if records.has(key):
			if records[key] == request:
				return {"ok": true, "code": &"ok",
					"value": {"record": request, "first_delivery": false}, "receipt": {}}
			return {"ok": false, "code": &"publication_record_conflict", "message": key}
		records[key] = request.duplicate(true)
		return {"ok": true, "code": &"ok",
			"value": {"record": request, "first_delivery": true}, "receipt": {}}


## Duck-typed stand-in for the coordinator's committed_condition_receipt read seam. The REAL
## retention law lives in DesktopConsequenceCoordinator and is proven in its own suite.
class StubConditionReadCoordinator:
	var retained: Dictionary = {}

	func committed_condition_receipt(causal_day_instance: String) -> Dictionary:
		var receipt: Variant = retained.get(causal_day_instance)
		return (receipt as Dictionary).duplicate(true) if typeof(receipt) == TYPE_DICTIONARY else {}


var _port_script: Script = null
var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER
var _board_state: RefCounted
var _board_fate_port: RefCounted
var _publication_ledger: FakePublicationLedger
var _coordinator_stub: StubConditionReadCoordinator
var _identity_context: Dictionary = {}
var _port: Object = null


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_port_script = loaded["value"] if loaded.get("ok", false) else null
	_root_store = FAKE_ROOT_STORE.new("77".repeat(32), 1)
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))
	_board_state = BOARD_STATE.new()
	_publication_ledger = FakePublicationLedger.new()
	_board_fate_port = BOARD_FATE_PORT.new()
	assert_true(_board_fate_port.configure_publication_ledger(_publication_ledger).get("ok", false))
	assert_true(_board_fate_port.configure(_board_state, _issuer).get("ok", false))
	_coordinator_stub = StubConditionReadCoordinator.new()
	_identity_context = {"run_id": "run-source", "branch_id": "branch-source",
		"desktop_timeline_generation": 0, "causal_day_instance": ""}
	if _port_script != null:
		_port = _port_script.new()
		var configured: Dictionary = _port.configure(
			_coordinator_stub, _board_fate_port, _issuer, _identity_context)
		assert_true(configured.get("ok", false), JSON.stringify(configured))


func _require_port() -> bool:
	if _port_script == null:
		assert_true(false, "the consequence-source module is absent: " + PORT_PATH)
		return false
	return true


# ---- module presence ----

func test_source_port_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	assert_true(loaded.get("ok", false), "DesktopConsequenceSourcePort.gd must load")


# ---- configure ----

func test_configure_rejects_a_missing_dependency() -> void:
	if not _require_port():
		return
	var fresh: Object = _port_script.new()
	var null_coordinator: Dictionary = fresh.configure(null, _board_fate_port, _issuer, _identity_context)
	assert_false(null_coordinator.get("ok", true))
	var bare_fate: Dictionary = fresh.configure(_coordinator_stub, RefCounted.new(), _issuer, _identity_context)
	assert_false(bare_fate.get("ok", true))
	var blank_context: Dictionary = fresh.configure(_coordinator_stub, _board_fate_port, _issuer,
		{"run_id": "", "branch_id": "", "desktop_timeline_generation": 0, "causal_day_instance": ""})
	assert_false(blank_context.get("ok", true))


func test_configure_identical_replay_is_idempotent_and_replacement_is_refused() -> void:
	if not _require_port():
		return
	var replay: Dictionary = _port.configure(
		_coordinator_stub, _board_fate_port, _issuer, _identity_context)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(bool((replay.get("value", {}) as Dictionary).get("already_configured", false)))
	var replaced: Dictionary = _port.configure(
		StubConditionReadCoordinator.new(), _board_fate_port, _issuer, _identity_context)
	assert_false(replaced.get("ok", true))


# ---- resolve_board_fate_receipt ----

func test_resolve_board_fate_rejects_extra_or_missing_keys() -> void:
	if not _require_port():
		return
	var extra: Dictionary = _port.resolve_board_fate_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": 1, "extra": 1})
	assert_false(extra.get("ok", true))
	var missing: Dictionary = _port.resolve_board_fate_receipt({"causal_day_instance": CAUSAL_DAY})
	assert_false(missing.get("ok", true))
	var blank: Dictionary = _port.resolve_board_fate_receipt({
		"causal_day_instance": " ", "source_day": 1})
	assert_false(blank.get("ok", true))


func test_resolve_board_fate_settles_a_real_schedule_done_departure() -> void:
	if not _require_port():
		return
	var result: Dictionary = _port.resolve_board_fate_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": 1})
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	assert_eq(value.keys(), ["board_fate_receipt"])
	var receipt: Dictionary = value["board_fate_receipt"]
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, BOARD_FATE_KEYS)
	assert_eq(str(receipt["causal_day_instance"]), CAUSAL_DAY)
	assert_eq(str(receipt["fate"]), "none", "a NONE board departs as fate none")
	assert_eq(receipt["board_identity"], null)
	assert_eq(int(receipt["board_revision"]), -1)
	assert_eq(receipt["source_action_commit_receipt_id"], null,
		"the Schedule-Done consumer path carries null action ancestry")
	assert_eq(receipt["source_action_commit_receipt_provenance"], null)
	var validated: Dictionary = _issuer.validate_child(receipt["receipt_provenance"], &"board_fate")
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	# The departure was PUBLISHED through the real port into the ledger before any signal.
	var kinds: Array = []
	for record: Dictionary in _publication_ledger.records.values():
		kinds.append(str(record["kind"]))
	assert_eq(kinds, ["board_fate"])


func test_resolve_board_fate_replay_binds_the_same_receipt_without_a_second_departure() -> void:
	if not _require_port():
		return
	var first: Dictionary = _port.resolve_board_fate_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": 1})
	assert_true(first.get("ok", false), JSON.stringify(first))
	var replay: Dictionary = _port.resolve_board_fate_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": 1})
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay["value"], first["value"], "a replayed resolution binds the SAME board fate")
	assert_eq(_publication_ledger.records.size(), 1, "no second departure was minted or published")


func test_resolve_board_fate_returns_detached_bytes() -> void:
	if not _require_port():
		return
	var first: Dictionary = _port.resolve_board_fate_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": 1})
	((first["value"] as Dictionary)["board_fate_receipt"] as Dictionary)["fate"] = "mutated"
	var replay: Dictionary = _port.resolve_board_fate_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": 1})
	assert_eq(str(((replay["value"] as Dictionary)["board_fate_receipt"] as Dictionary)["fate"]),
		"none", "a caller mutation never reaches the retained receipt")


# ---- resolve_condition_receipt ----

func test_resolve_condition_fails_closed_when_no_action_committed_one() -> void:
	if not _require_port():
		return
	var result: Dictionary = _port.resolve_condition_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": 1})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"condition_receipt_unavailable")


func _condition_owner() -> Node:
	var owner: Node = add_child_autofree(preload("res://autoload/GameState.gd").new())
	owner.reset_game()
	# Seed the already-persisted causal receipt; only allocators may issue this purpose.
	var causal: Dictionary = _root_store.mint(&"causal_day_instance")
	owner._run_lifecycle.reset("run-source", "branch-source", 0, causal["token"],
		{"causal_day_instance_issuer_receipt": causal}, false)
	var root: Dictionary = _issuer.issue(&"transaction_id")["value"]["issuer_receipt"]
	var derived: Dictionary = _issuer.derive_child({"child_kind": "day_resolution_stage", "ordinal": 0,
		"parent_receipt_id": root["receipt_id"], "source_ids": ["P(role,day_resolution.start)"]})
	assert_true(derived.get("ok", false), str(derived))
	var start := {"receipt_id": derived["value"]["child_id"],
		"receipt_provenance": derived["value"]["provenance"], "resolution_id": root["token"],
		"causal_day_instance": causal["token"], "source_day": 1, "board_fate_receipt_id": null,
		"schedule_commit_receipt_id": null, "schedule_entry_ids": []}
	var plan: Dictionary = preload("res://scripts/domain/run/DayResolutionPlan.gd").create(
		root["token"], 1, owner.capture_run_snapshot_input()["committed_schedule"], [], null, null,
		{"command_id": "done-condition-test", "resolution_issuer_receipt": root,
			"day_resolution_start_receipt": start})
	assert_true(plan.get("ok", false), str(plan))
	var lifecycle: Dictionary = owner._run_lifecycle.to_dict()
	lifecycle["active_resolution_plan"] = plan["value"]["plan"].to_dict()
	var prepared: Dictionary = owner._run_lifecycle.prepare_restore(lifecycle)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(owner._run_lifecycle.commit_restore(prepared["value"]["candidate"]).get("ok", false))
	owner.set_stat(owner.STAT_PRESSURE, 10)
	owner.set_stat(owner.STAT_HEALTH, 0)
	assert_true(owner.resolve_pressure_health_condition_end_of_day().get("needs_hospital", false))
	return owner


func _condition_request(owner: Node) -> Dictionary:
	return {"causal_day_instance": owner._run_lifecycle.to_dict()["causal_day_instance"], "source_day": 1}


func _bind_condition_owner(owner: Node) -> Object:
	var port: Object = _port_script.new()
	assert_true(port.configure(_coordinator_stub, _board_fate_port, _issuer, _identity_context).get("ok", false))
	assert_true(port.configure_current_condition_owner(owner).get("ok", false))
	return port


func test_condition_receipt_uses_committed_current_run_outcome_and_ignores_old_action_history() -> void:
	var owner := _condition_owner()
	var port := _bind_condition_owner(owner)
	var request := _condition_request(owner)
	_coordinator_stub.retained[request["causal_day_instance"]] = {
		"receipt_id": "stale-action-condition", "day": 1, "decision": "no_departure"}
	var before: Dictionary = owner.to_save_dict()
	var result: Dictionary = port.resolve_condition_receipt(request)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	var receipt: Dictionary = result["value"]["condition_receipt"]
	assert_ne(receipt["receipt_id"], "stale-action-condition")
	assert_true(receipt["required"])
	assert_eq(receipt["hospital_resolution"], owner.route_context["provisional_hospital_resolution"])
	assert_eq(receipt["condition_after"]["pressure"], 9, "records the already-applied result after clamping")
	assert_eq(receipt["condition_after"]["health"], 1)
	assert_true(_issuer.validate_child(receipt["receipt_provenance"], &"condition").get("ok", false))
	assert_eq(owner.to_save_dict(), before, "receipt capture never reapplies penalties or recovery")


func test_condition_receipt_reconstructs_from_restored_gameplay_and_resolution_with_empty_action_history() -> void:
	var owner := _condition_owner()
	var first: Dictionary = _bind_condition_owner(owner).resolve_condition_receipt(_condition_request(owner))
	assert_true(first.get("ok", false), str(first))
	var serialized: Dictionary = preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify({
		"gameplay": owner.to_save_dict(), "lifecycle": owner._run_lifecycle.to_dict()})
	assert_true(serialized.get("ok", false), str(serialized))
	var saved: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(serialized["value"])["value"]
	var restored: Node = add_child_autofree(preload("res://autoload/GameState.gd").new())
	restored.reset_game()
	assert_true(restored.apply_save_dict(saved["gameplay"]).get("ok", false))
	var prepared: Dictionary = restored._run_lifecycle.prepare_restore(saved["lifecycle"])
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(restored._run_lifecycle.commit_restore(prepared["value"]["candidate"]).get("ok", false))
	_coordinator_stub.retained.clear()
	var before: Dictionary = restored.to_save_dict()
	var reconstructed: Dictionary = _bind_condition_owner(restored).resolve_condition_receipt(_condition_request(restored))
	assert_true(reconstructed.get("ok", false), str(reconstructed))
	assert_eq(reconstructed.get("value"), first.get("value"), "the persisted issuer root reproduces exact condition ancestry")
	assert_eq(restored.to_save_dict(), before)


func test_condition_receipt_uses_retained_plan_after_live_continuation_identity_is_remapped() -> void:
	var owner := _condition_owner()
	var port := _bind_condition_owner(owner)
	var request := _condition_request(owner)
	var first: Dictionary = port.resolve_condition_receipt(request)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	var retained_plan: Dictionary = owner._run_lifecycle.to_dict()["active_resolution_plan"].duplicate(true)
	var replacement: Dictionary = _root_store.mint(&"causal_day_instance")
	owner._run_lifecycle._causal_day_instance = str(replacement["token"])
	owner._run_lifecycle._causal_day_instance_issuer_receipt = replacement.duplicate(true)
	assert_eq(owner._run_lifecycle.to_dict()["day"], request["source_day"])
	assert_ne(owner._run_lifecycle.to_dict()["causal_day_instance"], request["causal_day_instance"])
	assert_eq(owner._run_lifecycle.to_dict()["active_resolution_plan"], retained_plan,
		"fresh-load continuation remapping retains the unfinished source plan")
	var reconstructed: Dictionary = port.resolve_condition_receipt(request)
	assert_true(reconstructed.get("ok", false), str(reconstructed))
	assert_eq(reconstructed.get("value"), first.get("value"),
		"the retained plan start and root reproduce the exact condition receipt")
	var foreign := request.duplicate(true)
	foreign["causal_day_instance"] = str(replacement["token"])
	assert_false(port.resolve_condition_receipt(foreign).get("ok", true),
		"the remapped live identity cannot replace the retained plan's source request")


func test_condition_receipt_refuses_stale_continuation_and_an_unresolved_current_day() -> void:
	var owner := _condition_owner()
	var port := _bind_condition_owner(owner)
	var stale := _condition_request(owner)
	stale["causal_day_instance"] = "older-continuation"
	assert_false(port.resolve_condition_receipt(stale).get("ok", true))
	owner.condition_resolved_day = 0
	assert_false(port.resolve_condition_receipt(_condition_request(owner)).get("ok", true),
		"a current danger value cannot substitute for a committed condition decision")


func test_current_condition_owner_binding_rejects_replacement() -> void:
	var owner := _condition_owner()
	var port := _bind_condition_owner(owner)
	assert_true(port.configure_current_condition_owner(owner).get("ok", false))
	assert_false(port.configure_current_condition_owner(_condition_owner()).get("ok", true))
