extends "res://scripts/ui/desktop/DesktopConfirmation.gd"
## Price-only Shop consent, reusing the existing modal input/focus custody.

var attempt_purchase: Callable
var failure_text := ""
var retry_text := ""
var _price_body: Label

func _ready() -> void:
	super._ready()
	accessibility_name = str(request.get("dialog_name", ""))
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_price_body = body_scroll.get_child(0) as Label
	_price_body.text = str(request.title)
	_price_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_button.accessibility_description = _price_body.text
	confirm_button.accessibility_description = _price_body.text

func _finish(accepted: bool) -> void:
	if _settled: return
	if accepted:
		get_viewport().set_input_as_handled()
		var result: Dictionary = attempt_purchase.call()
		if not is_inside_tree():
			# A completed purchase may hand physical custody to Hospital or an ending.
			_settled = true
			_restore_custody()
			queue_free()
			return
		if not result.get("ok", false):
			_cancelable = not result.get("retained_purchase", false)
			_price_body.text = str(request.title) + "\n\n" + (failure_text if _cancelable else retry_text)
			cancel_button.visible = _cancelable
			cancel_button.disabled = not _cancelable
			cancel_button.focus_mode = Control.FOCUS_ALL if _cancelable else Control.FOCUS_NONE
			var other: Button = cancel_button if _cancelable else confirm_button
			confirm_button.focus_previous = confirm_button.get_path_to(other)
			confirm_button.focus_next = confirm_button.get_path_to(other)
			confirm_button.focus_neighbor_left = confirm_button.get_path_to(other)
			confirm_button.accessibility_description = _price_body.text
			confirm_button.set_pressed_no_signal(false)
			confirm_button.grab_focus()
			invalidate_pending_input()
			return
	super._finish(accepted)

func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		var element := get_accessibility_element()
		if element.is_valid():
			DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_DIALOG)
			DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_MODAL, true)
