extends DialogicNode_DialogText
## Native action registration delegates all admission and advancement to the input owner.

var accept_action_provider: Callable

func _notification(what: int) -> void:
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE or not accept_action_provider.is_valid(): return
	var element := get_accessibility_element()
	if element.is_valid():
		# RichTextLabel's generic container may be omitted by native AT adapters.
		# Keep its text children, while exposing this activatable root explicitly.
		DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_BUTTON)
		DisplayServer.accessibility_update_set_name(element, get_parsed_text())
		DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK,
			accept_action_provider.call(self))
