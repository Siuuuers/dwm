extends "res://tests/integration/verify_playable_startup.gd"
## Click-latency benchmark for the desktop Minesweeper app and the Dating Challenge board.
##
## Runs the real production app on a fresh account inside the isolated runner, then times the
## synchronous cost of each board command exactly as a click would pay it (the worksheet signal
## through panel, port, coordinator, storage and back to the grid), plus the wall time until two
## frames later so deferred work still counts. Prints one `CLICK_LATENCY:` JSON line per command
## and a `CLICK_LATENCY_SUMMARY:` line per label. Timings are observations on this machine, not
## frame-time guarantees; the harness asserts nothing about speed.
##
## `--dating-ending=win` (default) plays the Dating board to its solving cell and then the
## terminal choice; `--dating-ending=loss` reveals a mine after the routine sample (dwm-634.2).
## `--reply-locale=en|zh-CN|zh-HK` first persists the registered Day-1 Lavinia A reply through the
## production command port, so App terminal/save measurements include that real localized receipt.
## `--user-data=<absolute directory>` seeds the isolated `user://` root from that directory before
## the bootstrap runs, enters through the title's real Log In and loads the existing autosave, then
## runs the same App benchmark on that long history; the dating benchmark is skipped and an
## unplayable loaded run prints `CLICK_LATENCY_UNPLAYABLE:` and exits 0 (dwm-634.3).

const ROUTINE_LOG_LIMIT := 12
const ORDINARY_REPLY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const REPLY_LOCALES: Array[String] = ["en", "zh-CN", "zh-HK"]
const INITIAL_REPLY_ID := "reply.ordinary.lavinia.day1.a"
const USER_DATA_INVALID := "<invalid>"
var _samples: Dictionary = {}


func _dating_ending() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--dating-ending="):
			return argument.trim_prefix("--dating-ending=")
	return "win"


func _reply_locale_option() -> Dictionary:
	var selected := ""
	var present := false
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--reply-locale="): continue
		if present: return {"ok": false, "value": argument.trim_prefix("--reply-locale=")}
		selected = argument.trim_prefix("--reply-locale=")
		present = true
	return {"ok": not present or selected in REPLY_LOCALES, "value": selected}


## The single `--user-data=` value; empty when absent, USER_DATA_INVALID when repeated or empty.
func _user_data_option() -> String:
	var selected := ""
	var count := 0
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--user-data="): continue
		selected = argument.trim_prefix("--user-data=")
		count += 1
	if count == 0: return ""
	if count > 1 or selected.is_empty(): return USER_DATA_INVALID
	return selected


## Seeds `user://` synchronously before the parent defers `_run`; ApplicationBootstrap only
## `call_deferred`s its start from `_ready`, so the copy lands before any bootstrap stage reads.
func _initialize() -> void:
	var source := _user_data_option()
	if not source.is_empty() and source != USER_DATA_INVALID and not _seed_user_data(source):
		quit(1)
		return
	super()


func _seed_user_data(source: String) -> bool:
	var origin := source.simplify_path()
	var target := ProjectSettings.globalize_path("user://").simplify_path()
	if not DirAccess.dir_exists_absolute(origin): return _seed_fail("source directory missing: " + origin)
	if origin == target: return _seed_fail("source equals the isolated user directory: " + target)
	if DirAccess.dir_exists_absolute(target.path_join("saves")): return _seed_fail("isolated user directory already holds saves: " + target)
	if DirAccess.make_dir_recursive_absolute(target) != OK: return _seed_fail("cannot create target: " + target)
	var counts := {"files": 0, "bytes": 0}
	var detail := _copy_tree(origin, target, counts)
	if not detail.is_empty(): return _seed_fail(detail)
	print("CLICK_LATENCY_SEED: " + JSON.stringify({"source": origin, "target": target, "files": counts.files, "bytes": counts.bytes}))
	return true


func _seed_fail(detail: String) -> bool:
	printerr("CLICK_LATENCY_SEED_FAIL: " + detail)
	return false


## Copies every file and subdirectory of `from` into `to`; returns an empty String or the first error.
func _copy_tree(from: String, to: String, counts: Dictionary) -> String:
	var dir := DirAccess.open(from)
	if dir == null: return "cannot open %s: %s" % [from, error_string(DirAccess.get_open_error())]
	dir.include_hidden = true
	if dir.list_dir_begin() != OK: return "cannot list " + from
	var name := dir.get_next()
	while not name.is_empty():
		var source_path := from.path_join(name)
		var target_path := to.path_join(name)
		if dir.current_is_dir():
			if DirAccess.make_dir_recursive_absolute(target_path) != OK: return "cannot create " + target_path
			var nested := _copy_tree(source_path, target_path, counts)
			if not nested.is_empty(): return nested
		else:
			var copied := DirAccess.copy_absolute(source_path, target_path)
			if copied != OK: return "copy %s failed: %s" % [source_path, error_string(copied)]
			var file := FileAccess.open(target_path, FileAccess.READ)
			if file == null: return "cannot read back " + target_path
			counts.files += 1
			counts.bytes += file.get_length()
		name = dir.get_next()
	dir.list_dir_end()
	return ""


func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false), "benchmark startup " + JSON.stringify(bootstrap.get_startup_state())): return
	var user_data := _user_data_option()
	if not _check(user_data != USER_DATA_INVALID, "--user-data must occur exactly once with a non-empty directory"): return
	var seeded := not user_data.is_empty()
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	var menu: Node = current_scene
	# A seeded long-history login has measured 21-32 s on a loaded shared machine (session 5), so
	# the seeded journey gets a wider deadline; the fresh-account deadline is unchanged.
	var deadline := Time.get_ticks_msec() + (120000 if seeded else 30000)
	var login_started := Time.get_ticks_usec()
	if seeded:
		if not await _title_login(menu): return
	else:
		menu.get_node("%NewAccButton").pressed.emit()
		while is_instance_valid(menu) and menu._title_transition and Time.get_ticks_msec() < deadline: await process_frame
		if is_instance_valid(menu) and is_instance_valid(menu._confirmation): menu._confirmation.confirm_button.pressed.emit()
	var game: Node = root.get_node("GameState")
	var manager: Node = root.get_node("SaveManager")
	var desktop: Node
	while Time.get_ticks_msec() < deadline:
		desktop = current_scene.find_child("ComputerDesktop", true, false) if current_scene != null else null
		if desktop != null and not manager._new_run_busy and game.capture_live_session().value.active: break
		await process_frame
	if seeded:
		print("CLICK_LATENCY_LOGIN: " + JSON.stringify({"elapsed_us": Time.get_ticks_usec() - login_started}))
		if desktop == null:
			_unplayable("desktop_not_mounted_after_load", {"session_active": game.capture_live_session().value.active,
				"day": game.day, "scene": current_scene.name if current_scene != null else ""})
			return
	if not _check(desktop != null, "benchmark desktop ready"): return
	var reply_option := _reply_locale_option()
	if not _check(reply_option.ok, "--reply-locale must occur at most once and be en, zh-CN or zh-HK"): return
	if not str(reply_option.value).is_empty() \
			and not _persist_initial_ordinary_reply(bootstrap, game, manager, str(reply_option.value)):
		return
	if seeded and not await _seeded_board_playable(game, desktop): return
	if not await _minesweeper_app_benchmark(bootstrap, desktop): return
	if seeded: print("CLICK_LATENCY_NOTE: dating benchmark skipped in --user-data mode")
	elif not await _dating_benchmark(game, desktop): return
	_print_summary()
	print("CLICK_LATENCY_PASS: issuer_root_bytes=%d" % _issuer_root_bytes())
	print("CLICK_LATENCY_MODE: " + JSON.stringify({"mode": "user-data" if seeded else "fresh-account", "user_data": user_data}))
	quit(0)


## Loads the seeded autosave through the title's real Log In and Backup picker; the button sequence
## and waits mirror the parent's `_completed_load_journey`. `last_result` read right after the
## confirmation is the prepare result (the commit lands after an await), so commit success is judged
## by the desktop wait in `_run`.
func _title_login(menu: Node) -> bool:
	var login: Button = menu.get_node("%LogInButton")
	if not _check(not login.disabled, "seeded Log In is enabled"): return false
	login.pressed.emit()
	await _frames()
	var picker: Node = menu.get("_backup_app_instance")
	if not _check(picker != null and picker.is_visible_in_tree(), "seeded Log In opens the real Backup picker"): return false
	picker.drawer_buttons["autosave"].pressed.emit()
	if not _check(not picker.action_buttons["load"].disabled, "seeded autosave Load enabled: " + JSON.stringify(picker.last_result)): return false
	picker.action_buttons["load"].pressed.emit()
	if is_instance_valid(picker.confirmation): picker.confirmation.confirm_button.pressed.emit()
	var loaded: Dictionary = picker.last_result.duplicate(true)
	await _frames()
	return _check(loaded.get("ok", false), "seeded autosave Load prepared: " + JSON.stringify(loaded))


## Honest playability probe for a loaded run: the App must open and show a valid, unsettled board
## with the two rounds the win-then-loss benchmark spends. Leaves the App open for the benchmark.
func _seeded_board_playable(game: Node, desktop: Node) -> bool:
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	var state := {"open": opened, "day": game.day, "rounds_left": game.minesweeper_rounds_left,
		"rounds_finished_today": game.minesweeper_app_rounds_finished_today}
	if not opened.get("ok", false):
		_unplayable("minesweeper_app_does_not_open", state)
		return false
	await _frames()
	var panel: Control = desktop._cached_app_windows[&"minesweeper"].panel
	state["presentation_valid"] = panel.has_valid_presentation()
	if not panel.has_valid_presentation():
		_unplayable("minesweeper_presentation_invalid", state)
		return false
	state["settled"] = panel.public_view.settled
	state["actions"] = panel.public_view.actions
	state["difficulty_enabled"] = panel.public_view.register.difficulty_enabled
	state["board_terminal"] = panel.public_view.board.get("terminal", false)
	state["board_custody"] = panel.public_view.board.get("custody", false)
	if bool(panel.public_view.settled):
		_unplayable("board_already_settled", state)
		return false
	if (panel.public_view.register.difficulty_enabled as Array).is_empty():
		_unplayable("no_difficulty_enabled", state)
		return false
	if int(game.minesweeper_rounds_left) < 2:
		_unplayable("fewer_than_two_rounds_left", state)
		return false
	return true


## Prints the unplayable verdict and whatever was measured, then exits 0: a loaded run that cannot
## play is an observation, never a check failure.
func _unplayable(reason: String, state: Dictionary) -> void:
	print("CLICK_LATENCY_UNPLAYABLE: " + JSON.stringify({"reason": reason, "state": state}))
	_print_summary()
	print("CLICK_LATENCY_MODE: " + JSON.stringify({"mode": "user-data", "user_data": _user_data_option(), "playable": false}))
	quit(0)


func _persist_initial_ordinary_reply(bootstrap: Node, game: Node, manager: Node, locale: String) -> bool:
	var command_port: Object = bootstrap.get("_contact_command_port")
	if not _check(command_port != null and command_port.has_method("prepare_ordinary_reply") \
			and command_port.has_method("acknowledge_ordinary_reply"), "production ordinary reply port available"): return false
	var authored: Dictionary = ORDINARY_REPLY.reply_definition(INITIAL_REPLY_ID, locale)
	if not _check(authored.get("ok", false), "authored ordinary reply resolves for " + locale): return false
	var prepared: Dictionary = command_port.prepare_ordinary_reply("lavinia", INITIAL_REPLY_ID, locale)
	if not _check(prepared.get("ok", false), "ordinary reply prepares: " + JSON.stringify(prepared)): return false
	var command: Dictionary = prepared.get("value", {}).get("command", {})
	if not _check(command.get("rendered_line", {}).get("text") == authored.value.text,
			"prepared reply carries the authored localized text"): return false
	var committed: Dictionary = command_port.acknowledge_ordinary_reply(command, command.rendered_line)
	if not _check(committed.get("ok", false), "ordinary reply persists: " + JSON.stringify(committed)): return false
	var receipt: Dictionary = game.contacts.get("transaction_receipts", {}).get(command.command_id, {})
	if not _check(receipt.get("kind") == "ordinary_reply" and receipt.get("locale") == locale \
			and receipt.get("reply_id") == INITIAL_REPLY_ID and receipt.get("rendered_line") == command.rendered_line \
			and receipt.get("plain_text_snapshot") == authored.value.text,
			"live Contacts retains the exact localized ordinary receipt"): return false
	var stable: Dictionary = manager.get_latest_stable_checkpoint()
	var saved_receipt: Variant = stable.get("value", {}).get("bundle", {}).get("snapshot", {}) \
		.get("contacts", {}).get("transaction_receipts", {}).get(command.command_id)
	if not _check(stable.get("ok", false) and CANONICAL_JSON._deep_same(receipt, saved_receipt),
			"latest durable checkpoint contains the exact ordinary receipt"): return false
	print("CLICK_LATENCY_REPLY: " + JSON.stringify({
		"locale": locale, "entry_id": receipt.entry_id, "reply_id": receipt.reply_id,
		"transaction_id": receipt.transaction_id, "witnessed_line_id": receipt.witnessed_line_id,
		"text_utf8_bytes": str(receipt.plain_text_snapshot).to_utf8_buffer().size(),
		"contains_non_ascii": _contains_non_ascii(str(receipt.plain_text_snapshot)),
		"checkpoint_id": stable.value.bundle.snapshot.checkpoint_id,
	}))
	return true


func _contains_non_ascii(value: String) -> bool:
	for index: int in value.length():
		if value.unicode_at(index) > 127: return true
	return false


# ---------------------------------------------------------------------------------------------
# Minesweeper app
# ---------------------------------------------------------------------------------------------

func _minesweeper_app_benchmark(bootstrap: Node, desktop: Node) -> bool:
	if not _check(desktop.open_app(&"minesweeper").get("ok", false), "board app opens"): return false
	await _frames()
	var app: Node = desktop._cached_app_windows[&"minesweeper"]
	var panel: Control = app.panel
	var enabled: Array = panel.public_view.register.difficulty_enabled
	var chosen := ""
	for tier: String in ["expert", "intermediate", "beginner"]:
		if tier in enabled:
			chosen = tier
			break
	if not _check(chosen != "", "a difficulty is enabled"): return false
	if chosen != str(panel.public_view.register.difficulty):
		panel.register.difficulties[chosen].pressed.emit()
	print("CLICK_LATENCY_BOARD: " + JSON.stringify({"surface": "app", "difficulty": chosen,
		"width": panel.public_view.board.width, "height": panel.public_view.board.height}))
	if not await _play_app_board(bootstrap, app, panel, "win"): return false
	# A settled board offers New Board; the next round is played to a loss.
	if panel.public_view.settled:
		panel.dock.action_requested.emit(&"new_board")
		await _frames()
	if not _check(not panel.public_view.settled, "New Board offers a fresh round"): return false
	if not await _play_app_board(bootstrap, app, panel, "loss"): return false
	if not _check(desktop.return_home().get("ok", false), "Home after board benchmark"): return false
	await _frames()
	return true


func _play_app_board(bootstrap: Node, app: Node, panel: Control, ending: String) -> bool:
	var worksheet: Control = panel.worksheet
	# The second round starts from New Board on a settled account; its first reveal is labelled
	# apart so the two boundaries never share one median (dwm-634.2).
	var first_label := "first_reveal" if ending == "win" else "new_board_first_reveal"
	var first := await _timed("app", first_label, func() -> void:
		worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision)))
	if not _check(app.last_result.get("ok", false) and first.ok, "app first reveal accepted"): return false
	for frame: int in 600:
		if bootstrap._desktop_board_state.capture().board is Dictionary: break
		await process_frame
	var physical: Dictionary = _app_physical(bootstrap)
	if not _check(not physical.is_empty(), "app first reveal materialized a board"): return false
	# One flag and one unflag on a covered mine, then routine reveals.
	var flag_target := -1
	for index: int in physical.mine_indices:
		if index not in physical.flagged_indices:
			flag_target = index
			break
	if not _check(flag_target >= 0, "an unflagged mine exists"): return false
	await _timed("app", "flag", func() -> void:
		worksheet.cell_action_requested.emit(&"flag", flag_target, int(panel.public_view.board.revision)))
	await _timed("app", "unflag", func() -> void:
		worksheet.cell_action_requested.emit(&"unflag", flag_target, int(panel.public_view.board.revision)))
	var routine := 0
	var terminal_action := {}
	while true:
		physical = _app_physical(bootstrap)
		if physical.is_empty() or bool(physical.get("terminal", false)): break
		var safe := _next_safe_cell(physical)
		if safe < 0: break
		var label := "routine_reveal" if routine < ROUTINE_LOG_LIMIT else "routine_reveal_more"
		if ending == "loss" and routine >= 3:
			var lost := await _timed("app", label, func() -> void:
				worksheet.cell_action_requested.emit(&"reveal", int(physical.mine_indices[0]), int(panel.public_view.board.revision)),
				func() -> bool: return bool(panel.public_view.board.get("terminal", false)), "losing_reveal")
			if not _check(lost.label == "losing_reveal" and app.last_result.get("ok", false), "losing reveal accepted"): return false
			terminal_action = lost
			break
		var step := await _timed("app", label, func() -> void:
			worksheet.cell_action_requested.emit(&"reveal", safe, int(panel.public_view.board.revision)),
			func() -> bool: return bool(panel.public_view.board.get("terminal", false)), "winning_reveal")
		if not _check(step.ok and app.last_result.get("ok", false), "routine reveal %d accepted" % routine): return false
		if step.label == "winning_reveal":
			terminal_action = step
			break
		routine += 1
		if routine > 600: return _check(false, "routine reveal loop did not terminate")
	var expected_terminal_label := "winning_reveal" if ending == "win" else "losing_reveal"
	if not _check(terminal_action.get("label", "") == expected_terminal_label,
			"app requested %s and observed %s" % [expected_terminal_label, terminal_action.get("label", "none")]): return false
	var settled_us := await _until(func() -> bool: return bool(panel.public_view.settled), 600)
	print("CLICK_LATENCY_SETTLED: " + JSON.stringify({"surface": "app", "ending": ending, "settled_after_us": settled_us,
		"end_to_end_us": Time.get_ticks_usec() - int(terminal_action.started_us), "settled": panel.public_view.settled}))
	return _check(panel.public_view.settled, "app %s settles" % ending)


func _app_physical(bootstrap: Node) -> Dictionary:
	var captured: Dictionary = bootstrap._desktop_board_state.capture()
	if not captured.get("board") is Dictionary: return {}
	var wrapper: Dictionary = captured.board
	if not wrapper.get("board") is Dictionary: return {}
	return wrapper.board


# ---------------------------------------------------------------------------------------------
# Dating challenge
# ---------------------------------------------------------------------------------------------

func _dating_benchmark(game: Node, desktop: Node) -> bool:
	var friend_id := "priscilla"
	var invitation_id := "solo:%s:day%d" % [friend_id, game.day]
	var opened: Dictionary = desktop.open_app(&"contacts")
	if not _check(opened.get("ok", false), "Contacts opens: " + JSON.stringify(opened)): return false
	await _frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit(friend_id)
	if not _check(contacts.last_result.get("ok", false), "read invitation: " + JSON.stringify(contacts.last_result)): return false
	if not _check(game.contacts.solo_actions.get(invitation_id, {}).get("state") == "ACCEPTED", "reading accepts the invitation"): return false
	if not _check(desktop.return_home().get("ok", false), "Home after Contacts"): return false
	opened = desktop.open_app(&"schedule")
	if not _check(opened.get("ok", false), "Schedule opens"): return false
	await _frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit(invitation_id)
	if not _check(schedule.last_result.get("ok", false), "invitation scheduled: " + JSON.stringify(schedule.last_result)): return false
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "Schedule Done: " + JSON.stringify(done)): return false
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		var dismissed: Dictionary = ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
		if not _check(dismissed.get("ok", false), "Dating warning: " + JSON.stringify(dismissed)): return false
	await _frames()
	if not _check(current_scene.has_method("get_presentation_projection") and current_scene.get("worksheet") != null, "Dating scene mounted"): return false
	var dating: Node = current_scene
	dating.get("_continue_button").pressed.emit()
	for frame: int in 600:
		if dating.get("_physical_view").phase == "challenge": break
		if dating.get("_physical_view").phase == "preparing": dating.get("_continue_button").pressed.emit()
		await process_frame
	if not _check(dating.get("_physical_view").phase == "challenge", "Continue starts the challenge: " + str(dating.get("_physical_view").phase)): return false
	var worksheet: Control = dating.worksheet
	var first := await _timed("dating", "first_reveal", func() -> void:
		worksheet.cell_action_requested.emit(&"reveal", 0, int(dating.get("_physical_view").board.revision)))
	var record: Dictionary = game.capture_dating_challenge_state().value
	if not _check(first.ok and record.board != null, "dating first reveal generated a board"): return false
	print("CLICK_LATENCY_BOARD: " + JSON.stringify({"surface": "dating", "width": record.board.width, "height": record.board.height}))
	var ending := _dating_ending()
	if not _check(ending in ["win", "loss"], "--dating-ending must be win or loss: " + ending): return false
	var routine := 0
	var terminal_action := {}
	while true:
		record = game.capture_dating_challenge_state().value
		if record.board == null or bool(record.board.terminal): break
		var safe := _next_safe_cell(record.board)
		if safe < 0: break
		var remaining := _safe_remaining(record.board)
		var label := "routine_reveal" if routine < ROUTINE_LOG_LIMIT else "routine_reveal_more"
		if ending == "loss" and (routine >= ROUTINE_LOG_LIMIT or remaining <= 1):
			var lost := await _timed("dating", label, func() -> void:
				worksheet.cell_action_requested.emit(&"reveal", int(record.board.mine_indices[0]), int(dating.get("_physical_view").board.revision)),
				func() -> bool: return bool(dating.get("_physical_view").board.get("terminal", false)), "losing_reveal")
			if not _check(lost.label == "losing_reveal", "dating losing reveal accepted"): return false
			terminal_action = lost
			break
		var step := await _timed("dating", label, func() -> void:
			worksheet.cell_action_requested.emit(&"reveal", safe, int(dating.get("_physical_view").board.revision)),
			func() -> bool: return bool(dating.get("_physical_view").board.get("terminal", false)), "winning_reveal")
		if not _check(step.ok and (step.label == "winning_reveal" or dating.get("_physical_view").phase == "challenge"),
				"dating reveal %d accepted" % routine): return false
		if step.label == "winning_reveal":
			terminal_action = step
			break
		routine += 1
		if routine > 600: return _check(false, "dating routine reveal loop did not terminate")
	var expected_terminal_label := "winning_reveal" if ending == "win" else "losing_reveal"
	if not _check(terminal_action.get("label", "") == expected_terminal_label,
			"dating requested %s and observed %s" % [expected_terminal_label, terminal_action.get("label", "none")]): return false
	var post_action: Dictionary = terminal_action
	if ending == "win":
		# A solved board waits for the player's terminal choice unless it was Perfect, which
		# settles by itself. Either way the choice click is its own boundary.
		var chosen_us := await _until(func() -> bool:
			return str(dating.get("_physical_view").phase) in ["cleared_awaiting_terminal_choice", "post_challenge"], 600)
		print("CLICK_LATENCY_SETTLED: " + JSON.stringify({"surface": "dating", "ending": "win", "settled_after_us": chosen_us,
			"end_to_end_us": Time.get_ticks_usec() - int(terminal_action.started_us), "phase": str(dating.get("_physical_view").phase)}))
		if str(dating.get("_physical_view").phase) == "cleared_awaiting_terminal_choice":
			await _until(func() -> bool: return bool(dating.get("_choice_released")), 60)
			if not _check(bool(dating.get("_choice_released")), "terminal choice released"): return false
			post_action = await _timed("dating", "terminal_choice", func() -> void:
				dating.get("_continue_button").pressed.emit())
	var reached_us := await _until(func() -> bool: return bool(dating.get("_post_challenge_reached")), 600)
	print("CLICK_LATENCY_SETTLED: " + JSON.stringify({"surface": "dating", "ending": ending, "settled_after_us": reached_us,
		"end_to_end_us": Time.get_ticks_usec() - int(post_action.started_us), "phase": str(dating.get("_physical_view").phase)}))
	return _check(str(dating.get("_physical_view").phase) == "post_challenge", "dating outcome visible")


# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------

func _next_safe_cell(board: Dictionary) -> int:
	var total := int(board.width) * int(board.height)
	var mines := {}
	for index: int in board.mine_indices: mines[int(index)] = true
	var revealed := {}
	for index: int in board.revealed_indices: revealed[int(index)] = true
	var flagged := {}
	for index: int in board.get("flagged_indices", []): flagged[int(index)] = true
	for index: int in total:
		if not mines.has(index) and not revealed.has(index) and not flagged.has(index): return index
	return -1


func _safe_remaining(board: Dictionary) -> int:
	var total := int(board.width) * int(board.height)
	return total - int((board.mine_indices as Array).size()) - int((board.revealed_indices as Array).size())


## Times `action` synchronously, then measures the wall time until two more frames have run.
func _timed(surface: String, label: String, action: Callable,
		terminal_predicate: Callable = Callable(), terminal_label: String = "") -> Dictionary:
	var started := Time.get_ticks_usec()
	action.call()
	var sync_us := Time.get_ticks_usec() - started
	if terminal_predicate.is_valid() and terminal_predicate.call(): label = terminal_label
	await process_frame
	await process_frame
	var two_frames_us := Time.get_ticks_usec() - started
	var key := surface + ":" + label
	if not _samples.has(key): _samples[key] = []
	(_samples[key] as Array).append({"sync_us": sync_us, "two_frames_us": two_frames_us})
	print("CLICK_LATENCY: " + JSON.stringify({"surface": surface, "label": label, "sync_us": sync_us, "two_frames_us": two_frames_us}))
	return {"ok": true, "sync_us": sync_us, "started_us": started, "label": label}


## Waits until `predicate` holds or `frames` frames pass; returns the wall time waited in microseconds.
func _until(predicate: Callable, frames: int) -> int:
	var started := Time.get_ticks_usec()
	for frame: int in frames:
		if predicate.call(): break
		await process_frame
	return Time.get_ticks_usec() - started


func _print_summary() -> void:
	var keys: Array = _samples.keys()
	keys.sort()
	for key: String in keys:
		var rows: Array = _samples[key]
		var sync: Array[int] = []
		var frames: Array[int] = []
		for row: Dictionary in rows:
			sync.append(int(row.sync_us))
			frames.append(int(row.two_frames_us))
		sync.sort()
		frames.sort()
		print("CLICK_LATENCY_SUMMARY: " + JSON.stringify({"key": key, "count": rows.size(),
			"sync_min_us": sync[0], "sync_median_us": sync[sync.size() / 2], "sync_max_us": sync[sync.size() - 1],
			"two_frames_median_us": frames[frames.size() / 2], "two_frames_max_us": frames[frames.size() - 1]}))


func _issuer_root_bytes() -> int:
	var path := ProjectSettings.globalize_path("user://desktop-issuer-root.json")
	if not FileAccess.file_exists(path): return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return -1
	return int(file.get_length())
