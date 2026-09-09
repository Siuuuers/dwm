extends "res://tests/unit/test_shop_catalog_projection.gd"

const CARD := preload("res://scenes/shared/ShopItemBox.tscn")
const FONTS := preload("res://scripts/ui/desktop/DesktopTheme.gd")

# Native pointer input belongs to this test viewport, not the runner's overlay.
var _card_viewport: SubViewport

func before_each() -> void:
	_card_viewport = SubViewport.new()
	_card_viewport.size = Vector2i(512,512)
	_card_viewport.handle_input_locally = true
	_card_viewport.gui_disable_input = false
	add_child_autofree(_card_viewport)

func _card(record: Dictionary, font_size: int = 20) -> Button:
	var card := CARD.instantiate()
	var card_theme := Theme.new()
	card_theme.default_font = FONTS.ENGLISH
	card_theme.default_font_size = font_size
	card.theme = card_theme
	var price := "$%d" % record.unit_price if record.currency == "money" else "%d coin%s" % [record.unit_price, "" if record.unit_price == 1 else "s"]
	card.configure(record, price, "Available" if record.available else "Sold out")
	_card_viewport.add_child(card)
	return card

func _settle() -> void:
	for frame in 3: await get_tree().process_frame

func _mouse(point: Vector2, held: bool, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = held
	event.double_click = double_click
	_card_viewport.push_input(event,true)
	await _settle()

func test_card_has_only_public_copy_and_no_purchase_or_hidden_controls() -> void:
	var row: Dictionary = CATALOG_PROJECTION.project(_valid_rows()).value[0]
	var card := _card(row)
	await _settle()
	assert_eq(card.name_label.text, "Coffee")
	assert_eq(card.price_label.text, "$20")
	assert_eq(card.availability_label.text, "Available")
	assert_eq(card.accessibility_name, "Coffee, $20, Available")
	assert_eq(card.get_child_count(), 4, "Three public labels plus nonfocusable pointer surface.")
	for child in card.get_children():
		assert_false(child is BaseButton, "No nested Buy/quantity/secret target.")
		assert_eq(child.focus_mode, Control.FOCUS_NONE)

func test_unconfigured_card_is_not_a_phantom_blank_target() -> void:
	var card := CARD.instantiate()
	_card_viewport.add_child(card)
	await _settle()
	assert_false(card.visible)
	assert_eq(card.focus_mode, Control.FOCUS_NONE)
	assert_eq(card.accessibility_name, "")

func test_fixed_card_bands_keep_name_price_and_availability_inside_two_page_geometry() -> void:
	var rows: Array = CATALOG_PROJECTION.project(_valid_rows()).value
	for font_size in [20, 25, 30]:
		for row: Dictionary in rows:
			if row.blank: continue
			var card := _card(row, font_size)
			await _settle()
			assert_eq(card.size.y, 176.0)
			var previous_bottom: float = card.get("_art_rect").end.y + 4.0
			for label: Label in [card.name_label, card.price_label, card.availability_label]:
				assert_gte(label.position.y, previous_bottom)
				assert_lte(label.position.y + label.size.y, card.size.y - 8)
				assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
				assert_true(label.clip_text)
				previous_bottom = label.position.y + label.size.y
			card.hide()

func test_pointer_release_selects_once_and_cancels_after_leave_or_hide() -> void:
	var card := _card(CATALOG_PROJECTION.project(_valid_rows()).value[0])
	await _settle()
	var activations: Array = []
	card.pressed.connect(func(): activations.append(true))
	var point := card.get_global_rect().get_center()
	await _mouse(point, true)
	assert_eq(activations.size(), 0)
	await _mouse(point, false)
	assert_eq(activations.size(), 1)
	await _mouse(point, true, true)
	await _mouse(point, false)
	assert_eq(activations.size(), 1)
	await _mouse(point, true)
	card.hide()
	card.show()
	await _mouse(point, false)
	assert_eq(activations.size(), 1)
	await _mouse(point, true)
	card.get_node("PointerSurface").mouse_exited.emit()
	await _mouse(point, false)
	assert_eq(activations.size(), 1, "Leaving cancels contact even after re-entry.")
	await _mouse(point, true)
	var changed: Dictionary = CATALOG_PROJECTION.project(_valid_rows()).value[1]
	card.configure(changed, "$55", "Available")
	await _mouse(point, false)
	assert_eq(activations.size(), 1, "A new projection cannot inherit a held activation.")
	await _mouse(point, true)
	card.set_admitted(false)
	assert_false(card.get("_held"))
	card.set_admitted(true)
	await _mouse(point, false)
	assert_eq(activations.size(), 1, "Re-admission needs a fresh press.")

func test_sold_out_stays_selectable_and_selection_does_not_follow_focus() -> void:
	var rows := _valid_rows()
	rows[0].available = false
	rows[0].legal_max = 0
	var card := _card(CATALOG_PROJECTION.project(rows).value[0])
	await _settle()
	assert_false(card.disabled)
	assert_eq(card.availability_label.text, "Sold out")
	card.grab_focus()
	assert_false(card.selected)
	card.selected = true
	assert_true(card.has_focus())

func test_native_keyboard_and_controller_activate_without_owning_selection() -> void:
	var card := _card(CATALOG_PROJECTION.project(_valid_rows()).value[0])
	await _settle()
	card.grab_focus()
	var activations: Array = []
	card.pressed.connect(func(): activations.append(true))
	for held in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = held
		_card_viewport.push_input(key, true)
		await _settle()
	assert_eq(activations.size(), 1)
	# This isolated lane has no production controller default yet. Supply a
	# declared UI accept binding for this component test, then restore InputMap.
	var mapping := InputEventJoypadButton.new()
	mapping.button_index = JOY_BUTTON_A
	var had_mapping := InputMap.action_has_event("ui_accept", mapping)
	if not had_mapping: InputMap.action_add_event("ui_accept", mapping)
	for held in [true, false]:
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_A
		button.pressed = held
		_card_viewport.push_input(button,true)
		await _settle()
	if not had_mapping: InputMap.action_erase_event("ui_accept", mapping)
	assert_eq(activations.size(), 2)
	assert_false(card.selected, "Shop owns selection after an admitted activation.")

func test_cjk_font_metrics_preserve_complete_public_labels_at_all_sizes() -> void:
	# Representative literal object-name fixtures, not a production translation catalog.
	for font: Font in [FONTS.SIMPLIFIED, FONTS.TRADITIONAL]:
		for font_size in [20, 25, 30]:
			var row: Dictionary = CATALOG_PROJECTION.project(_valid_rows()).value[17]
			row.name = "口袋計算器"
			var card := _card(row, font_size)
			card.theme.default_font = font
			card.configure(row, "3", "可用")
			card.refresh_layout()
			await _settle()
			assert_eq(card.name_label.text, row.name)
			var previous_bottom: float = card.get("_art_rect").end.y + 4.0
			for label: Label in [card.name_label, card.price_label, card.availability_label]:
				assert_gte(label.position.y, previous_bottom)
				assert_lte(label.position.y + label.size.y, card.size.y - 8)
				assert_true(label.clip_text)
				previous_bottom = label.position.y + label.size.y
			card.hide()
