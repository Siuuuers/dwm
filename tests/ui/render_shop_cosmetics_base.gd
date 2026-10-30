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

func _assert_retained_catalogue(shop: Control) -> void:
	for item_id: String in ["lucky_charm", "debug_key", "bookend_keepsake", "metronome_keepsake", "pocket_calculator_keepsake"]:
		assert_true(shop.cards.has(item_id), "retained catalogue card " + item_id)
	var supportz: Array = shop._records.filter(func(row: Dictionary) -> bool: return row.id == "supportz")
	assert_eq(supportz.size(), 1, "Supportz keeps one existing secret slot")
	if supportz.size() == 1:
		assert_true(supportz[0].blank)
		assert_false(supportz[0].actionable, "ordinary caption has no fabricated round completions")

func _assert_retired_unavailable(shop: Control) -> void:
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	for item_id: String in COSMETICS:
		assert_false(shop.cards.has(item_id))
		assert_eq(shop._provider.can_purchase(item_id).get("code"), &"unregistered_shop_item")
		assert_eq(shop._provider.purchase(item_id, 1).get("code"), &"unregistered_shop_item")
	assert_eq(game.capture_run_snapshot_input(), before, "rejected retired purchases never debit or mutate state")

func _assert_cosmetic_overlay(shell: Control) -> void:
	assert_null(shell.find_child("CosmeticOverlay", true, false))
	assert_null(get_tree().current_scene.find_child("CrystalSurface", true, false))

func _cosmetic_pixels(shell: Control) -> Dictionary:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = get_viewport().get_texture().get_image()
	var canvas: Control = shell.desktop_canvas
	# Sample the former paper and edge decoration regions.
	# The right strip also clears the silk stroke's antialiased fringe.
	var regions := {"letter_with_wax_seal": [Rect2(canvas.size.x * 0.5 - 64, canvas.size.y - 232, 128, 48)],
		"crystal_stutters": [Rect2(0, 0, canvas.size.x - 9, 8),
			Rect2(0, canvas.size.y - 72, canvas.size.x - 9, 8),
			Rect2(0, 8, 8, canvas.size.y - 80), Rect2(canvas.size.x - 28, 8, 8, canvas.size.y - 80)],
		"inked_silk_string": [Rect2(canvas.size.x - 18, canvas.size.y * 0.12 - 2, 18, 36)]}
	# Window.get_final_transform includes letterbox offsets outside the viewport texture.
	var texture_transform := Transform2D.IDENTITY.scaled(Vector2(pixels.get_size()) / get_viewport().get_visible_rect().size)
	var hashes := {}
	for item_id: String in COSMETICS:
		var sampled := PackedByteArray()
		for sample: Rect2 in regions[item_id]:
			var region := Rect2i(texture_transform * canvas.get_global_transform_with_canvas() * sample)
			assert_true(Rect2i(Vector2i.ZERO, pixels.get_size()).encloses(region), item_id + " sample stays inside viewport pixels")
			sampled.append_array(pixels.get_region(region).get_data())
			print("COSMETIC_PIXEL_REGION ", item_id, " ", region)
		hashes[item_id] = sampled.hex_encode().sha256_text()
	return hashes
