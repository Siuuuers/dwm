extends Control
## Keep the frozen composition drawn while a reading recovery owns inspection.
## Keep RecoveryLayer before this node: Godot 4.6's Windows accessibility tree
## can omit later siblings of this hidden container. Its CanvasLayer controls draw order.

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
