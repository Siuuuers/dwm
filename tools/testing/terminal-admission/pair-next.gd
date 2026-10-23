extends "res://.godot/ci/pair.gd"
## Identical baseline/candidate observations; input and assertions stay in the parent.
var _ui_timings: Array[Dictionary] = []
var _load_pressed_us := 0

func test_genuine_ending_load_save() -> void:
	await super.test_genuine_ending_load_save()

func _setup_authored() -> bool:
	var succeeded := super._setup_authored()
	if succeeded:
		# Connect before _load_authored's checkpoint-copy observation callback.
		saves.live_session_ready.connect(_observe_load_ready)
	return succeeded

func _observe_load_ready() -> void:
	var ready_us := Time.get_ticks_usec()
	if _load_pressed_us == 0: return
	_ui_timings.append({"operation": "load_action_to_ready", "started_us": _load_pressed_us,
		"finished_us": ready_us, "elapsed_us": ready_us - _load_pressed_us})
	_load_pressed_us = 0

func _press_label(control: Control) -> String:
	if not is_instance_valid(control): return ""
	var scene: Node = get_tree().current_scene
	if scene is MenuScene:
		if control == scene.get_node("%LogInButton"): return "title_backup_open"
		var app: Control = scene._backup_app_instance
		if is_instance_valid(app):
			if control == app.action_buttons.get("load"): return "load_action"
			if app.drawer_buttons.values().has(control): return "load_slot_select"
			if is_instance_valid(app.confirmation) and control == app.confirmation.confirm_button:
				return "load_confirmation"
	else:
		var caption: Node = _caption()
		if is_instance_valid(caption) and control == caption.transport_rail.get_node("Save"):
			return "ending_backup_open"
		var surface: Control = get_node("/root/SceneRouter")._production_pause.surface
		var app: Control = surface._hosts.get(&"backup")
		if is_instance_valid(app):
			if control == app.action_buttons.get("save"): return "save_action"
			if app.drawer_buttons.values().has(control): return "save_slot_select"
		if control == surface.rows.get(&"continue"): return "continue"
	return ""

func _press_authored(control: Control) -> bool:
	var label := _press_label(control)
	if label.is_empty(): return await super._press_authored(control)
	var save_app: Control = null
	if label == "save_action":
		save_app = get_node("/root/SceneRouter")._production_pause.surface._hosts[&"backup"]
	var started := Time.get_ticks_usec()
	if label == "load_action": _load_pressed_us = started
	var succeeded := await super._press_authored(control)
	var finished := Time.get_ticks_usec()
	var row := {"operation": label + "_press_return", "started_us": started,
		"finished_us": finished, "elapsed_us": finished - started, "ok": succeeded}
	if is_instance_valid(save_app):
		row.save_in_operation_at_return = save_app._in_operation
		row.save_result_ok_at_return = save_app.last_result.get("ok", false)
	_ui_timings.append(row)
	return succeeded

func _end(label: String, started: int, succeeded: bool) -> void:
	_pair_result.ui_timings = _ui_timings.duplicate(true)
	_pair_result.ui_timing_scope = "Press-return includes the existing five frame waits; Load Ready is the existing owner signal. No added validation, screenshot or wait."
	super._end(label, started, succeeded)
