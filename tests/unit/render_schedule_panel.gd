extends SceneTree
const PANEL := preload("res://scripts/ui/schedule/SchedulePanel.gd")
const ART := preload("res://scripts/ui/schedule/ScheduleArtRegistry.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var loaded := REGISTRY.load_current()
	var art := ART.resolve(loaded.value.registry,"training",loaded.value.registry_fingerprint).value as Dictionary
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,656)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	for sample: Dictionary in [
		{"locale":"en","percent":100,"large":false,"day7":false,"file":"schedule-en100.png"},
		{"locale":"zh-CN","percent":150,"large":true,"day7":false,"file":"schedule-cn150-large.png"},
		{"locale":"en","percent":100,"large":false,"day7":true,"file":"schedule-day7-empty.png"},
		{"locale":"en","percent":100,"large":false,"day7":false,"focus":"source:0","selected":"0","unavailable":true,"file":"schedule-paper-focus.png"},
		{"locale":"en","percent":100,"large":false,"day7":false,"palette":&"midnight","focus":"source:0","selected":"0","unavailable":true,"file":"schedule-midnight-focus.png"},
		{"locale":"zh-HK","percent":150,"large":true,"day7":false,"palette":&"midnight","focus":"remove","file":"schedule-midnight-hk150.png"},
		{"locale":"en","percent":100,"large":false,"day7":false,"focus":"entry:0","selected":"0","file":"schedule-first-entry-focus.png"},
		{"locale":"en","percent":100,"large":false,"day7":false,"status":true,"file":"schedule-status-en100.png"},
		{"locale":"zh-HK","percent":150,"large":true,"day7":false,"palette":&"midnight","status":true,"file":"schedule-status-hk150.png"},
	]:
		var panel := PANEL.new()
		viewport.add_child(panel)
		panel.configure(sample.locale,sample.percent,sample.large,sample.get("palette",&"after_hours"))
		panel.set_done_enabled(true)
		var names: Array = ["Training","Working","Rest"] if sample.locale == "en" else ["训练","工作","休息"]
		if sample.locale == "zh-HK": names = ["訓練","工作","休息"]
		var sources: Array = []
		var entries: Array = []
		if not sample.day7:
			for i in 3:
				sources.append({"id":str(i),"name":names[i],"available":not (i == 2 and sample.get("unavailable",false)),"compact":art.compact,"folio":art.folio})
				entries.append({"id":str(i),"source_id":str(i),"name":names[i],"folio":art.folio})
		if not panel.set_projection({"day_seven":sample.day7,"sources":sources,"entries":entries},sample.get("selected","1")):
			push_error("render projection refused")
			quit(1)
			return
		await process_frame
		await process_frame
		panel.focus_target(sample.get("focus","entry:1"))
		if sample.get("status",false): panel.set_refusal_status("fixture-refusal")
		for frame in 5: await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		if pixels == null or pixels.is_empty() or pixels.save_png("res://.godot/phase2r_logs/"+sample.file) != OK:
			push_error("render capture failed")
			quit(1)
			return
		if not sample.day7:
			var compact_ink := 0
			for py in range(104,152):
				for px in range(48,96):
					var pixel := pixels.get_pixel(px,py)
					if pixel.r < 0.275 and pixel.g < 0.275 and pixel.b < 0.275: compact_ink += 1
			if compact_ink != 256:
				push_error("First registered compact-art pixels missing in %s: %d" % [sample.file,compact_ink])
				quit(1)
				return
			print("FIRST_COMPACT_ART_VERIFIED ",sample.file," ",compact_ink)
		# These exact native rails lie outside the ScrollContainer aperture. A
		# clipped focus can pass all layout tests; prove the real rendered pixels.
		var rail_pixels: Array[Vector2i] = []
		if sample.file == "schedule-midnight-hk150.png": rail_pixels = [Vector2i(500,554),Vector2i(766,554)]
		elif sample.file == "schedule-first-entry-focus.png": rail_pixels = [Vector2i(296,24),Vector2i(480,24)]
		for point: Vector2i in rail_pixels:
			if pixels.get_pixelv(point).to_html(false) != panel.get_theme_color("habitat","Schedule").to_html(false):
				push_error("Detached focus pixel missing at %s in %s" % [point,sample.file])
				quit(1)
				return
		if not rail_pixels.is_empty(): print("DETACHED_FOCUS_VERIFIED ",sample.file," ",rail_pixels)
		print("CAPTURE ",sample.file," ",pixels.get_size())
		viewport.remove_child(panel)
		panel.queue_free()
	quit(0)
