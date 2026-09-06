extends GutTest

const WINDOW := preload("res://autoload/WindowModeManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const AUDIO_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const PATH := &"preferences.display.window_mode"

class MemoryFiles extends "res://tests/support/FakeFileOps.gd":
	var reject_write := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if reject_write:
			reject_write = false
			return {"ok": false, "code": &"injected_write_failure"}
		return super.write_bytes(path, bytes)

## Manager orchestration double only. Actual DisplayServer geometry is exercised
## separately by test_window_mode_port and verify_window_mode_native.
class PhysicalWindow extends RefCounted:
	var available := true
	var fail_apply := false
	var fail_restore := false
	var lie_apply := false
	var operations: Array = []
	var state := {"mode": "windowed", "screen": 1, "position": Vector2i(17, 31), "size": Vector2i(900, 700)}
	func capture_output() -> Dictionary:
		if not available: return {"ok": false, "code": &"window_output_unavailable"}
		return {"ok": true, "value": state.duplicate(true)}
	func apply_mode(mode: String) -> Dictionary:
		operations.append(["apply", mode])
		if not lie_apply:
			state.mode = mode
			state.position = Vector2i.ZERO
			state.size = Vector2i(1600, 860) if mode == "borderless" else Vector2i(1280, 720)
		if fail_apply:
			fail_apply = false
			return {"ok": false, "code": &"injected_window_apply"}
		return {"ok": true}
	func output_matches(mode: String) -> bool: return available and state.mode == mode
	func restore_output(snapshot: Dictionary) -> Dictionary:
		operations.append(["restore", snapshot.duplicate(true)])
		if fail_restore: return {"ok": false, "code": &"injected_window_restore"}
		state = snapshot.duplicate(true)
		return {"ok": true}

func _fixture(available: bool = true, initialize_window: bool = true) -> Dictionary:
	var files := MemoryFiles.new()
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("window-manager.memory", files)).ok)
	var gate := GATE.new()
	assert_true(profile.configure_mutation_gate(gate).ok)
	var audio_port := AUDIO_PORT.new()
	var audio := AUDIO.new(audio_port)
	add_child_autofree(audio)
	assert_true(audio.configure_mutation_gate(gate).ok)
	assert_true(audio.initialize(profile).ok)
	var port := PhysicalWindow.new()
	port.available = available
	var owner := WINDOW.new(port)
	add_child_autofree(owner)
	assert_true(owner.configure_mutation_gate(gate).ok)
	var initialized: Dictionary = {}
	if initialize_window:
		initialized = owner.initialize(profile, audio.get_settings_output_transactions())
		assert_true(initialized.ok)
	return {"owner": owner, "port": port, "profile": profile, "files": files,
		"audio": audio, "audio_port": audio_port, "gate": gate, "initialized": initialized}

func test_ready_owner_commits_once_through_real_profile_and_shared_output_transaction() -> void:
	var f := _fixture()
	assert_true(f.owner.get_settings_window_capability().value.available)
	assert_same(f.owner.get_settings_output_transactions(), f.audio.get_settings_output_transactions())
	var revision: int = f.profile.get_profile_revision()
	var publications: Array = []
	f.profile.preference_changed.connect(func(path, value): publications.append([path, value]))
	var players: Dictionary = f.audio_port.players.duplicate(true)
	assert_true(f.owner.commit_settings_window_preference("settings-test", "borderless").ok)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(publications, [[PATH, "borderless"]])
	assert_eq(f.profile.get_preference(PATH), "borderless")
	assert_eq(f.owner.get_applied_mode(), "borderless")
	assert_true(f.port.output_matches("borderless"))
	assert_eq(f.audio_port.players, players)
	assert_false(f.audio.get_settings_output_transactions().is_busy())

func test_headless_owner_initializes_as_unavailable_without_physical_or_profile_mutation() -> void:
	var f := _fixture(false)
	assert_false(f.initialized.value.available)
	assert_false(f.owner.get_settings_window_capability().value.available)
	var snapshot: Dictionary = f.profile.get_profile_snapshot()
	assert_eq(f.owner.commit_settings_window_preference("settings", "borderless").code, &"window_output_unavailable")
	assert_eq(f.profile.get_profile_snapshot(), snapshot)
	assert_true(f.port.operations.is_empty())
	assert_eq(f.owner.capture_restore_state().code, &"window_output_unavailable")

func test_failed_physical_apply_restores_exact_prior_geometry_and_does_not_publish() -> void:
	var f := _fixture()
	f.port.state.position = Vector2i(111, 73)
	f.port.state.size = Vector2i(1050, 650)
	var physical: Dictionary = f.port.state.duplicate(true)
	var profile: Dictionary = f.profile.get_profile_snapshot()
	var persisted: Dictionary = f.files.snapshot_persisted()
	f.port.fail_apply = true
	assert_false(f.owner.commit_settings_window_preference("settings", "borderless").ok)
	assert_eq(f.port.state, physical)
	assert_eq(f.owner.get_applied_mode(), "windowed")
	assert_eq(f.profile.get_profile_snapshot(), profile)
	assert_eq(f.files.snapshot_persisted(), persisted)
	assert_false(f.gate.is_fatal_latched())

func test_failed_persistence_restores_prior_output_not_generic_windowed_geometry() -> void:
	var f := _fixture()
	f.port.state.position = Vector2i(81, 117)
	f.port.state.size = Vector2i(1110, 680)
	var physical: Dictionary = f.port.state.duplicate(true)
	var profile: Dictionary = f.profile.get_profile_snapshot()
	f.files.reject_write = true
	assert_false(f.owner.commit_settings_window_preference("settings", "borderless").ok)
	assert_eq(f.port.state, physical)
	assert_eq(f.profile.get_profile_snapshot(), profile)
	assert_false(f.gate.is_fatal_latched())

func test_unproved_apply_and_failed_rollback_latch_shared_fatal() -> void:
	var f := _fixture()
	var profile: Dictionary = f.profile.get_profile_snapshot()
	f.port.lie_apply = true
	f.port.fail_restore = true
	assert_false(f.owner.commit_settings_window_preference("settings", "borderless").ok)
	assert_true(f.gate.is_fatal_latched())
	assert_false(f.owner.get_settings_window_capability().value.available)
	assert_eq(f.profile.get_profile_snapshot(), profile)
	var count: int = f.port.operations.size()
	assert_false(f.owner.commit_settings_window_preference("settings", "borderless").ok)
	assert_eq(f.port.operations.size(), count)

func test_publication_profile_change_is_settled_to_latest_committed_mode() -> void:
	var f := _fixture()
	var nested: Array = []
	f.profile.preference_changed.connect(func(path, value):
		if path == PATH and value == "borderless":
			nested.append(f.owner.commit_settings_window_preference("reentrant", "windowed"))
			nested.append(f.profile.set_preference(PATH, "windowed")))
	assert_true(f.owner.commit_settings_window_preference("settings", "borderless").ok)
	assert_eq(nested.size(), 2)
	if nested.size() == 2:
		assert_false(nested[0].ok)
		assert_true(nested[1].ok)
	assert_eq(f.profile.get_preference(PATH), "windowed")
	assert_eq(f.owner.get_applied_mode(), "windowed")
	assert_true(f.port.output_matches("windowed"))

func test_second_window_owner_binding_refuses_and_restores_its_prior_physical_state() -> void:
	var f := _fixture()
	var second_port := PhysicalWindow.new()
	var physical := second_port.state.duplicate(true)
	var second := WINDOW.new(second_port)
	add_child_autofree(second)
	assert_false(second.initialize(f.profile, f.audio.get_settings_output_transactions()).ok)
	assert_eq(second_port.state, physical)
	assert_false(second.get_settings_window_capability().value.available)
	assert_true(f.owner.get_settings_window_capability().value.available)
	assert_eq(f.owner.initialize(f.profile, f.audio.get_settings_output_transactions()).code, &"already_initialized")

func test_invalid_restore_plans_refuse_and_silent_restore_does_not_publish_profile() -> void:
	var f := _fixture()
	var count: int = f.port.operations.size()
	for plan: Dictionary in [{}, {"window_mode": "fullscreen"}, {"window_mode": "windowed", "extra": true}]:
		assert_false(f.owner.apply_restore_silent(plan).ok)
	assert_eq(f.port.operations.size(), count)
	var physical: Dictionary = f.owner.capture_restore_state().value
	var profile: Dictionary = f.profile.get_profile_snapshot()
	var prepared: Dictionary = f.owner.prepare_restore({"display": {"window_mode": "borderless"}})
	assert_true(prepared.ok)
	assert_true(f.owner.apply_restore_silent(prepared.value).ok)
	assert_eq(f.profile.get_profile_snapshot(), profile)
	assert_true(f.owner.rollback_restore_silent(physical).ok)
	assert_eq(f.owner.capture_restore_state().value, physical)
	assert_true(f.owner.finalize_restore().ok)

func test_failed_initialization_retains_one_binding_and_only_exact_dependencies_can_retry() -> void:
	var f := _fixture(true, false)
	var other := _fixture(true, false)
	var helper: RefCounted = f.audio.get_settings_output_transactions()
	var other_helper: RefCounted = other.audio.get_settings_output_transactions()
	var original: Dictionary = f.port.state.duplicate(true)
	var profile: Dictionary = f.profile.get_profile_snapshot()
	f.port.fail_apply = true
	assert_eq(f.owner.initialize(f.profile, helper).code, &"injected_window_apply")
	assert_eq(f.port.state, original, "failed initial output is compensated exactly")
	assert_false(f.owner.get_settings_window_capability().value.available)
	assert_false(f.gate.is_fatal_latched())
	var setters: int = f.port.operations.size()
	for dependencies: Array in [[other.profile, helper], [f.profile, other_helper], [other.profile, other_helper]]:
		assert_eq(f.owner.initialize(dependencies[0], dependencies[1]).code, &"settings_output_owner_already_bound")
		assert_eq(f.port.operations.size(), setters)
		assert_eq(f.port.state, original)
	assert_true(f.owner.initialize(f.profile, helper).ok)
	assert_true(f.owner.get_settings_window_capability().value.available)
	assert_eq(f.profile.get_profile_snapshot(), profile, "initialization retry never persists Profile")
	assert_same(f.owner.get_settings_output_transactions(), helper)
	assert_true(helper.bind_window_output(f.owner).value.already_bound)
	assert_false(helper.bind_window_output(other.owner).ok, "the first helper retains exactly its original owner")
	assert_true(other.owner.initialize(other.profile, other_helper).ok, "rejected retry did not contaminate the other helper")
	assert_true(other_helper.bind_window_output(other.owner).value.already_bound)
	assert_false(other_helper.bind_window_output(f.owner).ok)
	var notifications: Array = []
	f.profile.preference_changed.connect(func(path, value): notifications.append([path, value]))
	assert_true(f.owner.commit_settings_window_preference("retry-proof", "borderless").ok)
	assert_eq(notifications, [[PATH, "borderless"]])
	assert_eq(other.profile.get_preference(PATH), "windowed")
	assert_eq(other.owner.get_applied_mode(), "windowed")

class IncompleteProfile extends Node:
	func get_preference(_path: StringName, fallback: Variant = null) -> Variant:
		return fallback

func test_get_preference_only_profile_is_cleanly_refused_before_binding_or_output() -> void:
	var f := _fixture(true, false)
	var incomplete := IncompleteProfile.new()
	add_child_autofree(incomplete)
	var helper: RefCounted = f.audio.get_settings_output_transactions()
	var original: Dictionary = f.port.state.duplicate(true)
	assert_eq(f.owner.initialize(incomplete, helper).code, &"invalid_settings_output_owner")
	assert_true(f.port.operations.is_empty())
	assert_eq(f.port.state, original)
	assert_false(f.owner.get_settings_window_capability().value.available)
	assert_true(f.owner.initialize(f.profile, helper).ok, "refused incomplete owner leaves valid first binding available")
