extends SceneTree
## Native archive probe for dwm-oqw. It uses the installed catalog and imported
## textures directly; no overlays, fixture art, profile, or save data are involved.

const ART := preload("res://scripts/data/ArtManifest.gd")
const CONTACTS := preload("res://scripts/ui/contacts/ContactsPanel.gd")
const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const SCENE_ART := preload("res://scripts/ui/art/SceneArtView.gd")
const FOLDER := "user://evidence/found_paintings"
const LOGICAL_SIZE := Vector2i(1280, 720)
const EXPECTED: Dictionary = {
	"res://art/characters/priscilla/scene.png": Vector2i(640, 896),
	"res://art/characters/lavinia/scene.png": Vector2i(640, 896),
	"res://art/characters/sylvia/scene.png": Vector2i(640, 896),
	"res://art/characters/priscilla/contact.png": Vector2i(32, 64),
	"res://art/characters/lavinia/contact.png": Vector2i(32, 64),
	"res://art/characters/sylvia/contact.png": Vector2i(32, 64),
	"res://art/shell/background.png": Vector2i(960, 1008),
	"res://art/environments/paintings/morisot_reading_field.jpg": Vector2i(1920, 672),
	"res://art/environments/paintings/degas_frieze_rehearsal.jpg": Vector2i(1920, 672),
	"res://art/environments/paintings/vuillard_at_the_cafe.jpg": Vector2i(1920, 672),
	"res://art/environments/paintings/monet_red_kerchief_window.jpg": Vector2i(1920, 672),
	"res://art/environments/paintings/gwen_john_interior.jpg": Vector2i(1920, 672),
	"res://art/environments/paintings/hammershoi_interior_easel.jpg": Vector2i(1920, 672),
}

var _viewport: SubViewport
var _checks := 0
var _captures := 0
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition

func _settle() -> void:
	for _frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw

func _capture(filename: String) -> void:
	await _settle()
	var pixels: Image = _viewport.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), filename + " rendered pixels"):
		return
	if _check(pixels.get_size() == LOGICAL_SIZE, filename + " exact 1280x720 capture"):
		var output := ProjectSettings.globalize_path(FOLDER.path_join(filename))
		if _check(pixels.save_png(output) == OK, filename + " saved"):
			_captures += 1

func _clear_stage() -> void:
	for child: Node in _viewport.get_children():
		child.queue_free()
	await process_frame

func _texture_path(texture: Texture2D) -> String:
	return texture.resource_path if texture != null else ""

func _verify_installed_textures() -> void:
	_check(ART.reload_placements(), "installed art manifest loads")
	var assets: Dictionary = ART.get_expected_art_paths()
	var loaded_paths: Dictionary = {}
	for asset_id: String in assets:
		var path: String = str(assets[asset_id])
		if not EXPECTED.has(path):
			continue
		var expected_size: Vector2i = EXPECTED[path]
		var texture: Texture2D = ART.get_texture(asset_id, expected_size)
		if _check(texture != null, "%s loads through %s" % [path, asset_id]):
			_check(texture.get_size() == Vector2(expected_size), path + " imported dimensions")
			_check(_texture_path(texture) == path, path + " is the loaded resource")
			loaded_paths[path] = true
	_check(loaded_paths.size() == EXPECTED.size(), "all 13 installed derivatives load through ArtManifest")
	for path: String in EXPECTED:
		_check(loaded_paths.has(path), path + " has a live manifest binding")

func _capture_contacts() -> void:
	await _clear_stage()
	var backdrop := ColorRect.new()
	backdrop.color = Color("15111a")
	backdrop.size = Vector2(LOGICAL_SIZE)
	_viewport.add_child(backdrop)
	var panel := CONTACTS.new()
	panel.position = Vector2(240, 32)
	panel.size = Vector2(800, 656)
	_check(panel.configure(ThemeDB.fallback_font, ThemeDB.fallback_font,
		ThemeDB.fallback_font, 100, false), "real ContactsPanel configures")
	_viewport.add_child(panel)
	await _settle()
	var entries: Array = [
		{"id": "found-art-incoming", "outgoing": false,
			"texts": {"en": "I found the room we spoke about."}, "timestamp": "20:14"},
		{"id": "found-art-outgoing", "outgoing": true,
			"texts": {"en": "Keep the window open until I arrive."}, "timestamp": "20:16"},
	]
	_check(panel.set_projection("priscilla", entries,
		{"priscilla": false, "lavinia": true, "sylvia": false}, "en", ""),
		"real Contacts thread projects")
	await _settle()
	for index: int in range(3):
		var row_texture: Texture2D = panel.rows[index].get("portrait_texture")
		_check(row_texture != null and row_texture.get_size() == Vector2(32, 64),
			"Contacts row %d uses its installed crop" % index)
	var header: Texture2D = ART.get_texture("contact.priscilla.header", Vector2i(32, 64))
	_check(header != null, "selected Contacts header resolves through its production asset id")
	_check(_texture_path(header) == "res://art/characters/priscilla/contact.png",
		"selected Contacts header uses Priscilla's installed crop")
	await _capture("contacts-row-and-header.png")

func _capture_shell() -> void:
	await _clear_stage()
	var main: Control = MAIN.instantiate()
	_viewport.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _settle()
	var host: Control = main.get_node_or_null("%AngelaImage") as Control
	if _check(host != null, "real Angela art host mounts"):
		var background: TextureRect = host.get_node_or_null("BackgroundArtwork") as TextureRect
		if _check(background != null and background.texture != null,
				"real shell background layer mounts"):
			_check(_texture_path(background.texture) == "res://art/shell/background.png",
				"real shell host uses the installed Hammershoi derivative")
			_check(background.texture.get_size() == Vector2(960, 1008),
				"real shell background has its declared dimensions")
	await _capture("angela-shell-background.png")

func _capture_tableau() -> void:
	await _clear_stage()
	var backdrop := ColorRect.new()
	backdrop.color = Color("09080a")
	backdrop.size = Vector2(LOGICAL_SIZE)
	_viewport.add_child(backdrop)
	var title := Label.new()
	title.text = "Installed Witnessed tableau · Priscilla · Day 1"
	title.position = Vector2(32, 32)
	title.add_theme_font_size_override("font_size", 28)
	_viewport.add_child(title)
	var view := SCENE_ART.new()
	view.position = Vector2(0, 136)
	view.configure_entry("dating.solo.priscilla.day1.pre_challenge", 100)
	_viewport.add_child(view)
	await _settle()
	var background: TextureRect = view.get_node_or_null("Background") as TextureRect
	var portrait: TextureRect = view.get_node_or_null("PortraitLeft") as TextureRect
	if _check(background != null and background.texture != null, "real tableau background mounts"):
		_check(_texture_path(background.texture) ==
			"res://art/environments/paintings/morisot_reading_field.jpg",
			"real tableau uses the installed Morisot derivative")
	if _check(portrait != null and portrait.texture != null and portrait.visible,
			"real tableau portrait mounts"):
		_check(_texture_path(portrait.texture) == "res://art/characters/priscilla/scene.png",
			"real tableau uses Priscilla's installed scene portrait")
		_check(portrait.modulate == Color.WHITE and portrait.self_modulate == Color.WHITE,
			"installed portrait remains unfiltered")
	await _capture("witnessed-tableau.png")

func _run() -> void:
	# Refuse before creating a directory or opening a file when run outside the
	# repository's isolated test wrapper.
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(),
			"DWM_TEST_ROOT is required") \
			or not _check(DisplayServer.get_name() != "headless", "native renderer is required"):
		for failure: String in _failures:
			printerr(failure)
		quit(1)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER)) == OK,
			"capture directory is available"):
		quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = LOGICAL_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_verify_installed_textures()
	await _capture_contacts()
	await _capture_shell()
	await _capture_tableau()
	_check(_captures == 3, "three native captures were written")
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("FOUND_PAINTINGS_NATIVE_VERIFIED textures=13 captures=", _captures,
			" checks=", _checks)
	else:
		printerr("FOUND_PAINTINGS_NATIVE_FAILED checks=", _checks,
			" failures=", _failures.size())
	_viewport.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)
