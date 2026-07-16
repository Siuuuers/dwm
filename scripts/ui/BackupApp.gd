extends AppWindowBase
class_name BackupApp

## Save/Load app window: 3x3 grid (autosave/quick/slots 1-7) (FLOWS.md §9, CONTRACTS.md §6).

@onready var mode_tabs: TabBar = %ModeTabs
@onready var save_grid: GridContainer = %SaveGrid
@onready var status_label: Label = %StatusLabel
@onready var return_button: Button = %ReturnButton
