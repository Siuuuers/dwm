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
	assert_eq(REGISTRY.new().get_scene_ids(), [&"minesweeper", &"contacts", &"shop", &"backup", &"settings", &"logout"])
	assert_false(REGISTRY.new().get_scene_record(&"schedule").ok)
	assert_true(REGISTRY.new().get_record(&"schedule").ok, "legacy resolver retained")
	assert_false(desktop.launcher_buttons[&"schedule"].visible)
	assert_eq(desktop.launcher_buttons[&"schedule"].focus_mode, Control.FOCUS_NONE)
	var expected := {&"minesweeper": "Minesweeper", &"contacts": "Contacts", &"shop": "Shop", &"backup": "Backup", &"settings": "Settings", &"logout": "Log out"}
	for id: StringName in expected:
		var button: Button = desktop.launcher_buttons[id]
		assert_eq(button.icon_id, id)
		assert_eq(button.get_node("Caption").text, expected[id])
		assert_ne(button.focus_next, button.get_path_to(desktop.launcher_buttons[&"schedule"]))
	assert_false(desktop.open_app(&"schedule").ok)
	assert_null(host.get_state().active_app_id)

func test_titles_and_cached_home_use_real_scene_host() -> void:
	var app: Control = ports.install_cached_view(desktop, &"shop")
	assert_true(desktop.open_app(&"shop").ok)
	assert_eq(host.get_state().active_app_id, &"shop")
	assert_eq(desktop.title_label.text, "Shop")
	assert_true(app.visible)
	assert_true(desktop.return_home().ok)
	assert_null(host.get_state().active_app_id)
	assert_false(app.visible)
	assert_eq(app.remembered, 1)
	assert_true(desktop.open_app(&"shop").ok)
	assert_eq(desktop._cached_app_windows[&"shop"], app)
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
	assert_false(desktop.configure_schedule(null, null, null, host, 1).ok)
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
