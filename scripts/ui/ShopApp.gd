extends AppWindowBase
class_name ShopApp
## Public Shop presentation. The host supplies a fresh catalog snapshot and owns purchases through
## the configured semantic provider; this node never reads or writes gameplay state directly.

signal recovery_requested(code: String)

const PROJECTION := preload("res://scripts/ui/shop/ShopCatalogProjection.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const CARD := preload("res://scenes/shared/ShopItemBox.tscn")
const SHOP_THEME := preload("res://scripts/ui/shop/ShopTheme.gd")
const SUPPORTZ_CONFIRMATION := preload("res://scripts/ui/shop/SupportzConfirmation.gd")
const CONFIRMATION_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")

var cards: Dictionary = {}
var page_index := 0
var page_capacity := 9
var page_count := 2
var selected_id := "coffee"
var quantity := 1
var _item_quantities: Dictionary = {}
var previous_button: Button
var next_button: Button
var page_label: Label
var info_scroll: ScrollContainer
var quantity_buttons: Dictionary = {}
var status_label: Label
var _buy_button: Button
var _supportz_button: Button
var _supportz_confirmation: Control
var last_result := {"ok": false, "code": "shop_unconfigured"}
var _purchase_result := {"ok": false, "code": "shop_purchase_unconfigured"}
var _records: Array = []
var _body: Control
var _catalog: Control
var _document: Control
var _art: TextureRect
var _name_label: Label
var _description_label: Label
var _meta_price: Label
var _meta_state: Label
var _quantity_label: Label
var _total_label: Label
var _information_overlay: Control
var _home: Button
var _locale := "en"
var _percent := 100
var _large := false
var _page_selection: Dictionary = {}
var _measurement_revision := 0
var _focus_after_layout := true
var _palette: StringName = &"after_hours"
var _day := 1
var _high_contrast := false
var _colour_preset := "standard"
var _roles: Dictionary = SHOP_THEME.resolve(&"after_hours")
var _provider: Object
var _localization: Object
var _profile: Object
var _catalog_rows: Array = []
var _refresh_pending := false
var _refreshing := false
var _source_pending := false
var _large_targets := false
var _host_anchor: Dictionary = {}
var _remembered_focus := "selected"
var _focus_viewport: Viewport
var _view_exiting := false
var _catalog_layout_pending := false
const PREFERENCE_KEYS := ["preferences.accessibility.text_size","preferences.accessibility.large_targets",
	"preferences.accessibility.high_contrast","preferences.accessibility.colour_differentiation"]

func _enter_tree() -> void:
	_view_exiting = false
	if is_node_ready():
		_connect_focus_observer()
		if _catalog_layout_pending: _measure_catalog.call_deferred(_measurement_revision)

func _exit_tree() -> void:
	_view_exiting = true
	_measurement_revision += 1
	_host_anchor.clear()
	if is_instance_valid(_focus_viewport) and _focus_viewport.gui_focus_changed.is_connected(_on_viewport_focus_changed):
		_focus_viewport.gui_focus_changed.disconnect(_on_viewport_focus_changed)
	_focus_viewport = null

func _connect_focus_observer() -> void:
	_focus_viewport = get_viewport()
	if is_instance_valid(_focus_viewport) and not _focus_viewport.gui_focus_changed.is_connected(_on_viewport_focus_changed):
		_focus_viewport.gui_focus_changed.connect(_on_viewport_focus_changed)

func _on_viewport_focus_changed(_control: Control) -> void:
	if not _view_is_current(): return
	_remember_focus()
	if _refresh_pending and not _other_control_has_focus(): refresh_view.call_deferred(false,true)

func _view_is_current() -> bool:
	if _view_exiting or not is_inside_tree() or get_viewport() == null: return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion() or not ancestor.is_inside_tree(): return false
		ancestor = ancestor.get_parent()
	return true

func configure_catalog(provider: Object, localization: Object = null, profile: Object = null, palette: StringName = &"after_hours", day: int = 1) -> Dictionary:
	if SHOP_THEME.resolve(palette, day).is_empty(): return {"ok":false,"code":"invalid_shop_palette"}
	if not is_instance_valid(provider) or not provider.has_method("get_catalog") or Callable(provider,"get_catalog").get_argument_count() != 1 or not provider.has_signal("catalog_changed"):
		return {"ok":false,"code":"invalid_shop_catalog_provider"}
	if provider.has_method("purchase") and Callable(provider,"purchase").get_argument_count() != 2:
		return {"ok":false,"code":"invalid_shop_purchase_provider"}
	if provider.has_method("can_purchase") and Callable(provider,"can_purchase").get_argument_count() != 2:
		return {"ok":false,"code":"invalid_shop_purchase_provider"}
	for signal_info: Dictionary in provider.get_signal_list():
		if signal_info.name == "catalog_changed" and not signal_info.args.is_empty():
			return {"ok":false,"code":"invalid_shop_catalog_provider"}
	if localization != null and (not is_instance_valid(localization) or not localization.has_method("get_locale") or not localization.has_signal("locale_changed")):
		return {"ok":false,"code":"invalid_shop_preferences"}
	if profile != null and (not is_instance_valid(profile) or not profile.has_method("get_preference") or not profile.has_signal("preference_changed")):
		return {"ok":false,"code":"invalid_shop_preferences"}
	if (_provider != null and (_provider != provider or _palette != palette or _day != day)) or (_localization != null and localization != null and _localization != localization) or (_profile != null and profile != null and _profile != profile):
		return {"ok":false,"code":"shop_catalog_already_configured"}
	var next_localization: Object = localization if localization != null else _localization
	var next_profile: Object = profile if profile != null else _profile
	var preferences := _read_preferences(next_localization,next_profile)
	if not preferences.ok: return preferences
	if _provider == null:
		_palette = palette
		_day = day
		_roles = SHOP_THEME.resolve(palette, day, preferences.value[3], preferences.value[4])
		_source_pending = true
		_provider = provider
		_provider.connect("catalog_changed",_on_catalog_changed)
	if _localization == null and next_localization != null:
		_localization = next_localization
		if not _localization.is_connected("locale_changed", _on_locale_changed):
			_localization.connect("locale_changed",_on_locale_changed)
	if _profile == null and next_profile != null:
		_profile = next_profile
		if not _profile.is_connected("preference_changed", _on_preference_changed):
			_profile.connect("preference_changed",_on_preference_changed)
	return refresh_view()

func _read_preferences(localization: Object, profile: Object) -> Dictionary:
	if (localization != null and not is_instance_valid(localization)) or (profile != null and not is_instance_valid(profile)):
		return {"ok":false,"code":"invalid_shop_preferences"}
	var locale: Variant = localization.get_locale() if localization != null else _locale
	var percent: Variant = profile.get_preference(PREFERENCE_KEYS[0],null) if profile != null else _percent
	var large: Variant = profile.get_preference(PREFERENCE_KEYS[1],null) if profile != null else _large_targets
	var high_contrast: Variant = profile.get_preference(PREFERENCE_KEYS[2], false) if profile != null else _high_contrast
	var colour_preset: Variant = profile.get_preference(PREFERENCE_KEYS[3], "standard") if profile != null else _colour_preset
	if typeof(locale) != TYPE_STRING or locale.replace("-","_") not in ["en","zh_CN","zh_HK", "ja", "ko"] or typeof(percent) != TYPE_INT or percent not in [100,125,150] or typeof(large) != TYPE_BOOL \
		or typeof(high_contrast) != TYPE_BOOL or typeof(colour_preset) != TYPE_STRING or colour_preset not in ["standard","protan","deutan","tritan"]:
		return {"ok":false,"code":"invalid_shop_preferences"}
	return {"ok":true,"value":[locale.replace("-","_"),percent,large,high_contrast,colour_preset]}

func _on_catalog_changed() -> void:
	_source_pending = true
	refresh_view()

func _on_locale_changed(_locale_id: String) -> void:
	refresh_view(false,true)

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if str(path) in PREFERENCE_KEYS: refresh_view(false,true)

func prepare_show_window() -> Dictionary:
	# Validate the current public source before the desktop publishes its route.
	# Hidden measurement may rebuild this app, but never shared Home custody.
	if _provider == null: return {"ok":last_result.ok,"code":last_result.code}
	return refresh_view(false,true,true)

func refresh_view(on_open: bool = false, _presentation_only: bool = false, prepare_hidden: bool = false) -> Dictionary:
	_refresh_pending = true
	if is_node_ready() and not _view_is_current(): return {"ok":false,"code":"shop_view_detached"}
	if not is_instance_valid(_provider): return {"ok":false,"code":"shop_catalog_unconfigured"}
	var preferences := _read_preferences(_localization,_profile)
	if not preferences.ok: return preferences
	if _refreshing or (is_node_ready() and not prepare_hidden and (not _has_host_custody() or (not on_open and _other_control_has_focus()))):
		return {"ok":true,"code":"deferred"}
	# Colour-only changes use the retained projection. Catalog refresh on show or after
	# a purchase still reaches the owner, even when ordinary rows would look identical.
	if _presentation_only and not on_open and not prepare_hidden and not _source_pending \
		and last_result.ok and preferences.value.slice(0, 3) == [_locale,_percent,_large_targets]:
		var unchanged: bool = preferences.value.slice(3) == [_high_contrast,_colour_preset]
		_high_contrast = preferences.value[3]
		_colour_preset = preferences.value[4]
		_roles = SHOP_THEME.resolve(_palette, _day, _high_contrast, _colour_preset)
		if is_node_ready() and not unchanged: _apply_colours()
		_refresh_pending = false
		return {"ok":true,"code":"unchanged" if unchanged else "ok"}
	_refreshing = true
	var snapshot: Variant = _provider.get_catalog(preferences.value[0])
	_refreshing = false
	if is_node_ready() and not _view_is_current(): return {"ok":false,"code":"shop_view_detached"}
	if typeof(snapshot) != TYPE_DICTIONARY or typeof(snapshot.get("ok")) != TYPE_BOOL or not snapshot.ok or typeof(snapshot.get("value")) != TYPE_ARRAY:
		_refresh_pending = false
		return _catalog_failure("shop_catalog_unavailable")
	var rows: Array = snapshot.value
	var projected := PROJECTION.project(rows)
	if not projected.ok:
		_refresh_pending = false
		return _catalog_failure(str(projected.code))
	var changed: bool = rows != _catalog_rows
	var source_changed: bool = (changed and _source_pending) or (not _catalog_rows.is_empty() and _catalog_facts(projected.value) != _catalog_facts(_records))
	if not changed and last_result.ok and preferences.value.slice(0, 3) == [_locale,_percent,_large_targets]:
		var colours_changed: bool = preferences.value.slice(3) != [_high_contrast,_colour_preset]
		_high_contrast = preferences.value[3]
		_colour_preset = preferences.value[4]
		_roles = SHOP_THEME.resolve(_palette, _day, _high_contrast, _colour_preset)
		if is_node_ready() and colours_changed: _apply_colours()
		# Eligibility changes after rounds/day transitions even when all ordinary rows are identical.
		if is_node_ready():
			_refresh_supportz()
			_wire_focus()
		_refresh_pending = false
		_source_pending = false
		return {"ok":true,"code":"unchanged"}
	var prior_quantity := quantity
	var prior_item_quantities := _item_quantities.duplicate()
	if is_node_ready():
		_remember_focus()
		var focused := get_viewport().gui_get_focus_owner()
		if on_open or (focused != null and is_ancestor_of(focused)):
			_host_anchor = {"focus":_remembered_focus,"scroll":info_scroll.scroll_vertical}
	var result := configure_shop(rows,preferences.value[0],preferences.value[1],preferences.value[2],_palette,
		_day,preferences.value[3],preferences.value[4])
	_focus_after_layout = false
	if result.ok:
		_catalog_rows = rows.duplicate(true)
		if not source_changed:
			_item_quantities = prior_item_quantities
			var maximum: int = _records[_index_of(selected_id)].legal_max
			quantity = prior_quantity if prior_quantity <= maxi(1,maximum) else 1
	else: _host_anchor.clear()
	_refresh_pending = false
	_source_pending = false
	return result

func _catalog_facts(records: Array) -> Array:
	var facts: Array = []
	for record: Dictionary in records:
		var fact := record.duplicate()
		for key: String in ["name","description","card_art","inspector_art"]: fact.erase(key)
		facts.append(fact)
	return facts

func _catalog_failure(code: String) -> Dictionary:
	last_result = {"ok":false,"code":code}
	_records = []
	_host_anchor.clear()
	if is_node_ready():
		var focused := get_viewport().gui_get_focus_owner()
		_focus_after_layout = focused != null and is_ancestor_of(focused)
		_rebuild_catalog()
	return last_result.duplicate()

func configure_desktop_home(home: Button) -> void:
	configure_host(home)

func _has_host_custody(require_visible: bool = true) -> bool:
	if is_instance_valid(_supportz_confirmation): return false
	if not _view_is_current(): return false
	if (require_visible and not is_visible_in_tree()) or not can_process(): return false
	var current: Control = self
	while current != null:
		if current.focus_behavior_recursive != Control.FOCUS_BEHAVIOR_INHERITED:
			return current.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_ENABLED
		current = current.get_parent_control()
	return true

func _other_control_has_focus() -> bool:
	if not _view_is_current(): return true
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and focused.is_visible_in_tree() and focused != _home and not is_ancestor_of(focused)

func can_return_home() -> bool:
	if not _has_host_custody(false): return false
	for card in cards.values():
		if card._held or card.is_pressed(): return false
	for button in quantity_buttons.values() + [previous_button,next_button,_buy_button,_supportz_button]:
		if is_instance_valid(button) and button.is_pressed(): return false
	return true

func _remember_focus() -> void:
	if not _view_is_current(): return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == info_scroll: _remembered_focus = "information"
	elif focused == previous_button: _remembered_focus = "previous"
	elif focused == next_button: _remembered_focus = "next"
	else:
		for key in quantity_buttons:
			if focused == quantity_buttons[key]: _remembered_focus = "quantity:"+key
		for id in cards:
			if focused == cards[id]: _remembered_focus = "card:"+id

func _restore_host_view(revision: int) -> void:
	if revision != _measurement_revision or _host_anchor.is_empty(): return
	var anchor := _host_anchor
	_host_anchor = {}
	if not _has_host_custody(): return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused.is_visible_in_tree() and not is_ancestor_of(focused) and focused != _home: return
	var target: Control = null
	var key: String = anchor.focus
	if key.begins_with("card:"): target = cards.get(key.substr(5))
	elif key.begins_with("quantity:"): target = quantity_buttons.get(key.substr(9))
	elif key == "information": target = info_scroll
	elif key == "previous": target = previous_button
	elif key == "next": target = next_button
	if not is_instance_valid(target) or not target.is_visible_in_tree() or target.get_focus_mode_with_override() != Control.FOCUS_ALL:
		target = cards.get(selected_id)
	if is_instance_valid(target) and target.get_focus_mode_with_override() == Control.FOCUS_ALL: target.grab_focus()
	info_scroll.scroll_vertical = clampi(int(anchor.scroll),0,maxi(0,int(_document.size.y-info_scroll.size.y)))

func configure_shop(items: Array, locale: String = "en", percent: int = 100, large_targets: bool = false, palette: StringName = &"after_hours", day: int = 1, high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary:
	if is_node_ready() and not _view_is_current(): return {"ok":false,"code":"shop_view_detached"}
	# Refuse an unknown presentation before disturbing a valid mounted snapshot.
	var candidate_roles: Dictionary = SHOP_THEME.resolve(palette, day, high_contrast, colour_preset)
	if candidate_roles.is_empty():
		return {"ok": false, "code": "invalid_shop_palette"}
	var normalized_locale := locale.replace("-","_")
	if normalized_locale not in ["en","zh_CN","zh_HK", "ja", "ko"] or percent not in [100,125,150]:
		return {"ok":false,"code":"invalid_shop_presentation"}
	var projected := PROJECTION.project(items)
	if not projected.ok: return {"ok":false,"code":projected.code}
	if is_node_ready():
		var focused := get_viewport().gui_get_focus_owner()
		_focus_after_layout = focused != null and is_ancestor_of(focused)
	_cancel_contacts()
	# A new owner snapshot cannot retain a quantity against an expired maximum.
	quantity = 1
	_item_quantities.clear()
	_locale = locale.replace("-", "_")
	_percent = percent
	_large_targets = large_targets
	_large = large_targets or percent > 100
	_palette = palette
	_day = day
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_roles = candidate_roles
	# No hidden action is admitted before its real purchase owner is bound.
	last_result = projected
	_records = last_result.get("value", [])
	if is_node_ready(): _rebuild_catalog()
	return {"ok": last_result.ok, "code": last_result.code}

func configure_host(home: Button) -> void:
	_home = home
	if is_node_ready(): _wire_focus()

func _ready() -> void:
	super._ready()
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	custom_minimum_size = Vector2(800, 656)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	$VBoxContainer/TopBar.hide()
	$VBoxContainer.add_theme_constant_override("separation", 0)
	_content_host.custom_minimum_size = Vector2(800, 656)
	_body = Control.new()
	_body.name = "ShopPlate"
	_body.size = Vector2(800, 656)
	_content_host.add_child(_body)
	_body.draw.connect(_draw_plate)
	_catalog = Control.new()
	_catalog.name = "Catalog"
	_catalog.position = Vector2(16, 16)
	_catalog.size = Vector2(448, 544)
	_body.add_child(_catalog)
	previous_button = _button("previous", Vector2(16, 576), Vector2(144, 64), func(): _change_page(-1))
	page_label = _label(_body, Vector2(168, 576), Vector2(144, 64), false)
	page_label.set_meta("shop_color_role", &"secondary_dark_copy")
	page_label.add_theme_color_override("font_color", _role("secondary_dark_copy"))
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_button = _button("next", Vector2(320, 576), Vector2(144, 64), func(): _change_page(1))
	info_scroll = ScrollContainer.new()
	info_scroll.name = "InformationViewport"
	info_scroll.position = Vector2(480, 16)
	info_scroll.size = Vector2(304, 384)
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	info_scroll.gui_input.connect(_information_input)
	_body.add_child(info_scroll)
	_document = Control.new()
	_document.name = "InformationDocument"
	_document.custom_minimum_size = Vector2(304, 384)
	info_scroll.add_child(_document)
	_document.draw.connect(func():
		_document.draw_rect(Rect2(88, 16, 128, 128), _role("paper"))
		_document.draw_rect(Rect2(88, 16, 128, 128), _role("structure"), false, 2))
	_art = TextureRect.new()
	_art.position = Vector2(96, 24)
	_art.size = Vector2(112, 112)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_document.add_child(_art)
	_name_label = _label(_document, Vector2(16, 160), Vector2(272, 0))
	_description_label = _label(_document, Vector2(16, 200), Vector2(272, 0))
	_description_label.set_meta("shop_color_role", &"secondary_ink")
	_description_label.add_theme_color_override("font_color", _role("secondary_ink"))
	_information_overlay = Control.new()
	_information_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_information_overlay.draw.connect(_draw_information)
	_body.add_child(_information_overlay)
	info_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _information_overlay.queue_redraw())
	info_scroll.focus_entered.connect(_information_overlay.queue_redraw)
	info_scroll.focus_exited.connect(_information_overlay.queue_redraw)
	_meta_price = _label(_body, Vector2(496, 400), Vector2(136, 48))
	_meta_state = _label(_body, Vector2(632, 400), Vector2(136, 48))
	_meta_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_label = _label(_body, Vector2(608, 456), Vector2(48, 48), false)
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for key in ["minimum", "minus", "plus", "maximum"]:
		quantity_buttons[key] = _button(key, Vector2.ZERO, Vector2(48, 48), _quantity_action.bind(key))
	_total_label = _label(_body, Vector2(496, 512), Vector2(272, 64), false)
	status_label = _label(_body, Vector2(496, 576), Vector2(136, 64), false)
	_buy_button = _button("buy", Vector2(640, 576), Vector2(128, 64), _purchase_selected)
	_supportz_button = Button.new()
	_supportz_button.name = "SecretSupportz"
	_supportz_button.flat = true
	_supportz_button.text = ""
	_supportz_button.accessibility_name = _supportz_accessible_name()
	_supportz_button.pressed.connect(_purchase_supportz)
	_supportz_button.gui_input.connect(_card_input.bind("supportz"))
	_supportz_button.draw.connect(_draw_supportz_contact)
	for event: Signal in [_supportz_button.mouse_entered, _supportz_button.mouse_exited,
			_supportz_button.focus_entered, _supportz_button.focus_exited,
			_supportz_button.button_down, _supportz_button.button_up]:
		event.connect(_supportz_button.queue_redraw)
	_catalog.add_child(_supportz_button)
	_rebuild_catalog()
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _cancel_contacts())
	_connect_focus_observer()

func _apply_colours() -> void:
	theme = SHOP_THEME.build(_locale, _percent, _palette, _day, _high_contrast, _colour_preset)
	for card: Button in cards.values():
		card.apply_palette(_palette, _day, _high_contrast, _colour_preset)
	for found: Node in find_children("*", "Label", true, false):
		var label := found as Label
		if label != null and label.has_meta("shop_color_role"):
			label.add_theme_color_override("font_color", _role(StringName(label.get_meta("shop_color_role"))))
	for control: Control in [_body, _document, _information_overlay, _supportz_button, previous_button,
			next_button, _buy_button] + quantity_buttons.values():
		if is_instance_valid(control): control.queue_redraw()

func _rebuild_catalog() -> void:
	_measurement_revision += 1
	_catalog_layout_pending = true
	_cancel_contacts()
	for child in _catalog.get_children():
		if child == _supportz_button: continue
		_catalog.remove_child(child)
		child.queue_free()
	cards.clear()
	_apply_colours()
	previous_button.text = _t("previous")
	next_button.text = _t("next")
	_buy_button.text = _t("buy")
	_buy_button.accessibility_name = _t("buy")
	_supportz_button.accessibility_name = _supportz_accessible_name()
	_supportz_button.hide()
	info_scroll.accessibility_name = _t("information")
	for key in quantity_buttons:
		quantity_buttons[key].text = {"minus": "−", "plus": "+"}.get(key, _t(key))
		quantity_buttons[key].accessibility_name = _t(key)
	if not last_result.ok:
		_show_recovery()
		return
	for record: Dictionary in _records:
		if record.blank: continue
		var card: Button = CARD.instantiate()
		card.apply_palette(_palette, _day, _high_contrast, _colour_preset)
		card.configure(record, _price(record.unit_price, record.currency), _t("available" if record.available else "sold_out"))
		card.pressed.connect(_select_item.bind(record.id))
		card.inspection_requested.connect(_inspect_item.bind(record.id))
		card.gui_input.connect(_card_input.bind(record.id))
		_catalog.add_child(card)
		cards[record.id] = card
		card.hide()
	_measure_catalog.call_deferred(_measurement_revision)

func _measure_catalog(revision: int) -> void:
	if not _view_is_current(): return
	if revision != _measurement_revision or not last_result.ok: return
	for card in cards.values():
		card.refresh_layout()
	page_capacity = 9
	page_count = 2
	page_index = int(_index_of(selected_id) / page_capacity) if cards.has(selected_id) else 0
	for card in cards.values(): card.size = Vector2(144, 176)
	_show_page(_focus_after_layout)
	_catalog_layout_pending = false
	if not _host_anchor.is_empty(): _restore_host_view.call_deferred(revision)

func _show_page(focus_selection: bool = true) -> void:
	_cancel_contacts()
	for control in [previous_button, next_button, page_label, _total_label]: control.show()
	for card in cards.values(): card.hide()
	_supportz_button.hide()
	var start := page_index * page_capacity
	var end := mini(start + page_capacity, _records.size())
	for index in range(start, end):
		var record: Dictionary = _records[index]
		var slot := index - start
		if record.blank:
			_refresh_supportz()
			continue
		var card: Button = cards[record.id]
		card.position = Vector2((slot % 3) * 152, (slot / 3) * (card.size.y + 8))
		card.show()
	if not cards.has(selected_id) or not cards[selected_id].visible:
		selected_id = str(_page_selection.get(page_index, ""))
		if not cards.has(selected_id) or not cards[selected_id].visible:
			for index in range(start, end):
				if not _records[index].blank:
					selected_id = _records[index].id
					break
		quantity = _item_quantity(selected_id)
	_page_selection[page_index] = selected_id
	previous_button.disabled = page_index == 0
	next_button.disabled = page_index == page_count - 1
	previous_button.focus_mode = Control.FOCUS_NONE if previous_button.disabled else Control.FOCUS_ALL
	next_button.focus_mode = Control.FOCUS_NONE if next_button.disabled else Control.FOCUS_ALL
	page_label.text = "%d / %d" % [page_index + 1, page_count]
	_render_selection()
	_body.queue_redraw()
	if focus_selection: _focus_selected.call_deferred()

func _inspect_item(item_id: String) -> void:
	# Hover/focus must not retarget an action whose press is already in progress.
	if not can_return_home(): return
	_select_item(item_id)

func _item_quantity(item_id: String) -> int:
	var record: Dictionary = _records[_index_of(item_id)]
	return clampi(int(_item_quantities.get(item_id, 1)), 1, maxi(1, record.legal_max))

func _select_item(item_id: String) -> void:
	if not _has_host_custody(): return
	if not cards.has(item_id) or not cards[item_id].is_visible_in_tree(): return
	if selected_id == item_id: return
	_cancel_contacts()
	quantity = _item_quantity(item_id)
	info_scroll.scroll_vertical = 0
	selected_id = item_id
	_page_selection[page_index] = item_id
	_render_selection()

func _render_selection() -> void:
	var record: Dictionary = _records[_index_of(selected_id)]
	for item_id in cards: cards[item_id].selected = item_id == selected_id
	info_scroll.show()
	_information_overlay.show()
	_meta_price.show()
	_meta_state.show()
	_art.texture = record.inspector_art
	_name_label.text = record.name
	_description_label.text = record.get("description", "")
	_meta_price.text = _price(record.unit_price, record.currency)
	_meta_state.text = _t("available" if record.available else "sold_out")
	var meta_y := 336 if _large else 400
	info_scroll.size.y = meta_y - 16
	_meta_price.position.y = meta_y
	_meta_state.position.y = meta_y
	_information_overlay.position = info_scroll.position
	_information_overlay.size = info_scroll.size
	var positions := {"minimum": Vector2(496, 456), "minus": Vector2(552, 456), "plus": Vector2(664, 456), "maximum": Vector2(720, 456)}
	if _large:
		positions = {"minimum": Vector2(492, 384), "minus": Vector2(564, 384), "plus": Vector2(708, 384), "maximum": Vector2(708, 448)}
	for key in quantity_buttons:
		var button: Button = quantity_buttons[key]
		button.position = positions[key]
		button.size = Vector2(64, 64) if _large else Vector2(48, 48)
		button.visible = record.batchable and record.available
		button.disabled = record.legal_max == 0 or (quantity == 1 if key in ["minimum", "minus"] else quantity >= record.legal_max)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	_quantity_label.position = Vector2(636, 384) if _large else Vector2(608, 456)
	_quantity_label.size = Vector2(64, 64) if _large else Vector2(48, 48)
	_quantity_label.visible = record.batchable and record.available
	_quantity_label.text = str(quantity)
	_total_label.text = _price(record.unit_price * quantity, record.currency)
	_buy_button.accessibility_name = "%s: %s × %d" % [_t("buy"), record.name, quantity]
	_buy_button.tooltip_text = _buy_button.accessibility_name
	status_label.position = Vector2(496, 576)
	status_label.size = Vector2(136, 64)
	var has_purchase := _provider != null and _provider.has_method("purchase")
	_buy_button.visible = has_purchase
	_buy_button.disabled = true
	_buy_button.focus_mode = Control.FOCUS_NONE
	status_label.text = ""
	if has_purchase:
		var admitted := _provider_can_purchase(selected_id, quantity)
		_buy_button.disabled = not admitted.get("ok", false)
		_buy_button.focus_mode = Control.FOCUS_NONE if _buy_button.disabled else Control.FOCUS_ALL
		if _buy_button.disabled: status_label.text = _t("unavailable")
	elif record.available:
		status_label.text = _t("unavailable")
	_measure_information.call_deferred()
	_verify_dock_fit.call_deferred()
	_wire_focus()

func _verify_dock_fit() -> void:
	if not _view_is_current(): return
	if not last_result.ok: return
	# Do not truncate exact amounts or invent a lower owner maximum to fit a key.
	for label: Label in [_quantity_label, _total_label, _meta_price, _meta_state]:
		if not label.visible: continue
		var measure := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
		if measure.x > label.size.x or measure.y > label.size.y:
			last_result = {"ok": false, "code": "shop_dock_does_not_fit"}
			_show_recovery()
			return

func _measure_information() -> void:
	if not _view_is_current(): return
	if not last_result.ok: return
	_name_label.size = Vector2(272, 0)
	_name_label.size.y = ceilf(_name_label.get_minimum_size().y / 2) * 2
	_description_label.position.y = _name_label.position.y + _name_label.size.y + 8
	_description_label.size = Vector2(272, 0)
	_description_label.size.y = ceilf(_description_label.get_minimum_size().y / 2) * 2
	var bottom := _name_label.position.y + _name_label.size.y
	if not _description_label.text.is_empty(): bottom = _description_label.position.y + _description_label.size.y
	_document.custom_minimum_size = Vector2(304, maxf(info_scroll.size.y, bottom + 16))
	_document.size = _document.custom_minimum_size
	var overflow := _document.size.y > info_scroll.size.y
	info_scroll.focus_mode = Control.FOCUS_ALL if overflow else Control.FOCUS_NONE
	info_scroll.scroll_vertical = clampi(info_scroll.scroll_vertical, 0, int(_document.size.y - info_scroll.size.y))
	_information_overlay.queue_redraw()
	_wire_focus()

func _quantity_action(key: String) -> void:
	if not _has_host_custody() or not last_result.ok: return
	var record: Dictionary = _records[_index_of(selected_id)]
	if not record.available or not record.batchable or record.legal_max <= 0: return
	match key:
		"minimum": quantity = 1
		"minus": quantity = maxi(1, quantity - 1)
		"plus": quantity = mini(record.legal_max, quantity + 1)
		"maximum": quantity = record.legal_max
	_item_quantities[selected_id] = quantity
	_render_selection()
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or (focused is BaseButton and focused.disabled):
		_focus_first_action()

func _provider_can_purchase(item_id: String, requested_quantity: int) -> Dictionary:
	if _provider == null or not _provider.has_method("can_purchase"):
		return {"ok": _provider != null and _provider.has_method("purchase"), "code": &"ok"}
	var result: Variant = _provider.call(&"can_purchase", item_id, requested_quantity)
	return (result as Dictionary).duplicate(true) if typeof(result) == TYPE_DICTIONARY \
		else {"ok": false, "code": &"shop_purchase_result_malformed"}

func _purchase_selected() -> void:
	if not _has_host_custody() or not is_instance_valid(_buy_button) or _buy_button.disabled:
		return
	_dispatch_purchase(selected_id, quantity)

func _refresh_supportz() -> void:
	if not is_instance_valid(_supportz_button): return
	var admitted: bool = page_index == 0 and _provider != null and _provider.has_method("purchase") \
		and _provider_can_purchase("supportz", 1).get("ok", false)
	var card_height: float = 176.0 if cards.is_empty() else (cards.values()[0] as Control).size.y
	_supportz_button.position = Vector2(304, 2 * (card_height + 8))
	_supportz_button.size = Vector2(144, card_height)
	_supportz_button.disabled = not admitted
	_supportz_button.focus_mode = Control.FOCUS_ALL if admitted else Control.FOCUS_NONE
	_supportz_button.mouse_filter = Control.MOUSE_FILTER_STOP if admitted else Control.MOUSE_FILTER_IGNORE
	_supportz_button.accessibility_name = _supportz_accessible_name() if admitted else ""
	_supportz_button.visible = admitted
	_supportz_button.queue_redraw()

func _draw_supportz_contact() -> void:
	if _supportz_button.disabled or not _has_host_custody(): return
	var height := _supportz_button.size.y
	if _supportz_button.is_pressed():
		_supportz_button.draw_rect(Rect2(138, 4, 2, height - 8), _role("structure"))
	elif _supportz_button.is_hovered():
		_supportz_button.draw_rect(Rect2(4, 4, 2, height - 8), _role("structure"))
	if _supportz_button.has_focus():
		_supportz_button.draw_rect(Rect2(-7, -7, 158, height + 14), _role("dark_focus_outer"), false, 2)
		_supportz_button.draw_rect(Rect2(-3, -3, 150, height + 6), _role("dark_focus_inner"), false, 2)

func _purchase_supportz() -> void:
	if not _has_host_custody() or not is_instance_valid(_supportz_button): return
	_refresh_supportz()
	if _supportz_button.disabled: return
	_cancel_contacts()
	_supportz_confirmation = SUPPORTZ_CONFIRMATION.new()
	_supportz_confirmation.name = "ShopConfirmation"
	_supportz_confirmation.theme = CONFIRMATION_THEME.build(_locale, _percent, _palette, _day, _high_contrast, _colour_preset)
	_supportz_confirmation.request = {"title": _price(45, "money"), "body": "", "warning": false,
		"cancel": _t("no"), "confirm": _t("yes"), "risk": "neutral", "dialog_name": _t("confirmation")}
	_supportz_confirmation.attempt_purchase = _attempt_supportz_purchase
	_supportz_confirmation.failure_text = _t("unavailable")
	_supportz_confirmation.retry_text = _t("retry_purchase")
	_supportz_confirmation.finished.connect(_finish_supportz_confirmation)
	add_child(_supportz_confirmation)
	_supportz_button.queue_redraw()

func _attempt_supportz_purchase() -> Dictionary:
	if not _view_is_current() or not is_visible_in_tree():
		return {"ok": false, "code": &"shop_view_detached"}
	# The owner revalidates on Yes and can resume its retained transaction after a save failure.
	# A fresh can_purchase query would reject that retry while its mutation lease is retained.
	var result: Variant = _provider.call(&"purchase", "supportz", 1)
	var outcome: Dictionary = result.duplicate(true) if result is Dictionary \
		else {"ok": false, "code": &"shop_purchase_result_malformed"}
	outcome["retained_purchase"] = _provider.has_method("has_pending_purchase") \
		and bool(_provider.call(&"has_pending_purchase"))
	return outcome

func _finish_supportz_confirmation(_accepted: bool) -> void:
	_supportz_confirmation = null
	if not _view_is_current(): return
	refresh_view(true, true)
	_restore_supportz_focus.call_deferred()

func _restore_supportz_focus() -> void:
	if not _has_host_custody(): return
	_refresh_supportz()
	_wire_focus()
	var target: Control = _supportz_button if _supportz_button.visible else cards.get("spa_coupon")
	if is_instance_valid(target) and target.is_visible_in_tree(): target.grab_focus()

func _dispatch_purchase(item_id: String, requested_quantity: int) -> void:
	if _provider == null or not _provider.has_method("purchase"):
		return
	var result: Variant = _provider.call(&"purchase", item_id, requested_quantity)
	_purchase_result = (result as Dictionary).duplicate(true) if typeof(result) == TYPE_DICTIONARY \
		else {"ok": false, "code": &"shop_purchase_result_malformed"}
	if _purchase_result.get("ok", false):
		quantity = 1
		_item_quantities.erase(item_id)
		status_label.text = ""
		refresh_view(true, true)
	else:
		status_label.text = _t("unavailable")
	_render_selection()

func _supportz_accessible_name() -> String:
	return _t("blank_card")


func _change_page(delta: int) -> void:
	if not _has_host_custody(): return
	var target := page_index + delta
	if not last_result.ok or target < 0 or target >= page_count: return
	page_index = target
	info_scroll.scroll_vertical = 0
	_show_page()

func _card_input(event: InputEvent, item_id: String) -> void:
	if not _has_host_custody(): return
	var index := _index_of(item_id)
	var slot := index % page_capacity
	var target := -1
	if event.is_action_pressed("ui_left"):
		if slot % 3 > 0: target = index - 1
	elif event.is_action_pressed("ui_right"):
		if slot % 3 < 2: target = index + 1
		else: _focus_first_action()
	elif event.is_action_pressed("ui_up"):
		if slot >= 3: target = index - 3
	elif event.is_action_pressed("ui_down"):
		if slot + 3 < page_capacity: target = index + 3
		else:
			if slot % 3 == 2 and not next_button.disabled: next_button.grab_focus()
			elif not previous_button.disabled: previous_button.grab_focus()
			elif not next_button.disabled: next_button.grab_focus()
	else: return
	if target >= page_index * page_capacity and target < mini((page_index + 1) * page_capacity, _records.size()) and target >= 0:
		if not _records[target].blank: cards[_records[target].id].grab_focus()
		elif _supportz_button.visible and not _supportz_button.disabled: _supportz_button.grab_focus()
	get_viewport().set_input_as_handled()

func _information_input(event: InputEvent) -> void:
	var line := int(ceil(theme.default_font.get_height(theme.default_font_size) / 2)) * 2
	var offset := info_scroll.scroll_vertical
	if event.is_action_pressed("ui_left"):
		_focus_selected()
	elif event.is_action_pressed("ui_up"): offset -= line
	elif event.is_action_pressed("ui_down"): offset += line
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_HOME: offset = 0
			KEY_END: offset = int(_document.size.y)
			KEY_PAGEUP: offset -= int(info_scroll.size.y) - line
			KEY_PAGEDOWN: offset += int(info_scroll.size.y) - line
			_: return
	else: return
	info_scroll.scroll_vertical = clampi(offset, 0, int(_document.size.y - info_scroll.size.y))
	info_scroll.accept_event()

func _wire_focus() -> void:
	if not _view_is_current(): return
	if not is_instance_valid(_body): return
	var chain: Array[Control] = []
	if is_instance_valid(_home) and _has_host_custody(): chain.append(_home)
	for record: Dictionary in _records:
		if record.blank and record.id == "supportz" and _supportz_button.visible and not _supportz_button.disabled:
			chain.append(_supportz_button)
		elif not record.blank and cards.has(record.id) and cards[record.id].visible:
			chain.append(cards[record.id])
	if info_scroll.visible and info_scroll.focus_mode == Control.FOCUS_ALL: chain.append(info_scroll)
	for key in ["minimum", "minus", "plus", "maximum"]:
		var button: Button = quantity_buttons[key]
		if button.visible and not button.disabled: chain.append(button)
	if _buy_button.visible and not _buy_button.disabled: chain.append(_buy_button)
	for button: Button in [previous_button, next_button]:
		if button.visible and not button.disabled: chain.append(button)
	for index in chain.size():
		var control := chain[index]
		control.focus_previous = control.get_path_to(chain[maxi(0, index - 1)])
		control.focus_next = control.get_path_to(chain[mini(chain.size() - 1, index + 1)])
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: control.set_focus_neighbor(side, control.get_path())

func _focus_first_action() -> void:
	if not _has_host_custody(): return
	for key in ["minimum", "minus", "plus", "maximum"]:
		var button: Button = quantity_buttons[key]
		if button.visible and not button.disabled:
			button.grab_focus()
			return

func _focus_selected() -> void:
	if _has_host_custody() and cards.has(selected_id) and cards[selected_id].visible and cards[selected_id].get_focus_mode_with_override() == Control.FOCUS_ALL: cards[selected_id].grab_focus()

func _cancel_contacts() -> void:
	for card in cards.values(): card.cancel_contact()
	for button in quantity_buttons.values() + [previous_button, next_button, _buy_button, _supportz_button]:
		if not is_instance_valid(button): continue
		var was_disabled: bool = button.disabled
		button.disabled = true
		button.disabled = was_disabled

func _show_recovery() -> void:
	_catalog_layout_pending = false
	for card in cards.values(): card.hide()
	for control in [info_scroll, _information_overlay, _meta_price, _meta_state, previous_button, next_button, page_label, _quantity_label, _total_label, _buy_button, _supportz_button] + quantity_buttons.values(): control.hide()
	status_label.position = Vector2(32, 32)
	status_label.size = Vector2(736, 576)
	status_label.text = _t("unavailable")
	_body.queue_redraw()
	_wire_focus()
	if _focus_after_layout and _has_host_custody() and is_instance_valid(_home): _home.grab_focus()
	recovery_requested.emit(str(last_result.code))

func show_window() -> void:
	show()
	if _provider != null: refresh_view(true,true)
	_wire_focus()
	if not last_result.ok and is_instance_valid(_home) and _has_host_custody(): _home.grab_focus()
	elif _host_anchor.is_empty():
		if _provider != null:
			_host_anchor = {"focus":_remembered_focus,"scroll":info_scroll.scroll_vertical}
			_restore_host_view.call_deferred(_measurement_revision)
		else: _focus_selected.call_deferred()

func hide_window() -> void:
	_remember_focus()
	_cancel_contacts()
	super.hide_window()

func _index_of(item_id: String) -> int:
	for index in _records.size():
		if _records[index].id == item_id: return index
	return 0

func _t(key: String) -> String:
	return COPY.text(_locale if _locale in ["en", "zh_CN", "zh_HK", "ja", "ko"] else "en", key)

func _price(amount: int, currency: String) -> String:
	return COPY.price(_locale, amount, currency)

func _label(parent: Control, at: Vector2, measure: Vector2, on_paper: bool = true) -> Label:
	var label := Label.new()
	label.position = at
	label.size = measure
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("line_spacing", 0)
	var color_role: StringName = &"primary_ink" if on_paper else &"primary_dark_copy"
	label.set_meta("shop_color_role", color_role)
	label.add_theme_color_override("font_color", _role(color_role))
	parent.add_child(label)
	return label

func _button(key: String, at: Vector2, measure: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.name = key.to_pascal_case()
	button.position = at
	button.size = measure
	button.pressed.connect(action)
	button.gui_input.connect(func(event: InputEvent):
		if key in quantity_buttons and event.is_action_pressed("ui_left"):
			_focus_selected()
			button.accept_event())
	button.draw.connect(func():
		if button.has_focus():
			button.draw_rect(Rect2(2, 2, button.size.x - 4, button.size.y - 4), _role("dark_focus_outer"), false, 2)
			button.draw_rect(Rect2(6, 6, button.size.x - 12, button.size.y - 12), _role("dark_focus_inner"), false, 2))
	button.focus_entered.connect(button.queue_redraw)
	button.focus_exited.connect(button.queue_redraw)
	_body.add_child(button)
	return button

func _draw_plate() -> void:
	_body.draw_rect(Rect2(0, 0, 800, 656), _role("habitat"))
	if not last_result.ok: return
	_body.draw_rect(Rect2(16, 16, 768, 624), _role("controlled_face"))
	_body.draw_rect(Rect2(480, 16, 304, 368 if _large else 432), _role("laminate"))
	var blank_index := 8 - page_index * page_capacity
	if blank_index >= 0 and blank_index < page_capacity and not cards.is_empty():
		var height: float = cards.values()[0].size.y
		var at := Vector2(16 + (blank_index % 3) * 152, 16 + (blank_index / 3) * (height + 8))
		_body.draw_rect(Rect2(at, Vector2(144, height)), _role("controlled_face"))
		_body.draw_rect(Rect2(at + Vector2(4, 4), Vector2(136, height - 8)), _role("laminate"))

func _draw_information() -> void:
	if not last_result.ok: return
	var height := int(info_scroll.size.y / 2)
	var document_height := int(_document.size.y / 2)
	if document_height <= height: return
	var thumb := maxi(8, int(floor(float(height * height) / document_height)))
	var at := int(floor(float((height - thumb) * int(info_scroll.scroll_vertical / 2)) / (document_height - height)))
	_information_overlay.draw_rect(Rect2(302, 0, 2, height * 2), _role("scroll_track"))
	_information_overlay.draw_rect(Rect2(302, at * 2, 2, thumb * 2), _role("scroll_thumb"))
	if info_scroll.has_focus():
		_information_overlay.draw_rect(Rect2(2, 2, 300, height * 2 - 4), _role("laminate_focus_outer"), false, 2)
		_information_overlay.draw_rect(Rect2(6, 6, 292, height * 2 - 12), _role("laminate_focus_inner"), false, 2)

func _role(name: StringName) -> Color:
	return _roles[name]
