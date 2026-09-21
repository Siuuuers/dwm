extends Control
## Presentation-only scene art. Dating shares a portrait divider across its hosts.
const ART := preload("res://scripts/data/ArtManifest.gd")
const PANEL_SPLIT := preload("res://scripts/ui/desktop/DesktopPanelSplit.gd")
const APERTURE_HEIGHT := {100: 448, 125: 392, 150: 328}

signal split_changed(right_rect: Rect2)
signal split_drag_changed(active: bool)

# Remember the dating composition through dialogue/challenge transitions in this session.
static var _dating_width := 480.0
var _background: TextureRect
var _portraits: Array[TextureRect] = []
var _portrait_slots: Array[Control] = []
var _opaque_portraits: Array[bool] = [false, false]
var _portrait_background: TextureRect
var _portrait_panel: Control
var _scene_panel: Control
var _split: PANEL_SPLIT
var _cg: TextureRect
var _entry_id := ""
var _dating_split := false
var _portrait_count := 0

func configure_entry(entry_id: String, text_percent: int = 100,
		challenge: bool = false, show_portraits: bool = true) -> void:
	_entry_id = entry_id
	var placement: Dictionary = ART.get_scene_art(entry_id)
	var portraits: Array[Texture2D] = []
	if show_portraits:
		for asset_id: String in placement.get("portraits", []):
			portraits.append(ART.get_texture(asset_id))
	configure_textures(ART.get_texture(str(placement.get("background", ""))), portraits,
		ART.get_texture(str(placement.get("cg", ""))), text_percent, challenge, entry_id.begins_with("dating."))

func configure_textures(background: Texture2D, portraits: Array[Texture2D], cg: Texture2D = null,
		text_percent: int = 100, challenge: bool = false, dating_overlay: bool = false) -> void:
	_build()
	var height := 720 if challenge else (656 if dating_overlay else int(APERTURE_HEIGHT.get(text_percent, 448)))
	size = Vector2(1280, height)
	_portrait_count = mini(portraits.size(), 2)
	_dating_split = (dating_overlay or challenge) and _portrait_count > 0 and cg == null
	_background.texture = background
	_portrait_background.texture = background
	_cg.texture = cg
	_cg.size = size
	_split.visible = _dating_split
	_split.size = size
	_split.width_step = 4.0 if _portrait_count == 2 else 2.0
	for index: int in range(2):
		var portrait: TextureRect = _portraits[index]
		var texture: Texture2D = portraits[index] if index < _portrait_count else null
		if portrait.texture != texture:
			_opaque_portraits[index] = false
			if texture != null:
				var source: Image = texture.get_image()
				_opaque_portraits[index] = source != null and source.detect_alpha() == Image.ALPHA_NONE
		portrait.texture = texture
		portrait.visible = texture != null and cg == null
		var parent: Node = _portrait_slots[index] if _dating_split else self
		if portrait.get_parent() != parent: portrait.reparent(parent)
		if not _dating_split:
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.position = Vector2(320 if portraits.size() == 1 else index * 640, 0)
			portrait.size = Vector2(640, height)
	var background_parent: Node = _scene_panel if _dating_split else self
	if _background.get_parent() != background_parent: _background.reparent(background_parent)
	_background.position = Vector2.ZERO
	if _dating_split:
		_split.set_angela_width(_dating_width)
		_layout_dating_art()
	else:
		cancel_split_input()
		move_child(_background, 0)
		_background.size = size
	visible = _dating_split or background != null or cg != null or _portraits[0].visible or _portraits[1].visible
	split_changed.emit(get_right_rect())

func get_right_rect() -> Rect2:
	var width := get_portrait_width() if _dating_split else 0.0
	return Rect2(width, 0, size.x - width, size.y)

func get_portrait_width() -> float:
	return _split.get_angela_width() if is_instance_valid(_split) else _dating_width

func set_portrait_width(width: float) -> void:
	_build()
	_split.set_angela_width(width)
	_dating_width = _split.get_angela_width()

func get_split_handle() -> Control:
	return _split._handle if is_instance_valid(_split) and _dating_split else null

func is_split_dragging() -> bool:
	return is_instance_valid(_split) and _split.is_dragging()

func cancel_split_input() -> void:
	if is_instance_valid(_split): _split._retire_drag()

func set_split_input_admission(admission: Callable) -> void:
	_build()
	_split.set_input_admission(admission)

func handle_split_input(event: InputEvent, source_control: Control) -> bool:
	if not _dating_split or not is_visible_in_tree(): return false
	var handle := get_split_handle()
	if not is_instance_valid(handle): return false
	var positioned := event is InputEventMouseButton or event is InputEventMouseMotion \
		or event is InputEventScreenTouch or event is InputEventScreenDrag
	if not positioned: return false
	var point: Vector2 = source_control.get_global_transform_with_canvas() * event.position
	var handle_point := handle.get_global_transform_with_canvas().affine_inverse() * point
	if not is_split_dragging() and not Rect2(Vector2.ZERO, handle.size).has_point(handle_point): return false
	# The caption canvas is above the artwork; route only the divider's gesture.
	var local_event: InputEvent = event.duplicate()
	local_event.position = handle_point
	_split._on_handle_gui_input(local_event)
	get_viewport().set_input_as_handled()
	return true

func _on_split_changed(width: float) -> void:
	_dating_width = width
	if not _dating_split: return
	_layout_dating_art()
	split_changed.emit(get_right_rect())

func _layout_dating_art() -> void:
	var width := get_portrait_width()
	_background.size = Vector2(size.x - width, size.y)
	_fit_height(_portrait_background, width, size.y)
	for index: int in range(2):
		var portrait: TextureRect = _portraits[index]
		var slot: Control = _portrait_slots[index]
		slot.position = Vector2.ZERO
		slot.size = Vector2(width, size.y)
		slot.clip_contents = false
		if not portrait.visible: continue
		var center := width * (index + 0.5) / _portrait_count
		# Existing opaque paintings cannot overlap without covering the other face.
		# Cut-out portraits can share the full panel and overlap naturally.
		if _portrait_count == 2 and (_opaque_portraits[0] or _opaque_portraits[1]):
			slot.position.x = index * width / _portrait_count
			slot.size.x = width / _portrait_count
			slot.clip_contents = true
			center = slot.size.x * 0.5
		_fit_height(portrait, center * 2.0, size.y)

func _fit_height(rect: TextureRect, width: float, height: float) -> void:
	if rect.texture == null: return
	var image_width := height * rect.texture.get_width() / rect.texture.get_height()
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = Vector2((width - image_width) * 0.5, 0)
	rect.size = Vector2(image_width, height)

func _build() -> void:
	if is_instance_valid(_background): return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	add_to_group("dating_split_surface")
	_background = _texture_rect("Background", TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_split = PANEL_SPLIT.new()
	_split.name = "DatingPanelSplit"
	_split.minimum_first_width = 320.0
	_split.maximum_first_width = 640.0
	_split.minimum_second_width = 640.0
	_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_split)
	_portrait_panel = Control.new()
	_portrait_panel.name = "PortraitPanel"
	_portrait_panel.clip_contents = true
	_portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split.add_child(_portrait_panel)
	_scene_panel = Control.new()
	_scene_panel.name = "BackgroundPanel"
	_scene_panel.clip_contents = true
	_scene_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split.add_child(_scene_panel)
	_portrait_background = _texture_rect("PortraitBackground", TextureRect.STRETCH_SCALE)
	_portrait_background.reparent(_portrait_panel)
	for index: int in range(2):
		var slot := Control.new()
		slot.name = "PortraitSlot%d" % index
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_panel.add_child(slot)
		_portrait_slots.append(slot)
		_portraits.append(_texture_rect("PortraitLeft" if index == 0 else "PortraitRight", TextureRect.STRETCH_KEEP_ASPECT_CENTERED))
	_cg = _texture_rect("EndingCG", TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	_split.set_handle_accessibility("Resize portrait panel", "Drag horizontally or use Left and Right arrow keys")
	_split.split_changed.connect(_on_split_changed)
	_split.drag_changed.connect(func(active: bool): split_drag_changed.emit(active))

func _texture_rect(node_name: String, stretch: TextureRect.StretchMode) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.focus_mode = Control.FOCUS_NONE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	add_child(rect)
	return rect
