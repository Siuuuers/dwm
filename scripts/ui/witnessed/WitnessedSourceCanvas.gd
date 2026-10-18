extends Control
## Keep the frozen composition drawn while a reading recovery owns inspection.
## Keep RecoveryLayer before this node: Godot 4.6's Windows accessibility tree
## can omit later siblings of this hidden container. Its CanvasLayer controls draw order.

var ending_publication_observer: Callable

var accessibility_withdrawn := false:
	set(value):
		if accessibility_withdrawn == value: return
		accessibility_withdrawn = value
		queue_accessibility_update()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		var element := get_accessibility_element()
		var hidden := false
		if element.is_valid():
			hidden = accessibility_withdrawn or not is_visible_in_tree()
			DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_HIDDEN,
				hidden)
		if ending_publication_observer.is_valid():
			ending_publication_observer.call("canvas_accessibility", {
				"node_id": get_instance_id(), "element_read": true,
				"element_id": element.get_id(), "element_valid": element.is_valid(),
				"hidden_written": hidden if element.is_valid() else null})
