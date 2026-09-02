extends "res://addons/gut/test.gd"

# Amendment Plan 03 Task 1 Steps 1-2 (dwm-oyo.3, RED): the executable downstream-contract net over
# the `.7` Schedule and `.9` desktop transaction ports, asserted through the compiling
# ScheduleDownstreamContractGuard skeleton. The consumed-interface-lock section of
# docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-03-seven-day-flow-integration.md
# is the sole authority for every shape asserted here.
#
# RED DISCIPLINE (global constraint line 40). Every test's FIRST assertion routes a REAL production
# result through the guard and asserts the guard's verdict, so at RED each failure message names
# `not_implemented` -- never a missing preload, parse error, or fixture error. GUT orders tests
# alphabetically (see test_schedule_done_public_walk.gd's own `test_a_` precedent), so test_a01 is
# the suite's first failure. When Step 4 implements the validators, the same assertions go green
# against corrected predecessors without edits here.
#
# GUARD VERDICT SEMANTICS pinned by this suite (documented for Step 4): a validator returns ok:true
# for a result conforming to the master envelope law -- a success exactly {ok, code, value, receipt}
# with the participant's exact candidate/receipt schema, or a failure exactly
# {ok, code, message, details}; anything else fails closed naming the exact difference.
#
# STEP 2 OWNERSHIP LAW. This suite calls the production ScheduleActionRegistry (registry + saved
# fingerprint), the production GameState candidate builders (Schedule commit and Shop economy over
# a real GameState node), the production DesktopConsequenceCoordinator, and the production
# DayResolutionStartPort. The only doubles are Plan 02's own established Task-8 contract fakes
# (FakeDesktopConsequenceCheckpointPort, FakeDesktopConditionPolicyPort,
# FakeScheduleDepartureViewPort -- Plan 03 Tasks 2-7 own their real law) plus the issuer's
# FakeFileOps/FakeDesktopNamespaceSource substrate; every fake only observes, and no fake
# manufactures a success candidate under test. Wiring copies
# tests/integration/test_desktop_completion_transaction.gd /
# test_shop_condition_contract_departure.gd / test_schedule_done_public_walk.gd seam for seam.
#
# REJECTION ASSERTIONS (DECISION 9.9). Every port rejection asserts failure AND an exact code
# != &"not_implemented" -- pin identity, not occurrence -- plus the exact 4-key failure envelope,
# plus a byte-identical downstream graph after the refusal (fail WITHOUT mutation).
#
# PREDECESSOR DISPOSITIONS under DEVIATION-18 Ruling 18-A (maintainer AskUserQuestion, recorded
# 2026-09-02 on dwm-oyo.3: HYBRID -- fix safety, defer shapes):
#   1. DayResolutionStartPort SHAPES are deferred: test_a10 characterizes the SHIPPED success value
#      {start_receipt, committed_schedule, route_plan, schedule_commit_receipt_id,
#      board_fate_receipt_id} and the shipped 8-member receipt (no registry_fingerprint); the
#      lock's {day_resolution_candidate, resolution_plan, day_resolution_start_receipt} divergence
#      is reconciled by the first consuming task (Task 6/7), never patched here. The SAFETY half is
#      fixed additively in the port: a causal_day_instance different from the committed Schedule's
#      own refuses (day_resolution_causal_day_mismatch) and a resolution_id that is not the
#      verified root's token refuses (day_resolution_id_mismatch) -- both pinned in test_b11.
#   2. DesktopConsequenceCoordinator's configure_schedule_departure_ports() /
#      request_schedule_departure() exist as fail-closed not_configured STUBS under Ruling 18-A;
#      Plan 03 Task 6 implements them (test_a01's census is green through the stubs).
#   3. ScheduleActionRegistry exposes find_record(action_id), not the locked
#      lookup(action_id, expected_fingerprint) / snapshot(expected_fingerprint) names; this suite
#      uses the shipped surface as every existing integration test does, and records the gap.
#
# GLOBAL CLASS NAMES are not used for the new Task-1 guard (DECISION 9.18 precedent): it is
# preloaded by path. ApplicationMutationGate.acquire() is never called here with more than its one
# frozen &"causal_transaction" argument, and no identity is minted outside the injected issuer.

const GUARD := preload("res://scripts/application/schedule/ScheduleDownstreamContractGuard.gd")
const GS := preload("res://autoload/GameState.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const SCHEDULE_COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const SCHEDULE_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const DAY7_PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")
const DAY_STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const DAY_START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
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
const VIEW_FINGERPRINT := "schedule_view.77777777777777777777777777777777"

# ---- consumed-interface-lock key sets (sorted; the lock's prose order differs, the SET is law) ----
const SUCCESS_ENVELOPE_KEYS: Array = ["code", "ok", "receipt", "value"]
const FAILURE_ENVELOPE_KEYS: Array = ["code", "details", "message", "ok"]
const SCHEDULE_VALUE_KEYS: Array = [
	"committed_schedule", "game_state_candidate", "route_plan", "schedule_commit_receipt",
]
const SCHEDULE_RECEIPT_KEYS: Array = [
	"causal_day_instance", "day", "motivation_charged", "receipt_id", "receipt_provenance",
	"registry_fingerprint", "schedule_entry_ids", "source_receipt_ids", "transaction_id",
	"transaction_issuer_receipt", "view_fingerprint",
]
const DAY7_TERMINAL_KEYS: Array = [
	"action_id", "causal_day_instance", "cause", "day", "kind", "receipt_id",
	"receipt_provenance", "registry_fingerprint", "schedule_commit_receipt_id",
	"schedule_entry_id", "source_receipt_id",
]
const RESERVATION_VALUE_KEYS: Array = ["causal_sequence_receipt", "sequence_candidate"]
const SEQUENCE_RECEIPT_KEYS: Array = [
	"branch_id", "causal_day_instance", "causal_sequence", "desktop_timeline_generation",
	"receipt_id", "receipt_provenance", "run_id", "run_revision", "source_commit_receipt_id",
	"source_commit_receipt_provenance", "source_kind", "transaction_id",
	"transaction_issuer_receipt",
]
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
# SHIPPED day-start shapes, characterized per DEVIATION-18 Ruling 18-A (2026-09-02, dwm-oyo.3):
# the consumed-interface-lock {day_resolution_candidate, resolution_plan,
# day_resolution_start_receipt} / nine-member-receipt divergence is deferred to the first
# consuming task (Task 6/7), never patched here.
const DAY_START_VALUE_KEYS: Array = [
	"board_fate_receipt_id", "committed_schedule", "route_plan", "schedule_commit_receipt_id",
	"start_receipt",
]
const DAY_START_RECEIPT_KEYS: Array = [
	"board_fate_receipt_id", "causal_day_instance", "receipt_id", "receipt_provenance",
	"resolution_id", "schedule_commit_receipt_id", "schedule_entry_ids", "source_day",
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
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("p2r13_downstream_contracts") \
		.path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root)

	var gs: Node = GS.new()
	add_child_autofree(gs)
	gs.reset_game()
	gs.money = 100
	gs.coins = 10
	gs._lifecycle_set_playing_day(day)

	var registry_loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
	assert_true(registry_loaded.get("ok", false), JSON.stringify(registry_loaded))
	var registry: Object = (registry_loaded["value"] as Dictionary)["registry"]
	var registry_fingerprint := str((registry_loaded["value"] as Dictionary)["registry_fingerprint"])

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

	var schedule_ledger: Object = SCHEDULE_PUBLICATION_LEDGER.new()
	assert_true(schedule_ledger.configure(STORAGE.new(root.path_join("schedule"))).get("ok", false))
	assert_true(schedule_ledger.load().get("ok", false))
	var schedule_port: Object = SCHEDULE_COMMIT_PORT.new(gs, registry, issuer, schedule_ledger)

	var day7_provenance: Object = DAY7_PROVENANCE.new()
	assert_true(day7_provenance.configure(registry, issuer).get("ok", false))

	var day_state_port: Object = DAY_STATE_PORT.new(gs)
	var day_start_port: Object = DAY_START_PORT.new(day_state_port, registry, issuer, schedule_ledger)

	return {
		"gs": gs, "issuer": issuer, "registry": registry,
		"registry_fingerprint": registry_fingerprint, "gate": gate,
		"consequence_state": consequence_state, "checkpoint_port": checkpoint_port,
		"board_state": round_coordinator._board_state, "round_coordinator": round_coordinator,
		"shop_participant": shop_participant, "coordinator": coordinator,
		"board_fate_port": board_fate_port, "causal_sequence_port": causal_sequence_port,
		"schedule_port": schedule_port, "day7_provenance": day7_provenance,
		"day_start_port": day_start_port, "schedule_view_port": schedule_view_port,
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


## Seeds a real receipt-backed solo source through the Contacts domain module, exactly as the
## public-walk suite does, so the commit port validates true ancestry rather than a plausible index.
func _seed_solo_source(wired: Dictionary, friend_id: String, action_id: String,
		day: int = DAY) -> String:
	var gs: Node = wired["gs"]
	var issuer: Object = wired["issuer"]
	var registry: Object = wired["registry"]
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		gs.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), JSON.stringify(offered))
	var command := _mint_transaction(issuer)
	var found: Dictionary = registry.find_record(action_id)
	assert_true(found.get("ok", false), JSON.stringify(found))
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		(offered["value"] as Dictionary)["candidate"], friend_id, day,
		command["transaction_id"], command["transaction_issuer_receipt"], issuer,
		((found["value"] as Dictionary)["record"] as Dictionary))
	assert_true(opened.get("ok", false), JSON.stringify(opened))
	gs.contacts = (opened["value"] as Dictionary)["candidate"]
	return str((opened["receipt"] as Dictionary)["receipt_id"])


func _schedule_request(wired: Dictionary, txn: Dictionary, draft_entries: Array,
		day: int = DAY) -> Dictionary:
	return {
		"transaction_id": txn["transaction_id"],
		"transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": draft_entries,
		"registry_fingerprint": wired["registry_fingerprint"],
	}


func _valid_day3_request(wired: Dictionary) -> Dictionary:
	var action_id := "solo:lavinia:day%d" % DAY
	var source_receipt_id := _seed_solo_source(wired, "lavinia", action_id)
	var txn := _mint_transaction(wired["issuer"])
	var request := _schedule_request(wired, txn, [{
		"draft_entry_id": "d-lav", "day": DAY, "slot_index": 0, "action_id": action_id,
		"action_kind": "solo", "participants": ["lavinia"], "source_receipt_id": source_receipt_id,
	}])
	return {"request": request, "txn": txn}


func _prepare_day3_schedule(wired: Dictionary) -> Dictionary:
	var built := _valid_day3_request(wired)
	var prepared: Dictionary = (wired["schedule_port"] as Object).prepare_commit(built["request"])
	return {"request": built["request"], "prepared": prepared, "txn": built["txn"]}


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


func _schedule_done_reservation_request(txn: Dictionary, schedule_receipt: Dictionary) -> Dictionary:
	return {
		"transaction_id": txn["transaction_id"],
		"transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"run_id": RUN_ID, "branch_id": BRANCH_ID,
		"desktop_timeline_generation": 0, "causal_day_instance": CAUSAL_DAY,
		"source_kind": "schedule_done",
		"source_commit_receipt_id": str(schedule_receipt["receipt_id"]),
		"source_commit_receipt_provenance": (schedule_receipt["receipt_provenance"] as Dictionary).duplicate(true),
		"expected_last_sequence": 0, "expected_run_revision": 0,
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
	var schedule_backup: Dictionary = \
		((wired["schedule_port"] as Object).capture()["value"] as Dictionary)["backup"]
	return {
		"schedule": schedule_backup,
		"board": ((wired["board_state"] as Object).capture() as Dictionary).duplicate(true),
		"consequence": (((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"] as Dictionary),
		"contacts": (gs.contacts as Dictionary).duplicate(true),
		"economy": {"money": gs.money, "coins": gs.coins,
			"inventory": (gs.inventory as Dictionary).duplicate(true)},
	}


# -------------------------------------------------------------------------------------------------
# a: the guard over real success drives -- each first assertion is the RED not_implemented anchor.
# -------------------------------------------------------------------------------------------------

func test_a01_validate_ports_covers_every_frozen_downstream_method() -> void:
	var wired := _wired()
	var verdict: Dictionary = GUARD.validate_ports(wired["schedule_port"],
		wired["day7_provenance"], wired["causal_sequence_port"], wired["board_fate_port"],
		wired["coordinator"], wired["day_start_port"])
	_assert_guard_accepts(verdict, "validate_ports over the six production participants")
	# The same census pinned directly, so a missing frozen method is named even without the guard.
	# The coordinator rows configure_schedule_departure_ports / request_schedule_departure are
	# satisfied by the fail-closed DEVIATION-18 Ruling 18-A stubs until Task 6 implements them
	# (disposition 2 in the header).
	for expectation: Array in [
		[wired["schedule_port"], ["prepare_commit", "capture", "commit", "rollback", "publish"]],
		[wired["day7_provenance"], ["configure", "validate_handoff"]],
		[wired["causal_sequence_port"], ["configure", "prepare_reservation", "prepare_admission",
			"capture", "commit", "rollback", "publish"]],
		[wired["board_fate_port"], ["prepare_causal_departure",
			"prepare_projected_causal_departure", "capture", "commit", "rollback", "publish"]],
		[wired["coordinator"], ["accept_prepared_action", "configure_schedule_departure_ports",
			"request_schedule_departure"]],
		[wired["day_start_port"], ["prepare_from_committed_schedule", "capture", "commit",
			"rollback", "publish"]],
	]:
		var target: Object = expectation[0]
		for method_name: String in (expectation[1] as Array):
			assert_true(target.has_method(method_name),
				"frozen downstream method missing: %s" % method_name)


func test_a02_schedule_prepare_commit_matches_the_frozen_contract() -> void:
	var wired := _wired()
	var driven := _prepare_day3_schedule(wired)
	var prepared: Dictionary = driven["prepared"]
	_assert_guard_accepts(GUARD.validate_schedule_result(prepared),
		"validate_schedule_result over a real prepare_commit success")

	_assert_success_shape(prepared, "prepare_commit")
	assert_eq(_keys_of(prepared["value"]), SCHEDULE_VALUE_KEYS,
		"success value carries exactly game_state_candidate, committed_schedule, route_plan, schedule_commit_receipt")
	var receipt: Dictionary = (prepared["value"] as Dictionary)["schedule_commit_receipt"]
	assert_eq(prepared["receipt"], receipt,
		"the outer receipt is an exact detached copy of schedule_commit_receipt")
	assert_eq(_keys_of(receipt), SCHEDULE_RECEIPT_KEYS, "the commit receipt member set is exact")
	var aggregate: Dictionary = (prepared["value"] as Dictionary)["committed_schedule"]
	assert_eq(int(aggregate["schema_version"]), 1, "committed_schedule schema_version is 1")
	assert_eq(aggregate["commit_receipt"], receipt,
		"a nonempty aggregate embeds the exact commit receipt byte-for-byte")
	assert_eq(int(receipt["motivation_charged"]), (aggregate["entries"] as Array).size(),
		"motivation_charged equals the committed-entry count")
	var entry: Dictionary = (aggregate["entries"] as Array)[0]
	assert_eq((receipt["schedule_entry_ids"] as Array)[0], entry["schedule_entry_id"],
		"schedule_entry_ids are the entries' own ordered ids")
	assert_eq((receipt["source_receipt_ids"] as Array)[0], entry["source_receipt_id"],
		"source receipt IDs align by index with the committed entries")
	var issuer: Object = wired["issuer"]
	assert_true((issuer.validate_child(entry["schedule_entry_provenance"], &"schedule_entry") as Dictionary).get("ok", false),
		"every committed entry child validates through the production issuer")
	assert_true((issuer.validate_child(receipt["receipt_provenance"], &"schedule_commit") as Dictionary).get("ok", false),
		"the aggregate commit child validates through the production issuer")

	# Detached candidate law: caller mutation of the returned bytes never reaches the port's memo.
	var stolen: Dictionary = (prepared["value"] as Dictionary)["committed_schedule"]
	stolen["day"] = 99
	var replayed: Dictionary = (wired["schedule_port"] as Object).prepare_commit(driven["request"])
	assert_true(replayed.get("ok", false), JSON.stringify(replayed))
	assert_eq(int(((replayed["value"] as Dictionary)["committed_schedule"] as Dictionary)["day"]), DAY,
		"an identical replay returns the original detached bytes, untouched by caller mutation")


func test_a03_day7_empty_done_provenance_matches_the_frozen_contract() -> void:
	var wired := _wired(7)
	var txn := _mint_transaction(wired["issuer"])
	var request := _schedule_request(wired, txn, [], 7)
	var prepared: Dictionary = (wired["schedule_port"] as Object).prepare_commit(request)
	if not _require_ok(prepared, "the real Day-7 empty-Done prepare"):
		return
	var result: Dictionary = (wired["day7_provenance"] as Object).validate_handoff({
		"transaction_id": txn["transaction_id"],
		"transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": (prepared["value"] as Dictionary)["committed_schedule"],
		"source_receipt_index": {},
	})
	_assert_guard_accepts(GUARD.validate_day7_provenance_result(result),
		"validate_day7_provenance_result over a real empty-Done handoff")

	_assert_success_shape(result, "validate_handoff")
	assert_eq(_keys_of(result["value"]), ["terminal_provenance"],
		"success value is exactly {terminal_provenance}")
	var terminal: Dictionary = (result["value"] as Dictionary)["terminal_provenance"]
	assert_eq(result["receipt"], terminal,
		"the outer receipt is an exact detached copy of terminal provenance")
	assert_eq(_keys_of(terminal), DAY7_TERMINAL_KEYS, "the terminal provenance member set is exact")
	assert_eq(str(terminal["kind"]), "day7_schedule_provenance", "kind is frozen")
	assert_eq(int(terminal["day"]), 7, "day is 7")
	assert_eq(str(terminal["cause"]), "empty_done", "an empty receipted Done is cause empty_done")
	assert_null(terminal["schedule_entry_id"], "empty Done leaves schedule_entry_id null")
	assert_null(terminal["action_id"], "empty Done leaves action_id null")
	assert_null(terminal["source_receipt_id"], "empty Done leaves source_receipt_id null")
	assert_true(((wired["issuer"] as Object).validate_child(terminal["receipt_provenance"], &"day7_schedule_provenance") as Dictionary).get("ok", false),
		"the receipt is the configured issuer's validated day7_schedule_provenance child")

	# Detached receipt law: mutating the returned value copy never reaches the receipt copy.
	terminal["cause"] = "tampered"
	assert_eq(str((result["receipt"] as Dictionary)["cause"]), "empty_done",
		"the outer receipt is detached from the value copy")


func test_a04_schedule_done_causal_reservation_matches_the_frozen_contract() -> void:
	var wired := _wired()
	var driven := _prepare_day3_schedule(wired)
	var prepared: Dictionary = driven["prepared"]
	if not _require_ok(prepared, "the Schedule prepare whose receipt seeds the reservation"):
		return
	var schedule_receipt: Dictionary = (prepared["value"] as Dictionary)["schedule_commit_receipt"]
	var request := _schedule_done_reservation_request(driven["txn"], schedule_receipt)
	var reserved: Dictionary = (wired["causal_sequence_port"] as Object).prepare_reservation(request)
	_assert_guard_accepts(GUARD.validate_causal_reservation_result(reserved),
		"validate_causal_reservation_result over a real schedule_done reservation")

	_assert_success_shape(reserved, "prepare_reservation")
	assert_eq(_keys_of(reserved["value"]), RESERVATION_VALUE_KEYS,
		"success value is exactly {sequence_candidate, causal_sequence_receipt}")
	var receipt: Dictionary = (reserved["value"] as Dictionary)["causal_sequence_receipt"]
	assert_eq(reserved["receipt"], receipt,
		"the outer receipt is an exact detached copy of causal_sequence_receipt")
	assert_eq(_keys_of(receipt), SEQUENCE_RECEIPT_KEYS, "the sequence receipt member set is exact")
	assert_eq(int(receipt["causal_sequence"]), 1, "prepare proposes exactly expected_last_sequence + 1")
	assert_eq(int(receipt["run_revision"]), 1, "prepare proposes exactly expected_run_revision + 1")
	assert_eq(str(receipt["source_kind"]), "schedule_done", "the source kind is carried exactly")
	assert_eq(str(receipt["source_commit_receipt_id"]), str(schedule_receipt["receipt_id"]),
		"Schedule departure reserves only from the issued Schedule commit receipt")
	var live: Dictionary = ((wired["consequence_state"] as Object).capture()["value"] as Dictionary)["state"]
	assert_eq(int(live["causal_sequence"]), 0, "reservation is pure: no sequence is allocated yet")
	assert_eq(int(live["run_revision"]), 0, "reservation is pure: no revision is allocated yet")

	# Detached candidate law: caller mutation never reaches the retained reservation.
	receipt["causal_sequence"] = 99
	var replayed: Dictionary = (wired["causal_sequence_port"] as Object).prepare_reservation(request)
	assert_true(replayed.get("ok", false), JSON.stringify(replayed))
	assert_eq(int(((replayed["value"] as Dictionary)["causal_sequence_receipt"] as Dictionary)["causal_sequence"]), 1,
		"an identical replay returns the original detached bytes")


func test_a05_causal_admission_binds_reservation_checkpoint_and_payload_hash() -> void:
	var wired := _wired()
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
	var prepared := _shop_prepared(wired, "lucky_charm")
	var action_receipt: Dictionary = prepared["action_receipt"]
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


func test_a10_day_resolution_start_matches_the_frozen_contract() -> void:
	var wired := _wired()
	var driven := _prepare_day3_schedule(wired)
	var prepared: Dictionary = driven["prepared"]
	if not _require_ok(prepared, "the Schedule prepare feeding the day-resolution start"):
		return
	var value: Dictionary = prepared["value"]
	var fate: Dictionary = (wired["board_fate_port"] as Object).prepare_causal_departure(
		_schedule_fate_request(wired, _mint_transaction(wired["issuer"])))
	if not _require_ok(fate, "the board-fate prepare feeding the day-resolution start"):
		return
	var txn: Dictionary = driven["txn"]
	var result: Dictionary = (wired["day_start_port"] as Object).prepare_from_committed_schedule({
		"resolution_id": txn["transaction_id"],
		"resolution_issuer_receipt": txn["transaction_issuer_receipt"],
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": value["committed_schedule"],
		"route_plan": value["route_plan"],
		"board_fate_receipt": (fate["value"] as Dictionary)["board_fate_receipt"],
	})
	_assert_guard_accepts(GUARD.validate_day_resolution_start_result(result),
		"validate_day_resolution_start_result over a real start preparation")

	_assert_success_shape(result, "prepare_from_committed_schedule")
	# SHIPPED-shape characterization per DEVIATION-18 Ruling 18-A (2026-09-02, dwm-oyo.3): the
	# consumed-interface-lock value/receipt shapes are deferred to the first consuming task
	# (Task 6/7); until then this net freezes the surface production actually ships.
	assert_eq(_keys_of(result["value"]), DAY_START_VALUE_KEYS,
		"the shipped success value is exactly {start_receipt, committed_schedule, route_plan, schedule_commit_receipt_id, board_fate_receipt_id}")
	var receipt: Dictionary = result["receipt"]
	assert_eq(receipt, (result["value"] as Dictionary)["start_receipt"],
		"the outer receipt is an exact detached copy of start_receipt")
	assert_eq(_keys_of(receipt), DAY_START_RECEIPT_KEYS,
		"the shipped start receipt carries exactly its eight frozen members")
	assert_eq(str(receipt.get("resolution_id", "")), str(txn["transaction_id"]),
		"the start shares the Schedule transaction's own verified root; no second root is issued")


## Review-fix (Minor 3): the nonnull direction of the board-fate -1-iff-null identity law needs a
## real green driver -- a materialized, STARTED board (the completion suite's own arm/reveal
## pattern, test_desktop_completion_transaction.gd lines 110-183) whose schedule_done departure
## returns the live nonnull identity and nonnegative revision through the guard.
func test_a11_board_fate_forfeits_a_started_board_with_nonnull_identity() -> void:
	var wired := _wired()
	var round_coordinator: Object = wired["round_coordinator"]
	var mine_indices: Array[int] = [1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
	(round_coordinator._generation_port as Object).arm_materialize({"schema_version": 1,
		"width": 9, "height": 9, "mine_indices": mine_indices, "mine_count": mine_indices.size()})
	var identity: Dictionary = round_coordinator.get_entry_context("beginner")["value"]["identity"]
	var reveal_txn := _mint_transaction(wired["issuer"])
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


## Review-fix (Minor 2): the scheduled_solo (trio-nonnull) branch of the Day-7 provenance law
## needs a real green driver -- a Day-7 commit of one eligible slot-zero solo destination
## (solo:lavinia:day7, allowed_days [7] in the real manifest) whose source receipt is the
## registered read/acceptance ancestor seeded through the production Contacts module, resolved
## through the REAL contacts schedule_source_receipts index. No fake manufactures anything here.
func test_a12_day7_scheduled_solo_provenance_binds_the_nonnull_trio() -> void:
	var wired := _wired(7)
	var action_id := "solo:lavinia:day7"
	var source_receipt_id := _seed_solo_source(wired, "lavinia", action_id, 7)
	var txn := _mint_transaction(wired["issuer"])
	var request := _schedule_request(wired, txn, [{
		"draft_entry_id": "d-lav7", "day": 7, "slot_index": 0, "action_id": action_id,
		"action_kind": "solo", "participants": ["lavinia"], "source_receipt_id": source_receipt_id,
	}], 7)
	var prepared: Dictionary = (wired["schedule_port"] as Object).prepare_commit(request)
	if not _require_ok(prepared, "the real Day-7 one-solo prepare"):
		return
	var source_index: Dictionary = ((wired["gs"] as Node).contacts as Dictionary) 		.get("schedule_source_receipts", {})
	assert_true(source_index.has(source_receipt_id),
		"the production Contacts index holds the seeded read/acceptance ancestor")
	var result: Dictionary = (wired["day7_provenance"] as Object).validate_handoff({
		"transaction_id": txn["transaction_id"],
		"transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": (prepared["value"] as Dictionary)["committed_schedule"],
		"source_receipt_index": source_index,
	})
	_assert_guard_accepts(GUARD.validate_day7_provenance_result(result),
		"validate_day7_provenance_result over a real scheduled-solo handoff")
	_assert_success_shape(result, "validate_handoff (scheduled solo)")
	var terminal: Dictionary = (result["value"] as Dictionary)["terminal_provenance"]
	assert_eq(str(terminal["cause"]), "scheduled_solo",
		"one eligible slot-zero solo is cause scheduled_solo")
	var entry: Dictionary = (((prepared["value"] as Dictionary)["committed_schedule"]
		as Dictionary)["entries"] as Array)[0]
	assert_eq(str(terminal["schedule_entry_id"]), str(entry["schedule_entry_id"]),
		"the nonnull trio names the exact committed entry")
	assert_eq(str(terminal["action_id"]), action_id, "...its exact registry destination")
	assert_eq(str(terminal["source_receipt_id"]), source_receipt_id,
		"...and the registered read/acceptance ancestor for that destination")
	assert_true(((wired["issuer"] as Object).validate_child(terminal["receipt_provenance"], &"day7_schedule_provenance") as Dictionary).get("ok", false),
		"the scheduled-solo receipt is the issuer's validated day7_schedule_provenance child")


# -------------------------------------------------------------------------------------------------
# b: one-field-at-a-time refusals -- exact code, exact failure envelope, byte-identical graph.
# -------------------------------------------------------------------------------------------------

func test_b01_schedule_prepare_commit_refuses_a_missing_member_without_mutation() -> void:
	var wired := _wired()
	var built := _valid_day3_request(wired)
	var request: Dictionary = (built["request"] as Dictionary).duplicate(true)
	request.erase("registry_fingerprint")
	var before := _graph_snapshot(wired)
	var refused: Dictionary = (wired["schedule_port"] as Object).prepare_commit(request)
	_assert_guarded_refusal(GUARD.validate_schedule_result(refused), refused,
		&"invalid_schedule_commit_request", "prepare_commit missing registry_fingerprint")
	assert_eq(_graph_snapshot(wired), before, "a refused prepare mutates nothing")


func test_b02_schedule_prepare_commit_refuses_an_extra_member_without_mutation() -> void:
	var wired := _wired()
	var built := _valid_day3_request(wired)
	var request: Dictionary = (built["request"] as Dictionary).duplicate(true)
	request["route_plan"] = []
	var before := _graph_snapshot(wired)
	var refused: Dictionary = (wired["schedule_port"] as Object).prepare_commit(request)
	_assert_guarded_refusal(GUARD.validate_schedule_result(refused), refused,
		&"invalid_schedule_commit_request", "prepare_commit with an extra route_plan member")
	assert_eq(_graph_snapshot(wired), before, "a refused prepare mutates nothing")


func test_b03_schedule_prepare_commit_refuses_a_stale_registry_fingerprint_without_mutation() -> void:
	var wired := _wired()
	var built := _valid_day3_request(wired)
	var request: Dictionary = (built["request"] as Dictionary).duplicate(true)
	request["registry_fingerprint"] = "0".repeat(64)
	var before := _graph_snapshot(wired)
	var refused: Dictionary = (wired["schedule_port"] as Object).prepare_commit(request)
	_assert_guarded_refusal(GUARD.validate_schedule_result(refused), refused,
		&"stale_registry_fingerprint", "prepare_commit against a stale registry fingerprint")
	assert_eq(_graph_snapshot(wired), before, "a refused prepare mutates nothing")


func test_b04_schedule_prepare_commit_refuses_caller_supplied_route_effect_and_cost() -> void:
	var wired := _wired()
	var built := _valid_day3_request(wired)
	var before := _graph_snapshot(wired)
	# Route, effects, and cost come only from the immutable versioned registry (global constraint):
	# a draft entry that tries to carry any of them is malformed by ScheduleRules' exact DRAFT_KEYS.
	for forbidden: String in ["route", "effects", "cost"]:
		var request: Dictionary = (built["request"] as Dictionary).duplicate(true)
		var entry: Dictionary = (request["draft_entries"] as Array)[0]
		entry[forbidden] = "caller-supplied"
		var refused: Dictionary = (wired["schedule_port"] as Object).prepare_commit(request)
		_assert_guarded_refusal(GUARD.validate_schedule_result(refused), refused,
			&"invalid_draft_entry", "prepare_commit with a caller-supplied %s member" % forbidden)
	assert_eq(_graph_snapshot(wired), before, "route/effect/cost refusals mutate nothing")


func test_b05_board_fate_accepts_only_its_own_request_shape_and_reason() -> void:
	var wired := _wired()
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
	var request := _schedule_fate_request(wired, _mint_transaction(wired["issuer"]))
	request["expected_board_revision"] = int(request["expected_board_revision"]) + 7
	var before := _graph_snapshot(wired)
	var refused: Dictionary = (wired["board_fate_port"] as Object).prepare_causal_departure(request)
	_assert_guarded_refusal(GUARD.validate_board_fate_result(refused), refused,
		&"board_fate_stale_revision", "prepare_causal_departure with a stale expected_board_revision")
	assert_eq(_graph_snapshot(wired), before, "a stale-revision refusal mutates nothing")


func test_b07_board_fate_refuses_a_wrong_causal_day_without_mutation() -> void:
	var wired := _wired()
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


func test_b09_causal_reservation_refuses_shape_and_stale_expectation_mutations() -> void:
	var wired := _wired()
	var driven := _prepare_day3_schedule(wired)
	var prepared: Dictionary = driven["prepared"]
	if not _require_ok(prepared, "the Schedule prepare whose receipt seeds the reservation"):
		return
	var schedule_receipt: Dictionary = (prepared["value"] as Dictionary)["schedule_commit_receipt"]
	var port: Object = wired["causal_sequence_port"]
	var before := _graph_snapshot(wired)

	var missing := _schedule_done_reservation_request(driven["txn"], schedule_receipt)
	missing.erase("source_kind")
	var refused_missing: Dictionary = port.prepare_reservation(missing)
	_assert_guarded_refusal(GUARD.validate_causal_reservation_result(refused_missing), refused_missing,
		&"causal_reservation_request_invalid", "prepare_reservation missing source_kind")

	var extra := _schedule_done_reservation_request(driven["txn"], schedule_receipt)
	extra["route_plan"] = []
	var refused_extra: Dictionary = port.prepare_reservation(extra)
	_assert_guarded_refusal(GUARD.validate_causal_reservation_result(refused_extra), refused_extra,
		&"causal_reservation_request_invalid", "prepare_reservation with an extra route_plan member")

	var stale_sequence := _schedule_done_reservation_request(driven["txn"], schedule_receipt)
	stale_sequence["expected_last_sequence"] = 5
	var refused_sequence: Dictionary = port.prepare_reservation(stale_sequence)
	_assert_guarded_refusal(GUARD.validate_causal_reservation_result(refused_sequence), refused_sequence,
		&"causal_sequence_stale", "prepare_reservation with a stale expected_last_sequence")

	var stale_revision := _schedule_done_reservation_request(driven["txn"], schedule_receipt)
	stale_revision["expected_run_revision"] = 5
	var refused_revision: Dictionary = port.prepare_reservation(stale_revision)
	_assert_guarded_refusal(GUARD.validate_causal_reservation_result(refused_revision), refused_revision,
		&"run_revision_stale", "prepare_reservation with a stale expected_run_revision")

	assert_eq(_graph_snapshot(wired), before, "every reservation refusal mutates nothing")


func test_b10_day7_provenance_refuses_shape_mutations_and_a_non_day7_commit() -> void:
	var wired := _wired()
	var driven := _prepare_day3_schedule(wired)
	var prepared: Dictionary = driven["prepared"]
	if not _require_ok(prepared, "the Day-3 Schedule prepare feeding the Day-7 refusals"):
		return
	var txn: Dictionary = driven["txn"]
	var provenance: Object = wired["day7_provenance"]
	var base := {
		"transaction_id": txn["transaction_id"],
		"transaction_issuer_receipt": txn["transaction_issuer_receipt"],
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": (prepared["value"] as Dictionary)["committed_schedule"],
		"source_receipt_index": {},
	}
	var before := _graph_snapshot(wired)

	var refused_day: Dictionary = provenance.validate_handoff(base.duplicate(true))
	_assert_guarded_refusal(GUARD.validate_day7_provenance_result(refused_day), refused_day,
		&"invalid_day7_handoff", "a Day-3 commit offered as the Day-7 handoff")

	var missing: Dictionary = base.duplicate(true)
	missing.erase("source_receipt_index")
	var refused_missing: Dictionary = provenance.validate_handoff(missing)
	_assert_guarded_refusal(GUARD.validate_day7_provenance_result(refused_missing), refused_missing,
		&"invalid_day7_handoff", "validate_handoff missing source_receipt_index")

	var extra: Dictionary = base.duplicate(true)
	extra["terminal_provenance"] = {}
	var refused_extra: Dictionary = provenance.validate_handoff(extra)
	_assert_guarded_refusal(GUARD.validate_day7_provenance_result(refused_extra), refused_extra,
		&"invalid_day7_handoff", "validate_handoff with an extra terminal_provenance member")

	assert_eq(_graph_snapshot(wired), before, "every handoff refusal mutates nothing")


func test_b11_day_resolution_start_refuses_shape_mutations_and_a_wrong_causal_day() -> void:
	var wired := _wired()
	var driven := _prepare_day3_schedule(wired)
	var prepared: Dictionary = driven["prepared"]
	if not _require_ok(prepared, "the Schedule prepare feeding the start refusals"):
		return
	var value: Dictionary = prepared["value"]
	var fate: Dictionary = (wired["board_fate_port"] as Object).prepare_causal_departure(
		_schedule_fate_request(wired, _mint_transaction(wired["issuer"])))
	if not _require_ok(fate, "the board-fate prepare feeding the start refusals"):
		return
	var txn: Dictionary = driven["txn"]
	var base := {
		"resolution_id": txn["transaction_id"],
		"resolution_issuer_receipt": txn["transaction_issuer_receipt"],
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": value["committed_schedule"],
		"route_plan": value["route_plan"],
		"board_fate_receipt": (fate["value"] as Dictionary)["board_fate_receipt"],
	}
	var port: Object = wired["day_start_port"]
	var before := _graph_snapshot(wired)

	var missing: Dictionary = base.duplicate(true)
	missing.erase("route_plan")
	var refused_missing: Dictionary = port.prepare_from_committed_schedule(missing)
	_assert_guarded_refusal(GUARD.validate_day_resolution_start_result(refused_missing), refused_missing,
		&"invalid_day_resolution_start", "prepare_from_committed_schedule missing route_plan")

	var extra: Dictionary = base.duplicate(true)
	extra["resolution_plan"] = []
	var refused_extra: Dictionary = port.prepare_from_committed_schedule(extra)
	_assert_guarded_refusal(GUARD.validate_day_resolution_start_result(refused_extra), refused_extra,
		&"invalid_day_resolution_start", "prepare_from_committed_schedule with an extra member")

	# Consumed-interface-lock safety law, implemented additively under DEVIATION-18 Ruling 18-A:
	# a causal day different from the committed Schedule's own refuses with its exact code.
	var wrong_day: Dictionary = base.duplicate(true)
	wrong_day["causal_day_instance"] = "causal-day-OTHER"
	var refused_day: Dictionary = port.prepare_from_committed_schedule(wrong_day)
	_assert_guarded_refusal(GUARD.validate_day_resolution_start_result(refused_day), refused_day,
		&"day_resolution_causal_day_mismatch",
		"a causal_day_instance different from the committed Schedule's own")

	# Ruling 18-A's second safety law: resolution_id must equal the verified root's own token.
	var foreign_id: Dictionary = base.duplicate(true)
	foreign_id["resolution_id"] = "not-the-issued-token"
	var refused_id: Dictionary = port.prepare_from_committed_schedule(foreign_id)
	_assert_guarded_refusal(GUARD.validate_day_resolution_start_result(refused_id), refused_id,
		&"day_resolution_id_mismatch", "a resolution_id that is not the issued token")

	assert_eq(_graph_snapshot(wired), before, "every start refusal mutates nothing (prepare is pure)")
