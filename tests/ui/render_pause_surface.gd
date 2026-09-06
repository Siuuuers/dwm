extends SceneTree
## Presentation evidence only: real Pause controls/catalogs, no story art or fake hosts.
const SURFACE := preload("res://scenes/overlay/PauseSurface.tscn")
const LOCALES := {"en":"en","zh_CN":"zh-CN","zh_HK":"zh-HK"}
const PRESETS := ["standard","protan","deutan","tritan"]
const COPY_KEYS := ["continue","backup","settings","return","title","question","warning","cancel"]
var _viewport: SubViewport
var _surface: Control
var _folder := ""
var _records: Array[Dictionary] = []
var _captures := 0
var _failure := ""

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/pause_surface")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"cannot create evidence directory"):
		_finish(false)
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640,360)
	_viewport.size_2d_override = Vector2i(1280,720)
	_viewport.size_2d_override_stretch = true
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_surface = SURFACE.instantiate()
	_viewport.add_child(_surface)
	for catalog_locale: String in LOCALES:
		var copy := _read_copy(catalog_locale)
		if copy.is_empty():
			_finish(false)
			return
		for percent: int in [100,125,150]:
			for palette: String in ["AfterHours","Midnight"]:
				for high: bool in [false,true]:
					for preset: String in PRESETS:
						var representative := percent == 150 and high and palette == ("Midnight" if catalog_locale == "zh_HK" else "AfterHours")
						var capture := (not high and preset == "standard") or representative
						if not await _fixture(catalog_locale,percent,palette,high,preset,false,copy,"return",capture):
							_finish(false)
							return
	if not _check(_records.size() == 144,"incomplete ordinary-target tuple matrix"):
		_finish(false)
		return
	if OS.get_cmdline_user_args().has("--pause-large"):
		for catalog_locale: String in LOCALES:
			for percent: int in [100,125,150]:
				for palette: String in ["AfterHours","Midnight"]:
					if not await _fixture(catalog_locale,percent,palette,false,"standard",true,_read_copy(catalog_locale),"return",true):
						_finish(false)
						return
	if not await _fixture("en",100,"AfterHours",false,"standard",false,_read_copy("en"),"continue",true):
		_finish(false)
		return
	_finish(true)

func _read_copy(catalog_locale: String) -> Dictionary:
	var path := "res://localization/ui/%s.json" % catalog_locale
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(parsed is Dictionary and parsed.get("messages") is Array,"invalid real locale catalog: "+path): return {}
	var result: Dictionary = {}
	for message: Dictionary in parsed.messages:
		var key := str(message.get("id",""))
		if key.begins_with("ui.pause."):
			var short_key := key.trim_prefix("ui.pause.")
			if short_key in COPY_KEYS: result[short_key] = message.get("text","")
	for key: String in COPY_KEYS:
		if not _check(typeof(result.get(key)) == TYPE_STRING and not str(result[key]).strip_edges().is_empty(),"missing real catalog key ui.pause."+key+" in "+path): return {}
	return result

func _fixture(catalog_locale: String, percent: int, palette: String, high: bool, preset: String,
		large: bool, copy: Dictionary, mode: String, capture: bool) -> bool:
	_surface.close_surface()
	if not _check(_surface.configure_presentation(LOCALES[catalog_locale],percent,palette,high,preset,large),"presentation tuple rejected"): return false
	if not _check(_surface.configure_copy(copy),"real catalog copy rejected"): return false
	_surface.open_surface()
	if mode == "return":
		_surface.rows[&"return"].grab_focus()
		var press := InputEventKey.new()
		press.keycode = KEY_RIGHT
		press.pressed = true
		_viewport.push_input(press,true)
		var release := InputEventKey.new()
		release.keycode = KEY_RIGHT
		_viewport.push_input(release,true)
	await _frames()
	if not _check(_surface.size == Vector2(1280,720),"logical canvas changed"): return false
	if not _check(_surface.context_strip.position == Vector2(480,0) and _surface.context_strip.size == Vector2(800,64),"context strip partition changed"): return false
	if not _check(_surface.workfield.position == Vector2(480,64) and _surface.workfield.size == Vector2(800,656),"workfield partition changed"): return false
	var row_geometry: Array[Dictionary] = []
	for index: int in _surface.ACTIONS.size():
		var id: StringName = _surface.ACTIONS[index]
		var row: Button = _surface.rows[id]
		if not _check(row.position == Vector2(32,32+112*index) and row.size == Vector2(416,96),"four-row allocation changed"): return false
		if not _check(row.public_copy == copy[id] and row.accessibility_name == copy[id],"row copy changed or was truncated"): return false
		if not _check(row.theme.default_font_size == int(24*percent/100.0) and row._text_height <= 64,"full-size row text does not fit"): return false
		row_geometry.append({"action":id,"rect":_rect(row),"copy":row.public_copy,"text_height":row._text_height,
			"lines":row._paragraph.get_line_count(),"face_inset":row._inset})
	var details: Dictionary = {}
	if mode == "return":
		if not _check(_surface.entered_action == &"return" and _surface.cancel_button.has_focus(),"native Right did not enter Return with Cancel focus"): return false
		if not _check(_surface._question.text == copy.question and _surface._warning.text == copy.warning,"confirmation copy changed"): return false
		var warning_scroll: ScrollContainer = _surface.confirmation.get_node("WarningScroll")
		var column: Control = warning_scroll.get_child(0)
		for label: Label in [_surface._question,_surface._warning]:
			if not _check(label.size.y >= label.get_minimum_size().y,"confirmation label clipped vertically"): return false
			if not _check(label.get_theme_default_font_size() == int(24*percent/100.0),"confirmation silently changed font size"): return false
			if not _check(label.size.x <= warning_scroll.size.x,"confirmation requires horizontal scrolling"): return false
		var bar := warning_scroll.get_v_scroll_bar()
		if not _check(column.size.y <= warning_scroll.size.y or bar.max_value > bar.page,"overflow copy has no vertical scroll range"): return false
		details = {"question":copy.question,"warning":copy.warning,"question_rect":_rect(_surface._question),
			"warning_rect":_rect(_surface._warning),"scroll_rect":_rect(warning_scroll),
			"scroll_extent":maxf(0,bar.max_value-bar.page),"all_copy_fits_without_scroll":column.size.y <= warning_scroll.size.y,
			"cancel_rect":_rect(_surface.cancel_button),"return_rect":_rect(_surface.return_button)}
	else:
		if not _check(not _surface.context_strip.visible and not _surface.workfield.visible and _surface.rows[&"continue"].has_focus(),"Continue must leave the right surface absent"): return false
	var name := "%s-%d-%s-%s-%s-%s-%s.png" % [catalog_locale,percent,palette,"high" if high else "standard",preset,"large" if large else "ordinary",mode]
	var path := ""
	if capture:
		var pixels := _viewport.get_texture().get_image()
		if not _check(pixels != null and pixels.get_size() == Vector2i(640,360),"capture is not native 640x360"): return false
		if not _check(_same_color(pixels.get_pixel(2,2),_surface.theme.get_color(&"face",&"Pause")),"opaque action-pane pixel differs from exact palette role"): return false
		path = _folder.path_join(name)
		if not _check(pixels.save_png(path) == OK,"cannot save Pause image"): return false
		_captures += 1
	_records.append({"locale":LOCALES[catalog_locale],"catalog_path":"res://localization/ui/%s.json" % catalog_locale,
		"text_percent":percent,"font_size":int(24*percent/100.0),"palette":palette,"high_contrast":high,
		"colour_preset":preset,"large_targets":large,"mode":mode,"native_size":[640,360],"logical_size":[1280,720],
		"rows":row_geometry,"confirmation":details,"focus":String(_viewport.gui_get_focus_owner().name),"path":path})
	return true

func _rect(control: Control) -> Array:
	return [control.position.x,control.position.y,control.size.x,control.size.y]

func _same_color(actual: Color, expected: Color) -> bool:
	return absf(actual.r-expected.r) <= 1.1/255 and absf(actual.g-expected.g) <= 1.1/255 and absf(actual.b-expected.b) <= 1.1/255 and actual.a >= 0.999

func _frames() -> void:
	for frame in 3: await RenderingServer.frame_post_draw

func _check(ok: bool, message: String) -> bool:
	if not ok:
		if _failure.is_empty(): _failure = message
		push_error("PAUSE_SURFACE_RENDER_FAILED: "+message)
	return ok

func _finish(ok: bool) -> void:
	var report := FileAccess.open(_folder.path_join("pause-measurements.json"),FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"ok":ok,"failure":_failure,
			"scope":"Actual service-free PauseSurface and localized catalog copy only; no complete Pause lifecycle, assistive technology, hosted-app, or authored-story acceptance.",
			"source_art":"Absent. Transparent viewport beneath decorative veil; no replacement scene artwork.",
			"geometry_space":"Control rectangles are logical coordinates relative to their actual parent; PNGs are native 640x360.",
			"requested_ordinary_return_tuples":144,"captures":_captures,"measurements":_records.size(),"samples":_records},"\t")+"\n")
		report.close()
	else:
		ok = false
		push_error("PAUSE_SURFACE_RENDER_FAILED: cannot write report")
	if is_instance_valid(_viewport): _viewport.queue_free()
	print("PAUSE_SURFACE_RENDER_", "VERIFIED" if ok else "FAILED", " captures=",_captures," measurements=",_records.size()," evidence=",_folder)
	quit(0 if ok else 1)
