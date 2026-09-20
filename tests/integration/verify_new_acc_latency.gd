extends "res://tests/integration/verify_complete_action_recovery.gd"
## Real title actions with isolated user data. Timings are evidence, not a hardware-dependent gate.

var _previous_frame_us := 0
var _max_frame_gap_us := 0

func _sample_new_acc_frame() -> void:
	var now := Time.get_ticks_usec()
	if _previous_frame_us > 0:
		_max_frame_gap_us = maxi(_max_frame_gap_us, now - _previous_frame_us)
	_previous_frame_us = now

func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false), "latency bootstrap ready"): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	process_frame.connect(_sample_new_acc_frame)
	var samples: Array[Dictionary] = []
	var fresh := await _measure_new_acc(false)
	if fresh.is_empty(): return
	samples.append(fresh)
	var game: Node = root.get_node("GameState")
	var first_session: Dictionary = game.capture_live_session().value
	var desktop: Node = current_scene.find_child("ComputerDesktop", true, false)
	if not _check(desktop.open_app(&"logout").get("ok", false), "latency public Logout opens"): return
	await _frames()
	var logout: Node = desktop._cached_app_windows[&"logout"]
	if not _check(not logout.yes_button.disabled, "latency Logout enabled"): return
	logout.yes_button.pressed.emit()
	await _frames()
	if not _check(current_scene != null and current_scene.has_node("%NewAccButton") \
			and not game.capture_live_session().value.active, "latency Logout retires session and returns to title"): return
	var replacement := await _measure_new_acc(true)
	if replacement.is_empty(): return
	samples.append(replacement)
	if not _check(game.capture_live_session().value != first_session, "latency replacement activates a new session"): return
	print("NEW_ACC_LATENCY_VERIFIED " + JSON.stringify({"ok":true,"samples":samples}))
	quit(0)

func _measure_new_acc(replacement: bool) -> Dictionary:
	var menu: Node = current_scene
	var manager: Node = root.get_node("SaveManager")
	var game: Node = root.get_node("GameState")
	if not _check(menu != null and menu.has_node("%NewAccButton"), "latency actual title ready"): return {}
	var button: Button = menu.get_node("%NewAccButton")
	if not _check(not button.disabled, "latency New Acc enabled"): return {}
	var confirmed := 0
	var started := Time.get_ticks_usec()
	_previous_frame_us = started
	_max_frame_gap_us = 0
	button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	var desktop: Node
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(menu) and is_instance_valid(menu._confirmation) and not menu._title_transition:
			confirmed += 1
			if not _check(replacement and confirmed == 1 and not str(menu._new_acc_token).is_empty(),
					"latency only replacement requests one valid confirmation"): return {}
			menu._confirmation.confirm_button.pressed.emit()
		desktop = current_scene.find_child("ComputerDesktop", true, false) if current_scene != null else null
		if desktop != null and not manager._new_run_busy and game.capture_live_session().value.active: break
		await process_frame
	_sample_new_acc_frame()
	var elapsed := Time.get_ticks_usec() - started
	_previous_frame_us = 0
	if not _check(desktop != null and desktop.is_visible_in_tree() and not manager._new_run_busy,
			"latency account reaches visible desktop"): return {}
	if not _check(game.capture_live_session().value.active and game.day == 1,
			"latency account activates Day 1"): return {}
	if not _check(confirmed == int(replacement), "latency consent matches occupied Autosave"): return {}
	var incomplete: Dictionary = manager._continuation_journal.list_incomplete()
	if not _check(incomplete.get("ok", false) and incomplete.value.is_empty(),
			"latency new account has no incomplete transaction"): return {}
	return {"case":"replacement" if replacement else "fresh", "button_to_desktop_us":elapsed,
		"max_frame_gap_us":_max_frame_gap_us}
