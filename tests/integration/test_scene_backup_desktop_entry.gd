extends GutTest
## Uncached real desktop/Backup/confirmation boundary, not production Bootstrap or disk proof.
## Only Bootstrap, app preparation, board dispatch and the lower save owner are injected.
const DESKTOP_FIXTURE := preload("res://tests/support/SceneDesktopConsumerFixture.gd")
const APP_FIXTURE := preload("res://tests/support/SceneAppPreparationFixture.gd")
const BACKUP := preload("res://scripts/ui/BackupApp.gd")
const CONFIRMATION := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
var viewport: SubViewport
var desktop: Control
var host: RefCounted
var ports: RefCounted
var owner: RefCounted
var port: RefCounted
var bind_confirmation := true
var reject_configuration := false
var preparation_calls := 0
var prepared_app: WeakRef
var preparation_result: Dictionary = {}

func before_each() -> void:
	bind_confirmation = true
	reject_configuration = false
	preparation_calls = 0
	prepared_app = null
	preparation_result = {}
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	ports = DESKTOP_FIXTURE.new()
	host = DESKTOP_FIXTURE.HOST.new()
	assert_true(host.commit_restore(host.prepare_scene_restore(null).value.candidate_state).ok)
	owner = APP_FIXTURE.backup_owner()
	port = APP_FIXTURE.BACKUP_PORT.new()
	assert_true(port.configure(owner).ok)
	desktop = ports.make_desktop()
	viewport.add_child(desktop)
	assert_true(desktop.configure_scene_navigation(host, ports.read_phase,
		ports.dispatch, _prepare_backup).ok)

func _settle_views() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(viewport): viewport.queue_free()
	await _settle_views()

func _prepare_backup(id: StringName, app: Control) -> Dictionary:
	preparation_calls += 1
	prepared_app = weakref(app)
	if id != &"backup": return {"ok": false, "code": &"fixture_unexpected_app"}
	# Explicit test callback: never replace this with a fabricated ready result.
	if bind_confirmation: app.set_confirmation_host(desktop)
	preparation_result = app.configure_scene_backup(null if reject_configuration else port)
	return preparation_result

func test_uncached_backup_uses_real_desktop_consent_and_reuses_the_view() -> void:
	assert_true(desktop._cached_app_windows.is_empty())
	var opened: Dictionary = desktop.open_app(&"backup")
	assert_true(opened.ok, str(opened))
	if not opened.ok: return
	var app: Control = opened.value.app
	assert_same(app.get_script(), BACKUP)
	assert_same(app.get_parent(), desktop.app_window_host)
	assert_same(desktop._cached_app_windows[&"backup"], app)
	assert_same(app._confirmation_host, desktop)
	assert_true(app.get_desktop_ready_result().ok)
	assert_true(app._scene_presentation)
	assert_null(app._day)
	assert_eq(preparation_calls, 1)
	assert_eq(host.get_state().active_app_id, &"backup")
	assert_eq(ports.commands, [{"kind": "open_app", "app_id": "backup"}])
	app.mode_buttons.load.pressed.emit()
	app.action_buttons.load.pressed.emit()
	assert_not_null(app.confirmation)
	if app.confirmation == null: return
	var sheet: Control = app.confirmation
	var token: String = app._pending_token
	assert_same(sheet.get_script(), CONFIRMATION)
	assert_same(sheet, desktop._confirmation)
	assert_same(sheet.get_parent(), desktop.desktop_canvas)
	assert_eq(sheet.request.body, app._t("fallback") + "\n--:--\n\n" + app._t("replace_progress"))
	assert_true(owner.committed.is_empty())
	var before: Dictionary = host.get_state()
	assert_eq(desktop.return_home().code, &"desktop_modal_active")
	assert_eq(desktop.open_app(&"shop").code, &"desktop_modal_active")
	assert_eq(host.get_state(), before)
	assert_eq(preparation_calls, 1)
	assert_eq(ports.commands.size(), 1)
	sheet.cancel_button.pressed.emit()
	await _settle_views()
	assert_null(desktop._confirmation)
	assert_null(app.confirmation)
	assert_null(app._pending_token)
	assert_eq(owner.cancelled, [token])
	assert_true(owner.pending.is_empty())
	assert_true(owner.committed.is_empty())
	assert_true(desktop.return_home().ok)
	assert_false(app.visible)
	var reopened: Dictionary = desktop.open_app(&"backup")
	assert_true(reopened.ok, str(reopened))
	if not reopened.ok: return
	assert_same(reopened.value.app, app)
	assert_eq(preparation_calls, 1, "Cached reopen must not prepare another Backup")
	assert_eq(app.active_mode, "load")
	assert_null(app._day)

func test_refused_configuration_never_admits_or_caches_backup_and_can_retry() -> void:
	reject_configuration = true
	var before: Dictionary = host.get_state()
	var children: int = desktop.app_window_host.get_child_count()
	var refused: Dictionary = desktop.open_app(&"backup")
	assert_eq(refused.code, &"invalid_backup_port")
	assert_false(refused.ok)
	assert_eq(preparation_result.code, &"invalid_backup_port")
	assert_eq(preparation_calls, 1)
	assert_eq(host.get_state(), before)
	assert_eq(desktop._active_id, &"")
	assert_true(desktop._cached_app_windows.is_empty())
	assert_eq(desktop.app_window_host.get_child_count(), children)
	assert_true(ports.commands.is_empty())
	assert_true(owner.prepared.is_empty())
	assert_true(owner.committed.is_empty())
	assert_null(desktop._confirmation)
	await _settle_views()
	assert_null(prepared_app.get_ref(), "The rejected view must be released, not cached")
	reject_configuration = false
	var opened: Dictionary = desktop.open_app(&"backup")
	assert_true(opened.ok, str(opened))
	if not opened.ok: return
	assert_eq(preparation_calls, 2)
	assert_true(opened.value.app.get_desktop_ready_result().ok)
	assert_same(opened.value.app._confirmation_host, desktop)
	assert_eq(host.get_state().active_app_id, &"backup")

func test_missing_confirmation_host_cancels_prepared_action_without_commit() -> void:
	bind_confirmation = false
	var opened: Dictionary = desktop.open_app(&"backup")
	assert_true(opened.ok, str(opened))
	if not opened.ok: return
	var app: Control = opened.value.app
	# Presentation readiness alone does not certify production confirmation wiring.
	assert_true(app.get_desktop_ready_result().ok)
	assert_null(app._confirmation_host)
	var before: Dictionary = host.get_state()
	app.mode_buttons.load.pressed.emit()
	app.action_buttons.load.pressed.emit()
	assert_eq(owner.prepared.size(), 1)
	if owner.prepared.is_empty(): return
	assert_eq(owner.cancelled, [owner.prepared[0].token])
	assert_true(owner.committed.is_empty())
	assert_true(owner.pending.is_empty())
	assert_null(app._pending_token)
	assert_null(app.confirmation)
	assert_null(desktop._confirmation)
	assert_true(app._recovering)
	assert_eq(host.get_state(), before)
	assert_eq(ports.commands.size(), 1)
	app.action_buttons.cancel.pressed.emit()
	assert_false(app._recovering)
	assert_true(desktop.return_home().ok)
