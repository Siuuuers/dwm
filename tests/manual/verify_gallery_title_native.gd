extends SceneTree
## Run in the root-owned isolated rendering wrapper. No profile files or replay owner.
const MENU := preload("res://scenes/menu/MenuScene.tscn")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")

class PublicProfile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	signal gallery_changed(ending_id: String, unlocked: bool)
	signal profile_restored(snapshot: Dictionary)
	var percent := 100
	var midnight := false
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		match path:
			&"preferences.accessibility.text_size": return percent
			&"preferences.dark_mode.available": return true
			&"preferences.dark_mode.next_run_enabled": return midnight
		return fallback
	func get_gallery_discovery_snapshot() -> Dictionary:
		# Explicit synthetic discovery fixture, never claimed as player entitlement.
		return {"ok":true,"value":{"revision":1,"ending_ids":SCHEMA.ENDING_IDS.duplicate()}}
	func present(size_percent: int, dark: bool) -> void:
		percent = size_percent
		midnight = dark
		preference_changed.emit(&"preferences.accessibility.text_size", percent)
		preference_changed.emit(&"preferences.dark_mode.next_run_enabled", midnight)

class CatalogLocale extends Node:
	signal locale_changed(locale_id: String)
	var locale := "en"
	var messages: Dictionary = {}
	func present(id: String) -> bool:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/%s.json" % id))
		if not raw is Dictionary or not raw.get("messages") is Array: return false
		var next := {}
		for entry: Dictionary in raw.messages: next[str(entry.id)] = str(entry.text)
		messages = next
		locale = id
		locale_changed.emit(id)
		return true
	func get_locale() -> String: return locale
	func has_key(key: String) -> bool: return messages.has(key)
	func t(key: String, parameters: Dictionary = {}) -> String:
		var copy := str(messages.get(key,key))
		for parameter: Variant in parameters: copy = copy.replace("{%s}" % parameter,str(parameters[parameter]))
		return copy

var _view: SubViewport
var _menu: Control
var _profile: PublicProfile
var _locale: CatalogLocale
var _folder := ""
var _records: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks := 0
var _captures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/gallery_title_native")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"evidence directory unavailable"):
		_finish()
		return
	_view = SubViewport.new()
	_view.size = Vector2i(640,360)
	_view.size_2d_override = Vector2i(1280,720)
	_view.size_2d_override_stretch = true
	_view.handle_input_locally = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_profile = PublicProfile.new()
	_locale = CatalogLocale.new()
	_view.add_child(_profile)
	_view.add_child(_locale)
	if not _check(_locale.present("en"),"real English catalog unavailable"):
		_finish()
		return
	_menu = MENU.instantiate()
	_menu.configure_settings_services({"profile":_profile,"localization":_locale})
	_view.add_child(_menu)
	await _frames()
	for locale: String in ["en","zh_CN","zh_HK"]:
		for percent: int in [100,125,150]:
			for palette: String in ["AfterHours","Midnight"]:
				if not await _sample(locale,percent,palette):
					_finish()
					return
	_check(_records.size() == 18,"incomplete locale/size/Standard-palette matrix")
	_finish()

func _sample(locale: String, percent: int, palette: String) -> bool:
	if not _check(_locale.present(locale),"real catalog unavailable: "+locale): return false
	_profile.present(percent,palette == "Midnight")
	await _menu._on_gallery_pressed()
	await _frames()
	var gallery: Control = _menu._gallery_instance
	if not _check(is_instance_valid(gallery) and gallery.is_visible_in_tree(),"real Menu did not mount Gallery"): return false
	var cached_id := gallery.get_instance_id()
	var rows: GridContainer = gallery.get_node("%EndingTileGrid")
	var index: Control = gallery.get_node("%IndexViewport")
	var status: Label = gallery.get_node("%ReplayStatus")
	var replay: Button = gallery.get_node("%ReplayButton")
	var home: Button = _menu._title_home
	_check(gallery._return_button == home and home.is_visible_in_tree(),"Gallery does not share Title Return")
	_check(not gallery.get_node("TitleChrome").visible,"duplicate Gallery title chrome is visible")
	_check(_menu.size == Vector2(1280,720),"logical title size changed")
	_check(rows.get_child_count() == SCHEMA.ENDING_IDS.size(),"discovery-only fixture count changed")
	if rows.get_child_count() == 0: return false
	_check(rows.get_child(0).has_focus(),"Gallery entry did not focus first native row")
	_check(replay.disabled and replay.focus_mode == Control.FOCUS_NONE,"Replay falsely enabled or traversable without owner")
	var expected := _locale.t("gallery.record.unavailable")
	_check(expected != "gallery.record.unavailable","catalog lacks truthful unavailable copy")
	var measurements: Array[Dictionary] = []
	for row: Button in rows.get_children():
		var caption: Label = row.caption
		_check(row.text == expected and row.accessibility_name == expected and caption.text == expected,"record copy is not complete public unavailable copy")
		_check(caption.get_theme_default_font_size() == int(24*percent/100.0),"record font shrank")
		_check(caption.max_lines_visible == -1 and not caption.clip_text,"caption truncation enabled")
		_check(caption.size.y >= caption.get_minimum_size().y,"caption minimum height clipped")
		_check(row.get_global_rect().encloses(caption.get_global_rect()),"wrapped caption escapes its row")
		_check(row.size.x == 296 and row.size.y >= 80,"record target geometry changed")
		measurements.append({"row":measurements.size(),"rect":_rect(row),"caption_rect":_rect(caption),
			"font_size":caption.get_theme_default_font_size(),"copy":caption.text,"line_count":caption.get_line_count()})
	_check(status.text == expected and status.size.y >= status.get_minimum_size().y,"unavailable leaf text clipped or changed")
	_check(status.get_theme_default_font_size() == int(24*percent/100.0),"unavailable leaf font shrank")
	_check(Rect2(Vector2.ZERO,gallery._canvas.size).encloses(Rect2(status.position,status.size)),"unavailable leaf escapes workfield")
	_audit_public_text(_menu)
	for row_index in range(1,rows.get_child_count()): await _key(KEY_DOWN)
	await _frames()
	var last: Button = rows.get_child(rows.get_child_count()-1)
	_check(last.has_focus() and last.selected,"native Down did not reach/select final row")
	var selected_count := 0
	for row: Button in rows.get_children():
		if row.selected: selected_count += 1
	_check(selected_count == 1,"selection is not singular")
	_check(gallery._index_offset > 0,"overflow index did not scroll for focused row")
	_check(index.get_global_rect().encloses(last.get_global_rect()),"focused final row is clipped")
	var offset: float = gallery._index_offset
	var name := "%s-%d-%s-scrolled.png" % [locale,percent,palette]
	var path := _capture(name)
	await _key(KEY_TAB)
	_check(home.has_focus(),"Tab from final row does not reach shared Title Return")
	_check(last.selected and is_equal_approx(gallery._index_offset,offset),"Return focus changed selection or index offset")
	if _records.is_empty(): _capture("en-100-AfterHours-title-return.png")
	await _key(KEY_ENTER)
	_check(not gallery.is_visible_in_tree() and _menu._gallery_button.has_focus(),"native Return did not restore Gallery ledger focus")
	await _menu._on_gallery_pressed()
	await _frames()
	_check(_menu._gallery_instance.get_instance_id() == cached_id,"Gallery reopen replaced cached instance")
	_records.append({"locale":locale,"text_percent":percent,"palette":palette,"high_contrast":false,"colour_preset":"standard",
		"native_size":[640,360],"logical_size":[1280,720],"row_count":rows.get_child_count(),"rows":measurements,
		"index_rect":_rect(index),"index_extent":gallery._index_extent,"scrolled_offset":offset,
		"status_copy":status.text,"status_rect":_rect(status),"shared_return_rect":_rect(home),"path":path})
	return _failures.is_empty()

func _audit_public_text(node: Node) -> void:
	if node is Control and node.is_visible_in_tree():
		var copies: Array[String] = [node.accessibility_name,node.accessibility_description,node.tooltip_text]
		if node is Label or node is Button: copies.append(node.text)
		for copy: String in copies:
			for id: String in SCHEMA.ENDING_IDS:
				_check(not copy.contains(id),"private ending locator leaked into visible/accessible copy")
	for child: Node in node.get_children(): _audit_public_text(child)

func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_view.push_input(event,true)
		await process_frame
	await _frames()

func _frames() -> void:
	for frame in 3: await RenderingServer.frame_post_draw

func _rect(control: Control) -> Array:
	var rect := control.get_global_rect()
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _capture(name: String) -> String:
	var pixels := _view.get_texture().get_image()
	if not _check(pixels != null and pixels.get_size() == Vector2i(640,360),"native image unavailable"): return ""
	var path := _folder.path_join(name)
	if not _check(pixels.save_png(path) == OK,"PNG write failed"): return ""
	_captures += 1
	return path

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("GALLERY_TITLE_NATIVE_FAILED: "+message)
	return condition

func _finish() -> void:
	var report := FileAccess.open(_folder.path_join("gallery-measurements.json"),FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"ok":_failures.is_empty(),"failures":_failures,"checks":_checks,
			"scope":"Actual Menu/Gallery rendering, native keyboard focus and tree accessibility strings; no replay, metadata, OS assistive technology or complete Gallery acceptance.",
			"fixture":"In-memory mock public Profile explicitly reports all canonical discoveries. No public ending metadata/version or player entitlement is inferred. Real locale catalogs and production font themes.",
			"geometry_space":"Global logical rectangles; screenshots are native 640x360.","requested_tuples":18,
			"captures":_captures,"samples":_records},"\t")+"\n")
		report.close()
	else: _check(false,"report write failed")
	print("GALLERY_TITLE_NATIVE_", "VERIFIED" if _failures.is_empty() else "FAILED", " captures=",_captures," tuples=",_records.size()," evidence=",_folder)
	if is_instance_valid(_view): _view.queue_free()
	quit(0 if _failures.is_empty() else 1)
