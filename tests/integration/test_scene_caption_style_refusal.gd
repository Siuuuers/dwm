extends "res://addons/gut/test.gd"
## One fresh process; no Pause/service composition is needed to refuse initial style.
const FIXTURE := preload("res://tests/support/SceneCaptionStyleRefusalFixture.gd")
var fixture: RefCounted
var fixture_ready := false
var _watchdog: Timer
var _test_stage := "setup"

func before_all() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog = Timer.new()
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.one_shot = true
	_watchdog.wait_time = 30.0
	add_child(_watchdog)
	_watchdog.timeout.connect(_timeout)
	_watchdog.start()
	fixture = FIXTURE.new()
	var checked: Dictionary = await fixture.setup_refusal(get_tree())
	fixture_ready = checked.get("ok", false)
	assert_true(fixture_ready, str(checked))
	if fixture_ready:
		assert_false(fixture.runtime.Styles.has_active_layout_node(), "initial activation starts without a preinstalled layout")
		assert_eq(fixture.default_style_projection(), fixture.default_style_before)

func _timeout() -> void:
	print("DWM_STYLE_REFUSAL_TIMEOUT " + _test_stage)
	get_tree().quit(1)

func after_all() -> void:
	_test_stage = "cleanup"
	if fixture_ready: assert_eq(fixture.default_style_projection(), fixture.default_style_before,
		"scene activation must not change the global default style")
	if fixture != null: await fixture.close_restart()
	fixture = null
	fixture_ready = false
	if is_instance_valid(_watchdog):
		_watchdog.stop()
		_watchdog.queue_free()

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result))
	return result.get("ok", false)

func test_retired_native_style_refuses_activation_without_acknowledging_creation() -> void:
	if not fixture_ready: return
	fixture.runtime.Styles.style_changed.connect(fixture.refuse_selected_style, CONNECT_ONE_SHOT)
	_test_stage = "start_with_style_refusal"
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	var operation_id: String = str(started.get("transaction_id", ""))
	assert_false(operation_id.is_empty())
	_test_stage = "await_style_refusal"
	var refused: Dictionary = await fixture.await_activation()
	assert_false(refused.get("ok", false))
	assert_eq(refused.get("code"), &"scene_caption_style_unavailable")
	assert_eq(fixture.style_refusal_count, 1)
	assert_eq(fixture.ready_count, 0)
	assert_eq(fixture.narrative_confirmations.size(), 0)
	assert_eq(fixture.native_publications, [])
	assert_eq(fixture.native_markers, [])
	assert_false(fixture.bridge._scene_restore.native_started)
	assert_false(fixture.bridge._scene_restore.proof)
	assert_false(fixture.bridge._scene_restore.confirmed)
	assert_eq(fixture.manager._scene_restore_activation.operation_id, operation_id)
	assert_eq(fixture.manager._scene_restore_activation.failure, refused)
	var reopened: Dictionary = fixture.reopen_journal()
	if not _ok(reopened): return
	var durable: Dictionary = reopened.value.get_creation_operation(operation_id)
	if not _ok(durable): return
	assert_eq(durable.value.transaction_id, operation_id)
	assert_eq(durable.value.activation_state, "pending", "refused native style cannot acknowledge durable creation")
	var retried: Dictionary = fixture.manager.retry_scene_activation(operation_id)
	assert_eq(retried, refused, "same pending operation retains its actual failure")
	for frame: int in 4: await get_tree().process_frame
	assert_eq(fixture.ready_count, 0)
	assert_eq(fixture.native_publications, [])
	assert_eq(fixture.manager._scene_restore_activation.operation_id, operation_id)
	assert_eq(fixture.default_style_projection(), fixture.default_style_before)
