extends AppWindowBase
class_name MinesweeperApp

## Minesweeper app window. Placeholder difficulty/status/simulation controls (FLOWS.md §9, PHASES.md 3B1).

@onready var difficulty_tabs: TabBar = %DifficultyTabs
@onready var status_row: HBoxContainer = %StatusRow
@onready var tool_row: HBoxContainer = %ToolRow
@onready var task_list_panel: Control = %TaskListPanel
@onready var board_scroll: ScrollContainer = %BoardScroll
@onready var simulation_buttons: HBoxContainer = %SimulationButtons
@onready var invitation_notification: Control = %InvitationNotification

func _ready() -> void:
	super._ready()
	if is_instance_valid(task_list_panel):
		task_list_panel.visible = false
	if is_instance_valid(invitation_notification):
		invitation_notification.visible = false
