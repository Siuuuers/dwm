extends SceneTree

const GUARD := preload("res://tools/config/ProjectConfigGuard.gd")

func _init() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		printerr("PROJECT_CONFIG_ARGUMENT_UNKNOWN")
		quit(2)
		return
	var result: Dictionary = GUARD.new().inspect_file("res://project.godot")
	if not result.ok:
		printerr(JSON.stringify(result.errors))
		quit(1)
		return
	print("PROJECT_CONFIG: PASS config_version=5 count=%d" % result.canonical_count)
	quit(0)
