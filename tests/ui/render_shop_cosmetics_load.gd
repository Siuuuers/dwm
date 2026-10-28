extends "res://tests/ui/render_shop_cosmetics_base.gd"

func test_fresh_process_load_restores_cosmetic_ownership() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(SHOP_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), int(proof.creator_process_id))
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.b", "line.scene.test.b.one"): return
	assert_eq(game.capture_run_snapshot_input().gameplay, proof.gameplay, "Load restores purchases without another debit")
	assert_true(_shop_receipts().is_empty(), "new process restores ownership, not live retry receipts")
	var shell: Control = await _open_apps(get_tree().current_scene)
	if shell == null: return
	_assert_cosmetic_overlay(shell, true)
	assert_eq(await _cosmetic_pixels(shell), proof.owned_pixels, "fresh Load renders all three saved decorations")
	await _screenshot("shop-cosmetics-loaded-home")
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	_assert_retained_catalogue(shop)
	await _assert_owned_unavailable(shop)
	assert_eq(game.capture_run_snapshot_input().gameplay, proof.gameplay)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	proof["loader_process_id"] = OS.get_process_id()
	_write_json("res://.godot/ci/shop-cosmetics-load.json", proof)
	print("SHOP_COSMETICS_LOAD_COMPLETED owned=3")
