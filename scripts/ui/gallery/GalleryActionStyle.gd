extends StyleBox
## State paint has no content margins and never changes the action's geometry.

var state: StringName
var ink: Color
var focus_ink: Color

func _init(kind: StringName = &"", primary := Color.WHITE, secondary := Color.WHITE) -> void:
	state = kind
	ink = primary
	focus_ink = secondary
	set_content_margin_all(0)

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(8) if state == &"focus" else rect

func _draw(canvas: RID, rect: Rect2) -> void:
	match state:
		&"hover":
			RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position, Vector2(2, rect.size.y)), ink)
		&"pressed":
			RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position, Vector2(rect.size.x, 2)), ink)
		&"focus":
			_ring(canvas, rect.grow(8), ink)
			_ring(canvas, rect.grow(4), focus_ink)

func _ring(canvas: RID, rect: Rect2, color: Color) -> void:
	RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position, Vector2(rect.size.x, 2)), color)
	RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2)), color)
	RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position + Vector2(0, 2), Vector2(2, rect.size.y - 4)), color)
	RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position + Vector2(rect.size.x - 2, 2), Vector2(2, rect.size.y - 4)), color)
