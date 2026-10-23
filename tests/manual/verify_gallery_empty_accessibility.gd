extends SceneTree
## The native observer subscribes before opening this initially hidden Gallery.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

var _test_root := ""
var _gallery: Control
var _profile: Node
var _locale: Node
var _home: Button
var _files: RefCounted
var _before: Dictionary
var _bytes: Dictionary
var _phases: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var candidate := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").simplify_path().trim_suffix("/")
	if candidate.is_empty() or not candidate.to_lower().begins_with(allowed.to_lower() + "/") \
			or not DirAccess.dir_exists_absolute(candidate):
		_finish(false, "unproven_test_root")
		return
	_test_root = candidate
	var command_path := candidate.path_join("gallery-empty-command.json")
	var completion_path := candidate.path_join("gallery-empty-complete.json")
	if FileAccess.file_exists(command_path) or FileAccess.file_exists(completion_path):
		_finish(false, "preexisting_observer_files")
		return
	for frame: int in 3: await process_frame
	var bootstrap: Node = root.get_node_or_null("ApplicationBootstrap")
	if bootstrap == null or bootstrap.get_startup_state().get("mode") != &"test_manual" \
			or DisplayServer.get_name() == "headless":
		_finish(false, "native_manual_test_required")
		return
	var language := "en"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gallery-test-locale="):
			language = argument.trim_prefix("--gallery-test-locale=")
	root.size = Vector2i(1280, 720)
	var window_title := "DWM Gallery Empty %d" % OS.get_process_id()
	DisplayServer.window_set_title(window_title)
	_files = FILES.new()
	_profile = PROFILE.new()
	root.add_child(_profile)
	if not _profile.initialize(STORAGE.new("gallery-empty.memory", _files)).get("ok", false):
		_finish(false, "profile_initialization_failed")
		return
	_locale = LOCALIZATION.new()
	root.add_child(_locale)
	if not _locale.initialize(_profile).get("ok", false) or not _locale.set_locale(language).get("ok", false):
		_finish(false, "localization_failed")
		return
	_home = Button.new()
	_home.text = _locale.t("button.return")
	_home.position = Vector2(1100, 650)
	root.add_child(_home)
	_gallery = GALLERY.instantiate()
	_gallery.hide()
	if not _gallery.configure_title_host(_home, _locale, _profile).get("ok", false):
		_finish(false, "gallery_configuration_failed")
		return
	root.add_child(_gallery)
	for frame: int in 6: await process_frame
	_before = _profile.get_profile_snapshot()
	_bytes = _files.snapshot_persisted()
	print("READY " + JSON.stringify({"pid": OS.get_process_id(), "window_title": window_title,
		"expected_empty": _locale.t("gallery.empty"), "expected_return": _home.text,
		"command_path": command_path, "completion_path": completion_path}))
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(completion_path):
			var completion: Variant = JSON.parse_string(FileAccess.get_file_as_string(completion_path))
			if completion is Dictionary:
				var unchanged: bool = _profile.get_profile_snapshot() == _before and _files.snapshot_persisted() == _bytes
				var empty: bool = _gallery.get_node("%EndingTileGrid").get_child_count() == 0 \
					and not _gallery.get_node("%ReplayButton").visible and _home.has_focus()
				_finish(bool(completion.get("ok", false)) and unchanged and empty \
					and _phases == ["open", "refresh", "reopen"], str(completion.get("code", "invalid_completion")))
				return
		if FileAccess.file_exists(command_path):
			var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(command_path))
			if command is Dictionary:
				var phase := str(command.get("phase", ""))
				if not phase.is_empty() and phase not in _phases:
					var expected: Array[String] = ["open", "refresh", "reopen"]
					if _phases.size() >= expected.size() or phase != expected[_phases.size()]:
						_finish(false, "invalid_phase_order")
						return
					match phase:
						"open": _gallery.open_in_title_host()
						"refresh":
							_home.grab_focus()
							_gallery._on_locale_changed(_locale.get_locale())
							_gallery._on_profile_restored({})
							_gallery._on_preference_changed(&"preferences.accessibility.text_size", 100)
						"reopen":
							if not _gallery.close_for_title_host():
								_finish(false, "close_failed")
								return
							for frame: int in 6: await process_frame
							_gallery.open_in_title_host()
					for frame: int in 6: await process_frame
					await RenderingServer.frame_post_draw
					_phases.append(phase)
					print("PHASE " + phase)
		await process_frame
	_finish(false, "observer_timeout")

func _finish(ok: bool, code: String) -> void:
	var result := {"ok": ok, "code": code, "pid": OS.get_process_id(), "phases": _phases}
	if not _test_root.is_empty():
		var file := FileAccess.open(_test_root.path_join("gallery-empty-result.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result))
			file.close()
	print("RESULT " + JSON.stringify(result))
	quit(0 if ok else 1)
