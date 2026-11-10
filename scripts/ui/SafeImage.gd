class_name SafeImage
extends Control
@export var category: String = ""
@export var asset_id: String = ""
func set_image(_path: String) -> void: pass
func show_placeholder() -> void: pass
func get_missing_art_report() -> Dictionary: return {}
