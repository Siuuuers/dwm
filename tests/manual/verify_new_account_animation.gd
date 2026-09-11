extends "res://tests/integration/verify_complete_action_recovery.gd"
## Native, isolated proof of frame latency throughout preparation and commit.
var _phase := ""
var _previous_frame_us := 0
var _frame_gaps: Dictionary = {}
var _frame_samples: Array = []

func _sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if not _phase.is_empty() and _previous_frame_us > 0:
		_frame_gaps[_phase] = maxi(int(_frame_gaps.get(_phase, 0)), now - _previous_frame_us)
		_frame_samples.append({"phase": _phase, "us": now, "gap_us": now - _previous_frame_us})
	_previous_frame_us = now


func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false), "animation bootstrap ready"): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	var menu: Node = current_scene
	var manager: Node = root.get_node("SaveManager")
	menu._title_welcome.set_busy("starting")
	menu._title_welcome._dot_started_us = Time.get_ticks_usec() - 750000
	menu._title_welcome._process(0.001)
	if not _check(menu._title_welcome._dot_count == 3, "dots track elapsed time even when engine delta is clamped"): return
	menu._title_welcome.set_busy("")
	print("NEW_ACCOUNT_WINDOW: " + JSON.stringify({"position": str(DisplayServer.window_get_position()), "mode": DisplayServer.window_get_mode(), "focused": root.has_focus(), "max_fps": Engine.max_fps, "low_processor_usage_mode": OS.low_processor_usage_mode}))
	process_frame.connect(_sample_frame)
	_phase = "idle"
	for index: int in range(20): await process_frame
	_phase = "preparing"
	_previous_frame_us = Time.get_ticks_usec()
	menu.get_node("%NewAccButton").pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while is_instance_valid(menu) and menu._title_transition and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(is_instance_valid(menu) and is_instance_valid(menu._confirmation), "animation real replacement consent"): return
	var token: String = menu._new_acc_token
	_phase = "starting"
	_previous_frame_us = Time.get_ticks_usec()
	var started := Time.get_ticks_usec()
	menu._confirmation.confirm_button.pressed.emit()
	var dots := {}
	var checked_custody := false
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

		await process_frame
	while manager._new_run_busy and Time.get_ticks_msec() < deadline: await process_frame
	_sample_frame()
	print("NEW_ACCOUNT_TIMING: " + JSON.stringify({"frame_gaps_us": _frame_gaps, "frame_samples": _frame_samples}))
	if not _check(not manager._new_run_busy and root.get_node("GameState").capture_live_session().value.active, "responsive account finishes and activates"): return
	var elapsed_us := Time.get_ticks_usec() - started
	if not _check(checked_custody and (elapsed_us < 1050000 or dots.size() >= 2), "dots change during sustained real saving: " + str(dots)): return
	var allowed_gap_us := maxi(350000, int(_frame_gaps.get("idle", 0)) + 100000)
	for phase: String in ["preparing", "starting"]:
		if not _check(int(_frame_gaps.get(phase, 0)) <= allowed_gap_us, phase + " frame gap exceeds " + str(allowed_gap_us) + "us: " + str(_frame_gaps)): return
	print("NEW_ACCOUNT_ANIMATION_PASS: " + JSON.stringify({"dots": dots.keys(), "elapsed_us": Time.get_ticks_usec()-started}))
	quit(0)
