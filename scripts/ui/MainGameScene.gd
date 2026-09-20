extends Control
class_name MainGameScene

## In-run shell; fresh entry goes directly to the desktop launcher.

const COMPUTER_DESKTOP_SCENE := preload("res://scenes/desktop/ComputerDesktop.tscn")
const ART_MANIFEST := preload("res://scripts/data/ArtManifest.gd")
const PANEL_SPLIT := preload("res://scripts/ui/desktop/DesktopPanelSplit.gd")

@onready var _computer_panel: PanelContainer = %ComputerPanel
@onready var _angela_image: Control = %AngelaImage

var _computer_desktop_instance: Node = null

func _ready() -> void:
	_mount_angela_art()
	_ensure_computer_desktop()
	%AngelaPanel.resized.connect(_layout_angela_overlay)
	%StatHud.get_node("%Rows").minimum_size_changed.connect(_layout_angela_overlay)
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null:
		localization.locale_changed.connect(_refresh_split_presentation)
	_refresh_split_presentation()
	%StatHud.theme_changed.connect(_refresh_split_presentation)
	_layout_angela_overlay.call_deferred()

func _layout_angela_overlay() -> void:
	var hud: Control = %StatHud
	var rows: Control = hud.get_node("%Rows")
	var natural_height: float = rows.get_combined_minimum_size().y + hud.get_theme_stylebox("panel").get_minimum_size().y
	# Keep the whole card and native scroll rail above the divider's hit target.
	var handle_top: float = maxf(0.0, (%AngelaPanel.size.y - PANEL_SPLIT.HANDLE_SIZE.y) * 0.5)
	hud.offset_left = 16.0
	hud.offset_right = -16.0
	hud.offset_bottom = hud.offset_top + minf(natural_height, maxf(0.0, handle_top - hud.offset_top - 12.0))

func _refresh_split_presentation(_locale_id: String = "") -> void:
	var localization := get_node_or_null("/root/LocalizationManager")
	var locale := str(localization.get_locale()) if localization != null else "en"
	var copy: Array = {
		"en": ["Resize Angela panel", "Drag horizontally. Left/Right adjust width; Home/End use the minimum/maximum."],
		"zh-CN": ["调整安吉拉面板大小", "横向拖动。左右键调整宽度，Home/End 键设为最小/最大。"],
		"zh-HK": ["調整安吉拉面板大小", "橫向拖動。左右鍵調整寬度，Home/End 鍵設為最小/最大。"],
	}.get(locale, ["Resize Angela panel", "Drag horizontally to resize."])
	if $RootHBox.theme != %StatHud.theme:
		$RootHBox.theme = %StatHud.theme
	$RootHBox.set_handle_accessibility(copy[0], copy[1])
	_layout_angela_overlay.call_deferred()

func _mount_angela_art() -> void:
	for asset_id: String in ["shell.background", "shell.character.angela", "shell.keepsakes"]:
		var texture := ART_MANIFEST.get_texture(asset_id)
		if texture == null: continue
		var layer := TextureRect.new()
		layer.name = asset_id.get_slice(".", asset_id.get_slice_count(".") - 1).to_pascal_case() + "Artwork"
		_angela_image.add_child(layer)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
