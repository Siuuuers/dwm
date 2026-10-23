extends GutTest

const AUDIO := preload("res://autoload/AudioManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const WINDOW_MODE := &"preferences.display.window_mode"
const MUSIC := &"preferences.audio.music_volume"

class MemoryFiles extends "res://tests/support/FakeFileOps.gd":
	var reject_write := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if reject_write:
			reject_write = false
			return {"ok": false, "code": &"injected_write_failure"}
		return super.write_bytes(path, bytes)

class AudioPort extends "res://tests/support/FakeAudioPlaybackPort.gd":
	var trace: Array = []
	func capture_output() -> Dictionary:
		trace.append("audio_capture")
		return super.capture_output()
	func set_bus_state(bus: StringName, db: float, muted: bool) -> Dictionary:
		trace.append("audio_bus")
		return super.set_bus_state(bus, db, muted)

class WindowOutput extends Node:
	var _profile: Node
	var _fatal := false
	var available := true
	var trace: Array = []
	var state := {"window_mode": "windowed", "rect": Rect2i(47, 83, 1111, 703)}
	var fail_apply := false
	var fail_rollback := false
	var on_apply: Callable
	var on_capture: Callable
	func get_settings_window_capability() -> Dictionary:
		return {"ok": true, "value": {"available": available and not _fatal}}
	func get_applied_mode() -> String:
		return state.window_mode
	func get_applied_size() -> String:
		return state.get("window_size", "1280x720")
	func capture_restore_state() -> Dictionary:
		trace.append("window_capture")
		var captured := state.duplicate(true)
		if on_capture.is_valid():
			var callback := on_capture
			on_capture = Callable()
			callback.call()
		return {"ok": true, "value": captured}
	func apply_restore_silent(candidate: Dictionary) -> Dictionary:
		trace.append("window_apply")
		if fail_apply:
			fail_apply = false
			return {"ok": false, "code": &"injected_window_apply_failure"}
		state = {"window_mode": candidate.window_mode, "window_size": candidate.window_size, "rect": Rect2i(0, 0, 1280, 720) if candidate.window_mode == "borderless" else Rect2i(100, 100, 960, 540)}
		if on_apply.is_valid():
			var callback := on_apply
			on_apply = Callable()
			callback.call()
		return {"ok": true, "value": state.duplicate(true)}
	func rollback_restore_silent(capsule: Dictionary) -> Dictionary:
		trace.append("window_rollback")
		if fail_rollback: return {"ok": false, "code": &"injected_window_rollback_failure"}
		state = capsule.duplicate(true)
		return {"ok": true}
	func latch_output_failure(_phase: StringName, _cause: Dictionary) -> void:
		_fatal = true

func _fixture(bind_window: bool = true) -> Dictionary:
	var files := MemoryFiles.new()
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("settings-window.memory", files)).ok)
	var gate := GATE.new()
	assert_true(profile.configure_mutation_gate(gate).ok)
	var port := AudioPort.new()
	var audio := AUDIO.new(port)
	add_child_autofree(audio)
	assert_true(audio.configure_mutation_gate(gate).ok)
	assert_true(audio.initialize(profile).ok)
	var window := WindowOutput.new()
	add_child_autofree(window)
	window._profile = profile
	window.trace = port.trace
	var helper: RefCounted = audio.get_settings_output_transactions()
	if bind_window: assert_true(helper.bind_window_output(window).ok)
	port.trace.clear()
	return {"profile": profile, "files": files, "gate": gate, "audio": audio,
		"port": port, "window": window, "helper": helper, "trace": port.trace}

func test_window_binding_has_one_identity_and_requires_the_same_profile() -> void:
	var f := _fixture(false)
	var wrong := WindowOutput.new()
	add_child_autofree(wrong)
	assert_false(f.helper.bind_window_output(wrong).ok)
	assert_true(f.helper.bind_window_output(f.window).ok)
	assert_true(f.helper.bind_window_output(f.window).value.already_bound)
	wrong._profile = f.profile
	assert_eq(f.helper.bind_window_output(wrong).code, &"settings_window_already_bound")
	assert_true(f.trace.is_empty())

func test_window_commit_applies_before_one_deferred_profile_publication() -> void:
	var f := _fixture()
	var revision: int = f.profile.get_profile_revision()
	var observations: Array = []
	f.profile.preference_changed.connect(func(path, value):
		if path == WINDOW_MODE:
			observations.append([value, f.window.get_applied_mode(), f.helper.is_busy()]))
	assert_true(f.helper.commit_settings_window_preference("settings", "borderless").ok)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(observations, [["borderless", "borderless", true]])
	assert_eq(f.trace[0], "window_capture")
	assert_lt(f.trace.find("audio_capture"), f.trace.find("audio_bus"))
	assert_lt(f.trace.find("audio_bus"), f.trace.find("window_apply"))
	assert_eq(f.trace.count("window_apply"), 1)
	assert_false(f.helper.is_busy())

func test_audio_preview_commit_and_cancel_never_touch_an_unchanged_window() -> void:
	var f := _fixture()
	var window_before: Dictionary = f.window.state.duplicate(true)
	var preview: Dictionary = f.audio.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(preview.ok)
	if not preview.ok: return
	assert_eq(f.helper.commit_settings_window_preference("settings", "borderless").code, &"settings_audio_busy")
	assert_true(f.audio.commit_settings_audio_preference("settings", MUSIC, 0.3, preview.value.preview_handle).ok)
	var next: Dictionary = f.audio.preview_settings_volume("settings", MUSIC, 0.2)
	assert_true(next.ok)
	if not next.ok: return
	assert_true(f.audio.cancel_settings_volume_preview(next.value.preview_handle).ok)
	assert_eq(f.window.state, window_before)
	for operation: String in f.trace: assert_false(operation.begins_with("window_"))

func test_invalid_stale_and_gate_refusals_happen_before_capture_or_output() -> void:
	var f := _fixture()
	assert_false(f.helper.commit_settings_window_preference("settings", "exclusive").ok)
	assert_true(f.trace.is_empty())
	var revision: int = f.profile.get_profile_revision()
	assert_true(f.profile.set_preference(MUSIC, 0.2).ok)
	f.trace.clear()
	assert_eq(f.helper.commit_settings_profile_reset("settings", &"reset_preferences", revision).code, &"profile_revision_changed")
	assert_true(f.trace.is_empty())
	var acquired: Dictionary = f.gate.acquire(&"restore")
	assert_true(acquired.ok)
	assert_eq(f.helper.commit_settings_window_preference("settings", "borderless").code, &"TRANSACTION_ACTIVE")
	assert_true(f.trace.is_empty())
	assert_true(f.gate.release(&"restore", acquired.value.token).ok)

func test_reset_that_changes_window_refuses_unbound_or_unavailable_output_before_audio() -> void:
	for bind: bool in [false, true]:
		var f := _fixture(bind)
		assert_true(f.profile.set_preference(WINDOW_MODE, "borderless").ok)
		f.window.state.window_mode = "borderless"
		f.window.available = false
		var revision: int = f.profile.get_profile_revision()
		f.trace.clear()
		assert_eq(f.helper.commit_settings_profile_reset("settings", &"reset_preferences", revision).code, &"settings_window_unavailable")
		assert_true(f.trace.is_empty())
		assert_eq(f.profile.get_profile_revision(), revision)
		assert_eq(f.profile.get_preference(WINDOW_MODE), "borderless")

func test_disk_failure_restores_exact_resized_window_before_audio_compensation() -> void:
	var f := _fixture()
	var before: Dictionary = f.window.state.duplicate(true)
	var revision: int = f.profile.get_profile_revision()
	var publications: Array = []
	f.profile.preference_changed.connect(func(path, value): publications.append([path, value]))
	f.files.reject_write = true
	assert_false(f.helper.commit_settings_window_preference("settings", "borderless").ok)
	assert_eq(f.window.state, before)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.profile.get_preference(WINDOW_MODE), "windowed")
	assert_true(publications.is_empty())
	var rollback: int = f.trace.find("window_rollback")
	assert_gt(rollback, f.trace.find("window_apply"))
	assert_eq(f.trace[rollback + 1], "audio_capture", "reverse compensation restores window before audio")
	assert_false(f.audio._fatal)

func test_reset_combines_audio_window_and_one_profile_reset_publication() -> void:
	var f := _fixture()
	assert_true(f.profile.set_preferences({MUSIC: 0.2, WINDOW_MODE: "borderless"}).ok)
	f.window.state = {"window_mode": "borderless", "rect": Rect2i(0, 0, 1600, 900)}
	f.trace.clear()
	var revision: int = f.profile.get_profile_revision()
	var resets: Array = []
	f.profile.profile_reset.connect(func(section): resets.append([section, f.window.get_applied_mode(), f.audio._settings[&"music"].volume]))
	assert_true(f.helper.commit_settings_profile_reset("settings", &"reset_preferences", revision).ok)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(resets, [[&"preferences", "windowed", 0.8]])
	assert_eq(f.profile.get_preference(WINDOW_MODE), "windowed")
	assert_eq(f.trace.count("window_capture"), 1)
	assert_eq(f.trace.count("window_apply"), 1)

func test_failed_reset_restores_both_outputs_without_partial_profile_adoption() -> void:
	var f := _fixture()
	assert_true(f.profile.set_preferences({MUSIC: 0.2, WINDOW_MODE: "borderless"}).ok)
	f.window.state = {"window_mode": "borderless", "rect": Rect2i(13, 27, 1600, 900)}
	var before: Dictionary = f.window.state.duplicate(true)
	var profile: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	f.files.reject_write = true
	assert_false(f.helper.commit_settings_profile_reset("settings", &"reset_preferences", revision).ok)
	assert_eq(f.window.state, before)
	assert_eq(f.profile.get_profile_snapshot(), profile)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.audio._settings[&"music"].volume, 0.2)
	assert_almost_eq(f.port.bus_states[&"Music"].db, linear_to_db(0.2), 0.0001)

func test_new_profile_commit_during_window_apply_wins_over_original_geometry() -> void:
	var f := _fixture()
	var revision: int = f.profile.get_profile_revision()
	var callback_results: Array = []
	f.window.on_apply = func(): callback_results.append(f.profile.set_preferences({WINDOW_MODE: "borderless", MUSIC: 0.6}))
	assert_eq(f.helper.commit_settings_window_preference("settings", "borderless").code, &"settings_audio_commit_conflict")
	assert_eq(callback_results.size(), 1)
	if callback_results.size() == 1: assert_true(callback_results[0].ok)
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(f.window.get_applied_mode(), "borderless")
	assert_eq(f.trace.count("window_rollback"), 0)
	assert_eq(f.audio._settings[&"music"].volume, 0.6)
	assert_almost_eq(f.port.bus_states[&"Music"].db, linear_to_db(0.6), 0.0001)

func test_publication_callback_reverting_mode_applies_latest_instead_of_old_geometry() -> void:
	var f := _fixture()
	var before: Dictionary = f.window.state.duplicate(true)
	var callbacks: Array = []
	f.profile.preference_changed.connect(func(path, value):
		if path == WINDOW_MODE and value == "borderless": callbacks.append(f.profile.set_preference(WINDOW_MODE, "windowed")))
	assert_true(f.helper.commit_settings_window_preference("settings", "borderless").ok)
	assert_eq(callbacks.size(), 1)
	assert_eq(f.profile.get_preference(WINDOW_MODE), "windowed")
	assert_eq(f.window.get_applied_mode(), "windowed")
	assert_ne(f.window.state.rect, before.rect)
	assert_eq(f.trace.count("window_rollback"), 0)
	assert_eq(f.trace.count("window_apply"), 2)

func test_unproved_window_compensation_latches_shared_fatal() -> void:
	var f := _fixture()
	f.files.reject_write = true
	f.window.fail_rollback = true
	assert_eq(f.helper.commit_settings_window_preference("settings", "borderless").code, &"audio_runtime_indeterminate")
	assert_true(f.audio._fatal)
	assert_true(f.gate.is_fatal_latched())
	assert_eq(f.profile.get_preference(WINDOW_MODE), "windowed")
	assert_false(f.helper.is_busy())

func test_window_apply_failure_compensates_audio_and_retains_exact_prior_geometry() -> void:
	var f := _fixture()
	assert_true(f.profile.set_preferences({MUSIC: 0.2, WINDOW_MODE: "borderless"}).ok)
	f.window.state = {"window_mode": "borderless", "rect": Rect2i(13, 27, 1600, 900)}
	var before: Dictionary = f.window.state.duplicate(true)
	var profile: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	f.trace.clear()
	f.window.fail_apply = true
	assert_eq(f.helper.commit_settings_profile_reset("settings", &"reset_preferences", revision).code, &"injected_window_apply_failure")
	assert_eq(f.window.state, before)
	assert_eq(f.profile.get_profile_snapshot(), profile)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.audio._settings[&"music"].volume, 0.2)
	assert_almost_eq(f.port.bus_states[&"Music"].db, linear_to_db(0.2), 0.0001)
	var rollback: int = f.trace.find("window_rollback")
	assert_gt(rollback, f.trace.find("window_apply"))
	assert_eq(f.trace[rollback + 1], "audio_capture")
	assert_false(f.audio._fatal)

class FirstRollbackFailurePort extends RefCounted:
	var state := {"mode": "windowed", "rect": Rect2i(41, 73, 1110, 670)}
	var armed := false
	var rollback_count := 0
	func capture_output() -> Dictionary:
		return {"ok": true, "value": state.duplicate(true)}
	func apply_mode(mode: String, _window_size: String = "1280x720") -> Dictionary:
		state = {"mode": mode, "rect": Rect2i(0, 0, 1280, 720)}
		if armed: return {"ok": false, "code": &"injected_window_apply_failure"}
		return {"ok": true}
	func output_matches(mode: String, _window_size: String = "1280x720") -> bool:
		return state.mode == mode
	func restore_output(capsule: Dictionary) -> Dictionary:
		rollback_count += 1
		if armed and rollback_count == 1:
			return {"ok": false, "code": &"injected_first_window_rollback_failure"}
		state = capsule.duplicate(true)
		return {"ok": true}

func test_helper_attempts_its_window_backup_after_native_owner_internal_rollback_latches_fatal() -> void:
	var f := _fixture(false)
	var physical := FirstRollbackFailurePort.new()
	var window := preload("res://autoload/WindowModeManager.gd").new(physical)
	add_child_autofree(window)
	assert_true(window.configure_mutation_gate(f.gate).ok)
	assert_true(window.initialize(f.profile, f.helper).ok)
	physical.state.rect = Rect2i(47, 83, 1111, 703)
	var before: Dictionary = physical.state.duplicate(true)
	var revision: int = f.profile.get_profile_revision()
	physical.armed = true
	var result: Dictionary = f.helper.commit_settings_window_preference("settings", "borderless")
	assert_false(result.ok)
	assert_eq(result.code, &"window_output_indeterminate")
	assert_eq(physical.rollback_count, 2, "helper recovery attempts its own capsule after the owner's first rollback fails")
	assert_eq(physical.state, before)
	assert_eq(window.get_applied_mode(), "windowed")
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.profile.get_preference(WINDOW_MODE), "windowed")
	assert_true(window._fatal, "proved recovery does not clear the owner's irreversible fatal state")
	assert_true(f.gate.is_fatal_latched())
	assert_false(f.helper.is_busy())
	assert_eq(f.audio.commit_settings_audio_preference("settings", MUSIC, 0.2).code, &"APPLICATION_FATAL")
