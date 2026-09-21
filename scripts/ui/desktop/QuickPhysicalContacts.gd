extends RefCounted
## A bound modifier chord is one activation; unrelated held contacts retain custody.

static func only_activation(input_owner: Object, event: InputEvent, contacts: Dictionary, activation: String) -> bool:
	var allowed := {activation: true}
	if event is InputEventKey:
		var codes: Array[int] = []
		if event.shift_pressed: codes.append(KEY_SHIFT)
		if event.ctrl_pressed: codes.append(KEY_CTRL)
		if event.alt_pressed: codes.append(KEY_ALT)
		if event.meta_pressed: codes.append(KEY_META)
		for code: int in codes:
			var modifier := InputEventKey.new()
			modifier.device = event.device
			modifier.physical_keycode = code
			allowed[input_owner.get_physical_contact_id(modifier)] = true
	for contact: String in contacts:
		if not allowed.has(contact): return false
	return contacts.has(activation)
