extends Control
## Modal Schedule warning presentation. All prose is supplied by its owner.

signal close_requested
signal go_requested

const KEY := preload("res://scripts/ui/schedule/SchedulePaperButton.gd")
const WELL := preload("res://scripts/ui/schedule/ScheduleScrollWell.gd")
const SCHEDULE_THEME := preload("res://scripts/ui/schedule/ScheduleTheme.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const BREAKS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE

var close_button: Button
var go_button: Button
var body_scroll: ScrollContainer
var activation_id := ""
var _locale := "en"
var _font_size := 20
var _large := false
var _configured := false
var _busy := false
var _sheet: Control
var _body_document: Control
var _config_key: Array = []
var _presentation_key: Array = []
var _focus_generation := 0
var _focus_target := "close"

func _ready() -> void:
	custom_minimum_size = Vector2(800,656)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	set_process_unhandled_key_input(true)
	visibility_changed.connect(func():
		_focus_generation += 1
		if is_visible_in_tree() and not _presentation_key.is_empty():
			_restore_focus.call_deferred(_focus_generation)
		else: _cancel_contacts())

func configure(locale: String = "en", percent: int = 100, large: bool = false,
		palette: StringName = &"after_hours", day: int = 1,
		high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	locale = locale.replace("_","-")
	var key: Array = [locale,percent,large,palette,day,high_contrast,colour_preset]
	if _configured and key == _config_key: return true
	var next_theme: Theme = SCHEDULE_THEME.build(palette,day,high_contrast,colour_preset)
	if not TYPOGRAPHY.supports(locale) or percent not in [100,125,150] or next_theme == null: return false
	_locale = locale
	_font_size = TYPOGRAPHY.font_size(locale, percent, 20)
	_large = large
	theme = next_theme
	theme.default_font = TYPOGRAPHY.font(locale, percent)
	theme.default_font_size = _font_size
	_config_key = key
	_configured = true
	return true

func present(next_activation_id: String, copy: Dictionary, error_text: String = "") -> bool:
	if not _configured or next_activation_id.is_empty(): return false
	for field: String in ["title","body","close","go"]:
		if typeof(copy.get(field)) != TYPE_STRING or copy[field].strip_edges().is_empty(): return false
	if not error_text.is_empty() and error_text.strip_edges().is_empty(): return false
	if _height(copy.title,288) > 112 or _height(copy.close,144) > (64 if _large else 48) or _height(copy.go,240) > (64 if _large else 48): return false
	var key: Array = [next_activation_id,copy.title,copy.body,copy.close,copy.go,error_text,_config_key.duplicate()]
	if key == _presentation_key: return true
	var new_activation: bool = next_activation_id != activation_id
	var new_error: bool = not error_text.is_empty() and (new_activation or _presentation_key.is_empty() or _presentation_key[5] != error_text)
	# A second presentation can arrive before the first deferred focus restore.
	# Keep the semantic target across that gap for the same activation.
	var prior_focus: String = _focus_target if next_activation_id == activation_id else ""
	if is_instance_valid(close_button) and close_button.has_focus(): prior_focus = "close"
	elif is_instance_valid(go_button) and go_button.has_focus(): prior_focus = "go"
	var prior_scroll: int = body_scroll.scroll_vertical if is_instance_valid(body_scroll) else 0
	_cancel_contacts()
	if is_instance_valid(_sheet):
		remove_child(_sheet)
		_sheet.queue_free()
	activation_id = next_activation_id
	_presentation_key = key
	_build(copy,error_text)
	_focus_target = "close" if new_activation or new_error or prior_focus == "" else prior_focus
	_focus_generation += 1
	close_button.focus_entered.connect(func(): _focus_target = "close")
	go_button.focus_entered.connect(func(): _focus_target = "go")
	_restore_focus.call_deferred(_focus_generation)
	var maximum_scroll: int = maxi(0,int(_body_document.custom_minimum_size.y-body_scroll.size.y))
	var restored_scroll: int = mini(prior_scroll,maximum_scroll)
	if new_error: restored_scroll = maxi(restored_scroll,maximum_scroll)
	body_scroll.set_deferred("scroll_vertical",restored_scroll)
	return true

func _restore_focus(generation: int) -> void:
	if generation != _focus_generation or not is_visible_in_tree() or not can_process() or _busy: return
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion(): return
		ancestor = ancestor.get_parent()
	var target: Button = go_button if _focus_target == "go" else close_button
	if not is_instance_valid(target) or not target.is_visible_in_tree() or not target.can_process() or target.get_focus_mode_with_override() != Control.FOCUS_ALL: return
	target.grab_focus()

func set_busy(value: bool) -> void:
	_busy = value
	_cancel_contacts()
	for button: Button in [close_button,go_button]:
		if is_instance_valid(button):
			button.disabled = value
			button.focus_mode = Control.FOCUS_NONE if value else Control.FOCUS_ALL

func _build(copy: Dictionary, error_text: String) -> void:
	_sheet = Control.new()
	_sheet.position = Vector2(120,80)
	_sheet.size = Vector2(560,496)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.accessibility_name = copy.title
	add_child(_sheet)
	_rect(_sheet,Rect2(Vector2.ZERO,_sheet.size),get_theme_color(&"paper",&"Schedule"))
	# One native pixel, drawn inward: the dossier specifies the ink role but
	# leaves perimeter thickness open. This does not change geometry or hits.
	for edge: Rect2 in [Rect2(0,0,560,2),Rect2(0,494,560,2),Rect2(0,2,2,492),Rect2(558,2,2,492)]:
		_rect(_sheet,edge,get_theme_color(&"paper_ink",&"Schedule"))
	_rect(_sheet,Rect2(16,16,2,384),get_theme_color(&"paper_ink",&"Schedule"))
	var mark := _label(_sheet,"!",Rect2(32,40,32,32))
	# The invariant warning mark is a fixed glyph, independent of text reflow.
	mark.add_theme_font_override("font",TYPOGRAPHY.font("en", 100))
	mark.add_theme_font_size_override("font_size",20)
	mark.size = Vector2(32,32)
	_label(_sheet,copy.title,Rect2(80,16,288,112))
	close_button = _command(Rect2(384,24 if _large else 32,160,64 if _large else 48),copy.close)
	body_scroll = ScrollContainer.new()
	body_scroll.position = Vector2(48,136)
	body_scroll.size = Vector2(496,264)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body_scroll.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_DISABLED
	body_scroll.draw_focus_border = false
	_sheet.add_child(body_scroll)
	_body_document = Control.new()
	_body_document.name = "BodyDocument"
	var body_h: float = _height(copy.body,480)
	var error_h: float = 0.0 if error_text.is_empty() else _height(error_text,464)
	_body_document.custom_minimum_size = Vector2(480,body_h+(0 if error_text.is_empty() else 16+error_h))
	_body_document.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_scroll.add_child(_body_document)
	var body_label: Label = _label(_body_document,copy.body,Rect2(0,0,480,body_h))
	body_label.accessibility_name = copy.body
	if not error_text.is_empty():
		_rect(_body_document,Rect2(0,body_h+16,2,error_h),get_theme_color(&"paper_ink",&"Schedule"))
		var error_label: Label = _label(_body_document,error_text,Rect2(16,body_h+16,464,error_h))
		error_label.accessibility_name = error_text
	var well: Control = WELL.new()
	well.scroll = body_scroll
	well.position = Vector2(528,136)
	well.size = Vector2(16,264)
	_sheet.add_child(well)
	_rect(_sheet,Rect2(16,416,528,64),get_theme_color(&"face",&"Schedule"))
	go_button = _command(Rect2(288,416 if _large else 424,256,64 if _large else 48),copy.go)
	close_button.pressed.connect(func(): close_requested.emit())
	go_button.pressed.connect(func(): go_requested.emit())
	_wire_focus()
	set_busy(_busy)

func _command(rect: Rect2, text_value: String) -> Button:
	var button: Button = KEY.new()
	button.kind = "command"
	button.detached_focus = false
	button.position = rect.position
	button.size = rect.size
	button.accessibility_name = text_value
	_sheet.add_child(button)
	_label(button,text_value,Rect2(8,0,rect.size.x-16,rect.size.y),get_theme_color(&"ink",&"Schedule"))
	return button

func _wire_focus() -> void:
	close_button.focus_next = close_button.get_path_to(go_button)
	close_button.focus_previous = close_button.get_path_to(go_button)
	go_button.focus_next = go_button.get_path_to(close_button)
	go_button.focus_previous = go_button.get_path_to(close_button)
	for button: Button in [close_button,go_button]:
		button.focus_neighbor_top = button.get_path_to(close_button)
		button.focus_neighbor_bottom = button.get_path_to(go_button)
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed(): return
	var cancel: bool = event.is_action_pressed("ui_cancel")
	var page_up: bool = event.is_action_pressed("ui_page_up")
	var page_down: bool = event.is_action_pressed("ui_page_down")
	if not cancel and not page_up and not page_down: return
	get_viewport().set_input_as_handled()
	if _busy: return
	if cancel:
		close_requested.emit()
	else:
		var direction: int = -1 if page_up else 1
		body_scroll.scroll_vertical += direction*int(body_scroll.size.y)

func _cancel_contacts() -> void:
	for button: Button in [close_button,go_button]:
		if is_instance_valid(button): button.cancel_contact()

func _height(text_value: String, width: float) -> float:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = BREAKS
	paragraph.add_string(text_value,theme.default_font,_font_size)
	return ceilf(paragraph.get_size().y)

func _label(parent: Node, text_value: String, rect: Rect2, color: Color = Color.TRANSPARENT) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.autowrap_trim_flags = 0
	label.add_theme_constant_override("line_spacing",0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",get_theme_color(&"paper_ink",&"Schedule") if color == Color.TRANSPARENT else color)
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	label.text = text_value
	return label

func _rect(parent: Node, rect: Rect2, color: Color) -> void:
	var block: ColorRect = ColorRect.new()
	block.position = rect.position
	block.size = rect.size
	block.color = color
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(block)
