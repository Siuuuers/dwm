extends "res://tests/integration/verify_playable_startup.gd"
## Two processes: write, then read with --recovery-seed-root=<retained isolated user dir>.
## --recovery-case=completed|interrupted|day2|legacy; --recovery-phase=write|read.
## Only interrupted installs a FileOps fault. All actions use the real production app.
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const PROOF_PATH := "user://complete-action-proof.json"
var _recovery_phase := "write"
var _recovery_case := "completed"
var _seed_root := ""
var _sidecars_before: Dictionary = {}

class RejectCompletionWrite extends "res://scripts/infrastructure/storage/FileOps.gd":
	var rejected := 0
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if path.get_file() == "autosave.json.next":
			var parsed: Dictionary = STRICT.parse_object(bytes.get_string_from_utf8())
			if parsed.get("ok", false) and parsed.value.get("current_snapshot", {}).get("checkpoint_kind") == "post_result":
				rejected += 1
				return {"ok": false, "code": &"injected_completion_write_failure"}
		return super.write_bytes(path, bytes)

func _initialize() -> void:
	var destination := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	if not _check(not isolated.is_empty() and isolated.get_file() == "dwm_test_root" and destination.to_lower().begins_with(isolated.get_base_dir().path_join("appdata").to_lower() + "/"), "recovery probe requires isolated user data"): return
	var seen := {}
	for argument: String in OS.get_cmdline_user_args():
		for key: String in ["phase", "case", "seed-root"]:
			var prefix := "--recovery-" + key + "="
			if not argument.begins_with(prefix): continue
			if not _check(not seen.has(key), "duplicate recovery argument " + key): return
			seen[key] = true
			var value := argument.trim_prefix(prefix)
			match key:
				"phase": _recovery_phase = value
				"case": _recovery_case = value
				"seed-root": _seed_root = ProjectSettings.globalize_path(value).replace("\\", "/").simplify_path()
	if not _check(_recovery_phase in ["write", "read"] and _recovery_case in ["completed", "interrupted", "day2", "legacy"], "valid recovery phase and case"): return
	if not _seed_root.is_empty():
		var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests").replace("\\", "/").to_lower() + "/"
		var legacy_source := ProjectSettings.globalize_path("res://temp-artifacts/player-bugs-20260909/user-data-snapshot").replace("\\", "/").simplify_path().to_lower()
		var allowed_source := _seed_root.to_lower().begins_with(allowed) or _seed_root.to_lower() == legacy_source
		if not _check(allowed_source and _seed_root.to_lower() != destination.to_lower(), "seed must be retained isolated data or the explicit legacy snapshot"): return
		if not _copy_seed(_seed_root, destination): return
	_sidecars_before = _sidecar_hashes(destination.path_join("saves"))
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(120.0).timeout
	_check(false, "recovery probe exceeded its 120-second deadline")

func _copy_seed(source: String, destination: String) -> bool:
	var directory := DirAccess.open(source)
	if not _check(directory != null, "recovery seed exists"): return false
	if not _check(DirAccess.make_dir_recursive_absolute(destination) == OK, "recovery seed destination"): return false
	for folder: String in directory.get_directories():
		if folder in ["logs", "evidence"]: continue
		if not _copy_seed(source.path_join(folder), destination.path_join(folder)): return false
	for filename: String in directory.get_files():
		if not _check(DirAccess.copy_absolute(source.path_join(filename), destination.path_join(filename)) == OK, "copy isolated recovery artifact " + filename): return false
	return true

func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false), "recovery startup " + JSON.stringify(bootstrap.get_startup_state())): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	if not _check(current_scene != null and current_scene.has_node("%NewAccButton"), "recovery real title"): return
	if _recovery_phase == "read":
		if _recovery_case == "legacy":
			await _legacy_phase(bootstrap)
			return
		await _read_phase(bootstrap)
		return
	var menu: Node = current_scene
	menu.get_node("%NewAccButton").pressed.emit()
	var new_run_deadline := Time.get_ticks_msec() + 30000
	while is_instance_valid(menu) and menu._title_transition and Time.get_ticks_msec() < new_run_deadline:
		await process_frame
	if is_instance_valid(menu) and is_instance_valid(menu._confirmation):
		if not _check(not str(menu._new_acc_token).is_empty(), "New Account replacement prepared"): return
		menu._confirmation.confirm_button.pressed.emit()
	var game: Node = root.get_node("GameState")
	var manager: Node = root.get_node("SaveManager")
	var desktop: Node = null
	while Time.get_ticks_msec() < new_run_deadline:
		desktop = current_scene.find_child("ComputerDesktop", true, false) if current_scene != null else null
		if desktop != null and not manager._new_run_busy and game.capture_live_session().value.active: break
		await process_frame
	if not _check(desktop != null and game.capture_live_session().value.active, "recovery live desktop"): return
	if not _check(desktop.open_app(&"minesweeper").get("ok", false), "recovery open Minesweeper"): return
	await _frames()
	var app: Node = desktop._cached_app_windows[&"minesweeper"]
	var panel: Control = app.panel
	if not _check(panel.has_valid_presentation(), "recovery board ready"): return
	var first_started := Time.get_ticks_usec()
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	var first_us := Time.get_ticks_usec() - first_started
	if not _check(app.last_result.get("ok", false), "recovery first Reveal " + JSON.stringify(app.last_result)): return
	var prior := _snapshot(_autosave_text())
	if prior.is_empty(): return
	if not _check(game.minesweeper_app_rounds_finished_today == 0 and not bool(prior.desktop.board.board.board.terminal), "first Reveal saved a complete nonterminal action"): return
	var fault: RejectCompletionWrite = null
	if _recovery_case == "interrupted":
		fault = RejectCompletionWrite.new()
		root.get_node("SaveManager")._storage._file_ops = fault
	var physical: Dictionary = bootstrap._desktop_board_state.capture().board.board
	var mine_started := Time.get_ticks_usec()
	panel.worksheet.cell_action_requested.emit(&"reveal", int(physical.mine_indices[0]), int(panel.public_view.board.revision))
	var mine_us := Time.get_ticks_usec() - mine_started
	print("COMPLETE_ACTION_TIMING: " + JSON.stringify({"case": _recovery_case, "seeded": not _seed_root.is_empty(), "first_reveal_us": first_us, "mine_us": mine_us, "code": str(app.last_result.get("code", ""))}))
	if _recovery_case == "interrupted":
		if not _check(fault.rejected > 0 and not app.last_result.get("ok", false), "real completion write was rejected"): return
	else:
		if not _check(app.last_result.get("ok", false) and bool(panel.public_view.settled) and game.minesweeper_app_rounds_finished_today == 1, "mine reached fully settled result " + JSON.stringify(app.last_result)): return
		if _recovery_case == "day2" and not await _advance_day(desktop, game): return
	var saved_text := _autosave_text()
	var expected := _snapshot(saved_text)
	if expected.is_empty(): return
	if _recovery_case == "interrupted":
		# A new safe-marker ID is allowed only when it still captures the prior complete action.
		if not _check(CANON._deep_same(expected.gameplay, prior.gameplay) and CANON._deep_same(expected.desktop.board.board, prior.desktop.board.board) and expected.desktop.consequence.pending == null, "failed completion preserves the prior action; terminal-but-unsettled is insufficient"): return
	var proof := CANON.stringify({"case": _recovery_case, "autosave_text": saved_text, "snapshot": expected})
	if not _check(proof.get("ok", false), "recovery proof canonicalizes"): return
	var output := FileAccess.open(PROOF_PATH, FileAccess.WRITE)
	if not _check(output != null, "recovery proof opens"): return
	output.store_string(proof.value)
	output.flush()
	output.close()
	if not _verify_sidecars(): return
	# Immediate exit: no Logout/Return save can repair or conceal this boundary.
	print("COMPLETE_ACTION_WRITE_PASS: " + _recovery_case + " restart seed=" + ProjectSettings.globalize_path("user://"))
	quit(0)

func _advance_day(desktop: Node, game: Node) -> bool:
	if not _check(desktop.return_home().get("ok", false) and desktop.open_app(&"schedule").get("ok", false), "recovery Schedule opens"): return false
	await _frames()
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "recovery Done " + JSON.stringify(done)): return false
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		if not _check(ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss").get("ok", false), "recovery warning dismissal"): return false
	await _frames()
	return _check(game.day == 2 and game.minesweeper_rounds_left == 2 and game.minesweeper_app_rounds_finished_today == 0, "recovery saved Day2 reset")

func _autosave_text() -> String:
	var storage: Object = root.get_node("SaveManager")._storage
	return FileAccess.get_file_as_string(str(storage.describe_root()).path_join("autosave.json"))

func _snapshot(text: String) -> Dictionary:
	var parsed := STRICT.parse_object(text)
	if not _check(parsed.get("ok", false), "recovery Autosave strict JSON"): return {}
	var snapshot: Dictionary = parsed.value.get("current_snapshot", {}).get("snapshot", {})
	if not _check(not snapshot.is_empty(), "recovery complete snapshot exists"): return {}
	return snapshot

func _read_phase(bootstrap: Node) -> void:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(PROOF_PATH))
	if not _check(parsed.get("ok", false), "prior process recovery proof exists"): return
	var proof: Dictionary = parsed.value
	if not _check(proof.get("case") == _recovery_case and _autosave_text() == proof.autosave_text, "startup keeps the exact authoritative complete save"): return
	var expected: Dictionary = proof.snapshot
	var login: Button = current_scene.get_node("%LogInButton")
	if not _check(not login.disabled, "recovery Login enabled"): return
	login.pressed.emit()
	await _frames()
	var picker: Node = current_scene._backup_app_instance
	if not _check(picker != null and picker.is_visible_in_tree(), "recovery Login picker mounted"): return
	picker.drawer_buttons["autosave"].pressed.emit()
	if not _check(not picker.action_buttons["load"].disabled, "recovery Autosave Load enabled"): return
	picker.action_buttons["load"].pressed.emit()
	if is_instance_valid(picker.confirmation): picker.confirmation.confirm_button.pressed.emit()
	await _frames()
	var game: Node = root.get_node("GameState")
	if not _check(current_scene.find_child("ComputerDesktop", true, false) != null and game.capture_live_session().value.active, "recovery fresh session mounted"): return
	var restored: Dictionary = game.capture_run_snapshot_input()
	var expected_gameplay: Dictionary = expected.gameplay.duplicate(true)
	var routing: Dictionary = SNAPSHOT.derive_route_restore_context(expected)
	if not _check(routing.get("ok", false), "saved snapshot derives exact routing metadata"): return
	# SceneRouter merges precisely this projection over saved story context on Load.
	expected_gameplay.route_context.merge(routing.value, true)
	var gameplay_diff := {}
	for key: String in expected_gameplay:
		if not CANON._deep_same(restored.gameplay.get(key), expected_gameplay[key]):
			gameplay_diff[key] = {"saved": expected_gameplay[key], "restored": restored.gameplay.get(key)}
	if not _check(CANON._deep_same(restored.gameplay, expected_gameplay), "recovery preserves all saved gameplay values " + JSON.stringify(gameplay_diff)): return
	var board: Dictionary = bootstrap._desktop_board_state.capture()
	# Load remaps identity/receipt keys; the entire physical board wrapper stays exact.
	if not _check(CANON._deep_same(board.board, expected.desktop.board.board) and board.phase == expected.desktop.board.phase, "recovery preserves exact physical board, actions, paid receipt, and phase"): return
	if not _check(game.day == int(expected.lifecycle.day) and restored.desktop.consequence.pending == null, "recovery has no half-finished consequence"): return
	if _recovery_case == "interrupted":
		if not _check(not bool(board.board.board.terminal) and game.minesweeper_app_rounds_finished_today == 0, "interrupted action returns to prior playable board"): return
	elif _recovery_case == "completed":
		if not _check(bool(board.board.board.terminal) and game.minesweeper_app_rounds_finished_today == 1, "completed action restores exactly one settled outcome"): return
	else:
		if not _check(game.day == 2 and game.minesweeper_rounds_left == 2 and game.minesweeper_app_rounds_finished_today == 0, "Day2 restart retains reset"): return
	await _capture_screen("complete-action-recovered-" + _recovery_case)
	if not _verify_sidecars(): return
	print("COMPLETE_ACTION_RECOVERY_PASS: fresh process -> real Login -> " + _recovery_case)
	quit(0)

func _legacy_phase(bootstrap: Node) -> void:
	var source := _snapshot(_autosave_text())
	if source.is_empty(): return
	var login: Button = current_scene.get_node("%LogInButton")
	if not _check(not login.disabled, "legacy copied Login enabled"): return
	login.pressed.emit()
	await _frames()
	var picker: Node = current_scene._backup_app_instance
	if not _check(picker != null, "legacy real Login picker"): return
	picker.drawer_buttons["autosave"].pressed.emit()
	if not _check(not picker.action_buttons["load"].disabled, "legacy copied Autosave loadable"): return
	picker.action_buttons["load"].pressed.emit()
	if is_instance_valid(picker.confirmation): picker.confirmation.confirm_button.pressed.emit()
	await _frames()
	var game: Node = root.get_node("GameState")
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null and game.capture_live_session().value.active, "legacy Login mounts current-session desktop"): return
	var opened_at := Time.get_ticks_usec()
	if not _check(desktop.open_app(&"minesweeper").get("ok", false), "legacy actual Minesweeper opens"): return
	var opened_us := Time.get_ticks_usec() - opened_at
	await _frames()
	var app: Node = desktop._cached_app_windows[&"minesweeper"]
	var captured: Dictionary = bootstrap._desktop_board_state.capture()
	var terminal: bool = captured.board is Dictionary and bool(captured.board.board.terminal)
	print("LEGACY_ACTION_RECOVERY_STATE: " + JSON.stringify({"source_checkpoint": source.checkpoint_id, "open_settlement_us": opened_us, "source_phase": source.desktop.board.phase, "phase": captured.phase, "terminal": terminal, "settled": app.panel.public_view.get("settled", false), "finished": game.minesweeper_app_rounds_finished_today, "pending": game.capture_run_snapshot_input().desktop.consequence.pending != null}))
	if not _check(not terminal or (bool(app.panel.public_view.get("settled", false)) and game.minesweeper_app_rounds_finished_today > 0), "legacy save must not leave a terminal board without a settled outcome"): return
	if captured.board is Dictionary and not terminal:
		var count_before: int = game.minesweeper_app_rounds_finished_today
		app.panel.worksheet.cell_action_requested.emit(&"reveal", int(captured.board.board.mine_indices[0]), int(app.panel.public_view.board.revision))
		if not _check(app.last_result.get("ok", false) and bool(app.panel.public_view.settled) and game.minesweeper_app_rounds_finished_today == count_before + 1, "legacy restored board accepts and settles an actual action exactly once"): return
	await _capture_screen("complete-action-legacy-loaded")
	if not _verify_sidecars(): return
	print("COMPLETE_ACTION_LEGACY_PASS: copied production snapshot -> real Login -> playable settled boundary")
	quit(0)

func _sidecar_hashes(folder: String) -> Dictionary:
	var hashes := {}
	var directory := DirAccess.open(folder)
	if directory == null: return hashes
	for filename: String in directory.get_files():
		if filename.begins_with("desktop-consequence-checkpoint."):
			hashes[filename] = FileAccess.get_sha256(folder.path_join(filename))
	return hashes

func _verify_sidecars() -> bool:
	var folder: String = root.get_node("SaveManager")._storage.describe_root()
	var after := _sidecar_hashes(folder)
	print("COMPLETE_ACTION_LEGACY_SIDECARS: " + JSON.stringify(after))
	return _check(after == _sidecars_before, "legacy sidecars remain byte-identical through startup, action, and Load")
