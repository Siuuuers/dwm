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

	## Shaping is the fallible half and changes nothing; a refused composition leaves
	## every retained bay exactly as the last accepted one left it.
	func measure(label: String, value: String, next_theme: Theme, width: int) -> Dictionary:
		var label_result: Dictionary = TEXT.measure_copy(label,next_theme,width-16)
		var tabular := next_theme.duplicate() as Theme
		var font := FontVariation.new()
		font.base_font = next_theme.default_font
		font.opentype_features = {"tnum":1}
		tabular.default_font = font
		var value_result: Dictionary = TEXT.measure_copy(value,tabular,width-16)
		if label_result.is_empty() or value_result.is_empty(): return {}
		return {"label":label,"value":value,"theme":next_theme,"width":width,
			"label_shape":label_result,"value_shape":value_result,
			"height":label_result.height+value_result.height+16}

	func apply(measured: Dictionary) -> void:
		theme = measured.theme
		label_shape = measured.label_shape
		value_shape = measured.value_shape
		label_copy = measured.label
		value_copy = measured.value
		custom_minimum_size = Vector2(measured.width,measured.height)
		size = custom_minimum_size
		accessibility_name = label_copy+": "+value_copy
		queue_redraw()

	func content_height() -> float:
		return label_shape.height+value_shape.height+16

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

var _scene_presentation := false
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
		high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel", day: int = 1) -> bool:
	return _configure_context(host, locale, percent, large, palette, high_contrast, colour_preset, font_style, day, false)

func configure_scene(host: String = "desktop_app", locale: String = "en", percent: int = 100, large: bool = false, palette: StringName = &"after_hours", high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> bool:
	return _configure_context(host, locale, percent, large, palette, high_contrast, colour_preset, font_style, null, true)

func _configure_context(host: String = "desktop_app", locale: String = "en", percent: int = 100, large: bool = false, palette: StringName = &"after_hours", high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel", day: Variant = 1, scene: bool = false) -> bool:
	if _scene_presentation and not scene: return false
	if host not in ["desktop_app","canonical_solo","canonical_pair"]: return false
	var next_theme := MS_THEME._build_context(locale,percent,palette,high_contrast,colour_preset,font_style,day, scene)
	if next_theme == null or (not public_view.is_empty() and (host == "desktop_app") != (_host == "desktop_app")): return false
	var measured: Dictionary = {}
	if not public_view.is_empty():
		measured = _compose(public_view,next_theme,host,locale,large)
		if measured.is_empty(): return false
	_host = host
	_locale = locale.replace("_","-")
	_large = large
	_scene_presentation = scene
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

## Plans the whole composition without mutating a single installed bay: retained nodes are
## reused, and only a changed theme, scale or copy costs a rebuilt button or a reshaped metric.
func _compose(view: Dictionary, next_theme: Theme, host: String, locale: String, large: bool) -> Dictionary:
	var copy := COPY.get_copy(locale)
	var candidate_buttons: Dictionary = {}
	var candidate_metrics: Dictionary = {}
	var height := 72 if large else 56
	var stacked := false
	var tier_band := 480
	var responsive_allocations: Array = []
	if host == "desktop_app":
		if metrics.has("rounds") and metrics.rounds.theme == next_theme:
			stacked = metrics.rounds.position.y > 0
			tier_band = int(metrics.rounds.position.x) if not stacked else 800
		else:
			var minimum_width := 0
			for key: String in TIERS:
				minimum_width += BUTTON.single_line_width(copy[key],next_theme,large)
			var status_widths: Array[int] = []
			for key: String in ["rounds","mine_estimate"]:
				var label: String = COPY.COMPACT_METRICS.get(locale.replace("_","-"),{}).get(key,copy[key])
				var measured := TEXT.measure_copy(label,next_theme,784)
				if measured.is_empty() or measured.paragraph.get_line_count() != 1: return {}
				var width := int(ceilf((measured.paragraph.get_line_width(0)+16)/2.0))*2
				status_widths.append(width)
				minimum_width += width
			stacked = minimum_width > 800
			if not stacked and status_widths[0]+status_widths[1] > 320:
				tier_band = 800-status_widths[0]-status_widths[1]
				responsive_allocations = [["rounds",tier_band/2,status_widths[0]/2],
					["mine_estimate",(tier_band+status_widths[0])/2,status_widths[1]/2]]
		var widths: Array[int] = []
		if large == _large:
			for key: String in TIERS:
				var button: Button = difficulties.get(key)
				if button == null or button.theme != next_theme or button.public_copy != copy[key]:
					widths.clear()
					break
				widths.append(int(button.custom_minimum_size.x))
		if stacked:
			widths.assign([266,268,266])
		elif widths.is_empty():
			widths.assign([160,160,160])
			var minimums: Array[int] = []
			var excess := 480-tier_band
			for index in TIERS.size():
				var minimum := BUTTON.single_line_width(copy[TIERS[index]],next_theme,large)
				if minimum == 0: return {}
				minimums.append(minimum)
				widths[index] = maxi(160,minimum)
				excess += widths[index]-160
			# Keep the authored bays unless a label needs room; borrow only spare width.
			while excess > 0:
				var reduced := false
				for index in TIERS.size():
					if excess == 0: break
					if widths[index]-2 >= minimums[index]:
						widths[index] -= 2
						excess -= 2
						reduced = true
				if not reduced: return {}
		var left := 0
		for index in TIERS.size():
			var key: String = TIERS[index]
			var button: Button = difficulties.get(key)
			if button == null or button.theme != next_theme or button.public_copy != copy[key] or large != _large \
					or int(button.custom_minimum_size.x) != widths[index]:
				button = BUTTON.new()
				if not button.configure(copy[key],next_theme,large,widths[index]):
					button.free()
					_free_candidates(candidate_buttons,candidate_metrics)
					return {}
			candidate_buttons[key] = {"node":button,"x":left,
				"enabled":key in view.difficulty_enabled,"selected":key == view.difficulty,
				"description":copy.selected if key == view.difficulty else ""}
			left += widths[index]
			height = maxi(height,int(button.custom_minimum_size.y)+8)
	var status_y := height if stacked else 0
	var allocations: Array = [["rounds",0,200],["mine_estimate",200,200]] if stacked else _status_allocations(next_theme,host,locale,copy)
	if not responsive_allocations.is_empty(): allocations = responsive_allocations
	for allocation: Array in allocations:
		var key: String = allocation[0]
		var value := ""
		match key:
			"rounds": value = str(view.rounds)+"/2"
			"mine_estimate": value = "—" if view.mine_estimate == null else str(view.mine_estimate)
		var width: int = allocation[2]*2
		var label: String = COPY.COMPACT_METRICS.get(locale.replace("_","-"),{}).get(key,copy[key])
		var metric: Metric = metrics.get(key)
		var retained: bool = metric != null and metric.theme == next_theme and metric.label_copy == label \
			and metric.value_copy == value and int(metric.custom_minimum_size.x) == width
		if metric == null: metric = Metric.new()
		var measured: Dictionary = {} if retained else metric.measure(label,value,next_theme,width)
		if not retained and measured.is_empty():
			if not metrics.has(key): metric.free()
			_free_candidates(candidate_buttons,candidate_metrics)
			return {}
		candidate_metrics[key] = {"node":metric,"measured":measured,"x":allocation[1]*2,"trailing_rule":key != "mine_estimate", "accessible_name":copy[key]+": "+value}
		height = maxi(height,status_y+int(metric.content_height() if retained else measured.height))
	return {"buttons":candidate_buttons,"metrics":candidate_metrics,"height":height,"status_y":status_y}

## Keep the status block fixed; extra heading width comes from its spare capacity.
func _status_allocations(next_theme: Theme, host: String, locale: String, copy: Dictionary) -> Array:
	var allocations: Array = [["rounds",240,72],["mine_estimate",312,88]] if host == "desktop_app" else [["mine_estimate",392,88]]
	var labels: Dictionary = {}
	var retained := true
	for allocation: Array in allocations:
		var key: String = allocation[0]
		labels[key] = COPY.COMPACT_METRICS.get(locale.replace("_","-"),{}).get(key,copy[key])
		var metric: Metric = metrics.get(key)
		if metric == null or metric.theme != next_theme or metric.label_copy != labels[key]: retained = false
	if retained:
		for allocation: Array in allocations:
			var metric: Metric = metrics[allocation[0]]
			allocation[1] = int(metric.position.x/2.0)
			allocation[2] = int(metric.custom_minimum_size.x/2.0)
		return allocations
	var measured := TEXT.measure_copy(labels.mine_estimate,next_theme,304)
	if measured.is_empty() or measured.paragraph.get_line_count() != 1: return allocations
	var width := maxi(176,int(ceilf((measured.paragraph.get_line_width(0)+16)/2.0))*2)
	if width == 176: return allocations
	var half_width := int(width/2.0)
	if host == "desktop_app":
		var rounds := TEXT.measure_copy(labels.rounds,next_theme,320-width-16)
		if rounds.is_empty() or rounds.paragraph.get_line_count() != 1: return allocations
		return [["rounds",240,160-half_width],["mine_estimate",400-half_width,half_width]]
	return [["mine_estimate",480-half_width,half_width]]

func _free_candidates(buttons: Dictionary, fields: Dictionary) -> void:
	for key: String in buttons:
		if not is_same(difficulties.get(key),buttons[key].node): buttons[key].node.free()
	for key: String in fields:
		if not is_same(metrics.get(key),fields[key].node): fields[key].node.free()

func _install(measured: Dictionary) -> void:
	var focused := ""
	for key: String in difficulties:
		if difficulties[key].has_focus(): focused = key
	var buttons: Dictionary = {}
	var fields: Dictionary = {}
	for key: String in measured.buttons: buttons[key] = measured.buttons[key].node
	for key: String in measured.metrics: fields[key] = measured.metrics[key].node
	for child: Control in difficulties.values()+metrics.values():
		if child in buttons.values() or child in fields.values(): continue
		remove_child(child)
		child.queue_free()
	difficulties = buttons
	metrics = fields
	custom_minimum_size = Vector2(800 if _host == "desktop_app" else 960,measured.height)
	size = custom_minimum_size
	for key: String in measured.buttons:
		var plan: Dictionary = measured.buttons[key]
		var button: Button = plan.node
		var button_band: float = measured.status_y if measured.status_y > 0 else size.y
		button.position = Vector2(plan.x,floorf((button_band-button.custom_minimum_size.y)/4.0)*2.0)
		button.present_state(plan.enabled,plan.selected)
		button.accessibility_description = plan.description
		if button.get_parent() == null:
			add_child(button)
			button.pressed.connect(_request.bind(key))
	for key: String in measured.metrics:
		var plan: Dictionary = measured.metrics[key]
		var metric: Metric = plan.node
		if not plan.measured.is_empty(): metric.apply(plan.measured)
		metric.accessibility_name = plan.accessible_name
		metric.position = Vector2(plan.x,measured.status_y)
		metric.trailing_rule = plan.trailing_rule
		metric.custom_minimum_size.y = size.y-measured.status_y
		metric.size = metric.custom_minimum_size
		if metric.get_parent() == null: add_child(metric)
	if difficulties.has(focused) and not difficulties[focused].disabled: difficulties[focused].grab_focus()
	queue_redraw()

func _request(tier: String) -> void:
	if tier in public_view.difficulty_enabled:
		difficulty_requested.emit(StringName(tier))

func _draw() -> void:
	if theme == null or public_view.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),theme.get_color(&"controlled_face" if _host == "desktop_app" else &"habitat",&"Minesweeper"))
	# Canonical blank capacity has no field face, seam, label or node.
	if _host == "desktop_app":
		var status_y: float = metrics.rounds.position.y
		var button_band: float = status_y if status_y > 0 else size.y
		for key: String in TIERS:
			var x: float = difficulties[key].position.x+difficulties[key].size.x
			draw_rect(Rect2(x-2,0,2,button_band),theme.get_color(&"dark_registration",&"Minesweeper"))
		draw_rect(Rect2(metrics.mine_estimate.position.x-2,status_y,2,size.y-status_y),theme.get_color(&"dark_registration",&"Minesweeper"))
		if status_y > 0:
			draw_rect(Rect2(0,status_y-2,size.x,2),theme.get_color(&"dark_registration",&"Minesweeper"))
	draw_rect(Rect2(0,size.y-2,size.x,2),theme.get_color(&"dark_registration",&"Minesweeper"))
