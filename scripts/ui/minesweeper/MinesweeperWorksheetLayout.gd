extends RefCounted
## Integer native-pixel geometry. Hosts multiply these values by two at the logical boundary.
## Gutters are always reserved; a fit axis has no scrollbar object or input target.

static func measure(columns: int, rows: int, band: Vector2i, large: bool = false, requested_scroll: Vector2i = Vector2i.ZERO) -> Dictionary:
	var target := 32 if large else 24
	var measured := _measure_scrolled(columns, rows, band, target, 1.0, 24 if large else 12, requested_scroll)
	if not measured.ok: return measured
	var value: Dictionary = measured.value
	var mount: Rect2 = value.mount
	var origin := Vector2i(floori(mount.position.x), floori(mount.position.y))
	value.mount = Rect2i(origin, Vector2i(target * columns + 2, target * rows + 2))
	value.target = target
	value.erase("scale")
	return measured

static func reveal_cell(columns: int, rows: int, index: int, band: Vector2i, large: bool, scroll: Vector2i) -> Dictionary:
	if index < 0 or index >= columns * rows: return {"ok": false, "code": &"invalid_worksheet_cell"}
	var measured := measure(columns, rows, band, large, scroll)
	if not measured.ok: return measured
	var target := 32 if large else 24
	return measure(columns, rows, band, large, _revealed_scroll(measured.value, columns, index, target))


## Manual cell sizes are logical stage pixels; the grid keeps its 24/32 native-pixel cells.
static func measure_view(columns: int, rows: int, band: Vector2i, large: bool, cell_size: int,
		fit: bool, requested_scroll: Vector2i = Vector2i.ZERO) -> Dictionary:
	if cell_size < 10 or cell_size > 60 or cell_size % 2 != 0:
		return {"ok": false, "code": &"invalid_worksheet_geometry"}
	var source_target := 32 if large else 24
	if fit: return _fit_view(columns, rows, band, source_target, 30.0 / source_target, true)
	if band.x <= 2 * source_target or band.y <= 2 * source_target:
		return {"ok": false, "code": &"invalid_worksheet_geometry"}
	return _measure_scrolled(columns, rows, band, source_target,
		float(cell_size) / (source_target * 2.0), 24 if large else 12, requested_scroll)


static func reveal_view(columns: int, rows: int, index: int, band: Vector2i, large: bool,
		cell_size: int, fit: bool, scroll: Vector2i) -> Dictionary:
	if index < 0 or index >= columns * rows: return {"ok": false, "code": &"invalid_worksheet_cell"}
	var measured := measure_view(columns, rows, band, large, cell_size, fit, scroll)
	if not measured.ok or fit: return measured
	var source_target := 32 if large else 24
	return measure_view(columns, rows, band, large, cell_size, false,
		_revealed_scroll(measured.value, columns, index, source_target))


## The anchor is a native-pixel coordinate in the well. Preserve its grid-local point.
static func anchored_scroll(old_geometry: Dictionary, new_geometry: Dictionary, anchor_native: Vector2) -> Vector2i:
	var old_scale: float = old_geometry.get("scale", 1.0)
	var new_scale: float = new_geometry.get("scale", 1.0)
	var board_point: Vector2 = (anchor_native - Vector2(old_geometry.mount.position)) / old_scale
	var desired: Vector2 = board_point * new_scale - anchor_native
	var maximum: Vector2i = new_geometry.maximum_scroll
	return Vector2i(clampi(roundi(desired.x), 0, maximum.x), clampi(roundi(desired.y), 0, maximum.y))


static func _measure_scrolled(columns: int, rows: int, band: Vector2i, source_target: int,
		scale: float, gutter: int, requested_scroll: Vector2i) -> Dictionary:
	var rendered_target := source_target * scale
	if columns < 1 or rows < 1 or band.x < 2 * gutter or band.y < 2 * gutter:
		return {"ok": false, "code": &"invalid_worksheet_geometry"}
	var well := band - Vector2i.ONE * gutter
	var extent := Vector2(columns * source_target + 2, rows * source_target + 2) * scale
	var maximum := Vector2i(maxi(0, ceili(extent.x - well.x - 0.00001)), maxi(0, ceili(extent.y - well.y - 0.00001)))
	var scroll := Vector2i(clampi(requested_scroll.x, 0, maximum.x), clampi(requested_scroll.y, 0, maximum.y))
	var origin := Vector2(-scroll.x if maximum.x > 0 else (well.x - extent.x) / 2.0,
		-scroll.y if maximum.y > 0 else (well.y - extent.y) / 2.0)
	var horizontal: Variant = null
	var vertical: Variant = null
	if maximum.x > 0:
		horizontal = _rail(Rect2i(0, well.y, well.x, gutter), well.x, well.x + maximum.x, scroll.x, gutter, false)
	if maximum.y > 0:
		vertical = _rail(Rect2i(well.x, 0, gutter, well.y), well.y, well.y + maximum.y, scroll.y, gutter, true)
	return {"ok": true, "value": {"target": rendered_target, "scale": scale,
		"well": Rect2i(Vector2i.ZERO, well), "mount": Rect2(origin, extent),
		"scroll": scroll, "maximum_scroll": maximum, "horizontal": horizontal, "vertical": vertical,
		"corner": Rect2i(well, Vector2i.ONE * gutter)}}


static func _revealed_scroll(geometry: Dictionary, columns: int, index: int, source_target: int) -> Vector2i:
	var scale: float = geometry.get("scale", 1.0)
	var cell := Rect2(Vector2(index % columns, index / columns) * source_target * scale + Vector2.ONE * scale,
		Vector2.ONE * source_target * scale)
	var next: Vector2i = geometry.scroll
	for axis in 2:
		if geometry.maximum_scroll[axis] == 0: continue
		if cell.position[axis] < next[axis]: next[axis] = floori(cell.position[axis])
		elif cell.end[axis] > next[axis] + geometry.well.size[axis]:
			next[axis] = ceili(cell.end[axis] - geometry.well.size[axis])
	return next

static func _rail(rect: Rect2i, viewport: int, mount: int, scroll: int, target: int, vertical: bool) -> Dictionary:
	var length := maxi(target, floori(float(viewport * viewport) / mount))
	var leading := floori(float((viewport - length) * scroll) / (mount - viewport))
	var thumb := Rect2i(rect.position + (Vector2i(0, leading) if vertical else Vector2i(leading, 0)),
		Vector2i(target, length) if vertical else Vector2i(length, target))
	return {"rect": rect, "thumb": thumb}

## Fit the complete rendered board; text preferences do not change this geometry.
## Keep the grid's local cell coordinates so pointer/touch hit testing is unchanged.
static func fit_board(columns: int, rows: int, band: Vector2i, large: bool = false) -> Dictionary:
	var target := 32 if large else 24
	return _fit_view(columns, rows, band, target, 1.0, false)


static func _fit_view(columns: int, rows: int, band: Vector2i, source_target: int,
		maximum_scale: float, rendered_target: bool) -> Dictionary:
	if columns < 1 or rows < 1 or band.x < 2 or band.y < 2:
		return {"ok":false,"code":&"invalid_worksheet_geometry"}
	var source := Vector2(columns * source_target + 2, rows * source_target + 2)
	var factor := minf(maximum_scale,minf((band.x - 1.0)/source.x,(band.y - 1.0)/source.y))
	var extent := source * factor
	var origin := (Vector2(band) - extent) / 2.0
	var target: Variant = source_target * factor if rendered_target else source_target
	return {"ok":true,"value":{"target":target,"scale":factor,
		"well":Rect2(Vector2.ZERO,Vector2(band)),"mount":Rect2(origin,extent),
		"scroll":Vector2i.ZERO,"maximum_scroll":Vector2i.ZERO,
		"horizontal":null,"vertical":null,"corner":Rect2i()}}

