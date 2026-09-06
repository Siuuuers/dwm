extends SceneTree
## Native presentation evidence: real Pause/Backup/confirmation controls and production
## localized copy. The operation projection is explicitly a double; no storage is mounted.

const SURFACE := preload("res://scenes/overlay/PauseSurface.tscn")
const BACKUP := preload("res://scenes/apps/BackupApp.tscn")
const OPERATIONS := preload("res://tests/backup_ui/test_backup_ui.gd")
const FIXTURES := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const LOCALES := {"en": "en", "zh_CN": "zh-CN", "zh_HK": "zh-HK"}
const COPY_KEYS := ["continue", "backup", "settings", "return", "title", "question", "warning", "cancel"]

var _viewport: SubViewport
var _surface: Control
var _app: Control
var _port: RefCounted
var _locale: Node
var _profile: RefCounted
var _folder := ""
var _failure := ""
var _records: Array[Dictionary] = []
var _cancel_restores := 0

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/pause_backup")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "cannot create evidence directory"):
		await _finish(false)
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.size_2d_override = Vector2i(1280, 720)
	_viewport.size_2d_override_stretch = true
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	for catalog_locale: String in LOCALES:
		for percent: int in [100, 125, 150]:
			if not await _fixture(catalog_locale, percent):
				await _finish(false)
				return
	if not _check(_records.size() == 27 and _cancel_restores == 18, "incomplete nine-tuple capture or Cancel restoration matrix"):
		await _finish(false)
		return
	await _finish(true)

func _fixture(catalog_locale: String, percent: int) -> bool:
	await _unmount()
	_locale = FIXTURES.FakeLocale.new()
	_locale.locale = LOCALES[catalog_locale]
	_profile = FIXTURES.FakeProfile.new()
	_profile.font_scale = percent / 100.0
	_port = OPERATIONS.FakeBackupPort.new()
	var original_records: Array = _port.records.duplicate(true)
	_surface = SURFACE.instantiate()
	_viewport.add_child(_surface)
	var copy := _read_pause_copy(catalog_locale)
	if copy.is_empty(): return false
	if not _check(_surface.configure_presentation(LOCALES[catalog_locale], percent, "AfterHours"), "Pause tuple refused"): return false
	if not _check(_surface.configure_copy(copy), "Pause catalog copy refused"): return false
	_app = BACKUP.instantiate()
	if not _check(_app.configure_backup(_port, _locale, _profile).get("ok", false), "Backup fixture configuration refused"): return false
	if not _check(_surface.set_host(&"backup", _app), "Pause refused the actual Backup scene"): return false
	_surface.open_surface()
	_surface.rows[&"backup"].grab_focus()
	await _key(KEY_RIGHT)
	if not _check(_surface.entered_action == &"backup", "native Right failed to enter Backup"): return false
	_app.mode_buttons.load.grab_focus()
	await _key(KEY_ENTER)
	if not _check(_app.active_mode == "load", "native Enter failed to select Load"): return false
	_app.drawer_buttons["slot:2"].grab_focus()
	await _key(KEY_ENTER)
	if not _check(_app.selected_locator == "slot:2", "occupied drawer selection failed"): return false
	if not _check(_port.prepared.is_empty() and _port.committed.is_empty(), "mode/drawer selection performed an operation"): return false
	if not await _capture(catalog_locale, percent, "backup"): return false
	_app.action_buttons.delete.grab_focus()
	await _key(KEY_ENTER)
	if not _check(is_instance_valid(_app.confirmation), "native Delete did not open the shared confirmation"): return false
	if not await _capture(catalog_locale, percent, "delete-confirmation"): return false
	for index in 4:
		await _key(KEY_TAB)
		if not _check(_app.confirmation.is_ancestor_of(_viewport.gui_get_focus_owner()), "confirmation Tab escaped its exclusive focus scope"): return false
	await _key(KEY_ESCAPE)
	if not _check(not is_instance_valid(_app.confirmation) and _app.action_buttons.delete.has_focus(), "Cancel failed to restore Delete focus"): return false
	if not _check(_surface.entered_action == &"backup" and _port.cancelled.size() == 1 and _port.records == original_records, "confirmation Cancel changed host/records or failed to retire consent"): return false
	_cancel_restores += 1
	await _key(KEY_ENTER)
	if not _check(is_instance_valid(_app.confirmation) and _app.confirmation.cancel_button.has_focus(), "fresh Delete did not begin with fresh Cancel focus"): return false
	_port.reject_commit = true
	await _key(KEY_TAB)
	if not _check(_app.confirmation.confirm_button.has_focus(), "native Tab failed to select final Delete"): return false
	await _key(KEY_ENTER)
	if not _check(not is_instance_valid(_app.confirmation) and _app.action_buttons.has("cancel"), "rejected fixture commit failed to enter recovery"): return false
	if not _check(_app.last_result.get("code") == &"backup_commit_failed", "capture must identify actual rejected-commit recovery, not claim stale storage"): return false
	if not await _capture(catalog_locale, percent, "operation-recovery"): return false
	for index in 4:
		await _key(KEY_TAB)
		var focused: Control = _viewport.gui_get_focus_owner()
		if not _check(focused in _app.action_buttons.values() or focused == _app.info_scroll, "recovery Tab escaped its current operation controls"): return false
	_app.action_buttons.cancel.grab_focus()
	await _key(KEY_ENTER)
	if not _check(_app.can_return_home() and _app.action_buttons.delete.has_focus(), "recovery Cancel failed to restore the initiating action"): return false
	if not _check(_surface.entered_action == &"backup" and _port.committed.is_empty() and _port.records == original_records, "recovery Cancel performed a record mutation or left Backup"): return false
	_cancel_restores += 1
	return true

func _capture(catalog_locale: String, percent: int, mode: String) -> bool:
	await _frames()
	if not _check(_surface.workfield.position == Vector2(480,64) and _surface.workfield.size == Vector2(800,656), "Pause workfield allocation changed"): return false
	if not _check(_app.position == Vector2.ZERO and _app.size == Vector2(800,656) and _app._body.size == Vector2(800,656), "Backup escaped its fixed 800x656 host"): return false
	if not _check(_surface.entered_action == &"backup" and _app.active_mode == "load" and _app.selected_locator == "slot:2", "capture changed selected host/mode/locator"): return false
	var focused: Control = _viewport.gui_get_focus_owner()
	if not _check(focused != null, "capture has no native Focus owner"): return false
	var details := {}
	if mode == "delete-confirmation":
		var modal: Control = _app.confirmation
		if not _check(modal.get_parent() == _surface.workfield and modal.cancel_button.has_focus(), "shared workfield confirmation lacks initial Cancel focus"): return false
		if not _check(modal.request.confirm == _app.COPY[LOCALES[catalog_locale]].delete and modal.request.cancel == _app.COPY[LOCALES[catalog_locale]].cancel, "confirmation uses incorrect localized action copy"): return false
		var sheet: Control = modal.get_node("ConfirmationSheet")
		if not _check(sheet.position == Vector2(120,112) and sheet.size == Vector2(560,480), "shared confirmation allocation changed"): return false
		var body: Label = modal.body_scroll.get_child(0)
		if not _check(body.text == str(modal.request.title) + "\n\n" + str(modal.request.body), "confirmation lost full title/body copy"): return false
		if not _labels_fit(modal, percent, false): return false
		if not _check(body.size.y <= modal.body_scroll.size.y or modal.body_scroll.get_v_scroll_bar().max_value > modal.body_scroll.get_v_scroll_bar().page, "confirmation overflow lacks real vertical scroll"): return false
		details = {"title":modal.request.title,"body":modal.request.body,"sheet_rect":_rect(sheet),
			"body_rect":_rect(body),"scroll_extent":maxf(0,modal.body_scroll.get_v_scroll_bar().max_value-modal.body_scroll.get_v_scroll_bar().page)}
	else:
		if not _check(_app.is_ancestor_of(focused), "entered Backup lost native focus custody"): return false
		if not _labels_fit(_app, percent, false): return false
		if mode == "operation-recovery":
			if not _check(_app.action_buttons.cancel.has_focus() and not _app.can_return_home(), "operation recovery lacks initial Cancel custody"): return false
			if not _check(_app.status_label.text == _app.COPY[LOCALES[catalog_locale]].failed, "recovery status is not full production localized failure copy"): return false
			for button: Control in _app.mode_buttons.values() + _app.drawer_buttons.values():
				if not _check(button.focus_mode == Control.FOCUS_NONE, "recovery leaves background Backup focus stops"): return false
		details = {"information":_app._info_text.text,"status":_app.status_label.text,
			"information_rect":_rect(_app.info_scroll),"information_extent":maxf(0,_app.info_scroll.get_v_scroll_bar().max_value-_app.info_scroll.get_v_scroll_bar().page),
			"status_rect":_rect(_app.status_region),"action_dock_rect":_rect(_app.action_dock)}
	var pixels := _viewport.get_texture().get_image()
	if not _check(pixels != null and pixels.get_size() == Vector2i(640,360), "capture is not native 640x360"): return false
	if not _check(_same_color(pixels.get_pixel(2,2),_surface.theme.get_color(&"face",&"Pause")), "Pause action plane is not the declared AfterHours role"): return false
	# Theme inheritance must paint native button faces and Focus, not only labels.
	if mode == "delete-confirmation":
		if not _button_pixel(pixels,_app.confirmation.cancel_button,Vector2(12,12),"face"): return false
		if not _button_pixel(pixels,_app.confirmation.cancel_button,Vector2(2,16),"ink"): return false
		if not _button_pixel(pixels,_app.confirmation.cancel_button,Vector2(6,16),"focus"): return false
	elif mode == "backup":
		if not _button_pixel(pixels,_app.mode_buttons.load,Vector2(12,12),"filed"): return false
		if not _button_pixel(pixels,_app.action_buttons.delete,Vector2(12,12),"face"): return false
		if not _button_pixel(pixels,_app.action_buttons.delete,Vector2(0,18),"destructive"): return false
	else:
		if not _button_pixel(pixels,_app.action_buttons.cancel,Vector2(12,12),"face"): return false
		if not _button_pixel(pixels,_app.action_buttons.cancel,Vector2(2,16),"ink"): return false
		if not _button_pixel(pixels,_app.action_buttons.cancel,Vector2(6,16),"focus"): return false
	var name := "%s-%d-AfterHours-ordinary-%s.png" % [catalog_locale,percent,mode]
	if not _check(pixels.save_png(_folder.path_join(name)) == OK, "cannot save native image"): return false
	_records.append({"file":name,"locale":LOCALES[catalog_locale],"text_percent":percent,
		"palette":"AfterHours","high_contrast":false,"colour_preset":"standard","large_targets":false,
		"mode":mode,"native_size":[640,360],"logical_size":[1280,720],"host_rect":_rect(_app),
		"main_font_size":int(24*percent/100.0),"drawer_font_size":int(20*percent/100.0),"action_dock_font_size":int(20*percent/100.0),
		"focus":str(focused.name),"details":details,"prepared":_port.prepared.size(),"committed":_port.committed.size(),"cancelled":_port.cancelled.size()})
	return true

func _labels_fit(node: Node, percent: int, drawer: bool) -> bool:
	drawer = drawer or node.get_script() == _app.DRAWER
	if node is Label and node.is_visible_in_tree() and not node.text.is_empty():
		var label := node as Label
		# BackupApp explicitly authors both drawer labels and the compact two-action
		# dock at 20/25/30; mode keys, information and shared confirmation use 24/30/36.
		var compact: bool = drawer or _app.action_dock.is_ancestor_of(label)
		var expected := int((20 if compact else 24)*percent/100.0)
		var actual := label.get_theme_font_size("font_size")
		if not _check(actual == expected, "text font changed: %s expected=%d actual=%d" % [label.get_path(),expected,actual]): return false
		if not _check(label.max_lines_visible == -1 and label.visible_characters == -1, "text was line- or character-capped: " + str(label.get_path())): return false
		if not _check(label.size.y + 0.1 >= label.get_minimum_size().y, "full label text clips vertically: " + label.text): return false
		if label.get_parent() is Button or label == _app.status_label:
			if not _check((label.get_parent() as Control).get_global_rect().encloses(label.get_global_rect()), "button caption escaped its fixed target: " + label.text): return false
		var font: Font = label.get_theme_font("font")
		for character: String in label.text:
			if character in ["\n", "\r", "\t", " "]: continue
			if not _check(font.has_char(character.unicode_at(0)), "font lacks a visible copy glyph: " + character): return false
	for child: Node in node.get_children():
		if not _labels_fit(child,percent,drawer): return false
	return true

func _read_pause_copy(catalog_locale: String) -> Dictionary:
	var path := "res://localization/ui/%s.json" % catalog_locale
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(parsed is Dictionary and parsed.get("messages") is Array, "invalid real Pause locale catalog: " + path): return {}
	var copy := {}
	for message: Dictionary in parsed.messages:
		var key := str(message.get("id",""))
		if key.begins_with("ui.pause.") and key.trim_prefix("ui.pause.") in COPY_KEYS:
			copy[key.trim_prefix("ui.pause.")] = message.get("text", "")
	for key: String in COPY_KEYS:
		if not _check(typeof(copy.get(key)) == TYPE_STRING and not str(copy[key]).strip_edges().is_empty(), "missing Pause copy: " + key): return {}
	return copy

func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_viewport.push_input(event,true)
		await process_frame
	await _frames()

func _frames() -> void:
	for frame in 3: await RenderingServer.frame_post_draw

func _unmount() -> void:
	if is_instance_valid(_surface):
		_surface.close_surface()
		_surface.queue_free()
		await process_frame
	if is_instance_valid(_locale): _locale.free()
	_port = null
	_profile = null

func _rect(control: Control) -> Array:
	return [control.position.x,control.position.y,control.size.x,control.size.y]

func _same_color(actual: Color, expected: Color) -> bool:
	return absf(actual.r-expected.r) <= 1.1/255 and absf(actual.g-expected.g) <= 1.1/255 and absf(actual.b-expected.b) <= 1.1/255 and actual.a >= 0.999

func _button_pixel(pixels: Image, button: Control, local: Vector2, role: String) -> bool:
	var native := Vector2i((button.get_global_transform_with_canvas()*local)/2.0)
	return _check(_same_color(pixels.get_pixelv(native),button.get_theme_color(role,"Backup")),
		"native button role missing: %s %s at %s" % [button.name,role,native])

func _check(ok: bool, message: String) -> bool:
	if not ok:
		if _failure.is_empty(): _failure = message
		push_error("PAUSE_BACKUP_RENDER_FAILED: " + message)
	return ok

func _finish(ok: bool) -> void:
	var report := FileAccess.open(_folder.path_join("pause-backup-measurements.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"ok":ok,"failure":_failure,"captures":_records.size(),"cancel_restores":_cancel_restores,
			"scope":"Real PauseSurface, BackupApp and DesktopConfirmation presentation with existing FakeBackupPort projection/operation double. No storage, save/load durability, full lifecycle or assistive-technology acceptance.",
			"palette_scope":"AfterHours Standard ordinary targets only. Backup does not yet consume all shared palette/accessibility contexts; no broader tuple acceptance.",
			"recovery_scope":"Explicit rejected commit (backup_commit_failed), not an actual stale-storage transaction.",
			"source_art":"Absent; no authored narrative art or substitute background.",
			"geometry_space":"Logical parent-relative control rectangles; native 640x360 PNGs from a 1280x720 logical SubViewport.",
			"samples":_records},"\t") + "\n")
		report.close()
	else:
		ok = false
		push_error("PAUSE_BACKUP_RENDER_FAILED: cannot write measurement report")
	await _unmount()
	if is_instance_valid(_viewport): _viewport.queue_free()
	await process_frame
	print("PAUSE_BACKUP_RENDER_", "VERIFIED" if ok else "FAILED", " captures=",_records.size()," cancel_restores=",_cancel_restores," evidence=",_folder)
	quit(0 if ok else 1)
