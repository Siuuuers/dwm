extends "res://tests/integration/scene_ordinary_day_child.gd"
## Two actual rendered rounds, a selected same-day Save, then a fresh-process
## settled-board Load and Supportz purchase. No day transition or ledger injection.
const SAME_DAY_PROOF := "user://same-day-supportz-proof.json"
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

func _install_content_registration() -> Dictionary:
	# Same-day behavior needs no daily-renewal metadata or abandonment policy.
	return CONTENT.new()._install_registration()

func create_same_day_supportz() -> void:
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
	var panel: Control = shell._cached_app_windows[&"minesweeper"].panel
	await _click(panel.register.difficulties["intermediate"])
	assert_eq(panel.public_view.register.difficulty, "intermediate")
	for ordinal: int in [1, 2]:
		if ordinal == 2: await _click(panel.dock.buttons.new_board)
		if not await _clear_ordinary(panel, ordinal): return
	assert_eq(game.minesweeper_rounds_left, 0)
	assert_gte(game.money, 45, "actual rewards fund Supportz")
	assert_eq(_ordinary_board().identity.app_round_ordinal, 2)
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	assert_true(shop._supportz_button.is_visible_in_tree())
	assert_false(shop._supportz_button.disabled)
	await _screenshot("same-day-supportz-eligible-before-save")
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	var before_save: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	assert_eq(typeof(before_save.desktop.board.board.board.outcome), TYPE_STRING_NAME,
		"real reducer retains its native enum before serialization")
	var before_encoded: Dictionary = WRITER.stringify(before_save)
	if not _ok(before_encoded): return
	if not await _save_slot(1): return
	var after_save: Dictionary = game.capture_run_snapshot_input()
	assert_eq(after_save, before_save, "manual Save never mutates board, receipts or gameplay")
	assert_eq(typeof(after_save.desktop.board.board.board.outcome), TYPE_STRING_NAME)
	var run: Dictionary = BOARD_STATE._inspection_normalize(after_save)
	var after_encoded: Dictionary = WRITER.stringify(run)
	if not _ok(after_encoded): return
	assert_eq(after_encoded.value.sha256_text(), before_encoded.value.sha256_text(),
		"producer normalization preserves canonical hashes")
	var slot: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(slot): return
	var saved_board: Dictionary = slot.value.current_snapshot.snapshot.desktop.board
	assert_eq(typeof(saved_board.board.board.outcome), TYPE_STRING)
	assert_eq(saved_board, run.desktop.board, "strict JSON slot preserves the complete settled board")
	assert_eq(run.desktop.consequence.shop_ledger.base_completion_receipts.size(), 2)
	assert_eq(run.desktop.consequence.shop_ledger.supportz_branch_purchase_count, 0)
	var proof := {"process_id": OS.get_process_id(), "run": run,
		"reading": bridge.capture_reading_checkpoint(false).value,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json")}
	if not _write_json(SAME_DAY_PROOF, proof): return
	_write_json("res://.godot/ci/same-day-supportz-create-proof.json", proof)

func load_same_day_supportz() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(SAME_DAY_PROOF))
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
	if not await _wait_line("scene.test.b", "line.scene.test.b.one"): return
	var restored: Dictionary = BOARD_STATE._inspection_normalize(game.capture_run_snapshot_input())
	assert_eq(restored.gameplay, proof.run.gameplay, "Load preserves rewards and daily completion count")
	assert_eq(restored.command_receipts, proof.run.command_receipts)
	assert_eq(restored.desktop.consequence.shop_ledger, proof.run.desktop.consequence.shop_ledger)
	assert_eq(restored.desktop.board.board, proof.run.desktop.board.board, "settled layout and history survive")
	assert_eq(restored.desktop.board.terminal_receipts, proof.run.desktop.board.terminal_receipts)
	assert_ne(restored.desktop.board.identity.branch_id, proof.run.desktop.board.identity.branch_id)
	assert_true(bootstrap._desktop_board_state.has_settled_inspection())
	assert_eq(bridge.capture_reading_checkpoint(false).value, proof.reading)
	var disk: Dictionary = saves._storage.read_text("autosave.json")
	var owner: Object = bootstrap._retained_minesweeper_round_coordinator_app
	var completions := _completion_receipts()
	assert_eq(completions.size(), 2)
	for receipt: Dictionary in completions.values():
		var saved: Dictionary = receipt.scene_round_completion
		var request := {"transaction_id": receipt.transaction_id, "transaction_issuer_receipt": saved.issuer_receipt,
			"expected_identity": saved.completion.board_identity, "expected_revision": saved.completion.revision}
		var retried: Dictionary = owner.complete_round(request)
		if not _ok(retried): return
		assert_true(retried.get("already_applied", false))
		assert_eq(BOARD_STATE._inspection_normalize(game.capture_run_snapshot_input()), restored)
		assert_eq(saves._storage.read_text("autosave.json"), disk, "historical retry makes no new checkpoint")
		request.expected_revision += 1
		assert_false(owner.complete_round(request).get("ok", false), "changed historical request conflicts")
	var host: Control = get_tree().current_scene
	var shell: Control = await _open_apps(host)
	if shell == null or not await _launch_app(shell, &"minesweeper"): return
	var panel: Control = shell._cached_app_windows[&"minesweeper"].panel
	assert_true(panel.public_view.settled)
	await _screenshot("same-day-fresh-load-settled-board")
	if not await _launch_app(shell, &"shop"): return
	var shop: Control = shell._cached_app_windows[&"shop"]
	assert_true(shop._supportz_button.is_visible_in_tree(), "same-day completed rounds remain eligible after Load")
	assert_false(shop._supportz_button.disabled)
	await _screenshot("same-day-fresh-load-supportz-eligible")
	var before_money: int = game.money
	await _click(shop._supportz_button)
	assert_not_null(shop._supportz_confirmation)
	if shop._supportz_confirmation == null: return
	await _click(shop._supportz_confirmation.confirm_button)
	assert_eq(game.money, before_money - 45)
	assert_eq(game.minesweeper_round_floor, -1)
	assert_eq(_completion_receipts(), completions, "purchase cannot replay completion")
	assert_eq(_shop_receipts().size(), 1)
	assert_false(shop._supportz_button.is_visible_in_tree())
	var after: Dictionary = game.capture_run_snapshot_input()
	assert_eq(after.desktop.consequence.shop_ledger.supportz_branch_purchase_count, 1)
	assert_eq(after.desktop.consequence.shop_ledger.supportz_last_purchase_causal_day_instance, after.lifecycle.causal_day_instance)
	assert_eq(after.gameplay.minesweeper_app_rounds_finished_today, 2)
	await _screenshot("same-day-fresh-load-supportz-purchased")
	_write_json("res://.godot/ci/same-day-supportz-load-proof.json", {"process_id": OS.get_process_id(),
		"creator_process_id": proof.process_id, "run": after, "reading": bridge.capture_reading_checkpoint(false).value})
