extends "res://tests/ui/render_self_talk_base.gd"
## Synthetic authored transition, actual FINAL services and rendered native input.
const TRANSITION_PROOF := "user://scene-transition-proof.json"
const TARGET_LINE := "line.scene.test.b.one"
var transition_events: Array[Dictionary] = []
var transition_frames: Array[Dictionary] = []
var _transition_started_usec := 0
var _observing_transition := false
var _source_rail_rect := Rect2()
var _source_caret_rect := Rect2()

func _self_talk_markers() -> Array:
	return [{"marker_id": "scene.test.a.transition", "label": "scene.test.a.loop",
		"after_line_id": "line.scene.test.a.five", "kind": "scene.transition", "payload": {"target_id": "target_b"}}]

func _on_transition_changed(active: bool) -> void:
	var ticks := Time.get_ticks_usec()
	if active: _transition_started_usec = ticks
	transition_events.append({"active": active, "ticks_usec": ticks,
		"target_read": profile.is_line_visited(TARGET_LINE)})
	if active: assert_false(profile.is_line_visited(TARGET_LINE), "destination is unread when transition begins")

func _process(_delta: float) -> void:
	if not _observing_transition or not is_instance_valid(bridge) or not bridge.is_scene_transition_active(): return
	var caption: Node = _caption()
	var host: Control = get_tree().current_scene
	var row := {"ticks_usec": Time.get_ticks_usec(), "line_id": bridge._runtime_adapter.current_line_id(),
		"target_read": profile.is_line_visited(TARGET_LINE), "auto_admitted": bridge.can_auto_advance_current_line(),
		"has_capture": host.transition_surface.texture != null, "progress_millionths": roundi(bridge._scene_transition_progress * 1000000.0),
		"has_tween": bridge._scene_transition_tween != null}
	transition_frames.append(row)
	assert_false(row.target_read, "covered destination is never globally witnessed")
	assert_false(row.auto_admitted, "Auto cannot advance a covered destination")
	if caption != null:
		assert_false(caption._reading_source_admitted(), "transition excludes reading input")
		assert_eq(caption.transport_rail.get_global_rect(), _source_rail_rect, "rail geometry stays fixed")
	assert_eq(_controls(host, "CheckComputer").get_global_rect(), _source_caret_rect, "caret geometry stays fixed")

func _begin_transition_fixture(reduced: bool = false) -> bool:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return false
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if not _ok(profile.set_preference(&"preferences.accessibility.reduced_motion", reduced)): return false
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return false
	if not _ok(profile.set_preference(&"preferences.reading.auto_delay", "short")): return false
	if not _ok(profile.set_preference(&"preferences.reading.skip_mode", "all_text")): return false
	bridge.scene_transition_changed.connect(_on_transition_changed)
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return false
	for frame: int in 5: await get_tree().process_frame
	assert_true(transition_events.is_empty(), "initial admission does not animate")
	await _click(_caption().transport_rail.get_node("Skip"))
	var deadline := Time.get_ticks_msec() + 12000
	while _caption().skip_controller.is_skip_active() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(_caption().skip_controller.is_skip_active())
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.five", "Skip stops at the explicit transition")
	assert_eq(bridge._reading_session.latest_entry, "scene.test.a")
	assert_true(transition_events.is_empty(), "Skip does not execute the authored transition")
	assert_false(profile.is_line_visited(TARGET_LINE))
	_source_rail_rect = _caption().transport_rail.get_global_rect()
	_source_caret_rect = _controls(get_tree().current_scene, "CheckComputer").get_global_rect()
	_observing_transition = true
	return true

func _transition_key(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	event.echo = echo
	get_viewport().push_input(event, true)

func _wait_transition_finished() -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while (transition_events.size() < 2 or bridge.is_scene_transition_active()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(bridge.is_scene_transition_active())
	assert_eq(transition_events.size(), 2, "one begin and one completion")
	if transition_events.size() != 2: return false
	assert_true(transition_events[0].active)
	assert_false(transition_events[1].active)
	for frame: int in 3: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), TARGET_LINE)
	assert_eq(bridge._reading_session.boundary, "line", "no queued input admits the next control")
	assert_true(profile.is_line_visited(TARGET_LINE), "visible destination is acknowledged after completion")
	assert_false(profile.is_line_visited("line.scene.test.b.two"))
	assert_null(get_tree().current_scene.transition_surface.texture, "completed transition releases captured pixels")
	return true

func _save_transition_slot() -> bool:
	await _click(_controls(get_tree().current_scene, "Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup())
	if not sheet.can_save_backup(): return false
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(prepared): return false
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return false
	sheet.surface.leave_host()
	for frame: int in 5: await get_tree().process_frame
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return false
	var compact: Dictionary = COMPACT_READING.project_player_checkpoint(checkpoint.value)
	if not _ok(compact): return false
	return _write_json(TRANSITION_PROOF, {"creator_process_id": OS.get_process_id(),
		"checkpoint": compact.value, "profile": profile.get_profile_snapshot(),
		"gameplay": game.capture_run_snapshot_input().gameplay, "scene": game.capture_run_snapshot_input().scene,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json")})
