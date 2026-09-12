# tests/unit/test_application_bootstrap_profile_stage.gd
extends "res://addons/gut/test.gd"
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const PROFILE_MANAGER := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION_MANAGER := preload("res://autoload/LocalizationManager.gd")
const INPUT_MANAGER := preload("res://autoload/InputManager.gd")
const ACCESSIBILITY_MANAGER := preload("res://autoload/AccessibilityManager.gd")
const AUDIO_MANAGER := preload("res://autoload/AudioManager.gd")
const DIALOGIC_BRIDGE := preload("res://autoload/DialogicBridge.gd")
const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const JSON_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const EXPECTED_STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
	&"construct_identity_issuer_and_contact_commands",
	&"initialize_saves",
	&"initialize_profile",
	&"initialize_localization",
	&"initialize_input",
	&"initialize_accessibility",
	&"initialize_audio",
	&"initialize_window_mode",
	&"initialize_dialogic_bridge",
	&"configure_restore_participants",
	&"configure_day_resolution",
	&"configure_minesweeper_rounds",
	&"publish_application_ready",
]


class InjectableBootstrap:
	extends "res://autoload/ApplicationBootstrap.gd"
	var injected_targets: Dictionary = {}
	var target_requests: Array[StringName] = []

	func _target(target_name: StringName) -> Node:
		target_requests.append(target_name)
		return injected_targets.get(target_name)

func test_application_bootstrap_contract_exists() -> void:
	var result: Dictionary = PROBE.load_script("res://autoload/ApplicationBootstrap.gd")
	assert_true(result.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(result))
	if not result.get("ok", false): return
	var bootstrap: Node = autofree(result["value"].new())
	assert_eq(bootstrap.get("STAGE_ORDER"), EXPECTED_STAGE_ORDER)


func test_final_contact_stage_reuses_profile_storage_and_retains_one_identity_graph() -> void:
	var bootstrap: Node = autofree(InjectableBootstrap.new())
	assert_true(bootstrap.has_method("_construct_identity_issuer_and_contact_commands"),
		"RED: final bootstrap needs the exact identity/contact stage")
	if not bootstrap.has_method("_construct_identity_issuer_and_contact_commands"):
		return
	var game_state: Node = autofree(GAME_STATE.new())
	game_state.set("_identity_issuer", null)
	bootstrap.injected_targets = {&"GameState": game_state}
	var storage_result: Dictionary = TemporaryStorage.create("contact-bootstrap")
	assert_true(storage_result.ok, storage_result.get("message", ""))
	if not storage_result.ok:
		return
	var root: String = storage_result.value
	var storage: RefCounted = JSON_STORAGE.new(root)
	bootstrap.set("_selected_root", root)
	bootstrap.set("_profile_storage", storage)
	var result: Dictionary = bootstrap.call(&"_construct_identity_issuer_and_contact_commands")
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false):
		return
	var retained_root: Object = bootstrap.get("_desktop_issuer_root_store")
	var retained_issuer: Object = bootstrap.get("_desktop_identity_nonce_issuer")
	var retained_port: Object = bootstrap.get("_contact_command_port")
	assert_same(retained_root.get("_storage"), storage,
		"issuer root reuses the exact root-scoped profile storage object")
	assert_same(retained_issuer.get("_root"), retained_root)
	assert_same(game_state.get("_identity_issuer"), retained_issuer)
	assert_same(retained_port.get("_identity_issuer"), retained_issuer)
	assert_same(retained_port.get("_game_state"), game_state)
	assert_eq(result["value"]["issuer_instance_id"], retained_issuer.get_instance_id())
	for stage_set: Array in bootstrap.get("DEVELOPMENT_STAGE_SETS").values():
		assert_false(&"construct_identity_issuer_and_contact_commands" in stage_set,
			"development subsets do not silently widen")

func test_manual_mode_executes_no_stage_and_is_not_readiness() -> void:
	var loaded: Dictionary = PROBE.load_script("res://autoload/ApplicationBootstrap.gd")
	var bootstrap: Node = autofree(loaded["value"].new())
	var result: Dictionary = bootstrap.call(&"start", &"test_manual")
	assert_true(result.get("ok", false), str(result))
	var state: Dictionary = bootstrap.call(&"get_startup_state")
	assert_eq(state["completed_stages"], [])
	assert_false(state["ready"])
	assert_eq(state["fatal_result"], {})
	assert_eq(bootstrap.call(&"start", &"test_manual").get("code"), &"bootstrap_already_started")

func test_final_mode_constructs_production_gate_and_injects_before_profile() -> void:
	# Task 7: final mode now constructs the Task-3 production gate via the private
	# factory and injects the exact eight FINAL_GATE_TARGETS in order. In this bare
	# harness the /root autoloads are absent, so injection stops at the first target
	# BEFORE any initializer runs -- never returning missing_production_gate_factory.
	var loaded: Dictionary = PROBE.load_script("res://autoload/ApplicationBootstrap.gd")
	var bootstrap: Node = autofree(loaded["value"].new())
	var result: Dictionary = bootstrap.call(&"start", &"final")
	assert_ne(result.get("code"), &"missing_production_gate_factory",
		"final mode no longer stalls on a missing production factory")
	assert_eq(result.get("code"), &"invalid_gate_target",
		"injection stops at the first unavailable target in this bare harness")
	var state: Dictionary = bootstrap.call(&"get_startup_state")
	assert_eq(state["completed_stages"], [&"select_and_prove_roots"],
		"it stops inside the gate stage, before initialize_profile")
	assert_eq(int(state["gate_injection"]["factory_invocation_count"]), 1,
		"the production gate factory was invoked exactly once")
	assert_false(state["ready"])

func test_ready_callbacks_are_side_effect_free_or_deferred_only() -> void:
	for path in [
		"res://autoload/ProfileManager.gd", "res://autoload/GameState.gd",
		"res://autoload/LocalizationManager.gd", "res://autoload/InputManager.gd",
		"res://autoload/AccessibilityManager.gd", "res://autoload/AudioManager.gd",
		"res://autoload/DialogicBridge.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		assert_true(source.contains("func _ready() -> void:\n\tpass"), path)
	var bootstrap_source := FileAccess.get_file_as_string("res://autoload/ApplicationBootstrap.gd")
	assert_true(bootstrap_source.contains("func _ready() -> void:\n\tcall_deferred(\"start\", _requested_mode_from_debug_args())"))

func test_task2_owned_managers_expose_common_gate_contract() -> void:
	for path in ["res://autoload/InputManager.gd", "res://autoload/AccessibilityManager.gd", "res://autoload/LocalizationManager.gd", "res://autoload/AudioManager.gd"]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "%s: %s" % [path, loaded])
		var manager: Node = autofree(loaded["value"].new())
		assert_true(manager.has_method("configure_mutation_gate"), path)
		var gate: RefCounted = FAKE_GATE.new()
		var first: Dictionary = manager.call(&"configure_mutation_gate", gate)
		assert_true(first.get("ok", false), "%s: %s" % [path, first])
		assert_eq(first["value"]["gate_instance_id"], gate.get_instance_id())
		assert_false(first["value"]["already_configured"])
		assert_true(manager.call(&"configure_mutation_gate", gate)["value"]["already_configured"])
		assert_eq(manager.call(&"configure_mutation_gate", null).get("code"), &"invalid_mutation_gate")
		assert_eq(manager.call(&"configure_mutation_gate", FAKE_GATE.new()).get("code"), &"mutation_gate_already_configured")


func test_dialogic_bridge_exposes_common_gate_contract() -> void:
	var loaded: Dictionary = PROBE.load_script("res://autoload/DialogicBridge.gd")
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false):
		return
	var bridge: Node = autofree(loaded["value"].new())
	var gate: RefCounted = FAKE_GATE.new()
	var first: Dictionary = bridge.call(&"configure_mutation_gate", gate)
	assert_true(first.get("ok", false), str(first))
	assert_eq(first["value"]["gate_instance_id"], gate.get_instance_id())
	assert_false(first["value"]["already_configured"])
	assert_true(bridge.call(&"configure_mutation_gate", gate)["value"]["already_configured"])
	assert_eq(bridge.call(&"configure_mutation_gate", null).get("code"), &"invalid_mutation_gate")
	var incomplete: Node = autofree(Node.new())
	assert_eq(bridge.call(&"configure_mutation_gate", incomplete).get("code"), &"invalid_mutation_gate")
	assert_eq(bridge.call(&"configure_mutation_gate", FAKE_GATE.new()).get("code"), &"mutation_gate_already_configured")


func test_real_plan02_target_order_is_exactly_six_managers() -> void:
	var loaded: Dictionary = PROBE.load_script("res://autoload/ApplicationBootstrap.gd")
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false):
		return
	var bootstrap: Node = autofree(loaded["value"].new())
	assert_eq(
		bootstrap.get("DEVELOPMENT_GATE_TARGETS")[&"profile_locale_audio_development"],
		[&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager", &"AudioManager", &"DialogicBridge"],
	)


func test_real_six_target_gate_failure_stops_at_each_ordinal_before_initialization() -> void:
	var target_names: Array[StringName] = [&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager", &"AudioManager", &"DialogicBridge"]
	var scripts := [PROFILE_MANAGER, LOCALIZATION_MANAGER, INPUT_MANAGER, ACCESSIBILITY_MANAGER, AUDIO_MANAGER, DIALOGIC_BRIDGE]
	for failing_ordinal in range(target_names.size()):
		var bootstrap: Node = autofree(InjectableBootstrap.new())
		var targets := {}
		for index in range(target_names.size()):
			var manager: Node = autofree(scripts[index].new())
			targets[target_names[index]] = manager
		bootstrap.set("injected_targets", targets)
		var blocker: RefCounted = FAKE_GATE.new()
		assert_true(targets[target_names[failing_ordinal]].configure_mutation_gate(blocker).get("ok", false))
		var shared_gate: RefCounted = FAKE_GATE.new()
		bootstrap.set("_debug_gate_factory", func() -> Object: return shared_gate)
		var result: Dictionary = bootstrap.call(&"_construct_and_inject_mutation_gate", &"profile_locale_audio_development")
		assert_eq(result.get("code"), &"mutation_gate_already_configured", "ordinal %d" % failing_ordinal)
		for index in range(target_names.size()):
			var retained: Object = targets[target_names[index]].get("_mutation_gate")
			if index < failing_ordinal:
				assert_eq(retained.get_instance_id(), shared_gate.get_instance_id())
			elif index == failing_ordinal:
				assert_eq(retained.get_instance_id(), blocker.get_instance_id())
			else:
				assert_null(retained)
		assert_null(targets[&"ProfileManager"].get("_storage"))
		assert_false(targets[&"ProfileManager"].get("_initialized"))
		assert_null(targets[&"LocalizationManager"].get("_profile"))
		assert_eq(targets[&"LocalizationManager"].get("_bundle"), {})
		assert_null(targets[&"InputManager"].get("_profile"))
		assert_null(targets[&"AccessibilityManager"].get("_profile"))
		assert_null(targets[&"AudioManager"].get("_profile"))
		assert_false(targets[&"AudioManager"].get("_initialized"))
		assert_null(targets[&"DialogicBridge"].get("_profile"))
		assert_false(targets[&"DialogicBridge"].get("_preferences_bound"))
		for forbidden_target in [&"SaveManager", &"GameState", &"SceneRouter"]:
			assert_false(forbidden_target in bootstrap.target_requests, "ordinal %d requested %s" % [failing_ordinal, forbidden_target])
