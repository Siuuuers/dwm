# tests/unit/test_application_bootstrap.gd
# Task 2 (dwm-p2r.9 Plan 06) freezes the production bootstrap's Minesweeper stage: exactly one
# coordinator built from initialized production adapters, installed in GameState exactly once,
# with every missing or out-of-order dependency rejected WITHOUT partial configuration.
extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const BOOTSTRAP_PATH := "res://autoload/ApplicationBootstrap.gd"
const GAME_STATE := preload("res://autoload/GameState.gd")
const SAVE_MANAGER := preload("res://autoload/SaveManager.gd")
const SCENE_ROUTER := preload("res://autoload/SceneRouter.gd")
const AUDIO_MANAGER := preload("res://autoload/AudioManager.gd")
const DIALOGIC_BRIDGE := preload("res://autoload/DialogicBridge.gd")
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const DAY_RESOLUTION_STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const MINESWEEPER_COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")

const RETAINED_MINESWEEPER_FIELDS: Array[String] = [
	"_retained_minesweeper_state_port",
	"_retained_minesweeper_save_port",
	"_retained_minesweeper_coordinator",
]


class InjectableBootstrap:
	extends "res://autoload/ApplicationBootstrap.gd"
	var injected_targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return injected_targets.get(target_name)


var _root_ordinal := 0


func _unique_root() -> String:
	_root_ordinal += 1
	var created: Dictionary = TemporaryStorage.create(
		"minesweeper-bootstrap-%d" % _root_ordinal)
	assert_true(created.get("ok", false), created.get("message", "temporary storage unavailable"))
	if not created.get("ok", false):
		return ""
	return str(created.get("value", ""))


## Builds a bootstrap whose Minesweeper stage has every dependency satisfied. Individual tests
## then knock exactly one dependency out and assert nothing was retained.
func _make_ready_bootstrap() -> Dictionary:
	var root: String = _unique_root()
	if root.is_empty():
		return {}
	var gate: RefCounted = FAKE_GATE.new()
	var game_state: Node = autofree(GAME_STATE.new())
	game_state.call(&"reset_game")
	assert_true(game_state.call(&"configure_mutation_gate", gate).get("ok", false))
	var save_manager: Node = autofree(SAVE_MANAGER.new())
	assert_true(save_manager.call(&"initialize", JSON_STORAGE.new(root)).get("ok", false))
	var bootstrap: Node = autofree(InjectableBootstrap.new())
	bootstrap.injected_targets = {
		&"GameState": game_state,
		&"SaveManager": save_manager,
		&"SceneRouter": autofree(SCENE_ROUTER.new()),
		&"AudioManager": autofree(AUDIO_MANAGER.new()),
		&"DialogicBridge": autofree(DIALOGIC_BRIDGE.new()),
	}
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(save_manager)
	bootstrap.set("_application_gate", gate)
	bootstrap.set("_retained_checkpoint_port", checkpoint_port)
	# Build the provider bundle through the REAL day-resolution provider stage, so the Minesweeper
	# stage consumes the exact Callables Bootstrap already handed the day-resolution port.
	var day_port: RefCounted = DAY_RESOLUTION_STATE_PORT.new(game_state)
	var provided: Dictionary = bootstrap.call(&"_configure_day_resolution_providers", day_port)
	assert_true(provided.get("ok", false), str(provided))
	return {
		"bootstrap": bootstrap, "gate": gate, "game_state": game_state,
		"save_manager": save_manager, "checkpoint_port": checkpoint_port,
	}


func _assert_nothing_retained(bootstrap: Node, context: String) -> void:
	for field: String in RETAINED_MINESWEEPER_FIELDS:
		assert_null(bootstrap.get(field), "%s retained %s" % [context, field])


func test_stage_order_runs_minesweeper_after_day_resolution_and_before_readiness() -> void:
	var loaded: Dictionary = PROBE.load_script(BOOTSTRAP_PATH)
	assert_true(loaded.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(loaded))
	if not loaded.get("ok", false):
		return
	var bootstrap: Node = autofree(loaded["value"].new())
	var order: Array = bootstrap.get("STAGE_ORDER")
	var minesweeper_index: int = order.find(&"configure_minesweeper_rounds")
	assert_true(minesweeper_index >= 0, "the production stage order owns the Minesweeper stage")
	assert_eq(minesweeper_index, order.find(&"configure_day_resolution") + 1,
		"the Minesweeper stage runs immediately after day resolution")
	assert_eq(order.find(&"publish_application_ready"), minesweeper_index + 1,
		"readiness is published only after the Minesweeper stage")
	for stage_set: Array in bootstrap.get("DEVELOPMENT_STAGE_SETS").values():
		assert_false(&"configure_minesweeper_rounds" in stage_set,
			"development subsets do not silently widen into round wiring")


func test_minesweeper_stage_rejects_a_missing_gate_without_partial_configuration() -> void:
	var made := _make_ready_bootstrap()
	if made.is_empty():
		return
	var bootstrap: Node = made["bootstrap"]
	bootstrap.set("_application_gate", null)
	var result: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
		made["game_state"], made["save_manager"])
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"mutation_gate_not_configured")
	_assert_nothing_retained(bootstrap, "a missing gate")
	assert_null(made["game_state"].get("_minesweeper_round_coordinator"))


func test_minesweeper_stage_rejects_missing_targets_without_partial_configuration() -> void:
	for missing: String in ["game_state", "save_manager"]:
		var made := _make_ready_bootstrap()
		if made.is_empty():
			return
		var bootstrap: Node = made["bootstrap"]
		var result: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
			null if missing == "game_state" else made["game_state"],
			null if missing == "save_manager" else made["save_manager"])
		assert_false(result.get("ok", false), missing)
		assert_eq(result.get("code"), &"missing_stage_adapter", missing)
		_assert_nothing_retained(bootstrap, "missing " + missing)


func test_minesweeper_stage_rejects_an_unretained_checkpoint_port_without_partial_configuration() -> void:
	var made := _make_ready_bootstrap()
	if made.is_empty():
		return
	var bootstrap: Node = made["bootstrap"]
	bootstrap.set("_retained_checkpoint_port", null)
	var result: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
		made["game_state"], made["save_manager"])
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"missing_stage_adapter")
	_assert_nothing_retained(bootstrap, "an unretained checkpoint port")


func test_minesweeper_stage_rejects_unconfigured_checkpoint_providers() -> void:
	# Out of order: the Minesweeper stage cannot run before day resolution built the bundle.
	var made := _make_ready_bootstrap()
	if made.is_empty():
		return
	var bootstrap: Node = made["bootstrap"]
	bootstrap.set("_checkpoint_provider_bundle", {})
	var result: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
		made["game_state"], made["save_manager"])
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"missing_stage_adapter")
	_assert_nothing_retained(bootstrap, "unconfigured providers")


func test_minesweeper_stage_rejects_a_gate_game_state_did_not_retain() -> void:
	var made := _make_ready_bootstrap()
	if made.is_empty():
		return
	var bootstrap: Node = made["bootstrap"]
	# GameState retained the gate from _make_ready_bootstrap; hand the stage a different one.
	bootstrap.set("_application_gate", FAKE_GATE.new())
	var result: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
		made["game_state"], made["save_manager"])
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"mutation_gate_identity_mismatch")
	_assert_nothing_retained(bootstrap, "a foreign gate")
	assert_null(made["game_state"].get("_minesweeper_round_coordinator"))


func test_minesweeper_stage_constructs_exactly_one_coordinator_over_production_adapters() -> void:
	var made := _make_ready_bootstrap()
	if made.is_empty():
		return
	var bootstrap: Node = made["bootstrap"]
	var game_state: Node = made["game_state"]
	var result: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
		game_state, made["save_manager"])
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false):
		return
	var coordinator: Object = bootstrap.get("_retained_minesweeper_coordinator")
	var state_port: Object = bootstrap.get("_retained_minesweeper_state_port")
	var save_port: Object = bootstrap.get("_retained_minesweeper_save_port")
	assert_not_null(coordinator)
	assert_true(coordinator is MINESWEEPER_COORDINATOR, "the retained coordinator is the real one")
	# The coordinator holds these exact adapter identities, and no others.
	assert_same(coordinator.get("_state_port"), state_port)
	assert_same(coordinator.get("_save_port"), save_port)
	assert_true(bool(coordinator.get("_configured")))
	# Both production adapters are initialized against the shared objects Bootstrap already owns.
	assert_same(state_port.get("_game_state"), game_state)
	assert_same(state_port.get("_gate"), made["gate"])
	assert_same(save_port.get("_checkpoint_port"), made["checkpoint_port"])
	assert_same(save_port.get("_save_manager"), made["save_manager"])
	assert_eq(int(result["value"]["gate_instance_id"]), made["gate"].get_instance_id())
	# Installed in GameState exactly once, and reachable through the shared facade methods.
	assert_same(game_state.get("_minesweeper_round_coordinator"), coordinator)
	assert_eq(game_state.call(&"get_active_minesweeper_round").get("code"), &"no_active_round")
	# The state port received the SAME provider Callables the day-resolution port was given.
	var bundle: Dictionary = bootstrap.get("_checkpoint_provider_bundle")
	var port_providers: Dictionary = state_port.get("_checkpoint_providers")
	assert_eq(port_providers.keys().size(), bundle.keys().size())
	for key: Variant in bundle:
		assert_eq((port_providers[key] as Callable).get_object_id(),
			(bundle[key] as Callable).get_object_id(), "provider identity for " + str(key))
		assert_eq(String((port_providers[key] as Callable).get_method()),
			String((bundle[key] as Callable).get_method()), "provider method for " + str(key))


func test_identical_startup_replay_reuses_the_exact_same_round_graph() -> void:
	var made := _make_ready_bootstrap()
	if made.is_empty():
		return
	var bootstrap: Node = made["bootstrap"]
	var game_state: Node = made["game_state"]
	var first: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
		game_state, made["save_manager"])
	assert_true(first.get("ok", false), str(first))
	var second: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds",
		game_state, made["save_manager"])
	assert_true(second.get("ok", false), str(second))
	for key: String in ["coordinator_instance_id", "state_port_instance_id", "save_port_instance_id"]:
		assert_eq(int(second["value"][key]), int(first["value"][key]),
			"replay rebuilt %s instead of reusing it" % key)
	assert_same(game_state.get("_minesweeper_round_coordinator"),
		bootstrap.get("_retained_minesweeper_coordinator"))


func test_game_state_refuses_a_second_distinct_round_coordinator() -> void:
	var game_state: Node = autofree(GAME_STATE.new())
	var first: RefCounted = MINESWEEPER_COORDINATOR.new()
	assert_true(game_state.call(&"_install_minesweeper_round_coordinator", first).get("ok", false))
	var replay: Dictionary = game_state.call(&"_install_minesweeper_round_coordinator", first)
	assert_true(replay.get("ok", false))
	assert_true(bool(replay["value"]["already_installed"]), "the same coordinator is idempotent")
	var intruder: Dictionary = game_state.call(&"_install_minesweeper_round_coordinator",
		MINESWEEPER_COORDINATOR.new())
	assert_false(intruder.get("ok", false))
	assert_eq(intruder.get("code"), &"minesweeper_coordinator_already_installed")
	assert_same(game_state.get("_minesweeper_round_coordinator"), first)


func test_round_facade_fails_closed_before_the_coordinator_is_installed() -> void:
	var game_state: Node = autofree(GAME_STATE.new())
	for call_name: StringName in [&"begin_minesweeper_round", &"complete_minesweeper_round"]:
		var result: Dictionary = (
			game_state.call(call_name, {"context": &"app", "difficulty": &"beginner"})
			if call_name == &"begin_minesweeper_round"
			else game_state.call(call_name, "round-1", {"outcome": &"cleared"}, "tx-1")
		)
		assert_false(result.get("ok", false), String(call_name))
		assert_eq(result.get("code"), &"NOT_CONFIGURED", String(call_name))


func test_game_state_reports_only_its_gate_identity_never_the_gate() -> void:
	var game_state: Node = autofree(GAME_STATE.new())
	assert_eq(int(game_state.call(&"get_mutation_gate_instance_id")), 0,
		"an unconfigured GameState reports no gate identity")
	var gate: RefCounted = FAKE_GATE.new()
	assert_true(game_state.call(&"configure_mutation_gate", gate).get("ok", false))
	assert_eq(int(game_state.call(&"get_mutation_gate_instance_id")), gate.get_instance_id())
	var source := FileAccess.get_file_as_string("res://autoload/GameState.gd")
	assert_false(source.contains("func get_mutation_gate("),
		"the fence itself is never handed to a caller")


func test_bootstrap_stage_and_this_suite_are_source_bound_by_uid() -> void:
	# Task 3 hashes these exact bytes into both handoff artifacts, so each bound path must carry
	# a real, well-formed UID sidecar.
	for path: String in [
		"res://autoload/ApplicationBootstrap.gd.uid",
		"res://tests/unit/test_application_bootstrap.gd.uid",
	]:
		assert_true(FileAccess.file_exists(path), "missing UID sidecar: " + path)
		if not FileAccess.file_exists(path):
			continue
		var uid := FileAccess.get_file_as_string(path).strip_edges()
		assert_true(uid.begins_with("uid://"), "%s is not a UID: %s" % [path, uid])
		assert_true(uid.length() > "uid://".length(), path)
		assert_eq(ResourceUID.text_to_id(uid) != ResourceUID.INVALID_ID, true,
			"%s does not resolve to a valid resource id" % path)
