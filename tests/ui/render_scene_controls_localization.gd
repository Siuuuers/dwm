extends SceneTree
## Production chrome, caption and rail with isolated preferences and synthetic text.
## Presentation evidence only; connected journeys own command/custody acceptance.
const HOST := preload("res://scenes/narrative/SceneHost.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CAPTION := preload("res://scenes/ui/witnessed/WitnessedCaptionLayer.tscn")
const COMMANDS := ["History", "Save", "Load", "Skip", "Auto", "Next", "Settings"]
const FIXTURE_TEXT := "Synthetic layout fixture: the last rendered dialogue row meets the visible computer tag. This deliberately long sentence wraps naturally while preserving the selected font and full text size."
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
var _failures: Array[String] = []
var _samples: Array[Dictionary] = []
var _captures := 0
var _dispatches := 0
var _caption: Node
var _viewport: SubViewport
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
	_viewport = viewport
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
	_caption = CAPTION.instantiate()
	viewport.add_child(_caption)
	# Geometry uses the production layer with synthetic display text. Disable its
	# gameplay polling; these captures do not claim a live reading session.
	_caption.set_process(false)
	_caption._localization = locale
	_caption._profile = profile
	_check(_caption.transport_rail.bind_localization(locale), "caption rail catalog")
	_caption.caption_text.text = FIXTURE_TEXT
	_caption.caption_text.visible_characters = -1
	_caption.caption_text.revealing = false
	_caption.caption_text.show()
	_caption.caption_text.set_process(false)
	for language: String in ["en", "zh_HK", "zh_CN", "ja", "ko"]:
		_check(locale.set_locale(language).get("ok", false), "commit " + language)
		for style: String in ["pixel", "readable"]:
			_check(locale.set_font_style(style).get("ok", false), "commit " + style)
			for percent: int in [100, 125, 150]:
				_check(profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "commit size")
				_check(_caption.configure_presentation(language, percent, "AfterHours", false, "standard", false, 1, style), "caption tuple")
				for opened: bool in [false, true]:
					await _capture(host, locale, language, style, percent, opened, "baseline")
				if percent == 150:
					viewport.size = Vector2i(1600, 900)
					viewport.global_canvas_transform = Transform2D(0.0, Vector2(1.25, 1.25), 0.0, Vector2.ZERO)
					await _capture(host, locale, language, style, percent, false, "scaled")
					viewport.global_canvas_transform = Transform2D.IDENTITY
					viewport.size = Vector2i(1280, 720)
					_caption.transport_rail.set_ending_layout(true)
					await _capture(host, locale, language, style, percent, false, "ending")
					_caption.transport_rail.set_ending_layout(false)
	_check(_samples.size() == 80, "60 locale/style/size/open tuples, 10 scaled and 10 ending tuples")
	_check(_dispatches == 0, "presentation changes dispatch no game commands")
	if DisplayServer.get_name() != "headless": _check(_captures == 80, "all 80 presentation screenshots")
	var report := {"ok": _failures.is_empty(), "renderer": DisplayServer.get_name(), "samples": _samples,
		"captures": _captures, "failures": _failures, "fixture": "Production SceneHost, caption and seven-command rail; synthetic wrapped English display text, isolated real locale/profile. No board or live reading session; command effects belong to connected journeys."}
	var file := FileAccess.open(_folder.path_join("results.json"), FileAccess.WRITE)
	if _check(file != null, "result file"):
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("SCENE_CONTROLS_LOCALIZATION_RESULT ", JSON.stringify(report))
	viewport.free()
	locale.free()
	profile.free()
	quit(0 if _failures.is_empty() else 1)

func _capture(host: Control, locale: Node, language: String, style: String, percent: int, opened: bool, variant: String) -> void:
	host.set_computer_open(opened)
	_caption._layout_stack()
	_caption.transport_rail.project(not opened, false, true, not opened, not opened, not opened, not opened, not opened, not opened)
	await _settle()
	var id := "%s-%s-%d-%s-%s" % [language, style, percent, "open" if opened else "closed", variant]
	var rectangles := _inspect(host, locale, language, style, percent, id)
	var rail: Control = _caption.transport_rail
	var caret: Button = host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer")
	var tag := Rect2(caret.get_global_rect().get_center() - Vector2(16, 12), Vector2(32, 24))
	var leaf: RichTextLabel = _caption.caption_text
	leaf.release_focus()
	var row_bottom := leaf.global_position.y + leaf.get_theme_stylebox("normal").get_content_margin(SIDE_TOP) + leaf.get_content_height()
	_check(leaf.get_line_count() > 1, id + ": synthetic text actually wraps")
	_check(absf(row_bottom - tag.position.y) <= 1.0, id + ": rendered content bottom meets visible tag top: " + str(row_bottom))
	_check(not caret.get_global_rect().intersects(rail.get_node("Save").get_global_rect()), id + ": Save and tag have separate hit targets")
	var final: Transform2D = _viewport.get_final_transform()
	var drawn_row: Vector2 = final * leaf.get_global_transform_with_canvas() * Vector2(0, leaf.get_theme_stylebox("normal").get_content_margin(SIDE_TOP) + leaf.get_content_height())
	var drawn_tag: Vector2 = final * caret.get_global_transform_with_canvas() * ((caret.size - Vector2(32, 24)) * 0.5)
	_check(absf(drawn_row.y - drawn_tag.y) <= 1.25, id + ": alignment survives viewport scale")
	var centers: Array[float] = []
	for command: String in COMMANDS:
		var button: Button = rail.get_node(command)
		var bounds := button.get_global_rect()
		centers.append(bounds.get_center().x)
		_check(is_equal_approx(bounds.size.x, 1280.0 / 7.0), id + ": equal bay " + command)
		_check(button.visible and button.disabled == opened, id + ": drawn command admission " + command)
		_check(not button.text.is_empty() and not button.text.begins_with("[missing:"), id + ": translated " + command)
		var inner := button.size - button.get_theme_stylebox("normal").get_minimum_size()
		var extent := button.get_theme_font("font").get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER,
			inner.x, button.get_theme_font_size("font_size"), -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		_check(extent.x <= inner.x + 1 and extent.y <= inner.y + 1, id + ": full-size command fits " + command)
		if command in ["Skip", "Auto"]:
			_check(button.text == locale.t("witnessed.transport." + command.to_lower()), id + ": names-only " + command)
			_check(button.accessibility_name != button.text and not button.tooltip_text.is_empty(), id + ": mode state remains accessible")
	for index in range(1, centers.size()):
		_check(is_equal_approx(centers[index] - centers[index - 1], 1280.0 / 7.0), id + ": even command centers")
	_check(rail.get_node("Auto").theme_type_variation == &"WitnessedTransportMode", id + ": selected Auto survives disabled projection")
	_samples.append({"id": id, "buttons": rectangles, "centers": centers, "row_bottom": row_bottom,
		"tag_top": tag.position.y, "drawn_row_bottom": drawn_row.y, "drawn_tag_top": drawn_tag.y,
		"wrapped_lines": leaf.get_line_count(), "viewport": str(_viewport.size)})
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture := _viewport.get_texture().get_image()
	# Confirm that native glyphs were painted near the measured last row, rather
	# than accepting empty containers or geometry-only screenshots.
	var ink := leaf.get_theme_color("default_color")
	var ink_bottom := -1
	var native_font := leaf.get_theme_font("normal_font")
	var native_size := leaf.get_theme_font_size("normal_font_size")
	var scale_y := 1.25 if variant == "scaled" else 1.0
	var last_row_height := int(ceil(native_font.get_height(native_size) * scale_y))
	for y in range(maxi(0, int(drawn_row.y) - last_row_height), mini(picture.get_height(), int(drawn_row.y) + 2)):
		for x in range(int(24 * scale_y), mini(picture.get_width(), int(1256 * scale_y))):
			var pixel := picture.get_pixel(x, y)
			if absf(pixel.r - ink.r) + absf(pixel.g - ink.g) + absf(pixel.b - ink.b) < 0.04:
				ink_bottom = y
	_check(ink_bottom >= int(drawn_row.y) - last_row_height, id + ": native last-row glyph ink exists")
	_samples.back()["native_ink_bottom"] = ink_bottom
	var center := Vector2i(final * caret.get_global_transform_with_canvas() * (caret.size * 0.5))
	var top := picture.get_pixel(center.x, center.y - 2).get_luminance()
	var bottom := picture.get_pixel(center.x, center.y + 2).get_luminance()
	_check(bottom > top + 0.1 if opened else top > bottom + 0.1, id + ": visible chevron orientation")
	if _check(not picture.is_empty() and picture.save_png(_folder.path_join(id + ".png")) == OK, id + " screenshot"):
		_captures += 1


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
