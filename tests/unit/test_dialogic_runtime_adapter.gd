extends "res://addons/gut/test.gd"

# RED-first via dynamic load (dwm-p2r.8, Plan-05 Task 2 Step 2.1). Proves only the physically
# audited signals/methods are connected/called, connections are made once, a missing subsystem
# returns a safe error, and no complete addon state is serialized.

const ADAPTER_PATH := "res://scripts/narrative/DialogicRuntimeAdapter.gd"
const FAKE := preload("res://tests/support/FakeDialogicRuntime.gd")

var _adapter_script: GDScript

class NoStartRuntime extends FAKE:
	func start(_timeline: Variant, _label_or_idx: Variant = "") -> Object:
		calls.append("refused_start")
		return null

class ReadyLayoutNoStartRuntime extends FAKE:
	var layout: Node
	func start(_timeline: Variant, _label_or_idx: Variant = "") -> Object:
		return layout

class PartialQualifiedRuntime extends FAKE:
	signal timeline_started_with_generation(generation: int, request_id: String)
	signal timeline_ended_with_generation(generation: int)


func before_all() -> void:
	if ResourceLoader.exists(ADAPTER_PATH, "Script"):
		_adapter_script = load(ADAPTER_PATH)


func _new_adapter() -> Object:
	return _adapter_script.new()


func test_adapter_script_exists() -> void:
	assert_true(ResourceLoader.exists(ADAPTER_PATH, "Script"), "missing %s" % ADAPTER_PATH)


func test_bind_connects_audited_signals_once() -> void:
	if _adapter_script == null:
		return
	var fake: Node = autofree(FAKE.new())
	var adapter: Object = _new_adapter()
	assert_true(adapter.bind_runtime(fake).get("ok", false), "first bind ok")
	assert_true(adapter.bind_runtime(fake).get("ok", false), "idempotent re-bind to same runtime")
	for signal_name in ["timeline_started", "timeline_ended", "event_handled", "signal_event"]:
		assert_eq(fake.get_signal_connection_list(signal_name).size(), 1, "exactly one connection for " + signal_name)


func test_bind_rejects_missing_text_subsystem() -> void:
	if _adapter_script == null:
		return
	var fake: Node = autofree(FAKE.new(false, true))
	var result: Dictionary = _new_adapter().bind_runtime(fake)
	assert_false(result.get("ok", false), "missing Text must reject")
	assert_eq(str(result.get("code")), "missing_subsystem", "safe error code")


func test_bind_rejects_missing_choices_subsystem() -> void:
	if _adapter_script == null:
		return
	var fake: Node = autofree(FAKE.new(true, false))
	assert_false(_new_adapter().bind_runtime(fake).get("ok", false), "missing Choices must reject")


func test_bind_rejects_null_runtime() -> void:
	if _adapter_script == null:
		return
	assert_false(_new_adapter().bind_runtime(null).get("ok", false), "null runtime must reject")


func test_bind_rejects_partial_qualified_lifecycle_without_query_methods() -> void:
	var fake: Node = autofree(PartialQualifiedRuntime.new())
	var result: Dictionary = _new_adapter().bind_runtime(fake)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"invalid_runtime")


func test_start_timeline_orders_clear_reapply_then_start() -> void:
	if _adapter_script == null:
		return
	var fake: Node = autofree(FAKE.new())
	var adapter: Object = _new_adapter()
	adapter.bind_runtime(fake)
	var snapshots: Array = []
	adapter.preference_reapply_requested.connect(func() -> void: snapshots.append(fake.calls.duplicate()))
	var result: Dictionary = adapter.start_timeline("res://dialogic/timelines/en/core/opening_day1.dtl", 0)
	assert_true(result.get("ok", false), str(result))
	assert_eq(snapshots.size(), 1, "reapply fires exactly once")
	assert_eq(snapshots[0], ["clear:1"], "reapply fires after clear and before start")
	assert_eq(fake.calls, ["clear:1", "start:res://dialogic/timelines/en/core/opening_day1.dtl:0"], "clear then start")


func test_capture_checkpoint_never_serializes_full_state() -> void:
	if _adapter_script == null:
		return
	var fake: Node = autofree(FAKE.new())
	var adapter: Object = _new_adapter()
	adapter.bind_runtime(fake)
	adapter.start_timeline("res://x.dtl", 0)
	var captured: Dictionary = adapter.capture_checkpoint()
	assert_true(captured.get("ok", false), str(captured))
	assert_eq(fake.full_state_reads(), 0, "adapter must never call get_full_state")
	assert_true(captured["value"]["timeline_active"], "timeline active after start")


func test_runtime_start_refusal_does_not_leave_admission_occupied() -> void:
	var fake: Node = autofree(NoStartRuntime.new())
	var adapter: Object = _new_adapter()
	assert_true(adapter.bind_runtime(fake).get("ok",false))
	assert_false(adapter.start_timeline("res://refused.dtl").get("ok",true))
	assert_false(adapter.has_active_playback())
	assert_null(fake.current_timeline)


func test_ready_layout_without_timeline_is_removed_after_failed_start() -> void:
	var fake: Node = autofree(ReadyLayoutNoStartRuntime.new())
	fake.layout = Node.new()
	add_child(fake.layout)
	var layout: Node = fake.layout
	var adapter: Object = _new_adapter()
	assert_true(adapter.bind_runtime(fake).get("ok",false))
	assert_false(adapter.start_timeline("res://refused.dtl").get("ok",true))
	assert_false(adapter.has_active_playback())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(layout), "failed startup leaves no mounted layout")


func test_reentrant_cancel_before_native_start_cannot_be_overwritten_by_startup() -> void:
	var fake: Node = autofree(FAKE.new())
	var adapter: Object = _new_adapter()
	assert_true(adapter.bind_runtime(fake).get("ok",false))
	adapter.preference_reapply_requested.connect(func(): adapter.halt_with_error({"code":"fixture_cancel"}))
	assert_false(adapter.start_timeline("res://cancelled.dtl").get("ok",true))
	assert_eq(fake.calls,["clear:1"],"cancelled startup never reaches the native start call")
	assert_false(adapter.has_active_playback())
	assert_null(fake.current_timeline)


func test_capture_and_restore_state_roundtrip() -> void:
	if _adapter_script == null:
		return
	var fake: Node = autofree(FAKE.new())
	var adapter: Object = _new_adapter()
	adapter.bind_runtime(fake)
	adapter.start_timeline("res://x.dtl", 0)
	var backup: Dictionary = adapter.capture_restore_state()
	assert_true(backup.get("ok", false), str(backup))
	assert_true(adapter.restore_captured_state(backup["value"]["backup"]).get("ok", false), "restore ok")


func test_halt_ends_timeline_and_returns_error() -> void:
	if _adapter_script == null:
		return
	var fake: Node = autofree(FAKE.new())
	var adapter: Object = _new_adapter()
	adapter.bind_runtime(fake)
	adapter.start_timeline("res://x.dtl", 0)
	var result: Dictionary = adapter.halt_with_error({"reason": "bad_event"})
	assert_false(result.get("ok", true), "halt returns an error result")
	assert_true("end_timeline:true" in fake.calls, "halt ends the timeline")
