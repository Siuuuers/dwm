extends "res://addons/gut/test.gd"
# Same-boot desktop/Schedule foundation identity (Plan 01 Task 8 Step 8.1, dwm-p2r.14).
#
# WHY THIS FILE EXISTS NOW. Plan 01 Task 8 names `tests/integration/test_desktop_bootstrap_wiring.gd`
# in both its RED and GREEN gate command lines, but the file had never been authored on any branch
# (DEVIATION-2 on dwm-p2r.14: `.9` shipped at a narrower scope than Plan 02 chartered). Task 8 needs
# it, so Task 8 writes it.
#
# WHAT IT OWNS. `ApplicationBootstrap.get_desktop_contract_state()` -- the read-only probe Step 8.1
# requires -- and the law it exists to enforce: composing the presentation layer must not
# reconstruct, swap, or fake any foundation instance. The probe is captured BEFORE presentation
# configuration and compared afterwards, which is the only way a silently rebuilt issuer or ledger
# would ever be caught.
#
# WHY IT MUST BE INTEGERS ONLY. A probe that returned live Objects would itself be the leak it is
# meant to detect: any caller could reach in and take an owner. Every value below is an int or a
# bool, and one test asserts exactly that.
#
# THESE NUMBERS ARE PROCESS-LOCAL. They are meaningless across runs. Nothing here compares them to a
# prior run or to a committed evidence file -- only to another reading from this same boot.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const CONTACT_COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
## dwm-p2r.32 Plan 02 Task 9 additions below: the one production desktop board/consequence/causal
## graph, built and probed against the SAME harness/foundation helpers Plan 01 Task 8 established
## above -- extending this file rather than creating a second one, since
## `ApplicationBootstrap.get_desktop_contract_state()` is the ONE probe both plans read.
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const MINESWEEPER_ROUND_COORDINATOR_APP := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const MINESWEEPER_SHOP_PURCHASE_PARTICIPANT := preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd")
const DESKTOP_CONSEQUENCE_COORDINATOR := preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")

const EXPECTED_RESTORE_ORDER: Array[StringName] = [
	&"identity_allocation", &"run", &"desktop_consequence", &"desktop_board",
	&"profile", &"localization", &"audio", &"route", &"narrative",
]
const EXPECTED_RESTORE_PARTICIPANT_KEYS: Array[String] = [
	"identity_allocation", "run", "desktop_consequence", "desktop_board",
	"profile", "localization", "audio", "route", "narrative",
]

## Every foundation identity Step 8.1 requires to survive presentation configuration unchanged.
const FOUNDATION_IDENTITY_KEYS: Array[String] = [
	"causal_day_advance_identity_port_instance_id",
	"contact_command_port_instance_id",
	"day_resolution_coordinator_instance_id",
	"day_resolution_start_port_instance_id",
	"day_resolution_state_port_instance_id",
	"issuer_instance_id",
	"provenance_owner_instance_id",
	"publication_ledger_instance_id",
	"root_store_instance_id",
	"schedule_port_instance_id",
	"schedule_registry_instance_id",
]

var _bootstrap: Node = null
var _game_state: Node = null
var _state_port: RefCounted = null
var _coordinator: RefCounted = null
var _issuer: RefCounted = null
var _storage: RefCounted = null
var _root_counter := 0


## A bootstrap that resolves its tree targets from an injected map instead of `/root`, so the suite
## can wire one stage by hand without adding Bootstrap to the tree (whose `_ready()` would defer into
## the whole `start()` sequence).
class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


func before_each() -> void:
	_storage = JsonFileStorage.new(_isolated_root())
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(root_store).get("ok", false))

	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	_state_port = STATE_PORT.new(_game_state)
	_coordinator = COORDINATOR.new()

	_bootstrap = HarnessBootstrap.new()
	autofree(_bootstrap)
	_bootstrap.set("_profile_storage", _storage)
	_bootstrap.set("_desktop_issuer_root_store", root_store)
	_bootstrap.set("_desktop_identity_nonce_issuer", _issuer)
	_bootstrap.set("_retained_day_resolution_state_port", _state_port)
	_bootstrap.set("_retained_day_resolution_coordinator", _coordinator)
	_bootstrap.set("targets", {
		"DialogicBridge": _bridge(),
		"SceneRouter": _router(),
	})


## dwm-p2r.32 Plan 02 Task 9: wires the remaining five targets `_configure_restore_participants()`
## and `_configure_desktop_production_graph()` need, plus the shared gate/checkpoint port, then
## drives both stages in the exact production order. Kept as a separate builder (never folded into
## `before_each()`) so the Plan-01 Task-8 tests above stay exercising the narrower foundation they
## were written against.
func _build_desktop_graph() -> Dictionary:
	_build_foundation()
	var profile: Node = load("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var localization: Node = load("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	var audio: Node = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(audio)
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	var storage: RefCounted = JSON_STORAGE.new(_isolated_root())
	assert_true(save_manager.call(&"initialize", storage).get("ok", false))
	# Mirrors the initialize_saves stage's own new Task-9 wiring (never exercised here since this
	# helper builds SaveManager directly rather than driving _run_stage(&"initialize_saves", ...)).
	assert_true(save_manager.call(&"configure_identity_issuer", _issuer).get("ok", false))
	var allocation_participant: RefCounted = load(
		"res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd").new(
		_issuer, save_manager)
	assert_true(save_manager.call(
		&"configure_identity_allocation_participant", allocation_participant).get("ok", false))
	_bootstrap.set("_desktop_identity_allocation_participant", allocation_participant)
	var targets: Dictionary = _bootstrap.get("targets")
	targets["ProfileManager"] = profile
	targets["LocalizationManager"] = localization
	targets["AudioManager"] = audio
	targets["GameState"] = _game_state
	targets["SaveManager"] = save_manager
	_bootstrap.set("targets", targets)

	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	_bootstrap.set("_application_gate", gate)
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	_bootstrap.set("_retained_checkpoint_port", checkpoint_port)

	var restore_result: Dictionary = _bootstrap.call(&"_configure_restore_participants")
	assert_true(restore_result.get("ok", false), "restore participants: " + str(restore_result))
	# dwm-oyo.3 slice (2026-08-24): the desktop graph stage now composes the Plan-03 condition pair,
	# the consequence source, and the Done dispatcher, which consume the presentation ports and the
	# state port's identity half -- both composed by the EARLIER configure_day_resolution stage in
	# production. The harness mirrors that exact order.
	assert_true(_build_presentation().get("ok", false), "presentation ports compose first")
	var graph_result: Dictionary = _bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(graph_result.get("ok", false), "desktop production graph: " + str(graph_result))
	return {"gate": gate, "checkpoint_port": checkpoint_port, "save_manager": save_manager,
		"restore_result": restore_result, "graph_result": graph_result}


func _bridge() -> Node:
	var bridge: Node = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	return bridge


func _router() -> Node:
	var router: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(router)
	return router


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	return wrapper.path_join("desktop-wiring-%d" % _root_counter)


## Composes the retained foundation in the same order `configure_day_resolution()` does: the shared
## advance-identity owner, then the Schedule foundation. The contact command port belongs to the
## earlier identity stage, so the harness supplies the one Bootstrap would already be holding.
func _build_foundation() -> void:
	if _bootstrap.get("_contact_command_port") == null:
		_bootstrap.set("_contact_command_port", CONTACT_COMMAND_PORT.new())
	var advance: Dictionary = _bootstrap.call(&"_configure_causal_day_advance_identity",
		_coordinator)
	assert_true(advance.get("ok", false), "the shared advance-identity owner composes: "
		+ str(advance))
	var built: Dictionary = _bootstrap.call(&"_construct_schedule_foundation", _game_state,
		_state_port)
	assert_true(built.get("ok", false), "the Schedule foundation composes: " + str(built))


func _build_presentation() -> Dictionary:
	return _bootstrap.call(&"_construct_schedule_presentation", _coordinator)


func _foundation_identities(state: Dictionary) -> Dictionary:
	var identities: Dictionary = {}
	for key: String in FOUNDATION_IDENTITY_KEYS:
		identities[key] = state.get(key)
	return identities


# -------------------------------------------------------------------------------------------------
# the probe itself
# -------------------------------------------------------------------------------------------------

func test_the_probe_exists_and_returns_only_integers_and_booleans() -> void:
	assert_true(_bootstrap.has_method("get_desktop_contract_state"),
		"Step 8.1 requires this read-only probe")
	_build_foundation()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_false(state.is_empty())
	for key: Variant in state:
		_assert_detached_primitive(state[key], str(key))


## dwm-p2r.32 Plan 02 Task 9 broadened this law: the extended probe legitimately carries
## `restore_order` (Array[StringName]), `restore_participant_instance_ids`/`registry_versions`
## (Dictionary) alongside the original int/bool fields. The SAFETY property this test protects --
## no live Object/Node/RefCounted ever leaks out -- is unchanged and checked recursively.
func _assert_detached_primitive(value: Variant, path: String) -> void:
	match typeof(value):
		TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
			pass
		TYPE_ARRAY:
			for index in range((value as Array).size()):
				_assert_detached_primitive((value as Array)[index], "%s[%d]" % [path, index])
		TYPE_DICTIONARY:
			for inner_key: Variant in (value as Dictionary):
				_assert_detached_primitive((value as Dictionary)[inner_key], "%s.%s" % [path, str(inner_key)])
		_:
			assert_true(false, "%s must be a detached primitive, never a live Object (got type %d)" % [path, typeof(value)])


func test_the_probe_names_every_foundation_identity_step_8_1_requires() -> void:
	_build_foundation()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	for key: String in FOUNDATION_IDENTITY_KEYS:
		assert_true(state.has(key), "the probe must expose " + key)
		assert_true(int(state[key]) != 0, key + " must name a retained instance")


func test_reading_the_probe_twice_is_stable_and_mutates_nothing() -> void:
	_build_foundation()
	var first: Dictionary = _bootstrap.get_desktop_contract_state()
	var second: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(second, first, "the probe is a pure read")


# -------------------------------------------------------------------------------------------------
# the law the probe exists for
# -------------------------------------------------------------------------------------------------

func test_presentation_configuration_reconstructs_no_foundation_instance() -> void:
	_build_foundation()
	var before: Dictionary = _foundation_identities(_bootstrap.get_desktop_contract_state())
	assert_true(_build_presentation().get("ok", false))
	var after: Dictionary = _foundation_identities(_bootstrap.get_desktop_contract_state())
	assert_eq(after, before,
		"composing the presentation layer rebuilds no foundation object")


func test_identical_startup_replay_reuses_every_instance() -> void:
	_build_foundation()
	assert_true(_build_presentation().get("ok", false))
	var first: Dictionary = _bootstrap.get_desktop_contract_state()

	_build_foundation()
	assert_true(_build_presentation().get("ok", false),
		"identical replay is idempotent rather than a replacement conflict")
	assert_eq(_bootstrap.get_desktop_contract_state(), first,
		"a legitimate re-run builds a second of nothing")


func test_a_swapped_issuer_is_visible_in_the_probe() -> void:
	# The probe's whole purpose: if a later edit ever re-pointed a retained dependency, the same-boot
	# reading changes. This test proves the probe would actually notice.
	_build_foundation()
	var before: Dictionary = _bootstrap.get_desktop_contract_state()
	var other_store: RefCounted = ROOT_STORE.new()
	assert_true(other_store.configure(JsonFileStorage.new(_isolated_root()),
		NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(other_store.load_or_create().get("ok", false))
	var other_issuer: RefCounted = ISSUER.new()
	assert_true(other_issuer.configure(other_store).get("ok", false))
	_bootstrap.set("_desktop_identity_nonce_issuer", other_issuer)

	var after: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_ne(int(after["issuer_instance_id"]), int(before["issuer_instance_id"]),
		"a swapped issuer changes its same-boot identity")


func test_the_probe_reports_hospital_ready_and_dating_deliberately_not_ready() -> void:
	_build_foundation()
	assert_true(_build_presentation().get("ok", false))
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_true(bool(state["hospital_presentation_ready"]),
		"the Hospital route is composed and ready")
	assert_false(bool(state["dating_presentation_ready"]),
		"Phase 2R exposes the Dating route as NOT ready; dwm-oyo.4 owns that owner")
	assert_true(int(state["dating_presentation_port_instance_id"]) != 0,
		"the Dating port is still CONSTRUCTED and retained, just unconfigured")


## The dwm-p2r.18 twin of the Dating handoff above, NARROWED by the dwm-oyo.3 slice (2026-08-24):
## the consequence source is now composed by the LATER desktop-graph stage, so after only the
## foundation and presentation stages the producer honestly reports not-ready -- the identity half
## exists, the Plan-02 record source does not yet. The graph-stage test below proves the flip.
func test_the_producer_is_not_ready_before_the_desktop_graph_stage() -> void:
	_build_foundation()
	assert_true(_build_presentation().get("ok", false))
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_false(bool(state["presentation_producer_ready"]),
		"before the desktop-graph stage there is no consequence source to consume")
	assert_true(int(state["day_resolution_start_port_instance_id"]) != 0,
		"the start port the producer would drive is still constructed and retained")

	# The gap must be a MISSING Plan-02 record, not a missing identity owner: the state port already
	# holds the exact issuer and start port, so configuring the source is all that remains.
	var state_port: Object = _bootstrap.get("_retained_day_resolution_state_port")
	assert_true(state_port != null, "the state port is retained")
	if state_port == null:
		return
	assert_true(state_port.configure_resolution_identity(
		_bootstrap.get("_desktop_identity_nonce_issuer"),
		_bootstrap.get("_retained_day_resolution_start_port")).get("ok", false),
		"the identity half is already configured, so an identical replay is idempotent")


func test_an_unbuilt_foundation_reports_zero_rather_than_guessing() -> void:
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(int(state["provenance_owner_instance_id"]), 0)
	assert_eq(int(state["schedule_port_instance_id"]), 0)
	assert_false(bool(state["hospital_presentation_ready"]))
	assert_false(bool(state["dating_presentation_ready"]))
	assert_false(bool(state["presentation_producer_ready"]))
	assert_false(bool(state["desktop_graph_constructed"]))
	assert_false(bool(state["destination_composition_ready"]))


# -------------------------------------------------------------------------------------------------
# dwm-p2r.32 Plan 02 Task 9: the one production desktop board/consequence/causal graph
# -------------------------------------------------------------------------------------------------

func test_the_production_graph_wires_every_object_identity_and_readiness() -> void:
	_build_desktop_graph()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	for key: String in ["desktop_publication_ledger_instance_id", "causal_sequence_port_instance_id",
			"board_fate_port_instance_id", "consequence_coordinator_instance_id",
			"minesweeper_round_source_port_instance_id", "shop_purchase_source_port_instance_id",
			"host_instance_id", "board_state_instance_id", "consequence_state_instance_id",
			"mutation_gate_instance_id", "admission_checkpoint_port_instance_id",
			"continuation_journal_instance_id"]:
		assert_true(int(state[key]) != 0, key + " must name a retained instance")
	assert_true(bool(state["desktop_graph_constructed"]))
	assert_false(bool(state["destination_composition_ready"]),
		"Plan 03 owns real destination composition; Plan 02 never claims it")


func test_the_desktop_publication_ledger_is_shared_by_causal_round_shop_and_board_fate() -> void:
	_build_desktop_graph()
	var causal_port: Object = _bootstrap.get("_retained_desktop_causal_sequence_port")
	var round_coordinator: Object = _bootstrap.get("_retained_minesweeper_round_coordinator_app")
	var shop_participant: Object = _bootstrap.get("_retained_minesweeper_shop_purchase_participant")
	var board_fate_port: Object = _bootstrap.get("_retained_desktop_board_fate_port")
	var ledger: Object = _bootstrap.get("_retained_desktop_publication_ledger")
	assert_true(ledger is DESKTOP_PUBLICATION_LEDGER)
	assert_same(causal_port.get("_publication_ledger"), ledger)
	assert_same(round_coordinator.get("_publication_ledger"), ledger)
	assert_same(shop_participant.get("_publication_ledger"), ledger)
	assert_same(board_fate_port.get("_publication_ledger"), ledger)


func test_the_round_coordinator_and_board_fate_port_drive_the_exact_same_shared_board_state() -> void:
	_build_desktop_graph()
	var round_coordinator: Object = _bootstrap.get("_retained_minesweeper_round_coordinator_app")
	var board_fate_port: Object = _bootstrap.get("_retained_desktop_board_fate_port")
	var restore_board: Object = _bootstrap.get("_desktop_board_state")
	assert_same(round_coordinator.get("_board_state"), restore_board,
		"the round coordinator adopted Bootstrap's already-shared board object")
	assert_same(board_fate_port.get("_board_state"), restore_board)


func test_the_consequence_coordinator_retains_the_exact_round_and_shop_source_objects() -> void:
	_build_desktop_graph()
	var coordinator: Object = _bootstrap.get("_retained_desktop_consequence_coordinator")
	var round_coordinator: Object = _bootstrap.get("_retained_minesweeper_round_coordinator_app")
	var shop_participant: Object = _bootstrap.get("_retained_minesweeper_shop_purchase_participant")
	assert_true(round_coordinator is MINESWEEPER_ROUND_COORDINATOR_APP)
	assert_true(shop_participant is MINESWEEPER_SHOP_PURCHASE_PARTICIPANT)
	assert_same(coordinator.get("_minesweeper_round_source_port"), round_coordinator)
	assert_same(coordinator.get("_shop_purchase_source_port"), shop_participant)
	assert_not_same(round_coordinator, shop_participant, "the two source roles are distinct objects")
	assert_true(coordinator is DESKTOP_CONSEQUENCE_COORDINATOR)


## SUPERSEDED LAW, updated by the dwm-oyo.3 slice (2026-08-24): Task 9's original assertion here
## was that the pair stays NULL because "Plan 03 owns the condition-policy port; Task 9 never fakes
## or stubs it". Plan 03's REAL ports now exist and the graph stage configures them together, so
## the surviving law is the second half -- the configured objects are the retained production
## classes, never a fake, and no other object ever occupies either slot.
func test_the_consequence_coordinator_holds_the_real_condition_departure_pair() -> void:
	_build_desktop_graph()
	var coordinator: Object = _bootstrap.get("_retained_desktop_consequence_coordinator")
	var policy_port: Object = coordinator.get("_condition_policy_port")
	var view_port: Object = coordinator.get("_schedule_view_port")
	assert_true(policy_port != null and policy_port.get_script()
		== preload("res://scripts/application/desktop/DesktopConditionPolicyPort.gd"),
		"the configured policy port is the real Plan-03 class, never a fake")
	assert_true(view_port != null and view_port.get_script()
		== preload("res://scripts/application/schedule/ScheduleDepartureViewPort.gd"),
		"the configured view port is the real Plan-03 class, never a fake")
	assert_same(policy_port, _bootstrap.get("_retained_desktop_condition_policy_port"))
	assert_same(view_port, _bootstrap.get("_retained_schedule_departure_view_port"))


func test_snapshot_provider_instance_id_equals_game_state() -> void:
	_build_desktop_graph()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(int(state["snapshot_provider_instance_id"]), _game_state.get_instance_id())
	assert_true(_game_state.has_method("capture_run_snapshot_input"))


func test_the_probe_names_the_exact_frozen_restore_order_and_nine_participant_keys() -> void:
	_build_desktop_graph()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(state["restore_order"], EXPECTED_RESTORE_ORDER)
	var participant_ids: Dictionary = state["restore_participant_instance_ids"]
	var keys: Array = participant_ids.keys()
	keys.sort()
	var expected := EXPECTED_RESTORE_PARTICIPANT_KEYS.duplicate()
	expected.sort()
	assert_eq(keys, expected)
	for key: String in EXPECTED_RESTORE_PARTICIPANT_KEYS:
		assert_true(int(participant_ids[key]) != 0, key + " must name a retained participant")


func test_identical_replay_of_the_production_graph_reuses_every_instance() -> void:
	_build_desktop_graph()
	var first: Dictionary = _bootstrap.get_desktop_contract_state()
	var replayed: Dictionary = _bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(replayed.get("ok", false), str(replayed))
	var second: Dictionary = _bootstrap.get_desktop_contract_state()
	for key: String in ["desktop_publication_ledger_instance_id", "causal_sequence_port_instance_id",
			"board_fate_port_instance_id", "consequence_coordinator_instance_id",
			"minesweeper_round_source_port_instance_id", "shop_purchase_source_port_instance_id"]:
		assert_eq(int(second[key]), int(first[key]), key + ": replay rebuilt instead of reusing")


## The simulator-authority law (brief Step 9.1): the retained .9-era stack is never touched or
## registered by this graph. GameState's OWN `_minesweeper_round_coordinator` slot (the .9-era
## install seam) stays untouched by `_configure_desktop_production_graph()`; only the retained
## .9-era `_configure_minesweeper_rounds()` stage -- a SEPARATE, untouched stage -- may ever fill it.
func test_the_production_graph_never_touches_the_retained_simulator_install_seam() -> void:
	_build_desktop_graph()
	assert_null(_game_state.get("_minesweeper_round_coordinator"),
		"the Plan-02 graph must never install into the .9-era GameState seam")


# -------------------------------------------------------------------------------------------------
# dwm-oyo.3 slice (2026-08-24, dwm-p2r.21): the condition pair, consequence source, and Done
# dispatcher -- the desktop-graph stage's Plan-03 composition
# -------------------------------------------------------------------------------------------------

func test_the_desktop_graph_composes_the_condition_pair_and_flips_the_producer_ready() -> void:
	_build_desktop_graph()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_true(bool(state["presentation_producer_ready"]),
		"the composed consequence source makes the presentation producer reachable (DEVIATION-5 done)")
	for key: String in ["condition_context_port_instance_id", "condition_policy_port_instance_id",
			"schedule_departure_view_port_instance_id", "desktop_consequence_source_port_instance_id",
			"schedule_done_dispatcher_instance_id"]:
		assert_true(state.has(key), "the probe must expose " + key)
		assert_true(int(state.get(key, 0)) != 0, key + " must name a retained instance")

	# The pair really is CONFIGURED on the one shared consequence coordinator (identical replay is
	# idempotent; anything else would conflict), in the together-order Plan 03 owns.
	var coordinator: Object = _bootstrap.get("_retained_desktop_consequence_coordinator")
	var pair_replay: Dictionary = coordinator.configure_condition_departure_ports(
		_bootstrap.get("_retained_desktop_condition_policy_port"),
		_bootstrap.get("_retained_schedule_departure_view_port"))
	assert_true(pair_replay.get("ok", false), str(pair_replay))
	assert_true(bool((pair_replay.get("value", {}) as Dictionary).get("already_configured", false)))

	# The retained source object is THE configured consequence source on the day-resolution seam.
	var source_replay: Dictionary = _state_port.configure_desktop_consequence_source(
		_bootstrap.get("_retained_desktop_consequence_source_port"))
	assert_true(source_replay.get("ok", false), str(source_replay))
	assert_true(bool((source_replay.get("value", {}) as Dictionary).get("already_configured", false)))


func test_replaying_the_desktop_graph_reuses_the_condition_pair_and_dispatcher() -> void:
	_build_desktop_graph()
	var first: Dictionary = _bootstrap.get_desktop_contract_state()
	var replayed: Dictionary = _bootstrap.call(&"_configure_desktop_production_graph")
	assert_true(replayed.get("ok", false), str(replayed))
	var second: Dictionary = _bootstrap.get_desktop_contract_state()
	for key: String in ["condition_context_port_instance_id", "condition_policy_port_instance_id",
			"schedule_departure_view_port_instance_id", "desktop_consequence_source_port_instance_id",
			"schedule_done_dispatcher_instance_id"]:
		assert_eq(int(second.get(key, 0)), int(first.get(key, -1)),
			key + ": replay rebuilt instead of reusing")
