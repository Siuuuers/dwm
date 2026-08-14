extends "res://addons/gut/test.gd"

const MENU_SCENE := preload("res://scenes/menu/MenuScene.tscn")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_OPS := preload("res://tests/support/FakeFileOps.gd")

func before_all() -> void:
	var profile := get_node("/root/ProfileManager")
	if not bool(profile.get("_initialized")):
		assert_true(profile.initialize(STORAGE.new("title-art-presenter-tests", FAKE_OPS.new())).get("ok", false))
	var localization := get_node("/root/LocalizationManager")
	if localization.get_readiness() == &"uninitialized":
		assert_true(localization.initialize(profile).get("ok", false))

func _make_fixture() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var menu := MENU_SCENE.instantiate() as MenuScene
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	return {"viewport": viewport, "menu": menu}

func _send_ui_cancel(viewport: SubViewport) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	viewport.push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame

func test_empty_presenter_has_exact_geometry_and_is_inert() -> void:
	var fixture := await _make_fixture()
	var presenter := (fixture.menu as MenuScene).get_node_or_null("%TitleArtPresenter") as Control
	assert_not_null(presenter)
	if presenter == null:
		return
	assert_eq(presenter.get_rect(), Rect2(320.0, 64.0, 960.0, 656.0))
	assert_true(presenter.visible)
	assert_eq(presenter.get_child_count(), 0)
	assert_null(presenter.get_script())
	assert_eq(presenter.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(presenter.focus_mode, Control.FOCUS_NONE)
	assert_eq(presenter.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(presenter.tooltip_text, "")
	assert_eq(presenter.accessibility_name, "")
	assert_eq(presenter.accessibility_description, "")
	assert_eq(int(presenter.accessibility_live), 0)

func test_ledger_ends_at_presenter_edge_without_overlap() -> void:
	var fixture := await _make_fixture()
	var menu := fixture.menu as MenuScene
	var ledger := menu.get_node("MenuPanel") as Control
	var presenter := menu.get_node("%TitleArtPresenter") as Control
	assert_eq(ledger.get_rect(), Rect2(0.0, 0.0, 320.0, 720.0))
	assert_false(ledger.get_rect().intersection(presenter.get_rect()).has_area())

func test_new_acc_remains_initial_focus() -> void:
	var fixture := await _make_fixture()
	assert_same(
		(fixture.viewport as SubViewport).gui_get_focus_owner(),
		(fixture.menu as MenuScene).get_node("%NewAccButton")
	)

func test_log_in_close_restores_presenter_and_exact_source_focus() -> void:
	var fixture := await _make_fixture()
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%LogInButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	var host := menu.get_node("%BackupAppHost") as Control
	assert_true(host.visible)
	var child := host.get_child(0) as BackupApp
	var hosted_control := child.get_node("%ReturnButton") as Button
	hosted_control.grab_focus()
	assert_same((fixture.viewport as SubViewport).gui_get_focus_owner(), hosted_control)
	child.hide_window()
	await get_tree().process_frame
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_false(host.visible)
	assert_same((fixture.viewport as SubViewport).gui_get_focus_owner(), source)
	source.pressed.emit()
	await get_tree().process_frame
	assert_eq(host.get_child_count(), 1)
	assert_same(host.get_child(0), child)
	assert_true(host.visible)
	assert_true(child.visible)

func test_settings_close_and_cached_reopen_preserve_presenter_and_source() -> void:
	var fixture := await _make_fixture()
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%SettingButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	var host := menu.get_node("%SettingHost") as Control
	var child := host.get_child(0) as Setting
	var hosted_control := child.get_node("%CloseButton") as Button
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	hosted_control.grab_focus()
	assert_same((fixture.viewport as SubViewport).gui_get_focus_owner(), hosted_control)
	hosted_control.pressed.emit()
	await get_tree().process_frame
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_false(host.visible)
	assert_same((fixture.viewport as SubViewport).gui_get_focus_owner(), source)
	source.pressed.emit()
	await get_tree().process_frame
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_true(host.visible)
	assert_true(child.visible)

func test_log_in_ui_cancel_closes_host_and_restores_exact_source_focus() -> void:
	var fixture := await _make_fixture()
	var viewport := fixture.viewport as SubViewport
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%LogInButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	var host := menu.get_node("%BackupAppHost") as Control
	var child := host.get_child(0) as BackupApp
	var hosted_control := child.get_node("%ReturnButton") as Button
	hosted_control.grab_focus()
	assert_same(viewport.gui_get_focus_owner(), hosted_control)
	await _send_ui_cancel(viewport)
	assert_false(host.visible)
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_same(viewport.gui_get_focus_owner(), source)

func test_settings_ui_cancel_closes_host_and_restores_exact_source_focus() -> void:
	var fixture := await _make_fixture()
	var viewport := fixture.viewport as SubViewport
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%SettingButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	var host := menu.get_node("%SettingHost") as Control
	var child := host.get_child(0) as Setting
	var hosted_control := child.get_node("%CloseButton") as Button
	hosted_control.grab_focus()
	assert_same(viewport.gui_get_focus_owner(), hosted_control)
	await _send_ui_cancel(viewport)
	assert_false(host.visible)
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_same(viewport.gui_get_focus_owner(), source)

func test_shutdown_confirmation_consumes_first_cancel_before_active_host() -> void:
	var fixture := await _make_fixture()
	var viewport := fixture.viewport as SubViewport
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%SettingButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	var host := menu.get_node("%SettingHost") as Control
	var child := host.get_child(0) as Setting
	var hosted_control := child.get_node("%CloseButton") as Button
	hosted_control.grab_focus()
	(menu.get_node("%ShutDownButton") as Button).pressed.emit()
	await get_tree().process_frame
	var confirmation := menu.get_node("%ShutDownConfirm") as ConfirmationDialog
	assert_true(confirmation.visible)
	await _send_ui_cancel(viewport)
	assert_false(confirmation.visible)
	assert_true(host.visible)
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	await _send_ui_cancel(viewport)
	assert_false(host.visible)
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_same(viewport.gui_get_focus_owner(), source)

func test_shutdown_confirmation_consumes_first_cancel_before_log_in_child() -> void:
	var fixture := await _make_fixture()
	var viewport := fixture.viewport as SubViewport
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%LogInButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	var host := menu.get_node("%BackupAppHost") as Control
	var child := host.get_child(0) as BackupApp
	var hosted_control := child.get_node("%ReturnButton") as Button
	hosted_control.grab_focus()
	assert_same(viewport.gui_get_focus_owner(), hosted_control)
	(menu.get_node("%ShutDownButton") as Button).pressed.emit()
	await get_tree().process_frame
	var confirmation := menu.get_node("%ShutDownConfirm") as ConfirmationDialog
	assert_true(confirmation.visible)
	await _send_ui_cancel(viewport)
	assert_false(confirmation.visible)
	assert_true(host.visible)
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	await _send_ui_cancel(viewport)
	assert_false(host.visible)
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_same(viewport.gui_get_focus_owner(), source)
