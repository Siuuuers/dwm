extends Control
## Shared in-run confirmation host. It owns geometry and input custody only.

const KEY := preload("res://scripts/ui/backup/BackupKey.gd")
# A literal Warning triangle and exclamation; working geometry, not an assertion
# that a previously registered glyph asset was found or accepted.
const WARNING_GLYPH := ["000001100000", "000010010000", "000010010000",
	"000100001000", "000101101000", "001001100100", "001001100100",
	"010000000010", "010001100010", "100000000001", "111111111111"]
signal finished(accepted: bool)
var request: Dictionary = {}
var cancel_button: Button
var confirm_button: Button
var body_scroll: ScrollContainer
var _lower_controls: Array[Dictionary] = []
var _settled := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for sibling in get_parent().get_children():
		if sibling != self:
			_suspend(sibling)
	var sheet := PanelContainer.new()
	sheet.name = "ConfirmationSheet"
	sheet.position = Vector2(120, 112)
	sheet.size = Vector2(560, 480)
	var paper := StyleBoxFlat.new()
	paper.bg_color = get_theme_color("paper", "Backup")
	paper.border_color = get_theme_color("paper_ink", "Backup")
	paper.set_border_width_all(2)
	for edge in ["left", "right", "top", "bottom"]:
		paper.set("content_margin_" + edge, 16)
	sheet.add_theme_stylebox_override("panel", paper)
	if request.get("warning", true):
		sheet.draw.connect(func(): sheet.draw_rect(Rect2(4, 8, 2, sheet.size.y - 16), get_theme_color("paper_ink", "Backup")))
	add_child(sheet)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	sheet.add_child(layout)
	if request.get("warning", true):
		var warning := Control.new()
		warning.name = "WarningGlyph"
		warning.custom_minimum_size = Vector2(24, 24)
		warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		warning.draw.connect(func():
			for y in WARNING_GLYPH.size():
				for x in WARNING_GLYPH[y].length():
					if WARNING_GLYPH[y][x] == "1":
						warning.draw_rect(Rect2(x * 2, y * 2, 2, 2), get_theme_color("paper_ink", "Backup")))
		layout.add_child(warning)
	body_scroll = ScrollContainer.new()
	body_scroll.name = "ConfirmationBody"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body_scroll)
	var body := Label.new()
	body.text = str(request.get("title", "")) + "\n\n" + str(request.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("font_color", get_theme_color("paper_ink", "Backup"))
	body_scroll.add_child(body)
	var actions := HBoxContainer.new()
	actions.name = "ConfirmationActions"
	actions.add_theme_constant_override("separation", 16)
	layout.add_child(actions)
	cancel_button = KEY.new()
	cancel_button.name = "CancelButton"
	cancel_button.set_caption(str(request.get("cancel", "Cancel")))
	confirm_button = KEY.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.set_caption(str(request.get("confirm", "")))
	confirm_button.risk = str(request.get("risk", "neutral"))
	for button in [cancel_button, confirm_button]:
		button.custom_minimum_size = Vector2(248, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	cancel_button.pressed.connect(_finish.bind(false))
	confirm_button.pressed.connect(_finish.bind(true))
	cancel_button.accessibility_description = body.text
	cancel_button.grab_focus()

func _suspend(node: Node) -> void:
	if node is Control:
		_lower_controls.append({"node": weakref(node), "focus": node.focus_mode,
			"mouse": node.mouse_filter})
		node.focus_mode = Control.FOCUS_NONE
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_suspend(child)

func _finish(accepted: bool) -> void:
	if _settled:
		return
	_settled = true
	for prior in _lower_controls:
		var control: Control = prior.node.get_ref() as Control
		if is_instance_valid(control):
			control.focus_mode = prior.focus
			control.mouse_filter = prior.mouse
	hide()
	finished.emit(accepted)
	queue_free()

func _input(event: InputEvent) -> void:
	if _settled or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel"):
		_finish(false)
	elif event.is_action_pressed("ui_accept"):
		_finish(confirm_button.has_focus())
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		(cancel_button if confirm_button.has_focus() else confirm_button).grab_focus()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		body_scroll.scroll_vertical += -48 if event.is_action_pressed("ui_up") else 48
	elif event is InputEventKey and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		body_scroll.scroll_vertical += -240 if event.keycode == KEY_PAGEUP else 240
	elif event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton:
		pass
	else:
		return
	get_viewport().set_input_as_handled()
