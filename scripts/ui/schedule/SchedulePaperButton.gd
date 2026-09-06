extends Button
## A single semantic target. Text/art are drawn by its owning panel; marks add no nodes.

var kind := "command"
var selected := false
var unavailable := false
var drag_grip := Rect2()
var drag_started := Callable()
var drag_ended := Callable()
var detached_focus := false

func _ready() -> void:
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)

func cancel_contact() -> void:
	var prior := disabled
	disabled = true
	disabled = prior
	queue_redraw()

func _get_drag_data(at_position: Vector2) -> Variant:
	if disabled or kind != "entry" or not drag_grip.has_point(at_position) or not drag_started.is_valid():
		return null
	return drag_started.call()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and drag_ended.is_valid():
		drag_ended.call()

func _line(rect: Rect2, ink: Color) -> void:
	draw_rect(Rect2(rect.position * 2, rect.size * 2), ink)

func draw_focus_on(canvas: CanvasItem, offset: Vector2 = Vector2.ZERO) -> void:
	var outer := get_theme_color(&"ink",&"Schedule") if kind == "done" else get_theme_color(&"habitat",&"Schedule")
	var inner := get_theme_color(&"focus",&"Schedule") if kind == "done" else get_theme_color(&"face" if selected else &"paper_focus",&"Schedule")
	for margin: int in [8,4]:
		var rect := Rect2(offset-Vector2(margin,margin),size+Vector2(margin*2,margin*2))
		var ink := outer if margin == 8 else inner
		for line: Rect2 in [Rect2(rect.position,Vector2(rect.size.x,2)),
			Rect2(rect.position+Vector2(0,rect.size.y-2),Vector2(rect.size.x,2)),
			Rect2(rect.position,Vector2(2,rect.size.y)),
			Rect2(rect.position+Vector2(rect.size.x-2,0),Vector2(2,rect.size.y))]:
			canvas.draw_rect(line,ink)

func _draw() -> void:
	var width := size.x / 2
	var height := size.y / 2
	var paper_ink := get_theme_color(&"paper_ink",&"Schedule")
	var face := get_theme_color(&"face",&"Schedule")
	var structure := get_theme_color(&"structure",&"Schedule")
	var command := kind in ["command", "done"]
	var carrier := Rect2(0, 0, width, height)
	if kind == "source": carrier = Rect2(28, 0, width - 28, height)
	if kind == "entry": carrier = Rect2(12, 0, width - 12, height)
	if command: _line(Rect2(0, 0, width, height), face)
	if selected:
		if kind == "source":
			for rect in [Rect2(0,0,width,4), Rect2(0,4,4,24), Rect2(28,4,width-28,24), Rect2(0,28,width,height-28)]:
				_line(rect,get_theme_color(&"filed",&"Schedule"))
		else: _line(carrier,get_theme_color(&"filed",&"Schedule"))
		_line(Rect2(width-2, 0, 2, height),paper_ink)
	if unavailable:
		# Clockwise one-native-pixel perimeter, two on/two off.
		var perimeter: Array[Vector2] = []
		for x in int(width): perimeter.append(Vector2(x,0))
		for y in range(1,int(height)): perimeter.append(Vector2(width-1,y))
		for x in range(int(width)-2,-1,-1): perimeter.append(Vector2(x,height-1))
		for y in range(int(height)-2,0,-1): perimeter.append(Vector2(0,y))
		for index in perimeter.size():
			if index % 4 < 2: _line(Rect2(perimeter[index],Vector2.ONE),paper_ink)
		for y in range(1,int(height)-1):
			for x in range(92,100):
				if (x-92+y-1)%4 == 0: _line(Rect2(x,y,1,1),paper_ink)
	elif disabled and command:
		var gy := floorf((height-5)/2)
		for rect in [Rect2(width-5,gy,5,1),Rect2(width-5,gy,1,5),Rect2(width-1,gy,1,5)]:
			_line(rect,structure)
	elif not disabled:
		var mark := structure if command else paper_ink
		if is_pressed(): _line(Rect2(carrier.position+Vector2(2,2),Vector2(carrier.size.x-4,1)),mark)
		elif is_hovered(): _line(Rect2(carrier.position+Vector2(2,2),Vector2(1,carrier.size.y-4)),mark)
		if has_focus() and not detached_focus: draw_focus_on(self)
