extends Control
## Inert renderer for one owner-published public cell. The future grid owns input and Focus.

const MINESWEEPER_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const KEYS := ["index","face","mark","number","bracketed","inspectable","pressable","actions"]
const MARKS := ["none","flag","mine","exploded","correct_flag","incorrect_flag","marked_mine","marked_flag"]
const ACTIONS := ["reveal","chord","flag","unflag","activate"]
const A11Y := {
	"en":{"none":"","flag":"Flag","mine":"Mine","exploded":"Exploded mine","correct_flag":"Correct flag","incorrect_flag":"Incorrect flag","marked_mine":"Marked mine","marked_flag":"Marked flag"},
	"zh-CN":{"none":"","flag":"旗帜","mine":"地雷","exploded":"爆炸的地雷","correct_flag":"正确旗帜","incorrect_flag":"错误旗帜","marked_mine":"标记地雷","marked_flag":"标记旗帜"},
	"zh-HK":{"none":"","flag":"旗幟","mine":"地雷","exploded":"爆炸的地雷","correct_flag":"正確旗幟","incorrect_flag":"錯誤旗幟","marked_mine":"標記地雷","marked_flag":"標記旗幟"},
}

var public_cell: Dictionary = {}
var focused := false
var hovered := false
var pressed := false
var _locale := "en"
var _large := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_resize()

func configure(locale: String = "en", percent: int = 100, large: bool = false, palette: StringName = &"after_hours",
		high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	locale = locale.replace("_","-")
	var candidate: Theme = MINESWEEPER_THEME.build(locale,percent,palette,high_contrast,colour_preset)
	if candidate == null: return false
	_locale = locale
	_large = large
	theme = candidate
	_resize()
	_update_accessibility()
	queue_redraw()
	return true

func present(cell: Dictionary) -> bool:
	if cell.size() != KEYS.size(): return false
	for key: String in KEYS:
		if not cell.has(key): return false
	if typeof(cell.index) != TYPE_INT or cell.index < 0 or typeof(cell.face) != TYPE_STRING or cell.face not in ["covered","revealed"]: return false
	if typeof(cell.mark) != TYPE_STRING or cell.mark not in MARKS or typeof(cell.number) != TYPE_INT or cell.number < 0 or cell.number > 8: return false
	for key: String in ["bracketed","inspectable","pressable"]:
		if typeof(cell[key]) != TYPE_BOOL: return false
	if typeof(cell.actions) != TYPE_ARRAY or cell.pressable != not cell.actions.is_empty(): return false
	var seen := {}
	for action: Variant in cell.actions:
		if typeof(action) != TYPE_STRING or action not in ACTIONS or seen.has(action): return false
		seen[action] = true
	if cell.pressable and not cell.inspectable: return false
	if not _valid_content(cell): return false
	public_cell = cell.duplicate(true)
	set_contact(focused,hovered,pressed)
	_update_accessibility()
	queue_redraw()
	return true

func set_contact(next_focused: bool, next_hovered: bool, next_pressed: bool) -> void:
	var inspectable: bool = public_cell.get("inspectable",false)
	var pressable: bool = public_cell.get("pressable",false)
	focused = next_focused and inspectable
	pressed = next_pressed and pressable
	hovered = next_hovered and inspectable and not pressed
	queue_redraw()

func _valid_content(cell: Dictionary) -> bool:
	var legal_sets: Array = []
	if cell.face == "covered":
		if cell.number != 0 or cell.mark in ["mine","exploded","marked_mine"]: return false
		if cell.bracketed and cell.mark not in ["none","flag"]: return false
		if cell.mark == "none": legal_sets = [[],["reveal"]] if cell.bracketed else [[],["reveal"],["reveal","flag"]]
		elif cell.mark == "flag": legal_sets = [[],["unflag"]]
		elif cell.mark == "marked_flag": legal_sets = [[],["activate"]]
		else: legal_sets = [[]]
	else:
		if cell.bracketed or cell.mark in ["flag","correct_flag","incorrect_flag","marked_flag"]: return false
		if cell.mark != "none" and cell.number != 0: return false
		if cell.mark == "none": legal_sets = [[],["chord"]] if cell.number > 0 else [[]]
		elif cell.mark == "marked_mine": legal_sets = [[],["activate"]]
		else: legal_sets = [[]]
	return cell.actions in legal_sets

func _resize() -> void:
	custom_minimum_size = Vector2.ONE*(64 if _large else 48)
	size = custom_minimum_size

func _update_accessibility() -> void:
	var facts: Array[String] = []
	if not public_cell.is_empty():
		if public_cell.number > 0: facts.append(str(public_cell.number))
		if public_cell.mark != "none": facts.append(A11Y[_locale][public_cell.mark])
	accessibility_name = ", ".join(facts)

func _draw() -> void:
	if public_cell.is_empty(): return
	var covered: bool = public_cell.face == "covered"
	var face: Color = _role(&"controlled_face") if covered else _role(&"paper")
	var structure: Color = _role(&"dark_registration") if covered else _role(&"paper_structure")
	draw_rect(Rect2(Vector2.ZERO,size),face)
	draw_rect(Rect2(Vector2.ZERO,size),structure,false,2)
	if covered: draw_rect(Rect2(2,size.y-4,size.x-4,2),_role(&"habitat"))
	_draw_public_mark(covered)
	if public_cell.bracketed: _draw_brackets(_aperture(),_role(&"dark_mark"))
	if pressed: draw_rect(Rect2(size.x-4,4,2,size.y-8),structure)
	elif hovered: draw_rect(Rect2(2,4,2,size.y-8),structure)
	if focused:
		var outer: Color = _role(&"dark_focus_outer") if covered else _role(&"paper_focus_outer")
		var inner: Color = _role(&"dark_focus_inner") if covered else _role(&"paper_focus_inner")
		draw_rect(Rect2(2,2,size.x-4,size.y-4),outer,false,2)
		draw_rect(Rect2(6,6,size.x-12,size.y-12),inner,false,2)

func _aperture() -> Rect2:
	return Rect2(16,16,32,32) if _large else Rect2(12,12,24,24)

func _draw_public_mark(covered: bool) -> void:
	var aperture := _aperture()
	var ink: Color = _role(&"dark_mark") if covered else _role(&"paper_mark")
	var separation: Color = _role(&"dark_separation") if covered else _role(&"paper")
	# These crisp shapes are provisional calibration inside the accepted aperture.
	match public_cell.mark:
		"flag","correct_flag","incorrect_flag","marked_flag": _draw_flag(aperture,ink,separation)
		"mine","exploded","marked_mine": _draw_mine(aperture,ink,public_cell.mark == "exploded")
	if public_cell.mark == "correct_flag": draw_rect(aperture.grow(-2),ink,false,2)
	elif public_cell.mark == "incorrect_flag":
		draw_line(aperture.position+Vector2(2,2),aperture.end-Vector2(2,2),ink,2)
		draw_line(Vector2(aperture.end.x-2,aperture.position.y+2),Vector2(aperture.position.x+2,aperture.end.y-2),ink,2)
	elif public_cell.mark in ["marked_mine","marked_flag"]:
		_draw_marked_frame(aperture,ink)
	if public_cell.number > 0:
		var text: String = str(public_cell.number)
		var font: Font = get_theme_default_font()
		var font_size: int = _numeral_font_size()
		var measure: Vector2 = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		var ascent: float = font.get_ascent(font_size)
		var descent: float = font.get_descent(font_size)
		var baseline: Vector2 = aperture.position+Vector2((aperture.size.x-measure.x)/2.0,(aperture.size.y-ascent-descent)/2.0+ascent)
		baseline = (baseline/2.0).round()*2.0
		# Source Han's numeral ink sits below its typographic centre. Lift one native pixel;
		# keep the complete 20/25/30 logical font size and the fixed aperture (GPU atlas proof).
		if _locale != "en": baseline.y -= 2
		draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)

func _numeral_font_size() -> int:
	return get_theme_default_font_size()

func _draw_flag(a: Rect2, ink: Color, separation: Color) -> void:
	var large: bool = a.size.x == 32
	var mast: Rect2 = Rect2(5,2,1,11) if large else Rect2(4,2,1,8)
	var pennant: PackedVector2Array
	if large:
		pennant = PackedVector2Array([Vector2(6,2),Vector2(13,5),Vector2(6,7)])
	else:
		pennant = PackedVector2Array([Vector2(5,2),Vector2(10,4),Vector2(5,6)])
	draw_rect(_native_rect(a,mast),ink)
	var positioned: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in pennant:
		positioned.append(a.position+point*2)
	draw_colored_polygon(positioned,ink)
	var cut_a: Vector2 = Vector2(6,3) if large else Vector2(5,3)
	var cut_b: Vector2 = Vector2(10,5) if large else Vector2(8,4)
	draw_line(a.position+cut_a*2,a.position+cut_b*2,separation,2)
	draw_rect(_native_rect(a,Rect2(3,13,7,1) if large else Rect2(2,10,7,1)),ink)

func _draw_mine(a: Rect2, ink: Color, exploded: bool) -> void:
	var n: int = 16 if a.size.x == 32 else 12
	var center: Vector2 = Vector2(n/2,n/2)
	draw_rect(_native_rect(a,Rect2(center-Vector2(2,2),Vector2(4,4))),ink)
	if exploded:
		for direction: Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(a.position+(center+direction*3)*2,a.position+(center+direction*(n/2-1))*2,ink,2)

func _draw_brackets(a: Rect2, ink: Color) -> void:
	var n: int = 16 if a.size.x == 32 else 12
	var arm: int = 4 if n == 16 else 3
	for corner: Vector2 in [Vector2(1,1),Vector2(n-1,1),Vector2(n-1,n-1),Vector2(1,n-1)]:
		var inward := Vector2(1 if corner.x == 1 else -1,1 if corner.y == 1 else -1)
		draw_line(a.position+corner*2,a.position+(corner+Vector2(inward.x*arm,0))*2,ink,2)
		draw_line(a.position+corner*2,a.position+(corner+Vector2(0,inward.y*arm))*2,ink,2)

func _draw_marked_frame(a: Rect2, ink: Color) -> void:
	var n: int = 16 if a.size.x == 32 else 12
	draw_rect(_native_rect(a,Rect2(1,1,n-2,n-2)),ink,false,2)
	draw_rect(_native_rect(a,Rect2(3,3,n-6,n-6)),ink,false,2)
	draw_rect(_native_rect(a,Rect2(n-4,1,3,2)),ink)

func _native_rect(aperture: Rect2, native: Rect2) -> Rect2:
	return Rect2(aperture.position+native.position*2,native.size*2)

func _role(role: StringName) -> Color:
	return get_theme_color(role,&"Minesweeper")
