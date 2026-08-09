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
