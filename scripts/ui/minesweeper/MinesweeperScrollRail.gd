extends Control
## Presentation-only worksheet scroll rail. Values and geometry remain native-pixel integers.

signal scroll_requested(native_value: int)

const LOCALES := ["en","zh-CN","zh-HK"]
const ROLES := [&"controlled_face",&"dark_registration",&"dark_scroll_thumb",&"dark_separation",&"dark_focus_outer",&"dark_focus_inner"]

var vertical := false
var rail: Dictionary = {}
var maximum := 0
var value := 0
var page := 0
var interactive := false
var _locale := "en"
var _dragging := false
var _drag_start := 0.0
var _drag_value := 0
var _large := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	focus_entered.connect(queue_redraw)
	focus_exited.connect(_on_focus_exited)


func configure(next_vertical: bool, locale: String, next_theme: Theme, large: bool = false) -> bool:
	var normalized: String = locale.replace("_","-")
	if normalized not in LOCALES or next_theme == null: return false
	for role: StringName in ROLES:
		if not next_theme.has_color(role,&"Minesweeper"): return false
	if vertical != next_vertical: _dragging = false
	vertical = next_vertical
	_large = large
	_locale = normalized
	theme = next_theme
	_refresh_accessibility()
	queue_redraw()
	return true


func present(next_rail: Dictionary, next_maximum: int, next_value: int, next_page: int, next_interactive: bool) -> bool:
	if not _valid(next_rail,next_maximum,next_value,next_page): return false
	if _dragging and (not next_interactive or maximum != next_maximum or page != next_page or rail.get("rect") != next_rail.rect):
		_dragging = false
	rail = next_rail.duplicate(true)
	maximum = next_maximum
	value = next_value
	page = next_page
	interactive = next_interactive
	var rect: Rect2i = rail.rect
	position = Vector2(rect.position*2)
	custom_minimum_size = Vector2(rect.size*2)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	if not interactive:
		release_focus()
	_refresh_accessibility()
	queue_redraw()
	return true


func _valid(next_rail: Dictionary, next_maximum: int, next_value: int, next_page: int) -> bool:
	if next_rail.size() != 2 or not next_rail.has("rect") or not next_rail.has("thumb"): return false
	if typeof(next_rail.rect) != TYPE_RECT2I or typeof(next_rail.thumb) != TYPE_RECT2I: return false
	if next_maximum <= 0 or next_value < 0 or next_value > next_maximum or next_page <= 0: return false
	var rect: Rect2i = next_rail.rect
	var thumb: Rect2i = next_rail.thumb
	if rect.size.x <= 0 or rect.size.y <= 0 or thumb.size.x <= 0 or thumb.size.y <= 0: return false
	if not rect.encloses(thumb): return false
	var axis := 1 if vertical else 0
	var cross := 0 if vertical else 1
	var target: int = rect.size[cross]
	if target not in [12,24,32]: return false
	if next_page != rect.size[axis]: return false
	if thumb.position[cross] != rect.position[cross] or thumb.size[cross] != rect.size[cross]: return false
	var expected_length: int = maxi(target,floori(float(next_page*next_page)/(next_page+next_maximum)))
	if thumb.size[axis] != expected_length: return false
	var travel: int = rect.size[axis]-thumb.size[axis]
	if travel <= 0: return false
	var expected_leading: int = floori(float(travel*next_value)/next_maximum)
	return thumb.position[axis]-rect.position[axis] == expected_leading


func _gui_input(event: InputEvent) -> void:
	if not interactive or rail.is_empty(): return
	if event is InputEventMouseButton:
		var wheel_backward: bool = (vertical and event.button_index == MOUSE_BUTTON_WHEEL_UP) or (not vertical and event.button_index == MOUSE_BUTTON_WHEEL_LEFT)
		var wheel_forward: bool = (vertical and event.button_index == MOUSE_BUTTON_WHEEL_DOWN) or (not vertical and event.button_index == MOUSE_BUTTON_WHEEL_RIGHT)
		if (wheel_backward or wheel_forward) and event.pressed:
			_request(value + (-_step() if wheel_backward else _step()))
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		if event.pressed:
			grab_focus()
			var coordinate: float = _coordinate(event.position)
			var thumb: Rect2 = _local_thumb()
			if thumb.has_point(event.position):
				_dragging = true
				_drag_start = coordinate
				_drag_value = value
			else:
				var leading: float = thumb.position.y if vertical else thumb.position.x
				_request(value + (-page if coordinate < leading else page))
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var rect: Rect2i = rail.rect
		var thumb: Rect2i = rail.thumb
		var axis := 1 if vertical else 0
		var travel: int = rect.size[axis]-thumb.size[axis]
		var native_delta: float = (_coordinate(event.position)-_drag_start)/2.0
		_request(_drag_value+roundi(native_delta*maximum/travel))
		accept_event()
	elif event is InputEventKey:
		if not event.pressed or event.echo: return
		var next_value := value
		match event.keycode:
			KEY_HOME: next_value = 0
			KEY_END: next_value = maximum
			KEY_PAGEUP: next_value -= page
			KEY_PAGEDOWN: next_value += page
			KEY_UP:
				if not vertical: return
				next_value -= _step()
			KEY_DOWN:
				if not vertical: return
				next_value += _step()
			KEY_LEFT:
				if vertical: return
				next_value -= _step()
			KEY_RIGHT:
				if vertical: return
				next_value += _step()
			_: return
		_request(next_value)
		accept_event()


func _request(next_value: int) -> void:
	next_value = clampi(next_value,0,maximum)
	if next_value != value: scroll_requested.emit(next_value)


func _step() -> int:
	return 32 if _large else 24


func _coordinate(point: Vector2) -> float:
	return point.y if vertical else point.x


func _local_thumb() -> Rect2:
	var rect: Rect2i = rail.rect
	var thumb: Rect2i = rail.thumb
	return Rect2(Vector2((thumb.position-rect.position)*2),Vector2(thumb.size*2))


func _on_focus_exited() -> void:
	_dragging = false
	queue_redraw()


func _refresh_accessibility() -> void:
	if rail.is_empty():
		accessibility_name = ""
		accessibility_description = ""
		return
	match _locale:
		"zh-CN":
			accessibility_name = "垂直滚动" if vertical else "水平滚动"
			accessibility_description = "位置%d，共%d" % [value,maximum]
		"zh-HK":
			accessibility_name = "垂直捲動" if vertical else "水平捲動"
			accessibility_description = "位置%d，共%d" % [value,maximum]
		_:
			accessibility_name = "Vertical scroll" if vertical else "Horizontal scroll"
			accessibility_description = "Position %d of %d" % [value,maximum]


func _draw() -> void:
	if rail.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),get_theme_color(&"controlled_face",&"Minesweeper"))
	draw_rect(Rect2(1,1,size.x-2,size.y-2),get_theme_color(&"dark_registration",&"Minesweeper"),false,2)
	var thumb: Rect2 = _local_thumb()
	# The hit rail stays generous; only the centred thumb is visually narrow.
	var cross := 0 if vertical else 1
	var inset := maxf(3.0, (thumb.size[cross] - 8.0) / 2.0)
	thumb.position[cross] += inset
	thumb.size[cross] -= inset * 2.0
	draw_rect(thumb,get_theme_color(&"dark_scroll_thumb",&"Minesweeper"))
	draw_rect(thumb.grow(-1),get_theme_color(&"dark_separation",&"Minesweeper"),false,2)
	if has_focus() and interactive:
		draw_rect(Rect2(2,2,size.x-4,size.y-4),get_theme_color(&"dark_focus_outer",&"Minesweeper"),false,2)
		draw_rect(Rect2(6,6,size.x-12,size.y-12),get_theme_color(&"dark_focus_inner",&"Minesweeper"),false,2)

