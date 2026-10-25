extends Node
## Diagnostic export only. No game preloads: this observer must not add eager dependencies.
const FIRST_LINE := "line.Day1.one"
const FIRST_EN := "Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself."
var milestones: Dictionary = {}
var phases: Array[Dictionary] = []
var failures: Array[String] = []
var inputs: Array[Dictionary] = []
var frame_gaps: Dictionary = {}
var observation: Dictionary = {}
var font_cache: Dictionary = {}
var folder := OS.get_environment("DWM_STARTUP_OUTPUT")
var case_name := OS.get_environment("DWM_STARTUP_CASE")
var journey := OS.get_environment("DWM_STARTUP_JOURNEY")
var minimal := OS.get_environment("DWM_STARTUP_MINIMAL") == "1"
var gap_scope := "startup"
var previous_frame_us := 0
var finished := false

func stamp() -> Dictionary:
	return {"ticks_us": Time.get_ticks_usec(), "unix_ms": Time.get_unix_time_from_system() * 1000.0}

func mark(key: String) -> void:
	milestones[key] = stamp()

func finish_phase(phase: String, began: Dictionary, ok: bool = true) -> void:
	var ended := stamp()
	phases.append({"phase": phase, "start": began, "end": ended,
		"elapsed_us": int(ended.ticks_us) - int(began.ticks_us), "ok": ok})

func _enter_tree() -> void:
	mark("probe_enter_tree")
	_sample_font_cache("probe_enter_tree")
	get_tree().process_frame.connect(_frame)
	RenderingServer.frame_post_draw.connect(_drawn)

func _ready() -> void:
	_run.call_deferred()

func _sample_font_cache(key: String) -> void:
	font_cache[key] = {
		"sc": ResourceLoader.has_cached("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf"),
		"hc": ResourceLoader.has_cached("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")}

func _frame() -> void:
	var now := Time.get_ticks_usec()
	if previous_frame_us > 0 and not gap_scope.is_empty():
		frame_gaps[gap_scope] = maxi(int(frame_gaps.get(gap_scope, 0)), now - previous_frame_us)
	previous_frame_us = now

func _drawn() -> void:
	if milestones.has("first_title_drawn"): return
	var scene := get_tree().current_scene
	if scene != null and ((minimal and scene.has_node("ProbeButton")) or scene.has_node("%NewAccButton")):
		mark("first_title_drawn")

func _check(ok: bool, detail: String) -> bool:
	if ok: return true
	failures.append(detail)
	_finish(false)
	return false

func _capture(label: String) -> bool:
	var pixels := get_viewport().get_texture().get_image()
	return _check(not pixels.is_empty() and pixels.save_png(folder.path_join(label + ".png")) == OK,
		label + " capture failed")

func _prepare_pointer(button: Button, label: String) -> bool:
	if not _check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,
		label + " target unavailable"): return false
	gap_scope = "" # Screenshot and pointer setup are explicit diagnostic dwell.
	var point := button.get_global_transform_with_canvas() * (button.size / 2.0)
	var row := {"label": label, "path": str(button.get_path()), "point": str(point),
		"pressed_count": 0, "down_count": 0, "up_count": 0}
	inputs.append(row)
	button.pressed.connect(func() -> void:
		row.pressed_count += 1
		row["accepted"] = stamp()
		if not milestones.has("first_title_input_accepted"): mark("first_title_input_accepted"), CONNECT_ONE_SHOT)
	button.button_down.connect(func() -> void:
		row.down_count += 1, CONNECT_ONE_SHOT)
	button.button_up.connect(func() -> void:
		row.up_count += 1, CONNECT_ONE_SHOT)
	get_window().grab_focus()
	get_viewport().warp_mouse(point)
	var deadline := Time.get_ticks_msec() + 5000
	while not button.is_hovered() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	row["hovered"] = button.is_hovered()
	row["focused_window"] = get_window().has_focus()
	return _check(button.is_hovered(), label + " native hover not established")

func _click(button: Button, label: String) -> bool:
	var point := button.get_global_transform_with_canvas() * (button.size / 2.0)
	gap_scope = label
	previous_frame_us = Time.get_ticks_usec()
	mark(label + "_input")
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.window_id = get_window().get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	var row: Dictionary = inputs.back()
	return _check(row.pressed_count == 1 and row.down_count == 1 and row.up_count == 1,
		label + " expected one actual Button press/down/up")

func _run() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	var appdata := OS.get_environment("APPDATA").replace("\\", "/").to_lower()
	if not _check(not folder.is_empty() and case_name in ["fresh", "retained"]
		and not appdata.is_empty() and user_path.begins_with(appdata + "/")
		and DisplayServer.get_name() != "headless", "isolated rendered Windows export required"): return
	if minimal:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		mark("title_drawn_usable")
		gap_scope = ""
		if not _capture("title"): return
		var target: Button = get_tree().current_scene.get_node("ProbeButton")
		if not await _prepare_pointer(target, "minimal"): return
		if not await _click(target, "minimal"): return
		_finish(true)
		return
	var bootstrap := get_node("/root/ApplicationBootstrap")
	var deadline := Time.get_ticks_msec() + 180000
	var menu: Node
	var button: Button
	while Time.get_ticks_msec() < deadline:
		menu = get_tree().current_scene
		if menu != null and menu.has_node("%NewAccButton") and bootstrap.get_startup_state().get("ready", false):
			button = menu.get_node("%NewAccButton")
			if button.is_visible_in_tree() and not button.disabled and not menu._title_transition: break
		await get_tree().process_frame
	if not _check(is_instance_valid(button) and not button.disabled and button.is_visible_in_tree()
		and bootstrap.get_startup_state().get("ready", false) and menu._can_leave_login(), "Title unavailable"): return
	await RenderingServer.frame_post_draw
	mark("title_drawn_usable")
	_sample_font_cache("title_drawn_usable")
	gap_scope = ""
	if not _capture("title"): return
	if journey == "screens":
		await _screens(menu)
	else:
		await _new_acc(menu, button)

func _screens(menu: Node) -> void:
	for screen: Dictionary in [
		{"name": "settings", "button": "%SettingButton", "instance": "_setting_instance"},
		{"name": "backup", "button": "%LogInButton", "instance": "_backup_app_instance"},
		{"name": "gallery", "button": "%GalleryButton", "instance": "_gallery_instance"}]:
		var button: Button = menu.get_node(screen.button)
		if not await _prepare_pointer(button, screen.name): return
		if not await _click(button, screen.name): return
		var deadline := Time.get_ticks_msec() + 60000
		var view: Node = menu.get(screen.instance)
		while (not is_instance_valid(view) or not view.is_visible_in_tree() or menu._title_transition) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			view = menu.get(screen.instance)
		if not _check(is_instance_valid(view) and view.is_visible_in_tree() and not menu._title_transition,
			screen.name + " did not open"): return
		if screen.name == "backup" and not _check(menu._login_result.get("ok", false), "Backup projection failed"): return
		await RenderingServer.frame_post_draw
		mark(screen.name + "_drawn")
		gap_scope = ""
		if not _capture(screen.name): return
		var home: Button = menu._title_home
		if not await _prepare_pointer(home, screen.name + "_home"): return
		if not await _click(home, screen.name + "_home"): return
		deadline = Time.get_ticks_msec() + 10000
		while (view.is_visible_in_tree() or menu._title_transition) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not _check(not view.is_visible_in_tree() and not menu._title_transition, screen.name + " Home did not close"): return
	_finish(true)

func _new_acc(menu: Node, button: Button) -> void:
	var saves := get_node("/root/SaveManager")
	var bridge := get_node("/root/DialogicBridge")
	var game := get_node("/root/GameState")
	if not await _prepare_pointer(button, "new_acc"): return
	if not await _click(button, "new_acc"): return
	var confirmed := false
	var deadline := Time.get_ticks_msec() + 300000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(menu) and is_instance_valid(menu._confirmation) and menu._confirmation.is_visible_in_tree() and not menu._title_transition:
			if not _check(case_name == "retained" and not confirmed and not str(menu._new_acc_token).is_empty(), "unexpected New Acc confirmation"): return
			await RenderingServer.frame_post_draw
			mark("consent_drawn")
			gap_scope = ""
			if not _capture("consent"): return
			if not await _prepare_pointer(menu._confirmation.confirm_button, "confirm"): return
			confirmed = true
			if not await _click(menu._confirmation.confirm_button, "confirm"): return
		var caption: Node = get_node("/root/SceneRouter")._production_pause._find_caption(get_tree().root)
		if is_instance_valid(caption) and caption.caption_text.is_visible_in_tree():
			if not milestones.has("caption_first_visible"): mark("caption_first_visible")
			var native: Node = caption.caption_text
			var event: Resource = bridge._runtime_adapter._current_skip_text(true)
			# DialogicTextEvent.States.DONE == 2; avoid a preload dependency from the observer.
			if bridge._runtime_adapter.current_line_id() == FIRST_LINE and event != null and int(event.get("state")) == 2 \
				and not native.revealing and native.visible_ratio == 1.0 and bridge.is_current_line_presentation_acknowledged() \
				and not saves._new_run_busy and game.capture_live_session().value.active:
				await RenderingServer.frame_post_draw
				mark("caption_complete_drawn_idle")
				gap_scope = ""
				observation = {"line_id": FIRST_LINE, "text": native.get_parsed_text(), "visible_ratio": native.visible_ratio,
					"event_done": true, "new_run_busy": false, "active": true}
				break
		await get_tree().process_frame
	if not _check(not observation.is_empty() and confirmed == (case_name == "retained"), "complete caption/expected consent not reached"): return
	var locale: String = get_node("/root/LocalizationManager").get_locale()
	var texts: Dictionary = load("res://scripts/localization/StoryLocalization.gd").catalog(locale)
	if not _check(observation.text == texts.get(FIRST_LINE, FIRST_EN), "caption differs from authored text"): return
	var incomplete: Dictionary = saves._continuation_journal.list_incomplete()
	if not _check(incomplete.get("ok", false) and incomplete.value.is_empty(), "New Acc journal not settled"): return
	if not _capture("caption"): return
	_finish(true)

func _finish(ok: bool) -> void:
	if finished: return
	finished = true
	var rendering := {}
	for method: String in ["get_current_rendering_method", "get_current_rendering_driver_name", "get_video_adapter_name", "get_video_adapter_api_version"]:
		if RenderingServer.has_method(method): rendering[method] = RenderingServer.call(method)
	var preferences := {}
	var profile := get_node_or_null("/root/ProfileManager")
	if profile != null:
		for key: String in ["preferences.language.primary_locale_id", "preferences.accessibility.text_size", "preferences.accessibility.font_style", "preferences.reading.reveal_speed", "preferences.reading.auto_enabled"]:
			preferences[key] = profile.get_preference(key, null)
	var report := {"complete": ok, "case": case_name, "journey": journey, "minimal": minimal,
		"autoload_trace": Engine.get_meta("_dwm_autoload_trace", []),
		"autoload_trace_scope": "Optional constructor begin/end stamps. Previous constructor end to next constructor begin includes dependency loading, member initialization and engine bookkeeping. It is not pure disk time or an exclusive dependency cost. All autoloads are constructed before the first root add_child; probe_enter_tree is later than these constructors.",
		"milestones": milestones, "phases": phases, "inputs": inputs, "observation": observation, "font_cache": font_cache,
		"max_frame_gap_us": frame_gaps, "failures": failures, "rendering": rendering,
		"engine": Engine.get_version_info(), "preferences": preferences, "display_server": DisplayServer.get_name(),
		"window_size": str(get_window().size), "viewport_size": str(get_viewport().get_visible_rect().size),
		"user_path": ProjectSettings.globalize_path("user://"), "argv": OS.get_cmdline_args(),
		"scope": "Instrumented exported game. Fresh means empty user data, not cold OS cache. First accepted input follows screenshot and pointer-setup dwell; use drawn-usable Title for startup comparison. Separate new_acc and screens processes avoid first-open warming of New Acc. Screen opening order is settings, backup, gallery; shared-resource warming is not isolated per screen. Frame gaps begin with probe process_frame and exclude explicit capture/pointer dwell. Inclusive bootstrap phases overlap."}
	var output := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t") + "\n")
		output.close()
	else: ok = false
	print("EXPORTED_STARTUP_PROBE ", JSON.stringify(report))
	get_tree().quit(0 if ok else 1)
