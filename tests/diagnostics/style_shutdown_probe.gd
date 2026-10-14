extends SceneTree
## Diagnostic only: real Dialogic Styles with no Save/Bridge fixture or GUT owner.
## Run with -- --retire-style for the synchronous style_changed retirement case.
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
var _retire_style := false
var _inherited_cycle := false
var _style_events := 0
var _selected_before_mount := false
var _selected_layout: Node
var _styles: Node
var _watchdog: Timer
var _finished := false

func _initialize() -> void:
	_retire_style = OS.get_cmdline_user_args().has("--retire-style")
	_inherited_cycle = OS.get_cmdline_user_args().has("--inherited-cycle")
	call_deferred("_run_probe")

func _timeout() -> void:
	if _finished: return
	print("DWM_STYLE_PROBE timeout retire=", _retire_style)
	quit(1)

func _selected(_info: Dictionary) -> void:
	_style_events += 1
	_selected_layout = _styles.get_layout_node()
	if not is_instance_valid(_selected_layout): return
	_selected_before_mount = not _selected_layout.is_inside_tree()
	print("DWM_STYLE_PROBE selected before_mount=", _selected_before_mount,
		" retire=", _retire_style)
	if _retire_style: _selected_layout.queue_free()

func _run_probe() -> void:
	_watchdog = Timer.new()
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.one_shot = true
	_watchdog.wait_time = 10.0
	root.add_child(_watchdog)
	_watchdog.timeout.connect(_timeout)
	_watchdog.start()
	var runtime: Node = root.get_node_or_null("Dialogic")
	if runtime == null:
		print("DWM_STYLE_PROBE missing Dialogic autoload")
		quit(1)
		return
	_styles = runtime.get_subsystem("Styles")
	if _styles == null:
		print("DWM_STYLE_PROBE missing Styles subsystem")
		quit(1)
		return
	var previous: Node = _styles.get_layout_node()
	if is_instance_valid(previous):
		previous.queue_free()
		await process_frame
		if is_instance_valid(previous):
			print("DWM_STYLE_PROBE previous layout not retired")
			quit(1)
			return
	if _inherited_cycle:
		var cycle_ok: bool = await _run_inherited_cycle()
		if not cycle_ok:
			quit(1)
			return
	_styles.style_changed.connect(_selected, CONNECT_ONE_SHOT)
	_styles.load_style(STYLE, root, true, false)
	for frame: int in 8: await process_frame
	var valid := _style_events == 1 and _selected_before_mount
	if _retire_style:
		valid = valid and not is_instance_valid(_selected_layout)
	else:
		valid = valid and is_instance_valid(_selected_layout)
		if is_instance_valid(_selected_layout):
			valid = valid and _selected_layout.is_inside_tree() and _selected_layout.is_node_ready()
			_selected_layout.queue_free()
			await process_frame
			valid = valid and not is_instance_valid(_selected_layout)
	_watchdog.stop()
	_watchdog.queue_free()
	for frame: int in 4: await process_frame
	_finished = true
	print("DWM_STYLE_PROBE completed valid=", valid, " retire=", _retire_style,
		" events=", _style_events, " inherited_cycle=", _inherited_cycle)
	quit(0 if valid else 1)

func _run_inherited_cycle() -> bool:
	print("DWM_STYLE_PROBE inherited_cycle begin")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var layout: Node = _styles.load_style(STYLE, viewport)
	if not is_instance_valid(layout):
		print("DWM_STYLE_PROBE inherited_cycle missing_layout")
		return false
	if not layout.is_node_ready(): await layout.ready
	# Resume within the actual ready callback stack, exactly as the fixture does.
	print("DWM_STYLE_PROBE inherited_cycle ready_then_queue")
	layout.queue_free()
	for frame: int in 4:
		await process_frame
		if not is_instance_valid(layout): break
	if is_instance_valid(layout):
		print("DWM_STYLE_PROBE inherited_cycle layout_not_retired")
		return false
	print("DWM_STYLE_PROBE inherited_cycle layout_retired")
	viewport.queue_free()
	await process_frame
	if is_instance_valid(viewport):
		print("DWM_STYLE_PROBE inherited_cycle viewport_not_retired")
		return false
	print("DWM_STYLE_PROBE inherited_cycle viewport_retired")
	return true
