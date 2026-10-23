extends SceneTree
## Engine-routed Contacts input with a read-counting presentation port.

const APP := preload("res://scenes/apps/ContactListApp.tscn")
var app: Control
var checks := 0
var failures: Array[String] = []
var port := Presentation.new()
var input_spy := InputSpy.new()

class InputSpy extends Node:
	var emulated_mouse_packets := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
			emulated_mouse_packets += 1

class Presentation extends RefCounted:
	var opened: Array[String] = []
	var replies := 0
	var projections := 0
	func get_projection(friend_id: String, _primary: String = "en", _secondary: String = "") -> Dictionary:
		projections += 1
		return {"ok": true, "value": {"friend_id": friend_id, "entries": [],
			"unread": {"priscilla": true, "lavinia": true, "sylvia": true}, "reply_required": false}}
	func open_friend(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		opened.append(friend_id)
		return get_projection(friend_id, primary, secondary)
	func reply_to_group(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
		replies += 1
		return get_projection(friend_id, primary, secondary)

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func():
		printerr("CONTACTS_TOUCH_PROBE_TIMEOUT")
		quit(1))
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func _frames(count: int = 3) -> void:
	for ignored in range(count): await process_frame

func _point(index: int = 1) -> Vector2:
	return app.contacts_panel.rows[index].get_global_rect().get_center()

func _touch(index: int, pressed: bool, point: Vector2, cancelled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = point
	event.canceled = cancelled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(index: int = 0, row: int = 1) -> void:
	_touch(index, true, _point(row))
	await _frames()
	_touch(index, false, _point(row))
	await _frames()

func _mouse(pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	if OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty():
		printerr("DWM_TEST_ROOT required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	Input.emulate_touch_from_mouse = false
	Input.emulate_mouse_from_touch = true
	# Headless input has no SDL-connected pad; install its semantic Accept
	# position explicitly, as the existing native component fixtures do.
	var controller_accept := InputEventJoypadButton.new()
	controller_accept.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event(&"ui_accept", controller_accept):
		InputMap.action_add_event(&"ui_accept", controller_accept)
	app = APP.instantiate()
	_check(app.configure_presentation(port).ok, "memory port admitted")
	root.add_child(app)
	app.position = Vector2(480, 64)
	app.size = Vector2(800, 656)
	root.add_child(input_spy)
	await _frames()
	_check(app.contacts_panel.selected_friend == "", "fresh view has no opened thread")
	_check(app.contacts_panel.rows[1].unread, "inspection fixture is unread")
	var p := _point()
	var description: String = app.contacts_panel.rows[1].accessibility_description
	var projection_count := port.projections
	_touch(0, true, p)
	await create_timer(0.65).timeout
	_check(port.opened.is_empty(), "long hold sends no read/open")
	_check(port.projections == projection_count, "inspection requests no new projection")
	_check(app.contacts_panel.rows[1].is_touch_inspecting(), "long hold draws the existing quiet inspection state")
	_check(app.contacts_panel.rows[1].has_focus(), "long hold exposes existing focus/inspection")
	_check(app.contacts_panel.rows[1].accessibility_description == description, "inspection retains truthful public description")
	_check(app.contacts_panel.selected_friend == "", "inspection never selects a thread")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://.godot/phase2r_logs/contacts-touch-inspection.png") == OK,
			"native inspection capture written")
	_touch(0, false, p)
	await _frames()
	_check(port.opened.is_empty(), "long-press release and emulated mouse do not open")
	_check(app.contacts_panel.rows[1].unread, "long press leaves unread unchanged")
	_check(input_spy.emulated_mouse_packets > 0, "real engine synthesized tagged mouse packets from touch")
	await _tap()
	_check(port.opened == ["lavinia"], "fresh short tap opens once with mouse emulation enabled")
	for emulate: bool in [false, true]:
		Input.emulate_mouse_from_touch = emulate
		var before := port.opened.size()
		await _tap(0, 0)
		_check(port.opened.size() == before + 1, "short tap opens once; emulation=%s" % emulate)
		before = port.opened.size()
		var offset_point := _point(2)
		_touch(0, true, offset_point)
		_drag(0, offset_point + Vector2(6, 0), Vector2(6, 0))
		_touch(0, false, offset_point + Vector2(6, 0))
		await _frames()
		_check(port.opened.size() == before + 1, "six-pixel jitter on offset Sylvia row remains a tap")
		before = port.opened.size()
		_touch(0, true, p)
		_drag(0, p + Vector2(24, 0), Vector2(24, 0))
		_drag(0, p, Vector2(-24, 0))
		_touch(0, false, p)
		await _frames()
		_check(port.opened.size() == before, "drag out and return cannot become a tap")
		_touch(0, true, p)
		_touch(1, true, _point(2))
		await create_timer(0.6).timeout
		_check(not app.contacts_panel.rows[1].is_touch_inspecting()
			and not app.contacts_panel.rows[2].is_touch_inspecting(), "multitouch never matures into inspection")
		_touch(1, false, _point(2))
		_touch(0, false, p)
		await _frames()
		_check(port.opened.size() == before, "two rows touched in one gesture activate neither")
		_touch(0, true, p)
		_touch(1, true, Vector2(30, 30))
		_touch(0, false, p)
		_touch(1, false, Vector2(30, 30))
		await _frames()
		_check(port.opened.size() == before, "second contact outside app also cancels")
		_touch(0, true, p)
		_touch(0, false, p, true)
		await _frames()
		_check(port.opened.size() == before, "cancelled OS touch cannot open")
		await _tap()
		_check(port.opened.size() == before + 1, "neutral after cancelled gestures rearms")
	Input.emulate_mouse_from_touch = true
	var before := port.opened.size()
	_touch(0, true, p)
	app.hide_window()
	await _frames()
	app.show_window()
	_touch(0, false, p)
	await _frames()
	_check(port.opened.size() == before, "hidden and reopened app refuses old touch release")
	await _tap()
	_check(port.opened.size() == before + 1, "fresh tap works after reopen")
	before = port.opened.size()
	_touch(0, true, p)
	paused = true
	await _frames()
	paused = false
	_touch(0, false, p)
	await _frames()
	_check(port.opened.size() == before, "Pause cancels touch even when held until Continue")
	await _tap()
	_check(port.opened.size() == before + 1, "fresh tap works after Pause")
	before = port.opened.size()
	_touch(0, true, p)
	app.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	app.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_touch(0, false, p)
	await _frames()
	_check(port.opened.size() == before, "window focus loss retires the gesture")
	await _tap()
	_check(port.opened.size() == before + 1, "fresh tap works after window focus returns")
	before = port.opened.size()
	_touch(0, true, p)
	var input_owner := root.get_node("InputManager")
	var suspension := {"generation": 1, "handle_id": "contacts-touch-probe",
		"holder": &"contacts_touch_probe", "reason": &"universal_pause"}
	_check(input_owner.begin_suspend(suspension).ok, "real input owner suspends source")
	_check(input_owner.resume(suspension).ok, "real input owner resumes with held-contact quarantine")
	_touch(0, false, p)
	await _frames()
	_check(port.opened.size() == before, "custody loss cancels without hiding app")
	await _tap()
	_check(port.opened.size() == before + 1, "fresh tap after custody returns is admitted")
	before = port.opened.size()
	app.contacts_panel.rows[0].grab_focus()
	app.contacts_panel.rows[1].focus_entered.connect(func():
		app.hide_window()
		app.show_window(), CONNECT_ONE_SHOT)
	_touch(0, true, p)
	_touch(0, false, p)
	await _frames()
	_check(port.opened.size() == before, "focus callback cannot revive a touch retired by hide/reopen")
	await _tap()
	_check(port.opened.size() == before + 1, "fresh tap follows synchronous focus callback cancellation")
	before = port.opened.size()
	app.contacts_panel.rows[0].grab_focus()
	app.contacts_panel.rows[1].focus_entered.connect(func():
		app.contacts_panel.rows[0].grab_focus()
		app.contacts_panel.rows[1].grab_focus(), CONNECT_ONE_SHOT)
	_touch(0, true, p)
	_touch(0, false, p)
	await _frames()
	_check(port.opened.size() == before, "focus-away-and-back callback also retires the old touch")
	await _tap()
	_check(port.opened.size() == before + 1, "fresh tap follows focus-only cancellation")
	before = port.opened.size()
	_mouse(true, p)
	_mouse(false, p)
	await _frames()
	_check(port.opened.size() == before + 1, "ordinary pointer click remains one open")
	for device: String in ["keyboard", "controller"]:
		before = port.opened.size()
		app.contacts_panel.rows[2].grab_focus()
		for pressed: bool in [true, false]:
			var event: InputEvent
			if device == "keyboard":
				event = InputEventKey.new()
				event.keycode = KEY_ENTER
				event.physical_keycode = KEY_ENTER
			else:
				event = InputEventJoypadButton.new()
				event.button_index = JOY_BUTTON_A
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await _frames()
		_check(port.opened.size() == before + 1, device + " Accept remains one open")
	_check(port.replies == 0, "inspection and navigation never issue a reply")
	app.contacts_panel.rows[0].grab_focus()
	for pressed: bool in [true, false]:
		var back := InputEventKey.new()
		back.keycode = KEY_ESCAPE
		back.physical_keycode = KEY_ESCAPE
		back.pressed = pressed
		Input.parse_input_event(back)
		Input.flush_buffered_events()
	await _frames()
	_check(not app.is_visible_in_tree(), "keyboard Back still hides Contacts")
	app.queue_free()
	await _frames()
	print("CONTACTS_TOUCH_PROBE_%s checks=%d failures=%d opens=%d" % [
		"VERIFIED" if failures.is_empty() else "FAILED", checks, failures.size(), port.opened.size()])
	quit(0 if failures.is_empty() else 1)
