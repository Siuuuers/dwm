extends "res://addons/gut/test.gd"

const SOURCE_PATH := "res://scripts/narrative/DialogicCaptionProjectionSource.gd"
const ADAPTER_SCENE_PATH := "res://scenes/dialogic/NarrativeCaptionDialogicLayer.tscn"

class FakeTextSubsystem:
	extends Node
	signal text_started(info: Dictionary)

class FakeRuntime:
	extends Node
	signal timeline_started
	signal timeline_ended
	var current_event_idx := -1
	var text := FakeTextSubsystem.new()
	var mutation_calls: Array[StringName] = []

	func _init() -> void:
		add_child(text)

	func get_subsystem(name: String) -> Node:
		return text if name == "Text" else null

	func start_timeline() -> void:
		mutation_calls.append(&"start_timeline")

	func advance() -> void:
		mutation_calls.append(&"advance")

func _make_source() -> RefCounted:
	var source_script := load(SOURCE_PATH) as Script
	assert_not_null(source_script)
	if source_script == null:
		return null
	var source := source_script.new() as RefCounted
	var result: Dictionary = source.call("configure", &"fixture.session", &"single", [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
		{"event_index": 1, "event_kind": "text", "semantic_id": &"fixture.caption.two"},
	])
	assert_true(result.ok)
	return source

func _make_adapter() -> Node:
	var packed := load(ADAPTER_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return null
	var adapter := packed.instantiate()
	add_child_autofree(adapter)
	await get_tree().process_frame
	return adapter

func test_binding_is_idempotent_and_timeline_signals_reset_the_presenter() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var runtime := FakeRuntime.new()
	add_child_autofree(runtime)
	assert_true(adapter.call("bind_runtime", runtime, source).ok)
	assert_true(adapter.call("bind_runtime", runtime, source).ok)
	assert_eq(runtime.timeline_started.get_connections().size(), 1)
	assert_eq(runtime.timeline_ended.get_connections().size(), 1)
	assert_eq(runtime.text.text_started.get_connections().size(), 1)
	runtime.timeline_started.emit()
	runtime.current_event_idx = 0
	runtime.text.text_started.emit({"text": "First", "append": false})
	var presenter: Node = adapter.call("get_presenter")
	assert_eq(presenter.call("get_visual_semantic_ids"), [&"fixture.caption.one"])
	runtime.current_event_idx = 1
	runtime.text.text_started.emit({"text": "Second", "append": false})
	assert_eq(presenter.call("get_visual_semantic_ids"), [&"fixture.caption.one", &"fixture.caption.two"])
	runtime.timeline_started.emit()
	assert_true((presenter.call("get_visual_semantic_ids") as Array).is_empty())
	assert_true(runtime.mutation_calls.is_empty())

func test_append_uses_current_identity_and_end_clears_without_mutating_runtime() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var runtime := FakeRuntime.new()
	add_child_autofree(runtime)
	adapter.call("bind_runtime", runtime, source)
	runtime.timeline_started.emit()
	runtime.current_event_idx = 0
	runtime.text.text_started.emit({"text": "First", "append": false})
	runtime.text.text_started.emit({"text": " continued", "append": true})
	var presenter: Node = adapter.call("get_presenter")
	assert_eq((presenter.call("get_projection", &"fixture.caption.one") as Dictionary).primary_text, "First continued")
	runtime.timeline_ended.emit()
	assert_true((presenter.call("get_visual_semantic_ids") as Array).is_empty())
	assert_true(runtime.mutation_calls.is_empty())

func test_unknown_event_is_recorded_without_changing_presenter() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var runtime := FakeRuntime.new()
	add_child_autofree(runtime)
	adapter.call("bind_runtime", runtime, source)
	runtime.timeline_started.emit()
	runtime.current_event_idx = 99
	runtime.text.text_started.emit({"text": "Untrusted prose", "append": false})
	assert_true((adapter.call("get_presenter").call("get_visual_semantic_ids") as Array).is_empty())
	assert_eq((adapter.call("get_last_failure") as Dictionary).code, &"unknown_caption_event")
	assert_true(runtime.mutation_calls.is_empty())

func test_replacing_runtime_clears_stale_presenter_and_disconnects_previous_runtime() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var first_runtime := FakeRuntime.new()
	var second_runtime := FakeRuntime.new()
	add_child_autofree(first_runtime)
	add_child_autofree(second_runtime)
	adapter.call("bind_runtime", first_runtime, source)
	first_runtime.timeline_started.emit()
	first_runtime.current_event_idx = 0
	first_runtime.text.text_started.emit({"text": "Stale", "append": false})
	assert_eq(adapter.call("get_presenter").call("get_visual_semantic_ids"), [&"fixture.caption.one"])
	assert_true(adapter.call("bind_runtime", second_runtime, source).ok)
	assert_true((adapter.call("get_presenter").call("get_visual_semantic_ids") as Array).is_empty())
	assert_eq(first_runtime.timeline_started.get_connections().size(), 0)
	assert_eq(first_runtime.timeline_ended.get_connections().size(), 0)
	assert_eq(first_runtime.text.text_started.get_connections().size(), 0)
	assert_eq(second_runtime.timeline_started.get_connections().size(), 1)
	assert_eq(second_runtime.timeline_ended.get_connections().size(), 1)
	assert_eq(second_runtime.text.text_started.get_connections().size(), 1)
	assert_true(first_runtime.mutation_calls.is_empty())
	assert_true(second_runtime.mutation_calls.is_empty())

func test_unbind_disconnects_every_owned_signal() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var runtime := FakeRuntime.new()
	add_child_autofree(runtime)
	adapter.call("bind_runtime", runtime, source)
	adapter.call("unbind_runtime")
	assert_eq(runtime.timeline_started.get_connections().size(), 0)
	assert_eq(runtime.timeline_ended.get_connections().size(), 0)
	assert_eq(runtime.text.text_started.get_connections().size(), 0)
