extends GridContainer
## The existing visible index is one single-selection accessibility list.

func _notification(what: int) -> void:
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
	var element := get_accessibility_element()
	if not element.is_valid(): return
	DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_LIST_BOX)
	DisplayServer.accessibility_update_set_name(element, "")
	DisplayServer.accessibility_update_set_list_orientation(element, true)
