extends Node
signal preference_changed(path: StringName, value: Variant)
var percent := 100
var large := false
func get_preference(path: StringName, fallback: Variant = null) -> Variant:
	if path == &"preferences.accessibility.text_size": return percent
	if path == &"preferences.accessibility.large_targets": return large
	return fallback
func present(size_percent: int, large_targets: bool) -> void:
	percent = size_percent
	large = large_targets
	preference_changed.emit(&"preferences.accessibility.text_size",percent)
	preference_changed.emit(&"preferences.accessibility.large_targets",large)
