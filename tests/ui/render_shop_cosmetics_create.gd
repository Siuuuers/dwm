extends "res://tests/ui/render_shop_cosmetics_base.gd"

func test_retired_ownership_is_inert_and_can_be_saved() -> void:
	if not await _begin_cosmetic_run(): return
	var initial_inventory: Dictionary = game.inventory.duplicate(true)
	var host: Control = get_tree().current_scene
	var shell: Control = await _open_apps(host)
	if shell == null: return
	_assert_cosmetic_overlay(shell)
	var bare_pixels: Dictionary = await _cosmetic_pixels(shell)
	# Compatibility fixture: model ownership from before retirement, not a new purchase.
	for item_id: String in COSMETICS: game.add_inventory(item_id)
	_assert_cosmetic_overlay(shell)
	assert_eq(await _cosmetic_pixels(shell), bare_pixels, "legacy ownership draws no materials")
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	_assert_retained_catalogue(shop)
	_assert_retired_unavailable(shop)
	await _screenshot("shop-cosmetics-retired")
	await _click(shell.home_button)
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	var after: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	if not await _save_slot(1): return
	var disk: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(disk): return
	assert_eq(disk.value.current_snapshot.snapshot.gameplay, after.gameplay)
	var proof := {"creator_process_id": OS.get_process_id(), "gameplay": after.gameplay,
		"initial_inventory": initial_inventory, "bare_pixels": bare_pixels, "slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json")}
	if not _write_json(SHOP_PROOF, proof): return
	_write_json("res://.godot/ci/shop-cosmetics-create.json", proof)
	print("SHOP_COSMETICS_CREATE_COMPLETED retired=3 purchases=0")
