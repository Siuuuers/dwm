extends GutTest
## Synthetic pixel proof; the connected journey separately owns reading/input timing.
const SURFACE := preload("res://scripts/ui/witnessed/SceneTransitionOverlay.gd")
const RAIL := preload("res://scripts/ui/witnessed/WitnessedTransportRail.gd")
const ART_LAYER := preload("res://scenes/ui/witnessed/WitnessedArtLayer.tscn")

func test_pixel_dissolve_covers_story_and_preserves_live_controls() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var art: Node = ART_LAYER.instantiate()
	viewport.add_child(art)
	var old_background := _texture(Color("702c40"))
	var old_portrait := _texture(Color("235b42"))
	var old_portraits: Array[Texture2D] = [old_portrait]
	art._view.configure_textures(old_background, old_portraits, null, 100, false, true, &"solo", true)
	var caption := _label(viewport, Vector2(620, 420), "SYNTHETIC CAPTION")
	var thought := _label(viewport, Vector2(32, 32), "SYNTHETIC THOUGHT")
	var rail := ColorRect.new()
	rail.position = Vector2(0, RAIL.CONTROL_TOP)
	rail.size = Vector2(1280, 720 - RAIL.CONTROL_TOP)
	rail.color = Color("683d20")
	viewport.add_child(rail)
	var button := Button.new()
	button.position = Vector2(920, 280)
	button.size = Vector2(240, 64)
	button.text = "Synthetic input target"
	viewport.add_child(button)
	var presses := [0]
	button.pressed.connect(func(): presses[0] += 1)
	var chrome := CanvasLayer.new()
	chrome.layer = 20
	viewport.add_child(chrome)
	var caret := Control.new()
	caret.position = Vector2(RAIL.BAY_WIDTH * 1.5 - 24, RAIL.RAIL_POSITION.y + RAIL.CONTROL_RECTS[&"save"].position.y - 48)
	caret.size = Vector2(48, 48)
	chrome.add_child(caret)
	var tag := ColorRect.new()
	tag.position = Vector2(8, 24)
	tag.size = Vector2(32, 24 + RAIL.PLATE_INSET)
	tag.color = Color(0.8, 0.6, 0.2, 0.5)
	caret.add_child(tag)
	var capture_layer := CanvasLayer.new()
	capture_layer.layer = 19
	viewport.add_child(capture_layer)
	var surface: TextureRect = SURFACE.new()
	surface.caret = caret
	capture_layer.add_child(surface)
	await _settle()
	var handle: Control = art._view.get_split_handle()
	assert_not_null(handle)
	if handle == null: return
	var old: Image = viewport.get_texture().get_image()
	assert_true(surface.capture_source())
	var retained: Texture2D = surface.texture
	var new_portraits: Array[Texture2D] = [_texture(Color("bc962d"))]
	art._view.configure_textures(_texture(Color("254f95")), new_portraits, null, 100, false, true, &"solo", true)
	caption.add_theme_color_override("font_color", Color("ffb657"))
	thought.add_theme_color_override("font_color", Color("ffb657"))
	rail.color = Color("1d816d")
	tag.color = Color(0.2, 0.8, 0.9, 0.5)
	await _settle()
	handle.separator_color = Color.CYAN
	handle.queue_redraw()
	# Reference the installed destination, then restore the unchanged captured texture.
	surface.visible = false
	await _settle()
	var target: Image = viewport.get_texture().get_image()
	surface.visible = true
	surface.set_progress(0.0)
	await _settle()
	var start: Image = viewport.get_texture().get_image()
	var content := {"background": Rect2i(700, 120, 160, 80), "portrait": Rect2i(80, 180, 160, 80),
		"caption": Rect2i(620, 420, 360, 48), "thought": Rect2i(32, 32, 360, 48),
		"lower_art": Rect2i(700, int(RAIL.CONTROL_TOP) - 32, 160, 32),
		"caret_clearance": Rect2i(int(caret.position.x) + 1, 616, 46, 12)}
	var line: Rect2 = handle.get_global_transform_with_canvas() * Rect2(handle.size.x - 1, 0, 2, handle.separator_height)
	var controls := {"rail": Rect2i(20, int(RAIL.CONTROL_TOP), 180, 32), "caret": Rect2i(tag.get_global_rect()),
		"divider": Rect2i(line)}
	for name: String in content:
		assert_eq(_hash(start.get_region(content[name])), _hash(old.get_region(content[name])), name + " retains outgoing pixels at zero")
		assert_ne(_hash(old.get_region(content[name])), _hash(target.get_region(content[name])), name + " fixture has different destination pixels")
	for name: String in controls:
		assert_eq(_hash(start.get_region(controls[name])), _hash(target.get_region(controls[name])), name + " shows live destination pixels immediately")
	surface.set_progress(0.5)
	await _settle()
	var middle: Image = viewport.get_texture().get_image()
	for name: String in content:
		var region: Rect2i = content[name]
		var outgoing := 0
		var incoming := 0
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				var before := old.get_pixel(x, y)
				var after := target.get_pixel(x, y)
				if before == after: continue
				var pixel := middle.get_pixel(x, y)
				if pixel == before: outgoing += 1
				if pixel == after: incoming += 1
		assert_gt(outgoing, 0, name + " retains source cells during dissolve")
		assert_gt(incoming, 0, name + " reveals destination cells during dissolve")
	for name: String in controls:
		assert_eq(_hash(middle.get_region(controls[name])), _hash(target.get_region(controls[name])), name + " remains unaffected by progress")
	surface.set_progress(1.0)
	await _settle()
	var finished: Image = viewport.get_texture().get_image()
	assert_eq(_hash(finished), _hash(target), "completion exactly matches installed destination")
	assert_same(surface.texture, retained, "progress never reads back or replaces the retained framebuffer")
	assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(surface.focus_mode, Control.FOCUS_NONE)
	surface.set_progress(0.5)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame
	assert_eq(presses[0], 1, "capture surface itself never intercepts input")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	for item: Array in [["source", old], ["start", start], ["middle", middle], ["finished", finished]]:
		assert_eq(item[1].save_png("res://.godot/ci/scene-transition-pixels-" + item[0] + ".png"), OK)
	surface.clear_capture()
	assert_false(surface.visible)
	assert_null(surface.texture)
	print("SCENE_TRANSITION_PIXELS_COMPLETED")

func _texture(color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _label(parent: Node, position: Vector2, copy: String) -> Label:
	var label := Label.new()
	label.position = position
	label.size = Vector2(500, 48)
	label.text = copy
	label.add_theme_font_size_override("font_size", 32)
	parent.add_child(label)
	return label

func _settle() -> void:
	for frame: int in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _hash(image: Image) -> String:
	return image.get_data().hex_encode().sha256_text()
