extends "res://addons/gut/test.gd"

var _scene_validation_scope := preload("res://tests/support/SceneValidationScope.gd").new()

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")


const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const CONTACT_COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const WINDOW_MODE_MANAGER := preload("res://autoload/WindowModeManager.gd")
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const APPLICATION_MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const MINESWEEPER_ROUND_COORDINATOR_APP := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const DESKTOP_PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/DesktopPublicationLedger.gd")

var _bootstrap: Node = null
var _game_state: Node = null
var _issuer: RefCounted = null
var _storage: RefCounted = null
var _root_counter := 0
var _root := ""


class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


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
	_scene_validation_scope.install()
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
	add_child_autofree(_game_state)
	_game_state.reset_game()
	assert_true(_game_state.configure_identity_issuer(_issuer).get("ok", false))

	_bootstrap = HarnessBootstrap.new()
	autofree(_bootstrap)
	_bootstrap.set("_profile_storage", _storage)
	_bootstrap.set("_desktop_issuer_root_store", root_store)
	_bootstrap.set("_desktop_identity_nonce_issuer", _issuer)
	_bootstrap.set("targets", {
		"DialogicBridge": _bridge(),
		"SceneRouter": _router(),
	})

func _build_desktop_graph(saved_root: String = "") -> Dictionary:
	assert_true(_bootstrap._configure_causal_day_advance_identity().get("ok", false))
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
	assert_true(save_manager.call(&"configure_identity_issuer", _issuer).get("ok", false))
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
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	_bootstrap.set("_retained_checkpoint_port", checkpoint_port)

	var restore_result: Dictionary = _bootstrap.call(&"_configure_restore_participants")
	assert_true(restore_result.get("ok", false), "restore participants: " + str(restore_result))
	_bootstrap._configure_checkpoint_providers()
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

func test_scene_graph_shares_board_generation_and_physical_owners() -> void:
	_build_desktop_graph()
	var round_owner: Object = _bootstrap._retained_minesweeper_round_coordinator_app
	var physical: Object = _bootstrap._retained_dating_physical_owner
	var port: Object = _bootstrap._retained_dating_presentation_port
	assert_true(round_owner is MINESWEEPER_ROUND_COORDINATOR_APP)
	assert_same(round_owner.get("_board_state"), _bootstrap._desktop_board_state)
	assert_same(round_owner.get("_publication_ledger"), _bootstrap._retained_desktop_publication_ledger)
	assert_same(round_owner.get("_scene_completion_owner"), _game_state)
	assert_same(physical.get("_game_state"), _game_state)
	assert_same(physical.get("_generation"), _bootstrap._retained_minesweeper_generation_port)
	assert_same(port.get("_physical_owner"), physical)
	assert_true(port.is_ready())

func test_scene_graph_probe_is_detached_and_stable() -> void:
	_build_desktop_graph()
	var first: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(_bootstrap.get_desktop_contract_state(), first)
	assert_true(first.desktop_graph_constructed)
	assert_true(first.dating_presentation_ready)
	for key: String in first:
		_assert_detached_primitive(first[key], key)

func test_identical_replay_of_scene_graph_reuses_shared_instances() -> void:
	_build_desktop_graph()
	var first: Dictionary = _bootstrap.get_desktop_contract_state()
	var physical: Object = _bootstrap._retained_dating_physical_owner
	var generation: Object = _bootstrap._retained_minesweeper_generation_port
	var result: Dictionary = _bootstrap._configure_desktop_production_graph()
	assert_true(result.get("ok", false), str(result))
	assert_eq(_bootstrap.get_desktop_contract_state(), first)
	assert_same(_bootstrap._retained_dating_physical_owner, physical)
	assert_same(_bootstrap._retained_minesweeper_generation_port, generation)


func test_snapshot_provider_instance_id_equals_game_state() -> void:
	if _root.is_empty():
		return
	_build_desktop_graph()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(int(state["snapshot_provider_instance_id"]), _game_state.get_instance_id())
	assert_true(_game_state.has_method("capture_run_snapshot_input"))

func test_current_restore_graph_retains_exactly_eight_participants() -> void:
	_build_desktop_graph()
	var participants: Dictionary = _bootstrap._retained_restore_participants
	var keys: Array = participants.keys()
	keys.sort()
	assert_eq(keys, ["audio", "desktop_board", "desktop_consequence", "localization", "narrative", "profile", "route", "run"])
	for participant: Object in participants.values():
		assert_true(is_instance_valid(participant))

func after_each() -> void:
	_scene_validation_scope.restore()
