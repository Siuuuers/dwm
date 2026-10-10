extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

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
const WINDOW_MODE_MANAGER := preload("res://autoload/WindowModeManager.gd")
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const MINESWEEPER_ROUND_COORDINATOR_APP := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const MINESWEEPER_SHOP_PURCHASE_PARTICIPANT := preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd")
const DESKTOP_CONSEQUENCE_COORDINATOR := preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")

const EXPECTED_RESTORE_ORDER: Array[StringName] = [
	&"identity_allocation", &"run", &"desktop_consequence", &"desktop_board",
	&"schedule_view", &"profile", &"localization", &"audio", &"route", &"narrative",
]
const EXPECTED_RESTORE_PARTICIPANT_KEYS: Array[String] = [
	"identity_allocation", "run", "desktop_consequence", "desktop_board",
	"schedule_view", "profile", "localization", "audio", "route", "narrative",
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
var _root := ""


## A bootstrap that resolves its tree targets from an injected map instead of `/root`, so the suite
## can wire one stage by hand without adding Bootstrap to the tree (whose `_ready()` would defer into
## the whole `start()` sequence).
class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


class CompletionFailureCheckpoint extends SAVE_CHECKPOINT_PORT:
	var fail_completion_once := false
	var last_prepare_failure: Dictionary = {}
	func prepare(inputs: Dictionary, kind: StringName, disk_write: Dictionary) -> Dictionary:
		var prepared: Dictionary = super.prepare(inputs, kind, disk_write)
		last_prepare_failure = {} if prepared.get("ok", false) else prepared.duplicate(true)
		return prepared

	func commit(candidate: Dictionary) -> Dictionary:
		if fail_completion_once and candidate.get("autosave_document") is Dictionary \
				and candidate.autosave_document.current_snapshot.get("checkpoint_kind") == "post_result":
			fail_completion_once = false
			return {"ok": false, "code": &"injected_completion_write_failure"}
		return super.commit(candidate)

	# Test-only disk probe; completed-action recovery no longer needs this helper in production.
	func _read_completed_snapshot() -> Dictionary:
		var path: String = _storage().describe_root().path_join("autosave.json")
		var text: String = FileAccess.get_file_as_string(path)
		var validated: Dictionary = _document_text_validator(text)
		if not validated.get("ok", false): return validated
		return {"ok": true, "value": {"snapshot": validated.value.current_snapshot.snapshot}}


class UnavailableWindowOutput extends RefCounted:
	func capture_output() -> Dictionary:
		return {"ok": false, "code": &"window_output_unavailable", "details": {}, "receipt": {}}
	func apply_mode(_mode: String) -> Dictionary:
		return {"ok": false, "code": &"window_output_unavailable", "details": {}, "receipt": {}}
	func output_matches(_mode: String) -> bool:
		return false
	func restore_output(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"window_output_unavailable", "details": {}, "receipt": {}}


func before_each() -> void:
	_root = ""
	var result: Dictionary = TEMPORARY_STORAGE.create("desktop-bootstrap-wiring")
	assert_true(result.get("ok", false), result.get("message", ""))
	if not result.get("ok", false):
		return
	_root = str(result["value"])
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
func _build_desktop_graph(saved_root: String = "") -> Dictionary:
	_build_foundation()
	var profile: Node = load("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	assert_true(profile.initialize(JSON_STORAGE.new(_isolated_root())).get("ok", false))
	var localization: Node = load("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).get("ok", false))
	var audio: Node = load("res://autoload/AudioManager.gd").new()
	add_child_autofree(audio)
	assert_true(audio.initialize(profile).get("ok", false))
	var window: Node = WINDOW_MODE_MANAGER.new(UnavailableWindowOutput.new())
	add_child_autofree(window)
	assert_true(window.initialize(profile, audio.get_settings_output_transactions()).get("ok", false))
	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	add_child_autofree(save_manager)
	var storage: RefCounted = JSON_STORAGE.new(_isolated_root() if saved_root.is_empty() else saved_root)
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
	targets["WindowModeManager"] = window
	targets["GameState"] = _game_state
	targets["SaveManager"] = save_manager
	_bootstrap.set("targets", targets)

	var gate: RefCounted = APPLICATION_MUTATION_GATE.new()
	_bootstrap.set("_application_gate", gate)
	assert_true(save_manager.configure_mutation_gate(gate).get("ok", false))
	var checkpoint_port: RefCounted = CompletionFailureCheckpoint.new(save_manager)
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
	if _root.is_empty():
		return ""
	_root_counter += 1
	return _root.path_join("desktop-wiring-%d" % _root_counter)


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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
	_build_foundation()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	for key: String in FOUNDATION_IDENTITY_KEYS:
		assert_true(state.has(key), "the probe must expose " + key)
		assert_true(int(state[key]) != 0, key + " must name a retained instance")


func test_reading_the_probe_twice_is_stable_and_mutates_nothing() -> void:
	if _root.is_empty():
		return
	_build_foundation()
	var first: Dictionary = _bootstrap.get_desktop_contract_state()
	var second: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(second, first, "the probe is a pure read")


# -------------------------------------------------------------------------------------------------
# the law the probe exists for
# -------------------------------------------------------------------------------------------------

func test_presentation_configuration_reconstructs_no_foundation_instance() -> void:
	if _root.is_empty():
		return
	_build_foundation()
	var before: Dictionary = _foundation_identities(_bootstrap.get_desktop_contract_state())
	assert_true(_build_presentation().get("ok", false))
	var after: Dictionary = _foundation_identities(_bootstrap.get_desktop_contract_state())
	assert_eq(after, before,
		"composing the presentation layer rebuilds no foundation object")


func test_identical_startup_replay_reuses_every_instance() -> void:
	if _root.is_empty():
		return
	_build_foundation()
	assert_true(_build_presentation().get("ok", false))
	var first: Dictionary = _bootstrap.get_desktop_contract_state()

	_build_foundation()
	assert_true(_build_presentation().get("ok", false),
		"identical replay is idempotent rather than a replacement conflict")
	assert_eq(_bootstrap.get_desktop_contract_state(), first,
		"a legitimate re-run builds a second of nothing")


func test_a_swapped_issuer_is_visible_in_the_probe() -> void:
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
	_build_desktop_graph()
	var round_coordinator: Object = _bootstrap.get("_retained_minesweeper_round_coordinator_app")
	var board_fate_port: Object = _bootstrap.get("_retained_desktop_board_fate_port")
	var restore_board: Object = _bootstrap.get("_desktop_board_state")
	assert_same(round_coordinator.get("_board_state"), restore_board,
		"the round coordinator adopted Bootstrap's already-shared board object")
	assert_same(board_fate_port.get("_board_state"), restore_board)


func test_the_consequence_coordinator_retains_the_exact_round_and_shop_source_objects() -> void:
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
	_build_desktop_graph()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(int(state["snapshot_provider_instance_id"]), _game_state.get_instance_id())
	assert_true(_game_state.has_method("capture_run_snapshot_input"))


func test_the_probe_names_identity_allocation_plus_the_nine_participant_keys() -> void:
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
	_build_desktop_graph()
	assert_null(_game_state.get("_minesweeper_round_coordinator"),
		"the Plan-02 graph must never install into the .9-era GameState seam")


# -------------------------------------------------------------------------------------------------
# dwm-oyo.3 slice (2026-08-24, dwm-p2r.21): the condition pair, consequence source, and Done
# dispatcher -- the desktop-graph stage's Plan-03 composition
# -------------------------------------------------------------------------------------------------

func test_the_desktop_graph_composes_the_condition_pair_and_flips_the_producer_ready() -> void:
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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


class GameplayDesktop extends Node:
	var panel: Object
	var schedule: Object
	var done: Callable
	var shop: Object
	func configure_shop(port: Object, _locale: Object, _profile: Object, _host: Object, _day: int) -> Dictionary:
		shop = port
		return {"ok": true}
	func configure_minesweeper(port: Object, _locale: Object, _profile: Object,
			_host: Object, _day: int, _input: Object) -> Dictionary:
		panel = port
		return {"ok": true}
	func configure_schedule(port: Object, _locale: Object, _profile: Object,
			_host: Object, _day: int, handler: Callable, _warning: Object, _commands: Object) -> Dictionary:
		schedule = port
		done = handler
		return {"ok": true}
	func prepare_warning_navigation(_intent: StringName) -> Dictionary:
		return {"ok": false, "code": &"not_used"}
	func commit_warning_navigation(_receipt: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"not_used"}


func test_gameplay_mount_uses_real_ports_and_first_reveal_persists_one_charge() -> void:
	if _root.is_empty():
		return
	var graph := _build_desktop_graph()
	var mounted := _activate_gameplay_fixture(graph)
	if mounted.is_empty(): return
	var desktop: GameplayDesktop = mounted.desktop
	var gate: Object = graph.gate
	var money_before: int = _game_state.money
	var motivation_before: int = _game_state.get_stat("motivation")
	var purchased: Dictionary = desktop.shop.purchase("coffee", 1)
	assert_true(purchased.get("ok", false), str(purchased))
	assert_eq(_game_state.money, money_before - 20)
	assert_eq(_game_state.get_stat("motivation"), mini(motivation_before + 1, _game_state.get_stat_max("motivation")))
	var projected: Dictionary = desktop.panel.pull()
	assert_true(projected.get("ok", false), str(projected))
	if not projected.get("ok", false): return
	var before_rounds: int = _game_state.minesweeper_rounds_left
	var before_motivation: int = _game_state.get_stat("motivation")
	var revealed: Dictionary = desktop.panel.dispatch("reveal", 0, int(projected.value.board.revision))
	assert_true(revealed.get("ok", false), str(revealed))
	assert_eq(_game_state.minesweeper_rounds_left, before_rounds - 1)
	assert_eq(_game_state.get_stat("motivation"), before_motivation - 1)
	assert_true(graph.save_manager.save_exists(&"autosave"))
	assert_eq(_game_state.capture_run_snapshot_input().desktop.board,
		_bootstrap.get("_desktop_board_state").capture(), "snapshots must read live board state after the first action")
	assert_true(desktop.shop.get_catalog("en").get("ok", false))
	assert_eq(desktop.shop.get("_purchase_participant"), _bootstrap.get("_retained_minesweeper_shop_purchase_participant"))
	# The test may inspect hidden state to choose an actual mine; the player command still
	# goes through the same public Reveal action and the real reducer decides the result.
	var board: Dictionary = _bootstrap.get("_desktop_board_state").capture().board.board
	var paid_receipt: Dictionary = _bootstrap.get("_desktop_board_state").capture().board.paid_start_receipt
	assert_eq(paid_receipt.get("difficulty_id"), "beginner", "the durable board retains its reward difficulty")
	assert_false(str(paid_receipt.get("receipt_id", "")).is_empty(), "completion uses the real paid-start identity")
	watch_signals(_game_state)
	var money_before_result: int = _game_state.money
	var pressure_before_result: int = _game_state.get_stat("pressure")
	var expected_reward: Dictionary = _game_state.calculate_minesweeper_money_reward({"difficulty": "beginner", "outcome": "exploded"})
	var finished_before: int = _game_state.minesweeper_app_rounds_finished_today
	graph.checkpoint_port.fail_completion_once = true
	var terminal: Dictionary = desktop.panel.dispatch("reveal", int(board.mine_indices[0]), int(revealed.value.board.revision))
	assert_true(terminal.get("ok", false), str(terminal))
	if not terminal.get("ok", false): return
	assert_false(terminal.value.settled, "the terminal click publishes before its next-frame settlement")
	assert_true(desktop.panel.has_pending_settlement())
	assert_true(graph.checkpoint_port.fail_completion_once, "the click has not attempted the result save")
	# The production panel pumps this public seam on the next frame after painting the board.
	terminal = desktop.panel.advance_preparation(int(terminal.value.board.revision))
	assert_false(terminal.get("ok", true), "the injected full-save failure retains terminal custody")
	assert_false(graph.checkpoint_port.fail_completion_once,
		"the pump reached the injected result-save failure: " + str(graph.checkpoint_port.last_prepare_failure))
	assert_signal_emit_count(_game_state, "contact_message_unlocked", 0, "notification waits for durable result")
	assert_eq(_bootstrap.get("_desktop_board_state").capture().phase, "ACTIVE_VISIBLE", "failed durable settlement retains the terminal board")
	assert_true(_bootstrap.get("_desktop_board_state").capture().board.board.terminal)
	assert_true(gate.is_internal_owner_active(&"causal_transaction"))
	terminal = desktop.panel.pull()
	assert_false(gate.is_internal_owner_active(&"causal_transaction"), "the public panel retries and releases custody")

	assert_true(terminal.get("ok", false), str(terminal.get("code")))
	if not terminal.get("ok", false): return
	assert_true(terminal.value.board.terminal)
	assert_true(terminal.value.settled)
	assert_eq(_game_state.minesweeper_app_rounds_finished_today, finished_before + 1)
	assert_eq(_game_state.money, money_before_result + int(expected_reward.money))
	assert_eq(_game_state.get_stat("pressure"), clampi(pressure_before_result + int(expected_reward.pressure),
		_game_state.get_stat_min("pressure"), _game_state.get_stat_max("pressure")))
	var unlocked_friend: String = _game_state.get_daily_message_friend_for_finished_round(finished_before + 1, _game_state.day)
	assert_true(_game_state.is_contact_message_unlocked(unlocked_friend))
	var disk: Dictionary = graph.checkpoint_port.call(&"_read_completed_snapshot")
	assert_true(disk.get("ok", false), str(disk))
	if disk.get("ok", false):
		assert_eq(disk.value.snapshot.gameplay.money, _game_state.money)
		assert_eq(disk.value.snapshot.gameplay.minesweeper_app_rounds_finished_today, finished_before + 1)
		assert_eq(disk.value.snapshot.contacts, _game_state.contacts)
		assert_eq(disk.value.snapshot.desktop.board.phase, "ACTIVE_VISIBLE")
		assert_true(disk.value.snapshot.desktop.board.board.board.terminal)
		assert_null(disk.value.snapshot.desktop.consequence.pending)
		assert_eq(disk.value.snapshot.desktop.consequence.outbox.notification.status, "published")
	assert_signal_emit_count(_game_state, "contact_message_unlocked", 1)

	assert_true(_bootstrap.get("_desktop_board_state").is_settled_inspection(_bootstrap.get("_desktop_board_state").capture()))
	var paid_rounds: int = _game_state.minesweeper_rounds_left
	var fresh: Dictionary = desktop.panel.dispatch("new_board", -1, terminal.value.board.revision)
	assert_true(fresh.get("ok", false), str(fresh.get("code")))
	assert_eq(_game_state.minesweeper_rounds_left, paid_rounds, "New Board releases presentation without another charge")
	# Complete the next real generated board without any flags. Test-only hidden-state
	# inspection chooses safe cells; every action still passes through the player's port.
	var winning: Dictionary = desktop.panel.dispatch("reveal", 0, int(fresh.value.board.revision))
	assert_true(winning.get("ok", false), str(winning.get("code")))
	if not winning.get("ok", false): return
	var winning_board: Dictionary = _bootstrap.get("_desktop_board_state").capture().board.board
	var money_before_win: int = _game_state.money
	var win_reward: Dictionary = _game_state.calculate_minesweeper_money_reward({"difficulty": "beginner", "outcome": "no_flag"})
	for index in range(int(winning_board.width) * int(winning_board.height)):
		if bool(winning.value.get("settled", false)): break
		var live: Dictionary = _bootstrap.get("_desktop_board_state").capture().board.board
		if live.mine_indices.has(index) or live.revealed_indices.has(index): continue
		winning = desktop.panel.dispatch("reveal", index, int(winning.value.board.revision))
		assert_true(winning.get("ok", false), str(winning.get("code")))
		if not winning.get("ok", false): return
	assert_true(winning.value.board.terminal, "the real reducer reached the winning terminal board")
	assert_false(winning.value.settled, "the winning terminal click also paints before settlement")
	assert_true(desktop.panel.has_pending_settlement())
	winning = desktop.panel.advance_preparation(int(winning.value.board.revision))
	assert_true(winning.get("ok", false), str(winning))
	if not winning.get("ok", false): return
	assert_true(winning.value.settled)
	assert_signal_emit_count(_game_state, "contact_message_unlocked", 2)

	assert_eq(_game_state.money, money_before_win + int(win_reward.money))
	assert_eq(_game_state.minesweeper_app_rounds_finished_today, finished_before + 2)
	assert_true(_game_state.minesweeper_task_rewards_claimed.has("complete_beginner"))
	assert_true(_game_state.minesweeper_task_rewards_claimed.has("no_flag_finish"))
	var settled_owner: Object = _bootstrap.get("_retained_minesweeper_round_coordinator_app")
	var admissions: Dictionary = settled_owner.get("_round_pending_admission_requests")
	var last_id: String = admissions.keys().back()
	var admission: Dictionary = admissions[last_id]
	var repeated: Dictionary = settled_owner.complete_round({"transaction_id": last_id,
		"transaction_issuer_receipt": admission.action_receipt.transaction_issuer_receipt,
		"expected_identity": admission.expected_board_identity, "expected_revision": admission.expected_board_revision})
	assert_true(repeated.get("ok", false), str(repeated.get("code")))
	assert_eq(_game_state.money, money_before_win + int(win_reward.money), "replayed completion never pays twice")
	assert_eq(_game_state.minesweeper_app_rounds_finished_today, finished_before + 2)
	var won_disk: Dictionary = graph.checkpoint_port.call(&"_read_completed_snapshot")
	assert_true(won_disk.get("ok", false), str(won_disk))
	if won_disk.get("ok", false):
		assert_eq(won_disk.value.snapshot.gameplay.money, _game_state.money)
		assert_true(won_disk.value.snapshot.gameplay.minesweeper_task_rewards_claimed.has("no_flag_finish"))



func _activate_gameplay_fixture(graph: Dictionary, day: int = 1) -> Dictionary:
	_bootstrap.get("targets")["SceneRouter"].set("_current_scene_id", "main")
	# Production configures the issuer and frozen Contacts before gameplay can generate offers.
	# Without this stage, result preparation correctly refuses the missing v7 presentation facts.
	var identity: Dictionary = _bootstrap.call(&"_construct_identity_issuer_and_contact_commands")
	assert_true(identity.get("ok", false), str(identity))
	if not identity.get("ok", false): return {}
	assert_true(_game_state.frozen_contacts_contexts_enabled())
	assert_true(_bootstrap.call(&"_configure_day_resolution_providers", _state_port).get("ok", false))
	add_child(_game_state)
	if not _bootstrap.has_method("configure_gameplay_desktop"):
		fail_test("Bootstrap must mount the real gameplay ports")
		return {}
	var gate: Object = graph.gate
	assert_true(_game_state.configure_mutation_gate(gate).ok)
	assert_true(graph.save_manager.configure_mutation_gate(gate).ok)
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	snapshot.lifecycle.day = day
	snapshot.committed_schedule.day = day
	snapshot.schedule_view.day = day
	var validated: Dictionary = preload("res://scripts/domain/run/RunSnapshotSchema.gd").validate(snapshot)
	assert_true(validated.get("ok", false), str(validated))
	if not validated.get("ok", false): return {}
	snapshot = validated.value.candidate
	assert_true(graph.save_manager.get("_journal").reset(snapshot.run_id).ok)
	var acquired: Dictionary = gate.acquire(&"new_run")
	assert_true(acquired.ok)
	var applied: Dictionary = _game_state.apply_restore_silent({"snapshot": snapshot})
	assert_true(applied.get("ok", false), str(applied))
	var consequence: Object = _bootstrap.get("_desktop_consequence_state")
	var consequence_restored: Dictionary = consequence.prepare_restore(snapshot.desktop.consequence)
	assert_true(consequence_restored.get("ok", false), str(consequence_restored))
	assert_true(consequence.commit(consequence_restored.value.candidate).ok)
	assert_true(_game_state.activate_live_session({"operation_id": "fixture-install",
		"expected_generation": 0, "owner_id": _game_state.get_instance_id(), "run_id": snapshot.run_id}).ok)
	assert_true(gate.release(&"new_run", str(acquired.value.token)).ok)
	var view: Object = _bootstrap.get("_retained_schedule_view_controller")
	assert_true(view.open_day(snapshot.lifecycle.day, snapshot.lifecycle.causal_day_instance).ok)
	var targets: Dictionary = _bootstrap.get("targets")
	_bootstrap.set("targets", targets)
	_bootstrap.get("_state")["ready"] = true
	var desktop := GameplayDesktop.new()
	autofree(desktop)
	var mounted: Dictionary = _bootstrap.call(&"configure_gameplay_desktop", desktop)
	assert_true(mounted.get("ok", false), str(mounted))
	if not mounted.get("ok", false): return {}
	assert_eq(desktop.schedule.get("_view_controller"), view)
	assert_eq(desktop.done.get_argument_count(), 0)
	return {"desktop": desktop, "view": view, "gate": gate}


func test_fresh_graph_keeps_prior_day_two_autosave_after_failed_completion() -> void:
	if _root.is_empty():
		return
	_assert_fresh_graph_preserves_last_saved_action(false)


func test_fresh_graph_keeps_prior_autosave_after_failed_condition_departure() -> void:
	if _root.is_empty():
		return
	_assert_fresh_graph_preserves_last_saved_action(true)


func _assert_fresh_graph_preserves_last_saved_action(departure: bool, shop_item: String = "") -> void:
	var graph := _build_desktop_graph()
	var mounted := _activate_gameplay_fixture(graph, 2)
	if mounted.is_empty(): return
	var desktop: GameplayDesktop = mounted.desktop
	if departure:
		_game_state.minesweeper_selected_difficulty = "intermediate"
		_game_state.stats["pressure"] = 9
		_game_state.condition_effects_today.assign(["sequela"])
	var before_interrupted: Dictionary = {}
	if shop_item.is_empty():
		var initial: Dictionary = desktop.panel.pull()
		assert_true(initial.get("ok", false), str(initial))
		if not initial.get("ok", false): return
		var reveal: Dictionary = desktop.panel.dispatch("reveal", 0, initial.value.board.revision)
		assert_true(reveal.get("ok", false), str(reveal))
		if not reveal.get("ok", false): return
		var board: Dictionary = _bootstrap.get("_desktop_board_state").capture().board.board
		before_interrupted = _game_state.capture_run_snapshot_input().duplicate(true)
		graph.checkpoint_port.fail_completion_once = true
		var interrupted: Dictionary = desktop.panel.dispatch("reveal", int(board.mine_indices[0]), reveal.value.board.revision)
		assert_true(interrupted.get("ok", false), str(interrupted))
		if not interrupted.get("ok", false): return
		assert_false(interrupted.value.settled, "the terminal board is presented before deferred settlement")
		assert_true(desktop.panel.has_pending_settlement())
		assert_true(graph.checkpoint_port.fail_completion_once, "the result save remains deferred")
		interrupted = desktop.panel.advance_preparation(int(interrupted.value.board.revision))
		assert_false(interrupted.get("ok", true), str(interrupted))
		assert_false(graph.checkpoint_port.fail_completion_once,
			"the result-save fault must be exercised: " + str(graph.checkpoint_port.last_prepare_failure))
		assert_true(graph.gate.is_active(), str(interrupted))
	else:
		_game_state.money = 200
		_game_state.coins = 4
		if departure: _game_state.stats["health"] = 1
		before_interrupted = _game_state.capture_run_snapshot_input().duplicate(true)
		graph.checkpoint_port.fail_completion_once = true
		var interrupted: Dictionary = desktop.shop.purchase(shop_item, 1)
		assert_false(interrupted.get("ok", true))
		assert_true(graph.gate.is_active(), str(interrupted))
		if not graph.gate.is_active(): return
	var saved_root: String = graph.save_manager.get("_storage").describe_root()
	var source_text: String = FileAccess.get_file_as_string(saved_root.path_join("autosave.json"))
	var prior: Dictionary = graph.checkpoint_port._read_completed_snapshot()
	assert_true(prior.get("ok", false), str(prior))
	if not prior.get("ok", false): return
	assert_eq(prior.value.snapshot.gameplay, before_interrupted.gameplay,
		"failed completion preserves gameplay from the preceding saved player action")
	assert_eq(prior.value.snapshot.contacts, before_interrupted.contacts)
	assert_eq(preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(prior.value.snapshot.desktop.board.board).value,
		preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(before_interrupted.desktop.board.board).value)
	assert_null(prior.value.snapshot.desktop.consequence.pending)
	var issuer_root: String = _storage.describe_root()
	var old_game_id: int = _game_state.get_instance_id()
	var old_round_id: int = _bootstrap.get("_retained_minesweeper_round_coordinator_app").get_instance_id()
	# Fresh owners share only disk: no live source/coordinator/state objects or callback caches.
	_storage = JSON_STORAGE.new(issuer_root)
	var roots: RefCounted = ROOT_STORE.new()
	assert_true(roots.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(roots.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(roots).get("ok", false))
	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()
	_state_port = STATE_PORT.new(_game_state)
	_coordinator = COORDINATOR.new()
	_bootstrap = HarnessBootstrap.new()
	autofree(_bootstrap)
	_bootstrap.set("_profile_storage", _storage)
	_bootstrap.set("_desktop_issuer_root_store", roots)
	_bootstrap.set("_desktop_identity_nonce_issuer", _issuer)
	_bootstrap.set("_retained_day_resolution_state_port", _state_port)
	_bootstrap.set("_retained_day_resolution_coordinator", _coordinator)
	_bootstrap.set("targets", {"DialogicBridge": _bridge(), "SceneRouter": _router()})
	var unactivated: Dictionary = _game_state.capture_run_snapshot_input().duplicate(true)
	var fresh := _build_desktop_graph(saved_root)
	if not fresh.graph_result.get("ok", false): return
	assert_ne(_game_state.get_instance_id(), old_game_id)
	assert_ne(_bootstrap.get("_retained_minesweeper_round_coordinator_app").get_instance_id(), old_round_id)
	var composed: Dictionary = _game_state.capture_run_snapshot_input()
	for key: String in unactivated:
		if key == "desktop": continue # Graph construction installs the initial desktop providers.
		assert_eq(composed[key], unactivated[key], "building fresh owners cannot replay interrupted effects: " + key)
	assert_eq(composed.desktop.board.phase, "NONE")
	assert_null(composed.desktop.consequence.pending)
	assert_false(_game_state.capture_live_session().value.active)
	assert_false(fresh.gate.is_active())
	assert_eq(FileAccess.get_file_as_string(saved_root.path_join("autosave.json")), source_text,
		"fresh Bootstrap graph leaves the authoritative saved action byte-identical")
	var saved: Dictionary = fresh.checkpoint_port._read_completed_snapshot()
	assert_true(saved.get("ok", false), str(saved))
	if saved.get("ok", false): assert_eq(saved.value.snapshot, prior.value.snapshot)
	# Actual cross-process Login/Load of this boundary is exercised by
	# verify_complete_action_recovery.gd; graph construction alone is not a restore.


func test_shop_purchase_saves_authored_effects_and_retries_without_a_second_charge() -> void:
	if _root.is_empty():
		return
	var graph := _build_desktop_graph()
	var mounted := _activate_gameplay_fixture(graph, 2)
	if mounted.is_empty(): return
	var shop: Object = mounted.desktop.shop
	_game_state.money = 200
	_game_state.stats["health"] = 1
	_game_state.condition_effects_today.assign(["sequela"])
	_game_state.stats["pressure"] = 5
	graph.checkpoint_port.fail_completion_once = true
	var bought: Dictionary = shop.purchase("wine", 1)
	assert_false(bought.get("ok", true), "result-save failure retains the purchase")
	assert_eq(_game_state.money, 145)
	assert_eq(_game_state.get_stat("health"), 0)
	assert_true(graph.gate.is_active())
	assert_false(shop.purchase("coffee", 1).get("ok", true), "another item cannot replace the pending purchase")
	var retried: Dictionary = shop.purchase("wine", 1)
	assert_true(retried.get("ok", false), str(retried))
	if not retried.get("ok", false): return
	assert_eq(_game_state.money, 145, "retry does not spend again")
	assert_false(graph.gate.is_active())
	var saved: Dictionary = graph.checkpoint_port.call(&"_read_completed_snapshot")
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false): return
	assert_eq(saved.value.snapshot.gameplay.money, 145)
	assert_null(saved.value.snapshot.desktop.consequence.pending)
	assert_true(saved.value.snapshot.desktop.consequence.outbox.has("hospital"), "post-purchase health triggers Hospital")


func test_fresh_graph_keeps_prior_autosave_after_failed_ordinary_purchase() -> void:
	if _root.is_empty():
		return
	_assert_fresh_graph_preserves_last_saved_action(true, "wine")


func test_fresh_graph_keeps_prior_autosave_after_failed_special_purchase() -> void:
	if _root.is_empty():
		return
	_assert_fresh_graph_preserves_last_saved_action(false, "lucky_charm")


func test_shop_batch_and_public_gift_alias_commit_authored_values_and_inventory() -> void:
	if _root.is_empty():
		return
	var graph := _build_desktop_graph()
	var mounted := _activate_gameplay_fixture(graph, 2)
	if mounted.is_empty(): return
	_game_state.money = 200
	_game_state.coins = 4
	_game_state.stats["motivation"] = 4
	var shop: Object = mounted.desktop.shop
	var batch: Dictionary = shop.purchase("coffee", 3)
	assert_true(batch.get("ok", false), str(batch))
	if not batch.get("ok", false): return
	assert_eq(_game_state.money, 140)
	assert_eq(_game_state.get_stat("motivation"), 7)
	var gift: Dictionary = shop.purchase("bookend_keepsake", 1)
	assert_true(gift.get("ok", false), str(gift))
	if not gift.get("ok", false): return
	assert_eq(_game_state.coins, 1)
	assert_eq(int(_game_state.inventory.get("priscilla_gift", 0)), 1)
	assert_false(shop.purchase("bookend_keepsake", 1).get("ok", true))
	var saved: Dictionary = graph.checkpoint_port.call(&"_read_completed_snapshot")
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false): return
	assert_eq(saved.value.snapshot.gameplay.money, 140)
	assert_eq(saved.value.snapshot.gameplay.coins, 1)
	assert_eq(int(saved.value.snapshot.gameplay.inventory.get("priscilla_gift", 0)), 1)
