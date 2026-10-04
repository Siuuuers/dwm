extends "res://tests/ui/render_witnessed_caption.gd"
## Two real OS actions drive installed Dialogic; no direct input/callback invocation.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FIRST := "Native caption activation fixture."
const SECOND := "The successor keeps its own reveal."
var _evidence := ""
var _captures_ok := true

func _initialize() -> void:
	_run_native.call_deferred()

func _run_native() -> void:
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests/").replace("\\", "/")
	_evidence = OS.get_environment("DWM_CAPTION_EVIDENCE_ROOT").replace("\\", "/").simplify_path()
	var evidence_allowed := ProjectSettings.globalize_path("res://.godot/ci/").replace("\\", "/")
	if not isolated.to_lower().begins_with(allowed.to_lower()) \
			or not _evidence.to_lower().begins_with(evidence_allowed.to_lower()) \
			or not DirAccess.dir_exists_absolute(isolated) \
			or not DirAccess.dir_exists_absolute(_evidence) \
			or DisplayServer.get_name() == "headless" or not is_accessibility_enabled():
		quit(1)
		return
	var profile: Node = root.get_node("ProfileManager")
	var locale: Node = root.get_node("LocalizationManager")
	if not profile.initialize(STORAGE.new(isolated.path_join("profile"))).get("ok", false) \
			or not locale.initialize(profile).get("ok", false):
		quit(1)
		return
	if not await _mount():
		quit(1)
		return
	_layout.reparent(root)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var title := "DWM Native Caption Accept %d" % OS.get_process_id()
	DisplayServer.window_set_title(title)
	# Stationary typewriters make the OS action, rather than elapsed runner time,
	# the only way to finish. Dialogic's actual reveal/input owners remain intact.
	_runtime.Text.text_started.connect(func(_info: Dictionary):
		_caption.caption_text.set_process(false)
		_caption.set_process(false))
	var timeline := DialogicTimeline.new()
	timeline.from_text(FIRST + "\n" + SECOND + "\nGuard caption.")
	_runtime.start(timeline)
	await _frames()
	_caption.caption_text.grab_focus()
	await _wait_input_delay()
	if not _valid(0, true, 0):
		_finish(false, "initial_state")
		return
	await _ready("reveal", title)
	var deadline := Time.get_ticks_msec() + 30000
	while _finished == 0 and _runtime.current_event_idx == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	await _wait_input_delay()
	if not _valid(0, false, 1):
		_finish(false, "reveal_only")
		return
	await _ready("advance", title)
	deadline = Time.get_ticks_msec() + 30000
	while _runtime.current_event_idx == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(0.3).timeout
	await _frames()
	var ok: bool = _valid(1, true, 1) and _caption.caption_text.get_parsed_text() == SECOND
	await _capture_native("successor")
	_finish(ok, "two_native_invocations")

func _wait_input_delay() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not _runtime.Inputs.input_block_timer.is_stopped() and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames()

func _valid(event: int, revealing: bool, finished: int) -> bool:
	return _runtime.current_event_idx == event and _caption.caption_text.revealing == revealing \
		and _finished == finished and _ended == 0 and not _runtime.paused \
		and _runtime.Inputs.input_block_timer.is_stopped() \
		and root.get_node("InputManager").get_physical_contacts().is_empty()

func _state() -> Dictionary:
	return {"event_index": _runtime.current_event_idx, "revealing": _caption.caption_text.revealing,
		"text": _caption.caption_text.get_parsed_text(), "finished": _finished, "ended": _ended,
		"physical_contacts": root.get_node("InputManager").get_physical_contacts().size(),
		"reveal_generation": _caption.caption_text.get_reveal_generation()}

func _ready(stage: String, title: String) -> void:
	await _capture_native(stage)
	var state := _state()
	state.merge({"stage": stage, "pid": OS.get_process_id(), "window_title": title})
	print("CAPTION_READY " + JSON.stringify(state))

func _capture_native(stage: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	if pixels == null or pixels.save_png(_evidence.path_join(stage + ".png")) != OK:
		_captures_ok = false
		push_error("NATIVE_CAPTION_CAPTURE_FAILED")

func _finish(ok: bool, phase: String) -> void:
	ok = ok and _captures_ok
	var result := _state()
	result.merge({"ok": ok, "phase": phase,
		"scope": "Synthetic mounted caption; Windows UIA discovery/invocation only. No whole-screen-reader or production route acceptance."})
	var file := FileAccess.open(_evidence.path_join("runtime.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")
		file.close()
	else:
		ok = false
		result.ok = false
	print("CAPTION_RESULT " + JSON.stringify(result))
	quit(0 if ok else 1)
