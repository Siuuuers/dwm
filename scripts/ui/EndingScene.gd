extends Control
class_name EndingScene

## Ending scene: selects timeline by GameState.route_context["ending_id"] (prompt_docs/requirements/dating_endings.md).

# get_node_or_null keeps the scene instantiable bare (e.g. EndingScene.new() in tests) without
# erroring on the unique-name lookups when the .tscn children are absent.
@onready var _ending_title_label: Label = get_node_or_null("%EndingTitleLabel")
@onready var _ending_body_label: Label = get_node_or_null("%EndingBodyLabel")
@onready var _return_to_menu_button: Button = get_node_or_null("%ReturnToMenuButton")

func _ready() -> void:
	if is_instance_valid(_return_to_menu_button) and not _return_to_menu_button.pressed.is_connected(_on_return_pressed):
		_return_to_menu_button.pressed.connect(_on_return_pressed)
	_show_ending()

func _show_ending() -> void:
	if not has_node("/root/GameState"):
		return
	var gs := get_node("/root/GameState")
	var ending_id: String = String(gs.route_context.get("ending_id", ""))
	if ending_id == "":
		ending_id = "ending.alone"
	if is_instance_valid(_ending_title_label):
		_ending_title_label.text = ending_id
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_music_context("ending", {"ending_id": ending_id})
	if has_node("/root/DialogicBridge"):
		var bridge := get_node("/root/DialogicBridge")
		if bridge.is_dialogic_available():
			bridge.start_timeline_id(ending_id)
		else:
			push_warning("Dialogic 2 addon file does not exist.")
	# Planned blocker: Plan 04 commits the run-scoped gallery transaction after ending playback.

func _on_return_pressed() -> void:
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").goto_menu()


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
	var next: Dictionary = _ending_state_port.request_next_ending_command()
	if not next.get("ok", false):
		return next
	var command: Dictionary = next["value"]
	# Only a play_ending command starts a timeline; gallery/complete commands are applied by the
	# state port itself and carry no playback to resume.
	if str(command.get("kind", "")) != "play_ending":
		return {"ok": true, "code": &"ok", "value": {"command": command.duplicate(true)}}
	var started: Dictionary = _ending_playback_port.start_ending_id(str(command["ending_id"]), command["playback_context"])
	if not started.get("ok", false):
		return started
	_pending_ending_command = command.duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"started": true}}

func on_ending_playback_completed(completion: Dictionary) -> void:
	# A completion that does not match the pending command (or an out-of-band one after the stage
	# already advanced, which clears the pending command) is ignored.
	if not _completion_matches_pending(completion):
		return
	var context: Dictionary = _pending_ending_command["playback_context"]
	var receipt := {
		"timeline_completion_receipt_id": str(completion.get("timeline_completion_receipt_id", "")),
		"outcome": "completed",
	}
	var result: Dictionary = _ending_state_port.complete_ending_playback_stage(
		str(context["transaction_id"]), context["expected_stage"], receipt)
	if result.get("ok", false):
		# The command is consumed; a duplicate callback now finds no pending command and no-ops.
		_pending_ending_command = {}

func on_ending_playback_failed(_failure: Dictionary) -> void:
	# A failure never advances the stage. A matching failure leaves the command pending for an
	# explicit retry (resume_ending); the scene owner decides. Nothing to mutate here.
	pass

func _completion_matches_pending(completion: Dictionary) -> bool:
	if _pending_ending_command.is_empty():
		return false
	var context: Dictionary = _pending_ending_command["playback_context"]
	return str(completion.get("outcome", "")) == "completed" \
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
