extends Control
## Native drag/drop surface for the docket's legal insertion boundaries.

var drag_owner: Object
var boundaries: Array[float] = []
var witness := -1
var _overlay: Control

class InsertionWitness extends Control:
	var boundary_y := -1.0
	func _draw() -> void:
		if boundary_y < 0.0: return
		draw_rect(Rect2(8,boundary_y,204,2),Color("151b25"))
		draw_rect(Rect2(210,boundary_y-2,2,6),Color("151b25"))

func _ready() -> void:
	_overlay = InsertionWitness.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.focus_mode = Control.FOCUS_NONE
	_overlay.z_index = 10
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	mouse_exited.connect(clear_witness)

func _input(event: InputEvent) -> void:
	# A blocking control in the folio may prevent native drop lookup from reaching
	# this lane. Remove its old witness as soon as the pointer leaves a boundary.
	if witness >= 0 and event is InputEventMouseMotion:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if _boundary_at(local) < 0: clear_witness()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var next := _boundary_at(at_position)
	var allowed: bool = next >= 0 and is_instance_valid(drag_owner) and drag_owner.accepts_docket_drag(data)
	_set_witness(next if allowed else -1)
	return allowed

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var boundary := _boundary_at(at_position)
	_set_witness(-1)
	if boundary >= 0 and is_instance_valid(drag_owner):
		drag_owner.drop_docket_drag(data,boundary)

func clear_witness() -> void:
	_set_witness(-1)

func _boundary_at(at_position: Vector2) -> int:
	if not at_position.is_finite() or at_position.x < 8.0 or at_position.x > 212.0:
		return -1
	for index in boundaries.size():
		if absf(at_position.y-boundaries[index]) <= 4.0:
			return index
	return -1

func _set_witness(value: int) -> void:
	if witness == value: return
	witness = value
	if is_instance_valid(_overlay):
		_overlay.boundary_y = boundaries[value] if value >= 0 and value < boundaries.size() else -1.0
		_overlay.queue_redraw()
