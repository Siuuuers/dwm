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
const SHOP_THEME := preload("res://scripts/ui/shop/ShopTheme.gd")
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")

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
	var supportz_available := false
	var purchase_calls: Array[Dictionary] = []

	func get_catalog(locale: String) -> Dictionary:
		calls.append(locale)
		if not failure_code.is_empty():
			return {"ok":false,"code":StringName(failure_code),"value":[]}
		var value: Array = rows.duplicate(true)
		var copy_locale := locale.replace("-","_")
		for row: Dictionary in value:
			row.name = COPY.item_name(copy_locale,row.id)
		return {"ok":true,"code":&"ok","value":value}

	func can_purchase(item_id: String, quantity: int) -> Dictionary:
		return {"ok":supportz_available and item_id == "supportz" and quantity == 1}

	func purchase(item_id: String, quantity: int) -> Dictionary:
		purchase_calls.append({"id":item_id,"quantity":quantity})
		return {"ok":false,"code":&"fixture_purchase_not_authorized"}

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


func test_desktop_enlargement_preserves_shop_state_and_maps_physical_card_input() -> void:
	var desktop := await _desktop_on_tree()
	desktop.size = Vector2(800, 720)
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	app.quantity_buttons.maximum.pressed.emit()
	var card: Button = app.cards.coffee
	card.grab_focus()
	var card_rect := card.get_global_rect()
	var page_before: int = app.page_index
	var calls_before: int = _provider.calls.size()
	desktop.size.x = 960
	await _settle()
	assert_true(card.get_global_rect().size.is_equal_approx(card_rect.size * 1.2),
		"card artwork, captions and input bounds magnify together")
	assert_same(desktop._cached_app_windows[&"shop"], app)
	assert_same(app.cards.coffee, card)
	assert_same(_viewport.gui_get_focus_owner(), card)
	assert_eq(app.selected_id, "coffee")
	assert_eq(app.quantity, 4)
	assert_eq(app.page_index, page_before)
	assert_eq(_provider.calls.size(), calls_before, "presentation resize does not refresh the catalog")
	var wine: Button = app.cards.wine
	var point := wine.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event, true)
		await get_tree().process_frame
	await _settle()
	assert_eq(app.selected_id, "wine", "physical input reaches the enlarged card")
	assert_true(_provider.purchase_calls.is_empty(), "inspection does not purchase")
	desktop.app_scroll.ensure_control_visible(app.get("_buy_button"))
	await _settle()
	assert_true(desktop.app_scroll.get_global_rect().encloses(app.get("_buy_button").get_global_rect()),
		"the enlarged bottom action remains reachable above the fixed footer")
	desktop.size.x = 800
	await _settle()
	assert_true(card.get_global_rect().size.is_equal_approx(card_rect.size))
	assert_same(app.cards.coffee, card)
	assert_eq(app.selected_id, "wine")
	assert_eq(_provider.calls.size(), calls_before)


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


func test_live_accessibility_colours_repaint_cached_shop_without_catalog_or_selection_mutation() -> void:
	var desktop := await _desktop_on_tree()
	var meal: Dictionary = _record("healthy_meal")
	meal.description = "Public fixture description. ".repeat(80)
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	app.next_button.pressed.emit()
	await _settle()
	app.cards.healthy_meal.pressed.emit()
	app.quantity_buttons.maximum.pressed.emit()
	app.info_scroll.grab_focus()
	app.info_scroll.scroll_vertical = 30
	var card: Button = app.cards.healthy_meal
	var art: Texture2D = card.get("_art")
	var inspector_art: Texture2D = app._art.texture
	var calls_before: int = _provider.calls.size()
	var records_before: Array = app._records.duplicate(true)
	var warm: Dictionary = SHOP_THEME.resolve(&"after_hours",3,false,"standard")
	assert_eq(app.theme.get_color("habitat","Shop"),warm.habitat)
	assert_true(_profile.set_preferences({
		&"preferences.accessibility.high_contrast":true,
		&"preferences.accessibility.colour_differentiation":"protan",
	}).ok)
	await _settle()
	var high: Dictionary = SHOP_THEME.resolve(&"after_hours",3,true,"protan")
	assert_eq(app.theme.get_color("habitat","Shop"),high.habitat)
	assert_eq(card.get("_roles"),high)
	assert_eq(_provider.calls.size(),calls_before,"Appearance-only preference signals do not query the catalog.")
	assert_true(_provider.purchase_calls.is_empty())
	assert_eq(app._records,records_before)
	assert_eq(app.selected_id,"healthy_meal")
	assert_eq(app.quantity,4)
	assert_eq(app.page_index,1)
	assert_eq(app.info_scroll.scroll_vertical,30)
	assert_true(app.info_scroll.has_focus())
	assert_same(app.cards.healthy_meal,card)
	assert_same(card.get("_art"),art)
	assert_same(app._art.texture,inspector_art)
	assert_eq(app._art.modulate,Color.WHITE)
	assert_eq(card.modulate,Color.WHITE)
	assert_true(desktop.return_home().ok)
	assert_true(_profile.set_preferences({
		&"preferences.accessibility.high_contrast":false,
		&"preferences.accessibility.colour_differentiation":"tritan",
	}).ok)
	assert_true(desktop.open_app(&"shop").ok)
	await _settle()
	assert_same(desktop._cached_app_windows[&"shop"],app)
	assert_same(app.cards.healthy_meal,card)
	assert_eq(app.theme.get_color("habitat","Shop"),SHOP_THEME.resolve(&"after_hours",3,false,"tritan").habitat)
	assert_eq(app.selected_id,"healthy_meal")
	assert_eq(app.quantity,4)
	assert_eq(app.page_index,1)
	assert_eq(app.info_scroll.scroll_vertical,30)
	assert_true(app.info_scroll.has_focus())
	assert_true(_provider.purchase_calls.is_empty())


func test_shop_uses_new_installed_day_after_desktop_eviction() -> void:
	var desktop := await _desktop_on_tree()
	assert_true(_configure_shop(desktop).ok)
	var day_three := _open_shop(desktop)
	if day_three == null: return
	await _settle()
	assert_eq(day_three.theme.get_color("habitat","Shop"),
		SHOP_THEME.resolve(&"after_hours",3,false,"standard").habitat)
	assert_true(desktop.return_home().ok)
	_host.reset(7)
	assert_true(desktop.dispatch_desktop_eviction({"kind":&"evict_cached_apps","day":7}).ok)
	await _settle()
	assert_false(desktop._cached_app_windows.has(&"shop"))
	assert_false(is_instance_valid(day_three))
	var opened: Dictionary = desktop.open_app(&"shop")
	assert_true(opened.ok)
	if not opened.ok: return
	var day_seven: Control = opened.value.app as Control
	await _settle()
	assert_not_null(day_seven)
	assert_eq(day_seven.theme.get_color("habitat","Shop"),
		SHOP_THEME.resolve(&"after_hours",7,false,"standard").habitat)
	assert_eq(day_seven.cards.size(),17)
	assert_eq(day_seven.page_count,2)
	assert_true(day_seven._records[8].blank)
	assert_true(_provider.purchase_calls.is_empty())


func test_supportz_confirmation_holds_old_colours_until_modal_finishes() -> void:
	_provider.supportz_available = true
	var desktop := await _desktop_on_tree()
	assert_true(_configure_shop(desktop).ok)
	var app := _open_shop(desktop)
	if app == null: return
	await _settle()
	assert_true(app._supportz_button.visible)
	app._supportz_button.pressed.emit()
	await _settle()
	var modal: Control = app._supportz_confirmation
	assert_not_null(modal)
	if modal == null: return
	var old_shop: Color = app.theme.get_color("habitat","Shop")
	var old_confirmation: Color = BACKUP_THEME.build("en",100,&"after_hours",3,false,"standard").get_color("paper","Backup")
	assert_eq(modal.theme.get_color("paper","Backup"),old_confirmation)
	var calls_before: int = _provider.calls.size()
	# The owner may have fresher ordinary facts without an event while this modal
	# owns input. Cancel must revalidate them as it publishes pending colours.
	var coffee: Dictionary = _record("coffee")
	coffee.legal_max = 2
	var wine: Dictionary = _record("wine")
	wine.available = false
	wine.legal_max = 0
	assert_true(_profile.set_preferences({
		&"preferences.accessibility.high_contrast":true,
		&"preferences.accessibility.colour_differentiation":"deutan",
	}).ok)
	await _settle()
	assert_same(app._supportz_confirmation,modal)
	assert_eq(app.theme.get_color("habitat","Shop"),old_shop)
	assert_eq(modal.theme.get_color("paper","Backup"),old_confirmation)
	assert_eq(_provider.calls.size(),calls_before)
	assert_eq(app._records[0].legal_max,4)
	assert_true(app._records[0].available)
	assert_true(app._records[1].available)
	assert_true(_provider.purchase_calls.is_empty())
	assert_false(app.can_return_home())
	modal.cancel_button.pressed.emit()
	await _settle()
	assert_null(app._supportz_confirmation)
	assert_eq(app.theme.get_color("habitat","Shop"),
		SHOP_THEME.resolve(&"after_hours",3,true,"deutan").habitat)
	assert_gt(_provider.calls.size(),calls_before,"Cancel revalidates an unsignaled owner snapshot.")
	assert_eq(app._records[0].legal_max,2)
	assert_false(app._records[1].available)
	assert_eq(app._records[1].legal_max,0)
	assert_eq(app.cards.wine.availability_label.text,"Sold out")
	assert_true(_provider.purchase_calls.is_empty())
	assert_eq(_host.get_state().active_app_id,&"shop")
	app._supportz_button.pressed.emit()
	await _settle()
	var current_modal: Control = app._supportz_confirmation
	assert_not_null(current_modal)
	if current_modal == null: return
	assert_eq(current_modal.theme.get_color("paper","Backup"),
		BACKUP_THEME.build("en",100,&"after_hours",3,true,"deutan").get_color("paper","Backup"))
	current_modal.cancel_button.pressed.emit()
	await _settle()
	assert_true(_provider.purchase_calls.is_empty())
