extends GutTest
## Unit boundary coverage for the callback registered with DisplayServer. The separate
## Windows UI Automation journey proves native accessibility provenance.

const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")
const INPUT_OWNER := preload("res://autoload/InputManager.gd")
const PAUSE_HANDLE := {"generation": 1, "handle_id": "day7-accessibility-fixture",
	"holder": &"day7_accessibility_fixture", "reason": &"universal_pause"}

class ReceiptOwner extends RefCounted:
	var calls: Array[Dictionary] = []
	var acknowledgments: Array[Dictionary] = []
	var advances: Array[Dictionary] = []
	var succeed := true

	func acknowledge(receipt: Dictionary) -> Dictionary:
		calls.append(receipt.duplicate(true))
		return {"ok": succeed, "code": &"ok" if succeed else &"write_failed"}

	func acknowledged(receipt: Dictionary, _result: Dictionary) -> void:
		acknowledgments.append(receipt.duplicate(true))

	func advance(receipt: Dictionary) -> void:
		advances.append(receipt.duplicate(true))

var _viewport: SubViewport
var _manager: Node
var _surface: Node
var _owner: ReceiptOwner
var _old_process_mode: int

func before_each() -> void:
	_old_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	process_mode = _old_process_mode

func _card(token: String = "first") -> Dictionary:
	return {"title": "Day 7 remembered detail", "body": "The complete remembered line.",
		"receipt": {"entry_id": "echo.fallback.day7", "view_token": token}}

func _frames(count: int = 3) -> void:
	for frame: int in count: await get_tree().process_frame

func _mount(presentation_receipts: bool = true, bind_custody: bool = true) -> void:
	_surface = SURFACE.new()
	assert_true(_surface.configure(_card(), _owner.acknowledge).ok)
	if presentation_receipts: assert_true(_surface.use_presentation_receipts().ok)
	if bind_custody: assert_true(_surface.bind_input_custody(_manager))
	_surface.card_acknowledged.connect(_owner.acknowledged)
	_surface.advance_requested.connect(_owner.advance)
	_viewport.add_child(_surface)
	await _settle_card()

func _settle_card() -> void:
	await _frames(4)
	# Native runs require the renderer. Headless runs arrange the same draw boundary
	# explicitly; neither path fabricates acknowledgment or navigation.
	if DisplayServer.get_name() == "headless" and not _surface._drawn:
		_surface._current_body.draw.emit()
	for frame: int in 12:
		if _surface._drawn: break
		await get_tree().process_frame
	assert_true(_surface._drawn, "the current card is presented before an accessibility action")
	await _frames(3)

func _accessibility_click(generation: int) -> void:
	# This invokes the exact Callable registered as ACTION_CLICK. It proves the
	# application boundary only; native Windows registration is covered elsewhere.
	_surface._next._on_accessibility_click({}, generation)

func _push_held_non_action_key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.physical_keycode = KEY_B
	event.pressed = down
	_viewport.push_input(event, true)

func test_current_action_advances_once_and_cannot_cross_a_replacement_generation() -> void:
	await _mount()
	var receipt: Dictionary = _card().receipt
	assert_eq(_owner.calls, [receipt], "presentation records the one real acknowledgment")
	assert_eq(_owner.acknowledgments, [receipt])
	var generation: int = _surface._next._generation
	_accessibility_click(generation)
	assert_eq(_owner.advances, [receipt], "accessible Next emits the exact current receipt once")
	_accessibility_click(generation)
	assert_eq(_owner.advances, [receipt], "the same queued action is stale after navigation retires input")
	assert_eq(_owner.calls, [receipt], "Next does not acknowledge the already witnessed card again")

	var old_generation: int = _surface._next._generation
	var replacement := _card("replacement")
	assert_true(_surface.present_card(replacement).ok)
	await _settle_card()
	assert_eq(_owner.calls, [_card().receipt, replacement.receipt])
	_accessibility_click(old_generation)
	assert_eq(_owner.advances, [receipt], "the old registered callback cannot act on the replacement")
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances, [receipt, replacement.receipt], "a current callback advances only the replacement")

func test_focus_pause_cover_and_held_contacts_reject_actions_until_a_fresh_admitted_call() -> void:
	await _mount()
	_surface.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames()
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances, [], "a current-generation callback still fails while the app lacks focus")
	_surface.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames()
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances, [_card().receipt], "focus return admits a fresh accessibility action")

	var paused_card := _card("after-pause")
	assert_true(_surface.present_card(paused_card).ok)
	await _settle_card()
	var projection: Dictionary = _surface.get_pause_projection()
	var captured: Dictionary = _surface.capture_pause_view({"day7_prelude": projection})
	assert_true(captured.ok)
	assert_true(_surface.cover_pause_view(captured.value))
	await _frames()
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances.size(), 1, "a covered view rejects its current callback")
	get_tree().paused = true
	assert_true(_surface.restore_pause_view(captured.value))
	await _frames()
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances.size(), 1, "a restored view remains inert while the tree is paused")
	get_tree().paused = false
	assert_true(_manager.begin_suspend(PAUSE_HANDLE).ok)
	await _frames()
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances.size(), 1, "source suspension independently rejects accessibility actions")
	assert_true(_manager.resume(PAUSE_HANDLE).ok)
	await _frames()
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances, [_card().receipt, paused_card.receipt],
		"Continue admits one fresh action after source custody returns")

	var contact_card := _card("after-held-contact")
	assert_true(_surface.present_card(contact_card).ok)
	await _settle_card()
	_push_held_non_action_key(true)
	assert_false(_manager.get_physical_contacts().is_empty(), "fixture owns a real held physical contact")
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances.size(), 2, "accessibility cannot bypass a held physical contact")
	_push_held_non_action_key(false)
	await _frames()
	assert_true(_manager.get_physical_contacts().is_empty())
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.advances, [_card().receipt, paused_card.receipt, contact_card.receipt],
		"physical neutral admits one fresh accessibility action")

func test_failed_receipt_retry_requires_a_fresh_action_and_never_duplicates_acknowledgment() -> void:
	_owner.succeed = false
	await _mount()
	var receipt: Dictionary = _card().receipt
	assert_eq(_owner.calls, [receipt])
	assert_eq(_owner.acknowledgments, [])
	var failed_generation: int = _surface._next._generation
	_accessibility_click(failed_generation)
	assert_eq(_owner.calls, [receipt, receipt], "one accessibility action retries the exact failed receipt")
	_accessibility_click(failed_generation)
	assert_eq(_owner.calls, [receipt, receipt], "the queued duplicate cannot retry again")
	_owner.succeed = true
	await _frames()
	var retry_generation: int = _surface._next._generation
	_accessibility_click(retry_generation)
	assert_eq(_owner.calls, [receipt, receipt, receipt])
	assert_eq(_owner.acknowledgments, [receipt], "only the successful durable retry acknowledges the card")
	_accessibility_click(retry_generation)
	assert_eq(_owner.calls.size(), 3, "the successful retry also retires its action generation")
	assert_eq(_owner.advances, [], "Retry never spends the same action as Next")

func test_unbound_gallery_surface_retains_its_native_pressed_contract() -> void:
	await _mount(false, false)
	var receipt: Dictionary = _card().receipt
	_accessibility_click(_surface._next._generation)
	assert_eq(_owner.calls, [], "the Day 7 accessibility route stays closed without explicit custody")
	_surface._next.pressed.emit()
	assert_eq(_owner.calls, [receipt], "Gallery still acknowledges through its native Button signal")
	assert_eq(_owner.acknowledgments, [receipt])
	_surface._next.pressed.emit()
	assert_eq(_owner.calls, [receipt], "an already accepted Gallery card is not acknowledged twice")
