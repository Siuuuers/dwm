extends RefCounted


static func freeze(value: Variant) -> void:
	if value is Dictionary:
		if value.is_read_only(): return
		for key: Variant in value: freeze(value[key])
		value.make_read_only()
	elif value is Array:
		if value.is_read_only(): return
		for child: Variant in value: freeze(child)
		value.make_read_only()
