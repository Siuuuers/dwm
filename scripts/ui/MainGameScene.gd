extends Control
class_name MainGameScene

## In-run shell; fresh entry goes directly to the desktop launcher.

const COMPUTER_DESKTOP_SCENE := preload("res://scenes/desktop/ComputerDesktop.tscn")
const ART_MANIFEST := preload("res://scripts/data/ArtManifest.gd")
const PANEL_WIDTH_PATH := &"preferences.display.angela_panel_width"

@onready var _computer_panel: PanelContainer = %ComputerPanel
@onready var _angela_image: Control = %AngelaImage

var _computer_desktop_instance: Node = null
var _view_profile: Object
var _view_preferences_bound := false

func _ready() -> void:
	if not _view_preferences_bound:
		bind_view_preferences(get_node_or_null("/root/ProfileManager"))
	$RootHBox.width_committed.connect(_on_panel_width_committed)
	_mount_angela_art()
	_ensure_computer_desktop()
	if _computer_desktop_instance is Control:
		(_computer_desktop_instance as Control).theme_changed.connect(_refresh_split_presentation)
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null:
		localization.locale_changed.connect(_refresh_split_presentation)
	_refresh_split_presentation()

func bind_view_preferences(profile: Object) -> bool:
	if profile != null and (not profile.has_method("get_preference") or not profile.has_method("set_preference")): return false
	if is_instance_valid(_view_profile) and _view_profile.has_signal("preference_changed") \
			and _view_profile.is_connected("preference_changed", _on_panel_preference_changed):
		_view_profile.disconnect("preference_changed", _on_panel_preference_changed)
	_view_profile = profile
	_view_preferences_bound = true
	if profile != null and profile.has_signal("preference_changed"):
		profile.connect("preference_changed", _on_panel_preference_changed)
	_refresh_panel_width()
	return true

func _refresh_panel_width() -> void:
	var split := get_node_or_null("RootHBox")
	if split == null: return
	split._retire_drag()
	var width := float(_view_profile.get_preference(PANEL_WIDTH_PATH, 480)) if is_instance_valid(_view_profile) else 480.0
	split.set_angela_width(width)

func _on_panel_preference_changed(path: StringName, _value: Variant) -> void:
	if path == PANEL_WIDTH_PATH: _refresh_panel_width()

func _on_panel_width_committed(width: float) -> void:
	if not is_instance_valid(_view_profile): return
	var saved: Dictionary = _view_profile.set_preference(PANEL_WIDTH_PATH, roundi(width))
	if not saved.get("ok", false): _refresh_panel_width()

func _refresh_split_presentation(_locale_id: String = "") -> void:
	var localization := get_node_or_null("/root/LocalizationManager")
	var locale := str(localization.get_locale()) if localization != null else "en"
	var copy: Array = {
		"en": ["Resize Angela panel", "Drag horizontally. Left/Right adjust width; Home/End use the minimum/maximum."],
		"zh-CN": ["调整安吉拉面板大小", "横向拖动。左右键调整宽度，Home/End 键设为最小/最大。"],
		"zh-HK": ["調整安吉拉面板大小", "橫向拖動。左右鍵調整寬度，Home/End 鍵設為最小/最大。"],
		"ja": ["アンジェラパネルのサイズ変更", "左右にドラッグ。左右キーで幅を調整、Home/End で最小/最大にします。"],
		"ko": ["안젤라 패널 크기 조절", "가로로 드래그하세요. 좌우 키로 너비를 조절하고 Home/End로 최소/최대 크기를 설정하세요."],
	}.get(locale, ["Resize Angela panel", "Drag horizontally to resize."])
	if _computer_desktop_instance is Control:
		var desktop_theme: Theme = (_computer_desktop_instance as Control).theme
		# Inherited theme notifications can reenter this callback. Only assign a new
		# resource; the mounted Desktop remains the sole palette/font owner.
		if $RootHBox.theme != desktop_theme:
			$RootHBox.theme = desktop_theme
	$RootHBox.set_handle_accessibility(copy[0], copy[1])
	# The handle copies its colors during sorting, even when width is unchanged.
	$RootHBox.queue_sort()

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
