extends Node

const FAKE_APPLICATION_MUTATION_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const EXPECTED_FOUR_TARGETS: Array[StringName] = [&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager"]
const EXPECTED_SIX_TARGETS: Array[StringName] = [&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager", &"AudioManager", &"DialogicBridge"]

var _application_ready_count := 0


func _enter_tree() -> void:
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	if bootstrap == null or not bootstrap.has_method("configure_debug_mutation_gate_factory"):
		_abort("missing debug gate factory seam")
		return
	bootstrap.application_ready.connect(func() -> void: _application_ready_count += 1)
	bootstrap.development_subset_ready.connect(_on_development_subset_ready)
	var result: Dictionary = bootstrap.configure_debug_mutation_gate_factory(Callable(self, "_create_debug_mutation_gate"))
	if not result.get("ok", false):
		_abort("gate factory rejected: %s" % JSON.stringify(result))


func _create_debug_mutation_gate() -> Object:
	return FAKE_APPLICATION_MUTATION_GATE.new()


func _on_development_subset_ready(mode: StringName) -> void:
	if mode != &"profile_localization_development":
		_abort("unexpected development mode: %s" % mode)
		return
	call_deferred("_verify_ready_state")


func _verify_ready_state() -> void:
	var bootstrap := get_node("/root/ApplicationBootstrap")
	var state: Dictionary = bootstrap.get_startup_state()
	var injection: Dictionary = state["gate_injection"]
	if injection["factory_invocation_count"] != 1 or injection["targets"] != EXPECTED_FOUR_TARGETS:
		_abort("invalid gate injection: %s" % JSON.stringify(injection))
		return
	if injection["gate_instance_id"] == 0:
		_abort("invalid gate identity: %s" % JSON.stringify(injection))
		return
	for retained_id in injection["target_instance_ids"]:
		if retained_id != injection["gate_instance_id"]:
			_abort("gate identity mismatch")
			return
	var expected_stages: Array[StringName] = [&"select_and_prove_roots", &"construct_and_inject_mutation_gate", &"initialize_profile", &"initialize_localization", &"initialize_input", &"initialize_accessibility"]
	if state["completed_stages"] != expected_stages or state["ready"] or not state["fatal_result"].is_empty() or _application_ready_count != 0:
		_abort("invalid development readiness: %s" % JSON.stringify(state))
		return
	var localization := get_node("/root/LocalizationManager")
	var profile := get_node("/root/ProfileManager")
	var menu := get_node("MenuScene")
	var presentation := menu.get_node("LocalePresentationRoot")
	if presentation.get("_registration_result").get("code") != &"pending_registration":
		_abort("menu root did not register pending")
		return
	if localization.get_readiness() != &"ready" or menu.layout_direction != Control.LAYOUT_DIRECTION_LTR:
		_abort("menu presentation was not ready in startup frame")
		return
	var events := {"profile": 0, "locale": 0}
	profile.preference_changed.connect(func(path: StringName, _value: Variant) -> void:
		if path == &"preferences.language": events["profile"] += 1
	)
	localization.locale_changed.connect(func(_locale_id: String) -> void: events["locale"] += 1)
	var switched: Dictionary = localization.set_locale("zh_hk")
	if not switched.get("ok", false) or localization.get_locale() != "zh_HK" or profile.get_preference(&"preferences.language") != "zh_HK" or events["profile"] != 1 or events["locale"] != 1:
		_abort("alias transaction did not publish exactly once: result=%s locale=%s profile=%s events=%s" % [JSON.stringify(switched), localization.get_locale(), profile.get_preference(&"preferences.language"), JSON.stringify(events)])
		return
	if localization.prepare_locale("en")["value"]["root_plans"].size() < 1:
		_abort("live menu root was not registered")
		return
	menu.free()
	if not localization.prepare_locale("en")["value"]["root_plans"].is_empty():
		_abort("freed menu root was not pruned")
		return
	get_tree().quit(0)


func _abort(message: String) -> void:
	push_error("ProjectStartupLocalizationHarness: %s" % message)
	get_tree().quit(1)
