class_name SettingsTheme
extends RefCounted

const ENGLISH := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const ROLES := {
	"habitat": Color("0b0d13"), "face": Color("151b25"),
	"paper": Color("c3baa3"), "paper_ink": Color("151b25"),
	"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
	"structure": Color("657d89"), "filed": Color("789083"),
	"focus": Color("a9935f"), "paper_focus": Color("644000"),
	"danger": Color("c9846e"), "destructive": Color("dd7a7f"),
	"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
}
const MIDNIGHT_OVERRIDES := {
	"habitat": Color("0d1514"), "face": Color("14201d"),
	"paper_ink": Color("14201d"),
}
const SAMPLE_COPY := {
	"ja": ["選択中","フォーカス","警告","利用不可"],
	"ko": ["선택됨","포커스","경고","사용 불가"],
	"en": ["Selected", "Focus", "Warning", "Unavailable"],
	"zh-CN": ["已选择", "焦点", "警告", "不可用"],
	"zh-HK": ["已選擇", "焦點", "警告", "無法使用"],
}


static func build(locale: String, percent: int, palette_id: StringName = &"after_hours", high_contrast: bool = false, colour_preset: String = "standard", day: int = 1, font_style: String = "pixel") -> Theme:
	var roles: Dictionary = PALETTES.resolve(palette_id, high_contrast, colour_preset)
	if roles.is_empty() or day < 1 or day > 7:
		return null
	roles = WEEK_TINT.apply(roles, WEEK_TINT.tint_for_day(day), high_contrast, colour_preset)
	var result := Theme.new()
	var primary: Font = TYPOGRAPHY.font(locale, percent, font_style)
	if primary == null: return null
	var font := FontVariation.new()
	font.base_font = primary
	var fallbacks: Array[Font] = []
	# Every language name must remain readable while another language is selected.
	for companion_locale: String in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
		var companion := TYPOGRAPHY.font(companion_locale, percent, font_style)
		if companion != primary:
			fallbacks.append(companion)
	font.fallbacks = fallbacks
	result.default_font = font
	result.default_font_size = TYPOGRAPHY.font_size(locale, percent, 24, font_style)
	for role: String in roles:
		result.set_color(role, "Settings", roles[role])
	result.set_color("font_color", "Label", roles.paper_ink)
	for type: String in ["Button", "CheckBox", "OptionButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			result.set_stylebox(state, type, box(roles.paper, roles.paper_ink, 2))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			result.set_color(state, type, roles.paper_ink)
		result.set_stylebox("focus", type, StyleBoxEmpty.new())
		result.set_color("icon_normal_color", type, roles.paper_ink)
		result.set_color("icon_disabled_color", type, roles.paper_ink)
	result.set_constant("h_separation", "CheckBox", 12)
	for state: String in ["checked", "checked_disabled", "unchecked", "unchecked_disabled"]:
		result.set_icon(state, "CheckBox", check_icon(state.begins_with("checked"), roles))
	result.set_icon("arrow", "OptionButton", arrow_icon(roles))
	result.set_constant("arrow_margin", "OptionButton", 12)
	result.set_constant("modulate_arrow", "OptionButton", 0)
	result.set_stylebox("panel", "PopupMenu", box(roles.paper, roles.paper_ink, 2))
	result.set_stylebox("hover", "PopupMenu", box(roles.filed))
	for state: String in ["font_color", "font_hover_color", "font_disabled_color"]:
		result.set_color(state, "PopupMenu", roles.paper_ink)
	result.set_constant("v_separation", "PopupMenu", 16)
	# Slider values and the preview thumb are drawn from separate committed/live values.
	for state: String in ["slider", "grabber_area", "grabber_area_highlight"]:
		result.set_stylebox(state, "HSlider", StyleBoxEmpty.new())
	var transparent := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	transparent.fill(Color.TRANSPARENT)
	for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		result.set_icon(state, "HSlider", ImageTexture.create_from_image(transparent))
	result.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	return result


static func roles_from_theme(source: Theme) -> Dictionary:
	var roles := ROLES.duplicate()
	if source != null:
		for role: String in roles:
			if source.has_color(role, "Settings"):
				roles[role] = source.get_color(role, "Settings")
	return roles


static func roles_for(control: Control) -> Dictionary:
	var roles := ROLES.duplicate()
	for role: String in roles:
		if control.has_theme_color(role, "Settings"):
			roles[role] = control.get_theme_color(role, "Settings")
	return roles


static func box(fill: Color, edge: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func confirmation_theme(source: Theme, font_size: int, large_targets: bool) -> Theme:
	var roles := roles_from_theme(source)
	var result := source.duplicate() as Theme
	result.default_font_size = font_size
	var panel := box(roles.paper, roles.paper_ink, 2)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	result.set_stylebox("panel", "AcceptDialog", panel)
	result.set_constant("buttons_separation", "AcceptDialog", 32)
	result.set_constant("buttons_min_height", "AcceptDialog", maxi(64 if large_targets else 48, font_size * 2))
	result.set_constant("buttons_min_width", "AcceptDialog", 96)
	result.set_constant("separation", "HBoxContainer", 24)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		result.set_stylebox(state, "Button", box(roles.face))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		result.set_color(state, "Button", roles.ink)
	# The native title is part of the same document, with no unrelated window skin.
	var border := box(roles.paper, roles.paper_ink, 2)
	border.expand_margin_left = 2
	border.expand_margin_right = 2
	border.expand_margin_top = font_size + 24
	border.expand_margin_bottom = 2
	result.set_stylebox("embedded_border", "Window", border)
	result.set_stylebox("embedded_unfocused_border", "Window", border)
	result.set_font("title_font", "Window", result.default_font)
	result.set_font_size("title_font_size", "Window", font_size)
	result.set_constant("title_height", "Window", font_size + 24)
	result.set_color("title_color", "Window", roles.paper_ink)
	result.set_constant("close_h_offset", "Window", 24)
	result.set_constant("close_v_offset", "Window", (font_size + 24) / 2 + 8)
	var close_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	close_image.fill(Color.TRANSPARENT)
	for point: int in range(3, 13):
		close_image.fill_rect(Rect2i(point, point, 2, 2), roles.paper_ink)
		close_image.fill_rect(Rect2i(15 - point, point, 2, 2), roles.paper_ink)
	for icon: String in ["close", "close_pressed"]:
		result.set_icon(icon, "Window", ImageTexture.create_from_image(close_image))
	return result


static func apply_scroll(scroll: ScrollContainer, paper: bool) -> void:
	var roles := roles_for(scroll)
	var fill: Color = roles.paper if paper else roles.face
	var edge: Color = roles.paper_ink if paper else roles.structure
	var panel := box(fill)
	panel.content_margin_left = 16 if paper else 8
	panel.content_margin_right = 16 if paper else 8
	scroll.add_theme_stylebox_override("panel", panel)
	var bar := scroll.get_v_scroll_bar()
	var track := box(fill, edge, 2)
	track.content_margin_left = 6
	track.content_margin_right = 6
	bar.add_theme_stylebox_override("scroll", track)
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var thumb := box(roles.paper_focus if paper else roles.ink)
		thumb.content_margin_left = 6
		thumb.content_margin_right = 6
		bar.add_theme_stylebox_override(state, thumb)
	for icon: String in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		bar.add_theme_icon_override(icon, ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)))


static func apply_category(button: Button, selected: bool) -> void:
	var roles := roles_for(button)
	for state: String in ["normal", "hover", "disabled"]:
		button.add_theme_stylebox_override(state, box(roles.face))
	for state: String in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, box(roles.filed))
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, roles.ink)
	for state: String in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, roles.paper_ink)
	for child: Node in button.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", roles.paper_ink if selected else roles.ink)
	button.queue_redraw()


static func apply_volume_value(label: Label, preview: bool) -> void:
	var roles := roles_for(label)
	# Both states reserve the same space; contact never moves the surrounding rows.
	label.add_theme_stylebox_override("normal", box(roles.inward_preview if preview else roles.paper, roles.structure if preview else Color.TRANSPARENT, 2))
	label.add_theme_color_override("font_color", roles.ink if preview else roles.paper_ink)


static func attach_state(control: Control, directory: bool = false) -> void:
	control.set_meta("settings_directory", directory)
	control.draw.connect(draw_control.bind(control))
	for signal_name: String in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
		control.connect(signal_name, control.queue_redraw)
	if control is BaseButton:
		control.button_down.connect(func() -> void:
			control.set_meta("settings_press", true)
			control.queue_redraw())
		control.button_up.connect(func() -> void:
			control.set_meta("settings_press", false)
			control.queue_redraw())
	elif control is HSlider:
		control.value_changed.connect(func(_value: float) -> void: control.queue_redraw())


static func draw_control(control: Control) -> void:
	var roles := roles_for(control)
	var directory: bool = control.get_meta("settings_directory", false)
	var selected: bool = directory and control is BaseButton and control.button_pressed
	var context := "filed" if selected else ("dark" if directory else "paper")
	var rect := Rect2(Vector2.ZERO, control.size)
	if control is HSlider:
		var track := Rect2(12, floorf(control.size.y / 2.0) - 4, control.size.x - 24, 8)
		control.draw_rect(track, roles.paper_ink)
		control.draw_rect(track.grow(-2), roles.paper)
		var fill := track.grow(-2)
		var extent: float = maxf(control.max_value - control.min_value, 0.000001)
		var committed := clampf((float(control.get_meta("settings_committed_value", control.value)) - control.min_value) / extent, 0.0, 1.0)
		fill.size.x = floorf(fill.size.x * committed)
		control.draw_rect(fill, roles.filed)
		var thumb := Rect2(Vector2(track.position.x + (track.size.x - 16) * control.ratio, track.position.y - 8), Vector2(16, 24))
		control.draw_rect(thumb, roles.face)
	var disabled: bool = (control is BaseButton and control.disabled) or (control is Slider and not control.editable)
	var unavailable: bool = disabled and control.get_meta("settings_unavailable", false)
	if selected:
		control.draw_line(Vector2(rect.size.x - 2, 2), Vector2(rect.size.x - 2, rect.size.y - 2), roles.paper_ink, 2)
	if unavailable:
		draw_unavailable(control, rect, context)
	elif disabled:
		var ink: Color = roles.structure if context == "dark" else roles.paper_ink
		control.draw_line(Vector2(rect.size.x - 8, 8), Vector2(rect.size.x - 8, rect.size.y - 8), ink, 2)
		control.draw_line(Vector2(rect.size.x - 12, 8), Vector2(rect.size.x - 4, 8), ink, 2)
		control.draw_line(Vector2(rect.size.x - 12, rect.size.y - 8), Vector2(rect.size.x - 4, rect.size.y - 8), ink, 2)
	elif control.get_global_rect().has_point(control.get_global_mouse_position()):
		var ink: Color = roles.structure if context == "dark" else roles.paper_ink
		for corner: Vector2 in [Vector2(2, 2), Vector2(rect.size.x - 2, rect.size.y - 2)]:
			var direction := 1.0 if corner.x == 2 else -1.0
			control.draw_line(corner, corner + Vector2(12 * direction, 0), ink, 2)
			control.draw_line(corner, corner + Vector2(0, 12 * direction), ink, 2)
	if not disabled and control.get_meta("settings_press", false):
		var ink: Color = roles.structure if context == "dark" else roles.paper_ink
		control.draw_line(Vector2(4, rect.size.y - 6), Vector2(rect.size.x - 4, rect.size.y - 6), ink, 2)
	if control.has_focus():
		draw_focus(control, rect, context)


static func draw_focus(control: Control, rect: Rect2, context: String) -> void:
	var roles := roles_for(control)
	var outer: Color = roles.ink if context == "dark" else roles.habitat
	var gap: Color = roles.face if context == "dark" else (roles.filed if context == "filed" else roles.paper)
	var inner: Color = roles.focus if context == "dark" else (roles.paper_ink if context == "filed" else roles.paper_focus)
	control.draw_rect(rect.grow(7), outer, false, 2)
	control.draw_rect(rect.grow(5), gap, false, 2)
	control.draw_rect(rect.grow(3), inner, false, 2)


static func draw_unavailable(control: Control, rect: Rect2, context: String) -> void:
	var roles := roles_for(control)
	var ink: Color = roles.structure if context == "dark" else roles.paper_ink
	control.draw_rect(rect.grow(-1), ink, false, 2)
	for y: int in range(int(rect.position.y) + 8, int(rect.end.y) - 4, 8):
		control.draw_line(Vector2(rect.end.x - 10, y), Vector2(rect.end.x - 4, y - 4), ink, 2)


static func check_icon(checked: bool, roles: Dictionary = ROLES) -> ImageTexture:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(2, 2, 20, 20), roles.paper_ink)
	image.fill_rect(Rect2i(4, 4, 16, 16), roles.paper)
	if checked:
		image.fill_rect(Rect2i(7, 7, 10, 10), roles.filed)
		image.fill_rect(Rect2i(8, 11, 8, 2), roles.paper_ink)
	return ImageTexture.create_from_image(image)


static func arrow_icon(roles: Dictionary = ROLES) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for row: int in range(4):
		image.fill_rect(Rect2i(2 + row, 6 + row, 12 - row * 2, 1), roles.paper_ink)
	return ImageTexture.create_from_image(image)


class StateSpecimen extends Control:
	var state: String
	var caption: Label

	func _init(specimen_state: String) -> void:
		state = specimen_state
		name = state
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(248, 56)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption = Label.new()
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left = 20
		caption.offset_right = -16

	func _draw() -> void:
		var roles := SettingsTheme.roles_for(self)
		var rect := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		if state == "Selected":
			draw_rect(rect, roles.filed)
			draw_rect(rect.grow(-1), roles.paper_ink, false, 2)
			draw_line(rect.position + Vector2(4, 2), Vector2(rect.position.x + 4, rect.end.y - 2), roles.paper_ink, 2)
		elif state == "Focus":
			SettingsTheme.draw_focus(self, rect, "paper")
		elif state == "Warning":
			# Warning's double rule and triangular glyph supplement its literal label.
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), roles.paper_ink, 2)
			draw_line(rect.position + Vector2(0, 4), Vector2(rect.end.x, rect.position.y + 4), roles.paper_ink, 2)
			var p := rect.position + Vector2(8, 16)
			draw_polyline(PackedVector2Array([p + Vector2(0, 12), p + Vector2(6, 0), p + Vector2(12, 12), p + Vector2(0, 12)]), roles.paper_ink, 2)
		else:
			SettingsTheme.draw_unavailable(self, rect, "paper")
