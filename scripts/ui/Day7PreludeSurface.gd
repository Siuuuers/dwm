extends CanvasLayer
## A witnessed staging card. Ordering, provenance and persistence belong to its caller.
signal card_acknowledged(receipt: Dictionary, result: Dictionary)
signal advance_requested(receipt: Dictionary)
const SCENE_ART := preload("res://scripts/ui/art/SceneArtView.gd")
const COPY := {
	"en": ["Next", "Retry", "This moment could not be saved. Please try again.", "Unable to continue. Please try again."],
	"zh-CN": ["\u4e0b\u4e00\u9879", "\u91cd\u8bd5", "\u6682\u65f6\u65e0\u6cd5\u4fdd\u5b58\u8fd9\u4e00\u523b\uff0c\u8bf7\u91cd\u8bd5\u3002", "\u6682\u65f6\u65e0\u6cd5\u7ee7\u7eed\uff0c\u8bf7\u91cd\u8bd5\u3002"],
	"zh-HK": ["\u4e0b\u4e00\u9805", "\u91cd\u8a66", "\u66ab\u6642\u7121\u6cd5\u5132\u5b58\u9019\u4e00\u523b\uff0c\u8acb\u91cd\u8a66\u3002", "\u66ab\u6642\u7121\u6cd5\u7e7c\u7e8c\uff0c\u8acb\u91cd\u8a66\u3002"]}
var _configured := false
var _advance_retry: Callable
var _retrying := false
var _card: Dictionary = {}
var _acknowledge: Callable
var _locale := "en"
var _presentation_theme: Theme
var _drawn := false
var _accepted := false
var _busy := false
var _presentation_receipts := false
var _navigation_requested := false
var _history: Array[Dictionary] = []
var _root: Control
var _scene_art: SCENE_ART
var _reading_margin: MarginContainer
var _history_list: VBoxContainer
var _scroll: ScrollContainer
var _current_title: Label
var _current_body: Label
var _next: Button
var _status: Label
var _input_owner: Node
var _custody_bound := false
var _pointer: Control
var _contacts: Dictionary = {}
var _blocked_contacts: Dictionary = {}
var _candidate: Dictionary = {}
var _fresh_contact := ""
var _input_generation := 0
var _retired_frame := -1
var _foreground := true
var _input_activation := false
var _focus_pending: Control
var _covered := false
var _pause_anchor: Dictionary = {}
var _capture_id := 0
var _acknowledgment_pending := false

func configure(card: Dictionary, acknowledge: Callable, locale: String = "en", presentation_theme: Theme = null) -> Dictionary:
	if is_node_ready() or _configured: return _fail("prelude_already_configured")
	if not acknowledge.is_valid(): return _fail("prelude_acknowledgment_unavailable")
	var checked := _validate_card(card)
	if not checked.ok: return checked
	_configured = true
	_card = card.duplicate(true)
	_acknowledge = acknowledge
	_locale = locale.replace("_", "-")
	_presentation_theme = presentation_theme
	return {"ok": true}

func configure_waiting(retry: Callable, acknowledge: Callable, locale: String = "en", presentation_theme: Theme = null) -> Dictionary:
	if is_node_ready() or _configured: return _fail("prelude_already_configured")
	if not retry.is_valid() or not acknowledge.is_valid(): return _fail("prelude_acknowledgment_unavailable")
	_configured = true
	_advance_retry = retry
	_acknowledge = acknowledge
	_locale = locale.replace("_", "-")
	_presentation_theme = presentation_theme
	return {"ok": true}

## Day 7 witnesses on presentation, then keeps the card until navigation. Gallery
## replay keeps its separate completion-on-Next contract through the default mode.
func use_presentation_receipts() -> Dictionary:
	if not _configured or is_inside_tree(): return _fail("prelude_already_configured")
	_presentation_receipts = true
	return {"ok": true}

func is_card_acknowledged(receipt: Dictionary) -> bool:
	return _accepted and not is_queued_for_deletion() and _card.get("receipt", {}) == receipt

func show_advance_retry(retry: Callable) -> Dictionary:
	if not _configured or not retry.is_valid(): return _fail("prelude_retry_unavailable")
	if _busy or (not _card.is_empty() and not _accepted): return _fail("prelude_card_still_pending")
	_retire_input()
	_advance_retry = retry
	if is_node_ready(): _show_advance_retry()
	return {"ok": true}

func _show_advance_retry() -> void:
	_status.text = _copy(3)
	_status.show()
	_next.text = _copy(1)
	_next.disabled = false
	_focus_next.call_deferred()

func present_card(card: Dictionary) -> Dictionary:
	if not _configured: return _fail("prelude_acknowledgment_unavailable")
	var checked := _validate_card(card)
	if not checked.ok: return checked
	if card == _card: return {"ok": true, "value": {"already_presented": true}}
	if _busy or (not _card.is_empty() and not _accepted): return _fail("prelude_card_still_pending")
	if not _card.is_empty() and card.receipt.view_token == _card.receipt.view_token: return _fail("prelude_card_identity_mismatch")
	_retire_input()
	_pause_anchor.clear()
	_card = card.duplicate(true)
	_advance_retry = Callable()
	_drawn = false
	_accepted = false
	_navigation_requested = false
	if is_node_ready(): _append_card()
	return {"ok": true}

func get_presentation_history() -> Array[Dictionary]:
	return _history.duplicate(true)

func _ready() -> void:
	layer = 30
	if _presentation_receipts: add_to_group("day7_prelude_surface")
	visibility_changed.connect(_retire_input)
	_root = Control.new()
	_root.name = "Day7Prelude"
	_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	_root.theme = _presentation_theme
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("202631")
	_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene_art = SCENE_ART.new()
	_scene_art.name = "SceneArt"
	_root.add_child(_scene_art)
	_scene_art.hide()
	var margin := MarginContainer.new()
	_reading_margin = margin
	_root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 96)
	for edge: String in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 48)
	var panel := PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f1ebdf")
	for edge: String in ["left", "right", "top", "bottom"]: paper.set("content_margin_" + edge, 24)
	panel.add_theme_stylebox_override("panel", paper)
	margin.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	_scroll = ScrollContainer.new()
	_scroll.name = "PresentationHistory"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	_scroll.resized.connect(_redraw_current_body)
	layout.add_child(_scroll)
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 24)
	_scroll.add_child(_history_list)
	_status = Label.new()
	_status.name = "PreludeStatus"
	_status.add_theme_color_override("font_color", Color("252b34"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.hide()
	layout.add_child(_status)
	_next = Button.new()
	_next.name = "NextPreludeCard"
	_next.custom_minimum_size.y = 56
	_next.add_theme_color_override("font_color", Color("252b34"))
	_next.add_theme_color_override("font_hover_color", Color("252b34"))
	_next.add_theme_color_override("font_pressed_color", Color("252b34"))
	_next.add_theme_color_override("font_focus_color", Color("252b34"))
	_next.pressed.connect(_on_next)
	layout.add_child(_next)
	_next.focus_exited.connect(_retire_input)
	_pointer = Control.new()
	_pointer.name = "NextPointerSurface"
	_pointer.mouse_filter = Control.MOUSE_FILTER_STOP if _custody_bound else Control.MOUSE_FILTER_IGNORE
	_next.add_child(_pointer)
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.gui_input.connect(_pointer_input)
	for property: String in ["focus_next", "focus_previous", "focus_neighbor_top", "focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right"]:
		_next.set(property, _next.get_path())
	if _card.is_empty(): _show_advance_retry()
	else: _append_card()

func _append_card() -> void:
	_refresh_scene_art()
	_status.text = ""
	_status.hide()
	_next.text = _copy(0)
	_next.disabled = true
	var title := Label.new()
	_current_title = title
	title.text = _card.title
	title.add_theme_color_override("font_color", Color("252b34"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_list.add_child(title)
	_current_body = Label.new()
	_current_body.name = "StagingDetail"
	_current_body.text = _card.body
	_current_body.add_theme_color_override("font_color", Color("252b34"))
	_current_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_current_body.draw.connect(_on_body_drawn.bind(_card.receipt.duplicate(true)))
	_current_body.item_rect_changed.connect(_redraw_current_body)
	_history_list.add_child(_current_body)
	_reveal_current_card.call_deferred(str(_card.receipt.view_token))

func _refresh_scene_art() -> void:
	# GalleryTheme uses 24/30/36 px at the three supported reading sizes.
	var font_size := _root.get_theme_default_font_size()
	var percent := 150 if font_size >= 36 else (125 if font_size >= 30 else 100)
	_scene_art.configure_entry(str(_card.receipt.entry_id), percent)
	# Keep the existing opaque reading panel below art; absent images preserve its layout.
	_reading_margin.add_theme_constant_override("margin_top",
		int(_scene_art.size.y) if _scene_art.visible else 48)

func _on_body_drawn(receipt: Dictionary) -> void:
	if receipt != _card.receipt or _drawn or not is_instance_valid(_current_body) \
		or not _current_body.is_visible_in_tree() or is_queued_for_deletion(): return
	if _presentation_receipts and not _beginning_is_visible(): return
	_drawn = true
	_history.append(_card.duplicate(true))
	if _presentation_receipts:
		# The renderer's acceptance is the witness. Save outside its draw callback;
		# a retired or replaced source cannot admit this queued receipt afterward.
		_acknowledgment_pending = true
		_acknowledge_drawn_card.call_deferred(receipt.duplicate(true))
	else:
		_next.disabled = false
		_focus_next.call_deferred()

func _acknowledge_drawn_card(receipt: Dictionary) -> void:
	_acknowledgment_pending = false
	if not is_inside_tree() or is_queued_for_deletion() or receipt != _card.get("receipt", {}) \
			or not _drawn or _busy or _accepted: return
	_submit_acknowledgment()

func _on_next() -> void:
	if _retrying or not is_inside_tree() or is_queued_for_deletion() or _covered: return
	if _custody_bound and (not _input_activation or not _input_admitted()): return
	_retire_input()
	if _advance_retry.is_valid():
		_retrying = true
		_next.disabled = true
		# The preparation callback may synchronously call present_card; _busy stays false.
		_invoke_advance_retry(weakref(self), _advance_retry)
		return
	if _busy or not _drawn or not is_instance_valid(_current_body) or not _current_body.is_visible_in_tree(): return
	if _accepted:
		if _presentation_receipts and not _navigation_requested:
			_navigation_requested = true
			_next.disabled = true
			advance_requested.emit(_card.receipt.duplicate(true))
		return
	_submit_acknowledgment()

func _submit_acknowledgment() -> void:
	_busy = true
	_next.disabled = true
	_invoke_acknowledgment(weakref(self), _acknowledge, _card.receipt.duplicate(true))

static func _invoke_acknowledgment(target: WeakRef, acknowledge: Callable, receipt: Dictionary) -> void:
	var result: Variant = await acknowledge.call(receipt.duplicate(true))
	var surface: Node = target.get_ref()
	if is_instance_valid(surface): surface._complete_acknowledgment(receipt, result)

func _complete_acknowledgment(receipt: Dictionary, result: Variant) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _card.receipt != receipt: return
	_busy = false
	_retire_input()
	if not result is Dictionary or not result.get("ok", false):
		_status.text = _copy(2)
		_status.show()
		_next.text = _copy(1)
		_next.disabled = false
		_focus_next()
		return
	_accepted = true
	if _presentation_receipts:
		_status.text = ""
		_status.hide()
		_next.text = _copy(0)
		_next.disabled = false
		_focus_next.call_deferred()
	card_acknowledged.emit(receipt.duplicate(true), result.duplicate(true))

static func _invoke_advance_retry(target: WeakRef, retry: Callable) -> void:
	var result: Variant = await retry.call()
	var surface: Node = target.get_ref()
	if is_instance_valid(surface): surface._complete_advance_retry(retry, result)

func _complete_advance_retry(retry: Callable, result: Variant) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	_retrying = false
	_retire_input()
	if _advance_retry != retry: return # A new real card was already installed.
	if not result is Dictionary or not result.get("ok", false): _show_advance_retry()

func _focus_next() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_next) \
		or not _next.is_visible_in_tree() or _next.disabled: return
	if _covered: return
	if _custody_bound and (not _input_admitted() or not _input_owner.get_physical_contacts().is_empty()):
		_focus_pending = _next
		return
	_next.grab_focus()

func _reveal_current_card(token: String) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _card.get("receipt", {}).get("view_token") != token \
		or not is_instance_valid(_scroll) or not is_instance_valid(_current_body): return
	if not _presentation_receipts:
		_scroll.ensure_control_visible(_current_body)
		return
	# A tall control's ensure_control_visible() aligns its bottom. Wait for layout
	# and start at the title instead, leaving the whole body available to scroll.
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion() or _card.get("receipt", {}).get("view_token") != token: return
	_scroll.scroll_vertical = int(_current_title.position.y)
	_redraw_current_body()

func _beginning_is_visible() -> bool:
	var body := _current_body.get_global_rect()
	var aperture := _scroll.get_global_rect().intersection(_root.get_viewport_rect())
	return body.has_area() and aperture.has_area() \
		and body.position.y >= aperture.position.y and body.position.y < aperture.end.y \
		and body.end.x > aperture.position.x and body.position.x < aperture.end.x

func _on_scroll_changed(_value: float) -> void:
	_candidate.clear()
	_redraw_current_body()

func _redraw_current_body() -> void:
	if _presentation_receipts and not _drawn and is_instance_valid(_current_body):
		_current_body.queue_redraw()

## Explicitly bound by the production owner; standalone Gallery keeps native Button semantics.
func bind_input_custody(owner: Node) -> bool:
	if not is_instance_valid(owner): return false
	for method: String in ["get_physical_contacts", "observe_physical_contact", "get_physical_contact_id", "is_source_input_admitted"]:
		if not owner.has_method(method): return false
	for event: String in ["source_input_custody_changed", "input_bindings_changed"]:
		if not owner.has_signal(event): return false
	if _custody_bound: return is_instance_valid(_input_owner) and _input_owner == owner
	_custody_bound = true
	_input_owner = owner
	owner.connect("source_input_custody_changed", _retire_input)
	owner.connect("input_bindings_changed", _retire_input)
	process_mode = Node.PROCESS_MODE_ALWAYS # Releases remain observable through universal Pause.
	if is_instance_valid(_pointer): _pointer.mouse_filter = Control.MOUSE_FILTER_STOP
	_retire_input()
	return true

func _retire_input() -> void:
	_candidate.clear()
	_fresh_contact = ""
	_input_generation += 1
	_retired_frame = Engine.get_process_frames()
	if is_instance_valid(_input_owner):
		_contacts = _input_owner.get_physical_contacts()
		_blocked_contacts = _contacts.duplicate()

func _input_admitted() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and visible and not _covered \
		and _foreground and not get_tree().paused and is_instance_valid(_next) \
		and _next.is_visible_in_tree() and not _next.disabled \
		and Engine.get_process_frames() != _retired_frame and _blocked_contacts.is_empty() \
		and is_instance_valid(_input_owner) and _input_owner.is_source_input_admitted()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_foreground = false
		_retire_input()
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_foreground = true
		_retire_input()
	elif what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]:
		_retire_input()

func _process(_delta: float) -> void:
	if not is_instance_valid(_input_owner): return
	_prune_contacts()
	if is_instance_valid(_focus_pending) and _input_admitted() and _input_owner.get_physical_contacts().is_empty():
		var target := _focus_pending
		_focus_pending = null
		if target.is_visible_in_tree(): target.grab_focus()

func _prune_contacts() -> void:
	var current: Dictionary = _input_owner.get_physical_contacts()
	for id: String in _blocked_contacts.keys():
		if current.get(id) != _blocked_contacts[id]: _blocked_contacts.erase(id)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_input_owner) or event.device == InputEvent.DEVICE_ID_EMULATION: return
	_input_owner.observe_physical_contact(event)
	_prune_contacts()
	var id: String = _input_owner.get_physical_contact_id(event)
	var current: Dictionary = _input_owner.get_physical_contacts()
	_fresh_contact = ""
	if not id.is_empty() and event.is_pressed() and current.get(id) != _contacts.get(id):
		_fresh_contact = id
	_contacts = current
	if current.size() > 1:
		_retire_input()
		return
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if not _candidate.is_empty() and _candidate.has("origin"):
			var point: Vector2 = _pointer.get_global_transform_with_canvas().affine_inverse() * event.position
			if point.distance_to(_candidate.origin) > 8.0 or not Rect2(Vector2.ZERO, _pointer.size).has_point(point):
				_candidate.clear()
		return
	if event is InputEventScreenTouch and event.canceled:
		_candidate.clear()
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction): return
	if not is_instance_valid(_next) or not _next.has_focus() or not visible or _covered or get_tree().paused: return
	var direction := _page_direction(event)
	if direction != 0:
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo() and _fresh_contact == id and _input_admitted():
			_candidate.clear()
			var bar := _scroll.get_v_scroll_bar()
			bar.value += bar.page * direction
		return
	if not event.is_action("ui_accept"): return
	if not visible or _covered or get_tree().paused: return
	get_viewport().set_input_as_handled()
	if event.is_pressed():
		if (not event is InputEventKey or not event.echo) and _fresh_contact == id and _input_admitted():
			_candidate = {"id": id, "generation": _input_generation}
	elif _candidate.get("id") == id:
		_activate_candidate()

func _page_direction(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER: return -1
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER: return 1
	if event is InputEventKey or event is InputEventAction:
		if event.is_action(&"ui_page_up", true): return -1
		if event.is_action(&"ui_page_down", true): return 1
	return 0

func _pointer_input(event: InputEvent) -> void:
	if not is_instance_valid(_input_owner): return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		_pointer.accept_event()
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton): return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT: return
	_pointer.accept_event()
	var id: String = _input_owner.get_physical_contact_id(event)
	if event.is_pressed():
		if _fresh_contact != id or not _input_admitted(): return
		if event is InputEventMouseButton and event.double_click: return
		_next.grab_focus()
		# Focus callbacks can hide/reopen or leave and return before this press arms.
		if _fresh_contact != id or not _input_admitted() or not _next.has_focus(): return
		_candidate = {"id": id, "generation": _input_generation, "origin": event.position}
	elif _candidate.get("id") == id:
		if (event is InputEventScreenTouch and event.canceled) or not Rect2(Vector2.ZERO, _pointer.size).has_point(event.position):
			_candidate.clear()
			return
		_activate_candidate()

func _activate_candidate() -> void:
	var admitted: bool = _candidate.get("generation", -1) == _input_generation and _input_admitted() and _next.has_focus()
	_candidate.clear()
	if not admitted: return
	_input_activation = true
	_on_next()
	_input_activation = false

func get_pause_projection() -> Dictionary:
	if not _presentation_receipts or not is_inside_tree() or is_queued_for_deletion(): return {}
	if _covered: return _pause_anchor.get("projection", {}).duplicate(true)
	if not visible or _busy or _retrying or _acknowledgment_pending or _navigation_requested: return {}
	if not _drawn and not _advance_retry.is_valid(): return {}
	return {"view_id": get_instance_id(), "receipt": _card.get("receipt", {}).duplicate(true), "acknowledged": _accepted}

func capture_pause_view(source: Dictionary) -> Dictionary:
	var projection := get_pause_projection()
	if _covered or projection.is_empty(): return {"ok": false, "code": &"pause_view_unavailable"}
	_capture_id += 1
	var focus := get_viewport().gui_get_focus_owner()
	_pause_anchor = {"view_id": get_instance_id(), "capture_id": _capture_id,
		"projection": projection, "source": source.duplicate(true), "scroll": _scroll.scroll_vertical,
		"focus": _root.get_path_to(focus) if is_instance_valid(focus) and _root.is_ancestor_of(focus) else NodePath()}
	return {"ok": true, "value": _pause_anchor.duplicate(true)}

func cover_pause_view(anchor: Dictionary) -> bool:
	if anchor.is_empty() or anchor != _pause_anchor or get_pause_projection() != anchor.projection: return false
	if _covered: return true
	_focus_pending = null
	_covered = true
	_retire_input()
	hide()
	return true

func restore_pause_view(anchor: Dictionary) -> bool:
	if not _covered or anchor.is_empty() or anchor != _pause_anchor or get_pause_projection() != anchor.projection: return false
	_focus_pending = null
	_covered = false
	show()
	_scroll.scroll_vertical = int(anchor.scroll)
	_retire_input()
	var focus: Control = _root.get_node_or_null(anchor.focus) if not anchor.focus.is_empty() else null
	if is_instance_valid(focus):
		if _custody_bound: _focus_pending = focus
		else: focus.grab_focus.call_deferred()
	return true

func _copy(index: int) -> String:
	return COPY.get(_locale, COPY.en)[index]

static func _validate_card(card: Dictionary) -> Dictionary:
	if card.size() != 3 or not card.get("title") is String or not card.get("body") is String \
		or not card.get("receipt") is Dictionary or card.title.is_empty() or card.body.is_empty():
		return _fail("invalid_prelude_card")
	var receipt: Dictionary = card.receipt
	if not receipt.get("entry_id") is String or not receipt.get("view_token") is String \
		or receipt.entry_id.is_empty() or receipt.view_token.is_empty(): return _fail("invalid_prelude_receipt")
	return {"ok": true}

static func _fail(code: String) -> Dictionary:
	return {"ok": false, "code": StringName(code)}
