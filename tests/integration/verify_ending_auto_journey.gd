extends "res://tests/integration/verify_ending_reading_journey.gd"
## Isolated noncanonical Auto seam proof; native reveal, real timers and ending owners.
const AUTO_LOCATOR := preload("res://tests/support/EndingAutoTimelineCatalog.gd")
const TERMINAL := "fixture.ending.auto_terminal"
const TERMINAL_TEXT := "This final test caption waits for an explicit player completion."
const DELAY := 4.0
var _auto_frames: Array = []
var _auto_observing := false
var _successor_reveal_seen := false
var _successor_finished_ms := -1
var _terminal_seen_ms := -1

func _auto_catalogue() -> Dictionary:
	var catalogue: Dictionary = ENDING_FIXTURE.catalogue().duplicate(true)
	catalogue.entries[1].lines.append({"beat_id": TERMINAL, "line_id": TERMINAL,
		"revision": "fixture-ending-v1", "text": TERMINAL_TEXT})
	return catalogue

func _run() -> void:
	_reading_mode = "auto"
	if not _check(DisplayServer.get_name() != "headless" and not OS.get_environment("DWM_TEST_ROOT").is_empty(),
		"isolated rendered Auto process required"): return
	print("ENDING_AUTO_PROCESS: " + JSON.stringify({"mode": "auto", "process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://")}))
	await _frames()
	var bridge: Node = root.get_node("DialogicBridge")
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false) and bridge.initialize(AUTO_LOCATOR).get("ok", false)
		and bridge.configure_reading_catalogue(_auto_catalogue()).get("ok", false), "real startup with explicit Auto fixture"): return
	bootstrap.get("_ending_playback_port").playback_completed.connect(func(completion: Dictionary) -> void:
		_ending_completions.append(completion.duplicate(true)))
	root.get_node("Dialogic").Text.text_started.connect(func(info: Dictionary) -> void: _ending_texts.append(str(info.get("text", ""))))
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	current_scene.get_node("%NewAccButton").pressed.emit()
	if not await _wait_desktop(1): return
	var profile: Node = root.get_node("ProfileManager")
	if not _check(profile.set_preferences({&"preferences.reading.read_aloud_enabled": false,
		&"preferences.reading.reveal_speed": "slow", &"preferences.reading.auto_enabled": false,
		&"preferences.reading.auto_delay": "long"}).get("ok", false), "speech disabled solely to isolate native reveal and Auto timing"): return
	if not _seed_ordered_plan(): return
	root.get_node("SceneRouter").goto_ending()
	if not await _wait_line(ENDING_LINES[0]): return
	if not await _fresh_caption_accept(): return
	if not _check(bridge.get("_runtime_adapter").is_current_line_complete(), "first reveal completed by player"): return
	var auto_button: Button = _caption_layer().transport_rail.get_node("Auto")
	auto_button.grab_focus()
	if not await _ordinary_accept_focused(auto_button, "enable Auto through actual rail"): return
	if not _check(profile.get_preference(&"preferences.reading.auto_enabled", false), "Auto On committed"): return
	_auto_observing = true
	RenderingServer.frame_post_draw.connect(_observe_auto_frame)
	var controller: Node = _caption_layer().auto_controller
	var stale: Dictionary = bridge.capture_current_line_presentation_frontier()
	var deadline := Time.get_ticks_msec() + 10000
	while (not controller.get("_armed") or float(controller.get("_remaining")) > DELAY - 0.4) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(controller.get("_armed") and float(controller.get("_remaining")) > 0.0
		and float(controller.get("_remaining")) <= DELAY - 0.4, "departing timer really consumed part of its delay"): return
	var departing_remaining: float = controller.get("_remaining")
	# Fresh input retires the partly spent ordinary-line timer. The boundary itself
	# cannot arm Auto because the next event is Return, not an ordinary text event.
	if not await _fresh_caption_accept(): return
	if not await _wait_line(ENDING_LINES[1]): return
	if not await _fresh_caption_accept(): return
	if not await _fresh_caption_accept(): return
	if not await _wait_line(ENDING_LINES[2]): return
	if not await _fresh_caption_accept(): return
	if not _check(not _caption_layer().auto_controller.get("_armed") and not bridge.can_auto_advance_current_line(),
		"fully revealed boundary still requires explicit completion"): return
	await _capture_screen("ending-auto-before")
	if not await _fresh_caption_accept(): return
	if not await _wait_line(ENDING_LINES[3]): return
	if not _check(_successor_reveal_seen and _ending_completions.size() == 1,
		"one physical completion starts a genuinely revealing successor"): return
	await _capture_screen("ending-auto-successor")
	var before_stale: Dictionary = bridge.capture_reading_checkpoint(false)
	var stale_result: Dictionary = bridge.request_auto_step(stale)
	if not _check(not stale_result.get("ok", false) and before_stale == bridge.capture_reading_checkpoint(false)
		and _ending_completions.size() == 1, "departed frontier cannot advance or change successor ledger"): return
	deadline = Time.get_ticks_msec() + 30000
	while bridge.get("_runtime_adapter").current_line_id() != TERMINAL and Time.get_ticks_msec() < deadline:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _check(_terminal_seen_ms >= 0 and _successor_finished_ms >= 0
		and _terminal_seen_ms - _successor_finished_ms >= int(DELAY * 1000.0) - 100,
		"successor receives full foreground delay after its own native reveal"): return
	if not await _fresh_caption_accept(): return
	if not _check(bridge.get("_runtime_adapter").is_current_line_complete(), "terminal reveal complete"): return
	var terminal_before: Dictionary = _ending_observe()
	deadline = Time.get_ticks_msec() + int((DELAY + 0.3) * 1000.0)
	while Time.get_ticks_msec() < deadline: await process_frame
	if not _check(bridge.get("_runtime_adapter").current_line_id() == TERMINAL
		and _ending_completions.size() == 1 and _ending_observe() == terminal_before
		and not bridge.can_auto_advance_current_line(), "Auto On never performs terminal Return or repeats ending consequences"): return
	await _capture_screen("ending-auto-terminal")
	_auto_observing = false
	RenderingServer.frame_post_draw.disconnect(_observe_auto_frame)
	var handoff_seen := false
	for sample: Dictionary in _auto_frames:
		if not _check(sample.profile_auto, "Auto preference remains On throughout"): return
		if not _check(not sample.layers.is_empty(), "Auto rail remains drawn through the observed seam"): return
		for layer: Dictionary in sample.layers:
			if not _check(layer.auto_on and not layer.skip_on, "every drawn rail retains Auto On and Skip Off"): return
			if layer.handoff:
				handoff_seen = true
				if not _check(not layer.armed, "departing handoff has no live timer"): return
			if layer.line_id == ENDING_LINES[3] and layer.revealing:
				if not _check(not layer.armed, "successor reveal never consumes Auto delay"): return
	var report := {"schema_version": 1, "mode": "auto", "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"), "fixture_scope": "Noncanonical ordered captions; speech disabled for timing isolation; real physical input, native reveal, Auto timer and ending owners.",
		"departing_remaining": departing_remaining, "drawn_handoff_seen": handoff_seen, "successor_reveal_finished_ms": _successor_finished_ms,
		"terminal_seen_ms": _terminal_seen_ms, "delay_seconds": DELAY, "stale_result": stale_result,
		"completions": _ending_completions, "terminal": terminal_before, "frames": _auto_frames}
	if not _check(_write_text("auto.json", JSON.stringify(report, "\t")), "retain Auto seam evidence"): return
	print("ENDING_AUTO_PASS: Auto On -> retired prior timer -> manual ending seam -> native successor reveal and full delay -> manual terminal boundary")
	await _finish_proof()

func _capture_screen(label: String) -> bool:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	return _check(pixels != null and not pixels.is_empty()
		and pixels.save_png(_evidence_path(label + ".png")) == OK, "retain rendered Auto evidence " + label)

func _observe_auto_frame() -> void:
	if not _auto_observing: return
	var bridge: Node = root.get_node("DialogicBridge")
	var line_id: String = bridge.get("_runtime_adapter").current_line_id()
	var now := Time.get_ticks_msec()
	var layers: Array = []
	for layer: Node in root.find_children("WitnessedCaptionLayer", "", true, false):
		if not layer.transport_rail.is_visible_in_tree(): continue
		var revealing: bool = layer.caption_text.revealing
		layers.append({"line_id": line_id, "auto_on": layer.transport_rail.get("_auto_enabled"),
			"skip_on": layer.transport_rail.get("_skip_active"),
			"handoff": layer.get("_ending_caption_handoff"), "revealing": revealing,
			"armed": layer.auto_controller.get("_armed"), "remaining": layer.auto_controller.get("_remaining")})
		if line_id == ENDING_LINES[3] and not layer.get("_ending_caption_handoff"):
			if revealing: _successor_reveal_seen = true
			elif _successor_finished_ms < 0: _successor_finished_ms = now
	if line_id == TERMINAL and _terminal_seen_ms < 0: _terminal_seen_ms = now
	_auto_frames.append({"frame": Engine.get_process_frames(), "ms": now,
		"profile_auto": root.get_node("ProfileManager").get_preference(&"preferences.reading.auto_enabled", false), "layers": layers})
