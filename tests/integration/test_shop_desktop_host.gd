extends GutTest
## Production Desktop and ShopApp over a strict public-catalog provider. Art uses generated
## dimension fixtures only; these tests make no asset provenance claim and expose no purchase API.

const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")

const ORDER := [
	"coffee","wine","pineapple_bun","bandage_pack","quiet_tea","soft_blanket",
	"weighted_plush","spa_coupon","supportz","healthy_meal","protein_box","pep_note",
	"premium_care","lucky_charm","debug_key","bookend_keepsake",
	"metronome_keepsake","pocket_calculator_keepsake",
]
const SPECS := {
	"coffee":[20,"money",true],"wine":[55,"money",true],
	"pineapple_bun":[10,"money",true],"bandage_pack":[15,"money",true],
	"quiet_tea":[15,"money",true],"soft_blanket":[25,"money",true],
	"weighted_plush":[35,"money",true],"spa_coupon":[45,"money",false],
	"healthy_meal":[25,"money",true],"protein_box":[35,"money",true],
	"pep_note":[10,"money",true],"premium_care":[1,"minesweeper_coin",true],
	"lucky_charm":[1,"minesweeper_coin",false],"debug_key":[3,"minesweeper_coin",false],
	"bookend_keepsake":[3,"minesweeper_coin",false],
	"metronome_keepsake":[3,"minesweeper_coin",false],
	"pocket_calculator_keepsake":[3,"minesweeper_coin",false],
}


class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	func _configure_from_bootstrap() -> void:
		pass


class ContactsPort extends RefCounted:
	func get_projection(_friend_id: String, _primary: String = "en", _secondary: String = "") -> Dictionary:
		return {"ok":true,"value":{"friends":[],"group":{},"unread":{}}}
	func open_friend(_friend_id: String) -> Dictionary:
		return {"ok":false,"code":&"fixture_command_unavailable"}
	func reply_to_group(_choice_id: String) -> Dictionary:
		return {"ok":false,"code":&"fixture_command_unavailable"}


class CatalogProvider extends RefCounted:
	signal catalog_changed
	var rows: Array = []
	var failure_code := ""
	var calls: Array[String] = []

	func get_catalog(locale: String) -> Dictionary:
		calls.append(locale)
		if not failure_code.is_empty():
			return {"ok":false,"code":StringName(failure_code),"value":[]}
		var value: Array = rows.duplicate(true)
		var copy_locale := locale.replace("-","_")
		for row: Dictionary in value:
			row.name = COPY.item_name(copy_locale,row.id)
		return {"ok":true,"code":&"ok","value":value}

class InvalidSignalProvider extends RefCounted:
	signal catalog_changed(_payload: Dictionary)
	func get_catalog(_locale: String) -> Dictionary:
		return {"ok":true,"code":&"ok","value":[]}


var _viewport: SubViewport
var _profile: Node
var _localization: Node
var _host: RefCounted
var _contacts: RefCounted
var _provider: CatalogProvider
var _accepted := 0
var _cancelled := 0


func before_each() -> void:
	_accepted = 0
	_cancelled = 0
	var files := FILES.new()
	_profile = PROFILE.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new("memory/shop-desktop/profile",files)).ok)
	_localization = LOCALIZATION.new()
	add_child_autofree(_localization)
	assert_true(_localization.initialize(_profile).ok)
	_host = HOST.new()
	_host.reset(3)
	_contacts = ContactsPort.new()
	_provider = CatalogProvider.new()
	_provider.rows = _valid_rows()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024,720)
	_viewport.handle_input_locally = true
	_viewport.gui_disable_input = false
	add_child_autofree(_viewport)


func _texture(width: int, height: int) -> ImageTexture:
	var image := Image.create(width,height,false,Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)


func _valid_rows() -> Array:
	var rows: Array = []
	var card_art := _texture(28,28)
	var inspector_art := _texture(56,56)
	for item_id: String in ORDER:
		if item_id == "supportz": continue
		var spec: Array = SPECS[item_id]
		rows.append({
			"id":item_id,"name":item_id.capitalize(),"description":"Public fixture description.",
			"unit_price":spec[0],"currency":spec[1],"available":true,
			"batchable":spec[2],"legal_max":4 if spec[2] else 1,
			"card_art":card_art,"inspector_art":inspector_art,
		})
	return rows


func _desktop_same_frame() -> Control:
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	_viewport.add_child(desktop)
	assert_true(desktop.configure_contacts(_contacts,_localization,_profile,_host,3).ok)
	return desktop


func _desktop_on_tree() -> Control:
	var desktop := _desktop_same_frame()
	# Most owner-event tests isolate their signal boundary after startup settles.
	await get_tree().process_frame
	return desktop


func _configure_shop(desktop: Control) -> Dictionary:
	return desktop.configure_shop(_provider,_localization,_profile,_host,3)


func _open_shop(desktop: Control) -> Control:
	desktop.launcher_buttons[&"shop"].pressed.emit()
	var app: Control = desktop._cached_app_windows.get(&"shop") as Control
	assert_not_null(app)
	if app != null:
		assert_true(app.is_visible_in_tree())
		assert_eq(desktop._active_id,&"shop")
		assert_eq(_host.get_state().active_app_id,&"shop")
		assert_false(desktop.icon_grid.visible)
	return app


func _settle() -> void:
	for frame in 5:
		await get_tree().process_frame


func _tap(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_viewport.push_input(event,true)
		await get_tree().process_frame


func _record(item_id: String) -> Dictionary:
	for row: Dictionary in _provider.rows:
		if row.id == item_id: return row
	return {}


func _ids(records: Array) -> Array:
	var result: Array = []
	for record: Dictionary in records:
		result.append(record.id)
	return result


func _accept_confirmation() -> void:
	_accepted += 1


func _cancel_confirmation() -> void:
	_cancelled += 1


func test_absent_provider_keeps_shop_unavailable_without_host_or_cache_mutation() -> void:
	var desktop := await _desktop_on_tree()
	await get_tree().process_frame
	var before: Dictionary = _host.get_state()
	assert_eq(desktop.open_app(&"shop"),{"ok":false,"code":&"shop_unavailable"})
	assert_eq(desktop._cached_app_windows,{})
	assert_eq(desktop.app_window_host.get_child_count(),0)
	assert_eq(_host.get_state(),before)
	assert_true(desktop.icon_grid.visible)
	assert_true(desktop.status_label.visible)


func test_invalid_owner_bundle_rejects_atomically_then_exact_owners_remain_immutable() -> void:
	var desktop := await _desktop_on_tree()
	var other_host := HOST.new()
	other_host.reset(3)
	assert_eq(desktop.configure_shop(RefCounted.new(),_localization,_profile,_host,3).code,
		&"invalid_shop_provider")
	assert_eq(desktop.configure_shop(InvalidSignalProvider.new(),_localization,_profile,_host,3).code,
		&"invalid_shop_provider","catalog_changed must be an exact zero-argument signal.")
	assert_eq(desktop.configure_shop(_provider,_localization,_profile,other_host,3).code,
		&"desktop_owner_mismatch")
	assert_eq(desktop.configure_shop(_provider,_localization,_profile,_host,4).code,
		&"desktop_owner_day_mismatch")
	assert_null(desktop._shop_port)
	assert_same(desktop._host_state,_host)
	assert_same(desktop._localization,_localization)
	assert_same(desktop._profile,_profile)
	assert_eq(desktop._day,3)
	assert_true(_configure_shop(desktop).ok)
	assert_true(_configure_shop(desktop).ok)
	var replacement := CatalogProvider.new()
	replacement.rows = _valid_rows()
	assert_eq(desktop.configure_shop(replacement,_localization,_profile,_host,3).code,
		&"shop_already_configured")
	assert_eq(desktop.configure_contacts(_contacts,null,null,null,3).code,
		&"desktop_owner_mismatch")
	assert_same(desktop._shop_port,_provider)
	assert_same(desktop._host_state,_host)
	assert_same(desktop._localization,_localization)
	assert_same(desktop._profile,_profile)
	assert_eq(desktop._day,3)
	var app := _open_shop(desktop)
	if app == null: return
	assert_true(app.last_result.ok)


func test_real_provider_projects_fixed_order_seventeen_cards_and_supportz_blank() -> void:
	var desktop := await _desktop_on_tree()
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	assert_eq(_provider.rows.size(),17)
	assert_eq(app.cards.size(),17)
	assert_eq(_ids(app._records),ORDER)
	assert_eq(app._records[8],{"id":"supportz","blank":true,"actionable":false})
	assert_false(app.cards.has("supportz"))
	assert_false(_provider.calls.is_empty())
	for locale: String in _provider.calls: assert_eq(locale,"en")
	var visible_order: Array = []
	for page in app.page_count:
		for record: Dictionary in app._records:
			if not record.blank and app.cards[record.id].visible:
				visible_order.append(record.id)
		if page < app.page_count-1:
			app.next_button.pressed.emit()
			await _settle()
	var expected: Array = ORDER.duplicate()
	expected.erase("supportz")
	assert_eq(visible_order,expected)


func test_home_cache_retains_page_selection_quantity_and_focus_then_hidden_preferences_reflow() -> void:
	var desktop := await _desktop_on_tree()
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	app.next_button.pressed.emit()
	await _settle()
	app.cards.healthy_meal.pressed.emit()
	app.quantity_buttons.maximum.pressed.emit()
	app.cards.healthy_meal.grab_focus()
	var page_before: int = app.page_index
	assert_eq(app.selected_id,"healthy_meal")
	assert_eq(app.quantity,4)
	assert_true(desktop.return_home().ok)
	assert_true(desktop.launcher_buttons[&"shop"].has_focus())
	var reopened: Dictionary = desktop.open_app(&"shop")
	assert_true(reopened.ok)
	if not reopened.ok: return
	await _settle()
	assert_same(reopened.value.app,app)
	assert_eq(app.page_index,page_before)
	assert_eq(app.selected_id,"healthy_meal")
	assert_eq(app.quantity,4,"An identical provider delivery does not reset presentation quantity.")
	assert_true(app.cards.healthy_meal.has_focus())
	assert_true(desktop.return_home().ok)
	assert_true(_localization.set_locale("zh_HK").ok)
	assert_true(_profile.set_preferences({
		&"preferences.accessibility.text_size":125,
		&"preferences.accessibility.large_targets":true,
	}).ok)
	assert_eq(app._locale,"en","A hidden app defers reconstruction.")
	assert_true(desktop.launcher_buttons[&"shop"].has_focus())
	assert_true(desktop.open_app(&"shop").ok)
	await _settle()
	assert_eq(app._locale,"zh_HK")
	assert_eq(app._percent,125)
	assert_true(app._large)
	assert_eq(app.selected_id,"healthy_meal")
	assert_eq(app.quantity,4)
	assert_true(app.cards.healthy_meal.visible)
	assert_true(app.cards.healthy_meal.has_focus())


func test_changed_owner_snapshot_resets_quantity_to_one_and_uses_new_legal_max() -> void:
	var desktop := await _desktop_on_tree()
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	app.quantity_buttons.maximum.pressed.emit()
	assert_eq(app.quantity,4)
	_record("coffee").legal_max = 2
	_provider.catalog_changed.emit()
	await _settle()
	assert_true(app.last_result.ok)
	assert_eq(app.quantity,1)
	assert_eq(app._records[0].legal_max,2)
	assert_eq(_record("coffee").legal_max,2)
	app.quantity_buttons.maximum.pressed.emit()
	assert_eq(app.quantity,2)
	assert_eq(_host.get_state().active_app_id,&"shop")


func test_bad_projection_recovers_without_partial_cards_or_route_change() -> void:
	var desktop := await _desktop_on_tree()
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	var stable_rows: Array = _provider.rows.duplicate(true)
	_provider.rows.pop_back()
	_provider.catalog_changed.emit()
	await _settle()
	assert_false(app.last_result.ok)
	assert_eq(app.last_result.code,"invalid_item_count")
	assert_true(app.cards.is_empty())
	assert_true(app.status_label.visible)
	assert_eq(app.status_label.text,"Unavailable")
	assert_true(desktop.status_label.visible)
	assert_eq(_host.get_state().active_app_id,&"shop")
	assert_true(desktop.return_home().ok)
	_provider.rows = stable_rows
	_provider.catalog_changed.emit()
	await _settle()
	assert_true(desktop.open_app(&"shop").ok)
	await _settle()
	assert_true(app.last_result.ok)
	assert_eq(app.cards.size(),17)
	assert_eq(_host.get_state().active_app_id,&"shop")

func test_failed_initial_catalog_does_not_change_an_ordinary_host_route() -> void:
	var desktop := await _desktop_on_tree()
	_provider.failure_code = "fixture_catalog_unavailable"
	assert_true(_configure_shop(desktop).ok)
	var opened: Dictionary = desktop.open_app(&"shop")
	assert_false(opened.ok)
	assert_null(_host.get_state().active_app_id)
	assert_eq(desktop._active_id,&"")
	assert_true(desktop.icon_grid.visible)
	assert_true(desktop.status_label.visible)


func test_pre_ready_restored_shop_route_mounts_or_masks_a_failed_projection() -> void:
	for fails: bool in [false,true]:
		_host.reset(3)
		assert_true(_host.open_app(&"shop",3).ok)
		_provider.failure_code = "fixture_catalog_unavailable" if fails else ""
		var desktop: Control = DESKTOP.instantiate()
		desktop.set_script(IsolatedDesktop)
		assert_true(desktop.configure_contacts(_contacts,_localization,_profile,_host,3).ok)
		assert_true(_configure_shop(desktop).ok)
		_viewport.add_child(desktop)
		await _settle()
		assert_eq(_host.get_state().active_app_id,&"shop")
		assert_eq(desktop._active_id,&"shop")
		assert_false(desktop.icon_grid.visible)
		if fails:
			assert_true(desktop._restoration_failed)
			assert_true(desktop.home_button.disabled)
			assert_eq(desktop.home_button.focus_mode,Control.FOCUS_NONE)
		else:
			var app: Control = desktop._cached_app_windows.get(&"shop") as Control
			assert_not_null(app)
			if app != null: assert_true(app.is_visible_in_tree())
			assert_false(desktop._restoration_failed)
		desktop.hide()

func test_native_back_returns_to_launcher_and_keeps_the_cached_shop() -> void:
	# Opening in the same frame as Desktop._ready must retire its deferred Minesweeper focus.
	var desktop := _desktop_same_frame()
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	assert_true(app.cards.coffee.has_focus())
	assert_false(desktop.home_button.disabled)
	assert_eq(desktop.home_button.focus_mode,Control.FOCUS_ALL)
	await _tap(KEY_ESCAPE)
	assert_false(app.visible)
	assert_true(desktop.icon_grid.visible)
	assert_null(_host.get_state().active_app_id)
	assert_same(desktop._cached_app_windows[&"shop"],app)
	assert_true(desktop.launcher_buttons[&"shop"].has_focus())


func test_shared_confirmation_owns_higher_routing_and_native_input_custody() -> void:
	var desktop := await _desktop_on_tree()
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	app.cards.coffee.grab_focus()
	var before := {"page":app.page_index,"selected":app.selected_id,"quantity":app.quantity}
	var presented: Dictionary = desktop.present_confirmation({
		"title":"Fixture custody","body":"No Shop command is available here.",
		"confirm":"Continue","cancel":"Cancel","warning":false,
	},_accept_confirmation,_cancel_confirmation)
	assert_true(presented.ok)
	assert_not_null(desktop._confirmation)
	assert_eq(desktop.return_home().code,&"desktop_modal_active")
	assert_eq(desktop.open_app(&"contacts").code,&"desktop_modal_active")
	await _tap(KEY_RIGHT)
	await _tap(KEY_PAGEDOWN)
	assert_eq({"page":app.page_index,"selected":app.selected_id,"quantity":app.quantity},before)
	assert_eq(_host.get_state().active_app_id,&"shop")
	assert_eq(_accepted,0)
	assert_eq(_cancelled,0)
	await _tap(KEY_ESCAPE)
	assert_null(desktop._confirmation)
	assert_eq(_accepted,0)
	assert_eq(_cancelled,1)
	assert_eq(_host.get_state().active_app_id,&"shop")
	assert_eq({"page":app.page_index,"selected":app.selected_id,"quantity":app.quantity},before)