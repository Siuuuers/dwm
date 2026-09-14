extends SceneTree
## Windows-native viewport probe for the mounted Witnessed reading-recovery surface.
## Input packets are injected through Viewport.push_input; this is not a hardware claim.
## Run through Invoke-IsolatedGodot.ps1 with the user argument
## `-- --phase2r-bootstrap-mode=final` so ApplicationBootstrap composes production Pause.

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
const RECOVERY := preload("res://scenes/ui/witnessed/WitnessedTransportRecovery.tscn")

const DEADLINE_MSEC := 5000
const STARTUP_DEADLINE_MSEC := 30000
const CONTROLLER_DEVICE := 37

var _failures: Array[String] = []
var _retry_count := 0
var _cancel_count := 0
var _observer: BackObserver
var _recovery: Control
var _layer: CanvasLayer
var _added_controller_binding := false
var _result_path := ""


class BackObserver extends Node:
	var keyboard_count := 0
	var controller_count := 0

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(event: InputEvent) -> void:
		if not event.is_action_pressed(&"ui_cancel", false): return
		if event is InputEventKey: keyboard_count += 1
		elif event is InputEventJoypadButton: controller_count += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var allocated: Dictionary = TEMPORARY_STORAGE.create("witnessed-recovery-custody-native")
	if not allocated.get("ok", false) or DisplayServer.get_name() != "Windows":
		printerr("WITNESSED_RECOVERY_CUSTODY_FAILED root/display ", allocated)
		quit(1)
		return
	var isolated := str(allocated.value)
	var output_dir := isolated.path_join("witnessed-recovery-custody")
	_result_path = output_dir.path_join("result.json")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("WITNESSED_RECOVERY_CUSTODY_FAILED cannot create output directory")
		quit(1)
		return
	var profile: Node = root.get_node_or_null("ProfileManager")
	var localization: Node = root.get_node_or_null("LocalizationManager")
	var input_owner: Node = root.get_node_or_null("InputManager")
	var router: Node = root.get_node_or_null("SceneRouter")
	var bootstrap: Node = root.get_node_or_null("ApplicationBootstrap")
	if profile == null or localization == null or input_owner == null or router == null \
			or bootstrap == null:
		_fail("required production owner is unavailable")
		await _finish({})
		return
	# The wrapper already redirects user://. Let the actual final-mode bootstrap create
	# Pause and initialize Profile/Localization; preinitializing either races its deferred start.
	var startup_ready: bool = await _wait_until(func() -> bool:
		return bootstrap.get_startup_state().get("ready", false), STARTUP_DEADLINE_MSEC)
	var startup_state: Dictionary = bootstrap.get_startup_state()
	if not startup_ready:
		_fail("production bootstrap did not become ready")
		await _finish({}, {"startup_state": startup_state})
		return
	if not localization.set_locale("en").get("ok", false):
		_fail("isolated production localization rejected English")
		await _finish({}, {"startup_state": startup_state})
		return
	var pause_candidate: Variant = router.get("_production_pause")
	if not is_instance_valid(pause_candidate) or not (pause_candidate.get("surface") is Control):
		_fail("ready production bootstrap has no composed Pause host")
		await _finish({}, {"startup_state": startup_state})
		return
	var pause_host: Node = pause_candidate
	var pause_before := _pause_projection(pause_host)
	if pause_before.tree_paused or pause_before.surface_visible \
			or not pause_before.handle_empty or pause_before.busy:
		_fail("production Pause baseline is not idle")
		await _finish(pause_before)
		return
	_install_controller_binding()
	_observer = BackObserver.new()
	_observer.name = "RecoveryBackLeakObserver"
	root.add_child(_observer)
	_layer = CanvasLayer.new()
	_layer.name = "RecoveryCustodyProbeLayer"
	_layer.layer = 3
	root.add_child(_layer)
	_recovery = RECOVERY.instantiate()
	_layer.add_child(_recovery)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	if not _recovery.bind_owners(localization, input_owner, func() -> bool: return true) \
			or not _recovery.configure_presentation(
				"en", 150, "AfterHours", false, "standard", false):
		_fail("recovery owners/presentation did not bind")
		await _finish(pause_before)
		return
	_recovery.retry_requested.connect(func() -> void: _retry_count += 1)
	_recovery.cancel_requested.connect(func() -> void: _cancel_count += 1)

	var determinate := await _probe_determinate(pause_host, pause_before, input_owner)
	var fatal := await _probe_fatal(pause_host, pause_before, input_owner)
	await _finish(pause_before, {"determinate": determinate, "fatal": fatal,
		"display_server": DisplayServer.get_name(),
		"input_provenance": "Viewport.push_input injected key and joypad packets; no hardware claim",
		"controller_binding": "temporary ui_cancel JOY_BUTTON_B on synthetic device 37"})


func _probe_determinate(pause_host: Node, pause_before: Dictionary,
		input_owner: Node) -> Dictionary:
	if not _recovery.present(true, true):
		_fail("determinate recovery refused presentation")
		return {}
	var retry := _recovery.get("retry_button") as Button
	var cancel := _recovery.get("cancel_button") as Button
	# present() schedules a focus repair; let that presentation boundary settle before
	# proving that the first Tab advances away from Retry.
	await process_frame
	if not await _wait_until(func() -> bool: return retry.has_focus()):
		_fail("determinate recovery did not focus Retry")
	var focus_sequence: Array[String] = [_focus_name()]
	_tap_key(KEY_TAB)
	await process_frame
	focus_sequence.append(_focus_name())
	_tap_key(KEY_TAB)
	await process_frame
	focus_sequence.append(_focus_name())
	_tap_key(KEY_TAB, true)
	await process_frame
	focus_sequence.append(_focus_name())
	var expected_focus: Array[String] = [String(retry.name), String(cancel.name),
		String(retry.name), String(cancel.name)]
	if focus_sequence != expected_focus:
		_fail("Tab focus escaped recovery: " + JSON.stringify(focus_sequence))
	retry.grab_focus()
	await process_frame
	var actions_before := [_retry_count, _cancel_count]
	var observer_before := [_observer.keyboard_count, _observer.controller_count]
	_tap_key(KEY_ESCAPE)
	await process_frame
	_tap_controller_back()
	await process_frame
	var contacts_empty: bool = input_owner.get_physical_contacts().is_empty()
	var contained: bool = _recovery.is_presented() \
		and [_retry_count, _cancel_count] == actions_before \
		and [_observer.keyboard_count, _observer.controller_count] == observer_before \
		and _pause_projection(pause_host) == pause_before and contacts_empty
	if not contained: _fail("determinate Back escaped or acted")
	var result := {"contained": contained, "focus_sequence": focus_sequence,
		"retry_count": _retry_count, "cancel_count": _cancel_count,
		"lower_keyboard_count": _observer.keyboard_count,
		"lower_controller_count": _observer.controller_count,
		"production_pause_unchanged": _pause_projection(pause_host) == pause_before,
		"physical_contacts_empty": contacts_empty}
	_recovery.dismiss()
	await process_frame
	return result


func _probe_fatal(pause_host: Node, pause_before: Dictionary,
		input_owner: Node) -> Dictionary:
	if not _recovery.present(false, false):
		_fail("fatal recovery refused presentation")
		return {}
	var retry := _recovery.get("retry_button") as Button
	var cancel := _recovery.get("cancel_button") as Button
	await process_frame
	var no_actions: bool = not retry.visible and retry.disabled \
		and not cancel.visible and cancel.disabled and not retry.has_focus() and not cancel.has_focus()
	if not no_actions: _fail("fatal recovery exposed an action or action focus")
	var actions_before := [_retry_count, _cancel_count]
	var observer_before := [_observer.keyboard_count, _observer.controller_count]
	_tap_key(KEY_ESCAPE)
	await process_frame
	_tap_controller_back()
	await process_frame
	var contacts_empty: bool = input_owner.get_physical_contacts().is_empty()
	var contained: bool = _recovery.is_presented() and no_actions \
		and [_retry_count, _cancel_count] == actions_before \
		and [_observer.keyboard_count, _observer.controller_count] == observer_before \
		and _pause_projection(pause_host) == pause_before and contacts_empty
	if not contained: _fail("fatal Back escaped, dismissed, or acted")
	return {"contained": contained, "no_actions": no_actions,
		"retry_count": _retry_count, "cancel_count": _cancel_count,
		"lower_keyboard_count": _observer.keyboard_count,
		"lower_controller_count": _observer.controller_count,
		"production_pause_unchanged": _pause_projection(pause_host) == pause_before,
		"physical_contacts_empty": contacts_empty}


func _tap_key(code: Key, shift := false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		root.push_input(event, true)


func _tap_controller_back() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_B
		event.device = CONTROLLER_DEVICE
		event.pressed = pressed
		root.push_input(event, true)


func _install_controller_binding() -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B
	event.device = CONTROLLER_DEVICE
	_added_controller_binding = not InputMap.action_has_event(&"ui_cancel", event)
	if _added_controller_binding: InputMap.action_add_event(&"ui_cancel", event)


func _remove_controller_binding() -> void:
	if not _added_controller_binding: return
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B
	event.device = CONTROLLER_DEVICE
	InputMap.action_erase_event(&"ui_cancel", event)
	_added_controller_binding = false


func _focus_name() -> String:
	var focused := root.gui_get_focus_owner()
	return focused.name if focused != null else ""


func _pause_projection(host: Node) -> Dictionary:
	var surface := host.get("surface") as Control
	var handle: Variant = host.get("_handle")
	return {"tree_paused": paused, "surface_visible": surface != null and surface.is_visible_in_tree(),
		"handle_empty": handle is Dictionary and handle.is_empty(),
		"busy": bool(host.get("_busy"))}


func _wait_until(predicate: Callable, timeout_msec: int = DEADLINE_MSEC) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call() == true: return true
		await process_frame
	return predicate.call() == true


func _finish(pause_before: Dictionary, observations: Dictionary = {}) -> void:
	if is_instance_valid(_recovery): _recovery.dismiss()
	_remove_controller_binding()
	if is_instance_valid(_layer): _layer.queue_free()
	if is_instance_valid(_observer): _observer.queue_free()
	await process_frame
	var ok := _failures.is_empty()
	var receipt := {"ok": ok, "failures": _failures,
		"pause_baseline": pause_before, "observations": observations,
		"result_path": _result_path,
		"scope": "real recovery scene and composed Pause host on the Windows main viewport, plus a lower unhandled-input observer; the current menu is not a playable narrative Pause-admission fixture; injected packets, no hardware/UIA claim"}
	var file := FileAccess.open(_result_path, FileAccess.WRITE)
	if file == null:
		ok = false
		receipt.ok = false
		receipt.failures.append("cannot write result receipt")
	else:
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
	print("RESULT " + JSON.stringify(receipt))
	quit(0 if ok else 1)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("WITNESSED_RECOVERY_CUSTODY_FAILED: " + message)
