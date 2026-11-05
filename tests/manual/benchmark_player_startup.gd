extends SceneTree

func _initialize() -> void:
	observe.call_deferred()

func observe() -> void:
	if OS.get_environment("DWM_STARTUP_AUDIT") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		quit(2)
		return
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		var bootstrap: Node = root.get_node_or_null("ApplicationBootstrap")
		if bootstrap != null and bootstrap.get_startup_state().get("ready", false) and is_instance_valid(current_scene) and current_scene.is_node_ready():
			var button: Button = current_scene.get_node_or_null("%NewAccButton")
			if button != null and button.is_visible_in_tree() and not button.disabled:
				if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
				print("PLAYER_STARTUP " + JSON.stringify({"engine_ticks_us": Time.get_ticks_usec(), "display": DisplayServer.get_name(), "revision": OS.get_environment("DWM_BENCHMARK_REVISION")}))
				quit(0)
				return
		await process_frame
	quit(1)
