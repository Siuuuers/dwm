extends "res://addons/gut/test.gd"

const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const FIXTURE := preload("res://tests/unit/test_shop_catalog_projection.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")


class Provider extends RefCounted:
	signal catalog_changed
	var rows: Array = []
	var purchases: Array[Dictionary] = []

	func get_catalog(locale: String) -> Dictionary:
		var result: Array = rows.duplicate(true)
		for row: Dictionary in result:
			row["name"] = COPY.item_name(locale, str(row["id"]))
		return {"ok": true, "code": &"ok", "value": result}

	func can_purchase(_item_id: String, _quantity: int = 1) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"eligible": true}}

	func purchase(item_id: String, quantity: int) -> Dictionary:
		purchases.append({"item_id": item_id, "quantity": quantity})
		catalog_changed.emit()
		return {"ok": true, "code": &"ok", "value": {"item_id": item_id, "quantity": quantity}}


func test_buy_control_dispatches_selected_quantity_and_refreshes_the_catalog() -> void:
	var provider := Provider.new()
	provider.rows = FIXTURE.new()._valid_rows()
	var shop: Control = SHOP.instantiate()
	assert_true(shop.configure_catalog(provider).get("ok", false))
	add_child_autofree(shop)
	await _settle()
	shop.quantity_buttons.maximum.pressed.emit()
	assert_eq(shop.quantity, 4)
	assert_not_null(shop.get("_buy_button"))
	shop.get("_buy_button").pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "coffee", "quantity": 4}])
	assert_eq(shop.quantity, 1, "the provider publication resets quantity against the new owner snapshot")


func test_structural_supportz_slot_is_a_real_accessible_purchase_target() -> void:
	var provider := Provider.new()
	provider.rows = FIXTURE.new()._valid_rows()
	var shop: Control = SHOP.instantiate()
	assert_true(shop.configure_catalog(provider).get("ok", false))
	add_child_autofree(shop)
	await _settle()
	while shop.page_index < int(8 / shop.page_capacity):
		shop.next_button.pressed.emit()
		await _settle()
	var supportz: Button = shop.get("_supportz_button")
	assert_not_null(supportz)
	assert_true(supportz.visible)
	assert_false(supportz.accessibility_name.is_empty())
	supportz.pressed.emit()
	await _settle()
	assert_eq(provider.purchases, [{"item_id": "supportz", "quantity": 1}])


func _settle() -> void:
	for frame: int in 5:
		await get_tree().process_frame
