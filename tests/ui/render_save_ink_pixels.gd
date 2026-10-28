extends GutTest
const DRAWER := preload("res://scripts/ui/backup/BackupDrawer.gd")
const THEME := preload("res://scripts/ui/backup/BackupTheme.gd")

func test_plain_paper_preserves_labels_selection_and_focus() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 220)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var drawer: Button = DRAWER.new()
	drawer.position = Vector2(24, 20)
	drawer.size = Vector2(188, 176)
	viewport.add_child(drawer)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	for text_size: int in [100, 150]:
		drawer.theme = THEME.build_scene("en", text_size)
		drawer.present("Slot 1", "12:34", false)
		await _settle_ink_pixels()
		assert_eq(drawer.accessibility_name, "Slot 1, 12:34")
		for label: Label in [drawer.identity_label, drawer.state_label]:
			assert_true(Rect2(0, 4, drawer.size.x, 156).encloses(label.get_rect()))
		var paper := drawer.get_theme_color("paper", "Backup")
		var plain: Image = viewport.get_texture().get_image()
		# Below the labels the whole paper stays blank, including the former splash area.
		var below_labels := ceili(drawer.position.y + drawer.state_label.get_rect().end.y + 2)
		for y: int in range(below_labels, 176):
			for x: int in range(28, 208):
				var pixel := plain.get_pixel(x, y)
				assert_almost_eq(pixel.r, paper.r, 0.005)
				assert_almost_eq(pixel.g, paper.g, 0.005)
				assert_almost_eq(pixel.b, paper.b, 0.005)
		drawer.queue_redraw()
		await _settle_ink_pixels()
		assert_eq(viewport.get_texture().get_image().get_data(), plain.get_data())
		drawer.selected = true
		drawer.grab_focus()
		await _settle_ink_pixels()
		assert_true(drawer.has_focus())
		var focused: Image = viewport.get_texture().get_image()
		assert_ne(focused.get_data(), plain.get_data(), "selection and focus remain visible")
		assert_eq(plain.save_png("res://.godot/ci/save-ink-pixels-plain-%d.png" % text_size), OK)
		assert_eq(focused.save_png("res://.godot/ci/save-ink-pixels-focus-%d.png" % text_size), OK)
		drawer.release_focus()
		drawer.selected = false
	print("SAVE_INK_PIXELS_COMPLETED")

func _settle_ink_pixels() -> void:
	for frame: int in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
