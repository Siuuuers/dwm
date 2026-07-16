class_name FocusGrid
extends Node
# Focus-neighbor helper for icon grids (CONTRACTS §7). Wires focus_neighbor_* so
# keyboard/controller navigation follows a GridContainer layout.


static func set_neighbors(control: Control, neighbors: Dictionary) -> void:
	if control == null:
		return
	if neighbors.has("left") and neighbors["left"] is Control:
		control.focus_neighbor_left = (neighbors["left"] as Control).get_path()
	if neighbors.has("right") and neighbors["right"] is Control:
		control.focus_neighbor_right = (neighbors["right"] as Control).get_path()
	if neighbors.has("top") and neighbors["top"] is Control:
		control.focus_neighbor_top = (neighbors["top"] as Control).get_path()
	if neighbors.has("bottom") and neighbors["bottom"] is Control:
		control.focus_neighbor_bottom = (neighbors["bottom"] as Control).get_path()


static func apply_grid(root: Node, columns: int = 4) -> void:
	# Collect focusable child Controls in order and wire neighbor links as a grid.
	if root == null or columns <= 0:
		return
	var cells: Array[Control] = []
	for child in root.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL:
			cells.append(child)
	var count := cells.size()
	for i in range(count):
		var c := cells[i]
		var col := i % columns
		var neighbors := {}
		if col > 0:
			neighbors["left"] = cells[i - 1]
		if col < columns - 1 and i + 1 < count:
			neighbors["right"] = cells[i + 1]
		if i - columns >= 0:
			neighbors["top"] = cells[i - columns]
		if i + columns < count:
			neighbors["bottom"] = cells[i + columns]
		set_neighbors(c, neighbors)
