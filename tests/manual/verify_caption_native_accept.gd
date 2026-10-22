extends "res://tests/ui/render_witnessed_caption.gd"
## Native wheel entry and UIA return; the nonzero reveal count alone is fixture setup.
## Frozen elapsed-time reveal is not a timed-lifecycle or production-consequence proof.

const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FIRST := "Native caption activation fixture."
const SECOND := "The successor keeps its own reveal."
const PARTIAL_PREFIX := "The live fourth"
var _evidence := ""
var _captures_ok := true
var _run_token := ""
var _native_captures: Dictionary = {}
var _partial_setup: Dictionary = {}
var _journey: Dictionary = {}
var _partial_rect := Rect2i()
var _partial_pixels := PackedByteArray()
var _clock_freezes: Array[Dictionary] = []
var _gui_wheels: Array[Dictionary] = []

func _initialize() -> void:
	_run_native.call_deferred()

func _run_native() -> void:
	_run_token = OS.get_environment("DWM_CAPTION_RUN_TOKEN")
	var isolated := OS.get_environment("DWM_TEST_ROOT").replace("\\", "/").simplify_path()
	var allowed := ProjectSettings.globalize_path("res://.godot/phase2r_tests/").replace("\\", "/")
	_evidence = OS.get_environment("DWM_CAPTION_EVIDENCE_ROOT").replace("\\", "/").simplify_path()
	var evidence_allowed := ProjectSettings.globalize_path("res://.godot/ci/").replace("\\", "/")
	if _run_token.length() != 32 or not isolated.to_lower().begins_with(allowed.to_lower()) \
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
	# Keep the real control's process mode: GUI delivery requires can_process().
	# Connect after the owner's reveal-start sync. Review return also syncs first,
	# then grabs live focus; freeze synchronously there, before any idle reveal tick.
	_caption.caption_text.started_revealing_text.connect(_freeze_elapsed_reveal.bind("reveal_started"))
	_caption.caption_text.focus_entered.connect(_freeze_elapsed_reveal.bind("live_focus_entered"))
	_caption.caption_text.gui_input.connect(_observe_gui_wheel)
	_runtime.Text.text_started.connect(func(_info: Dictionary):
		_freeze_elapsed_reveal("text_started")
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
	if not await _prepare_partial(captions[3]): return
	var before := _state()
	var invariant := _review_invariants()
	_journey["review_entry"] = {"before": before, "observed_offsets": [0]}
	# Observe native delivery only. No offset setter, Viewport event or callback fallback.
	if not await _ready("review-enter", title): return
	var deadline := Time.get_ticks_msec() + 30000
	while int(_caption.get_caption_projection().review_offset) == 0 and Time.get_ticks_msec() < deadline:
		if _review_invariants() != invariant: break
		await process_frame
	await _wait_input_delay()
	await create_timer(0.3).timeout
	await _frames()
	var reviewing := _state()
	_journey.review_entry.observed_offsets.append(int(reviewing.review_offset))
	_journey.review_entry["after"] = reviewing
	_journey.review_entry["invariants_unchanged"] = _review_invariants() == invariant
	if not _valid(3, true, 3) or int(reviewing.review_offset) != 1 \
			or reviewing.target_text != captions[2] or not reviewing.review_focused \
			or not reviewing.review_visible or reviewing.live_visible or _review_invariants() != invariant:
		await _capture_native("review-entry-failed")
		_finish(false, "native_review_entry")
		return
	_journey["review_return"] = {"before": before, "reviewing": reviewing}
	if not await _ready("review-return", title): return
	deadline = Time.get_ticks_msec() + 30000
	while int(_caption.get_caption_projection().review_offset) == 1 and Time.get_ticks_msec() < deadline:
		if _review_invariants() != invariant: break
		await process_frame
	await _wait_input_delay()
	await create_timer(0.3).timeout
	await _frames()
	var returned := _state()
	var unchanged := _review_invariants() == invariant
	_journey.review_return["returned"] = returned
	_journey.review_return["invariants_unchanged"] = unchanged
	_journey.review_return["native_history_unchanged"] = returned.simple_history == before.simple_history \
		and returned.full_history == before.full_history
	if not _valid(3, true, 3) or int(returned.review_offset) != 0 or not unchanged \
			or not returned.live_visible or returned.review_visible or not returned.live_focused \
			or returned.scroll_offset != before.scroll_offset:
		await _capture_native("review-return-failed")
		_finish(false, "review_return_only")
		return
	var returned_image := await _capture_native("returned-live")
	var same_pixels := returned_image != null and returned_image.get_region(_partial_rect).get_data() == _partial_pixels
	_journey.review_return["partial_pixels_equal"] = same_pixels
	if not same_pixels:
		_finish(false, "returned_partial_pixels")
		return
	# Fresh actions must remain independent: reveal this beat, then advance once.
	if not await _native_action("fresh-reveal", title, 3, false, 4, captions[3]): return
	if not await _native_action("fresh-advance", title, 4, true, 4, captions[4]): return
	await _capture_native("fresh-successor")
	_finish(true, "native_wheel_entry_and_nine_invocations")

func _prepare_partial(text: String) -> bool:
	if not _valid(3, true, 3) or _caption.caption_text.visible_characters != 0 \
			or _caption.caption_text.get_parsed_text() != text or not text.begins_with(PARTIAL_PREFIX) \
			or PARTIAL_PREFIX.length() >= _caption.caption_text.get_total_character_count():
		_finish(false, "partial_setup_source")
		return false
	var zero := await _capture_native("partial-zero")
	var expected := _review_invariants()
	# Deliberate fixture seed, not elapsed reveal. The actual text/reveal owner is retained.
	_caption.caption_text.visible_characters = PARTIAL_PREFIX.length()
	expected.visible = PARTIAL_PREFIX.length()
	await _frames()
	var partial := await _capture_native("before-review")
	if zero == null or partial == null or zero.get_size() != partial.get_size() \
			or partial.get_size() != Vector2i(1280, 720) or _review_invariants() != expected:
		_finish(false, "partial_setup_state")
		return false
	var projection: Dictionary = _caption.get_caption_projection()
	var full_rect: Rect2 = projection.caption_rect
	_partial_rect = Rect2i(full_rect)
	if not _partial_rect.has_area() or Rect2(_partial_rect) != full_rect \
			or not Rect2(Vector2.ZERO, Vector2(partial.get_size())).encloses(full_rect) \
			or projection.caption_visible_rect != full_rect:
		_finish(false, "partial_setup_clipped")
		return false
	var changed := 0
	for y in range(_partial_rect.position.y, _partial_rect.end.y):
		for x in range(_partial_rect.position.x, _partial_rect.end.x):
			if not _same_color(zero.get_pixel(x, y), partial.get_pixel(x, y)): changed += 1
	var masked_zero: Image = zero.duplicate()
	masked_zero.blit_rect(partial, _partial_rect, _partial_rect.position)
	var outside_unchanged := masked_zero.get_data() == partial.get_data()
	_partial_setup = {"method": "fixture_visible_characters_assignment", "expected_prefix": PARTIAL_PREFIX,
		"visible_characters": PARTIAL_PREFIX.length(), "changed_caption_pixels": changed,
		"outside_caption_unchanged": outside_unchanged, "caption_fully_visible": true,
		"caption_pixel_rect": [_partial_rect.position.x, _partial_rect.position.y, _partial_rect.size.x, _partial_rect.size.y],
		"zero_capture": "partial-zero", "partial_capture": "before-review", "naturally_elapsed": false}
	if changed <= 20 or not outside_unchanged or not _valid(3, true, 3):
		_finish(false, "partial_prefix_not_rendered")
		return false
	_partial_pixels = partial.get_region(_partial_rect).get_data()
	return true

func _native_action(stage: String, title: String, event: int, revealing: bool, finished: int, text: String) -> bool:
	if _valid(event, revealing, finished):
		_finish(false, stage + "_already_at_destination")
		return false
	if not await _ready(stage, title): return false
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

func _freeze_elapsed_reveal(reason: String) -> void:
	# Fixture clock control only: never repair visible count, generation or state.
	var was_processing: bool = _caption.caption_text.is_processing()
	_caption.caption_text.set_process(false)
	_clock_freezes.append({"reason": reason, "event_index": _runtime.current_event_idx,
		"review_offset": _caption.get_caption_projection().review_offset,
		"can_process": _caption.caption_text.can_process(), "idle_before": was_processing,
		"idle_after": _caption.caption_text.is_processing()})

func _observe_gui_wheel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# Passive signal observer; canonical GUI handlers retain event ownership.
		_gui_wheels.append({"button": event.button_index, "pressed": event.pressed,
			"device": event.device, "review_offset": _caption.get_caption_projection().review_offset})

func _elapsed_reveal_frozen() -> bool:
	var target: Control = _caption.review_current if int(_caption.get_caption_projection().review_offset) > 0 else _caption.caption_text
	return _caption.caption_text.can_process() and target.can_process() \
		and not _caption.caption_text.is_processing() and not _caption.is_processing()

func _wait_input_delay() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not _runtime.Inputs.input_block_timer.is_stopped() and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames()

func _valid(event: int, revealing: bool, finished: int) -> bool:
	return _runtime.current_event_idx == event and _caption.caption_text.revealing == revealing \
		and _finished == finished and _ended == 0 and not _runtime.paused \
		and _runtime.Inputs.input_block_timer.is_stopped() \
		and root.get_node("InputManager").get_physical_contacts().is_empty() \
		and not paused and not Input.is_anything_pressed() and _caption.accept_input.is_source_admitted() \
		and _elapsed_reveal_frozen()

func _state() -> Dictionary:
	var projection: Dictionary = _caption.get_caption_projection()
	var review: int = projection.review_offset
	return {"run_token": _run_token, "source_admitted": _caption.accept_input.is_source_admitted(),
		"caption_process_mode": _caption.caption_text.process_mode,
		"caption_can_process": _caption.caption_text.can_process(),
		"caption_idle_processing": _caption.caption_text.is_processing(),
		"layer_idle_processing": _caption.is_processing(),
		"target_can_process": (_caption.review_current if review > 0 else _caption.caption_text).can_process(),
		"input_delay_stopped": _runtime.Inputs.input_block_timer.is_stopped(),
		"anything_pressed": Input.is_anything_pressed(), "tree_paused": paused, "runtime_paused": _runtime.paused,
		"window_focused": DisplayServer.window_is_focused(),
		"retained_captions": projection.retained_captions.duplicate(), "scroll_offset": projection.scroll_offset,
		"event_index": _runtime.current_event_idx, "revealing": _caption.caption_text.revealing,
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

func _ready(stage: String, title: String) -> bool:
	if not _elapsed_reveal_frozen():
		_finish(false, stage + "_clock_boundary")
		return false
	await _capture_native(stage)
	if not _elapsed_reveal_frozen():
		_finish(false, stage + "_capture_clock_boundary")
		return false
	var state := _state()
	state.merge({"stage": stage, "pid": OS.get_process_id(), "window_title": title,
		"capture": _native_captures.get(stage, {}), "partial_setup": _partial_setup})
	print("CAPTION_READY " + JSON.stringify(state))
	return true

func _capture_native(stage: String) -> Image:
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	var path := _evidence.path_join(stage + ".png")
	if pixels == null or pixels.save_png(path) != OK:
		_captures_ok = false
		push_error("NATIVE_CAPTION_CAPTURE_FAILED")
		return null
	var digest := FileAccess.get_sha256(path)
	if digest.length() != 64:
		_captures_ok = false
		return null
	_native_captures[stage] = {"file": stage + ".png", "sha256": digest,
		"width": pixels.get_width(), "height": pixels.get_height(), "state": _state(),
		"method": "Godot root viewport after frame_post_draw; not a desktop screenshot"}
	return pixels

func _finish(ok: bool, phase: String) -> void:
	ok = ok and _captures_ok
	var result := _state()
	result.merge({"ok": ok, "phase": phase,
		"scope": "Synthetic mounted caption; native wheel entry and UIA return. Seeded count with elapsed reveal disabled. No speech, ScrollPattern, production consequences or timed-lifecycle acceptance.",
		"partial_setup": _partial_setup, "captures": _native_captures,
		"clock_freezes": _clock_freezes, "gui_wheels": _gui_wheels})
	result.merge(_journey)
	var file := FileAccess.open(_evidence.path_join("runtime.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")
		file.close()
	else:
		ok = false
		result.ok = false
	print("CAPTION_RESULT " + JSON.stringify(result))
	quit(0 if ok else 1)
