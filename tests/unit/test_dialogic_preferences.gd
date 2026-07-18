extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicPreferenceAdapter.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")


class FakeSettings:
	extends Node
	var settings := {}


class FakeText:
	extends Node
	var calls: Array = []

	func update_text_speed(letter_speed: float, use_default: bool, base_multiplier: float, delay_multiplier: float) -> void:
		calls.append([letter_speed, use_default, base_multiplier, delay_multiplier])


class FakeAutoAdvance:
	extends Node
	var delay_modifier := 1.0
	var enabled_until_user_input := false


class FakeInputs:
	extends Node
	var auto_advance: Node


class FakeBridgeProfile:
	extends Node
	signal preference_changed(path: StringName, value: Variant)
	var snapshot := {"preferences": {"dialogue": {"text_speed": 1.0, "auto_text_speed": 1.0, "auto_advance_dialogue": false}}}

	func get_profile_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class FailingPreferenceAdapter:
	extends RefCounted
	var fail_apply := false

	func bind(_dialogic: Node) -> Dictionary:
		return {"ok": true, "value": {}}

	func prepare(_profile: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"text_delay_multiplier": 1.0, "auto_delay_multiplier": 1.0, "auto_advance_enabled": false}}

	func apply_silent(_plan: Dictionary) -> Dictionary:
		return {"ok": not fail_apply, "code": &"injected_dialogic_failure" if fail_apply else &"ok", "details": {}, "receipt": {}}


class CountingPreferenceAdapter:
	extends RefCounted
	var delegate: RefCounted = ADAPTER.new()
	var apply_count := 0

	func bind(dialogic: Node) -> Dictionary:
		return delegate.call(&"bind", dialogic)

	func prepare(profile: Dictionary) -> Dictionary:
		return delegate.call(&"prepare", profile)

	func apply_silent(plan: Dictionary) -> Dictionary:
		apply_count += 1
		return delegate.call(&"apply_silent", plan)


func _fake_dialogic() -> Dictionary:
	var dialogic := Node.new()
	var settings := FakeSettings.new()
	settings.name = "Settings"
	var text := FakeText.new()
	text.name = "Text"
	var inputs := FakeInputs.new()
	inputs.name = "Inputs"
	var auto := FakeAutoAdvance.new()
	inputs.auto_advance = auto
	dialogic.add_child(settings)
	dialogic.add_child(text)
	dialogic.add_child(inputs)
	inputs.add_child(auto)
	add_child_autofree(dialogic)
	return {"dialogic": dialogic, "settings": settings, "text": text, "inputs": inputs, "auto": auto}


func test_installed_version_preference_adapter_exists() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/narrative/DialogicPreferenceAdapter.gd")
	assert_true(loaded.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(loaded))
	if not loaded.get("ok", false):
		return
	var adapter: RefCounted = autofree(loaded["value"].new())
	for method_name in [&"bind", &"prepare", &"capture_state", &"apply_silent", &"rollback_silent", &"finalize"]:
		assert_true(adapter.has_method(method_name), "missing %s" % method_name)


func test_dialogic_bridge_exposes_profile_preference_seams() -> void:
	var loaded: Dictionary = PROBE.load_script("res://autoload/DialogicBridge.gd")
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false):
		return
	var bridge: Node = autofree(loaded["value"].new())
	for method_name in [&"configure_mutation_gate", &"bind_profile_preferences", &"apply_profile_preferences", &"reapply_cached_preferences_after_clear"]:
		assert_true(bridge.has_method(method_name), "missing %s" % method_name)


func test_adapter_maps_profile_values_to_live_caches_without_persistence() -> void:
	var fake := _fake_dialogic()
	var adapter: RefCounted = ADAPTER.new()
	assert_true(adapter.call(&"bind", fake["dialogic"]).get("ok", false))
	var profile := {"preferences": {"dialogue": {
		"text_speed": 2.0,
		"auto_text_speed": 4.0,
		"auto_advance_dialogue": true,
	}}}
	var prepared: Dictionary = adapter.call(&"prepare", profile)
	assert_eq(prepared["value"], {
		"text_delay_multiplier": 0.5,
		"auto_delay_multiplier": 0.25,
		"auto_advance_enabled": true,
	})
	assert_true(adapter.call(&"apply_silent", prepared["value"]).get("ok", false))
	assert_eq(fake["settings"].settings[&"text_speed"], 0.5)
	assert_eq(fake["settings"].settings[&"autoadvance_delay_modifier"], 0.25)
	assert_eq(fake["text"].calls, [[-1.0, false, 1.0, 0.5]])
	assert_eq(fake["auto"].delay_modifier, 0.25)
	assert_true(fake["auto"].enabled_until_user_input)
	var backup: Dictionary = adapter.call(&"capture_state")["value"]
	fake["auto"].enabled_until_user_input = false
	backup["plan"]["auto_advance_enabled"] = false
	assert_true(adapter.call(&"rollback_silent", backup).get("ok", false))
	assert_false(fake["auto"].enabled_until_user_input)


func test_committed_dialogue_apply_failure_latches_shared_gate() -> void:
	var profile := FakeBridgeProfile.new()
	add_child_autofree(profile)
	var adapter := FailingPreferenceAdapter.new()
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	var gate: RefCounted = FAKE_GATE.new()
	assert_true(bridge.configure_mutation_gate(gate).get("ok", false))
	assert_true(bridge.bind_profile_preferences(profile, adapter).get("ok", false))
	adapter.fail_apply = true
	profile.preference_changed.emit(&"preferences.dialogue.text_speed", 2.0)
	assert_true(gate.is_fatal_latched())


func test_failed_bridge_binding_is_retryable_and_connects_only_after_apply() -> void:
	var profile := FakeBridgeProfile.new()
	add_child_autofree(profile)
	var adapter := FailingPreferenceAdapter.new()
	adapter.fail_apply = true
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	assert_false(bridge.bind_profile_preferences(profile, adapter).get("ok", true))
	assert_false(profile.preference_changed.is_connected(Callable(bridge, "_on_profile_preference_changed")))
	assert_false(bridge.get("_preferences_bound"))
	adapter.fail_apply = false
	assert_true(bridge.bind_profile_preferences(profile, adapter).get("ok", false))
	assert_true(profile.preference_changed.is_connected(Callable(bridge, "_on_profile_preference_changed")))


func test_bootstrap_binding_applies_installed_dialogic_preferences_exactly_once() -> void:
	var profile := FakeBridgeProfile.new()
	add_child_autofree(profile)
	profile.snapshot["preferences"]["dialogue"] = {
		"text_speed": 2.0,
		"auto_text_speed": 4.0,
		"auto_advance_dialogue": true,
	}
	var adapter := CountingPreferenceAdapter.new()
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	assert_true(bridge.bind_profile_preferences(profile, adapter).get("ok", false))
	assert_eq(adapter.apply_count, 1)
	var dialogic := get_node("/root/Dialogic")
	assert_almost_eq(float(dialogic.Settings.settings[&"text_speed"]), 0.5, 0.001)
	assert_almost_eq(float(dialogic.Inputs.auto_advance.delay_modifier), 0.25, 0.001)
	assert_true(dialogic.Inputs.auto_advance.enabled_until_user_input)
