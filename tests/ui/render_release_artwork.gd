extends SceneTree

const ART := preload("res://scripts/data/ArtManifest.gd")
const VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const SOURCE := preload("res://tools/authoring/DtlStorySource.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
var failures: Array[String] = []
var output := "res://.godot/ci/gallery-release"

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, name)

func _run() -> void:
	if OS.get_environment("DWM_TEST_ROOT").is_empty() or DisplayServer.get_name() == "headless":
		push_error("An isolated DWM_TEST_ROOT and rendered display are required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 1008)
	for frame: int in 180:
		if root.get_node("ApplicationBootstrap").get_startup_state().get("ready", false): break
		await process_frame
	var profile := root.get_node("ProfileManager")
	var localization := root.get_node("LocalizationManager")
	check(profile.reset_gallery().ok, "reset isolated gallery")
	var home := Button.new()
	root.add_child(home)
	var gallery := GALLERY.instantiate()
	check(gallery.configure_title_host(home, localization, profile).ok, "gallery host")
	root.add_child(gallery)
	gallery.open_in_title_host()
	gallery._show_gallery_tab("artwork")
	await capture("00-gallery-locked")
	for row: Button in gallery._artwork._rows: check(row.disabled, "unseen art remains locked")
	gallery.hide()
	var source: Dictionary = SOURCE.prepare(JSON.parse_string(FileAccess.get_file_as_string("res://data/manifests/authored_week_source.json")))
	check(source.ok, "authored source")
	var labels: Array = source.value.entries.map(func(row: Dictionary) -> String: return row.entry_id)
	for entry: String in ["Day1", "Day4", "ending.alone.normal"]:
		var spec: Dictionary = {}
		for row: Dictionary in source.value.entries:
			if row.entry_id == entry: spec = row
		var compiled: Dictionary = ADAPTER.compile_scene_programme(spec.path, entry, labels, spec.markers)
		check(compiled.ok, "compile " + entry)
		var commands: Array = compiled.value.nodes[0].presentation_commands
		var resolved: Dictionary = ART.apply_presentation_commands(commands, ART.make_scene_presentation(entry))
		check(resolved.ok, "presentation " + entry)
		var view := VIEW.new()
		view.bind_view_preferences(profile)
		root.add_child(view)
		view.configure_presentation(resolved.value.state, 100, false, false, true)
		await capture("scene-" + entry)
		await process_frame
		if entry == "Day1":
			check(profile.has_displayed_artwork("picture1") and profile.has_displayed_artwork("picture2"), "Day1 discovers 1 and 2")
			check(not profile.has_displayed_artwork("picture3"), "3 locked before Day4")
		if entry != "ending.alone.normal":
			check(not profile.has_displayed_artwork("picture4") and not profile.has_displayed_artwork("picture5"), "4 and 5 locked before ending")
		view.free()
	for id: String in ART.GALLERY_IDS: check(profile.has_displayed_artwork(id), "displayed " + id)
	gallery.show()
	gallery._artwork.refresh()
	for id: String in ART.GALLERY_IDS:
		gallery._artwork.select_picture(id)
		await capture(id + "-gallery")
		gallery._artwork.open_viewer()
		await capture(id + "-full")
		gallery._artwork.close_viewer()
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		check(localization.set_locale(locale).ok, "locale " + locale)
		await capture("gallery-" + locale)
	var receipt := FileAccess.open(output.path_join("checks.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"ok": failures.is_empty(), "failures": failures, "method": "Compiled Day1, Day4 and post-Day7 ending presentations rendered through SceneArtView; no direct discovery grants."}, "\t"))
	print("RELEASE_ARTWORK_CHECKS ", failures)
	quit(0 if failures.is_empty() else 1)
