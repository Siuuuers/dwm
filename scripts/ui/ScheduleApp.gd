extends AppWindowBase
class_name ScheduleApp

## Schedule app window: action row, invitation row, 7-box bar, Done flow (FLOWS.md §2, §9).

@onready var action_button_row: HBoxContainer = %ActionButtonRow
@onready var invitation_button_row: HBoxContainer = %InvitationButtonRow
@onready var schedule_bar: HBoxContainer = %ScheduleBar
@onready var gift_picker_panel: Control = %GiftPickerPanel
@onready var bottom_button_row: HBoxContainer = %BottomButtonRow
@onready var status_label: Label = %StatusLabel
@onready var minesweeper_warning_alert: Control = %MinesweeperWarningAlert

var _done_pressed_guard: bool = false

func _ready() -> void:
	super._ready()
	if is_instance_valid(gift_picker_panel):
		gift_picker_panel.visible = false
	if is_instance_valid(minesweeper_warning_alert):
		minesweeper_warning_alert.visible = false
