extends Button
## One semantic locator. Focus/selection never performs a record operation.

var selected := false:
	set(value):
		selected = value
		queue_redraw()
var unavailable := false
var identity_label: Label
var state_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(144, 176)
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	identity_label = _label("Identity", Vector2(8, 8), Vector2(128, 52))
	state_label = _label("RecordState", Vector2(8, 66), Vector2(128, 96))
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(_refresh_draw)

func _label(node_name: String, at: Vector2, bounds: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = bounds
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func present(identity: String, state: String, is_unavailable: bool) -> void:
	identity_label.text = identity
	state_label.text = state
	unavailable = is_unavailable
	for label in [identity_label, state_label]:
		label.add_theme_color_override("font_color", get_theme_color("paper_ink", "Backup"))
	accessibility_name = identity + ", " + state
	queue_redraw()

func _refresh_draw() -> void:
	z_index = 1 if has_focus() else 0
	queue_redraw()

func _outline(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, false, 2)

func _draw() -> void:
	if theme == null:
		return
	var ink := get_theme_color("paper_ink", "Backup")
	var face := get_theme_color("filed" if selected else "face", "Backup")
	draw_rect(Rect2(0, 0, 144, 176), face)
	draw_rect(Rect2(4, 4, 136, 168), get_theme_color("paper", "Backup"))
	# Stable filing lip; authored fingerprint/Bloom material is not synthesized.
	draw_rect(Rect2(48, 168, 48, 8), ink if selected else get_theme_color("structure", "Backup"))
	if unavailable:
		draw_rect(Rect2(132, 144, 2, 16), ink)
		draw_rect(Rect2(128, 150, 8, 2), ink)
	if is_pressed():
		draw_rect(Rect2(6, 6, 132, 2), ink)
		draw_rect(Rect2(6, 6, 2, 156), ink)
	elif is_hovered():
		draw_rect(Rect2(8, 162, 128, 2), ink)
	if has_focus():
		for offset in [2, 6]:
			_outline(Rect2(-offset + 1, -offset + 1, 142 + offset * 2, 174 + offset * 2), face)
		_outline(Rect2(-3, -3, 150, 182), ink if selected else get_theme_color("ink", "Backup"))
		_outline(Rect2(-7, -7, 158, 190), ink if selected else get_theme_color("focus", "Backup"))
