extends GutTest

const BACKUP := preload("res://scenes/apps/BackupApp.tscn")
const LOCATORS := ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]


class Port extends RefCounted:
	var projections := 0
	func get_projection() -> Dictionary:
		projections += 1
		var records := []
		for locator: String in LOCATORS:
			records.append({"locator": locator, "state": "occupied", "day": 2,
				"saved_time": "09:00", "actions": {"save": true, "load": true, "delete": true}})
		return {"ok": true, "value": {"records": records}}
	func prepare_action(_action: String, _locator: String) -> Dictionary:
		return {"ok": false, "code": &"unused"}
	func commit_action(_token: Variant) -> Dictionary:
		return {"ok": false, "code": &"unused"}
	func cancel_action(_token: Variant) -> void:
		pass


var _viewport: SubViewport
var _host: Control
var _app: BackupApp
var _port: Port


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 656)
	add_child_autofree(_viewport)
	_host = Control.new()
	_host.size = Vector2(800, 656)
	_viewport.add_child(_host)
	_app = BACKUP.instantiate()
	_host.add_child(_app)
	_port = Port.new()
	assert_true(_app.configure_backup(_port).get("ok", false))
	await _settle()


func _settle() -> void:
	for frame: int in range(3):
		await get_tree().process_frame


func _assert_drawers_unchanged() -> void:
	assert_eq(_app.drawer_buttons.keys(), LOCATORS)
	for index: int in LOCATORS.size():
		var drawer: Control = _app.drawer_buttons[LOCATORS[index]]
		assert_eq(drawer.get_rect(), Rect2(14 + (index % 3) * 196,
			96 + (index / 3) * 184, 188, 176), LOCATORS[index])


func test_right_information_status_and_actions_use_added_width_without_moving_drawers() -> void:
	_assert_drawers_unchanged()
	assert_eq(_app.info_scroll.get_rect(), Rect2(610, 96, 176, 336))
	assert_eq(_app.status_region.get_rect(), Rect2(610, 432, 176, 96))
	assert_eq(_app.action_dock.get_rect(), Rect2(610, 528, 176, 112))
	assert_eq((_app.action_buttons.save as Control).get_rect(), Rect2(0, 24, 176, 64))
	_host.size = Vector2(960, 656)
	await _settle()
	assert_eq(_app.get_rect(), Rect2(0, 0, 960, 656))
	_assert_drawers_unchanged()
	assert_eq(_app._body.size, Vector2(960, 656))
	assert_eq(_app.info_scroll.get_rect(), Rect2(610, 96, 336, 336))
	assert_eq(_app._info_overlay.get_rect(), Rect2(610, 96, 336, 336))
	assert_eq(_app.status_region.get_rect(), Rect2(610, 432, 336, 96))
	assert_eq(_app.status_label.get_rect(), Rect2(12, 4, 312, 88))
	assert_eq(_app.action_dock.get_rect(), Rect2(610, 528, 336, 112))
	assert_eq((_app.action_buttons.save as Control).get_rect(), Rect2(0, 24, 336, 64))
	_app._set_mode("load")
	await _settle()
	assert_eq((_app.action_buttons.load as Control).get_rect(), Rect2(0, 24, 160, 64))
	assert_eq((_app.action_buttons.delete as Control).get_rect(), Rect2(176, 24, 160, 64))


func test_resize_preserves_selection_pending_token_focus_and_control_identity() -> void:
	_app._select_drawer("slot:2")
	var action: Button = _app.action_buttons.save
	action.grab_focus()
	_app._pending_token = "prepared-resize-token"
	var drawer_id := (_app.drawer_buttons["slot:2"] as Control).get_instance_id()
	var action_id := action.get_instance_id()
	var projections := _port.projections
	_host.size = Vector2(960, 656)
	await _settle()
	assert_eq(_app.get_rect(), Rect2(0, 0, 960, 656))
	assert_eq(_app.selected_locator, "slot:2")
	assert_eq(_app._pending_token, "prepared-resize-token")
	assert_true(action.has_focus())
	assert_eq((_app.drawer_buttons["slot:2"] as Control).get_instance_id(), drawer_id)
	assert_eq((_app.action_buttons.save as Control).get_instance_id(), action_id)
	assert_eq(_port.projections, projections, "presentation resize does not query or mutate the port")


func test_title_login_uses_available_host_width_and_centers_its_own_body() -> void:
	var title_host := Control.new()
	title_host.size = Vector2(960, 656)
	_viewport.add_child(title_host)
	var title: BackupApp = BACKUP.instantiate()
	title.configure_title_login()
	title.position = Vector2(80, 0)
	title_host.add_child(title)
	await _settle()
	assert_eq(title.position, Vector2(16, 0))
	assert_eq(title.size, Vector2(928, 656))
	assert_true(title_host.get_global_rect().encloses(title.get_global_rect()))
	assert_eq(title.anchor_right, 0.0)
