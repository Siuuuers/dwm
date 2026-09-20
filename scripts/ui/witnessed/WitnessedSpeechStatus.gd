class_name WitnessedSpeechStatus
extends Label
## Nonmodal factual status for a failed Primary system-speech utterance.
## The Caption owner decides whether a completion still belongs to the visible publication.

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const COPY_KEY := "witnessed.speech.failed"
const LOCALES := ["en", "zh-CN", "zh-HK", "ja", "ko"]
const PRESENTATION := preload("res://scripts/ui/SettingsTheme.gd")

var _copy := ""
var _configured := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_live = DisplayServer.LIVE_POLITE
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false
	text = ""
	accessibility_name = ""


func update_presentation(localization: Node, locale: String, presentation_theme: Theme,
		text_percent: int) -> bool:
	var normalized := locale.replace("_", "-")
	if not is_instance_valid(localization) or normalized not in LOCALES \
			or presentation_theme == null or text_percent not in [100, 125, 150]:
		return _refuse_presentation()
	for method: StringName in [&"get_locale", &"has_key", &"t"]:
		if not localization.has_method(method):
			return _refuse_presentation()
	if String(localization.call("get_locale")).replace("_", "-") != normalized \
			or localization.call("has_key", COPY_KEY) != true:
		return _refuse_presentation()
	var value: Variant = localization.call("t", COPY_KEY)
	if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty():
		return _refuse_presentation()

	var was_presented := visible and not text.is_empty()
	_copy = String(value)
	_configured = true
	theme = presentation_theme
	language = normalized
	add_theme_font_size_override(&"font_size", TYPOGRAPHY.font_size(normalized, text_percent, 20))
	var error_color: Color = PRESENTATION.ROLES.danger
	if presentation_theme.has_color(&"danger", &"Settings"):
		error_color = presentation_theme.get_color(&"danger", &"Settings")
	add_theme_color_override(&"font_color", error_color)
	var outline_color: Color = PRESENTATION.ROLES.habitat
	if presentation_theme.has_color(&"deep", &"WitnessedCaption"):
		outline_color = presentation_theme.get_color(&"deep", &"WitnessedCaption")
	add_theme_color_override(&"font_outline_color", outline_color)
	add_theme_constant_override(&"outline_size", 4)
	if was_presented:
		_publish()
	else:
		clear_status()
	return true


func show_failure() -> bool:
	if not _configured or _copy.is_empty():
		clear_status()
		return false
	_publish()
	return true


func clear_status() -> void:
	text = ""
	accessibility_name = ""
	visible = false
	if is_inside_tree():
		queue_accessibility_update()


func _publish() -> void:
	text = _copy
	accessibility_name = _copy
	visible = true
	if is_inside_tree():
		queue_accessibility_update()


func _refuse_presentation() -> bool:
	_configured = false
	_copy = ""
	clear_status()
	return false
