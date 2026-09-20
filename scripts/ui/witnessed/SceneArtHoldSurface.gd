extends Control
## Transient art-only reading surface. Its Continue starts the original DTL; it witnesses no text.
signal continue_requested(token: String)
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const RUN_PRESENTATION := preload("res://scripts/ui/witnessed/WitnessedRunPresentation.gd")
var art: ART_VIEW
var next_button: Button
var _background: ColorRect
var _footer: ColorRect
var _token := ""
var _entry_id := ""
var _percent := 100
var _locale := "en"
var _show_portraits := true
var _palette := "AfterHours"
var _day := 1
var _high_contrast := false
var _colour_preset := "standard"
var _large_targets := false
var _run_owner: Object
var _drawn := false
var _paused := false
var _retired := false
var _covered := false
var _await_neutral := true
var _anchor: Dictionary = {}
var _capture_id := 0
var _input_owner: Node

func configure(entry_id: String, token: String, percent: int = 100,
		locale: String = "en", show_portraits: bool = true) -> bool:
	# Standalone legacy callers may mount before LocalizationManager initializes.
	if locale.is_empty(): locale = "en"
	if not configure_presentation(locale, percent, _palette, _high_contrast,
			_colour_preset, _large_targets, _day): return false
	_token = token
	_entry_id = entry_id
	_show_portraits = show_portraits
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	size = Vector2(1280, 720)
	_background = ColorRect.new()
	_background.name = "FieldBackdrop"
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.size = size
	add_child(_background)
	art = ART_VIEW.new()
	art.name = "SceneArt"
	add_child(art)
	art.configure_entry(entry_id, percent, false, show_portraits)
	art.draw.connect(_on_art_drawn)
	_footer = ColorRect.new()
	_footer.name = "ContinueFooter"
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.position = Vector2(0, 640)
	_footer.size = Vector2(1280, 80)
	add_child(_footer)
	next_button = Button.new()
	next_button.name = "ContinueArt"
	next_button.position = Vector2(448, 656)
	next_button.size = Vector2(384, 48)
	next_button.focus_mode = Control.FOCUS_ALL
	next_button.disabled = true
	next_button.pressed.connect(_on_continue)
	add_child(next_button)
	_apply_presentation()
	return art.visible

func configure_presentation(locale: String = "en", text_percent: int = 100,
		palette: String = "AfterHours", high_contrast: bool = false,
		colour_preset: String = "standard", large_targets: bool = false, day: int = 1) -> bool:
	if _retired: return false
	var next_theme: Theme = CAPTION_THEME.build(locale, text_percent, palette,
		high_contrast, colour_preset, large_targets, day)
	if next_theme == null: return false
	var resize_art := text_percent != _percent
	_locale = locale.replace("_", "-")
	_percent = text_percent
	_palette = palette
	_day = day
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_large_targets = large_targets
	theme = next_theme
	# Colour/locale changes retain all art objects and textures. Only text scale
	# changes the authored aperture, as it did before run presentation was added.
	if resize_art and is_instance_valid(art):
		art.configure_entry(_entry_id, _percent, false, _show_portraits)
	_apply_presentation()
	return true

func configure_run_presentation(owner: Object) -> bool:
	var installed: Dictionary = RUN_PRESENTATION.read(owner)
	if installed.is_empty() or not configure_presentation(_locale, _percent,
			installed.palette, _high_contrast, _colour_preset, _large_targets, installed.day): return false
	_run_owner = owner
	return true

func _apply_presentation() -> void:
	if theme == null: return
	var text := theme.get_color("text", "WitnessedCaption")
	var current := theme.get_color("current", "WitnessedCaption")
	var rule := theme.get_color("rule", "WitnessedCaption")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		face.bg_color = current
		face.border_color = rule
		face.set_border_width_all(2)
		theme.set_stylebox(state, "Button", face)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	# The expanded ring sits on deep footer, so it uses the invariant text role.
	focus.border_color = theme.get_color("focus_outer", "WitnessedCaption")
	focus.set_border_width_all(2)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		focus.set_expand_margin(side, 4)
	theme.set_stylebox("focus", "Button", focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		theme.set_color(state, "Button", text)
	if is_instance_valid(_background):
		_background.color = theme.get_color("field", "WitnessedCaption")
	if is_instance_valid(_footer):
		_footer.color = theme.get_color("deep", "WitnessedCaption")
	if is_instance_valid(next_button):
		next_button.text = {"en": "Continue", "zh-CN": "\u7ee7\u7eed", "zh-HK": "\u7e7c\u7e8c", "ja": "続ける", "ko": "계속"}[_locale]
		next_button.add_theme_font_size_override("font_size", TYPOGRAPHY.font_size(_locale, _percent, 20))
	# Continue stays 384x48 at (448,656); the fixed 80px footer contains its ring.
	# Large-target preference belongs to shared theme, without moving this action.

func _ready() -> void:
	_input_owner = get_node_or_null("/root/InputManager")
	if _run_owner == null:
		configure_run_presentation(get_node_or_null("/root/GameState"))
	var profile := get_node_or_null("/root/ProfileManager")
	if profile != null and profile.has_signal("preference_changed"):
		profile.connect("preference_changed", _on_preference_changed)
	if profile != null and profile.has_method("get_preference"):
		var contrast: Variant = profile.get_preference(&"preferences.accessibility.high_contrast", _high_contrast)
		var preset: Variant = profile.get_preference(&"preferences.accessibility.colour_differentiation", _colour_preset)
		var targets: Variant = profile.get_preference(&"preferences.accessibility.large_targets", _large_targets)
		if contrast is bool and preset is String and targets is bool:
			configure_presentation(_locale, _percent, _palette, contrast, preset, targets, _day)
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null and localization.has_signal("locale_changed"):
		localization.connect("locale_changed", _on_locale_changed)

func _on_preference_changed(path: StringName, value: Variant) -> void:
	match path:
		&"preferences.accessibility.text_size":
			if value is int:
				configure_presentation(_locale, value, _palette, _high_contrast, _colour_preset, _large_targets, _day)
		&"preferences.accessibility.high_contrast":
			if value is bool:
				configure_presentation(_locale, _percent, _palette, value, _colour_preset, _large_targets, _day)
		&"preferences.accessibility.colour_differentiation":
			if value is String:
				configure_presentation(_locale, _percent, _palette, _high_contrast, value, _large_targets, _day)
		&"preferences.accessibility.large_targets":
			if value is bool:
				configure_presentation(_locale, _percent, _palette, _high_contrast, _colour_preset, value, _day)

func _on_locale_changed(locale: String) -> void:
	configure_presentation(locale, _percent, _palette, _high_contrast, _colour_preset, _large_targets, _day)

func _on_art_drawn() -> void:
	if not _retired: _drawn = true

func has_drawn_art() -> bool:
	return _drawn and not _retired

func _process(_delta: float) -> void:
	if _retired: return
	var held := Input.is_action_pressed(&"ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _input_owner != null and _input_owner.has_method("get_physical_contacts"):
		held = not _input_owner.get_physical_contacts().is_empty()
	if _await_neutral and not held: _await_neutral = false
	var admitted := _input_owner == null or not _input_owner.has_method("is_source_input_admitted") \
		or bool(_input_owner.is_source_input_admitted())
	var enabled := _drawn and not _paused and not _covered and not _await_neutral \
		and not get_tree().paused and admitted
	var was_disabled := next_button.disabled
	next_button.disabled = not enabled
	if enabled and was_disabled and is_visible_in_tree(): next_button.grab_focus()

func _on_continue() -> void:
	if _retired or _paused or _covered or not _drawn or _await_neutral or next_button.disabled: return
	next_button.disabled = true
	continue_requested.emit(_token)

func set_presentation_paused(value: bool) -> void:
	_paused = value
	if value: next_button.disabled = true

func retire() -> void:
	_retired = true
	hide()
	set_process(false)
	next_button.disabled = true

func capture_pause_view(source: Dictionary) -> Dictionary:
	if not has_drawn_art() or _covered or not is_visible_in_tree():
		return {"ok": false, "code": &"pause_view_unavailable"}
	_capture_id += 1
	_anchor = {"view_id": get_instance_id(), "capture_id": _capture_id,
		"token": _token, "source": source.duplicate(true)}
	return {"ok": true, "value": _anchor.duplicate(true)}

func cover_pause_view(anchor: Dictionary) -> bool:
	if _retired or anchor != _anchor or _anchor.is_empty(): return false
	_covered = true
	hide()
	return true

func restore_pause_view(anchor: Dictionary) -> bool:
	if _retired or anchor != _anchor or _anchor.is_empty(): return false
	_covered = false
	show()
	return true
