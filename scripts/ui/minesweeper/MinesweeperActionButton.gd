extends Button
## A released action with owner-published selection; input never changes commitment.

const ROW := preload("res://scripts/ui/minesweeper/MinesweeperSheetRow.gd")
const WIDTHS := [80,96,112,128,144,160]
const ROLES := [&"controlled_face",&"primary_dark_copy",&"dark_registration",&"dark_focus_outer",&"dark_focus_inner",&"selected_plane",&"selected_ink",&"filed_focus_outer",&"filed_focus_inner"]

var public_copy := ""
var selected := false
var _paragraph: TextParagraph
var _baselines := PackedFloat32Array()
var _text_height := 0.0
var _inset := 6


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	toggle_mode = false
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())


func _ready() -> void:
	for event: Signal in [focus_entered,focus_exited,mouse_entered,mouse_exited,button_down,button_up]:
		event.connect(queue_redraw)


func _enter_tree() -> void:
	# Godot preserves its combined-minimum cache during off-tree configuration.
	update_minimum_size()
	size = custom_minimum_size


func configure(copy: String, next_theme: Theme, large: bool, width_logical: int = 128) -> bool:
	if next_theme == null or width_logical not in WIDTHS: return false
	for role: StringName in ROLES:
		if not next_theme.has_color(role,&"Minesweeper"): return false
	var inset: int = 8 if large else 6
	var measured: Dictionary = ROW.measure_copy(copy,next_theme,width_logical-inset*2-8)
	if measured.is_empty(): return false
	public_copy = copy
	theme = next_theme
	_paragraph = measured.paragraph
	_baselines = measured.baselines
	_text_height = measured.height
	_inset = inset
	# Drawing owns the copy; native Button owns released input and accessibility.
	text = ""
	accessibility_name = copy
	custom_minimum_size = Vector2(width_logical,maxf(64 if large else 48,_text_height+inset*2+4))
	update_minimum_size()
	size = custom_minimum_size
	queue_redraw()
	return true


func present_state(enabled: bool, next_selected: bool) -> void:
	selected = next_selected
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if not enabled and is_inside_tree(): release_focus()
	# Localized selection descriptions belong to the owner, via accessibility_description.
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		accept_event()
	elif event is InputEventMouseButton and event.double_click:
		accept_event()


func _face_rect() -> Rect2:
	return Rect2(Vector2.ONE*_inset,size-Vector2.ONE*_inset*2)


func _draw() -> void:
	if _paragraph == null: return
	var face: Rect2 = _face_rect()
	var ink: Color = _role(&"selected_ink" if selected else &"primary_dark_copy")
	var structure: Color = _role(&"selected_ink" if selected else &"dark_registration")
	draw_rect(face,_role(&"selected_plane" if selected else &"controlled_face"))
	draw_rect(face.grow(-1),structure,false,2)
	if selected:
		# The trailing filing seam persists through focus, contact, and disabled state.
		draw_rect(Rect2(face.end.x-4,face.position.y+2,2,face.size.y-4),structure)
	if disabled:
		# Blocked action edge stays outside the copy/face and inside the hit allocation.
		draw_rect(Rect2(face.position.x,size.y-4,face.size.x,2),_role(&"dark_registration"))
	if not disabled:
		if is_pressed():
			draw_rect(Rect2(face.position+Vector2(4,4),Vector2(face.size.x-8,2)),structure)
		elif is_hovered():
			draw_rect(Rect2(face.position+Vector2(2,4),Vector2(2,face.size.y-8)),structure)
	var top: float = floorf((size.y-_text_height)/4.0)*2.0
	for line: int in _paragraph.get_line_count():
		var x: float = floorf((size.x-_paragraph.get_line_width(line))/4.0)*2.0
		_paragraph.draw_line(get_canvas_item(),Vector2(x,top+_baselines[line]-_paragraph.get_line_ascent(line)),line,ink)
	if has_focus() and not disabled:
		draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),_role(&"filed_focus_outer" if selected else &"dark_focus_outer"),false,2)
		draw_rect(Rect2(Vector2(4,4),size-Vector2(8,8)),_role(&"filed_focus_inner" if selected else &"dark_focus_inner"),false,2)


func _role(role: StringName) -> Color:
	return get_theme_color(role,&"Minesweeper")
