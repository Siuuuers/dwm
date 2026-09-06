extends Control
## One public, inspectable paper fact. This control owns no activation operation.

const BREAKS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
const ROLES := [&"paper",&"primary_paper_copy",&"paper_structure",&"paper_focus_outer",&"paper_focus_inner"]
# Authored break opportunities for exact English chrome labels only. Public and
# accessibility copy remain plain; a soft hyphen is drawn only at a taken break.
const CHROME_BREAKS := {
	"Intermediate":"Inter\u00adme\u00addi\u00adate", "Expert":"Ex\u00adpert",
	"Reveal":"Re\u00adveal", "Assignments":"As\u00adsign\u00adments", "Foresight":"Fore\u00adsight",
}

var public_copy := ""
var _paragraph: TextParagraph
var _baselines := PackedFloat32Array()
var _text_height := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _enter_tree() -> void:
	# Godot retains its minimum-size cache during off-tree reconfiguration.
	update_minimum_size()
	size = custom_minimum_size


func configure(copy: String, next_theme: Theme, width_logical: int, minimum_height_logical: int) -> bool:
	if width_logical <= 24 or width_logical % 2 != 0 or minimum_height_logical < 48 or minimum_height_logical % 2 != 0: return false
	if next_theme == null: return false
	for role: StringName in ROLES:
		if not next_theme.has_color(role,&"Minesweeper"): return false
	var measured: Dictionary = measure_copy(copy,next_theme,width_logical-24)
	if measured.is_empty(): return false
	public_copy = copy
	theme = next_theme
	_paragraph = measured.paragraph
	_baselines = measured.baselines
	_text_height = measured.height
	custom_minimum_size = Vector2(width_logical,maxf(minimum_height_logical,_text_height+24))
	update_minimum_size()
	size = custom_minimum_size
	accessibility_name = copy
	queue_redraw()
	return true


## Shape once for both measurement and drawing; preserve full font size and every line.
static func measure_copy(copy: String, next_theme: Theme, width_logical: int) -> Dictionary:
	var shaped_copy: String = CHROME_BREAKS.get(copy,copy)
	var measured := _measure_text(shaped_copy,next_theme,width_logical)
	# Godot can include a discretionary hyphen beyond a very narrow line's width.
	# Preserve the existing adaptive layout when that optional decoration cannot fit.
	if measured.is_empty() and shaped_copy != copy:
		return _measure_text(copy,next_theme,width_logical)
	return measured


static func _measure_text(copy: String, next_theme: Theme, width_logical: int) -> Dictionary:
	if copy.strip_edges().is_empty() or next_theme == null or width_logical <= 0: return {}
	if next_theme.default_font == null or next_theme.default_font_size not in [20,25,30]: return {}
	var paragraph := TextParagraph.new()
	paragraph.width = width_logical
	paragraph.break_flags = BREAKS
	if not paragraph.add_string(copy,next_theme.default_font,next_theme.default_font_size): return {}
	var baselines := PackedFloat32Array()
	var height := 0.0
	for line: int in paragraph.get_line_count():
		if paragraph.get_line_width(line) > width_logical: return {}
		height += ceilf(paragraph.get_line_ascent(line)/2.0)*2.0
		baselines.append(height)
		height += ceilf(paragraph.get_line_descent(line)/2.0)*2.0
	return {"paragraph":paragraph,"baselines":baselines,"height":height}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: grab_focus()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed: grab_focus()
		accept_event()
	elif event.is_action("ui_accept"):
		# Confirm deliberately does nothing on an inspectable fact.
		accept_event()


func _draw() -> void:
	if _paragraph == null: return
	draw_rect(Rect2(Vector2.ZERO,size),_role(&"paper"))
	draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),_role(&"paper_structure"),false,2)
	var top: float = floorf((size.y-_text_height)/4.0)*2.0
	for line: int in _paragraph.get_line_count():
		_paragraph.draw_line(get_canvas_item(),Vector2(12,top+_baselines[line]-_paragraph.get_line_ascent(line)),line,_role(&"primary_paper_copy"))
	if has_focus():
		draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),_role(&"paper_focus_outer"),false,2)
		draw_rect(Rect2(Vector2(9,9),size-Vector2(18,18)),_role(&"paper_focus_inner"),false,2)


func _role(role: StringName) -> Color:
	return get_theme_color(role,&"Minesweeper")
