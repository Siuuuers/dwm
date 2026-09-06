extends SceneTree
## GPU component proof: actual composite grids, not a desktop/challenge host acceptance.
const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = viewport.size
	background.color = Color("0b0d13")
	viewport.add_child(background)
	var board: Dictionary = REDUCER.first_reveal({"schema_version":1,"width":8,"height":8,
		"mine_indices":[1,7,20,25,36,44,50,57,60,63],"mine_count":10},0).value.board
	board = REDUCER.set_flag(board,1,true,"fixture-flag").value.board
	board = REDUCER.reveal(board,16,"fixture-reveal").value.board
	var snapshot := STATE.new().capture()
	snapshot.phase = "ACTIVE_VISIBLE"
	snapshot.revision = 3
	snapshot.identity = {"run_id":"fixture","branch_id":"fixture","desktop_timeline_generation":0,"causal_day_instance":"fixture","app_round_ordinal":1}
	snapshot.board = {"board":board,"paid_start_receipt":{"checkpoint_id":"fixture"}}
	var result := QUERY.desktop(snapshot,"beginner")
	if not result.ok:
		quit(1)
		return
	for large: bool in [false,true]:
		var grid: Control = GRID.new()
		viewport.add_child(grid)
		grid.position = Vector2(660,100) if large else Vector2(64,100)
		if not grid.configure("zh-HK" if large else "en",150,large,&"midnight" if large else &"after_hours") or not grid.present(result.value):
			quit(1)
			return
		grid.grab_focus()
	for frame in 5: await RenderingServer.frame_post_draw
	var evidence := ProjectSettings.globalize_path("user://evidence/minesweeper_cells")
	DirAccess.make_dir_recursive_absolute(evidence)
	var pixels := viewport.get_texture().get_image()
	if pixels == null or pixels.is_empty() or pixels.save_png(evidence.path_join("composite-grids.png")) != OK:
		quit(1)
		return
	print("COMPOSITE_GRID_CAPTURE ",evidence.path_join("composite-grids.png"))
	quit(0)
