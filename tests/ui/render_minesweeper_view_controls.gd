extends SceneTree
## Public board fixtures at the four view-control states used for visual acceptance.

const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/minesweeper_view_controls")
	DirAccess.make_dir_recursive_absolute(folder)
	var samples := [
		["expert-manual36-en100", "expert", "en", 100, false, false, 36],
		["expert-fit-en100", "expert", "en", 100, false, true, 36],
		["expert-manual36-hk150-large", "expert", "zh-HK", 150, true, false, 36],
		["beginner-manual60-en100", "beginner", "en", 100, false, false, 60],
	]
	for sample: Array in samples:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.color = Color("30343d")
		background.size = viewport.size
		viewport.add_child(background)
		var panel: Control = PANEL.new()
		viewport.add_child(panel)
		panel.position = Vector2(64, 32)
		var tier: String = sample[1]
		var view := {"board": QUERY.desktop(STATE.new().capture(), tier, true).value,
			"register": {"difficulty": tier, "rounds": 2, "mine_estimate": null,
				"foresight": null, "no_flag": "intact", "custody": false, "difficulty_enabled": []},
			"assignments": [true, false, false, false, false, false, false, false, false],
			"actions": ["reveal", "flag", "drag", "assignments", "rules"], "settled": false}
		if not panel.configure(sample[2], sample[3], sample[4]) or not panel.present(view):
			push_error("View-control render fixture rejected: " + sample[0])
			quit(1)
			return
		if sample[5] and not panel.worksheet.set_always_fit(true):
			quit(1)
			return
		if sample[6] == 60 and not panel.worksheet.step_zoom(12):
			quit(1)
			return
		panel.worksheet.grid.grab_focus()
		for frame in 5: await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var file: String = folder.path_join(sample[0] + ".png")
		if image == null or image.is_empty() or image.save_png(file) != OK:
			quit(1)
			return
		print("VIEW_CONTROLS_CAPTURE ", file, " size=", panel.worksheet.cell_size,
			" fit=", panel.worksheet.always_fit, " scroll=", panel.worksheet.get_scroll())
		root.remove_child(viewport)
		viewport.queue_free()
	print("VIEW_CONTROLS_RENDER_VERIFIED samples=4")
	quit(0)
