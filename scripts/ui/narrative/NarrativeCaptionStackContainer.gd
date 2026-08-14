extends Container
class_name NarrativeCaptionStackContainer

@export var separation: float = 8.0

func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	var visible_count := 0
	for child in get_children():
		if child is Control and (child as Control).visible:
			var minimum := (child as Control).get_combined_minimum_size()
			result.x = maxf(result.x, minimum.x)
			result.y += minimum.y
			visible_count += 1
	if visible_count > 1:
		result.y += separation * float(visible_count - 1)
	return result

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var bottom := size.y
	for child in get_children():
		if not child is Control or not (child as Control).visible:
			continue
		var control := child as Control
		var height := control.get_combined_minimum_size().y
		fit_child_in_rect(control, Rect2(0.0, bottom - height, size.x, height))
		bottom -= height + separation
