extends "res://addons/gut/test.gd"

const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const FIXTURE := preload("res://tests/unit/test_shop_catalog_projection.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")


class Provider extends RefCounted:
	signal catalog_changed
	var rows: Array = []
	var purchases: Array[Dictionary] = []
	var supportz_eligible := true
	var reject_purchase := false
	var on_purchase: Callable

	func get_catalog(locale: String) -> Dictionary:
		var result: Array = rows.duplicate(true)
		for row: Dictionary in result:
			row["name"] = COPY.item_name(locale, str(row["id"]))
		return {"ok": true, "code": &"ok", "value": result}

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
	shop.quantity_buttons.maximum.pressed.emit()
	assert_eq(shop.quantity, 4)
	assert_not_null(shop.get("_buy_button"))
	shop.get("_buy_button").pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "coffee", "quantity": 4}])
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
	assert_eq(supportz.position, Vector2(304, 368), "page one lower-right slot")
	assert_eq(supportz.text, "", "eligibility never adds a visible secret name")
	assert_eq(supportz.accessibility_name, "Blank shop card")
	assert_eq(shop.page_count, 2)
	assert_eq(shop.selected_id, "coffee")
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
	assert_eq(shop.cards.coffee.get_focus_mode_with_override(), Control.FOCUS_NONE)
	assert_eq(get_viewport().gui_get_focus_owner(), sheet.cancel_button)
	sheet.confirm_button.pressed.emit()
	sheet.confirm_button.pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "supportz", "quantity": 1}])
	assert_false(supportz.visible)
	assert_eq(shop.selected_id, "spa_coupon", "Returning focus also restores the ordinary inspector")
	assert_eq(get_viewport().gui_get_focus_owner(), shop.cards.spa_coupon)

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
	assert_eq(get_viewport().gui_get_focus_owner(), shop.cards.spa_coupon)

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
	shop.cards.spa_coupon.grab_focus()
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	shop._card_input(right, "spa_coupon")
	assert_eq(get_viewport().gui_get_focus_owner(), shop.get("_supportz_button"))
	var up := InputEventAction.new()
	up.action = &"ui_up"
	up.pressed = true
	shop._card_input(up, "supportz")
	assert_eq(get_viewport().gui_get_focus_owner(), shop.cards.soft_blanket)

func test_supportz_is_absent_on_page_two() -> void:
	var shop := await _shop(Provider.new())
	shop.next_button.pressed.emit()
	await _settle()
	assert_eq(shop.page_index, 1)
	assert_false(shop.get("_supportz_button").visible)
	assert_eq(shop.page_count, 2)


func test_focus_and_pointer_inspect_without_purchase_and_preserve_each_item_quantity() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	provider.rows[0].description = "A sealed vending cup."
	provider.rows[1].description = "A bottle from the campus shop."
	provider.catalog_changed.emit()
	await _settle()
	shop.quantity_buttons.maximum.pressed.emit()
	assert_eq(shop.quantity, 4)
	shop.cards.wine.grab_focus()
	assert_eq(shop.selected_id, "wine", "No Enter press is needed")
	assert_eq(shop.get("_name_label").text, "Wine")
	assert_eq(shop.get("_description_label").text, provider.rows[1].description)
	assert_eq(shop.quantity, 1, "A different item does not inherit another item's batch")
	assert_true(shop.cards.wine.selected)
	shop.cards.coffee.get_node("PointerSurface").mouse_entered.emit()
	assert_eq(shop.selected_id, "coffee", "The child pointer surface owns native hover")
	assert_eq(shop.quantity, 4, "Returning from a preview restores the edited quantity")
	assert_eq(shop.get("_name_label").text, "Coffee")
	assert_eq(shop.get("_description_label").text, provider.rows[0].description)
	assert_true(shop.cards.coffee.selected)
	assert_false(shop.cards.wine.selected)
	assert_true(provider.purchases.is_empty(), "Inspection never dispatches a purchase")
	assert_eq(shop.get("_buy_button").accessibility_name, "Buy: Coffee × 4")
	shop.get("_buy_button").pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "coffee", "quantity": 4}])
	shop.cards.wine.grab_focus()
	shop.cards.coffee.grab_focus()
	assert_eq(shop.quantity, 1, "A successful purchase retires that item's old batch draft")


func test_inspection_does_not_retarget_a_held_buy_action() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	var buy: Button = shop.get("_buy_button")
	buy.toggle_mode = true
	buy.set_pressed_no_signal(true)
	assert_true(buy.is_pressed())
	shop.cards.wine.get_node("PointerSurface").mouse_entered.emit()
	assert_eq(shop.selected_id, "coffee")
	assert_eq(shop.get("_name_label").text, "Coffee")
	assert_true(provider.purchases.is_empty())
	buy.set_pressed_no_signal(false)
	buy.toggle_mode = false
	shop.cards.wine.get_node("PointerSurface").mouse_entered.emit()
	assert_eq(shop.selected_id, "wine")


func test_changed_catalog_retires_all_saved_item_quantities() -> void:
	var provider := Provider.new()
	var shop := await _shop(provider)
	shop.quantity_buttons.maximum.pressed.emit()
	shop.cards.wine.grab_focus()
	shop.quantity_buttons.maximum.pressed.emit()
	provider.rows[0].legal_max = 2
	provider.catalog_changed.emit()
	await _settle()
	assert_eq(shop.quantity, 1)
	shop.cards.coffee.grab_focus()
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
