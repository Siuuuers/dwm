extends RefCounted
## Real app scenes and inherited production implementations over labeled injected services.
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

# Backup uses A's real presentation port and the real shared confirmation sheet.
# The inspection/storage owner below is injected. No disk or restore proof is implied.
# Run on A's composition retaining the accepted a991b525 family contract, not C alone.
const BACKUP_PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")

class BackupSpy extends "res://scripts/ui/BackupApp.gd":
	var calendar_calls := 0
	func configure_backup(port: Object, localization: Object = null, profile: Object = null, palette: StringName = &"after_hours", day: int = 1) -> Dictionary:
		calendar_calls += 1
		return super.configure_backup(port, localization, profile, palette, day)
	func configure_run_presentation(palette: StringName, day: int) -> Dictionary:
		calendar_calls += 1
		return super.configure_run_presentation(palette, day)

class BackupOwner extends RefCounted:
	var rows: Dictionary = {}
	var save_enabled := true
	var prepared: Array[Dictionary] = []
	var committed: Array[String] = []
	var cancelled: Array[String] = []
	var pending: Dictionary = {}
	var commit_result := {"ok": true}
	func inspect_backup(locator: String) -> Dictionary:
		return {"ok": true, "value": rows[locator].duplicate(true)}
	func get_backup_save_capability() -> Dictionary:
		return {"enabled": save_enabled, "reason": ""}
	func prepare_backup_action(action: String, locator: String) -> Dictionary:
		var token := "fixture-backup-%d" % (prepared.size() + 1)
		prepared.append({"action": action, "locator": locator, "token": token})
		pending[token] = true
		return {"ok": true, "value": {"token": token, "record": rows[locator].duplicate(true)}}
	func commit_backup_action(token: String) -> Dictionary:
		if not pending.has(token): return {"ok": false, "code": &"fixture_stale_token"}
		pending.erase(token)
		committed.append(token)
		return commit_result.duplicate(true)
	func cancel_backup_action(token: String) -> void:
		cancelled.append(token)
		pending.erase(token)

class BackupPortProbe extends "res://scripts/application/backup/BackupPresentationPort.gd":
	var reads := 0
	var projection_override: Dictionary = {}
	var prepared_patch: Dictionary = {}
	func get_projection() -> Dictionary:
		reads += 1
		return super.get_projection() if projection_override.is_empty() else projection_override.duplicate(true)
	func prepare_action(action: String, locator: String) -> Dictionary:
		var result := super.prepare_action(action, locator)
		if result.get("ok", false) and not prepared_patch.is_empty():
			result.value.record.merge(prepared_patch, true)
		return result

class BackupHost extends Control:
	const SHEET := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
	func present_confirmation(request: Dictionary, accepted: Callable, cancelled: Callable) -> Dictionary:
		var sheet := SHEET.new()
		sheet.request = request.duplicate(true)
		sheet.theme = request.theme
		sheet.finished.connect(func(confirmed: bool) -> void:
			if confirmed: accepted.call()
			else: cancelled.call())
		add_child(sheet)
		return {"ok": true, "value": {"confirmation": sheet}}

static func backup_owner() -> RefCounted:
	var owner := BackupOwner.new()
	for locator: String in BACKUP_PORT.LOCATORS:
		owner.rows[locator] = {"locator": locator, "state": "empty", "family": null,
			"day": null, "saved_time": null, "fallback": false, "load_family": null,
			"load_day": null, "load_saved_time": null, "reason": "",
			"revision": "fixture-revision", "operation_allowed": true, "loadable": false}
	owner.rows.autosave.merge({"state": "occupied", "family": "scene", "saved_time": "09:10",
		"load_family": "scene", "load_saved_time": "09:10", "loadable": true}, true)
	owner.rows.quick.merge({"state": "occupied", "family": "legacy_day", "day": 2,
		"saved_time": "11:05", "load_family": "legacy_day", "load_day": 2,
		"load_saved_time": "11:05", "loadable": true}, true)
	owner.rows["slot:1"].merge({"state": "occupied", "family": "scene", "saved_time": "13:57",
		"fallback": true, "load_family": "scene", "loadable": true}, true)
	owner.rows["slot:2"].merge({"state": "occupied", "family": "legacy_day", "day": 6,
		"saved_time": "14:30", "fallback": true, "load_family": "legacy_day",
		"load_day": 3, "loadable": true}, true)
	owner.rows["slot:3"].merge({"state": "unavailable", "family": "scene", "reason": "restore_unavailable"}, true)
	owner.rows["slot:4"].merge({"state": "unavailable", "reason": "unreadable"}, true)
	# Deliberately old injected metadata: the real port must project null families.
	# Neither the view's mode nor these unclassified days may supply a family.
	owner.rows["slot:5"].merge({"state": "occupied", "day": 77, "saved_time": "12:34", "load_day": 88}, true)
	owner.rows["slot:5"].erase("family")
	owner.rows["slot:5"].erase("load_family")
	owner.rows["slot:7"].merge({"state": "unavailable", "family": "legacy_day", "reason": "no_compatible_checkpoint"}, true)
	return owner
