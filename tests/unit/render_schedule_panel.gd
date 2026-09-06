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
	]:
		var panel := PANEL.new()
		viewport.add_child(panel)
		panel.configure(sample.locale,sample.percent,sample.large)
		panel.set_done_enabled(true)
		var names: Array = ["Training","Working","Rest"] if sample.locale == "en" else ["训练","工作","休息"]
		var sources: Array = []
		var entries: Array = []
		if not sample.day7:
			for i in 3:
				sources.append({"id":str(i),"name":names[i],"available":true,"compact":art.compact,"folio":art.folio})
				entries.append({"id":str(i),"source_id":str(i),"name":names[i],"folio":art.folio})
		if not panel.set_projection({"day_seven":sample.day7,"sources":sources,"entries":entries},"1"):
			push_error("render projection refused")
			quit(1)
			return
		await process_frame
		await process_frame
		panel.focus_target("entry:1")
		for frame in 5: await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		if pixels == null or pixels.is_empty() or pixels.save_png("res://.godot/phase2r_logs/"+sample.file) != OK:
			push_error("render capture failed")
			quit(1)
			return
		print("CAPTURE ",sample.file," ",pixels.get_size())
		viewport.remove_child(panel)
		panel.queue_free()
	quit(0)
