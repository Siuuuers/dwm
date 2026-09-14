extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

# dwm-p2r.32 Plan 02 Task 9. The Lucky/Debug/Supportz/round-completion action matrix, driven
# through the REAL ApplicationBootstrap._configure_desktop_production_graph() wiring (Phase 1)
# rather than a separately hand-wired stack -- this is what makes it "the production graph" proof
# rather than a repeat of Task 7/8's own already-existing coverage against their own wiring.
#
# HONEST FINDING FROM THIS SUITE (recorded in the Task-9 report and both evidence documents):
# every row that would go on to spend currency, grant a capability, admit a causal transaction, or
# materialize a board is fail-closed through the real production graph, not just the round
# coordinator's reveal()/complete_round(). MinesweeperShopPurchaseParticipant._build_action_receipt()
# reads run_id/branch_id/desktop_timeline_generation/causal_day_instance from
# GameStateMinesweeperShopPort.capture()'s facts -- the SAME boot-time placeholder identity context
# gap 2 already named -- never from DesktopConsequenceState's own live causal_day_instance, so even
# a fully seeded, otherwise-valid DesktopConsequenceState cannot make prepare_purchase() succeed:
# DesktopActionReceipt.validate() rejects the blank causal_day_instance every time. quote() itself
# is unaffected (it never reads the identity context), so registry/price/currency/quote_id
# contracts remain genuinely provable and are proven below.
#
# This matrix proves the REJECTION for every row a gap blocks, rather than fabricating a success --
# exactly the "prove the fail-closed behavior rather than wiring a fake" instruction this task was
# given. Each row is also independent proof (alongside test_desktop_simulator_authority.gd) that
# both honest gaps cannot silently regress into a fake: if either gap were ever "fixed" by quietly
# wiring a stub instead of a real adapter, the corresponding row here would start passing with a
# fabricated result and a reviewer auditing this file would see the row's own status comment lie.

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")
const DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


var _bootstrap: Node = null
var _game_state: Node = null
var _root_counter := 0
var _root := ""


func _isolated_root() -> String:
	_root_counter += 1
	var result: Dictionary = TEMPORARY_STORAGE.create("desktop-action-matrix-%d" % _root_counter)
	assert_true(result.get("ok", false), result.get("message", ""))
	return str(result.get("value", "")) if result.get("ok", false) else ""


func before_each() -> void:
	_root = _isolated_root()
	if _root.is_empty():
		return
	assert_true(SHOP_REGISTRY.initialize().get("ok", false), "shop registry must load")
	var storage: RefCounted = JSON_STORAGE.new(_root.path_join("profile"))
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))

	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	_game_state.money = 1000
	_game_state.coins = 100
	var state_port: RefCounted = STATE_PORT.new(_game_state)
	var coordinator: RefCounted = COORDINATOR.new()

	_bootstrap = HarnessBootstrap.new()
	autofree(_bootstrap)
	_bootstrap.set("_profile_storage", storage)
	_bootstrap.set("_desktop_issuer_root_store", root_store)
	_bootstrap.set("_desktop_identity_nonce_issuer", issuer)
	_bootstrap.set("_retained_day_resolution_state_port", state_port)
	_bootstrap.set("_retained_day_resolution_coordinator", coordinator)

	var profile: Node = load("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var localization: Node = load("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	var audio: Node = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(audio)
	var bridge: Node = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	var router: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(router)
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(_root.path_join("saves"))).get("ok", false))
	assert_true(save_manager.call(&"configure_identity_issuer", issuer).get("ok", false))
	var allocation_participant: RefCounted = DESKTOP_IDENTITY_ALLOCATION_RESTORE_PARTICIPANT.new(issuer, save_manager)
	assert_true(save_manager.call(&"configure_identity_allocation_participant", allocation_participant).get("ok", false))
	_bootstrap.set("_desktop_identity_allocation_participant", allocation_participant)

	_bootstrap.set("targets", {
		"ProfileManager": profile, "LocalizationManager": localization, "AudioManager": audio,
		"DialogicBridge": bridge, "SceneRouter": router, "GameState": _game_state,
		"SaveManager": save_manager,
	})

	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	_bootstrap.set("_application_gate", gate)
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	_bootstrap.set("_retained_checkpoint_port", checkpoint_port)

	assert_true(_bootstrap.call(&"_configure_causal_day_advance_identity", coordinator).get("ok", false))
	assert_true(_bootstrap.call(&"_construct_schedule_foundation", _game_state, state_port).get("ok", false))
	assert_true(_bootstrap.call(&"_configure_restore_participants").get("ok", false))
	var graph_result: Dictionary = _bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(graph_result.get("ok", false), "desktop production graph: " + str(graph_result))

	# This harness boots the desktop graph PARTIALLY by design, and the dwm-oyo.3 Plan-03 composition
	# early-outs accordingly. That skip must be REPORTED, never silent -- so the stage's two composed
	# flags are pinned against the probe's own instance ids here. Nothing else read these flags, which
	# is exactly how a report drifts into decoration; the invariant holds on the full path too.
	var graph_value: Dictionary = graph_result["value"]
	assert_eq(bool(graph_value["presentation_producer_composed"]),
		int(graph_value["desktop_consequence_source_port_instance_id"]) != 0,
		"presentation_producer_composed must never disagree with the retained instance id")
	assert_eq(bool(graph_value["schedule_done_dispatcher_composed"]),
		int(graph_value["schedule_done_dispatcher_instance_id"]) != 0,
		"schedule_done_dispatcher_composed must never disagree with the retained instance id")

	# Seed the retained DesktopConsequenceState with a real, nonblank causal_day_instance of its
	# OWN -- proving the gap below is specifically about GameStateMinesweeperShopPort's facts, not
	# merely "nobody seeded anything anywhere". DesktopConsequenceState's own provenance check is
	# purely structural (no root/issuer cross-check), so a hand-built fixture receipt is legitimate
	# here, matching tests/integration/test_desktop_completion_transaction.gd's own established
	# pattern -- causal_day_instance is allocator-only and issuer.issue() itself refuses it directly.
	var day_receipt := {"receipt_id": "issuer_receipt.fixture-causal-day-matrix",
		"purpose": "causal_day_instance", "namespace": "fixturenamespace", "counter": 1,
		"token": "causal-day-matrix", "numeric_value": null}
	var consequence_state: Object = _bootstrap.get("_desktop_consequence_state")
	var made: Dictionary = CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": str(day_receipt["token"]), "causal_day_instance_issuer_receipt": day_receipt,
	})
	assert_true(made.get("ok", false), JSON.stringify(made))
	var prepared_state: Dictionary = consequence_state.prepare_restore((made["value"] as Dictionary)["state"])
	assert_true(prepared_state.get("ok", false), JSON.stringify(prepared_state))
	assert_true(consequence_state.commit((prepared_state["value"] as Dictionary)["candidate"]).get("ok", false))


func _mint(issuer: Object, purpose: StringName) -> Dictionary:
	var issued: Dictionary = issuer.call(&"issue", purpose)
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	var value: Dictionary = issued["value"]
	return {"token": str(value["token"]), "receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _shop_participant() -> Object:
	return _bootstrap.get("_retained_minesweeper_shop_purchase_participant")


func _issuer() -> Object:
	return _bootstrap.get("_desktop_identity_nonce_issuer")


func _quote(item_id: String) -> Dictionary:
	var quote_txn := _mint(_issuer(), &"transaction_id")
	return _shop_participant().quote(item_id, quote_txn["token"], quote_txn["receipt"])


# -------------------------------------------------------------------------------------------------
# rows 1-3: quote() -- registry/price/currency/quote_id contracts are genuinely proven (quote()
# never reads the placeholder identity context)
# -------------------------------------------------------------------------------------------------

func test_row_shop_lucky_charm_quote_matches_the_registry_record() -> void:
	if _root.is_empty():
		return
	var record: Dictionary = (SHOP_REGISTRY.get_record(&"lucky_charm")["value"] as Dictionary)["record"]
	var quoted: Dictionary = _quote("lucky_charm")
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var value: Dictionary = quoted["value"]
	assert_eq(str(value["currency"]), str(record["currency"]))
	assert_eq(int(value["price"]), int(record["price"]))
	assert_eq(int(record["price"]), 1)


func test_row_shop_debug_key_quote_matches_the_registry_record() -> void:
	if _root.is_empty():
		return
	var record: Dictionary = (SHOP_REGISTRY.get_record(&"debug_key")["value"] as Dictionary)["record"]
	var quoted: Dictionary = _quote("debug_key")
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var value: Dictionary = quoted["value"]
	assert_eq(str(value["currency"]), str(record["currency"]))
	assert_eq(int(value["price"]), int(record["price"]))
	assert_eq(int(record["price"]), 3)


func test_row_shop_supportz_quote_matches_the_registry_record_and_structured_cap() -> void:
	if _root.is_empty():
		return
	var record: Dictionary = (SHOP_REGISTRY.get_record(&"supportz")["value"] as Dictionary)["record"]
	var quoted: Dictionary = _quote("supportz")
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var value: Dictionary = quoted["value"]
	assert_eq(str(value["currency"]), str(record["currency"]))
	assert_eq(int(value["price"]), int(record["price"]))
	assert_eq(int(record["price"]), 45)
	var cap: Dictionary = record["cap"]
	assert_eq(int(cap["per_causal_day"]), 1)
	assert_eq(int(cap["per_branch"]), 3)


# -------------------------------------------------------------------------------------------------
# rows 4-6: prepare_purchase() is fail-closed for every item through the real production graph
# (honest gap 2, concretely: GameStateMinesweeperShopPort's placeholder causal_day_instance)
# -------------------------------------------------------------------------------------------------

func test_row_shop_lucky_charm_prepare_purchase_is_fail_closed() -> void:
	if _root.is_empty():
		return
	_assert_prepare_purchase_fails_closed_on_the_placeholder_identity("lucky_charm")


func test_row_shop_debug_key_prepare_purchase_is_fail_closed() -> void:
	if _root.is_empty():
		return
	_assert_prepare_purchase_fails_closed_on_the_placeholder_identity("debug_key")


## Supportz fails one step earlier than Lucky/Debug: its own eligibility check
## (_validate_supportz_eligibility(), which also reads GameStateMinesweeperShopPort's facts) runs
## BEFORE _build_action_receipt() and rejects first -- a different observable code
## (supportz_not_eligible) for the identical underlying gap, so this row is asserted separately
## rather than forced through the shared helper's action_receipt_field_invalid expectation.
func test_row_shop_supportz_prepare_purchase_is_fail_closed() -> void:
	if _root.is_empty():
		return
	var issuer := _issuer()
	var shop := _shop_participant()
	var money_before: int = _game_state.money
	var floor_before: int = _game_state.minesweeper_round_floor
	var quote_txn := _mint(issuer, &"transaction_id")
	var quoted: Dictionary = shop.quote("supportz", quote_txn["token"], quote_txn["receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live: Dictionary = (_bootstrap.get("_desktop_consequence_state").call(&"capture")["value"] as Dictionary)["state"]
	var prepared: Dictionary = shop.prepare_purchase({
		"transaction_id": quote_txn["token"], "transaction_issuer_receipt": quote_txn["receipt"],
		"item_id": "supportz", "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	})
	assert_false(prepared.get("ok", false), "prepare_purchase must fail closed, never fabricate a purchase")
	assert_eq(prepared.get("code"), &"supportz_not_eligible")
	assert_eq(_game_state.money, money_before, "money must be untouched")
	assert_eq(_game_state.minesweeper_round_floor, floor_before, "the capacity floor must be untouched")


func _assert_prepare_purchase_fails_closed_on_the_placeholder_identity(item_id: String) -> void:
	var issuer := _issuer()
	var shop := _shop_participant()
	var money_before: int = _game_state.money
	var coins_before: int = _game_state.coins
	var quote_txn := _mint(issuer, &"transaction_id")
	var quoted: Dictionary = shop.quote(item_id, quote_txn["token"], quote_txn["receipt"])
	assert_true(quoted.get("ok", false), JSON.stringify(quoted))
	var live: Dictionary = (_bootstrap.get("_desktop_consequence_state").call(&"capture")["value"] as Dictionary)["state"]
	assert_eq(str(live["causal_day_instance"]), "causal-day-matrix",
		"DesktopConsequenceState's OWN causal_day_instance is real and seeded")
	var prepared: Dictionary = shop.prepare_purchase({
		"transaction_id": quote_txn["token"], "transaction_issuer_receipt": quote_txn["receipt"],
		"item_id": item_id, "quote_id": str((quoted["value"] as Dictionary)["quote_id"]),
		"expected_run_revision": int(live["run_revision"]), "expected_causal_day_instance": str(live["causal_day_instance"]),
	})
	assert_false(prepared.get("ok", false),
		item_id + ": prepare_purchase must fail closed, never fabricate a purchase")
	assert_eq(prepared.get("code"), &"action_receipt_field_invalid", item_id)
	assert_eq(str((prepared.get("details", {}) as Dictionary).get("field", "")), "causal_day_instance", item_id)
	# No partial mutation: a rejected prepare never spends currency or grants anything.
	assert_eq(_game_state.money, money_before, item_id + ": money must be untouched")
	assert_eq(_game_state.coins, coins_before, item_id + ": coins must be untouched")
	assert_false(_game_state.inventory.has(item_id), item_id + ": no capability granted")


# -------------------------------------------------------------------------------------------------
# row 7: minesweeper.round.complete_round -- fail-closed (honest gap 1: no production generation_
# port/checkpoint_port adapter, so the round coordinator's own base configure() is never called)
# -------------------------------------------------------------------------------------------------

func test_row_minesweeper_round_complete_round_is_fail_closed() -> void:
	if _root.is_empty():
		return
	var round_coordinator: Object = _bootstrap.get("_retained_minesweeper_round_coordinator_app")
	assert_null(round_coordinator.get("_state_port"),
		"the production graph never calls the round coordinator's own base configure() " \
		+ "(honest gap: no production generation_port/checkpoint_port adapter exists)")
	var issuer := _issuer()
	var txn := _mint(issuer, &"transaction_id")
	var rejected: Dictionary = round_coordinator.complete_round({
		"transaction_id": txn["token"], "transaction_issuer_receipt": txn["receipt"],
		"expected_identity": {}, "expected_revision": 0, "expected_run_revision": 0,
	})
	assert_false(rejected.get("ok", false), "complete_round() must fail closed, never fabricate a completion")


# -------------------------------------------------------------------------------------------------
# row 8: minesweeper.round.reveal -- fail-closed for the identical reason
# -------------------------------------------------------------------------------------------------

func test_row_minesweeper_round_reveal_is_fail_closed() -> void:
	if _root.is_empty():
		return
	var round_coordinator: Object = _bootstrap.get("_retained_minesweeper_round_coordinator_app")
	assert_null(round_coordinator.get("_generation_port"))
	assert_null(round_coordinator.get("_checkpoint_port"))
	var issuer := _issuer()
	var txn := _mint(issuer, &"transaction_id")
	var rejected: Dictionary = round_coordinator.reveal({
		"transaction_id": txn["token"], "transaction_issuer_receipt": txn["receipt"],
		"expected_identity": {}, "expected_revision": 0, "difficulty_id": "beginner", "cell_index": 0,
	})
	assert_false(rejected.get("ok", false), "reveal() must fail closed, never fabricate a board")
