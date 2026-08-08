extends Control
class_name GalleryScene

## Read-only gallery of seen endings (prompt_docs/requirements/dating_endings.md).

@onready var _title_label: Label = %TitleLabel
@onready var _ending_tile_grid: GridContainer = %EndingTileGrid
@onready var _return_button: Button = %ReturnButton

const ALL_ENDING_IDS := [
	"alone",
	"priscilla.sweet", "priscilla.dark", "priscilla.observation",
	"lavinia.sweet", "lavinia.dark", "lavinia.observation",
	"sylvia.sweet", "sylvia.dark", "sylvia.special",
	"priscilla_lavinia",
]

func _ready() -> void:
	if is_instance_valid(_return_button) and not _return_button.pressed.is_connected(_on_return_pressed):
		_return_button.pressed.connect(_on_return_pressed)
	_refresh_tiles()

func _refresh_tiles() -> void:
	if not is_instance_valid(_ending_tile_grid):
		return
	for child in _ending_tile_grid.get_children():
		child.queue_free()
	if not has_node("/root/ProfileManager"):
		return
	var profile := get_node("/root/ProfileManager")
	var loc = get_node("/root/LocalizationManager") if has_node("/root/LocalizationManager") else null
	for ending_id in ALL_ENDING_IDS:
		if not profile.has_gallery_unlock("ending." + ending_id):
			continue
		var tile := Button.new()
		tile.focus_mode = Control.FOCUS_ALL
		var title_key := "gallery.ending.%s.title" % ending_id
		tile.text = loc.t(title_key) if loc != null else title_key
		_ending_tile_grid.add_child(tile)

func _on_return_pressed() -> void:
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").goto_menu()
