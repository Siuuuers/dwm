class_name WitnessedTransportRecovery
extends Control
## Presentation-only recovery for a refused Witnessed reading command.
## CaptionLayer retains the semantic request and decides whether Retry or Cancel is lawful.

signal retry_requested
signal cancel_requested

const TRANSPORT_BUTTON := preload("res://scripts/ui/witnessed/WitnessedTransportButton.gd")
const PRESENTATION := preload("res://scripts/ui/SettingsTheme.gd")
const LOCALES := ["en", "zh-CN", "zh-HK", "ja", "ko"]
const COLOUR_PRESETS := ["standard", "protan", "deutan", "tritan"]
const COPY_KEYS := {
	"failure": "witnessed.recovery.preference_failed",
	"uncertain": "witnessed.recovery.preference_uncertain",
	"next_failure": "witnessed.recovery.next_failed",
	"next_uncertain": "witnessed.recovery.next_uncertain",
	"step_failure": "witnessed.recovery.step_failed",
	"retry": "witnessed.recovery.retry",
	"cancel": "witnessed.recovery.cancel",
}

@onready var retry_button: TRANSPORT_BUTTON = %RetryButton
@onready var cancel_button: TRANSPORT_BUTTON = %CancelButton
@onready var message_label: Label = %RecoveryBody
@onready var _matte: ColorRect = %RecoveryMatte
@onready var _panel: PanelContainer = %RecoveryPanel

var _localization: Object
var _input_owner: Node
var _admission: Callable
var _copy: Dictionary = {}
var _locale := "en"
var _configured := false
var _bound := false
var _active := false
var _can_retry := false
var _can_cancel := false
var _command_kind: StringName = &"preference"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	retry_button.activated.connect(_on_retry_activated)
	cancel_button.activated.connect(_on_cancel_activated)
	visibility_changed.connect(_retire_buttons)
	_apply_capabilities()
	hide()


func bind_owners(localization: Object, input_owner: Node, admission: Callable) -> bool:
	if not is_instance_valid(localization) or not is_instance_valid(input_owner) \
			or not admission.is_valid() or admission.get_argument_count() != 0:
		return false
	for method: StringName in [&"has_key", &"t", &"get_locale"]:
		if not localization.has_method(method): return false
	if _bound:
		return _localization == localization and _input_owner == input_owner and _admission == admission
	if not retry_button.bind_admission(_retry_admitted, input_owner): return false
	if not cancel_button.bind_admission(_cancel_admitted, input_owner): return false
	_localization = localization
	_input_owner = input_owner
	_admission = admission
	_bound = true
	return true


func configure_presentation(locale: String, percent: int, palette: String,
		high_contrast: bool, colour: String, large_targets: bool, font_style: String = "pixel") -> bool:
	var normalized := locale.replace("_", "-")
	if normalized not in LOCALES or percent not in [100, 125, 150] \
			or colour not in COLOUR_PRESETS or not _bound:
		return false
	if String(_localization.call("get_locale")).replace("_", "-") != normalized:
		return false
	var next_copy := _read_copy()
	if next_copy.is_empty(): return false
	var palette_id := _palette_id(palette)
	if palette_id == &"": return false
	var next_theme: Theme = PRESENTATION.build(
		normalized, percent, palette_id, high_contrast, colour, 1, font_style)
	if next_theme == null: return false
	_retire_buttons()
	_locale = normalized
	_copy = next_copy
	theme = next_theme
	_style(percent, large_targets)
	_configured = true
	if _active: _publish()
	return true


func present(can_retry: bool, can_cancel: bool, command_kind: StringName = &"preference") -> bool:
	if not _configured or not _bound or (can_cancel and not can_retry) \
			or command_kind not in [&"preference", &"next", &"hospital"] \
			or (command_kind == &"hospital" and (not can_retry or can_cancel)):
		return false
	_command_kind = command_kind
	_can_retry = can_retry
	_can_cancel = can_cancel
	_active = true
	_retire_buttons()
	_publish()
	show()
	queue_accessibility_update()
	var focus_target: Control = retry_button if _can_retry else cancel_button
	if focus_target.visible and not focus_target.disabled:
		focus_target.grab_focus()
		focus_target.call_deferred("grab_focus")
	return true


func dismiss() -> void:
	_active = false
	_can_retry = false
	_can_cancel = false
	_retire_buttons()
	_apply_capabilities()
	hide()
	queue_accessibility_update()


func is_presented() -> bool:
	return _active and is_visible_in_tree()


func _read_copy() -> Dictionary:
	var result := {}
	for id: String in COPY_KEYS:
		var key: String = COPY_KEYS[id]
		if _localization.call("has_key", key) != true: return {}
		var value: Variant = _localization.call("t", key)
		if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty(): return {}
		result[id] = value
	return result


func _palette_id(value: String) -> StringName:
	match value.to_lower().replace("-", "_"):
		"afterhours", "after_hours": return &"after_hours"
		"midnight": return &"midnight"
	return &""


func _style(percent: int, large_targets: bool) -> void:
	var roles: Dictionary = PRESENTATION.roles_for(self)
	_matte.color = Color(roles.habitat, 0.78)
	_panel.add_theme_stylebox_override(&"panel", PRESENTATION.box(roles.face, roles.structure, 2))
	message_label.add_theme_color_override(&"font_color", roles.ink)
	var height := maxf(48.0 * percent / 100.0, 64.0 if large_targets else 48.0)
	var focus := PRESENTATION.box(Color.TRANSPARENT, roles.paper_focus, 4)
	for button: Button in [retry_button, cancel_button]:
		button.custom_minimum_size = Vector2(240, height)
		button.add_theme_stylebox_override(&"focus", focus)


func _publish() -> void:
	var next_command := _command_kind == &"next"
	if _command_kind == &"hospital":
		message_label.text = _copy["step_failure"]
	elif _can_retry or _can_cancel:
		message_label.text = _copy["next_failure"] if next_command else _copy["failure"]
	else:
		message_label.text = _copy["next_uncertain"] if next_command else _copy["uncertain"]
	accessibility_name = message_label.text
	retry_button.text = _copy["retry"]
	cancel_button.text = _copy["cancel"]
	for button: Button in [retry_button, cancel_button]:
		button.language = _locale
		button.accessibility_description = message_label.text
	_apply_capabilities()


func _apply_capabilities() -> void:
	if not is_instance_valid(retry_button) or not is_instance_valid(cancel_button): return
	for row: Array in [[retry_button, _active and _can_retry],
			[cancel_button, _active and _can_cancel]]:
		var button: Button = row[0]
		var enabled: bool = bool(row[1])
		button.visible = enabled
		button.disabled = not enabled
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _retry_admitted() -> bool:
	return _active and _can_retry and _owner_admitted()


func _cancel_admitted() -> bool:
	return _active and _can_cancel and _owner_admitted()


func _owner_admitted() -> bool:
	return _bound and is_visible_in_tree() and _admission.is_valid() and _admission.call() == true


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree() or not event.is_action(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_retire_buttons()


func _on_retry_activated() -> void:
	if _retry_admitted(): retry_requested.emit()


func _on_cancel_activated() -> void:
	if _cancel_admitted(): cancel_requested.emit()


func _retire_buttons() -> void:
	if is_instance_valid(retry_button): retry_button.retire_input()
	if is_instance_valid(cancel_button): cancel_button.retire_input()


func _notification(what: int) -> void:
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE or not _active: return
	var element := get_accessibility_element()
	if element.is_valid():
		DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_DIALOG)
		DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_MODAL, true)
