extends "res://tests/integration/verify_complete_action_recovery.gd"
## Native, isolated proof that dots change while the real SaveManager operation is in progress.

func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false), "animation bootstrap ready"): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	var menu: Node = current_scene
	var manager: Node = root.get_node("SaveManager")
	menu.get_node("%NewAccButton").pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while is_instance_valid(menu) and menu._title_transition and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(is_instance_valid(menu) and is_instance_valid(menu._confirmation), "animation real replacement consent"): return
	var token: String = menu._new_acc_token
	menu._confirmation.confirm_button.pressed.emit()
	var dots := {}
	var checked_custody := false
	var started := Time.get_ticks_usec()
	while is_instance_valid(menu) and (menu._title_transition or manager._new_run_busy) and Time.get_ticks_msec() < deadline:
		if manager._new_run_busy:
			if not checked_custody:
				if not _check(manager.commit_prepared_new_run(token).get("code") == &"new_run_busy", "duplicate start blocked between save operations"): return
				if not _check(not manager._mutation_gate.guard_external(&"animation_probe").get("ok", false), "mutation lease held while renderer runs"): return
				checked_custody = true
			var text: String = menu._title_welcome.status.text
			var count := text.length() - text.rstrip(".").length()
			if count in [1, 2, 3] and not dots.has(count):
				dots[count] = true
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/phase2r_logs/new-account-dots-%d.png" % count)
		await process_frame
	while manager._new_run_busy and Time.get_ticks_msec() < deadline: await process_frame
	if not _check(not manager._new_run_busy and root.get_node("GameState").capture_live_session().value.active, "responsive account finishes and activates"): return
	if not _check(checked_custody and dots.size() == 3, "all three dot frames rendered during real saving: " + str(dots)): return
	print("NEW_ACCOUNT_ANIMATION_PASS: " + JSON.stringify({"dots": dots.keys(), "elapsed_us": Time.get_ticks_usec()-started}))
	quit(0)
