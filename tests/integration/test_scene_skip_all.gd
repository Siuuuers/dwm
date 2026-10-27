extends "res://addons/gut/test.gd"
## Actual Scene admission, native text, Profile preference and mounted transport.
## Synthetic ordinary text stops at the existing Challenge marker.
const PATH := "res://tests/fixtures/dialogic/scene_skip_all.dtl"
const MIDDLE := "line.scene.test.b.skip_middle"
const LAST := "line.scene.test.b.skip_last"

class SkipFixture extends "res://tests/support/ScenePauseLoadFixture.gd":
	func _registration_bundle() -> Dictionary:
		var built: Dictionary = super._registration_bundle()
		if not built.ok: return built
		var bundle: Dictionary = built.value
		var labels: Array = []
		for entry: Dictionary in bundle.entry_manifest.entries:
			labels.append(entry.entry_id)
			entry.locators.en.path = PATH
		for row: Dictionary in [
			{"beat_id": "beat.scene.test.b.skip_middle", "line_id": MIDDLE, "text": "TEST skip middle.", "revision": "1"},
			{"beat_id": "beat.scene.test.b.skip_last", "line_id": LAST, "text": "TEST skip last.", "revision": "1"}]:
			bundle.ids_registry.lines.append({"line_id": row.line_id, "owning_entry_id": BASE_READING.B})
			for entry: Dictionary in bundle.caption_registry.entries:
				if entry.entry_id == BASE_READING.B:
					entry.lines.insert(entry.lines.size() - 1, row)
		bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
		var hashes := {}
		for programme: Dictionary in bundle.scene_programme.entries:
			if programme.entry_id == BASE_READING.B: programme.markers[0].after_line_id = LAST
			var compiled: Dictionary = RUNTIME_ADAPTER.compile_scene_programme(PATH, programme.entry_id, labels, programme.markers)
			if not compiled.ok: return compiled
			programme.content_sha256 = compiled.value.content_sha256
			programme.program_sha256 = compiled.value.program_sha256
			hashes[programme.entry_id] = programme.program_sha256
		for target: Dictionary in bundle.targets:
			target.target.program_sha256 = hashes[target.target.entry_id]
		return built

var _fixture: RefCounted

func after_all() -> void:
	if _fixture != null: await _fixture.close_restart()

func test_scene_skip_all_crosses_unread_text_and_stops_before_challenge() -> void:
	_fixture = SkipFixture.new()
	var setup: Dictionary = await _fixture.setup_pause(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false): return
	# Match Bootstrap's actual binding; changing Settings must update Bridge mode.
	var bound: Dictionary = _fixture.bridge.bind_profile_preferences(_fixture.profile)
	assert_true(bound.get("ok", false), str(bound))
	if not bound.get("ok", false): return
	var selected: Dictionary = _fixture.profile.set_preference(&"preferences.reading.skip_mode", "all_text")
	assert_true(selected.get("ok", false), str(selected))
	assert_eq(_fixture.bridge._skip_mode, &"all_text")
	var started: Dictionary = await _fixture.start_text()
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	var layer: Node = _fixture.pause._find_caption(get_tree().root)
	assert_not_null(layer)
	if layer == null: return
	for frame: int in 3: await get_tree().process_frame
	assert_false(_fixture.profile.is_line_visited(MIDDLE))
	assert_false(_fixture.profile.is_line_visited(LAST))
	var skip: Button = layer.transport_rail.get_node("Skip")
	assert_false(skip.disabled, "current Scene admits Skip through the live owner")
	skip.grab_focus()
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		get_tree().root.push_input(key, true)
	assert_true(layer.skip_controller.is_skip_active(), "native focused activation starts Skip")
	for frame: int in 30:
		await get_tree().process_frame
		if not layer.skip_controller.is_skip_active(): break
	print("DWM_SCENE_SKIP_ALL " + JSON.stringify({"line": _fixture.adapter.current_line_id(),
		"active": layer.skip_controller.is_skip_active(), "mode": str(_fixture.bridge._skip_mode),
		"boundary": _fixture.adapter.classify_next_event(), "admission": _fixture.bridge.capture_current_line_presentation_frontier()}))
	assert_eq(_fixture.adapter.current_line_id(), LAST, "all-text crosses both previously unread ordinary captions")
	assert_true(_fixture.profile.is_line_visited(MIDDLE))
	assert_true(_fixture.profile.is_line_visited(LAST))
	assert_false(layer.skip_controller.is_skip_active(), "Skip stops before the Challenge boundary")
	assert_eq(_fixture.bridge._reading_session.boundary, "line", "Skip does not dispatch the Challenge marker")
	assert_true(_fixture.native_markers.is_empty(), "no later story effect executes")
