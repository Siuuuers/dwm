extends "res://tests/ui/render_shop_cosmetics_base.gd"

func test_rendered_cosmetic_purchases_and_physical_save() -> void:
	if not await _begin_cosmetic_run(): return
	# Fixture funding uses the existing economy owner, never saved-state injection.
	assert_true(game.change_money(200), "canonical economy owner funds synthetic purchases")
	var initial_inventory: Dictionary = game.inventory.duplicate(true)
	var host: Control = get_tree().current_scene
	var shell: Control = await _open_apps(host)
	if shell == null: return
	_assert_cosmetic_overlay(shell, false)
	var bare_pixels: Dictionary = await _cosmetic_pixels(shell)
	var owned_pixels := {}
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	_assert_retained_catalogue(shop)
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_gte(before.gameplay.money, 135, "fixture's real money owner funds three purchases")
	if before.gameplay.money < 135: return
	var reading: Dictionary = bridge.capture_reading_checkpoint(false).value.duplicate(true)
	for index: int in COSMETICS.size():
		var item_id: String = COSMETICS[index]
		if not await _select_cosmetic(shop, item_id): return
		assert_eq(shop.quantity, 1)
		assert_false(shop._buy_button.disabled)
		var row: Dictionary = shop._records[shop._index_of(item_id)]
		assert_eq(row.unit_price, 45)
		assert_eq(row.currency, "money")
		assert_eq(row.legal_max, 1)
		assert_false(row.batchable)
		await _click(shop._buy_button)
		if not _ok(shop._purchase_result): return
		assert_eq(game.money, before.gameplay.money - 45 * (index + 1), "one debit per purchased cosmetic")
		for owned_index: int in range(index + 1):
			assert_eq(game.inventory.get(COSMETICS[owned_index], 0), 1, "previous decorations remain owned")
		assert_eq(_shop_receipts().size(), index + 1)
		assert_eq(bridge.capture_reading_checkpoint(false).value, reading)
		await _click(shell.home_button)
		var actual_pixels: Dictionary = await _cosmetic_pixels(shell)
		assert_ne(actual_pixels[item_id], bare_pixels[item_id], "purchase renders its own visible decoration")
		for previous_id: String in owned_pixels:
			assert_eq(actual_pixels[previous_id], owned_pixels[previous_id], "stack retains earlier decoration pixels")
		owned_pixels[item_id] = actual_pixels[item_id]
		await _screenshot("shop-cosmetic-" + item_id)
		if not await _launch_app(shell, &"shop"): return
	await _assert_owned_unavailable(shop)
	var after: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_eq(after.gameplay.stats, before.gameplay.stats, "cosmetics change no pressure or other stats")
	assert_eq(after.scene, before.scene)
	assert_eq(after.contacts, before.contacts)
	assert_eq(after.desktop, before.desktop, "cosmetics add no desktop notes or capability state")
	await _click(shell.home_button)
	assert_eq(shell._active_id, &"")
	_assert_cosmetic_overlay(shell, true)
	await _screenshot("shop-cosmetics-stacked-home")
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	_assert_cosmetic_overlay(shell, false)
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading)
	await _screenshot("shop-cosmetics-hidden-reading")
	if not await _save_slot(1): return
	var disk: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(disk): return
	assert_eq(disk.value.current_snapshot.snapshot.gameplay, after.gameplay)
	var proof := {"creator_process_id": OS.get_process_id(), "gameplay": after.gameplay,
		"initial_inventory": initial_inventory, "owned_pixels": owned_pixels, "bare_pixels": bare_pixels, "slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json")}
	if not _write_json(SHOP_PROOF, proof): return
	_write_json("res://.godot/ci/shop-cosmetics-create.json", proof)
	print("SHOP_COSMETICS_CREATE_COMPLETED purchases=3 debit=135")
