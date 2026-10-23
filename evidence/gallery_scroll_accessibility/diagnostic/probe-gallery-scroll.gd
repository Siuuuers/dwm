extends SceneTree
const PAPER := preload("res://scripts/ui/gallery/GalleryRecordPaper.gd")
const THEME := preload("res://scripts/ui/gallery/GalleryTheme.gd")
var paper: Control
var folder := ""
var phases: Array[String] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	folder = OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").simplify_path()
	if folder.is_empty() or not folder.to_lower().begins_with(allowed.to_lower() + "/") or not DirAccess.dir_exists_absolute(folder):
		quit(1)
		return
	for frame: int in 3: await process_frame
	if root.get_node("ApplicationBootstrap").get_startup_state().get("mode") != &"test_manual" or DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_title("DWM Gallery Scroll %d" % OS.get_process_id())
	var home := Button.new()
	home.text = "Return"
	home.position = Vector2(1000, 600)
	root.add_child(home)
	var reference := ScrollContainer.new()
	reference.name = "NativeReference"
	reference.accessibility_name = "Native scrolling reference"
	reference.position = Vector2(16, 32)
	reference.size = Vector2(300, 512)
	root.add_child(reference)
	var native_copy := Label.new()
	native_copy.text = "Reference text"
	native_copy.custom_minimum_size = Vector2(260, 1024)
	reference.add_child(native_copy)
	paper = PAPER.new()
	paper.theme = THEME.build("en", 100, &"after_hours")
	paper.position = Vector2(390, 32)
	root.add_child(paper)
	paper.focus_target_removed.connect(func(_hidden: bool): home.grab_focus())
	paper.set_copy("Scrolling record fixture\n".repeat(40), "One visible sentence.", "en", true)
	home.grab_focus()
	for frame: int in 6: await process_frame
	print("READY " + JSON.stringify({"pid": OS.get_process_id(), "title": "DWM Gallery Scroll %d" % OS.get_process_id(), "folder": folder,
		"max_offset": paper.content_extent - 512}))
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		var path := folder.path_join("scroll-command.json")
		if FileAccess.file_exists(path):
			var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if command is Dictionary:
				var phase := str(command.get("phase", ""))
				if not phase.is_empty() and phase not in phases:
					match phase:
						"offset": pass
						"fit": paper.set_copy("A short record", "One visible sentence.", "en", false)
						"title_only": paper.set_copy("A short record", "", "en", false)
						"done":
							print("RESULT " + JSON.stringify({"phases": phases, "offset": paper.scroll_offset, "home_focused": home.has_focus()}))
							quit(0)
							return
					for frame: int in 6: await process_frame
					phases.append(phase)
					print("PHASE " + JSON.stringify({"phase": phase, "offset": paper.scroll_offset, "home_focused": home.has_focus()}))
		await process_frame
	quit(1)
