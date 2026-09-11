extends Control
## Fixed status bays consume public facts only; raw boards and metric operands never enter this control.

signal difficulty_requested(difficulty: StringName)

const BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const TEXT := preload("res://scripts/ui/minesweeper/MinesweeperSheetRow.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const COPY := preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")
const TIERS := ["beginner","intermediate","expert"]
const COMMON := ["mine_estimate","foresight","no_flag","custody"]
const DESKTOP := ["difficulty","rounds","difficulty_enabled"]

class Metric extends Control:
	var label_shape: Dictionary
	var value_shape: Dictionary
	var label_copy := ""
	var value_copy := ""
	var trailing_rule := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE

	func configure(label: String, value: String, next_theme: Theme, width: int) -> bool:
		var label_result: Dictionary = TEXT.measure_copy(label,next_theme,width-16)
		var tabular := next_theme.duplicate() as Theme
		var font := FontVariation.new()
		font.base_font = next_theme.default_font
		font.opentype_features = {"tnum":1}
		tabular.default_font = font
		var value_result: Dictionary = TEXT.measure_copy(value,tabular,width-16)
		if label_result.is_empty() or value_result.is_empty(): return false
		theme = next_theme
		label_shape = label_result
		value_shape = value_result
		label_copy = label
		value_copy = value
		custom_minimum_size = Vector2(width,label_result.height+value_result.height+16)
		size = custom_minimum_size
		accessibility_name = label+": "+value
		return true

	func _draw_shape(shape: Dictionary, y: float, color: Color) -> void:
		var paragraph: TextParagraph = shape.paragraph
		for line in paragraph.get_line_count():
			var x := floorf((size.x-paragraph.get_line_width(line))/4.0)*2.0
			paragraph.draw_line(get_canvas_item(),Vector2(x,y+shape.baselines[line]-paragraph.get_line_ascent(line)),line,color)

	func _draw() -> void:
		if label_shape.is_empty(): return
		draw_rect(Rect2(Vector2.ZERO,size),theme.get_color(&"controlled_face",&"Minesweeper"))
		var top := floorf((size.y-label_shape.height-value_shape.height-4)/4.0)*2.0
		_draw_shape(label_shape,top,theme.get_color(&"secondary_dark_copy",&"Minesweeper"))
		_draw_shape(value_shape,top+label_shape.height+4,theme.get_color(&"primary_dark_copy",&"Minesweeper"))
		var rule := theme.get_color(&"dark_registration",&"Minesweeper")
		draw_rect(Rect2(0,size.y-2,size.x,2),rule)
		if trailing_rule: draw_rect(Rect2(size.x-2,0,2,size.y),rule)

var difficulties: Dictionary = {}
var metrics: Dictionary = {}
var public_view: Dictionary = {}
var _host := "desktop_app"
var _locale := "en"
var _large := false

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

func configure(host: String = "desktop_app", locale: String = "en", percent: int = 100,
		large: bool = false, palette: StringName = &"after_hours",
		high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	if host not in ["desktop_app","canonical_solo","canonical_pair"]: return false
	var next_theme := MS_THEME.build(locale,percent,palette,high_contrast,colour_preset)
	if next_theme == null or (not public_view.is_empty() and (host == "desktop_app") != (_host == "desktop_app")): return false
	var measured: Dictionary = {}
	if not public_view.is_empty():
		measured = _compose(public_view,next_theme,host,locale,large)
		if measured.is_empty(): return false
	_host = host
	_locale = locale.replace("_","-")
	_large = large
	theme = next_theme
	if not measured.is_empty(): _install(measured)
	return true

func present(view: Dictionary) -> bool:
	if theme == null or not _valid(view): return false
	var measured := _compose(view,theme,_host,_locale,_large)
	if measured.is_empty(): return false
	public_view = view.duplicate(true)
	_install(measured)
	return true

func _valid(view: Dictionary) -> bool:
	var keys: Array = COMMON+DESKTOP if _host == "desktop_app" else COMMON
	if view.size() != keys.size(): return false
	for key: String in keys:
		if not view.has(key): return false
	for key: String in ["mine_estimate","foresight"]:
		if view[key] != null and typeof(view[key]) != TYPE_INT: return false
	if view.foresight != null and view.foresight < 0: return false
	if view.no_flag not in ["intact","lost"] or typeof(view.custody) != TYPE_BOOL: return false
	if _host != "desktop_app": return true
	if view.difficulty not in TIERS or typeof(view.rounds) != TYPE_INT or not view.difficulty_enabled is Array: return false
	var seen: Array = []
	for tier: Variant in view.difficulty_enabled:
		if typeof(tier) != TYPE_STRING or tier not in TIERS or tier in seen: return false
		seen.append(tier)
	return true

func _compose(view: Dictionary, next_theme: Theme, host: String, locale: String, large: bool) -> Dictionary:
	var copy := COPY.get_copy(locale)
	var candidate_buttons: Dictionary = {}
	var candidate_metrics: Dictionary = {}
	var height := 108 if large else 92
	if host == "desktop_app":
		for index in TIERS.size():
			var key: String = TIERS[index]
			var button: Button = BUTTON.new()
			if not button.configure(copy[key],next_theme,large,96):
				button.free()
				_free_candidates(candidate_buttons,candidate_metrics)
				return {}
			button.position.x = index*96
			button.present_state(key in view.difficulty_enabled,key == view.difficulty)
			button.accessibility_description = copy.selected if key == view.difficulty else ""
			candidate_buttons[key] = button
			height = maxi(height,int(button.custom_minimum_size.y)+44)
	var allocations: Array = [["rounds",144,56],["mine_estimate",200,72],["foresight",272,64],["no_flag",336,64]] if host == "desktop_app" else [["mine_estimate",280,72],["foresight",352,64],["no_flag",416,64]]
	for allocation: Array in allocations:
		var key: String = allocation[0]
		var value := ""
		match key:
			"rounds": value = str(view.rounds)+"/2"
			"no_flag": value = copy[view.no_flag]
			"foresight": value = "—" if view.foresight == null else str(view.foresight)+"%"
			"mine_estimate": value = "—" if view.mine_estimate == null else str(view.mine_estimate)
		var metric := Metric.new()
		if not metric.configure(copy[key],value,next_theme,allocation[2]*2):
			metric.free()
			_free_candidates(candidate_buttons,candidate_metrics)
			return {}
		metric.position.x = allocation[1]*2
		metric.trailing_rule = key != "no_flag"
		candidate_metrics[key] = metric
		height = maxi(height,int(metric.custom_minimum_size.y))
	return {"buttons":candidate_buttons,"metrics":candidate_metrics,"height":height}

func _free_candidates(buttons: Dictionary, fields: Dictionary) -> void:
	for child: Control in buttons.values()+fields.values(): child.free()

func _install(measured: Dictionary) -> void:
	var focused := ""
	for key: String in difficulties:
		if difficulties[key].has_focus(): focused = key
	for child: Control in difficulties.values()+metrics.values():
		remove_child(child)
		child.queue_free()
	difficulties = measured.buttons
	metrics = measured.metrics
	custom_minimum_size = Vector2(800 if _host == "desktop_app" else 960,measured.height)
	size = custom_minimum_size
	for key: String in difficulties:
		var button: Button = difficulties[key]
		button.position.y = floorf((size.y-button.custom_minimum_size.y)/4.0)*2.0
		add_child(button)
		button.pressed.connect(_request.bind(key))
	for metric: Control in metrics.values():
		metric.custom_minimum_size.y = size.y
		metric.size = metric.custom_minimum_size
		add_child(metric)
	if difficulties.has(focused) and not difficulties[focused].disabled: difficulties[focused].grab_focus()
	queue_redraw()

func _request(tier: String) -> void:
	if tier in public_view.difficulty_enabled and tier != public_view.difficulty:
		difficulty_requested.emit(StringName(tier))

func _draw() -> void:
	if theme == null or public_view.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),theme.get_color(&"controlled_face" if _host == "desktop_app" else &"habitat",&"Minesweeper"))
	# Canonical blank capacity has no field face, seam, label or node.
	var boundaries: Array = [48,96,144,200,272,336] if _host == "desktop_app" else []
	for x: int in boundaries:
		draw_rect(Rect2(x*2-2,0,2,size.y),theme.get_color(&"dark_registration",&"Minesweeper"))
	draw_rect(Rect2(0,size.y-2,size.x,2),theme.get_color(&"dark_registration",&"Minesweeper"))
