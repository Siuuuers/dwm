extends Node
## Native project main scene, FINAL bootstrap, actual viewport clicks; diagnostic only.
const TIMING := preload("res://tests/support/StartupAttributionTiming.gd")
const VALIDATION := preload("res://scripts/narrative/SceneValidationTiming.gd")
const FIRST_LINE := "line.Day1.one"
const FIRST_EN := "Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself."
var folder := OS.get_environment("DWM_STARTUP_OUTPUT")
var phase := OS.get_environment("DWM_STARTUP_CASE")
var milestones: Dictionary = {}
var failures: Array[String] = []
var max_frame_gap_us := 0
var previous_frame_us := 0
var profiling := false
var observation: Dictionary = {}

func _ready() -> void:
	get_tree().process_frame.connect(_frame)
	_run.call_deferred()

func _frame() -> void:
	var now := Time.get_ticks_usec()
	if previous_frame_us > 0: max_frame_gap_us = maxi(max_frame_gap_us, now - previous_frame_us)
	previous_frame_us = now

func _mark(key: String) -> void:
	milestones[key] = TIMING.stamp()

func _check(ok: bool, message: String) -> bool:
	if ok: return true
	failures.append(message)
	_finish(false)
	return false

func _capture(name_: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	return not image.is_empty() and image.save_png(folder.path_join(name_ + ".png")) == OK

func _click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size / 2.0)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _run() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	var appdata := OS.get_environment("APPDATA").replace("\\", "/").to_lower()
	if not _check(not folder.is_empty() and phase in ["fresh", "retained"] and not appdata.is_empty()
			and user_path.begins_with(appdata + "/") and DisplayServer.get_name() != "headless", "isolated rendered invocation required"): return
	var tree := get_tree()
	var bootstrap: Node = tree.root.get_node("ApplicationBootstrap")
	var deadline := Time.get_ticks_msec() + 300000
	var menu: Node
	var button: Button
	while Time.get_ticks_msec() < deadline:
		menu = tree.current_scene
		if menu != null and menu.has_node("%NewAccButton") and bootstrap.get_startup_state().get("ready", false):
			button = menu.get_node("%NewAccButton")
			if button.is_visible_in_tree() and not button.disabled and not menu._title_transition: break
		await tree.process_frame
	if not _check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
			and bootstrap.get_startup_state().get("ready", false), "Title did not become usable"): return
	await RenderingServer.frame_post_draw
	_mark("title_drawn_usable")
	if not _check(_capture("title"), "Title screenshot failed"): return
	var saves: Node = tree.root.get_node("SaveManager")
	var bridge: Node = tree.root.get_node("DialogicBridge")
	var game: Node = tree.root.get_node("GameState")
	profiling = VALIDATION.begin_scope("new_acc_" + phase, "", "", 0)
	previous_frame_us = Time.get_ticks_usec()
	max_frame_gap_us = 0
	_mark("new_acc_input")
	await _click(button)
	var confirmed := false
	deadline = Time.get_ticks_msec() + 300000
	var caption: Node
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(menu) and is_instance_valid(menu._confirmation) and menu._confirmation.is_visible_in_tree() and not menu._title_transition:
			if not _check(phase == "retained" and not confirmed and not str(menu._new_acc_token).is_empty()
					and not menu._confirmation.confirm_button.disabled, "unexpected or invalid New Acc consent"): return
			await RenderingServer.frame_post_draw
			_mark("consent_drawn")
			if not _check(_capture("consent"), "consent screenshot failed"): return
			confirmed = true
			previous_frame_us = Time.get_ticks_usec() # Exclude deliberate screenshot dwell from frame-gap sampling.
			_mark("confirm_input")
			await _click(menu._confirmation.confirm_button)
		caption = tree.root.get_node("SceneRouter")._production_pause._find_caption(tree.root)
		if is_instance_valid(caption) and caption.caption_text.is_visible_in_tree():
			if not milestones.has("caption_first_visible"): _mark("caption_first_visible")
			var native: Node = caption.caption_text
			var event: DialogicTextEvent = bridge._runtime_adapter._current_skip_text(true)
			if bridge._runtime_adapter.current_line_id() == FIRST_LINE and event != null \
					and event.state == DialogicTextEvent.States.DONE and not native.revealing \
					and native.visible_ratio == 1.0 and bridge.is_current_line_presentation_acknowledged() \
					and not saves._new_run_busy and game.capture_live_session().value.active:
				await RenderingServer.frame_post_draw
				_mark("caption_complete_drawn_idle")
				observation = {"line_id": FIRST_LINE, "text": native.get_parsed_text(),
					"visible": native.is_visible_in_tree(), "revealing": native.revealing,
					"visible_ratio": native.visible_ratio, "event_done": true,
					"new_run_busy": saves._new_run_busy, "active": game.capture_live_session().value.active}
				break
		await tree.process_frame
	if not _check(not observation.is_empty() and confirmed == (phase == "retained"), "first caption or expected consent not reached"): return
	if profiling:
		VALIDATION.end_scope(true)
		profiling = false
	var locale: String = tree.root.get_node("LocalizationManager").get_locale()
	var texts: Dictionary = load("res://scripts/localization/StoryLocalization.gd").catalog(locale)
	if not _check(observation.text == texts.get(FIRST_LINE, FIRST_EN), "first caption text differs from authored text"): return
	var incomplete: Dictionary = saves._continuation_journal.list_incomplete()
	if not _check(incomplete.get("ok", false) and incomplete.value.is_empty(), "New Acc left incomplete journal operations"): return
	if not _check(_capture("caption"), "caption screenshot failed"): return
	_finish(true)

func _finish(ok: bool) -> void:
	if profiling:
		VALIDATION.end_scope(false)
		profiling = false
	var rendering := {}
	for method: String in ["get_current_rendering_method", "get_current_rendering_driver_name", "get_video_adapter_name", "get_video_adapter_api_version"]:
		if RenderingServer.has_method(method): rendering[method] = RenderingServer.call(method)
	var profile: Node = get_tree().root.get_node("ProfileManager")
	var preferences := {}
	for key: String in ["preferences.accessibility.text_size", "preferences.accessibility.font_style", "preferences.reading.reveal_speed", "preferences.reading.auto_enabled"]:
		preferences[key] = profile.get_preference(key, null)
	var report := {"complete": ok, "case": phase, "milestones": milestones, "phases": TIMING.rows,
		"observation": observation, "failures": failures, "max_new_acc_frame_gap_us": max_frame_gap_us,
		"engine": Engine.get_version_info(), "rendering": rendering, "preferences": preferences,
		"user_path": ProjectSettings.globalize_path("user://"), "argv": OS.get_cmdline_args(),
		"scope": "Instrumented native project launch; inclusive phases overlap. Natural default text reveal. Consent screenshot dwell separate. Two same-runner processes; fresh means empty user profile, not cold OS disk cache. No performance acceptance threshold or user-device claim."}
	var output := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t") + "\n")
		output.close()
	else: ok = false
	print("STARTUP_NEW_ACC_ATTRIBUTION ", JSON.stringify(report))
	get_tree().quit(0 if ok else 1)
