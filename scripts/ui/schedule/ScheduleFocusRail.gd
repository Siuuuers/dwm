extends Control
## Detached paper focus may cross the scroll aperture, but never grows its extent.
var scroll: ScrollContainer
var _target: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	z_index = 20
	get_viewport().gui_focus_changed.connect(_focus_changed)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): queue_redraw())
	theme_changed.connect(queue_redraw)
	_focus_changed(get_viewport().gui_get_focus_owner())

func _focus_changed(target: Control) -> void:
	if is_instance_valid(_target):
		if _target.draw.is_connected(queue_redraw): _target.draw.disconnect(queue_redraw)
		if _target.item_rect_changed.is_connected(queue_redraw): _target.item_rect_changed.disconnect(queue_redraw)
	_target = target if target != null and scroll.is_ancestor_of(target) else null
	if _target != null:
		_target.draw.connect(queue_redraw)
		_target.item_rect_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_target) or not _target.is_visible_in_tree() or not _target.has_focus(): return
	if not _target.has_method("draw_focus_on") or _target.disabled: return
	if not scroll.get_global_rect().intersects(_target.get_global_rect()): return
	draw_set_transform_matrix(get_global_transform().affine_inverse()*_target.get_global_transform())
	_target.draw_focus_on(self)
