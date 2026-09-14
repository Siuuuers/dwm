extends SceneTree
## Real Windows UIA selection check; the isolated wrapper owns all file roots.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var starts := 0
	func configure_reached_replay(_profile: Object) -> Dictionary: return {"ok": true}
	func replay_reached_signature(_signature: String) -> Dictionary:
		starts += 1
		return {"ok": false}
	func cancel_reached_replay(_signature: String) -> Dictionary: return {"ok": true}

var _test_root := ""
var _completion_path := ""
var _gallery: Control
var _profile: Node
var _files: RefCounted
var _bridge := ReplayBridge.new()
var _before: Dictionary
var _bytes: Dictionary
var _titles: Array[String] = []

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
	_completion_path = candidate.path_join("gallery-selection-complete.json")
	if FileAccess.file_exists(_completion_path):
		_finish(false, "completion_already_exists")
		return
	for frame: int in 3: await process_frame
	var bootstrap: Node = root.get_node_or_null("ApplicationBootstrap")
	if bootstrap == null or bootstrap.get_startup_state().get("mode") != &"test_manual" \
			or DisplayServer.get_name() == "headless":
		_finish(false, "native_manual_test_required")
		return
	var locale := "en"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gallery-test-locale="):
			locale = argument.trim_prefix("--gallery-test-locale=")
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_title("DWM Gallery Selection %d" % OS.get_process_id())
	_files = FILES.new()
	_profile = PROFILE.new()
	root.add_child(_profile)
	if not _profile.initialize(STORAGE.new("gallery-selection.memory", _files)).get("ok", false):
		_finish(false, "profile_initialization_failed")
		return
	for ending: String in ["ending.alone", "ending.sylvia.sweet"]:
		if not _profile.unlock_ending(ending, "gallery-selection:" + ending).get("ok", false):
			_finish(false, "fixture_discovery_failed")
			return
	var localization := LOCALIZATION.new()
	root.add_child(localization)
	if not localization.initialize(_profile).get("ok", false) or not localization.set_locale(locale).get("ok", false):
		_finish(false, "localization_failed")
		return
	var home := Button.new()
	home.text = "Return"
	home.position = Vector2(1100, 650)
	root.add_child(home)
	_gallery = GALLERY.instantiate()
	if not _gallery.configure_title_host(home, localization, _profile).get("ok", false) \
			or not _gallery.configure_replay(_bridge).get("ok", false):
		_finish(false, "gallery_configuration_failed")
		return
	root.add_child(_gallery)
	_gallery.open_in_title_host()
	for frame: int in 5: await process_frame
	await RenderingServer.frame_post_draw
	_before = _profile.get_profile_snapshot()
	_bytes = _files.snapshot_persisted()
	for row: Button in _gallery.get_node("%EndingTileGrid").get_children():
		_titles.append(row.text)
	if _titles.size() != 2 or _gallery._selected_id != "ending.alone":
		_finish(false, "initial_record_selection_failed")
		return
	print("READY " + JSON.stringify({"pid": OS.get_process_id(),
		"window_title": "DWM Gallery Selection %d" % OS.get_process_id(),
		"expected_titles": _titles, "completion_path": _completion_path}))
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(_completion_path):
			var completion: Variant = JSON.parse_string(FileAccess.get_file_as_string(_completion_path))
			if completion is Dictionary:
				var unchanged: bool = _profile.get_profile_snapshot() == _before and _files.snapshot_persisted() == _bytes
				var selected: bool = _gallery._selected_id == "ending.sylvia.sweet"
				_finish(bool(completion.get("ok", false)) and unchanged and selected and _bridge.starts == 0,
					str(completion.get("code", "invalid_completion")))
				return
		await process_frame
	_finish(false, "uia_timeout")

func _finish(ok: bool, code: String) -> void:
	var result := {"ok": ok, "code": code, "pid": OS.get_process_id(), "titles": _titles,
		"selected_record": _gallery._selected_id if is_instance_valid(_gallery) else "",
		"replay_starts": _bridge.starts}
	if not _test_root.is_empty():
		var file := FileAccess.open(_test_root.path_join("gallery-selection-result.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result))
			file.close()
	print("RESULT " + JSON.stringify(result))
	quit(0 if ok else 1)
