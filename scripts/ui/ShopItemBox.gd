extends Button
class_name ShopItemBox
## Ordinary public product card. Selection belongs to Shop; this target only activates.
## The host must respect minimum height at larger fonts rather than clip public copy.
## Host custody transitions use set_admitted(), not direct writes to disabled.

const SHOP_THEME := preload("res://scripts/ui/shop/ShopTheme.gd")

var selected := false:
	set(value):
		selected = value
		queue_redraw()
var item_id := ""
var name_label: Label
var price_label: Label
var availability_label: Label
var _art: Texture2D
var _available := false
var _copy: Array[String] = []
var _pointer: Control
var _held := false
var _hover := false
var _roles := SHOP_THEME.resolve(&"after_hours")

func apply_palette(palette: StringName) -> bool:
	var candidate: Dictionary = SHOP_THEME.resolve(palette)
	if candidate.is_empty(): return false
	_roles = candidate
	if is_instance_valid(name_label):
		for label: Label in [name_label, price_label, availability_label]:
			label.add_theme_color_override("font_color", _roles.primary_ink)
	queue_redraw()
	return true

func configure(record: Dictionary, price_copy: String, availability_copy: String) -> void:
	# Consume the validated ordinary projection, never raw gameplay catalog rows.
	cancel_contact()
	item_id = record.id
	_art = record.card_art
	_available = record.available
	_copy.assign([record.name, price_copy, availability_copy])
	accessibility_name = ", ".join(_copy)
	if is_node_ready():
		show()
		focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
		refresh_layout()
		refresh_layout.call_deferred()

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	clip_text = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for index in 3:
		var label := Label.new()
		label.name = ["NameLabel", "PriceLabel", "AvailabilityLabel"][index]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_constant_override("line_spacing", 0)
		label.add_theme_color_override("font_color", _roles.primary_ink)
		add_child(label)
	name_label = get_node("NameLabel")
	price_label = get_node("PriceLabel")
	availability_label = get_node("AvailabilityLabel")
	_pointer = Control.new()
	_pointer.name = "PointerSurface"
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.mouse_filter = Control.MOUSE_FILTER_STOP
	_pointer.gui_input.connect(_pointer_input)
	_pointer.mouse_exited.connect(cancel_contact)
	add_child(_pointer)
	for event: Signal in [focus_entered, focus_exited, button_down, button_up]:
		event.connect(queue_redraw)
	visibility_changed.connect(cancel_contact)
	# Theme propagation reaches child Label metrics after the root notification.
	theme_changed.connect(func(): refresh_layout.call_deferred())
	refresh_layout()
	if _copy.is_empty():
		focus_mode = Control.FOCUS_NONE
		hide()

func refresh_layout() -> void:
	if not is_instance_valid(name_label): return
	var y := 70.0
	var labels := [name_label, price_label, availability_label]
	for index in labels.size():
		var label: Label = labels[index]
		label.text = _copy[index] if _copy.size() == 3 else ""
		label.position = Vector2(8, y)
		label.size = Vector2(128, 0)
		label.size.y = ceilf(label.get_minimum_size().y / 2.0) * 2
		y += label.size.y + 4
	custom_minimum_size = Vector2(144, maxf(176, y + 8))
	queue_redraw()

func cancel_contact() -> void:
	_held = false
	_hover = false
	# BaseButton also retains keyboard/controller press state. Reset that state
	# when this semantic target loses custody, including same-frame replacement.
	var was_disabled := disabled
	disabled = true
	disabled = was_disabled
	queue_redraw()

func set_admitted(admitted: bool) -> void:
	cancel_contact()
	disabled = not admitted
	focus_mode = Control.FOCUS_ALL if admitted else Control.FOCUS_NONE

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel_contact()

func _pointer_input(event: InputEvent) -> void:
	if disabled or not is_visible_in_tree():
		cancel_contact()
		return
	if event is InputEventMouseMotion:
		_hover = Rect2(Vector2.ZERO, size).has_point(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer.accept_event()
		_hover = Rect2(Vector2.ZERO, size).has_point(event.position)
		if event.pressed:
			_held = not event.double_click
		else:
			var activate := _held and _hover
			_held = false
			if activate:
				grab_focus()
				pressed.emit()
	queue_redraw()

func _draw() -> void:
	if _copy.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO, size), _roles.selected_plane if selected else _roles.controlled_face)
	draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), _roles.laminate)
	if _art != null:
		draw_rect(Rect2(42, 6, 60, 60), _roles.paper)
		draw_rect(Rect2(42, 6, 60, 60), _roles.structure, false, 2)
		# All coordinates use the project's fixed native-to-logical 2:1 mapping.
		# The 28-native-pixel export stays 56 logical pixels at every font size.
		draw_texture_rect(_art, Rect2(44, 8, 56, 56), false)
	draw_rect(Rect2(8, size.y - 8, 128, 2), _roles.structure)
	if not _available: draw_rect(Rect2(134, size.y - 16, 2, 10), _roles.structure)
	if selected: draw_rect(Rect2(0, size.y - 4, size.x, 4), _roles.selected_ink)
	if _held or is_pressed(): draw_rect(Rect2(138, 4, 2, size.y - 8), _roles.structure)
	elif _hover: draw_rect(Rect2(4, 4, 2, size.y - 8), _roles.structure)
	if has_focus():
		draw_rect(Rect2(-7, -7, size.x + 14, size.y + 14), _roles.dark_focus_outer, false, 2)
		draw_rect(Rect2(-3, -3, size.x + 6, size.y + 6), _roles.dark_focus_inner, false, 2)
