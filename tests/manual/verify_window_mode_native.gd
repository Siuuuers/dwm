extends SceneTree
## Isolated Windows runner only. Root launches it in a disposable test user root.
## It moves the real main window, restores the entry capsule even after failed
## assertions, and uses memory-only Profile storage and a silent Audio port.

const PORT := preload("res://scripts/display/WindowModePort.gd")
const MANAGER := preload("res://autoload/WindowModeManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const AUDIO := preload("res://autoload/AudioManager.gd")
const AUDIO_PORT := preload("res://tests/support/FakeAudioPlaybackPort.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const PATH := &"preferences.display.window_mode"
const DESTINATION := "user://evidence/settings_window/native-window.json"

var _port: RefCounted
var _original: Dictionary = {}
var _checks: Array = []
var _states: Dictionary = {}
var _failed := false
var _profile: Node
var _audio: Node
var _manager: Node

func _initialize() -> void:
	# Capture before deferred setup or manager initialization can change the mode.
	_port = PORT.new()
	var captured: Dictionary = _port.capture_output()
	_check(captured.get("ok", false), "capture_entry_window")
	if captured.get("ok", false):
		_original = captured.value.duplicate(true)
		_states.entry = _serialize(_original)
	call_deferred("_run")

func _run() -> void:
	if not _original.is_empty():
		_verify_port()
		if not _failed: _verify_manager_pipeline()
	# No test failure may bypass cleanup of a captured physical window.
	if is_instance_valid(_manager): _manager.free()
	if is_instance_valid(_audio): _audio.free()
	if is_instance_valid(_profile): _profile.free()
	if not _original.is_empty():
		var restored: Dictionary = _port.restore_output(_original)
		_check(restored.get("ok", false), "restore_entry_window")
		var observed: Dictionary = _port.capture_output()
		_check(observed.get("ok", false) and observed.get("value", {}) == _original, "exact_entry_readback")
		if observed.get("ok", false): _states.restored = _serialize(observed.value)
	var directory := ProjectSettings.globalize_path(DESTINATION.get_base_dir())
	var created := DirAccess.make_dir_recursive_absolute(directory)
	_check(created == OK or created == ERR_ALREADY_EXISTS, "evidence_directory")
	var file := FileAccess.open(DESTINATION, FileAccess.WRITE)
	_check(file != null, "evidence_file")
	if file != null:
		file.store_string(JSON.stringify({"ok": not _failed, "backend": DisplayServer.get_name(),
			"checks": _checks, "states": _states,
			"scope": "Native main-window geometry and one real Profile commit; memory-only storage, fake silent audio; no audible or GPU typography claim."}, "\t"))
		file.close()
	print("WINDOW_MODE_NATIVE_VERIFIED checks=%d ok=%s evidence=%s" % [_checks.size(), not _failed, DESTINATION])
	quit(1 if _failed else 0)

func _verify_port() -> void:
	var borderless: Dictionary = _port.apply_mode("borderless")
	_check(borderless.get("ok", false), "apply_borderless")
	_check(_port.output_matches("borderless"), "borderless_native_readback")
	var observed: Dictionary = _port.capture_output()
	if observed.get("ok", false):
		_states.borderless = _serialize(observed.value)
		var usable := DisplayServer.screen_get_usable_rect(observed.value.screen)
		_check(observed.value.mode == DisplayServer.WINDOW_MODE_WINDOWED, "borderless_not_fullscreen")
		_check(observed.value.position == usable.position and observed.value.size == usable.size, "exact_current_usable_bounds")
	else:
		_check(false, "capture_borderless")
	if _failed: return
	var windowed: Dictionary = _port.apply_mode("windowed")
	_check(windowed.get("ok", false), "apply_windowed")
	_check(_port.output_matches("windowed"), "windowed_native_readback")
	observed = _port.capture_output()
	if observed.get("ok", false):
		_states.windowed = _serialize(observed.value)
		_check(observed.value.size == Vector2i(1280, 720), "windowed_1280_by_720")
	else:
		_check(false, "capture_windowed")

func _verify_manager_pipeline() -> void:
	var files := FILES.new()
	_profile = PROFILE.new()
	root.add_child(_profile)
	var initialized: Dictionary = _profile.initialize(STORAGE.new("window-native.memory", files))
	_check(initialized.get("ok", false), "memory_profile_initialized")
	if not initialized.get("ok", false): return
	var gate := GATE.new()
	_check(_profile.configure_mutation_gate(gate).ok, "profile_gate")
	_audio = AUDIO.new(AUDIO_PORT.new())
	root.add_child(_audio)
	_check(_audio.configure_mutation_gate(gate).ok, "audio_gate")
	initialized = _audio.initialize(_profile)
	_check(initialized.get("ok", false), "silent_audio_initialized")
	if not initialized.get("ok", false): return
	_manager = MANAGER.new(_port)
	root.add_child(_manager)
	_check(_manager.configure_mutation_gate(gate).ok, "window_gate")
	initialized = _manager.initialize(_profile, _audio.get_settings_output_transactions())
	_check(initialized.get("ok", false), "window_manager_initialized")
	if not initialized.get("ok", false): return
	var revision: int = _profile.get_profile_revision()
	var published: Array = []
	_profile.preference_changed.connect(func(path, value): published.append([String(path), value]))
	var committed: Dictionary = _manager.commit_settings_window_preference("native-window-verification", "borderless")
	_check(committed.get("ok", false), "manager_commit_borderless")
	_check(_profile.get_profile_revision() == revision + 1, "exactly_one_profile_revision")
	_check(published == [[String(PATH), "borderless"]], "exactly_one_preference_publication")
	_check(_profile.get_preference(PATH) == "borderless", "committed_profile_mode")
	_check(_manager.get_applied_mode() == "borderless" and _port.output_matches("borderless"), "committed_native_mode")
	_check(not gate.is_fatal_latched(), "shared_gate_healthy")
	var observed: Dictionary = _port.capture_output()
	if observed.get("ok", false): _states.manager_commit = _serialize(observed.value)

func _serialize(snapshot: Dictionary) -> Dictionary:
	return {"owner_id": snapshot.owner_id, "mode": snapshot.mode, "borderless": snapshot.borderless,
		"screen": snapshot.screen, "position": [snapshot.position.x, snapshot.position.y],
		"size": [snapshot.size.x, snapshot.size.y]}

func _check(condition: bool, label: String) -> void:
	_checks.append({"check": label, "ok": condition})
	if not condition:
		_failed = true
		printerr("WINDOW_MODE_NATIVE_FAILED ", label)
