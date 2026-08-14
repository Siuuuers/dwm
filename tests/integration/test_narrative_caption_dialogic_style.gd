extends "res://addons/gut/test.gd"

const STYLE_PATH := "res://dialogic/styles/NarrativeCaptionStyle.tres"
const FIXTURE_PATH := "res://tests/fixtures/dialogic/narrative_caption_style_fixture.dtl"
const SOURCE_PATH := "res://scripts/narrative/DialogicCaptionProjectionSource.gd"

var _host: Node = null
var _adapter: Node = null
var _segments: Array[Dictionary] = []
var _snapshots: Array = []
var _timeline_ended_observed := false
var _adapter_exit_observed := false
var _ended_snapshot: Array = []

func before_each() -> void:
	_segments.clear()
	_snapshots.clear()
	_timeline_ended_observed = false
	_adapter_exit_observed = false
	_ended_snapshot.clear()
	ProjectSettings.set_meta("caption_test_old_skip_delay", ProjectSettings.get_setting("dialogic/text/text_reveal_skip_delay", 0.1))
	ProjectSettings.set_setting("dialogic/text/text_reveal_skip_delay", 0.0)

func after_each() -> void:
	if Dialogic.Text.text_started.is_connected(_capture_segment):
		Dialogic.Text.text_started.disconnect(_capture_segment)
	if Dialogic.timeline_ended.is_connected(_capture_timeline_end):
		Dialogic.timeline_ended.disconnect(_capture_timeline_end)
	if is_instance_valid(_adapter):
		_adapter.call("unbind_runtime")
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
	elif Dialogic.Styles.has_active_layout_node():
		var active := Dialogic.Styles.get_layout_node()
		if is_instance_valid(active):
			active.queue_free()
	await get_tree().process_frame
	if get_tree().has_meta("dialogic_layout_node"):
		get_tree().remove_meta("dialogic_layout_node")
	ProjectSettings.set_setting(
		"dialogic/text/text_reveal_skip_delay",
		ProjectSettings.get_meta("caption_test_old_skip_delay", 0.1)
	)
	ProjectSettings.remove_meta("caption_test_old_skip_delay")

func test_explicit_style_drives_physical_timeline_with_one_text_owner() -> void:
	var style := load(STYLE_PATH)
	assert_not_null(style)
	assert_true(FileAccess.file_exists(FIXTURE_PATH))
	if style == null or not FileAccess.file_exists(FIXTURE_PATH):
		return
	assert_ne(str(ProjectSettings.get_setting("dialogic/layout/default_style", "")), STYLE_PATH)

	_host = Node.new()
	add_child_autofree(_host)
	var layout := Dialogic.Styles.load_style(STYLE_PATH, _host)
	assert_not_null(layout)
	await get_tree().process_frame
	await get_tree().process_frame

	_adapter = layout.find_child("NarrativeCaptionDialogicLayer", true, false)
	assert_not_null(_adapter)
	if _adapter == null:
		return
	var source_script := load(SOURCE_PATH) as Script
	assert_not_null(source_script)
	if source_script == null:
		return
	var source: RefCounted = source_script.new()
	assert_true(source.call("configure", &"fixture.caption.session", &"single", [
		{"event_index": 3, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
		{"event_index": 4, "event_kind": "text", "semantic_id": &"fixture.caption.two"},
		{"event_index": 5, "event_kind": "text", "semantic_id": &"fixture.caption.three"},
		{"event_index": 6, "event_kind": "text", "semantic_id": &"fixture.caption.four"},
	]).ok)
	assert_true(_adapter.call("bind_runtime", Dialogic, source).ok)
	Dialogic.Text.text_started.connect(_capture_segment)

	Dialogic.start_timeline(FIXTURE_PATH)
	await _wait_for_segment_count(1)
	assert_eq(_event_script_classes(Dialogic.current_timeline_events, 0, 3), [
		&"DialogicCommentEvent",
		&"DialogicCommentEvent",
		&"DialogicCommentEvent",
	])
	assert_eq(_event_script_classes(Dialogic.current_timeline_events, 3, 7), [
		&"DialogicTextEvent",
		&"DialogicTextEvent",
		&"DialogicTextEvent",
		&"DialogicTextEvent",
	])
	for expected_count in range(2, 6):
		Dialogic.Text.skip_text_reveal()
		Dialogic.Inputs.handle_input()
		await _wait_for_segment_count(expected_count)

	assert_eq(_segments.size(), 5)
	assert_eq(_snapshots[3], [&"fixture.caption.one", &"fixture.caption.two", &"fixture.caption.three"])
	assert_eq(_snapshots[4], [&"fixture.caption.two", &"fixture.caption.three", &"fixture.caption.four"])
	var presenter: Node = _adapter.call("get_presenter")
	assert_eq((presenter.call("get_projection", &"fixture.caption.three") as Dictionary).primary_text, "Third caption. Continued third caption.")

	var owners := _nodes_in_active_layout("dialogic_dialog_text")
	assert_eq(owners.size(), 1)
	assert_same(presenter.call("get_current_text_owner"), owners[0])
	assert_true(_nodes_in_active_layout("dialogic_name_label").is_empty())
	assert_true(_nodes_with_script_class(&"DialogicNode_NameLabel").is_empty())
	assert_null(layout.find_child("VN_TextboxLayer", true, false))
	assert_null(layout.find_child("DialogueBox", true, false))

	_adapter.tree_exiting.connect(_capture_adapter_exit.bind(presenter), CONNECT_ONE_SHOT)
	Dialogic.timeline_ended.connect(_capture_timeline_end, CONNECT_ONE_SHOT)
	Dialogic.Text.skip_text_reveal()
	await Dialogic.end_timeline(true)
	await _wait_for_timeline_end()
	assert_true(_timeline_ended_observed)
	assert_true(_adapter_exit_observed)
	assert_true(_ended_snapshot.is_empty())
	assert_null(Dialogic.current_timeline)

func _capture_segment(info: Dictionary) -> void:
	_segments.append(info.duplicate(true))
	var presenter: Node = _adapter.call("get_presenter")
	_snapshots.append((presenter.call("get_visual_semantic_ids") as Array).duplicate())

func _wait_for_segment_count(expected: int) -> void:
	for _frame in 120:
		if _segments.size() >= expected:
			return
		await get_tree().process_frame
	assert_true(false, "timed out waiting for Dialogic text segment %d" % expected)

func _capture_timeline_end() -> void:
	_timeline_ended_observed = true

func _capture_adapter_exit(presenter: Node) -> void:
	_adapter_exit_observed = true
	_ended_snapshot = (presenter.call("get_visual_semantic_ids") as Array).duplicate()

func _wait_for_timeline_end() -> void:
	for _frame in 120:
		if _timeline_ended_observed:
			return
		await get_tree().process_frame
	assert_true(false, "timed out waiting for Dialogic timeline end")

func _nodes_in_active_layout(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	var layout := Dialogic.Styles.get_layout_node()
	if not is_instance_valid(layout):
		return result
	for node in get_tree().get_nodes_in_group(group_name):
		if layout == node or layout.is_ancestor_of(node):
			result.append(node)
	return result

func _nodes_with_script_class(script_class: StringName) -> Array[Node]:
	var result: Array[Node] = []
	var layout := Dialogic.Styles.get_layout_node()
	if not is_instance_valid(layout):
		return result
	var candidates: Array[Node] = [layout]
	candidates.append_array(layout.find_children("*", "", true, false))
	for node in candidates:
		var script := node.get_script() as Script
		if script != null and StringName(script.get_global_name()) == script_class:
			result.append(node)
	return result

func _event_script_classes(events: Array, start: int, end: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for index in range(start, end):
		var event := events[index] as Object
		var script := event.get_script() as Script
		result.append(StringName(script.get_global_name()) if script != null else &"")
	return result
