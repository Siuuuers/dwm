extends CanvasLayer
## A witnessed staging card. Ordering, provenance and persistence belong to its caller.
signal card_acknowledged(receipt: Dictionary, result: Dictionary)
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
var _history: Array[Dictionary] = []
var _root: Control
var _scene_art: SCENE_ART
var _reading_margin: MarginContainer
var _history_list: VBoxContainer
var _scroll: ScrollContainer
var _current_body: Label
var _next: Button
var _status: Label

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

func show_advance_retry(retry: Callable) -> Dictionary:
	if not _configured or not retry.is_valid(): return _fail("prelude_retry_unavailable")
	if _busy or (not _card.is_empty() and not _accepted): return _fail("prelude_card_still_pending")
	_advance_retry = retry
	if is_node_ready(): _show_advance_retry()
	return {"ok": true}

func _show_advance_retry() -> void:
	_status.text = _copy(3)
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
	_card = card.duplicate(true)
	_advance_retry = Callable()
	_drawn = false
	_accepted = false
	if is_node_ready(): _append_card()
	return {"ok": true}

func get_presentation_history() -> Array[Dictionary]:
	return _history.duplicate(true)

func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.name = "Day7Prelude"
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
	layout.add_child(_scroll)
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 24)
	_scroll.add_child(_history_list)
	_status = Label.new()
	_status.name = "PreludeStatus"
	_status.add_theme_color_override("font_color", Color("252b34"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	for property: String in ["focus_next", "focus_previous", "focus_neighbor_top", "focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right"]:
		_next.set(property, _next.get_path())
	if _card.is_empty(): _show_advance_retry()
	else: _append_card()

func _append_card() -> void:
	_refresh_scene_art()
	_status.text = ""
	_next.text = _copy(0)
	_next.disabled = true
	var title := Label.new()
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
	_drawn = true
	_history.append(_card.duplicate(true))
	_next.disabled = false
	_focus_next.call_deferred()

func _on_next() -> void:
	if _retrying or not is_inside_tree() or is_queued_for_deletion(): return
	if _advance_retry.is_valid():
		_retrying = true
		_next.disabled = true
		# The preparation callback may synchronously call present_card; _busy stays false.
		_invoke_advance_retry(weakref(self), _advance_retry)
		return
	if _busy or _accepted or not _drawn or not is_instance_valid(_current_body) or not _current_body.is_visible_in_tree(): return
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
	if not result is Dictionary or not result.get("ok", false):
		_status.text = _copy(2)
		_next.text = _copy(1)
		_next.disabled = false
		_focus_next()
		return
	_accepted = true
	card_acknowledged.emit(receipt.duplicate(true), result.duplicate(true))

static func _invoke_advance_retry(target: WeakRef, retry: Callable) -> void:
	var result: Variant = await retry.call()
	var surface: Node = target.get_ref()
	if is_instance_valid(surface): surface._complete_advance_retry(retry, result)

func _complete_advance_retry(retry: Callable, result: Variant) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	_retrying = false
	if _advance_retry != retry: return # A new real card was already installed.
	if not result is Dictionary or not result.get("ok", false): _show_advance_retry()

func _focus_next() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_next) \
		or not _next.is_visible_in_tree() or _next.disabled: return
	_next.grab_focus()

func _reveal_current_card(token: String) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _card.get("receipt", {}).get("view_token") != token \
		or not is_instance_valid(_scroll) or not is_instance_valid(_current_body): return
	_scroll.ensure_control_visible(_current_body)

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
