extends GutTest
## Presentation-only proof over explicitly injected application ports, not gameplay/Save acceptance.
const F := preload("res://tests/support/SceneAppPreparationFixture.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
var viewport: SubViewport
var locale: RefCounted
var profile: RefCounted

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	locale = F.MINES.LocaleFixture.new()
	profile = F.MINES.ProfileFixture.new()
	profile.values = {"preferences.accessibility.text_size": 100, "preferences.accessibility.large_targets": false}

func mount_app(path: String, spy: Script = null) -> Control:
	var app: Control = load(path).instantiate()
	if spy != null: app.set_script(spy)
	app.hide()
	viewport.add_child(app)
	return app

func test_contacts_scene_refresh_reopen_and_preference_reflow() -> void:
	var app := mount_app("res://scenes/apps/ContactListApp.tscn", F.ContactSpy)
	var port := F.CONTACTS.FakePort.new()
	assert_true(app.configure_scene_presentation(port, locale, profile).ok)
	app.show_window()
	profile.change("preferences.accessibility.text_size", 150)
	profile.change("preferences.accessibility.high_contrast", true)
	locale.change("zh-HK")
	assert_true(app.refresh_view().ok)
	assert_null(app._day)
	assert_true(app.contacts_panel._scene_presentation)
	assert_eq(app.contacts_panel.font_size, 36)
	app.hide()
	app.show_window()
	assert_eq(app.calendar_calls, 0)
	var before: Theme = app.contacts_panel.theme
	assert_false(app.configure_scene_presentation(port, locale, profile, &"invalid").ok)
	assert_same(app.contacts_panel.theme, before)
	assert_false(app.configure_presentation(port, locale, profile).ok)
	assert_true(app._scene_presentation)
	assert_true(port.opens.is_empty())

func test_mines_scene_refresh_resize_information_and_reopen() -> void:
	var app := mount_app("res://scenes/apps/MinesweeperApp.tscn", F.MinesSpy)
	var port := F.board_port(app)
	assert_true(app.configure_scene_presentation(port, locale, profile).ok)
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	profile.change("preferences.accessibility.font_style", "readable")
	locale.change("zh-HK")
	assert_true(app.refresh_view().ok)
	app.set_desktop_height(720)
	assert_true(app.panel._scene_presentation)
	assert_true(app.panel.worksheet._scene_presentation)
	assert_true(app.panel.worksheet.grid._scene_presentation)
	assert_null(app.panel._day)
	app.panel.worksheet.open_rules()
	assert_not_null(app.panel.worksheet.information_sheet)
	if app.panel.worksheet.information_sheet != null:
		assert_true(app.panel.worksheet.information_sheet._scene_presentation)
		locale.change("en")
		assert_true(app.panel.worksheet.information_sheet._scene_presentation)
	assert_true(app.prepare_return_home().ok)
	app.hide_window()
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	assert_eq(app.calendar_calls, 0)
	var before: Theme = app.panel.register.theme
	assert_false(app.configure_scene_presentation(port, locale, profile, null, &"invalid").ok)
	assert_same(app.panel.register.theme, before)
	assert_false(app.configure_presentation(port, locale, profile).ok)
	assert_true(port.commands.is_empty())

func test_shop_scene_catalog_refresh_reflow_preserves_port_and_cards() -> void:
	var app := mount_app("res://scenes/apps/ShopApp.tscn", F.ShopSpy)
	var port := F.catalog_port()
	assert_true(app.configure_scene_catalog(port, locale, profile).ok)
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	profile.change("preferences.accessibility.text_size", 125)
	profile.change("preferences.accessibility.high_contrast", true)
	locale.change("zh-HK")
	assert_true(app.refresh_view().ok)
	assert_null(app._day)
	assert_false(app.cards.is_empty())
	for card: Control in app.cards.values(): assert_true(card._scene_presentation)
	app.hide()
	assert_true(app.prepare_show_window().ok)
	app.show_window()
	assert_eq(app.calendar_calls, 0)
	var before: Theme = app.theme
	assert_false(app.configure_scene_catalog(port, locale, profile, &"invalid").ok)
	assert_same(app.theme, before)
	assert_false(app.configure_catalog(port, locale, profile).ok)
	assert_true(port.purchase_calls.is_empty())

func test_settings_scene_presentation_uses_real_content_and_preferences() -> void:
	var owner := PROFILE.new()
	add_child_autofree(owner)
	assert_true(owner.initialize(STORAGE.new("scene-app-profile", FILES.new())).ok)
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(owner).ok)
	var app: Control = load("res://scenes/apps/SettingsApp.tscn").instantiate()
	app.get_node("SettingsContent").configure_services({"profile": owner, "localization": localization,
		"input": null, "audio": null, "volume": null, "tts": null,
		"profile_reset_admission": func() -> bool: return true})
	app.get_node("LocalePresentationRoot").set("_localization", localization)
	assert_true(app.configure_scene_run_presentation(&"after_hours").ok)
	app.hide()
	viewport.add_child(app)
	assert_true(app.get_desktop_ready_result().ok)
	app.show_window()
	app.settings_content.apply_text_size(150, true)
	assert_true(app.settings_content._scene_presentation)
	assert_null(app.settings_content._run_day)
	var before: Theme = app.settings_content.theme
	assert_false(app.configure_scene_run_presentation(&"invalid").ok)
	assert_same(app.settings_content.theme, before)
	assert_false(app.configure_run_presentation(&"after_hours", 1).ok)
	app.hide()
	app.show_window()
	assert_null(app.settings_content._presentation_day)

func test_backup_refuses_scene_activation_without_inspection_contract() -> void:
	var app := mount_app("res://scenes/apps/BackupApp.tscn")
	var before: Theme = app.theme
	var before_port: Object = app._port
	assert_eq(app.configure_scene_backup(null).code, &"scene_backup_projection_unavailable")
	assert_same(app.theme, before)
	assert_eq(app._port, before_port)
	assert_false(app.visible)
