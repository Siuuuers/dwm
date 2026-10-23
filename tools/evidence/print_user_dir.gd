extends SceneTree

func _init() -> void:
	print("PHASE2R_USER_DIR=" + ProjectSettings.globalize_path("user://"))
	quit(0)
