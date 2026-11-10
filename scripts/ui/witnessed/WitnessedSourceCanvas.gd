extends Control

var accessibility_withdrawn := false:
	set(value):
		if accessibility_withdrawn == value: return
		accessibility_withdrawn = value
		queue_accessibility_update()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		var element := get_accessibility_element()
		if element.is_valid():
			DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_HIDDEN,
				accessibility_withdrawn or not is_visible_in_tree())
