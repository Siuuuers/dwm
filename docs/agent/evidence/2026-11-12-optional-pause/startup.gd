extends SceneTree

func _initialize() -> void:
	observe.call_deferred()

func observe() -> void:
	if OS.get_environment("DWM_STARTUP_AUDIT") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		quit(2)
		return
	var click_us := 0
	var title_us := 0
	var runtime_us := 0
	var first_ack_us := 0
	var prior := ""
	var last_us := Time.get_ticks_usec()
	var gap_us := 0
	var trace := []
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		var now := Time.get_ticks_usec()
		if click_us > 0: gap_us = maxi(gap_us, now-last_us)
		last_us = now
		var app := root.get_node_or_null("ApplicationBootstrap")
		var loader := root.get_node_or_null("StartupLoader")
		if app == null or loader == null:
			await process_frame
			continue
		var state: Dictionary = app.get_startup_state()
		if state.ready and runtime_us == 0:
			runtime_us = now
			if OS.get_environment("DWM_EARLY_COMPUTER") == "1": loader.set_process(false)
		var mark: String = str(loader._phase) + "|" + str(loader._active) + "|" + str(state.completed_stages.size())
		if mark != prior:
			trace.append({"us":now,"state":mark})
			prior = mark
		var menu := current_scene
		if is_instance_valid(menu) and menu.scene_file_path == "res://scenes/menu/MenuScene.tscn" and menu.is_node_ready() and title_us == 0:
			title_us = now
		if title_us > 0 and click_us == 0 and (OS.get_environment("DWM_CLICK_MODE") != "settled" or (state.ready and now - runtime_us >= 2000000)):
			click_us = now
			menu.get_node("%NewAccButton").pressed.emit()
		var bridge := root.get_node_or_null("DialogicBridge")
		if click_us > 0 and bridge != null and bridge.is_current_line_presentation_acknowledged():
			if first_ack_us == 0: first_ack_us = now
			var layer: Node = root.get_node("SceneRouter")._production_pause._find_caption(root)
			if layer != null and layer.is_node_ready() and layer.caption_text.is_visible_in_tree() and not layer.caption_text.revealing and bridge._runtime_adapter.is_current_line_complete() and not bridge._runtime_adapter._dialogic.get_subsystem("Inputs").is_input_blocked():
				if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
				print("FIRST_CAPTION ", JSON.stringify({"title_us":title_us,"click_us":click_us,"runtime_us":runtime_us,"ack_us":first_ack_us,"caption_us":Time.get_ticks_usec(),"largest_frame_gap_us":gap_us,"text":layer.caption_text.get_parsed_text(),"trace":trace}))
				var pause: Node = root.get_node("SceneRouter")._production_pause
				var before: String = layer.caption_text.get_parsed_text()
				var timings := {}
				for action in ["save", "settings", "settings_again"]:
					var started := Time.get_ticks_usec()
					var result: Dictionary = await pause.open_scene_backup("save") if action == "save" else await pause.open_scene_settings()
					timings[action] = Time.get_ticks_usec() - started
					assert(result.get("ok", false), str(result))
					if action == "save": assert(not pause.surface._hosts.has(&"settings"))
					else: assert(pause.surface._hosts[&"settings"].is_visible_in_tree())
					assert((await pause.request_continue()).get("ok", false))
					assert(layer.caption_text.get_parsed_text() == before)
				print("PAUSE_OPEN ", JSON.stringify(timings))
				var gallery_start := Time.get_ticks_usec()
				var passage: Dictionary = bridge.get_scene_passage("passage.umbrella")
				print("PASSAGE_LOOKUP ", JSON.stringify({"us":Time.get_ticks_usec()-gallery_start,"ok":passage.ok,"captions":passage.get("value",{}).get("captions",[]).size()}))
				await process_frame
				app.request_quit()
				return
		await process_frame
	push_error("FIRST_CAPTION_TIMEOUT")
	quit(1)
