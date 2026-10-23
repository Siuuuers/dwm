extends "res://tests/manual/benchmark_minesweeper_click_latency.gd"
## Isolated seven-day persistence stress. The game actions are real; line/manual history is an
## explicit synthetic checkpoint fixture, not a claim that unauthored dialogue was played.
## Write process: New Account, 7 line + 7 manual checkpoints and a real Slot 1 save per day,
## one physical App loss per day, public Schedule Done to Day 7. Read process: real Login.
## --history-phase=write|read; read additionally requires --user-data=<retained isolated user dir>.

const HISTORY_STRICT := preload("res://scripts/validation/StrictJson.gd")
const HISTORY_DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const HISTORY_SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const HISTORY_PROOF := "user://seven-day-history-proof.json"
const HISTORY_PER_DAY := 7

var _history_phase := "write"
var _history_days: Array[Dictionary] = []

func _initialize() -> void:
	var destination := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	if not _check(not isolated.is_empty() and isolated.get_file() == "dwm_test_root"
		and destination.to_lower().begins_with(isolated.get_base_dir().path_join("appdata").to_lower() + "/"),
		"history benchmark requires isolated user data"): return
	var phase_seen := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--history-phase="):
			if not _check(not phase_seen, "one history phase"): return
			phase_seen = true
			_history_phase = argument.trim_prefix("--history-phase=")
	var source := _user_data_option()
	if not _check(_history_phase in ["write", "read"], "valid history phase"): return
	if _history_phase == "write":
		if not _check(source.is_empty(), "write starts a fresh isolated account"): return
	else:
		var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").to_lower() + "/"
		if not _check(source != USER_DATA_INVALID and not source.is_empty()
			and source.replace("\\", "/").simplify_path().to_lower().begins_with(allowed),
			"read requires a retained isolated source"): return
	super()
	_history_watchdog.call_deferred()

func _history_watchdog() -> void:
	await create_timer(600.0).timeout
	_check(false, "history benchmark exceeded ten minutes")

func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	var game: Node = root.get_node("GameState")
	var manager: Node = root.get_node("SaveManager")
	if not _check(bootstrap.get_startup_state().get("ready", false), "history startup"): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	if _history_phase == "read":
		await _history_read(bootstrap, game, manager)
		return
	var menu: Node = current_scene
	menu.get_node("%NewAccButton").pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if not manager._new_run_busy and game.capture_live_session().value.active \
			and current_scene != null and current_scene.find_child("ComputerDesktop", true, false) != null: break
		await process_frame
	if not _check(game.capture_live_session().value.active, "history New Account completed"): return
	# Leave optional Contacts replies unanswered. A chosen reply creates a mandatory Day 7
	# rendered echo, which the separate rendered journey verifies; this headless probe cannot
	# truthfully acknowledge that presentation. Localized payloads have their own matched probe.
	for expected_day: int in range(1, 8):
		if not _check(game.day == expected_day, "history expected day %d" % expected_day): return
		var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
		if not _check(desktop != null, "history desktop exists"): return
		var row := {"day": expected_day}
		if not await _history_fill(manager, desktop, row): return
		if not await _history_round(bootstrap, game, desktop, row): return
		var document := _history_document(manager)
		if document.is_empty(): return
		var expected_counts := {"line": mini(expected_day * HISTORY_PER_DAY, 32),
			"manual_save": mini(expected_day * (HISTORY_PER_DAY + 1), 32), "semantic": 2}
		if not _check(_history_counts(document.recovery_journal) == expected_counts,
			"exact unchanged journal retention on day %d: %s" % [expected_day, JSON.stringify(_history_counts(document.recovery_journal))]): return
		row["retained"] = expected_counts
		row["files"] = _history_file_sizes(ProjectSettings.globalize_path("user://"))
		row["autosave_sha256"] = _history_autosave(manager).sha256_text()
		_history_days.append(row)
		print("SEVEN_DAY_HISTORY_DAY: " + JSON.stringify(row))
		if expected_day < 7 and not await _history_advance(desktop, game, expected_day + 1): return
	var final_document := _history_document(manager)
	if final_document.is_empty(): return
	var proof := {"autosave_sha256": _history_autosave(manager).sha256_text(),
		"snapshot": final_document.current_snapshot.snapshot,
		"retained": _history_counts(final_document.recovery_journal), "days": _history_days,
		"fixture": "Seven synthetic line and seven synthetic manual checkpoint records per day; one real Slot 1 save and App loss per day. No authored dialogue playthrough."}
	var emitted := CANONICAL_JSON.stringify(proof)
	if not _check(emitted.get("ok", false), "history proof canonicalizes"): return
	var output := FileAccess.open(HISTORY_PROOF, FileAccess.WRITE)
	if not _check(output != null, "history proof opens"): return
	output.store_string(emitted.value)
	output.flush()
	output.close()
	print("SEVEN_DAY_HISTORY_WRITE_PASS: " + JSON.stringify({"days": 7, "retained": proof.retained,
		"autosave_sha256": proof.autosave_sha256, "synthetic_checkpoints": 98}))
	quit(0)

func _history_fill(manager: Node, desktop: Node, row: Dictionary) -> bool:
	if not _check(desktop.open_app(&"backup").get("ok", false), "history Backup opens"): return false
	await _frames()
	var samples := {"line": [], "manual_save": []}
	for kind: String in ["line", "manual_save"]:
		for index: int in HISTORY_PER_DAY:
			var captured: Dictionary = manager._capture_backup_inputs()
			if not _check(captured.get("ok", false), "production live backup capture"): return false
			var started := Time.get_ticks_usec()
			var recorded: Dictionary = manager.record_stable_checkpoint(captured.value, StringName(kind))
			samples[kind].append(Time.get_ticks_usec() - started)
			if not _check(recorded.get("ok", false), "synthetic " + kind + " record: " + JSON.stringify(recorded)): return false
			await process_frame
	row["synthetic_checkpoint_us"] = samples
	var previous_profile_context := OS.get_environment("DWM_SAVE_LOAD_CONTEXT")
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", "day%d-manual-slot-save" % int(row["day"]))
	var save_started := Time.get_ticks_usec()
	var prepared: Dictionary = manager.prepare_backup_action("save", "slot:1")
	row["manual_slot_prepare_us"] = Time.get_ticks_usec() - save_started
	if not _check(prepared.get("ok", false), "real Slot 1 prepares: " + JSON.stringify(prepared)): return false
	var commit_started := Time.get_ticks_usec()
	var saved: Dictionary = manager.commit_backup_action(str(prepared.value.token))
	row["manual_slot_commit_us"] = Time.get_ticks_usec() - commit_started
	row["manual_slot_save_us"] = Time.get_ticks_usec() - save_started
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", previous_profile_context)
	if not _check(saved.get("ok", false), "real Slot 1 commits: " + JSON.stringify(saved)): return false
	return _check(desktop.return_home().get("ok", false), "Home after history save")

func _history_round(bootstrap: Node, game: Node, desktop: Node, row: Dictionary) -> bool:
	if not _check(desktop.open_app(&"minesweeper").get("ok", false), "history Minesweeper opens"): return false
	await _frames()
	var app: Node = desktop._cached_app_windows[&"minesweeper"]
	var panel: Control = app.panel
	if not _check(panel.has_valid_presentation(), "history board ready"): return false
	if panel.public_view.settled:
		panel.dock.action_requested.emit(&"new_board")
		await _frames()
	var before: int = game.minesweeper_app_rounds_finished_today
	var started := Time.get_ticks_usec()
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	row["first_reveal_sync_us"] = Time.get_ticks_usec() - started
	if not _check(app.last_result.get("ok", false), "history first reveal"): return false
	await _frames()
	var physical: Dictionary = bootstrap._desktop_board_state.capture().board.board
	if not _check(not physical.terminal, "history first click remains nonterminal"): return false
	started = Time.get_ticks_usec()
	panel.worksheet.cell_action_requested.emit(&"reveal", int(physical.mine_indices[0]), int(panel.public_view.board.revision))
	row["terminal_reveal_sync_us"] = Time.get_ticks_usec() - started
	if not _check(app.last_result.get("ok", false), "history terminal reveal"): return false
	if not await _wait_app_round_settled(game, app, before): return false
	row["terminal_settlement_us"] = Time.get_ticks_usec() - started
	return _check(game.minesweeper_app_rounds_finished_today == 1
		and game.capture_run_snapshot_input().desktop.consequence.pending == null,
		"one complete App outcome per day with no pending consequence")

func _history_advance(desktop: Node, game: Node, expected_day: int) -> bool:
	if not _check(desktop.return_home().get("ok", false) and desktop.open_app(&"schedule").get("ok", false), "history Schedule opens"): return false
	await _frames()
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "history Done: " + JSON.stringify(done)): return false
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		if not _check(ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss").get("ok", false), "history warning dismissed"): return false
	await _frames()
	return _check(game.day == expected_day, "history advances to day %d" % expected_day)

func _history_read(bootstrap: Node, game: Node, manager: Node) -> void:
	var parsed := HISTORY_STRICT.parse_object(FileAccess.get_file_as_string(HISTORY_PROOF))
	if not _check(parsed.get("ok", false), "history prior-process proof exists"): return
	var proof: Dictionary = parsed.value
	if not _check(_history_autosave(manager).sha256_text() == proof.autosave_sha256, "cold startup preserves exact Autosave bytes"): return
	var loaded_document := _history_document(manager)
	if loaded_document.is_empty(): return
	if not _check(_history_counts(loaded_document.recovery_journal) == proof.retained, "cold disk retains all history budgets"): return
	var previous_profile_context := OS.get_environment("DWM_SAVE_LOAD_CONTEXT")
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", "day7-title-login")
	var started := Time.get_ticks_usec()
	if not await _title_login(current_scene): return
	var elapsed := Time.get_ticks_usec() - started
	OS.set_environment("DWM_SAVE_LOAD_CONTEXT", previous_profile_context)
	if not _check(game.capture_live_session().value.active and game.day == 7, "history Login restores Day 7"): return
	var expected: Dictionary = proof.snapshot
	var routing := HISTORY_SNAPSHOT.derive_route_restore_context(expected)
	if not _check(routing.get("ok", false), "history route restore context"): return
	var gameplay: Dictionary = expected.gameplay.duplicate(true)
	gameplay.route_context.merge(routing.value, true)
	var restored: Dictionary = game.capture_run_snapshot_input()
	if not _check(CANONICAL_JSON._deep_same(restored.gameplay, gameplay), "cold history restore preserves all gameplay"): return
	var board: Dictionary = bootstrap._desktop_board_state.capture()
	if not _check(CANONICAL_JSON._deep_same(board.board, expected.desktop.board.board)
		and board.phase == expected.desktop.board.phase and restored.desktop.consequence.pending == null,
		"cold history restore preserves exact physical board and complete outcome"): return
	var retained: Array = manager._journal.get_bundles_for_disk()
	if not _check(retained.size() == 66 and retained.size() == loaded_document.recovery_journal.size(),
		"cold Login restores all 66 retained checkpoints"): return
	for index: int in retained.size():
		if not _check(CANONICAL_JSON._deep_same(retained[index], loaded_document.recovery_journal[index]),
			"cold Login retains exact checkpoint %d" % index): return
	print("SEVEN_DAY_HISTORY_READ_PASS: " + JSON.stringify({"day": game.day,
		"login_us": elapsed, "retained": proof.retained, "autosave_sha256": proof.autosave_sha256,
		"save_manager_sha256": FileAccess.get_sha256("res://autoload/SaveManager.gd"),
		"retained_checkpoint_count": retained.size(),
		"restored_recovery_journal_sha256": str(CANONICAL_JSON.stringify(retained).value).sha256_text(),
		"parse_cache_enabled": OS.get_environment("DWM_SAVE_PARSE_CACHE_DISABLED") != "1",
		"restored_gameplay_sha256": str(CANONICAL_JSON.stringify(restored.gameplay).value).sha256_text(),
		"restored_board_sha256": str(CANONICAL_JSON.stringify(board.board).value).sha256_text()}))
	quit(0)

func _history_autosave(manager: Node) -> String:
	return FileAccess.get_file_as_string(str(manager._storage.describe_root()).path_join("autosave.json"))

func _history_document(manager: Node) -> Dictionary:
	var parsed := HISTORY_STRICT.parse_object(_history_autosave(manager))
	if not _check(parsed.get("ok", false), "history Autosave strict parse"): return {}
	var validated := HISTORY_DOCUMENT.validate(parsed.value)
	if not _check(validated.get("ok", false), "history Autosave schema: " + JSON.stringify(validated.get("code", ""))): return {}
	return validated.value.candidate

func _history_counts(bundles: Array) -> Dictionary:
	var counts := {"line": 0, "manual_save": 0, "semantic": 0}
	for bundle: Dictionary in bundles:
		var kind := str(bundle.checkpoint_kind)
		counts[kind if kind in ["line", "manual_save"] else "semantic"] += 1
	return counts

func _history_file_sizes(folder: String, prefix: String = "") -> Dictionary:
	var result := {}
	var directory := DirAccess.open(folder)
	if directory == null: return result
	for filename: String in directory.get_files():
		if filename.ends_with(".json"):
			var file := FileAccess.open(folder.path_join(filename), FileAccess.READ)
			if file != null: result[prefix + filename] = file.get_length()
	for child: String in directory.get_directories():
		if child in ["logs", "evidence"]: continue
		result.merge(_history_file_sizes(folder.path_join(child), prefix + child + "/"))
	return result
