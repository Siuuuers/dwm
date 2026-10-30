extends "res://tests/integration/scene_apps_connected_child.gd"
## Cloud-rendered synthetic scene, FINAL services and real Shop/Save owners.
const COSMETICS := ["letter_with_wax_seal", "crystal_stutters", "inked_silk_string"]
const SHOP_PROOF := "user://shop-cosmetics-proof.json"

func _begin_cosmetic_run() -> bool:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return false
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return false
	var started: Dictionary = saves.start_scene_new_run("target_b", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return false
	return await _wait_line("scene.test.b", "line.scene.test.b.one")

func _select_cosmetic(shop: Control, item_id: String) -> bool:
	assert_true(shop.cards.has(item_id), "catalogue retains " + item_id)
	if not shop.cards.has(item_id): return false
	# Page through actual visible controls instead of clicking hidden cards.
	for attempt: int in shop.page_count:
		if shop.cards[item_id].is_visible_in_tree(): break
		await _click(shop.next_button if not shop.next_button.disabled else shop.previous_button)
	assert_true(shop.cards[item_id].is_visible_in_tree())
	if not shop.cards[item_id].is_visible_in_tree(): return false
	await _click(shop.cards[item_id])
	assert_eq(shop.selected_id, item_id)
	return shop.selected_id == item_id

func _assert_retained_catalogue(shop: Control) -> void:
	for item_id: String in ["lucky_charm", "debug_key", "bookend_keepsake", "metronome_keepsake", "pocket_calculator_keepsake"]:
		assert_true(shop.cards.has(item_id), "retained catalogue card " + item_id)
	var supportz: Array = shop._records.filter(func(row: Dictionary) -> bool: return row.id == "supportz")
	assert_eq(supportz.size(), 1, "Supportz keeps one existing secret slot")
	if supportz.size() == 1:
		assert_true(supportz[0].blank)
		assert_false(supportz[0].actionable, "ordinary caption has no fabricated round completions")

func _assert_owned_unavailable(shop: Control) -> void:
	for item_id: String in COSMETICS:
		assert_eq(game.inventory.get(item_id, 0), 1)
		if not await _select_cosmetic(shop, item_id): return
		assert_true(shop._buy_button.disabled, "owned cosmetic cannot be bought again: " + item_id)
		var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
		await _click(shop._buy_button)
		assert_eq(game.capture_run_snapshot_input(), before, "disabled duplicate purchase changes nothing")

func _assert_cosmetic_overlay(shell: Control, expected: bool) -> void:
	var overlay: Control = shell.cosmetic_overlay
	assert_not_null(overlay)
	if overlay == null: return
	assert_eq(overlay.is_visible_in_tree(), expected)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(overlay.focus_mode, Control.FOCUS_NONE)

func _cosmetic_pixels(shell: Control) -> Dictionary:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = get_viewport().get_texture().get_image()
	var canvas: Control = shell.desktop_canvas
	# Purchase paper first: later edge materials leave this central background sample alone.
	var regions := {"letter_with_wax_seal": Rect2(canvas.size.x * 0.5 - 64, canvas.size.y - 232, 128, 48),
		"crystal_stutters": Rect2(1, 1, 60, 7),
		"inked_silk_string": Rect2(canvas.size.x - 8, canvas.size.y * 0.12 - 2, 8, 24)}
	# Window.get_final_transform includes letterbox offsets outside the viewport texture.
	var texture_transform := Transform2D.IDENTITY.scaled(Vector2(pixels.get_size()) / get_viewport().get_visible_rect().size)
	var hashes := {}
	for item_id: String in COSMETICS:
		var region := Rect2i(texture_transform * canvas.get_global_transform_with_canvas() * regions[item_id])
		assert_true(Rect2i(Vector2i.ZERO, pixels.get_size()).encloses(region), item_id + " sample stays inside viewport pixels")
		hashes[item_id] = pixels.get_region(region).get_data().hex_encode().sha256_text()
		print("COSMETIC_PIXEL_REGION ", item_id, " ", region)
	return hashes
