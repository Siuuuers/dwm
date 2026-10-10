extends Control
class_name EndingScene

## Presents the exact saved ending command; only physical completion advances its cursor.

const TRANSPORT_BUTTON := preload("res://scripts/ui/witnessed/WitnessedTransportButton.gd")
const RECOVERY_THEME := preload("res://scripts/ui/SettingsTheme.gd")
const RUN_PRESENTATION := preload("res://scripts/ui/witnessed/WitnessedRunPresentation.gd")

# get_node_or_null keeps the scene instantiable bare (e.g. EndingScene.new() in tests) without
# erroring on the unique-name lookups when the .tscn children are absent.
@onready var _ending_body_label: Label = get_node_or_null("%EndingBodyLabel")
@onready var _return_to_menu_button: TRANSPORT_BUTTON = get_node_or_null("%ReturnToMenuButton")
@onready var _recovery_panel: PanelContainer = get_node_or_null("%RecoveryPanel")

const RECOVERY_RETRY := "witnessed.recovery.retry"
const RECOVERY_MESSAGE := "witnessed.recovery.step_failed"
var _localization: Node
var _recovery_input_bound := false
var _recovery_copy_ready := false
var _profile: Node
var _recovery_palette: StringName = &"after_hours"

func _ready() -> void:
	_localization = get_node_or_null("/root/LocalizationManager")
	_profile = get_node_or_null("/root/ProfileManager")
	var run_presentation := RUN_PRESENTATION.read(get_node_or_null("/root/GameState"))
	if run_presentation.get("palette") == "Midnight": _recovery_palette = &"midnight"
	if is_instance_valid(_profile):
		_profile.preference_changed.connect(_on_preference_changed)
	if is_instance_valid(_localization):
		_localization.locale_changed.connect(_on_locale_changed)
	if is_instance_valid(_return_to_menu_button):
		_recovery_input_bound = _return_to_menu_button.bind_admission(
			_retry_admitted, get_node_or_null("/root/InputManager"))
		_return_to_menu_button.activated.connect(_on_return_pressed)
	_set_playback_status(false)
	# Routing must finish installing current_scene before a no-dialogue ending can return.
	_show_ending.call_deferred()


func _show_ending() -> void:
	if not _pending_ending_command.is_empty() or _finished: return
	if _ending_state_port == null or _ending_playback_port == null:
		_set_playback_status(true)
		return
	var resumed := resume_ending()
	if not resumed.get("ok", false): _set_playback_status(true)


func _on_return_pressed() -> void:
	if _finished:
		_return_to_title()
	elif _retry_available:
		_retry_available = false
		_set_playback_status(false)
		if not _pending_completion.is_empty():
			on_ending_playback_completed(_pending_completion.duplicate(true))
		else:
			var resumed := resume_ending()
			if not resumed.get("ok", false): _set_playback_status(true)


func configure_ending_navigation(router: Object) -> Dictionary:
	if router == null or not router.has_method("goto_menu"):
		return _ending_fail(&"invalid_ending_navigation", "router must expose goto_menu")
	if _ending_navigation != null and _ending_navigation != router:
		return _ending_fail(&"ending_navigation_already_configured", "")
	_ending_navigation = router
	return {"ok": true, "code": &"ok"}


func _return_to_title() -> void:
	if _ending_navigation != null: _ending_navigation.goto_menu()


func _set_playback_status(retry: bool) -> void:
	_retry_available = retry
	_refresh_recovery()


func _on_locale_changed(_locale: String) -> void:
	_refresh_recovery()


func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if str(path).begins_with("preferences.accessibility."): _refresh_recovery()


func _retry_admitted() -> bool:
	return _retry_available and not _finished and _recovery_copy_ready and _recovery_input_bound


func _refresh_recovery() -> void:
	# A locale or frontier change retires in-flight input before publishing both labels.
	# Normal playback contributes no heading, error, or Return action to the witnessed stream.
	_recovery_copy_ready = false
	var restore_focus := is_instance_valid(_return_to_menu_button) and _return_to_menu_button.has_focus()
	var first_exposure := is_instance_valid(_recovery_panel) and not _recovery_panel.visible
	if is_instance_valid(_recovery_panel): _recovery_panel.hide()
	if is_instance_valid(_return_to_menu_button):
		_return_to_menu_button.retire_input()
		_return_to_menu_button.hide()
		_return_to_menu_button.disabled = true
		_return_to_menu_button.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(_ending_body_label):
		_ending_body_label.hide()
	if not _retry_available or _finished or not _recovery_input_bound \
			or not is_instance_valid(_ending_body_label) or not is_instance_valid(_localization): return
	if _localization.get_readiness() != &"ready" \
			or not _localization.has_key(RECOVERY_RETRY) or not _localization.has_key(RECOVERY_MESSAGE): return
	var retry_text: String = _localization.t(RECOVERY_RETRY)
	var message_text: String = _localization.t(RECOVERY_MESSAGE)
	if retry_text.is_empty() or message_text.is_empty(): return
	_return_to_menu_button.text = retry_text
	_return_to_menu_button.accessibility_description = message_text
	_ending_body_label.text = message_text
	_style_recovery()
	_recovery_copy_ready = true
	_ending_body_label.show()
	_return_to_menu_button.focus_mode = Control.FOCUS_ALL
	_return_to_menu_button.disabled = false
	_return_to_menu_button.show()
	if is_instance_valid(_recovery_panel): _recovery_panel.show()
	if restore_focus or first_exposure: _return_to_menu_button.grab_focus()


func _style_recovery() -> void:
	if not is_instance_valid(_recovery_panel) or not is_instance_valid(_profile): return
	var percent: int = _profile.get_preference("preferences.accessibility.text_size", 100)
	var high_contrast: bool = _profile.get_preference("preferences.accessibility.high_contrast", false)
	var colour: String = _profile.get_preference("preferences.accessibility.colour_differentiation", "standard")
	# Technical recovery stays clean; it is not a fictional week-tinted surface.
	var material := RECOVERY_THEME.build(_localization.get_locale(), percent, _recovery_palette, high_contrast, colour, 1,
		str(_profile.get_preference("preferences.accessibility.font_style", "pixel")))
	if material == null: return
	var face := material.get_color("face", "Settings")
	var ink := material.get_color("ink", "Settings")
	var rule := material.get_color("structure", "Settings")
	_recovery_panel.theme = material
	_recovery_panel.add_theme_stylebox_override("panel", RECOVERY_THEME.box(face, rule, 2))
	_ending_body_label.add_theme_color_override("font_color", ink)
	_return_to_menu_button.custom_minimum_size.y = maxf(48.0 * percent / 100.0,
		64.0 if _profile.get_preference("preferences.accessibility.large_targets", false) else 48.0)
	var focus := RECOVERY_THEME.box(Color.TRANSPARENT, material.get_color("paper_focus", "Settings"), 4)
	_return_to_menu_button.add_theme_stylebox_override("focus", focus)


# ---- Resumable ending playback (dwm-p2r.7 Task 6, req.ending.playback) ----
# The stage advances ONLY from a matching playback_completed callback, never on start.
# Ports are injected; .7 uses recording fakes, .8 supplies the real Dialogic-backed port.

const _STATE_PORT_METHODS: Array[String] = ["request_next_ending_command", "complete_ending_playback_stage"]
const _PLAYBACK_PORT_METHODS: Array[String] = ["start_ending_id", "is_ready"]
const _PLAYBACK_PORT_SIGNALS: Array[String] = ["playback_completed", "playback_failed"]

var _ending_state_port: Object = null
var _ending_playback_port: Object = null
# A non-empty pending command means a start has fired and we await its matching completion.
var _pending_ending_command: Dictionary = {}
var _last_completed_transaction_id := ""
var _pending_completion: Dictionary = {}
var _ending_navigation: Object = null
var _retry_available := false
var _finished := false

func configure_ending_ports(state_port: Object, playback_port: Object) -> Dictionary:
	if not _pending_ending_command.is_empty():
		return _ending_fail(&"ending_command_pending", "cannot reconfigure while a command is pending")
	if state_port == null or not _has_all_methods(state_port, _STATE_PORT_METHODS):
		return _ending_fail(&"invalid_state_port", "state port is missing required methods")
	if playback_port == null or not _has_all_methods(playback_port, _PLAYBACK_PORT_METHODS):
		return _ending_fail(&"invalid_playback_port", "playback port is missing required methods")
	for signal_name: String in _PLAYBACK_PORT_SIGNALS:
		if not playback_port.has_signal(signal_name):
			return _ending_fail(&"invalid_playback_port", "playback port is missing signal " + signal_name)
	if _ending_playback_port != null:
		_disconnect_playback_signals(_ending_playback_port)
	_ending_state_port = state_port
	_ending_playback_port = playback_port
	if not playback_port.is_connected("playback_completed", on_ending_playback_completed):
		playback_port.connect("playback_completed", on_ending_playback_completed)
	if not playback_port.is_connected("playback_failed", on_ending_playback_failed):
		playback_port.connect("playback_failed", on_ending_playback_failed)
	return {"ok": true, "code": &"ok"}

func resume_ending() -> Dictionary:
	if _ending_state_port == null or _ending_playback_port == null:
		return _ending_fail(&"ports_not_configured", "configure_ending_ports first")
	if not _pending_completion.is_empty():
		return _ending_fail(&"ending_completion_retry_required", "retry the saved physical completion")
	if not _pending_ending_command.is_empty():
		return {"ok": true, "code": &"ok", "value": {"started": true}}
	# Background commands have no physical playback. Drain the bounded gallery/completion tail;
	# stop as soon as one timeline has started and await its matching callback.
	for _guard in range(8):
		var next: Dictionary = _ending_state_port.request_next_ending_command()
		if not next.get("ok", false):
			return next
		var command: Dictionary = next["value"]
		if str(command.get("kind", "")) == "play_ending":
			var context: Dictionary = command["playback_context"]
			if str(context["transaction_id"]) == _last_completed_transaction_id:
				return _ending_fail(&"ending_stage_not_advanced",
					"state port returned the presentation that just completed")
			_pending_ending_command = command.duplicate(true)
			var started: Dictionary = _ending_playback_port.start_ending_id(
				str(command["ending_id"]), context)
			if not started.get("ok", false):
				_pending_ending_command = {}
				_set_playback_status(true)
				return started
			return {"ok": true, "code": &"ok", "value": {"started": true}}
		var expected := StringName(str(command.get("expected_stage", "")))
		var applied: Dictionary = _ending_state_port.complete_ending_playback_stage("", expected, {})
		if not applied.get("ok", false):
			_set_playback_status(true)
			return applied
		if str((applied.get("value", {}) as Dictionary).get("route", "")) == "menu":
			_finished = true
			_set_playback_status(false)
			_return_to_title()
			return {"ok": true, "code": &"ok", "value": {"route": "menu"}}
	return _ending_fail(&"ending_command_loop", "ending background commands did not terminate")


func on_ending_playback_completed(completion: Dictionary) -> void:
	# A completion that does not match the pending command (or an out-of-band one after the stage
	# already advanced, which clears the pending command) is ignored.
	if not _completion_matches_pending(completion):
		return
	if not _pending_completion.is_empty() and _pending_completion != completion: return
	_pending_completion = completion.duplicate(true)
	var context: Dictionary = _pending_ending_command["playback_context"]
	var receipt := {
		"timeline_completion_receipt_id": str(completion.get("timeline_completion_receipt_id", "")),
		"outcome": "completed",
	}
	var result: Dictionary = _ending_state_port.complete_ending_playback_stage(
		str(context["transaction_id"]), context["expected_stage"], receipt)
	if result.get("ok", false):
		# Consume before resuming so a duplicate callback cannot advance the new command.
		_last_completed_transaction_id = str(context["transaction_id"])
		_pending_ending_command = {}
		_pending_completion = {}
		var resumed: Dictionary = resume_ending()
		if not resumed.get("ok", false): _set_playback_status(true)
	else:
		# Keep the exact completion while the state owner rolls back its unsaved cursor.
		_set_playback_status(true)


func on_ending_playback_failed(failure: Dictionary) -> void:
	if _pending_ending_command.is_empty(): return
	var context: Dictionary = _pending_ending_command.playback_context
	if str(failure.get("playback_id", "")) != str(context.playback_id) \
			or str(failure.get("transaction_id", "")) != str(context.transaction_id) \
			or str(failure.get("ending_id", "")) != str(_pending_ending_command.ending_id): return
	_pending_ending_command = {}
	_pending_completion = {}
	_set_playback_status(true)


## Read-only source witness for Pause/Backup; the scene retains the exact command.
func get_presentation_projection() -> Dictionary:
	return _pending_ending_command.duplicate(true)


func _completion_matches_pending(completion: Dictionary) -> bool:
	if _pending_ending_command.is_empty():
		return false
	var context: Dictionary = _pending_ending_command["playback_context"]
	return str(completion.get("outcome", "")) == "completed" \
		and not str(completion.get("timeline_completion_receipt_id", "")).is_empty() \
		and str(completion.get("playback_id", "")) == str(context["playback_id"]) \
		and str(completion.get("transaction_id", "")) == str(context["transaction_id"]) \
		and str(completion.get("expected_stage", "")) == str(context["expected_stage"]) \
		and str(completion.get("ending_id", "")) == str(_pending_ending_command["ending_id"])

func _disconnect_playback_signals(port: Object) -> void:
	if port.is_connected("playback_completed", on_ending_playback_completed):
		port.disconnect("playback_completed", on_ending_playback_completed)
	if port.is_connected("playback_failed", on_ending_playback_failed):
		port.disconnect("playback_failed", on_ending_playback_failed)

static func _has_all_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true

static func _ending_fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
