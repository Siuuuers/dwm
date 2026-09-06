extends RefCounted
## Integer native-pixel geometry. Hosts multiply these values by two at the logical boundary.
## Gutters are always reserved; a fit axis has no scrollbar object or input target.

static func measure(columns: int, rows: int, band: Vector2i, large: bool = false, requested_scroll: Vector2i = Vector2i.ZERO) -> Dictionary:
	var target := 32 if large else 24
	if columns < 1 or rows < 1 or band.x < 2 * target or band.y < 2 * target:
		return {"ok": false, "code": &"invalid_worksheet_geometry"}
	var well := band - Vector2i.ONE * target
	var mount := Vector2i(columns, rows) * target + Vector2i(2, 2)
	var maximum := Vector2i(maxi(0, mount.x - well.x), maxi(0, mount.y - well.y))
	var scroll := Vector2i(clampi(requested_scroll.x, 0, maximum.x), clampi(requested_scroll.y, 0, maximum.y))
	var origin := Vector2i(-scroll.x if maximum.x > 0 else floori((well.x - mount.x) / 2.0),
		-scroll.y if maximum.y > 0 else floori((well.y - mount.y) / 2.0))
	var horizontal: Variant = null
	var vertical: Variant = null
	if maximum.x > 0:
		horizontal = _rail(Rect2i(0, well.y, well.x, target), well.x, mount.x, scroll.x, target, false)
	if maximum.y > 0:
		vertical = _rail(Rect2i(well.x, 0, target, well.y), well.y, mount.y, scroll.y, target, true)
	return {"ok": true, "value": {"target": target, "well": Rect2i(Vector2i.ZERO, well), "mount": Rect2i(origin, mount),
		"scroll": scroll, "maximum_scroll": maximum, "horizontal": horizontal, "vertical": vertical,
		"corner": Rect2i(well, Vector2i.ONE * target)}}

static func reveal_cell(columns: int, rows: int, index: int, band: Vector2i, large: bool, scroll: Vector2i) -> Dictionary:
	if index < 0 or index >= columns * rows: return {"ok": false, "code": &"invalid_worksheet_cell"}
	var measured := measure(columns, rows, band, large, scroll)
	if not measured.ok: return measured
	var geometry: Dictionary = measured.value
	var target: int = geometry.target
	var cell := Rect2i(Vector2i(index % columns, index / columns) * target + Vector2i.ONE, Vector2i.ONE * target)
	var next: Vector2i = geometry.scroll
	for axis in 2:
		if geometry.maximum_scroll[axis] == 0: continue
		if cell.position[axis] < next[axis]: next[axis] = cell.position[axis]
		elif cell.end[axis] > next[axis] + geometry.well.size[axis]: next[axis] = cell.end[axis] - geometry.well.size[axis]
	return measure(columns, rows, band, large, next)

static func _rail(rect: Rect2i, viewport: int, mount: int, scroll: int, target: int, vertical: bool) -> Dictionary:
	var length := maxi(target, floori(float(viewport * viewport) / mount))
	var leading := floori(float((viewport - length) * scroll) / (mount - viewport))
	var thumb := Rect2i(rect.position + (Vector2i(0, leading) if vertical else Vector2i(leading, 0)),
		Vector2i(target, length) if vertical else Vector2i(length, target))
	return {"rect": rect, "thumb": thumb}
