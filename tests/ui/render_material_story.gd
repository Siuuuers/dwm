extends "res://tests/integration/authored_week_child.gd"
## Shipped Day1 artwork and seven controls; purchases use real Shop commands.

func test_authored_story_materials_preserve_reading_and_control_geometry() -> void:
	_phase = "create"
	if not _setup_authored(): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1): return
	var host: Control = get_tree().current_scene
	var art: Control = get_tree().root.find_child("SceneArt", true, false)
	assert_not_null(art)
	if art == null: return
	assert_eq(art._entry_id, "Day1", "current authored opening owns artwork")
	assert_not_null(art._background.texture, "capture contains the shipped background")
	assert_true(art.is_visible_in_tree())
	var rail: Control = _caption().transport_rail
	assert_eq(rail._buttons.size(), 7)
	var geometry := []
	for button: Button in rail._buttons.values(): geometry.append(button.get_global_rect())
	var reading: Dictionary = bridge.capture_reading_checkpoint(false).value.duplicate(true)
	var bare: Dictionary = await _story_material_pixels(art, rail)
	await _screenshot("material-authored-Day1-before")
	assert_true(game.change_money(200), "fixture funding uses the economy owner")
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	var shell: Control = host.get_computer_mount().get_node("SceneComputerDesktop")
	await _click(shell.launcher_buttons[&"shop"])
	var shop: Control = shell._cached_app_windows[&"shop"]
	for item: String in ["letter_with_wax_seal", "crystal_stutters", "inked_silk_string"]:
		for attempt: int in shop.page_count:
			if shop.cards[item].is_visible_in_tree(): break
			await _click(shop.next_button if not shop.next_button.disabled else shop.previous_button)
		assert_true(shop.cards[item].is_visible_in_tree())
		await _click(shop.cards[item])
		assert_false(shop._buy_button.disabled)
		await _click(shop._buy_button)
		if not _ok(shop._purchase_result): return
		assert_eq(game.inventory.get(item, 0), 1)
	await _screenshot("material-authored-Day1-Shop")
	await _click(shell.home_button)
	await _screenshot("material-authored-Day1-computer")
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	for frame: int in 6: await get_tree().process_frame
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading, "material purchase does not advance the authored beat")
	var decorated: Dictionary = await _story_material_pixels(art, rail)
	assert_ne(decorated.art, bare.art, "owned crystal visibly changes the authored artwork edge")
	for index: int in 7:
		assert_ne(decorated.rail[index], bare.rail[index], "paper visibly textures command " + str(index))
		assert_eq(rail._buttons.values()[index].get_global_rect(), geometry[index], "command geometry remains unchanged")
	assert_eq(art._material_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(art._material_overlay.focus_mode, Control.FOCUS_NONE)
	await _screenshot("material-authored-Day1-after")
	art._material_overlay.queue_redraw()
	rail._refresh_material()
	assert_eq(await _story_material_pixels(art, rail), decorated, "static story materials repaint identically")
	print("MATERIAL_AUTHORED_STORY_COMPLETED background=Day1 controls=7 purchases=3")

func _story_material_pixels(art: Control, rail: Control) -> Dictionary:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = get_viewport().get_texture().get_image()
	var texture_transform := Transform2D.IDENTITY.scaled(Vector2(pixels.get_size()) / get_viewport().get_visible_rect().size)
	var result := {"art": "", "rail": []}
	var artwork_rect: Rect2 = art.get_right_rect()
	var region := Rect2i(texture_transform * art.get_global_transform_with_canvas() * Rect2(artwork_rect.position, Vector2(64, 8)))
	assert_true(Rect2i(Vector2i.ZERO, pixels.get_size()).encloses(region))
	result.art = pixels.get_region(region).get_data().hex_encode().sha256_text()
	for button: Button in rail._buttons.values():
		region = Rect2i(texture_transform * button.get_global_transform_with_canvas() * Rect2(12, 12, button.size.x - 24, 4))
		assert_true(Rect2i(Vector2i.ZERO, pixels.get_size()).encloses(region))
		result.rail.append(pixels.get_region(region).get_data().hex_encode().sha256_text())
	return result
