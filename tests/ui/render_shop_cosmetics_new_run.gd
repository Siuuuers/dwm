extends "res://tests/ui/render_shop_cosmetics_base.gd"

func test_new_run_clears_cosmetics_without_changing_saved_run() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(SHOP_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), int(proof.creator_process_id))
	if not await _begin_cosmetic_run(): return
	assert_eq(game.inventory, proof.initial_inventory, "new run starts from its own inventory")
	for item_id: String in COSMETICS: assert_eq(game.inventory.get(item_id, 0), 0)
	assert_true(game.change_money(45), "fund fresh-run affordability through the economy owner")
	var shell: Control = await _open_apps(get_tree().current_scene)
	if shell == null: return
	_assert_cosmetic_overlay(shell, false)
	assert_eq(await _cosmetic_pixels(shell), proof.bare_pixels, "new run restores undecorated computer pixels")
	await _screenshot("shop-cosmetics-new-run-home")
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	_assert_retained_catalogue(shop)
	for item_id: String in COSMETICS:
		if not await _select_cosmetic(shop, item_id): return
		assert_false(shop._buy_button.disabled, "new run may purchase its own " + item_id)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256, "starting fresh leaves saved owned cosmetics intact")
	_write_json("res://.godot/ci/shop-cosmetics-new-run.json", {"process_id": OS.get_process_id(),
		"inventory": game.inventory, "prior_slot_sha256": proof.slot_sha256})
	print("SHOP_COSMETICS_NEW_RUN_COMPLETED owned=0")
