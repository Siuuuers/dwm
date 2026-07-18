# tests/unit/test_application_bootstrap_profile_stage.gd
extends "res://addons/gut/test.gd"
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const EXPECTED_STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
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

func test_application_bootstrap_contract_exists() -> void:
	var result: Dictionary = PROBE.load_script("res://autoload/ApplicationBootstrap.gd")
	assert_true(result.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(result))
	if not result.get("ok", false): return
	var bootstrap: Node = autofree(result["value"].new())
	assert_eq(bootstrap.get("STAGE_ORDER"), EXPECTED_STAGE_ORDER)

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

func test_final_mode_stops_at_missing_production_gate_before_profile() -> void:
	var loaded: Dictionary = PROBE.load_script("res://autoload/ApplicationBootstrap.gd")
	var bootstrap: Node = autofree(loaded["value"].new())
	var result: Dictionary = bootstrap.call(&"start", &"final")
	assert_eq(result.get("code"), &"missing_production_gate_factory")
	var state: Dictionary = bootstrap.call(&"get_startup_state")
	assert_eq(state["completed_stages"], [&"select_and_prove_roots"])
	assert_false(state["ready"])
	assert_eq(state["fatal_result"]["code"], &"missing_production_gate_factory")

func test_ready_callbacks_are_side_effect_free_or_deferred_only() -> void:
	var profile_source := FileAccess.get_file_as_string("res://autoload/ProfileManager.gd")
	var bootstrap_source := FileAccess.get_file_as_string("res://autoload/ApplicationBootstrap.gd")
	assert_true(profile_source.contains("func _ready() -> void:\n\tpass"))
	assert_true(bootstrap_source.contains("func _ready() -> void:\n\tcall_deferred(\"start\", _requested_mode_from_debug_args())"))
