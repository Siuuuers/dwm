extends Control
class_name DatingScene

## Solo/group/twofriends dating scene (prompt_docs/requirements/dating_endings.md).
##
## dwm-p2r.8 (Plan-05 Task 2): this scene deliberately owns NO narrative seam. Dating timelines are
## started through DialogicBridge with stable manifest timeline IDs by the flow that routes here --
## never from this scene, never by physical path, and never by inspecting a Dialogic event index.

@onready var dating_background: TextureRect = %DatingBackground
@onready var character_zone_left: Control = %CharacterZoneLeft
@onready var character_zone_center: Control = %CharacterZoneCenter
@onready var character_zone_right: Control = %CharacterZoneRight
@onready var previous_dialogue_list: VBoxContainer = %PreviousDialogueList
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var challenge_overlay_host: Control = %ChallengeOverlayHost

func _ready() -> void:
	pass


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
