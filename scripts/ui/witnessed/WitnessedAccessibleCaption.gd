extends DialogicNode_DialogText
## Native action registration delegates all admission and advancement to the input owner.

var accept_action_provider: Callable

func _notification(what: int) -> void:
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE or not accept_action_provider.is_valid(): return
	var element := get_accessibility_element()
	if element.is_valid():
		DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK,
			accept_action_provider.call(self))
