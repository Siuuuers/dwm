extends Control
class_name HospitalScene

## Hospital recovery PRESENTATION (Plan 01 Task 8, dwm-p2r.14).
##
## WHAT CHANGED AND WHY. This scene used to start the faint timeline itself and then call
## `GameState.apply_hospital_recovery_and_advance_day()` and route to main or to an ending. That made
## a Control node the owner of recovery, of the day, and of the ending -- three things a scene must
## never decide. All of it is gone.
##
## Retains the coordinator-owned presentation command. Live captions are mounted by the existing
## Dialogic playback owner for Sylvia-present scenes. Ordinary fainting shows a short notice
## whose Continue button acknowledges the retained owner command. It starts no timeline, decides
## no outcome, and mutates no stat, day, invitation, Schedule or ending. `SceneRouter` injects the
## command while this scene is still OFF-TREE, so it cannot reach `_ready()` unconfigured.
##
## AN UNCONFIGURED SCENE DOES NOTHING. That is deliberate: a Hospital scene that appeared without a
## committed presentation intent behind it would be a bug, and showing an empty room is a far better
## failure than inventing a recovery.

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const _PORT_METHODS: Array[String] = ["begin", "complete", "acknowledge_notice"]
const _CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const _FROZEN_CONTEXT := preload("res://scripts/narrative/HospitalFrozenContext.gd")

## Pure projection of already validated Run receipts. A different day/source never supplies art.
static func art_participants(contacts: Dictionary, context: Dictionary, committed_schedule: Dictionary = {}) -> Array[String]:
	if context.has("presentation"):
		var checked := _FROZEN_CONTEXT.validate(context)
		return ["sylvia"] if checked.get("ok", false) and checked.value.presentation.fields.sylvia_eligible else []
	if context.get("kind") != "hospital" or not context.get("source_entry_ids") is Array \
			or not context.get("miss_receipt_ids") is Array or context.get("day") not in range(1, 8):
		return []
	var witnesses: Variant = contacts.get("sylvia_hospital_witness_receipts", {})
	if not witnesses is Dictionary: return []
	for value: Variant in witnesses.values():
		if not value is Dictionary: continue
		var witness: Dictionary = value
		if witness.get("kind") != "sylvia_hospital_witness" \
				or int(witness.get("care_followup_day", -1)) != int(context.day) + 1:
			continue
		if witness.get("resolution_kind") == "condition_hospital":
			if str(witness.get("source_receipt_id", "")) in context.source_entry_ids \
					and str(witness.get("hospital_miss_receipt_id", "")) in context.miss_receipt_ids:
				return ["sylvia"]
		elif witness.get("resolution_kind") == "schedule_done" \
				and str(witness.get("schedule_entry_id", "")) in context.source_entry_ids:
			return ["sylvia"]
	# Schedule-Done writes the witness after physical presentation. Its current committed
	# entry plus the accepted Contacts receipt already prove attendance before that write.
	if committed_schedule.get("day") == context.day:
		for entry: Dictionary in committed_schedule.get("entries", []):
			if entry.get("action_kind") != "solo" or entry.get("participants") != ["sylvia"] \
					or str(entry.get("schedule_entry_id", "")) not in context.source_entry_ids: continue
			var found: Dictionary = _CONTACTS.get_schedule_source_receipt(contacts, str(entry.get("source_receipt_id", "")))
			if not found.get("ok", false): continue
			var receipt: Dictionary = found.value.receipt
			if receipt.get("action_id") == entry.get("action_id") and receipt.get("day") == context.day \
					and receipt.get("participants") == ["sylvia"]:
				return ["sylvia"]
	return []

var _presentation_port: Object = null
var _presentation_command: Dictionary = {}


@onready var _notice_panel: Control = %FaintNotice
@onready var _continue_button: Button = %ContinueButton
@onready var _message_label: Label = %Message


func _ready() -> void:
	if not is_presentation_configured(): return
	var context: Dictionary = _presentation_command.get("context", {})
	var sylvia_present := false
	if context.has("presentation"):
		sylvia_present = art_participants({}, context) == ["sylvia"]
	else:
		var game: Node = get_node_or_null("/root/GameState")
		var contacts: Dictionary = game.contacts if game != null and game.get("contacts") is Dictionary else {}
		var schedule: Dictionary = game._canonical_committed_schedule() if game != null and game.has_method("_canonical_committed_schedule") else {}
		sylvia_present = art_participants(contacts, context, schedule) == ["sylvia"]
	var profile := get_node_or_null("/root/ProfileManager")
	var localization := get_node_or_null("/root/LocalizationManager")
	if profile != null and profile.has_signal("preference_changed"):
		profile.connect("preference_changed", _on_presentation_preference_changed)
	if localization != null and localization.has_signal("locale_changed"):
		localization.connect("locale_changed", _refresh_notice_presentation)
	_refresh_notice_presentation()
	_notice_panel.visible = not sylvia_present
	if not sylvia_present:
		_continue_button.pressed.connect(_acknowledge_notice)
		_continue_button.grab_focus()


func _refresh_notice_presentation(_locale_id: String = "") -> void:
	var locale_manager: Node = get_node_or_null("/root/LocalizationManager")
	var locale := str(locale_manager.get_locale()).replace("_", "-") if locale_manager != null else "en"
	if locale not in ["en", "zh-CN", "zh-HK", "ja", "ko"]: locale = "en"
	var profile: Node = get_node_or_null("/root/ProfileManager")
	var percent := int(profile.get_preference("preferences.accessibility.text_size", 100)) if profile != null else 100
	var font_style := str(profile.get_preference("preferences.accessibility.font_style", "pixel")) if profile != null else "pixel"
	var scale := float(percent) / 100.0
	_message_label.text = {"en": "You fainted.", "zh-CN": "你晕倒了。", "zh-HK": "你暈倒了。", "ja": "気を失いました。", "ko": "정신을 잃었습니다."}[locale]
	_continue_button.text = {"en": "Continue", "zh-CN": "继续", "zh-HK": "繼續", "ja": "続ける", "ko": "계속"}[locale]
	for control: Control in [_message_label, _continue_button]:
		control.add_theme_font_override("font", TYPOGRAPHY.font(locale, percent, font_style))
		control.language = locale
	_message_label.add_theme_font_size_override("font_size", TYPOGRAPHY.font_size(locale, percent, 24, font_style))
	_continue_button.add_theme_font_size_override("font_size", TYPOGRAPHY.font_size(locale, percent, 20, font_style))
	_continue_button.custom_minimum_size.y = roundf(48.0 * scale)
	_notice_panel.custom_minimum_size = Vector2(roundf(360.0 * scale), roundf(144.0 * scale))


func _on_presentation_preference_changed(path: StringName, _value: Variant) -> void:
	if path in [&"preferences.accessibility.text_size", &"preferences.accessibility.font_style"]:
		_refresh_notice_presentation()


func _acknowledge_notice() -> void:
	_continue_button.disabled = true
	var result: Variant = _presentation_port.call(&"acknowledge_notice", _presentation_command.duplicate(true))
	if not result is Dictionary or not result.get("ok", false):
		_continue_button.disabled = false
	else:
		_allow_notice_retry.call_deferred()


func _allow_notice_retry() -> void:
	if is_inside_tree() and not is_queued_for_deletion() and get_tree().current_scene == self and not _presentation_command.is_empty(): _continue_button.disabled = false


## The ONE injection seam. Called by `SceneRouter` before `add_child()`, so `_ready()` always runs
## against a configured scene or against nothing at all. Identical replay is idempotent; a
## replacement port is refused rather than adopted.
func configure_presentation(port: Object, presentation_command: Dictionary) -> Dictionary:
	if port == null or not _has_methods(port, _PORT_METHODS):
		return _fail(&"invalid_presentation_port", "the presentation port contract is incomplete")
	if typeof(presentation_command) != TYPE_DICTIONARY or presentation_command.is_empty():
		return _fail(&"invalid_presentation_command", "a presentation command is required")
	if presentation_command.get("context") is Dictionary and presentation_command.context.has("presentation"):
		var frozen := _FROZEN_CONTEXT.validate(presentation_command.context)
		if not frozen.get("ok", false): return frozen
	if _presentation_port != null and _presentation_port != port:
		return _fail(&"presentation_port_already_configured",
			"a configured scene never adopts a replacement port")
	_presentation_port = port
	_presentation_command = presentation_command.duplicate(true)
	return {"ok": true, "code": &"ok",
		"value": {"port_instance_id": port.get_instance_id()}, "receipt": {}}


func is_presentation_configured() -> bool:
	return _presentation_port != null and not _presentation_command.is_empty()


## The exact command this scene was given, for tests and for a restore that re-projects it. Detached,
## so a caller cannot mutate the scene's copy.
func get_presentation_projection() -> Dictionary:
	return _presentation_command.duplicate(true)


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
