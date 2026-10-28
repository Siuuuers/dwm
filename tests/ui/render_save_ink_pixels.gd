extends GutTest
const DRAWER := preload("res://scripts/ui/backup/BackupDrawer.gd")
const THEME := preload("res://scripts/ui/backup/BackupTheme.gd")

func test_stable_splashes_fade_without_changing_labels_or_focus() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 220)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var drawer: Button = DRAWER.new()
	drawer.position = Vector2(24, 20)
	drawer.size = Vector2(188, 176)
	drawer.theme = THEME.build_scene("en", 100)
	viewport.add_child(drawer)
	drawer.present("Manual 1", "Saved", false, [])
	await _settle_ink_pixels()
	var label_rects := [drawer.identity_label.get_rect(), drawer.state_label.get_rect()]
	var bare: Image = viewport.get_texture().get_image()
	drawer.present("Manual 1", "Saved", false, [17])
	await _settle_ink_pixels()
	var first: Image = viewport.get_texture().get_image()
	drawer.present("Manual 1", "Saved", false, [9123])
	await _settle_ink_pixels()
	var second: Image = viewport.get_texture().get_image()
	drawer.present("Manual 1", "Saved", false, [17, 9123])
	await _settle_ink_pixels()
	var aged: Image = viewport.get_texture().get_image()
	assert_eq([drawer.identity_label.get_rect(), drawer.state_label.get_rect()], label_rects)
	assert_eq(drawer.accessibility_name, "Manual 1, Saved")
	assert_eq(_ink_hash(bare.get_region(Rect2i(24, 20, 188, 80))),
		_ink_hash(aged.get_region(Rect2i(24, 20, 188, 80))), "ink never changes caption pixels")
	var faded_pixels := 0
	var fresh_pixels := 0
	for y: int in range(106, 178):
		for x: int in range(28, 208):
			var background := bare.get_pixel(x, y)
			var old_pixel := first.get_pixel(x, y)
			var new_pixel := second.get_pixel(x, y)
			var actual := aged.get_pixel(x, y)
			if old_pixel != background and new_pixel == background:
				var before_distance := absf(old_pixel.r - background.r) + absf(old_pixel.g - background.g) + absf(old_pixel.b - background.b)
				var after_distance := absf(actual.r - background.r) + absf(actual.g - background.g) + absf(actual.b - background.b)
				if before_distance > 0.08:
					assert_almost_eq(after_distance / before_distance, 0.65, 0.09, "same old splash fades by selected proportion")
					faded_pixels += 1
			elif old_pixel == background and new_pixel != background:
				assert_eq(actual, new_pixel, "new splash retains original opacity")
				fresh_pixels += 1
	assert_gt(faded_pixels, 0)
	assert_gt(fresh_pixels, 0)
	drawer.queue_redraw()
	await _settle_ink_pixels()
	assert_eq(_ink_hash(viewport.get_texture().get_image()), _ink_hash(aged), "redraw never rerolls stored shapes")
	var marks := [17, 31, 73, 127, 257, 1021, 4093, 9123]
	drawer.present("Manual 1", "Saved", false, marks)
	await _settle_ink_pixels()
	var full: Image = viewport.get_texture().get_image()
	drawer.present("Manual 1", "Saved", false, marks.slice(1))
	await _settle_ink_pixels()
	assert_eq(_ink_hash(viewport.get_texture().get_image()), _ink_hash(full), "age seven is below five percent and disappears")
	drawer.grab_focus()
	await _settle_ink_pixels()
	var focused: Image = viewport.get_texture().get_image()
	drawer.present("Manual 1", "Saved", false, [])
	await _settle_ink_pixels()
	var focus_bare: Image = viewport.get_texture().get_image()
	assert_true(drawer.has_focus())
	assert_eq(_ink_hash(focused.get_region(Rect2i(14, 10, 208, 18))),
		_ink_hash(focus_bare.get_region(Rect2i(14, 10, 208, 18))), "focus perimeter remains unchanged")
	drawer.release_focus()
	drawer.theme = THEME.build_scene("en", 150)
	# Match the Scene Backup projection: slot identity and frozen HH:MM.
	drawer.present("Slot 1", "12:34", false, [])
	await _settle_ink_pixels()
	var large_bare: Image = viewport.get_texture().get_image()
	var large_rects := [drawer.identity_label.get_rect(), drawer.state_label.get_rect()]
	drawer.present("Slot 1", "12:34", false, marks)
	await _settle_ink_pixels()
	var large_ink: Image = viewport.get_texture().get_image()
	assert_eq([drawer.identity_label.get_rect(), drawer.state_label.get_rect()], large_rects, "150 percent production labels keep their layout")
	for rect: Rect2 in large_rects:
		assert_true(Rect2(0, 4, drawer.size.x, 156).encloses(rect), "150 percent labels remain inside the paper")
	var glyph_color := drawer.get_theme_color("paper_ink", "Backup")
	var glyph_pixels := 0
	for label: Label in [drawer.identity_label, drawer.state_label]:
		var bounds := Rect2i(label.get_global_rect()).intersection(Rect2i(0, 0, 240, 220))
		for y: int in range(bounds.position.y, bounds.end.y):
			for x: int in range(bounds.position.x, bounds.end.x):
				var before := large_bare.get_pixel(x, y)
				if absf(before.r - glyph_color.r) < 0.005 and absf(before.g - glyph_color.g) < 0.005 and absf(before.b - glyph_color.b) < 0.005:
					assert_eq(large_ink.get_pixel(x, y), before, "opaque large glyph remains above the ink")
					glyph_pixels += 1
	assert_gt(glyph_pixels, 0)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	for item: Array in [["bare", bare], ["fresh", first], ["aged", aged], ["bounded", full], ["focus", focused], ["large-text", large_ink]]:
		assert_eq(item[1].save_png("res://.godot/ci/save-ink-pixels-" + item[0] + ".png"), OK)
	print("SAVE_INK_PIXELS_COMPLETED")

func _settle_ink_pixels() -> void:
	for frame: int in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _ink_hash(pixels: Image) -> String:
	return pixels.get_data().hex_encode().sha256_text()
