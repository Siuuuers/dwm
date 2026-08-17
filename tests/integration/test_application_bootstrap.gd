extends "res://addons/gut/test.gd"
# Task 2 (dwm-p2r.9 Plan 06) freezes the FINAL production bootstrap graph.
#
# WHY THIS FILE EXISTS. Task 3 hashes these exact Bootstrap/project bytes into both Phase-3
# handoff artifacts, and Task 4 then treats them as immutable bindings. Every identity claim the
# artifact makes has to be asserted here first, or the artifact would be recording a wiring that
# nothing actually checks.
#
# WHAT A SECOND INSTANCE WOULD COST:
#   * A second MUTATION GATE: the fatal fence would stop being process-wide -- one subsystem could
#     keep mutating after another had latched.
#   * A second DESKTOP HOST: the persisted active_app_id and the evicted app list would disagree,
#     so a restored save could name an app the host never had open.
#   * A second CHECKPOINT PORT: two journals/sequences, so a restart could resume a checkpoint id
#     the other port never issued.
#
# HOW IT DRIVES BOOTSTRAP. Stages are invoked directly with injected targets rather than through a
# full start(): this suite is about object identity and dispatch counts, and dragging in root
# selection and profile IO would not sharpen a single claim. Bootstrap is built with .new() and
# never added to the tree, so _ready() -- which defers into start() -- never fires.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so locals are annotated.

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const SAVE_MANAGER := preload("res://autoload/SaveManager.gd")
const PROFILE_MANAGER := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION_MANAGER := preload("res://autoload/LocalizationManager.gd")
const AUDIO_MANAGER := preload("res://autoload/AudioManager.gd")
const SCENE_ROUTER := preload("res://autoload/SceneRouter.gd")
const INPUT_MANAGER := preload("res://autoload/InputManager.gd")
const ACCESSIBILITY_MANAGER := preload("res://autoload/AccessibilityManager.gd")
const DIALOGIC_BRIDGE := preload("res://autoload/DialogicBridge.gd")
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const SAVE_CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const DAY_RESOLUTION_STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const MINESWEEPER_COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const FAKE_EVICTION := preload("res://tests/support/FakeDesktopEvictionPort.gd")

## The exact literal autoload order project.godot must reach in this task.
const EXPECTED_AUTOLOAD_ORDER: Array[String] = [
	"ProfileManager", "GameState", "SaveManager", "LocalizationManager", "AudioManager",
	"EffectResolver", "SceneRouter", "InputManager", "AccessibilityManager", "Dialogic",
	"DialogicBridge", "ApplicationBootstrap",
]

const EXPECTED_STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
	&"construct_identity_issuer_and_contact_commands",
	&"initialize_profile",
	&"initialize_saves",
	&"initialize_localization",
	&"initialize_input",
	&"initialize_accessibility",
	&"initialize_audio",
	&"initialize_dialogic_bridge",
	&"configure_restore_participants",
	&"configure_day_resolution",
	&"configure_minesweeper_rounds",
	&"publish_application_ready",
]

var _root_counter := 0


class InjectableBootstrap:
	extends "res://autoload/ApplicationBootstrap.gd"
	var injected_targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return injected_targets.get(target_name)


func _isolated_root(label: String) -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("%s-%d" % [label, _root_counter])
	var production: String = ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	return root


## Builds the eight gate targets plus the bootstrap, with the gate already injected into all of
## them exactly as the production stage does.
func _make_graph(label: String) -> Dictionary:
	var root: String = _isolated_root(label)
	var targets := {
		&"ProfileManager": autofree(PROFILE_MANAGER.new()),
		&"GameState": autofree(GAME_STATE.new()),
		&"SaveManager": autofree(SAVE_MANAGER.new()),
		&"LocalizationManager": autofree(LOCALIZATION_MANAGER.new()),
		&"AudioManager": autofree(AUDIO_MANAGER.new()),
		&"SceneRouter": autofree(SCENE_ROUTER.new()),
		&"InputManager": autofree(INPUT_MANAGER.new()),
		&"AccessibilityManager": autofree(ACCESSIBILITY_MANAGER.new()),
		&"DialogicBridge": autofree(DIALOGIC_BRIDGE.new()),
	}
	targets[&"GameState"].call(&"reset_game")
	var bootstrap: Node = autofree(InjectableBootstrap.new())
	bootstrap.injected_targets = targets
	bootstrap.set("_selected_root", root)
	bootstrap.set("_profile_storage", JSON_STORAGE.new(root))
	var injected: Dictionary = bootstrap.call(&"_construct_and_inject_mutation_gate", &"final")
	assert_true(injected.get("ok", false), str(injected))
	assert_true(targets[&"SaveManager"].call(&"initialize",
		JSON_STORAGE.new(root.path_join("saves"))).get("ok", false))
	var checkpoint_port: RefCounted = SAVE_CHECKPOINT_PORT.new(targets[&"SaveManager"])
	assert_true(checkpoint_port.configure_fatal_latch(bootstrap.get("_application_gate")).get("ok", false))
	bootstrap.set("_retained_checkpoint_port", checkpoint_port)
	return {"bootstrap": bootstrap, "targets": targets, "checkpoint_port": checkpoint_port, "root": root}


func test_project_autoload_order_is_the_exact_final_literal_sequence() -> void:
	# project.godot reaches its final literal order in THIS task; Task 3 hashes these bytes.
	var text := FileAccess.get_file_as_string("res://project.godot")
	var section := text.get_slice("[autoload]", 1).get_slice("[", 0)
	var found: Array[String] = []
	for line: String in section.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or not trimmed.contains("="):
			continue
		found.append(trimmed.get_slice("=", 0).strip_edges())
	assert_eq(found, EXPECTED_AUTOLOAD_ORDER,
		"the production autoload order is frozen for the Phase 3 handoff")


func test_master_stage_order_is_frozen() -> void:
	var bootstrap: Node = autofree(BOOTSTRAP.new())
	assert_eq(bootstrap.get("STAGE_ORDER"), EXPECTED_STAGE_ORDER)
	assert_eq(bootstrap.get("FINAL_GATE_TARGETS").size(), 8, "exactly eight gate targets")


func test_exactly_eight_targets_retain_one_shared_gate_identity() -> void:
	var made := _make_graph("gate-identity")
	var bootstrap: Node = made["bootstrap"]
	var gate: Object = bootstrap.get("_application_gate")
	assert_not_null(gate)
	var state: Dictionary = bootstrap.call(&"get_startup_state")
	var injection: Dictionary = state["gate_injection"]
	assert_eq(int(injection["factory_invocation_count"]), 1, "the gate is constructed exactly once")
	assert_eq((injection["targets"] as Array).size(), 8)
	assert_eq((injection["target_instance_ids"] as Array).size(), 8)
	for retained_id: Variant in injection["target_instance_ids"]:
		assert_eq(int(retained_id), gate.get_instance_id(), "every target retained the ONE gate")
	assert_eq(injection["targets"], Array(bootstrap.get("FINAL_GATE_TARGETS")),
		"the eight targets are injected in the frozen order")
	# GameState reports that same identity to its adapters, without exposing the fence.
	assert_eq(int(made["targets"][&"GameState"].call(&"get_mutation_gate_instance_id")),
		gate.get_instance_id())


func test_one_desktop_host_is_shared_by_route_restore_and_the_direct_checkpoint_provider() -> void:
	var made := _make_graph("desktop-host")
	var bootstrap: Node = made["bootstrap"]
	var participants: Dictionary = bootstrap.call(&"_configure_restore_participants")
	assert_true(participants.get("ok", false), str(participants))
	var host: Object = bootstrap.get("_desktop_host_state")
	assert_not_null(host, "the restore stage constructs the ONE process-lifetime host")
	# The direct checkpoint provider reads that SAME host.
	assert_true(made["checkpoint_port"].configure_desktop_context_provider(host).get("ok", false))
	assert_same(made["checkpoint_port"].get("_desktop_context_provider"), host)
	# Replay never builds a second host.
	assert_true(bootstrap.call(&"_configure_restore_participants").get("ok", false))
	assert_same(bootstrap.get("_desktop_host_state"), host)


func test_the_stable_active_app_callable_keeps_its_identity_and_returns_raw_json_values() -> void:
	var made := _make_graph("active-app-callable")
	var bootstrap: Node = made["bootstrap"]
	# BEFORE host injection the stable Callable returns raw JSON null -- never a wrapper.
	var before: Variant = bootstrap.call(&"_active_app_id_context")
	assert_null(before, "an uninjected host reports raw JSON null")
	var day_port: RefCounted = DAY_RESOLUTION_STATE_PORT.new(made["targets"][&"GameState"])
	assert_true(bootstrap.call(&"_configure_day_resolution_providers", day_port).get("ok", false))
	var first_bundle: Dictionary = bootstrap.get("_checkpoint_provider_bundle")
	var first_callable: Callable = first_bundle["active_app_id"]
	assert_true(bootstrap.call(&"_configure_restore_participants").get("ok", false))
	# AFTER host injection the SAME Callable object answers; nothing was replaced.
	var second_bundle: Dictionary = bootstrap.get("_checkpoint_provider_bundle")
	var second_callable: Callable = second_bundle["active_app_id"]
	assert_eq(second_callable.get_object_id(), first_callable.get_object_id(),
		"the stable Callable identity is never replaced by host injection")
	assert_eq(String(second_callable.get_method()), String(first_callable.get_method()))
	var after: Variant = bootstrap.call(&"_active_app_id_context")
	assert_true(after == null or typeof(after) == TYPE_STRING,
		"the provider returns a raw registered app-ID String or JSON null, never a CommandResult")
	assert_false(typeof(after) == TYPE_DICTIONARY, "never a CommandResult wrapper")


func test_the_retained_checkpoint_port_and_gate_are_shared_by_both_coordinators() -> void:
	var made := _make_graph("shared-coordinators")
	var bootstrap: Node = made["bootstrap"]
	var game_state: Node = made["targets"][&"GameState"]
	# The Schedule foundation inside day resolution reuses the retained issuer, so that stage
	# has to have run first -- exactly as it does in the production stage order.
	assert_true(bootstrap.call(&"_construct_identity_issuer_and_contact_commands").get("ok", false))
	assert_true(bootstrap.call(&"_configure_restore_participants").get("ok", false))
	var resolved: Dictionary = bootstrap.call(&"configure_day_resolution", game_state,
		made["targets"][&"SaveManager"])
	assert_true(resolved.get("ok", false), str(resolved))
	# Day resolution reused the ONE retained checkpoint port rather than building a second.
	assert_same(bootstrap.get("_retained_checkpoint_port"), made["checkpoint_port"])
	var day_coordinator: Object = bootstrap.get("_retained_day_resolution_coordinator")
	assert_not_null(day_coordinator)
	var minesweeper: Dictionary = bootstrap.call(&"_configure_minesweeper_rounds", game_state,
		made["targets"][&"SaveManager"])
	assert_true(minesweeper.get("ok", false), str(minesweeper))
	var round_coordinator: Object = bootstrap.get("_retained_minesweeper_coordinator")
	assert_true(round_coordinator is MINESWEEPER_COORDINATOR)
	# Both coordinators answer to the SAME fatal fence, and the round adapters to the SAME port.
	var gate: Object = bootstrap.get("_application_gate")
	assert_eq(int(minesweeper["value"]["gate_instance_id"]), gate.get_instance_id())
	assert_same(bootstrap.get("_retained_minesweeper_state_port").get("_gate"), gate)
	assert_same(bootstrap.get("_retained_minesweeper_save_port").get("_checkpoint_port"),
		made["checkpoint_port"])
	assert_same(game_state.get("_minesweeper_round_coordinator"), round_coordinator)
	assert_not_same(round_coordinator, day_coordinator, "two distinct coordinators, one gate")


func test_exactly_one_day_changed_connection_dispatches_one_eviction_command() -> void:
	var made := _make_graph("day-change")
	var bootstrap: Node = made["bootstrap"]
	var game_state: Node = made["targets"][&"GameState"]
	assert_true(bootstrap.call(&"_configure_restore_participants").get("ok", false))
	assert_eq(game_state.day_changed.get_connections().size(), 0, "nothing connected yet")
	bootstrap.call(&"_connect_desktop_day_change", game_state)
	assert_eq(game_state.day_changed.get_connections().size(), 1,
		"Bootstrap owns exactly one day_changed connection")
	# An identical replay never adds a second connection.
	bootstrap.call(&"_connect_desktop_day_change", game_state)
	assert_eq(game_state.day_changed.get_connections().size(), 1)

	var eviction: RefCounted = FAKE_EVICTION.new()
	var registered: Dictionary = bootstrap.call(&"register_desktop_eviction_port", eviction)
	assert_true(registered.get("ok", false), str(registered))
	# The same port is idempotent; a different one is refused.
	assert_true(bootstrap.call(&"register_desktop_eviction_port", eviction)
		.get("value", {}).get("already_configured", false))
	assert_eq(bootstrap.call(&"register_desktop_eviction_port", FAKE_EVICTION.new()).get("code"),
		&"desktop_eviction_port_already_configured")

	game_state.emit_signal("day_changed", 2)
	assert_eq(int(eviction.get_call_counts()["dispatch_desktop_eviction"]), 1,
		"one day change dispatches exactly one eviction command")
	var command: Dictionary = eviction.get("_last_command")
	assert_eq(str(command["command_id"]), "desktop-day:2")
	assert_eq(str(command["kind"]), "evict_cached_apps")
	assert_eq(int(command["day"]), 2)
	assert_eq(typeof(command["app_ids"]), TYPE_ARRAY)
	assert_false(bootstrap.get("_application_gate").is_fatal_latched(),
		"a successful dispatch latches nothing")


func test_a_missing_eviction_port_latches_one_primitive_validated_fatal() -> void:
	var made := _make_graph("eviction-missing")
	var bootstrap: Node = made["bootstrap"]
	var game_state: Node = made["targets"][&"GameState"]
	assert_true(bootstrap.call(&"_configure_restore_participants").get("ok", false))
	bootstrap.call(&"_connect_desktop_day_change", game_state)
	var gate: Object = bootstrap.get("_application_gate")
	game_state.emit_signal("day_changed", 3)
	assert_true(gate.is_fatal_latched(), "a missing dispatch port is fatal")
	# The retained failure is primitive-validated, and every later guard returns it unchanged.
	var guarded: Dictionary = gate.guard_external(&"any_later_operation")
	assert_false(guarded.get("ok", false))
	assert_eq(guarded.get("code"), &"APPLICATION_FATAL")
	var failure: Dictionary = guarded["details"]["failure"]
	for key: String in ["source", "phase", "code", "details"]:
		assert_true(failure.has(key), "retained failure key " + key)
	assert_eq(typeof(failure["details"]), TYPE_DICTIONARY)
	assert_eq(str(failure["source"]), "desktop")


func test_each_stage_failure_returns_one_fatal_result_and_never_reaches_readiness() -> void:
	# Injecting a missing target at each stage must stop startup there: no later stage runs and
	# readiness is never published.
	for stage_id: StringName in [&"initialize_saves", &"configure_restore_participants",
			&"configure_day_resolution", &"configure_minesweeper_rounds"]:
		var made := _make_graph("stage-fail-%s" % stage_id)
		var bootstrap: Node = made["bootstrap"]
		var targets: Dictionary = bootstrap.injected_targets.duplicate()
		targets.erase(&"SaveManager")
		bootstrap.injected_targets = targets
		var result: Dictionary = bootstrap.call(&"_run_stage", stage_id, &"final")
		assert_false(result.get("ok", false), String(stage_id))
		assert_true(result.has("code"), String(stage_id))
		var state: Dictionary = bootstrap.call(&"get_startup_state")
		assert_false(bool(state["ready"]), "%s never publishes readiness" % stage_id)
		assert_false(&"publish_application_ready" in (state["completed_stages"] as Array))
		assert_null(bootstrap.get("_retained_minesweeper_coordinator"),
			"%s leaves no partially configured round graph" % stage_id)
