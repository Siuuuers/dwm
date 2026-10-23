extends Node
## Optional isolated native smoke check; never runs during ordinary F6.
var _preview: Control

func _ready() -> void:
	if OS.get_environment("DWM_TEST_ROOT").is_empty():
		push_error("Preview verification requires the isolated test wrapper.")
		get_tree().quit(1)
		return
	_preview = get_parent()
	get_tree().create_timer(40).timeout.connect(func():
		push_error("Manual preview verification timed out.")
		get_tree().quit(1))
	call_deferred("_run")

func _run() -> void:
	get_window().grab_focus()
	while not is_instance_valid(_preview._caption) or _preview._switching:
		await get_tree().process_frame
	await get_tree().process_frame
	var bootstrap: Dictionary = get_node("/root/ApplicationBootstrap").get_startup_state()
	if not _check(bootstrap.mode == &"test_manual" and bootstrap.completed_stages.is_empty(), "manual startup claimed before deferred final"): return
	if not _check(_preview._entries.size() == 39, "32 Dating + 7 Sylvia-present Hospital entries"): return
	for entry: Dictionary in _preview._entries:
		var timeline: DialogicTimeline = load(_preview.TIMELINE_FOLDER + str(entry.entry_id) + ".dtl")
		if not _check(timeline != null, "each scene has a standalone DTL"): return
		timeline.process()
		var text_count := 0
		for event: DialogicEvent in timeline.events:
			if event is DialogicTextEvent: text_count += 1
		if not _check(text_count == 3, "three real Dialogic text events per stub"): return
	if not _check(_preview._art._portraits[0].visible and not _preview._art._portraits[1].visible, "one fixed solo portrait"): return
	if not await _capture("01-solo"): return
	var starting_index: int = _preview._selected
	var attempts := 0
	while _preview._selected == starting_index and attempts < 12:
		await _accept()
		attempts += 1
	if not _check(str(_preview._entries[_preview._selected].entry_id).begins_with("dating.group."), "real caption input advances solo into pair"): return
	while _preview._switching: await get_tree().process_frame
	if not _check(_preview._art._portraits[0].visible and _preview._art._portraits[1].visible, "two fixed pair portraits"): return
	if not await _capture("02-two-characters"): return
	_preview._percent = 150
	_preview._refresh_art()
	_preview._caption.configure_presentation("en", 150)
	if not _check(_preview._art.size.y == 328, "production 150 percent art aperture"): return
	if not await _capture("03-large-text"): return
	for index: int in range(_preview._entries.size()):
		if str(_preview._entries[index].entry_id) == "hospital.faint.day1":
			await _preview._play(index)
			break
	if not await _capture("04-sylvia-hospital"): return
	if not _check(_preview._art._portraits[0].visible and not _preview._art._portraits[1].visible, "Hospital visual fixture has Sylvia alone"): return
	for singleton: String in ["ProfileManager", "DialogicBridge"]:
		if not _check(not bool(get_node("/root/" + singleton).get("_initialized")), singleton + " remains uninitialized"): return
	if not _check(get_node("/root/SaveManager").get("_storage") == null, "SaveManager has no storage adapter"): return
	var files := _persistent_files("user://")
	# Dialogic's autoload creates this empty file before any main scene enters.
	# It is not a game save and must remain empty throughout the preview.
	var empty_info := "user://dialogic/saves/global_info.txt"
	if files.has(empty_info):
		if not _check(FileAccess.get_file_as_string(empty_info).is_empty(), "Dialogic global info stays empty"): return
		files.erase(empty_info)
	if not _check(files.is_empty(), "no game saves/Profile/settings writes: " + str(files)): return
	print("MANUAL_DTL_PREVIEW_PASS: F6 startup isolation; 39 scene DTLs; native text input; solo/pair/Hospital art; 150% layout; no saves")
	get_tree().quit(0)

func _accept() -> void:
	if not is_instance_valid(_preview._caption):
		await get_tree().process_frame
		return
	_preview._caption.caption_text.grab_focus()
	var pressed := InputEventKey.new()
	pressed.keycode = KEY_ENTER
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = KEY_ENTER
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().create_timer(0.35).timeout

func _capture(name: String) -> bool:
	var until := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < until:
		if is_instance_valid(_preview._caption):
			var caption: RichTextLabel = _preview._caption.caption_text
			if caption.is_visible_in_tree() and not caption.get_parsed_text().is_empty() and not caption.revealing:
				break
		await get_tree().process_frame
	if not is_instance_valid(_preview._caption) or _preview._caption.caption_text.get_parsed_text().is_empty():
		var text_nodes: Array = []
		for node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
			text_nodes.append({"path": str(node.get_path()), "visible": node.is_visible_in_tree(),
				"enabled": node.enabled, "text": node.get_parsed_text()})
		print("MANUAL_PREVIEW_TEXT_STATE: " + JSON.stringify({"entry": _preview._entries[_preview._selected].entry_id,
			"event": Dialogic.current_event_idx, "state": Dialogic.current_state, "nodes": text_nodes,
			"native_text": Dialogic.current_state_info.get("text", "")}))
		return _check(false, "visible native text before screenshot " + name)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://evidence/manual-preview/"
	DirAccess.make_dir_recursive_absolute(path)
	return _check(get_viewport().get_texture().get_image().save_png(path + name + ".png") == OK, "native screenshot saved " + name)

func _persistent_files(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(path)
	for filename: String in dir.get_files(): result.append(path.path_join(filename))
	for folder: String in dir.get_directories():
		if folder not in ["logs", "evidence", "shader_cache"]: result.append_array(_persistent_files(path.path_join(folder)))
	return result

func _check(value: bool, message: String) -> bool:
	if not value:
		push_error("MANUAL_PREVIEW_FAIL: " + message)
		get_tree().quit(1)
	return value
