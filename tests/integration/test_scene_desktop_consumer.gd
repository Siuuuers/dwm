extends GutTest
## Bounded mounted consumer coverage; injected cached views are not production app proof.
const FIXTURE := preload("res://tests/support/SceneDesktopConsumerFixture.gd")
const REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")
var ports: RefCounted
var desktop: Control
var host: RefCounted

func before_each() -> void:
	ports = FIXTURE.new()
	host = FIXTURE.HOST.new()
	assert_true(host.commit_restore(host.prepare_scene_restore(null).value.candidate_state).ok)
	desktop = ports.make_desktop()
	add_child_autofree(desktop)
	assert_true(desktop.configure_scene_navigation(host, ports.read_phase, ports.dispatch, ports.prepare_app).ok)

func test_scene_launcher_uses_ids_without_schedule() -> void:
	assert_eq(REGISTRY.new().get_scene_ids(), [&"minesweeper", &"contacts", &"shop", &"backup", &"settings"])
	assert_false(REGISTRY.new().get_scene_record(&"schedule").ok)
	assert_false(REGISTRY.new().get_record(&"schedule").ok)
	assert_false(desktop.launcher_buttons.has(&"schedule"))
	var expected := {&"minesweeper": "Minesweeper", &"contacts": "Contacts", &"shop": "Shop", &"backup": "Backup", &"settings": "Settings", &"logout": "Log out"}
	for id: StringName in expected:
		var button: Button = desktop.launcher_buttons[id]
		assert_eq(button.icon_id, id)
		assert_eq(button.get_node("Caption").text, expected[id])
	assert_false(desktop.open_app(&"schedule").ok)
	assert_null(host.get_state().active_app_id)

func test_titles_and_cached_home_use_real_scene_host() -> void:
	var initial_theme: Theme = desktop.theme
	var app: Control = ports.install_cached_view(desktop, &"shop")
	assert_true(desktop.open_app(&"shop").ok)
	assert_eq(host.get_state().active_app_id, &"shop")
	assert_eq(desktop.title_label.text, "Shop")
	assert_false(desktop.home_button.disabled)
	assert_same(desktop.theme, initial_theme, "Opening a cached app retains launcher presentation")
	assert_true(app.visible)
	assert_true(desktop.return_home().ok)
	assert_null(host.get_state().active_app_id)
	assert_eq(desktop.title_label.text, "Home")
	assert_true(desktop.home_button.disabled)
	assert_same(desktop.theme, initial_theme)
	assert_false(app.visible)
	assert_eq(app.remembered, 1)
	assert_true(desktop.open_app(&"shop").ok)
	assert_eq(desktop._cached_app_windows[&"shop"], app)
	assert_same(desktop.theme, initial_theme)
	assert_eq(host.get_state().cached_app_ids, [&"shop"])
	assert_false(host.get_state().has("current_day"))

func test_board_commands_keep_order_and_read_current_phase() -> void:
	ports.install_cached_view(desktop, &"minesweeper")
	ports.phase = &"ACTIVE_SUSPENDED"
	assert_true(desktop.open_app(&"minesweeper").ok)
	assert_eq(ports.commands, [{"kind": "resume_board"}, {"kind": "open_app", "app_id": "minesweeper"}])
	ports.commands.clear()
	ports.phase = &"ACTIVE_VISIBLE"
	assert_true(desktop.return_home().ok)
	assert_eq(ports.commands, [{"kind": "suspend_board"}, {"kind": "hide_app", "app_id": "minesweeper"}])

func test_modal_and_preflight_refuse_before_host_mutation() -> void:
	var app: Control = ports.install_cached_view(desktop, &"contacts")
	app.preflight_ok = false
	var before: Dictionary = host.get_state()
	assert_false(desktop.open_app(&"contacts").ok)
	assert_eq(host.get_state(), before)
	assert_true(ports.commands.is_empty())
	app.preflight_ok = true
	assert_true(desktop.open_app(&"contacts").ok)
	before = host.get_state()
	app.modal = true
	assert_false(desktop.return_home().ok)
	assert_false(desktop.open_app(&"shop").ok)
	assert_eq(host.get_state(), before)
	assert_true(app.visible)

func test_calendar_configuration_and_eviction_are_refused() -> void:
	var before: Dictionary = host.get_state()
	assert_false(desktop.configure_contacts(null, null, null, host, 1).ok)
	assert_false(desktop.configure_minesweeper(null, null, null, host, 1).ok)
	assert_false(desktop.configure_shop(null, null, null, host, 1).ok)
	assert_false(desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 2}).ok)
	assert_eq(host.get_state(), before)

func test_uninstalled_host_and_invalid_phase_refuse() -> void:
	ports.install_cached_view(desktop, &"contacts")
	ports.phase = &"invented"
	assert_false(desktop.open_app(&"contacts").ok)
	assert_null(host.get_state().active_app_id)
	ports.phase = &"NONE"
	host.reset(1)
	var before: Dictionary = host.get_state()
	assert_eq(desktop.open_app(&"contacts").code, &"scene_desktop_not_installed")
	assert_eq(host.get_state(), before)
	assert_true(ports.commands.is_empty())

func test_dispatch_failure_masks_committed_host_without_replay() -> void:
	ports.install_cached_view(desktop, &"contacts")
	ports.fail_dispatch = true
	assert_false(desktop.open_app(&"contacts").ok)
	assert_eq(host.get_state().active_app_id, &"contacts", "UI must not reconstruct host rollback")
	assert_false(desktop.visible)
	assert_false(desktop.open_app(&"contacts").ok)
	assert_false(desktop.return_home().ok)
	assert_eq(ports.commands.size(), 1)

func test_all_existing_locales_keep_surviving_app_titles() -> void:
	ports.install_cached_view(desktop, &"shop")
	var titles := {"en": "Shop", "zh-CN": "商店", "zh-HK": "商店", "ja": "ショップ", "ko": "상점"}
	for locale: String in titles:
		desktop._locale = locale
		assert_true(desktop.open_app(&"shop").ok)
		assert_eq(desktop.title_label.text, titles[locale])
		assert_eq(desktop.launcher_buttons[&"shop"].get_node("Caption").text, titles[locale])
		assert_true(desktop.return_home().ok)

func test_restored_external_sheets_go_home_without_rewriting_saved_input() -> void:
	var external_calls: Array[StringName] = []
	var external := func(id: StringName) -> Dictionary:
		external_calls.append(id)
		return {"ok": true}
	assert_true(desktop.configure_scene_shell_actions(external, func() -> bool: return true).ok)
	for id: StringName in [&"settings", &"backup"]:
		var prepared: Dictionary = host.prepare_scene_restore(id)
		assert_true(prepared.ok)
		var original := prepared.duplicate(true)
		assert_true(host.commit_restore(prepared.value.candidate_state).ok)
		ports.commands.clear()
		assert_true(desktop.return_home().ok)
		assert_null(host.get_state().active_app_id)
		assert_eq(ports.commands, [{"kind": "hide_app", "app_id": String(id)}])
		assert_eq(prepared, original, "Home navigation does not rewrite the saved restore input")
		assert_true(external_calls.is_empty(), "Home neither reopens a sheet nor executes its action")
		assert_true(desktop._cached_app_windows.is_empty())

func test_restored_external_sheet_home_refusal_preserves_host_and_commands() -> void:
	assert_true(desktop.configure_scene_shell_actions(func(_id: StringName) -> Dictionary: return {"ok": true}, func() -> bool: return true).ok)
	for id: StringName in [&"settings", &"backup"]:
		assert_true(host.commit_restore(host.prepare_scene_restore(id).value.candidate_state).ok)
		var before: Dictionary = host.get_state()
		ports.phase = &"invalid_phase"
		assert_eq(desktop.return_home().code, &"invalid_board_phase")
		assert_eq(host.get_state(), before)
		assert_true(ports.commands.is_empty())
		ports.phase = &"NONE"

func test_logout_launcher_dispatches_action_without_app_scene() -> void:
	var calls: Array[StringName] = []
	var dispatch := func(id: StringName) -> Dictionary:
		calls.append(id)
		return {"ok": true}
	assert_true(desktop.configure_scene_shell_actions(dispatch, func() -> bool: return true).ok)
	desktop.launcher_buttons[&"logout"].pressed.emit()
	await get_tree().process_frame
	assert_eq(calls, [&"logout"])
	assert_null(host.get_state().active_app_id)
	assert_false(desktop._cached_app_windows.has(&"logout"))
	assert_false(REGISTRY.new().get_scene_record(&"logout").ok)

func test_uncached_settings_configures_scene_before_ready_and_reuses_ready_theme() -> void:
	var profile := preload("res://autoload/ProfileManager.gd").new()
	add_child_autofree(profile)
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"scene-settings-before-ready", preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).ok)
	var localization := preload("res://autoload/LocalizationManager.gd").new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).ok)
	var settings_desktop: Control = ports.make_desktop()
	add_child_autofree(settings_desktop)
	var observed := {"preparations": 0, "ready_theme": null}
	var prepare := func(id: StringName, app: Control) -> Dictionary:
		observed.preparations += 1
		assert_eq(id, &"settings")
		assert_false(app.is_inside_tree(), "Scene context precedes initial presentation")
		assert_false(app.is_node_ready())
		app.get_node("SettingsContent").configure_services({"profile": profile, "localization": localization,
			"input": null, "audio": null, "volume": null, "tts": null,
			"profile_reset_admission": func() -> bool: return true})
		app.get_node("LocalePresentationRoot").set("_localization", localization)
		app.ready.connect(func() -> void: observed.ready_theme = app.settings_content.theme)
		return app.configure_scene_run_presentation(&"midnight")
	assert_true(settings_desktop.configure_scene_navigation(host, ports.read_phase, ports.dispatch, prepare).ok)
	var opened: Dictionary = settings_desktop.open_app(&"settings")
	assert_true(opened.ok, str(opened))
	if not opened.ok: return
	var app: Control = opened.value.app
	assert_true(app.get_desktop_ready_result().ok)
	assert_true(app.visible)
	assert_true(app.settings_content.is_interaction_enabled())
	assert_true(app.settings_content._scene_presentation)
	assert_null(app.settings_content._presentation_day)
	assert_eq(app.settings_content._presentation_palette, &"midnight")
	assert_not_null(observed.ready_theme)
	assert_same(app.settings_content.theme, observed.ready_theme, "Initial theme survives first show")
	assert_true(settings_desktop.return_home().ok)
	assert_true(settings_desktop.open_app(&"settings").ok)
	assert_same(settings_desktop._cached_app_windows[&"settings"], app)
	assert_same(app.settings_content.theme, observed.ready_theme)
	assert_true(app.get_desktop_ready_result().ok)
	assert_eq(observed.preparations, 1, "Reopen retains the prepared Settings instance")

func test_launcher_theme_reuses_unchanged_inputs_and_refreshes_current_presentation() -> void:
	var fixtures := preload("res://tests/unit/test_minesweeper_app.gd")
	var locale := fixtures.LocaleFixture.new()
	var profile := fixtures.ProfileFixture.new()
	var launcher: Control = ports.make_desktop()
	assert_true(launcher.configure_scene_navigation(host, ports.read_phase, ports.dispatch, ports.prepare_app, locale, profile).ok)
	add_child_autofree(launcher)
	launcher._refresh_launcher()
	var before: Theme = launcher.theme
	launcher._refresh_launcher()
	assert_same(launcher.theme, before)
	locale.change("zh-HK")
	assert_not_same(launcher.theme, before, "Locale changes rebuild presentation")
	assert_eq(launcher.title_label.text, "主頁")
	assert_eq(launcher.launcher_buttons[&"settings"].get_node("Caption").text, "設定")
	for change: Array in [["text_size", 150], ["font_style", "readable"],
			["high_contrast", true], ["colour_differentiation", "protan"]]:
		before = launcher.theme
		profile.change("preferences.accessibility." + change[0], change[1])
		assert_not_same(launcher.theme, before, str(change[0]))
		before = launcher.theme
		launcher._refresh_launcher()
		assert_same(launcher.theme, before, "Unchanged " + str(change[0]))
	before = launcher.theme
	profile.change("preferences.accessibility.large_targets", true)
	assert_true(launcher.touch_navigation.visible)
	assert_same(launcher.theme, before, "Large targets update layout without changing theme inputs")
	profile.change("preferences.accessibility.large_targets", false)
	assert_false(launcher.touch_navigation.visible)
	assert_same(launcher.theme, before)
	launcher._run_palette = &"midnight"
	launcher._refresh_launcher()
	assert_not_same(launcher.theme, before, "Palette changes rebuild presentation")
	before = launcher.theme
	launcher._day = 7
	launcher._refresh_launcher()
	assert_same(launcher.theme, before, "Scene presentation remains dayless")
	var calendar: Control = ports.make_desktop()
	add_child_autofree(calendar)
	calendar._refresh_launcher()
	before = calendar.theme
	calendar._day = 2
	calendar._refresh_launcher()
	assert_not_same(calendar.theme, before, "Calendar day tint changes rebuild presentation")
	before = calendar.theme
	calendar._refresh_launcher()
	assert_same(calendar.theme, before)
