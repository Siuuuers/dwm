extends Control
## Mounted paper composition at exactly 2 logical pixels per native design pixel.
## Receives public names/art and opaque command keys; owns no gameplay state.

signal source_requested(source_id: String)
signal move_requested(entry_id: String, target_index: int)
signal remove_requested(entry_id: String)
signal done_requested
signal status_announced(refusal_id: String)

const KEY := preload("res://scripts/ui/schedule/SchedulePaperButton.gd")
const WELL := preload("res://scripts/ui/schedule/ScheduleScrollWell.gd")
const DOCKET_LANE := preload("res://scripts/ui/schedule/ScheduleDocketLane.gd")
const PALETTE := preload("res://scripts/ui/schedule/ScheduleTheme.gd")
const FOCUS_RAIL := preload("res://scripts/ui/schedule/ScheduleFocusRail.gd")
const FONTS := {
	"en": preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2"),
	"zh-CN": preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf"),
	"zh-HK": preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf"),
}
const COPY := {
	"en": ["Available", "Earlier", "Later", "Remove", "Done", "Unavailable"],
	"zh-CN": ["可选", "提前", "延后", "移除", "完成", "不可用"],
	"zh-HK": ["可選", "提前", "延後", "移除", "完成", "不可用"],
}
const MOTIVATION_REFUSAL := {
	"en": "Not enough Motivation.",
	"zh-CN": "动力不足。",
	"zh-HK": "動力不足。",
}
const BREAKS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE

var source_buttons: Dictionary = {}
var entry_buttons: Dictionary = {}
var commands: Dictionary = {}
var available_scroll: ScrollContainer
var docket_scroll: ScrollContainer
var done_button: Button
var selected_id := ""
var _projection: Dictionary = {}
var _locale := "en"
var _font_size := 20
var _large := false
var _home: Button
var _folio: Control
var _source_body: Control
var _docket_body: Control
var _done_enabled := false
var _drag_entry_id := ""
var _projection_revision := 0
var _refusal_id := ""
var _refusal_code: StringName = &""
var _status_nodes: Array[Node] = []
var _last_announced_refusal_id := ""
var _source_rows: Array[Dictionary] = []
var _docket_rows: Array[Dictionary] = []
var _pending_anchors: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(800,656)
	size = custom_minimum_size
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	clip_contents = true
	set_process_unhandled_input(false)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_drag()
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var direction := int(event.is_action_pressed("ui_page_down")) - int(event.is_action_pressed("ui_page_up"))
	if direction == 0: return
	var focused := get_viewport().gui_get_focus_owner()
	var owner: ScrollContainer = null
	for scroll: ScrollContainer in [available_scroll,docket_scroll]:
		if is_instance_valid(scroll) and focused != null and scroll.is_ancestor_of(focused): owner = scroll
	if owner == null: return
	# Page commands never become selection, reordering or focus navigation.
	get_viewport().set_input_as_handled()
	if not is_dragging(): owner.scroll_vertical += direction * int(owner.size.y)

func configure(locale: String = "en", percent: int = 100, large_targets: bool = false,
		palette: StringName = &"after_hours", day: int = 1,
		high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	locale = locale.replace("_","-")
	if locale not in FONTS or percent not in [100,125,150]: return false
	var next_theme: Theme = PALETTE.build(palette, day, high_contrast, colour_preset)
	if next_theme == null: return false
	_locale = locale
	_font_size = 20 * percent / 100
	_large = large_targets
	theme = next_theme
	theme.default_font = FONTS[locale]
	theme.default_font_size = _font_size
	if not _refusal_id.is_empty() and is_instance_valid(done_button): _rebuild_status()
	return true

func configure_home(home: Button) -> void:
	_home = home
	_wire_focus()

func set_done_enabled(enabled: bool) -> void:
	_done_enabled = enabled
	if is_instance_valid(done_button):
		done_button.cancel_contact()
		done_button.disabled = not enabled
		done_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		_wire_focus()

func set_refusal_status(refusal_id: String, code: StringName = &"") -> void:
	if refusal_id.is_empty() or refusal_id == _refusal_id: return
	_refusal_id = refusal_id
	_refusal_code = code
	_rebuild_status(refusal_id != _last_announced_refusal_id)
	if refusal_id != _last_announced_refusal_id:
		_last_announced_refusal_id = refusal_id
		status_announced.emit(refusal_id)

func clear_status() -> void:
	_refusal_id = ""
	_refusal_code = &""
	_clear_status_nodes()

func set_projection(value: Dictionary, inspection: String = "", focus_key: String = "", preserve_scroll: bool = false) -> bool:
	if typeof(value.get("day_seven")) != TYPE_BOOL or typeof(value.get("sources")) != TYPE_ARRAY or typeof(value.get("entries")) != TYPE_ARRAY:
		return false
	if value.entries.size() > (1 if value.day_seven else 7): return false
	var seen_sources := {}
	for source: Variant in value.sources:
		if typeof(source) != TYPE_DICTIONARY or not _valid_name(source) or typeof(source.get("available")) != TYPE_BOOL:
			return false
		if seen_sources.has(source.id) or not _valid_art(source.get("compact"),24) or not _valid_art(source.get("folio"),64): return false
		if not _fits_folio(source.name,value.day_seven): return false
		seen_sources[source.id] = true
	var seen_entries := {}
	for entry: Variant in value.entries:
		if typeof(entry) != TYPE_DICTIONARY or not _valid_name(entry) or typeof(entry.get("source_id")) != TYPE_STRING:
			return false
		if seen_entries.has(entry.id) or not _valid_art(entry.get("folio"),64): return false
		# Keep the registered 64px art intact inside the fixed folio document field.
		if not _fits_folio(entry.name,value.day_seven): return false
		seen_entries[entry.id] = true
	# A second projection must not capture temporary zero offsets before the
	# preceding same-frame reconstruction has settled.
	var source_anchor: Dictionary = _pending_anchors[0] if not _pending_anchors.is_empty() else _capture_anchor(_source_rows,available_scroll)
	var docket_anchor: Dictionary = _pending_anchors[1] if not _pending_anchors.is_empty() else _capture_anchor(_docket_rows,docket_scroll)
	_pending_anchors = [source_anchor,docket_anchor]
	cancel_drag()
	_projection_revision += 1
	_projection = value.duplicate(true)
	selected_id = inspection if seen_entries.has(inspection) else ""
	if value.day_seven and not value.entries.is_empty(): selected_id = value.entries[0].id
	cancel_contacts()
	for child in get_children():
		if child is Button and child.has_method("cancel_contact"): child.cancel_contact()
		remove_child(child)
		child.queue_free()
	source_buttons.clear()
	entry_buttons.clear()
	commands.clear()
	_status_nodes.clear()
	_source_rows.clear()
	_docket_rows.clear()
	_build()
	var revision: int = _projection_revision
	if preserve_scroll and focus_key != "": _restore_focus.call_deferred(revision,focus_key)
	_restore_anchors.call_deferred(revision,source_anchor,docket_anchor)
	if not preserve_scroll and focus_key != "": _restore_focus.call_deferred(revision,focus_key)
	return true

func _restore_focus(revision: int, focus_key: String) -> void:
	if revision == _projection_revision: focus_target(focus_key)

func clear_scroll_anchors() -> void:
	_projection_revision += 1
	_pending_anchors.clear()
	if is_instance_valid(available_scroll): available_scroll.scroll_vertical = 0
	if is_instance_valid(docket_scroll): docket_scroll.scroll_vertical = 0

func _capture_anchor(rows: Array[Dictionary], scroll: ScrollContainer) -> Dictionary:
	if rows.is_empty() or not is_instance_valid(scroll): return {}
	var offset: int = scroll.scroll_vertical
	var ordinal := 0
	for index in rows.size():
		if rows[index].y <= offset: ordinal = index
		else: break
	return {"key":rows[ordinal].key,"ordinal":ordinal,"delta":offset-int(rows[ordinal].y)}

func _restore_anchors(revision: int, source_anchor: Dictionary, docket_anchor: Dictionary) -> void:
	if revision != _projection_revision: return
	_restore_anchor(_source_rows,available_scroll,source_anchor)
	_restore_anchor(_docket_rows,docket_scroll,docket_anchor)
	_pending_anchors.clear()

func _restore_anchor(rows: Array[Dictionary], scroll: ScrollContainer, anchor: Dictionary) -> void:
	if rows.is_empty() or not is_instance_valid(scroll) or anchor.is_empty():
		if is_instance_valid(scroll): scroll.scroll_vertical = 0
		return
	var ordinal: int = clampi(int(anchor.ordinal),0,rows.size()-1)
	for index in rows.size():
		if rows[index].key == anchor.key:
			ordinal = index
			break
	var minimum_delta: int = -int(rows[ordinal].y) if ordinal == 0 else 0
	var delta: int = clampi(int(anchor.delta),minimum_delta,maxi(0,int(rows[ordinal].span)-1))
	var body: Control = _source_body if scroll == available_scroll else _docket_body
	var maximum: int = maxi(0,int(body.custom_minimum_size.y-scroll.size.y))
	scroll.scroll_vertical = clampi(int(rows[ordinal].y)+delta,0,maximum)

func focus_target(key: String = "") -> void:
	var target: Control = null
	if key.begins_with("source:"): target = source_buttons.get(key.substr(7))
	elif key.begins_with("entry:"): target = entry_buttons.get(key.substr(6))
	elif key == "done": target = done_button
	elif key == "home": target = _home
	elif commands.has(key): target = commands[key]
	if target == null or not target.is_visible_in_tree() or target.focus_mode != Control.FOCUS_ALL:
		var nodes := _targets()
		if not nodes.is_empty(): target = nodes[0]
	if is_instance_valid(target) and target.is_visible_in_tree() and target.focus_mode == Control.FOCUS_ALL: target.grab_focus()

func cancel_contacts() -> void:
	for button in source_buttons.values() + entry_buttons.values() + commands.values() + [done_button]:
		if is_instance_valid(button): button.cancel_contact()

func is_dragging() -> bool:
	return not _drag_entry_id.is_empty()

func cancel_drag() -> void:
	if is_instance_valid(_docket_body) and _docket_body.has_method("clear_witness"):
		_docket_body.clear_witness()
	_drag_entry_id = ""
	var viewport := get_viewport()
	if is_instance_valid(viewport) and viewport.gui_is_dragging():
		var data: Variant = viewport.gui_get_drag_data()
		if typeof(data) == TYPE_DICTIONARY and data.get("panel") == get_instance_id():
			viewport.gui_cancel_drag()

func accepts_docket_drag(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or _projection.get("day_seven",true): return false
	if data.get("kind") != "schedule_docket_occurrence" or data.get("panel") != get_instance_id(): return false
	if data.get("revision") != _projection_revision or data.get("entry_id") != _drag_entry_id: return false
	return _entry_index(_drag_entry_id) >= 0

func drop_docket_drag(data: Variant, boundary: int) -> void:
	if not accepts_docket_drag(data):
		cancel_drag()
		return
	var old_index := _entry_index(_drag_entry_id)
	var count: int = _projection.entries.size()
	if boundary < 0 or boundary > count:
		cancel_drag()
		return
	var final_ordinal := boundary if boundary <= old_index else boundary-1
	var moved_id := _drag_entry_id
	_drag_entry_id = ""
	if is_instance_valid(_docket_body): _docket_body.clear_witness()
	if final_ordinal != old_index:
		move_requested.emit(moved_id,final_ordinal)

func _begin_docket_drag(entry_id: String) -> Variant:
	if _projection.get("day_seven",true) or _entry_index(entry_id) < 0: return null
	_drag_entry_id = entry_id
	return {"kind":"schedule_docket_occurrence", "panel":get_instance_id(), "revision":_projection_revision, "entry_id":entry_id}

func _finish_docket_drag() -> void:
	if is_instance_valid(_docket_body): _docket_body.clear_witness()
	_drag_entry_id = ""

func _entry_index(entry_id: String) -> int:
	for index in _projection.get("entries",[]).size():
		if _projection.entries[index].id == entry_id: return index
	return -1

func _build() -> void:
	_paper(self,Rect2(0,0,800,656),"habitat")
	_paper(self,Rect2(16,16,250,548))
	_paper(self,Rect2(278,16,506,548))
	_label(self,COPY[_locale][0],Rect2(32,32,218,48))
	_paper(self,Rect2(32,78,218,2),"paper_ink")
	available_scroll = _scroll(Rect2(32,88,218,460))
	_source_body = _body(available_scroll,Vector2(218,460))
	var y := 8.0
	for source: Dictionary in _projection.sources:
		var label_h := _height(source.name,112)
		var status_h := 0.0 if source.available else _height(COPY[_locale][5],112)+4
		var height := 16 + maxf(64 if _large else 48,label_h+status_h)
		_source_rows.append({"key":"source:"+source.id,"y":y,"span":height+8})
		var key := _key(_source_body,Rect2(8,y,202,height),"source",source.available)
		key.name = "Source_%d" % source_buttons.size()
		key.unavailable = not source.available
		key.selected = _projection.day_seven and not _projection.entries.is_empty() and _projection.entries[0].source_id == source.id
		key.accessibility_name = source.name + (". " + COPY[_locale][5] if not source.available else "")
		_art(key,source.compact,Vector2(8,8),48)
		_label(key,source.name,Rect2(64,8,112,label_h))
		if not source.available: _label(key,COPY[_locale][5],Rect2(64,12+label_h,112,status_h-4))
		key.pressed.connect(func(): source_requested.emit(source.id))
		source_buttons[source.id] = key
		y += height + 8
	_source_body.custom_minimum_size.y = maxf(460,y)
	_well(available_scroll,Rect2(250,88,16,460))
	docket_scroll = _scroll(Rect2(294,32,474,516))
	_docket_body = DOCKET_LANE.new()
	_docket_body.custom_minimum_size = Vector2(474,516)
	_docket_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_docket_body.drag_owner = self
	docket_scroll.add_child(_docket_body)
	_folio = Control.new()
	_folio.position = Vector2(204,0)
	_folio.size = Vector2(270,516)
	_folio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_docket_body.add_child(_folio)
	y = 0
	var filled_geometry: Array[Vector2] = []
	var count: int = _projection.entries.size() if _projection.day_seven else 7
	for index in count:
		if index >= _projection.entries.size():
			var empty_h := 80 if _large else 64
			_docket_rows.append({"key":"slot:"+str(index),"y":y,"span":empty_h+8})
			_label(_docket_body,str(index+1),Rect2(8,y,24,empty_h))
			_paper(_docket_body,Rect2(40,y+empty_h/2,144,2),"paper_ink")
			y += empty_h+8
			continue
		var entry: Dictionary = _projection.entries[index]
		var name_width := 160 if _projection.day_seven else (72 if _large else 88)
		var label_h := _height(entry.name,name_width)
		var height := 16 + maxf(64 if _large else 48,label_h)
		_docket_rows.append({"key":"entry:"+entry.id,"y":y,"span":height+8})
		var key := _key(_docket_body,Rect2(8,y,176,height),"day7" if _projection.day_seven else "entry")
		key.selected = entry.id == selected_id and not _projection.day_seven
		key.accessibility_name = entry.name if _projection.day_seven else "%s, %d / 7" % [entry.name,index+1]
		_label(key,entry.name,Rect2(8 if _projection.day_seven else 32,8,name_width,label_h))
		if not _projection.day_seven:
			_label(key,str(index+1),Rect2(0,0,24,height))
			var gx := 136 if _large else 144
			var gy := 34 if _large else 26
			_paper(key,Rect2(gx,gy,16,2),"paper_ink")
			_paper(key,Rect2(gx,gy+8,16,2),"paper_ink")
			key.drag_grip = Rect2(112 if _large else 128,8,64 if _large else 48,64 if _large else 48)
			key.drag_started = func(): return _begin_docket_drag(entry.id)
			key.drag_ended = _finish_docket_drag
			filled_geometry.append(Vector2(y,height))
		key.pressed.connect(func(): _inspect(entry.id))
		entry_buttons[entry.id] = key
		y += height+8
	_docket_body.custom_minimum_size.y = maxf(516,y-8)
	if not _projection.day_seven and not filled_geometry.is_empty():
		_docket_body.boundaries.append(0.0)
		for index in range(1,filled_geometry.size()):
			_docket_body.boundaries.append(filled_geometry[index].x-4.0)
		var last := filled_geometry[-1]
		_docket_body.boundaries.append(last.x+last.y+4.0)
	_build_folio()
	_well(docket_scroll,Rect2(768,32,16,516))
	for scroll: ScrollContainer in [available_scroll,docket_scroll]:
		var rail := FOCUS_RAIL.new()
		rail.scroll = scroll
		rail.position = scroll.position-Vector2(8,8)
		rail.size = scroll.size+Vector2(16,16)
		add_child(rail)
	done_button = _key(self,Rect2(644,576 if _large else 584,132,64 if _large else 48),"done",_done_enabled)
	_label(done_button,COPY[_locale][4],Rect2(8,0,116,done_button.size.y),"ink")
	done_button.accessibility_name = COPY[_locale][4]
	done_button.pressed.connect(func(): done_requested.emit())
	_build_status()
	_wire_focus()

func _rebuild_status(announce: bool = false) -> void:
	_clear_status_nodes()
	if is_instance_valid(done_button): _build_status(announce)

func _build_status(announce: bool = false) -> void:
	if _refusal_id.is_empty(): return
	var rule_rect: Rect2 = Rect2(24,580,2,56) if _large else Rect2(24,588,2,40)
	var text_rect: Rect2 = Rect2(40,576,600,64) if _large else Rect2(40,584,600,48)
	var before: int = get_child_count()
	_paper(self,rule_rect,"structure")
	var copy: String = MOTIVATION_REFUSAL[_locale] if _refusal_code == &"insufficient_motivation" else COPY[_locale][5]
	var status: Label = _label(self,copy,text_rect,"ink")
	status.name = "DockStatus"
	# Reconstructing the same fact for layout must not request live speech again.
	status.accessibility_live = DisplayServer.LIVE_POLITE if announce else DisplayServer.LIVE_OFF
	for index in range(before,get_child_count()):
		_status_nodes.append(get_child(index))

func _clear_status_nodes() -> void:
	for node: Node in _status_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_status_nodes.clear()

func _inspect(id: String) -> void:
	selected_id = id
	for entry_id in entry_buttons:
		entry_buttons[entry_id].selected = entry_id == id and not _projection.day_seven
		entry_buttons[entry_id].queue_redraw()
	for button in commands.values():
		if is_instance_valid(button): button.cancel_contact()
	for child in _folio.get_children():
		_folio.remove_child(child)
		child.queue_free()
	commands.clear()
	_build_folio()
	_wire_focus()

func _build_folio() -> void:
	if selected_id == "": return
	var selected_index := -1
	for i in _projection.entries.size():
		if _projection.entries[i].id == selected_id: selected_index = i
	if selected_index < 0: return
	var entry: Dictionary = _projection.entries[selected_index]
	var day7: bool = _projection.day_seven
	var h := _height(entry.name,246)
	if not day7: _label(_folio,str(selected_index+1),Rect2(12,8,246,32))
	_label(_folio,entry.name,Rect2(12,8 if day7 else 48,246,h))
	_art(_folio,entry.folio,Vector2(12,(16 if day7 else 56)+h),128)
	for index in range(3):
		if day7 and index != 2: continue
		var y := (308+index*72) if _large else (356+index*56)
		var enabled: bool = index == 2 or (selected_index > 0 if index == 0 else selected_index < _projection.entries.size()-1)
		var key := _key(_folio,Rect2(8,y,254,64 if _large else 48),"command",enabled)
		_label(key,COPY[_locale][index+1],Rect2(8,0,238,key.size.y),"ink")
		key.accessibility_name = COPY[_locale][index+1]
		commands[["earlier","later","remove"][index]] = key
		if index == 2: key.pressed.connect(func(): remove_requested.emit(selected_id))
		else: key.pressed.connect(func(): move_requested.emit(selected_id,selected_index+(-1 if index == 0 else 1)))

func _targets() -> Array:
	var result: Array = []
	for button in source_buttons.values()+entry_buttons.values()+commands.values()+[done_button]:
		if is_instance_valid(button) and not button.disabled: result.append(button)
	return result

func _wire_focus() -> void:
	var targets := _targets()
	var sequential := targets.duplicate()
	if is_instance_valid(_home): sequential.push_front(_home)
	for i in sequential.size():
		sequential[i].focus_next = sequential[i].get_path_to(sequential[(i+1)%sequential.size()])
		sequential[i].focus_previous = sequential[i].get_path_to(sequential[(i-1+sequential.size())%sequential.size()])
	for group in [source_buttons.values(),entry_buttons.values(),commands.values(),[done_button]]:
		var enabled: Array = group.filter(func(button): return is_instance_valid(button) and not button.disabled)
		for i in enabled.size():
			var button: Button = enabled[i]
			button.focus_neighbor_top = button.get_path_to(enabled[maxi(0,i-1)])
			button.focus_neighbor_bottom = button.get_path_to(enabled[mini(enabled.size()-1,i+1)])
			button.focus_neighbor_left = button.get_path_to(button)
			button.focus_neighbor_right = button.get_path_to(button)

func _key(parent: Node, rect: Rect2, kind: String, enabled: bool = true) -> Button:
	var key := KEY.new()
	key.position = rect.position
	key.size = rect.size
	key.kind = kind
	key.detached_focus = kind != "done"
	# Native drop lookup must reach the owning insertion lane behind this row.
	if kind == "entry": key.mouse_filter = Control.MOUSE_FILTER_PASS
	key.disabled = not enabled
	key.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	parent.add_child(key)
	return key

func _label(parent: Node, text_value: String, rect: Rect2, role: String = "paper_ink") -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.autowrap_trim_flags = 0
	label.add_theme_constant_override("line_spacing",0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",get_theme_color(role,"Schedule"))
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	label.text = text_value
	return label

func _paper(parent: Node, rect: Rect2, role: String = "paper") -> void:
	var paper := ColorRect.new()
	paper.color = get_theme_color(role,"Schedule")
	paper.position = rect.position
	paper.size = rect.size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(paper)

func _art(parent: Node, texture: Texture2D, pos: Vector2, extent: int) -> void:
	var art := TextureRect.new()
	art.name = "RegisteredArt"
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position = pos
	art.size = Vector2(extent,extent)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)

func _scroll(rect: Rect2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_DISABLED
	scroll.draw_focus_border = false
	scroll.follow_focus = true
	add_child(scroll)
	return scroll

func _body(parent: Node, extent: Vector2) -> Control:
	var body := Control.new()
	body.custom_minimum_size = extent
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(body)
	return body

func _well(scroll: ScrollContainer, rect: Rect2) -> void:
	var well := WELL.new()
	well.scroll = scroll
	well.position = rect.position
	well.size = rect.size
	add_child(well)

func _height(text_value: String, width: float) -> float:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = BREAKS
	paragraph.add_string(text_value,FONTS[_locale],_font_size)
	return ceilf(paragraph.get_size().y)

func _valid_name(value: Dictionary) -> bool:
	return typeof(value.get("id")) == TYPE_STRING and not value.id.is_empty() and typeof(value.get("name")) == TYPE_STRING and not value.name.strip_edges().is_empty()

func _valid_art(value: Variant, native_size: int) -> bool:
	return value is Texture2D and value.get_size() == Vector2(native_size,native_size)

func _fits_folio(value: String, day7: bool) -> bool:
	return _height(value,246) + (24 if day7 else 64) + 128 <= (296 if _large else 344)
