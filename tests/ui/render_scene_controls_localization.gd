extends SceneTree
## Real host and isolated profile/catalog. Captures are chrome-only, not a board E2E claim.
const HOST := preload("res://scenes/narrative/SceneHost.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
var _failures: Array[String] = []
var _samples: Array[Dictionary] = []
var _captures := 0
var _dispatches := 0
var _folder := OS.get_environment("DWM_RENDER_OUTPUT")

func _initialize() -> void: _run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		printerr("SCENE_CONTROLS_LOCALIZATION_FAIL ", message)
	return condition

func _dispatch() -> Dictionary:
	_dispatches += 1
	return {"ok": true}

func _settle() -> void:
	for frame in 6: await process_frame

func _run() -> void:
	if _folder.is_empty(): _folder = ProjectSettings.globalize_path("user://evidence/scene_controls_localization")
	if not _check(not OS.get_environment("DWM_TEST_ROOT").is_empty(), "DWM_TEST_ROOT isolation required"):
		quit(1)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "evidence directory"):
		quit(1)
		return
	var profile := PROFILE.new()
	var locale := LOCALIZATION.new()
	_check(profile.initialize(STORAGE.new("scene-controls-render", FILES.new())).get("ok", false), "isolated profile")
	_check(locale.initialize(profile).get("ok", false), "real localization")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	var host: Control = HOST.instantiate()
	host._localization = locale
	host._profile = profile
	var actions := {}
	for action: String in ["computer_open", "computer_close", "apps", "contacts"]:
		actions[action] = _dispatch
	host.configure_scene_controls(actions)
	viewport.add_child(host)
	for language: String in ["en", "zh_HK", "zh_CN", "ja", "ko"]:
		_check(locale.set_locale(language).get("ok", false), "commit " + language)
		for style: String in ["pixel", "readable"]:
			_check(locale.set_font_style(style).get("ok", false), "commit " + style)
			for percent: int in [100, 125, 150]:
				_check(profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "commit size")
				for opened: bool in [false, true]:
					host.set_computer_open(opened)
					await _settle()
					var id := "%s-%s-%d-%s" % [language, style, percent, "open" if opened else "closed"]
					var rectangles: Dictionary = _inspect(host, locale, language, style, percent, id)
					_samples.append({"id": id, "buttons": rectangles})
					if percent == 150 and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						var picture := viewport.get_texture().get_image()
						var caret: Button = host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer")
						var center := Vector2i(caret.get_global_rect().get_center())
						var top := picture.get_pixel(center.x, center.y - 2).get_luminance()
						var bottom := picture.get_pixel(center.x, center.y + 2).get_luminance()
						_check(bottom > top + 0.1 if opened else top > bottom + 0.1, id + ": drawn caret points down when open and up when closed")
						if _check(not picture.is_empty() and picture.save_png(_folder.path_join(id + ".png")) == OK, id + " screenshot"):
							_captures += 1
	_check(_samples.size() == 60, "all 60 locale/style/size/state combinations")
	_check(_dispatches == 0, "presentation changes dispatch no game commands")
	if DisplayServer.get_name() != "headless": _check(_captures == 20, "all 20 largest-font screenshots")
	var report := {"ok": _failures.is_empty(), "renderer": DisplayServer.get_name(), "samples": _samples,
		"captures": _captures, "failures": _failures, "fixture": "Production SceneHost chrome; Challenge reserved rectangle, no mounted board or narrative."}
	var file := FileAccess.open(_folder.path_join("results.json"), FileAccess.WRITE)
	if _check(file != null, "result file"):
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("SCENE_CONTROLS_LOCALIZATION_RESULT ", JSON.stringify(report))
	viewport.free()
	locale.free()
	profile.free()
	quit(0 if _failures.is_empty() else 1)

func _inspect(host: Control, locale: Node, language: String, style: String, percent: int, id: String) -> Dictionary:
	var controls: Control = host.get_node("SceneControlsLayer/Surface/Controls")
	var mount: Control = host.get_challenge_mount()
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var previous := Rect2()
	var rectangles := {}
	var keys := {"CheckComputer": "scene.controls.close_computer" if host.is_computer_open() else "scene.controls.check_computer",
		"ComputerHome": "scene.controls.apps"}
	for child: Node in controls.get_children():
		if not child is Button or not child.visible: continue
		var button := child as Button
		_check(not button.accessibility_name.is_empty() and not button.accessibility_name.begins_with("[missing:"), id + ": populated accessible copy " + button.name)
		_check(button.accessibility_name == locale.t(keys[str(button.name)]), id + ": localized accessible label " + button.name)
		_check(button.text.is_empty(), id + ": visible label " + button.name)
		_check(not button.disabled, id + ": enabled control " + button.name)
		var bounds := button.get_global_rect()
		var face: Font = button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		_check(screen.encloses(bounds), id + ": on-screen " + button.name)
		_check(not bounds.intersects(mount.get_global_rect()), id + ": outside Challenge " + button.name)
		_check(not bounds.intersects(previous), id + ": separate targets " + button.name)
		_check(face == TYPOGRAPHY.font(language, percent, style), id + ": native face " + button.name)
		_check(font_size == TYPOGRAPHY.font_size(language, percent, 24, style), id + ": full accessible size " + button.name)
		var box := button.get_theme_stylebox("normal")
		var inner := bounds.size - box.get_minimum_size()
		var text_extent := face.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER,
			inner.x, font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		_check(text_extent.x <= inner.x + 1.0, id + ": wrapped text width " + button.name)
		_check(text_extent.y <= inner.y + 1.0, id + ": complete wrapped text " + button.name)
		for character: String in button.text:
			if not character.strip_edges().is_empty():
				_check(face.has_char(character.unicode_at(0)), id + ": glyph " + character)
		rectangles[str(button.name)] = {"text": button.text, "x": bounds.position.x, "y": bounds.position.y,
			"width": bounds.size.x, "height": bounds.size.y, "font_size": font_size}
		previous = bounds
	return rectangles
