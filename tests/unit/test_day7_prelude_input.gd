extends GutTest
## Real controls and the real contact ledger; no programmatic Button.pressed admission.
const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const INPUT_OWNER := preload("res://autoload/InputManager.gd")
const HANDLE := {"generation": 1, "handle_id": "day7-input-fixture", "holder": &"day7_fixture", "reason": &"universal_pause"}

class ReceiptOwner extends RefCounted:
	var calls: Array[Dictionary] = []
	var advances: Array[Dictionary] = []
	var succeed := true
	var preparations := 0
	func acknowledge(receipt: Dictionary) -> Dictionary:
		calls.append(receipt.duplicate(true))
		return {"ok": succeed, "code": &"ok" if succeed else &"write_failed"}
	func advance(receipt: Dictionary) -> void:
		advances.append(receipt.duplicate(true))
	func prepare() -> Dictionary:
		preparations += 1
		return {"ok": false, "code": &"fixture_preparation_failed"}

var _viewport: SubViewport
var _manager: Node
var _surface: Node
var _owner: ReceiptOwner
var _old_process_mode: int
var _old_accept: Array[InputEvent] = []

func before_each() -> void:
	_old_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_old_accept.assign(InputMap.action_get_events(&"ui_accept"))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	InputMap.action_add_event(&"ui_accept", key)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"ui_accept", joy)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_viewport)
	_manager = INPUT_OWNER.new()
	_viewport.add_child(_manager)
	_owner = ReceiptOwner.new()

func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(_viewport): _viewport.free()
	Input.action_release(&"ui_accept")
	InputMap.action_erase_events(&"ui_accept")
	for event: InputEvent in _old_accept: InputMap.action_add_event(&"ui_accept", event)
	process_mode = _old_process_mode

func _card(token: String = "first", long_body: bool = false) -> Dictionary:
	return {"title": "Day 7 remembered detail", "body": "The complete remembered line.\n".repeat(90 if long_body else 1),
		"receipt": {"entry_id": "echo.fallback.day7", "view_token": token}}

func _frames(count: int = 3) -> void:
	for frame: int in count: await get_tree().process_frame

func _mount(waiting: bool = false, long_body: bool = false) -> void:
	_surface = SURFACE.new()
	if waiting: assert_true(_surface.configure_waiting(_owner.prepare, _owner.acknowledge).ok)
	else: assert_true(_surface.configure(_card("first", long_body), _owner.acknowledge).ok)
	assert_true(_surface.use_presentation_receipts().ok)
	assert_true(_surface.bind_input_custody(_manager))
	_surface.advance_requested.connect(_owner.advance)
	_viewport.add_child(_surface)
	await _settle_card()

func _settle_card() -> void:
	await _frames(4)
	await _wait_for_draw()
	await _frames(3)
	assert_true(_surface._next.has_focus(), "the admitted current action has native focus")

func _wait_for_draw() -> void:
	if _surface._card.is_empty(): return
	# Native runs require the real renderer. Only a headless run arranges its draw
	# precondition separately; Next and Retry still enter through the viewport.
	if DisplayServer.get_name() == "headless" and not _surface._drawn:
		_surface._current_body.draw.emit()
	for frame: int in 12:
		if _surface._drawn: break
		await get_tree().process_frame
	assert_true(_surface._drawn, "the current card is actually presented before physical input")

func _event(kind: String, down: bool, index: int = 0, position: Vector2 = Vector2(-1, -1)) -> InputEvent:
	if kind == "key":
		var key := InputEventKey.new()
		key.physical_keycode = KEY_ENTER
		key.keycode = KEY_ENTER
		key.pressed = down
		return key
	if kind == "joy":
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_A
		joy.pressed = down
		return joy
	if kind == "action":
		var action := InputEventAction.new()
		action.action = &"ui_accept"
		action.pressed = down
		return action
	var point := position
	if point.x < 0: point = _surface._next.get_global_rect().get_center()
	if kind == "touch":
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.position = point
		touch.pressed = down
		return touch
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = point
	mouse.global_position = point
	mouse.pressed = down
	return mouse

func _push(kind: String, down: bool, index: int = 0, point: Vector2 = Vector2(-1, -1)) -> void:
	_viewport.push_input(_event(kind, down, index, point), true)

func test_native_keyboard_gamepad_mouse_touch_and_mapped_action_activate_once() -> void:
	await _mount()
	for kind: String in ["key", "joy", "mouse", "touch", "action"]:
		var expected := _owner.advances.size() + 1
		_push(kind, true)
		assert_eq(_owner.advances.size(), expected - 1, kind + ": press alone does not navigate")
		_push(kind, false)
		assert_eq(_owner.advances.size(), expected, kind + ": native release activates exactly once")
		_push(kind, false)
		assert_eq(_owner.advances.size(), expected, kind + ": duplicate release has no effect")
		assert_true(_surface.present_card(_card("after-" + kind)).ok)
		await _settle_card()

func test_held_contact_cannot_navigate_replacement_and_fresh_contact_can() -> void:
	await _mount()
	for kind: String in ["key", "joy", "mouse", "touch", "action"]:
		var previous := _owner.advances.size()
		_push(kind, true)
		assert_true(_surface.present_card(_card("replacement-" + kind)).ok)
		await _frames(4)
		await _wait_for_draw()
		await _frames(3)
		_push(kind, false)
		assert_eq(_owner.advances.size(), previous, kind + ": an old press cannot accept the replacement")
		await _frames()
		_push(kind, true)
		_push(kind, false)
		assert_eq(_owner.advances.size(), previous + 1, kind + ": neutral then fresh works")

func test_canceled_dragged_outside_and_multitouch_release_do_not_activate() -> void:
	await _mount()
	_push("touch", true)
	var canceled := _event("touch", false) as InputEventScreenTouch
	canceled.canceled = true
	_viewport.push_input(canceled, true)
	assert_eq(_owner.advances.size(), 0, "canceled touch is not a click")
	await _frames()
	_push("touch", true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _surface._next.get_global_rect().get_center() + Vector2(9, 0)
	drag.relative = Vector2(9, 0)
	_viewport.push_input(drag, true)
	_push("touch", false)
	assert_eq(_owner.advances.size(), 0, "drag beyond 8 px cancels even when release returns")
	await _frames()
	_push("touch", true)
	_push("touch", false, 0, Vector2(2, 2))
	assert_eq(_owner.advances.size(), 0, "release outside original button cancels")
	await _frames()
	_push("touch", true)
	_push("touch", true, 1, Vector2(2, 2))
	_push("touch", false, 1, Vector2(2, 2))
	_push("touch", false)
	assert_eq(_owner.advances.size(), 0, "second finger outside the button retires both contacts")
	await _frames()
	_push("touch", true)
	_push("touch", false)
	assert_eq(_owner.advances.size(), 1, "all-up rearms a fresh short tap")

func test_emulated_mouse_does_not_duplicate_touch_or_revive_canceled_touch() -> void:
	await _mount()
	_push("touch", true)
	for down: bool in [true, false]:
		var emulated := _event("mouse", down)
		emulated.device = InputEvent.DEVICE_ID_EMULATION
		_viewport.push_input(emulated, true)
	assert_eq(_owner.advances.size(), 0, "emulation cannot consume a still-held real touch")
	_push("touch", false)
	for down: bool in [true, false]:
		var emulated := _event("mouse", down)
		emulated.device = InputEvent.DEVICE_ID_EMULATION
		_viewport.push_input(emulated, true)
	assert_eq(_owner.advances.size(), 1, "one physical tap has one navigation effect")

func test_pause_preserves_exact_card_scroll_focus_and_quarantines_held_confirm() -> void:
	await _mount(false, true)
	_surface._scroll.scroll_vertical = 120
	var projection: Dictionary = _surface.get_pause_projection()
	var history: Array = _surface.get_presentation_history()
	var calls := _owner.calls.size()
	_push("joy", true)
	var captured: Dictionary = _surface.capture_pause_view({"day7_prelude": projection})
	assert_true(captured.ok)
	assert_true(_manager.begin_suspend(HANDLE).ok)
	assert_true(_surface.cover_pause_view(captured.value))
	assert_true(_surface.cover_pause_view(captured.value.duplicate(true)), "retrying the exact cover is idempotent")
	var altered: Dictionary = captured.value.duplicate(true)
	altered.capture_id += 1
	assert_false(_surface.cover_pause_view(altered), "a different anchor cannot cover an already covered source")
	get_tree().paused = true
	assert_false(_surface.visible)
	assert_eq(_surface.get_pause_projection(), projection, "covered projection retains exact witnessed identity")
	assert_true(_surface.restore_pause_view(captured.value))
	get_tree().paused = false
	assert_true(_manager.resume(HANDLE).ok)
	_push("joy", false)
	assert_eq(_owner.advances.size(), 0, "same-frame Continue release never advances the underlying card")
	await _frames(4)
	assert_true(_surface._next.has_focus(), "focus returns after source admission and physical neutral")
	assert_eq(_surface._scroll.scroll_vertical, 120)
	assert_eq(_surface.get_presentation_history(), history)
	assert_eq(_owner.calls.size(), calls, "Pause restore does not redraw a new semantic receipt or save")
	assert_false(_surface.restore_pause_view(captured.value), "an anchor cannot restore twice")
	_push("joy", true)
	_push("joy", false)
	assert_eq(_owner.advances.size(), 1)

func test_focus_visibility_binding_changes_and_foreground_loss_retire_pending_input() -> void:
	await _mount()
	for boundary: String in ["focus", "visibility", "bindings", "foreground"]:
		_push("key", true)
		match boundary:
			"focus":
				_surface._next.release_focus()
				_surface._next.grab_focus()
			"visibility":
				_surface.hide()
				_surface.show()
			"bindings": _manager.input_bindings_changed.emit()
			"foreground":
				_surface.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
				_surface.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		_push("key", false)
		assert_eq(_owner.advances.size(), 0, boundary + ": old input remains retired after synchronous restoration")
		await _frames()
		_surface._next.grab_focus()
	_push("key", true)
	_push("key", false)
	assert_eq(_owner.advances.size(), 1)

func test_focus_callback_hide_and_reopen_cannot_revive_the_press_being_delivered() -> void:
	await _mount()
	var other := Button.new()
	other.size = Vector2(60, 24)
	_viewport.add_child(other)
	other.grab_focus()
	await _frames()
	_surface._next.focus_entered.connect(func() -> void:
		_surface.hide()
		_surface.show(), CONNECT_ONE_SHOT)
	_push("touch", true)
	_push("touch", false)
	assert_eq(_owner.advances.size(), 0, "a pre-GUI focus observer can retire this exact press")
	await _frames()
	_push("touch", true)
	_push("touch", false)
	assert_eq(_owner.advances.size(), 1)

func test_save_retry_uses_exact_receipt_then_next_requires_another_fresh_input() -> void:
	_owner.succeed = false
	await _mount()
	assert_eq(_owner.calls, [_card().receipt])
	assert_false(_surface.get_pause_projection().acknowledged)
	_owner.succeed = true
	_push("touch", true)
	_push("touch", false)
	assert_eq(_owner.calls, [_card().receipt, _card().receipt])
	assert_eq(_owner.advances.size(), 0, "Retry changes to Next without spending the same contact twice")
	_push("touch", false)
	assert_eq(_owner.advances.size(), 0)
	await _frames()
	_push("key", true)
	_push("key", false)
	assert_eq(_owner.advances.size(), 1)

func test_preparation_retry_has_pause_projection_without_fabricated_receipt() -> void:
	await _mount(true)
	var projection: Dictionary = _surface.get_pause_projection()
	assert_eq(projection.receipt, {})
	assert_false(projection.acknowledged)
	var captured: Dictionary = _surface.capture_pause_view({"day7_prelude": projection})
	assert_true(captured.ok)
	assert_true(_surface.cover_pause_view(captured.value))
	assert_true(_surface.restore_pause_view(captured.value))
	await _frames()
	_push("mouse", true)
	_push("mouse", false)
	assert_eq(_owner.preparations, 1)
	assert_eq(_owner.calls, [])
	assert_eq(_surface.get_presentation_history(), [])

func test_page_keys_and_shoulders_expose_long_body_without_consuming_next() -> void:
	await _mount(false, true)
	var calls := _owner.calls.size()
	var page := InputEventKey.new()
	page.keycode = KEY_PAGEDOWN
	page.physical_keycode = KEY_PAGEDOWN
	page.pressed = true
	_viewport.push_input(page, true)
	assert_gt(_surface._scroll.scroll_vertical, 0, "Page Down reads the overflowing body")
	page.pressed = false
	_viewport.push_input(page, true)
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	_viewport.push_input(shoulder, true)
	assert_eq(_surface._scroll.scroll_vertical, 0, "left shoulder pages back to the beginning")
	shoulder.pressed = false
	_viewport.push_input(shoulder, true)
	assert_eq(_owner.calls.size(), calls)
	assert_eq(_owner.advances.size(), 0)

func test_lost_bound_input_owner_stays_fail_closed_for_native_buttons() -> void:
	await _mount()
	var calls := _owner.calls.size()
	_manager.free()
	for kind: String in ["key", "joy", "mouse", "touch", "action"]:
		_push(kind, true)
		_push(kind, false)
	assert_eq(_owner.advances, [], "loss of the explicit dependency cannot re-enable standalone Button admission")
	assert_eq(_owner.calls.size(), calls)
	assert_true(_surface.is_card_acknowledged(_card().receipt), "the already witnessed card remains intact")

func test_pause_with_no_captured_focus_discards_pending_initial_auto_focus() -> void:
	# A physical contact predates this mount. The rendered card queues initial Next
	# focus, but the real InputManager's held-contact ledger keeps it unassigned.
	_push("key", true)
	_surface = SURFACE.new()
	assert_true(_surface.configure(_card(), _owner.acknowledge).ok)
	assert_true(_surface.use_presentation_receipts().ok)
	assert_true(_surface.bind_input_custody(_manager))
	_surface.advance_requested.connect(_owner.advance)
	_viewport.add_child(_surface)
	await _frames(4)
	await _wait_for_draw()
	await _frames(3)
	assert_null(_viewport.gui_get_focus_owner(), "there is genuinely no focus at capture")
	assert_eq(_surface._focus_pending, _surface._next, "the initial deferred Next focus is actually pending")
	var projection: Dictionary = _surface.get_pause_projection()
	var captured: Dictionary = _surface.capture_pause_view({"day7_prelude": projection})
	assert_true(captured.ok)
	assert_eq(captured.value.focus, NodePath())
	var history: Array = _surface.get_presentation_history()
	var calls := _owner.calls.size()
	assert_true(_manager.begin_suspend(HANDLE).ok)
	assert_true(_surface.cover_pause_view(captured.value))
	get_tree().paused = true
	_push("key", false)
	assert_null(_surface._focus_pending, "cover discards the old automatic focus intent")
	assert_true(_surface.restore_pause_view(captured.value))
	get_tree().paused = false
	assert_true(_manager.resume(HANDLE).ok)
	await _frames(4)
	assert_null(_viewport.gui_get_focus_owner(), "Continue restores the captured absence of focus")
	assert_null(_surface._focus_pending)
	assert_eq(_surface.get_pause_projection(), projection)
	assert_eq(_surface.get_presentation_history(), history)
	assert_eq(_owner.calls.size(), calls)
	assert_eq(_owner.advances, [])
