extends "res://addons/gut/test.gd"
## RED/GREEN coverage for GameStateDesktopConditionContextPort (Plan 03 Task 7, dwm-oyo.3 slice
## authorized 2026-08-24 on dwm-p2r.21 / dwm-oyo.3 -- see both beads' deviation notes).
##
## SUBSTRATE. The real GameState autoload script, the real DesktopIdentityNonceIssuer over
## FakeDesktopIssuerRootStore (the established coordinator-suite substrate), and receipts derived
## through that same issuer. The port is loaded through DynamicScriptProbe so its absence during RED
## is a named assertion, not a parse crash.
##
## SCOPE HONESTY. This suite freezes the slice's contract: the exact 11-key context value, the
## receipt cross-checks against the live lifecycle, read-only capture, and the derive/validate
## delegation. The full Task-7 depth (action-outbox ownership proof, Contacts accepted/read state
## refinement) stays owned by Plan 03 Task 7 and is NOT claimed here.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/desktop/GameStateDesktopConditionContextPort.gd"
const GAME_STATE_PATH := "res://autoload/GameState.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")

const RUN_ID := "run-ctx"
const BRANCH_ID := "branch-ctx"
const GENERATION := 0
const CAUSAL_DAY := "causal-day-ctx-1"

## The exact frozen context member set (Plan 03 line 854), sorted.
const CONTEXT_KEYS: Array = [
	"accepted_unfulfilled_sources", "branch_id", "causal_day_instance", "condition_after",
	"dark_mode", "day", "desktop_timeline_generation", "run_id", "run_revision",
	"schedule_done_state", "sylvia_read_source_receipt",
]

var _port_script: Script = null
var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER
var _game_state: Node = null
var _port: Object = null


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_port_script = loaded["value"] if loaded.get("ok", false) else null
	_root_store = FAKE_ROOT_STORE.new("55".repeat(32), 1)
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))
	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	_install_lifecycle_identity(1)
	if _port_script != null:
		_port = _port_script.new()
		var configured: Dictionary = _port.configure(_game_state, _issuer)
		assert_true(configured.get("ok", false), JSON.stringify(configured))


func _require_port() -> bool:
	if _port_script == null:
		assert_true(false, "the context-port module is absent: " + PORT_PATH)
		return false
	return true


## Installs a real, receipt-backed lifecycle identity so DesktopActionReceipt validation and the
## port's live-identity cross-checks have honest live bytes to check against.
func _install_lifecycle_identity(day: int, dark_mode: bool = false) -> void:
	var receipt: Dictionary = _root_store.mint(&"causal_day_instance").duplicate(true)
	receipt["token"] = CAUSAL_DAY
	_game_state._run_lifecycle.reset(RUN_ID, BRANCH_ID, GENERATION, CAUSAL_DAY,
		{"causal_day_instance_issuer_receipt": receipt}, dark_mode)
	if day != 1:
		var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
		lifecycle["day"] = day
		var prepared: Dictionary = _game_state._run_lifecycle.prepare_restore(lifecycle)
		assert_true(prepared.get("ok", false), JSON.stringify(prepared))
		var committed: Dictionary = _game_state._run_lifecycle.commit_restore(
			(prepared["value"] as Dictionary)["candidate"])
		assert_true(committed.get("ok", false), JSON.stringify(committed))


func _mint_transaction() -> Dictionary:
	var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]),
		"transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _action_receipt(day: int, txn: Dictionary, unlock_receipt_ids: Array = []) -> Dictionary:
	var parent_id := str((txn["transaction_issuer_receipt"] as Dictionary)["receipt_id"])
	var source_commit := _issuer.derive_child({
		"child_kind": "shop_quote", "ordinal": 0, "parent_receipt_id": parent_id,
		"source_ids": ["ctx-quote-source"],
	})
	assert_true(source_commit.get("ok", false), JSON.stringify(source_commit))
	var action_derived := _issuer.derive_child({
		"child_kind": "desktop_action", "ordinal": 0, "parent_receipt_id": parent_id,
		"source_ids": ["ctx-action-source"],
	})
	assert_true(action_derived.get("ok", false), JSON.stringify(action_derived))
	var action_id := str((action_derived["value"] as Dictionary)["child_id"])
	var action_provenance: Dictionary = (action_derived["value"] as Dictionary)["provenance"]
	var receipt := {
		"schema_version": 1, "action_kind": "shop_purchase", "run_id": RUN_ID,
		"branch_id": BRANCH_ID, "desktop_timeline_generation": GENERATION,
		"causal_day_instance": CAUSAL_DAY, "day": day,
		"transaction_id": str(txn["transaction_id"]),
		"transaction_issuer_receipt": (txn["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"source_commit_receipt_id": str((source_commit["value"] as Dictionary)["child_id"]),
		"source_commit_receipt_provenance": (source_commit["value"] as Dictionary)["provenance"],
		"condition_before": {"health": 6, "pressure": 3, "carried_sequela": false},
		"condition_after": {"health": 6, "pressure": 3, "carried_sequela": false},
		"unlock_receipt_ids": unlock_receipt_ids.duplicate(true),
		"action_id": action_id, "action_id_provenance": action_provenance,
		"commit_receipt_id": action_id,
		"commit_receipt_provenance": (action_provenance as Dictionary).duplicate(true),
	}
	var validated := ACTION_RECEIPT.validate(receipt)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	return (validated["value"] as Dictionary)["receipt"]


func _causal_sequence_receipt(action_receipt: Dictionary) -> Dictionary:
	return {
		"receipt_id": "causal-sequence-receipt-" + str(action_receipt["transaction_id"]),
		"receipt_provenance": {"kind": "causal_sequence",
			"transaction_id": str(action_receipt["transaction_id"])},
		"transaction_id": str(action_receipt["transaction_id"]),
		"transaction_issuer_receipt":
			(action_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"run_id": RUN_ID, "branch_id": BRANCH_ID, "desktop_timeline_generation": GENERATION,
		"causal_day_instance": CAUSAL_DAY, "source_kind": "shop_purchase",
		"source_commit_receipt_id": str(action_receipt["source_commit_receipt_id"]),
		"source_commit_receipt_provenance":
			(action_receipt["source_commit_receipt_provenance"] as Dictionary).duplicate(true),
		"causal_sequence": 1, "run_revision": 1,
	}


func _request(day: int = 1) -> Dictionary:
	var txn := _mint_transaction()
	var action := _action_receipt(day, txn)
	return {"action_receipt": action, "causal_sequence_receipt": _causal_sequence_receipt(action)}


## Installs one issuer-derived Plan-01-shaped Schedule source receipt into the live Contacts bag.
func _install_source(action_id: String, day: int, participants: Array) -> Dictionary:
	var txn := _mint_transaction()
	var parent_id := str((txn["transaction_issuer_receipt"] as Dictionary)["receipt_id"])
	var derived := _issuer.derive_child({
		"child_kind": "contact_source", "ordinal": 0, "parent_receipt_id": parent_id,
		"source_ids": ["source:" + action_id],
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	var source := {
		"action_id": action_id, "day": day, "kind": "solo_read_acceptance",
		"participants": participants.duplicate(true), "previous_receipt_id": "",
		"receipt_id": str((derived["value"] as Dictionary)["child_id"]),
		"receipt_provenance": (derived["value"] as Dictionary)["provenance"],
	}
	(_game_state.contacts["schedule_source_receipts"] as Dictionary)[source["receipt_id"]] = \
		source.duplicate(true)
	return source


# ---- module presence ----

func test_context_port_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	assert_true(loaded.get("ok", false), "GameStateDesktopConditionContextPort.gd must load")


# ---- configure ----

func test_configure_rejects_null_game_state() -> void:
	if not _require_port():
		return
	var fresh: Object = _port_script.new()
	var result: Dictionary = fresh.configure(null, _issuer)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"invalid_context_configuration")


func test_configure_rejects_an_issuer_without_the_child_capability() -> void:
	if not _require_port():
		return
	var fresh: Object = _port_script.new()
	var result: Dictionary = fresh.configure(_game_state, RefCounted.new())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"invalid_context_configuration")


func test_configure_identical_replay_is_idempotent_and_replacement_is_refused() -> void:
	if not _require_port():
		return
	var replay: Dictionary = _port.configure(_game_state, _issuer)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(bool((replay.get("value", {}) as Dictionary).get("already_configured", false)))
	var other_state: Node = load(GAME_STATE_PATH).new()
	autofree(other_state)
	other_state.reset_game()
	var replaced: Dictionary = _port.configure(other_state, _issuer)
	assert_false(replaced.get("ok", true))
	assert_eq(replaced.get("code"), &"context_port_conflict")


func test_snapshot_before_configure_fails_closed() -> void:
	if not _require_port():
		return
	var fresh: Object = _port_script.new()
	var result: Dictionary = fresh.snapshot_for(_request())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"port_not_configured")


# ---- snapshot_for: request validation ----

func test_snapshot_rejects_a_request_with_extra_or_missing_keys() -> void:
	if not _require_port():
		return
	var request := _request()
	request["extra"] = true
	var extra: Dictionary = _port.snapshot_for(request)
	assert_false(extra.get("ok", true))
	assert_eq(extra.get("code"), &"context_request_invalid")
	var missing: Dictionary = _port.snapshot_for({"action_receipt": request["action_receipt"]})
	assert_false(missing.get("ok", true))
	assert_eq(missing.get("code"), &"context_request_invalid")


func test_snapshot_rejects_a_sequence_receipt_for_another_transaction() -> void:
	if not _require_port():
		return
	var request := _request()
	(request["causal_sequence_receipt"] as Dictionary)["transaction_id"] = "someone-else"
	var result: Dictionary = _port.snapshot_for(request)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"context_receipts_mismatch")


func test_snapshot_rejects_a_receipt_from_another_live_identity() -> void:
	if not _require_port():
		return
	var request := _request()
	(request["action_receipt"] as Dictionary)["causal_day_instance"] = "some-other-day"
	(request["causal_sequence_receipt"] as Dictionary)["causal_day_instance"] = "some-other-day"
	var result: Dictionary = _port.snapshot_for(request)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"context_receipts_mismatch")


func test_snapshot_rejects_a_day_the_live_lifecycle_is_not_in() -> void:
	if not _require_port():
		return
	var result: Dictionary = _port.snapshot_for(_request(3))
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"context_receipts_mismatch")


# ---- snapshot_for: the exact context value ----

func test_snapshot_returns_the_exact_context_member_set() -> void:
	if not _require_port():
		return
	var result: Dictionary = _port.snapshot_for(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	assert_eq(value.keys(), ["context"])
	var context: Dictionary = value["context"]
	var keys: Array = context.keys()
	keys.sort()
	assert_eq(keys, CONTEXT_KEYS)
	assert_eq(str(context["run_id"]), RUN_ID)
	assert_eq(str(context["branch_id"]), BRANCH_ID)
	assert_eq(int(context["desktop_timeline_generation"]), GENERATION)
	assert_eq(str(context["causal_day_instance"]), CAUSAL_DAY)
	assert_eq(int(context["day"]), 1)
	assert_eq(int(context["run_revision"]), 1)
	assert_eq(str(context["schedule_done_state"]), "open")
	assert_eq(context["sylvia_read_source_receipt"], null)
	assert_eq(context["accepted_unfulfilled_sources"], [])


func test_snapshot_reads_the_detached_prepared_condition_without_mutating_live_state() -> void:
	if not _require_port():
		return
	_game_state.stats[_game_state.STAT_PRESSURE] = 11
	_game_state.stats[_game_state.STAT_HEALTH] = 2
	_game_state.condition_effects_today.append("sequela")
	var request := _request()
	var before: Dictionary = _game_state.to_save_dict().duplicate(true)
	var result: Dictionary = _port.snapshot_for(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var condition: Dictionary = result["value"]["context"]["condition_after"]
	assert_eq(condition, {"health": 6, "pressure": 3, "carried_sequela": false},
		"the prepared action result can differ from every live condition field")
	assert_eq(_game_state.to_save_dict(), before)
	condition["pressure"] = 99
	assert_eq(request["action_receipt"]["condition_after"]["pressure"], 3,
		"the returned context cannot mutate the admitted action's receipt")
	var again: Dictionary = _port.snapshot_for(request)
	assert_eq(again["value"]["context"]["condition_after"]["pressure"], 3)


func test_snapshot_reports_captured_dark_mode_independently_of_friend_tone() -> void:
	if not _require_port():
		return
	var plain: Dictionary = _port.snapshot_for(_request())
	assert_false(bool(((plain["value"] as Dictionary)["context"] as Dictionary)["dark_mode"]))
	_game_state.dating_route_state["sylvia"] = {"date_count": 2, "dark_points": 2,
		"true_path_count": 0, "previous_entered_true_path": false}
	var toned: Dictionary = _port.snapshot_for(_request())
	assert_false(bool(toned.value.context.dark_mode), "friend tone cannot enable the captured run mode")
	_install_lifecycle_identity(1, true)
	var dark: Dictionary = _port.snapshot_for(_request())
	assert_true(bool(dark.value.context.dark_mode))


func test_snapshot_collects_current_day_sources_sorted_by_action_then_receipt() -> void:
	if not _require_port():
		return
	var second := _install_source("solo:priscilla:day1", 1, ["priscilla"])
	var first := _install_source("solo:lavinia:day1", 1, ["lavinia"])
	_install_source("solo:momo:day2", 2, ["momo"])
	var result: Dictionary = _port.snapshot_for(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var sources: Array = ((result["value"] as Dictionary)["context"] as Dictionary)["accepted_unfulfilled_sources"]
	assert_eq(sources.size(), 2, "only the current day's sources are consumable")
	assert_eq(str((sources[0] as Dictionary)["action_id"]), str(first["action_id"]))
	assert_eq(str((sources[1] as Dictionary)["action_id"]), str(second["action_id"]))


func test_snapshot_excludes_a_source_the_current_action_itself_unlocked() -> void:
	if not _require_port():
		return
	var unlocked := _install_source("solo:sylvia:day1", 1, ["sylvia"])
	var txn := _mint_transaction()
	var action := _action_receipt(1, txn, [str(unlocked["receipt_id"])])
	var result: Dictionary = _port.snapshot_for({
		"action_receipt": action, "causal_sequence_receipt": _causal_sequence_receipt(action)})
	assert_true(result.get("ok", false), JSON.stringify(result))
	var context: Dictionary = (result["value"] as Dictionary)["context"]
	assert_eq(context["accepted_unfulfilled_sources"], [],
		"an unlock emitted by the current action is not a read receipt")
	assert_eq(context["sylvia_read_source_receipt"], null)


func test_snapshot_reports_a_preexisting_sylvia_read_source() -> void:
	if not _require_port():
		return
	var sylvia := _install_source("solo:sylvia:day1", 1, ["sylvia"])
	var result: Dictionary = _port.snapshot_for(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var reported: Variant = ((result["value"] as Dictionary)["context"] as Dictionary)["sylvia_read_source_receipt"]
	assert_eq(typeof(reported), TYPE_DICTIONARY)
	assert_eq(str((reported as Dictionary)["receipt_id"]), str(sylvia["receipt_id"]))


func test_snapshot_is_read_only() -> void:
	if not _require_port():
		return
	_install_source("solo:priscilla:day1", 1, ["priscilla"])
	var before: Dictionary = (_game_state.to_save_dict() as Dictionary).duplicate(true)
	var result: Dictionary = _port.snapshot_for(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(_game_state.to_save_dict(), before, "snapshot_for must not mutate live state")


func test_snapshot_returns_detached_sources() -> void:
	if not _require_port():
		return
	_install_source("solo:priscilla:day1", 1, ["priscilla"])
	var result: Dictionary = _port.snapshot_for(_request())
	var sources: Array = ((result["value"] as Dictionary)["context"] as Dictionary)["accepted_unfulfilled_sources"]
	(sources[0] as Dictionary)["action_id"] = "mutated"
	var again: Dictionary = _port.snapshot_for(_request())
	var fresh: Array = ((again["value"] as Dictionary)["context"] as Dictionary)["accepted_unfulfilled_sources"]
	assert_eq(str((fresh[0] as Dictionary)["action_id"]), "solo:priscilla:day1",
		"a caller mutation must never reach the retained state")


# ---- derive_child / validate_child delegation ----

func test_derive_child_round_trips_through_the_real_issuer() -> void:
	if not _require_port():
		return
	var txn := _mint_transaction()
	var derived: Dictionary = _port.derive_child({
		"child_kind": "condition", "ordinal": 0,
		"parent_receipt_id": str((txn["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": ["ctx-condition-source"],
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	var provenance: Dictionary = (derived["value"] as Dictionary)["provenance"]
	var validated: Dictionary = _port.validate_child(provenance, &"condition")
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	var mismatched: Dictionary = _port.validate_child(provenance, &"destination_intent")
	assert_false(mismatched.get("ok", true), "a swapped expected_kind must fail")


# ---- the Schedule-Done discriminator (`_schedule_done_state`) ----

func test_snapshot_reports_committed_once_the_day_carries_a_commit_receipt() -> void:
	if not _require_port():
		return
	_install_committed_aggregate()
	var result: Dictionary = _port.snapshot_for(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var context: Dictionary = ((result["value"] as Dictionary)["context"] as Dictionary)
	assert_eq(str(context["schedule_done_state"]), "committed",
		"a committed aggregate for the LIVE day is the post-Done state, not open")


func test_a_completed_resolution_plan_is_not_resolving() -> void:
	if not _require_port():
		return
	var begun: Dictionary = _game_state._run_lifecycle.begin_day_resolution(
		"completed-resolution", {"schema_version": 1, "day": 1, "registry_fingerprint": null,
			"entries": [], "commit_receipt": null}, [], null, null, {})
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
	var plan: Dictionary = lifecycle["active_resolution_plan"]
	var stages: Array = plan["stages"]
	assert_false(stages.is_empty(), "the premise needs a plan that actually carries stages")
	for stage: Dictionary in stages:
		_complete_record(stage)
		for substage: Dictionary in (stage.get("substages", []) as Array):
			_complete_record(substage)
	var prepared: Dictionary = _game_state._run_lifecycle.prepare_restore(lifecycle)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = _game_state._run_lifecycle.commit_restore(
		(prepared["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	_install_committed_aggregate()
	var result: Dictionary = _port.snapshot_for(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var context: Dictionary = ((result["value"] as Dictionary)["context"] as Dictionary)
	assert_eq(str(context["schedule_done_state"]), "committed",
		"COMPLETENESS, not presence, is the discriminator: a completed plan is never resolving")


## A completed plan record: the lifecycle refuses "completed" unless the receipt is exactly the
## one-key {"value": Dictionary} envelope `DayResolutionPlan._normalize_receipt` accepts.
func _complete_record(record: Dictionary) -> void:
	record["state"] = "completed"
	record["receipt"] = {"value": {"completed_by": "the completed-plan premise"}}


## A day-scoped committed aggregate for the LIVE day, which is what `_canonical_committed_schedule`
## requires before it will hand back anything but the canonical empty aggregate.
func _install_committed_aggregate() -> void:
	_game_state._committed_schedule = {
		"schema_version": 1,
		"day": int(_game_state.day),
		"registry_fingerprint": null,
		"entries": [],
		"commit_receipt": {"receipt_id": "commit-receipt-ctx"},
	}
