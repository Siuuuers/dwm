extends "res://tests/integration/scene_apps_connected_child.gd"
## Real rendered cells/Shop/Next and FINAL owners. Only authored registration and
## solver knowledge of the generated mine layout are TEST; no money/ledger injection.
const ORDINARY_DAYS := preload("res://tests/support/SceneOrdinaryDayRegistrationFixture.gd")

func _install_content_registration() -> Dictionary:
	return ORDINARY_DAYS.new()._install_registration()

func _ordinary_board() -> Dictionary:
	return game.capture_run_snapshot_input().desktop.board

func _completion_receipts() -> Dictionary:
	var result := {}
	for key: String in game.capture_run_snapshot_input().command_receipts:
		var receipt: Dictionary = game.capture_run_snapshot_input().command_receipts[key]
		if receipt.get("kind") == "scene_round_completion": result[key] = receipt.duplicate(true)
	return result

func _wait_active_board() -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		if _ordinary_board().phase == "ACTIVE_VISIBLE":
			for frame: int in 3: await get_tree().process_frame
			return true
		await get_tree().process_frame
	return _ok({"ok": false, "code": "TEST.ordinary_board_timeout", "board": _ordinary_board()})

func _begin_ordinary(panel: Control) -> bool:
	var cell: int = panel.worksheet.grid.cell_nodes.size() - 1
	assert_gte(cell, 0)
	if cell < 0: return false
	assert_true(panel.worksheet.grid.focus_cell(cell))
	await get_tree().process_frame
	await _click(panel.worksheet.grid.cell_nodes[cell])
	return await _wait_active_board()

func _clear_ordinary(panel: Control, ordinal: int) -> bool:
	if not await _begin_ordinary(panel): return false
	for step: int in 484:
		var current: Dictionary = _ordinary_board()
		var board: Dictionary = current.board.board
		if board.terminal: break
		var next := -1
		for index: int in panel.public_view.board.cells.size():
			if not board.mine_indices.has(index) and "reveal" in panel.public_view.board.cells[index].actions:
				if next < 0: next = index
				if board.adjacency_counts[index] == 0:
					next = index
					break
		assert_gte(next, 0, "Generated board has an unrevealed safe cell.")
		if next < 0: return false
		assert_true(panel.worksheet.grid.focus_cell(next))
		await get_tree().process_frame
		await _click(panel.worksheet.grid.cell_nodes[next])
	var deadline := Time.get_ticks_msec() + 20000
	while game.minesweeper_app_rounds_finished_today != ordinal and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_eq(game.minesweeper_app_rounds_finished_today, ordinal)
	assert_eq(_completion_receipts().size(), ordinal)
	assert_true(_ordinary_board().board.board.terminal)
	assert_eq(_ordinary_board().board.board.outcome, "cleared")
	assert_true(panel.public_view.settled)
	await _screenshot("ordinary-round-%d-complete" % ordinal)
	return game.minesweeper_app_rounds_finished_today == ordinal

func create_ordinary_day() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var started: Dictionary = saves.start_scene_new_run("target_b", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.b", "line.scene.test.b.one"): return
	var host: Control = get_tree().current_scene
	var shell: Control = await _open_apps(host)
	if shell == null or not await _launch_app(shell, &"minesweeper"): return
	var app: Control = shell._cached_app_windows[&"minesweeper"]
	var panel: Control = app.panel
	await _click(panel.register.difficulties["intermediate"])
	assert_eq(panel.public_view.register.difficulty, "intermediate")
	for ordinal: int in [1, 2]:
		if ordinal == 2:
			await _click(panel.dock.buttons.new_board)
		if not await _clear_ordinary(panel, ordinal): return
	assert_eq(game.minesweeper_rounds_left, 0)
	assert_gte(game.money, 45, "Two genuine intermediate clears fund Supportz.")
	var earned: int = game.minesweeper_money_earned_today
	assert_gt(earned, 0)
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	assert_true(shop._supportz_button.is_visible_in_tree())
	assert_false(shop._supportz_button.disabled)
	var before_money: int = game.money
	await _click(shop._supportz_button)
	assert_not_null(shop._supportz_confirmation)
	if shop._supportz_confirmation == null: return
	await _screenshot("ordinary-supportz-confirmation")
	await _click(shop._supportz_confirmation.confirm_button)
	assert_eq(game.money, before_money - 45)
	assert_eq(game.minesweeper_round_floor, -1)
	assert_eq(_shop_receipts().size(), 1)
	assert_false(shop._supportz_button.is_visible_in_tree())
	await _screenshot("ordinary-supportz-purchased")
	if not await _launch_app(shell, &"minesweeper"): return
	app = shell._cached_app_windows[&"minesweeper"]
	panel = app.panel
	await _click(panel.dock.buttons.new_board)
	if not await _begin_ordinary(panel): return
	assert_false(_ordinary_board().board.board.terminal)
	assert_eq(game.minesweeper_rounds_left, -1)
	var unfinished: Dictionary = _ordinary_board().duplicate(true)
	var old_day: String = game.capture_run_snapshot_input().lifecycle.causal_day_instance
	var persistent: Dictionary = game.capture_run_snapshot_input().gameplay.duplicate(true)
	await _screenshot("ordinary-third-unfinished")
	await _click(_controls(host, "CheckComputer"))
	var suspended: Dictionary = _ordinary_board().duplicate(true)
	assert_eq(suspended.phase, "ACTIVE_SUSPENDED", "Closing Computer suspends the unfinished board.")
	assert_eq(suspended.board, unfinished.board, "Closing Computer preserves unfinished board progress.")
	assert_eq(suspended.identity, unfinished.identity, "Closing Computer preserves the same round identity.")
	await _click(_caption().caption_text)
	if not await _wait_line("scene.test.b", "line.scene.test.b.two"): return
	assert_eq(_ordinary_board(), suspended, "An intra-day caption does not renew or abandon.")
	await _click(_caption().caption_text)
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	var renewed: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_ne(renewed.lifecycle.causal_day_instance, old_day)
	assert_eq(renewed.desktop.consequence.causal_day_instance, renewed.lifecycle.causal_day_instance)
	assert_eq(renewed.desktop.board.phase, "NONE")
	assert_null(renewed.desktop.board.board)
	assert_null(renewed.desktop.board.identity)
	assert_eq(game.minesweeper_rounds_left, 2)
	assert_eq(game.minesweeper_app_rounds_finished_today, 0)
	assert_eq(game.minesweeper_money_earned_today, 0)
	assert_eq(game.minesweeper_round_floor, -1)
	for key: String in ["money", "coins", "stats", "minesweeper_task_rewards_claimed"]:
		assert_eq(renewed.gameplay[key], persistent[key], "Abandonment has no completion consequence: " + key)
	assert_eq(_completion_receipts().size(), 2)
	assert_eq(renewed.desktop.consequence.shop_ledger.supportz_branch_purchase_count, 1)
	assert_eq(renewed.desktop.consequence.shop_ledger.supportz_last_purchase_causal_day_instance, old_day)
	await _screenshot("ordinary-day2-renewed")
	if not await _save_slot(1): return
	var proof := {"process_id": OS.get_process_id(), "gameplay": renewed.gameplay,
		"completion_receipts": _completion_receipts(), "shop_receipts": _shop_receipts(),
		"old_day": old_day, "current_day": renewed.lifecycle.causal_day_instance,
		"shop_ledger": renewed.desktop.consequence.shop_ledger,
		"reading": bridge.capture_reading_checkpoint(false).value,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json")}
	assert_eq(str(proof.slot_sha256).length(), 64)
	if not _write_json("user://ordinary-day-proof.json", proof): return
	_write_json("res://.godot/ci/ordinary-day-create-proof.json", proof)

func load_ordinary_day() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://ordinary-day-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	var restored: Dictionary = game.capture_run_snapshot_input()
	assert_eq(restored.gameplay, proof.gameplay)
	assert_true(_completion_receipts().is_empty(), "Load starts a fresh app-round command session")
	assert_true(_shop_receipts().is_empty(), "Load starts a fresh shop command session")
	assert_eq(restored.desktop.consequence.shop_ledger, proof.shop_ledger)
	assert_eq(restored.desktop.board.phase, "NONE")
	assert_null(restored.desktop.board.board)
	assert_eq(bridge.capture_reading_checkpoint(false).value, proof.reading)
	var host: Control = get_tree().current_scene
	var shell: Control = await _open_apps(host)
	if shell == null or not await _launch_app(shell, &"minesweeper"): return
	var app: Control = shell._cached_app_windows[&"minesweeper"]
	assert_eq(app.panel.public_view.register.rounds, 2)
	assert_false(app.panel.public_view.board.terminal)
	await _screenshot("ordinary-fresh-load-new-board")
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	assert_false(shop._supportz_button.is_visible_in_tree(), "New day needs its own two completed base rounds.")
	assert_true(_completion_receipts().is_empty(), "Opening apps cannot replay settlement.")
	await _screenshot("ordinary-fresh-load-shop")
	proof["loader_process_id"] = OS.get_process_id()
	_write_json("res://.godot/ci/ordinary-day-load-proof.json", proof)
