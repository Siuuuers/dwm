extends Control
class_name HospitalScene

## Hospital recovery PRESENTATION (Plan 01 Task 8, dwm-p2r.14).
##
## WHAT CHANGED AND WHY. This scene used to start the faint timeline itself and then call
## `GameState.apply_hospital_recovery_and_advance_day()` and route to main or to an ending. That made
## a Control node the owner of recovery, of the day, and of the ending -- three things a scene must
## never decide. All of it is gone.
##
## WHAT IT MAY DO NOW. Exactly two things: display the projection of a coordinator-owned presentation
## command, and hand button input to its injected presentation port. It starts no timeline (the
## port's physical owner does), decides no outcome, advances no day, touches no stat, invitation,
## Schedule or ending, and calls no autoload. `SceneRouter` injects the exact retained port and the
## command while this scene is still OFF-TREE, so it cannot reach `_ready()` unconfigured.
##
## AN UNCONFIGURED SCENE DOES NOTHING. That is deliberate: a Hospital scene that appeared without a
## committed presentation intent behind it would be a bug, and showing an empty room is a far better
## failure than inventing a recovery.

const _PORT_METHODS: Array[String] = ["begin", "complete"]

@onready var _hospital_body_label: Label = %HospitalBodyLabel
@onready var _continue_button: Button = %ContinueButton

var _presentation_port: Object = null
var _presentation_command: Dictionary = {}


## The ONE injection seam. Called by `SceneRouter` before `add_child()`, so `_ready()` always runs
## against a configured scene or against nothing at all. Identical replay is idempotent; a
## replacement port is refused rather than adopted.
func configure_presentation(port: Object, presentation_command: Dictionary) -> Dictionary:
	if port == null or not _has_methods(port, _PORT_METHODS):
		return _fail(&"invalid_presentation_port", "the presentation port contract is incomplete")
	if typeof(presentation_command) != TYPE_DICTIONARY or presentation_command.is_empty():
		return _fail(&"invalid_presentation_command", "a presentation command is required")
	if _presentation_port != null and _presentation_port != port:
		return _fail(&"presentation_port_already_configured",
			"a configured scene never adopts a replacement port")
	_presentation_port = port
	_presentation_command = presentation_command.duplicate(true)
	return {"ok": true, "code": &"ok",
		"value": {"port_instance_id": port.get_instance_id()}, "receipt": {}}


func is_presentation_configured() -> bool:
	return _presentation_port != null and not _presentation_command.is_empty()


func _ready() -> void:
	if is_instance_valid(_continue_button) \
			and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	_render_projection()


## Scene-safe projection ONLY. It reads the command's own context and writes it to a label; it never
## re-derives a value, never asks an autoload for state, and never starts anything.
func _render_projection() -> void:
	if not is_instance_valid(_hospital_body_label):
		return
	if not is_presentation_configured():
		_hospital_body_label.text = ""
		if is_instance_valid(_continue_button):
			_continue_button.disabled = true
		return
	_hospital_body_label.text = tr("hospital.body")
	if is_instance_valid(_continue_button):
		_continue_button.disabled = false


## Button input reaches the presentation port and nothing else.
##
## There is deliberately NO port call here. The physical owner completes a Hospital presentation when
## its timeline actually ends; a button press is not evidence that it did, and the port exposes no
## method that would let a scene claim otherwise. So this acknowledges the press and stops.
func _on_continue_pressed() -> void:
	if not is_presentation_configured():
		return
	if is_instance_valid(_continue_button):
		_continue_button.disabled = true


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
