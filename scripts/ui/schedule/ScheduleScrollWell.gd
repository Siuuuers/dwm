extends Control
## An inert scroll witness; Range remains owned by the existing ScrollContainer.
var scroll: ScrollContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if scroll != null:
		scroll.get_v_scroll_bar().changed.connect(queue_redraw)
		scroll.get_v_scroll_bar().value_changed.connect(func(_value): queue_redraw())

func _draw() -> void:
	if scroll == null: return
	var bar := scroll.get_v_scroll_bar()
	if bar.max_value <= bar.page: return
	var viewport_h := size.y / 2
	var extent := bar.max_value / 2
	var thumb := maxf(8,floorf(viewport_h*viewport_h/extent))
	var offset := floorf((viewport_h-thumb)*bar.value/(bar.max_value-bar.page))
	draw_rect(Rect2(8,0,2,size.y),Color("151b25"))
	draw_rect(Rect2(6,offset*2,6,thumb*2),Color("151b25"))
