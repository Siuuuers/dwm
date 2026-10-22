extends RichTextLabel
## Story text remains focusable for ordinary keyboard reading; activation belongs
## to the existing background Continue surface and WitnessedAcceptInput.

func _notification(what: int) -> void:
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
	var element := get_accessibility_element()
	if element.is_valid():
		DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_STATIC_TEXT)
		DisplayServer.accessibility_update_set_name(element, get_parsed_text())
