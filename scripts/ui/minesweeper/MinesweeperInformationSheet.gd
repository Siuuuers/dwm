extends Control
## Ephemeral, read-only Rules/Assignments sheet. Claimed facts must be supplied by their owner.

signal return_requested()

const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const COPY := preload("res://scripts/ui/minesweeper/MinesweeperSheetCopy.gd")
const ROW := preload("res://scripts/ui/minesweeper/MinesweeperSheetRow.gd")
const RETURN := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const RAIL := preload("res://scripts/ui/minesweeper/MinesweeperScrollRail.gd")

var rows: Array[Control] = []
var body: Control
var document: Control
var return_button: Button
var rail: Control
var kind := ""
var _claims: Array = []
var _host := "desktop_app"
var _locale := "en"
var _large := false
var _band := Vector2i(400,246)
var _scroll := 0
var _extent := 0
var _page := 0
var _content: Control

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	clip_contents = true

func configure(host: String = "desktop_app", locale: String = "en", percent: int = 100,
		large: bool = false, palette: StringName = &"after_hours", native_band: Vector2i = Vector2i.ZERO) -> bool:
	if host not in ["desktop_app","canonical_solo","canonical_pair"]: return false
	if kind == "assignments" and host != "desktop_app": return false
	locale = locale.replace("_","-")
	var next_theme := MS_THEME.build(locale,percent,palette)
	var band := native_band
	if band == Vector2i.ZERO: band = Vector2i(400 if host == "desktop_app" else 480,232 if large else 246)
	if next_theme == null or band.x != (400 if host == "desktop_app" else 480) or band.y <= 0: return false
	var measured := _compose(next_theme,band,large,locale,"rules" if kind.is_empty() else kind,_claims)
	if measured.is_empty(): return false
	_host = host
	_locale = locale
	_large = large
	_band = band
	theme = next_theme
	custom_minimum_size = Vector2(band*2)
	size = custom_minimum_size
	if kind.is_empty(): _free_measured(measured)
	else: _install(measured,false)
	queue_redraw()
	return true

func present_rules() -> bool:
	return _present("rules",[])

func present_assignments(claimed: Array) -> bool:
	if _host != "desktop_app" or claimed.size() != 9: return false
	for status: Variant in claimed:
		if typeof(status) != TYPE_BOOL: return false
	return _present("assignments",claimed)

func _present(next_kind: String, claimed: Array) -> bool:
	if theme == null: return false
	var measured := _compose(theme,_band,_large,_locale,next_kind,claimed)
	if measured.is_empty(): return false
	var new_sheet: bool = kind != next_kind
	kind = next_kind
	_claims = claimed.duplicate()
	_install(measured,new_sheet)
	return true

func _compose(next_theme: Theme, band: Vector2i, large: bool, locale: String, next_kind: String, claimed: Array) -> Dictionary:
	var copy := COPY.get_copy(locale)
	var target := 32 if large else 24
	var button: Button = RETURN.new()
	if not button.configure(copy["return"],next_theme,large):
		button.free()
		return {}
	var heading_height := maxi(target,ceili((next_theme.default_font.get_height(next_theme.default_font_size)+8)/2.0))
	var footer_height := int(button.custom_minimum_size.y/2)+8
	var body_top := 8+heading_height+4
	var footer_top := band.y-8-footer_height
	var page := footer_top-4-body_top
	var row_width := (band.x-16)*2
	var text_rows: Array = copy.facts.duplicate() if next_kind == "rules" else []
	if next_kind == "assignments":
		for index in 9:
			text_rows.append(copy.requirements[index]+" — "+copy.claimed if claimed[index] else copy.requirements[index]+" — "+copy.unclaimed)
	var measured_rows: Array[Control] = []
	var extent := 0
	for text_value: String in text_rows:
		var row: Control = ROW.new()
		if not row.configure(text_value,next_theme,row_width,target*2):
			row.free()
			for prior: Control in measured_rows: prior.free()
			button.free()
			return {}
		measured_rows.append(row)
		extent += int(row.custom_minimum_size.y/2)
	var overflow := extent > page
	if overflow:
		row_width -= target*2
		extent = 0
		for index in measured_rows.size():
			measured_rows[index].configure(text_rows[index],next_theme,row_width,target*2)
			extent += int(measured_rows[index].custom_minimum_size.y/2)
	var result := {"rows":measured_rows,"button":button,"title":copy[next_kind],"heading":heading_height,
		"body_top":body_top,"footer_top":footer_top,"page":page,"extent":extent,"row_width":row_width,"overflow":overflow}
	for row: Control in measured_rows:
		if page < target or row.custom_minimum_size.y > page*2:
			_free_measured(result)
			return {}
	return result

func _free_measured(measured: Dictionary) -> void:
	for row: Control in measured.rows: row.free()
	measured.button.free()

func _install(measured: Dictionary, reset: bool) -> void:
	var prior_focus: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_index := rows.find(prior_focus)
	var return_focused := return_button != null and prior_focus == return_button
	if _content != null:
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.size = size
	add_child(_content)
	var heading := Label.new()
	heading.text = measured.title
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.position = Vector2(16,16)
	heading.size = Vector2((_band.x-16)*2,measured.heading*2)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color",theme.get_color(&"primary_paper_copy",&"Minesweeper"))
	_content.add_child(heading)
	accessibility_name = measured.title
	body = Control.new()
	body.position = Vector2(16,measured.body_top*2)
	body.size = Vector2(measured.row_width,measured.page*2)
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(body)
	document = Control.new()
	document.mouse_filter = Control.MOUSE_FILTER_PASS
	document.size = Vector2(measured.row_width,measured.extent*2)
	body.add_child(document)
	rows = measured.rows
	var y := 0.0
	for index in rows.size():
		var row := rows[index]
		row.position = Vector2(0,y)
		document.add_child(row)
		y += row.custom_minimum_size.y
		row.focus_entered.connect(_reveal_row.bind(index))
	return_button = measured.button
	return_button.position = Vector2((_band.x-72)*2,(measured.footer_top+4)*2)
	_content.add_child(return_button)
	return_button.pressed.connect(func(): return_requested.emit())
	_extent = measured.extent
	_page = measured.page
	_scroll = 0 if reset else clampi(_scroll,0,maxi(0,_extent-_page))
	rail = null
	if measured.overflow:
		rail = RAIL.new()
		_content.add_child(rail)
		var paper_theme := theme.duplicate() as Theme
		for pair: Array in [[&"controlled_face",&"paper"],[&"dark_registration",&"paper_structure"],[&"dark_scroll_thumb",&"paper_scroll_thumb"],[&"dark_separation",&"paper_structure"],[&"dark_focus_outer",&"paper_focus_outer"],[&"dark_focus_inner",&"paper_focus_inner"]]:
			paper_theme.set_color(pair[0],&"Minesweeper",theme.get_color(pair[1],&"Minesweeper"))
		rail.configure(true,_locale,paper_theme)
		rail.scroll_requested.connect(set_scroll)
	_update_scroll()
	var focus_order: Array[Control] = rows.duplicate()
	if rail != null: focus_order.append(rail)
	focus_order.append(return_button)
	for index in focus_order.size():
		var control := focus_order[index]
		control.focus_previous = control.get_path_to(focus_order[posmod(index-1,focus_order.size())])
		control.focus_next = control.get_path_to(focus_order[(index+1)%focus_order.size()])
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next
		control.focus_neighbor_left = control.get_path_to(control)
		control.focus_neighbor_right = control.get_path_to(control)
	if is_inside_tree() and is_visible_in_tree():
		if not reset and return_focused: return_button.grab_focus()
		else: rows[maxi(0,focus_index) if not reset else 0].grab_focus()
	queue_redraw()

func get_scroll() -> int:
	return _scroll

func set_scroll(value: int) -> void:
	if document == null: return
	_scroll = clampi(value,0,maxi(0,_extent-_page))
	_update_scroll()

func _update_scroll() -> void:
	document.position.y = -_scroll*2
	if rail == null: return
	var target := 32 if _large else 24
	var rect := Rect2i(_band.x-8-target,int(body.position.y/2),target,_page)
	var length := maxi(target,floori(float(_page*_page)/_extent))
	var leading := floori(float((_page-length)*_scroll)/(_extent-_page))
	var thumb := Rect2i(rect.position+Vector2i(0,leading),Vector2i(target,length))
	rail.present({"rect":rect,"thumb":thumb},_extent-_page,_scroll,_page,true)

func _reveal_row(index: int) -> void:
	var row := rows[index]
	var leading := int(row.position.y/2)
	var trailing := int((row.position.y+row.size.y)/2)
	if leading < _scroll: set_scroll(leading)
	elif trailing > _scroll+_page: set_scroll(trailing-_page)

func _gui_input(event: InputEvent) -> void:
	if body == null or not event is InputEventMouseButton or not event.pressed: return
	if not Rect2(body.position,body.size).has_point(event.position): return
	var step := 32 if _large else 24
	if event.button_index == MOUSE_BUTTON_WHEEL_UP: set_scroll(_scroll-step)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: set_scroll(_scroll+step)
	else: return
	accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or kind.is_empty() or not event.is_pressed(): return
	if event is InputEventKey and event.echo: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not is_ancestor_of(focus): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return_requested.emit()
	elif event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down"):
		set_scroll(_scroll+(-_page if event.is_action_pressed("ui_page_up") else _page))
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if theme != null: draw_rect(Rect2(Vector2.ZERO,size),theme.get_color(&"paper",&"Minesweeper"))
