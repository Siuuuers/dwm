extends ConfirmationDialog

const PRESENTATION := preload("res://scripts/ui/SettingsTheme.gd")
const CONTENT_WIDTH := 720
var reset_id: String = ""
var risk_class: String = "destructive"
var _wired: bool = false
var _input_owner: Object


func _init() -> void:
	dialog_autowrap = true
	exclusive = true
	unresizable = true
	min_size = Vector2i(CONTENT_WIDTH, 0)
	get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_label().mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_focus_cancel_when_open)


func configure(id: String, input_owner: Object = null) -> void:
	reset_id = id
	_input_owner = input_owner
	risk_class = "danger" if id in ["preferences", "controls"] else "destructive"
	if not _wired:
		PRESENTATION.attach_state(get_cancel_button(), true)
		PRESENTATION.attach_state(get_ok_button(), true)
		get_ok_button().draw.connect(_draw_final_risk)
		_wired = true
	get_ok_button().queue_redraw()


func _input(event: InputEvent) -> void:
	# This Window owns its packets before parent Pause input can see them.
	# Keep the shared contact ledger exact without admitting a Quick command.
	if visible and is_instance_valid(_input_owner) and _input_owner.has_method("observe_physical_contact"):
		_input_owner.observe_physical_contact(event)


func set_presentation(source_theme: Theme, font_size: int, large_targets: bool) -> void:
	theme = PRESENTATION.confirmation_theme(source_theme, font_size, large_targets)
	var roles := PRESENTATION.roles_from_theme(theme)
	get_label().add_theme_font_override("font", theme.default_font)
	get_label().add_theme_font_size_override("font_size", font_size)
	for button: Button in [get_cancel_button(), get_ok_button()]:
		button.add_theme_font_override("font", theme.default_font)
		button.add_theme_font_size_override("font_size", font_size)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# Reserve a small physical glyph lane without putting a symbol into the caption.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var final_style := PRESENTATION.box(roles.face)
		final_style.content_margin_left = 40 if risk_class == "danger" else 16
		final_style.content_margin_right = 16
		get_ok_button().add_theme_stylebox_override(state, final_style)
	get_ok_button().queue_redraw()


func popup_scoped() -> void:
	# Measure at the native content width without overriding its anchored layout.
	var label := get_label()
	var body_height := label.get_theme_font("font").get_multiline_string_size(
		dialog_text, HORIZONTAL_ALIGNMENT_LEFT, CONTENT_WIDTH - 48,
		label.get_theme_font_size("font_size")
	).y
	var button_height := maxf(get_ok_button().get_combined_minimum_size().y, get_cancel_button().get_combined_minimum_size().y)
	var content_height := ceili(body_height + button_height + 80)
	# Windows do not inherit the computer canvas transform like Controls do.
	var source := get_parent() as Control
	var source_scale := (source.get_global_transform_with_canvas() if is_embedded() else source.get_screen_transform()).get_scale()
	content_scale_factor = minf(source_scale.x, source_scale.y)
	min_size = Vector2i((Vector2(CONTENT_WIDTH, content_height) * content_scale_factor).round())
	popup_centered(min_size)
	get_cancel_button().grab_focus()
	get_cancel_button().call_deferred("grab_focus")


func _focus_cancel_when_open() -> void:
	if visible:
		get_cancel_button().grab_focus()
		get_cancel_button().call_deferred("grab_focus")


func _draw_final_risk() -> void:
	var button := get_ok_button()
	var roles := PRESENTATION.roles_for(button)
	var edge: Color = roles.danger if risk_class == "danger" else roles.destructive
	var rect := Rect2(Vector2.ZERO, button.size)
	button.draw_rect(rect.grow(-1), edge, false, 2)
	if risk_class == "danger":
		button.draw_rect(rect.grow(-5), edge, false, 2)
		var origin := Vector2(12, floorf(button.size.y / 2.0) - 10)
		button.draw_polyline(PackedVector2Array([
			origin + Vector2(0, 20), origin + Vector2(10, 0),
			origin + Vector2(20, 20), origin + Vector2(0, 20),
		]), edge, 2)
		button.draw_line(origin + Vector2(10, 7), origin + Vector2(10, 12), edge, 2)
		button.draw_rect(Rect2(origin + Vector2(9, 15), Vector2(2, 2)), edge)
