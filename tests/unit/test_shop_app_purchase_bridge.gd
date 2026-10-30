extends "res://addons/gut/test.gd"

const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const FIXTURE := preload("res://tests/unit/test_shop_catalog_projection.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")


class Provider extends RefCounted:
	signal catalog_changed
	var rows: Array = []
	var balances: Dictionary = {}
	var purchases: Array[Dictionary] = []
	var supportz_eligible := true
	var reject_purchase := false
	var on_purchase: Callable

	func get_catalog(locale: String) -> Dictionary:
		var result: Array = rows.duplicate(true)
		for row: Dictionary in result:
			row["name"] = COPY.item_name(locale, str(row["id"]))
		return {"ok": true, "code": &"ok", "value": result, "balances": balances.duplicate()}

	func can_purchase(item_id: String, _quantity: int = 1) -> Dictionary:
		var eligible := item_id != "supportz" or supportz_eligible
		return {"ok": eligible, "code": &"ok" if eligible else &"supportz_not_eligible", "value": {"eligible": eligible}}

	func purchase(item_id: String, quantity: int) -> Dictionary:
		var admitted := can_purchase(item_id, quantity)
		if not admitted.ok: return admitted
		if reject_purchase: return {"ok": false, "code": &"insufficient_funds"}
		purchases.append({"item_id": item_id, "quantity": quantity})
		if item_id == "supportz": supportz_eligible = false
		catalog_changed.emit()
		if on_purchase.is_valid(): on_purchase.call()
		return {"ok": true, "code": &"ok", "value": {"item_id": item_id, "quantity": quantity}}


class RetryProvider extends Provider:
	var pending := false
	func has_pending_purchase() -> bool: return pending
	func can_purchase(item_id: String, quantity: int = 1) -> Dictionary:
		if pending: return {"ok": false, "code": &"TRANSACTION_ACTIVE"}
		return super.can_purchase(item_id, quantity)
	func purchase(item_id: String, quantity: int) -> Dictionary:
		if not pending:
			pending = true
			return {"ok": false, "code": &"save_write_failed"}
		pending = false
		return super.purchase(item_id, quantity)


func test_buy_control_dispatches_selected_quantity_and_refreshes_the_catalog() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	assert_false(shop.quantity_buttons.maximum.visible)
	assert_eq(shop.quantity, 1)
	assert_not_null(shop.get("_buy_button"))
	shop.get("_buy_button").pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "crystal_stutters", "quantity": 1}])
	assert_eq(shop.quantity, 1, "the provider publication resets quantity against the new owner snapshot")


func test_supportz_rechecks_eligibility_when_ordinary_catalog_does_not_change() -> void:
	var provider := Provider.new()
	provider.supportz_eligible = false
	var shop := await _shop(provider)
	var supportz: Button = shop.get("_supportz_button")
	assert_false(supportz.visible)
	assert_eq(supportz.focus_mode, Control.FOCUS_NONE)
	assert_eq(supportz.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(supportz.accessibility_name, "")
	provider.supportz_eligible = true
	assert_eq(shop.refresh_view(true).code, "unchanged")
	assert_true(supportz.visible, "completing both base rounds must unlock the unchanged blank slot")
	assert_false(supportz.disabled)
	assert_eq(supportz.position, Vector2(304, 368), "page one lower-right slot follows the retained catalogue")
	assert_eq(supportz.text, "", "eligibility never adds a visible secret name")
	assert_eq(supportz.accessibility_name, "Blank shop card")
	assert_eq(shop.page_count, 1)
	assert_eq(shop.selected_id, "crystal_stutters")
	provider.supportz_eligible = false
	shop.refresh_view(true)
	assert_false(supportz.visible, "day/branch exhaustion must also refresh without changing ordinary rows")
	assert_eq(supportz.focus_mode, Control.FOCUS_NONE)

func test_supportz_activation_asks_price_only_and_yes_purchases_once() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	var supportz: Button = shop.get("_supportz_button")
	supportz.grab_focus()
	supportz.pressed.emit()
	var sheet: Control = shop.get("_supportz_confirmation")
	assert_not_null(sheet)
	assert_true(provider.purchases.is_empty(), "activation alone must never spend money")
	assert_eq(sheet.get("_price_body").text, "$45")
	assert_false(sheet.request.warning)
	assert_false(shop.can_return_home(), "the sheet owns Home custody")
	assert_eq(shop.cards.crystal_stutters.get_focus_mode_with_override(), Control.FOCUS_NONE)
	assert_eq(get_viewport().gui_get_focus_owner(), sheet.cancel_button)
	sheet.confirm_button.pressed.emit()
	sheet.confirm_button.pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "supportz", "quantity": 1}])
	assert_false(supportz.visible)
	assert_eq(shop.selected_id, "debug_key", "Returning focus also restores the ordinary inspector")
	assert_eq(get_viewport().gui_get_focus_owner(), shop.cards.debug_key)

func test_supportz_purchase_departure_does_not_touch_a_retired_viewport() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	var destination := Button.new()
	add_child_autofree(destination)
	provider.on_purchase = func():
		shop.get_parent().remove_child(shop)
		destination.grab_focus()
	shop.get("_supportz_button").pressed.emit()
	shop.get("_supportz_confirmation").confirm_button.pressed.emit()
	assert_false(shop.is_inside_tree())
	assert_eq(provider.purchases, [{"item_id": "supportz", "quantity": 1}])
	assert_eq(get_viewport().gui_get_focus_owner(), destination)
	await _settle()
	assert_eq(get_viewport().gui_get_focus_owner(), destination)

func test_supportz_no_restores_the_blank_slot_without_purchase() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	shop.get("_supportz_button").pressed.emit()
	shop.get("_supportz_confirmation").cancel_button.pressed.emit()
	await _settle()
	assert_true(provider.purchases.is_empty())
	assert_eq(get_viewport().gui_get_focus_owner(), shop.get("_supportz_button"))

func test_supportz_yes_revalidates_and_keeps_refusal_inside_the_sheet() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	shop.get("_supportz_button").pressed.emit()
	var sheet: Control = shop.get("_supportz_confirmation")
	provider.supportz_eligible = false
	sheet.confirm_button.pressed.emit()
	assert_true(provider.purchases.is_empty())
	assert_true(sheet.visible)
	assert_false(sheet.cancel_button.disabled, "ordinary refusal remains cancelable without retained custody")
	assert_eq(sheet.get("_price_body").text, "$45\n\nUnavailable")
	sheet.cancel_button.pressed.emit()
	await _settle()
	assert_eq(get_viewport().gui_get_focus_owner(), shop.cards.debug_key)

func test_supportz_failed_transaction_never_closes_the_sheet_as_success() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	shop.get("_supportz_button").pressed.emit()
	var sheet: Control = shop.get("_supportz_confirmation")
	provider.reject_purchase = true
	sheet.confirm_button.pressed.emit()
	assert_true(provider.purchases.is_empty())
	assert_true(sheet.visible)
	assert_false(sheet.cancel_button.disabled, "ordinary refusal remains cancelable without retained custody")
	assert_eq(sheet.get("_price_body").text, "$45\n\nUnavailable")
	sheet.cancel_button.pressed.emit()
	await _settle()

func test_supportz_failed_save_can_retry_through_the_retained_owner() -> void:
	var provider := RetryProvider.new()
	var shop := await _shop(provider)
	shop.get("_supportz_button").pressed.emit()
	var sheet: Control = shop.get("_supportz_confirmation")
	sheet.confirm_button.pressed.emit()
	assert_true(provider.pending)
	assert_true(sheet.visible)
	assert_eq(sheet.get("_price_body").text, "$45\n\nUnable to finish saving. Try again.")
	assert_true(sheet.cancel_button.disabled)
	sheet.cancel_button.pressed.emit()
	assert_true(sheet.visible, "No cannot abandon a retained purchase")
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	sheet._input(back)
	assert_true(sheet.visible, "Back cannot abandon a retained purchase")
	assert_eq(get_viewport().gui_get_focus_owner(), sheet.confirm_button)
	assert_false(provider.can_purchase("supportz").ok, "ordinary admission is blocked while the transaction is retained")
	sheet.confirm_button.pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "supportz", "quantity": 1}])
	assert_false(provider.pending)

func test_supportz_directional_focus_reaches_blank_slot_and_returns_to_grid() -> void:
	var shop := await _shop(Provider.new())
	shop.cards.bookend_keepsake.grab_focus()
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	shop._card_input(down, "bookend_keepsake")
	assert_eq(get_viewport().gui_get_focus_owner(), shop.get("_supportz_button"))
	var up := InputEventAction.new()
	up.action = &"ui_up"
	up.pressed = true
	shop._card_input(up, "supportz")
	assert_eq(get_viewport().gui_get_focus_owner(), shop.cards.bookend_keepsake)

func test_supportz_stays_on_the_only_page() -> void:
	var shop := await _shop(Provider.new())
	shop.next_button.pressed.emit()
	await _settle()
	assert_eq(shop.page_index, 0)
	assert_true(shop.get("_supportz_button").visible)
	assert_eq(shop.page_count, 1)


func test_focus_and_pointer_inspect_without_purchase_and_preserve_each_item_quantity() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	provider.rows[0].description = "A crystal ornament from the campus shop."
	provider.rows[1].description = "An inked silk string from the campus shop."
	provider.catalog_changed.emit()
	await _settle()
	assert_false(shop.quantity_buttons.maximum.visible)
	assert_eq(shop.quantity, 1)
	shop.cards.inked_silk_string.grab_focus()
	assert_eq(shop.selected_id, "inked_silk_string", "No Enter press is needed")
	assert_eq(shop.get("_name_label").text, "inked silk string")
	assert_eq(shop.get("_description_label").text, provider.rows[1].description)
	assert_eq(shop.quantity, 1, "A different item does not inherit another item's batch")
	assert_true(shop.cards.inked_silk_string.selected)
	shop.cards.crystal_stutters.get_node("PointerSurface").mouse_entered.emit()
	assert_eq(shop.selected_id, "crystal_stutters", "The child pointer surface owns native hover")
	assert_eq(shop.quantity, 1, "Returning from a preview restores the edited quantity")
	assert_eq(shop.get("_name_label").text, "crystal stutters")
	assert_eq(shop.get("_description_label").text, provider.rows[0].description)
	assert_true(shop.cards.crystal_stutters.selected)
	assert_false(shop.cards.inked_silk_string.selected)
	assert_true(provider.purchases.is_empty(), "Inspection never dispatches a purchase")
	assert_eq(shop.get("_buy_button").accessibility_name, "Buy: crystal stutters × 1")
	shop.get("_buy_button").pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "crystal_stutters", "quantity": 1}])
	shop.cards.inked_silk_string.grab_focus()
	shop.cards.crystal_stutters.grab_focus()
	assert_eq(shop.quantity, 1, "A successful purchase retires that item's old batch draft")


func test_inspection_does_not_retarget_a_held_buy_action() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	var buy: Button = shop.get("_buy_button")
	buy.toggle_mode = true
	buy.set_pressed_no_signal(true)
	assert_true(buy.is_pressed())
	shop.cards.inked_silk_string.get_node("PointerSurface").mouse_entered.emit()
	assert_eq(shop.selected_id, "crystal_stutters")
	assert_eq(shop.get("_name_label").text, "crystal stutters")
	assert_true(provider.purchases.is_empty())
	buy.set_pressed_no_signal(false)
	buy.toggle_mode = false
	shop.cards.inked_silk_string.get_node("PointerSurface").mouse_entered.emit()
	assert_eq(shop.selected_id, "inked_silk_string")


func test_changed_catalog_retires_all_saved_item_quantities() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	assert_false(shop.quantity_buttons.maximum.visible)
	shop.cards.inked_silk_string.grab_focus()
	assert_false(shop.quantity_buttons.maximum.visible)
	provider.rows[0].legal_max = 0
	provider.catalog_changed.emit()
	await _settle()
	assert_eq(shop.quantity, 1)
	shop.cards.crystal_stutters.grab_focus()
	assert_eq(shop.quantity, 1, "A changed owner snapshot invalidates every old maximum")

func _shop(provider: Provider) -> Control:
	var fixture := FIXTURE.new()
	provider.rows = fixture._valid_rows()
	fixture.free()
	var shop: Control = SHOP.instantiate()
	assert_true(shop.configure_catalog(provider).get("ok", false))
	add_child_autofree(shop)
	await _settle()
	return shop


func _settle() -> void:
	for frame: int in 5:
		await get_tree().process_frame


func test_balances_refresh_even_when_catalog_rows_do_not_change() -> void:
	var provider := Provider.new()
	provider.balances = {"money": 120, "coins": 7}
	var shop := await _shop(provider)
	assert_eq(shop._balance_label.text, "$120    7 coins")
	provider.balances = {"money": 75, "coins": 3}
	assert_true(shop.refresh_view(true).ok)
	assert_eq(shop._balance_label.text, "$75    3 coins")
	assert_eq(shop._catalog.position.y, 16.0)
	assert_eq(shop._balance_label.position.x, shop.info_scroll.position.x + 16)
	assert_eq(shop._balance_label.size.x, 272.0)
	assert_lte(shop._balance_label.get_rect().end.x, shop.info_scroll.get_rect().end.x)
	assert_lte(shop._balance_label.get_rect().end.y, shop.info_scroll.position.y)

func test_complete_card_names_and_balances_fit_every_font_and_locale() -> void:
	var provider := Provider.new()
	provider.balances = {"money": 120, "coins": 7}
	var shop := await _shop(provider)
	for style: String in ["pixel", "readable"]:
		for locale: String in ["en", "zh-HK", "zh-CN", "ja", "ko"]:
			for percent: int in [100, 125, 150]:
				assert_true(shop.configure_shop(provider.get_catalog(locale).value, locale, percent, false, &"after_hours", 1, false, "standard", style).ok)
				await _settle()
				for card: Control in shop.cards.values():
					assert_eq(card._art_rect.size, Vector2(56, 56), locale + str(percent) + style)
					for label: Label in [card.name_label, card.price_label, card.availability_label]:
						assert_true(card.get_global_rect().encloses(label.get_global_rect()), locale + str(percent) + label.text)
						var measured := label.get_theme_font("font").get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
							label.size.x, label.get_theme_font_size("font_size"), -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
						assert_lte(measured.y, label.size.y, label.text)
					if card.visible: assert_true(shop._catalog.get_global_rect().encloses(card.get_global_rect()))
				assert_true(shop.last_result.ok)
				assert_eq(shop._balance_label.get_line_count(), 1)
				assert_eq(shop._catalog.position.y, 16.0)
				assert_eq(shop._balance_label.position.x, shop.info_scroll.position.x + 16)
				assert_eq(shop._balance_label.size.x, 272.0)
				assert_lte(shop._balance_label.get_rect().end.y, shop.info_scroll.position.y)
				assert_lte(shop._balance_label.get_rect().end.x, shop.info_scroll.get_rect().end.x)
				assert_eq(shop.page_count, 1)
				assert_eq(shop.page_capacity, 9)
				assert_false(shop.previous_button.visible)
				assert_false(shop.next_button.visible)
				assert_false(shop.page_label.visible)
				for card: Control in shop.cards.values(): assert_true(card.visible)
				while shop.page_index < shop.page_count - 1: shop._change_page(1)
				assert_true(shop._supportz_button.visible)
				assert_true(shop._catalog.get_global_rect().encloses(shop._supportz_button.get_global_rect()))
