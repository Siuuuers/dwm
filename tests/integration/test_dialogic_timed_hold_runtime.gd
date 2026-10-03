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
	static var fixture_path := "res://tests/fixtures/dialogic/timed_hold_runtime.dtl"
	static var fixture_label := "timed_hold"
	static func get_entry(entry_id: String, _locale: String = "en") -> Dictionary:
		if entry_id != "contact.ordinary.lavinia.day1":
			return {"ok": false, "code": &"unknown_entry"}
		return {"ok": true, "value": {"entry_id": entry_id, "locale": "en",
			"requested_locale": "en", "path": fixture_path,
			"label": fixture_label, "used_fallback": false}}

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
	FixtureCatalog.fixture_path = FIXTURE
	FixtureCatalog.fixture_label = "timed_hold"
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
	var first_locator := {"path": str(_runtime.current_timeline.resource_path),
		"label": str(_bridge._active_entry.get("label", ""))}
	var first_generation := _runtime.get_timeline_generation()
	await _wait_seconds(0.80)
	assert_true(_bridge.abort_current_entry(&"fixture_same_path_replacement").ok)
	for frame: int in 4: await get_tree().process_frame
	assert_false(_bridge.has_active_playback(), "real native cancellation drains before replacement")
	assert_true(_completions.intents.is_empty(), "cancellation is never natural completion")
	var replacement := await _start_wait("replacement")
	if replacement == null: return
	var replacement_started := _observed_wait_start_msec
	assert_eq({"path": str(_runtime.current_timeline.resource_path),
		"label": str(_bridge._active_entry.get("label", ""))}, first_locator,
		"replacement uses the exact same physical path and label")
	assert_gt(_runtime.get_timeline_generation(), first_generation)
	# Once the old Timeline is released, ResourceLoader may rebuild its events.
	# Both retained and regenerated resources must reject the old callback.
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
		"old_event_instance_id": old_event.get_instance_id(), "replacement_event_instance_id": replacement.get_instance_id(),
		"event_finishes": _wait_finishes, "semantic_completions": _completions.intents.size()}))
	assert_gt(observed - first_started, int(HOLD_SECONDS * 1000.0), "observation must cross the old physical deadline")
	assert_lt(observed - replacement_started, int(HOLD_SECONDS * 1000.0), "observation must precede the replacement deadline")
	assert_eq(_wait_finishes, 0, "retired Wait callback must not finish the replacement event")
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

func _native_hold_state() -> Dictionary:
	return {"timeline": _runtime.current_timeline, "event_index": _runtime.current_event_idx,
		"generation": _runtime.get_timeline_generation(), "state": _runtime.current_state,
		"paused": _runtime.paused, "starts": _native_starts, "ends": _native_ends,
		"animation": _runtime.Animations.is_animating(), "interrupts": _animation_interrupts,
		"completion_count": _completions.intents.size()}

func _assert_no_durable_hold_frontier() -> void:
	assert_false(_adapter.can_capture_reading_frontier(), "native Wait is never a durable reading publication")
	assert_false(_adapter.capture_reading_frontier().get("ok", true))
	assert_false(_bridge.can_capture_reading_checkpoint(), "Pause eligibility never grants a Save checkpoint")
	assert_false(_bridge.capture_reading_checkpoint().get("ok", true))
	assert_false(_bridge.get_reading_history().get("ok", true), "captionless hold does not fabricate History")

func test_retired_bound_callbacks_and_duplicate_timeout_cannot_affect_replacement_or_complete_twice() -> void:
	var old_event := await _start_wait("stale-callback-old")
	if old_event == null: return
	var retained_timeline: DialogicTimeline = _runtime.current_timeline
	# Keeping this real Timeline alive explicitly exercises resource reuse;
	# the original deadline test also admits a regenerated replacement resource.
	# Capture actual callables installed by the native event. Calling them later
	# is an explicit stale delivery challenge; completion signals stay native.
	var retired_finish: Callable = old_event._finish_callback
	var retired_pause: Callable = old_event._pause_callback
	var retired_resume: Callable = old_event._resume_callback
	assert_true(retired_finish.is_valid())
	assert_true(_bridge.abort_current_entry(&"fixture_retired_callbacks").ok)
	for frame: int in 4: await get_tree().process_frame
	var replacement := await _start_wait("stale-callback-new")
	if replacement == null: return
	assert_same(_runtime.current_timeline, retained_timeline)
	assert_same(replacement, old_event)
	var own_finish: Callable = replacement._finish_callback
	var owned_tween: Tween = replacement._tween
	_runtime.Animations.start_animating()
	var before := _native_hold_state()
	retired_finish.call()
	retired_finish.call()
	retired_pause.call()
	assert_eq(_native_hold_state(), before, "retired callbacks neither finish, pause nor stop a replacement animation")
	assert_same(replacement._tween, owned_tween)
	assert_true(owned_tween.is_running(), "old pause delivery cannot stop the live replacement timer")
	_runtime.Animations.stop_animation()
	var handle := {"generation": 1, "handle_id": "native-callback-pause", "holder": &"timed_hold_fixture", "reason": &"universal_pause"}
	assert_true(_bridge.begin_suspend(handle).ok)
	var paused_frontier: Dictionary = _bridge.capture_pause_frontier()
	var paused_elapsed := owned_tween.get_total_elapsed_time()
	before = _native_hold_state()
	retired_resume.call()
	retired_finish.call()
	own_finish.call()
	assert_eq(_native_hold_state(), before, "even the current timeout cannot finish a suspended hold")
	await _wait_seconds(0.20)
	assert_almost_eq(owned_tween.get_total_elapsed_time(), paused_elapsed, 0.08,
		"retired resume delivery cannot consume the suspended replacement's remaining time")
	assert_eq(_bridge.capture_pause_frontier(), paused_frontier)
	assert_true(_bridge.resume(handle).ok)
	await _await_natural_end()
	before = _native_hold_state()
	own_finish.call()
	own_finish.call()
	retired_finish.call()
	retired_pause.call()
	retired_resume.call()
	assert_eq(_native_hold_state(), before, "duplicate or old delivery after natural completion is inert")
	assert_eq(_completions.intents.size(), 1)
	assert_true(replacement.get_wait_execution_state().is_empty(), "retired event exposes no transient identity")

func test_hidden_non_skippable_hold_keeps_full_duration_under_native_autoskip_and_input() -> void:
	_runtime.Inputs.auto_skip.time_per_event = 0.25
	_runtime.Inputs.auto_skip.disable_on_user_input = false
	_runtime.Inputs.auto_skip.enabled = true
	var event := await _start_wait("protected-from-skip")
	if event == null: return
	var started := _observed_wait_start_msec
	assert_true(_runtime.Inputs.auto_skip.enabled, "the control actually enables native auto-skip")
	_runtime.Inputs.handle_input()
	_runtime.Inputs.handle_input()
	await _wait_seconds(0.60)
	var elapsed := Time.get_ticks_msec() - started
	assert_lt(elapsed, int(HOLD_SECONDS * 1000.0), "skip observation must precede the authored timer deadline")
	assert_eq(_runtime.current_state, _runtime.States.WAITING, "auto-skip cannot shorten the authored silent hold")
	var index: int = _runtime.current_event_idx
	var current_event_valid := index >= 0 and index < _runtime.current_timeline_events.size()
	assert_true(current_event_valid, "protected hold retains its current event")
	if current_event_valid: assert_same(_runtime.current_timeline_events[index], event)
	assert_true(_completions.intents.is_empty(), "ordinary native input cannot finish a non-skippable hold")
	assert_true(_adapter.capture_pause_frontier().ok)
	_assert_no_durable_hold_frontier()
	await _await_natural_end()
	assert_gte(Time.get_ticks_msec() - started, 1800, "real completion retains the authored two-second delay")

func _start_legacy_wait(label: String) -> DialogicWaitEvent:
	FixtureCatalog.fixture_path = "res://tests/fixtures/dialogic/timed_hold_legacy_controls.dtl"
	FixtureCatalog.fixture_label = label
	if not await _mount_fixture(): return null
	var begun := _begin(label)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return null
	var deadline := get_tree().create_timer(3.0)
	while deadline.time_left > 0.0:
		var index: int = _runtime.current_event_idx
		if index >= 0 and index < _runtime.current_timeline_events.size():
			var event: Variant = _runtime.current_timeline_events[index]
			if event is DialogicWaitEvent and _runtime.current_state == _runtime.States.WAITING:
				_observed_wait_start_msec = Time.get_ticks_msec()
				_fixture_tweens.append(event._tween)
				return event
		await get_tree().process_frame
	assert_true(false, "native compatibility Wait did not enter its actual timer")
	return null

func _assert_legacy_autoskip(label: String) -> void:
	_runtime.Inputs.auto_skip.time_per_event = 0.25
	_runtime.Inputs.auto_skip.enabled = true
	var event := await _start_legacy_wait(label)
	if event == null: return
	assert_almost_eq(event.time, HOLD_SECONDS, 0.001)
	assert_true(_runtime.Inputs.auto_skip.enabled)
	assert_false(_adapter.capture_pause_frontier().get("ok", true), "legacy Wait flavor cannot borrow silent-hold Pause admission")
	assert_false(_bridge.capture_pause_frontier().get("ok", true))
	var started := _observed_wait_start_msec
	await _wait_seconds(0.65)
	var elapsed := Time.get_ticks_msec() - started
	print("TIMED_HOLD_LEGACY_SKIP_OBSERVATION " + JSON.stringify({"label": label,
		"authored_msec": 2000, "native_skip_msec": 250, "observed_elapsed_msec": elapsed,
		"semantic_completions": _completions.intents.size()}))
	assert_lt(elapsed, 1800, "legacy compatibility observation must precede the full authored delay")
	assert_eq(_completions.intents.size(), 1, "legacy auto-skip still uses min(authored delay, native skip delay)")
	assert_eq(_native_ends, 1)
	_assert_captionless_native_observations()

func test_legacy_skippable_wait_keeps_native_autoskip_delay_and_has_no_hold_frontier() -> void:
	await _assert_legacy_autoskip("skippable_wait")

func test_legacy_visible_wait_keeps_native_autoskip_delay_and_has_no_hold_frontier() -> void:
	await _assert_legacy_autoskip("visible_wait")

func test_only_live_eligible_hold_exposes_stable_pause_identity_without_save_or_history() -> void:
	assert_false(_adapter.capture_pause_frontier().get("ok", true), "idle runtime has no hold identity")
	assert_false(_bridge.capture_pause_frontier().get("ok", true))
	var pending_observations: Array[Dictionary] = []
	var observe_pending := func(resource: DialogicEvent) -> void:
		if resource is DialogicWaitEvent:
			var wait_event := resource as DialogicWaitEvent
			pending_observations.append({"wait": wait_event.get_wait_execution_state(),
				"adapter": _adapter.capture_pause_frontier(), "bridge": _bridge.capture_pause_frontier()})
	_runtime.event_handled.connect(observe_pending)
	var event := await _start_wait("frontier-boundary")
	_runtime.event_handled.disconnect(observe_pending)
	if event == null: return
	assert_eq(pending_observations.size(), 1, "observe the actual pending native dispatch exactly once")
	if pending_observations.size() == 1:
		assert_true(pending_observations[0].wait.is_empty())
		assert_false(pending_observations[0].adapter.get("ok", true), "queued deferred body is not yet a Pause frontier")
		assert_false(pending_observations[0].bridge.get("ok", true))
	var native: Dictionary = _adapter.capture_pause_frontier()
	var bridge_frontier: Dictionary = _bridge.capture_pause_frontier(ENTRY)
	assert_true(native.get("ok", false), str(native))
	assert_true(bridge_frontier.get("ok", false), str(bridge_frontier))
	if not native.get("ok", false) or not bridge_frontier.get("ok", false): return
	assert_eq(native.value.kind, "timed_hold")
	assert_gt(int(native.value.execution_token), 0)
	assert_eq(native.value.generation, _runtime.get_timeline_generation())
	assert_eq(native.value.event_index, _runtime.current_event_idx)
	assert_false(_bridge.capture_pause_frontier("contact.ordinary.priscilla.day3").get("ok", true),
		"foreign source identity cannot borrow the current hold")
	var keys: Array = bridge_frontier.value.keys()
	keys.sort()
	assert_eq(keys, ["event_index", "execution_token", "generation", "kind", "request_id"],
		"Pause identity is stable and contains no elapsed timer or durable cursor")
	await _wait_seconds(0.10)
	assert_eq(_bridge.capture_pause_frontier(), bridge_frontier, "elapsed native time cannot change Pause source identity")
	_assert_no_durable_hold_frontier()
	var original_time: float = event.time
	for invalid_duration: float in [0.0, -1.0, INF, NAN]:
		event.time = invalid_duration
		assert_false(_adapter.capture_pause_frontier().get("ok", true), "nonpositive/nonfinite authored duration refuses Pause")
		assert_false(_bridge.capture_pause_frontier().get("ok", true))
	event.time = original_time
	for field: String in ["hide_text", "skippable"]:
		var original: bool = event.get(field)
		event.set(field, not original)
		assert_false(_adapter.capture_pause_frontier().get("ok", true), "ineligible " + field + " refuses Pause")
		assert_false(_bridge.capture_pause_frontier().get("ok", true))
		event.set(field, original)
	assert_eq(_bridge.capture_pause_frontier(), bridge_frontier, "guard probes are restored without changing native ownership")
	var handle := {"generation": 1, "handle_id": "native-frontier-pause", "holder": &"timed_hold_fixture", "reason": &"universal_pause"}
	assert_true(_bridge.begin_suspend(handle).ok)
	assert_true(_runtime.paused)
	assert_eq(_bridge.capture_pause_frontier(), bridge_frontier, "real Bridge suspension preserves exact hold identity")
	assert_true(_bridge.get_state().ok)
	_assert_no_durable_hold_frontier()
	assert_true(_bridge.resume(handle).ok)
	assert_false(_runtime.paused)
	assert_eq(_bridge.capture_pause_frontier(), bridge_frontier)
	assert_true(_bridge.abort_current_entry(&"fixture_frontier_retired").ok)
	for frame: int in 4: await get_tree().process_frame
	assert_true(event.get_wait_execution_state().is_empty())
	assert_false(_adapter.capture_pause_frontier().get("ok", true))
	assert_false(_bridge.capture_pause_frontier().get("ok", true))
	assert_true(_completions.intents.is_empty(), "frontier inspection and cancellation cannot complete gameplay")

func test_foreign_native_same_path_replacement_cannot_inherit_adapter_or_bridge_pause_admission() -> void:
	var event := await _start_wait("before-foreign-native")
	if event == null: return
	assert_true(_bridge.capture_pause_frontier().ok)
	var admitted_generation := _runtime.get_timeline_generation()
	# Real native replacement has no admitted request from the retained adapter.
	_runtime.start_timeline(FIXTURE, "timed_hold", "foreign-native-request")
	for frame: int in 4: await get_tree().process_frame
	if is_instance_valid(event._tween): _fixture_tweens.append(event._tween)
	assert_gt(_runtime.get_timeline_generation(), admitted_generation)
	assert_false(_adapter.capture_pause_frontier().get("ok", true), "same resource path does not grant request ownership")
	assert_false(_bridge.capture_pause_frontier().get("ok", true))
	assert_true(_completions.intents.is_empty(), "foreign native replacement does not naturally complete the retired entry")
	_assert_no_durable_hold_frontier()
