extends SceneTree
## Bounded, noncanonical native Wait -> text proof. The actual startup, live Run,
## Input/Audio/Profile, Bridge/adapter, caption and production Pause owners run.
## Only the DTL locator and blank scene proxy are fixtures. The installed Dating
## completion port remains unchanged; this proof claims no canonical completion.
## No semantic reading catalogue, durable hold cursor or Hospital route is claimed.

const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const ENTRY := "contact.ordinary.lavinia.day1"
const LINE := "fixture.timed_hold.after"
const HOLD_SECONDS := 2.0
const PAUSE_SECONDS := 2.4

class FixtureCatalog:
	static func get_entry(entry_id: String, _locale: String = "en") -> Dictionary:
		if entry_id != "contact.ordinary.lavinia.day1": return {"ok": false, "code": &"unknown_entry"}
		return {"ok": true, "value": {"entry_id": entry_id, "locale": "en", "requested_locale": "en",
			"path": "res://tests/fixtures/dialogic/timed_hold_journey.dtl", "label": "timed_hold", "used_fallback": false}}

var _bridge: Node
var _runtime: Node
var _pause: Node
var _caption: Node
var _wait: Object
var _tween: Tween
var _completion_owner: Object
var _completion_before: Dictionary = {}
var _stages: Dictionary = {}
var _events: Array[Dictionary] = []
var _text_counts := {"about": 0, "started": 0, "finished": 0}
var _speech_admissions := 0
var _native_ends := 0
var _wait_finishes := 0
var _profile_before: Dictionary = {}
var _profile_bytes := ""
var _native_history_before: Array = []
var _native_visits_before: Dictionary = {}
var _failed := false
var _fixture_scene: Control

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _check(not OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty()
		and DisplayServer.get_name() != "headless", "isolated cloud rendering required"): return
	print("TIMED_HOLD_PROCESS: " + JSON.stringify({"process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://")}))
	await _frames(12)
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready", false), "real production startup ready"): return
	var router: Node = root.get_node("SceneRouter")
	router.goto_menu()
	await _frames(12)
	if not _check(current_scene != null and current_scene.has_node("%NewAccButton"), "real New Account control"): return
	current_scene.get_node("%NewAccButton").pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if not bool(root.get_node("SaveManager").get("_new_run_busy")) and current_scene != null \
			and current_scene.find_child("ComputerDesktop", true, false) != null: break
		await process_frame
	if not _check(current_scene != null and current_scene.find_child("ComputerDesktop", true, false) != null
		and root.get_node("GameState").capture_live_session().value.active, "real New Account activated Run"): return
	# The scene is intentionally a blank fixture, not a production Hospital or
	# contact view. The real Run and router stay mounted; Pause sees this exact
	# scene identity, and the proxy exposes no unrelated desktop input targets.
	var old_scene: Node = current_scene
	_fixture_scene = Control.new()
	_fixture_scene.name = "NoncanonicalTimedHoldScene"
	_fixture_scene.scene_file_path = "res://scenes/main/MainGameScene.tscn"
	_fixture_scene.size = Vector2(1280, 720)
	_fixture_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fixture_scene)
	current_scene = _fixture_scene
	old_scene.queue_free()
	var matte := ColorRect.new()
	matte.color = Color("202a3b")
	matte.size = Vector2(1280, 720)
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixture_scene.add_child(matte)
	await _frames(3)
	var focused := root.gui_get_focus_owner()
	if focused != null: focused.release_focus()
	_bridge = root.get_node("DialogicBridge")
	_runtime = root.get_node("Dialogic")
	_pause = router.get("_production_pause")
	if not _check(is_instance_valid(_pause) and _bridge.initialize(FixtureCatalog).get("ok", false),
		"real production Pause and explicit fixture locator"): return
	_completion_owner = _bridge.get("_playback_completion_port")
	if not _check(is_instance_valid(_completion_owner), "installed completion owner retained"): return
	_completion_before = _completion_snapshot()
	_runtime.History.simple_history_enabled = true
	_runtime.History.visited_event_history_enabled = true
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.Text.about_to_show_text.connect(func(info: Dictionary) -> void: _text_signal("about", info))
	_runtime.Text.text_started.connect(func(info: Dictionary) -> void: _text_signal("started", info))
	_runtime.Text.text_finished.connect(func(info: Dictionary) -> void: _text_signal("finished", info))
	_runtime.timeline_ended.connect(func() -> void: _native_ends += 1)
	var speech: Node = root.get_node("SystemTtsCoordinator")
	speech.speech_admitted.connect(func(_token: int, source: String) -> void:
		_speech_admissions += 1
		_event("speech_admitted", {"source": source}))
	if not _check(speech.refresh_capability("en").get("value", {}).get("available", false), "real native speech capability available"): return
	var profile: Node = root.get_node("ProfileManager")
	if not _check(profile.set_preferences({&"preferences.reading.read_aloud_enabled": true,
		&"preferences.reading.reveal_speed": "slow", &"preferences.reading.auto_enabled": true}).get("ok", false),
		"real Auto On and read-aloud preferences"): return
	_profile_before = profile.get_profile_snapshot().duplicate(true)
	_profile_bytes = FileAccess.get_file_as_string("user://profile.json")
	if not _check(not _profile_bytes.is_empty() and _write("profile-before.json", _profile_bytes), "retain exact baseline Profile bytes"): return
	_native_history_before = _runtime.History.simple_history_content.duplicate(true)
	_native_visits_before = _runtime.History.visited_event_history_content.duplicate(true)
	var started: Dictionary = _bridge.start_entry(ENTRY, {"expected_stage": "current_entry",
		"playback_id": "timed-hold-rendered", "role": "primary", "transaction_id": "timed-hold-rendered-transaction"})
	if not _check(started.get("ok", false), "actual Bridge starts fixture: " + JSON.stringify(started)): return
	deadline = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var frontier: Dictionary = _bridge.capture_pause_frontier()
		_caption = _find_caption(root)
		if frontier.get("ok", false) and frontier.value.get("kind", "") == "timed_hold" \
			and _caption != null and _caption.get_caption_projection().get("timed_hold", false): break
		await process_frame
	if not _check(_caption != null and _bridge.capture_pause_frontier().get("value", {}).get("kind", "") == "timed_hold",
		"owned live native timed hold reached"): return
	_wait = _runtime.current_timeline_events[_runtime.current_event_idx]
	_tween = _wait.get("_tween")
	if not _check(is_instance_valid(_tween), "native Wait owns its real timer"): return
	_wait.event_finished.connect(func(_event_resource: DialogicEvent) -> void: _wait_finishes += 1)
	_stage("hold")
	if not _assert_silent_hold(_stages.hold): return
	if not await _capture("01-hold"): return
	# Real engine input delivery, not a direct advance or fake acceptance callback.
	_key(true)
	await _frames(2)
	_key(false)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	Input.parse_input_event(joy)
	await _frames(1)
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = false
	Input.parse_input_event(joy)
	var pointer := InputEventMouseButton.new()
	pointer.position = Vector2(640, 360)
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	Input.parse_input_event(pointer)
	await _frames(1)
	pointer = InputEventMouseButton.new()
	pointer.position = Vector2(640, 360)
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = false
	Input.parse_input_event(pointer)
	await _frames(2)
	_stage("after_inert_inputs")
	if not _assert_silent_hold(_stages.after_inert_inputs): return
	if not _check(_stages.after_inert_inputs.frontier == _stages.hold.frontier, "inputs cannot advance or replace hold"): return
	var opened: Dictionary = await _pause.request_pause()
	if not _check(opened.get("ok", false) and paused and _runtime.paused, "real production Pause acquired all custody: " + JSON.stringify(opened)): return
	_stage("paused")
	if not _assert_silent_hold(_stages.paused): return
	if not _check(not _pause.can_save_backup() and not _bridge.can_capture_reading_checkpoint()
		and _pause.can_load_backup(), "Save remains unavailable while independent Pause Load remains admitted"): return
	if not await _capture("02-pause"): return
	await create_timer(PAUSE_SECONDS, true).timeout
	_stage("paused_after_deadline")
	if not _assert_silent_hold(_stages.paused_after_deadline): return
	if not _check(_stages.paused.frontier == _stages.paused_after_deadline.frontier
		and absf(_stages.paused.elapsed_seconds - _stages.paused_after_deadline.elapsed_seconds) < 0.000001
		and _stages.paused_after_deadline.tick_msec - _stages.paused.tick_msec >= 2300,
		"same native timer and frontier stay frozen beyond original duration"): return
	var resumed: Dictionary = await _pause.request_continue()
	if not _check(resumed.get("ok", false) and not paused and not _runtime.paused,
		"production Continue releases exact custody: " + JSON.stringify(resumed)): return
	_stage("resumed")
	if not _assert_silent_hold(_stages.resumed): return
	if not _check(_stages.resumed.frontier == _stages.hold.frontier
		and _stages.resumed.elapsed_seconds >= _stages.paused.elapsed_seconds
		and _stages.resumed.elapsed_seconds - _stages.paused.elapsed_seconds < 0.15,
		"resume retains elapsed time and execution token"): return
	if not _check(_write("profile-after-hold.json", FileAccess.get_file_as_string("user://profile.json")), "retain exact post-Pause Profile bytes"): return
	# Keep a press held across native expiry; it cannot accept the next caption.
	_key(true)
	var resumed_at := Time.get_ticks_msec()
	deadline = resumed_at + 10000
	while Time.get_ticks_msec() < deadline and _text_counts.started == 0: await process_frame
	await _frames(3)
	_stage("caption_held")
	if not _check(_text_counts.about == 1 and _text_counts.started == 1 and _wait_finishes == 1
		and _native_ends == 0 and _completion_snapshot() == _completion_before
		and _caption.caption_text.get_parsed_text().begins_with("The timed hold has finished.")
		and _caption.caption_text.has_focus() and not _caption.get_caption_projection().timed_hold,
		"one real caption owns ordinary Focus while old held input is inert"): return
	var remaining := HOLD_SECONDS - float(_stages.resumed.elapsed_seconds)
	if not _check((_stages.caption_held.tick_msec - resumed_at) / 1000.0 >= remaining - 0.15,
		"caption cannot arrive before retained native remaining duration"): return
	_key(false)
	await _frames(3)
	_stage("caption_released")
	if not _check(_native_ends == 0 and _completion_snapshot() == _completion_before and _text_counts.started == 1,
		"release of hold-era input cannot accept the following caption"): return
	if not _check(_speech_admissions == 1 and _bridge.capture_current_speech_presentation().get("ok", false),
		"real caption positively acquires one speech publication"): return
	if not await _capture("03-caption"): return
	# Turn Auto Off only after the positive caption observation, then exercise one
	# fresh real Accept. This is an explicit preference command in the fixture.
	if not _check(profile.set_preferences({&"preferences.reading.auto_enabled": false}).get("ok", false), "explicit post-caption Auto Off"): return
	if not _check(_bridge.get("_runtime_adapter").reveal_current_line(true).get("ok", false), "complete real caption reveal"): return
	await _frames(4)
	_key(true)
	await _frames(2)
	_key(false)
	deadline = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and _native_ends == 0: await process_frame
	await _frames(4)
	if not _check(_native_ends == 1 and _wait_finishes == 1 and _completion_snapshot() == _completion_before
		and not _bridge.has_active_playback(), "fresh input naturally ends exactly one fixture; canonical owner remains unchanged"): return
	_stages["completed"] = {"tick_msec": Time.get_ticks_msec(), "native_ends": _native_ends,
		"wait_finishes": _wait_finishes, "completion_owner": _completion_snapshot(),
		"text_counts": _text_counts.duplicate(true), "speech_admissions": _speech_admissions}
	var report := {"schema_version": 1, "process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"fixture_scope": "Noncanonical ephemeral contact hold; blank main-scene proxy; unchanged installed completion port; no durable reading catalogue or Hospital completion.",
		"hold_seconds": HOLD_SECONDS, "pause_seconds": PAUSE_SECONDS, "entry_id": ENTRY, "line_id": LINE,
		"stages": _stages, "events": _events, "baseline_profile": _profile_before,
		"baseline_completion_owner": _completion_before, "baseline_native_history": _native_history_before, "baseline_native_visits": _native_visits_before}
	if not _check(_write("journey.json", JSON.stringify(_json_value(report), "\t")), "retain exact bounded report"): return
	speech.stop(&"timed_hold_fixture_complete")
	await speech.wait_until_recovered()
	await _runtime.clear()
	await _frames(12)
	print("TIMED_HOLD_JOURNEY_PASS: native hold -> real Pause beyond deadline -> retained timer -> one caption -> fresh input")
	quit(0)

func _assert_silent_hold(state: Dictionary) -> bool:
	var p: Dictionary = state.projection
	return _check(state.frontier.get("kind", "") == "timed_hold" and p.get("timed_hold", false)
		and not p.caption_visible and not p.revealing and p.leaf_rects.is_empty() and p.visible_leaf_rects.is_empty()
		and state.caption_text.is_empty() and not state.caption_focus and not state.caption_visible
		and state.retained.is_empty() and state.scrollback.is_empty() and not state.caption_revealing
		and state.background_filter == Control.MOUSE_FILTER_IGNORE and state.native_timer_identity_matches
		and state.text_counts == {"about": 0, "started": 0, "finished": 0}
		and state.speech_admissions == 0 and state.wait_finishes == 0 and state.native_ends == 0
		and state.completion_owner == _completion_before and not state.reading_checkpoint.ok and not state.speech_publication.ok
		and state.native_history == _native_history_before and state.native_visits == _native_visits_before
		and state.profile == _profile_before and state.profile_bytes_equal
		and state.rail.size() == 6 and state.rail.all(func(button: Dictionary) -> bool:
			return button.disabled and button.focus_mode == Control.FOCUS_NONE and not button.focused),
		"captionless hold has zero text/history/speech/visited/Profile effects and Disabled rail")

func _stage(name: String) -> void:
	var rail: Array[Dictionary] = []
	for key: StringName in [&"history", &"skip", &"auto", &"save", &"load", &"next"]:
		var button: Button = _caption.transport_rail.get("_buttons")[key]
		rail.append({"key": key, "disabled": button.disabled, "focus_mode": button.focus_mode,
			"focused": button.has_focus(), "rect": button.get_global_rect()})
	_stages[name] = {"tick_msec": Time.get_ticks_msec(), "frontier": _bridge.capture_pause_frontier().get("value", {}),
		"elapsed_seconds": _tween.get_total_elapsed_time() if is_instance_valid(_tween) else -1.0,
		"native_timer_identity_matches": is_instance_valid(_wait) and _wait.get("_tween") == _tween,
		"native_pause_frontier": _bridge.get("_runtime_adapter").capture_pause_frontier(),
		"tree_paused": paused, "native_paused": _runtime.paused,
		"can_save_backup": _pause.can_save_backup(), "can_load_backup": _pause.can_load_backup(),
		"can_capture_reading_checkpoint": _bridge.can_capture_reading_checkpoint(),
		"pause_state": _pause.coordinator.get_state(), "projection": _caption.get_caption_projection(),
		"caption_text": _caption.caption_text.get_parsed_text(), "caption_visible": _caption.caption_text.is_visible_in_tree(),
		"caption_focus": _caption.caption_text.has_focus(), "caption_revealing": _caption.caption_text.revealing,
		"retained": _caption.get("_retained").duplicate(), "scrollback": _caption.get("_scrollback").duplicate(),
		"background_filter": _caption.background_input.mouse_filter, "rail": rail,
		"text_counts": _text_counts.duplicate(true), "speech_admissions": _speech_admissions,
		"native_ends": _native_ends, "wait_finishes": _wait_finishes,
		"completion_owner": _completion_snapshot(),
		"native_history": _runtime.History.simple_history_content.duplicate(true),
		"native_visits": _runtime.History.visited_event_history_content.duplicate(true),
		"reading_history": _bridge.get_reading_history(), "reading_checkpoint": _bridge.capture_reading_checkpoint(false),
		"speech_publication": _bridge.capture_current_speech_presentation(),
		"profile": root.get_node("ProfileManager").get_profile_snapshot().duplicate(true),
		"profile_bytes_equal": FileAccess.get_file_as_string("user://profile.json") == _profile_bytes}
	_event("stage", {"name": name})

func _completion_snapshot() -> Dictionary:
	var result := {"instance_id": _completion_owner.get_instance_id(),
		"bridge_owner_id": _bridge.get("_playback_completion_port").get_instance_id()}
	for key: String in ["_command", "_phase", "_entry_id", "_context", "_receipt", "_status", "_failure", "_starting", "_early_completion"]:
		var value: Variant = _completion_owner.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _text_signal(kind: String, info: Dictionary) -> void:
	_text_counts[kind] += 1
	_event("text_" + kind, {"text": str(info.get("text", ""))})

func _event(kind: String, value: Dictionary) -> void:
	_events.append({"sequence": _events.size() + 1, "tick_msec": Time.get_ticks_msec(), "kind": kind, "value": value})

func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	Input.parse_input_event(event)

func _find_caption(node: Node) -> Node:
	if node.get_script() == CAPTION: return node
	for child: Node in node.get_children():
		var found := _find_caption(child)
		if found != null: return found
	return null

func _frames(count: int) -> void:
	for index: int in count: await process_frame

func _path(name: String) -> String:
	var folder := ProjectSettings.globalize_path("user://evidence/timed-hold")
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(name)

func _write(name: String, text: String) -> bool:
	var file := FileAccess.open(_path(name), FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.close()
	return true

func _capture(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	return _check(pixels != null and not pixels.is_empty() and pixels.save_png(_path(name + ".png")) == OK,
		"retain cloud screenshot " + name)

func _json_value(value: Variant) -> Variant:
	if value is Rect2: return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}
	if value is Vector2 or value is Vector2i: return {"x": value.x, "y": value.y}
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key)] = _json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json_value(item))
		return result
	if value is Object: return {"instance_id": value.get_instance_id()} if is_instance_valid(value) else null
	return value

func _check(value: bool, detail: String) -> bool:
	if not value and not _failed:
		_failed = true
		_write("failure.json", JSON.stringify(_json_value({"detail": detail, "stages": _stages, "events": _events}), "\t"))
		printerr("TIMED_HOLD_JOURNEY_FAIL: " + detail)
		quit(1)
	return value
