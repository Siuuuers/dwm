extends Button
## Risk perimeter and inset Focus remain independent; no progress ornament.

var selected := false:
	set(value):
		selected = value
		_sync_caption()
		queue_redraw()
# Working hard-pixel operational glyph: distinct from the sheet's triangle.
const DANGER_GLYPH := ["00011000", "00100100", "01011010", "10011001",
	"10000001", "01011010", "00100100", "00011000"]
var risk := "neutral":
	set(value):
		risk = value
		_sync_caption()
		queue_redraw()
var caption: Label
var _caption_text := ""

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 8
		empty.content_margin_right = 8
		add_theme_stylebox_override(state, empty)
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)
	caption = Label.new()
	caption.name = "Caption"
	caption.position = Vector2(8, 4)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	caption.minimum_size_changed.connect(func(): _sync_caption.call_deferred())
	resized.connect(_sync_caption)
	theme_changed.connect(_sync_caption)
	_sync_caption()

func set_caption(value: String) -> void:
	_caption_text = value
	accessibility_name = value
	# Native Button text would impose a second wrapping/minimum-size owner.
	text = ""
	_sync_caption()

func _sync_caption() -> void:
	if not is_instance_valid(caption):
		return
	# Danger owns a protected glyph measure. Labels keep their declared font size.
	var leading := 36 if risk == "danger" else 8
	caption.position = Vector2(leading, 4)
	caption.size = size - Vector2(leading + 8, 8)
	caption.text = _caption_text
	caption.add_theme_color_override("font_color", get_theme_color("paper_ink" if selected else "ink", "Backup"))

func _draw() -> void:
	var face := get_theme_color("filed" if selected else "face", "Backup")
	var ink := get_theme_color("paper_ink" if selected else "ink", "Backup")
	draw_rect(Rect2(Vector2.ZERO, size), face)
	if risk == "destructive":
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), get_theme_color("destructive", "Backup"), false, 2)
	elif risk == "danger":
		for x in [0.0, size.x - 2]:
			draw_rect(Rect2(x, 0, 2, size.y), get_theme_color("danger", "Backup"))
		var glyph_origin := Vector2(12, floor((size.y - 16) / 4.0) * 2)
		for y in DANGER_GLYPH.size():
			for x in DANGER_GLYPH[y].length():
				if DANGER_GLYPH[y][x] == "1":
					draw_rect(Rect2(glyph_origin + Vector2(x * 2, y * 2), Vector2(2, 2)), get_theme_color("danger", "Backup"))
	else:
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), get_theme_color("structure", "Backup"), false, 2)
	if disabled:
		draw_rect(Rect2(8, size.y - 6, size.x - 16, 2), ink)
	elif is_pressed():
		draw_rect(Rect2(8, 8, size.x - 16, 2), ink)
		draw_rect(Rect2(8, 8, 2, size.y - 16), ink)
	elif is_hovered():
		draw_rect(Rect2(8, size.y - 6, size.x - 16, 2), get_theme_color("structure", "Backup"))
	if has_focus():
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), ink, false, 2)
		draw_rect(Rect2(7, 7, size.x - 14, size.y - 14), get_theme_color("focus", "Backup"), false, 2)
