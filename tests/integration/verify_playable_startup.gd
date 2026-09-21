extends SceneTree
## Runs real autoload startup and the actual New Account control under the isolated test runner.

var _first_day_board_identity: Dictionary = {}
var _ordinary_reply_receipt: Dictionary = {}


func _continue_drawn_art_if_ready() -> void:
	var view: Node = root.get_node("DialogicBridge").get_art_hold_view()
	if view == null or not view.has_drawn_art() or view.next_button.disabled: return
	# Ending artwork retains its own real Continue. Dating has no routine card.
	view.next_button.pressed.emit()


func _wait_for_dating_board(dating: Node) -> bool:
	for frame: int in 180:
		if not is_instance_valid(dating): return _check(false, "Dating scene vanished before its board")
		if dating.get("_physical_view").get("phase") == "challenge":
			return _check(not dating.get("_continue_button").visible and not dating.get("_special_mine_button").visible,
				"automatic Dating board exposes no retired confirmation or special-mine choice")
		await process_frame
	return _check(false, "empty semantic pre-DTL did not automatically enter the challenge")


# Test-only failure wrapper; all other prepare/commit work stays on the real checkpoint port.
class FailOneHospitalCheckpoint extends RefCounted:
	var target: Object
	var failures := 0
	func _init(port: Object) -> void: target = port
	func preview_checkpoint_id(run_id: String) -> Dictionary: return target.preview_checkpoint_id(run_id)
	func prepare(inputs: Dictionary, kind: StringName, write: Dictionary) -> Dictionary:
		return target.prepare(inputs, kind, write)
	func commit(candidate: Dictionary) -> Dictionary:
		if failures == 0:
			failures += 1
			return {"ok": false, "code": &"injected_hospital_completion_write_failure"}
		return target.commit(candidate)


class FailOneContactCheckpoint extends RefCounted:
	var target: Callable
	var failures := 0
	func _init(writer: Callable) -> void: target = writer
	func write() -> Dictionary:
		if failures == 0:
			failures += 1
			return {"ok": false, "code": &"injected_ordinary_echo_write_failure"}
		return target.call()

func _initialize() -> void:
	_run.call_deferred()

func _frames() -> void:
	for index: int in 12: await process_frame

func _capture_screen(label: String) -> bool:
	if "--render-evidence" not in OS.get_cmdline_user_args(): return true
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("user://evidence/playable")
	if not _check(DirAccess.make_dir_recursive_absolute(folder) == OK, "create rendered evidence folder"): return false
	var pixels: Image = root.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), "rendered viewport is available"): return false
	var path := folder.path_join(label + ".png")
	if not _check(pixels.save_png(path) == OK, "save rendered player screen"): return false
	print("PLAYABLE_RENDER_CAPTURE: " + path)
	return true

func _check(value: bool, detail: String) -> bool:
	if not value:
		printerr("PLAYABLE_STARTUP_FAIL: " + detail)
		quit(1)
	return value

func _run() -> void:
	if "--probe-ignored-ordinary" in OS.get_cmdline_user_args():
		if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty(), "ignored ordinary probe requires isolated test root"): return
	if "--probe-ordinary-echo" in OS.get_cmdline_user_args():
		if not _check("--probe-seven-days" in OS.get_cmdline_user_args(), "--probe-ordinary-echo requires --probe-seven-days"): return
		if not _check(DisplayServer.get_name() != "headless", "ordinary reply witness probe requires real GPU rendering"): return
	if "--probe-day7-condition" in OS.get_cmdline_user_args() and "--probe-seven-days" not in OS.get_cmdline_user_args():
		_check(false, "--probe-day7-condition requires --probe-seven-days for public day progression")
		return
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	var startup: Dictionary = bootstrap.get_startup_state()
	if not _check(bool(startup.get("ready", false)), "startup " + JSON.stringify(startup)): return
	var router: Node = root.get_node("SceneRouter")
	router.goto_menu()
	await _frames()
	if not _check(current_scene != null and current_scene.has_node("%NewAccButton"), "real title mounted"): return
	await _capture_screen("01-title")
	var new_acc: Button = current_scene.get_node("%NewAccButton")
	if not _check(not new_acc.disabled, "New Account enabled"): return
	new_acc.pressed.emit()
	var game: Node = root.get_node("GameState")
	var startup_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < startup_deadline:
		if not bool(root.get_node("SaveManager").get("_new_run_busy")) \
				and game.capture_live_session().value.active and current_scene != null \
				and current_scene.find_child("ComputerDesktop", true, false) != null: break
		await process_frame
	await _frames()
	if not _check(not bool(root.get_node("SaveManager").get("_new_run_busy")), "New Account completed its transaction before gameplay"): return
	var session: Dictionary = game.capture_live_session()
	if not _check(bool(session.value.active), "New Account activated a live session: " + JSON.stringify(session)): return
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null and desktop.is_visible_in_tree(), "new desktop is visible"): return
	await _capture_screen("02-desktop")
	if "--probe-ignored-ordinary" in OS.get_cmdline_user_args():
		await preload("res://tests/integration/PlayableOrdinaryExpiryProbe.gd").new().run(self, game, desktop)
		return
	if "--probe-desktop-debug" in OS.get_cmdline_user_args():
		# Explicit inventory fixture; all generation and persistence use production paths.
		game.inventory = {"debug_key": 1, "lucky_charm": 1}
		current_scene.get_window().grab_focus()
		await _frames()
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	if not _check(opened.get("ok", false), "Minesweeper opens: " + JSON.stringify(opened)): return
	if "--probe-desktop-debug" in OS.get_cmdline_user_args():
		await _desktop_debug_journey(game, desktop, desktop.get("_cached_app_windows")[&"minesweeper"])
		return
	await _frames()
	var app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
	var panel: Control = app.panel
	if not _check(panel.has_valid_presentation(), "board presentation ready"): return
	if "--probe-board-controls" in OS.get_cmdline_user_args():
		await _board_controls_journey(game, desktop, app)
		return
	var before: int = game.minesweeper_rounds_left
	var finished_before: int = game.minesweeper_app_rounds_finished_today
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "first Reveal: " + JSON.stringify(app.last_result)): return
	if not _check(game.minesweeper_rounds_left == before - 1, "first Reveal charges one round"): return
	await _capture_screen("03-minesweeper")
	print("PLAYABLE_STARTUP_PASS: actual startup -> New Account -> visible desktop -> Minesweeper -> first Reveal")
	if "--probe-pause-save" in OS.get_cmdline_user_args() and "--probe-dating" not in OS.get_cmdline_user_args() and "--probe-terminal-save" not in OS.get_cmdline_user_args():
		await _pause_journey(game)
		return
	# Only the fixture inspects hidden state to select a real mine; production Reveal determines loss.
	var day_one_owner: Dictionary = bootstrap.get("_desktop_board_state").capture()
	_first_day_board_identity = day_one_owner.identity.duplicate(true)
	var physical: Dictionary = day_one_owner.board.board
	if not panel.public_view.board.terminal:
		panel.worksheet.cell_action_requested.emit(&"reveal", int(physical.mine_indices[0]), int(panel.public_view.board.revision))
	if not await _wait_app_round_settled(game, app, finished_before): return
	if "--probe-message-popup" in OS.get_cmdline_user_args():
		await _message_popup_journey(game, desktop)
		return
	if "--probe-terminal-save" in OS.get_cmdline_user_args():
		await _terminal_inspection_journey(game, desktop, app)
		return
	var home: Dictionary = desktop.return_home()
	if not _check(home.get("ok", false), "Home after round: " + JSON.stringify(home)): return
	if "--probe-ordinary-echo" in OS.get_cmdline_user_args() or "--probe-ordinary-reply" in OS.get_cmdline_user_args():
		if not _check(DisplayServer.get_name() != "headless", "ordinary reply witness requires real rendering"): return
		if not await _ordinary_reply_journey(game, desktop): return
	if "--probe-schedule-hospital" in OS.get_cmdline_user_args():
		await _schedule_hospital_journey(game, desktop)
		return
	if "--probe-dating" in OS.get_cmdline_user_args() or "--probe-dating-debug" in OS.get_cmdline_user_args() or "--probe-dating-marked" in OS.get_cmdline_user_args():
		await _dating_journey(game, desktop)
		return
	if "--probe-pause" in OS.get_cmdline_user_args():
		await _pause_journey(game)
		return
	var scheduled: Dictionary = desktop.open_app(&"schedule")
	if not _check(scheduled.get("ok", false), "Schedule opens: " + JSON.stringify(scheduled)): return
	await _frames()
	var commands: Dictionary = desktop.get_meta("gameplay_ports")
	var done: Dictionary = {}
	for attempt: int in 5:
		done = commands.commands.dispatch_done()
		if not _check(done.get("ok", false), "Schedule Done: " + JSON.stringify(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		# This journey deliberately skips optional work using the same Dismiss offered by Schedule.
		var dismissed: Dictionary = commands.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
		if not _check(dismissed.get("ok", false), "warning dismissal: " + JSON.stringify(dismissed)): return
	await _frames()
	if not _check(game.day == 2, "empty Schedule advances to Day 2: " + JSON.stringify(done)): return
	if not _check(game.minesweeper_rounds_left == 2, "new day restores two rounds"): return
	if not _check(game.minesweeper_app_rounds_finished_today == 0, "new day clears finished-round count"): return
	if not _check(game.get_stat("motivation") == 7, "new day restores motivation"): return
	print("PLAYABLE_DAY_PASS: completed round -> Home -> Schedule -> acknowledged warning -> Day 2")
	if "--probe-observer-priscilla" in OS.get_cmdline_user_args() or "--probe-observer-lavinia" in OS.get_cmdline_user_args():
		await _dating_journey(game, current_scene.find_child("ComputerDesktop", true, false))
		return
	if "--probe-logout" in OS.get_cmdline_user_args():
		await _logout_journey(game)
		return
	if "--probe-seven-days" in OS.get_cmdline_user_args():
		await _seven_day_journey(game)
		return
	if "--probe-hospital" in OS.get_cmdline_user_args():
		await _hospital_journey(bootstrap, game)
		return
	if "--probe-day2-board" in OS.get_cmdline_user_args():
		await _day_two_board_journey(bootstrap, game)
		return
	quit(0)


func _hospital_journey(bootstrap: Node, game: Node) -> void:
	# Isolated fixture setup puts a real Shop purchase one authored effect away from fainting.
	game.money = 200
	game.set_stat("health", 1)
	game.set_stat("pressure", 5)
	game.condition_effects_today.assign(["sequela"])
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null, "desktop available for Shop journey"): return
	var opened: Dictionary = desktop.open_app(&"shop")
	if not _check(opened.get("ok", false), "Shop opens: " + JSON.stringify(opened)): return
	await _frames()
	var shop: Node = desktop.get("_cached_app_windows")[&"shop"]
	var card: Button = shop.cards.get("wine")
	if not _check(card != null and card.is_visible_in_tree(), "wine card visible"): return
	card.pressed.emit()
	var buy: Button = shop.get("_buy_button")
	if not _check(not buy.disabled, "wine purchase enabled"): return
	buy.pressed.emit()
	if not _check(shop.get("_purchase_result").get("ok", false), "Shop purchase: " + JSON.stringify(shop.get("_purchase_result"))): return
	await _frames()
	if not _check(current_scene != null and current_scene.has_node("%FaintNotice"), "ordinary Hospital notice mounted"): return
	var hospital: Node = current_scene
	var notice_port: Object = hospital.get("_presentation_port")
	var notice_command: Dictionary = hospital.get_presentation_projection()
	if not _check(hospital.get_node("%FaintNotice").visible, "ordinary Hospital uses the short notice"): return
	if not _check(not root.get_node("DialogicBridge").has_active_playback(), "ordinary Hospital starts no DTL or art"): return
	await _capture_screen("ordinary-hospital-notice")
	var coordinator: Object = bootstrap.get("_retained_condition_hospital_coordinator")
	var original: Object = coordinator.get("_checkpoint")
	var injected := FailOneHospitalCheckpoint.new(original)
	var retry_probe := "--probe-hospital-notice-retry" in OS.get_cmdline_user_args()
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	if retry_probe: coordinator.set("_checkpoint", injected)
	hospital.get_node("%ContinueButton").pressed.emit()
	await _frames()
	if retry_probe:
		if not _check(injected.failures == 1, "actual Hospital completion encountered one injected save failure"): return
		if not _check(current_scene == hospital and game.day == 2, "failed completion stays on the notice and source day"): return
		if not _check(game.capture_run_snapshot_input() == before, "failed completion applies no gameplay effects"): return
		if not _check(not hospital.get_node("%ContinueButton").disabled, "the visible Continue button becomes retryable"): return
		hospital.get_node("%ContinueButton").pressed.emit()
		await _frames()
		coordinator.set("_checkpoint", original)
	for frame: int in 100:
		await process_frame
		if game.day == 3 and game._run_lifecycle.to_dict().get("active_condition_hospital_plan") == null: break
	var result: Dictionary = bootstrap.get("_last_condition_hospital_result")
	if not _check(game.day == 3, "Hospital advanced exactly one day: " + JSON.stringify({"result": result, "condition": game.pending_hospital, "hospital_status": bootstrap.get("_desktop_consequence_state").capture().value.state.outbox.get("hospital", {}).get("status"), "gate": bootstrap.get("_application_gate").get_active_owner()})): return
	if not _check(not game.pending_hospital, "Hospital cleared pending condition"): return
	var recovery: Dictionary = preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd").HOSPITAL_RECOVERY
	if not _check(game.get_stat("health") == int(recovery.health), "Hospital health recovery applied"): return
	if not _check(game.get_stat("pressure") == int(recovery.pressure), "Hospital pressure recovery applied"): return
	if not _check(game.money == 145, "purchase charged once through Hospital"): return
	if not _check(game.minesweeper_rounds_left == 2, "Hospital new day resets daily rounds"): return
	await _frames()
	if not _check(current_scene.find_child("ComputerDesktop", true, false) != null, "Hospital returns to desktop"): return
	if retry_probe:
		var settled: Dictionary = game.capture_run_snapshot_input().duplicate(true)
		if not _check(notice_port.acknowledge_notice(notice_command).get("ok", false), "exact repeated acknowledgment remains harmless"): return
		await _frames()
		if not _check(game.capture_run_snapshot_input() == settled, "repeated completion applies no second recovery, charge, or day advance"): return
		print("PLAYABLE_HOSPITAL_NOTICE_RETRY_PASS: actual Continue -> failed durable completion -> same notice retry -> one recovery/day advance")
	print("PLAYABLE_HOSPITAL_PASS: actual wine purchase -> Hospital presentation -> recovered Day 3 desktop")
	quit(0)


func _seven_day_journey(game: Node) -> void:
	for expected_day: int in range(3, 8):
		var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
		if not _check(desktop != null, "desktop before next Schedule"): return
		if "--probe-ordinary-echo" in OS.get_cmdline_user_args() and game.day == 6:
			if not await _ordinary_day6_invitation(game, desktop): return
		var opened: Dictionary = desktop.open_app(&"schedule")
		if not _check(opened.get("ok", false), "Schedule next day: " + JSON.stringify(opened)): return
		await _frames()
		var ports: Dictionary = desktop.get_meta("gameplay_ports")
		var result: Dictionary = {}
		for attempt: int in 5:
			result = ports.commands.dispatch_done()
			if not _check(result.get("ok", false), "next Done: " + JSON.stringify(result)): return
			var warning: Variant = result.get("value", {}).get("warning")
			if warning == null: break
			var dismissed: Dictionary = ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
			if not _check(dismissed.get("ok", false), "next warning: " + JSON.stringify(dismissed)): return
		await _frames()
		if not _check(game.day == expected_day, "expected day %d: %s" % [expected_day, JSON.stringify(result)]): return
		if not _check(game.minesweeper_rounds_left == 2 and game.get_stat("motivation") == 7, "daily resources at day %d" % expected_day): return
	print("PLAYABLE_SEVEN_DAY_PASS: public Schedule Done reaches Day 7 through every daily transition")
	if "--probe-ordinary-echo" in OS.get_cmdline_user_args():
		if not await _ordinary_day7_prelude_journey(game): return
	if "--probe-day7-condition" in OS.get_cmdline_user_args():
		await _day_seven_condition_journey(game)
		return
	if "--probe-ending" in OS.get_cmdline_user_args():
		await _ending_journey(game)
		return
	quit(0)


func _click_logout_control(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size / 2)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()

func _logout_journey(game: Node) -> void:
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	var session: Dictionary = game.capture_live_session().value
	var host: Object = desktop.get("_host_state")
	var before: Dictionary = host.get_state()
	var launcher: Button = desktop.launcher_buttons[&"logout"]
	await _click_logout_control(launcher)
	var logout: Control = desktop.get("_confirmation")
	if not _check(logout != null and logout.is_visible_in_tree(), "real launcher opens Logout consent"): return
	if not _check(desktop.icon_grid.visible and desktop.get("_active_id") == &"", "Logout retains the launcher"): return
	if not _check(host.get_state() == before and host.capture_persistent_state().active_app_id == null, "consent preserves canonical host and saved launcher"): return
	if not _check(not desktop.get("_cached_app_windows").has(&"logout"), "Logout never enters the content cache"): return
	if not _check(root.gui_get_focus_owner() == logout.cancel_button, "No owns initial consent focus"): return
	if not await _capture_screen("logout-01-consent"): return
	await _click_logout_control(logout.cancel_button)
	if not _check(desktop.get("_confirmation") == null and root.gui_get_focus_owner() == launcher, "No restores exact Logout launcher focus"): return
	await _click_logout_control(launcher)
	logout = desktop.get("_confirmation")
	if not _check(logout != null, "Logout consent can reopen"): return
	await _click_logout_control(logout.confirm_button)
	await _frames()
	if not _check(current_scene.has_node("%LogInButton"), "Logout returns to title"): return
	if not _check(not game.capture_live_session().value.active, "Logout retires live session"): return
	var login: Button = current_scene.get_node("%LogInButton")
	if not _check(not login.disabled, "saved Login is enabled"): return
	login.pressed.emit()
	await _frames()
	var picker: Node = current_scene.get("_backup_app_instance")
	if not _check(picker != null and picker.is_visible_in_tree(), "Login opens the saved-slot picker"): return
	picker.drawer_buttons["autosave"].pressed.emit()
	if not _check(not picker.action_buttons["load"].disabled, "Autosave Load enabled"): return
	picker.action_buttons["load"].pressed.emit()
	if is_instance_valid(picker.confirmation): picker.confirmation.confirm_button.pressed.emit()
	var loaded: Dictionary = picker.last_result.duplicate(true)
	await _frames()
	if not _check(current_scene.find_child("ComputerDesktop", true, false) != null,
		"Login restores the desktop: " + JSON.stringify(loaded)): return
	var resumed: Dictionary = game.capture_live_session().value
	if not _check(resumed.active and resumed != session, "Login activates a fresh session handle"): return
	var restored_desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(restored_desktop.icon_grid.visible and restored_desktop.get("_active_id") == &"", "Logout Autosave restores launcher, never consent"): return
	if not _check(restored_desktop.get("_host_state").capture_persistent_state().active_app_id == null, "restored canonical workspace remains launcher"): return
	if not _check(game.day == 2 and game.minesweeper_rounds_left == 2, "Login preserves Day 2 resources"): return
	print("PLAYABLE_LOGOUT_PASS: actual Logout confirmation -> saved title -> Login -> restored Day 2 desktop")
	quit(0)


func _dating_journey(game: Node, desktop: Node) -> void:
	var date_day: int = game.day
	var reached_before: Dictionary = root.get_node("ProfileManager").get_profile_snapshot().reached_presentations.duplicate(true)
	var friend_id := "lavinia" if "--probe-observer-lavinia" in OS.get_cmdline_user_args() else "priscilla"
	var invitation_id := "solo:%s:day%d" % [friend_id, date_day]
	# Day-2 Observer scenes follow their real per-round invitation unlocks.
	if date_day == 2:
		for unlock_round: int in 2:
			if game.contacts.solo_actions.has(invitation_id): break
			var unlock_opened: Dictionary = desktop.open_app(&"minesweeper")
			if not _check(unlock_opened.get("ok", false), "open current-day invitation round"): return
			await _frames()
			var unlock_app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
			var unlock_panel: Control = unlock_app.panel
			if unlock_panel.public_view.settled:
				unlock_panel.dock.action_requested.emit(&"new_board")
				if not _check(not unlock_panel.public_view.settled, "New Board dismisses the settled invitation round"): return
			unlock_panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(unlock_panel.public_view.board.revision))
			var unlocked_owner: Dictionary = root.get_node("ApplicationBootstrap").get("_desktop_board_state").capture()
			if not _check(unlock_app.last_result.get("ok", false) and unlocked_owner.board is Dictionary, "actual first Reveal starts next invitation round"): return
			var unlock_board: Dictionary = unlocked_owner.board.board
			unlock_panel.worksheet.cell_action_requested.emit(&"reveal", int(unlock_board.mine_indices[0]), int(unlock_panel.public_view.board.revision))
			await _frames()  # dwm-634.1: the terminal board paints first; settlement runs on the next frames
			if not _check(unlock_app.last_result.get("ok", false) and unlock_panel.public_view.settled, "actual current-day round unlocks contact invitation"): return
			if not _check(desktop.return_home().get("ok", false), "Home after invitation round"): return
	var opened: Dictionary = desktop.open_app(&"contacts")
	if not _check(opened.get("ok", false), "Contacts opens: " + JSON.stringify(opened)): return
	await _frames()
	var contacts: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts.contacts_panel.open_requested.emit(friend_id)
	if not _check(contacts.last_result.get("ok", false), "read invitation: " + JSON.stringify(contacts.last_result)): return
	if not _check(game.contacts.solo_actions.get(invitation_id, {}).get("state") == "ACCEPTED", "reading accepts actual current-day invitation"): return
	if not _check(desktop.return_home().get("ok", false), "Home after Contacts"): return
	opened = desktop.open_app(&"schedule")
	if not _check(opened.get("ok", false), "Schedule opens for date"): return
	await _frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit(invitation_id)
	if not _check(schedule.last_result.get("ok", false) and schedule.get("_projection").entries.size() == 1,
		"invitation added to Schedule: " + JSON.stringify(schedule.last_result)): return
	if "--probe-dating-debug" in OS.get_cmdline_user_args():
		# Explicit capability fixture before the real Date owner freezes its inputs.
		game.inventory = {"debug_key": 1, "lucky_charm": 1}
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "Dating Schedule Done: " + JSON.stringify(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		var dismissed: Dictionary = ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
		if not _check(dismissed.get("ok", false), "Dating warning: " + JSON.stringify(dismissed)): return
	await _frames()
	if not _check(current_scene.has_method("get_presentation_projection") and current_scene.get("worksheet") != null,
		"actual Dating scene mounted"): return
	var dating: Node = current_scene
	await _capture_screen("04-dating-entry")
	if "--probe-observer-priscilla" in OS.get_cmdline_user_args() or "--probe-observer-lavinia" in OS.get_cmdline_user_args():
		if not await _observer_scene_journey(game, dating, friend_id): return
	if "--probe-dating-debug" in OS.get_cmdline_user_args() or "--probe-dating-marked" in OS.get_cmdline_user_args():
		await preload("res://tests/integration/PlayableDatingCapabilityProbe.gd").new().run(self, game, dating, "--probe-dating-debug" in OS.get_cmdline_user_args())
		return
	if not await _wait_for_dating_board(dating): return
	dating.worksheet.cell_action_requested.emit(&"reveal", 0, int(dating.get("_physical_view").board.revision))
	var record: Dictionary = game.capture_dating_challenge_state().value
	if not _check(record.board != null, "first reveal generated a canonical date board"): return
	await _capture_screen("05-dating-board")
	if "--probe-pause" in OS.get_cmdline_user_args() or "--probe-pause-save" in OS.get_cmdline_user_args():
		await _pause_journey(game)
		return
	if "--probe-dating-reload" in OS.get_cmdline_user_args():
		var before_reload := record.duplicate(true)
		var prior_session: Dictionary = game.capture_live_session().value
		var saves: Node = root.get_node("SaveManager")
		var prepared: Dictionary = saves.prepare_restore_autosave()
		if not _check(prepared.get("ok", false), "mid-Dating Autosave prepares: " + JSON.stringify(prepared)): return
		var restored: Dictionary = saves.commit_prepared_restore(prepared.value.prepared)
		if not _check(restored.get("ok", false), "mid-Dating Autosave commits: " + JSON.stringify(restored)): return
		for frame: int in 40:
			await process_frame
			# change_scene_to_* retires the outgoing node before installing its replacement.
			if current_scene != null and current_scene.get("worksheet") != null: break
		if not _check(current_scene != null and current_scene.get("worksheet") != null, "Load remounts active Dating scene: " + JSON.stringify({
			"route": root.get_node("SceneRouter").get_current_route_id(), "scene": current_scene.scene_file_path if current_scene != null else "none",
			"record_phase": game.capture_dating_challenge_state().value.get("phase", ""),
			"dispatch": root.get_node("ApplicationBootstrap").get("_retained_schedule_done_dispatcher").get_last_dispatch_result(),
			"loaded": restored})): return
		dating = current_scene
		record = game.capture_dating_challenge_state().value
		if not _check(record.board == before_reload.board and record.spec == before_reload.spec,
			"Load preserves exact Dating spec and board"): return
		if not _check(game.capture_live_session().value != prior_session and game.capture_live_session().value.active,
			"mid-Dating Load activates a new session"): return
		if not _check(dating.get("_physical_view").phase == "challenge", "restored Dating input is playable"): return
		print("PLAYABLE_DATING_RELOAD_PASS: actual mid-board Autosave Load preserves board and resumes current command")
	# The fixture chooses a hidden mine; the real worksheet/owner determines and persists its result.
	dating.worksheet.cell_action_requested.emit(&"reveal", int(record.board.mine_indices[0]),
		int(dating.get("_physical_view").board.revision))
	# Terminal cells paint before settlement; empty post-DTL may retire this scene.
	# Observe the durable day/route rather than calling the removed Done control.
	for frame: int in 240:
		if game.day == date_day + 1 and current_scene != null \
				and current_scene.find_child("ComputerDesktop", true, false) != null: break
		await process_frame
	if not _check(root.get_node("ProfileManager").get_profile_snapshot().reached_presentations == reached_before,
		"empty pre/post DTL adds no fabricated witnessed Gallery signature"): return
	if not _check(game.day == date_day + 1, "Dating outcome advances exactly one day: " + JSON.stringify(
		root.get_node("ApplicationBootstrap").get("_retained_schedule_done_dispatcher").get_last_dispatch_result())): return
	if not _check(current_scene.find_child("ComputerDesktop", true, false) != null, "Dating returns to desktop"): return
	var actions: Dictionary = game.contacts.solo_actions
	if not _check(actions[invitation_id].state == "RESOLVED_ATTENDED", "attended invitation resolved"): return
	print("PLAYABLE_DATING_PASS: actual invitation -> Contacts -> Schedule -> canonical board -> outcome -> next-day desktop")
	if "--probe-logout" in OS.get_cmdline_user_args():
		await _logout_journey(game)
		return
	quit(0)


func _observer_scene_journey(game: Node, dating: Node, friend_id: String) -> bool:
	# These preserved CLI aliases now verify the current retirement decision.
	if not _check(game.day == 2 and dating.get("_observer_view").is_empty(),
		"Day 2 has no active Observer interaction"): return false
	for name: String in ["PreviousSceneLine", "ObserverCapture", "ObserverAction"]:
		if not _check(dating.find_child(name, true, false) == null, "retired Observer control absent: " + name): return false
	var evidence: Dictionary = root.get_node("ProfileManager").get_observer_evidence().value
	if not _check(evidence.receipts.is_empty(), "no retired interaction manufactured an evidence receipt"): return false
	print("PLAYABLE_OBSERVER_RETIRED_PASS: actual Day 2 %s date has no provisional interaction or evidence" % friend_id)
	return true


func _ending_journey(game: Node) -> void:
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	var opened: Dictionary = desktop.open_app(&"schedule")
	if not _check(opened.get("ok", false), "Day 7 Schedule opens"): return
	await _frames()
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	for attempt: int in 5:
		var done: Dictionary = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "final Done: " + JSON.stringify(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		var dismissed: Dictionary = ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
		if not _check(dismissed.get("ok", false), "final warning: " + JSON.stringify(dismissed)): return
	for frame: int in 240:
		_continue_drawn_art_if_ready()
		await process_frame
		if current_scene != null and current_scene.has_node("%NewAccButton"): break
	if not _check(str(game._run_lifecycle.get_state()) == "COMPLETED", "ending completed: " +
		JSON.stringify({"state":game._run_lifecycle.get_state(), "plan":game._run_lifecycle.to_dict().ending_plan})): return
	if not _check(game.day == 7, "ending never creates Day 8"): return
	if not _check(current_scene.has_node("%NewAccButton"), "ending returns to actual title"): return
	if not _check(not game.capture_live_session().value.active, "completed ending retires live session"): return
	var profile: Node = root.get_node("ProfileManager")
	if not _check(profile.has_gallery_unlock("ending.alone"), "played Alone ending appears in Gallery"): return
	print("PLAYABLE_ENDING_PASS: all seven days -> final Schedule -> physical Alone ending -> Gallery unlock -> title")
	if "--probe-gallery" in OS.get_cmdline_user_args():
		await _gallery_journey(game)
		return
	if "--probe-completed-load" in OS.get_cmdline_user_args():
		await _completed_load_journey(game)
		return
	quit(0)


func _gallery_journey(game: Node) -> void:
	var profile: Node = root.get_node("ProfileManager")
	var before_run: Dictionary = game.to_save_dict()
	var before_profile: Dictionary = profile.get_profile_snapshot()
	current_scene.get_node("%GalleryButton").pressed.emit()
	await _frames()
	var gallery: Node = current_scene.get("_gallery_instance")
	if not _check(gallery != null and gallery.is_visible_in_tree(), "actual title opens Gallery"): return
	var owner: Object = gallery.get("_replay_owner")
	if not _check(owner != null, "actual Gallery has composed replay owner"): return
	var selected := false
	for tile: Button in gallery.get("_ending_tile_grid").get_children():
		if str(tile.get_meta("gallery_record_id")) == "ending.alone":
			tile.pressed.emit()
			selected = true
			break
	if not _check(selected and not gallery.get("_replay_button").disabled,
		"the physically reached Alone version is replayable"): return
	await _capture_screen("09-gallery")
	var completions: Array = []
	root.get_node("DialogicBridge").reached_replay_finished.connect(func(result: Dictionary): completions.append(result.duplicate(true)))
	gallery.get("_replay_button").pressed.emit()
	for frame: int in 240:
		_continue_drawn_art_if_ready()
		await process_frame
		if not owner.is_playing() and not completions.is_empty(): break
	if not _check(completions.size() == 1 and completions[0].get("outcome") == "completed" and not owner.is_playing(),
		"actual Gallery replay physically completes: " + JSON.stringify(completions)): return
	if not _check(game.to_save_dict() == before_run and profile.get_profile_snapshot() == before_profile,
		"Gallery replay preserves canonical Run and Profile"): return
	gallery.get("_return_button").pressed.emit()
	await _frames()
	if not _check(current_scene.has_node("%NewAccButton") and not gallery.is_visible_in_tree(), "Gallery Return restores title"): return
	print("PLAYABLE_GALLERY_PASS: public seven days -> exact ending completion -> title Gallery -> recorded replay -> unchanged Run/Profile -> Return")
	quit(0)


func _day_two_board_journey(bootstrap: Node, game: Node) -> void:
	if not _check(game.day == 2, "second-day board begins on public Day 2"): return
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null, "Day 2 desktop mounted"): return
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	if not _check(opened.get("ok", false), "Day 2 Minesweeper opens: " + JSON.stringify(opened)): return
	await _frames()
	var app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
	var panel: Control = app.panel
	if not _check(panel.has_valid_presentation(), "Day 2 board presentation ready"): return
	var rounds_before: int = game.minesweeper_rounds_left
	if not _check(rounds_before == 2, "Day 2 starts with both daily rounds"): return
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "Day 2 first Reveal: " + JSON.stringify(app.last_result)): return
	if not _check(game.minesweeper_rounds_left == rounds_before - 1, "Day 2 first Reveal charges exactly one round"): return
	if not _check(not bool(panel.public_view.settled), "Day 2 board remains playable after first Reveal"): return
	var owner: Dictionary = bootstrap.get("_desktop_board_state").capture()
	if not _check(owner.phase == "ACTIVE_VISIBLE" and owner.board is Dictionary, "Day 2 canonical board is active"): return
	var identity: Dictionary = owner.identity
	var lifecycle: Dictionary = game._run_lifecycle.to_dict()
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"]:
		if not _check(identity.get(key) == lifecycle.get(key), "Day 2 board belongs to current " + key): return
	if not _check(identity.causal_day_instance != _first_day_board_identity.causal_day_instance,
		"Day 2 board uses the new causal day, not Day 1's completed board"): return
	if not _check(int(identity.app_round_ordinal) == 1, "Day 2 first board restarts the daily ordinal"): return
	if not _check(game.minesweeper_app_rounds_finished_today == 0 and game.day == 2,
		"new active board has no stale Day 1 completion"): return
	print("PLAYABLE_DAY2_BOARD_PASS: public Day 2 -> fresh Minesweeper board -> first Reveal -> one round charged")
	quit(0)


func _day_seven_condition_journey(game: Node) -> void:
	if not _check(game.day == 7 and str(game._run_lifecycle.get_state()) == "PLAYING",
		"condition probe begins on public pre-Done Day 7"): return
	if not _check(not bool(game._run_lifecycle.to_dict().get("dark_mode", false)), "fresh run uses normal mode"): return
	if not _check(not bool(game.daily_opened_contacts.get("day:7:friend:sylvia", false)),
		"this fixture has not read Sylvia's Day 7 invitation"): return
	# Explicit isolated condition fixture; day progression and the triggering purchase stay real.
	print("PLAYABLE_DAY7_CONDITION_FIXTURE: health=1 pressure=5 carried_sequela=true money=200; trigger via actual wine Buy")
	game.money = 200
	game.set_stat("health", 1)
	game.set_stat("pressure", 5)
	game.condition_effects_today.assign(["sequela"])
	var physical_endings: Array[Dictionary] = []
	var announced_days: Array[int] = []
	var bridge: Node = root.get_node("DialogicBridge")
	bridge.ending_playback_finished.connect(func(token: String, ending_id: String, receipt: Dictionary) -> void:
		physical_endings.append({"token": token, "ending_id": ending_id, "receipt": receipt.duplicate(true)}))
	game.day_changed.connect(func(day_value: int) -> void: announced_days.append(day_value))
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null, "Day 7 desktop available for Shop"): return
	var opened: Dictionary = desktop.open_app(&"shop")
	if not _check(opened.get("ok", false), "Day 7 Shop opens: " + JSON.stringify(opened)): return
	await _frames()
	var shop: Node = desktop.get("_cached_app_windows")[&"shop"]
	var wine: Button = shop.cards.get("wine")
	if not _check(wine != null and wine.is_visible_in_tree(), "Day 7 wine card visible"): return
	wine.pressed.emit()
	var buy: Button = shop.get("_buy_button")
	if not _check(not buy.disabled, "Day 7 wine Buy enabled"): return
	buy.pressed.emit()
	var purchase: Dictionary = shop.get("_purchase_result").duplicate(true)
	if not _check(purchase.get("ok", false), "Day 7 actual wine purchase: " + JSON.stringify(purchase)): return
	for frame: int in 240:
		_continue_drawn_art_if_ready()
		await process_frame
		if current_scene != null and current_scene.has_node("%NewAccButton"): break
	var lifecycle: Dictionary = game._run_lifecycle.to_dict()
	var context: Dictionary = game.route_context
	var cause: Dictionary = context.get("day7_condition_ending", {})
	var diagnostic := {"lifecycle": lifecycle, "cause": cause,
		"pump": root.get_node("ApplicationBootstrap").get("_last_condition_hospital_result")}
	if not _check(str(lifecycle.state) == "COMPLETED", "condition ending completed: " + JSON.stringify(diagnostic)): return
	if not _check(game.day == 7, "condition ending never creates Day 8"): return
	for announced_day: int in announced_days:
		if not _check(announced_day == 7, "condition ending never publishes a different day"): return
	if not _check(cause.get("terminal_cause") == "hospital_alone" and cause.get("ending_form") == "normal",
		"frozen pre-Done cause is Hospital Alone: " + JSON.stringify(cause)): return
	if not _check(cause.get("sylvia_read_receipt_id") == null and not str(cause.get("destination_intent_id", "")).is_empty(),
		"ending retains its condition destination and unread-Sylvia evidence"): return
	var plan: Dictionary = lifecycle.ending_plan
	var steps: Array = plan.get("steps", [])
	if not _check(not steps.is_empty() and steps[0] == {"ending_id": "ending.alone", "role": "core"},
		"ordered condition ending begins with Alone core: " + JSON.stringify(steps)): return
	if not _check(steps == context.get("provisional_ending_plan", {}).get("steps"), "played order matches the frozen plan"): return
	if not _check(int(plan.get("next_step_index", -1)) == steps.size() and plan.get("playback_stage") == "GALLERY_RECORDED",
		"all frozen ending steps and Gallery stage completed"): return
	if not _check(not physical_endings.is_empty() and physical_endings[0].ending_id == "ending.alone",
		"actual Dialogic Alone timeline physically completed"): return
	for index: int in steps.size():
		var completion: Dictionary = plan.playback_receipts.get("step:%d" % index, {}).get("value", {})
		if not _check(completion.get("outcome") == "completed" and not str(completion.get("timeline_completion_receipt_id", "")).is_empty(),
			"frozen ending step %d has its physical completion receipt" % index): return
	if not _check(game.money == 145, "Day 7 wine charged once through ending"): return
	if not _check(lifecycle.get("active_condition_hospital_plan") == null, "Day 7 terminal route did not start next-day Hospital advancement"): return
	if not _check(current_scene != null and current_scene.has_node("%NewAccButton"), "condition ending returns to actual title"): return
	if not _check(not game.capture_live_session().value.active, "condition ending retires its live session"): return
	var profile: Node = root.get_node("ProfileManager")
	if not _check(profile.has_gallery_unlock("ending.alone") and profile.has_completed_ending(), "Profile records the played condition ending"): return
	var transaction_id := "ending:%s:gallery:ending.alone" % str(lifecycle.run_id)
	if not _check(profile.get_profile_snapshot().get("gallery_transaction_receipts", {}).has(transaction_id),
		"Profile completion evidence belongs to this run"): return
	print("PLAYABLE_DAY7_CONDITION_PASS: public Day 7 -> actual wine Buy -> frozen Hospital Alone -> physical ending -> Profile -> retired session -> title")
	quit(0)


func _pause_key() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = false
	Input.parse_input_event(event)
	await _frames()


func _ordinary_accept_focused(control: Control, detail: String) -> bool:
	if not _check(is_instance_valid(control) and control.is_visible_in_tree() and not control.disabled
		and control.has_focus(), detail + " starts from the real focused enabled control"): return false
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _frames()
	return true

func _pause_journey(game: Node) -> void:
	var router: Node = root.get_node("SceneRouter")
	var controller: Node = router.get("_production_pause")
	if not _check(controller != null, "production Pause controller composed"): return
	var original_scene: Node = current_scene
	var before: Dictionary = game.to_save_dict().duplicate(true)
	var profile: Node = root.get_node("ProfileManager")
	var original_profile: Dictionary = profile.get_profile_snapshot()
	# App Back owns the first press; the following desktop Back opens Pause.
	if str(router.get_current_route_id()) == "main":
		var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
		if desktop != null and desktop.get("_active_id") != &"":
			await _pause_key()
			if not _check(desktop.get("_active_id") == &"" and not paused, "app Back returns Home before desktop Pause"): return
	await _pause_key()
	if not _check(controller.surface.is_visible_in_tree() and paused,
		"public Back opens actual Pause: " + JSON.stringify(controller.last_result)): return
	await _capture_screen("06-pause")
	if "--probe-pause-save" in OS.get_cmdline_user_args():
		await _pause_save_load_journey(game, controller)
		return
	controller.surface.rows[&"continue"].pressed.emit()
	await _frames()
	if not _check(not paused and not controller.surface.visible and current_scene == original_scene,
		"actual Continue resumes the original scene"): return
	if not _check(game.to_save_dict() == before and profile.get_profile_snapshot() == original_profile,
		"Pause/Continue preserves run and Profile"): return
	await _pause_key()
	if not _check(controller.surface.visible and paused, "Pause reopens through Back"): return
	controller.surface.rows[&"return"].pressed.emit()
	if not _check(controller.surface.confirmation.visible, "Return shows its confirmation"): return
	controller.surface.return_button.pressed.emit()
	await _frames()
	if not _check(not paused and current_scene.has_node("%NewAccButton"),
		"confirmed Return reaches live title: " + JSON.stringify(controller.last_result)): return
	if not _check(not game.capture_live_session().value.active, "Return retires the old session"): return
	if not _check(profile.get_profile_snapshot() == original_profile, "Return preserves irreversible Profile history"): return
	print("PLAYABLE_PAUSE_PASS: public Back -> Pause -> Continue -> same scene -> Pause -> confirmed Return -> title")
	quit(0)


func _schedule_hospital_journey(game: Node, desktop: Node) -> void:
	# Only the condition is a fixture: invitation, Schedule, Hospital and rollover are production.
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	if not _check(opened.get("ok", false), "Minesweeper reopens for second invitation"): return
	await _frames()
	var app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
	var panel: Control = app.panel
	panel.dock.action_requested.emit(&"new_board")
	if not _check(not panel.public_view.settled, "second board is available"): return
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "second board Reveal"): return
	var board: Dictionary = root.get_node("ApplicationBootstrap").get("_desktop_board_state").capture().board.board
	panel.worksheet.cell_action_requested.emit(&"reveal", int(board.mine_indices[0]), int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false) and panel.public_view.settled, "second real outcome unlocks Sylvia"): return
	if not _check(desktop.return_home().get("ok", false), "Home after second round"): return
	opened = desktop.open_app(&"contacts")
	if not _check(opened.get("ok", false), "Contacts opens before Hospital"): return
	await _frames()
	var contacts_app: Node = desktop.get("_cached_app_windows")[&"contacts"]
	contacts_app.contacts_panel.open_requested.emit("sylvia")
	if not _check(contacts_app.last_result.get("ok", false), "Sylvia invitation is read"): return
	if not _check(game.contacts.solo_actions.get("solo:sylvia:day1", {}).get("state") == "ACCEPTED", "Sylvia accepted source exists"): return
	if not _check(desktop.return_home().get("ok", false), "Home after Sylvia invitation"): return
	opened = desktop.open_app(&"schedule")
	if not _check(opened.get("ok", false), "Schedule opens before Hospital"): return
	await _frames()
	var schedule: Node = desktop.get("_cached_app_windows")[&"schedule"]
	schedule.panel.source_requested.emit("solo:sylvia:day1")
	if not _check(schedule.last_result.get("ok", false), "Sylvia invitation added to Schedule"): return
	var relationships_before: Dictionary = _hospital_relationship_snapshot(game)
	game.set_stat("health", 0)
	game.set_stat("pressure", 10)
	game.condition_effects_today.assign(["sequela"])
	var physical_hospitals: Array = []
	root.get_node("DialogicBridge").timeline_finished.connect(func(timeline_id: String, receipt: Dictionary) -> void:
		if timeline_id == "hospital.faint": physical_hospitals.append(receipt.duplicate(true)))
	var ports: Dictionary = desktop.get_meta("gameplay_ports")
	var done: Dictionary = {}
	for attempt: int in 5:
		done = ports.commands.dispatch_done()
		if not _check(done.get("ok", false), "Hospital Schedule Done: " + JSON.stringify(done)): return
		var warning: Variant = done.get("value", {}).get("warning")
		if warning == null: break
		var dismissed: Dictionary = ports.warning_commands.resolve_warning(str(warning.activation_id), &"dismiss")
		if not _check(dismissed.get("ok", false), "Hospital warning acknowledgement"): return
	for frame: int in 100:
		await process_frame
		if game.day == 2 and current_scene.find_child("ComputerDesktop", true, false) != null: break
	if not _check(game.day == 2, "Schedule Hospital advances one day: " + JSON.stringify({"done": done,
		"last": root.get_node("ApplicationBootstrap").get("_retained_schedule_done_dispatcher").get_last_dispatch_result(),
		"lifecycle": game._run_lifecycle.to_dict()})): return
	if not _check(not physical_hospitals.is_empty(), "actual Hospital presentation physically completed"): return
	if not _check(game.get_stat("health") == 6 and game.get_stat("pressure") == 3 and not game.pending_hospital,
		"Schedule Hospital applies frozen recovery"): return
	if not _check(game.minesweeper_rounds_left == 2, "Schedule Hospital resets daily resources"): return
	if not _check(game.contacts.solo_actions["solo:sylvia:day1"].state == "RESOLVED_MISSED", "Hospital closes accepted Sylvia invitation"): return
	var witnesses: Dictionary = game.contacts.sylvia_hospital_witness_receipts
	if not _check(witnesses.size() == 1, "Hospital persists one Sylvia witness: " + JSON.stringify(witnesses)): return
	if not _check(_hospital_relationship_snapshot(game) == relationships_before,
		"Hospital witness does not apply future caring relationship effects"): return
	if not _check(witnesses.values()[0].care_followup_day == 2, "witness targets next-day caring entry"): return
	if not _check(current_scene.find_child("ComputerDesktop", true, false) != null, "Schedule Hospital returns to desktop"): return
	if "--probe-sylvia-care" in OS.get_cmdline_user_args():
		await _sylvia_care_journey(game, relationships_before)
		return
	print("PLAYABLE_SCHEDULE_HOSPITAL_PASS: accepted Sylvia -> Schedule Done -> physical Hospital -> witness -> recovered Day 2 desktop")
	quit(0)


func _sylvia_care_journey(game: Node, before: Dictionary) -> void:
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop.open_app(&"contacts").get("ok", false), "Contacts opens for next-day care"): return
	await _frames()
	var app: Node = desktop.get("_cached_app_windows")[&"contacts"]
	app.contacts_panel.open_requested.emit("sylvia")
	if not _check(app.last_result.get("ok", false), "actual Sylvia caring message opens: " + JSON.stringify(app.last_result)): return
	var after: Dictionary = _hospital_relationship_snapshot(game)
	if not _check(int(game.affection.sylvia) == clampi(int(before.affection.sylvia) + 2, -4, 10)
		and int(game.dating_route_state.sylvia.dark_points) == mini(int(before.dating.get("sylvia", {}).get("dark_points", 0)) + 1, 4)
		and game.dating_route_state.sylvia.relationship_state == "ambiguous"
		and game.friend_attitude.sylvia == "fixated", "care applies its fixed effect once"): return
	if not _check(preload("res://scripts/domain/contact/ContactInvitationState.gd").get_pending_sylvia_care(game.contacts, game.day).is_empty(),
		"care consumes its exact Hospital witness"): return
	var saved_contacts: Dictionary = game.contacts.duplicate(true)
	app.contacts_panel.open_requested.emit("sylvia")
	if not _check(app.last_result.get("ok", false) and game.contacts == saved_contacts and _hospital_relationship_snapshot(game) == after,
		"rereading Sylvia does not repeat care effects"): return
	var session: Dictionary = game.capture_live_session().value
	var saves: Node = root.get_node("SaveManager")
	var prepared: Dictionary = saves.prepare_restore_autosave()
	if not _check(prepared.get("ok", false), "care full Autosave prepares: " + JSON.stringify(prepared)): return
	var loaded: Dictionary = saves.commit_prepared_restore(prepared.value.prepared)
	if not _check(loaded.get("ok", false), "care full Autosave loads: " + JSON.stringify(loaded)): return
	await _frames()
	if not _check(game.capture_live_session().value.active and game.capture_live_session().value != session,
		"care Load activates a fresh session"): return
	if not _check(game.contacts == saved_contacts and _hospital_relationship_snapshot(game) == after,
		"care receipt and relationship effects survive full Load together"): return
	desktop = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null and desktop.open_app(&"contacts").get("ok", false), "Contacts reopens after care Load"): return
	await _frames()
	app = desktop.get("_cached_app_windows")[&"contacts"]
	app.contacts_panel.open_requested.emit("sylvia")
	if not _check(app.last_result.get("ok", false) and game.contacts == saved_contacts and _hospital_relationship_snapshot(game) == after,
		"restored care remains readable without duplicate effects"): return
	print("PLAYABLE_SYLVIA_CARE_PASS: actual Schedule Hospital -> next-day Sylvia read -> exact fixed effects -> Autosave Load -> harmless reread")
	quit(0)


func _hospital_relationship_snapshot(game: Node) -> Dictionary:
	return {"friends": game.friends.duplicate(true), "affection": game.affection.duplicate(true),
		"attitude": game.friend_attitude.duplicate(true), "dating": game.dating_route_state.duplicate(true)}


func _completed_load_journey(game: Node) -> void:
	var profile: Node = root.get_node("ProfileManager")
	var before_profile: Dictionary = profile.get_profile_snapshot()
	var before_plan: Dictionary = game._run_lifecycle.to_dict().ending_plan.duplicate(true)
	var replays: Array = []
	root.get_node("DialogicBridge").ending_playback_finished.connect(func(token: String, ending_id: String, receipt: Dictionary) -> void:
		replays.append({"token": token, "ending": ending_id, "receipt": receipt}))
	var login: Button = current_scene.get_node("%LogInButton")
	if not _check(not login.disabled, "completed Autosave Login is enabled"): return
	login.pressed.emit()
	await _frames()
	var picker: Node = current_scene.get("_backup_app_instance")
	if not _check(picker != null and picker.is_visible_in_tree(), "completed Login opens real Backup"): return
	picker.drawer_buttons["autosave"].pressed.emit()
	if not _check(not picker.action_buttons["load"].disabled, "completed Autosave Load enabled"): return
	picker.action_buttons["load"].pressed.emit()
	if is_instance_valid(picker.confirmation): picker.confirmation.confirm_button.pressed.emit()
	var loaded: Dictionary = picker.last_result.duplicate(true)
	await _frames()
	if not _check(current_scene.has_node("%NewAccButton") and not game.capture_live_session().value.active,
		"completed Load returns to title with retired session: " + JSON.stringify(loaded)): return
	if not _check(game.day == 7 and game._run_lifecycle.to_dict().ending_plan == before_plan,
		"completed Load retains the exact final plan and never advances the day"): return
	if not _check(replays.is_empty() and profile.get_profile_snapshot() == before_profile,
		"completed Load neither replays the ending nor rewrites Profile"): return
	print("PLAYABLE_COMPLETED_LOAD_PASS: actual title Login -> completed Autosave -> no replay -> retired title")
	quit(0)


func _pause_save_board(game: Node, route: String) -> Dictionary:
	if route == "dating": return game.capture_dating_challenge_state().value.duplicate(true)
	var owner: Dictionary = root.get_node("ApplicationBootstrap").get("_desktop_board_state").capture()
	if owner.get("candidate") is Dictionary:
		return {"phase": owner.phase, "candidate": owner.candidate.duplicate(true)}
	if not owner.get("board") is Dictionary: return {}
	return {"board": owner.board.board.duplicate(true),
		"spec": owner.board.get("spec", {"difficulty": owner.board.paid_start_receipt.difficulty_id}).duplicate(true),
		"phase": "terminal" if owner.board.board.terminal else "active"}


func _pause_save_load_journey(game: Node, controller: Node) -> void:
	var route: String = root.get_node("SceneRouter").get_current_route_id()
	var before: Dictionary = _pause_save_board(game, route)
	var prior_session: Dictionary = game.capture_live_session().value
	var profile: Node = root.get_node("ProfileManager")
	var prior_profile: Dictionary = profile.get_profile_snapshot()
	controller.surface.rows[&"backup"].pressed.emit()
	await _frames()
	var backup: Control = controller.surface.get("_hosts")[&"backup"]
	if not _check(backup.is_visible_in_tree(), "actual Pause Backup opens"): return
	backup.drawer_buttons["slot:1"].pressed.emit()
	if not _check(not backup.action_buttons["save"].disabled,
		"manual Save is available on the paused source: " + JSON.stringify(backup.last_result)): return
	backup.action_buttons["save"].pressed.emit()
	if is_instance_valid(backup.confirmation): backup.confirmation.confirm_button.pressed.emit()
	await _frames()
	if not _check(backup.last_result.get("ok", false), "actual paused Save commits: " + JSON.stringify(backup.last_result)): return
	if not _check(paused and controller.surface.visible and _pause_save_board(game, route) == before,
		"Save retains Pause custody and exact board"): return
	await _capture_screen("07-pause-backup-save")
	backup.mode_buttons["load"].pressed.emit()
	await _frames()
	if not _check(not backup.action_buttons["load"].disabled, "saved manual slot can Load"): return
	backup.action_buttons["load"].pressed.emit()
	if not _check(is_instance_valid(backup.confirmation), "paused Load requires confirmation"): return
	backup.confirmation.confirm_button.pressed.emit()
	var loaded: Dictionary = backup.last_result.duplicate(true)
	for frame: int in 40:
		await process_frame
		if not paused and root.get_node("SceneRouter").get_current_route_id() == route and game.capture_live_session().value != prior_session: break
	if not _check(not paused and root.get_node("SceneRouter").get_current_route_id() == route and game.capture_live_session().value.active,
		"Pause Load publishes the playable source: " + JSON.stringify({"load": loaded, "pause": controller.last_result})): return
	var after: Dictionary = _pause_save_board(game, route)
	# Saved JSON restores StringName outcomes as String and typed arrays as arrays.
	# Compare every field through the same strict canonical writer used by persistence.
	var writer := preload("res://scripts/validation/CanonicalJsonWriter.gd")
	var before_text: Dictionary = writer.stringify(before)
	var after_text: Dictionary = writer.stringify(after)
	if not _check(before_text.get("ok", false) and after_text.get("ok", false)
		and before_text.value == after_text.value,
		"manual Load restores the exact saved board, spec, and phase: " + JSON.stringify({"before": before_text, "after": after_text})): return
	if not _check(game.capture_live_session().value != prior_session and profile.get_profile_snapshot() == prior_profile,
		"manual Load creates a fresh session without changing Profile history"): return
	await _capture_screen("08-restored-" + route + "-board")
	print("PLAYABLE_PAUSE_SAVE_LOAD_PASS: actual Back -> Backup -> manual Save -> confirmed Load -> exact playable board")
	if not OS.get_cmdline_user_args().has("--probe-board-controls") and not OS.get_cmdline_user_args().has("--probe-desktop-debug") and not OS.get_cmdline_user_args().has("--probe-terminal-save"): quit(0)


## Optional GPU-only correspondence journey. No synthetic line draw or canonical reply/echo seed.
func _ordinary_reply_journey(game: Node, desktop: Node) -> bool:
	if not _check(desktop.open_app(&"contacts").get("ok", false), "ordinary reply opens actual Contacts"): return false
	await _frames()
	var app: Node = desktop.get("_cached_app_windows")[&"contacts"]
	app.contacts_panel.open_requested.emit("lavinia")
	await _frames()
	if not _check(app.last_result.get("ok", false), "Lavinia ordinary thread opens: " + JSON.stringify(app.last_result)): return false
	var choice: Button = app.find_child("OrdinaryReplyA", true, false)
	if not _check(choice != null and choice.is_visible_in_tree() and not choice.disabled,
		"actual registered A choice is visible"): return false
	var before: Dictionary = _ordinary_neutral_state(game)
	var profile_before: Dictionary = root.get_node("ProfileManager").get_profile_snapshot()
	var contacts_before: Dictionary = game.contacts.duplicate(true)
	choice.pressed.emit()
	# The actual outgoing Label.draw callback admits and saves the choice on a later frame.
	for frame: int in 180:
		await process_frame
		if game.get_pending_ordinary_echoes().size() == 1: break
	var pending: Array[Dictionary] = game.get_pending_ordinary_echoes()
	if not _check(pending.size() == 1, "one real rendered reply commits one pending echo: " + JSON.stringify({"ui": app.last_result, "pending": app.get("_ordinary_pending"), "busy": app.get("_ordinary_busy"), "gate": root.get_node("ApplicationBootstrap").get("_application_gate").get_active_owner()})): return false
	var echo: Dictionary = pending[0]
	if not _check(echo.reply_id == "reply.ordinary.lavinia.day1.a" and echo.day == 1,
		"pending echo preserves actual A source"): return false
	_ordinary_reply_receipt = game.contacts.transaction_receipts[echo.reply_transaction_id].duplicate(true)
	if not _check(_ordinary_reply_receipt.rendered_line.line_id == "line.contact.ordinary.lavinia.day1.reply.a",
		"saved reply owns exact registered rendered line"): return false
	var owned: Array = []
	for message: Dictionary in game.contacts.messages.lavinia:
		if message.get("parameters", {}).get("reply_transaction_id") == echo.reply_transaction_id: owned.append(message)
	if not _check(owned.size() == 3 and game.contacts.messages.lavinia.size() == contacts_before.messages.lavinia.size() + 3,
		"one reply atomically owns incoming, outgoing and scripted response history"): return false
	if not _check(owned[0].type == "ordinary_incoming" and owned[1].type == "ordinary_reply" and owned[2].type == "ordinary_response",
		"ordinary history has the promised three rows"): return false
	if not _check(_ordinary_neutral_state(game) == before and root.get_node("ProfileManager").get_profile_snapshot() == profile_before,
		"ordinary A reply changes no stats, relationship, board or Profile facts"): return false
	await _frames()
	await _capture_screen("11-ordinary-lavinia-reply")
	if not _check(desktop.return_home().get("ok", false), "Home after saved ordinary reply"): return false
	print("PLAYABLE_ORDINARY_REPLY_PASS: actual Contacts -> Lavinia A -> real Label draw -> three durable rows and one neutral echo")
	return true

func _ordinary_day6_invitation(game: Node, desktop: Node) -> bool:
	if not _check(game.day == 6 and desktop.open_app(&"minesweeper").get("ok", false),
		"Day 6 real Minesweeper opens for unread invitation"): return false
	await _frames()
	var app: Node = desktop.get("_cached_app_windows")[&"minesweeper"]
	var panel: Control = app.panel
	if not _check(panel.has_valid_presentation() and not panel.public_view.settled, "Day 6 fresh board is playable"): return false
	var finished_before: int = game.minesweeper_app_rounds_finished_today
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "Day 6 actual first Reveal starts a round"): return false
	if not panel.public_view.board.terminal:
		# Only this test fixture inspects hidden mines to select input; production Reveal settles it.
		var board: Dictionary = root.get_node("ApplicationBootstrap").get("_desktop_board_state").capture().board.board
		panel.worksheet.cell_action_requested.emit(&"reveal", int(board.mine_indices[0]), int(panel.public_view.board.revision))
	if not await _wait_app_round_settled(game, app, finished_before): return false
	if not _check(game.contacts.solo_actions.get("solo:priscilla:day6", {}).get("state") == "AVAILABLE",
		"Priscilla Day 6 invitation remains genuinely unread"): return false
	if not _check(desktop.return_home().get("ok", false), "Home without reading Day 6 invitation"): return false
	return true

func _wait_app_round_settled(game: Node, app: Node, finished_before: int) -> bool:
	# The real app owns deferred settlement; this fixture only observes its result.
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if not _check(is_instance_valid(app) and is_instance_valid(app.panel), "round keeps its real app surface"): return false
		if not _check(app.last_result.get("ok", false), "round settlement: " + JSON.stringify(app.last_result)): return false
		if app.panel.has_valid_presentation() and app.panel.public_view.board.terminal and app.panel.public_view.settled:
			return _check(game.minesweeper_app_rounds_finished_today == finished_before + 1,
				"settled round publishes exactly one finished-round increment")
		await process_frame
	return _check(false, "real app did not finish deferred round settlement before the deadline")

func _ordinary_day7_prelude_journey(game: Node) -> bool:
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	var owner: Node = await _ordinary_wait_prelude_draw(bootstrap, &"acknowledged")
	if owner == null: return false
	var followup_receipt: Dictionary = owner.get("_receipt").duplicate(true)
	var followup_surface: CanvasLayer = owner.get("_surface")
	var exact_followup := false
	for message: Dictionary in game.contacts.messages.get(str(followup_receipt.get("friend_id", "")), []):
		if message.get("message_id") == followup_receipt.get("message_id") \
				and message.get("sequence") == followup_receipt.get("sequence"):
			exact_followup = int(message.get("target_day", 0)) == 7 \
				and str(message.get("type", "")) in ["nevermind", "missed_question", "busy", "judge"]
			break
	if not _check(game.day == 7 and followup_receipt.get("kind") == "day7_followup"
		and followup_receipt.get("friend_id") == "priscilla" and exact_followup,
		"real unread Day 6 invitation renders the mandatory Day 7 followup first"): return false
	if not _check(game.get_pending_day7_followups().is_empty()
		and bool(followup_surface.call("is_card_acknowledged", followup_receipt)),
		"a fully drawn followup is durably witnessed but remains on its staging card"): return false
	var pending_echoes: Array[Dictionary] = game.get_pending_ordinary_echoes()
	if not _check(not _ordinary_reply_receipt.is_empty() and pending_echoes.size() == 1,
		"Day 1 selected reply survives every daily Autosave"): return false
	var profile: Node = root.get_node("ProfileManager")
	var original_auto_enabled: bool = bool(profile.get_preference(&"preferences.reading.auto_enabled", false))
	var original_auto_delay: String = str(profile.get_preference(&"preferences.reading.auto_delay", "normal"))
	if not _ordinary_assert_day7_guards(bootstrap, game): return false
	var initial_contacts: Dictionary = game.contacts.duplicate(true)
	var satisfied_before := _ordinary_satisfied_count(game.contacts)
	if not await _ordinary_pause_continue_prelude(game, bootstrap, owner, followup_surface, followup_receipt): return false
	if not await _capture_screen("12-day7-followup"): return false
	var original_writer: Callable = game.get("_contact_checkpoint_writer")
	if not _check(original_writer.is_valid(), "real contact checkpoint writer is installed before failure injection"): return false
	var failed_writer := FailOneContactCheckpoint.new(original_writer)
	game.set("_contact_checkpoint_writer", failed_writer.write)
	var followup_next: Button = followup_surface.get("_next")
	if not _check(followup_next.is_visible_in_tree() and not followup_next.disabled,
		"durably witnessed followup remains visible with a fresh Next command"): return false
	var auto_started_msec := Time.get_ticks_msec()
	var enabled_auto: Dictionary = profile.set_preferences({
		&"preferences.reading.auto_enabled": true,
		&"preferences.reading.auto_delay": "short",
	})
	if not _check(enabled_auto.get("ok", false),
		"committed Reading preferences enable Day 7 Auto at the short cadence: " + JSON.stringify(enabled_auto)): return false
	await _frames()
	var auto_state: Label = followup_surface.find_child("AutoReadingState", true, false) as Label
	if not _check(is_instance_valid(auto_state) and auto_state.text == "Auto On",
		"the production Day 7 surface projects the committed Auto On preference"): return false
	if not _check(owner.get("_receipt") == followup_receipt and failed_writer.failures == 0,
		"Auto does not advance the intermediate card before one eligible foreground second"): return false
	owner = await _ordinary_wait_prelude_draw(bootstrap, &"retry")
	if owner == null: return false
	if not _check(Time.get_ticks_msec() - auto_started_msec >= 900,
		"Auto advances the intermediate card only after the actual short foreground delay"): return false
	var old_command: Dictionary = owner.get("_command").duplicate(true)
	var old_receipt: Dictionary = owner.get("_receipt").duplicate(true)
	var old_surface: CanvasLayer = owner.get("_surface")
	var old_owner_id: int = owner.get_instance_id()
	var session: Dictionary = game.capture_live_session().value.duplicate(true)
	var saved_contacts: Dictionary = game.contacts.duplicate(true)
	game.set("_contact_checkpoint_writer", original_writer)
	if not _check(failed_writer.failures == 1 and not owner.last_result.get("ok", false)
		and owner.last_result.get("code") == &"injected_ordinary_echo_write_failure",
		"the first visible echo acknowledgment reports its injected durable save failure"): return false
	if not _check(old_receipt.entry_id == "echo.fallback.day7"
		and old_receipt.echo_id == pending_echoes[0].echo_id
		and old_receipt.presentation_atom_id == pending_echoes[0].presentation_atom_id,
		"first unsatisfied echo owns the exact rendered fallback atom"): return false
	if not _check(not bool(old_surface.call("is_card_acknowledged", old_receipt))
		and game.get_pending_ordinary_echoes() == pending_echoes and game.contacts == initial_contacts,
		"failed receipt keeps the rendered echo and its durable obligation pending"): return false
	var failed_history: Array[Dictionary] = old_surface.get_presentation_history()
	if not _check(failed_history.size() == 2 and failed_history[0].receipt == followup_receipt
		and failed_history[1].receipt == old_receipt,
		"one physical surface draws the exact followup then the exact echo without duplication"): return false
	var retry: Button = old_surface.get("_next")
	if not _check(retry.text == "Retry" and retry.is_visible_in_tree() and not retry.disabled,
		"failed echo exposes Retry on the same receipt without navigating"): return false
	await _frames()
	if not _check(is_instance_valid(bootstrap.get("_day7_prelude_owner"))
		and bootstrap.get("_day7_prelude_owner").get_instance_id() == old_owner_id
		and owner.get("_receipt") == old_receipt and failed_writer.failures == 1,
		"failed Retry state holds the same owner, receipt and card without an implicit retry or advance"): return false
	if not _ordinary_assert_day7_guards(bootstrap, game): return false
	if not await _ordinary_pause_load_autosave(game, owner, old_surface, old_receipt,
			saved_contacts, pending_echoes): return false
	for frame: int in 180:
		await process_frame
		var replacement: Variant = bootstrap.get("_day7_prelude_owner")
		if is_instance_valid(replacement) and replacement.get_instance_id() != old_owner_id: break
	owner = await _ordinary_wait_prelude_draw(bootstrap, &"acknowledged")
	if owner == null: return false
	if not _check(owner.get_instance_id() != old_owner_id and game.capture_live_session().value.active
		and game.capture_live_session().value != session, "mid-prelude Load mounts a fresh owner and live session"): return false
	var receipt: Dictionary = owner.get("_receipt").duplicate(true)
	var surface: CanvasLayer = owner.get("_surface")
	if not _check(receipt.echo_id == old_receipt.echo_id and receipt.presentation_atom_id == old_receipt.presentation_atom_id
		and receipt.view_token != old_receipt.view_token, "same pending atom receives a fresh exact presentation token"): return false
	if not _check(game.get_pending_ordinary_echoes().is_empty()
		and bool(surface.call("is_card_acknowledged", receipt))
		and game.require_day7_presentations_complete().get("ok", false),
		"fresh full draw durably acknowledges the echo while its accepted card remains visible"): return false
	var restored_history: Array[Dictionary] = surface.get_presentation_history()
	if not _check(restored_history.size() == 1 and restored_history[0].receipt == receipt,
		"fresh surface redraws the resumed echo exactly once"): return false
	var accepted_contacts: Dictionary = game.contacts.duplicate(true)
	var stale: Dictionary = game.commit_ordinary_echo(old_command, old_receipt)
	if not _check(not stale.get("ok", false) and game.contacts == accepted_contacts,
		"old view cannot acknowledge after Load or mutate the accepted receipt"): return false
	var final_auto_hold_until := Time.get_ticks_msec() + 1250
	while Time.get_ticks_msec() < final_auto_hold_until:
		await process_frame
	var restored_auto_state: Label = surface.find_child("AutoReadingState", true, false) as Label
	if not _check(is_instance_valid(bootstrap.get("_day7_prelude_owner"))
		and bootstrap.get("_day7_prelude_owner").get_instance_id() == owner.get_instance_id()
		and bool(surface.call("is_card_acknowledged", receipt))
		and is_instance_valid(restored_auto_state) and restored_auto_state.text == "Auto On",
		"Auto remains visibly On but cannot leave the final acknowledged card or complete the route"): return false
	if not await _capture_screen("13-day7-restored-echo"): return false
	var next: Button = surface.get("_next")
	if not _check(next.is_visible_in_tree() and not next.disabled, "accepted echo exposes its real Next button"): return false
	if not await _ordinary_accept_focused(next, "restored Day 7 echo Next"): return false
	var restored_preferences: Dictionary = profile.set_preferences({
		&"preferences.reading.auto_enabled": original_auto_enabled,
		&"preferences.reading.auto_delay": original_auto_delay,
	})
	if not _check(restored_preferences.get("ok", false)
		and profile.get_preference(&"preferences.reading.auto_enabled") == original_auto_enabled
		and profile.get_preference(&"preferences.reading.auto_delay") == original_auto_delay,
		"the native Auto journey restores the original committed Reading preferences"): return false
	for frame: int in 180:
		await process_frame
		if not is_instance_valid(bootstrap.get("_day7_prelude_owner")): break
	if not _check(game.get_pending_day7_followups().is_empty() and game.get_pending_ordinary_echoes().is_empty()
		and game.require_day7_presentations_complete().get("ok", false), "all mandatory presentations drain and gameplay guard clears"): return false
	if not _check(game.contacts.transaction_receipts[_ordinary_reply_receipt.transaction_id] == _ordinary_reply_receipt
		and _ordinary_satisfied_count(game.contacts) == satisfied_before + 1, "original reply is immutable and exact echo satisfies only once"): return false
	if not _check(game.contacts.messages == initial_contacts.messages and game.day == 7,
		"prelude adds no message duplicates and never advances the day"): return false
	await _frames()
	if not _check(not is_instance_valid(bootstrap.get("_day7_prelude_owner")), "finished prelude retires its surface"): return false
	print("PLAYABLE_ORDINARY_ECHO_PASS: real A reply -> witnessed Day 6 followup -> short foreground Auto -> guarded failed echo save -> Autosave Load -> final Auto hold -> fresh Next -> playable Day 7")
	return true


func _ordinary_pause_continue_prelude(game: Node, bootstrap: Node, owner: Node,
		surface: CanvasLayer, receipt: Dictionary) -> bool:
	var router: Node = root.get_node("SceneRouter")
	var controller: Node = router.get("_production_pause")
	if not _check(is_instance_valid(controller), "production Pause controller owns the Day 7 overlay"): return false
	var before := {"session": game.capture_live_session().value.duplicate(true),
		"owner_id": owner.get_instance_id(), "view_id": surface.get_instance_id(),
		"command": owner.get("_command").duplicate(true), "receipt": receipt.duplicate(true),
		"history": surface.get_presentation_history(), "scroll": surface.get("_scroll").scroll_vertical,
		"contacts": game.contacts.duplicate(true), "followups": game.get_pending_day7_followups(),
		"echoes": game.get_pending_ordinary_echoes()}
	var events := {"acknowledged": 0, "advanced": 0}
	surface.card_acknowledged.connect(func(_seen: Dictionary, _result: Dictionary) -> void:
		events.acknowledged += 1)
	surface.advance_requested.connect(func(_seen: Dictionary) -> void:
		events.advanced += 1)
	if not _check(surface.get("_next").has_focus(), "accepted followup owns focus before Pause"): return false
	await _pause_key()
	if not _check(paused and controller.surface.is_visible_in_tree() and not surface.visible
		and controller.surface.rows[&"continue"].has_focus(),
		"Day 7 Back covers its surface and opens universal Pause with Continue focused"): return false
	if not await _capture_screen("14-day7-paused-followup"): return false
	if not _check(owner.get_instance_id() == before.owner_id and surface.get_instance_id() == before.view_id
		and owner.get("_command") == before.command and owner.get("_receipt") == before.receipt
		and surface.get_presentation_history() == before.history
		and surface.get("_scroll").scroll_vertical == before.scroll,
		"Pause freezes the exact Day 7 owner, card, history and scroll"): return false
	if not _check(game.capture_live_session().value == before.session and game.contacts == before.contacts
		and game.get_pending_day7_followups() == before.followups
		and game.get_pending_ordinary_echoes() == before.echoes and events == {"acknowledged": 0, "advanced": 0},
		"opening Pause publishes no receipt, navigation, session or correspondence change"): return false
	if not await _ordinary_accept_focused(controller.surface.rows[&"continue"], "Pause Continue"): return false
	if not _check(not paused and not controller.surface.visible
		and is_instance_valid(bootstrap.get("_day7_prelude_owner"))
		and bootstrap.get("_day7_prelude_owner").get_instance_id() == before.owner_id,
		"Continue restores the same Day 7 owner instead of reconstructing it"): return false
	if not _check(game.capture_live_session().value == before.session and owner.get("_command") == before.command
		and owner.get("_receipt") == before.receipt and surface.get_presentation_history() == before.history
		and surface.get("_scroll").scroll_vertical == before.scroll and game.contacts == before.contacts
		and game.get_pending_day7_followups() == before.followups
		and game.get_pending_ordinary_echoes() == before.echoes and events == {"acknowledged": 0, "advanced": 0},
		"Continue changes no Day 7 receipt, history, pending work or durable state"): return false
	return _check(surface.get("_next").has_focus() and surface.is_card_acknowledged(receipt),
		"Continue restores exact accepted-card focus after release quarantine")


func _ordinary_pause_load_autosave(game: Node, owner: Node,
		surface: CanvasLayer, receipt: Dictionary, contacts: Dictionary,
		pending_echoes: Array[Dictionary]) -> bool:
	var router: Node = root.get_node("SceneRouter")
	var controller: Node = router.get("_production_pause")
	var session: Dictionary = game.capture_live_session().value.duplicate(true)
	var owner_id: int = owner.get_instance_id()
	var history: Array[Dictionary] = surface.get_presentation_history()
	var scroll: int = surface.get("_scroll").scroll_vertical
	if not _check(surface.get("_next").has_focus(), "failed echo Retry owns focus before Pause Load"): return false
	await _pause_key()
	if not _check(paused and controller.surface.visible and not surface.visible
		and controller.surface.rows[&"continue"].has_focus(),
		"failed echo is covered while universal Pause opens without retrying"): return false
	controller.surface.rows[&"backup"].pressed.emit()
	await _frames()
	var backup: Control = controller.surface.get("_hosts")[&"backup"]
	if not _check(backup.is_visible_in_tree(), "actual Pause Backup opens over the failed echo"): return false
	backup.mode_buttons["load"].pressed.emit()
	backup.drawer_buttons["autosave"].pressed.emit()
	await _frames()
	if not _check(not backup.action_buttons["load"].disabled,
		"the real Day 7 Autosave is available through hosted Backup: " + JSON.stringify(backup.last_result)): return false
	if not _check(game.capture_live_session().value == session and owner.get_instance_id() == owner_id
		and owner.get("_receipt") == receipt and surface.get_presentation_history() == history
		and surface.get("_scroll").scroll_vertical == scroll and game.contacts == contacts
		and game.get_pending_ordinary_echoes() == pending_echoes,
		"Pause and Backup inspection retain the failed exact echo without navigation"): return false
	backup.action_buttons["load"].pressed.emit()
	if not _check(is_instance_valid(backup.confirmation), "Pause Autosave Load requires its real confirmation"): return false
	if not _check(not surface.visible,
		"the failed Day 7 echo surface remains covered during Autosave confirmation"): return false
	if not await _capture_screen("15-day7-pause-autosave-confirmation"): return false
	var saves: Node = root.get_node("SaveManager")
	var restore_observation: Dictionary = {}
	var observe_restore: Callable = func() -> void:
		if not restore_observation.is_empty(): return
		var live: Dictionary = game.capture_live_session()
		restore_observation["session_ok"] = live.get("ok", false)
		restore_observation["session"] = live.get("value", {}).duplicate(true)
		restore_observation["contacts"] = game.contacts.duplicate(true)
		restore_observation["followups"] = game.get_pending_day7_followups().duplicate(true)
		restore_observation["echoes"] = game.get_pending_ordinary_echoes().duplicate(true)
	if not _check(saves.connect(&"live_session_ready", observe_restore, CONNECT_ONE_SHOT) == OK,
		"observe the real live-session restore boundary before confirming Autosave Load"): return false
	backup.confirmation.confirm_button.pressed.emit()
	for frame: int in 180:
		await process_frame
		if not paused and game.capture_live_session().value.active \
				and game.capture_live_session().value != session: break
	if saves.is_connected(&"live_session_ready", observe_restore):
		saves.disconnect(&"live_session_ready", observe_restore)
	if not _check(not restore_observation.is_empty()
		and bool(restore_observation.get("session_ok", false))
		and bool(restore_observation.get("session", {}).get("active", false))
		and restore_observation.get("session", {}) != session
		and restore_observation.get("contacts", {}) == contacts
		and restore_observation.get("followups", []) == []
		and restore_observation.get("echoes", []) == pending_echoes,
		"live_session_ready exposes the fresh session with exact saved Contacts, pending echo and no followups before redraw: "
			+ JSON.stringify(restore_observation)): return false
	return _check(not paused and not controller.surface.visible
		and game.capture_live_session().value.active and game.capture_live_session().value != session
		and backup.last_result.get("ok", false),
		"confirmed Pause Autosave Load closes Pause and publishes a fresh live session: "
			+ JSON.stringify({"backup": backup.last_result, "pause": controller.last_result}))

func _ordinary_wait_prelude_draw(bootstrap: Node, expected_state: StringName) -> Node:
	# Auto includes real elapsed reading time, independent of display refresh rate.
	var deadline_msec := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline_msec:
		await process_frame
		var owner: Variant = bootstrap.get("_day7_prelude_owner")
		if not is_instance_valid(owner): continue
		var surface: Variant = owner.get("_surface")
		if not is_instance_valid(surface) or not bool(surface.get("_drawn")): continue
		var receipt: Dictionary = owner.get("_receipt")
		var next: Button = surface.get("_next")
		if not next.is_visible_in_tree() or next.disabled: continue
		var acknowledged: bool = bool(surface.call("is_card_acknowledged", receipt))
		if expected_state == &"acknowledged" and acknowledged: return owner
		var status: Label = surface.get("_status")
		if expected_state == &"retry" and not acknowledged and not status.text.is_empty(): return owner
	var owner: Variant = bootstrap.get("_day7_prelude_owner")
	var details := {}
	if is_instance_valid(owner):
		details["result"] = owner.last_result
		var surface: Variant = owner.get("_surface")
		if is_instance_valid(surface):
			details.merge({"drawn": surface._drawn, "accepted": surface._accepted, "busy": surface._busy,
				"aperture": surface._scroll.get_global_rect(),
				"viewport": surface._root.get_viewport_rect(), "scroll": surface._scroll.scroll_vertical})
			if is_instance_valid(surface._current_body): details["body"] = surface._current_body.get_global_rect()
	await _capture_screen("day7-presentation-failure")
	_check(false, "actual Day 7 staging card did not reach %s after its full draw: %s" % [expected_state, JSON.stringify(details)])
	return null

func _ordinary_assert_day7_guards(bootstrap: Node, game: Node) -> bool:
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var board_before: Dictionary = bootstrap.get("_desktop_board_state").capture().duplicate(true)
	var profile_before: Dictionary = root.get_node("ProfileManager").get_profile_snapshot()
	# Direct source entry points deliberately bypass overlay UI to prove the saved obligation wins
	# before any stale command/quote/request can start a transaction or spend a resource.
	var shop: Dictionary = bootstrap.get("_retained_game_state_minesweeper_shop_port").prepare_purchase(
		{"item_id": "coffee"}, {"item_id": "coffee"}, "probe-mandatory-prelude", {})
	var board: Dictionary = bootstrap.get("_retained_minesweeper_round_coordinator_app").reveal({})
	var done: Dictionary = bootstrap.get("_retained_day_resolution_state_port").begin_or_resume("probe-mandatory-prelude")
	for result: Dictionary in [shop, board, done]:
		if not _check(not result.get("ok", false) and result.get("code") == &"day7_presentations_pending",
			"direct Shop, board and Done refuse pending presentation: " + JSON.stringify(result)): return false
	return _check(game.capture_run_snapshot_input() == before and bootstrap.get("_desktop_board_state").capture() == board_before
		and root.get_node("ProfileManager").get_profile_snapshot() == profile_before, "blocked Day 7 commands mutate no Run, board or Profile state")

func _ordinary_neutral_state(game: Node) -> Dictionary:
	return {"relationships": _hospital_relationship_snapshot(game), "stats": game.stats.duplicate(true),
		"money": game.money, "coins": game.coins, "inventory": game.inventory.duplicate(true),
		"rounds": game.minesweeper_rounds_left, "pair": game.inter_friend_route_state.duplicate(true),
		"board": root.get_node("ApplicationBootstrap").get("_desktop_board_state").capture().duplicate(true)}

func _ordinary_satisfied_count(contacts: Dictionary) -> int:
	var count := 0
	for receipt: Dictionary in contacts.transaction_receipts.values():
		if receipt.get("kind") == "ordinary_echo_presented": count += 1
	return count


## Real controls, persisted shell, and a paid replacement across a full session change.
func _board_controls_journey(game: Node, desktop: Node, app: Node) -> void:
	var panel: Control = app.panel
	var board_owner: RefCounted = root.get_node("ApplicationBootstrap").get("_desktop_board_state")
	var rounds: int = game.minesweeper_rounds_left
	var motivation: int = game.get_stat("motivation")
	panel.register.difficulty_requested.emit(&"intermediate")
	if not _check(app.last_result.get("ok", false) and panel.public_view.board.width == 16,
		"actual difficulty control selects an unpaid intermediate shell"): return
	for action: StringName in [&"flag", &"unflag"]:
		panel.worksheet.cell_action_requested.emit(action, 1, int(panel.public_view.board.revision))
		if not _check(app.last_result.get("ok", false), "unpaid shell action " + str(action)): return
	var shell: Dictionary = board_owner.capture()
	if not _check(shell.phase == "UNPAID_UNSTARTED" and shell.candidate.actions.size() == 2
		and shell.candidate.flagged_indices.is_empty() and shell.identity == null,
		"unpaid Flag/Unflag records history without a layout or paid identity"): return
	if not _check(game.minesweeper_rounds_left == rounds and game.get_stat("motivation") == motivation,
		"unpaid configuration and flags are free"): return
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "first Reveal accepts shell history"): return
	var paid: Dictionary = board_owner.capture()
	if not _check(paid.board is Dictionary and not paid.board.board.terminal
		and paid.board.board.actions == shell.candidate.actions
		and panel.public_view.register.no_flag == "lost", "first board preserves the No-flag latch"): return
	if not _check(game.minesweeper_rounds_left == rounds - 1 and game.get_stat("motivation") == motivation - 1,
		"first physical Reveal charges exactly once"): return
	panel.register.difficulty_requested.emit(&"expert")
	if not _check(app.last_result.get("ok", false) and panel.public_view.board.width == 22 and panel.public_view.board.height == 22,
		"active difficulty control selects an expert replacement"): return
	panel.worksheet.cell_action_requested.emit(&"flag", 1, int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "paid replacement allows an unstarted flag"): return
	var replacement: Dictionary = board_owner.capture()
	if not _check(replacement.phase == "PAID_UNSTARTED" and replacement.identity == paid.identity
		and replacement.candidate.paid_start_receipt == paid.board.paid_start_receipt
		and replacement.candidate.spec.difficulty_id == "expert" and replacement.candidate.flagged_indices == [1],
		"replacement retains original payment and freezes current expert spec"): return
	await _capture_screen("03-paid-replacement-shell")
	await _pause_journey(game)
	if not _check(not paused and game.capture_live_session().value.active, "paid shell Load resumes live session"): return
	desktop = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null and desktop.open_app(&"minesweeper").get("ok", false),
		"restored paid shell reopens through actual desktop icon"): return
	await _frames()
	app = desktop.get("_cached_app_windows")[&"minesweeper"]
	panel = app.panel
	panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "restored paid replacement accepts first Reveal"): return
	var resumed: Dictionary = board_owner.capture()
	if not _check(resumed.board is Dictionary and resumed.board.board.width == 22 and resumed.board.board.height == 22
		and resumed.board.board.flagged_indices == [1], "restored board preserves selected tier and flag"): return
	if not _check(game.minesweeper_rounds_left == rounds - 1 and game.get_stat("motivation") == motivation - 1,
		"revealing a paid replacement after Load never charges twice"): return
	panel.dock.action_requested.emit(&"new_board")
	if not _check(app.last_result.get("ok", false) and board_owner.capture().phase == "PAID_UNSTARTED",
		"actual New Board replaces the current paid board"): return
	if not _check(game.minesweeper_rounds_left == rounds - 1 and game.get_stat("motivation") == motivation - 1,
		"New Board also retains exactly one paid start"): return
	await _capture_screen("09-restored-replacement-new-board")
	print("PLAYABLE_BOARD_CONTROLS_PASS: unpaid difficulty/flags -> first paid Reveal -> expert replacement -> flag -> Pause Save/Load -> free Reveal -> New Board")
	quit(0)


func _desktop_debug_journey(game: Node, desktop: Node, app: Node) -> void:
	var board_owner: RefCounted = root.get_node("ApplicationBootstrap").get("_desktop_board_state")
	var rounds: int = game.minesweeper_rounds_left
	var motivation: int = game.get_stat("motivation")
	app.get_window().grab_focus()
	# The real foreground handler begins preparation; later frames run the search slices.
	app._process(0.0)
	var preparing: Dictionary = board_owner.capture()
	if not _check(app.last_result.get("ok", false) and preparing.phase == "PREPARING"
		and preparing.candidate.frontier is Dictionary, "real Debug pump begins saved preparation"): return
	if not _check(desktop.return_home().get("ok", false), "Home parks real stable Debug frontier"): return
	await _frames()
	if not _check(board_owner.capture() == preparing, "hidden Debug board does not advance"): return
	await _pause_journey(game)
	if not _check(not paused and board_owner.capture().phase == "PREPARING", "manual Load restores Debug frontier"): return
	current_scene.get_window().grab_focus()
	await _frames()
	desktop = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null and desktop.open_app(&"minesweeper").get("ok", false),
		"cold restored Debug opens through actual desktop icon"): return
	app = desktop.get("_cached_app_windows")[&"minesweeper"]
	app.get_window().grab_focus()
	var started := Time.get_ticks_msec()
	while board_owner.capture().phase == "PREPARING" and Time.get_ticks_msec() - started < 90000:
		await process_frame
		if not app.last_result.get("ok", false):
			# Diagnostic exact retry is confined to this failing isolated probe; it never converts failure to a pass.
			var presentation: RefCounted = app.get("_port").get("_board_port")
			var coordinator: RefCounted = presentation.get("_owner")
			var context: Dictionary = presentation.get("_pending_preparation_context")
			var request: Dictionary = presentation.get("_pending_preparation_request")
			var retry: Dictionary = {}
			if not request.is_empty():
				retry = coordinator.call("begin_debug_preparation" if context.get("action") == "begin" else "run_debug_preparation_slice", request.duplicate(true))
			print("PLAYABLE_DEBUG_FAILURE_DETAIL: " + JSON.stringify({"ui": app.last_result, "pending_context": context,
				"readiness": coordinator.get_preparation_context(), "retry_ok": retry.get("ok", false),
				"retry_code": retry.get("code", ""), "retry_message": retry.get("message", ""), "retry_details": retry.get("details", {})}))
			_check(false, "visible Debug pump remains healthy")
			return
	if not _check(board_owner.capture().phase == "PREPARED_UNSTARTED", "real Debug search reaches certification"): return
	print("PLAYABLE_DESKTOP_DEBUG_PREPARED_MS: " + str(Time.get_ticks_msec() - started))
	var panel: Control = app.panel
	var revealable: Array[int] = []
	for cell: Dictionary in panel.public_view.board.cells:
		if "reveal" in cell.actions: revealable.append(int(cell.index))
	if not _check(revealable.size() == 1 and panel.public_view.board.cells[revealable[0]].bracketed,
		"certified shell exposes one bracketed first Reveal"): return
	if not _check(game.minesweeper_rounds_left == rounds and game.get_stat("motivation") == motivation,
		"preparation and Save/Load consume no round or motivation"): return
	await _capture_screen("09-debug-certified-shell")
	panel.worksheet.cell_action_requested.emit(&"reveal", revealable[0], int(panel.public_view.board.revision))
	if not _check(app.last_result.get("ok", false), "real forced Debug Reveal succeeds"): return
	if not _check(game.minesweeper_rounds_left == rounds - 1 and game.get_stat("motivation") == motivation - 1,
		"certified first Reveal charges exactly once"): return
	await _capture_screen("10-debug-first-reveal")
	print("PLAYABLE_DESKTOP_DEBUG_PASS: prepare -> Home -> Pause Save/Load -> cold reopen -> certification -> forced Reveal")
	quit(0)


func _inspection_resources(game: Node) -> Dictionary:
	return {"money": game.money, "motivation": game.get_stat("motivation"),
		"pressure": game.get_stat("pressure"), "health": game.get_stat("health"),
		"rounds": game.minesweeper_rounds_left, "finished": game.minesweeper_app_rounds_finished_today}

func _terminal_inspection_journey(game: Node, desktop: Node, app: Node) -> void:
	var register: Dictionary = app.panel.public_view.register.duplicate(true)
	var resources: Dictionary = _inspection_resources(game)
	await _capture_screen("03-settled-inspection")
	await _pause_journey(game)
	desktop = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null and desktop.open_app(&"minesweeper").get("ok", false), "saved terminal inspection reopens"): return
	await _frames()
	app = desktop.get("_cached_app_windows")[&"minesweeper"]
	if not _check(app.panel.public_view.settled and app.panel.public_view.board.terminal,
		"cold Load preserves actual finished-board inspection"): return
	if not _check(app.panel.public_view.register == register and _inspection_resources(game) == resources,
		"cold inspection preserves metrics and never settles rewards twice"): return
	await _capture_screen("09-restored-terminal-inspection")
	app.panel.dock.action_requested.emit(&"new_board")
	if not _check(app.last_result.get("ok", false) and not app.panel.public_view.settled,
		"actual New Board dismisses inspection durably"): return
	var session: Dictionary = game.capture_live_session().value
	var saves: Node = root.get_node("SaveManager")
	var prepared: Dictionary = saves.prepare_restore_autosave()
	if not _check(prepared.get("ok", false), "dismissed inspection Autosave prepares: " + JSON.stringify(prepared)): return
	var loaded: Dictionary = saves.commit_prepared_restore(prepared.value.prepared)
	if not _check(loaded.get("ok", false), "dismissed inspection Autosave loads"): return
	await _frames()
	desktop = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(game.capture_live_session().value != session and desktop != null
		and desktop.open_app(&"minesweeper").get("ok", false), "new-session desktop reopens after dismissal"): return
	await _frames()
	app = desktop.get("_cached_app_windows")[&"minesweeper"]
	if not _check(not app.panel.public_view.settled and not app.panel.public_view.board.terminal
		and _inspection_resources(game) == resources, "Load retains dismissal without payment or reward changes"): return
	await _capture_screen("10-terminal-dismissal-restored")
	print("PLAYABLE_TERMINAL_INSPECTION_PASS: finished board -> Pause Save/Load -> exact inspection/no second reward -> New Board -> Load preserves dismissal")
	quit(0)


func _message_popup_journey(game: Node, desktop: Node) -> void:
	await _frames()
	var popup: Control = desktop.message_notification
	var friend_id := str(popup.get_meta("friend_id", ""))
	var notification_id := str(popup.get_meta("notification_id", ""))
	if not _check(popup.visible and not friend_id.is_empty() and not notification_id.is_empty(), "real result shows a corner message notice"): return
	if not _check(game.is_contact_message_unlocked(friend_id), "notice names the actually unlocked message"): return
	if not _check(desktop.get("_active_id") == &"minesweeper", "notice appears over finished Minesweeper"): return
	desktop._on_contact_message_unlocked({"notification_id": notification_id, "friend_id": friend_id})
	if not _check(desktop.get("_message_notification_queue").is_empty(), "same publication cannot queue twice"): return
	await _capture_screen("message-notification")
	desktop.notification_go.pressed.emit()
	await _frames()
	if not _check(desktop.get("_active_id") == &"contacts", "Go leaves finished Minesweeper and opens Contacts"): return
	if not _check(not popup.visible, "successful Go dismisses the notice"): return
	await _capture_screen("message-notification-contacts")
	print("PLAYABLE_MESSAGE_POPUP_PASS: saved result -> real corner notice -> duplicate suppressed -> Go opens Contacts")
	quit(0)
