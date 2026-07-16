extends Control
class_name HospitalScene

## Hospital recovery scene (FLOWS.md §6, §9).

const TIMELINE_ID := "hospital.faint"

@onready var _hospital_body_label: Label = %HospitalBodyLabel
@onready var _continue_button: Button = %ContinueButton

var _dialogic_blocked: bool = false

func _ready() -> void:
	if is_instance_valid(_continue_button) and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	_start_timeline()

func _start_timeline() -> void:
	if not has_node("/root/DialogicBridge"):
		return
	var bridge := get_node("/root/DialogicBridge")
	if not bridge.is_dialogic_available():
		_dialogic_blocked = true
		push_warning("Dialogic 2 addon file does not exist.")
		return
	bridge.start_timeline_id(TIMELINE_ID)

func _on_continue_pressed() -> void:
	if not has_node("/root/GameState") or not has_node("/root/SceneRouter"):
		return
	var gs := get_node("/root/GameState")
	var router := get_node("/root/SceneRouter")
	# apply_hospital_recovery_and_advance_day() performs the day advance (or sets the Day-8
	# ending marker) internally; caller must not call any other day-advance (FLOWS.md §6).
	var advanced: bool = gs.apply_hospital_recovery_and_advance_day()
	if advanced:
		router.goto_main()
	else:
		router.goto_ending()
