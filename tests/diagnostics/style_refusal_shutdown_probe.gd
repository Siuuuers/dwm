extends SceneTree
## Diagnostic only: identical real refusal fixture/checks without GUT.
## --natural-shutdown leaves actual owners to SceneTree destruction; never acceptance.
const FIXTURE := preload("res://tests/support/SceneCaptionStyleRefusalFixture.gd")
var fixture: RefCounted
var _natural_shutdown := false
var _checks := 0
var _failures := 0
var _stage := "setup"
var _watchdog: Timer
var _finished := false

func _initialize() -> void:
	_natural_shutdown = OS.get_cmdline_user_args().has("--natural-shutdown")
	call_deferred("_run_probe")

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures += 1
	print("DWM_REFUSAL_PROBE check=", label, " passed=", condition)
	return condition

func _timeout() -> void:
	if _finished: return
	print("DWM_REFUSAL_PROBE timeout stage=", _stage, " natural=", _natural_shutdown)
	quit(1)

func _run_probe() -> void:
	_watchdog = Timer.new()
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.one_shot = true
	_watchdog.wait_time = 30.0
	root.add_child(_watchdog)
	_watchdog.timeout.connect(_timeout)
	_watchdog.start()
	fixture = FIXTURE.new()
	print("DWM_REFUSAL_PROBE before_setup natural=", _natural_shutdown)
	var setup: Dictionary = await fixture.setup_refusal(self)
	if not _check(setup.get("ok", false), "setup"):
		await _finish_probe()
		return
	_check(not fixture.runtime.Styles.has_active_layout_node(), "no_preinstalled_layout")
	_check(fixture.default_style_projection() == fixture.default_style_before, "default_unchanged_before")
	var attached: bool = await _await_native_attach()
	if not attached:
		quit(1)
		return
	await _exercise_refusal()
	await _finish_probe()

func _await_native_attach() -> bool:
	var nonce := OS.get_environment("DWM_NATIVE_ATTACH_NONCE")
	if nonce.is_empty(): return true
	_stage = "native_attach"
	_watchdog.stop()
	var base := OS.get_environment("DWM_TEST_ROOT")
	var ready := base.path_join("attach-ready.json")
	var proceed := base.path_join("attach-continue.json")
	if FileAccess.file_exists(ready) or FileAccess.file_exists(proceed): return false
	var file := FileAccess.open(ready + ".next", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"nonce": nonce, "pid": OS.get_process_id(),
		"mode": "natural" if _natural_shutdown else "explicit"}))
	file.close()
	if DirAccess.rename_absolute(ready + ".next", ready) != OK: return false
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(proceed):
			var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(proceed))
			if not receipt is Dictionary or receipt.get("nonce") != nonce: return false
			_watchdog.start()
			return true
		await process_frame
	print("DWM_REFUSAL_PROBE attach_timeout")
	return false

func _exercise_refusal() -> void:
	fixture.runtime.Styles.style_changed.connect(fixture.refuse_selected_style, CONNECT_ONE_SHOT)
	_stage = "start_refusal"
	var started: Dictionary = fixture.start()
	if not _check(started.get("code") == &"scene_activation_pending", "activation_pending"):
		return
	var operation_id: String = str(started.get("transaction_id", ""))
	_check(not operation_id.is_empty(), "retained_operation_id")
	_stage = "await_refusal"
	var refused: Dictionary = await fixture.await_activation()
	_check(not refused.get("ok", false), "activation_refused")
	_check(refused.get("code") == &"scene_caption_style_unavailable", "exact_refusal_code")
	_check(fixture.style_refusal_count == 1, "one_actual_style_retirement")
	_check(fixture.ready_count == 0, "no_ready")
	_check(fixture.narrative_confirmations.size() == 0, "no_narrative_confirmation")
	_check(fixture.native_publications.is_empty(), "no_native_caption_publication")
	_check(fixture.native_markers.is_empty(), "no_native_marker")
	_check(not fixture.bridge._scene_restore.get("native_started", true), "native_not_started")
	_check(not fixture.bridge._scene_restore.get("proof", true), "native_unproven")
	_check(not fixture.bridge._scene_restore.get("confirmed", true), "native_unconfirmed")
	_check(fixture.manager._scene_restore_activation.get("operation_id") == operation_id, "same_activation_operation")
	_check(fixture.manager._scene_restore_activation.get("failure") == refused, "same_activation_failure")
	var reopened: Dictionary = fixture.reopen_journal()
	if not _check(reopened.get("ok", false), "reopened_real_journal"):
		return
	var durable: Dictionary = reopened.value.get_creation_operation(operation_id)
	if not _check(durable.get("ok", false), "read_real_durable_operation"):
		return
	_check(durable.value.get("transaction_id") == operation_id, "same_durable_operation")
	_check(durable.value.get("activation_state") == "pending", "durable_activation_unacknowledged")
	var retried: Dictionary = fixture.manager.retry_scene_activation(operation_id)
	_check(retried == refused, "retry_retains_same_failure")
	for frame: int in 4: await process_frame
	_check(fixture.ready_count == 0, "still_no_ready")
	_check(fixture.native_publications.is_empty(), "still_no_native_publication")
	_check(fixture.manager._scene_restore_activation.get("operation_id") == operation_id, "still_same_operation")
	_check(fixture.default_style_projection() == fixture.default_style_before, "default_unchanged_after")

func _finish_probe() -> void:
	_stage = "cleanup"
	if fixture != null:
		_check(fixture.default_style_projection() == fixture.default_style_before, "default_unchanged_at_cleanup")
		if not _natural_shutdown:
			print("DWM_REFUSAL_PROBE before_fixture_close")
			await fixture.close_restart()
			print("DWM_REFUSAL_PROBE after_fixture_close")
			fixture = null
			print("DWM_REFUSAL_PROBE after_fixture_null")
		else:
			print("DWM_REFUSAL_PROBE natural_tree_shutdown_selected diagnostic_only")
	_watchdog.stop()
	_watchdog.queue_free()
	_stage = "drain_frames"
	for frame: int in 4: await process_frame
	_finished = true
	print("DWM_REFUSAL_PROBE completed checks=", _checks, " failures=", _failures,
		" natural=", _natural_shutdown)
	quit(0 if _failures == 0 else 1)
