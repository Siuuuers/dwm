extends RefCounted
## Real app scenes and inherited production implementations; only ports are fixtures.
## Spies count public calendar entry calls, without replacing rendering or reflow.
const MINES := preload("res://tests/unit/test_minesweeper_app.gd")
const CONTACTS := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const SHOP := preload("res://tests/integration/test_shop_desktop_host.gd")
const SHOP_ROWS := preload("res://tests/unit/test_shop_catalog_projection.gd")

class ContactSpy extends "res://scripts/ui/ContactListApp.gd":
	var calendar_calls := 0
	func configure_presentation(port: Object, localization: Object = null, profile: Object = null, palette: StringName = &"after_hours", day: int = 1) -> Dictionary:
		calendar_calls += 1
		return super.configure_presentation(port, localization, profile, palette, day)

class MinesSpy extends "res://scripts/ui/MinesweeperApp.gd":
	var calendar_calls := 0
	func configure_presentation(port: Object, localization: Object = null, profile: Object = null, input_owner: Object = null, palette: StringName = &"after_hours", day: int = 1) -> Dictionary:
		calendar_calls += 1
		return super.configure_presentation(port, localization, profile, input_owner, palette, day)

class ShopSpy extends "res://scripts/ui/ShopApp.gd":
	var calendar_calls := 0
	func configure_catalog(provider: Object, localization: Object = null, profile: Object = null, palette: StringName = &"after_hours", day: int = 1) -> Dictionary:
		calendar_calls += 1
		return super.configure_catalog(provider, localization, profile, palette, day)

static func board_port(app: Control) -> RefCounted:
	var source := MINES.new()
	var port := MINES.PublicPort.new()
	port.view = source._view()
	port.live_view = port.view.duplicate(true)
	port.app = app
	source.free()
	return port

static func catalog_port() -> RefCounted:
	var source := SHOP_ROWS.new()
	var port := SHOP.CatalogProvider.new()
	port.rows = source._valid_rows()
	source.free()
	return port
