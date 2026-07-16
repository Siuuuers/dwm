extends PanelContainer
class_name SaveSlotRow

## Single row in BackupApp's SaveGrid (FLOWS.md §9).

@onready var slot_title_label: Label = %SlotTitleLabel
@onready var metadata_label: Label = %MetadataLabel
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var delete_button: Button = %DeleteButton
@onready var warning_label: Label = %WarningLabel

var slot_id: int = -1
