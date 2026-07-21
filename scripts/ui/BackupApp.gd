extends AppWindowBase
class_name BackupApp

## Save/Load app window: 3x3 grid (autosave/quick/slots 1-7) (prompt_docs/requirements/persistence.md).

@onready var mode_tabs: TabBar = %ModeTabs
@onready var save_grid: GridContainer = %SaveGrid
@onready var status_label: Label = %StatusLabel
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	super._ready()
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_signal("save_capability_changed"):
		save_manager.save_capability_changed.connect(_on_save_capability_changed)


func _on_save_capability_changed(capability: Dictionary) -> void:
	# Disable only save controls; silent locks (e.g. the Minesweeper board)
	# show no unavailable message (plan 2026-07-17-phase-2r-03 Task 6).
	var enabled: bool = bool(capability.get("enabled", true))
	if save_grid == null:
		return
	for row in save_grid.get_children():
		if row != null and row.has_method("set_save_enabled"):
			row.set_save_enabled(enabled)
