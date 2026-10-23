extends PanelContainer
class_name BoxMeter

## Displays a labeled value as a row of filled/unfilled boxes (prompt_docs/INDEX.md).

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _box_grid: GridContainer = %BoxGrid

var stat_id: String = ""
var display_name_key: String = ""

func _ready() -> void:
	refresh_localization()
	if has_node("/root/LocalizationManager"):
		var loc := get_node("/root/LocalizationManager")
		if not loc.locale_changed.is_connected(_on_locale_changed):
			loc.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	refresh_localization()

func set_meter(value: int, max_value: int, label_key: String = "") -> void:
	if label_key != "":
		display_name_key = label_key
	if is_instance_valid(_value_label):
		_value_label.text = str(value)
	_rebuild_boxes(value, max_value)

func _rebuild_boxes(value: int, max_value: int) -> void:
	if not is_instance_valid(_box_grid):
		return
	for child in _box_grid.get_children():
		child.queue_free()
	var safe_max: int = max(max_value, 0)
	for i in range(safe_max):
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(12, 12)
		box.color = Color(0.8, 0.3, 0.3) if i < value else Color(0.25, 0.25, 0.25)
		_box_grid.add_child(box)

func refresh_localization() -> void:
	if not is_instance_valid(_name_label):
		return
	if display_name_key != "" and has_node("/root/LocalizationManager"):
		_name_label.text = get_node("/root/LocalizationManager").t(display_name_key)
