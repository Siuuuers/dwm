extends GutTest
## Captured run configuration uses the real lifecycle/schema/install boundary.
## Catalog art and checkpoint/generation ports are explicit isolated fixtures.
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const GAME_STATE := preload("res://autoload/GameState.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SCHEDULE_VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const SHOP_FIXTURE := preload("res://tests/unit/test_shop_catalog_projection.gd")
const SHOP_RENDERER := preload("res://tests/manual/verify_shop_desktop_native.gd")
const SCHEDULE := preload("res://tests/manual/verify_schedule_desktop_native.gd")
const BOARD_PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const PANEL_PORT := preload("res://scripts/application/minesweeper/MinesweeperPanelPort.gd")
const CHECKPOINT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")

class IsolatedDesktop extends ComputerDesktop:
	func _configure_from_bootstrap() -> void: pass
class ConfigurationFixture extends RefCounted:
	var answer: Dictionary = {"ok":true,"value":{"dark_mode":true}}
	func get_run_configuration() -> Dictionary: return answer.duplicate(true)

static func make_captured_run(dark: bool) -> Dictionary:
	var state := GAME_STATE.new()
	state.reset_game()
	var issuer := ISSUER.new()
	var configured: Dictionary = issuer.configure(ROOT_STORE.new("64".repeat(32),1))
	if not configured.ok:
		state.free()
		return configured
	var issued: Dictionary = issuer.issue(&"transaction_id")
	if not issued.ok:
		state.free()
		return issued
	var allocation: Dictionary = issuer.prepare_continuation_allocation({
		"existing_run_id":null,"kind":"new_run","remap_source_transaction_ids":[],
		"source_desktop_timeline_generation":null,"transaction_id":issued.value.token,
		"transaction_issuer_receipt":issued.value.issuer_receipt,
	})
	if not allocation.ok:
		state.free()
		return allocation
	var committed: Dictionary = issuer.commit_continuation_allocation(allocation.value)
	if not committed.ok:
		state.free()
		return committed
	var identity: Dictionary = committed.value
	var prepared: Dictionary = state.prepare_new_run_snapshot_input(identity.run_id,identity.branch_id,
		identity.desktop_timeline_generation,identity.causal_day_instance,identity.causal_day_instance_issuer_receipt,dark)
	if not prepared.ok:
		state.free()
		return prepared
	var empty_view: Dictionary = SCHEDULE_VIEW_STATE.make_empty(1,
		str(identity.causal_day_instance))
	if not empty_view.get("ok", false):
		state.free()
		return empty_view
	prepared.value.snapshot_input["schedule_view"] = empty_view.value.view
	var built := SNAPSHOT.build(prepared.value.snapshot_input,{},"main",null,
		{"ambience_context":{},"ambience_context_id":"","music_context":{},"music_context_id":""},1,1)
	if not built.ok:
		state.free()
		return built
	var applied: Dictionary = state.apply_restore_silent({"snapshot":built.value.snapshot})
	if not applied.ok:
		state.free()
		return applied
	return {"ok":true,"value":{"state":state,"issuer":issuer}}

static func bind_apps(desktop: Control, state: Node, issuer: RefCounted, locale: Object, profile: Object, host: RefCounted) -> Dictionary:
	var shop_fixture := SHOP_FIXTURE.new()
	var shop := SHOP_RENDERER.CatalogFixture.new()
	shop.rows = shop_fixture._valid_rows()
	shop_fixture.free()
	var configured: Dictionary = desktop.configure_shop(shop,locale,profile,host,1)
	if not configured.ok: return configured
	var registry := SCHEDULE.REGISTRY.load_current()
	var draft := SCHEDULE.VIEW.new()
	configured = draft.configure(registry.value.registry,SCHEDULE.RULES,registry.value.registry_fingerprint)
	if not configured.ok: return configured
	configured = draft.open_day(1,state._run_lifecycle.get_desktop_identity_context().causal_day_instance)
	if not configured.ok: return configured
	var schedule := SCHEDULE.PORT.new()
	var names := {}
	for id: String in ["training","working","rest"]:
		names[id] = {"en":id.capitalize(),"zh-CN":id.capitalize(),"zh-HK":id.capitalize()}
	configured = schedule.configure(state,draft,registry.value.registry,registry.value.registry_fingerprint,issuer,names)
	if not configured.ok: return configured
	configured = desktop.configure_schedule(schedule,locale,profile,host,1)
	if not configured.ok: return configured
	var board := BOARD_PORT.new()
	var identity: Dictionary = state._run_lifecycle.get_desktop_identity_context()
	identity.erase("causal_day_instance_issuer_receipt")
	configured = board.configure(state,issuer,identity)
	if not configured.ok: return configured
	var coordinator := COORDINATOR.new()
	configured = coordinator.configure(board,CHECKPOINT.new(),GENERATION.new(),issuer)
	if not configured.ok: return configured
	var panel := PANEL_PORT.new()
	configured = panel.configure(coordinator,issuer,state,CATALOG.new())
	if not configured.ok: return configured
	return desktop.configure_minesweeper(panel,locale,profile,host,1)

func _fixture(dark: bool) -> Dictionary:
	var run := make_captured_run(dark)
	assert_true(run.get("ok",false),JSON.stringify(run))
	if not run.get("ok",false): return {}
	add_child_autofree(run.value.state)
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("run-palette-memory",FILES.new())).ok)
	var document: Dictionary = profile.get_profile_snapshot()
	document.preferences.dark_mode.available = true # Explicit test entitlement; not inferred by the view.
	document.preferences.dark_mode.next_run_enabled = dark
	assert_true(profile.commit_prepared_profile(document).ok)
	var locale := LOCALIZATION.new()
	add_child_autofree(locale)
	assert_true(locale.initialize(profile).ok)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,720)
	viewport.handle_input_locally = true
	add_child_autofree(viewport)
	var host := HOST.new()
	host.reset(1)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	assert_true(desktop.configure_run_configuration(run.value.state).ok)
	viewport.add_child(desktop)
	assert_true(bind_apps(desktop,run.value.state,run.value.issuer,locale,profile,host).ok)
	return {"desktop":desktop,"state":run.value.state,"profile":profile,"locale":locale,"host":host,"viewport":viewport}

func _settle() -> void:
	for frame in 6: await get_tree().process_frame

func test_captured_palette_reaches_all_hosts_and_survives_pending_profile_locale_and_size_changes() -> void:
	for dark: bool in [false,true]:
		var f := _fixture(dark)
		if f.is_empty(): continue
		var palette: StringName = &"midnight" if dark else &"after_hours"
		var face := Color("14201d") if dark else Color("151b25")
		var before: Dictionary = f.state.capture_run_snapshot_input()
		assert_eq(f.desktop.theme.get_color("face","Desktop"),face,"Palette is bound before the first visible frame")
		for id: StringName in [&"schedule",&"shop",&"minesweeper"]:
			var opened: Dictionary = f.desktop.open_app(id)
			assert_true(opened.get("ok",false),str(opened))
			if not opened.get("ok",false): continue
			await _settle()
			var app: Control = opened.value.app
			assert_eq(app._palette,palette)
			assert_true(f.desktop.return_home().ok)
		assert_true(f.profile.set_preference(&"preferences.dark_mode.next_run_enabled",not dark).ok)
		assert_true(f.profile.set_preference(&"preferences.accessibility.text_size",150).ok)
		assert_true(f.locale.set_locale("zh_HK").ok)
		await _settle()
		assert_eq(f.desktop.theme.get_color("face","Desktop"),face)
		assert_eq(f.desktop.theme.default_font_size,36)
		for id: StringName in [&"schedule",&"shop",&"minesweeper"]:
			var cached: Control = f.desktop._cached_app_windows[id]
			var reopened: Dictionary = f.desktop.open_app(id)
			assert_true(reopened.get("ok",false),str(reopened))
			if not reopened.get("ok",false): continue
			await _settle()
			assert_same(reopened.value.app,cached)
			assert_eq(cached._palette,palette)
			assert_true(f.desktop.return_home().ok)
		assert_eq(f.state.capture_run_snapshot_input(),before,"Presentation never rewrites the captured run or board")
		f.desktop.hide()

func test_malformed_unavailable_replacement_and_changed_capture_are_refused_atomically() -> void:
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	add_child_autofree(desktop)
	var placeholder := GAME_STATE.new()
	autofree(placeholder)
	placeholder.reset_game()
	assert_false(desktop.configure_run_configuration(placeholder).ok)
	var owner := ConfigurationFixture.new()
	owner.answer.value.dark_mode = 1
	assert_false(desktop.configure_run_configuration(owner).ok)
	assert_false(desktop._run_configuration_ready)
	owner.answer.value.dark_mode = true
	assert_true(desktop.configure_run_configuration(owner).ok)
	var current: Theme = desktop.theme
	assert_false(desktop.configure_run_configuration(ConfigurationFixture.new()).ok)
	owner.answer.value.dark_mode = false
	assert_false(desktop.configure_run_configuration(owner).ok)
	assert_same(desktop.theme,current)
	assert_eq(desktop._run_palette,&"midnight")


class StartupFixture extends Node:
	signal application_ready()
	var available := false
	var configured_hosts := 0
	var configured_gameplay_hosts := 0
	func get_startup_state() -> Dictionary: return {"ready":available}
	func configure_contacts_desktop(_desktop: Control) -> Dictionary:
		configured_hosts += 1
		return {"ok":true}
	func configure_gameplay_desktop(_desktop: Control) -> Dictionary:
		configured_gameplay_hosts += 1
		return {"ok":true}

class InertQuickFixture extends Node:
	func observe_input(_event: InputEvent) -> void: pass
	func handle_input(_event: InputEvent) -> bool: return false

class EarlyDesktop extends ComputerDesktop:
	var startup: Node
	func _configure_from_bootstrap() -> void:
		_bootstrap = startup
		super._configure_from_bootstrap()

func test_early_production_bootstrap_path_stays_hidden_until_captured_palette_is_admitted() -> void:
	var run := make_captured_run(true)
	assert_true(run.get("ok",false),str(run))
	if not run.get("ok",false): return
	add_child_autofree(run.value.state)
	var startup := StartupFixture.new()
	add_child_autofree(startup)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(EarlyDesktop)
	desktop.startup = startup
	assert_true(desktop.configure_run_configuration(run.value.state).ok)
	# This test isolates only unrelated Backup/Quick initialization while running
	# the production readiness/captured-owner/masking method itself.
	desktop._backup_port = RefCounted.new()
	var quick := InertQuickFixture.new()
	add_child_autofree(quick)
	desktop._quick_commands = quick
	startup.application_ready.connect(desktop._configure_from_bootstrap)
	add_child_autofree(desktop)
	assert_false(desktop.visible,"The early production mount is masked synchronously before its first frame")
	assert_true(desktop._run_configuration_masked)
	assert_eq(startup.configured_hosts,0)
	assert_false(desktop.open_app(&"shop").ok,"No route may be admitted during readiness masking")
	await _settle()
	assert_false(desktop.is_visible_in_tree())
	startup.available = true
	startup.application_ready.emit()
	assert_true(desktop.visible)
	assert_false(desktop._run_configuration_masked)
	assert_eq(desktop.theme.get_color("face","Desktop"),Color("14201d"))
	assert_eq(desktop.theme.get_color("habitat","Desktop"),Color("0d1514"))
	assert_eq(startup.configured_hosts,1)
	assert_eq(startup.configured_gameplay_hosts,1,
		"Gameplay desktop wiring follows the Contacts owner on the same ready signal.")
	assert_true(desktop._cached_app_windows.is_empty())
	await _settle()
	assert_same(desktop.get_viewport().gui_get_focus_owner(), desktop.launcher_buttons[&"minesweeper"], "Delayed readiness gives the visible launcher its initial native focus")
