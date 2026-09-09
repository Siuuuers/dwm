extends Control
## Optional, inert presentation images. No state, witnesses, or input ownership.
const ART := preload("res://scripts/data/ArtManifest.gd")
const APERTURE_HEIGHT := {100: 448, 125: 392, 150: 328}

var _background: TextureRect
var _portraits: Array[TextureRect] = []
var _cg: TextureRect
var _entry_id := ""

func configure_entry(entry_id: String, text_percent: int = 100,
		challenge: bool = false, show_portraits: bool = true) -> void:
	_entry_id = entry_id
	var placement: Dictionary = ART.get_scene_art(entry_id)
	var portraits: Array[Texture2D] = []
	if show_portraits:
		for asset_id: String in placement.get("portraits", []):
			portraits.append(ART.get_texture(asset_id))
	configure_textures(ART.get_texture(str(placement.get("background", ""))), portraits,
		ART.get_texture(str(placement.get("cg", ""))), text_percent, challenge)

func configure_textures(background: Texture2D, portraits: Array[Texture2D], cg: Texture2D = null,
		text_percent: int = 100, challenge: bool = false) -> void:
	_build()
	var height := 720 if challenge else int(APERTURE_HEIGHT.get(text_percent, 448))
	size = Vector2(1280, height)
	_background.texture = background
	_background.size = size
	_cg.texture = cg
	_cg.size = size
	for index: int in range(2):
		var portrait: TextureRect = _portraits[index]
		portrait.texture = portraits[index] if index < portraits.size() else null
		portrait.visible = portrait.texture != null and cg == null
		# The fixed worksheet keeps its native size; art never consumes its layout space.
		portrait.position = Vector2(index * 1120, 0) if challenge else Vector2(
			320 if portraits.size() == 1 else index * 640, 0)
		portrait.size = Vector2(160 if challenge else 640, height)
	visible = background != null or cg != null or _portraits[0].visible or _portraits[1].visible

func _build() -> void:
	if is_instance_valid(_background): return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_background = _texture_rect("Background", TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_portraits.append(_texture_rect("PortraitLeft", TextureRect.STRETCH_KEEP_ASPECT_CENTERED))
	_portraits.append(_texture_rect("PortraitRight", TextureRect.STRETCH_KEEP_ASPECT_CENTERED))
	_cg = _texture_rect("EndingCG", TextureRect.STRETCH_KEEP_ASPECT_CENTERED)

func _texture_rect(node_name: String, stretch: TextureRect.StretchMode) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.focus_mode = Control.FOCUS_NONE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	add_child(rect)
	return rect
