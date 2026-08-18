extends Control
class_name DatingScene

## Solo/group/twofriends dating PRESENTATION (prompt_docs/requirements/dating_endings.md).
##
## dwm-p2r.8 (Plan-05 Task 2): this scene deliberately owns NO narrative seam. Dating timelines are
## started through DialogicBridge with stable manifest timeline IDs by the flow that routes here --
## never from this scene, never by physical path, and never by inspecting a Dialogic event index.
##
## Plan 01 Task 8 (dwm-p2r.14): it now owns no gameplay seam either. `SceneRouter` injects the exact
## retained `DatingPresentationPort` and the coordinator-owned command while this scene is still
## OFF-TREE, and that port is the only thing `_ready()`, button input, or challenge completion may
## call. The scene decides no date outcome, touches no affection, invitation, day, Schedule or
## ending, and starts no challenge -- the port's physical owner does that.
##
## IN PHASE 2R THIS SCENE IS NEVER LEGITIMATELY REACHED. The Dating port is deliberately
## production-unconfigured, so every Dating route fails closed before routing until `dwm-oyo.4`
## configures it. An unconfigured scene therefore renders nothing rather than improvising a date.

const _PORT_METHODS: Array[String] = ["begin", "complete"]

var _presentation_port: Object = null
var _presentation_command: Dictionary = {}

@onready var dating_background: TextureRect = %DatingBackground
@onready var character_zone_left: Control = %CharacterZoneLeft
@onready var character_zone_center: Control = %CharacterZoneCenter
@onready var character_zone_right: Control = %CharacterZoneRight
@onready var previous_dialogue_list: VBoxContainer = %PreviousDialogueList
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var challenge_overlay_host: Control = %ChallengeOverlayHost

func _ready() -> void:
	# Deliberately empty of gameplay. A Dating scene reaching the tree must not start a challenge,
	# read a friend's state, or ask an autoload for anything.
	pass


## The ONE injection seam. Called by `SceneRouter` before `add_child()`. Identical replay is
## idempotent; a replacement port is refused rather than adopted.
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


## The exact command this scene was given, detached so a caller cannot mutate the scene's copy.
func get_presentation_projection() -> Dictionary:
	return _presentation_command.duplicate(true)


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}


## Forwards the narrative bridge to the hosted DialogueBox (dwm-p2r.8, Plan-05 Task 4). The scene
## never calls the bridge itself; it only wires the box that emits skip commands.
func configure_narrative_bridge(bridge: Object) -> Dictionary:
	if not is_instance_valid(dialogue_box) or not dialogue_box.has_method("configure_narrative_bridge"):
		return {"ok": false, "code": &"missing_dialogue_box", "message": "", "details": {}}
	return dialogue_box.configure_narrative_bridge(bridge)


## The visible transcript is RUN-specific presentation and is never the ProfileManager visited set:
## visited history is global and persists across runs, while this list resets with the scene.
func append_previous_dialogue_line(rendered_text: String) -> void:
	if not is_instance_valid(previous_dialogue_list):
		return
	var line := Label.new()
	line.text = rendered_text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	previous_dialogue_list.add_child(line)
