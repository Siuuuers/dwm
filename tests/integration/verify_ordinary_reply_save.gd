extends "res://tests/integration/verify_playable_startup.gd"
## Isolated public UI probe. The explicit locale fixture reproduces the reported setting.
## --reply-choice=A|B|C selects one registered first-day reply; A is the default.
var _reply_choice := "A"

func _initialize() -> void:
	var destination := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	var isolated_appdata := isolated.get_base_dir().path_join("appdata").to_lower()
	if not _check(not isolated.is_empty() and isolated.get_file() == "dwm_test_root" and destination.to_lower().begins_with(isolated_appdata + "/"), "reply probe requires isolated user directory"): return
	var choice_seen := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--reply-choice="):
			var requested := argument.trim_prefix("--reply-choice=")
			if not _check(not choice_seen and requested in ["A", "B", "C"], "reply choice must be one explicit A, B or C"): return
			_reply_choice = requested
			choice_seen = true
			continue
		if not argument.begins_with("--reply-seed-root="): continue
		var source := ProjectSettings.globalize_path(argument.trim_prefix("--reply-seed-root="))
		if not _copy_reply_seed(source, destination): return
	_run.call_deferred()

func _copy_reply_seed(source: String, destination: String) -> bool:
	var directory := DirAccess.open(source)
	if not _check(directory != null, "reply seed source exists"): return false
	if not _check(DirAccess.make_dir_recursive_absolute(destination) == OK, "reply seed target directory"): return false
	for folder: String in directory.get_directories():
		if folder == "logs": continue
		if not _copy_reply_seed(source.path_join(folder), destination.path_join(folder)): return false
	for filename: String in directory.get_files():
		if not _check(DirAccess.copy_absolute(source.path_join(filename), destination.path_join(filename)) == OK, "reply seed copied " + filename): return false
	return true

func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	var startup: Dictionary = bootstrap.get_startup_state()
	if not _check(startup.get("ready", false), "reply probe startup " + JSON.stringify(startup)): return
	var profile: Node = root.get_node("ProfileManager")
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.preferences.language = {"primary_locale_id": "zh_CN", "secondary_locale_id": "en", "dual_enabled": true}
	var localized: Dictionary = profile.commit_prepared_profile(candidate)
	if not _check(localized.get("ok", false), "reply locale fixture " + str(localized.get("code"))): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	if not _check(current_scene != null and current_scene.has_node("%NewAccButton"), "reply probe real title"): return
	if "--reply-login" in OS.get_cmdline_user_args():
		var login: Button = current_scene.get_node("%LogInButton")
		if not _check(not login.disabled, "reply saved Login available"): return
		login.pressed.emit()
		await _frames()
		var picker: Node = current_scene._backup_app_instance
		if not _check(picker != null and picker.is_visible_in_tree(), "reply real Login picker"): return
		picker.drawer_buttons["autosave"].pressed.emit()
		if not _check(not picker.action_buttons["load"].disabled, "reply Autosave Load available"): return
		picker.action_buttons["load"].pressed.emit()
		if is_instance_valid(picker.confirmation): picker.confirmation.confirm_button.pressed.emit()
	else:
		var menu: Node = current_scene
		menu.get_node("%NewAccButton").pressed.emit()
		await _frames()
		if is_instance_valid(menu) and is_instance_valid(menu._confirmation):
			if not _check(not str(menu._new_acc_token).is_empty(), "reply New Account has a real prepared replacement"): return
			menu._confirmation.confirm_button.pressed.emit()
	await _frames()
	var game: Node = root.get_node("GameState")
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop != null and game.capture_live_session().value.active, "reply probe active desktop"): return
	if "--reply-active-board" in OS.get_cmdline_user_args():
		if not _check(desktop.open_app(&"minesweeper").get("ok", false), "reply active board open"): return
		await _frames()
		var mines: Node = desktop._cached_app_windows[&"minesweeper"]
		mines.panel.worksheet.cell_action_requested.emit(&"reveal", 0, int(mines.panel.public_view.board.revision))
		if not _check(mines.last_result.get("ok", false), "reply prior first Reveal " + str(mines.last_result.get("code"))): return
		if not _check(desktop.return_home().get("ok", false), "reply Home after active board"): return
	var home: Dictionary = desktop.return_home()
	if not _check(home.get("ok", false), "reply Home " + JSON.stringify(home)): return
	var opened: Dictionary = desktop.open_app(&"contacts")
	if not _check(opened.get("ok", false), "reply Contacts open " + JSON.stringify(opened)): return
	await _frames()
	var app: Node = desktop._cached_app_windows[&"contacts"]
	app.contacts_panel.open_requested.emit("lavinia")
	await _frames()
	var choice: Button = app.find_child("OrdinaryReply" + _reply_choice, true, false)
	if not _check(choice != null and choice.is_visible_in_tree() and not choice.disabled, "reply actual " + _reply_choice + " visible " + str(app.last_result.get("code"))): return
	await _capture_screen("reply-01-lavinia-before-click")
	if not await _click_reply(choice): return
	for frame: int in 180:
		await process_frame
		if game.get_pending_ordinary_echoes().size() == 1 or not app.last_result.get("ok", false): break
	var diagnostic := {"choice": _reply_choice, "code": str(app.last_result.get("code", "")), "message": str(app.last_result.get("message", "")),
		"path": str(app.last_result.get("path", "")), "phase": "commit" if not app._ordinary_pending.is_empty() else "prepare",
		"drawn": app._ordinary_drawn, "busy": app._ordinary_busy, "locale": app._primary,
		"gate": str(bootstrap._application_gate.get_active_owner()), "echo_count": game.get_pending_ordinary_echoes().size()}
	await _capture_screen("reply-02-lavinia-after-click")
	print("ORDINARY_REPLY_DIAGNOSTIC: " + JSON.stringify(diagnostic))
	if not _check(game.get_pending_ordinary_echoes().size() == 1, "reply did not persist " + JSON.stringify(diagnostic)): return
	if not _check(game.get_pending_ordinary_echoes()[0].reply_id == "reply.ordinary.lavinia.day1." + _reply_choice.to_lower(), "reply persisted the exact clicked choice"): return
	print("ORDINARY_REPLY_SAVE_PASS: real title entry -> Chinese ordinary reply " + _reply_choice + " -> actual draw -> durable echo")
	quit(0)

func _click_reply(button: Button) -> bool:
	var window := button.get_window()
	window.grab_focus()
	for frame: int in 3: await process_frame
	if not _check(window.has_focus() and button.is_visible_in_tree() and not button.disabled, "reply real mouse source is focused and visible"): return false
	var point := button.get_global_rect().get_center()
	if not _check(button.get_viewport_rect().has_point(point), "reply mouse point lies in the actual viewport"): return false
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	Input.parse_input_event(press)
	for frame: int in 3: await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.global_position = point
	release.pressed = false
	Input.parse_input_event(release)
	return true
