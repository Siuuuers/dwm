extends RefCounted
## Shared static material drawing; ownership stays with each existing surface.
static var _paper_tile: ImageTexture

static func paper_texture() -> ImageTexture:
	if _paper_tile == null:
		var image := Image.create(128, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for fibre: int in 192:
			var x := (fibre * 37 + fibre / 11) % 128
			var y := (fibre * 19 + fibre / 7) % 64
			for point: int in 2 + fibre % 4:
				image.set_pixel((x + point) % 128, (y + (point / 3 if fibre % 5 == 0 else 0)) % 64,
					Color(1, 1, 1, 0.035 + (fibre % 4) * 0.012))
		_paper_tile = ImageTexture.create_from_image(image)
	return _paper_tile

static func draw_paper(canvas: CanvasItem, rect: Rect2, ink: Color) -> void:
	canvas.draw_texture_rect(paper_texture(), rect, true, ink)

static func draw_crystal(canvas: CanvasItem, rect: Rect2, ink: Color) -> void:
	for corner: int in 4:
		var origin := rect.position if corner < 2 else Vector2(rect.position.x, rect.end.y)
		var direction := Vector2(1, 1 if corner < 2 else -1)
		if corner % 2 == 1:
			origin.x = rect.end.x
			direction.x = -1
		var length := minf(44 if corner < 2 else 28, rect.size.x * 0.2)
		canvas.draw_colored_polygon(PackedVector2Array([origin + Vector2(2, 2) * direction,
			origin + Vector2(length, 2) * direction, origin + Vector2(length * 0.6, 5) * direction,
			origin + Vector2(2, 7) * direction]), Color(ink, 0.1))
		canvas.draw_polyline(PackedVector2Array([origin + Vector2(3, 6) * direction,
			origin + Vector2(11, 3) * direction, origin + Vector2(17, 6) * direction,
			origin + Vector2(22, 2) * direction]), Color(ink, 0.27), 1, true)
		canvas.draw_line(origin + Vector2(2, 2) * direction,
			origin + Vector2(length * 0.55, 2) * direction, Color(ink, 0.42), 1, true)

static func draw_seal(canvas: CanvasItem, center: Vector2, ink: Color, face: Color) -> void:
	var contour := PackedVector2Array()
	for point: int in 20:
		var angle := TAU * point / 20.0
		contour.append(center + Vector2.from_angle(angle) * (6.5 + 0.45 * sin(angle * 3)))
	canvas.draw_circle(center + Vector2(0.5, 1), 7, Color(ink, 0.2))
	canvas.draw_colored_polygon(contour, face.lerp(ink, 0.35))
	canvas.draw_arc(center, 5.5, PI, TAU, 12, Color(ink, 0.45), 1, true)
	canvas.draw_arc(center, 3.5, 0, TAU, 16, Color(ink, 0.55), 1, true)

static func draw_silk(canvas: CanvasItem, rect: Rect2, ink: Color, edge: Color) -> void:
	var turn_height := minf(18, rect.size.y / 5)
	for turn: int in 3:
		var y := rect.position.y + rect.size.y * (0.12 + turn * 0.31)
		var back := PackedVector2Array([Vector2(rect.end.x - 2, y), Vector2(rect.end.x - 6, y + turn_height * 0.5)])
		var front := PackedVector2Array([back[1], Vector2(rect.end.x - 2, y + turn_height)])
		canvas.draw_polyline(back, Color(edge, 0.45), 2.5, true)
		canvas.draw_polyline(back, Color(ink, 0.2), 1, true)
		canvas.draw_polyline(front, Color(edge, 0.9), 2.5, true)
		canvas.draw_polyline(front, Color(ink, 0.8), 1, true)
