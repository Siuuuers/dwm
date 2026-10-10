extends "res://tests/ui/render_witnessed_caption.gd"
## Real OS actions drive installed Dialogic; review entry alone is fixture setup.

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
	# Freeze elapsed-time reveal, including when review exit calls set_process(true).
	# Native accessibility callbacks and Dialogic reveal/advance methods are unchanged.
	_caption.caption_text.process_mode = Node.PROCESS_MODE_DISABLED
	_runtime.Text.text_started.connect(func(_info: Dictionary):
		_caption.caption_text.set_process(false)
		_caption.set_process(false))
	var captions := [FIRST, SECOND, "Third witnessed caption.",
		"The live fourth caption stays partial.", "Guard caption."]
	var timeline := DialogicTimeline.new()
	timeline.from_text("\n".join(captions))
	_runtime.start(timeline)
	await _frames()
	_caption.caption_text.grab_focus()
	await _wait_input_delay()
	if not _valid(0, true, 0):
		_finish(false, "initial_state")
		return
	# Three earlier captions are required by the existing review-window policy.
	# Build that history through native actions, not forged scrollback or callbacks.
	for index: int in range(3):
		var reveal_stage: String = ["reveal", "second-reveal", "third-reveal"][index]
		var advance_stage: String = ["advance", "second-advance", "third-advance"][index]
		if not await _native_action(reveal_stage, title, index, false, index + 1, captions[index]): return
		if not await _native_action(advance_stage, title, index + 1, true, index + 1, captions[index + 1]): return
		if index == 0: await _capture_native("successor")
	var before := _state()
	var invariant := _review_invariants()
	# Entering review is scoped fixture setup, not native-navigation acceptance.
	_caption._set_review_offset(1)
	await _frames()
	if int(_caption.get_caption_projection().review_offset) != 1 \
			or _caption.review_current.get_parsed_text() != captions[2] \
			or not _caption.review_current.has_focus() or _review_invariants() != invariant:
		_finish(false, "review_setup")
		return
	var reviewing := _state()
	await _ready("review-return", title)
	var deadline := Time.get_ticks_msec() + 30000
	while int(_caption.get_caption_projection().review_offset) == 1 \
			and _runtime.current_event_idx == 3 and _finished == 3 and Time.get_ticks_msec() < deadline:
		await process_frame
	await _wait_input_delay()
	await create_timer(0.3).timeout
	await _frames()
	var returned := _state()
	var unchanged := _review_invariants() == invariant
	if not _valid(3, true, 3) or int(returned.review_offset) != 0 or not unchanged \
			or not returned.live_visible or returned.review_visible or not returned.live_focused:
		_finish(false, "review_return_only", {"review_return": {
			"before": before, "reviewing": reviewing, "returned": returned, "invariants_unchanged": unchanged}})
		return
	await _capture_native("returned-live")
	# Fresh actions must remain independent: reveal this beat, then advance once.
	if not await _native_action("fresh-reveal", title, 3, false, 4, captions[3]): return
	if not await _native_action("fresh-advance", title, 4, true, 4, captions[4]): return
	await _capture_native("fresh-successor")
	_finish(true, "nine_native_invocations", {"review_return": {
		"before": before, "reviewing": reviewing, "returned": returned,
		"invariants_unchanged": unchanged, "native_history_unchanged": true,
		"entry_scope": "Existing presentation owner called only to prepare review; exit uses native UIA."}})

func _native_action(stage: String, title: String, event: int, revealing: bool, finished: int, text: String) -> bool:
	if _valid(event, revealing, finished):
		_finish(false, stage + "_already_at_destination")
		return false
	await _ready(stage, title)
	var deadline := Time.get_ticks_msec() + 30000
	while not _valid(event, revealing, finished) and Time.get_ticks_msec() < deadline:
		if _runtime.current_event_idx > event or _finished > finished or _ended != 0: break
		await process_frame
	await _wait_input_delay()
	await create_timer(0.3).timeout
	await _frames()
	if not _valid(event, revealing, finished) or _caption.caption_text.get_parsed_text() != text \
			or int(_caption.get_caption_projection().review_offset) != 0:
		_finish(false, stage)
		return false
	return true

func _review_invariants() -> Dictionary:
	var invariant := _invariants()
	invariant["full_history"] = _runtime.History.full_event_history_content.duplicate(true)
	invariant["revealing"] = _caption.caption_text.revealing
	invariant["reveal_generation"] = _caption.caption_text.get_reveal_generation()
	return invariant

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
	var review: int = _caption.get_caption_projection().review_offset
	return {"event_index": _runtime.current_event_idx, "revealing": _caption.caption_text.revealing,
		"text": _caption.caption_text.get_parsed_text(), "finished": _finished, "ended": _ended,
		"physical_contacts": root.get_node("InputManager").get_physical_contacts().size(),
		"reveal_generation": _caption.caption_text.get_reveal_generation(),
		"visible_characters": _caption.caption_text.visible_characters,
		"total_characters": _caption.caption_text.get_total_character_count(),
		"review_offset": review, "live_visible": _caption.caption_text.is_visible_in_tree(),
		"review_visible": _caption.review_current.is_visible_in_tree(),
		"live_focused": _caption.caption_text.has_focus(), "review_focused": _caption.review_current.has_focus(),
		"target_text": _caption.review_current.get_parsed_text() if review > 0 else _caption.caption_text.get_parsed_text(),
		"simple_history": _runtime.History.simple_history_content.duplicate(true),
		"full_history": _runtime.History.full_event_history_content.duplicate(true)}

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

func _finish(ok: bool, phase: String, proof: Dictionary = {}) -> void:
	ok = ok and _captures_ok
	var result := _state()
	result.merge({"ok": ok, "phase": phase,
		"scope": "Synthetic mounted caption; Windows UIA invocation only. Review entry is fixture setup, not native navigation. No whole-screen-reader or production route acceptance."})
	result.merge(proof)
	var file := FileAccess.open(_evidence.path_join("runtime.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")
		file.close()
	else:
		ok = false
		result.ok = false
	print("CAPTION_RESULT " + JSON.stringify(result))
	quit(0 if ok else 1)
