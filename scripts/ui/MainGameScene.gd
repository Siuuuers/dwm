extends Control
class_name MainGameScene

## In-run shell; fresh entry goes directly to the desktop launcher.

const COMPUTER_DESKTOP_SCENE := preload("res://scenes/desktop/ComputerDesktop.tscn")
const ART_MANIFEST := preload("res://scripts/data/ArtManifest.gd")

@onready var _computer_panel: PanelContainer = %ComputerPanel
@onready var _angela_image: Control = %AngelaImage

var _computer_desktop_instance: Node = null

func _ready() -> void:
	_mount_angela_art()
	_ensure_computer_desktop()

func _mount_angela_art() -> void:
	for asset_id: String in ["shell.background", "shell.character.angela", "shell.keepsakes"]:
		var texture := ART_MANIFEST.get_texture(asset_id)
		if texture == null: continue
		var layer := TextureRect.new()
		layer.name = asset_id.get_slice(".", asset_id.get_slice_count(".") - 1).to_pascal_case() + "Artwork"
		_angela_image.add_child(layer)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.texture = texture
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ensure_computer_desktop() -> void:
	if is_instance_valid(_computer_desktop_instance):
		return
	if not is_instance_valid(_computer_panel):
		return
	_computer_desktop_instance = COMPUTER_DESKTOP_SCENE.instantiate()
	_computer_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_computer_panel.add_child(_computer_desktop_instance)
