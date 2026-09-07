extends SceneTree
## Geometry-only evidence. Explicit nine-record projection; no save or restore is invoked.
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const EDGE := preload("res://scripts/ui/desktop/QuickStatusEdge.gd")
const KEYS: Array[StringName] = [&"saving",&"saved",&"unavailable",&"please_wait"]

class ProfileFixture extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var percent := 100
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return percent if path == &"preferences.accessibility.text_size" else fallback
	func present(value: int) -> void:
		percent = value
		preference_changed.emit(&"preferences.accessibility.text_size",value)

class CatalogLocale extends Node:
	signal locale_changed(locale: String)
	var locale := "en"
	var copy: Dictionary = {}
	func present(value: String) -> bool:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/%s.json" % value))
		if not raw is Dictionary or not raw.get("messages") is Array: return false
		copy.clear()
		for message: Dictionary in raw.messages: copy[str(message.id)] = str(message.text)
		locale = value
		locale_changed.emit(value)
		return true
	func get_locale() -> String: return locale
	func has_key(key: String) -> bool: return copy.has(key)
	func t(key: String, parameters: Dictionary = {}) -> String:
		var result := str(copy.get(key,key))
		for parameter: Variant in parameters: result = result.replace("{%s}" % parameter,str(parameters[parameter]))
		return result

class RecordsFixture extends RefCounted:
	signal projection_changed()
	var calls := 0
	func get_projection() -> Dictionary:
		var records: Array[Dictionary] = []
		for locator: String in ["autosave","quick","slot:1","slot:2","slot:3","slot:4","slot:5","slot:6","slot:7"]:
			records.append({"locator":locator,"state":"occupied","day":2,"saved_time":"09:07",
				"fallback":false,"load_day":2,"load_saved_time":"09:07","reason":"",
				"actions":{"save":locator != "autosave","load":true,"delete":true}})
		return {"ok":true,"value":{"records":records,"save_capability":{"enabled":true,"reason":""}}}
	func prepare_action(_action: String, _locator: String) -> Dictionary:
		calls += 1
		return {"ok":false,"code":&"geometry_fixture_has_no_commands"}
	func commit_action(_token: String) -> Dictionary:
		calls += 1
		return {"ok":false,"code":&"geometry_fixture_has_no_commands"}
	func cancel_action(_token: String) -> void: calls += 1

var _view: SubViewport
var _desktop: Control
var _backup: Control
var _edge: Label
var _locale: CatalogLocale
var _profile: ProfileFixture
var _port := RecordsFixture.new()
var _folder := ""
var _records: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks := 0
var _captures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/quick_status_native")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"evidence directory unavailable"):
		_finish()
		return
	_view = SubViewport.new()
	_view.size = Vector2i(400,360)
	_view.size_2d_override = Vector2i(800,720)
	_view.size_2d_override_stretch = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_profile = ProfileFixture.new()
	_locale = CatalogLocale.new()
	_view.add_child(_profile)
	_view.add_child(_locale)
	if not _check(_locale.present("en"),"real locale catalog missing"):
		_finish()
		return
	var host := HOST.new()
	host.reset(2)
	_desktop = DESKTOP.instantiate()
	_desktop._host_state = host
	_desktop._day = 2
	_desktop._localization = _locale
	_desktop._profile = _profile
	for child: Node in _desktop.get_children():
		if child.name == &"LocalePresentationRoot" or String(child.name).begins_with("L10n"):
			child.set("_localization",_locale)
	_view.add_child(_desktop)
	_desktop.configure_clock(func(): return {"hour":9,"minute":7,"second":0})
	if not _check(_desktop.configure_backup_port(_port).get("ok",false),"real Backup port configuration refused"):
		_finish()
		return
	if not _check(_desktop.open_app(&"backup").get("ok",false),"actual Desktop did not open Backup"):
		_finish()
		return
	_backup = _desktop._cached_app_windows[&"backup"]
	_edge = EDGE.new()
	_desktop.add_child(_edge)
	_edge.set_process(false)
	for locale: String in ["en","zh_CN","zh_HK"]:
		for percent: int in [100,125,150]:
			if not await _sample(locale,percent):
				_finish()
				return
	_check(_records.size() == 36,"incomplete 36-tuple matrix")
	_check(_port.calls == 0,"geometry fixture unexpectedly attempted an operation")
	_finish()

func _sample(locale: String, percent: int) -> bool:
	_edge.clear_status()
	if not _check(_locale.present(locale),"real locale catalog missing: "+locale): return false
	_profile.present(percent)
	# This geometry-only fixture does not construct the production command router.
	_desktop._refresh_launcher()
	_backup.drawer_buttons["slot:3"].grab_focus()
	await _frames()
	var focus: Control = _view.gui_get_focus_owner()
	var selected: String = _backup.selected_locator
	var local_status: String = _backup.status_label.text
	var rect: Rect2 = _desktop.quick_status_safe_rect()
	_check(rect == Rect2(480,80,304,64),"actual Backup safe region changed")
	_check(_desktop.size == Vector2(800,720),"logical desktop dimensions changed")
	var protected: Array[Control] = [_backup.info_scroll,_backup.action_dock,_backup.status_region]
	for mode: Control in _backup.mode_buttons.values(): protected.append(mode)
	for control: Control in protected:
		_check(not rect.intersects(control.get_global_rect()),"edge overlaps actual Backup information/mode/action/status")
	var baseline: Image = _view.get_texture().get_image()
	for key: StringName in KEYS:
		_edge.clear_status()
		_edge.set_presentation(locale,percent)
		_edge.position = rect.position
		_edge.size = rect.size
		_edge.set_eligible(true)
		_edge.publish_status(key,{"fixture":true,"tuple":_records.size()},func(): return true)
		await _frames()
		_check(_edge.is_visible_in_tree(),"edge did not publish")
		_check(_edge.get_theme_default_font_size() == int(24*percent/100.0),"edge font shrank")
		_check(_edge.size.y >= _edge.get_minimum_size().y and _edge.size == rect.size,"full copy does not fit safe allocation")
		_check(_edge.max_lines_visible == -1 and not _edge.clip_text,"edge truncates copy")
		_check(_edge.text == EDGE.COPY[locale.replace("_","-")][key] and _edge.accessibility_name == _edge.text,"edge public copy changed")
		_check(_edge.get_child_count() == 0 and _edge.focus_mode == Control.FOCUS_NONE and _edge.mouse_filter == Control.MOUSE_FILTER_IGNORE,"edge gained interactive/decorative children")
		_check(_view.gui_get_focus_owner() == focus and _backup.selected_locator == selected,"publication changed focus/selection")
		_check(_backup.status_label.text == local_status and local_status.is_empty(),"edge publication created local status twin")
		var pixels: Image = _view.get_texture().get_image()
		_check(pixels.get_size() == Vector2i(400,360),"image is not native 400x360")
		# The blank lower/right strips must retain the actual underlying pixels:
		# no new card, perimeter, backing plane or unrelated content mutation.
		var unchanged := true
		for x: int in range(240,392):
			for y: int in [70,71]:
				unchanged = unchanged and pixels.get_pixel(x,y) == baseline.get_pixel(x,y)
		for y: int in range(40,72):
			for x: int in [390,391]:
				unchanged = unchanged and pixels.get_pixel(x,y) == baseline.get_pixel(x,y)
		_check(unchanged,"edge blank strips acquired background/card pixels")
		var path := ""
		if key == &"unavailable" or (key == &"saved" and locale == "en" and percent == 100):
			path = _folder.path_join("%s-%d-%s.png" % [locale,percent,key])
			_check(pixels.save_png(path) == OK,"PNG write failed")
			_captures += 1
		_records.append({"locale":locale,"text_percent":percent,"key":key,"copy":_edge.text,
			"font_size":_edge.get_theme_default_font_size(),"safe_rect":_rect(_edge),"minimum_height":_edge.get_minimum_size().y,
			"information_rect":_rect(_backup.info_scroll),"dock_rect":_rect(_backup.action_dock),
			"selected_locator":selected,"focus_name":focus.name if focus != null else "","local_status":local_status,
			"blank_strips_unchanged":unchanged,"path":path})
	return _failures.is_empty()

func _frames() -> void:
	for frame in 3: await RenderingServer.frame_post_draw

func _rect(control: Control) -> Array:
	var rect := control.get_global_rect()
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("QUICK_STATUS_NATIVE_FAILED: "+message)
	return condition

func _finish() -> void:
	var report := FileAccess.open(_folder.path_join("quick-status-measurements.json"),FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"ok":_failures.is_empty(),"failures":_failures,"checks":_checks,"captures":_captures,
			"scope":"Native rendering of real Desktop/Backup/QuickStatusEdge with explicit mocked record facts; no command, durability, restore, collision arbitration or OS assistive-technology acceptance.",
			"fixture":"Nine synthetic occupied records, no player files. Real DesktopAppHostState, real locale catalogs, current font themes.",
			"native_size":[400,360],"logical_size":[800,720],"requested_tuples":36,"samples":_records},"\t")+"\n")
		report.close()
	else: _check(false,"report write failed")
	print("QUICK_STATUS_NATIVE_", "VERIFIED" if _failures.is_empty() else "FAILED", " tuples=",_records.size()," captures=",_captures," evidence=",_folder)
	if is_instance_valid(_view): _view.queue_free()
	quit(0 if _failures.is_empty() else 1)
