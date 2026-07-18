extends PanelContainer
class_name ScheduleEntryBox

## Single scheduled action/date entry in the ScheduleBar (prompt_docs/INDEX.md).

@onready var icon_image: TextureRect = %EntryIconImage
@onready var label: Label = %EntryLabel
@onready var gift_box: Control = %GiftBox

var entry_index: int = -1
