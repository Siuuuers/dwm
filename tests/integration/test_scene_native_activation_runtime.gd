extends "res://addons/gut/test.gd"
## Actual installed native restoration, with detached TEST scene admission.
## Proves saved caption installation, not Save9 persistence or issuer admission.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
var _runtime: DialogicGameHandler
var _adapter: DialogicRuntimeAdapter
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
var _results: Array[Dictionary] = []
var _profile_before: Dictionary = {}
var _bridge: Node

func before_all() -> void:
	assert_true(BASE.configure().ok)

func before_each() -> void:
	_results.clear()
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
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	add_child(_viewport)
	var layout: Node = _runtime.Styles.load_style(STYLE, _viewport)
	assert_not_null(layout)
	if not layout.is_node_ready(): await layout.ready
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void: _results.append(result.duplicate(true)))

	_bridge = BRIDGE.new()
	autofree(_bridge)
	_bridge._runtime_adapter = _adapter

func test_real_native_restores_saved_second_caption_without_executing_end_or_republishing() -> void:
	var created: Dictionary = BASE.create_session()
	assert_true(created.ok)
	var session: RefCounted = created.value
	assert_true(BASE.enter(session, BASE.B, "TEST.native.restore").ok)
	var advanced: Dictionary = BASE.advance_detached(session)
	assert_true(advanced.ok)
	var saved: Dictionary = BASE.checkpoint(session)
	assert_true(saved.ok)
	assert_eq(saved.value.reading_session.frontier.line_id, "line.scene.test.b.two")
	var ledger: Dictionary = session.ledger.snapshot().duplicate(true)
	var confirmations: Array[String] = []
	var markers: Array = []
	_bridge.scene_activation_confirmed.connect(func(id: String) -> void: confirmations.append(id))
	_adapter.runtime_signal_event.connect(func(value: Variant) -> void: markers.append(value))
	assert_true(_bridge.stage_scene_reading_restore(saved.value, "restore.native").ok)
	assert_false(_adapter.has_active_playback(), "silent staging starts no native timeline")
	assert_true(_bridge.begin_scene_activation("restore.native").ok)
	for frame: int in 30:
		if not confirmations.is_empty(): break
		await get_tree().process_frame
	assert_eq(confirmations, ["restore.native"])
	assert_true(_bridge.validate_scene_activation("restore.native").ok)
	assert_eq(_adapter.current_line_id(), "line.scene.test.b.two")
	assert_eq(_adapter.capture_reading_frontier().value, saved.value.reading_session.frontier)
	assert_eq(_bridge._reading_session.ledger.snapshot(), ledger)
	var boundary: Dictionary = _bridge.capture_scene_event_boundary()
	assert_true(boundary.ok)
	if boundary.ok:
		assert_eq(boundary.value.anchor.session_id, "TEST.native.restore")
		assert_ne(boundary.value.anchor.session_id, saved.value.reading_session.ledger.session_token)
		assert_true(_bridge.validate_scene_event_anchor(boundary.value.anchor, saved.value).ok)
		var forged: Dictionary = boundary.value.anchor.duplicate(true)
		forged.session_id = saved.value.reading_session.ledger.session_token
		assert_false(_bridge.validate_scene_event_anchor(forged, saved.value).ok)
	assert_false(_results.is_empty(), "native text_started was actually observed")
	for result: Dictionary in _results:
		assert_true(result.ok)
		assert_true(result.get("value", {}).get("duplicate", false), "restore reuses only the committed publication")
	assert_eq(markers, [], "future end marker cannot execute while restoring source caption")
	assert_true(_bridge.begin_scene_activation("restore.native").ok)
	assert_eq(confirmations.size(), 1)

func after_each() -> void:
	assert_eq(get_node("/root/ProfileManager").get_profile_snapshot(), _profile_before,
		"internal publication capture cannot write the real Profile")
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		var remaining: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(remaining) and not _viewport.is_ancestor_of(remaining): remaining.queue_free()
	_viewport.queue_free()
	await get_tree().process_frame
	if is_instance_valid(_runtime): _runtime.free()
	_adapter = null
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

func _settle() -> void:
	for frame: int in 6: await get_tree().process_frame


