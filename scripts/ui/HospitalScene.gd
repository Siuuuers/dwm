extends Control
class_name HospitalScene

## Hospital recovery PRESENTATION (Plan 01 Task 8, dwm-p2r.14).
##
## WHAT CHANGED AND WHY. This scene used to start the faint timeline itself and then call
## `GameState.apply_hospital_recovery_and_advance_day()` and route to main or to an ending. That made
## a Control node the owner of recovery, of the day, and of the ending -- three things a scene must
## never decide. All of it is gone.
##
## Retains the coordinator-owned command. The existing Dialogic owner presents
## the shared fainting DTL, with Sylvia art only when eligible. Normal dialogue
## completion returns to the resolver; this host owns no controls or gameplay.

const _PORT_METHODS: Array[String] = ["begin", "complete"]
const _CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const _FROZEN_CONTEXT := preload("res://scripts/narrative/HospitalFrozenContext.gd")

## Pure projection of already validated Run receipts. A different day/source never supplies art.
static func art_participants(contacts: Dictionary, context: Dictionary, committed_schedule: Dictionary = {}) -> Array[String]:
	if context.has("presentation"):
		var checked := _FROZEN_CONTEXT.validate(context)
		if checked.get("ok", false) and checked.value.presentation.fields.sylvia_eligible:
			return ["sylvia"]
		return []
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
var _completion_recovery: WitnessedTransportRecovery
var _completion_retry: Callable
var _completion_admission: Callable


## Technical recovery appears only after the retained coordinator reports a failed step.
## It retries that coordinator; the scene never acknowledges or restarts narrative playback.
func show_completion_recovery(retry: Callable, admission: Callable) -> bool:
	if not retry.is_valid() or not admission.is_valid() or admission.call() != true:
		return false
	_completion_retry = retry
	_completion_admission = admission
	if not is_instance_valid(_completion_recovery):
		var layer := CanvasLayer.new()
		layer.layer = 90
		add_child(layer)
		_completion_recovery = preload("res://scenes/ui/witnessed/WitnessedTransportRecovery.tscn").instantiate()
		layer.add_child(_completion_recovery)
		if not _completion_recovery.bind_owners(get_node_or_null("/root/LocalizationManager"),
				get_node_or_null("/root/InputManager"), _completion_retry_admitted):
			layer.queue_free()
			_completion_recovery = null
			return false
		_completion_recovery.retry_requested.connect(_retry_completion)
		var profile := get_node_or_null("/root/ProfileManager")
		var localization := get_node_or_null("/root/LocalizationManager")
		if profile != null: profile.preference_changed.connect(_on_recovery_preference_changed)
		if localization != null: localization.locale_changed.connect(_refresh_completion_recovery)
	return _refresh_completion_recovery()


func dismiss_completion_recovery() -> void:
	_completion_retry = Callable()
	_completion_admission = Callable()
	if is_instance_valid(_completion_recovery): _completion_recovery.dismiss()


func _completion_retry_admitted() -> bool:
	return is_inside_tree() and get_tree().current_scene == self and _completion_retry.is_valid() \
		and _completion_admission.is_valid() and _completion_admission.call() == true


func _retry_completion() -> void:
	if not _completion_retry_admitted(): return
	var retry := _completion_retry
	dismiss_completion_recovery()
	retry.call()


func _on_recovery_preference_changed(_path: StringName, _value: Variant) -> void:
	_refresh_completion_recovery()


func _refresh_completion_recovery(_locale: String = "") -> bool:
	if not is_instance_valid(_completion_recovery) or not _completion_retry_admitted(): return false
	var profile := get_node_or_null("/root/ProfileManager")
	var localization := get_node_or_null("/root/LocalizationManager")
	if profile == null or localization == null: return false
	var presentation := preload("res://scripts/ui/witnessed/WitnessedRunPresentation.gd").read(get_node_or_null("/root/GameState"))
	if not _completion_recovery.configure_presentation(str(localization.get_locale()),
		int(profile.get_preference("preferences.accessibility.text_size", 100)),
		str(presentation.get("palette", "AfterHours")),
		bool(profile.get_preference("preferences.accessibility.high_contrast", false)),
		str(profile.get_preference("preferences.accessibility.colour_differentiation", "standard")),
		bool(profile.get_preference("preferences.accessibility.large_targets", false)),
		str(profile.get_preference("preferences.accessibility.font_style", "pixel"))): return false
	return _completion_recovery.present(true, false, &"hospital")


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
