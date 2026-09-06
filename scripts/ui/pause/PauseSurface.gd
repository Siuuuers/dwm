extends Control
## Pure modal presentation. The injected owner admits every lifecycle/save command.
signal preview_requested(action_id: StringName)
signal enter_requested(action_id: StringName)
signal continue_requested
signal return_confirmed

const PRESENTATION := preload("res://scripts/ui/pause/PauseTheme.gd")
const ACTION := preload("res://scripts/ui/pause/PauseActionButton.gd")
const ACTIONS := [&"continue",&"backup",&"settings",&"return"]
const COPY_KEYS := ["continue","backup","settings","return","title","question","warning","cancel"]

var rows: Dictionary = {}
var selected_action: StringName = &"continue"
var entered_action: StringName = &""
var context_strip: Control
var workfield: Control
var confirmation: Control
var cancel_button: Button
var return_button: Button
var _title: Label
var _question: Label
var _warning: Label
var _left: Control
var _hosts: Dictionary = {}
var _suspended_inputs: Dictionary = {}
var _opened := false
var _interactive := true
var _pointer_contact := false
var _high_contrast := false
var _large_targets := false
var _locale := "en"
var _percent := 100
var _palette := "AfterHours"
var _colour_preset := "standard"
var _copy := {"continue":"Continue","backup":"Backup","settings":"Settings","return":"Return to Title",
	"title":"Pause","question":"Return to title?","warning":"No new save will be made. Unsaved progress will be left behind.","cancel":"Cancel"}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(1280,720)
	theme = PRESENTATION.build("en",100)

func _ready() -> void:
	_left = Control.new()
	_left.name = "Actions"
	_left.size = Vector2(480,720)
	add_child(_left)
	for index: int in ACTIONS.size():
		var id: StringName = ACTIONS[index]
		var row := ACTION.new()
		row.name = String(id).to_pascal_case()
		row.position = Vector2(32,32+112*index)
		_left.add_child(row)
		rows[id] = row
		row.focus_entered.connect(_row_focused.bind(id))
		row.pressed.connect(_activate.bind(id))
		row.gui_input.connect(_row_input.bind(id))
	context_strip = Control.new()
	context_strip.name = "ContextStrip"
	context_strip.position = Vector2(480,0)
	context_strip.size = Vector2(800,64)
	context_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(context_strip)
	_title = Label.new()
	_title.position = Vector2(32,0)
	_title.size = Vector2(736,64)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_strip.add_child(_title)
	workfield = Control.new()
	workfield.name = "Workfield"
	workfield.position = Vector2(480,64)
	workfield.size = Vector2(800,656)
	add_child(workfield)
	_build_confirmation()
	for id: StringName in _hosts: _mount_host(id)
	_apply_copy()
	_wire_rows()
	_sync_custody()
	hide()

func _build_confirmation() -> void:
	confirmation = Control.new()
	confirmation.name = "ReturnConfirmation"
	confirmation.size = Vector2(800,656)
	workfield.add_child(confirmation)
	confirmation.draw.connect(_draw_confirmation)
	var scroll := ScrollContainer.new()
	scroll.name = "WarningScroll"
	scroll.position = Vector2(32,32)
	scroll.size = Vector2(736,464)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	confirmation.add_child(scroll)
	var copy_column := VBoxContainer.new()
	copy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_column.add_theme_constant_override("separation",24)
	scroll.add_child(copy_column)
	_question = Label.new()
	_warning = Label.new()
	for label: Label in [_question,_warning]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy_column.add_child(label)
	return_button = ACTION.new()
	return_button.name = "ConfirmReturn"
	return_button.dangerous = true
	return_button.position = Vector2(32,528)
	confirmation.add_child(return_button)
	return_button.pressed.connect(_confirm_return)
	cancel_button = ACTION.new()
	cancel_button.name = "Cancel"
	cancel_button.position = Vector2(464,528)
	confirmation.add_child(cancel_button)
	cancel_button.pressed.connect(leave_host)
	cancel_button.focus_previous = cancel_button.get_path()
	cancel_button.focus_next = cancel_button.get_path_to(return_button)
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(return_button)
	cancel_button.focus_neighbor_right = cancel_button.get_path()
	return_button.focus_previous = return_button.get_path_to(cancel_button)
	return_button.focus_next = return_button.get_path()
	return_button.focus_neighbor_left = return_button.get_path()
	return_button.focus_neighbor_right = return_button.get_path_to(cancel_button)

func configure_presentation(locale: String, percent: int, palette: String = "AfterHours", high_contrast: bool = false, colour_preset: String = "standard", large_targets: bool = false) -> bool:
	var candidate := PRESENTATION.build(locale,percent,palette,high_contrast,colour_preset)
	if candidate == null or not _can_measure(_copy,candidate): return false
	_locale = locale
	_percent = percent
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_large_targets = large_targets
	theme = candidate
	if is_node_ready(): _apply_copy()
	queue_redraw()
	return true

func configure_copy(copy: Dictionary) -> bool:
	if copy.size() != COPY_KEYS.size(): return false
	for key: String in COPY_KEYS:
		if typeof(copy.get(key)) != TYPE_STRING or str(copy[key]).strip_edges().is_empty(): return false
	if not _can_measure(copy,theme): return false
	_copy = copy.duplicate(true)
	accessibility_name = _copy.title
	if is_node_ready(): _apply_copy()
	return true

func _can_measure(copy: Dictionary, candidate: Theme) -> bool:
	for id: StringName in ACTIONS:
		if ACTION.measure(str(copy[id]),candidate,Vector2(416,96)).is_empty(): return false
	return not ACTION.measure(str(copy.cancel),candidate,Vector2(304,96)).is_empty()

func _apply_copy() -> void:
	accessibility_name = _copy.title
	for id: StringName in ACTIONS: rows[id].configure(_copy[id],theme,Vector2(416,96),_large_targets)
	return_button.configure(_copy["return"],theme,Vector2(416,96),_large_targets)
	cancel_button.configure(_copy.cancel,theme,Vector2(304,96),_large_targets)
	_question.text = _copy.question
	_warning.text = _copy.warning
	_title.text = _copy[selected_action]
	confirmation.queue_redraw()
	queue_redraw()

func set_host(action_id: StringName, host: Control) -> bool:
	if action_id not in [&"backup",&"settings"] or not is_instance_valid(host): return false
	if _hosts.has(action_id): return _hosts[action_id] == host
	if host.get_parent() != null: return false
	_hosts[action_id] = host
	if is_node_ready():
		_mount_host(action_id)
		_sync_custody()
	return true

func _mount_host(id: StringName) -> void:
	var host: Control = _hosts[id]
	host.position = Vector2.ZERO
	host.size = Vector2(800,656)
	host.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	host.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	workfield.add_child(host)
	for close_signal: StringName in [&"close_requested",&"window_hidden"]:
		if host.has_signal(close_signal): host.connect(close_signal,_host_closed.bind(id))

func open_surface() -> void:
	if not is_node_ready(): return
	_opened = true
	selected_action = &"continue"
	entered_action = &""
	show()
	_sync_custody()
	if _interactive: rows[&"continue"].grab_focus()

func close_surface() -> void:
	_opened = false
	entered_action = &""
	_sync_custody()
	hide()

func set_interactive(value: bool) -> void:
	_interactive = value
	if is_node_ready(): _sync_custody()

func _wire_rows() -> void:
	for index: int in ACTIONS.size():
		var row: Control = rows[ACTIONS[index]]
		var before: Control = rows[ACTIONS[maxi(0,index-1)]]
		var after: Control = rows[ACTIONS[mini(ACTIONS.size()-1,index+1)]]
		row.focus_previous = row.get_path_to(before)
		row.focus_neighbor_top = row.get_path_to(before)
		row.focus_next = row.get_path_to(after)
		row.focus_neighbor_bottom = row.get_path_to(after)
		row.focus_neighbor_left = row.get_path()
		row.focus_neighbor_right = row.get_path()

func _row_focused(id: StringName) -> void:
	if _pointer_contact: return
	_preview(id)

func _preview(id: StringName) -> void:
	if not _opened or not _interactive or entered_action != &"": return
	selected_action = id
	_sync_custody()
	preview_requested.emit(id)

func _activate(id: StringName) -> void:
	if not _opened or not _interactive or entered_action != &"": return
	_preview(id)
	if not _opened or not _interactive or entered_action != &"": return
	if id == &"continue":
		continue_requested.emit()
		return
	enter_requested.emit(id)
	if not _opened or not _interactive or entered_action != &"": return
	if id != &"return" and not _hosts.has(id): return
	entered_action = id
	_sync_custody()
	if id == &"return": cancel_button.grab_focus()
	else:
		var host: Control = _hosts[id]
		if host.has_method("focus_entry"): host.call("focus_entry")
		elif host.has_method("show_window"): host.call("show_window")
		else: _focus_first(host)

func _focus_first(node: Node) -> bool:
	if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree():
		node.grab_focus()
		return true
	for child: Node in node.get_children():
		if _focus_first(child): return true
	return false

func _row_input(event: InputEvent, id: StringName) -> void:
	if event.is_action_pressed(&"ui_right",false):
		rows[id].accept_event()
		if id != &"continue": _activate(id)

func handle_back() -> bool:
	if not _opened: return false
	if not _interactive: return true
	if entered_action == &"": continue_requested.emit()
	elif entered_action == &"return": leave_host()
	else:
		var host: Control = _hosts[entered_action]
		if host.has_method("handle_back") and host.call("handle_back") == true: return true
		leave_host()
	return true

func leave_host() -> void:
	if entered_action == &"": return
	var source := entered_action
	entered_action = &""
	_sync_custody()
	if _opened and _interactive: rows[source].grab_focus()

func _host_closed(id: StringName) -> void:
	if entered_action == id: leave_host()

func _confirm_return() -> void:
	if _opened and _interactive and entered_action == &"return": return_confirmed.emit()

func _sync_custody() -> void:
	var root_active := _opened and _interactive and entered_action == &""
	_set_custody(_left,root_active)
	for id: StringName in ACTIONS:
		rows[id].selected = id == selected_action
		rows[id].queue_redraw()
	for id: StringName in _hosts:
		var host: Control = _hosts[id]
		host.visible = _opened and selected_action == id
		var active := _opened and _interactive and entered_action == id
		_set_custody(host,active)
		_host_script_input(host,active)
	confirmation.visible = _opened and selected_action == &"return"
	_set_custody(confirmation,_opened and _interactive and entered_action == &"return")
	context_strip.visible = _opened and selected_action != &"continue"
	workfield.visible = context_strip.visible
	_title.text = _copy[selected_action]
	queue_redraw()

func _set_custody(control: Control, active: bool) -> void:
	control.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if active else Control.FOCUS_BEHAVIOR_DISABLED
	control.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if active else Control.MOUSE_BEHAVIOR_DISABLED
	if not active:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and (focused == control or control.is_ancestor_of(focused)): focused.release_focus()

func _host_script_input(node: Node, active: bool) -> void:
	var id := node.get_instance_id()
	if not active and not _suspended_inputs.has(id):
		_suspended_inputs[id] = [node.is_processing_input(),node.is_processing_unhandled_input(),node.is_processing_unhandled_key_input()]
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
		node.set_process_unhandled_key_input(false)
	elif active and _suspended_inputs.has(id):
		var flags: Array = _suspended_inputs[id]
		node.set_process_input(flags[0])
		node.set_process_unhandled_input(flags[1])
		node.set_process_unhandled_key_input(flags[2])
		_suspended_inputs.erase(id)
	for child: Node in node.get_children(): _host_script_input(child,active)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: _pointer_contact = event.pressed
	elif event is InputEventScreenTouch: _pointer_contact = event.pressed

func _unhandled_input(event: InputEvent) -> void:
	if _opened and event.is_action_pressed(&"ui_cancel",false):
		get_viewport().set_input_as_handled()
		handle_back()

func _draw() -> void:
	if theme == null: return
	var veil := get_theme_color(&"habitat",&"Pause")
	veil.a = 1.0 if _high_contrast else 0.7
	draw_rect(Rect2(0,0,1280,720),veil)
	draw_rect(Rect2(0,0,480,720),get_theme_color(&"face",&"Pause"))
	if _opened and selected_action != &"continue": draw_rect(Rect2(480,0,800,64),get_theme_color(&"face",&"Pause"))

func _draw_confirmation() -> void:
	confirmation.draw_rect(Rect2(0,0,800,656),get_theme_color(&"face",&"Pause"))
	confirmation.draw_rect(Rect2(32,16,736,2),get_theme_color(&"warning",&"Pause"))
