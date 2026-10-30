extends RefCounted
## Shared static material drawing; ownership stays with each existing surface.
static var _paper_tile: ImageTexture

static func paper_texture() -> ImageTexture:
	if _paper_tile == null:
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var grain := RandomNumberGenerator.new()
		grain.seed = 0x50415045
		for point: int in 3600:
			image.set_pixel(grain.randi_range(0, 127), grain.randi_range(0, 127), Color(1, 1, 1, grain.randf_range(0.05, 0.14)))
		for fibre: int in 180:
			var x := grain.randi_range(0, 127)
			var y := grain.randi_range(0, 127)
			var slope := grain.randi_range(-1, 1)
			var alpha := grain.randf_range(0.10, 0.20)
			for point: int in grain.randi_range(3, 7):
				image.set_pixel((x + point) % 128, posmod(y + point * slope, 128), Color(1, 1, 1, alpha))
		_paper_tile = ImageTexture.create_from_image(image)
	return _paper_tile

static func draw_paper(canvas: CanvasItem, rect: Rect2, ink: Color) -> void:
	canvas.draw_texture_rect(paper_texture(), rect, true, ink)

static func draw_crystal(canvas: CanvasItem, rect: Rect2, ink: Color) -> void:
	var shine := Color(0.86, 0.94, 1.0)
	for corner: int in 4:
		var origin := rect.position if corner < 2 else Vector2(rect.position.x, rect.end.y)
		var direction := Vector2(1, 1 if corner < 2 else -1)
		if corner % 2 == 1:
			origin.x = rect.end.x
			direction.x = -1
		var length := minf(128 if corner < 2 else 64, minf(rect.size.x * 0.3, rect.size.y * 0.25))
		canvas.draw_colored_polygon(PackedVector2Array([origin + Vector2(2, 2) * direction,
			origin + Vector2(length, 2) * direction, origin + Vector2(2, length * 0.7) * direction]), Color(shine, 0.16))
		canvas.draw_colored_polygon(PackedVector2Array([origin + Vector2(length * 0.55, 2) * direction,
			origin + Vector2(length * 0.72, 2) * direction, origin + Vector2(2, length * 0.55) * direction,
			origin + Vector2(2, length * 0.42) * direction]), Color(shine, 0.24))
		var crack := PackedVector2Array([origin + Vector2(3, 6) * direction,
			origin + Vector2(18, 15) * direction, origin + Vector2(27, 12) * direction,
			origin + Vector2(39, 31) * direction, origin + Vector2(53, 37) * direction])
		canvas.draw_polyline(crack, Color(0.04, 0.07, 0.1, 0.5), 2.5, true)
		canvas.draw_polyline(crack, Color(shine, 0.8), 1, true)
		canvas.draw_polyline(PackedVector2Array([crack[2], origin + Vector2(33, 6) * direction,
			origin + Vector2(46, 3) * direction]), Color(shine, 0.65), 1, true)
		canvas.draw_line(origin + Vector2(2, 2) * direction,
			origin + Vector2(length, 2) * direction, Color(ink, 0.8), 2, true)

static func draw_silk(canvas: CanvasItem, rect: Rect2, ink: Color, edge: Color) -> void:
	var turn_height := minf(32, rect.size.y / 5)
	var cord := PackedVector2Array([Vector2(rect.end.x - 3, rect.position.y + 2)])
	for turn: int in 3:
		var y := rect.position.y + rect.size.y * (0.12 + turn * 0.31)
		cord.append(Vector2(rect.end.x - 3, y))
		cord.append(Vector2(rect.end.x - 15, y + turn_height * 0.5))
		cord.append(Vector2(rect.end.x - 3, y + turn_height))
	cord.append(Vector2(rect.end.x - 3, rect.end.y - 2))
	canvas.draw_polyline(cord, Color(0.03, 0.04, 0.06, 0.9), 6, true)
	canvas.draw_polyline(cord, edge, 4, true)
	canvas.draw_polyline(cord, Color(ink, 0.9), 1.5, true)
