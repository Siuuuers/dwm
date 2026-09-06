extends GutTest
## Bootstrap composition only: all output owners are real; window pixels remain modeled.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const WINDOW := preload("res://autoload/WindowModeManager.gd")
const AUDIO_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const WINDOW_TESTS := preload("res://tests/unit/test_window_mode_manager.gd")
const PARTICIPANT_KEYS := ["audio", "desktop_board", "desktop_consequence", "localization", "narrative", "profile", "route", "run"]

class InjectableBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var injected_targets: Dictionary = {}
	func _target(target_name: StringName) -> Node:
		return injected_targets.get(target_name)

class SaveCapture extends Node:
	var configure_count := 0
	var participants: Dictionary = {}
	func configure_restore_participants(value: Dictionary) -> Dictionary:
		configure_count += 1
		participants = value.duplicate()
		return {"ok": true, "code": &"ok"}

class DayState extends Node:
	var day := 1

func _fixture(available: bool = true, mode: String = "windowed") -> Dictionary:
	var profile := PROFILE.new()
	autofree(profile)
	assert_true(profile.initialize(STORAGE.new("bootstrap-window.memory", FILES.new())).ok)
	if mode != "windowed": assert_true(profile.set_preference(&"preferences.display.window_mode", mode).ok)
	var audio := AUDIO.new(AUDIO_PORT.new())
	autofree(audio)
	assert_true(audio.initialize(profile).ok)
	var physical := WINDOW_TESTS.PhysicalWindow.new()
	physical.available = available
	var window := WINDOW.new(physical)
	autofree(window)
	var save := SaveCapture.new()
	autofree(save)
	var bootstrap := InjectableBootstrap.new()
	autofree(bootstrap)
	bootstrap.injected_targets = {
		&"ProfileManager": profile, &"AudioManager": audio, &"WindowModeManager": window,
		&"SaveManager": save, &"GameState": autofree(DayState.new()),
		&"LocalizationManager": autofree(Node.new()), &"SceneRouter": autofree(Node.new()),
		&"DialogicBridge": autofree(Node.new()),
	}
	return {"bootstrap": bootstrap, "profile": profile, "audio": audio,
		"window": window, "physical": physical, "save": save}

func _initialize_window(f: Dictionary) -> Dictionary:
	return f.bootstrap._run_stage(&"initialize_window_mode", &"final")

func test_window_stage_order_and_missing_dependencies_refuse_before_physical_output() -> void:
	var f := _fixture()
	var order: Array = f.bootstrap.STAGE_ORDER
	assert_eq(order.find(&"initialize_window_mode"), order.find(&"initialize_audio") + 1)
	assert_lt(order.find(&"initialize_window_mode"), order.find(&"configure_restore_participants"))
	for missing: StringName in [&"ProfileManager", &"AudioManager", &"WindowModeManager"]:
		var original: Node = f.bootstrap.injected_targets[missing]
		f.bootstrap.injected_targets.erase(missing)
		assert_eq(_initialize_window(f).code, &"missing_stage_adapter", String(missing))
		assert_true(f.physical.operations.is_empty())
		assert_false(f.window.is_output_initialized())
		f.bootstrap.injected_targets[missing] = original
	f.bootstrap.injected_targets[&"AudioManager"] = autofree(Node.new())
	assert_eq(_initialize_window(f).code, &"missing_stage_adapter")
	assert_true(f.physical.operations.is_empty())

func test_real_stage_applies_saved_mode_and_rejects_replacement_owner_before_setters() -> void:
	var f := _fixture(true, "borderless")
	var revision: int = f.profile.get_profile_revision()
	assert_true(_initialize_window(f).ok)
	assert_true(f.window.is_output_initialized())
	assert_same(f.window.get_settings_output_transactions(), f.audio.get_settings_output_transactions())
	assert_eq(f.window.get_applied_mode(), "borderless")
	assert_true(f.physical.output_matches("borderless"))
	assert_eq(f.profile.get_profile_revision(), revision, "bootstrap projects saved preferences without rewriting Profile")
	var replacement_physical := WINDOW_TESTS.PhysicalWindow.new()
	var replacement := WINDOW.new(replacement_physical)
	autofree(replacement)
	f.bootstrap.injected_targets[&"WindowModeManager"] = replacement
	assert_eq(_initialize_window(f).code, &"settings_window_already_bound")
	assert_true(replacement_physical.operations.is_empty(), "replacement cannot call physical setters before binding refusal")
	assert_false(replacement.is_output_initialized())
	assert_eq(f.window.get_applied_mode(), "borderless")

func test_restore_wiring_embeds_exact_window_in_profile_without_adding_outer_participant() -> void:
	var f := _fixture()
	assert_true(_initialize_window(f).ok)
	assert_true(f.bootstrap._configure_restore_participants().ok)
	assert_eq(f.save.configure_count, 1)
	var keys: Array = f.save.participants.keys()
	keys.sort()
	assert_eq(keys, PARTICIPANT_KEYS)
	assert_same(f.save.participants.profile._window_output, f.window)
	assert_same(f.save.participants.profile._owner, f.profile)
	assert_same(f.save.participants.audio._owner, f.audio)
	assert_same(f.bootstrap._retained_restore_participants.profile, f.save.participants.profile)

func test_uninitialized_or_other_transaction_window_refuses_before_save_configuration() -> void:
	var uninitialized := _fixture()
	assert_eq(uninitialized.bootstrap._configure_restore_participants().code, &"missing_stage_adapter")
	assert_eq(uninitialized.save.configure_count, 0)
	assert_true(uninitialized.bootstrap._retained_restore_participants.is_empty())
	var first := _fixture()
	var other := _fixture()
	assert_true(_initialize_window(first).ok)
	assert_true(_initialize_window(other).ok)
	first.bootstrap.injected_targets[&"WindowModeManager"] = other.window
	assert_eq(first.bootstrap._configure_restore_participants().code, &"missing_stage_adapter")
	assert_eq(first.save.configure_count, 0)
	assert_true(first.bootstrap._retained_restore_participants.is_empty())

func test_unavailable_native_window_is_ready_but_supplies_no_physical_restore_binding() -> void:
	var f := _fixture(false, "borderless")
	var initialized := _initialize_window(f)
	assert_true(initialized.ok)
	assert_false(initialized.value.available)
	assert_true(f.window.is_output_initialized())
	assert_false(f.window.get_settings_window_capability().value.available)
	assert_same(f.window.get_settings_output_transactions(), f.audio.get_settings_output_transactions())
	assert_true(f.physical.operations.is_empty())
	assert_true(f.bootstrap._configure_restore_participants().ok)
	assert_eq(f.save.configure_count, 1)
	assert_null(f.save.participants.profile._window_output)
	var keys: Array = f.save.participants.keys()
	keys.sort()
	assert_eq(keys, PARTICIPANT_KEYS)
	assert_eq(f.window.capture_restore_state().code, &"window_output_unavailable")

class GateTarget extends Node:
	var retained_gate: Object
	func configure_mutation_gate(gate: Object) -> Dictionary:
		retained_gate = gate
		return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": false}}

func test_actual_final_gate_injection_retains_one_identity_in_real_window_and_every_target() -> void:
	var bootstrap := InjectableBootstrap.new()
	autofree(bootstrap)
	var physical := WINDOW_TESTS.PhysicalWindow.new()
	var window := WINDOW.new(physical)
	autofree(window)
	for target_name: StringName in bootstrap.FINAL_GATE_TARGETS:
		bootstrap.injected_targets[target_name] = window if target_name == &"WindowModeManager" else autofree(GateTarget.new())
	var injected: Dictionary = bootstrap._construct_and_inject_mutation_gate(&"final")
	assert_true(injected.ok, "the actual final stage must accept WindowManager's retained gate identity")
	if not injected.ok: return
	var gate: Object = bootstrap._application_gate
	assert_not_null(gate)
	assert_same(window._mutation_gate, gate)
	for target_name: StringName in bootstrap.FINAL_GATE_TARGETS:
		if target_name != &"WindowModeManager":
			assert_same(bootstrap.injected_targets[target_name].retained_gate, gate, String(target_name))
	var record: Dictionary = bootstrap._state.gate_injection
	assert_eq(record.factory_invocation_count, 1)
	assert_eq(record.targets, bootstrap.FINAL_GATE_TARGETS)
	assert_eq(record.target_instance_ids.size(), bootstrap.FINAL_GATE_TARGETS.size())
	for retained_id: int in record.target_instance_ids: assert_eq(retained_id, gate.get_instance_id())
	var repeated: Dictionary = window.configure_mutation_gate(gate)
	assert_true(repeated.ok)
	assert_eq(repeated.value.gate_instance_id, gate.get_instance_id())
	assert_true(repeated.value.already_configured)
	assert_true(physical.operations.is_empty(), "gate wiring itself cannot set the physical window")
