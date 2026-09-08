extends Control
class_name EndingScene

## Presents the exact saved ending command; only physical completion advances its cursor.

# get_node_or_null keeps the scene instantiable bare (e.g. EndingScene.new() in tests) without
# erroring on the unique-name lookups when the .tscn children are absent.
@onready var _ending_title_label: Label = get_node_or_null("%EndingTitleLabel")
@onready var _ending_body_label: Label = get_node_or_null("%EndingBodyLabel")
@onready var _return_to_menu_button: Button = get_node_or_null("%ReturnToMenuButton")

func _ready() -> void:
	if is_instance_valid(_return_to_menu_button) and not _return_to_menu_button.pressed.is_connected(_on_return_pressed):
		_return_to_menu_button.pressed.connect(_on_return_pressed)
	_set_playback_status(false)
	# Routing must finish installing current_scene before a no-dialogue ending can return.
	_show_ending.call_deferred()


func _show_ending() -> void:
	if not _pending_ending_command.is_empty() or _finished: return
	if is_instance_valid(_ending_title_label): _ending_title_label.text = "Ending"
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
	if is_instance_valid(_return_to_menu_button):
		_return_to_menu_button.disabled = not retry and not _finished
		_return_to_menu_button.text = "Retry" if retry else "Return to title"
	if is_instance_valid(_ending_body_label):
		_ending_body_label.text = "The ending could not continue. Retry to resume this step." if retry else ""


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
