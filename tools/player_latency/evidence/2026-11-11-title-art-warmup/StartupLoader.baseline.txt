extends Node

# Own resource requests until completion even when the requesting scene leaves.
const CORE := ["ProfileManager", "SaveManager", "LocalizationManager", "AudioManager",
	"SystemTtsCoordinator", "WindowModeManager", "InputManager", "AccessibilityManager", "DialogicBridge"]
const RUNTIME := ["GameState", "EffectResolver", "SceneRouter", "Dialogic"]
const TITLE := "res://scenes/menu/MenuScene.tscn"
var _pending: Array[String] = []
var _active := ""
var _loaded: Dictionary = {}
var _failed: Array[String] = []
var _bootstrap: Node
var _runtime_paths: Array = []
var _runtime_install_index := 0
var _phase := &"idle"

func _init() -> void:
	# Autoload construction precedes test scripts' deferred setup.
	_install.call_deferred()

func _owner_path(owner: String) -> String:
	return "res://addons/dialogic/Core/DialogicGameHandler.gd" if owner == "Dialogic" else "res://autoload/%s.gd" % owner

func _attach(owner: String, script: Script) -> Node:
	var instance: Node = script.new()
	instance.name = owner
	get_tree().root.add_child(instance)
	return instance

func _install() -> void:
	_bootstrap = load("res://autoload/ApplicationBootstrap.gd").new()
	_bootstrap.name = "ApplicationBootstrap"
	var mode: StringName = _bootstrap._requested_mode_from_debug_args()
	var staged: bool = mode == &"final"
	_bootstrap.staged_startup = staged
	for owner: String in CORE:
		_attach(owner, load(_owner_path(owner)))
	if not staged:
		for owner: String in RUNTIME:
			_attach(owner, load(_owner_path(owner)))
	get_tree().root.add_child(_bootstrap)
	if not staged: return
	var title_result: Dictionary = _bootstrap.start_title()
	if not title_result.get("ok", false):
		# Recovery keeps the original synchronous continuation and all its real owners.
		for owner: String in RUNTIME:
			_attach(owner, load(_owner_path(owner)))
		if _bootstrap.get_startup_state().failed_stage == &"initialize_saves":
			_bootstrap.prepare_runtime()
		get_tree().change_scene_to_file(TITLE)
		return
	for owner: String in RUNTIME: _runtime_paths.append(_owner_path(owner))
	_runtime_paths.append_array(_bootstrap.RUNTIME_RESOURCES)
	queue_resources([TITLE])
	_phase = &"title"

func queue_resources(paths: Array, priority: bool = false) -> void:
	if _phase == &"closing": return
	var added: Array[String] = []
	for path: String in paths:
		if _loaded.has(path) or path in _failed or path == _active: continue
		if path in _pending:
			if not priority: continue
			_pending.erase(path)
		added.append(path)
	if priority: _pending = added + _pending
	else: _pending.append_array(added)

func resources_ready(paths: Array) -> bool:
	for path: String in paths:
		if not _loaded.has(path): return false
	return true

func resources_failed(paths: Array) -> bool:
	for path: String in paths:
		if path in _failed: return true
	return false

func loaded_resource(path: String) -> Resource:
	return _loaded.get(path)

func prioritize_destination(destination: String) -> void:
	if destination != "settings": queue_resources(_runtime_paths, true)

func _process(_delta: float) -> void:
	if not _active.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_active)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded[_active] = ResourceLoader.load_threaded_get(_active)
			_active = ""
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_failed.append(_active)
			_active = ""
	while _active.is_empty() and not _pending.is_empty():
		_active = _pending.pop_front()
		if ResourceLoader.has_cached(_active):
			_loaded[_active] = load(_active)
			_active = ""
			continue
		if ResourceLoader.load_threaded_request(_active) != OK:
			_failed.append(_active)
			_active = ""
	match _phase:
		&"title":
			if resources_failed([TITLE]):
				_phase = &"idle"
				_bootstrap.show_content_error({"code": &"title_load_failed"})
			elif resources_ready([TITLE]):
				_phase = &"first_draw"
				get_tree().change_scene_to_packed(loaded_resource(TITLE))
		&"first_draw":
			_phase = &"drawing"
			_begin_background_after_title_draw()
		&"runtime":
			if resources_failed(_runtime_paths):
				_phase = &"idle"
				_bootstrap._record_startup_stage_failure(&"load_runtime",
					{"ok": false, "code": &"runtime_load_failed"})
			elif resources_ready(_runtime_paths):
				if _runtime_install_index < RUNTIME.size():
					var owner: String = RUNTIME[_runtime_install_index]
					_attach(owner, loaded_resource(_owner_path(owner)))
					_runtime_install_index += 1
				else:
					var prepared: Dictionary = _bootstrap.prepare_runtime()
					_phase = &"wiring" if prepared.get("ok", false) else &"idle"
		&"wiring":
			var result: Dictionary = _bootstrap.advance_runtime()
			if not result.get("ok", false):
				_phase = &"idle"
			elif _bootstrap.get_startup_state().ready:
				_phase = &"idle"
				queue_resources(_bootstrap.BACKGROUND_RESOURCES)

func shutdown() -> void:
	_phase = &"closing"
	_pending.clear()
	set_process(false)
	# Finish the one outstanding request before the engine frees its resource owners.
	if not _active.is_empty():
		while ResourceLoader.load_threaded_get_status(_active) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(_active) == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded[_active] = ResourceLoader.load_threaded_get(_active)
		_active = ""


func _begin_background_after_title_draw() -> void:
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	else: await get_tree().process_frame
	if _phase == &"closing": return
	queue_resources(_runtime_paths)
	_phase = &"runtime"
