extends "res://tests/integration/scene_contacts_connected_child.gd"
## FINAL services and real Viewport clicks; TEST authored registration only.
## Wrapper invokes create_apps_scene/load_apps_scene in distinct rendered processes.
## Save/Load use the existing backup application port after opening the real Save sheet.

func _apps_shell(host: Control) -> Control:
	return host.get_computer_mount().get_node_or_null("SceneComputerDesktop")

func _open_apps(host: Control) -> Control:
	if not host.is_computer_open(): await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return null
	if host.get_challenge_mount().is_visible_in_tree():
		var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
		assert_true(panel.home_button.is_visible_in_tree())
		await _click(panel.home_button)
	var shell := _apps_shell(host)
	assert_not_null(shell)
	if shell != null: assert_true(shell.is_visible_in_tree())
	return shell

## A launcher belongs to the Home grid; navigate through the visible Home button
## before selecting a different app, rather than clicking hidden icon coordinates.
func _launch_app(shell: Control, app_id: StringName) -> bool:
	if shell._active_id != &"":
		assert_true(shell.home_button.is_visible_in_tree())
		if not shell.home_button.is_visible_in_tree(): return false
		await _click(shell.home_button)
		assert_eq(shell._active_id, &"")
		if shell._active_id != &"": return false
	var button: Button = shell.launcher_buttons[app_id]
	assert_true(button.is_visible_in_tree(), "Launcher must be physically visible before its Viewport click.")
	assert_false(button.disabled)
	if not button.is_visible_in_tree() or button.disabled: return false
	await _click(button)
	assert_eq(shell._active_id, app_id)
	return shell._active_id == app_id

func _shop_receipts() -> Dictionary:
	var result: Dictionary = {}
	for key: String in game.capture_run_snapshot_input().command_receipts:
		var receipt: Dictionary = game.capture_run_snapshot_input().command_receipts[key]
		if receipt.get("kind") == "scene_shop_purchase": result[key] = receipt.duplicate(true)
	return result

func create_apps_scene() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "Acceptance requires actual rendered frames.")
	if DisplayServer.get_name() == "headless": return
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var started: Dictionary = saves.start_scene_new_run("target_b", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.b", "line.scene.test.b.one"): return
	assert_false(game.capture_scene_challenge_command().get("ok", false), "Ordinary caption precedes Playable admission.")
	var host: Control = get_tree().current_scene
	assert_true(game.change_money(45), "canonical economy owner funds the cosmetic purchase fixture")
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false).value.duplicate(true)
	await _screenshot("apps-ordinary-caption")
	# The direct seventh command uses the existing desktop Settings, without
	# entering Pause or admitting the available story Challenge.
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var blocked: Dictionary = bootstrap._application_gate.acquire(&"restore")
	if not _ok(blocked): return
	var refused: Dictionary = bootstrap.open_scene_settings(host)
	assert_eq(refused.get("code"), &"TRANSACTION_ACTIVE")
	assert_false(host.is_computer_open())
	assert_false(bridge.is_computer_caption_held())
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	if not _ok(bootstrap._application_gate.release(&"restore", blocked.value.token)): return
	await _click(_caption().transport_rail.get_node("Settings"))
	var shell: Control = _apps_shell(host)
	assert_not_null(shell)
	if shell == null: return
	assert_eq(shell._active_id, &"settings")
	assert_true(host.is_computer_open())
	assert_true(bridge.is_computer_caption_held())
	assert_false(get_tree().paused)
	assert_false(get_node("/root/SceneRouter")._production_pause.surface.is_visible_in_tree())
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	assert_eq(profile.get_profile_snapshot(), profile_before, "Opening Settings adds no History/read marks.")
	var settings: Control = shell._cached_app_windows[&"settings"]
	var content: Control = settings.get_content_host()
	assert_true(content._scene_presentation)
	assert_null(content._run_day)
	await _click(content._rails["reading"])
	var auto: BaseButton = content.controls[&"preferences.reading.auto_enabled"]
	assert_true(auto.is_visible_in_tree())
	await _click(auto)
	assert_true(profile.get_preference(&"preferences.reading.auto_enabled", false))
	assert_true(_caption().auto_controller.is_auto_enabled())
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading)
	await _click(auto)
	assert_false(profile.get_preference(&"preferences.reading.auto_enabled", true))
	await _screenshot("apps-direct-settings")
	# Back from the category rail returns to Home; closing the computer returns
	# to the exact caption, and reopening reuses the existing Settings instance.
	content.focus_rail()
	for pressed: bool in [true, false]:
		var back := InputEventKey.new()
		back.keycode = KEY_ESCAPE
		back.physical_keycode = KEY_ESCAPE
		back.pressed = pressed
		get_viewport().push_input(back, true)
		await get_tree().process_frame
	for frame: int in 3: await get_tree().process_frame
	assert_eq(shell._active_id, &"")
	assert_true(host.is_computer_open())
	if not await _launch_app(shell, &"settings"): return
	assert_same(shell._cached_app_windows[&"settings"], settings)
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	assert_false(bridge.is_computer_caption_held())
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading)
	await _click(_caption().transport_rail.get_node("Settings"))
	assert_same(shell._cached_app_windows[&"settings"], settings)
	assert_true(settings.is_visible_in_tree())
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading)
	shell = await _open_apps(host)
	if shell == null: return
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows.get(&"shop")
	assert_not_null(shop)
	if shop == null: return
	assert_true(shop.is_visible_in_tree())
	assert_true(shop.cards["inked_silk_string"].is_visible_in_tree())
	await _click(shop.cards["inked_silk_string"])
	assert_eq(shop.selected_id, "inked_silk_string")
	assert_eq(shop.quantity, 1)
	assert_true(shop._buy_button.is_visible_in_tree())
	assert_false(shop._buy_button.disabled)
	await _screenshot("apps-shop-before-buy")
	await _click(shop._buy_button)
	if not _ok(shop._purchase_result): return
	var bought: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_eq(bought.gameplay.money, before.gameplay.money - 45)
	assert_eq(bought.gameplay.inventory.get("inked_silk_string", 0), before.gameplay.inventory.get("inked_silk_string", 0) + 1)
	assert_eq(_shop_receipts().size(), 1)
	assert_eq(bought.scene, before.scene, "Purchase does not advance the story occurrence.")
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading, "Purchase preserves the visible beat.")
	await _screenshot("apps-shop-purchased")
	if not await _launch_app(shell, &"contacts"): return
	var contacts_app: Control = shell._cached_app_windows.get(&"contacts")
	assert_not_null(contacts_app)
	if contacts_app == null: return
	assert_true(contacts_app.is_visible_in_tree())
	await _screenshot("apps-contacts")
	assert_true(shell.home_button.is_visible_in_tree())
	await _click(shell.home_button)
	assert_eq(shell._active_id, &"")
	await _screenshot("apps-home")
	if not await _launch_app(shell, &"minesweeper"): return
	assert_true(shell.is_visible_in_tree(), "Without a held Challenge, Minesweeper uses the ordinary desktop app.")
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	assert_true(_caption().caption_text.is_visible_in_tree())
	assert_eq(bridge.capture_reading_checkpoint(false).value, reading)
	assert_eq(game.capture_run_snapshot_input().scene, before.scene)
	await _screenshot("apps-same-caption-return")
	# Admit Playable through caption input, then start a physical challenge board.
	await _click(_caption().caption_text)
	if not _ok(game.capture_scene_challenge_command()): return
	var available_reading: Dictionary = bridge.capture_reading_checkpoint(false).value.duplicate(true)
	var available_challenge: Dictionary = game.capture_dating_challenge_state().value.duplicate(true)
	await _click(_caption().transport_rail.get_node("Settings"))
	assert_eq(shell._active_id, &"settings")
	assert_true(host.is_computer_open())
	assert_eq(game.capture_dating_challenge_state().value, available_challenge,
		"Opening Settings does not start an available Challenge.")
	assert_eq(bridge.capture_reading_checkpoint(false).value, available_reading)
	await _screenshot("apps-settings-available-challenge")
	await _click(_controls(host, "CheckComputer"))
	assert_eq(game.capture_dating_challenge_state().value, available_challenge)
	await _click(_controls(host, "CheckComputer"))
	var panel: Control = host.get_challenge_mount().get_node_or_null("SceneChallengePanel")
	assert_not_null(panel)
	if panel == null: return
	assert_true(panel.worksheet.grid.focus_cell(323))
	await _click(panel.worksheet.grid.cell_nodes[323])
	var record: Dictionary = game.capture_dating_challenge_state().value.duplicate(true)
	assert_eq(record.state, "in_progress")
	if record.state != "in_progress": return
	var board: Dictionary = panel.public_view.board.duplicate(true)
	var held: Dictionary = bridge.capture_reading_checkpoint(false).value.duplicate(true)
	await _screenshot("apps-challenge-before-switch")
	# Close the held Challenge, then use the direct Settings command. It must
	# retain the board and cue; Home → Minesweeper resumes that same panel.
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	await _click(_caption().transport_rail.get_node("Settings"))
	assert_true(host.is_computer_open())
	assert_true(bridge.is_computer_caption_held())
	assert_true(shell.is_visible_in_tree())
	assert_same(shell._cached_app_windows[&"settings"], settings)
	assert_eq(shell._active_id, &"settings")
	assert_false(panel.is_visible_in_tree())
	assert_eq(panel.public_view.board, board)
	assert_eq(game.capture_dating_challenge_state().value, record)
	assert_eq(bridge.capture_reading_checkpoint(false).value, held)
	await _screenshot("apps-settings-held-challenge")
	if not await _launch_app(shell, &"shop"): return
	assert_eq(game.capture_dating_challenge_state().value, record)
	await _screenshot("apps-shop-during-challenge")
	await _click(shell.home_button)
	await _click(shell.launcher_buttons[&"minesweeper"])
	assert_true(panel.is_visible_in_tree(), "Home → Minesweeper returns to the held story Challenge.")
	assert_same(host.get_challenge_mount().get_node("SceneChallengePanel"), panel)
	assert_false(shell.is_visible_in_tree())
	assert_eq(panel.public_view.board, board)
	assert_eq(game.capture_dating_challenge_state().value, record, "Reopening preserves the durable Challenge record.")
	assert_eq(bridge.capture_reading_checkpoint(false).value, held)
	await _screenshot("apps-home-minesweeper-challenge-return")
	await _click(_controls(host, "CheckComputer"))
	await _click(_controls(host, "CheckComputer"))
	assert_true(panel.is_visible_in_tree())
	assert_eq(panel.public_view.board, board)
	assert_eq(game.capture_dating_challenge_state().value, record)
	assert_eq(bridge.capture_reading_checkpoint(false).value, held)
	await _screenshot("apps-challenge-return")
	if not await _save_slot(1): return
	var proof := {"process_id": OS.get_process_id(), "board": board, "record": record,
		"money": game.money, "inventory": game.inventory.duplicate(true), "shop_receipts": _shop_receipts(),
		"reading": bridge.capture_reading_checkpoint(false).value,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json")}
	assert_eq(str(proof.slot_sha256).length(), 64)
	if not _write_json("user://scene-apps-proof.json", proof): return
	_write_json("res://.godot/ci/scene-apps-create-proof.json", proof)

func load_apps_scene() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://scene-apps-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	# The controller opts in; only this fresh loader enables owner profiling.
	if OS.get_environment("DWM_APPS_COLD_LOAD_PROFILE") == "1":
		OS.set_environment("DWM_SAVE_LOAD_PROFILE", "1")
		OS.set_environment("DWM_SAVE_LOAD_CONTEXT", "scene-apps-cold-load")
		OS.set_environment("DWM_CHECKPOINT_PROFILE", "1")
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var load_started_us := Time.get_ticks_usec()
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	var prepared_us := Time.get_ticks_usec()
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	var committed_us := Time.get_ticks_usec()
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	var ready_us := Time.get_ticks_usec()
	var timing := {"prepare_us": prepared_us - load_started_us,
		"commit_us": committed_us - prepared_us, "ready_us": ready_us - committed_us,
		"total_us": ready_us - load_started_us, "process_id": OS.get_process_id(),
		"slot_sha256": proof.slot_sha256, "context": "scene-apps-cold-load"}
	print("DWM_APPS_COLD_LOAD " + JSON.stringify(timing))
	_write_json("res://.godot/ci/scene-apps-cold-load-timing.json", timing)
	assert_eq(game.money, proof.money)
	assert_eq(game.inventory, proof.inventory)
	assert_true(_shop_receipts().is_empty(), "Load preserves purchase effects without restoring live retry receipts.")
	for receipt: Dictionary in proof.shop_receipts.values():
		var purchase: Dictionary = receipt.scene_shop_purchase
		var stale: Dictionary = game.commit_scene_shop_purchase(purchase.purchase.item_id, purchase.purchase.quantity,
			receipt.transaction_id, purchase.issuer_receipt,
			{"identity": purchase.source_identity, "scene_occurrence": receipt.source_id})
		assert_false(stale.get("ok", false), "pre-Load purchase command cannot debit the restored branch")
		assert_eq(game.money, proof.money)
		assert_eq(game.inventory, proof.inventory)
	assert_eq(game.capture_dating_challenge_state().value, proof.record)
	var player_reading: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(proof.reading)
	if not _ok(player_reading): return
	var expected_reading: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(player_reading.value)
	if not _ok(expected_reading): return
	assert_eq(bridge.capture_reading_checkpoint(false).value, expected_reading.value,
		"Load restores the current reading state without saved traversal history")
	var host: Control = get_tree().current_scene
	await _click(_controls(host, "CheckComputer"))
	var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
	assert_eq(panel.public_view.board, proof.board)
	await _screenshot("apps-fresh-load-board")
	var shell: Control = await _open_apps(host)
	if shell == null: return
	if not await _launch_app(shell, &"shop"): return
	assert_eq(game.money, proof.money)
	assert_eq(game.inventory, proof.inventory)
	assert_true(_shop_receipts().is_empty(), "Opening Shop does not replay the purchase.")
	await _screenshot("apps-fresh-load-shop")
	proof["loader_process_id"] = OS.get_process_id()
	_write_json("res://.godot/ci/scene-apps-load-proof.json", proof)
