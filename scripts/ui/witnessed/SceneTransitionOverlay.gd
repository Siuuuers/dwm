extends TextureRect
## One outgoing framebuffer, retained across Dialogic layout replacement.
## Bridge owns timing and admission; this surface only draws the captured pixels.
const DISSOLVE := preload("res://scripts/ui/witnessed/SceneTransitionOverlay.gdshader")

var caret: Control
var _dissolve: ShaderMaterial

func _init() -> void:
	name = "SceneTransition"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dissolve = ShaderMaterial.new()
	_dissolve.shader = DISSOLVE
	material = _dissolve
	visible = false

func capture_source() -> bool:
	var source: Image = get_viewport().get_texture().get_image()
	if source == null or source.is_empty(): return false
	texture = ImageTexture.create_from_image(source)
	size = get_viewport().get_visible_rect().size
	var final := get_viewport().get_final_transform()
	_dissolve.set_shader_parameter("source_size", Vector2(source.get_size()))
	# Rail's container starts at592, but its buttons and matte start at656.
	_dissolve.set_shader_parameter("rail_top", (final * Vector2(0, 656)).y)
	_dissolve.set_shader_parameter("caret_rect", Vector4.ZERO)
	_dissolve.set_shader_parameter("divider_rect", Vector4.ZERO)
	_dissolve.set_shader_parameter("preview_rect", Vector4.ZERO)
	if is_instance_valid(caret) and caret.is_visible_in_tree():
		var rect: Rect2 = final * caret.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, caret.size)
		_dissolve.set_shader_parameter("caret_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	for surface: Node in get_tree().get_nodes_in_group("dating_split_surface"):
		if surface.get_viewport() != get_viewport(): continue
		var layer := surface.get_parent()
		if layer == null or layer.get_script() == null \
				or layer.get_script().resource_path != "res://scripts/ui/witnessed/WitnessedArtLayer.gd": continue
		var handle: Control = surface.get_split_handle()
		if handle == null or not handle.is_visible_in_tree(): continue
		var transform: Transform2D = final * handle.get_global_transform_with_canvas()
		var seam: float = handle.size.x - 1.0
		var line := Rect2(seam - 2.0 if handle.has_focus() else seam, 0,
			4.0 if handle.has_focus() else 2.0, handle.separator_height)
		var rect: Rect2 = transform * line
		_dissolve.set_shader_parameter("divider_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		if handle.preview_visible:
			rect = transform * Rect2(seam + handle.preview_offset, 0, 2, handle.separator_height)
			_dissolve.set_shader_parameter("preview_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		break
	set_progress(0.0)
	visible = true
	return true

func set_progress(progress: float) -> void:
	_dissolve.set_shader_parameter("progress", progress)

func clear_capture() -> void:
	visible = false
	texture = null
	set_progress(1.0)
