extends "res://tests/save_load_loop/Observe.gd"
## Reuses only observer isolation, assertions and scene-wait helpers.
## All application nodes, transactions, storage and routing are production instances.

func _run() -> void:
	await get_tree().process_frame
	_check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(1280, 720)), "Actual project config supplies the 1280x720 logical viewport")
	var bootstrap: Node = get_node("/root/ApplicationBootstrap")
	var startup: Dictionary = bootstrap.get_startup_state()
	_facts["startup"] = startup
	_facts["process_id"] = OS.get_process_id()
	_facts["phase"] = OS.get_environment("DWM_SAVE_LOAD_PHASE")
	if not _check(startup.get("ready", false) and startup.get("mode") == &"final", "Actual production startup is final and ready"):
		_finish(false)
		return
	var menu: Node = get_tree().current_scene
	if not _check(menu != null and menu.scene_file_path == "res://scenes/menu/MenuScene.tscn", "Original title Menu is the cold startup scene"):
		_finish(false)
		return
	await _shutdown_cancel(menu)
	if _facts.phase == "seed":
		await _settings_navigation(menu)
		await _seed(menu, bootstrap)
	else:
		await _resume(menu)
	_finish(_failures.is_empty())

func _shutdown_cancel(menu: Node) -> void:
	var state: Node = get_node("/root/GameState")
	var before: Dictionary = state.capture_run_snapshot_input()
	_check(menu._clock_label.is_visible_in_tree(), "Routine title clock is visible before opening any app")
	_check(not menu._title_home.visible and menu._title_home.focus_mode == Control.FOCUS_NONE and not menu._title_label.visible and menu._title_label.focus_mode == Control.FOCUS_NONE, "Unhosted title has no visible or focusable Return and heading")
	var shutdown: Button = menu.get_node("%ShutDownButton")
	shutdown.grab_focus()
	shutdown.pressed.emit()
	await _settle()
	if not _check(is_instance_valid(menu._confirmation) and menu._confirmation.cancel_button.has_focus(), "Real title shutdown begins with Cancel focused"):
		return
	_check(not menu._confirmation.request.get("warning", true), "Routine shutdown uses a neutral shared confirmation")
	await _back()
	_check(not is_instance_valid(menu._confirmation) and shutdown.has_focus(), "Escape cancels real shutdown and restores its invoking title command")
	_check(get_tree().current_scene == menu and state.capture_run_snapshot_input() == before, "Shutdown cancellation preserves the actual Menu and run state")
	_check(menu._clock_label.is_visible_in_tree(), "Routine clock persists after cancelling shutdown")

func _settings_navigation(menu: Node) -> void:
	var profile: Node = get_node("/root/ProfileManager")
	var before: Dictionary = profile.capture_restore_state()
	var backup: Node = await _open_title(menu)
	if backup == null:
		return
	var settings_button: Button = menu.get_node("%SettingButton")
	settings_button.pressed.emit()
	await _settle()
	var panel: Node = menu._setting_instance
	if not _check(is_instance_valid(panel) and panel.is_visible_in_tree(), "Real title Setting opens its existing panel"):
		return
	_check(menu._clock_label.is_visible_in_tree() and menu._title_home.visible and menu._title_label.visible and menu._title_label.text == "Setting", "Setting hosts Return and its own heading beside the persistent clock")
	settings_button.grab_focus()
	await _press_key(KEY_RIGHT)
	_check(menu._title_home.has_focus(), "Right from the Setting ledger command reaches hosted Return")
	await _press_key(KEY_TAB)
	_check(panel.get_node("%LanguageOption").has_focus(), "Return Tab enters visible Settings instead of cached Backup")
	menu._title_home.grab_focus()
	await _press_key(KEY_DOWN)
	_check(panel.get_node("%LanguageOption").has_focus(), "Return Down enters the current Settings language control")
	var panel_id := panel.get_instance_id()
	panel.get_node("%CloseButton").pressed.emit()
	await _settle()
	_check(not menu._setting_host.visible and settings_button.has_focus(), "Setting Close hides its host and restores Setting command focus")
	_check(not menu._title_home.visible and menu._title_home.focus_mode == Control.FOCUS_NONE and not menu._title_label.visible and menu._clock_label.is_visible_in_tree(), "Closing Setting returns to the unhosted title strip")
	settings_button.pressed.emit()
	await _settle()
	_check(menu._setting_instance.get_instance_id() == panel_id and panel.is_visible_in_tree(), "Reopening Setting shows its cached panel")
	menu._title_home.pressed.emit()
	await _settle()
	_check(not menu._setting_host.visible and settings_button.has_focus(), "Return closes Setting and restores its title command focus")
	_check(profile.capture_restore_state() == before, "Settings navigation changes no preference values")

func _open_title(menu: Node) -> Node:
	menu.get_node("%LogInButton").pressed.emit()
	await _settle()
	var app: Node = menu._backup_app_instance
	if not _check(is_instance_valid(app) and app.is_visible_in_tree(), "Log in opens configured title Backup"):
		return null
	_check(app.mode_buttons.is_empty() and app.active_mode == "load", "Title exposes Load/Delete with no mode group")
	_check(menu._title_label.text == "Log in", "Opened title heading uses the ready English catalog text")
	_check(menu._backup_app_host.get_global_rect().is_equal_approx(Rect2(320, 0, 960, 720)), "Actual title reserves 320 pixels for menu and 960 for the login host")
	_check(app.get_global_rect().is_equal_approx(Rect2(400, 64, 800, 656)), "Title Backup keeps its 800x656 body below the 64px strip with 80px side inset")
	return app

func _back() -> void:
	await _press_key(KEY_ESCAPE)

func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await _settle()

func _seed(menu: Node, bootstrap: Node) -> void:
	var state: Node = get_node("/root/GameState")
	var before: Dictionary = state.capture_run_snapshot_input()
	var app: Node = await _open_title(menu)
	if app == null:
		return
	_check(app.selected_locator == "autosave", "Empty title chooses unavailable Autosave without inventing a save")
	_check(app.action_buttons.load.disabled and app.action_buttons.delete.disabled, "Empty title slot cannot Load or Delete")
	menu._title_home.pressed.emit()
	await _settle()
	_check(not app.is_visible_in_tree() and menu.get_node("%LogInButton").has_focus(), "Title Home returns focus to Log in")
	_check(state.capture_run_snapshot_input() == before, "Empty title navigation does not create or mutate a run")
	menu.get_node("%NewAccButton").pressed.emit()
	if not await _await_scene("res://scenes/opening/OpeningScene.tscn"):
		return
	var opening: Node = get_tree().current_scene
	if not _check(not opening.get("_dialogic_blocked"), "Registered production opening starts"):
		return
	opening.get_node("%ContinueButton").pressed.emit()
	if not await _await_scene("res://scenes/main/MainGameScene.tscn"):
		return
	var graph: Dictionary = bootstrap.get_desktop_contract_state()
	var issuer: Object = instance_from_id(int(graph.issuer_instance_id))
	var issued: Dictionary = issuer.issue(&"transaction_id")
	if not _check(issued.get("ok", false), "Production issuer provides a lawful transaction identity"):
		return
	var effects: Array[String] = ["money:+5"]
	var changed: Dictionary = state.commit_effect_transaction(str(issued.value.token), effects, "title_resume.integration_probe")
	if not _check(changed.get("ok", false) and state.money == 5, "Real effect owner changes money before saving"):
		_facts["effect_result"] = changed
		return
	var desktop: Node = get_tree().current_scene._computer_desktop_instance
	desktop.launcher_buttons[&"backup"].pressed.emit()
	await _settle()
	app = desktop._cached_app_windows.get(&"backup")
	if not _check(is_instance_valid(app) and not app.action_buttons.save.disabled, "In-run Backup is configured for real Save"):
		return
	app.action_buttons.save.pressed.emit()
	await _settle()
	if not _check(app.last_result.get("ok", false) and app.status_label.text == "Saved", "Real Backup saves the seeded run durably"):
		_facts["save_result"] = app.last_result
		return
	var slot_path: String = str(_facts.user_root).path_join("saves/slot_1.json")
	var validated: Dictionary = SAVE_SCHEMA.validate(JSON.parse_string(FileAccess.get_file_as_string(slot_path)))
	if not _check(validated.get("ok", false), "Saved slot passes the real document schema"):
		return
	var snapshot: Dictionary = validated.value.candidate.current_snapshot.snapshot
	_check(snapshot.gameplay.money == 5 and snapshot.route_id == "main" and snapshot.active_app_id == "backup", "Disk snapshot holds changed money and the saved desktop route")
	var expected := {"money": state.money, "day": state.day, "opening_seen": state.opening_seen,
		"seed_process_id": OS.get_process_id(), "slot_sha256": FileAccess.get_sha256(slot_path)}
	var file := FileAccess.open(str(_facts.user_root).path_join("title_resume_expected.json"), FileAccess.WRITE)
	if not _check(file != null, "Expectation is written only in the proven isolated user root"):
		return
	file.store_string(JSON.stringify(expected))
	file.close()
	_facts["saved"] = expected

func _resume(menu: Node) -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(_facts.user_root).path_join("title_resume_expected.json")))
	if not _check(expected is Dictionary, "Cold process reads seed expectations from shared isolated storage"):
		return
	_check(int(expected.seed_process_id) != OS.get_process_id(), "Resume runs in a distinct operating-system process")
	var state: Node = get_node("/root/GameState")
	var before: Dictionary = state.capture_run_snapshot_input()
	_check(state.money != int(expected.money), "Cold title has not silently reused the previous live money")
	var slot_path: String = str(_facts.user_root).path_join("saves/slot_1.json")
	_check(FileAccess.get_sha256(slot_path) == expected.slot_sha256, "Cold startup preserves the seeded slot bytes")
	var app: Node = await _open_title(menu)
	if app == null:
		return
	app.drawer_buttons["slot:7"].pressed.emit()
	await _settle()
	_check(app.action_buttons.load.disabled, "An empty numbered drawer remains unavailable for title Load")
	var corrupt_path: String = str(_facts.user_root).path_join("saves/slot_7.json")
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	if not _check(corrupt_file != null, "Corrupt-slot fixture stays within the proven isolated save root"):
		return
	corrupt_file.store_string("{invalid fixture")
	corrupt_file.close()
	app.refresh_view()
	await _settle()
	_check(app._records["slot:7"].state == "unavailable" and app.action_buttons.load.disabled, "Corrupt title record cannot be loaded")
	_check(DirAccess.remove_absolute(corrupt_path) == OK, "Temporary corrupt fixture is removed from isolated storage")
	app.refresh_view()
	app.drawer_buttons["slot:1"].pressed.emit()
	await _settle()
	if not _check(not app.action_buttons.load.disabled and not app.action_buttons.delete.disabled, "Seeded slot exposes operational title Load and Delete"):
		return
	app.action_buttons.delete.pressed.emit()
	await _settle()
	if not _check(is_instance_valid(app.confirmation) and app.confirmation.cancel_button.has_focus(), "Title Delete uses the real Cancel-first confirmation"):
		return
	menu._title_home.pressed.emit()
	_check(app.is_visible_in_tree() and is_instance_valid(app.confirmation), "Home cannot bypass title confirmation custody")
	app.confirmation.cancel_button.pressed.emit()
	await _settle()
	_check(FileAccess.get_sha256(slot_path) == expected.slot_sha256 and state.capture_run_snapshot_input() == before, "Cancelling title Delete preserves the slot and cold run state")
	var original_slot_text := FileAccess.get_file_as_string(slot_path)
	var ledger: Array[Button] = []
	for name in ["NewAccButton", "LogInButton", "GalleryButton", "SettingButton", "ShutDownButton"]:
		ledger.append(menu.get_node("%" + name))
	var prior_mouse: Array = ledger.map(func(button: Button): return button.mouse_filter)
	app.action_buttons.delete.pressed.emit()
	await _settle()
	if not _check(is_instance_valid(app.confirmation), "Second title Delete obtains fresh confirmation"):
		return
	var revision_file := FileAccess.open(slot_path, FileAccess.WRITE)
	if not _check(revision_file != null, "Stale Delete modifies only the already proven isolated slot"):
		return
	revision_file.store_string(original_slot_text + "\n")
	revision_file.close()
	app.confirmation.confirm_button.pressed.emit()
	await _settle()
	_check(not app.last_result.get("ok", false) and app.action_buttons.has("cancel"), "Changed slot revision rejects title Delete into recovery")
	_check(state.capture_run_snapshot_input() == before and get_tree().current_scene == menu, "Rejected title Delete preserves cold run state and actual Menu")
	for button in ledger:
		_check(not button.disabled and button.focus_mode == Control.FOCUS_NONE and button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Recovery masks title input without changing command availability")
	_check(not menu._title_home.disabled and not menu._title_home.current_on_launcher and menu._title_home.return_arrow and menu._title_home.focus_mode == Control.FOCUS_NONE, "Recovery Return retains its canonical identity while losing focus eligibility")
	menu._title_home.pressed.emit()
	_check(app.is_visible_in_tree() and not app.can_return_home(), "Return activation cannot bypass title recovery")
	revision_file = FileAccess.open(slot_path, FileAccess.WRITE)
	if not _check(revision_file != null, "Exact saved slot can be restored within isolated storage"):
		return
	revision_file.store_string(original_slot_text)
	revision_file.close()
	await _back()
	_check(app.is_visible_in_tree() and app.can_return_home(), "First Escape cancels recovery while leaving title Backup open")
	_check(FileAccess.get_sha256(slot_path) == expected.slot_sha256, "Recovery cancellation preserves the exact original slot bytes")
	for index in range(ledger.size()):
		_check(not ledger[index].disabled and ledger[index].focus_mode == Control.FOCUS_ALL and ledger[index].mouse_filter == prior_mouse[index], "Recovery cancellation restores each title command's focus and pointer mask")
	await _back()
	_check(not app.is_visible_in_tree() and menu.get_node("%LogInButton").has_focus(), "Title Back closes Backup and restores Log in focus")
	app = await _open_title(menu)
	if app == null:
		return
	app.drawer_buttons["slot:1"].pressed.emit()
	await _settle()
	_facts["restore_notifications"] = 0
	get_node("/root/SaveManager").run_restored.connect(func(_checkpoint: String, _route: String): _facts["restore_notifications"] += 1)
	app.action_buttons.load.pressed.emit()
	_facts["load_result"] = app.last_result.duplicate(true)
	if not _check(app.last_result.get("ok", false), "Ordinary title Load succeeds directly without replace-progress consent: " + JSON.stringify(app.last_result)):
		return
	if not await _await_scene("res://scenes/main/MainGameScene.tscn"):
		return
	await _settle()
	_check(_facts.restore_notifications == 1, "Cold Load publishes one completed restore")
	_check(state.money == int(expected.money) and state.day == int(expected.day) and state.opening_seen == expected.opening_seen, "Cold Load restores saved money, day and opening progress")
	var desktop: Node = get_tree().current_scene._computer_desktop_instance
	if not _check(is_instance_valid(desktop) and desktop._active_id == &"backup", "Restored real desktop opens the saved Backup app"):
		return
	var restored: Node = desktop._cached_app_windows.get(&"backup")
	_check(is_instance_valid(restored) and restored.is_visible_in_tree() and not restored.action_buttons.save.disabled, "Resumed Backup is usable after the restore owner releases its gate")
	_check(desktop.return_home().get("ok", false), "Home works after cold resume")
	_facts["restored"] = {"money": state.money, "day": state.day, "scene": get_tree().current_scene.scene_file_path}

func _finish(passed: bool) -> void:
	print("TITLE_RESUME_SUMMARY ", JSON.stringify({"checks": _checks, "failures": _failures, "facts": _facts}))
	if passed and _failures.is_empty():
		print("TITLE_RESUME_SEED_PASS" if _facts.get("phase") == "seed" else "TITLE_RESUME_PASS")
	get_tree().quit(0 if passed and _failures.is_empty() else 1)
