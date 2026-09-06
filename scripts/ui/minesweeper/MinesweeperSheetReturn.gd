extends Button
## The sole sheet action. Native Button owns release activation and accessibility.

const ROW := preload("res://scripts/ui/minesweeper/MinesweeperSheetRow.gd")
const ROLES := [&"controlled_face",&"primary_dark_copy",&"dark_registration",&"dark_focus_outer",&"dark_focus_inner"]

var public_copy := ""
var _paragraph: TextParagraph
var _baselines := PackedFloat32Array()
var _text_height := 0.0
var _inset := 6


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())


func _ready() -> void:
	for event: Signal in [focus_entered,focus_exited,mouse_entered,mouse_exited,button_down,button_up]:
		event.connect(queue_redraw)


func _enter_tree() -> void:
	# Resolve any smaller measured minimum cached while this button was off-tree.
	update_minimum_size()
	size = custom_minimum_size


func configure(copy: String, next_theme: Theme, large: bool) -> bool:
	if next_theme == null: return false
	for role: StringName in ROLES:
		if not next_theme.has_color(role,&"Minesweeper"): return false
	var inset: int = 8 if large else 6
	var measured: Dictionary = ROW.measure_copy(copy,next_theme,128-inset*2-8)
	if measured.is_empty(): return false
	public_copy = copy
	theme = next_theme
	_paragraph = measured.paragraph
	_baselines = measured.baselines
	_text_height = measured.height
	_inset = inset
	# Native text is empty so it cannot add another minimum-size/wrapping owner.
	text = ""
	accessibility_name = copy
	custom_minimum_size = Vector2(128,maxf(64 if large else 48,_text_height+inset*2+4))
	update_minimum_size()
	size = custom_minimum_size
	queue_redraw()
	return true


func _gui_input(event: InputEvent) -> void:
	# Script input precedes native Button input; consume duplicate contacts only.
	if event is InputEventKey and event.echo:
		accept_event()
	elif event is InputEventMouseButton and event.double_click:
		accept_event()


func _draw() -> void:
	if _paragraph == null: return
	var face := Rect2(Vector2.ONE*_inset,size-Vector2.ONE*_inset*2)
	draw_rect(face,_role(&"controlled_face"))
	draw_rect(face.grow(-1),_role(&"dark_registration"),false,2)
	if not disabled:
		if is_pressed():
			draw_rect(Rect2(face.position+Vector2(4,4),Vector2(face.size.x-8,2)),_role(&"dark_registration"))
		elif is_hovered():
			draw_rect(Rect2(face.position+Vector2(4,4),Vector2(2,face.size.y-8)),_role(&"dark_registration"))
	var top: float = floorf((size.y-_text_height)/4.0)*2.0
	for line: int in _paragraph.get_line_count():
		var x: float = floorf((size.x-_paragraph.get_line_width(line))/4.0)*2.0
		_paragraph.draw_line(get_canvas_item(),Vector2(x,top+_baselines[line]-_paragraph.get_line_ascent(line)),line,_role(&"primary_dark_copy"))
	if has_focus() and not disabled:
		draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),_role(&"dark_focus_outer"),false,2)
		draw_rect(Rect2(Vector2(4,4),size-Vector2(8,8)),_role(&"dark_focus_inner"),false,2)


func _role(role: StringName) -> Color:
	return get_theme_color(role,&"Minesweeper")
