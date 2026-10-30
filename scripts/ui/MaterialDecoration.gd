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
			image.set_pixel(grain.randi_range(0, 127), grain.randi_range(0, 127), Color(1, 1, 1, grain.randf_range(0.04, 0.10)))
		for fibre: int in 96:
			var x := grain.randi_range(0, 127)
			var y := grain.randi_range(0, 127)
			var slope := grain.randi_range(-1, 1)
			var alpha := grain.randf_range(0.08, 0.14)
			for point: int in grain.randi_range(3, 7):
				image.set_pixel((x + point) % 128, posmod(y + point * slope, 128), Color(1, 1, 1, alpha))
		_paper_tile = ImageTexture.create_from_image(image)
	return _paper_tile

static func draw_paper(canvas: CanvasItem, rect: Rect2, ink: Color) -> void:
	canvas.draw_texture_rect(paper_texture(), rect, true, ink)

static var _crystal_run_id := ""
static var _crystal_patterns: Dictionary = {}

static func crystal_pattern(run_id: String, surface: String) -> Array:
	if run_id != _crystal_run_id:
		_crystal_run_id = run_id
		_crystal_patterns.clear()
	if not _crystal_patterns.has(surface):
		var rng := RandomNumberGenerator.new()
		rng.seed = ("crystal:" + run_id + ":" + surface).sha256_text().left(15).hex_to_int()
		var corners := [0, 1, 2, 3]
		var pattern := []
		for index: int in [1, 2, 2, 2, 3][rng.randi_range(0, 4)]:
			var choice := rng.randi_range(0, corners.size() - 1)
			var corner: int = corners.pop_at(choice)
			var crack := PackedVector2Array([Vector2(rng.randf_range(0.06, 0.3), 0)])
			for point: int in rng.randi_range(3, 5):
				crack.append(crack[-1] + Vector2(rng.randf_range(0.06, 0.15), rng.randf_range(0.04, 0.14)))
			var paths := [crack]
			for branch: int in rng.randi_range(1, 3):
				var fork: Vector2 = crack[rng.randi_range(1, crack.size() - 2)]
				var tip := fork + Vector2(rng.randf_range(0.12, 0.3), rng.randf_range(-0.12, 0.18))
				tip.y = maxf(0.02, tip.y)
				var bend := fork.lerp(tip, 0.5) + Vector2(0, rng.randf_range(-0.04, 0.04))
				bend.y = maxf(0.01, bend.y)
				paths.append(PackedVector2Array([fork, bend, tip]))
			var reach := rng.randf_range(0.65, 1.0)
			pattern.append({"corner": corner, "paths": paths, "reflection": PackedVector2Array([
				Vector2.ZERO, Vector2(reach, 0), Vector2(0, reach * rng.randf_range(0.45, 0.8))])})
		_crystal_patterns[surface] = pattern
	return _crystal_patterns[surface]

static func draw_crystal(canvas: CanvasItem, rect: Rect2, ink: Color, pattern: Array) -> void:
	var shine := Color(0.86, 0.94, 1.0)
	for fracture: Dictionary in pattern:
		var corner: int = fracture.corner
		var origin := rect.position if corner < 2 else Vector2(rect.position.x, rect.end.y)
		var direction := Vector2(1, 1 if corner < 2 else -1)
		if corner % 2 == 1:
			origin.x = rect.end.x
			direction.x = -1
		var length := minf(128 if corner < 2 else 64, minf(rect.size.x * 0.3, rect.size.y * 0.25))
		var transform := Transform2D(Vector2(direction.x * length, 0), Vector2(0, direction.y * length), origin + Vector2(2, 2) * direction)
		canvas.draw_colored_polygon(transform * fracture.reflection, Color(shine, 0.16))
		for path: PackedVector2Array in fracture.paths:
			var points: PackedVector2Array = transform * path
			canvas.draw_polyline(points, Color(0.04, 0.07, 0.1, 0.5), 2.5, true)
			canvas.draw_polyline(points, Color(shine, 0.8), 1, true)
		canvas.draw_line(transform * Vector2.ZERO, transform * fracture.reflection[1], Color(ink, 0.7), 1.5, true)

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
