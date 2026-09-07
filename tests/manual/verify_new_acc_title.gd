extends SceneTree
## Actual title controls and native input. The fake owner supplies operation outcomes;
## SaveManager durability and pure preparation are covered by separate real-owner suites.
const MENU := preload("res://scenes/menu/MenuScene.tscn")
const FIXTURE := preload("res://tests/manual/verify_gallery_title_native.gd")

class NewAccOwner extends RefCounted:
	var prepares := 0
	var commits: Array[String] = []
	var cancels: Array[String] = []
	var retries: Array[String] = []
	var live := false
	var autosave := true
	var next_commit := "recovery"
	var retry_ok := false
	func prepare_new_run_action(context: Dictionary) -> Dictionary:
		prepares += 1
		if context != {"route_id":"main","dialogic_checkpoint":{},"active_app_id":null,"audio_context":{},"content_version":1}:
			return {"ok":false,"code":"bad_context"}
		return {"ok":true,"value":{"token":"prepared-%d" % prepares,
			"requires_confirmation":live or autosave,"replaces_live":live,"replaces_autosave":autosave}}
	func commit_prepared_new_run(token: String) -> Dictionary:
		commits.append(token)
		if next_commit == "stale": return {"ok":false,"code":"NEW_RUN_PREPARATION_STALE"}
		if next_commit == "ok": return {"ok":true}
		return {"ok":false,"code":"NEW_RUN_RECOVERY_PENDING","recovery_required":true,"transaction_id":"retained-operation"}
	func cancel_prepared_new_run(token: String) -> Dictionary:
		cancels.append(token)
		return {"ok":true}
	func retry_new_run(transaction: String) -> Dictionary:
		retries.append(transaction)
		return {"ok":retry_ok}

var _view: SubViewport
var _menu: Control
var _profile: Node
var _locale: Node
var _owner: NewAccOwner
var _folder := ""
var _failures: Array[String] = []
var _checks := 0
var _captures := 0
var _samples: Array[Dictionary] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/new_acc_title")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "evidence folder"):
		_finish()
		return
	_view = SubViewport.new()
	_view.size = Vector2i(640,360)
	_view.size_2d_override = Vector2i(1280,720)
	_view.size_2d_override_stretch = true
	_view.handle_input_locally = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_profile = FIXTURE.PublicProfile.new()
	_locale = FIXTURE.CatalogLocale.new()
	_view.add_child(_profile)
	_view.add_child(_locale)
	_check(_locale.present("en"), "real locale catalog")
	_owner = NewAccOwner.new()
	_menu = MENU.instantiate()
	_menu.configure_settings_services({"profile":_profile,"localization":_locale})
	_menu.configure_new_acc_owner(_owner)
	_view.add_child(_menu)
	await _frames()
	for language: String in ["en","zh_CN","zh_HK"]:
		for percent: int in [100,125,150]:
			await _sample(language,percent)
			if not _failures.is_empty():
				_finish()
				return
	await _edge_cases()
	_finish()

func _sample(language: String, percent: int) -> void:
	_check(_locale.present(language), "locale catalog " + language)
	_profile.present(percent,false)
	_owner.autosave = true
	_owner.live = false
	_owner.next_commit = "recovery"
	_owner.retry_ok = false
	await _frames()
	_menu._new_acc_button.grab_focus()
	var before_commits := _owner.commits.size()
	await _key(KEY_ENTER)
	var sheet: Control = _menu._confirmation
	if not _check(is_instance_valid(sheet), "native New Acc opens confirmation"): return
	_check(_owner.commits.size() == before_commits, "opening release cannot consent")
	_check(sheet.cancel_button.has_focus(), "replacement begins on Cancel")
	_check(sheet.request.warning and sheet.confirm_button.risk == "danger", "replacement uses Warning and Danger Start")
	_check(sheet.request.body == _menu.NEW_ACC_COPY[_menu._locale][1], "Autosave replacement exact copy")
	_measure(sheet,percent)
	_capture("%s-%d-consent.png" % [language,percent])
	var before_prepares := _owner.prepares
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(_menu._confirmation) and _menu._new_acc_button.has_focus(), "Back cancels preparation and restores source")
	_check(_owner.commits.size() == before_commits and _owner.cancels.back() == "prepared-%d" % before_prepares, "Cancel discards only matching preparation")
	await _key(KEY_ENTER)
	await _key(KEY_TAB)
	_check(_menu._confirmation.confirm_button.has_focus(), "Tab reaches Start")
	await _key(KEY_ENTER)
	_check(_owner.commits.size() == before_commits+1, "released Start commits once")
	sheet = _menu._confirmation
	if not _check(is_instance_valid(sheet), "interrupted Start shows recovery"): return
	_check(not sheet.cancel_button.visible and sheet.confirm_button.has_focus(), "Retry is sole visible focus target")
	_check(sheet.confirm_button.risk == "neutral" and not sheet.request.warning, "Retry is neutral")
	_measure(sheet,percent)
	_capture("%s-%d-retry.png" % [language,percent])
	await _key(KEY_ESCAPE)
	_check(_menu._confirmation == sheet and _owner.retries.is_empty(), "Back cannot abandon retained decision")
	await _key(KEY_TAB)
	_check(sheet.confirm_button.has_focus(), "Retry Tab stays inside")
	await _menu._on_gallery_pressed()
	_check(_menu._confirmation == sheet and not _menu._gallery_host.visible, "recovery blocks other title commands")
	await _key(KEY_ENTER)
	_check(_owner.retries == ["retained-operation"], "Retry addresses exact operation")
	_check(is_instance_valid(_menu._confirmation) and not _menu._confirmation.cancel_button.visible, "retry failure retains recovery sheet")
	_owner.retry_ok = true
	await _key(KEY_ENTER)
	_check(_owner.retries == ["retained-operation","retained-operation"], "repeated Retry does not allocate another operation")
	_check(not is_instance_valid(_menu._confirmation) and _menu._can_leave_login(), "successful recovery releases title custody in fixture")
	_owner.retries.clear()
	_samples.append({"locale":language,"text_percent":percent,"palette":"Standard Backup paper",
		"logical_size":[1280,720],"native_size":[640,360]})

func _edge_cases() -> void:
	_check(_locale.present("en"),"English edge cases")
	_profile.present(100,false)
	_owner.live = true
	_owner.autosave = false
	await _menu._on_new_acc_pressed()
	await _frames()
	_check(_menu._confirmation.request.body == "Current progress will be replaced. Other saves will remain.","live-only copy does not invent occupied Autosave")
	await _key(KEY_ESCAPE)
	_owner.live = false
	_owner.next_commit = "ok"
	var before := _owner.commits.size()
	await _menu._on_new_acc_pressed()
	await _frames()
	_check(_owner.commits.size() == before+1 and not is_instance_valid(_menu._confirmation), "fresh empty title commits without unnecessary confirmation")
	_owner.autosave = true
	_owner.next_commit = "stale"
	await _menu._on_new_acc_pressed()
	await _frames()
	await _key(KEY_TAB)
	await _key(KEY_ENTER)
	_check(_menu._confirmation.request.body == _menu.NEW_ACC_COPY.en[7], "stale consent is explained without committing again")
	before = _owner.prepares
	await _key(KEY_TAB)
	await _key(KEY_ENTER)
	_check(_owner.prepares == before+1 and _menu._confirmation.request.title == _menu.NEW_ACC_COPY.en[0], "stale Retry prepares fresh and requires new consent")
	await _key(KEY_ESCAPE)
	await _menu._on_new_acc_pressed()
	await _frames()
	var token: String = _menu._new_acc_token
	_menu.queue_free()
	await _frames()
	_check(_owner.cancels.back() == token,"teardown discards pending preparation")

func _measure(sheet: Control, percent: int) -> void:
	var panel: Control = sheet.get_node("ConfirmationSheet")
	_check(Rect2(320,64,960,656).encloses(panel.get_global_rect()), "sheet remains inside title workfield")
	_check(panel.size == Vector2(560,480),"pinned sheet dimensions")
	for button: Button in [sheet.cancel_button,sheet.confirm_button]:
		if not button.visible: continue
		var caption: Label = button.get_node("Caption")
		_check(panel.get_global_rect().encloses(button.get_global_rect()),"action stays inside sheet")
		_check(button.size.y >= 64,"fixed accessible target")
		_check(button.get_global_rect().encloses(caption.get_global_rect()),"complete action caption fits")
		_check(caption.text == button.accessibility_name and caption.max_lines_visible == -1,"visible and accessible complete action copy")
	var body: Label = sheet.body_scroll.get_child(0)
	_check(body.get_theme_font_size("font_size") == int(24*percent/100.0),"body preserves font preset")
	_check(body.size.x <= sheet.body_scroll.size.x and body.size.y >= body.get_minimum_size().y,"body wraps without horizontal clipping")
	_check(sheet.body_scroll.get_global_rect().end.y <= sheet.confirm_button.get_global_rect().position.y,"scroll body never obscures actions")

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

func _capture(name: String) -> void:
	var pixels := _view.get_texture().get_image()
	if not _check(pixels != null and pixels.get_size() == Vector2i(640,360),"native image"): return
	if _check(pixels.save_png(_folder.path_join(name)) == OK,"PNG write"): _captures += 1

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("NEW_ACC_TITLE_FAILED: " + message)
	return condition

func _finish() -> void:
	var report := FileAccess.open(_folder.path_join("measurements.json"),FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"ok":_failures.is_empty(),"failures":_failures,"checks":_checks,
			"captures":_captures,"samples":_samples,"scope":"Actual Menu and shared sheet native rendering/input with explicit in-memory operation outcome fixture. Real fonts/catalogs; Standard paper only. No storage, OS assistive-technology or complete New Acc acceptance claim."},"\t")+"\n")
		report.close()
	else: _check(false,"report write")
	print("NEW_ACC_TITLE_", "VERIFIED" if _failures.is_empty() else "FAILED", " captures=",_captures," checks=",_checks," evidence=",_folder)
	if is_instance_valid(_view): _view.queue_free()
	quit(0 if _failures.is_empty() else 1)
