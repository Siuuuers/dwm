extends GutTest
## Real installed Wait, Bridge, adapter and mounted layout. Only the locator and
## completion recorder are test seams; durations are explicitly noncanonical.
## Adapter Pause tests the native timer, not production Pause admission/UI.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const COMPLETIONS := preload("res://tests/support/FakeDialogicPlaybackCompletionPort.gd")
const FIXTURE := "res://tests/fixtures/dialogic/timed_hold_runtime.dtl"
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const ENTRY := "contact.ordinary.lavinia.day1"
const HOLD_SECONDS := 2.0

class FixtureCatalog:
	static func get_entry(entry_id: String, _locale: String = "en") -> Dictionary:
		if entry_id != "contact.ordinary.lavinia.day1":
			return {"ok": false, "code": &"unknown_entry"}
		return {"ok": true, "value": {"entry_id": entry_id, "locale": "en",
			"requested_locale": "en", "path": "res://tests/fixtures/dialogic/timed_hold_runtime.dtl",
			"label": "timed_hold", "used_fallback": false}}

var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
var _bridge: Node
var _completions: RefCounted
var _viewport: SubViewport
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _style_directory: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _profile_before: Dictionary = {}
var _fixture_layouts: Array[Node] = []
var _fixture_text_nodes: Array[Node] = []
var _fixture_tweens: Array[Tween] = []
var _native_starts := 0
var _native_ends := 0
var _wait_finishes := 0
var _animation_interrupts := 0
var _native_text: Array[Dictionary] = []
var _observed_wait_start_msec := 0

func before_each() -> void:
	_native_starts = 0
	_native_ends = 0
	_wait_finishes = 0
	_animation_interrupts = 0
	_native_text.clear()
	_fixture_layouts.clear()
	_fixture_text_nodes.clear()
	_fixture_tweens.clear()
	_profile_before = get_node("/root/ProfileManager").get_profile_snapshot().duplicate(true)
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.simple_history_enabled = true
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.Inputs.auto_skip.enabled = false
	_runtime.timeline_started.connect(func() -> void: _native_starts += 1)
	_runtime.timeline_ended.connect(func() -> void: _native_ends += 1)
	_runtime.Animations.animation_interrupted.connect(func() -> void: _animation_interrupts += 1)
	_runtime.Text.text_started.connect(func(info: Dictionary) -> void: _native_text.append(info.duplicate(true)))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	add_child(_viewport)
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_completions = COMPLETIONS.new()
	_bridge = BRIDGE.new()
	add_child(_bridge)
	assert_true(_bridge.initialize(FixtureCatalog, _adapter).ok)
	assert_true(_bridge.configure_playback_completion_port(_completions).ok)

func after_each() -> void:
	# Only exact fixture timers/layouts are retired. Killing any still-live timer
	# occurs after every assertion, so an intentionally red test cannot leak its
	# abandoned callback into the next test or the restored production runtime.
	for tween: Tween in _fixture_tweens:
		if is_instance_valid(tween): tween.kill()
	if is_instance_valid(_bridge) and not _bridge._active_entry.is_empty():
		_bridge.abort_current_entry(&"timed_hold_fixture_teardown")
	if is_instance_valid(_bridge): _bridge.free()
	for text_node: Node in _fixture_text_nodes:
		if is_instance_valid(text_node): text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		await get_tree().process_frame
	for layout: Node in _fixture_layouts:
		if is_instance_valid(layout): layout.free()
	for text_node: Node in _fixture_text_nodes:
		assert_false(is_instance_valid(text_node), "caption must retire with its exact fixture layout")
		if is_instance_valid(text_node): text_node.free()
	if is_instance_valid(_viewport): _viewport.free()
	if is_instance_valid(_runtime): _runtime.free()
	_adapter = null
	_completions = null
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout) and is_instance_valid(_original_layout_parent):
		_original_layout_parent.add_child(_original_layout)
		_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null
	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before,
		"native hold tests never mutate the real Profile")

func _mount_fixture() -> bool:
	var layout: Node = _runtime.Styles.load_style(STYLE, _viewport)
	assert_not_null(layout, "the native fixture has its own mounted Witnessed layout")
	if layout == null: return false
	_fixture_layouts.append(layout)
	for frame: int in 4: await get_tree().process_frame
	assert_same(layout.get_parent(), _viewport)
	for layer: Node in layout.get_layers():
		if layer.get_script() != null and layer.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd":
			var text_node: Node = layer.caption_text
			assert_true(layout.is_ancestor_of(text_node))
			_fixture_text_nodes.append(text_node)
	return true

func _begin(suffix: String) -> Dictionary:
	var context := {"expected_stage": "current_entry", "playback_id": "native-hold-" + suffix,
		"role": "primary", "transaction_id": "native-hold-transaction-" + suffix}
	var begun: Dictionary = _bridge.start_entry(ENTRY, context)
	return begun

func _start_wait(suffix: String) -> DialogicWaitEvent:
	if not await _mount_fixture(): return null
	var begun := _begin(suffix)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return null
	var deadline := get_tree().create_timer(3.0)
	while deadline.time_left > 0.0:
		var index: int = _runtime.current_event_idx
		if index >= 0 and index < _runtime.current_timeline_events.size():
			var event: Variant = _runtime.current_timeline_events[index]
			if event is DialogicWaitEvent and _runtime.current_state == _runtime.States.WAITING:
				_observed_wait_start_msec = Time.get_ticks_msec()
				assert_almost_eq(event.time, HOLD_SECONDS, 0.001, "test-owned duration has no production meaning")
				assert_false(event.skippable)
				assert_true(is_instance_valid(event._tween), "installed native Wait owns an actual timer")
				_fixture_tweens.append(event._tween)
				return event
		await get_tree().process_frame
	assert_true(false, "native Wait never entered WAITING within its fixture startup budget")
	return null

func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _await_natural_end() -> void:
	var deadline := get_tree().create_timer(4.0)
	while _completions.intents.is_empty() and deadline.time_left > 0.0:
		await get_tree().process_frame
	assert_eq(_completions.intents.size(), 1, "one actual return produces one semantic natural completion")
	if _completions.intents.size() == 1:
		assert_eq(str(_completions.intents[0].completion_kind), "natural_end")
	await get_tree().process_frame
	await get_tree().process_frame

func _assert_captionless_native_observations() -> void:
	assert_true(_native_text.is_empty(), "Wait emits no native text_started publication")
	assert_true(_runtime.History.simple_history_content.is_empty(), "Wait creates no native History entry")

func test_normal_native_hold_waits_then_completes_once_without_caption_or_history() -> void:
	var event := await _start_wait("normal")
	if event == null: return
	await _wait_seconds(0.30)
	assert_eq(_runtime.current_state, _runtime.States.WAITING)
	assert_true(_completions.intents.is_empty(), "native timer cannot complete at the early observation")
	await _await_natural_end()
	assert_eq(_native_starts, 1)
	assert_eq(_native_ends, 1)
	assert_false(_bridge.has_active_playback())
	_assert_captionless_native_observations()

func test_cancel_then_same_path_replacement_outlives_old_wait_deadline_without_stale_effects() -> void:
	var old_event := await _start_wait("cancelled")
	if old_event == null: return
	var first_started := _observed_wait_start_msec
	await _wait_seconds(0.80)
	assert_true(_bridge.abort_current_entry(&"fixture_same_path_replacement").ok)
	for frame: int in 4: await get_tree().process_frame
	assert_false(_bridge.has_active_playback(), "real native cancellation drains before replacement")
	assert_true(_completions.intents.is_empty(), "cancellation is never natural completion")
	var replacement := await _start_wait("replacement")
	if replacement == null: return
	var replacement_started := _observed_wait_start_msec
	assert_same(replacement, old_event, "same path and label exercise the cached native Wait resource")
	replacement.event_finished.connect(func(_event: DialogicEvent) -> void: _wait_finishes += 1, CONNECT_ONE_SHOT)
	var generation := _runtime.get_timeline_generation()
	var event_index := _runtime.current_event_idx
	var ends_before := _native_ends
	# A real subsystem animation is a sentinel for a foreign stop_animation call.
	# No synthetic event completion or native end is emitted by this fixture.
	_runtime.Animations.start_animating()
	var interrupts_before := _animation_interrupts
	await _wait_seconds(1.40)
	var observed := Time.get_ticks_msec()
	print("TIMED_HOLD_REPLACEMENT_OBSERVATION " + JSON.stringify({
		"first_started_msec": first_started, "replacement_started_msec": replacement_started,
		"observed_msec": observed, "hold_msec": int(HOLD_SECONDS * 1000.0),
		"event_finishes": _wait_finishes, "semantic_completions": _completions.intents.size()}))
	assert_gt(observed - first_started, int(HOLD_SECONDS * 1000.0), "observation must cross the old physical deadline")
	assert_lt(observed - replacement_started, int(HOLD_SECONDS * 1000.0), "observation must precede the replacement deadline")
	assert_eq(_wait_finishes, 0, "retired Wait callback must not finish the reused replacement event")
	assert_eq(_completions.intents.size(), 0, "old deadline cannot complete replacement playback")
	assert_eq(_native_ends, ends_before, "old deadline cannot stop the replacement native timeline")
	assert_eq(_runtime.get_timeline_generation(), generation)
	assert_eq(_runtime.current_event_idx, event_index, "old deadline cannot advance replacement cursor")
	assert_true(_bridge.has_active_playback())
	assert_true(_runtime.Animations.is_animating(), "old deadline cannot stop the replacement's animation")
	assert_eq(_animation_interrupts, interrupts_before, "old deadline causes zero animation interruptions")
	assert_eq(_runtime.current_state, _runtime.States.ANIMATING, "old callback cannot force replacement state to IDLE")
	_assert_captionless_native_observations()
	# Let the retained replacement's own timer prove it was not killed by the old
	# callback. This does not manually finish or resume the event.
	await _await_natural_end()
	assert_eq(_wait_finishes, 1, "only the replacement's own timer finishes its event")
	assert_eq(_native_ends, ends_before + 1)

func test_native_pause_freezes_hold_and_resume_preserves_remaining_time() -> void:
	var event := await _start_wait("pause")
	if event == null: return
	await _wait_seconds(0.25)
	var held_tween: Tween = event._tween
	var elapsed_before_pause := held_tween.get_total_elapsed_time()
	assert_gt(elapsed_before_pause, 0.15, "timer has consumed a meaningful part of its duration before Pause")
	assert_true(_adapter.set_paused(true).ok)
	var paused_index := _runtime.current_event_idx
	var pause_started := Time.get_ticks_msec()
	await _wait_seconds(HOLD_SECONDS + 0.25)
	assert_true(_runtime.paused)
	assert_same(event._tween, held_tween, "Pause retains the exact native timer")
	assert_almost_eq(held_tween.get_total_elapsed_time(), elapsed_before_pause, 0.08,
		"paused wall time consumes none of the native timer's remaining delay")
	assert_eq(_runtime.current_event_idx, paused_index, "Pause preserves the exact Wait cursor")
	assert_eq(_runtime.current_state, _runtime.States.WAITING, "paused timer may not finish and wait at a successor")
	assert_eq(_native_ends, 0)
	assert_true(_completions.intents.is_empty(), "paused wall time cannot complete the hold")
	assert_true(_adapter.set_paused(false).ok)
	assert_same(event._tween, held_tween, "Resume retains the same partially elapsed timer")
	assert_almost_eq(held_tween.get_total_elapsed_time(), elapsed_before_pause, 0.08,
		"Resume neither resets the timer nor replaces remaining delay with a full duration")
	var resumed := Time.get_ticks_msec()
	await _wait_seconds(0.35)
	print("TIMED_HOLD_PAUSE_OBSERVATION " + JSON.stringify({"pause_started_msec": pause_started,
		"resumed_msec": resumed, "observed_msec": Time.get_ticks_msec(),
		"elapsed_before_pause": elapsed_before_pause, "elapsed_after_resume": held_tween.get_total_elapsed_time(),
		"semantic_completions": _completions.intents.size()}))
	assert_gt(held_tween.get_total_elapsed_time(), elapsed_before_pause + 0.20,
		"the retained native timer consumes its remaining delay after Resume")
	assert_eq(_runtime.current_state, _runtime.States.WAITING, "Resume retains unelapsed hold instead of consuming paused wall time")
	assert_true(_completions.intents.is_empty(), "remaining hold must survive the early post-resume observation")
	await _await_natural_end()
	assert_eq(_native_starts, 1)
	assert_eq(_native_ends, 1)
	_assert_captionless_native_observations()

func test_cancel_after_native_dispatch_retires_deferred_execute_before_same_path_restart() -> void:
	# handle_event emits event_handled after execute() queues the deferred body.
	# Abort from that actual signal before the body runs. An event_started hook
	# would instead interrupt handle_event before its array access and exercise
	# a separate handler reentrancy bug. No completion callback is synthesized.
	var timeline: DialogicTimeline = load(FIXTURE)
	timeline.process()
	var event: DialogicWaitEvent
	for candidate: Variant in timeline.events:
		if candidate is DialogicWaitEvent: event = candidate
	assert_not_null(event)
	if event == null: return
	if not await _mount_fixture(): return
	var cancellations: Array[Dictionary] = []
	var cancel_dispatched_wait := func(dispatched: DialogicEvent) -> void:
		if dispatched == event:
			cancellations.append({"at_msec": Time.get_ticks_msec(),
				"result": _bridge.abort_current_entry(&"fixture_deferred_wait_cancel")})
	_runtime.event_handled.connect(cancel_dispatched_wait)
	var begun := _begin("deferred-cancel")
	# The start was physically entered before its dispatch signal cancelled
	# it. The adapter may report cancellation to the initiating caller.
	assert_true(begun.get("ok", false) or str(begun.get("code", "")) == "runtime_start_failed", str(begun))
	for frame: int in 4: await get_tree().process_frame
	_runtime.event_handled.disconnect(cancel_dispatched_wait)
	assert_eq(cancellations.size(), 1, "one real native dispatch callback retires this attempt")
	if cancellations.size() == 1:
		assert_true(cancellations[0].result.get("ok", false), str(cancellations[0]))
	if is_instance_valid(event._tween): _fixture_tweens.append(event._tween)
	assert_null(_runtime.current_timeline)
	assert_eq(_runtime.current_state, _runtime.States.IDLE, "a retired deferred body cannot change idle runtime state to WAITING")
	assert_true(not is_instance_valid(event._tween) or not event._tween.is_running(),
		"native dispatch cancellation prevents a retired deferred body from creating a live timer")
	assert_true(_completions.intents.is_empty())
	assert_false(_bridge.has_active_playback())
	# Separate the cancelled and replacement physical deadlines enough for a
	# bounded cloud observation while keeping the exact cached resource.
	await _wait_seconds(0.80)
	var replacement := await _start_wait("after-deferred-cancel")
	if replacement == null: return
	assert_same(replacement, event)
	var replacement_started := _observed_wait_start_msec
	var generation := _runtime.get_timeline_generation()
	var ends_before := _native_ends
	await _wait_seconds(1.40)
	var observed := Time.get_ticks_msec()
	print("TIMED_HOLD_DEFERRED_OBSERVATION " + JSON.stringify({"cancellations": cancellations,
		"replacement_started_msec": replacement_started, "observed_msec": observed,
		"semantic_completions": _completions.intents.size()}))
	if cancellations.size() == 1:
		assert_gt(observed - int(cancellations[0].at_msec), int(HOLD_SECONDS * 1000.0),
			"deferred-cancel observation crosses the first attempted execution deadline")
	assert_lt(observed - replacement_started, int(HOLD_SECONDS * 1000.0),
		"deferred-cancel observation precedes replacement deadline")
	assert_eq(_runtime.current_state, _runtime.States.WAITING, "retired deferred timer cannot finish same-path replacement")
	assert_eq(_runtime.get_timeline_generation(), generation)
	assert_eq(_native_ends, ends_before)
	assert_true(_completions.intents.is_empty())
	await _await_natural_end()
	assert_eq(_native_starts, 2)
	assert_eq(_native_ends, 2)
	_assert_captionless_native_observations()
