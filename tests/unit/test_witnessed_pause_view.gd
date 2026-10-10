extends GutTest
## Native DialogText view custody; no fake reveal implementation or narrative completion.
const SCENE := preload("res://scenes/ui/witnessed/WitnessedCaptionLayer.tscn")
var runtime: DialogicGameHandler
var caption: Node
var viewport: SubViewport
var _original_runtime: Node
var _runtime_index := 0
var _original_layout: Node
var _layout_parent: Node
var _layout_index := 0
var _styles: Dictionary
var _persistent: Variant
var _had_persistent := false
var _finished := 0
var _original_localization: Node
var _localization_index := 0
var _fixture_localization: Node
var _localization_profile: Node

func before_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_finished = 0
	_styles = DialogicStylesUtil.style_directory.duplicate(true)
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info",{})
	_original_runtime = get_node("/root/Dialogic")
	_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	_layout_parent = null
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_layout_parent = _original_layout.get_parent()
		_layout_index = _original_layout.get_index()
		_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)
	runtime.History.save_visited_history_on_save = false
	runtime.History.save_visited_history_on_autosave = false
	runtime.paused = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child(viewport)
	# Cloud GUT leaves Bootstrap in test_manual; its root localization owner has
	# no catalog. Mount the real recovery view against an initialized local owner.
	_localization_profile = preload("res://autoload/ProfileManager.gd").new()
	var storage: RefCounted = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"pause-view-localization", preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(_localization_profile.initialize(storage).get("ok", false))
	_fixture_localization = preload("res://autoload/LocalizationManager.gd").new()
	assert_true(_fixture_localization.initialize(_localization_profile).get("ok", false))
	_original_localization = get_node("/root/LocalizationManager")
	_localization_index = _original_localization.get_index()
	get_tree().root.remove_child(_original_localization)
	_fixture_localization.name = "LocalizationManager"
	get_tree().root.add_child(_fixture_localization)
	caption = SCENE.instantiate()
	viewport.add_child(caption)
	assert_true(caption.configure_presentation("en",100))
	caption.caption_text.finished_revealing_text.connect(func(): _finished += 1)
	caption.caption_text.reveal_text("Native caption remains at its actual reveal position. ".repeat(45))
	caption.caption_text.visible_characters = 7
	assert_true(caption.reproject_retained_captions(["An older public beat.","The previous public beat."]))
	for frame in 6: await get_tree().process_frame
	caption.caption_text.grab_focus()
	var bar: VScrollBar = caption.get_scroll_bar()
	assert_gt(bar.max_value-bar.page,80.0)
	bar.value = 80.0

func after_each() -> void:
	if is_instance_valid(caption):
		caption.caption_text.set_process(false)
		caption.free()
	if is_instance_valid(viewport): viewport.free()
	if is_instance_valid(runtime):
		await runtime.clear()
		runtime.free()
	if is_instance_valid(_fixture_localization): _fixture_localization.free()
	if is_instance_valid(_localization_profile): _localization_profile.free()
	get_tree().root.add_child(_original_localization)
	get_tree().root.move_child(_original_localization,_localization_index)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime,_runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_layout_parent):
			_layout_parent.add_child(_original_layout)
			_layout_parent.move_child(_original_layout,_layout_index)
		get_tree().set_meta("dialogic_layout_node",_original_layout)
	DialogicStylesUtil.style_directory = _styles
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info",_persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")

func _source() -> Dictionary:
	return {"route_id":"hospital","timeline_id":"hospital.faint","physical_token":"view-fixture",
		"frontier":{"generation":runtime.get_timeline_generation(),"event_index":runtime.current_event_idx}}

func _native_state() -> Dictionary:
	return {"node_id":caption.caption_text.get_instance_id(),"text":caption.caption_text.text,
		"visible_characters":caption.caption_text.visible_characters,"revealing":caption.caption_text.revealing,
		"generation":caption.caption_text.get_reveal_generation(),"retained":caption.get_caption_projection().retained_captions,
		"history":runtime.History.simple_history_content.duplicate(true)}

func test_cover_hides_complete_native_view_without_changing_reveal_or_history_then_restores_pan_focus() -> void:
	var captured: Dictionary = caption.capture_pause_view(_source())
	assert_true(captured.get("ok",false))
	var before := _native_state()
	var scroll: float = caption.get_scroll_bar().value
	assert_true(caption.cover_pause_view(captured.value))
	assert_true(caption.cover_pause_view(captured.value),"cover is idempotent for recovery")
	assert_false(caption.canvas.visible)
	assert_true(caption.caption_text.visible,"ancestor hiding does not invoke native empty-caption clear")
	assert_false(caption.caption_text.is_visible_in_tree())
	assert_false(caption.previous.is_visible_in_tree())
	assert_false(caption.older.is_visible_in_tree())
	assert_eq(caption.caption_text.focus_mode,Control.FOCUS_NONE)
	assert_null(viewport.gui_get_focus_owner())
	assert_false(caption.is_processing())
	assert_false(caption.caption_text.is_processing())
	assert_true(runtime.paused,"view cover does not mutate the runtime suspension owner")
	# Even without the separate runtime pause, hidden source text cannot progress.
	runtime.paused = false
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	viewport.push_input(key,true)
	key.pressed = false
	viewport.push_input(key,true)
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(100,500)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	viewport.push_input(wheel,true)
	for frame in 5: await get_tree().process_frame
	assert_eq(_native_state(),before)
	assert_almost_eq(caption.get_scroll_bar().value,scroll,0.01,"covered pointer input cannot scroll the source")
	assert_eq(_finished,0)
	runtime.paused = true
	assert_true(caption.restore_pause_view(captured.value))
	for frame in 4: await get_tree().process_frame
	assert_true(caption.canvas.visible)
	assert_true(caption.caption_text.has_focus())
	assert_almost_eq(caption.get_scroll_bar().value,scroll,0.01)
	assert_eq(_native_state(),before)
	assert_eq(_finished,0)
	assert_true(caption.cover_pause_view(captured.value),"the same anchor can re-cover after another port refuses resume")
	assert_true(caption.restore_pause_view(captured.value))

func test_tampered_stale_and_foreign_view_anchors_are_refused_without_mutation() -> void:
	var source := _source()
	var first: Dictionary = caption.capture_pause_view(source)
	assert_true(first.get("ok",false))
	source.frontier.generation = 999
	var changed: Dictionary = first.value.duplicate(true)
	changed.source.timeline_id = "other.timeline"
	assert_false(caption.cover_pause_view(changed))
	assert_true(caption.canvas.visible)
	var second: Dictionary = caption.capture_pause_view(_source())
	assert_true(second.get("ok",false))
	assert_false(caption.cover_pause_view(first.value),"a new capture retires the old view anchor")
	var other: Node = SCENE.instantiate()
	viewport.add_child(other)
	assert_false(other.cover_pause_view(second.value),"another mounted native view cannot consume this anchor")
	other.free()
	assert_true(caption.cover_pause_view(second.value))
	caption.caption_text.reveal_text("A new actual native publication.")
	assert_false(caption.restore_pause_view(second.value),"native replacement invalidates old view restoration")
	assert_false(caption.canvas.visible)
	assert_eq(caption.caption_text.get_parsed_text(),"A new actual native publication.")

func test_settings_reprojection_under_cover_preserves_native_copy_and_restores_clamped_pan() -> void:
	var captured: Dictionary = caption.capture_pause_view(_source())
	assert_true(captured.get("ok",false))
	var before := _native_state()
	assert_true(caption.cover_pause_view(captured.value))
	var locale_source := preload("res://tests/integration/test_witnessed_caption_runtime.gd").CaptionFixtureLocale.new()
	locale_source.locale = "zh-HK"
	viewport.add_child(locale_source)
	assert_true(caption.transport_rail.bind_localization(locale_source))
	assert_true(caption.configure_presentation("zh-HK",150,"Midnight",true,"tritan",true))
	for frame in 5: await get_tree().process_frame
	assert_false(caption.canvas.visible)
	assert_false(caption.caption_text.is_processing())
	assert_eq(_native_state(),before)
	assert_true(caption.restore_pause_view(captured.value))
	for frame in 5: await get_tree().process_frame
	assert_eq(_native_state(),before)
	assert_true(caption.caption_text.has_focus())
	var bar: VScrollBar = caption.get_scroll_bar()
	assert_almost_eq(bar.value,minf(80,bar.max_value-bar.page),0.01)
	assert_eq(caption.get_caption_projection().text_percent,150)

func test_no_source_focus_is_not_invented_and_empty_capture_is_refused() -> void:
	caption.caption_text.release_focus()
	var captured: Dictionary = caption.capture_pause_view(_source())
	assert_true(captured.get("ok",false))
	assert_true(caption.cover_pause_view(captured.value))
	assert_true(caption.restore_pause_view(captured.value))
	for frame in 3: await get_tree().process_frame
	assert_null(viewport.gui_get_focus_owner())
	assert_false(caption.capture_pause_view({}).get("ok",true))
	caption.caption_text.text = ""
	assert_false(caption.capture_pause_view(_source()).get("ok",true))

func test_next_matte_retains_native_composition_and_excludes_input_pause_and_rail_commands() -> void:
	var before := _native_state()
	var scroll: float = caption.get_scroll_bar().value
	caption._next_pending = true
	caption._sync_next_presentation()
	caption._sync_transport()
	assert_true(caption.is_next_transport_active())
	assert_true(caption.get_node("RecoveryLayer/NextMatte").visible)
	assert_true(caption.canvas.visible, "the last safe composition stays drawn under the matte")
	assert_true(caption.canvas.accessibility_withdrawn, "covered text is absent from assistive traversal")
	assert_eq(caption.caption_text.focus_mode, Control.FOCUS_NONE)
	assert_false(caption.caption_text.is_processing())
	assert_false(caption._reading_source_admitted())
	assert_false(caption.capture_pause_view(_source()).get("ok", true), "Pause cannot capture an intermediate seek")
	for name: String in ["History", "Skip", "Auto", "Save", "Load", "Next"]:
		assert_true(caption.transport_rail.get_node(name).disabled, name + " cannot observe the intermediate source")
	runtime.paused = false
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		viewport.push_input(key, true)
	for frame: int in 3: await get_tree().process_frame
	assert_eq(_native_state(), before, "covered reveal and repeated Accept cannot change safe composition")
	assert_almost_eq(caption.get_scroll_bar().value, scroll, 0.01)
	assert_eq(_finished, 0)
	runtime.paused = true
	caption._complete_next_presentation()
	assert_false(caption.is_next_transport_active())
	assert_false(caption.get_node("RecoveryLayer/NextMatte").visible)
	assert_false(caption.canvas.accessibility_withdrawn)
	assert_true(caption.caption_text.has_focus(), "the settled caption regains meaningful Focus")
	assert_eq(_native_state(), before)

class SettlingNextProfile extends RefCounted:
	func get_profile_revision() -> int: return 1
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		if path == &"preferences.reading.auto_enabled": return false
		if path == &"preferences.reading.auto_delay": return "normal"
		return fallback
	func set_preference(_path: StringName, _value: Variant) -> Dictionary: return {"ok": true}

class SettlingNextBridge extends RefCounted:
	signal next_traversal_changed
	signal next_request_finished(expected_frontier: Dictionary, result: Dictionary)
	signal settled(result: Dictionary)
	var active := false
	var requests := 0
	var captures := 0
	var acknowledgements := 0
	var frontier := {"ok": true, "line": "retained-next-source"}
	func can_next_current_line() -> bool: return true
	func can_skip_current_line() -> bool: return false
	func can_auto_advance_current_line() -> bool: return false
	func request_skip_step() -> Dictionary: return {"ok": false}
	func request_auto_step(_frontier: Dictionary) -> Dictionary: return {"ok": false}
	func is_next_traversal_active() -> bool: return active
	func capture_current_line_presentation_frontier() -> Dictionary:
		captures += 1
		return frontier.duplicate(true)
	func requires_line_presentation_acknowledgement() -> bool: return true
	func acknowledge_current_line_presentation(_frontier: Dictionary) -> Dictionary:
		acknowledgements += 1
		return {"ok": true}
	func is_current_line_presentation_acknowledged() -> bool: return acknowledgements > 0
	func request_next(expected_frontier: Dictionary) -> Dictionary:
		requests += 1
		active = true
		next_traversal_changed.emit()
		var result: Dictionary = await settled
		next_request_finished.emit(expected_frontier, result)
		return result
	func finish(result: Dictionary) -> void:
		active = false
		next_traversal_changed.emit()
		settled.emit(result)

func _begin_settling_next() -> SettlingNextBridge:
	var bridge := SettlingNextBridge.new()
	caption._transport_bridge = bridge
	caption._reading_profile = SettlingNextProfile.new()
	caption._line_waiting_for_text = false
	caption._presented_line = bridge.frontier.duplicate(true)
	caption.auto_controller._auto_enabled = false
	bridge.next_traversal_changed.connect(caption._on_next_traversal_changed)
	caption._request_reading_command(&"next", true)
	assert_eq(bridge.requests, 1, "the real host submitted the admitted Bridge command synchronously")
	assert_true(caption._next_pending)
	assert_true(caption.canvas.accessibility_withdrawn)
	assert_eq(bridge.get_signal_connection_list("next_request_finished").size(), 1)
	return bridge

func _assert_detached_next_settlement(result: Dictionary) -> void:
	var bridge := _begin_settling_next()
	viewport.remove_child(caption)
	assert_false(caption.is_inside_tree(), "natural terminal completion removes the host before settlement")
	assert_false(caption._next_pending, "detachment retires local custody without awaiting durable settlement")
	assert_true(caption._next_request.is_empty())
	assert_eq(bridge.get_signal_connection_list("next_request_finished").size(), 0)
	var replacement := Button.new()
	replacement.focus_mode = Control.FOCUS_ALL
	viewport.add_child(replacement)
	replacement.grab_focus()
	assert_true(replacement.has_focus())
	var captures: int = bridge.captures
	var reveal_generation: int = caption.caption_text.get_reveal_generation()
	var public_text: String = caption.caption_text.text
	bridge.finish(result)
	assert_false(caption._next_pending, "local in-flight bookkeeping is retired without reviving the departed view")
	assert_true(replacement.has_focus(), "settlement cannot steal the successor's Focus")
	assert_eq(bridge.captures, captures, "the departed host must not query or re-publish a frontier")
	assert_eq(bridge.acknowledgements, 0)
	assert_true(caption._reading_recovery.is_empty(), "the old presenter cannot attach recovery to a departed source")
	assert_true(caption.canvas.accessibility_withdrawn, "settlement does not restore departed canvas interaction")
	assert_eq(caption.caption_text.get_reveal_generation(), reveal_generation)
	assert_eq(caption.caption_text.text, public_text)
	assert_false(caption._speech_pending)
	assert_false(caption._reading_request_owner_matches({}), "owner admission checks tree membership before absolute lookup")
	assert_eq(caption._pause_runtime_identity(), {}, "detached identity queries never access absolute SceneTree paths")
	replacement.free()

func test_next_success_after_native_host_detachment_cannot_republish_or_refocus() -> void:
	_assert_detached_next_settlement({"ok": true, "value": {"destination": "completion"}})

func test_next_failure_after_native_host_detachment_cannot_mount_old_recovery() -> void:
	_assert_detached_next_settlement({"ok": false, "code": &"reading_next_projection_failed", "fatal": true})

func test_next_can_finish_after_native_presenter_is_freed() -> void:
	var bridge := _begin_settling_next()
	var departed: WeakRef = weakref(caption)
	viewport.remove_child(caption)
	caption.queue_free()
	caption = null
	await get_tree().process_frame
	assert_null(departed.get_ref(), "the Bridge command does not retain its native presenter")
	assert_eq(bridge.get_signal_connection_list("next_request_finished").size(), 0)
	var captures: int = bridge.captures
	bridge.finish({"ok": true, "value": {"destination": "completion"}})
	assert_false(bridge.active)
	assert_eq(bridge.captures, captures)
	assert_eq(bridge.acknowledgements, 0)

func test_next_storage_refusal_retries_through_signal_and_restores_current_caption_focus() -> void:
	assert_true(caption._recovery_bound, "the real recovery view has its input and localization owners")
	assert_true(caption.recovery_overlay._configured, "the recovery view loaded its localized catalog before Next")
	var bridge := _begin_settling_next()
	bridge.finish({"ok": false, "code": &"candidate_write_failed"})
	assert_false(caption._next_pending)
	assert_true(caption.is_reading_recovery_active())
	assert_true(caption.recovery_overlay.is_visible_in_tree())
	assert_eq(caption.recovery_overlay.message_label.text,
		_fixture_localization.t("witnessed.recovery.next_failed"))
	assert_eq(caption._reading_recovery.frontier, bridge.frontier)
	assert_true(caption._recovery_action_admitted())
	caption._retry_reading_command()
	assert_eq(bridge.requests, 2)
	assert_true(caption._next_pending)
	assert_true(caption._reading_retry_in_progress)
	assert_false(caption.recovery_overlay.is_visible_in_tree(), "the retained retry has exclusive traversal custody")
	caption._retry_reading_command()
	assert_eq(bridge.requests, 2, "repeated Retry cannot submit another command")
	bridge.finish({"ok": true, "value": {"destination": "unseen_stop"}})
	assert_false(caption._next_pending)
	assert_false(caption._reading_retry_in_progress)
	assert_true(caption._next_request.is_empty())
	assert_false(caption.is_reading_recovery_active())
	assert_false(caption.canvas.accessibility_withdrawn)
	assert_true(caption.caption_text.has_focus())
	assert_eq(bridge.acknowledgements, 1, "only the settled retained owner acknowledges its current caption")
	assert_eq(bridge.get_signal_connection_list("next_request_finished").size(), 0)

func test_next_completion_from_retired_owner_generation_cannot_publish_or_attach_fatal_recovery() -> void:
	var bridge := _begin_settling_next()
	caption._reading_owner_generation += 1
	var replacement := Button.new()
	replacement.focus_mode = Control.FOCUS_ALL
	viewport.add_child(replacement)
	replacement.grab_focus()
	bridge.finish({"ok": false, "code": &"reading_next_projection_failed", "fatal": true})
	assert_false(caption._next_pending)
	assert_true(caption._next_request.is_empty())
	assert_false(caption.is_reading_recovery_active())
	assert_eq(bridge.acknowledgements, 0)
	assert_false(caption.canvas.accessibility_withdrawn, "a reused presenter must release obsolete traversal custody")
	assert_false(caption.get_node("RecoveryLayer/NextMatte").visible)
	assert_eq(caption.caption_text.focus_mode, Control.FOCUS_ALL)
	assert_true(replacement.has_focus(), "old completion restores availability without claiming successor Focus")
	assert_false(caption._speech_pending)
	assert_eq(bridge.get_signal_connection_list("next_request_finished").size(), 0)
	replacement.free()

func test_reconfiguring_next_presenter_releases_old_matte_and_ignores_old_completion() -> void:
	var old_bridge := _begin_settling_next()
	var replacement_bridge := SettlingNextBridge.new()
	replacement_bridge.frontier.line = "replacement-source"
	var replacement := Button.new()
	replacement.focus_mode = Control.FOCUS_ALL
	viewport.add_child(replacement)
	replacement.grab_focus()
	assert_true(caption.configure_reading_transport(SettlingNextProfile.new(), replacement_bridge))
	assert_false(caption._next_pending)
	assert_true(caption._next_request.is_empty())
	assert_true(caption._next_canvas_state.is_empty())
	assert_false(caption.get_node("RecoveryLayer/NextMatte").visible)
	assert_false(caption.canvas.accessibility_withdrawn)
	assert_eq(caption.caption_text.focus_mode, Control.FOCUS_ALL)
	assert_true(replacement.has_focus(), "configuration restores controls without reclaiming successor Focus")
	assert_eq(old_bridge.get_signal_connection_list("next_request_finished").size(), 0)
	assert_eq(replacement_bridge.acknowledgements, 1, "the explicit new configuration owns its publication")
	var captures: int = replacement_bridge.captures
	old_bridge.finish({"ok": false, "code": &"reading_next_projection_failed", "fatal": true})
	assert_false(caption.is_reading_recovery_active())
	assert_eq(replacement_bridge.captures, captures)
	assert_eq(replacement_bridge.acknowledgements, 1)
	assert_eq(old_bridge.acknowledgements, 0)
	assert_true(replacement.has_focus())
	replacement.free()
