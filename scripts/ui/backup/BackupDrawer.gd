extends Button
## One semantic locator. Focus/selection never performs a record operation.

const MINIMUM_SIZE := Vector2(188, 176)

var selected := false:
	set(value):
		selected = value
		queue_redraw()
var unavailable := false
var ink_marks: Array = []
var identity_label: Label
var state_label: Label
var _layout_queued := false

func _ready() -> void:
	custom_minimum_size = MINIMUM_SIZE
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	identity_label = _label("Identity", Vector2(4, 4), Vector2(size.x - 8, 0))
	state_label = _label("RecordState", Vector2(4, 56), Vector2(size.x - 8, 0))
	for label in [identity_label, state_label]:
		label.minimum_size_changed.connect(_queue_label_layout)
		label.theme_changed.connect(_queue_label_layout)
	resized.connect(_queue_label_layout)
	_queue_label_layout()
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

func present(identity: String, state: String, is_unavailable: bool, marks: Array = []) -> void:
	identity_label.text = identity
	state_label.text = state
	unavailable = is_unavailable
	ink_marks = marks.duplicate()
	for label in [identity_label, state_label]:
		label.add_theme_color_override("font_color", get_theme_color("paper_ink", "Backup"))
	accessibility_name = identity + ", " + state
	_queue_label_layout()
	queue_redraw()

func _queue_label_layout() -> void:
	if _layout_queued or not is_inside_tree():
		return
	_layout_queued = true
	_layout_labels.call_deferred()

func _layout_labels() -> void:
	_layout_queued = false
	if identity_label == null or state_label == null:
		return
	var top := 4.0
	for label in [identity_label, state_label]:
		# Keep full glyphs clear of the paper edge at the common measured width.
		# No height cap: impossible content remains detectable by enclosure checks.
		label.size = Vector2(size.x - 8, 0)
		label.size.y = label.get_minimum_size().y
		label.position = Vector2(4, top)
		top += label.size.y + 4.0
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
	draw_rect(Rect2(Vector2.ZERO, size), face)
	draw_rect(Rect2(0, 4, size.x, 156), get_theme_color("paper", "Backup"))
	# Persisted seeds reproduce each splash; age only changes opacity. This local
	# generator never advances gameplay RNG, and drawing has no process loop.
	var random := RandomNumberGenerator.new()
	for index: int in ink_marks.size():
		var opacity := pow(0.65, ink_marks.size() - index - 1)
		if opacity < 0.05: continue
		random.seed = ink_marks[index]
		var center := Vector2(random.randf_range(30.0, size.x - 30.0), random.randf_range(112.0, 132.0))
		var radius := random.randf_range(7.0, 12.0)
		var phase := random.randf_range(0.0, TAU)
		var squash := random.randf_range(0.65, 0.9)
		var colour := Color(ink, 0.22 * opacity)
		var outline := PackedVector2Array()
		for point: int in 32:
			var angle := TAU * point / 32.0
			var edge := radius * (1.0 + 0.18 * sin(angle * 3.0 + phase) + 0.12 * cos(angle * 5.0 - phase))
			outline.append(center + Vector2(cos(angle), sin(angle) * squash) * edge)
		draw_colored_polygon(outline, colour)
		for streak: int in 3:
			var angle := random.randf_range(0.0, TAU)
			var direction := Vector2(cos(angle), sin(angle))
			var side := direction.orthogonal() * 1.4
			var start := center + direction * radius * 0.65
			var tip := center + direction * random.randf_range(15.0, 21.0)
			draw_colored_polygon(PackedVector2Array([start - side, start + side, tip]), colour)
		for droplet: int in 3:
			var angle := random.randf_range(0.0, TAU)
			var at := center + Vector2(cos(angle), sin(angle)) * random.randf_range(16.0, 24.0)
			draw_circle(at, random.randf_range(0.8, 1.7), colour)
	# Stable filing lip; authored fingerprint/Bloom material is not synthesized.
	draw_rect(Rect2(floorf((size.x - 48) / 4.0) * 2.0, 168, 48, 8), ink if selected else get_theme_color("structure", "Backup"))
	if unavailable:
		draw_rect(Rect2(size.x - 12, 164, 2, 8), ink)
		draw_rect(Rect2(size.x - 15, 167, 8, 2), ink)
	if is_pressed():
		draw_rect(Rect2(0, 0, size.x, 2), ink)
	elif is_hovered():
		draw_rect(Rect2(8, 162, size.x - 16, 2), ink)
	if has_focus():
		for offset in [2, 6]:
			_outline(Rect2(-offset + 1, -offset + 1, size.x - 2 + offset * 2, 174 + offset * 2), face)
		_outline(Rect2(-3, -3, size.x + 6, 182), ink if selected else get_theme_color("ink", "Backup"))
		_outline(Rect2(-7, -7, size.x + 14, 190), ink if selected else get_theme_color("focus", "Backup"))

