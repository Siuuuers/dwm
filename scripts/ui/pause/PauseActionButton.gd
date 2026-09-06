extends Button
## Native released Button input, with independent owner-published Filed selection.
var public_copy := ""
var selected := false
var dangerous := false
var _paragraph: TextParagraph
var _baselines := PackedFloat32Array()
var _text_height := 0.0
var _inset := 6

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())

func _ready() -> void:
	for event: Signal in [focus_entered,focus_exited,mouse_entered,mouse_exited,button_down,button_up]:
		event.connect(queue_redraw)

static func measure(copy: String, next_theme: Theme, allocation: Vector2) -> Dictionary:
	if copy.strip_edges().is_empty() or next_theme == null or allocation.x < 64 or allocation.y < 64: return {}
	var paragraph := TextParagraph.new()
	paragraph.width = allocation.x-32
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	if not paragraph.add_string(copy,next_theme.default_font,next_theme.default_font_size): return {}
	var baselines := PackedFloat32Array()
	var height := 0.0
	for line: int in paragraph.get_line_count():
		if paragraph.get_line_width(line) > allocation.x-32: return {}
		height += ceilf(paragraph.get_line_ascent(line)/2.0)*2
		baselines.append(height)
		height += ceilf(paragraph.get_line_descent(line)/2.0)*2
	if height > allocation.y-32: return {}
	return {"paragraph":paragraph,"baselines":baselines,"height":height}

func configure(copy: String, next_theme: Theme, allocation: Vector2 = Vector2(416,96), large: bool = false) -> bool:
	var measured := measure(copy,next_theme,allocation)
	if measured.is_empty(): return false
	public_copy = copy
	accessibility_name = copy
	text = ""
	theme = next_theme
	_paragraph = measured.paragraph
	_baselines = measured.baselines
	_text_height = measured.height
	_inset = 8 if large else 6
	custom_minimum_size = allocation
	update_minimum_size()
	size = allocation
	queue_redraw()
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: accept_event()
	elif event is InputEventMouseButton and event.double_click: accept_event()

func _draw() -> void:
	if _paragraph == null: return
	var face := Rect2(Vector2.ONE*_inset,size-Vector2.ONE*_inset*2)
	var ink := get_theme_color(&"paper_ink" if selected else &"ink",&"Pause")
	var rule := get_theme_color(&"paper_ink" if selected else (&"danger" if dangerous else &"structure"),&"Pause")
	draw_rect(face,get_theme_color(&"filed" if selected else &"face",&"Pause"))
	draw_rect(face.grow(-1),rule,false,2)
	if selected: draw_rect(Rect2(face.end.x-4,face.position.y+2,2,face.size.y-4),rule)
	if is_pressed(): draw_rect(Rect2(face.position+Vector2(4,4),Vector2(face.size.x-8,2)),rule)
	elif is_hovered(): draw_rect(Rect2(face.position+Vector2(2,4),Vector2(2,face.size.y-8)),rule)
	var top := floorf((size.y-_text_height)/4.0)*2
	for line: int in _paragraph.get_line_count():
		_paragraph.draw_line(get_canvas_item(),Vector2(16,top+_baselines[line]-_paragraph.get_line_ascent(line)),line,ink)
	if has_focus():
		draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),get_theme_color(&"paper_ink" if selected else &"ink",&"Pause"),false,2)
		draw_rect(Rect2(Vector2(4,4),size-Vector2(8,8)),get_theme_color(&"paper_focus" if selected else &"focus",&"Pause"),false,2)
