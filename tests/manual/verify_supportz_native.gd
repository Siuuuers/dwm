extends SceneTree
## Synthetic shop-only visual/input probe. Run natively with isolated user paths.
const SHOP := preload("res://scenes/apps/ShopApp.tscn")
const FIXTURE := preload("res://tests/unit/test_shop_catalog_projection.gd")
class Provider extends RefCounted:
	signal catalog_changed
	var rows: Array = []
	var supportz_eligible := false
	var purchases: Array = []
	func get_catalog(_locale: String) -> Dictionary: return {"ok": true, "value": rows}
	func can_purchase(item_id: String, _quantity: int = 1) -> Dictionary:
		return {"ok": item_id != "supportz" or supportz_eligible}
	func purchase(item_id: String, quantity: int) -> Dictionary:
		purchases.append({"item_id": item_id, "quantity": quantity})
		supportz_eligible = false
		catalog_changed.emit()
		return {"ok": true}

var _failures: Array[String] = []
var _viewport: SubViewport

func _initialize() -> void: _run.call_deferred()

func _check(passed: bool, message: String) -> void:
	if not passed: _failures.append(message)

func _drawn() -> void:
	for frame in 4: await RenderingServer.frame_post_draw

func _capture(name: String) -> Image:
	await _drawn()
	var pixels := _viewport.get_texture().get_image()
	_check(pixels.save_png("res://.godot/phase2r_logs/supportz-" + name + ".png") == OK, "save native pixels")
	return pixels

func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var fixture := FIXTURE.new()
	var provider := Provider.new()
	provider.rows = fixture._valid_rows()
	fixture.free()
	provider.supportz_eligible = false
	var shop: Control = SHOP.instantiate()
	_check(shop.configure_catalog(provider).ok, "shop configured")
	_viewport.add_child(shop)
	await _drawn()
	shop.cards.coffee.grab_focus()
	var ineligible: Image = await _capture("ineligible")
	provider.supportz_eligible = true
	shop.refresh_view(true)
	shop.cards.coffee.grab_focus()
	var eligible: Image = await _capture("eligible-resting")
	var slot: Button = shop.get("_supportz_button")
	var crop := Rect2i(slot.get_global_rect())
	_check(ineligible.get_region(crop).get_data() == eligible.get_region(crop).get_data(), "eligibility has identical resting pixels")
	slot.grab_focus()
	var focused: Image = await _capture("eligible-focused")
	_check(focused.get_region(crop.grow(7)).get_data() != eligible.get_region(crop.grow(7)).get_data(), "focus has visible contact evidence")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = slot.get_global_rect().get_center()
	event.pressed = true
	_viewport.push_input(event, true)
	await _drawn()
	event = event.duplicate()
	event.pressed = false
	_viewport.push_input(event, true)
	await _drawn()
	var sheet: Control = shop.get("_supportz_confirmation")
	_check(is_instance_valid(sheet), "real pointer release opens price consent")
	_check(provider.purchases.is_empty(), "activation does not spend")
	if is_instance_valid(sheet):
		await _capture("confirmation")
		_check(sheet.get("_price_body").text == "$45", "only price in body")
		sheet.cancel_button.pressed.emit()
		await _drawn()
		_check(_viewport.gui_get_focus_owner() == slot, "No restores blank focus")
	_check(provider.purchases.is_empty(), "No does not spend")
	for failure in _failures: printerr("SUPPORTZ_NATIVE_FAILURE: ", failure)
	print("SUPPORTZ_NATIVE_RESULT: ", JSON.stringify({"ok": _failures.is_empty(), "failures": _failures}))
	_viewport.free()
	quit(0 if _failures.is_empty() else 1)
