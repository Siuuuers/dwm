extends Control
class_name ComputerDesktop

## Desktop app host: icon grid + single visible app window + notification layer (prompt_docs/requirements/desktop_minesweeper_handoff.md).

@onready var icon_grid: GridContainer = %IconGrid
@onready var app_window_host: Control = %AppWindowHost
@onready var notification_layer: Control = %NotificationLayer

var _cached_app_windows: Dictionary = {}

func _ready() -> void:
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		if not gs.daily_state_reset.is_connected(_on_daily_state_reset):
			gs.daily_state_reset.connect(_on_daily_state_reset)

func _on_daily_state_reset() -> void:
	for window in _cached_app_windows.values():
		if is_instance_valid(window):
			window.queue_free()
	_cached_app_windows.clear()
