extends DialogicNode_DialogText
## Native action registration delegates all admission and advancement to the input owner.

var accept_action_provider: Callable
var ending_publication_observer: Callable

func _notification(what: int) -> void:
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
	if not accept_action_provider.is_valid():
		if ending_publication_observer.is_valid():
			ending_publication_observer.call("caption_accessibility", {
				"node_id": get_instance_id(), "provider_valid": false, "element_read": false})
		return
	var element := get_accessibility_element()
	var published_name := ""
	if element.is_valid():
		# RichTextLabel's generic container may be omitted by native AT adapters.
		# Keep its text children, while exposing this activatable root explicitly.
		DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_BUTTON)
		published_name = get_parsed_text()
		DisplayServer.accessibility_update_set_name(element, published_name)
		DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK,
			accept_action_provider.call(self))
	if ending_publication_observer.is_valid():
		ending_publication_observer.call("caption_accessibility", {
			"node_id": get_instance_id(), "provider_valid": true, "element_read": true,
			"element_id": element.get_id(), "element_valid": element.is_valid(),
			"name_written": published_name if element.is_valid() else null,
			"role_written": "button" if element.is_valid() else null})
