extends "res://tests/integration/verify_complete_action_recovery.gd"
## Native acceptance: isolated copied data, real UI and owner, no gameplay writes outside the fixture.

func _run() -> void:
	await _frames()
	var bootstrap: Node = root.get_node("ApplicationBootstrap")
	if not _check(bootstrap.get_startup_state().get("ready",false),"UI bootstrap ready"): return
	root.get_node("SceneRouter").goto_menu()
	await _frames()
	var menu: Node = current_scene
	menu.get_node("%NewAccButton").pressed.emit()
	var deadline := Time.get_ticks_msec()+30000
	while is_instance_valid(menu) and menu._title_transition and Time.get_ticks_msec()<deadline: await process_frame
	if is_instance_valid(menu) and is_instance_valid(menu._confirmation): menu._confirmation.confirm_button.pressed.emit()
	var game: Node = root.get_node("GameState")
	var manager: Node = root.get_node("SaveManager")
	var desktop: Node
	while Time.get_ticks_msec()<deadline:
		desktop = current_scene.find_child("ComputerDesktop",true,false) if current_scene != null else null
		if desktop != null and not manager._new_run_busy and game.capture_live_session().value.active: break
		await process_frame
	if not _check(desktop != null,"UI desktop ready"): return
	if not _check(desktop.open_app(&"minesweeper").get("ok",false),"UI board opens"): return
	root.grab_focus()
	await _frames()
	var app: Node = desktop._cached_app_windows[&"minesweeper"]
	var panel: Control = app.panel
	for tier: String in ["beginner","intermediate","expert"]:
		panel.register.difficulties[tier].pressed.emit()
		if not _check(panel.worksheet.cell_size == 36 and not panel.worksheet.always_fit, "fresh tier defaults to manual 36"): return
		panel.worksheet.zoom_controls[1].pressed.emit()
		if not _check(panel.worksheet.always_fit, "explicit Fit toggle is remembered for " + tier): return
		for percent: int in [100,125,150]:
			if not _check(panel.configure("en",percent,false),"UI text preference accepted"): return
			if not _check(_complete_board_visible(panel),"complete "+tier+" at "+str(percent)): return
		if not await _visible_grid_rules(panel.worksheet.grid): return
		await _capture_screen("fit-"+tier+"-150")
	var prior_window_size := root.size
	for display: Vector2i in [Vector2i(960,540),Vector2i(640,360)]:
		root.size=display
		await _frames()
		if not _check(root.size==display,"native window resized to "+str(display)): return
		if not _check(_complete_board_visible(panel),"expert fits resized window"): return
		if not await _visible_grid_rules(panel.worksheet.grid): return
		await _capture_screen("fit-expert-"+str(display.x))
	root.size=prior_window_size
	await _frames()
	if not _check(panel.configure("en",100,false),"restore standard text"): return
	var rounds: int = game.minesweeper_rounds_left
	_click_cell(panel.worksheet.grid,0)
	if not _check(game.minesweeper_rounds_left==rounds-1,"first click charges one round"): return
	if not _chord_in_flag_mode(bootstrap,panel): return
	await _capture_screen("fit-expert-chord")
	var physical: Dictionary = bootstrap._desktop_board_state.capture().board.board
	var mine := -1
	for index: int in physical.mine_indices:
		if index not in physical.flagged_indices: mine=index; break
	if not _check(mine>=0,"fixture has an unflagged mine"): return
	panel.dock.buttons.flag.pressed.emit()
	_click_cell(panel.worksheet.grid,mine)
	await _frames()  # dwm-634.1: the terminal board paints first; settlement runs on the next frames
	if not _check(panel.public_view.settled,"real loss settles"): return
	var paid_rounds: int = game.minesweeper_rounds_left
	panel.register.difficulties.intermediate.pressed.emit()
	if not _check(not panel.public_view.settled and panel.public_view.board.width==16,"terminal difficulty shows next tier"): return
	if not _check(game.minesweeper_rounds_left==paid_rounds,"tier selection does not charge first Reveal"): return
	_click_cell(panel.worksheet.grid,0)
	if not _check(game.minesweeper_rounds_left==paid_rounds-1,"next board pays normal first Reveal"): return
	physical = bootstrap._desktop_board_state.capture().board.board
	_click_cell(panel.worksheet.grid,int(physical.mine_indices[0]))
	await _frames()
	if not _check(panel.public_view.settled,"second real result settles"): return
	var verify_rebinding := OS.get_cmdline_user_args().has("--verify-new-board-rebinding")
	var new_board_key: Key = KEY_SPACE
	if verify_rebinding:
		var events: Array[Dictionary] = [{"kind": "key", "physical_keycode": KEY_G, "keycode": 0,
			"shift": false, "alt": false, "ctrl": false, "meta": false}]
		if not _check(root.get_node("ProfileManager").set_input_mapping(&"game_new_board",events).ok,"New Board binding saved"): return
		var old_binding := InputEventKey.new()
		old_binding.keycode=KEY_SPACE
		old_binding.physical_keycode=KEY_SPACE
		old_binding.pressed=true
		root.push_input(old_binding,true)
		old_binding.pressed=false
		root.push_input(old_binding,true)
		if not _check(panel.public_view.settled,"old Space binding is inert after rebind"): return
		new_board_key=KEY_G
	var space := InputEventKey.new()
	space.keycode=new_board_key
	space.physical_keycode=new_board_key
	space.pressed=true
	root.push_input(space,true)
	space.pressed=false
	root.push_input(space,true)
	if not _check(not panel.public_view.settled and not panel.public_view.board.terminal,"New Board shortcut works without grid focus"): return
	if not _check(game.minesweeper_rounds_left==paid_rounds-1,"New Board shortcut does not spend beyond normal entry"): return
	if not _check(_complete_board_visible(panel),"final next board fits"): return
	if desktop.message_notification.visible: desktop.notification_close.pressed.emit()
	await _capture_screen("fit-next-board-space")
	print("MINESWEEPER_UI_PASS: all tiers/text sizes fit; real flag-mode chord; terminal tier transition; New Board key=%s; normal costs" % OS.get_keycode_string(new_board_key))
	quit(0)

func _complete_board_visible(panel: Control) -> bool:
	var grid: Control = panel.worksheet.grid
	var local := Rect2(grid.position,grid.size*grid.scale)
	return Rect2(Vector2.ZERO,panel.worksheet.well.size).encloses(local) \
		and panel.worksheet.vertical_rail==null and panel.worksheet.horizontal_rail==null

func _click_cell(grid: Control,index: int) -> void:
	var cell: Control = grid.cell_nodes[index]
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=grid.get_global_transform_with_canvas()*(cell.position+cell.size/2.0)
	click.pressed=true
	root.push_input(click,true)
	click.pressed=false
	root.push_input(click,true)

func _chord_in_flag_mode(bootstrap: Node,panel: Control) -> bool:
	var physical: Dictionary = bootstrap._desktop_board_state.capture().board.board
	var width: int = physical.width
	for index: int in physical.revealed_indices:
		if physical.adjacency_counts[index]<=0: continue
		var adjacent_mines: Array[int]=[]
		var hidden_safe := false
		for dy: int in [-1,0,1]:
			for dx: int in [-1,0,1]:
				var x:=index%width+dx
				var y:=index/width+dy
				if x<0 or y<0 or x>=width or y>=physical.height: continue
				var neighbor:int=y*width+x
				if neighbor in physical.mine_indices: adjacent_mines.append(neighbor)
				elif neighbor not in physical.revealed_indices: hidden_safe=true
		if not hidden_safe: continue
		panel.dock.buttons.flag.pressed.emit()
		for mine: int in adjacent_mines: _click_cell(panel.worksheet.grid,mine)
		var revision: int=panel.public_view.board.revision
		_click_cell(panel.worksheet.grid,index)
		return _check(panel.public_view.board.revision>revision,"flag mode numbered click commits Chord")
	return _check(false,"fixture needs revealed number with hidden safe neighbor")

func _visible_grid_rules(grid: Control) -> bool:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var ink: Color = grid.get_theme_color(&"dark_registration",&"Minesweeper")
	var transform := root.get_stretch_transform()*grid.get_global_transform_with_canvas()
	var target: float = grid.cell_nodes[0].size.x
	# Sample every cell boundary halfway along a cell, away from crossing rules.
	for axis: int in [0,1]:
		var count: int = grid.projection.width if axis==0 else grid.projection.height
		for boundary: int in range(1,count):
			var local := Vector2(2+boundary*target,2+7.5*target) if axis==0 else Vector2(2+7.5*target,2+boundary*target)
			var point: Vector2 = transform*local
			var found := false
			for offset: int in range(-2,3):
				var at := Vector2i(roundi(point.x),roundi(point.y))
				at[axis]+=offset
				if at.x<0 or at.y<0 or at.x>=pixels.get_width() or at.y>=pixels.get_height(): continue
				var actual := pixels.get_pixelv(at)
				if absf(actual.r-ink.r)+absf(actual.g-ink.g)+absf(actual.b-ink.b)<0.04: found=true
			if not _check(found,"rendered grid rule axis="+str(axis)+" boundary="+str(boundary)+" point="+str(point)+" pixels="+str(pixels.get_size())): return false
	return true
