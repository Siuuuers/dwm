extends SceneTree
## Public composition fixtures. Real owner command integration is covered by the port suite.

const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/minesweeper_panel")
	DirAccess.make_dir_recursive_absolute(folder)
	var samples := [
		["panel-en100","en",100,false,&"after_hours",""],
		["panel-en150-large","en",150,true,&"midnight",""],
		["rules-cn125","zh-CN",125,false,&"midnight","rules"],
		["assignments-hk150-large","zh-HK",150,true,&"after_hours","assignments"],
	]
	for sample: Array in samples:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280,720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var panel: Control = PANEL.new()
		viewport.add_child(panel)
		panel.position = Vector2(64,32)
		var view := {"board":QUERY.desktop(STATE.new().capture(),"expert",true).value,
			"register":{"difficulty":"expert","rounds":2,"mine_estimate":null,"foresight":null,
				"no_flag":"intact","custody":false,"difficulty_enabled":[]},
			"assignments":[true,false,false,false,false,false,false,false,false],
			"actions":["reveal","flag","drag","assignments","rules"]}
		if not panel.configure(sample[1],sample[2],sample[3],sample[4]) or not panel.present(view):
			push_error("Panel rejected render sample: "+sample[0])
			quit(1)
			return
		panel.worksheet.grid.grab_focus()
		if sample[5] != "": panel.dock.buttons[sample[5]].pressed.emit()
		for frame in 4: await RenderingServer.frame_post_draw
		if panel.dock.position.y+panel.dock.size.y != 656:
			push_error("Panel bands do not close at 328 native pixels")
			quit(1)
			return
		if sample[5] != "" and panel.worksheet.information_sheet == null:
			push_error("Requested information sheet did not open")
			quit(1)
			return
		var file: String = folder.path_join(sample[0]+".png")
		if viewport.get_texture().get_image().save_png(file) != OK:
			quit(1)
			return
		print("PANEL_CAPTURE ",file," native_bands=",Vector3i(int(panel.register.size.y/2),int(panel.worksheet.size.y/2),int(panel.dock.size.y/2)))
		root.remove_child(viewport)
		viewport.queue_free()
	print("PANEL_RENDER_VERIFIED samples=4 desktop-composition-public-fixtures")
	quit(0)
