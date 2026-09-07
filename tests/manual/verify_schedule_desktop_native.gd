extends SceneTree
## Isolated real desktop/draft-owner rendering; names are fixture copy, Done is absent.
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const PORT := preload("res://scripts/application/schedule/SchedulePresentationPort.gd")
const VIEW := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const FIXTURES := preload("res://tests/manual/verify_quick_status_native.gd")

class DesktopFixture extends ComputerDesktop:
	func _configure_from_bootstrap() -> void: pass

class DraftSource extends RefCounted:
	var contacts := CONTACTS.make_defaults()
	var day := 3

class Preferences extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var percent := 100
	var large := false
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		if path == &"preferences.accessibility.text_size": return percent
		if path == &"preferences.accessibility.large_targets": return large
		return fallback
	func present(size_percent: int, large_targets: bool) -> void:
		percent = size_percent
		large = large_targets
		preference_changed.emit(&"preferences.accessibility.text_size",percent)
		preference_changed.emit(&"preferences.accessibility.large_targets",large)

var _failures: Array[String] = []
var _checks := 0
var _samples: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok: _failures.append(label)
	return ok
func _run() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/schedule_desktop_native")
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400,360)
	viewport.size_2d_override = Vector2i(800,720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var profile := Preferences.new()
	var locale := FIXTURES.CatalogLocale.new()
	viewport.add_child(profile)
	viewport.add_child(locale)
	locale.present("en")
	var host := HOST.new()
	host.reset(3)
	var loaded := REGISTRY.load_current()
	var draft := VIEW.new()
	_check(draft.configure(loaded.value.registry,RULES,loaded.value.registry_fingerprint).ok,"real draft configuration")
	_check(draft.open_day(3,"native-docket-day").ok,"real day open")
	var issuer := ISSUER.new()
	_check(issuer.configure(ROOT_STORE.new("73".repeat(32),23)).ok,"isolated issuer")
	var names := {"training":{"en":"Training","zh-CN":"训练","zh-HK":"訓練"},
		"working":{"en":"Working","zh-CN":"工作","zh-HK":"工作"},"rest":{"en":"Rest","zh-CN":"休息","zh-HK":"休息"}}
	var port := PORT.new()
	_check(port.configure(DraftSource.new(),draft,loaded.value.registry,loaded.value.registry_fingerprint,issuer,names).ok,"real projection")
	for id: String in ["training","working","rest"]:
		var projected: Dictionary = port.project("en")
		_check(port.append(id,projected.value.fingerprint,"en").ok,"real fixture append")
	var before: Dictionary = draft.snapshot().duplicate(true)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(DesktopFixture)
	viewport.add_child(desktop)
	_check(desktop.configure_schedule(port,locale,profile,host,3).ok,"desktop owner injection")
	_check(desktop.open_app(&"schedule").ok,"desktop Schedule open")
	var app: Control = desktop._cached_app_windows[&"schedule"]
	for language: String in ["en","zh_CN","zh_HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				_check(locale.present(language),"locale catalog")
				_check("?" not in str(names.training[language.replace("_","-")]),"fixture UTF-8 names")
				profile.present(percent,large)
				for frame in 4: await process_frame
				var selected: String = str(app._projection.entries[1].id)
				app.panel.selected_id = selected
				app.refresh_view(true)
				for frame in 3: await process_frame
				app.panel.focus_target("entry:"+selected)
				for frame in 3: await RenderingServer.frame_post_draw
				_check(app.panel._font_size == int(20 * percent / 100.0),"unshrunk text size")
				_check(app.panel._large == large,"large-target preference")
				_check(app.panel.get_global_rect() == Rect2(0,64,800,656),"mounted docket bounds")
				_check(not app.get_node("VBoxContainer/TopBar").visible,"one shared top bar")
				_check(app.panel.done_button.disabled,"no invented Done owner")
				_check(app.panel.entry_buttons[selected].has_focus(),"semantic entry focus")
				_check(draft.snapshot() == before,"render reflow preserves draft bytes")
				var filename := "%s-%d-%s.png" % [language,percent,"large" if large else "ordinary"]
				var pixels := viewport.get_texture().get_image()
				_check(pixels != null and not pixels.is_empty(),"native pixels")
				_check(pixels.save_png(folder.path_join(filename)) == OK,"capture saved")
				_samples.append({"locale":language,"percent":percent,"large_targets":large,"path":filename,
					"font_size":app.panel._font_size,"selected_id":selected,"native_size":[400,360],"draft_unchanged":draft.snapshot()==before})
	var result := {"ok":_failures.is_empty(),"checks":_checks,"samples":_samples,"failures":_failures,
		"captures":_samples.size(),"fixture":"Real injected desktop and draft owners, ordinary-action fixture names, isolated issuer, no player data or Done owner."}
	var file := FileAccess.open(folder.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	for failure in _failures: printerr(failure)
	print("SCHEDULE_DESKTOP_NATIVE_VERIFIED tuples=",_samples.size()," checks=",_checks) if _failures.is_empty() else printerr("SCHEDULE_DESKTOP_NATIVE_FAILED")
	viewport.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)
